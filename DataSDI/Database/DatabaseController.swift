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

/// DatabaseController adalah class yang menyimpan seluruh fungsi CRUD database dan memiliki satu koneksi database.
///
/// Koneksi database di DBController menggunakan `read-write connection`.
/// Koneksi ini bisa digunakan untuk memperbarui nilai di Database. Berbeda dengan ``DatabaseManager``
/// yang koneksinya husus untuk pembacaan nilai di database saja.
class DatabaseController {
    // MARK: - Properti Notifikasi

    /// Antrean `DispatchQueue` khusus untuk memposting notifikasi terkait pemuatan ulang data.
    let notifQueue = DispatchQueue(label: "sdi.Data.reloadSavedData", qos: .userInitiated)

    /// Nama notifikasi yang diposting ketika data *database* umum telah berubah.
    static let dataDidChangeNotification = NSNotification.Name("DB_ControllerDataDidChange")

    /// Nama notifikasi yang diposting ketika data telah dimuat ulang dari *database*.
    static let dataDidReloadNotification = NSNotification.Name("DB_ControllerDataDidReload")

    /// Nama notifikasi yang diposting ketika data siswa telah berubah.
    static let siswaDidChangeNotification = NSNotification.Name("DB_ControllerSiswaDidChange")

    /// Nama notifikasi yang diposting ketika data guru telah berubah.
    static let guruDidChangeNotification = NSNotification.Name("DB_ControllerGuruDidChange")

    /// Nama notifikasi yang diposting ketika nama guru diperbarui.
    static let namaGuruUpdate = NSNotification.Name("namaGuruUpdate")

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

    /// Instans **singleton** dari `DB_Controller`, memastikan hanya ada satu instans di seluruh aplikasi.
    static let shared = DatabaseController()

    /// *Connection pool* untuk akses *database* *read-only* yang efisien, diperoleh dari `DatabaseManager.shared`.
    let pool = DatabaseManager.shared

    // MARK: - Definisi Tabel dan Kolom

    // Definisi tabel Inventaris (kolom diatur di file DynamicTable)
    /// Representasi objek tabel `main_table` di *database*. Kolom-kolomnya diatur secara dinamis.
    private let mainTable = Table("main_table")

    // Definisi kolom tabel siswa
    /// Representasi objek tabel `siswa` di *database*.
    private let siswa = Table("siswa")
    /// Kolom 'id' pada tabel `siswa`.
    private let id = Expression<Int64>("id")
    /// Kolom 'Nama' pada tabel `siswa`.
    private let nama = Expression<String>("Nama")
    /// Kolom 'Alamat' pada tabel `siswa`.
    private let alamat = Expression<String>("Alamat")
    /// Kolom 'T.T.L.' (Tanggal, Tempat Lahir) pada tabel `siswa`.
    private let ttl = Expression<String>("T.T.L.")
    /// Kolom 'Tahun Daftar' pada tabel `siswa`.
    private let tahundaftar = Expression<String>("Tahun Daftar")
    /// Kolom 'Nama Wali' pada tabel `siswa`.
    private let namawali = Expression<String>("Nama Wali")
    /// Kolom 'NIS' (Nomor Induk Siswa) pada tabel `siswa`.
    private let nis = Expression<String>("NIS")
    /// Kolom 'Status' pada tabel `siswa`.
    private let status = Expression<String>("Status")
    /// Kolom 'Tgl. Lulus' pada tabel `siswa`, merepresentasikan tanggal berhenti/lulus.
    private let tanggalberhenti = Expression<String>("Tgl. Lulus")
    /// Kolom 'Jenis Kelamin' pada tabel `siswa`.
    private let jeniskelamin = Expression<String>("Jenis Kelamin")
    /// Kolom 'NISN' (Nomor Induk Siswa Nasional) pada tabel `siswa`.
    private let nisn = Expression<String>("NISN")
    /// Kolom 'Kelas Aktif' pada tabel `siswa`.
    private let kelasSekarang = Expression<String>("Kelas Aktif")
    /// Kolom 'Ayah' pada tabel `siswa`.
    private let ayah = Expression<String>("Ayah")
    /// Kolom 'Ibu' pada tabel `siswa`.
    private let ibu = Expression<String>("Ibu")
    /// Kolom 'Nomor Telepon' pada tabel `siswa`.
    private let tlv = Expression<String>("Nomor Telepon")
    /// Kolom 'foto' pada tabel `siswa`, menyimpan data gambar.
    private let foto = Expression<Data>("foto")

    // Definisi kolom tabel guru
    /// Representasi objek tabel `guru` di *database*.
    private let guru = Table("guru")
    /// Kolom 'id' pada tabel `guru`.
    private let idGuru = Expression<Int64>("id")
    /// Kolom 'Nama' pada tabel `guru`.
    private let namaGuru = Expression<String>("Nama")
    /// Kolom 'Alamat' pada tabel `guru`.
    private let alamatGuru = Expression<String>("Alamat")
    /// Kolom 'Tahun Aktif' pada tabel `guru`.
    private let tahunaktif = Expression<String>("Tahun Aktif")
    /// Kolom 'Mata Pelajaran' pada tabel `guru` (juga digunakan di tabel kelas).
    private let mapel = Expression<String>("Mata Pelajaran")
    /// Kolom 'Jabatan' pada tabel `guru`, merepresentasikan posisi struktural.
    private let struktural = Expression<String>("Jabatan")

    // Definisi kolom tabel kelas
    /// Representasi objek tabel `kelas1` di *database*.
    let kelas1 = Table("kelas1")
    /// Representasi objek tabel `kelas2` di *database*.
    let kelas2 = Table("kelas2")
    /// Representasi objek tabel `kelas3` di *database*.
    let kelas3 = Table("kelas3")
    /// Representasi objek tabel `kelas4` di *database*.
    let kelas4 = Table("kelas4")
    /// Representasi objek tabel `kelas5` di *database*.
    let kelas5 = Table("kelas5")
    /// Representasi objek tabel `kelas6` di *database*.
    let kelas6 = Table("kelas6")
    /// Kolom 'kelasId' pada tabel kelas.
    private let kelasId = Expression<Int64>("kelasId")
    /// Kolom 'siswa_id' pada tabel kelas, sebagai referensi ke ID siswa.
    private let siswa_id = Expression<Int64>("siswa_id")
    /// Kolom 'Nilai' pada tabel kelas.
    private let nilai = Expression<Int64?>("Nilai")
    /// Kolom 'Nama Guru' pada tabel kelas.
    private let namaguru = Expression<String>("Nama Guru")
    /// Kolom 'Nama Siswa' pada tabel kelas.
    private let namasiswa = Expression<String?>("Nama Siswa")
    /// Kolom 'Tanggal' pada tabel kelas.
    private let tanggal = Expression<String>("Tanggal")
    /// Kolom 'Semester' pada tabel kelas.
    private let semester = Expression<String>("Semester")

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

            #if DEBUG
                print("✅ WAL checkpoint.")
            #endif

            let walPath = dbPath! + "-wal"
            let shmPath = dbPath! + "-shm"

            try FileManager.default.removeItem(atPath: walPath)
            try FileManager.default.removeItem(atPath: shmPath)
        } catch {
            #if DEBUG
                print("❌ WAL checkpoint: \(error)")
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
            print("❌: \(error.localizedDescription)")
        }
    }

    /// Metode untuk inisialisasi ulang
    public func reloadDatabase(withNewPath newPath: String) {
        dbPath = newPath
        setupConnection()
    }

    /// Membuat koneksi SQLite ke File SQLite3
    private func setupConnection() {
        guard let dbPath else { return }
        do {
            db = try Connection(dbPath)
            try db.run("PRAGMA journal_mode=WAL;")
            siapkanTabel()
            buatTabel()
            let walPath = dbPath + "-wal"
            let shmPath = dbPath + "-shm"
            excludeFileFromBackup(walPath)
            excludeFileFromBackup(shmPath)
        } catch {
            print("Error initializing database: \(error.localizedDescription)")
        }
    }

    /// Menyiapkan tabel SQLite3 dan membuat indeks tabel untuk digunakan Aplikasi.
    func siapkanTabel() {
        do {
            // Check dan buat tabel jika belum ada
            buatTabel()

            // Buat indeks untuk kolom nama di tabel siswa dan guru
            try db.run(siswa.createIndex(nama, alamat, nis, nisn, jeniskelamin, status, kelasSekarang, tahundaftar, tanggalberhenti, ifNotExists: true))
            try db.run(guru.createIndex(namaGuru, alamatGuru, mapel, ifNotExists: true))
            try db.run(kelas1.createIndex(namasiswa, mapel, ifNotExists: true))
            try db.run(kelas2.createIndex(namasiswa, mapel, ifNotExists: true))
            try db.run(kelas3.createIndex(namasiswa, mapel, ifNotExists: true))
            try db.run(kelas4.createIndex(namasiswa, mapel, ifNotExists: true))
            try db.run(kelas5.createIndex(namasiswa, mapel, ifNotExists: true))
            try db.run(kelas6.createIndex(namasiswa, mapel, ifNotExists: true))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
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
        let tablesToCreate = ["siswa", "guru", "kelas1", "kelas2", "kelas3", "kelas4", "kelas5", "kelas6", "main_table"]
        for tableName in tablesToCreate {
            if !isTableExists(tableName) {
                do {
                    switch tableName {
                    case "siswa":
                        try db.run(siswa.create { t in
                            t.column(id, primaryKey: true)
                            t.column(nama)
                            t.column(alamat)
                            t.column(ttl)
                            t.column(tahundaftar)
                            t.column(namawali)
                            t.column(nis)
                            t.column(nisn)
                            t.column(ayah)
                            t.column(ibu)
                            t.column(jeniskelamin)
                            t.column(status)
                            t.column(tanggalberhenti)
                            t.column(kelasSekarang)
                            t.column(tlv)
                            t.column(foto)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            let image = NSImage(named: "image")
                            let imageData = image?.compressImage(quality: 0.01)
                            try db.run(siswa.insert(nama <- "Siswa 1", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 1", ttl <- "Pasuruan, 01-01-2008", tahundaftar <- "03 Maret 2021", namawali <- "Wali 1", nis <- "12345", nisn <- "54321", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Laki-laki", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 1", tlv <- "085234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 2", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 2", ttl <- "Jeddah, 02-02-2009", tahundaftar <- "03 Mei 2017", namawali <- "Wali 2", nis <- "67890", nisn <- "98765", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Perempuan", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 2", tlv <- "082234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 3", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 3", ttl <- "Madinah, 01-01-2008", tahundaftar <- "03 Maret 2021", namawali <- "Wali 3", nis <- "12345", nisn <- "54321", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Laki-laki", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 3", tlv <- "085234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 4", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 4", ttl <- "Mekkah, 02-02-2009", tahundaftar <- "03 Mei 2017", namawali <- "Wali 4", nis <- "67890", nisn <- "98765", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Perempuan", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 4", tlv <- "082234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 5", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 5", ttl <- "Yogyakarta, 01-01-2008", tahundaftar <- "03 Maret 2021", namawali <- "Wali 5", nis <- "12345", nisn <- "54321", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Laki-laki", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 5", tlv <- "085234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 6", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 6", ttl <- "Surabaya, 02-02-2009", tahundaftar <- "03 Mei 2017", namawali <- "Wali 6", nis <- "67890", nisn <- "98765", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Perempuan", status <- "Aktif", tanggalberhenti <- "", kelasSekarang <- "Kelas 6", tlv <- "082234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa 7", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 1", ttl <- "Malang, 03-03-2010", tahundaftar <- "20 Oktober 2015", namawali <- "Wali 3", nis <- "11223", nisn <- "33221", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Laki-laki", status <- "Berhenti", tanggalberhenti <- "08 November 2021", kelasSekarang <- "Kelas 6", tlv <- "081234567890", foto <- imageData ?? Data()))
                            try db.run(siswa.insert(nama <- "Siswa Lulus", alamat <- "Drag & Drop ke/dari kolom \"Nama Siswa\" untuk insert/ekspor foto siswa 8", ttl <- "Gondang Wetan, 03-03-2010", tahundaftar <- "20 Oktober 2015", namawali <- "Wali 3", nis <- "11223", nisn <- "33221", ayah <- "Nama Ayah", ibu <- "Nama Ibu", jeniskelamin <- "Laki-laki", status <- "Lulus", tanggalberhenti <- "08 November 2022", kelasSekarang <- "Lulus", tlv <- "081234567890", foto <- imageData ?? Data()))
                        }
                    case "guru":
                        try db.run(guru.create { t in
                            t.column(idGuru, primaryKey: true)
                            t.column(namaGuru)
                            t.column(alamatGuru)
                            t.column(tahunaktif)
                            t.column(mapel)
                            t.column(struktural)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(guru.insert(namaGuru <- "Guru 1", alamatGuru <- "Alamat Guru 1", tahunaktif <- "2010", mapel <- "Al-Qur'an", struktural <- "Kepala Sekolah"))
                            try db.run(guru.insert(namaGuru <- "Guru 2", alamatGuru <- "Alamat Guru 2", tahunaktif <- "2011", mapel <- "Bahasa Arab", struktural <- "Wakil Kepala Sekolah"))
                            try db.run(guru.insert(namaGuru <- "Guru 3", alamatGuru <- "Alamat Guru 3", tahunaktif <- "2012", mapel <- "Bahasa Indonesia", struktural <- "Sekretaris"))
                        }
                    // tambahkan kasus untuk setiap tabel lainnya
                    case "kelas1":
                        try db.run(kelas1.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas1.insert(Expression<Int64>("siswa_id") <- 1, namasiswa <- "Siswa 1", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas1.insert(Expression<Int64>("siswa_id") <- 1, namasiswa <- "Siswa 1", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas1.insert(Expression<Int64>("siswa_id") <- 1, namasiswa <- "Siswa 1", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "kelas2":
                        try db.run(kelas2.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas2.insert(Expression<Int64>("siswa_id") <- 2, namasiswa <- "Siswa 2", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas2.insert(Expression<Int64>("siswa_id") <- 2, namasiswa <- "Siswa 2", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas2.insert(Expression<Int64>("siswa_id") <- 2, namasiswa <- "Siswa 2", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "kelas3":
                        try db.run(kelas3.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas3.insert(Expression<Int64>("siswa_id") <- 3, namasiswa <- "Siswa 3", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas3.insert(Expression<Int64>("siswa_id") <- 3, namasiswa <- "Siswa 3", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas3.insert(Expression<Int64>("siswa_id") <- 3, namasiswa <- "Siswa 3", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "kelas4":
                        try db.run(kelas4.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas4.insert(Expression<Int64>("siswa_id") <- 4, namasiswa <- "Siswa 4", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas4.insert(Expression<Int64>("siswa_id") <- 4, namasiswa <- "Siswa 4", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas4.insert(Expression<Int64>("siswa_id") <- 4, namasiswa <- "Siswa 4", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "kelas5":
                        try db.run(kelas5.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas5.insert(Expression<Int64>("siswa_id") <- 5, namasiswa <- "Siswa 5", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas5.insert(Expression<Int64>("siswa_id") <- 5, namasiswa <- "Siswa 5", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas5.insert(Expression<Int64>("siswa_id") <- 5, namasiswa <- "Siswa 5", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "kelas6":
                        try db.run(kelas6.create { t in
                            t.column(kelasId, primaryKey: true)
                            t.column(Expression<Int64>("siswa_id"))
                            t.column(namasiswa, defaultValue: nil)
                            t.column(mapel)
                            t.column(namaguru)
                            t.column(nilai, defaultValue: nil)
                            t.column(semester)
                            t.column(tanggal)
                        })
                        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
                            try db.run(kelas6.insert(Expression<Int64>("siswa_id") <- 6, namasiswa <- "Siswa 6", mapel <- "Al-Qur'an", namaguru <- "Guru 1", nilai <- 85, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas6.insert(Expression<Int64>("siswa_id") <- 6, namasiswa <- "Siswa 6", mapel <- "Bahasa Arab", namaguru <- "Guru 2", nilai <- 90, semester <- "1", tanggal <- "02 Februari 2023"))
                            try db.run(kelas6.insert(Expression<Int64>("siswa_id") <- 6, namasiswa <- "Siswa 6", mapel <- "Bahasa Indonesia", namaguru <- "Guru 3", nilai <- 95, semester <- "1", tanggal <- "02 Februari 2023"))
                        }
                    case "main_table":
                        try db.run(mainTable.create { t in
                            t.column(Expression<Int64>("id"), primaryKey: true)
                            t.column(Expression<String?>("Nama Barang"))
                            t.column(Expression<String?>("Lokasi"))
                            t.column(Expression<String?>("Kondisi"))
                            t.column(Expression<String?>("Tanggal Dibuat"))
                            t.column(Expression<Data?>("Foto"))
                            // Tambahkan kolom lainnya di sini jika diperlukan
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
                } catch {
                    print(error.localizedDescription)
                }
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

    /// Menambahkan data guru ke dalam database jika data tersebut belum ada sebelumnya.
    ///
    /// Fungsi ini akan memeriksa apakah guru dengan kombinasi `namaGuru`, `mapel`, dan `tahunaktif` sudah ada
    /// di dalam tabel `guru`. Jika belum ada, maka data guru akan dimasukkan ke database, dan juga
    /// kata-kata unik dari masing-masing field (nama, alamat, tahun aktif, mapel, dan struktur) akan disimpan
    /// dalam himpunan kata pada `ReusableFunc` untuk keperluan lain seperti autocomplete atau pencarian.
    ///
    /// - Parameters:
    ///   - namaGuruValue: Nama lengkap guru.
    ///   - alamatGuruValue: Alamat tempat tinggal guru.
    ///   - tahunaktifValue: Tahun aktif atau tahun pengangkatan guru.
    ///   - mapelValue: Mata pelajaran yang diajarkan oleh guru.
    ///   - struktur: Jabatan atau struktur organisasi guru dalam sekolah.
    public func addGuru(namaGuruValue: String, alamatGuruValue: String, tahunaktifValue: String, mapelValue: String, struktur: String) {
        do {
            let query = guru.filter(namaGuru == namaGuruValue && mapel == mapelValue && tahunaktif == tahunaktifValue)
            let existingGuru = try db.pluck(query)
            if existingGuru == nil {
                try db.run(guru.insert(
                    namaGuru <- namaGuruValue,
                    alamatGuru <- alamatGuruValue,
                    tahunaktif <- tahunaktifValue,
                    mapel <- mapelValue,
                    struktural <- struktur
                ))
                var namaWords: Set<String> = []
                var alamatWords: Set<String> = []
                var tahunWords: Set<String> = []
                var mapelWords: Set<String> = []
                var strukturWords: Set<String> = []
                namaWords.formUnion(namaGuruValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaWords.insert(namaGuruValue.capitalizedAndTrimmed())
                alamatWords.formUnion(alamatGuruValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                alamatWords.insert(alamatGuruValue.capitalizedAndTrimmed())
                tahunWords.formUnion(tahunaktifValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                tahunWords.insert(tahunaktifValue.capitalizedAndTrimmed())
                mapelWords.formUnion(mapelValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                mapelWords.insert(mapelValue.capitalizedAndTrimmed())
                strukturWords.formUnion(struktur.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                strukturWords.insert(struktur.capitalizedAndTrimmed())

                ReusableFunc.namaguru.formUnion(namaWords)
                ReusableFunc.alamat.formUnion(alamatWords)
                ReusableFunc.ttl.formUnion(tahunWords)
                ReusableFunc.mapel.formUnion(mapelWords)
                ReusableFunc.jabatan.formUnion(strukturWords)

            } else {}
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Seperti ``addGuru(namaGuruValue:alamatGuruValue:tahunaktifValue:mapelValue:struktur:)`` dengan tambahan mendapatkan ID unik untuk guru yang baru saja ditambahkan.
    /// - Returns: ID unik guru yang ditambahkan.
    public func addGuruID(namaGuruValue: String, alamatGuruValue: String, tahunaktifValue: String, mapelValue: String, struktur: String) -> Int64? {
        do {
            var ID: Int64?
            let query = guru.filter(namaGuru == namaGuruValue && mapel == mapelValue)
            let existingGuru = try db.pluck(query)
            if existingGuru == nil {
                try db.transaction {
                    let insert = guru.insert(
                        namaGuru <- namaGuruValue,
                        alamatGuru <- alamatGuruValue,
                        tahunaktif <- tahunaktifValue,
                        mapel <- mapelValue,
                        struktural <- struktur
                    )
                    try db.run(insert)
                    ID = try db.scalar(guru.select(Expression<Int64>("rowid").max))
                }
                var namaWords: Set<String> = []
                var alamatWords: Set<String> = []
                var tahunWords: Set<String> = []
                var mapelWords: Set<String> = []
                var strukturWords: Set<String> = []
                namaWords.formUnion(namaGuruValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaWords.insert(namaGuruValue.capitalizedAndTrimmed())
                alamatWords.formUnion(alamatGuruValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                alamatWords.insert(alamatGuruValue.capitalizedAndTrimmed())
                tahunWords.formUnion(tahunaktifValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                tahunWords.insert(tahunaktifValue.capitalizedAndTrimmed())
                mapelWords.formUnion(mapelValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                mapelWords.insert(mapelValue.capitalizedAndTrimmed())
                strukturWords.formUnion(struktur.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                strukturWords.insert(struktur.capitalizedAndTrimmed())
                ReusableFunc.namaguru.formUnion(namaWords)
                ReusableFunc.alamat.formUnion(alamatWords)
                ReusableFunc.ttl.formUnion(tahunWords)
                ReusableFunc.mapel.formUnion(mapelWords)
                ReusableFunc.jabatan.formUnion(strukturWords)
                return ID
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Menambahkan entri guru baru ke dalam database dengan nama guru tertentu jika belum ada sebelumnya.
    ///
    /// Fungsi ini memeriksa apakah nama guru sudah ada di tabel `guru`. Jika belum ada, maka akan dilakukan
    /// penyisipan entri baru dengan `alamatGuru`, `tahunaktif`, `mapel`, dan `struktural` yang masih kosong.
    ///
    /// - Parameter namaGuruValue: Nama guru yang ingin ditambahkan.
    public func addGuruMapel(namaGuruValue: String) {
        do {
            // Cek apakah nama guru sudah ada di database
            let query = guru.filter(namaGuru == namaGuruValue)
            let existingGuru = try db.pluck(query)

            // Jika `existingGuru` nil, maka nama guru belum ada, dan proses insert dapat dilakukan
            if existingGuru == nil {
                // Insert data guru baru
                try db.run(guru.insert(namaGuru <- namaGuruValue, alamatGuru <- "", tahunaktif <- "", mapel <- "", struktural <- ""))

            } else {
                return
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Mencatat data siswa baru ke dalam database beserta informasi lengkapnya.
    ///
    /// Fungsi ini akan menyimpan data lengkap siswa ke dalam tabel `siswa` menggunakan transaksi database.
    /// Setelah penyimpanan berhasil, fungsi juga mencatat kumpulan kata unik dari berbagai field untuk
    /// keperluan seperti pencarian atau pelengkapan otomatis. Data juga dikirim ke fungsi `catatSuggestions`
    /// untuk dicatat sebagai saran pengisian di masa mendatang.
    ///
    /// - Parameters:
    ///   - namaValue: Nama lengkap siswa.
    ///   - alamatValue: Alamat tempat tinggal siswa.
    ///   - ttlValue: Tempat dan tanggal lahir siswa.
    ///   - tahundaftarValue: Tahun pendaftaran siswa.
    ///   - namawaliValue: Nama wali siswa.
    ///   - nisValue: Nomor Induk Siswa.
    ///   - nisnValue: Nomor Induk Siswa Nasional.
    ///   - namaAyah: Nama ayah siswa.
    ///   - namaIbu: Nama ibu siswa.
    ///   - jeniskelaminValue: Jenis kelamin siswa.
    ///   - statusValue: Status siswa (aktif/lulus/berhenti).
    ///   - tanggalberhentiValue: Tanggal berhenti jika siswa sudah keluar.
    ///   - kelasAktif: Kelas aktif saat ini.
    ///   - noTlv: Nomor telepon siswa atau wali.
    ///   - fotoPath: Data foto siswa dalam format `Data`.
    public func catatSiswa(namaValue: String, alamatValue: String, ttlValue: String, tahundaftarValue: String, namawaliValue: String, nisValue: String, nisnValue: String, namaAyah: String, namaIbu: String, jeniskelaminValue: String, statusValue: String, tanggalberhentiValue: String, kelasAktif: String, noTlv: String, fotoPath: Data) {
        do {
            try db.transaction {
                try db.run(siswa.insert(
                    nama <- namaValue,
                    alamat <- alamatValue,
                    ttl <- ttlValue,
                    tahundaftar <- tahundaftarValue,
                    namawali <- namawaliValue,
                    nis <- nisValue,
                    nisn <- nisnValue,
                    ayah <- namaAyah,
                    ibu <- namaIbu,
                    jeniskelamin <- jeniskelaminValue,
                    status <- statusValue,
                    tanggalberhenti <- tanggalberhentiValue,
                    kelasSekarang <- kelasAktif,
                    tlv <- noTlv,
                    foto <- fotoPath
                ))

                var namaWords: Set<String> = []
                var alamatWords: Set<String> = []
                var ttlWords: Set<String> = []
                var namaWaliWords: Set<String> = []
                var nisWords: Set<String> = []
                var nisnWords: Set<String> = []
                var tlvWords: Set<String> = []
                var ayah: Set<String> = []
                var ibu: Set<String> = []
                namaWords.formUnion(namaValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaWords.insert(namaValue.capitalizedAndTrimmed())
                alamatWords.formUnion(alamatValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                alamatWords.insert(alamatValue.capitalizedAndTrimmed())
                ttlWords.formUnion(ttlValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                ttlWords.insert(ttlValue.capitalizedAndTrimmed())
                nisWords.formUnion(nisValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                nisWords.insert(nisValue.capitalizedAndTrimmed())
                namaWaliWords.formUnion(ttlValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaWaliWords.insert(ttlValue.capitalizedAndTrimmed())
                nisnWords.formUnion(nisValue.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                nisnWords.insert(nisValue.capitalizedAndTrimmed())
                tlvWords.formUnion(noTlv.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                tlvWords.insert(noTlv.capitalizedAndTrimmed())
                ayah.formUnion(namaAyah.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                ayah.insert(namaAyah.capitalizedAndTrimmed())
                ibu.formUnion(namaIbu.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                ibu.insert(namaIbu.capitalizedAndTrimmed())
                ReusableFunc.namasiswa.formUnion(namaWords)
                ReusableFunc.alamat.formUnion(alamatWords)
                ReusableFunc.namaAyah.formUnion(ayah)
                ReusableFunc.namaIbu.formUnion(ibu)
                ReusableFunc.namawali.formUnion(namaWaliWords)
                ReusableFunc.ttl.formUnion(ttlWords)
                ReusableFunc.nis.formUnion(nisWords)
                ReusableFunc.nisn.formUnion(nisnWords)
                ReusableFunc.tlvString.formUnion(tlvWords)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        let data: [SiswaColumn: String] = [
            .nama: namaValue,
            .alamat: alamatValue,
            .ttl: ttlValue,
            .namawali: namawaliValue,
            .nis: nisValue,
            .nisn: nisnValue,
            .ayah: namaAyah,
            .ibu: namaIbu,
            .tlv: noTlv,
        ]
        catatSuggestions(data: data)
    }

    #if DEBUG
        private let poi = OSLog(subsystem: "Test", category: .pointsOfInterest)
        nonisolated func threadedProcess(_ message: StaticString, _ this: Int) {
            let id = OSSignpostID(log: poi)
            os_signpost(.begin, log: poi, name: #function, signpostID: id, message)

            os_signpost(.end, log: poi, name: #function, signpostID: id)
        }
    #endif

    /// Fungsi untuk mengambil daftar siswa dari database SQLite secara asinkron.
    ///
    /// - Parameter group: Nilai opsional untuk menentukan filter berdasarkan status kelulusan.
    ///   - Jika `false`, siswa dengan status "Lulus" akan dikecualikan kecuali jika pengaturan `tampilkanSiswaLulus` aktif.
    ///   - Jika `true` atau `nil`, tidak ada filter tambahan terkait status kelulusan.
    ///
    /// - Returns: Array `[ModelSiswa]` yang telah difilter sesuai dengan kondisi tertentu.
    ///
    /// ## Logika Utama:
    /// - **Menyiapkan Query Dasar**: Menggunakan tabel `siswa` untuk mengambil data siswa.
    /// - **Menerapkan Filter**:
    ///   - Mengecualikan siswa dengan status `"Lulus"`, kecuali jika `tampilkanSiswaLulus` aktif.
    ///   - Mengecualikan siswa dengan status `"Berhenti"` jika `sembunyikanSiswaBerhenti` aktif.
    /// - **Mengumpulkan ID Siswa yang Dihapus**:
    ///   - Menggabungkan ID dari `deletedStudentIDs`, `deletedSiswaArray`, `deletedSiswasArray`, dan `redoPastedSiswaArray`.
    /// - **Menghapus Siswa yang Dihapus dari Query**:
    ///   - Mengecualikan siswa dengan `id` yang ada dalam daftar `deletedIDs`.
    ///   - *Catatan*: SQLite tidak mendukung `contains` langsung dalam query, sehingga filtering mungkin kurang efisien untuk dataset besar.
    /// - **Mengambil ID Siswa yang Sesuai**:
    ///   - Mengeksekusi query untuk mendapatkan daftar `id` siswa yang memenuhi kriteria.
    /// - **Menggunakan `TaskGroup` untuk Fetching Paralel**:
    ///   - Menjalankan pengambilan data siswa secara paralel untuk meningkatkan performa.
    /// - **Mengembalikan Data Siswa**:
    ///   - Jika terjadi error, akan ditangkap dalam blok `catch`.
    ///   - Mengembalikan daftar siswa yang sesuai dengan filter.
    ///
    /// - Note:
    ///   - `TaskGroup` digunakan untuk meningkatkan efisiensi pengambilan data.
    ///   - Filtering berbasis `deletedIDs` lebih baik dilakukan setelah data diambil dari database.
    ///   - `weak self` digunakan dalam `TaskGroup` untuk menghindari kemungkinan memory leak.
    public func getSiswa(_ group: Bool? = nil) async -> [ModelSiswa] {
        var bentukSiswa: [ModelSiswa] = []

        var siswaQuery = siswa // Asumsi 'siswa' adalah Table("siswa")

        // Terapkan filter jika diperlukan
        if group == false, !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
            siswaQuery = siswaQuery.filter(status != "Lulus")
        }

        if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
            siswaQuery = siswaQuery.filter(status != "Berhenti")
        }

        // Mengumpulkan ID yang dihapus
        var deletedIDs: Set<Int64> = []
        // adalah array yang berisi objek dengan properti 'id'
        deletedIDs.formUnion(SingletonData.deletedStudentIDs)

        _ = SingletonData.deletedSiswaArray.compactMap { index in
            deletedIDs.insert(index.id)
        }
        _ = SingletonData.deletedSiswasArray.compactMap { array in
            array.compactMap { innerArray in
                deletedIDs.insert(innerArray.id)
            }
        }
        _ = SingletonData.redoPastedSiswaArray.compactMap { array in
            array.compactMap { innerArray in
                deletedIDs.insert(innerArray.id)
            }
        }

        // Filter berdasarkan deletedIDs
        // Perhatikan: SQLite.swift tidak memiliki operator 'contains' untuk set secara langsung dalam filter query.
        // Anda perlu membuat filter 'NOT IN' secara manual atau mengelola ini setelah query.
        // Untuk tujuan demonstrasi, asumsikan ini bekerja atau Anda akan mengelola filtering setelah fetch.
        // Jika 'deletedIDs' bisa sangat besar, ini mungkin tidak efisien di sisi database.
        // Solusi yang lebih baik adalah memfilter ini setelah mendapatkan semua data dari database
        // atau membangun klausa WHERE IN/NOT IN yang kompleks.
        // Untuk saat ini, kita akan mengasumsikan filter ini bekerja seperti yang dimaksud.
        siswaQuery = siswaQuery.filter(!deletedIDs.contains(id)) // Ini akan menjadi masalah jika deletedIDs besar

        do {
            let studentIDsToFetch = try await DatabaseManager.shared.pool.read { conn in
                let rows = try conn.prepare(siswaQuery.select(id))
                return rows.map { $0[id] }
            }

            // Tangkap juga Expression properties karena digunakan di dalam Task.
            // Meskipun ini biasanya 'let' dan Sendable, eksplisit lebih aman
            // atau pastikan mereka didefinisikan sebagai 'let' di scope yang tepat.
            await withTaskGroup(of: ModelSiswa?.self) { [weak self] group in
                guard let s = self else { return }
                for studentID in studentIDsToFetch {
                    group.addTask(priority: .background) {
                        #if DEBUG
                            s.threadedProcess(#function, 0)
                        #endif
                        return try? await DatabaseManager.shared.pool.read { conn in
                            let filteredQuery = s.siswa.filter(s.id == studentID)
                            if let user = try conn.pluck(filteredQuery) {
                                return ModelSiswa(row: user)
                            }
                            return nil
                        }
                    }
                }

                // Kumpulkan hasil dari TaskGroup secara serial
                for await model in group {
                    if let valid = model {
                        bentukSiswa.append(valid)
                    }
                }
            }
        } catch {
            #if DEBUG
                print("Error preparing initial query or during TaskGroup execution: \(error.localizedDescription)")
            #endif
        }
        return bentukSiswa
    }

    /// Mengambil informasi nama dan kelas siswa berdasarkan ID.
    ///
    /// - Parameter idValue: ID unik siswa yang akan dicari dalam database.
    /// - Returns: Tuple `(nama: String, kelas: String)?` berisi nama siswa dan kelasnya jika ditemukan.
    ///            Jika data tidak ditemukan atau terjadi kesalahan, akan mengembalikan `nil`.
    ///
    /// ## Logika Utama:
    /// - **Menyiapkan Query**: Mencari data siswa berdasarkan `idValue`.
    /// - **Eksekusi Query**:
    ///   - Jika siswa ditemukan, mengambil nilai `nama` dan `kelasSekarang`.
    ///   - Mengembalikan tuple berisi nama dan kelas.
    /// - **Menangani Error**:
    ///   - Jika terjadi kesalahan saat mengambil data, mencetak pesan error.
    ///   - Mengembalikan `nil` jika tidak ada data atau terjadi kegagalan eksekusi.
    ///
    /// - Note:
    ///   - Pastikan `siswa` adalah tabel yang tersedia dalam database.
    ///   - Menggunakan `pluck` untuk mengambil satu baris data siswa.
    ///   - Jika terjadi error, ditangani dengan `catch` untuk menghindari crash aplikasi.
    func getKelasSiswa(_ idValue: Int64) -> (nama: String, kelas: String)? {
        do {
            let query = siswa.filter(id == idValue)
            if let row = try db.pluck(query) {
                let namaSiswa = try row.get(nama)
                let kelas = try row.get(kelasSekarang)
                return (namaSiswa, kelas)
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }

    /// Mengambil daftar guru dari database SQLite secara asinkron.
    ///
    /// - Returns: Array `[GuruModel]` yang telah difilter berdasarkan ID yang tidak termasuk dalam daftar penghapusan.
    ///
    /// ## Logika Utama:
    /// - **Mengumpulkan ID Guru yang Dihapus**:
    ///   - Mengambil daftar `deletedGuruArray` dan `undoAddGuruArray` dari `SingletonData`.
    /// - **Menghapus Guru yang Dihapus dari Query**:
    ///   - Mengecualikan guru dengan `idGuru` yang ada dalam daftar `deletedGuruArray` dan `undoAddGuruArray`.
    /// - **Mengambil ID Guru yang Sesuai**:
    ///   - Mengeksekusi query untuk mendapatkan daftar `idGuru` yang memenuhi kriteria.
    /// - **Menggunakan `TaskGroup` untuk Fetching Paralel**:
    ///   - Menjalankan pengambilan data guru berdasarkan `idGuru` secara paralel untuk meningkatkan performa.
    /// - **Mengembalikan Data Guru**:
    ///   - Jika terjadi error, akan ditangkap dalam blok `catch`.
    ///   - Mengembalikan daftar guru yang sesuai dengan filter.
    ///
    /// - Note:
    ///   - `TaskGroup` digunakan untuk meningkatkan efisiensi pengambilan data.
    ///   - Filtering berbasis `deletedGuruArray` dan `undoAddGuruArray` dilakukan sebelum query dijalankan.
    ///   - `weak self` digunakan dalam `TaskGroup` untuk menghindari kemungkinan memory leak.
    public func getGuru() async -> [GuruModel] {
        var hasil: [GuruModel] = []

        let deletedGuruArray = Array(SingletonData.deletedGuru)
        let undoAddGuruArray = Array(SingletonData.undoAddGuru)

        do {
            // Ambil data dari database secara synchronous di dalam pool.read

            let asatidz = try await DatabaseManager.shared.pool.read { conn in
                let query = guru.filter(!deletedGuruArray.contains(idGuru) && !undoAddGuruArray.contains(idGuru))
                let rows = try conn.prepare(query.select(idGuru))
                return rows.map { $0[idGuru] }
            }

            // Proses mapping ke GuruModel secara konkuren
            await withTaskGroup(of: GuruModel?.self) { [weak self] group in
                guard let self else { return }
                for ID in asatidz {
                    group.addTask(priority: .userInitiated) {
                        try? await DatabaseManager.shared.pool.read { conn in
                            let filteredQuery = self.guru.filter(self.idGuru == ID)
                            if let user = try conn.pluck(filteredQuery) {
                                let g = GuruModel()
                                g.idGuru = user[self.idGuru]
                                g.namaGuru = user[self.namaGuru]
                                g.alamatGuru = user[self.alamatGuru]
                                g.tahunaktif = user[self.tahunaktif]
                                g.mapel = user[self.mapel]
                                g.struktural = user[self.struktural]
                                return g
                            }
                            return nil
                        }
                    }
                }

                for await g in group {
                    if let g {
                        hasil.append(g)
                    }
                }
            }
        } catch {
            print("DB error: \(error.localizedDescription)")
        }

        return hasil
    }

    /// Mengambil daftar guru yang aktif untuk tahun yang ditentukan.
    ///
    /// - Parameter year: String yang mewakili tahun aktif guru yang ingin diambil.
    /// - Returns: Array berisi objek `GuruModel` yang sesuai dengan kriteria filter.
    public func getGuru(forYear year: String) -> [GuruModel] {
        var bentukGuru: [GuruModel] = []
        // Konversi Set ke Array untuk digunakan dalam query SQL
        let deletedGuruArray = Array(SingletonData.deletedGuru)
        let undoAddGuruArray = Array(SingletonData.undoAddGuru)

        // Filter query: hanya ambil guru yang tidak ada di deletedGuruArray atau undoAddGuruArray dan sesuai tahun
        let query = guru
            .filter(!deletedGuruArray.contains(idGuru) &&
                !undoAddGuruArray.contains(idGuru) &&
                tahunaktif == year)
        do {
            for user in try db.prepare(query) {
                let bentukGurus = GuruModel()
                bentukGurus.idGuru = user[idGuru]
                bentukGurus.namaGuru = user[namaGuru]
                bentukGurus.alamatGuru = user[alamatGuru]
                bentukGurus.tahunaktif = user[tahunaktif]
                bentukGurus.mapel = user[mapel]
                bentukGurus.struktural = user[struktural]

                bentukGuru.append(bentukGurus)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return bentukGuru
    }

    /// Mengambil daftar unik tahun aktif dari semua guru yang ada.
    ///
    /// - Returns: Array berisi `String` yang merepresentasikan tahun-tahun aktif unik dari guru-guru yang tersedia.
    public func getTahunAktifGuru() -> [String] {
        var tahunAktif: [String] = []

        // Konversi Set ke Array untuk digunakan dalam query SQL
        let deletedGuruArray = Array(SingletonData.deletedGuru)
        let undoAddGuruArray = Array(SingletonData.undoAddGuru)

        // Query hanya memilih kolom `tahunaktif`
        let query = guru
            .select(tahunaktif)
            .filter(!deletedGuruArray.contains(idGuru) &&
                !undoAddGuruArray.contains(idGuru))

        do {
            for user in try db.prepare(query) {
                // Ambil hanya kolom `tahunaktif`
                let tahun = user[tahunaktif].trimmingCharacters(in: .whitespacesAndNewlines)
                if !tahun.isEmpty, !tahunAktif.contains(tahun) {
                    tahunAktif.append(tahun)
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return tahunAktif
    }

    /// Mengambil ID siswa terakhir yang baru saja dimasukkan ke dalam database.
    ///
    /// - Returns: Sebuah `Int64` opsional yang merupakan ID dari siswa terakhir yang dimasukkan.
    ///            Akan mengembalikan `nil` jika tidak ada siswa yang ditemukan atau terjadi kesalahan.
    func getInsertedSiswaID() -> Int64? {
        do {
            let query = siswa.order(id.desc).limit(1)
            let lastInsertedSiswa = try db.pluck(query)
            return lastInsertedSiswa?[id]
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
            return nil
        }
    }

    /// Mengambil data siswa berdasarkan ID yang diberikan.
    ///
    /// - Parameter idValue: ID siswa (`Int64`) yang ingin dicari.
    /// - Returns: Objek `ModelSiswa` yang berisi data siswa yang ditemukan. Jika siswa tidak ditemukan
    ///            atau terjadi kesalahan, objek `ModelSiswa` yang dikembalikan akan memiliki nilai default.
    public func getSiswa(idValue: Int64) -> ModelSiswa {
        let query = siswa.filter(id == idValue)
        do {
            if let firstRow = try db.pluck(query) {
                return ModelSiswa(row: firstRow)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return ModelSiswa()
    }

    /// Membaca nama siswa dari Database yang sesuai dengan ID yang diterima.
    /// - Parameter idValue: ID Siswa yang akan dicari di Database.
    /// - Returns: Nilai nama siswa yang didapatkan.
    public func getNamaSiswa(idValue: Int64) -> String {
        var namaSiswa = ""
        do {
            let user: AnySequence<Row> = try db.prepare(siswa.filter(id == idValue))
            try user.forEach { rowValue in
                namaSiswa = try rowValue.get(nama)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return namaSiswa
    }

    /// Membaca data foto siswa di Database sesuai dengan ID yang diterima.
    /// 
    /// - Parameter idValue: ID Siswa yang akan dicari di Database.
    /// - Returns: Data foto yang didapatkan dari Database yang dibungkus dengan kerangka data.
    ///
    /// * Note: Gambar yang telah dikueri disimpan sebagai cache di ``ImageCacheManager``.
    /// * Note: Fungsi ini mengembalikan gambar dari ``ImageCacheManager`` jika sebelumnya gambar telah dicache.
    public func bacaFotoSiswa(idValue: Int64) -> Data {
        if let cached = ImageCacheManager.shared.getCachedSiswa(for: idValue) {
            return cached
        }
        var fotoSiswa = Data()
        do {
            if let rowValue = try db.pluck(siswa.filter(id == idValue)) {
                let fotoBlob = try rowValue.get(foto)
                fotoSiswa = fotoBlob
                if !fotoBlob.isEmpty {
                    ImageCacheManager.shared.cacheSiswaImage(fotoBlob, for: idValue)
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return fotoSiswa
    }

    /// Mengambil ID siswa berdasarkan nama siswa.
    ///
    /// - Parameter namaSiswa: Nama siswa (`String`) yang ingin dicari.
    /// - Returns: Sebuah `Int64` opsional yang merupakan ID siswa yang ditemukan.
    ///            Akan mengembalikan `nil` jika siswa dengan nama tersebut tidak ditemukan atau terjadi kesalahan.
    func getSiswaIDForNamaSiswa(_ namaSiswa: String) -> Int64? {
        do {
            if let row = try db.pluck(siswa.filter(nama == namaSiswa)) {
                return try row.get(Expression<Int64>("id"))
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return nil
    }

    /// Mengambil nama siswa beserta ID mereka berdasarkan kelas yang ditentukan.
    ///
    /// - Parameter table: `String` yang merepresentasikan nama kelas (`kelasSekarang`) siswa yang ingin diambil.
    /// - Returns: Sebuah `Dictionary` dengan `String` sebagai kunci (nama siswa) dan `Int64` sebagai nilai (ID siswa).
    ///            Akan mengembalikan dictionary kosong jika tidak ada siswa yang ditemukan atau terjadi kesalahan.
    func getNamaSiswa(withTable table: String) -> [String: Int64] {
        var siswaData: [String: Int64] = [:]
        do {
            // Filter data siswa berdasarkan kelasSekarang
            let filteredSiswaData = siswa.filter(kelasSekarang == table && status == "Aktif").order(nama.asc)
            for user in try db.prepare(filteredSiswaData) {
                let namaSiswa = user[nama]
                let siswaID = user[id]
                siswaData[namaSiswa] = siswaID
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return siswaData
    }

    /// Memperbarui status siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idSiswa: ID siswa (`Int64`) yang statusnya ingin diperbarui.
    ///   - newStatus: Status baru (`String`) yang akan diterapkan pada siswa.
    public func updateStatusSiswa(idSiswa: Int64, newStatus: String) {
        do {
            let statusBaru = siswa.filter(id == idSiswa)
            try db.run(statusBaru.update(
                status <- newStatus
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kelas aktif, status, dan tanggal berhenti siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idSiswa: ID siswa (`Int64`) yang datanya ingin diperbarui.
    ///   - newKelasAktif: Nama kelas aktif baru (`String`) yang akan diterapkan pada siswa.
    public func updateKelasAktif(idSiswa: Int64, newKelasAktif: String) {
        do {
            let statusBaru = siswa.filter(id == idSiswa)
            try db.run(statusBaru.update(
                kelasSekarang <- newKelasAktif,
                status <- "Aktif",
                tanggalberhenti <- ""
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui tanggal berhenti siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - kunci: ID siswa (`Int64`) yang tanggal berhentinya ingin diperbarui.
    ///   - editTglBerhenti: Tanggal berhenti baru (`String`) yang akan diterapkan pada siswa.
    public func updateTglBerhenti(kunci: Int64, editTglBerhenti: String) {
        do {
            let update = siswa.filter(id == kunci)
            try db.run(update.limit(1).update(tanggalberhenti <- editTglBerhenti))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui data lengkap siswa berdasarkan ID yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set data terkait siswa (`ReusableFunc.namasiswa`, `ReusableFunc.alamat`, dll.)
    /// serta memperbarui nama siswa di tabel kelas yang relevan (kelas1 hingga kelas6).
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang datanya ingin diperbarui.
    ///   - namaValue: Nama siswa yang baru (`String`).
    ///   - alamatValue: Alamat siswa yang baru (`String`).
    ///   - ttlValue: Tempat/Tanggal Lahir siswa yang baru (`String`).
    ///   - tahundaftarValue: Tahun daftar siswa yang baru (`String`).
    ///   - namawaliValue: Nama wali siswa yang baru (`String`).
    ///   - nisValue: Nomor Induk Siswa (NIS) siswa yang baru (`String`).
    ///   - jeniskelaminValue: Jenis kelamin siswa yang baru (`String`).
    ///   - statusValue: Status siswa yang baru (`String`).
    ///   - tanggalberhentiValue: Tanggal berhenti siswa yang baru (`String`).
    ///   - nisnValue: Nomor Induk Siswa Nasional (NISN) siswa yang baru (`String`).
    ///   - updatedAyah: Nama ayah siswa yang baru (`String`).
    ///   - updatedIbu: Nama ibu siswa yang baru (`String`).
    ///   - updatedTlv: Nilai TLV siswa yang baru (`String`).
    public func updateSiswa(idValue: Int64, namaValue: String, alamatValue: String, ttlValue: String, tahundaftarValue: String, namawaliValue: String, nisValue: String, jeniskelaminValue: String, statusValue: String, tanggalberhentiValue: String, nisnValue: String, updatedAyah: String, updatedIbu: String, updatedTlv: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                nama <- namaValue,
                alamat <- alamatValue,
                ttl <- ttlValue,
                tahundaftar <- tahundaftarValue,
                namawali <- namawaliValue,
                nis <- nisValue,
                nisn <- nisnValue,
                ayah <- updatedAyah,
                ibu <- updatedIbu,
                tlv <- updatedTlv,
                jeniskelamin <- jeniskelaminValue,
                status <- statusValue,
                tanggalberhenti <- tanggalberhentiValue
            ))
            var namaWords: Set<String> = []
            var alamatWords: Set<String> = []
            var ttlWords: Set<String> = []
            var namaWaliWords: Set<String> = []
            var nisWords: Set<String> = []
            var nisnWords: Set<String> = []
            var tlvWords: Set<String> = []
            var ayah: Set<String> = []
            var ibu: Set<String> = []
            namaWords.formUnion(namaValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            namaWords.insert(namaValue.capitalizedAndTrimmed())
            alamatWords.formUnion(alamatValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            alamatWords.insert(alamatValue.capitalizedAndTrimmed())
            ttlWords.formUnion(ttlValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ttlWords.insert(ttlValue.capitalizedAndTrimmed())
            nisWords.formUnion(nisValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            nisWords.insert(nisValue.capitalizedAndTrimmed())
            namaWaliWords.formUnion(ttlValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            namaWaliWords.insert(ttlValue.capitalizedAndTrimmed())
            nisnWords.formUnion(nisValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            nisnWords.insert(nisValue.capitalizedAndTrimmed())
            tlvWords.formUnion(updatedTlv.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            tlvWords.insert(updatedTlv.capitalizedAndTrimmed())
            ayah.formUnion(updatedAyah.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ayah.insert(updatedAyah.capitalizedAndTrimmed())
            ibu.formUnion(updatedIbu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ibu.insert(updatedIbu.capitalizedAndTrimmed())
            ReusableFunc.namasiswa.formUnion(namaWords)
            ReusableFunc.alamat.formUnion(alamatWords)
            ReusableFunc.namaAyah.formUnion(ayah)
            ReusableFunc.namaIbu.formUnion(ibu)
            ReusableFunc.namawali.formUnion(namaWaliWords)
            ReusableFunc.ttl.formUnion(ttlWords)
            ReusableFunc.nis.formUnion(nisWords)
            ReusableFunc.nisn.formUnion(nisnWords)
            ReusableFunc.tlvString.formUnion(tlvWords)

            do {
                try db.run(kelas1.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
                try db.run(kelas2.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
                try db.run(kelas3.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
                try db.run(kelas4.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
                try db.run(kelas5.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
                try db.run(kelas6.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            } catch {}
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui satu kolom spesifik pada entitas siswa.
    ///
    /// - Parameters:
    ///   - id: ID siswa (`Int64`) yang kolomnya ingin diperbarui.
    ///   - kolom: Nama kolom (`String`) yang akan diperbarui.
    ///   - data: Data baru (`String`) untuk kolom yang ditentukan.
    func updateKolomSiswa(_ id: Int64, kolom: String, data: String) {
        do {
            let user = siswa.filter(self.id == id)
            try db.run(user.limit(1).update(
                Expression<String>(kolom) <- data
            ))
        } catch {
            print(error.localizedDescription)
        }
    }

    /// Memperbarui kolom 'ayah' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.namaAyah` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'ayah'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'ayah'.
    func updateKolomAyah(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                ayah <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.namaAyah.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'ibu' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.namaIbu` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'ibu'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'ibu'.
    func updateKolomIbu(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                ibu <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.namaIbu.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'nisn' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.nisn` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'nisn'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'nisn'.
    func updateKolomNISN(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                nisn <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.nisn.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'tlv' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.tlvString` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'tlv'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'tlv'.
    func updateKolomTlv(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                tlv <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.tlvString.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'nama' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.namasiswa` dengan nilai baru
    /// dan memperbarui nama siswa di tabel kelas yang relevan (kelas1 hingga kelas6).
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'nama'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'nama'.
    func updateKolomNama(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                nama <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.namasiswa.formUnion(words)
            do {
                try db.run(kelas1.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
                try db.run(kelas2.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
                try db.run(kelas3.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
                try db.run(kelas4.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
                try db.run(kelas5.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
                try db.run(kelas6.filter(Expression<Int64>("siswa_id") == idValue && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- value))
            } catch {}
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'alamat' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.alamat` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'alamat'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'alamat'.
    func updateKolomAlamat(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                alamat <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.alamat.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'nis' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'nis'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'nis'.
    func updateKolomNIS(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                nis <- value
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'ttl' (Tanggal Lahir) untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'ttl'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'ttl'.
    func updateKolomTglLahir(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                ttl <- value
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'tahundaftar' (Tahun Daftar) untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'tahundaftar'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'tahundaftar'.
    func updateKolomTahunDaftar(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                tahundaftar <- value
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'namawali' (Nama Wali) untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// Fungsi ini juga memperbarui set `ReusableFunc.namawali` dengan nilai baru.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'namawali'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'namawali'.
    func updateKolomWali(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                namawali <- value
            ))
            var words: Set<String> = []
            words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            words.insert(value.capitalizedAndTrimmed())
            ReusableFunc.namawali.formUnion(words)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui kolom 'jeniskelamin' untuk siswa berdasarkan ID siswa yang diberikan.
    ///
    /// - Parameters:
    ///   - idValue: ID siswa (`Int64`) yang kolom 'jeniskelamin'-nya ingin diperbarui.
    ///   - value: Nilai baru (`String`) untuk kolom 'jeniskelamin'.
    func updateKolomKelamin(_ idValue: Int64, value: String) {
        do {
            let user = siswa.filter(id == idValue)
            try db.run(user.limit(1).update(
                jeniskelamin <- value
            ))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui nama siswa di semua tabel kelas (kelas1 hingga kelas6) berdasarkan ID siswa.
    ///
    /// - Parameters:
    ///   - siswaID: ID siswa (`Int64`) yang namanya ingin diperbarui di tabel kelas.
    ///   - namaValue: Nama siswa baru (`String`) yang akan diterapkan.
    func updateNamaSiswaInKelas(siswaID: Int64, namaValue: String) {
        do {
            try db.run(kelas1.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            try db.run(kelas2.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            try db.run(kelas3.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            try db.run(kelas4.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            try db.run(kelas5.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
            try db.run(kelas6.filter(Expression<Int64>("siswa_id") == siswaID && namasiswa != nil).filter(namasiswa != nil).update(namasiswa <- namaValue))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui data nilai mata pelajaran, nama guru, dan semester dalam tabel kelas yang ditentukan.
    ///
    /// Fungsi ini juga memperbarui set data terkait (nama guru, mata pelajaran, dan semester)
    /// yang digunakan dalam `ReusableFunc`.
    ///
    /// - Parameters:
    ///   - kelasID: ID entri kelas (`Int64`) yang datanya ingin diperbarui.
    ///   - mapelValue: Nama mata pelajaran baru (`String`).
    ///   - nilaiValue: Nilai baru (`Int64`) untuk mata pelajaran tersebut.
    ///   - namaguruValue: Nama guru baru (`String`) yang mengajar mata pelajaran tersebut.
    ///   - semesterValue: Nilai semester baru (`String`).
    ///   - table: Objek `Table` yang merepresentasikan tabel kelas yang akan diperbarui (e.g., `kelas1`, `kelas2`, dst.).
    func updateDataInKelas(kelasID: Int64, mapelValue: String, nilaiValue: Int64, namaguruValue: String, semesterValue: String, table: Table) {
        do {
            let query = table.filter(kelasId == kelasID)
            try db.run(query.limit(1).update(
                mapel <- mapelValue,
                nilai <- nilaiValue,
                semester <- semesterValue,
                namaguru <- namaguruValue
            ))

            var mapelWords: Set<String> = []
            var namaguruWords: Set<String> = []
            var semesterWords: Set<String> = []

            mapelWords.formUnion(mapelValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            mapelWords.insert(mapelValue.capitalizedAndTrimmed())

            namaguruWords.formUnion(namaguruValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            namaguruWords.insert(namaguruValue.capitalizedAndTrimmed())

            semesterWords.formUnion(semesterValue.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            semesterWords.insert(semesterValue.capitalizedAndTrimmed())

            ReusableFunc.namaguru.formUnion(namaguruWords)
            ReusableFunc.mapel.formUnion(mapelWords)
            ReusableFunc.semester.formUnion(semesterWords)

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui satu kolom spesifik pada entitas guru berdasarkan ID guru.
    ///
    /// Fungsi ini secara dinamis memperbarui kolom yang ditentukan dan juga memperbarui set data terkait
    /// (`ReusableFunc.namaguru`, `ReusableFunc.alamat`, `ReusableFunc.ttl`, `ReusableFunc.mapel`, `ReusableFunc.jabatan`)
    /// berdasarkan kolom yang diubah.
    ///
    /// - Parameters:
    ///   - id: ID guru (`Int64`) yang kolomnya ingin diperbarui.
    ///   - kolom: Nama kolom (`String`) yang akan diperbarui (misalnya, "Nama", "Alamat", "Tahun Aktif", "Mata Pelajaran", "Jabatan").
    ///   - baru: Data baru (`String`) untuk kolom yang ditentukan.
    func updateKolomGuru(_ id: Int64, kolom: String, baru: String) {
        do {
            let user = guru.filter(idGuru == id)
            try db.run(user.limit(1).update(
                Expression<String>(kolom) <- baru
            ))

            var namaWords: Set<String> = []
            if kolom == "Nama" {
                namaWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaWords.insert(baru.capitalizedAndTrimmed())
                ReusableFunc.namaguru.formUnion(namaWords)
            }

            var alamatWords: Set<String> = []
            if kolom == "Alamat" {
                alamatWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                alamatWords.insert(baru.capitalizedAndTrimmed())
                ReusableFunc.alamat.formUnion(alamatWords)
            }

            var tahunWords: Set<String> = []
            if kolom == "Tahun Aktif" {
                tahunWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                tahunWords.insert(baru.capitalizedAndTrimmed())
                ReusableFunc.ttl.formUnion(tahunWords)
            }

            var mapelWords: Set<String> = []
            if kolom == "Mata Pelajaran" {
                mapelWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                mapelWords.insert(baru.capitalizedAndTrimmed())
                ReusableFunc.mapel.formUnion(mapelWords)
            }

            var strukturWords: Set<String> = []
            if kolom == "Jabatan" {
                strukturWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                strukturWords.insert(baru.capitalizedAndTrimmed())
                ReusableFunc.jabatan.formUnion(strukturWords)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    /// Menghapus data siswa dari tabel `siswa` dan semua tabel kelas terkait (kelas1 hingga kelas6)
    /// berdasarkan ID siswa yang diberikan. Setelah penghapusan, database akan di-vacuum.
    ///
    /// - Parameter idValue: ID siswa (`Int64`) yang datanya ingin dihapus.
    public func hapusDaftar(idValue: Int64) {
        do {
            let siswaQuery = siswa.filter(id == idValue)
            try db.run(siswaQuery.delete())
            // Mulai dengan menghapus data siswa dari tabel "kelas1"
            let kelas1Query = kelas1.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas1Query.delete())
            // Selanjutnya, hapus data siswa dari tabel "kelas2"
            let kelas2Query = kelas2.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas2Query.delete())
            let kelas3Query = kelas3.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas3Query.delete())
            let kelas4Query = kelas4.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas4Query.delete())
            let kelas5Query = kelas5.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas5Query.delete())
            let kelas6Query = kelas6.filter(Expression<Int64>("siswa_id") == idValue)
            try db.run(kelas6Query.delete())

            vacuumDatabase()
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Fungsi untuk membatalkan update foto siswa dan mendukung mekanisme undo.
    /// - Parameters:
    ///   - idx: ID siswa yang fotonya ingin di-undo.
    ///   - oldImageData: Data gambar lama yang akan dikembalikan.
    ///   - undoManager: Objek UndoManager untuk mencatat aksi undo.
    /// * Note: Gambar yang ditambahkan disimpan sebagai cache di ``ImageCacheManager``.
    public func undoUpdateFoto(idx: Int64, oldImageData: Data, undoManager: UndoManager) {
        let query = siswa.filter(id == idx)

        do {
            // Ambil data foto saat ini (sebelum di-undo) untuk didaftarkan ke undo berikutnya
            if let rowValue = try db.pluck(query) {
                let currentImageData = try rowValue.get(foto)
                
                // Daftarkan undo dengan data saat ini sebagai oldImageData berikutnya
                undoManager.registerUndo(withTarget: self) { target in
                    target.undoUpdateFoto(idx: idx, oldImageData: currentImageData, undoManager: undoManager)
                }
            }

            // Jalankan update ke data lama
            try db.run(query.update(foto <- oldImageData))

            // Simpan kembali ke cache agar sinkron
            oldImageData.isEmpty ?
            ImageCacheManager.shared.clearSiswaCache(for: idx) :
            ImageCacheManager.shared.cacheSiswaImage(oldImageData, for: idx)
            
        } catch {
            #if DEBUG
            print("❌ Undo error: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Memperbarui kolom 'foto' dalam database untuk siswa tertentu dengan data gambar yang diberikan.
    /// Jika data `imageData` kosong, foto di database akan dihapus.
    /// Setelah pembaruan, database akan di-vacuum.
    ///
    /// - Parameters:
    ///   - imageData: Data gambar (`Data`) yang akan disimpan.
    ///   - idx: ID siswa (`Int64`) yang fotonya ingin diperbarui.
    ///   - undoManager: Opsional. Objek UndoManager untuk mencatat aksi undo.
    ///
    /// * Note: Gambar yang ditambahkan disimpan sebagai cache di ``ImageCacheManager``.
    func updateFotoInDatabase(with imageData: Data, idx: Int64, undoManager: UndoManager? = nil) {
        // Update foto dalam database
        let updateQuery = siswa.filter(id == idx)
        
        do {
            if let undoManager, let rowValue = try db.pluck(updateQuery) {
                let oldImageData = try rowValue.get(foto)
                // Daftarkan undo
                undoManager.registerUndo(withTarget: self) { [oldImageData] target in
                    target.undoUpdateFoto(idx: idx, oldImageData: oldImageData, undoManager: undoManager)
                }
            }
            
            try db.run(updateQuery.limit(1).update(foto <- imageData))
            
            imageData.isEmpty ?
            ImageCacheManager.shared.clearSiswaCache(for: idx) :
            ImageCacheManager.shared.cacheSiswaImage(imageData, for: idx)
            
            vacuumDatabase()
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus data guru dari database berdasarkan ID guru yang diberikan.
    ///
    /// - Parameter idGuruValue: ID guru (`Int64`) yang datanya ingin dihapus.
    public func hapusGuru(idGuruValue: Int64) {
        do {
            let user = guru.filter(idGuru == idGuruValue)
            try db.run(user.delete())
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Melakukan pencarian siswa secara asinkron berdasarkan kueri yang diberikan.
    ///
    /// Fungsi ini mencari siswa yang namanya, kelas aktif, NIS, alamat, jenis kelamin, atau statusnya
    /// cocok dengan `query`. Hasil pencarian akan mengecualikan siswa yang ID-nya
    /// ada di daftar siswa yang dihapus sementara (`SingletonData.deletedStudentIDs`, `SingletonData.deletedSiswaArray`,
    /// `SingletonData.deletedSiswasArray`, dan `SingletonData.redoPastedSiswaArray`).
    /// Proses pengambilan dan pemrosesan data siswa dilakukan secara konkuren menggunakan `TaskGroup`.
    ///
    /// - Parameter query: `String` yang berisi kueri pencarian.
    /// - Returns: Array berisi objek `ModelSiswa` yang sesuai dengan kriteria pencarian dan filter.
    ///            Akan mengembalikan array kosong jika tidak ada siswa yang ditemukan atau terjadi kesalahan.
    func searchSiswa(query: String) async -> [ModelSiswa] {
        var bentukSiswa: [ModelSiswa] = []
        var deletedIDs: Set<Int64> = []

        // Ambil data dari SingletonData dan masukkan ke dalam set
        let deletedSiswa = Array(SingletonData.deletedStudentIDs)

        // Mengisi deletedIDs dari array satu dimensi
        _ = SingletonData.deletedSiswaArray.compactMap { item in
            deletedIDs.insert(item.id)
        }

        // Mengisi deletedIDs dari array dua dimensi
        _ = SingletonData.deletedSiswasArray.compactMap { array in
            array.compactMap { innerItem in
                deletedIDs.insert(innerItem.id)
            }
        }

        _ = SingletonData.redoPastedSiswaArray.compactMap { array in
            array.compactMap { innerItem in
                deletedIDs.insert(innerItem.id)
            }
        }

        let queryLower = query.lowercased()

        // Filter data berdasarkan query dan memastikan id tidak ada di deletedIDs
        let filteredSiswa = siswa.filter(
            nama.lowercaseString.like("%\(queryLower)%") ||
            kelasSekarang.lowercaseString.like("%\(queryLower)%") ||
            nis.lowercaseString.like("%\(queryLower)%") ||
            nisn.lowercaseString.like("%\(queryLower)%") ||
            alamat.lowercaseString.like("%\(queryLower)%") ||
            jeniskelamin.lowercaseString.like("%\(queryLower)%") ||
            kelasSekarang.lowercaseString.like("%\(queryLower)%") ||
            status.lowercaseString.like("%\(queryLower)%")
        ).filter(!deletedSiswa.contains(id) && !deletedIDs.contains(id))

        do {
            // Dapatkan row hasil query dari database secara synchronous (karena SQLite biasanya mensupport ini)
            let users = try db.prepare(filteredSiswa)

            // Gunakan TaskGroup untuk memproses setiap row secara konkuren
            let siswaArray: [ModelSiswa] = await withTaskGroup(of: ModelSiswa?.self) { [weak self] group in
                guard let self else { return [] }
                for row in users {
                    group.addTask {
                        #if DEBUG
                            self.threadedProcess(#function, 0)
                        #endif
                        return ModelSiswa(row: row)
                    }
                }

                // Kumpulkan semua hasil dari task group secara sekuensial
                var results: [ModelSiswa] = []
                for await siswa in group {
                    if let siswa {
                        results.append(siswa)
                    }
                }
                return results
            }

            bentukSiswa = siswaArray
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return bentukSiswa
    }

    /// Melakukan pencarian guru secara asinkron berdasarkan kueri yang diberikan.
    ///
    /// Fungsi ini mencari guru yang nama, alamat, tahun aktif, mata pelajaran, atau strukturalnya
    /// cocok dengan `query`. Hasil pencarian akan mengecualikan guru yang ID-nya
    /// ada di daftar guru yang dihapus sementara (`SingletonData.deletedGuru` dan `SingletonData.undoAddGuru`).
    /// Proses pengambilan dan pemrosesan data guru dilakukan secara konkuren menggunakan `TaskGroup`.
    ///
    /// - Parameter query: `String` yang berisi kueri pencarian.
    /// - Returns: Array berisi objek `GuruModel` yang sesuai dengan kriteria pencarian dan filter.
    ///            Akan mengembalikan array kosong jika tidak ada guru yang ditemukan atau terjadi kesalahan.
    func searchGuru(query: String) async -> [GuruModel] {
        var pencarianGuru: [GuruModel] = []

        let deletedGuruArray = Array(SingletonData.deletedGuru)
        let undoAddGuruArray = Array(SingletonData.undoAddGuru)

        // Ubah pola pencarian agar memanfaatkan indeks
        let filteredGuru = guru.filter(
            namaGuru.lowercaseString.like("%\(query)%") ||
                alamatGuru.lowercaseString.like("%\(query)%") ||
                tahunaktif.lowercaseString.like("%\(query)%") ||
                mapel.lowercaseString.like("%\(query)%") ||
                struktural.lowercaseString.like("%\(query)%")
        ).filter(!deletedGuruArray.contains(idGuru) && !undoAddGuruArray.contains(idGuru)) // Menggabungkan filter untuk id yang

        do {
            let filteredTabel = try db.prepare(filteredGuru)
            let filteredGuru: [GuruModel] = await withTaskGroup(of: GuruModel.self) { [weak self] group in
                guard let self else { return [] }
                for user in filteredTabel {
                    group.addTask(priority: .background) {
                        let guru = GuruModel()
                        guru.idGuru = user[self.idGuru]
                        guru.namaGuru = user[self.namaGuru]
                        guru.alamatGuru = user[self.alamatGuru]
                        guru.tahunaktif = user[self.tahunaktif]
                        guru.mapel = user[self.mapel]
                        return guru
                    }
                }
                var result = [GuruModel]()
                for await guru in group {
                    result.append(guru)
                }
                return result
            }
            pencarianGuru = filteredGuru
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return pencarianGuru
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
            let siswaArray: [Row] = try await DatabaseManager.shared.pool.read { [weak self] db in
                guard let self else { return [] }
                return try Array(db.prepare(self.siswa.select(
                    self.tahundaftar,
                    self.tanggalberhenti,
                    self.jeniskelamin
                ).order(self.tahundaftar, self.tanggalberhenti)))
            }

            // Ambil tahun unik dari data siswa
            let uniqueYears: Set<Int> = Set(siswaArray.compactMap { [weak self] row in
                guard let self else { return nil }
                if let tanggalDaftar = try? row.get(self.tahundaftar),
                   let year = self.getYearFromDate(dateString: tanggalDaftar)
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
                                        guard let tanggalDaftar = try? $0.get(self.tahundaftar),
                                              let yearDaftar = self.getYearFromDate(dateString: tanggalDaftar),
                                              let monthDaftar = self.getMonthFromDate(dateString: tanggalDaftar)
                                        else {
                                            return false
                                        }

                                        if let tanggalBerhenti = try? $0.get(self.tanggalberhenti),
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
                                        (try? $0.get(self.jeniskelamin)) == "Laki-laki"
                                    }.count

                                    let perempuanCount = filteredSiswa.filter {
                                        (try? $0.get(self.jeniskelamin)) == "Perempuan"
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

    /// Menghitung jumlah siswa berdasarkan status yang diberikan.
    ///
    /// - Parameter statusFilter: `String` yang merepresentasikan status siswa yang ingin dihitung (misalnya, "Aktif", "Tidak Aktif").
    /// - Returns: Jumlah siswa (`Int`) yang memiliki status sesuai `statusFilter`. Mengembalikan 0 jika terjadi kesalahan.
    func countSiswaByStatus(statusFilter: String) -> Int {
        do {
            return try db.scalar(siswa.filter(status == statusFilter).count)
        } catch {
            return 0
        }
    }

    /// Menghitung total jumlah siswa dalam database.
    ///
    /// - Returns: Jumlah seluruh siswa (`Int`) yang terdaftar. Mengembalikan 0 jika terjadi kesalahan.
    func countAllSiswa() -> Int {
        do {
            return try db.scalar(siswa.count)
        } catch {
            return 0
        }
    }

    // MARK: - KODE KELAS

    /// Memasukkan data nilai siswa ke dalam tabel kelas yang ditentukan.
    ///
    /// Fungsi ini melakukan transaksi database untuk menambahkan catatan baru ke tabel kelas
    /// dengan detail seperti ID siswa, nama siswa, mata pelajaran, nama guru, nilai, semester, dan tanggal.
    /// Setelah berhasil memasukkan data, fungsi ini juga memperbarui set saran (`ReusableFunc.namaguru`,
    /// `ReusableFunc.mapel`, `ReusableFunc.semester`) dan mencatat saran baru.
    ///
    /// - Parameters:
    ///   - table: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - siswaID: ID unik siswa (`Int64`) yang terkait dengan catatan ini.
    ///   - namaSiswa: Nama siswa (`String?`) yang terkait. Ini bisa `nil`.
    ///   - mapel: Nama mata pelajaran (`String`).
    ///   - namaguru: Nama guru (`String`) yang mengajar mata pelajaran ini.
    ///   - nilai: Nilai siswa (`Int64`) untuk mata pelajaran ini.
    ///   - semester: Semester (`String`) di mana nilai ini dicatat.
    ///   - tanggal: Tanggal (`String`) pencatatan nilai.
    /// - Returns: `Int64?` yang merepresentasikan ID baris (`rowid`) dari catatan yang baru dimasukkan,
    ///            atau `nil` jika operasi penyisipan gagal.
    func insertDataToKelas(table: Table, siswaID: Int64, namaSiswa: String?, mapel: String, namaguru: String, nilai: Int64, semester: String, tanggal: String) -> Int64? {
        do {
            var insertedId: Int64?

            try db.transaction {
                let insert = table.insert(
                    self.siswa_id <- siswaID,
                    self.namasiswa <- namaSiswa ?? nil,
                    self.mapel <- mapel,
                    self.namaguru <- namaguru,
                    self.nilai <- nilai,
                    self.semester <- semester,
                    self.tanggal <- tanggal
                )

                try db.run(insert)

                // Dapatkan kelasId yang baru ditambahkan
                insertedId = try db.scalar(table.select(Expression<Int64>("rowid").max))

                var mapelWords: Set<String> = []
                var namaguruWords: Set<String> = []
                var semesterWords: Set<String> = []

                mapelWords.formUnion(mapel.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                mapelWords.insert(mapel.capitalizedAndTrimmed())

                namaguruWords.formUnion(namaguru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                namaguruWords.insert(namaguru.capitalizedAndTrimmed())

                semesterWords.formUnion(semester.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
                semesterWords.insert(semester.capitalizedAndTrimmed())

                ReusableFunc.namaguru.formUnion(namaguruWords)
                ReusableFunc.mapel.formUnion(mapelWords)
                ReusableFunc.semester.formUnion(semesterWords)
            }

            let suggestionData: [KelasColumn: String] = [
                .mapel: mapel,
                .guru: namaguru,
            ]
            catatSuggestions(data: suggestionData)

            return insertedId
        } catch {
            return nil
        }
    }

    /// Menambahkan data kelas baru ke tabel yang ditentukan.
    ///
    /// Fungsi ini memasukkan detail kelas seperti ID siswa, nama siswa, mata pelajaran,
    /// nama guru, semester, dan tanggal ke dalam tabel yang diberikan. Setelah berhasil
    /// menambahkan data, fungsi ini memposting notifikasi `dataDidChangeNotification`
    /// dan mencatat saran berdasarkan mata pelajaran dan nama guru.
    ///
    /// - Parameters:
    ///   - table: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - siswaID: ID unik siswa (`Int64`) yang terkait dengan catatan ini.
    ///   - namaSiswa: Nama siswa (`String`).
    ///   - mapel: Nama mata pelajaran (`String`).
    ///   - namaguru: Nama guru (`String`) yang mengajar mata pelajaran ini.
    ///   - semester: Semester (`String`) di mana data ini dicatat.
    ///   - tanggal: Tanggal (`String`) pencatatan data.
    func tambahDataKelas(table: Table, siswaID: Int64, namaSiswa: String, mapel: String, namaguru: String, semester: String, tanggal: String) {
        do {
            try db.transaction {
                try db.run(table.insert(
                    Expression<Int64>("siswa_id") <- siswaID,
                    self.namasiswa <- namaSiswa,
                    self.mapel <- mapel,
                    self.namaguru <- namaguru,
                    self.semester <- semester,
                    self.tanggal <- tanggal
                ))
            }
            NotificationCenter.default.post(name: DatabaseController.dataDidChangeNotification, object: self)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        let suggestionData: [KelasColumn: String] = [
            .mapel: mapel,
            .guru: namaguru,
        ]
        catatSuggestions(data: suggestionData)
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

    /// Mengambil seluruh data kelas yang memiliki nama siswa dari tabel yang ditentukan.
    ///
    /// Fungsi ini bekerja dalam dua tahap:
    /// 1. Mengambil semua `kelasID` yang memiliki data `namasiswa` valid.
    /// 2. Melakukan pengambilan detail untuk setiap ID tersebut secara paralel menggunakan `TaskGroup`.
    ///
    /// Hanya data yang tidak masuk ke dalam daftar penghapusan (`deletedStudentIDs`,
    /// `deletedKelasAndSiswaIDs`, dan `siswaNaikId`) yang akan dikembalikan.
    ///
    /// - Parameters:
    ///   - type: Tipe tabel yang akan diambil datanya, dibungkus dalam `TableType`.
    ///   - priority: Prioritas tugas asinkron (default: `.background`).
    /// - Returns: Array berisi objek bertipe `T` yang merupakan turunan dari `RowInitializable`.
    ///
    /// - Note:
    ///   - Fungsi ini membutuhkan akses ke database melalui `DatabaseManager.shared.pool`.
    ///   - Filtering tambahan dilakukan berdasarkan ID siswa dan kelas yang telah ditandai sebagai dihapus atau naik.
    ///   - Proses pengambilan data detail dilakukan paralel untuk efisiensi.
    ///
    /// - Important:
    ///   - Objek generik `T` harus mengimplementasikan protokol `RowInitializable`.
    ///   - Jika `self` sudah tidak tersedia (misalnya karena dilepas dari memori), maka tugas akan gagal dan dilewati.
    ///
    /// - Warning:
    ///   - Jika terjadi kesalahan pada tahap pengambilan ID atau data, akan dicetak ke konsol di mode DEBUG.
    func getAllKelas<T: RowInitializable>(ofType type: TableType, priority: TaskPriority = .background) async -> [T] {
        // 3a) Ambil semua kelas_id yang punya namasiswa
        let ids: [Int64]
        do {
            ids = try await DatabaseManager.shared.pool.read { [weak self] db in
                guard let self else { return [] }
                let tbl = type.table
                let colId = self.kelasId
                let colName = self.namasiswa
                let rows = try db.prepare(tbl
                    .filter(colName != nil && colName != "")
                    .select(colId))
                return rows.map { $0[colId] }
            }
        } catch {
            #if DEBUG
                print("fetch IDs error:", error)
            #endif
            return []
        }

        // 3b) Fetch detail per ID secara paralel
        var result = [T]()
        await withTaskGroup(of: T?.self) { group in
            for id in ids {
                group.addTask(priority: priority) { [weak self] () async -> T? in
                    do {
                        return try await DatabaseManager.shared.pool.read { [weak self] db in
                            guard let self else { throw NSError(domain: "self unallocated", code: 403) }

                            let tbl = type.table
                            let colId = self.kelasId
                            let colSid = self.siswa_id

                            guard let row = try db.pluck(tbl.filter(colId == id)) else {
                                throw NSError(domain: "RowNotFound", code: 404)
                            }

                            let sid = row[colSid]
                            let rels = SingletonData.deletedKelasAndSiswaIDs.flatMap { $0 }
                            let isDeleted = SingletonData.deletedStudentIDs.contains(sid)
                                || rels.contains { $0.kelasID == id && $0.siswaID == sid }
                                || SingletonData.siswaNaikId.contains(sid)

                            guard !isDeleted else {
                                throw NSError(domain: "FilteredOut", code: 403)
                            }

                            #if DEBUG
                                self.threadedProcess(#function, 0)
                            #endif

                            return T(row: row)
                        }
                    } catch {
                        // Bisa log di sini kalau mau
                        print("Task error for id \(id): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await maybeModel in group {
                if let m = maybeModel { result.append(m) }
            }
        }

        return result
    }

    /// Mengambil semua data kelas dari *database* secara asinkron.
    ///
    /// Fungsi ini akan memuat daftar dari semua data dari tabel `kelas`.
    /// Data hanya akan diambil untuk entri di mana `namasiswa` tidak `nil` atau kosong.
    /// Proses pengambilan data dilakukan secara paralel menggunakan `TaskGroup`
    /// untuk meningkatkan performa. Selain itu, fungsi ini juga akan memfilter
    /// siswa yang telah "naik kelas", "dihapus", atau "dihapus dari kelas dan siswa"
    /// berdasarkan `SingletonData`.
    ///
    /// - Returns: Sebuah array salah satu dari subclass `[KelasModels]` Kelas1Model-Kelas6Model yang berisi semua data kelas tertentu
    ///            yang relevan dan telah difilter. Jika terjadi kesalahan selama
    ///            pengambilan data, array kosong akan dikembalikan.
    func getAllKelas() async -> [TableType: [KelasModels]] {
        await withTaskGroup(of: (TableType, [KelasModels]).self) { [unowned self] group in
            // spawn satu child task per tipe
            for type in TableType.allCases {
                group.addTask {
                    let data: [KelasModels] = await self.getAllKelas(ofType: type)
                    return (type, data)
                }
            }

            // koleksi hasil
            var result: [TableType: [KelasModels]] = [:]
            for await (type, data) in group {
                result[type] = data
            }
            return result
        }
    }

    /// Mengambil daftar semester unik dari tabel database yang ditentukan.
    ///
    /// Fungsi ini menjalankan kueri SQL untuk mendapatkan semua nilai unik dari kolom `semester`
    /// dari tabel yang diberikan. Ini memfilter string kosong atau hanya spasi,
    /// memformat nama semester menggunakan `formatSemesterName`, dan memastikan
    /// bahwa "Semester 1" dan "Semester 2" selalu disertakan dalam daftar hasil.
    /// Daftar semester yang dihasilkan diurutkan secara alfabetis.
    ///
    /// - Parameter tableName: Nama tabel (`String`) untuk mengambil data semester.
    /// - Returns: Sebuah array berisi string unik yang mewakili semester, diurutkan secara alfabetis.
    func fetchSemesters(fromTable tableName: String) -> [String] {
        var semesters: Set<String> = []
        let query = "SELECT DISTINCT semester FROM \"\(tableName)\""
        // Debugging line to check the query
        do {
            for row in try db.prepare(query) {
                if let semester = row[0] as? String, !semester.trimmingCharacters(in: .whitespaces).isEmpty {
                    let formattedSemester = ReusableFunc.formatSemesterName(semester)
                    semesters.insert(formattedSemester)
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        // Menambahkan "Semester 1" dan "Semester 2" jika belum ada
        if !semesters.contains("Semester 1") {
            semesters.insert("Semester 1")
        }
        if !semesters.contains("Semester 2") {
            semesters.insert("Semester 2")
        }

        return Array(semesters).sorted()
    }

    /// Ambil data KelasModels dari tabel sesuai `TableType` untuk `siswaID`
    /// - Parameters:
    ///   - type: `TableType` untuk kelas yang akan diambil datanya.
    ///   - siswaID: ID siswa yang ada di kelas.
    /// - Returns: Data yang didapatkan dari database.
    func getKelas(_ type: TableType, siswaID: Int64) async -> [KelasModels] {
        let tbl = type.table
        let colKelasID = kelasId
        let colSiswaID = siswa_id

        var result = [KelasModels]()
        do {
            let rows = try await DatabaseManager.shared.pool.read { db in
                let filteredKelas = try db.prepare(tbl.filter(colSiswaID == siswaID))
                return filteredKelas
            }

            await withTaskGroup(of: KelasModels?.self) { group in
                for row in rows {
                    group.addTask(priority: .background) {
                        // skip jika siswa atau relasi terhapus
                        let removedSiswa = SingletonData.deletedStudentIDs.contains(siswaID)
                        let removedRel = SingletonData.deletedKelasAndSiswaIDs
                            .flatMap { $0 }
                            .contains { $0.kelasID == row[colKelasID] && $0.siswaID == siswaID }

                        guard !removedSiswa, !removedRel else { return nil }
                        return KelasModels(row: row)
                    }
                }
                // Collect results from the task group
                for await kelasModel in group {
                    if let kelasModel = kelasModel {
                        result.append(kelasModel)
                    }
                }
            }
        } catch {
            #if DEBUG
                print("DB fetch error:", error.localizedDescription)
            #endif
        }
        return result
    }

    /// Algoritma untuk membaca data di  semua tabel Kelas yang ada di database secara konkuren untuk siswa tertentu dan mendapatkan datanya sebagai model `[KelasModels]`.
    /// - Parameter siswaID: memfilter sesuai dengan siswaID
    /// - Returns: Mengirim data yang dibaca sebagai model `[KelasModels]` yang sesuai enum ``TableType`` ke class yang memanggil.
    func getAllKelas(for siswaID: Int64) async -> [TableType: [KelasModels]] {
        await withTaskGroup(of: (TableType, [KelasModels]).self) { [unowned self] group in
            // 1) Spawn satu child task per TableType
            for type in TableType.allCases {
                group.addTask {
                    let data = await self.getKelas(type, siswaID: siswaID)
                    return (type, data)
                }
            }

            // 2) Kumpulkan hasilnya
            var result: [TableType: [KelasModels]] = [:]
            for await (type, data) in group {
                result[type] = data
            }
            return result
        }
    }

    /// Mengambil data kelas berdasarkan ID dari tabel yang ditentukan.
    ///
    /// Fungsi ini melakukan query pada tabel `TableType` untuk mencari baris dengan
    /// `kelasID` tertentu. Jika ditemukan, akan dikembalikan objek `KelasModels`
    /// yang diinisialisasi dari baris tersebut. Jika tidak ditemukan atau terjadi error,
    /// fungsi akan mengembalikan `nil`.
    ///
    /// - Parameters:
    ///   - tabel: Tipe tabel yang akan diakses, dibungkus dalam enum `TableType`.
    ///   - kelasID: Nilai ID unik dari kelas yang ingin diambil datanya.
    /// - Returns: Objek `KelasModels` jika ditemukan, atau `nil` jika tidak ada atau terjadi kesalahan.
    ///
    /// - Warning:
    ///   Kesalahan saat eksekusi query akan dicetak ke konsol melalui `print(error.localizedDescription)`.
    func getKelasData(for tabel: TableType, kelasID: Int64) -> KelasModels? {
        let tbl = tabel.table
        let query = tbl.filter(kelasId == kelasID)
        do {
            if let firstRow = try db.pluck(query) {
                return KelasModels(row: firstRow)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return nil
    }

    /// Menghapus nama siswa dari baris tertentu dalam tabel yang diberikan dengan mengatur kolom `namasiswa` menjadi `nil`.
    ///
    /// Fungsi ini menargetkan baris dalam `tabel` yang sesuai dengan `siswaID` yang diberikan
    /// dan mengatur nilai kolom `namasiswa` menjadi `nil`. Ini secara efektif "menghapus" nama siswa
    /// tanpa menghapus seluruh baris.
    ///
    /// - Parameters:
    ///   - tabel: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - siswaID: ID siswa (`Int64`) yang namanya ingin dihapus atau disetel ke `nil`.
    public func hapusSiswa(fromTabel tabel: Table, siswaID: Int64) {
        do {
            let dataSiswa = tabel.filter(siswa_id == siswaID)
            try db.run(dataSiswa.update(namasiswa <- nil as String?))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus data kelas dari tabel yang ditentukan dengan mengatur kolom `namasiswa` menjadi `nil`.
    ///
    /// Fungsi ini menargetkan baris dalam `tabel` yang sesuai dengan `kelasID` yang diberikan
    /// dan mengatur nilai kolom `namasiswa` menjadi `nil`. Ini secara efektif "menghapus" nama siswa
    /// dari entri kelas tanpa menghapus seluruh baris.
    ///
    /// - Parameters:
    ///   - kelasID: ID unik dari entri kelas (`Int64`) yang datanya ingin dihapus atau disetel ke `nil`.
    ///   - tabel: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    public func hapusDataKelas(kelasID: Int64, fromTabel tabel: Table) {
        do {
            let dataSiswa = tabel.filter(kelasId == kelasID)
            try db.run(dataSiswa.update(namasiswa <- nil as String?))
        } catch {}
    }

    /// Mengembalikan nama siswa yang sebelumnya dihapus atau disetel ke `nil` dalam entri kelas.
    ///
    /// Fungsi ini menargetkan baris dalam `tabel` yang sesuai dengan `kelasID` yang diberikan
    /// dan mengembalikan nilai kolom `namasiswa` ke `String` yang disediakan. Ini berfungsi
    /// sebagai operasi "undo" untuk fungsi `hapusDataKelas`.
    ///
    /// - Parameters:
    ///   - kelasID: ID unik dari entri kelas (`Int64`) yang namanya ingin dikembalikan.
    ///   - tabel: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - siswa: Nama siswa (`String`) yang akan dikembalikan ke kolom `namasiswa`.
    public func undoHapusDataKelas(kelasID: Int64, fromTabel tabel: Table, siswa: String) {
        do {
            let dataSiswa = tabel.filter(kelasId == kelasID)
            try db.run(dataSiswa.update(namasiswa <- siswa))
        } catch {}
    }

    /// Menghapus data dari tabel kelas yang ditentukan berdasarkan ID kelas.
    ///
    /// Fungsi ini menargetkan dan menghapus seluruh baris dari `table`
    /// di mana `kelasId` cocok dengan `kelasID` yang diberikan.
    ///
    /// - Parameters:
    ///   - table: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - kelasID: ID unik dari entri kelas (`Int64`) yang ingin dihapus.
    func deleteDataFromKelas(table: Table, kelasID: Int64) {
        do {
            let filter = table.filter(kelasId == kelasID)
            try db.run(filter.delete())
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus nilai dari entri kelas tertentu dalam tabel yang ditentukan.
    ///
    /// Fungsi ini menargetkan baris dalam `table` yang sesuai dengan `kelasID` yang diberikan
    /// dan mengatur nilai kolom `nilai` menjadi `nil`. Ini secara efektif menghapus nilai
    /// tanpa menghapus seluruh catatan kelas.
    ///
    /// - Parameters:
    ///   - table: Objek `Table` yang merepresentasikan tabel kelas target (misalnya, `kelas1`, `kelas2`, dst.).
    ///   - kelasID: ID unik dari entri kelas (`Int64`) yang nilainya ingin dihapus.
    func deleteNilaiFromKelas(table: Table, kelasID: Int64) {
        do {
            let filter = table.filter(kelasId == kelasID)

            // Update kolom nilai menjadi nil
            try db.run(filter.update(nilai <- nil))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menandai seorang siswa sebagai "lulus" atau berpindah ke kelas berikutnya.
    ///
    /// Fungsi ini memperbarui entri siswa di database dengan mengatur statusnya ke `kelasBerikutnya` (yang mengindikasikan kelulusan atau perpindahan),
    /// mencatat tanggal saat ini sebagai `tanggalberhenti`, dan memperbarui `kelasSekarang` siswa ke `kelasBerikutnya`.
    /// Perubahan ini dilakukan dalam sebuah transaksi database untuk memastikan atomisitas.
    ///
    /// - Parameters:
    ///   - namaSiswa: Nama siswa (`String`) yang akan diluluskan. (Perhatikan: parameter ini ada di fungsi, tetapi tidak digunakan dalam implementasi saat ini.)
    ///   - siswaID: ID unik siswa (`Int64`) yang akan diperbarui.
    ///   - kelasBerikutnya: String (`String`) yang menunjukkan status atau kelas baru siswa (misalnya, "Lulus", "Kelas 7", dll.).
    func siswaLulus(namaSiswa: String, siswaID: Int64, kelasBerikutnya: String) {
        do {
            try db.transaction {
                // Mengupdate kolom kelasSekarang di tabel siswa
                let tglsekarang = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                let tanggalSekarang = dateFormatter.string(from: tglsekarang)
                let updateSiswaQuery = siswa.filter(Expression<Int64>("id") == siswaID).update(
                    status <- kelasBerikutnya,
                    tanggalberhenti <- tanggalSekarang,
                    kelasSekarang <- kelasBerikutnya
                )
                try db.run(updateSiswaQuery)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Mengedit status kelulusan atau kelas berikutnya untuk seorang siswa.
    ///
    /// Fungsi ini memperbarui entri siswa di database dengan mengatur status dan `kelasSekarang` ke nilai `kelasBerikutnya` yang diberikan.
    /// Perubahan ini dilakukan dalam sebuah transaksi database untuk memastikan atomisitas.
    ///
    /// - Parameters:
    ///   - namaSiswa: Nama siswa (`String`) yang akan diedit status kelulusannya. (Parameter ini ada di fungsi, tetapi tidak digunakan dalam implementasi saat ini.)
    ///   - siswaID: ID unik siswa (`Int64`) yang akan diperbarui.
    ///   - kelasBerikutnya: `String` yang menunjukkan status atau kelas baru siswa (misalnya, "Lulus", dll.).
    func editSiswaLulus(namaSiswa: String, siswaID: Int64, kelasBerikutnya: String) {
        do {
            try db.transaction {
                // Mengupdate kolom kelasSekarang di tabel siswa
                let updateSiswaQuery = siswa.filter(Expression<Int64>("id") == siswaID).update(
                    status <- kelasBerikutnya,
                    kelasSekarang <- kelasBerikutnya
                )
                try db.run(updateSiswaQuery)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Memperbarui status kelas siswa dan mengelola tumpukan "undo" untuk operasi kenaikan kelas.
    ///
    /// Fungsi ini dirancang untuk menandai bahwa seorang siswa akan naik kelas atau statusnya akan diubah.
    /// Fungsi ini memeriksa apakah siswa tersebut sudah ada dalam daftar siswa yang akan naik kelas (`SingletonData.siswaNaikId`).
    /// Jika belum, fungsi ini akan:
    /// 1. Memanggil `updateUndoStackKelas` secara asinkron untuk mencatat status kelas siswa saat ini (`kelasAwal`) untuk tujuan "undo".
    /// 2. Menambahkan informasi siswa (ID, kelas awal, dan kelas yang dikecualikan) ke `SingletonData.siswaNaikArray`.
    /// 3. Menambahkan ID siswa ke `SingletonData.siswaNaikId` untuk mencegah penambahan duplikat.
    ///
    /// - Parameters:
    ///   - idSiswa: ID unik siswa (`Int64`) yang status kelasnya akan diperbarui.
    ///   - kelasAwal: String (`String`) yang merepresentasikan kelas atau status siswa saat ini sebelum perubahan.
    ///   - kelasYangDikecualikan: String (`String`) yang merepresentasikan kelas yang harus dikecualikan
    ///                             atau kelas tujuan siswa, diformat menjadi huruf kecil dan tanpa spasi.
    func updateTabelKelasAktif(idSiswa: Int64, kelasAwal: String, kelasYangDikecualikan: String) {
        if !SingletonData.siswaNaikId.contains(idSiswa) {
            Task { [weak self] in
                guard let self else { return }
                await self.updateUndoStackKelas(idSiswa: idSiswa, kelas: kelasAwal)
                SingletonData.siswaNaikArray.append((siswaID: [idSiswa], kelasAwal: [kelasAwal], kelasDikecualikan: [kelasYangDikecualikan.lowercased().replacingOccurrences(of: " ", with: "")]))
                SingletonData.siswaNaikId.append(idSiswa)
            }
        }
    }

    /// Memperbarui tumpukan "undo" untuk operasi yang melibatkan data kelas siswa.
    ///
    /// Fungsi ini dirancang untuk menyimpan salinan data siswa dari tabel kelas tertentu
    /// ke dalam `SingletonData.undoStack` sebelum perubahan dilakukan, memungkinkan operasi "undo" di kemudian hari.
    /// Ini mengambil data siswa hanya jika tabel kelas yang sesuai belum dimuat (`SingletonData.tableXdimuat`).
    /// Kemudian, ia menyaring data siswa berdasarkan `idSiswa` dan menambahkannya ke tumpukan undo yang relevan
    /// hanya jika siswa tersebut belum ada di tumpukan undo untuk kelas tersebut.
    ///
    /// - Parameters:
    ///   - idSiswa: ID unik siswa (`Int64`) yang datanya perlu disimpan untuk operasi "undo".
    ///   - kelas: String (`String`) yang menunjukkan nama kelas siswa (misalnya, "Kelas 1", "Kelas 2", dst.).
    func updateUndoStackKelas(idSiswa: Int64, kelas: String) async {
        var allKelasModels: [String: [KelasModels]] = [:]

        switch kelas {
        case "Kelas 1":
            guard !SingletonData.table1dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas1)]
        case "Kelas 2":
            guard !SingletonData.table2dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas2)]
        case "Kelas 3":
            guard !SingletonData.table3dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas3)]
        case "Kelas 4":
            guard !SingletonData.table4dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas4)]
        case "Kelas 5":
            guard !SingletonData.table5dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas5)]
        case "Kelas 6":
            guard !SingletonData.table6dimuat else { return }
            allKelasModels = await [kelas: getAllKelas(ofType: TableType.kelas6)]
        default:
            break
        }
        for (kelasSekarang, kelasModels) in allKelasModels {
            guard !kelasModels.isEmpty else { continue }

            let siswaData = kelasModels.filter { $0.siswaID == idSiswa }

            if !siswaData.isEmpty {
                if SingletonData.undoStack[kelasSekarang] == nil {
                    SingletonData.undoStack[kelasSekarang] = []
                }

                let existingSiswaIDs = SingletonData.undoStack[kelasSekarang]?.flatMap { $0 }.map(\.siswaID) ?? []

                let newSiswaData = siswaData.filter { !existingSiswaIDs.contains($0.siswaID) }

                if !newSiswaData.isEmpty {
                    let copies = newSiswaData.map { $0.copy() as! KelasModels }
                    SingletonData.undoStack[kelasSekarang]?.append(copies)
                }
            }
        }
    }

    /// Memproses daftar siswa yang akan naik kelas dengan memperbarui nama siswa di tabel kelas.
    ///
    /// Fungsi ini mengiterasi `SingletonData.siswaNaikArray`, yang berisi informasi tentang siswa
    /// yang akan naik kelas. Untuk setiap siswa, fungsi ini akan mengatur kolom `namasiswa` menjadi `nil`
    /// di semua tabel kelas **kecuali** tabel yang ditentukan dalam `kelasYangDikecualikan`.
    /// Hal ini dilakukan dalam sebuah transaksi database untuk memastikan konsistensi.
    ///
    /// - Catatan: Parameter `kelasAwal` dalam `siswa` yang diambil dari `SingletonData.siswaNaikArray`
    ///            saat ini tidak digunakan dalam implementasi fungsi ini.
    func processSiswaNaik() {
        for siswa in SingletonData.siswaNaikArray {
            // Ambil siswaID, kelasAwal, dan kelasDikecualikan dari tuple
            let idSiswa = siswa.siswaID.first
            _ = siswa.kelasAwal.first // Mengambil kelas awal pertama jika ada
            let kelasYangDikecualikan = siswa.kelasDikecualikan.first
            do {
                // Collect all table instances except the one to be excluded
                let semuaKelas: [String: Table] = [
                    "kelas1": kelas1,
                    "kelas2": kelas2,
                    "kelas3": kelas3,
                    "kelas4": kelas4,
                    "kelas5": kelas5,
                    "kelas6": kelas6,
                ]

                // Filter the tables based on the excluded class
                let kelasTable = semuaKelas
                    .filter { $0.key != kelasYangDikecualikan }
                    .map(\.value)

                try db.transaction {
                    // Check if the student with the given ID exists in any of the classes
                    let existingSiswa = kelasTable
                        .compactMap { table in
                            try? db.pluck(table.filter(siswa_id == idSiswa!))
                        }

                    if existingSiswa.count > 0 {
                        // If the student exists in any of the classes, update the namasiswa column to nil
                        for table in kelasTable {
                            let updateQuery = table
                                .filter(siswa_id == idSiswa!).update(namasiswa <- nil as String?)
                            try db.run(updateQuery)
                        }
                    } else {}
                }
            } catch {}
        }
    }

    /// Melakukan pencarian asinkron pada tabel kelas generik berdasarkan kueri yang diberikan.
    ///
    /// Fungsi ini memfilter catatan dalam `table` yang disediakan di mana `namasiswa`, `mapel`,
    /// atau `namaguru` cocok dengan `query` (tidak peka huruf besar/kecil).
    /// Ini juga mengecualikan catatan yang `kelasId` atau kombinasi `kelasId` dan `siswa_id` mereka
    /// ada dalam daftar ID yang dihapus sementara (`SingletonData.deletedStudentIDs` atau `SingletonData.deletedKelasAndSiswaIDs`).
    /// Data yang cocok kemudian diubah menjadi instance `modelType` yang diberikan.
    /// Pemrosesan data dilakukan secara konkuren menggunakan `TaskGroup` untuk meningkatkan performa.
    ///
    /// - Parameters:
    ///   - query: `String` yang berisi kueri pencarian.
    ///   - table: Objek `Table` dari SQLite.swift yang merepresentasikan tabel kelas target (misalnya, `self.kelas1`).
    /// - Returns: Sebuah array berisi objek `T` yang sesuai dengan kriteria pencarian dan filter.
    ///            Akan mengembalikan array kosong jika tidak ada data yang ditemukan atau terjadi kesalahan.
    func searchGenericModels<T: KelasModels>(
        query: String,
        table: Table // Pass the specific SQLite.swift Table object (e.g., self.kelas1)
    ) async -> [T] {
        var pencarianSiswa: [T] = []
        let lowercasedQuery = query.lowercased() // Lowercase query once for efficiency

        // Adjust the filter logic if your ORM handles lowercase differently.
        // For SQLite.swift, LIKE is often case-insensitive for ASCII by default.
        // Using lower() SQL function for explicit case-insensitivity is more robust.
        // Expression<String>("lower(namasiswa_column_name)").like(...)
        // The original code uses `.lowercaseString.like()`, which might be an extension.
        // We'll assume `Expression` has a `lowercaseString` property returning another `Expression`.
        let filteredTable = table.filter(
            namasiswa.lowercaseString.like("%\(lowercasedQuery)%") || // Assumes .lowercaseString exists on Expression
                mapel.lowercaseString.like("%\(lowercasedQuery)%") ||
                namaguru.lowercaseString.like("%\(lowercasedQuery)%")
        )

        do {
            let preparedStatement = try db.prepare(filteredTable)
            pencarianSiswa = await withTaskGroup(of: T?.self) { [weak self] group in
                guard let strongSelf = self else { return [] } // Capture self weakly

                for row in preparedStatement {
                    guard let currentNamaSiswa = row[strongSelf.namasiswa], !currentNamaSiswa.isEmpty else {
                        continue
                    }

                    group.addTask(priority: .background) {
                        // Ensure SingletonData related IDs are of the same type as row[column] (e.g., String)
                        if !SingletonData.deletedStudentIDs.contains(row[strongSelf.kelasId]),
                           !SingletonData.deletedKelasAndSiswaIDs.contains(where: { innerArray in
                               innerArray.contains { item in
                                   item.kelasID == row[strongSelf.kelasId] && item.siswaID == row[strongSelf.siswa_id]
                               }
                           })
                        {
                            return T(row: row)
                        }
                        return nil
                    }
                }

                var results: [T] = []
                for await siswaOptional in group {
                    if let siswa = siswaOptional {
                        results.append(siswa)
                    }
                }
                return results
            }
        } catch {
            #if DEBUG
                print("Database error in searchGenericModels: \(error.localizedDescription)")
            #endif
        }
        return pencarianSiswa
    }

    // MARK: - PRINT KELAS DATA

    /// Mengambil data kelas yang sesuai nama func yang memenuhi kriteria tertentu untuk tujuan pencetakan.
    ///
    /// Fungsi ini mengambil semua baris dari tabel `kelas` tertentu yang sesuai dengan nama func di mana kolom `namasiswa`
    /// tidak kosong dan tidak `nil`. Setiap baris yang cocok kemudian dipetakan ke objek `KelasPrint`.
    /// Jika nilai untuk kolom `nilai` adalah `nil`, properti `nilai` di `KelasPrint` akan diatur ke string kosong.
    ///
    /// - Returns: Sebuah array berisi objek `KelasPrint` yang mewakili data kelas 1 yang difilter.
    func getKelasPrint(table: Table) -> [KelasPrint] {
        var kelasData = [KelasPrint]()
        do {
            let filteredKelas = table.filter(namasiswa != "" && namasiswa != nil)

            for row in try db.prepare(filteredKelas) {
                let kelasModel = KelasPrint()
                kelasModel.mapel = row[mapel]
                if let nilai = row[nilai] {
                    // Jika tidak nil, gunakan nilai tersebut
                    kelasModel.nilai = String(nilai)
                } else {
                    // Jika nil, atur nilai ke string kosong
                    kelasModel.nilai = ""
                }
                kelasModel.namasiswa = row[namasiswa] ?? ""
                kelasModel.namaguru = row[namaguru]
                kelasModel.semester = row[semester]

                kelasData.append(kelasModel)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return kelasData
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
    public func getAllDataForAutoCompletion() -> [AutoCompletion] {
        var result: [AutoCompletion] = []
        var namaGuruSet: Set<String> = []

        // Ambil data dari tabel siswa
        do {
            let siswaData = try db.prepare(siswa)
            for user in siswaData {
                var autoCompleteItem = AutoCompletion()
                autoCompleteItem.namasiswa = cleanString(user[nama])
                autoCompleteItem.alamat = cleanString(user[alamat])
                autoCompleteItem.ayah = cleanString(user[ayah])
                autoCompleteItem.ibu = cleanString(user[ibu])
                autoCompleteItem.wali = cleanString(user[namawali])
                autoCompleteItem.nis = cleanString(user[nis])
                autoCompleteItem.nisn = cleanString(user[nisn])
                autoCompleteItem.tlv = cleanString(user[tlv])
                autoCompleteItem.tanggallahir = cleanString(user[ttl])
                result.append(autoCompleteItem)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        // Ambil data dari tabel guru
        do {
            let guruData = try db.prepare(guru)
            for user in guruData {
                var autoCompleteItem = AutoCompletion() // Buat item baru untuk guru
                autoCompleteItem.alamat = cleanString(user[alamatGuru])
                autoCompleteItem.jabatan = cleanString(user[struktural])
                if !namaGuruSet.contains(user[namaGuru]) { // Periksa apakah nama guru sudah ada
                    autoCompleteItem.namaguru = cleanString(user[namaGuru])
                    namaGuruSet.insert(user[namaGuru])
                }
                autoCompleteItem.mapel = cleanString(user[mapel])
                result.append(autoCompleteItem) // Tambahkan ke hasil
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        // Ambil data dari semua tabel kelas (kelas1 hingga kelas6)
        let kelasTables: [Table] = [kelas1, kelas2, kelas3, kelas4, kelas5, kelas6]

        for kelasTable in kelasTables {
            do {
                let kelasData = try db.prepare(kelasTable)
                for user in kelasData {
                    var autoCompleteItem = AutoCompletion()
                    autoCompleteItem.mapel = cleanString(user[mapel])

                    let namaGuruKelas = user[namaguru] // Ambil nama guru dari kelas
                    autoCompleteItem.semester = cleanString(user[semester])
                    // Periksa apakah nama guru sudah ada di set
                    if !namaGuruSet.contains(namaGuruKelas) {
                        autoCompleteItem.namaguru = cleanString(namaGuruKelas)
                        namaGuruSet.insert(namaGuruKelas) // Tambahkan nama guru ke set
                    }
                    result.append(autoCompleteItem) // Tambahkan ke hasil
                }
            } catch {}
        }
        return result
    }

    /// Lihat: ``DynamicTable/vacuumDatabase()``
    func vacuumDatabase() {
        do {
            try db.run("VACUUM")

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
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
