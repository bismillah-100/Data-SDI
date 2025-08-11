//
//  GuruQuery.swift
//  Data SDI
//
//  Created by MacBook on 13/07/25.
//

import Foundation
import SQLite

typealias TabelTugas = PenugasanGuruMapelKelasColumns
typealias TabelNilai = NilaiSiswaMapelColumns

extension DatabaseController {
    /// Fungsi untuk mendapatkan id guru dan nama guru dari database.
    /// - Returns: Array tuple `(Int64, String)`
    ///   yang bisa diakses dengan `$0` (ID) dan `$1` (Nama Guru).
    func fetchGuruDanID() async -> [(Int64, String)] {
        let deletedGuruIDs = Array(SingletonData.deletedGuru)
        let undoAddGuruIDs = Array(SingletonData.undoAddGuru)

        return await fetchIDAndName(
            from: GuruColumns.tabel,
            idColumn: GuruColumns.id,
            nameColumn: GuruColumns.nama
        ) { _ in // Menggunakan closure untuk filter
            // Pastikan Anda membandingkan dengan kolom yang benar dari tabel yang diberikan
            // di sini kita asumsikan GuruColumns.id dan currentTable adalah sama
            !deletedGuruIDs.contains(GuruColumns.id) && !undoAddGuruIDs.contains(GuruColumns.id)
        }
    }

    /// Mengambil nama mata pelajaran berdasarkan ID yang diberikan secara asynchronous.
    ///
    /// Fungsi ini akan melakukan query ke database untuk mencari nama mata pelajaran
    /// yang memiliki ID sesuai parameter. Jika ditemukan, nama mata pelajaran akan dikembalikan.
    /// Jika terjadi kesalahan atau data tidak ditemukan, fungsi akan mengembalikan string kosong.
    ///
    /// - Parameter id: ID dari mata pelajaran yang ingin diambil namanya.
    /// - Returns: Nama mata pelajaran sebagai `String`, atau string kosong jika tidak ditemukan atau terjadi error.
    func fetchNamaMapelById(_ id: Int64) async -> String {
        let tabel = MapelColumns.tabel
        let query = tabel.filter(MapelColumns.id == id).limit(1)
        do {
            if let row = try await DatabaseManager.shared.pool.read({ db in
                try db.pluck(query)
            }) {
                return row[MapelColumns.nama]
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return ""
    }

    /// Mengambil data penugasan berdasarkan ID secara asinkron.
    ///
    /// - Parameter id: ID penugasan yang ingin diambil (tipe `Int64`).
    /// - Returns: Objek ``PenugasanModel`` jika ditemukan, atau `nil` jika tidak ditemukan atau terjadi kesalahan.
    /// - Note: Fungsi ini menggunakan database pool untuk membaca data secara asinkron dan melakukan mapping hasil query ke model ``PenugasanModel``.
    func fetchPenugasan(byID id: Int64) async -> PenugasanModel? {
        let tabel = PenugasanGuruMapelKelasColumns.tabel
        let query = tabel
            .filter(PenugasanGuruMapelKelasColumns.id == id)
            .limit(1)

        do {
            if let row = try await DatabaseManager.shared.pool.read({ db in
                try db.pluck(query)
            }) {
                // Mapping Row → PenugasanModel
                return PenugasanModel(row: row)
            }
        } catch {
            #if DEBUG
                print("Error mengambil penugasan dengan ID \(id): \(error)")
            #endif
        }

        return nil
    }

    /// Menghasilkan query SQL dan daftar binding untuk mengambil data guru dari database dengan filter dinamis.
    ///
    /// Fungsi ini membangun query SQL berdasarkan beberapa parameter filter seperti status tugas, kata kunci pencarian,
    /// semester, tahun ajaran, serta mode tampilan (guruVC). Query yang dihasilkan dapat berupa query sederhana (tanpa join)
    /// jika `guruVC` bernilai `true`, atau query lengkap dengan join ke tabel terkait jika `guruVC` bernilai `false`.
    ///
    /// - Parameter:
    ///   - statusTugas: Status penugasan guru (opsional). Jika diisi, hanya data dengan status ini yang diambil.
    ///   - searchQuery: Kata kunci pencarian (opsional). Digunakan untuk mencari berdasarkan nama/alamat guru, jabatan, mapel, atau tahun ajaran.
    ///   - semester: Semester (opsional). Jika diisi, hanya data pada semester ini yang diambil.
    ///   - tahunAjaran: Tahun ajaran (opsional). Jika diisi, hanya data pada tahun ajaran ini yang diambil.
    ///   - guruVC: Mode tampilan guru (default: `false`). Jika `true`, query hanya mengambil data guru tanpa join ke tabel lain.
    ///
    /// - Returns: Tuple berisi string query SQL dan array binding untuk parameter query.
    ///
    private func composeFilteredGuruSQL(statusTugas: StatusSiswa?, searchQuery: String?, semester: String?, tahunAjaran: String?, guruVC: Bool = false) -> (sql: String, bindings: [Binding]) {
        var bindings: [Binding] = []

        // Ambil ID guru yang dihapus
        var deletedGuruIDs = Set(SingletonData.deletedGuru)
        deletedGuruIDs.formUnion(SingletonData.undoAddGuru)

        if guruVC {
            // ➤ QUERY SEDERHANA jika guruVC aktif
            var sql = """
            SELECT g.id_guru, g.nama_guru, g.alamat_guru
            FROM guru AS g
            """
            var clauses: [String] = []

            if !deletedGuruIDs.isEmpty {
                let ph = Array(repeating: "?", count: deletedGuruIDs.count).joined(separator: ",")
                clauses.append("g.id_guru NOT IN (\(ph))")
                bindings.append(contentsOf: deletedGuruIDs.map { $0 as Binding })
            }

            if let q = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
               !q.isEmpty
            {
                let lower = q.lowercased()
                clauses.append("""
                (
                  LOWER(g.nama_guru) LIKE ? OR
                  LOWER(g.alamat_guru) LIKE ?
                )
                """)
                let pat = "%\(lower)%"
                bindings.append(pat)
                bindings.append(pat)
            }

            if !clauses.isEmpty {
                sql += " WHERE " + clauses.joined(separator: " AND ")
            }
            return (sql, bindings)
        }

        // ➤ QUERY LENGKAP (JOIN) jika bukan guruVC
        let deletedPenugasanIDs = Set(SingletonData.deletedTugasGuru)

        var sql = """
        SELECT
          g.id_guru, g.nama_guru, g.alamat_guru,
          j.nama, m.nama_mapel,
          k.tahun_ajaran, k.tingkat_kelas, k.nama_kelas, k.semester,
          t.id_penugasan, t.status_penugasan, t.tanggal_mulai_efektif, t.tanggal_selesai_efektif
        FROM guru AS g
        INNER JOIN penugasan_guru_mapel_kelas AS t
          ON g.id_guru = t.id_guru
        LEFT JOIN jabatan_guru AS j
          ON t.id_jabatan = j.id_jabatan
        LEFT JOIN mapel AS m
          ON t.id_mapel = m.id_mapel
        LEFT JOIN kelas AS k
          ON t.id_kelas = k.idKelas
        """

        var clauses: [String] = []

        if !deletedGuruIDs.isEmpty {
            let ph = Array(repeating: "?", count: deletedGuruIDs.count).joined(separator: ",")
            clauses.append("g.id_guru NOT IN (\(ph))")
            bindings.append(contentsOf: deletedGuruIDs.map { $0 as Binding })
        }
        if !deletedPenugasanIDs.isEmpty {
            let ph2 = Array(repeating: "?", count: deletedPenugasanIDs.count).joined(separator: ",")
            clauses.append("t.id_penugasan NOT IN (\(ph2))")
            bindings.append(contentsOf: deletedPenugasanIDs.map { $0 as Binding })
        }

        if let statusTugas {
            let st = statusTugas.rawValue
            #if DEBUG
                print("st:", st)
            #endif
            clauses.append("t.status_penugasan = ?")
            bindings.append(st)
        }
        if let sem = semester {
            clauses.append("k.semester = ?")
            bindings.append(sem)
        }
        if let ta = tahunAjaran {
            clauses.append("k.tahun_ajaran = ?")
            bindings.append(ta)
        }

        if let q = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !q.isEmpty
        {
            let lower = q.lowercased()
            if let num = Int(lower), (1 ... 6).contains(num) {
                clauses.append("LOWER(k.tingkat_kelas) LIKE ?")
                bindings.append("%\(lower)%")
            } else {
                clauses.append("""
                (
                  LOWER(g.nama_guru) LIKE ? OR
                  LOWER(g.alamat_guru) LIKE ? OR
                  LOWER(j.nama) LIKE ? OR
                  LOWER(m.nama_mapel) LIKE ? OR
                  LOWER(k.tahun_ajaran) LIKE ?
                )
                """)
                let pat = "%\(lower)%"
                for _ in 0 ..< 5 {
                    bindings.append(pat)
                }
            }
        }

        if !clauses.isEmpty {
            sql += " WHERE " + clauses.joined(separator: " AND ")
        }

        return (sql, bindings)
    }

    /// Mengambil daftar guru dari database SQLite secara asinkron.
    ///  - Parameters:
    ///    - statusTugas: Status penugasan siswa untuk memfilter guru
    ///    - searchQuery: Kata kunci pencarian untuk memfilter guru berdasarkan nama atau atribut lainnya
    ///    - semester: Periode semester untuk memfilter guru
    ///    - tahunAjaran: Tahun ajaran untuk memfilter guru
    ///    - guruVC: Flag boolean yang menunjukkan apakah permintaan berasal dari view controller guru
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
    func getGuru(statusTugas: StatusSiswa? = nil, searchQuery: String? = nil, semester: String? = nil, tahunAjaran: String? = nil, guruVC: Bool = false) async -> [GuruModel] {
        // 1. Siapkan SQL + bindings
        let (sql, bindings) = composeFilteredGuruSQL(
            statusTugas: statusTugas,
            searchQuery: searchQuery,
            semester: semester,
            tahunAjaran: tahunAjaran,
            guruVC: guruVC
        )

        do {
            // 2. Prepare & execute dalam pool.read
            let stmt = try await DatabaseManager.shared.pool.read { conn in
                try conn.prepare(sql, bindings)
            }

            // 3. Paralelisasi mapping setiap row → GuruModel
            let list: [GuruModel] = await withTaskGroup(of: GuruModel?.self) { group in
                for row in stmt {
                    group.addTask {
                        // init dengan row array
                        if !guruVC {
                            let guru = GuruModel(from: row)
                            return guru
                        } else {
                            let guru = GuruModel(fromGuruOnlyRow: row)
                            return guru
                        }
                    }
                }
                var out: [GuruModel] = []
                for await g in group {
                    if let g = g {
                        out.append(g)
                    }
                }
                return out
            }

            return list
        } catch {
            #if DEBUG
                print("getGuruRaw error:", error)
            #endif
            return []
        }
    }

    /// Fungsi untuk menghapus penugasan guru.
    /// - Parameter idTugas: ID tugas yang akan dihapus.
    func hapusTugasGuru(_ idTugas: Int64) {
        let query = TabelTugas.tabel.filter(TabelTugas.id == idTugas)
        do {
            try db.run(query.delete())
        } catch {
            DispatchQueue.main.async {
                ReusableFunc.showProgressWindow(2, pesan: "Tugas mapel masih terhubung ke nilai, tidak dapat dihapus.", image: ReusableFunc.trashSlashFill!)
            }
        }
    }

    /// Fungsi untuk memeriksa apakah tugas masih digunakan di tabel NilaiSiswa.
    /// - Parameter idTugas: ID tugas yang akan dicek.
    /// - Returns: true jika tugas masih terhubung ke nilai siswa.
    func isTugasMasihDipakai(idTugas: Int64) -> Bool {
        do {
            let query = TabelNilai.tabel.filter(TabelNilai.idPenugasanGuruMapelKelas == idTugas)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            #if DEBUG
                print("Error memeriksa FK NilaiSiswa: \(error)")
            #endif
            return false
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
        let guru = GuruColumns.tabel.filter(GuruColumns.id == id)
        do {
            try db.run(guru.limit(1).update(
                Expression<String>(kolom) <- baru
            ))
        } catch {
            print(error)
        }

        switch kolom {
        case "nama_guru":
            addNamaGuruAutoComplete(baru)
            catatSuggestions(data: [KelasColumn.guru: baru])
        case "alamat_guru":
            addAlamatAutoComplete(baru)
            catatSuggestions(data: [SiswaColumn.alamat: baru])
        default: break
        }

        // POST Notification ke KelasVC dan DetailSiswaView
        let userInfo: [String: Any] = ["namaGuru": baru, "idGuru": id]
        NotificationCenter.default.post(name: .updateGuruMapel, object: nil, userInfo: userInfo)
    }

    private func addNamaGuruAutoComplete(_ baru: String) {
        var namaWords: Set<String> = []
        namaWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        namaWords.insert(baru.capitalizedAndTrimmed())
        ReusableFunc.namaguru.formUnion(namaWords)
    }

    private func addAlamatAutoComplete(_ baru: String) {
        var alamatWords: Set<String> = []
        alamatWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        alamatWords.insert(baru.capitalizedAndTrimmed())
        ReusableFunc.alamat.formUnion(alamatWords)
    }

    private func addMapelAutoComplete(_ baru: String) {
        var mapelWords: Set<String> = []
        mapelWords.formUnion(baru.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        mapelWords.insert(baru.capitalizedAndTrimmed())
        ReusableFunc.mapel.formUnion(mapelWords)
    }

    /// Menghapus data guru dari database berdasarkan ID guru yang diberikan.
    ///
    /// - Parameter idGuruValue: ID guru (`Int64`) yang datanya ingin dihapus.
    func hapusGuru(idGuruValue: Int64) {
        let query = GuruColumns.tabel.filter(GuruColumns.id == idGuruValue)
        do {
            try db.run(query.delete())
        } catch {
            DispatchQueue.main.async {
                ReusableFunc.showProgressWindow(2, pesan: "Guru masih terhubung ke tugas, tidak dapat dihapus.", image: ReusableFunc.trashSlashFill!)
            }
        }
    }

    /// Fungsi untuk memeriksa penugasan guru tertentu.
    /// - Parameter idGuruValue: ID guru yang akan diperiksa.
    /// - Returns: 'true' jika masih dipakai di tabel lain, 'false' jika tidak.
    func isGuruMasihDipakai(idGuruValue: Int64) -> Bool {
        do {
            let penugasanQuery = TabelTugas.tabel.filter(TabelTugas.idGuru == idGuruValue)
            let count = try db.scalar(penugasanQuery.count)
            return count > 0
        } catch {
            print("Gagal memeriksa FK PenugasanGuru: \(error)")
            return false
        }
    }

    /// Menambahkan data jabatan baru ke dalam tabel Jabatan.
    /// - Parameter nama: Nama jabatan yang akan ditambahkan.
    /// - Returns: Nilai Int64 berupa ID dari jabatan yang berhasil ditambahkan, atau nil jika gagal.
    func tambahJabatan(_ nama: String) -> Int64? {
        let insert = JabatanColumns.tabel.insert(
            JabatanColumns.nama <- nama
        )
        var jabWords: Set<String> = []
        jabWords.formUnion(nama.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        jabWords.insert(nama.capitalizedAndTrimmed())
        ReusableFunc.jabatan.formUnion(jabWords)
        return executeInsert(insert)
    }

    /// Menambahkan data guru baru ke dalam tabel.
    /// - Parameter nama: Nama guru yang akan ditambahkan.
    /// - Parameter alamat: Alamat guru (opsional).
    /// - Returns: ID baris yang baru dimasukkan jika berhasil, atau `nil` jika gagal.
    func tambahGuru(_ nama: String, alamat: String? = nil) -> Int64? {
        let insert = GuruColumns.tabel.insert(
            GuruColumns.nama <- nama,
            GuruColumns.alamat <- alamat
        )

        addNamaGuruAutoComplete(nama)
        catatSuggestions(data: [KelasColumn.guru: nama])

        if let alamat {
            addAlamatAutoComplete(alamat)
            catatSuggestions(data: [SiswaColumn.alamat: alamat])
        }

        return executeInsert(insert)
    }

    /// Menambahkan penugasan guru ke dalam tabel `PenugasanGuruMapelKelas`.
    ///
    /// - Parameter idGuru: ID guru yang akan ditugaskan.
    /// - Parameter idJabatan: ID jabatan guru.
    /// - Parameter idMapel: ID mata pelajaran yang diajarkan.
    /// - Parameter idKelas: ID kelas yang diajar.
    /// - Parameter tanggalMulai: Tanggal mulai efektif penugasan (format string).
    /// - Parameter tanggalBerhenti: Tanggal selesai efektif penugasan (opsional, default `nil`).
    /// - Parameter statusTugas: Status penugasan guru.
    ///
    /// - Returns: ID baris yang berhasil dimasukkan (`Int64?`), atau `nil` jika gagal.
    func buatPenugasanGuru(idGuru: Int64, idJabatan: Int64, idMapel: Int64, idKelas: Int64, tanggalMulai: String, tanggalBerhenti _: String? = nil, statusTugas: StatusSiswa) -> Int64? {
        let insert = TabelTugas.tabel.insert(
            TabelTugas.idGuru <- idGuru,
            TabelTugas.idJabatan <- idJabatan,
            TabelTugas.idMapel <- idMapel,
            TabelTugas.idKelas <- idKelas,
            TabelTugas.tanggalMulaiEfektif <- tanggalMulai,
            TabelTugas.tanggalSelesaiEfektif <- nil,
            TabelTugas.statusPenugasan <- statusTugas.rawValue
        )
        return executeInsert(insert)
    }

    /// Memperbarui data penugasan guru berdasarkan ID penugasan yang diberikan.
    ///
    /// - Parameters:
    ///   - idPenugasan: ID penugasan yang akan diperbarui.
    ///   - idJabatan: (Opsional) ID jabatan baru untuk penugasan.
    ///   - idMapel: (Opsional) ID mata pelajaran baru untuk penugasan.
    ///   - tanggalMulai: (Opsional) Tanggal mulai efektif penugasan (format String).
    ///   - tanggalBerhenti: (Opsional) Tanggal selesai efektif penugasan (format String).
    ///   - statusTugas: (Opsional) Status penugasan baru.
    /// - Returns: `true` jika pembaruan berhasil, `false` jika gagal atau tidak ada field yang diupdate.
    ///
    /// Fungsi ini akan memperbarui hanya field yang diberikan nilainya (tidak nil).
    /// Jika tidak ada field yang diberikan untuk diupdate, fungsi akan mengembalikan `false`.
    /// Jika terjadi error saat proses update, fungsi juga akan mengembalikan `false`.
    @discardableResult
    func updatePenugasanGuru(
        idPenugasan: Int64,
        idJabatan: Int64? = nil,
        idMapel: Int64? = nil,
        tanggalMulai: String? = nil,
        tanggalBerhenti: String? = nil,
        statusTugas: StatusSiswa? = nil
    ) async -> Bool {
        do {
            let penugasanTable = TabelTugas.tabel
            let rowToUpdate = penugasanTable.filter(TabelTugas.id == idPenugasan)

            var setters: [SQLite.Setter] = []
            if let idMapel {
                setters.append(TabelTugas.idMapel <- idMapel)
            }
            if let idJabatan {
                setters.append(TabelTugas.idJabatan <- idJabatan)
            }
            if let tanggalMulai {
                setters.append(TabelTugas.tanggalMulaiEfektif <- tanggalMulai)
            }

            setters.append(TabelTugas.tanggalSelesaiEfektif <- tanggalBerhenti)

            if let statusTugas {
                setters.append(TabelTugas.statusPenugasan <- statusTugas.rawValue)
            }

            guard !setters.isEmpty else {
                #if DEBUG
                    print("Tidak ada field yang diupdate untuk Penugasan ID \(idPenugasan)")
                #endif
                return false
            }

            try db.run(rowToUpdate.update(setters))
            return true
        } catch {
            #if DEBUG
                print("Gagal update penugasan guru ID \(idPenugasan): \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Menyisipkan data mapel baru ke dalam database jika belum ada, atau mengambil ID mapel yang sudah ada.
    /// - Parameter namaMapel: Nama mapel yang ingin dimasukkan atau diambil ID-nya.
    /// - Returns: ID mapel (`Int64`) jika berhasil, atau `nil` jika gagal.
    /// - Note: Fungsi ini berjalan secara asynchronous.
    func insertOrGetMapelID(namaMapel: String) async -> Int64? {
        addMapelAutoComplete(namaMapel)
        return await upsertGetIDAsync(
            suggestions: [.mapel: namaMapel],
            checkInsert: { [unowned self] db in
                if let row = try db.pluck(MapelColumns.tabel.filter(MapelColumns.nama == namaMapel)) {
                    return row[MapelColumns.id]
                } else {
                    return try self.db.run(MapelColumns.tabel.insert(MapelColumns.nama <- namaMapel))
                }
            }
        )
    }

    /// Mencari ID guru berdasarkan nama. Jika guru tidak ditemukan, sisipkan guru baru dan kembalikan ID-nya.
    ///
    /// - Parameters:
    ///   - nama: Nama guru yang ingin dicari atau disisipkan.
    ///   - alamat: Alamat guru (digunakan jika sisipan baru, opsional).
    ///   - tahunAktif: Tahun aktif guru (digunakan jika sisipan baru, opsional).
    ///   - jabatan: Jabatan guru (digunakan jika sisipan baru, opsional).
    /// - Returns: ID dari guru yang ditemukan atau baru disisipkan.
    func insertOrGetGuruID(nama: String, alamat: String? = nil) async -> Int64? {
        await upsertGetIDAsync(
            suggestions: [.guru: nama],
            checkInsert: { [unowned self] db in
                let query = GuruColumns.tabel.filter(GuruColumns.nama == nama)
                if let row = try db.pluck(query) {
                    #if DEBUG
                        print("Guru '\(nama)' ditemukan dengan ID: \(row[GuruColumns.id])")
                    #endif
                    return row[GuruColumns.id]
                } else {
                    guard let newID = tambahGuru(nama, alamat: alamat) else { return nil }
                    #if DEBUG
                        print("Guru baru '\(nama)' disisipkan dengan ID: \(newID)")
                    #endif
                    return newID
                }
            }
        )
    }

    /// Mencari ID penugasan guru-mapel-kelas berdasarkan trio ID.
    /// Jika belum ada, sisipkan penugasan baru.
    /// - Parameters:
    ///   - guruID: ID Guru.
    ///   - mapelID: ID Mapel.
    ///   - kelasID: ID Kelas.
    /// - Returns: ID penugasan yang ditemukan atau baru disisipkan.
    func insertOrGetPenugasanID(guruID: Int64, mapelID: Int64, kelasID: Int64, jabatanID: Int64? = nil, tanggalMulai: String? = nil) async -> Int64? {
        return await upsertGetIDAsync { [unowned self] db in
            // 1) Cek penugasan yang ada
            let table = TabelTugas.tabel
            let filter = table.filter(
                TabelTugas.idGuru == guruID &&
                    TabelTugas.idMapel == mapelID &&
                    TabelTugas.idKelas == kelasID
            )

            let rows = try Array(db.prepare(filter))

            // 1️⃣ Cek match jabatan
            if let jabatanID,
               let exact = rows.first(where: { $0[TabelTugas.idJabatan] == jabatanID })
            {
                return exact[TabelTugas.id]
            }
            // 2️⃣ Fallback first
            if let first = rows.first {
                return first[TabelTugas.id]
            }

            let tanggalFix = tanggalMulai == nil
                ? ReusableFunc.buatFormatTanggal(Date())!
                : tanggalMulai!

            // 3️⃣ Kalau tidak ada, insert penugasan baru
            guard let newID = buatPenugasanGuru(idGuru: guruID, idJabatan: jabatanID ?? 1, idMapel: mapelID, idKelas: kelasID, tanggalMulai: tanggalFix, tanggalBerhenti: nil, statusTugas: .aktif) else { return nil }

            #if DEBUG
                print("Penugasan baru disisipkan [guru:\(guruID), mapel:\(mapelID), kelas:\(kelasID)] idPenugasan: \(newID)")
            #endif

            return newID
        }
    }

    /// Menyisipkan data jabatan baru dengan nama yang diberikan ke dalam database jika belum ada,
    /// atau mengambil ID jabatan yang sudah ada dengan nama tersebut.
    /// - Parameter nama: Nama jabatan yang ingin disisipkan atau diambil ID-nya.
    /// - Returns: ID jabatan (`Int64`) jika berhasil, atau `nil` jika terjadi kesalahan.
    /// - Note: Fungsi ini berjalan secara asynchronous.
    func insertOrGetJabatanID(_ nama: String) async -> Int64? {
        await upsertGetIDAsync(
            checkInsert: { [unowned self] db in
                if let row = try db.pluck(JabatanColumns.tabel.filter(JabatanColumns.nama == nama)) {
                    return row[JabatanColumns.id]
                } else {
                    return self.tambahJabatan(nama)
                }
            }
        )
    }

    // MARK: - STRUKTUR GURU

    /// Mengambil daftar `GuruModel` berdasarkan tahun ajaran tertentu.
    ///
    /// Fungsi ini melakukan query ke database untuk mengambil data guru beserta penugasannya,
    /// dengan melakukan join ke tabel jabatan dan kelas. Data yang diambil akan difilter berdasarkan:
    /// - Guru yang telah dihapus (deleted) atau di-undo penambahannya tidak akan diikutsertakan.
    /// - Penugasan guru yang telah dihapus juga tidak akan diikutsertakan.
    /// - Jika parameter `tahunAjaran` diberikan, maka hanya data guru pada tahun ajaran tersebut yang diambil.
    ///
    /// Hanya kolom-kolom tertentu yang diambil dari database untuk mengisi properti utama pada `GuruModel`.
    /// Properti lain pada `GuruModel` akan tetap pada nilai default atau `nil`.
    ///
    /// - Parameter tahunAjaran: Tahun ajaran yang ingin difilter (opsional). Jika nil, akan mengambil semua tahun ajaran.
    /// - Returns: Array berisi objek `GuruModel` yang sesuai dengan filter yang diberikan.
    func getGuruByTahunAjaran(tahunAjaran: String? = nil) async -> [GuruModel] {
        var hasil: [GuruModel] = []

        // Ambil ID guru dan penugasan yang dihapus/undo dari SingletonData
        let deletedGuruIDs = Array(SingletonData.deletedGuru)
        let undoAddGuruIDs = Array(SingletonData.undoAddGuru)
        let deletedPenugasanIDs = Array(SingletonData.deletedTugasGuru)

        do {
            hasil = try await DatabaseManager.shared.pool.read { conn in
                // Bangun dasar kueri dengan join yang diperlukan
                var query = GuruColumns.tabel
                    .join(.inner, TabelTugas.tabel, on: GuruColumns.tabel[GuruColumns.id] == TabelTugas.tabel[TabelTugas.idGuru])
                    .join(.leftOuter, JabatanColumns.tabel,
                          on: TabelTugas.tabel[TabelTugas.idJabatan] == JabatanColumns.tabel[JabatanColumns.id])
                    .join(.leftOuter, KelasColumns.tabel, // Perlu join ke KelasColumns untuk filter tahun ajaran
                          on: KelasColumns.tabel[KelasColumns.id] == TabelTugas.tabel[TabelTugas.idKelas])
                    .filter(
                        // Filter berdasarkan ID yang dihapus atau di-undo
                        !deletedGuruIDs.contains(GuruColumns.tabel[GuruColumns.id]) &&
                            !undoAddGuruIDs.contains(GuruColumns.tabel[GuruColumns.id]) &&
                            !deletedPenugasanIDs.contains(TabelTugas.tabel[TabelTugas.id])
                    )
                if let tahunAjaran {
                    query = query.filter(KelasColumns.tabel[KelasColumns.tahunAjaran] == tahunAjaran) // Filter utama berdasarkan tahun ajaran)
                }

                // Hanya pilih kolom yang dibutuhkan.
                // Meskipun kita mengembalikan GuruModel lengkap, kita tetap bisa membatasi kolom yang ditarik dari DB.
                query = query.select(
                    GuruColumns.tabel[GuruColumns.id],
                    TabelTugas.tabel[TabelTugas.id],
                    GuruColumns.tabel[GuruColumns.nama],
                    JabatanColumns.tabel[JabatanColumns.nama],
                    KelasColumns.tabel[KelasColumns.tahunAjaran]
                    // Hanya kolom-kolom ini yang akan ditarik. Properti lain di GuruModel akan tetap default/nil.
                )

                var daftarGuru: [GuruModel] = []

                for row in try conn.prepare(query) {
                    let guruID = row[GuruColumns.tabel[GuruColumns.id]]
                    let idTugas = row[TabelTugas.tabel[TabelTugas.id]] // Perlu untuk inisialisasi GuruModel

                    // Buat instance GuruModel dari baris hasil kueri
                    let guru = GuruModel(idGuru: guruID, idTugas: idTugas) // Inisialisasi dengan ID wajib
                    guru.namaGuru = row[GuruColumns.tabel[GuruColumns.nama]] // Nama guru
                    guru.struktural = row[JabatanColumns.tabel[JabatanColumns.nama]] // Nama jabatan
                    guru.tahunaktif = row[KelasColumns.tabel[KelasColumns.tahunAjaran]] // Tahun ajaran

                    // Properti GuruModel lainnya (alamatGuru, mapel, statusTugas, kelas, tglMulai, tglSelesai)
                    // tidak akan diisi dari kueri ini dan akan tetap pada nilai default atau nil.

                    daftarGuru.append(guru)
                }

                return daftarGuru
            }

        } catch {
            print("Error saat mengambil data guru berdasarkan tahun ajaran: \(error.localizedDescription)")
            #if DEBUG
                print("DB error: \(error.localizedDescription)")
            #endif
        }

        return hasil
    }
}
