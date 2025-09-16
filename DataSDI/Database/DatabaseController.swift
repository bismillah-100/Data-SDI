//
//  DatabaseController.swift
//  ReadSQL
//
//  Created by Bismillah on 16/10/23.
//

import Foundation
import SQLite

#if DEBUG
    import os.log
#endif

typealias PenugasanGuruDefaultData = (idGuru: Int64, idJabatan: Int64, idMapel: Int64, idKelas: Int64, tanggalMulaiEfektif: String, tanggalSelesaiEfektif: String?, statusPenugasan: StatusSiswa)
typealias SiswaDefaultData = (nama: String, alamat: String, ttl: String, tahundaftar: String, namawali: String, nis: String, nisn: String, ayah: String, ibu: String, jeniskelamin: JenisKelamin, status: StatusSiswa, tanggalberhenti: String, tlv: String, foto: Data?)
typealias KelasDefaultData = (nama: String, tingkat: String, tahunAjaran: String, semester: String)
typealias SiswaKelasDefaultData = (idSiswa: Int64, idKelas: Int64, statusEnrollment: StatusSiswa, tanggalMasuk: String, tanggalKeluar: String?)
typealias NilaiSiswaDefaultData = (idSiswaKelas: Int64, idPenugasanGuruMapelKelas: Int64, nilai: Int, tanggalNilai: String)

/// DatabaseController adalah class yang menyimpan seluruh fungsi CRUD database dan memiliki satu koneksi database.
///
/// Koneksi database di DBController menggunakan `read-write connection`.
/// Koneksi ini bisa digunakan untuk memperbarui nilai di Database. Berbeda dengan ``DatabaseManager``
/// yang koneksinya husus untuk pembacaan nilai di database saja.
class DatabaseController {
    // MARK: - Properti Notifikasi

    /**
         Antrian operasi `DispatchQueue` pribadi yang digunakan untuk mengelola tugas-tugas asinkron.

         Digunakan untuk untuk memposting notifikasi terkait pemuatan ulang data secara bersamaan tanpa memblokir thread utama.
         Dan juga untuk operasi write database yang membutuhkan operasi sync ketika dijalankan di dalam `TaskGroup`.
     */
    let notifQueue: DispatchQueue = .init(label: "sdi.Data.reloadSavedData", qos: .userInitiated)

    /// Nama notifikasi yang diposting ketika tanggal berhenti (misalnya, lulus) seorang siswa berubah.
    static let tanggalBerhentiBerubah = NSNotification.Name("TanggalBerhentiDidChange")

    /// Nama notifikasi yang diposting ketika seorang siswa baru ditambahkan.
    static let siswaBaru = NSNotification.Name("SiswaBaru")

    // MARK: - Properti Koneksi Database

    /// Koneksi *database* utama yang digunakan untuk operasi baca/tulis.
    /// Ini diinisialisasi secara implisit unwrapped, yang berarti diharapkan selalu tersedia setelah inisialisasi.
    private(set) var db: Connection!

    /// Jalur file ke *database* SQLite.
    private(set) var dbPath: String?

    /// Instance **singleton** dari `DB_Controller`, memastikan hanya ada satu Instance di seluruh aplikasi.
    static let shared: DatabaseController = .init()

    /// *Connection pool* untuk akses *database* *read-only* yang efisien, diperoleh dari `DatabaseManager.shared`.
    let pool = DatabaseManager.shared.pool

    // MARK: - Definisi Tabel dan Kolom

    // Definisi tabel Inventaris (kolom diatur di file DynamicTable)
    /// Representasi objek tabel `main_table` di *database*. Kolom-kolomnya diatur secara dinamis.
    private let mainTable: Table = .init("main_table")

    // MARK: - Inisialisasi

    /// Inisialisasi privat untuk `DB_Controller`, mendukung pola *singleton*.
    ///
    /// Saat diinisialisasi:
    /// 1. Memastikan folder "Data SDI" ada di direktori Dokumen aplikasi.
    /// 2. Menentukan `dbPath` ke `data.sdi` di dalam folder tersebut.
    /// 3. Memanggil `waitForDatabaseFile()` untuk memastikan file *database* ada
    ///    sebelum mencoba membuat koneksi.
    /// 4. Setelah file *database* tersedia, `setupConnection()` dipanggil untuk
    ///    membuat koneksi *database* utama (`db`).
    private init() {
        // Lokasi database
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
        dbPath = dataSiswaFolderURL.appendingPathComponent("data.sdi").path

        // Pastikan file tersedia sebelum melanjutkan
        waitForDatabaseFile()

        // Setelah file tersedia, lanjutkan koneksi
        setupConnection()
    }

    /// **Menunggu file tersedia sebelum melanjutkan eksekusi**
    private func waitForDatabaseFile() {
        guard let dbPath else { return }

        let fileURL = URL(fileURLWithPath: dbPath)

        // Cek apakah file database sudah ada
        if !FileManager.default.fileExists(atPath: dbPath) {
            #if DEBUG
                print("File database tidak ditemukan.")
            #endif
            // Cek apakah file ada di iCloud tapi belum diunduh
            if FileManager.default.ubiquityIdentityToken != nil {
                let alert = NSAlert()
                alert.messageText = "File di iCloud belum diunduh."
                alert.informativeText = "Aplikasi membutuhkan file ini dan akan menunggu proses unduhan selesai. Anda bisa melihat proses unduhan di Finder. Tekan OK untuk melanjutkan."
                alert.runModal()
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                    #if DEBUG
                        print("Memulai unduhan dari iCloud...")
                    #endif
                    // Tunggu hingga file tersedia sebelum melanjutkan
                    while !FileManager.default.fileExists(atPath: dbPath) {
                        #if DEBUG
                            print("Menunggu file selesai diunduh...")
                        #endif
                        sleep(1) // Polling setiap 1 detik
                    }
                } catch {
                    #if DEBUG
                        print("❌: \(error.localizedDescription)")
                    #endif
                }
            }
        }
        #if DEBUG
            print("file tersedia")
        #endif
    }

    /// **Checkpoint dan save ke file SQLite3**
    func checkPoint() {
        do {
            try db?.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            db = nil
            Task.detached(priority: .high) {
                await DatabaseManager.shared.pool.closeAll()
                // Tunggu sedikit agar semua koneksi benar-benar dilepas (opsional tapi aman)
                usleep(200_000) // 200ms
            }

            guard let dbPath else { return }
            hapusWalShm(dbPath: dbPath)

            #if DEBUG
                print("✅ WAL checkpoint.")
            #endif
        } catch {
            #if DEBUG
                print("❌ WAL checkpoint: \(error)")
            #endif
        }
    }

    /// Menghapus file `wal` dan `shm` di folder ~/Documents/Data SDI/.
    /// - Parameter dbPath: path ke folder dan file `.sqlite` (tanpa wal-shm).
    func hapusWalShm(dbPath: String) {
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        do {
            try FileManager.default.removeItem(atPath: walPath)
            try FileManager.default.removeItem(atPath: shmPath)
        } catch {
            #if DEBUG
                print("error menghapus file WAL-SHM")
            #endif
        }
    }

    /// Kecualikan file database dari iCloud Documents.
    ///
    /// Bertujuan untuk mengecualikan file WAL dan SHM supaya tidak di unggah ke iCloud Drive.
    func excludeFileFromBackup(_ path: String) {
        var url: URL! = if #available(macOS 13.0, *) {
            URL(filePath: path)
        } else {
            URL(fileURLWithPath: path)
        }
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
            #if DEBUG
                print("✅ dikecualikan dari backup: \(url.lastPathComponent)")
            #endif
        } catch {
            #if DEBUG
                print("❌: \(error.localizedDescription)")
            #endif
        }
    }

    /// Menutup koneksi database ``db``.
    func closeConnection() {
        db = nil
    }

    /// Metode untuk inisialisasi ulang
    func reloadDatabase(withNewPath newPath: String) {
        closeConnection()
        dbPath = newPath
        setupConnection()
    }

    /// Membuat koneksi SQLite ke File SQLite3
    private func setupConnection() {
        guard let dbPath else { return }
        do {
            db = try Connection(dbPath)
            siapkanTabel()
            try db.run("PRAGMA journal_mode=WAL;")
            try db.run("PRAGMA foreign_keys = ON")
            let walPath = dbPath + "-wal"
            let shmPath = dbPath + "-shm"
            excludeFileFromBackup(walPath)
            excludeFileFromBackup(shmPath)
        } catch {
            #if DEBUG
                print("Error initializing database: \(error.localizedDescription)")
            #endif
        }
    }

    /// Menyiapkan tabel SQLite3 dan membuat indeks tabel untuk digunakan Aplikasi.
    func siapkanTabel() {
        do {
            // Buat tabel jika belum ada
            buatTabel()

            // MARK: - Index untuk tabel siswa

            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.nama,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.alamat,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.tahundaftar,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.nis,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.nisn,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.jeniskelamin,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.status,
                ifNotExists: true
            ))
            try db.run(SiswaColumns.tabel.createIndex(
                SiswaColumns.id,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel guru

            try db.run(GuruColumns.tabel.createIndex(
                GuruColumns.nama,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel mapel

            try db.run(MapelColumns.tabel.createIndex(
                MapelColumns.nama,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel kelas

            // Tabel kelas: index pada kolom 'tingkat_kelas' untuk filter cepat
            try db.run(KelasColumns.tabel.createIndex(
                KelasColumns.tingkat,
                ifNotExists: true
            ))

            // 5. Tabel kelas: index PK idKelas otomatis, dan untuk filter by tahun_ajaran/tingkat_kelas/semester:
            try db.run(KelasColumns.tabel.createIndex(
                KelasColumns.tahunAjaran,
                ifNotExists: true
            ))
            try db.run(KelasColumns.tabel.createIndex(
                KelasColumns.tingkat,
                ifNotExists: true
            ))
            try db.run(KelasColumns.tabel.createIndex(
                KelasColumns.semester,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel siswa_kelas

            // 2. Tabel siswa_kelas: index pada foreign key + filter statusEnrollment
            try db.run(SiswaKelasColumns.tabel.createIndex(
                SiswaKelasColumns.idSiswa,
                SiswaKelasColumns.statusEnrollment,
                ifNotExists: true
            ))

            // 2. Tabel kelas: composite index
            //    tahun_ajaran, tingkat_kelas, semester
            //    (untuk filter komposit sekaligus)
            try db.run(KelasColumns.tabel.createIndex(
                KelasColumns.tahunAjaran,
                KelasColumns.tingkat,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel penugasan_guru_mapel_kelas

            try db.run(
                PenugasanGuruMapelKelasColumns.tabel.createIndex(
                    PenugasanGuruMapelKelasColumns.statusPenugasan,
                    ifNotExists: true
                )
            )

            // 2. Index tunggal untuk id_kelas (karena sering join/filter)
            try db.run(
                PenugasanGuruMapelKelasColumns.tabel.createIndex(
                    PenugasanGuruMapelKelasColumns.idKelas,
                    ifNotExists: true
                )
            )

            // 3. (Opsional) Index untuk id_guru jika sering filter juga di WHERE
            try db.run(
                PenugasanGuruMapelKelasColumns.tabel.createIndex(
                    PenugasanGuruMapelKelasColumns.idGuru,
                    ifNotExists: true
                )
            )

            // 4. Index di tabel kelas untuk kolom semester + tahun_ajaran
            try db.run(
                KelasColumns.tabel.createIndex(
                    KelasColumns.semester,
                    KelasColumns.tahunAjaran,
                    ifNotExists: true
                )
            )

            // 5. Index di tabel kelas untuk tingkat_kelas (if you search by it)
            try db.run(
                KelasColumns.tabel.createIndex(
                    KelasColumns.tingkat,
                    ifNotExists: true
                )
            )

            // 5. Tabel siswa & guru & mapel: PK sudah otomatis di‑index via rowid
            try db.run(GuruColumns.tabel.createIndex(
                GuruColumns.nama,
                ifNotExists: true
            ))
            try db.run(MapelColumns.tabel.createIndex(
                MapelColumns.nama,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel nilai_siswa_mapel

            try db.run(NilaiSiswaMapelColumns.tabel.createIndex(
                NilaiSiswaMapelColumns.idSiswaKelas,
                ifNotExists: true
            ))

            try db.run(NilaiSiswaMapelColumns.tabel.createIndex(
                NilaiSiswaMapelColumns.idMapel,
                ifNotExists: true
            ))

            try db.run(NilaiSiswaMapelColumns.tabel.createIndex(
                NilaiSiswaMapelColumns.idPenugasanGuruMapelKelas,
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel main_table (jika digunakan untuk pencarian)

            try db.run(mainTable.createIndex(
                Expression<String?>("Nama Barang"),
                Expression<String?>("Lokasi"),
                Expression<String?>("Kondisi"),
                ifNotExists: true
            ))

            // MARK: - Index untuk tabel jabatan

            try db.run(JabatanColumns.tabel.createIndex(
                JabatanColumns.nama,
                ifNotExists: true
            ))

            try db.run("""
                CREATE INDEX IF NOT EXISTS idx_sk_status_siswa_max
                ON siswa_kelas (status_enrollment, id_siswa, id_siswa_kelas DESC)
            """)

            try db.run("""
                CREATE INDEX IF NOT EXISTS idx_sk_siswa_max
                ON siswa_kelas (id_siswa, id_siswa_kelas DESC)
            """)

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    private func buatDataDefault(tabel: String) throws {
        do {
            switch tabel {
            case "siswa": try siswaTabel()
            case "jabatan_guru": try jabatanTabel()
            case "guru": try guruTabel()
            case "mapel": try mapel()
            case "kelas": try kelas()
            case "siswa_kelas": try siswaKelas()
            case "penugasan_guru_mapel_kelas": try penugasan()
            case "nilai_siswa_mapel": try nilaiSiswa()
            default: break
            }
        } catch {
            print(error.localizedDescription)
        }

        func siswaTabel() throws {
            let image = NSImage(named: .siswa)
            let imageData = image?.compressImage(quality: 0.01)
            let siswaList: [SiswaDefaultData] = [
                (nama: "Siswa 1", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 1", ttl: "Pasuruan, 01-01-2008", tahundaftar: "03 Maret 2021", namawali: "Wali 1", nis: "12345", nisn: "54321", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .lakiLaki, status: .aktif, tanggalberhenti: "", tlv: "085234567890", foto: nil),
                (nama: "Siswa 2", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 2", ttl: "Jeddah, 02-02-2009", tahundaftar: "03 Mei 2017", namawali: "Wali 2", nis: "67890", nisn: "98765", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .perempuan, status: .aktif, tanggalberhenti: "", tlv: "082234567890", foto: nil),
                (nama: "Siswa 3", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 3", ttl: "Madinah, 01-01-2008", tahundaftar: "03 Maret 2021", namawali: "Wali 3", nis: "12345", nisn: "54321", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .lakiLaki, status: .aktif, tanggalberhenti: "", tlv: "085234567890", foto: nil),
                (nama: "Siswa 4", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 4", ttl: "Mekkah, 02-02-2009", tahundaftar: "03 Mei 2017", namawali: "Wali 4", nis: "67890", nisn: "98765", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .perempuan, status: .aktif, tanggalberhenti: "", tlv: "082234567890", foto: nil),
                (nama: "Siswa 5", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 5", ttl: "Yogyakarta, 01-01-2008", tahundaftar: "03 Maret 2021", namawali: "Wali 5", nis: "12345", nisn: "54321", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .lakiLaki, status: .aktif, tanggalberhenti: "", tlv: "085234567890", foto: nil),
                (nama: "Siswa 6", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 6", ttl: "Surabaya, 02-02-2009", tahundaftar: "03 Mei 2017", namawali: "Wali 6", nis: "67890", nisn: "98765", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .perempuan, status: .aktif, tanggalberhenti: "", tlv: "082234567890", foto: nil),
                (nama: "Siswa 7", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 1", ttl: "Malang, 03-03-2010", tahundaftar: "20 Oktober 2015", namawali: "Wali 3", nis: "11223", nisn: "33221", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .lakiLaki, status: .berhenti, tanggalberhenti: "08 November 2021", tlv: "081234567890", foto: nil),
                (nama: "Siswa Lulus", alamat: "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 8", ttl: "Gondang Wetan, 03-03-2010", tahundaftar: "20 Oktober 2015", namawali: "Wali 3", nis: "11223", nisn: "33221", ayah: "Nama Ayah", ibu: "Nama Ibu", jeniskelamin: .lakiLaki, status: .lulus, tanggalberhenti: "08 November 2022", tlv: "081234567890", foto: nil),
            ]

            for siswa in siswaList {
                try db.run(SiswaColumns.tabel.insert(
                    SiswaColumns.nama <- siswa.nama,
                    SiswaColumns.alamat <- siswa.alamat,
                    SiswaColumns.ttl <- siswa.ttl,
                    SiswaColumns.tahundaftar <- siswa.tahundaftar,
                    SiswaColumns.namawali <- siswa.namawali,
                    SiswaColumns.nis <- siswa.nis,
                    SiswaColumns.nisn <- siswa.nisn,
                    SiswaColumns.ayah <- siswa.ayah,
                    SiswaColumns.ibu <- siswa.ibu,
                    SiswaColumns.jeniskelamin <- siswa.jeniskelamin.rawValue,
                    SiswaColumns.status <- siswa.status.rawValue,
                    SiswaColumns.tanggalberhenti <- siswa.tanggalberhenti,
                    SiswaColumns.tlv <- siswa.tlv,
                    SiswaColumns.foto <- imageData ?? Data()
                ))
            }
        }

        func jabatanTabel() throws {
            // Master Jabatan default
            // --- Master Jabatan default ---
            let jabatanData: [(id: Int64, nama: String)] = [
                (1, "Guru Kelas"),
                (2, "Wali Kelas dan Hafalan"),
                (3, "Wali Kelas"),
            ]
            for jabatan in jabatanData {
                try db.run(JabatanColumns.tabel.insert(JabatanColumns.id <- jabatan.id, JabatanColumns.nama <- jabatan.nama))
            }
        }

        func guruTabel() throws {
            // GURU
            let guruData: [(nama: String, alamat: String)] = [
                ("Muhammad Abdul Karim", "Jl. Anggrek No.1"),
                ("Abdulloh Mubarok", "Jl. Mawar No.2"),
                ("Jalaluddin Ahmad", "Jl. Melati No.3"),
            ]
            for guru in guruData {
                try db.run(GuruColumns.tabel.insert(GuruColumns.nama <- guru.nama, GuruColumns.alamat <- guru.alamat))
            }
        }

        func mapel() throws {
            // MAPEL
            let mapelData: [String] = ["Al-Qur'an", "Bahasa Arab", "Fiqh", "Tauhid", "Tajwid"]
            for mapel in mapelData {
                try db.run(MapelColumns.tabel.insert(MapelColumns.nama <- mapel))
            }
        }

        func kelas() throws {
            // --- Kelas ---
            let kelasData: [KelasDefaultData] = [
                KelasDefaultData(nama: "A", tingkat: "1", tahunAjaran: "2024/2025", semester: "1"), // ID 1
                KelasDefaultData(nama: "A", tingkat: "2", tahunAjaran: "2024/2025", semester: "2"), // ID 2
                KelasDefaultData(nama: "A", tingkat: "3", tahunAjaran: "2024/2025", semester: "1"), // ID 3
                KelasDefaultData(nama: "A", tingkat: "4", tahunAjaran: "2024/2025", semester: "1"), // ID 4
                KelasDefaultData(nama: "A", tingkat: "5", tahunAjaran: "2024/2025", semester: "2"), // ID 5
                KelasDefaultData(nama: "A", tingkat: "6", tahunAjaran: "2024/2025", semester: "1"), // ID 6
            ]
            for kelas in kelasData {
                try db.run(KelasColumns.tabel.insert(
                    KelasColumns.nama <- kelas.nama,
                    KelasColumns.tingkat <- kelas.tingkat,
                    KelasColumns.tahunAjaran <- kelas.tahunAjaran,
                    KelasColumns.semester <- kelas.semester
                ))
            }
        }

        // --- Siswa Kelas Enrollment ---
        func siswaKelas() throws {
            let siswaKelasData: [SiswaKelasDefaultData] = [
                SiswaKelasDefaultData(idSiswa: 1, idKelas: 1, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 2, idKelas: 2, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 3, idKelas: 3, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 4, idKelas: 4, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 5, idKelas: 5, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 6, idKelas: 6, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 7, idKelas: 6, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 8, idKelas: 6, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 9, idKelas: 6, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 10, idKelas: 6, statusEnrollment: .aktif, tanggalMasuk: "01 Juli 2024", tanggalKeluar: nil),
                SiswaKelasDefaultData(idSiswa: 1, idKelas: 4, statusEnrollment: .lulus, tanggalMasuk: "01 Januari 2024", tanggalKeluar: "30 Juni 2024"),
            ]
            for enrollment in siswaKelasData {
                try db.run(SiswaKelasColumns.tabel.insert(
                    SiswaKelasColumns.idSiswa <- enrollment.idSiswa,
                    SiswaKelasColumns.idKelas <- enrollment.idKelas,
                    SiswaKelasColumns.statusEnrollment <- enrollment.statusEnrollment.rawValue,
                    SiswaKelasColumns.tanggalMasuk <- enrollment.tanggalMasuk,
                    SiswaKelasColumns.tanggalKeluar <- enrollment.tanggalKeluar
                ))
            }
        }

        // --- Penugasan Guru ---
        func penugasan() throws {
            let penugasanGuruData: [PenugasanGuruDefaultData] = [
                PenugasanGuruDefaultData(idGuru: 1, idJabatan: 1, idMapel: 1, idKelas: 1, tanggalMulaiEfektif: "1 Juni 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
                PenugasanGuruDefaultData(idGuru: 2, idJabatan: 2, idMapel: 2, idKelas: 2, tanggalMulaiEfektif: "15 Juli 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
                PenugasanGuruDefaultData(idGuru: 3, idJabatan: 3, idMapel: 3, idKelas: 3, tanggalMulaiEfektif: "14 Juli 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
                PenugasanGuruDefaultData(idGuru: 1, idJabatan: 3, idMapel: 3, idKelas: 4, tanggalMulaiEfektif: "14 Juli 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
                PenugasanGuruDefaultData(idGuru: 2, idJabatan: 3, idMapel: 3, idKelas: 5, tanggalMulaiEfektif: "14 Juli 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
                PenugasanGuruDefaultData(idGuru: 3, idJabatan: 3, idMapel: 3, idKelas: 6, tanggalMulaiEfektif: "14 Juli 2024", tanggalSelesaiEfektif: nil, statusPenugasan: .aktif),
            ]
            for penugasan in penugasanGuruData {
                try db.run(PenugasanGuruMapelKelasColumns.tabel.insert(
                    PenugasanGuruMapelKelasColumns.idGuru <- penugasan.idGuru,
                    PenugasanGuruMapelKelasColumns.idJabatan <- penugasan.idJabatan,
                    PenugasanGuruMapelKelasColumns.idMapel <- penugasan.idMapel,
                    PenugasanGuruMapelKelasColumns.idKelas <- penugasan.idKelas,
                    PenugasanGuruMapelKelasColumns.tanggalMulaiEfektif <- penugasan.tanggalMulaiEfektif,
                    PenugasanGuruMapelKelasColumns.tanggalSelesaiEfektif <- penugasan.tanggalSelesaiEfektif,
                    PenugasanGuruMapelKelasColumns.statusPenugasan <- penugasan.statusPenugasan.rawValue
                ))
            }
        }

        func nilaiSiswa() throws {
            // --- Nilai Siswa ---
            let nilaiSiswaData: [NilaiSiswaDefaultData] = [
                NilaiSiswaDefaultData(idSiswaKelas: 1, idPenugasanGuruMapelKelas: 1, nilai: 71, tanggalNilai: "29 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 1, idPenugasanGuruMapelKelas: 1, nilai: 76, tanggalNilai: "11 Juli 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 2, idPenugasanGuruMapelKelas: 2, nilai: 72, tanggalNilai: "29 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 2, idPenugasanGuruMapelKelas: 2, nilai: 77, tanggalNilai: "11 Juli 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 3, idPenugasanGuruMapelKelas: 3, nilai: 73, tanggalNilai: "29 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 3, idPenugasanGuruMapelKelas: 3, nilai: 78, tanggalNilai: "11 Juli 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 4, idPenugasanGuruMapelKelas: 4, nilai: 74, tanggalNilai: "29 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 4, idPenugasanGuruMapelKelas: 4, nilai: 79, tanggalNilai: "11 Juli 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 5, idPenugasanGuruMapelKelas: 5, nilai: 75, tanggalNilai: "29 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 5, idPenugasanGuruMapelKelas: 5, nilai: 80, tanggalNilai: "11 Juli 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 6, idPenugasanGuruMapelKelas: 6, nilai: 81, tanggalNilai: "30 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 7, idPenugasanGuruMapelKelas: 6, nilai: 82, tanggalNilai: "30 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 8, idPenugasanGuruMapelKelas: 6, nilai: 83, tanggalNilai: "30 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 9, idPenugasanGuruMapelKelas: 6, nilai: 84, tanggalNilai: "30 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 10, idPenugasanGuruMapelKelas: 6, nilai: 85, tanggalNilai: "30 Juni 2024"),
                NilaiSiswaDefaultData(idSiswaKelas: 11, idPenugasanGuruMapelKelas: 1, nilai: 85, tanggalNilai: "11 Juli 2024"),
            ]
            for nilaiSiswa in nilaiSiswaData {
                try db.run(NilaiSiswaMapelColumns.tabel.insert(
                    NilaiSiswaMapelColumns.idSiswaKelas <- nilaiSiswa.idSiswaKelas,
                    NilaiSiswaMapelColumns.idPenugasanGuruMapelKelas <- nilaiSiswa.idPenugasanGuruMapelKelas,
                    NilaiSiswaMapelColumns.nilai <- nilaiSiswa.nilai,
                    NilaiSiswaMapelColumns.tanggalNilai <- nilaiSiswa.tanggalNilai
                ))
            }
        }
    }

    /// Membuat tabel-tabel *database* yang diperlukan jika belum ada.
    ///
    /// Fungsi ini mengiterasi daftar nama tabel yang telah ditentukan
    /// (`siswa`, `guru`, `kelas1` hingga `kelas6`, dan `main_table`).
    /// Untuk setiap tabel, ia memeriksa apakah tabel tersebut sudah ada di *database*.
    /// Jika belum ada, tabel akan dibuat dengan skema kolom yang telah ditentukan.
    ///
    /// Selain itu, untuk setiap tabel utama (`siswa`, `guru`, `kelas1` hingga `kelas6`, `main_table`),
    /// jika ini adalah peluncuran aplikasi pertama (ditentukan oleh `UserDefaults.standard.bool(forKey: "aplFirstLaunch")`),
    /// data contoh akan disisipkan ke dalam tabel yang baru dibuat.
    ///
    /// - Catatan: Metode ini mengandalkan properti `db` yang sudah terhubung
    ///   ke *database* dan metode pembantu `isTableExists` untuk memeriksa keberadaan tabel.
    ///   Kesalahan saat membuat tabel atau menyisipkan data akan dicetak ke konsol.
    func buatTabel() {
        let tablesToCreate = [
            "siswa", "jabatan_guru", "guru", "mapel", "kelas", "siswa_kelas",
            "penugasan_guru_mapel_kelas", "nilai_siswa_mapel", "main_table",
        ] // Urutan penting untuk FK

        for tableName in tablesToCreate {
            if !isTableExists(tableName) {
                do {
                    switch tableName {
                    case "siswa":
                        try db.run(SiswaColumns.tabel.create { t in
                            t.column(SiswaColumns.id, primaryKey: true)
                            t.column(SiswaColumns.nama)
                            t.column(SiswaColumns.alamat)
                            t.column(SiswaColumns.ttl)
                            t.column(SiswaColumns.tahundaftar)
                            t.column(SiswaColumns.namawali)
                            t.column(SiswaColumns.nis)
                            t.column(SiswaColumns.nisn)
                            t.column(SiswaColumns.ayah)
                            t.column(SiswaColumns.ibu)
                            t.column(SiswaColumns.jeniskelamin)
                            t.column(SiswaColumns.status)
                            t.column(SiswaColumns.tanggalberhenti)
                            t.column(SiswaColumns.tlv)
                            t.column(SiswaColumns.foto)
                        })

                    case "jabatan_guru":
                        try db.run(JabatanColumns.tabel.create { t in
                            t.column(JabatanColumns.id, primaryKey: true)
                            t.column(JabatanColumns.nama, unique: true)
                        })

                    case "guru":
                        try db.run(GuruColumns.tabel.create { t in
                            t.column(GuruColumns.id, primaryKey: true)
                            t.column(GuruColumns.nama)
                            t.column(GuruColumns.alamat)
                        })

                    case "mapel":
                        try db.run(MapelColumns.tabel.create { t in
                            t.column(MapelColumns.id, primaryKey: true)
                            t.column(MapelColumns.nama, unique: true)
                        })

                    case "kelas":
                        try db.run(KelasColumns.tabel.create { t in
                            t.column(KelasColumns.id, primaryKey: true)
                            t.column(KelasColumns.nama)
                            t.column(KelasColumns.tingkat)
                            t.column(KelasColumns.tahunAjaran)
                            t.column(KelasColumns.semester)
                            t.unique(KelasColumns.nama, KelasColumns.tingkat, KelasColumns.tahunAjaran, KelasColumns.semester)
                        })

                    case "siswa_kelas":
                        try db.run(SiswaKelasColumns.tabel.create { t in
                            t.column(SiswaKelasColumns.id, primaryKey: true)
                            t.column(SiswaKelasColumns.idSiswa)
                            t.column(SiswaKelasColumns.idKelas)
                            t.column(SiswaKelasColumns.statusEnrollment)
                            t.column(SiswaKelasColumns.tanggalMasuk)
                            t.column(SiswaKelasColumns.tanggalKeluar)
                            t.foreignKey(SiswaKelasColumns.idSiswa, references: SiswaColumns.tabel, SiswaColumns.id, delete: .restrict)
                            t.foreignKey(SiswaKelasColumns.idKelas, references: KelasColumns.tabel, KelasColumns.id, delete: .restrict)
                            t.unique(SiswaKelasColumns.idSiswa, SiswaKelasColumns.idKelas)
                        })

                    case "penugasan_guru_mapel_kelas":
                        try db.run(PenugasanGuruMapelKelasColumns.tabel.create { t in
                            t.column(PenugasanGuruMapelKelasColumns.id, primaryKey: true)
                            t.column(PenugasanGuruMapelKelasColumns.idGuru)
                            t.column(PenugasanGuruMapelKelasColumns.idJabatan) // FK ke Jabatan
                            t.column(PenugasanGuruMapelKelasColumns.idMapel)
                            t.column(PenugasanGuruMapelKelasColumns.idKelas)
                            t.column(PenugasanGuruMapelKelasColumns.tanggalMulaiEfektif)
                            t.column(PenugasanGuruMapelKelasColumns.tanggalSelesaiEfektif)
                            t.column(PenugasanGuruMapelKelasColumns.statusPenugasan)
                            t.foreignKey(PenugasanGuruMapelKelasColumns.idGuru, references: GuruColumns.tabel, GuruColumns.id, delete: .restrict)
                            t.foreignKey(PenugasanGuruMapelKelasColumns.idJabatan, references: JabatanColumns.tabel, JabatanColumns.id, delete: .restrict)
                            t.foreignKey(PenugasanGuruMapelKelasColumns.idMapel, references: MapelColumns.tabel, MapelColumns.id, delete: .restrict)
                            t.foreignKey(PenugasanGuruMapelKelasColumns.idKelas, references: KelasColumns.tabel, KelasColumns.id, delete: .restrict)
                            t.unique(PenugasanGuruMapelKelasColumns.idGuru, PenugasanGuruMapelKelasColumns.idMapel, PenugasanGuruMapelKelasColumns.idKelas, PenugasanGuruMapelKelasColumns.tanggalMulaiEfektif)
                        })

                    case "nilai_siswa_mapel":
                        try db.run(NilaiSiswaMapelColumns.tabel.create { t in
                            t.column(NilaiSiswaMapelColumns.id, primaryKey: true)
                            t.column(NilaiSiswaMapelColumns.idSiswaKelas)
                            t.column(NilaiSiswaMapelColumns.idPenugasanGuruMapelKelas) // FK baru
                            t.column(NilaiSiswaMapelColumns.nilai)
                            t.column(NilaiSiswaMapelColumns.tanggalNilai)

                            t.foreignKey(NilaiSiswaMapelColumns.idSiswaKelas, references: SiswaKelasColumns.tabel, SiswaKelasColumns.id, delete: .restrict)
                            t.foreignKey(NilaiSiswaMapelColumns.idPenugasanGuruMapelKelas, references: PenugasanGuruMapelKelasColumns.tabel, PenugasanGuruMapelKelasColumns.id, delete: .restrict)

                            // Unik per siswa_kelas + penugasan + tanggal
                            t.unique(NilaiSiswaMapelColumns.idSiswaKelas, NilaiSiswaMapelColumns.idPenugasanGuruMapelKelas, NilaiSiswaMapelColumns.tanggalNilai)
                        })

                    case "main_table":
                        try db.run(mainTable.create { t in
                            t.column(Expression<Int64>("id"), primaryKey: true)
                            t.column(Expression<String?>("Nama Barang"))
                            t.column(Expression<String?>("Lokasi"))
                            t.column(Expression<String?>("Kondisi"))
                            t.column(Expression<String?>("Tanggal Dibuat"))
                            t.column(Expression<Data?>("Foto"))
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            let image = NSImage(named: "pensil")
                            let imageData = image?.compressImage(quality: 0.5, preserveTransparency: true)
                            try db.run(mainTable.insert(Expression<String?>("Nama Barang") <- "Barang 1 (Drag & Drop ke/dari Kolom \"Nama Barang\" untuk insert/ekspor foto Barang 1)", Expression<String?>("Lokasi") <- "Lokasi 1", Expression<String?>("Kondisi") <- "Baru", Expression<String?>("Tanggal Dibuat") <- "02 Februari 2023", Expression<Data?>("Foto") <- imageData ?? nil))
                            try db.run(mainTable.insert(Expression<String?>("Nama Barang") <- "Barang 2 (Drag & Drop ke/dari Kolom \"Nama Barang\" untuk insert/ekspor foto Barang 2)", Expression<String?>("Lokasi") <- "Lokasi 2", Expression<String?>("Kondisi") <- "Baik", Expression<String?>("Tanggal Dibuat") <- "02 Maret 2023", Expression<Data?>("Foto") <- imageData ?? nil))
                            try db.run(mainTable.insert(Expression<String?>("Nama Barang") <- "Barang 3 (Drag & Drop ke/dari Kolom \"Nama Barang\" untuk insert/ekspor foto Barang 3)", Expression<String?>("Lokasi") <- "Lokasi 3", Expression<String?>("Kondisi") <- "Usang", Expression<String?>("Tanggal Dibuat") <- "02 April 2023", Expression<Data?>("Foto") <- imageData ?? nil))
                        }

                    default:
                        break
                    }

                    if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                        try buatDataDefault(tabel: tableName)
                    }
                } catch {
                    #if DEBUG
                        print("Error creating table '\(tableName)': \(error.localizedDescription)")
                    #endif
                }
            } else {
                #if DEBUG
                    print("Tabel '\(tableName)' sudah ada, melewati pembuatan.")
                #endif
            }
        }
    }

    /// Memeriksa apakah tabel sudah ada atau belum.
    func isTableExists(_ tableName: String) -> Bool {
        do {
            _ = try db.scalar("SELECT 1 FROM \(tableName) LIMIT 1")
            return true
        } catch {
            return false
        }
    }

    /// Membuat folder yang menampung semua file yang digunakan untuk menyimpan data di dalam folder Dokumen pengguna.
    static func createDataSiswaFolder() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")

        do {
            try FileManager.default.createDirectory(at: dataSiswaFolderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    #if DEBUG
        private let poi: OSLog = .init(subsystem: "Test", category: .pointsOfInterest)
        nonisolated func threadedProcess(_ message: StaticString, _: Int) {
            let id = OSSignpostID(log: poi)
            os_signpost(.begin, log: poi, name: #function, signpostID: id, message)

            os_signpost(.end, log: poi, name: #function, signpostID: id)
        }
    #endif

    /// Fungsi pembantu generik untuk mengambil ID dan Nama dari tabel mana pun
    /// yang memiliki kolom 'id' (Int64) dan 'nama' (String).
    /// - Parameters:
    ///   - table: Objek `Table` yang merepresentasikan tabel database.
    ///   - idColumn: `Expression<Int64>` untuk kolom ID.
    ///   - nameColumn: `Expression<String>` untuk kolom nama.
    ///   - filter: Sebuah closure opsional yang mengembalikan `Expression<Bool>` untuk kondisi WHERE.
    /// - Returns: Array tuple `(Int64, String)` atau array kosong jika terjadi error.
    func fetchIDAndName(from table: Table, idColumn: Expression<Int64>, nameColumn: Expression<String>, filter: ((Table) -> Expression<Bool>)? = nil) async -> [(Int64, String)] {
        var results: [(Int64, String)] = []
        do {
            results = try await pool.read { db in
                var query = table // Mulai dengan tabel

                // Terapkan filter jika ada
                if let filterCondition = filter {
                    query = table.filter(filterCondition(table)) // Filter apply ke tabel
                }

                var list: [(Int64, String)] = []
                for row in try db.prepare(query) {
                    // Pastikan row memiliki kolom yang diminta
                    if let id = try? row.get(idColumn), let name = try? row.get(nameColumn) {
                        list.append((id, name))
                    }
                }
                return list
            }
        } catch {
            #if DEBUG
                print("Database Error: \(error.localizedDescription)")
            #endif
        }
        return results
    }

    /// Melakukan backup database utama (`data.sdi`) dan database administrasi (`Administrasi.sdi`).
    ///
    /// Fungsi ini membuat salinan database ke dalam folder "Data SDI" di direktori Documents
    /// dengan format nama file `data_DD-MM-YYYY.sdi` dan `Administrasi_DD-MM-YYYY.sdi`.
    /// Jika file backup dengan tanggal yang sama sudah ada, fungsi akan membandingkan tanggal modifikasi
    /// dan ukuran file. Backup akan diperbarui jika file database asli lebih baru atau memiliki ukuran yang berbeda.
    func backupDatabase() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy" // Format tanggal yang diinginkan

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("Data SDI/data.sdi").path
        let lokAdministrasi = documentsDirectory.appendingPathComponent("Data SDI/Administrasi.sdi").path

        let currentDate = dateFormatter.string(from: Date())
        let backupFileName = "data_\(currentDate).sdi"
        let namaBackupAdministrasi = "Administrasi_\(currentDate).sdi"

        let backupPath = documentsDirectory.appendingPathComponent("Data SDI/\(backupFileName)").path
        let lokBackupAdministrasi = documentsDirectory.appendingPathComponent("Data SDI/\(namaBackupAdministrasi)").path

        do {
            // Cek apakah file backup sudah ada
            if FileManager.default.fileExists(atPath: backupPath) {
                // Ambil informasi tanggal modifikasi dan ukuran file lama
                let attributes = try FileManager.default.attributesOfItem(atPath: backupPath)
                if let fileModificationDate = attributes[.modificationDate] as? Date,
                   let fileSize = attributes[.size] as? NSNumber
                {
                    // Ambil informasi tanggal modifikasi dan ukuran file baru
                    let currentFileAttributes = try FileManager.default.attributesOfItem(atPath: dbPath)
                    if let currentFileModificationDate = currentFileAttributes[.modificationDate] as? Date,
                       let currentFileSize = currentFileAttributes[.size] as? NSNumber
                    {
                        // Bandingkan tanggal modifikasi dan ukuran file
                        if currentFileModificationDate > fileModificationDate, currentFileSize != fileSize {
                            // Jika tanggal modifikasi file baru lebih baru dan ukuran file berbeda
                            try FileManager.default.removeItem(atPath: backupPath)
                            #if DEBUG
                                print("backup lama dihapus.")
                            #endif
                            // Salin file baru ke lokasi backup
                            try FileManager.default.copyItem(atPath: dbPath, toPath: backupPath)
                            #if DEBUG
                                print("backup baru telah dibuat.")
                            #endif
                        } else {
                            #if DEBUG
                                print("Tidak ada modifikasi atau ukuran file sama.")
                            #endif
                        }
                    }
                }
            } else {
                // Jika file backup belum ada, langsung salin file baru
                try FileManager.default.copyItem(atPath: dbPath, toPath: backupPath)
                #if DEBUG
                    print("backup baru telah disalin.")
                #endif
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        do {
            // Cek apakah file backup sudah ada
            if FileManager.default.fileExists(atPath: lokBackupAdministrasi) {
                // Ambil informasi tanggal modifikasi dan ukuran file lama
                let attributes = try FileManager.default.attributesOfItem(atPath: lokBackupAdministrasi)
                if let fileModificationDate = attributes[.modificationDate] as? Date,
                   let fileSize = attributes[.size] as? NSNumber
                {
                    // Ambil informasi tanggal modifikasi dan ukuran file baru
                    let currentFileAttributes = try FileManager.default.attributesOfItem(atPath: lokAdministrasi)
                    if let currentFileModificationDate = currentFileAttributes[.modificationDate] as? Date,
                       let currentFileSize = currentFileAttributes[.size] as? NSNumber
                    {
                        // Bandingkan tanggal modifikasi dan ukuran file
                        if currentFileModificationDate > fileModificationDate, currentFileSize != fileSize {
                            // Jika tanggal modifikasi file baru lebih baru dan ukuran file berbeda
                            try FileManager.default.removeItem(atPath: lokBackupAdministrasi)
                            #if DEBUG
                                print("backup lama dihapus.")
                            #endif
                            // Salin file baru ke lokasi backup
                            try FileManager.default.copyItem(atPath: lokAdministrasi, toPath: lokBackupAdministrasi)
                            #if DEBUG
                                print("backup baru telah dibuat.")
                            #endif
                        } else {
                            #if DEBUG
                                print("Tidak ada modifikasi atau ukuran file sama.")
                            #endif
                        }
                    }
                }
            } else {
                // Jika file backup belum ada, langsung salin file baru
                try FileManager.default.copyItem(atPath: lokAdministrasi, toPath: lokBackupAdministrasi)
                #if DEBUG
                    print("backup baru telah disalin.")
                #endif
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus file backup database yang sudah lebih dari 7 bulan.
    ///
    /// Fungsi ini mencari semua file backup dengan awalan "data_backup_" dan akhiran ".sdi"
    /// di dalam folder "Data SDI" di direktori Documents. Jika tanggal file backup menunjukkan
    /// sudah lebih dari atau sama dengan 7 bulan dari tanggal saat ini, file tersebut akan dihapus.
    func deleteOldBackups() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy" // Format tanggal yang diinginkan

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDirectory = documentsDirectory.appendingPathComponent("Data SDI/")

        do {
            let backupFiles = try FileManager.default.contentsOfDirectory(atPath: backupDirectory.path)

            for file in backupFiles {
                if file.hasPrefix("data_backup_"), file.hasSuffix(".sdi") {
                    let fileDateStr = file.replacingOccurrences(of: "data_backup_", with: "").replacingOccurrences(of: ".sdi", with: "")

                    if let fileDate = dateFormatter.date(from: fileDateStr) {
                        let currentDate = Date()
                        let monthsApart = Calendar.current.dateComponents([.month], from: fileDate, to: currentDate).month ?? 0

                        if monthsApart >= 7 {
                            let filePath = backupDirectory.appendingPathComponent(file).path

                            do {
                                try FileManager.default.removeItem(atPath: filePath)

                            } catch {
                                #if DEBUG
                                    print(error.localizedDescription)
                                #endif
                            }
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// enum untuk bulan
    enum Month: Int {
        case januari = 1, februari, maret, april, mei, juni, juli, agustus, september, oktober, november, desember
    }

    /// Mengambil dan memproses data siswa dari database untuk menghasilkan statistik bulanan berdasarkan tahun.
    ///
    /// Fungsi ini secara asinkron mengambil data pendaftaran dan status berhenti siswa,
    /// kemudian mengelompokkannya berdasarkan tahun dan bulan. Untuk setiap bulan,
    /// akan dihitung jumlah siswa laki-laki dan perempuan yang aktif pada bulan tersebut.
    /// Data yang dihasilkan diformat ke dalam objek `MonthlyData` untuk ditampilkan di tabel.
    /// Proses ini memanfaatkan `TaskGroup` untuk konkurensi guna meningkatkan performa.
    ///
    /// - Returns: Sebuah array berisi objek `MonthlyData`, diurutkan berdasarkan tahun.
    ///            Setiap `MonthlyData` berisi statistik siswa laki-laki dan perempuan per bulan.
    ///            Akan mengembalikan array kosong jika terjadi kesalahan atau tidak ada data.
    func getDataForTableView() async -> [MonthlyData] {
        var resultData: [MonthlyData] = []

        do {
            // Ambil semua data siswa dari database secara asinkron
            let siswaArray: [Row] = try await pool.read { db in
                try Array(db.prepare(SiswaColumns.tabel.select(
                    SiswaColumns.tahundaftar,
                    SiswaColumns.tanggalberhenti,
                    SiswaColumns.jeniskelamin
                ).order(SiswaColumns.tahundaftar, SiswaColumns.tanggalberhenti)))
            }

            // Ambil tahun unik dari data siswa
            let uniqueYears: Set<Int> = Set(siswaArray.compactMap { [weak self] row in
                guard let self else { return nil }
                if let tanggalDaftar = try? row.get(SiswaColumns.tahundaftar),
                   let year = getYearFromDate(dateString: tanggalDaftar)
                {
                    return year
                }
                return nil
            })

            let sortedYears = uniqueYears.sorted()

            // Proses setiap tahun secara paralel menggunakan TaskGroup
            resultData = try await withThrowingTaskGroup(of: MonthlyData.self) { group in
                for year in sortedYears {
                    group.addTask { [weak self] in
                        guard let self else { return MonthlyData(year: year) }
                        var monthlyData = MonthlyData(year: year)

                        let monthlyResults = try await withThrowingTaskGroup(of: (Int, String).self) { monthGroup in
                            for month in 1 ... 12 {
                                monthGroup.addTask {
                                    let filteredSiswa = siswaArray.filter {
                                        guard let tanggalDaftar = try? $0.get(SiswaColumns.tahundaftar),
                                              let yearDaftar = self.getYearFromDate(dateString: tanggalDaftar),
                                              let monthDaftar = self.getMonthFromDate(dateString: tanggalDaftar)
                                        else {
                                            return false
                                        }

                                        if let tanggalBerhenti = try? $0.get(SiswaColumns.tanggalberhenti),
                                           let yearBerhenti = self.getYearFromDate(dateString: tanggalBerhenti),
                                           let monthBerhenti = self.getMonthFromDate(dateString: tanggalBerhenti)
                                        {
                                            let isActive = (yearDaftar < year || (yearDaftar == year && monthDaftar <= month)) &&
                                                (tanggalBerhenti.isEmpty || (year < yearBerhenti || (year == yearBerhenti && month <= monthBerhenti)))

                                            return isActive
                                        } else {
                                            return yearDaftar < year || (yearDaftar == year && monthDaftar <= month)
                                        }
                                    }

                                    let lakiLakiCount = filteredSiswa.filter {
                                        (try? $0.get(SiswaColumns.jeniskelamin)) == JenisKelamin.lakiLaki.rawValue
                                    }.count

                                    let perempuanCount = filteredSiswa.filter {
                                        (try? $0.get(SiswaColumns.jeniskelamin)) == JenisKelamin.perempuan.rawValue
                                    }.count

                                    let formatted = "L:\(lakiLakiCount) P:\(perempuanCount)"
                                    return (month, formatted)
                                }
                            }

                            var results: [(Int, String)] = []
                            for try await result in monthGroup {
                                results.append(result)
                            }
                            return results
                        }

                        for (month, formatted) in monthlyResults {
                            if let monthEnum = Month(rawValue: month) {
                                switch monthEnum {
                                case .januari: monthlyData.januari = formatted
                                case .februari: monthlyData.februari = formatted
                                case .maret: monthlyData.maret = formatted
                                case .april: monthlyData.april = formatted
                                case .mei: monthlyData.mei = formatted
                                case .juni: monthlyData.juni = formatted
                                case .juli: monthlyData.juli = formatted
                                case .agustus: monthlyData.agustus = formatted
                                case .september: monthlyData.september = formatted
                                case .oktober: monthlyData.oktober = formatted
                                case .november: monthlyData.november = formatted
                                case .desember: monthlyData.desember = formatted
                                }
                            }
                        }

                        return monthlyData
                    }
                }

                // Di sinilah kita kumpulkan hasilnya!
                var collected: [MonthlyData] = []
                for try await data in group {
                    collected.append(data)
                }
                return collected.sorted { $0.year < $1.year }
            }
        } catch {
            #if DEBUG
                print("Error in getDataForTableView: \(error)")
            #endif
        }
        return resultData
    }

    /// Mengambil tahun dari string tanggal yang diberikan.
    ///
    /// - Parameter dateString: String yang merepresentasikan tanggal (misalnya, "DD-MM-YYYY").
    /// - Returns: Nilai `Int` yang merepresentasikan tahun dari tanggal yang diberikan, atau `nil` jika string tanggal tidak valid.
    func getYearFromDate(dateString: String) -> Int? {
        if let date = dateFormatter.date(from: dateString) {
            let calendar = Calendar.current
            return calendar.component(.year, from: date)
        }
        return nil
    }

    /// Mengambil bulan dari string tanggal yang diberikan.
    ///
    /// - Parameter dateString: String yang merepresentasikan tanggal (misalnya, "DD-MM-YYYY").
    /// - Returns: Nilai `Int` yang merepresentasikan bulan dari tanggal yang diberikan (1 untuk Januari, 12 untuk Desember), atau `nil` jika string tanggal tidak valid.
    func getMonthFromDate(dateString: String) -> Int? {
        if let date = dateFormatter.date(from: dateString) {
            let calendar = Calendar.current
            return calendar.component(.month, from: date)
        }
        return nil
    }

    /// Properti privat yang menyediakan instance `DateFormatter` yang dikonfigurasi.
    ///
    /// Formatter ini disetel untuk mengubah string tanggal menjadi format "dd MMMM yyyy"
    /// (misalnya, "01 Januari 2023") dan sebaliknya. Ini digunakan untuk konsistensi
    /// dalam mengelola representasi tanggal dalam aplikasi.
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter
    }()

    /// Fungsi pembantu generik untuk menjalankan operasi insert dan menangani error.
    /// - Parameter insertStatement: Sebuah `Insert` statement dari SQLite.swift.
    /// - Returns: ID baris yang baru dimasukkan (Int64) atau `nil` jika gagal.
    func executeInsert(_ insertStatement: Insert) -> Int64? {
        do {
            return try db.run(insertStatement)
        } catch {
            #if DEBUG
                print("Database Insert Error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Mencatat saran ke dalam cache menggunakan `SuggestionCacheManager`.
    ///
    /// Fungsi ini mengiterasi kamus `data` yang diberikan. Untuk setiap pasangan kunci-nilai
    /// di mana nilai tidak kosong, ia akan menambahkan nilai yang sudah dikapitalisasi
    /// dan di-trim ke cache saran yang sesuai dengan `rawValue` dari kunci.
    /// Operasi penulisan ke cache dilakukan secara asinkron.
    ///
    /// - Parameter data: Sebuah kamus di mana kunci adalah tipe yang sesuai dengan `RawRepresentable`
    ///                   (dengan `RawValue` berupa `String`) dan nilai adalah `String` yang akan dicatat sebagai saran.
    func catatSuggestions<T: RawRepresentable>(data: [T: String]) where T.RawValue == String {
        for (key, value) in data where !value.isEmpty {
            Task {
                await SuggestionCacheManager.shared.appendToCache(
                    for: key.rawValue,
                    filter: value.capitalizedAndTrimmed(),
                    newSuggestions: [value.capitalizedAndTrimmed()]
                )
            }
        }
    }

    /// Membersihkan dan menormalisasi string opsional.
    ///
    /// Fungsi ini melakukan beberapa operasi pembersihan pada string masukan opsional:
    /// 1. Menghilangkan spasi di awal dan akhir string (`trimmingCharacters(in: .whitespacesAndNewlines)`).
    /// 2. Memecah string menjadi komponen-komponen berdasarkan spasi dan baris baru.
    /// 3. Memfilter komponen-komponen kosong, menghilangkan spasi berlebihan di antara kata-kata.
    /// 4. Menggabungkan kembali komponen-komponen dengan satu spasi di antaranya.
    /// Jika string masukan adalah `nil`, fungsi akan mengembalikan string kosong.
    ///
    /// - Parameter str: String opsional (`String?`) yang akan dibersihkan.
    /// - Returns: String yang sudah dibersihkan dan dinormalisasi (`String`).
    func cleanString(_ str: String?) -> String {
        str?.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ") ?? ""
    }

    /// Mengambil semua data yang relevan dari tabel siswa, guru, dan kelas untuk tujuan pelengkapan otomatis (autocompletion).
    ///
    /// Fungsi ini mengumpulkan berbagai informasi seperti nama siswa, alamat, nama orang tua, NIS/NISN,
    /// informasi kontak, tanggal lahir, nama guru, mata pelajaran, jabatan, dan semester.
    /// Ini memproses data dari tabel `siswa`, `guru`, dan semua tabel `kelas` (dari `kelas1` hingga `kelas6`).
    /// Untuk menghindari duplikasi nama guru, sebuah `Set` digunakan untuk menyimpan nama guru unik.
    /// Setiap nilai string dibersihkan menggunakan fungsi `cleanString` untuk menormalisasi data.
    ///
    /// - Returns: Sebuah array berisi objek `AutoCompletion` yang digabungkan dari semua data yang relevan,
    ///            disiapkan untuk fungsionalitas pelengkapan otomatis.
    func getAllDataForAutoCompletion() async -> [AutoCompletion] {
        var allResults: [AutoCompletion] = []
        do {
            allResults = try await withThrowingTaskGroup(of: [AutoCompletion].self) { [weak self] group in
                guard let self else { return [] }

                group.addTask {
                    try await self.pool.read { [weak self] db in
                        guard let self else { return [] }
                        var result: [AutoCompletion] = []
                        for user in try db.prepare(SiswaColumns.tabel) {
                            var item = AutoCompletion()
                            item.namasiswa = StringInterner.shared.intern(cleanString(user[SiswaColumns.nama]))
                            item.alamat = cleanString(user[SiswaColumns.alamat])
                            item.ayah = cleanString(user[SiswaColumns.ayah])
                            item.ibu = cleanString(user[SiswaColumns.ibu])
                            item.wali = cleanString(user[SiswaColumns.namawali])
                            item.nis = cleanString(user[SiswaColumns.nis])
                            item.nisn = cleanString(user[SiswaColumns.nisn])
                            item.tlv = cleanString(user[SiswaColumns.tlv])
                            item.tanggallahir = cleanString(user[SiswaColumns.ttl])
                            result.append(item)
                        }
                        return result
                    }
                }

                // 2️⃣ Ambil data guru (pakai Set filter)
                group.addTask {
                    try await self.pool.read { [weak self] db in
                        guard let self else { return [] }

                        var result: [AutoCompletion] = []
                        var localGuruSet = Set<String>()
                        for user in try db.prepare(GuruColumns.tabel) {
                            let namaGuru = cleanString(user[GuruColumns.nama])
                            guard !localGuruSet.contains(namaGuru) else { continue }
                            localGuruSet.insert(namaGuru)

                            var item = AutoCompletion()
                            item.namaguru = StringInterner.shared.intern(namaGuru)
                            item.alamat = cleanString(user[GuruColumns.alamat])
                            result.append(item)
                        }
                        return result
                    }
                }

                // 3️⃣ Ambil data mapel
                group.addTask {
                    try await self.pool.read { [weak self] db in
                        guard let self else { return [] }
                        var result: [AutoCompletion] = []
                        for row in try db.prepare(MapelColumns.tabel) {
                            var item = AutoCompletion()
                            item.mapel = StringInterner.shared.intern(cleanString(row[MapelColumns.nama]))
                            result.append(item)
                        }
                        return result
                    }
                }

                // 4️⃣ Ambil data struktur/jabatan
                group.addTask {
                    try await self.pool.read { [weak self] db in
                        guard let self else { return [] }
                        var result: [AutoCompletion] = []
                        for row in try db.prepare(JabatanColumns.tabel) {
                            var item = AutoCompletion()
                            item.jabatan = StringInterner.shared.intern(cleanString(row[JabatanColumns.nama]))
                            result.append(item)
                        }
                        return result
                    }
                }

                // 5️⃣ Ambil data semester (distinct)
                group.addTask {
                    try await self.pool.read { [weak self] db in
                        guard let self else { return [] }
                        var result: [AutoCompletion] = []
                        var semesterSet = Set<String>()
                        for row in try db.prepare(KelasColumns.tabel) {
                            let semester = cleanString(row[KelasColumns.semester])
                            guard !semesterSet.contains(semester) else { continue }
                            semesterSet.insert(semester)

                            var item = AutoCompletion()
                            item.semester = semester
                            result.append(item)
                        }
                        return result
                    }
                }

                // 🔁 Kumpulkan semua task hasilnya
                for try await partialResult in group {
                    allResults.append(contentsOf: partialResult)
                }
                return allResults
            }
        } catch {
            print(error)
        }

        return allResults
    }

    /// Melangsingkan ukuran file database.
    func vacuumDatabase() {
        do {
            try db.vacuum()
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Asynchronous core upsert-get-ID
    /// Fungsi core: versi async manual (tanpa GRDB)
    func upsertGetIDAsync(
        suggestions: [KelasColumn: String]? = nil,
        checkInsert: @escaping (_ db: Connection) throws -> Int64?
    ) async -> Int64? {
        // catat suggestions jika ada
        if let data = suggestions {
            catatSuggestions(data: data)
        }
        do {
            // pool.read sudah async dan me‐throw, jadi langsung await
            return try await pool.read { db in
                try checkInsert(db)
            }
        } catch {
            #if DEBUG
                print("upsertGetIDAsync error:", error.localizedDescription)
            #endif
            return nil
        }
    }
}

extension Connection {
    /// Mengambil detail kolom untuk tabel database yang ditentukan.
    ///
    /// Fungsi ini menggunakan `SchemaReader` untuk mendapatkan definisi skema
    /// dari setiap kolom dalam tabel yang diberikan. Ini mengembalikan array tuple yang berisi
    /// nama kolom, tipe afinitas (misalnya, "TEXT", "INTEGER"), properti `notNull`,
    /// dan informasi `primaryKey` jika ada.
    ///
    /// - Parameter tableName: Nama tabel (`String`) yang detail kolomnya ingin diambil.
    /// - Throws: `Error` jika ada masalah saat mengakses skema database.
    /// - Returns: Sebuah array tuple, di mana setiap tuple merepresentasikan detail kolom
    ///            (nama, tipe, nullable, dan informasi primary key).
    func getColumnDetails(in tableName: String) throws -> [(name: String, type: ColumnDefinition.Affinity, notNull: Bool, primaryKey: ColumnDefinition.PrimaryKey?)] {
        var columnDetails: [(name: String, type: ColumnDefinition.Affinity, notNull: Bool, primaryKey: ColumnDefinition.PrimaryKey?)] = []

        // Gunakan SchemaReader untuk mendapatkan informasi kolom
        let columnsSchema = try schema.columnDefinitions(table: tableName)

        for column in columnsSchema {
            // Tentukan apakah kolom adalah primary key
            // Properti `primaryKey` pada `Schema.Column` adalah enum `Schema.PrimaryKey`.

            // Properti `type` pada `Schema.Column` adalah tipe afinitas atau tipe yang dideklarasikan.
            // Ini sudah sesuai dengan apa yang Anda dapatkan dari PRAGMA table_info (kolom 'type').

            columnDetails.append((
                name: column.name,
                type: column.type, // Ini adalah tipe data yang dideklarasikan (e.g., "TEXT", "INTEGER")
                notNull: column.nullable,
                primaryKey: column.primaryKey
            ))
        }

        return columnDetails
    }
}
