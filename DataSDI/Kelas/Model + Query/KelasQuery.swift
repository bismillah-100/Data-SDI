//
//  KelasQuery.swift
//  Data SDI
//
//  Created by MacBook on 13/07/25.
//

import SQLite

extension DatabaseController {
    /// Daftar kolom yang dipilih untuk query terkait kelas.
    /// Kolom-kolom ini mencakup informasi siswa, guru, mata pelajaran, nilai, dan detail kelas.
    /// Digunakan untuk membangun query yang mengambil data lengkap terkait nilai siswa dalam suatu kelas.
    /// - Kolom yang diambil antara lain:
    ///   - ID nilai siswa mapel
    ///   - ID dan nama siswa
    ///   - Nama mata pelajaran
    ///   - Nilai siswa
    ///   - Nama guru
    ///   - Semester, tingkat, nama, dan tahun ajaran kelas
    ///   - Tanggal nilai diberikan
    ///   - Status enrollment siswa dalam kelas
    private var selectedKelasColumns: [any Expressible] {
        [
            TabelNilai.tabel[TabelNilai.id],
            TabelNilai.tabel[TabelNilai.nilai],
            TabelNilai.tabel[TabelNilai.tanggalNilai],
            SiswaColumns.tabel[SiswaColumns.id],
            SiswaColumns.tabel[SiswaColumns.nama],
            MapelColumns.tabel[MapelColumns.nama],
            GuruColumns.tabel[GuruColumns.id],
            GuruColumns.tabel[GuruColumns.nama],
            TabelTugas.tabel[TabelTugas.id],
            KelasColumns.tabel[KelasColumns.semester],
            KelasColumns.tabel[KelasColumns.tingkat],
            KelasColumns.tabel[KelasColumns.tahunAjaran],
            SiswaKelasColumns.tabel[SiswaKelasColumns.statusEnrollment],
        ]
    }

    /// Menyisipkan data nilai seorang siswa untuk suatu mata pelajaran di kelas tertentu.
    /// Fungsi ini akan memastikan semua entitas terkait (siswa, guru, mapel, kelas, siswa-kelas) ada,
    /// dan kemudian menyisipkan catatan nilai.
    ///
    /// - Parameters:
    ///   - siswaID: ID Siswa. Diasumsikan siswa sudah ada di tabel `siswa`.
    ///   - namaSiswa: Nama siswa. Digunakan jika siswaID belum ada (untuk insert baru).
    ///   - mapelID: ID Mata Pelajaran. Diasumsikan mapel sudah ada di tabel `mapel`.
    ///   - guruID: ID Guru. Diasumsikan guru sudah ada di tabel `guru`.
    ///   - nilai: Nilai yang akan dimasukkan.
    ///   - tingkatKelas: Tingkat kelas siswa (e.g., "1", "2").
    ///   - namaKelas: Nama kelas siswa (e.g., "1A").
    ///   - tahunAjaran: Tahun ajaran (e.g., "2024/2025").
    ///   - semester: Semester (e.g., "Ganjil", "Genap").
    ///   - TabelNilai.tanggalNilai: Tanggal pemberian nilai.
    /// - Returns: ID dari catatan nilai yang baru disisipkan di `nilai_siswa_mapel` atau `nil` jika gagal.
    func insertNilaiSiswa(siswaID: Int64, namaSiswa: String, penugasanGuruID: Int64, nilai: Int, tingkatKelas: String, namaKelas: String, tahunAjaran: String, semester: String, tanggalNilai: String, status: StatusSiswa) async -> Int64? {
        do {
            // --- 1. Pastikan Siswa Ada ---
            var finalSiswaID: Int64 = siswaID
            if try db.pluck(SiswaColumns.tabel.filter(SiswaColumns.id == siswaID)) == nil {
                // Siswa tidak ditemukan, sisipkan siswa baru (atau gunakan ID jika 0 untuk auto-increment)
                let insertSiswa = SiswaColumns.tabel.insert(
                    SiswaColumns.nama <- namaSiswa,
                    SiswaColumns.ttl <- "", // Tambahkan ini sesuai kebutuhan
                    SiswaColumns.alamat <- "",
                    SiswaColumns.jeniskelamin <- JenisKelamin.lakiLaki.rawValue,
                    SiswaColumns.status <- StatusSiswa.aktif.rawValue
                )
                finalSiswaID = try db.run(insertSiswa)
                #if DEBUG
                    print("Siswa baru '\(namaSiswa)' disisipkan dengan ID: \(finalSiswaID)")
                #endif
            }

            // --- 3. Pastikan Kelas Ada ---
            var kelasRecordID: Int64
            if let existingKelas = try db.pluck(KelasColumns.tabel.filter(
                KelasColumns.tingkat == tingkatKelas &&
                    KelasColumns.nama == namaKelas &&
                    KelasColumns.tahunAjaran == tahunAjaran &&
                    KelasColumns.semester == semester
            )) {
                kelasRecordID = existingKelas[KelasColumns.id]
                #if DEBUG
                    print("Kelas '\(namaKelas) (\(tingkatKelas)) \(tahunAjaran) \(semester)' ditemukan dengan ID: \(kelasRecordID)")
                #endif
            } else {
                // Kelas tidak ditemukan, sisipkan kelas baru
                let insertKelas = KelasColumns.tabel.insert(
                    KelasColumns.nama <- namaKelas,
                    KelasColumns.tingkat <- tingkatKelas,
                    KelasColumns.tahunAjaran <- tahunAjaran,
                    KelasColumns.semester <- semester
                )
                kelasRecordID = try db.run(insertKelas)
                #if DEBUG
                    print("Kelas baru '\(namaKelas) (\(tingkatKelas)) \(tahunAjaran) \(semester)' disisipkan dengan ID: \(kelasRecordID)")
                #endif
            }

            // --- 4. Pastikan Relasi Siswa-Kelas Ada ---
            var siswaKelasRecordID: Int64
            if let existingSiswaKelas = try db.pluck(SiswaKelasColumns.tabel.filter(
                SiswaKelasColumns.idSiswa == finalSiswaID &&
                    SiswaKelasColumns.idKelas == kelasRecordID
            )) {
                siswaKelasRecordID = existingSiswaKelas[SiswaKelasColumns.id]
                #if DEBUG
                    print("Relasi Siswa-Kelas (Siswa: \(finalSiswaID), Kelas: \(kelasRecordID)) ditemukan dengan ID: \(siswaKelasRecordID)")
                #endif
            } else {
                // Relasi siswa-kelas tidak ditemukan, sisipkan
                guard let siswaKelasID = insertSiswaKelas(siswaId: finalSiswaID, inToKelas: kelasRecordID, tanggalMasuk: tanggalNilai, status: status) else {
                    return nil
                }
                siswaKelasRecordID = siswaKelasID
                #if DEBUG
                    print("Relasi Siswa-Kelas baru disisipkan dengan ID: \(siswaKelasRecordID)")
                #endif
            }

            // --- 5. Sisipkan Catatan Nilai ---
            let insertNilai = TabelNilai.tabel.insert(
                TabelNilai.idSiswaKelas <- siswaKelasRecordID,
                TabelNilai.idPenugasanGuruMapelKelas <- penugasanGuruID,
                TabelNilai.nilai <- nilai,
                TabelNilai.tanggalNilai <- tanggalNilai
            )
            return executeInsert(insertNilai)
        } catch {
            #if DEBUG
                print("Error saat menyisipkan nilai siswa: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Membangun query SQL dengan melakukan join pada beberapa tabel terkait data kelas, siswa, guru, dan mapel.
    ///
    /// - Parameters:
    ///   - type: Tipe tabel yang menentukan tingkat kelas yang akan difilter.
    ///   - siswaID: (Opsional) ID siswa yang ingin difilter. Jika nil, tidak ada filter berdasarkan ID siswa.
    ///   - tahunAjaran: opsional filter tahun ajaran.
    ///   - semester: opsional filter semester.
    ///   - bagian: opsional filter bagian kelas.
    ///   - excludeSiswaIDs: opsional filter siswaID.
    ///   - excludeKelasSiswaPairs: opsional filter nilaiID dan siswaID.
    ///   - excludeNilaiIDs: Filter nilaiID.
    ///   - status: (Opsional) Status enrollment siswa pada kelas. Jika nil, tidak ada filter berdasarkan status enrollment.
    ///   - queryText: (Opsional) untuk mencari data sesuai string.`
    /// - Throws: Melempar error jika terjadi kegagalan dalam membangun query.
    /// - Returns: QueryType hasil join dan filter sesuai parameter yang diberikan, dengan kolom-kolom yang telah dipilih.
    func buildKelasJoinQuery(
        type: TableType,
        siswaID: Int64? = nil,
        tahunAjaran: String? = nil,
        semester: String? = nil,
        bagian: String? = nil,
        status: StatusSiswa? = nil,
        queryText: String? = nil,
        excludeSiswaIDs: Set<Int64>,
        excludeKelasSiswaPairs: [(nilaiID: Int64, siswaID: Int64)],
        excludeNilaiIDs: Set<Int64>
    ) throws -> QueryType {
        // =================================================================
        // LANGKAH 1: Cari Tahu Tahun Ajaran Aktif secara Otomatis
        // =================================================================
        var autoFilterTahunAjaran: Set<String> = []

        // Hanya cari tahun ajaran otomatis jika pengguna TIDAK menyediakannya
        if tahunAjaran == nil, siswaID == nil {
            // Kueri sekarang mengumpulkan semua tahun ajaran yang memiliki entri aktif
            let subquery = SiswaKelasColumns.tabel
                .join(KelasColumns.tabel, on: KelasColumns.tabel[KelasColumns.id] == SiswaKelasColumns.tabel[SiswaKelasColumns.idKelas])
                .filter(SiswaKelasColumns.tabel[
                    SiswaKelasColumns.statusEnrollment
                ] == StatusSiswa.aktif.rawValue &&
                    KelasColumns.tabel[KelasColumns.tingkat] == type.tingkatKelasString)
                .select(distinct: true, KelasColumns.tabel[KelasColumns.tahunAjaran])

            // Mengubah hasil kueri menjadi array
            for row in try db.prepare(subquery) {
                autoFilterTahunAjaran.insert(row[KelasColumns.tabel[KelasColumns.tahunAjaran]])
            }
        }

        var query = SiswaKelasColumns.tabel
            .join(KelasColumns.tabel, on:
                KelasColumns.tabel[KelasColumns.id] == SiswaKelasColumns.tabel[SiswaKelasColumns.idKelas])
            .join(SiswaColumns.tabel, on:
                SiswaColumns.tabel[SiswaColumns.id] == SiswaKelasColumns.tabel[SiswaKelasColumns.idSiswa])
            .filter(KelasColumns.tabel[KelasColumns.tingkat] == type.tingkatKelasString)

        // apply tahun ajaran (user > auto) sama seperti di atas
        // apply siswaID/bagian/semester sama seperti di atas

        // LEFT JOIN ke nilai & relasi lainnya
        query = query
            .join(TabelNilai.tabel, on:
                TabelNilai.tabel[TabelNilai.idSiswaKelas] == SiswaKelasColumns.tabel[SiswaKelasColumns.id])
            .join(PenugasanGuruMapelKelasColumns.tabel, on:
                PenugasanGuruMapelKelasColumns.tabel[PenugasanGuruMapelKelasColumns.id] == TabelNilai.tabel[TabelNilai.idPenugasanGuruMapelKelas])
            .join(MapelColumns.tabel, on:
                MapelColumns.tabel[MapelColumns.id] == PenugasanGuruMapelKelasColumns.tabel[PenugasanGuruMapelKelasColumns.idMapel])
            .join(GuruColumns.tabel, on:
                GuruColumns.tabel[GuruColumns.id] == PenugasanGuruMapelKelasColumns.tabel[PenugasanGuruMapelKelasColumns.idGuru])

        // 3. Tambahkan full-text + exclusion
        if let q = queryText?.lowercased(), !q.isEmpty {
            let pattern = "%\(q)%"

            var filters: [Expression<Bool>] = [
                SiswaColumns.tabel[SiswaColumns.nama].lowercaseString.like(pattern),
                MapelColumns.tabel[MapelColumns.nama].lowercaseString.like(pattern),
                GuruColumns.tabel[GuruColumns.nama].lowercaseString.like(pattern),
                KelasColumns.tabel[KelasColumns.tahunAjaran].lowercaseString.like(pattern),
            ]

            if let intQuery = Int(q) {
                filters.append((TabelNilai.tabel[TabelNilai.nilai] ?? -1) == intQuery)
            }

            if !filters.isEmpty {
                let combinedFilter = filters.dropFirst().reduce(filters[0]) { $0 || $1 }
                query = query.filter(combinedFilter)
            }
        }

        // Gunakan filter dari pengguna jika ada, jika tidak, gunakan filter otomatis
        let finalTahunAjaranFilter: [String] = if let userTahunAjaran = tahunAjaran {
            [userTahunAjaran]
        } else {
            Array(autoFilterTahunAjaran)
        }

        // Tambahkan filter IN pada kueri utama untuk mengizinkan multiple tahun ajaran
        if !finalTahunAjaranFilter.isEmpty {
            query = query.filter(finalTahunAjaranFilter.contains(KelasColumns.tabel[KelasColumns.tahunAjaran]))
        }

        if tahunAjaran == nil, siswaID == nil {
            query = query.filter(SiswaColumns.tabel[SiswaColumns.status] == StatusSiswa.aktif.rawValue)
        }

        if let siswaID {
            query = query.filter(
                SiswaColumns.tabel[SiswaColumns.id] == siswaID
            )
        }
        if let bagian {
            query = query.filter(KelasColumns.tabel[KelasColumns.nama] == bagian)
        }
        if let semester {
            query = query.filter(KelasColumns.tabel[KelasColumns.semester] == semester)
        }
        if let status {
            query = query.filter(SiswaKelasColumns.tabel[SiswaKelasColumns.statusEnrollment] == status.rawValue)
        }

        // 1) exclude deletedStudentIDs
        if !excludeSiswaIDs.isEmpty {
            query = query.filter(!excludeSiswaIDs.contains(SiswaColumns.tabel[SiswaColumns.id]))
        }

        // 2) exclude specific (kelas, siswa) pairs
        if !excludeKelasSiswaPairs.isEmpty {
            let pairPredicates = excludeKelasSiswaPairs.map { rel in
                TabelNilai.tabel[TabelNilai.id] == rel.nilaiID
            }
            let combined = pairPredicates.dropFirst().reduce(pairPredicates.first!) { $0 || $1 }
            query = query.filter(!combined)
        }

        // 3) exclude unAddedNilai to nstableView
        if !excludeNilaiIDs.isEmpty {
            query = query.filter(!excludeNilaiIDs.contains(TabelNilai.tabel[TabelNilai.id]))
        }

        return query.select(selectedKelasColumns)
    }

    /// Mengurai array `Row` menjadi array `KelasModels` secara konkuren (paralel).
    ///
    /// - Parameter rows: Array baris data (`Row`) yang akan diurai.
    /// - Returns: Array `KelasModels` hasil parsing dari baris-baris yang valid.
    /// - Throws: Error jika terjadi kegagalan saat parsing baris.
    private func parseRowsConcurrently(_ rows: [Row], priority: TaskPriority = .background) async throws -> [KelasModels] {
        try await withThrowingTaskGroup(of: KelasModels?.self) { group in
            for row in rows {
                group.addTask(priority: priority) {
                    KelasModels(row: row)
                }
            }

            var models: [KelasModels] = []
            for try await model in group {
                if let model { models.append(model) }
            }
            return models
        }
    }

    /// Mengambil seluruh data `KelasModels` yang memiliki relasi lengkap antar tabel: siswa, kelas, mapel, dan guru.
    ///
    /// Fungsi ini bekerja dalam tiga tahap utama:
    /// 1. Mengambil semua `nilaiID` yang sesuai filter `tingkat`, `semester`, dan `tahunAjaran` (jika disediakan).
    /// 2. Melakukan query `JOIN` multi-tabel (`siswa_kelas`, `nilai_siswa_mapel`, `mapel`, `guru`, `kelas`) untuk mengambil data baris mentah.
    /// 3. Melakukan parsing data baris ke model ``KelasModels`` secara konkuren menggunakan `withThrowingTaskGroup` di luar connection pool.
    ///
    /// Hanya data yang tidak termasuk dalam daftar penghapusan (`deletedStudentIDs`,
    /// `deletedKelasAndSiswaIDs`, dan `siswaNaikId`) yang akan diproses pada tahap pemrosesan di `KelasModels`.
    ///
    /// - Parameters:
    ///   - type: Tipe tabel atau filter ``TableType`` yang mewakili `tingkat` kelas.
    ///   - priority: Prioritas eksekusi tugas asinkron. Default: `.background`.
    ///   - semester: Nama semester opsional untuk filter tambahan.
    ///   - tahunAjaran: Tahun ajaran opsional untuk filter tambahan.
    ///
    /// - Returns: Array ``KelasModels`` hasil parsing baris yang valid dan lolos filter.
    ///
    /// - Note:
    ///   - Fungsi ini bergantung pada akses database melalui `DatabaseManager.shared.pool.read`.
    ///   - Semua parsing model dilakukan secara paralel di luar koneksi database untuk meningkatkan performa.
    ///   - Proses debug akan mencetak hasil intermediate di mode DEBUG.
    ///
    /// - Important:
    ///   - Pastikan properti filter `tingkat`, `semester`, dan `tahunAjaran` valid agar query efektif.
    ///   - Objek generik `KelasModels` harus mendukung inisialisasi dari `Row`.
    ///   - Selalu aktifkan `PRAGMA foreign_keys = ON` di awal koneksi agar constraint relasi berjalan.
    ///
    /// - Warning:
    ///   - Jika terjadi kesalahan query atau parsing, error akan ditangani dan dicetak di DEBUG,
    ///     dan fungsi akan mengembalikan array kosong.
    func getAllKelas(ofType type: TableType, priority: TaskPriority = .background, bagian: String? = nil, semester: String? = nil, tahunAjaran: String? = nil, status: StatusSiswa? = nil, query: String? = nil) async -> [KelasModels] {
        do {
            let excludeSiswaIDs = SingletonData.deletedStudentIDs
            let excludeKelasSiswaPairs = SingletonData.deletedKelasAndSiswaIDs.flatMap { $0 }
            let excludeNilaiIDs = SingletonData.insertedID
            // Cukup satu kali akses database
            let rows = try await DatabaseManager.shared.pool.read { db in
                let queryRows = try self.buildKelasJoinQuery(
                    type: type,
                    tahunAjaran: tahunAjaran,
                    semester: semester, // <--- Parameter semester dilewatkan
                    bagian: bagian,
                    status: status,
                    queryText: query,
                    excludeSiswaIDs: Set(excludeSiswaIDs), // <--- Hasil dependency injection
                    excludeKelasSiswaPairs: excludeKelasSiswaPairs,
                    excludeNilaiIDs: excludeNilaiIDs
                )
                return try Array(db.prepare(queryRows))
            }
            return try await parseRowsConcurrently(rows, priority: priority)
        } catch {
            return []
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
    /// - Returns: Sebuah array berisi string unik yang mewakili semester, diurutkan secara alfabetis.
    func fetchSemesters() -> [String] {
        var semesters: Set<String> = []
        let query = "SELECT DISTINCT semester FROM \"kelas\""
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

    /// Mengambil data `KelasModels` dari database yang sudah dinormalisasi, difilter berdasarkan
    /// tingkat kelas (`TableType`) dan `siswaID` tertentu.
    ///
    /// Fungsi ini bekerja dalam dua tahap:
    /// 1. Melakukan query `JOIN` multi-tabel (`nilai_siswa_mapel`, `siswa_kelas`, `siswa`, `mapel`, `guru`, `kelas`)
    ///    untuk mendapatkan informasi nilai, relasi siswa, mapel yang diambil, guru pemberi nilai, dan metadata kelas.
    /// 2. Memproses setiap baris hasil query secara paralel menggunakan `withTaskGroup` untuk membuat
    ///    objek `KelasModels`. Pada tahap ini, data akan difilter ulang secara lunak (soft-delete) dengan
    ///    memeriksa ID yang sudah masuk ke `SingletonData.deletedStudentIDs` atau `deletedKelasAndSiswaIDs`.
    ///
    /// - Parameters:
    ///   - type: `TableType` yang digunakan untuk memfilter `tingkat_kelas` pada tabel `kelas`.
    ///   - siswaID: ID siswa (`Int64`) yang akan diambil datanya.
    ///
    /// - Returns: Array `[KelasModels]` berisi data nilai, mapel, guru, dan metadata kelas untuk siswa tersebut.
    ///   Jika tidak ada data valid atau terjadi error, array kosong akan dikembalikan.
    ///
    /// - Note:
    ///   - Struktur tabel database harus sudah dinormalisasi dengan foreign key antar `siswa_kelas`,
    ///     `nilai_siswa_mapel`, `mapel`, `guru`, dan `kelas`.
    ///   - Proses filter soft-delete sebaiknya disesuaikan dengan strategi delete permanen di database agar filtering ini minimal.
    ///   - Semua parsing dilakukan di luar connection pool untuk mencegah blocking connection.
    ///
    /// - Important:
    ///   - Pastikan `SingletonData` selalu diperbarui secara konsisten agar status soft-delete akurat.
    ///   - Objek `KelasModels` harus dapat diinisialisasi dari baris `Row` hasil query.
    ///
    /// - Warning:
    ///   - Error SQL akan dicetak di konsol saat mode DEBUG.
    func getKelas(_ type: TableType, siswaID: Int64, priority: TaskPriority = .background) async -> [KelasModels] {
        do {
            let excludeSiswaIDs = SingletonData.deletedStudentIDs
            let excludeKelasSiswaPairs = SingletonData.deletedKelasAndSiswaIDs.flatMap { $0 }
            let excludeNilaiIDs = SingletonData.insertedID
            let rows = try await DatabaseManager.shared.pool.read { [unowned self] db in
                let query = try buildKelasJoinQuery(type: type, siswaID: siswaID,
                                                    excludeSiswaIDs: Set(excludeSiswaIDs),
                                                    excludeKelasSiswaPairs: excludeKelasSiswaPairs,
                                                    excludeNilaiIDs: excludeNilaiIDs)
                return try Array(db.prepare(query))
            }
            return try await parseRowsConcurrently(rows, priority: priority)
        } catch {
            return []
        }
    }

    /// Membaca semua data `KelasModels` dari seluruh tabel kelas di database
    /// untuk satu siswa tertentu secara asinkron dan konkuren.
    ///
    /// Fungsi ini akan:
    /// 1. Melakukan iterasi pada seluruh nilai `TableType.allCases` untuk mewakili setiap tingkat kelas.
    /// 2. Untuk setiap ``TableType``, memanggil ``getKelas(_:siswaID:priority:)`` yang akan melakukan query multi-tabel
    ///    (`nilai_siswa_mapel`, `siswa_kelas`, `mapel`, `guru`, dan `kelas`) untuk siswa dengan `siswaID` yang diberikan.
    /// 3. Menjalankan semua pengambilan data secara paralel di dalam `TaskGroup` untuk efisiensi.
    /// 4. Menggabungkan hasilnya dalam bentuk dictionary `[TableType: [KelasModels]]`.
    ///
    /// - Parameter siswaID: ID siswa (`Int64`) yang akan digunakan sebagai filter data.
    ///
    /// - Returns: Dictionary `[TableType: [KelasModels]]` berisi data nilai, mapel, guru,
    ///   dan metadata kelas untuk siswa tersebut, dikelompokkan per `TableType`.
    ///   Jika tidak ada data valid atau terjadi error pada salah satu tipe, hasilnya akan kosong untuk tipe tersebut.
    ///
    /// - Note:
    ///   - Fungsi ini hanya memanggil ``getKelas(_:siswaID:)`` untuk setiap tipe dan tidak melakukan filter tambahan.
    ///   - Semua pemrosesan dilakukan secara konkuren di luar connection pool.
    ///
    /// - Important:
    ///   - Pastikan `TableType.allCases` sudah memuat semua tipe kelas yang valid.
    ///   - `KelasModels` harus mendukung inisialisasi dari baris query.
    ///
    /// - Warning:
    ///   - Jika terjadi error di salah satu `Task`, error akan dicetak di konsol mode DEBUG dan hasilnya akan kosong untuk tipe tersebut.
    ///   - Jika `self` tidak tersedia atau dilepas dari memori, task akan dilewati.
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

    /// Menghapus catatan nilai spesifik dari tabel `nilai_siswa_mapel` berdasarkan ID-nya.
    ///
    /// - Parameter nilaiID: ID dari catatan nilai yang akan dihapus (yaitu, id_nilai dari tabel nilai_siswa_mapel).
    func deleteSpecificNilai(nilaiID: Int64) {
        do {
            let filter = TabelNilai.tabel.filter(TabelNilai.id == nilaiID)
            try db.run(filter.delete())
        } catch {
            #if DEBUG
                print("Error menghapus nilai (ID: \(nilaiID)): \(error.localizedDescription)")
            #endif
        }
    }

    /// Memperbarui nilai untuk catatan tertentu di tabel `nilai_siswa_mapel`.
    /// - Parameters:
    ///   - id: ID dari catatan nilai yang akan diperbarui.
    ///   - nilai: Nilai baru yang akan digunakan untuk memperbarui
    func updateNilai(_ id: Int64, nilai: Int? = nil) {
        let filter = TabelNilai.tabel.filter(TabelNilai.id == id)
        do {
            try db.run(filter.update(TabelNilai.nilai <- nilai))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Fungsi untuk mendapatkan id dan detail kelas dari database.
    /// - Returns: Array tuple `(Int64, String)`
    ///   yang bisa diakses dengan `$0` (ID) dan `$1` (Nama Jabatan).
    func fetchKelas() async -> [(Int64, String)] {
        await fetchIDAndName(
            from: KelasColumns.tabel,
            idColumn: KelasColumns.id,
            nameColumn: KelasColumns.tingkat
        )
    }

    /// Mencari ID kelas berdasarkan nama kelas.
    /// Jika kelas belum ada, sisipkan kelas baru dan kembalikan ID-nya.
    /// - Parameters:
    ///   - nama: Nama kelas.
    ///   - tingkat: Tingkat kelas atau level (opsional, jika kamu mau support SD/SMP/SMK).
    ///   - tahunAjaran: Tahun ajaran kelas.
    ///   - semester: semester kelas.
    /// - Returns: ID dari kelas yang ditemukan atau baru disisipkan.
    func insertOrGetKelasID(nama: String, tingkat: String, tahunAjaran: String, semester: String) async -> Int64? {
        // 1️⃣ Cek apakah kelas sudah ada (biasanya nama unik, atau nama+tingkat)
        let query = KelasColumns.tabel.filter(KelasColumns.nama == nama && KelasColumns.tingkat == tingkat && KelasColumns.tahunAjaran == tahunAjaran && KelasColumns.semester == semester)

        do {
            if let row = try await DatabaseManager.shared.pool.read({ db in
                try db.pluck(query)
            }) {
                #if DEBUG
                    print("Kelas '\(nama)' ditemukan dengan ID: \(row[KelasColumns.id])")
                #endif
                return row[KelasColumns.id]
            } else {
                #if DEBUG
                    print("Kelas '\(nama)' tidak ditemukan")
                #endif
                // 2️⃣ Insert jika belum ada
                let insert = KelasColumns.tabel.insert(
                    KelasColumns.nama <- nama,
                    KelasColumns.tingkat <- tingkat,
                    KelasColumns.tahunAjaran <- tahunAjaran,
                    KelasColumns.semester <- semester
                )
                return try db.run(insert)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return nil
    }

    /// Ambil semua (namaMapel, mapelID)
    /// - Returns: Tupe (namaMapel, mapelID)
    func fetchAllMapel() async -> [(String, Int64)] {
        do {
            let result: [(String, Int64)] = try await DatabaseManager.shared.pool.read { conn in
                var rows: [(String, Int64)] = []
                for row in try conn.prepare(MapelColumns.tabel) {
                    let id = row[MapelColumns.id]
                    let nama = row[MapelColumns.nama]
                    rows.append((nama, id))
                }
                return rows
            }
            return result
        } catch {
            #if DEBUG
                print("fetchAllMapel error:", error)
            #endif
            return []
        }
    }

    /// Ambil semua (namaJabatan, jabatanID).
    /// - Returns: Tuple (namaJabatan, jabatanID).
    func fetchAllJabatan() async -> [(String, Int64)] {
        do {
            let result: [(String, Int64)] = try await DatabaseManager.shared.pool.read { connection in
                var list = [(String, Int64)]()
                for row in try connection.prepare(JabatanColumns.tabel) {
                    let id = row[JabatanColumns.id]
                    let nama = row[JabatanColumns.nama]
                    list.append((nama, id))
                }
                return list
            }
            return result
        } catch {
            #if DEBUG
                print("fetchAllJabatan error:", error)
            #endif
            return []
        }
    }

    // MARK: - TABEL SISWA KELAS

    /// Menandai status siswa pada kelas lama sebagai "Naik" dan memasukkan entri baru ke kelas tujuan.
    ///
    /// Fungsi ini digunakan untuk memindahkan seorang siswa dari satu kelas yang ``SiswaKelasColumns/statusEnrollment``
    /// masih bernilai `aktif`.
    /// Jika entri ``SiswaKelasColumns`` sebelumnya masih berstatus "Aktif", maka status tersebut akan diubah menjadi "Naik",
    /// dan entri baru akan ditambahkan dengan status "Aktif" pada kelas baru.
    ///
    /// Fungsi ini juga akan membuat entri kelas baru jika belum tersedia di database.
    ///
    /// Fungsi ini mengirim notifikasi `Notification.Name("didChangeStudentEnrollment")`
    /// dengan data siswaId.
    ///
    /// - Parameters:
    ///   - siswaId: ID unik siswa yang akan dipindahkan.
    ///   - intoKelasId: ID kelas tujuan.
    ///   - tingkat: Tingkat kelas baru.
    ///   - tahunAjaran: Tahun ajaran kelas baru.
    ///   - semester: Semester kelas baru.
    ///   - tanggalNaik: Tanggal saat siswa resmi naik kelas.
    ///
    /// - Note:
    ///   Fungsi ini **tidak membatalkan** (undo) perubahan status kelas lama secara otomatis.
    ///   Pastikan menyimpan data yang diperlukan jika ingin mendukung fitur undo.
    /// - Returns: ID (Int64) untuk data siswa di tabel database `siswa_kelas`.
    @discardableResult
    func naikkanSiswa(
        _ siswaId: Int64,
        intoKelasId: Int64? = nil,
        tingkatBaru: String? = nil,
        tahunAjaran: String? = nil,
        semester: String? = nil,
        tanggalNaik: String,
        statusEnrollment: StatusSiswa = .naik
    ) -> UndoNaikKelasContext? {
        func getOldData(queryTabel: Table) throws -> [(Int64, Int, String?)] {
            var snapshot: [(Int64, Int, String?)] = []
            for row in try db.prepare(queryTabel) {
                let rowID = row[SiswaKelasColumns.id]
                let oldStat = row[SiswaKelasColumns.statusEnrollment]
                let oldTgl = row[SiswaKelasColumns.tanggalKeluar]
                snapshot.append((rowID, oldStat, oldTgl))
            }
            return snapshot
        }
        // 2. Panggil fungsi sinkron untuk operasi database di dalam notifQueue
        do {
            let siswaKelas = SiswaKelasColumns.tabel
            let kls = KelasColumns.tabel

            // 2. Ambil semua entri aktif, simpan snapshot sebelum di-update
            var queryAktif = siswaKelas
                .join(kls, on: siswaKelas[SiswaKelasColumns.idKelas] == kls[KelasColumns.id])
                .filter(
                    SiswaKelasColumns.idSiswa == siswaId
                )

            if statusEnrollment == .aktif {
                // kita reaktivasi: cari entri yang NON-AKTIF (naik/lulus/berhenti)
                queryAktif = queryAktif.filter(
                    SiswaKelasColumns.statusEnrollment != StatusSiswa.aktif.rawValue
                )
                .order(SiswaKelasColumns.id.desc)
                .limit(1)
            } else {
                queryAktif = queryAktif.filter(
                    SiswaKelasColumns.statusEnrollment == StatusSiswa.aktif.rawValue
                )
                if let tahunAjaran, let tingkatBaru, let semester {
                    queryAktif = queryAktif.filter(
                        kls[KelasColumns.tahunAjaran] != tahunAjaran ||
                            kls[KelasColumns.tingkat] != tingkatBaru ||
                            kls[KelasColumns.semester] != semester
                    )
                }
            }

            var snapshot: [(Int64, Int, String?)] = try getOldData(queryTabel: queryAktif)

            #if DEBUG
                let total = try db.scalar(queryAktif.count) // ← ini akan menjalankan COUNT(*) di SQL
                print("total rows:", total)
            #endif

            // 3. Nonaktifkan entri lama
            for (rowID, _, _) in snapshot {
                let upd = siswaKelas.filter(SiswaKelasColumns.id == rowID)
                try db.run(upd.update(
                    SiswaKelasColumns.statusEnrollment <- statusEnrollment.rawValue,
                    SiswaKelasColumns.tanggalKeluar <- statusEnrollment == .aktif ? nil : tanggalNaik
                ))
            }

            if snapshot.isEmpty, statusEnrollment == .naik {
                var queryTable = siswaKelas
                    .join(kls, on: siswaKelas[SiswaKelasColumns.idKelas] == kls[KelasColumns.id])
                    .filter(
                        SiswaKelasColumns.idSiswa == siswaId &&
                            SiswaKelasColumns.statusEnrollment != StatusSiswa.aktif.rawValue
                    )
                if let tahunAjaran, let tingkatBaru, let semester {
                    queryTable = queryTable.filter(
                        kls[KelasColumns.tahunAjaran] == tahunAjaran ||
                            kls[KelasColumns.tingkat] == tingkatBaru ||
                            kls[KelasColumns.semester] == semester
                    )
                }
                snapshot = try getOldData(queryTabel: queryTable)
            }

            sendDidChangeStudentEnroll(siswaId)

            // 4. Buat entry baru
            if statusEnrollment == .naik, let intoKelasId, !snapshot.isEmpty,
               let newID = insertSiswaKelas(siswaId: siswaId, inToKelas: intoKelasId, tanggalMasuk: tanggalNaik)
            {
                // Perbarui kolom tanggal berhenti jika siswa telah naik.
                updateKolomSiswa(siswaId, kolom: SiswaColumns.tanggalberhenti, data: "")
                // 5. Kembalikan context untuk undo
                return UndoNaikKelasContext(
                    siswaId: siswaId,
                    deactivatedEntries: snapshot,
                    newEntryID: newID,
                    newEntryKelasID: intoKelasId,
                    newEntryTanggal: tanggalNaik,
                    tahunAjaran: tahunAjaran ?? "",
                    semester: semester ?? ""
                )
            } else if statusEnrollment == .aktif {
                return UndoNaikKelasContext(
                    siswaId: siswaId,
                    deactivatedEntries: snapshot,
                    newEntryID: -1,
                    newEntryKelasID: -1,
                    newEntryTanggal: "",
                    tahunAjaran: tahunAjaran ?? "",
                    semester: semester ?? ""
                )
            } else {
                // 6. Context untuk undo ketika statusEnrollment != .naik
                return UndoNaikKelasContext(
                    siswaId: siswaId,
                    deactivatedEntries: snapshot,
                    newEntryID: -1,
                    newEntryKelasID: -1,
                    newEntryTanggal: tanggalNaik,
                    tahunAjaran: "",
                    semester: ""
                )
            }
        } catch {
            #if DEBUG
                print("error menaikkan kelas siswa")
            #endif
            return nil
        }
    }

    /// Membatalkan satu atau beberapa operasi “naik kelas” dengan menghapus entri
    /// baru dan mengembalikan entri lama ke status semula.
    ///
    /// Semua perubahan dibungkus dalam satu transaksi agar bersifat atomic. Untuk setiap
    /// `UndoNaikKelasContext` di parameter `ctx`, langkahnya adalah:
    /// 1. Menghapus entri baru di tabel `siswa_kelas` yang dibuat saat siswa dinaikkan.
    /// 2. Mengembalikan semua entri lama (statusEnrollment dan tanggalKeluar) ke nilai awal.
    ///
    /// Fungsi ini mengirim notifikasi `Notification.Name("didChangeStudentEnrollment")`
    /// dengan data idSiswa.
    ///
    /// - Parameter ctx: Array `UndoNaikKelasContext` yang berisi:
    ///   - `newEntryID`: ID entri baru yang akan dihapus (jika ada).
    ///   - `deactivatedEntries`: Daftar tuple `(rowID, oldStatus, oldTanggalKeluar)`
    ///     yang mewakili entri lama yang dinonaktifkan saat kenaikan kelas.
    func undoNaikKelas(using ctx: [UndoNaikKelasContext]) {
        for data in ctx {
            // 1. Hapus entri baru
            do {
                try db.run(
                    SiswaKelasColumns.tabel
                        .filter(SiswaKelasColumns.id == data.newEntryID)
                        .delete()
                )
                try db.run(
                    KelasColumns.tabel
                        .filter(KelasColumns.id == data.newEntryKelasID)
                        .delete()
                )
            } catch {
                #if DEBUG
                    print(error)
                #endif
            }
            #if DEBUG
                print("✅ Undo: Hapus entri baru dengan ID \(data.newEntryID)")
                print("✅ Undo: Restore \(data.deactivatedEntries.count) entri lama")
            #endif

            // 2. Kembalikan entri lama ke status semula
            for (rowID, oldStatus, oldTgl) in data.deactivatedEntries {
                let q = SiswaKelasColumns.tabel
                    .filter(SiswaKelasColumns.id == rowID)
                #if DEBUG
                    print("oldstatus:", oldStatus)
                #endif
                do {
                    try db.run(q.update(
                        SiswaKelasColumns.statusEnrollment <- oldStatus,
                        SiswaKelasColumns.tanggalKeluar <- oldTgl
                    ))
                } catch {
                    #if DEBUG
                        print(error)
                    #endif
                }
            }
            // Setelah loop untuk satu siswa selesai:
            sendDidChangeStudentEnroll(data.siswaId)
        }
    }

    /// Menambahkan entri baru ke tabel `SiswaKelas` untuk seorang siswa ke kelas tertentu.
    ///
    /// Fungsi ini digunakan untuk mencatat siswa masuk ke kelas tertentu pada tanggal tertentu,
    /// dengan status keaktifan yang dapat ditentukan (`Aktif`, `Naik`, atau lainnya).
    ///
    /// - Parameters:
    ///   - siswaId: ID siswa.
    ///   - keKelas: ID kelas tujuan.
    ///   - tanggalMasuk: Tanggal masuk siswa ke kelas tersebut.
    ///   - status: Status keikutsertaan siswa dalam kelas. Default-nya adalah `"Aktif"`.
    ///
    /// - Returns: ID baris (`rowID`) yang baru dimasukkan jika berhasil.
    ///
    /// - Important:
    ///   Pastikan fungsi ini dipanggil dalam konteks database `write` yang harus dijalankan secara serial.
    func insertSiswaKelas(siswaId: Int64, inToKelas: Int64, tanggalMasuk: String? = nil, status: StatusSiswa = .aktif) -> Int64? {
        do {
            let siswaKelasFilter = SiswaKelasColumns.tabel.filter(
                SiswaKelasColumns.idSiswa == siswaId &&
                    SiswaKelasColumns.idKelas == inToKelas
            )

            if let existingSiswaKelas = try db.pluck(siswaKelasFilter) {
                try db.run(siswaKelasFilter.update(SiswaKelasColumns.statusEnrollment <- status.rawValue))
                return existingSiswaKelas[SiswaKelasColumns.id]
            } else {
                let insert = SiswaKelasColumns.tabel.insert(
                    SiswaKelasColumns.idSiswa <- siswaId,
                    SiswaKelasColumns.idKelas <- inToKelas,
                    SiswaKelasColumns.statusEnrollment <- status.rawValue,
                    SiswaKelasColumns.tanggalMasuk <- tanggalMasuk,
                    SiswaKelasColumns.tanggalKeluar <- nil
                )
                return try db.run(insert)
            }
        } catch {
            #if DEBUG
                print("error insertSiswaKelas")
            #endif
        }
        return nil
    }

    /// Mengambil data detail dari kelas yang sedang aktif untuk seorang siswa.
    /// - Parameter idSiswa: `id` siswa yang digunakan untuk look-up tabel ``SiswaKelasColumns`` dengan status aktif.
    /// - Returns: ``KelasDefaultData``.
    func fetchDataKelasAktif(forSiswa idSiswa: Int64) async throws -> KelasDefaultData? {
        // Query ini melakukan JOIN antara siswa_kelas dan kelas
        let query = SiswaKelasColumns.tabel
            .filter(SiswaKelasColumns.idSiswa == idSiswa && SiswaKelasColumns.statusEnrollment == 1)
            .join(KelasColumns.tabel, on: KelasColumns.id == SiswaKelasColumns.idKelas)
            .select(
                KelasColumns.nama,
                KelasColumns.tingkat,
                KelasColumns.tahunAjaran,
                KelasColumns.semester
            )

        return try await pool.read { db in
            guard let row = try db.pluck(query) else { return nil }

            // GRDB secara cerdas akan memberikan akses ke kolom dari tabel yang di-JOIN
            return (
                nama: row[KelasColumns.nama],
                tingkat: row[KelasColumns.tingkat],
                tahunAjaran: row[KelasColumns.tahunAjaran],
                semester: row[KelasColumns.semester]
            )
        }
    }

    private func sendDidChangeStudentEnroll(_ siswaId: Int64) {
        NotificationCenter.default.post(
            name: .didChangeStudentEnrollment,
            object: nil, // 'self' jika perlu
            userInfo: ["siswaID": siswaId] // Kirim ID siswa yang berubah
        )
        #if DEBUG
            print("[NOTIFICATION] Mengirim notifikasi perubahan pendaftaran untuk siswa ID: \(siswaId)")
        #endif
    }
}
