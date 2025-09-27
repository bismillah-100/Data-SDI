//
//  SiswaQuery.swift
//  Data SDI
//
//  Created by MacBook on 12/07/25.
//

import Foundation
import SQLite

extension DatabaseController {
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
    @discardableResult
    func catatSiswa(_ data: SiswaDefaultData) -> Int64? {
        do {
            let query = SiswaColumns.tabel.insert(
                SiswaColumns.nama <- data.nama,
                SiswaColumns.alamat <- data.alamat,
                SiswaColumns.ttl <- data.ttl,
                SiswaColumns.tahundaftar <- data.tahundaftar,
                SiswaColumns.namawali <- data.namawali,
                SiswaColumns.nis <- data.nis,
                SiswaColumns.nisn <- data.nisn,
                SiswaColumns.ayah <- data.ayah,
                SiswaColumns.ibu <- data.ibu,
                SiswaColumns.jeniskelamin <- data.jeniskelamin.rawValue,
                SiswaColumns.status <- data.status.rawValue,
                SiswaColumns.tanggalberhenti <- data.tanggalberhenti,
                SiswaColumns.tlv <- data.tlv,
                SiswaColumns.foto <- data.foto ?? nil
            )

            var namaWords: Set<String> = []
            var alamatWords: Set<String> = []
            var ttlWords: Set<String> = []
            var namaWaliWords: Set<String> = []
            var nisWords: Set<String> = []
            var nisnWords: Set<String> = []
            var tlvWords: Set<String> = []
            var ayah: Set<String> = []
            var ibu: Set<String> = []
            namaWords.formUnion(data.nama.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            namaWords.insert(data.nama.capitalizedAndTrimmed())
            alamatWords.formUnion(data.alamat.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            alamatWords.insert(data.alamat.capitalizedAndTrimmed())
            ttlWords.formUnion(data.ttl.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ttlWords.insert(data.ttl.capitalizedAndTrimmed())
            nisWords.formUnion(data.nis.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            nisWords.insert(data.nis.capitalizedAndTrimmed())
            namaWaliWords.formUnion(data.namawali.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            namaWaliWords.insert(data.namawali.capitalizedAndTrimmed())
            nisnWords.formUnion(data.nisn.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            nisnWords.insert(data.nisn.capitalizedAndTrimmed())
            tlvWords.formUnion(data.tlv.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            tlvWords.insert(data.tlv.capitalizedAndTrimmed())
            ayah.formUnion(data.ayah.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ayah.insert(data.ibu.capitalizedAndTrimmed())
            ibu.formUnion(data.ibu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            ibu.insert(data.ibu.capitalizedAndTrimmed())

            ReusableFunc.namasiswa.formUnion(namaWords)
            ReusableFunc.alamat.formUnion(alamatWords)
            ReusableFunc.namaAyah.formUnion(ayah)
            ReusableFunc.namaIbu.formUnion(ibu)
            ReusableFunc.namawali.formUnion(namaWaliWords)
            ReusableFunc.ttl.formUnion(ttlWords)
            ReusableFunc.nis.formUnion(nisWords)
            ReusableFunc.nisn.formUnion(nisnWords)
            ReusableFunc.tlvString.formUnion(tlvWords)

            return try db.run(query)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        let data: [SiswaColumn: String] = [
            .nama: data.nama,
            .alamat: data.alamat,
            .ttl: data.ttl,
            .namawali: data.namawali,
            .nis: data.nis,
            .nisn: data.nisn,
            .ayah: data.ayah,
            .ibu: data.ibu,
            .tlv: data.tlv,
        ]
        catatSuggestions(data: data)

        return nil
    }

    private func composeFilteredSiswaSQL(group _: Bool = false, applyFilter _: Bool = true, siswaID: Int64? = nil) -> (sql: String, bindings: [Binding]) {
        /* Status: 1: Aktif, 2: Berhenti, 3: Lulus */

        // Kondisi untuk menambahkan status '2' ke subquery
        let subqueryEnrollmentStatusWhereClause = "WHERE status_enrollment IN ('1', '2', '3')"

        // SQL dasar dengan JOIN
        var sql = """
        SELECT
          s.id, s.Nama, s.Alamat, s.`T.T.L.`, s.`Tahun Daftar`, s.`Nama Wali`,
          s.NIS, s.Status, s.`Tgl. Lulus`, s.`Jenis Kelamin`, s.NISN,
          k.tingkat_kelas AS tingkat_kelas,
          s.Ayah, s.Ibu, s.`Nomor Telepon`
        FROM siswa AS s
        LEFT JOIN (
            SELECT sk1.id_siswa_kelas, sk1.id_siswa, sk1.id_kelas, sk1.status_enrollment
            FROM siswa_kelas sk1
            INNER JOIN (
                SELECT id_siswa, MAX(id_siswa_kelas) AS max_id
                FROM siswa_kelas
                \(subqueryEnrollmentStatusWhereClause)
                GROUP BY id_siswa
            ) AS latest
            ON sk1.id_siswa_kelas = latest.max_id
        ) AS sk ON sk.id_siswa = s.id
        LEFT JOIN kelas AS k ON k.idKelas = sk.id_kelas
        """

        // 3. Bangun kondisi WHERE
        var conditions: [String] = []
        var bindings: [Binding] = []

        if let id = siswaID {
            conditions.append("s.id = ?")
            bindings.append(id as Binding)
        } else {
            // Kumpulkan ID siswa yang dikecualikan
            var deletedIDs: Set<Int64> = []
            deletedIDs.formUnion(SingletonData.deletedStudentIDs)
            SingletonData.deletedSiswaArray.forEach { deletedIDs.insert($0.id) }
            SingletonData.deletedSiswasArray.flatMap { $0 }.forEach { deletedIDs.insert($0.id) }
            SingletonData.redoPastedSiswaArray.flatMap { $0 }.forEach { deletedIDs.insert($0.id) }

            // Lanjutkan dengan logika filter yang ada jika siswaID adalah nil
            // bangun daftar status positif
            var allowed: Set<String> = []
            allowed.insert("1")

            if UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                allowed.insert("3")
            }
            if !UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
                allowed.insert("2")
            }
            if !allowed.isEmpty {
                let ph = Array(repeating: "?", count: allowed.count).joined(separator: ", ")
                conditions.append("s.Status IN (\(ph))")
                bindings.append(contentsOf: allowed.map { $0 as Binding })
            }

            // id NOT IN tetap di-handle seperti biasa
            if !deletedIDs.isEmpty {
                let ph = Array(repeating: "?", count: deletedIDs.count).joined(separator: ", ")
                conditions.append("s.id NOT IN (\(ph))")
                bindings.append(contentsOf: deletedIDs.map { $0 as Binding })
            }
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        return (sql, bindings)
    }

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
    func getSiswa(_ group: Bool? = nil) async -> [ModelSiswa] {
        var result: [ModelSiswa] = []
        let (sql, bindings) = composeFilteredSiswaSQL(group: group ?? false)

        do {
            let stmt = try await DatabaseManager.shared.pool.read { db in
                try db.prepare(sql, bindings)
            }
            await withTaskGroup(of: ModelSiswa?.self) { group in
                for row in stmt {
                    group.addTask {
                        guard let siswa = ModelSiswa(from: row) else { return nil }
                        return siswa
                    }
                }

                for await siswa in group {
                    if let siswa {
                        result.append(siswa)
                    }
                }
            }
        } catch {
            #if DEBUG
                print("Error prepare/fetch raw: \(error)")
            #endif
        }

        return result
    }

    /// Mengambil data siswa berdasarkan ID yang diberikan.
    ///
    /// - Parameter idValue: ID siswa (`Int64`) yang ingin dicari.
    /// - Returns: Objek `ModelSiswa` yang berisi data siswa yang ditemukan. Jika siswa tidak ditemukan
    ///            atau terjadi kesalahan, objek `ModelSiswa` yang dikembalikan akan memiliki nilai default.
    func getSiswa(idValue: Int64) -> ModelSiswa {
        let semaphore = DispatchSemaphore(value: 0)
        let resultPointer = UnsafeMutablePointer<ModelSiswa>.allocate(capacity: 1)
        resultPointer.initialize(to: ModelSiswa())

        Task {
            let asyncResult = await getSiswaAsync(idValue: idValue)
            resultPointer.pointee = asyncResult
            semaphore.signal()
        }

        semaphore.wait()
        let result = resultPointer.pointee
        resultPointer.deallocate()

        return result
    }

    func getSiswaAsync(idValue: Int64) async -> ModelSiswa {
        let (sql, bindings) = composeFilteredSiswaSQL(group: false, applyFilter: false, siswaID: idValue)
        do {
            let stmt = try await pool.read { conn in
                try conn.prepare(sql, bindings)
            }
            if let row = stmt.next() { // Menggunakan .next() untuk mengambil satu baris
                if let siswa = ModelSiswa(from: row) {
                    return siswa
                }
            }
        } catch {
            #if DEBUG
                print("❌ getSiswa(idValue:) error: \(error.localizedDescription)")
            #endif
        }
        return ModelSiswa()
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
    func getKelasSiswa(_ idValue: Int64) -> ModelSiswa? {
        let sql = joinedSiswaKelasLatestSQL() + " WHERE s.id = ? LIMIT 1"
        do {
            let stmt = try db.prepare(sql, [idValue])
            if let row = stmt.next(),
               let nama = row[1] as? String,
               let kelas = row[2] as? String
            {
                let siswa = ModelSiswa()
                siswa.id = idValue
                siswa.nama = nama
                siswa.tingkatKelasAktif = KelasAktif(rawValue: kelas) ?? .belumDitentukan
                return siswa
            }
        } catch {
            print("❌ Error getNamaDanKelasTerakhir: \(error)")
        }
        return nil
    }

    private func joinedSiswaKelasLatestSQL() -> String {
        """
        SELECT
            s.id,
            s.Nama,
            k.tingkat_kelas AS tingkat_kelas
        FROM siswa AS s
        LEFT JOIN (
            SELECT sk1.id_siswa, sk1.id_kelas
            FROM siswa_kelas sk1
            INNER JOIN (
                SELECT id_siswa, MAX(id_siswa_kelas) AS max_id
                FROM siswa_kelas
                GROUP BY id_siswa
            ) AS latest
            ON sk1.id_siswa_kelas = latest.max_id
        ) AS sk ON sk.id_siswa = s.id
        LEFT JOIN kelas AS k ON k.idKelas = sk.id_kelas
        """
    }

    /// Membaca data foto siswa di Database sesuai dengan ID yang diterima.
    ///
    /// - Parameter idValue: ID Siswa yang akan dicari di Database.
    /// - Returns: Data foto yang didapatkan dari Database yang dibungkus dengan kerangka data.
    ///
    /// * Note: Gambar yang telah dikueri disimpan sebagai cache di ``ImageCacheManager``.
    /// * Note: Fungsi ini mengembalikan gambar dari ``ImageCacheManager`` jika sebelumnya gambar telah dicache.
    func bacaFotoSiswa(idValue: Int64) -> Data {
        if let cached = ImageCacheManager.shared.getCachedSiswa(for: idValue) {
            return cached
        }
        var fotoSiswa = Data()
        do {
            if let rowValue = try db.pluck(SiswaColumns.tabel.filter(SiswaColumns.id == idValue)),
               let fotoBlob = try rowValue.get(SiswaColumns.foto)
            {
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

    /// Mengambil nama siswa beserta ID mereka berdasarkan kelas yang ditentukan.
    ///
    /// - Parameter table: `String` yang merepresentasikan nama kelas (``KelasColumns/tingkat``) siswa yang ingin diambil.
    /// - Returns: Sebuah `Dictionary` dengan `String` sebagai kunci (nama siswa) dan `Int64` sebagai nilai (ID siswa).
    ///            Akan mengembalikan dictionary kosong jika tidak ada siswa yang ditemukan atau terjadi kesalahan.
    func getNamaSiswa(withTable table: String) -> [String: Int64] {
        var siswaData: [String: Int64] = [:]
        let siswa = SiswaColumns.tabel
        let siswaKelas = SiswaKelasColumns.tabel
        let kelas = KelasColumns.tabel
        let tingkatKelas = table.replacingOccurrences(of: "Kelas ", with: "")
        let query = siswa
            .join(.inner, siswaKelas,
                  on: siswa[SiswaColumns.id] == siswaKelas[SiswaKelasColumns.idSiswa] &&
                      siswaKelas[SiswaKelasColumns.statusEnrollment] == StatusSiswa.aktif.rawValue)
            .join(.inner, kelas,
                  on: siswaKelas[SiswaKelasColumns.idKelas] == kelas[KelasColumns.id] &&
                      kelas[KelasColumns.tingkat] == tingkatKelas)
            .order(siswa[SiswaColumns.nama].asc)
            .filter(!SingletonData.deletedStudentIDs.contains(siswa[SiswaColumns.id]))

        do {
            // Filter data siswa berdasarkan kelasSekarang
            for user in try db.prepare(query) {
                let namaSiswa = user[SiswaColumns.nama]
                let siswaID = user[SiswaColumns.id]
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
    func updateStatusSiswa(idSiswa: Int64, newStatus: StatusSiswa) {
        do {
            let statusBaru = SiswaColumns.tabel.filter(SiswaColumns.id == idSiswa)
            try db.run(statusBaru.update(
                SiswaColumns.status <- newStatus.rawValue
            ))
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
    ///   - jeniskelaminValue: Jenis kelamin siswa yang baru (`enum` ``JenisKelamin).
    ///   - statusValue: Status siswa yang baru (`enum` ``StatusSiswa``).
    ///   - tanggalberhentiValue: Tanggal berhenti siswa yang baru (`String`).
    ///   - nisnValue: Nomor Induk Siswa Nasional (NISN) siswa yang baru (`String`).
    ///   - updatedAyah: Nama ayah siswa yang baru (`String`).
    ///   - updatedIbu: Nama ibu siswa yang baru (`String`).
    ///   - updatedTlv: Nilai TLV siswa yang baru (`String`).
    func updateSiswa(idValue: Int64, namaValue: String, alamatValue: String, ttlValue: String, tahundaftarValue: String, namawaliValue: String, nisValue: String, jeniskelaminValue: JenisKelamin, statusValue: StatusSiswa, tanggalberhentiValue: String, nisnValue: String, updatedAyah: String, updatedIbu: String, updatedTlv: String) {
        do {
            let user = SiswaColumns.tabel.filter(SiswaColumns.id == idValue)
            try db.run(user.limit(1).update(
                SiswaColumns.nama <- namaValue,
                SiswaColumns.alamat <- alamatValue,
                SiswaColumns.ttl <- ttlValue,
                SiswaColumns.tahundaftar <- tahundaftarValue,
                SiswaColumns.namawali <- namawaliValue,
                SiswaColumns.nis <- nisValue,
                SiswaColumns.nisn <- nisnValue,
                SiswaColumns.ayah <- updatedAyah,
                SiswaColumns.ibu <- updatedIbu,
                SiswaColumns.tlv <- updatedTlv,
                SiswaColumns.jeniskelamin <- jeniskelaminValue.rawValue,
                SiswaColumns.status <- statusValue.rawValue,
                SiswaColumns.tanggalberhenti <- tanggalberhentiValue
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
    func updateKolomSiswa(_ id: Int64, kolom: Expression<String>, data: String) {
        do {
            let user = SiswaColumns.tabel.filter(SiswaColumns.id == id)
            try db.run(user.limit(1).update(
                kolom <- data
            ))
        } catch {
            print(error.localizedDescription)
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
        do {
            // 3. Prepare dan eksekusi raw SQL secara async
            let stmt = try await DatabaseManager.shared.pool.read { conn in
                // 1. Siapkan base SQL + bindings
                let (baseSQL, baseBindings) = self.composeFilteredSiswaSQL(group: false)
                var sql = baseSQL
                var bindings = baseBindings

                // 2. Tambahkan filter pencarian
                let q = query.lowercased()
                let likePattern = "%\(q)%"
                if q.hasPrefix("kelas ") {
                    let kelasKey = q.replacingOccurrences(of: "kelas ", with: "")
                    sql += baseBindings.isEmpty ? " WHERE" : " AND"
                    sql += " LOWER(tingkat_kelas) LIKE ?"
                    bindings.append("%\(kelasKey)%")
                } else {
                    sql += baseBindings.isEmpty ? " WHERE" : " AND"
                    sql += """
                    (
                      LOWER(Nama) LIKE ? OR
                      LOWER(NIS) LIKE ? OR
                      LOWER(NISN) LIKE ? OR
                      LOWER(Alamat) LIKE ? OR
                      LOWER(`Jenis Kelamin`) LIKE ?
                    )
                    """
                    // masing‑masing param
                    for _ in 0 ..< 5 {
                        bindings.append(likePattern)
                    }
                }

                return try conn.prepare(sql, bindings)
            }

            // 4. Paralelisasi mapping row→ModelSiswa
            let hasil: [ModelSiswa] = await withTaskGroup(of: ModelSiswa?.self) { group in
                // spawn task untuk tiap row
                for row in stmt {
                    group.addTask {
                        // pakai init?(from:) yang sudah didefinisikan di ModelSiswa
                        ModelSiswa(from: row)
                    }
                }

                // kumpulkan
                var temp: [ModelSiswa] = []
                for await m in group {
                    if let s = m {
                        temp.append(s)
                    }
                }
                return temp
            }

            return hasil
        } catch {
            #if DEBUG
                print("searchSiswa error:", error)
            #endif
            return []
        }
    }

    /// Menghapus data siswa dari tabel `siswa` dan semua tabel kelas terkait (kelas1 hingga kelas6)
    /// berdasarkan ID siswa yang diberikan. Setelah penghapusan, database akan di-vacuum.
    ///
    /// - Parameter idValue: ID siswa (`Int64`) yang datanya ingin dihapus.
    func hapusDaftar(idValue: Int64) {
        do {
            try db.transaction {
                // 1. Temukan semua id_siswa_kelas yang terkait dengan siswa ini
                let siswaKelasEntries = try db.prepare(SiswaKelasColumns.tabel.filter(SiswaKelasColumns.idSiswa == idValue))
                var associatedSiswaKelasIDs: [Int64] = []
                for row in siswaKelasEntries {
                    try associatedSiswaKelasIDs.append(row.get(SiswaKelasColumns.id))
                }

                // 2. Hapus semua nilai terkait dari nilai_siswa_mapel
                // Hanya jalankan jika ada id_siswa_kelas yang ditemukan
                if !associatedSiswaKelasIDs.isEmpty {
                    let nilaiFilter = NilaiSiswaMapelColumns.tabel.filter(associatedSiswaKelasIDs.contains(NilaiSiswaMapelColumns.idSiswaKelas))
                    try db.run(nilaiFilter.delete())
                    #if DEBUG
                        print("Berhasil menghapus nilai terkait siswa ID: \(idValue)")
                    #endif
                }

                // 3. Hapus relasi siswa-kelas dari siswa_kelas
                let siswaKelasFilter = SiswaKelasColumns.tabel.filter(SiswaKelasColumns.idSiswa == idValue)
                try db.run(siswaKelasFilter.delete())
                #if DEBUG
                    print("Berhasil menghapus relasi siswa-kelas untuk siswa ID: \(idValue)")
                #endif

                // 4. Akhirnya, hapus siswa dari tabel siswa
                let siswaFilter = SiswaColumns.tabel.filter(SiswaColumns.id == idValue)
                try db.run(siswaFilter.delete())
                #if DEBUG
                    print("Berhasil menghapus siswa ID: \(idValue) secara permanen.")
                #endif
            }
            vacuumDatabase() // Panggil vacuum setelah transaksi selesai dan berhasil
        } catch {
            print(error.localizedDescription)
        }
    }

    /// Fungsi untuk membatalkan update foto siswa dan mendukung mekanisme undo.
    /// - Parameters:
    ///   - idx: ID siswa yang fotonya ingin di-undo.
    ///   - oldImageData: Data gambar lama yang akan dikembalikan.
    ///   - undoManager: Objek UndoManager untuk mencatat aksi undo.
    /// * Note: Gambar yang ditambahkan disimpan sebagai cache di ``ImageCacheManager``.
    func undoUpdateFoto(idx: Int64, oldImageData: Data, undoManager: UndoManager) {
        let query = SiswaColumns.tabel.filter(SiswaColumns.id == idx)

        do {
            // Ambil data foto saat ini (sebelum di-undo) untuk didaftarkan ke undo berikutnya
            if let rowValue = try db.pluck(query),
               let currentImageData = try rowValue.get(SiswaColumns.foto)
            {
                // Daftarkan undo dengan data saat ini sebagai oldImageData berikutnya
                undoManager.registerUndo(withTarget: self) { target in
                    target.undoUpdateFoto(idx: idx, oldImageData: currentImageData, undoManager: undoManager)
                }
            }

            // Jalankan update ke data lama
            try db.run(query.update(SiswaColumns.foto <- oldImageData))

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
        let updateQuery = SiswaColumns.tabel.filter(SiswaColumns.id == idx)

        do {
            if let undoManager, let rowValue = try db.pluck(updateQuery) {
                let oldImageData = try rowValue.get(SiswaColumns.foto) ?? Data()
                // Daftarkan undo
                undoManager.registerUndo(withTarget: self) { [oldImageData] target in
                    target.undoUpdateFoto(idx: idx, oldImageData: oldImageData, undoManager: undoManager)
                }
            }

            try db.run(updateQuery.limit(1).update(SiswaColumns.foto <- imageData))

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

    /// Mengubah status keaktifan siswa, seperti meluluskan atau mengaktifkan kembali.
    ///
    /// Fungsi ini memperbarui status keaktifan (`statusEnrollment`) siswa pada entri database.
    /// Jika status baru bukan `.aktif`, maka pencarian dilakukan pada entri dengan status `.aktif`,
    /// dan sebaliknya. Perubahan akan diterapkan pada semua entri siswa yang ditemukan.
    /// Jika `tanggalLulus` disediakan, nilai tersebut akan diatur sebagai `tanggalKeluar`.
    ///
    /// Operasi ini dilakukan dalam sebuah blok `do-catch` untuk menangani kemungkinan kesalahan saat menjalankan query SQLite.
    ///
    /// - Parameters:
    ///   - siswaID: ID unik siswa (`Int64`) yang akan diperbarui.
    ///   - tanggalLulus: Tanggal siswa keluar/lulus (`String`), opsional. Jika disediakan, akan disimpan di kolom `tanggalKeluar`.
    ///   - statusEnrollment: Status baru siswa (`StatusSiswa`), seperti `.lulus` atau `.aktif`.
    func editSiswaLulus(siswaID: Int64, tanggalLulus: String? = nil, statusEnrollment: StatusSiswa, registerUndo: Bool = true) {
        do {
            let siswaKelas = SiswaKelasColumns.tabel
            let filter: StatusSiswa = statusEnrollment != .aktif ? .aktif : .lulus
            let aktifRows = siswaKelas
                .filter(
                    SiswaKelasColumns.idSiswa == siswaID &&
                        SiswaKelasColumns.statusEnrollment == filter.rawValue
                )

            let rows = try db.prepare(aktifRows).map { $0 }
            guard !rows.isEmpty else { return }

            for row in rows {
                let rowID = row[SiswaKelasColumns.id]
                let upd = siswaKelas.filter(SiswaKelasColumns.id == rowID)
                try db.run(upd.update(
                    SiswaKelasColumns.statusEnrollment <- statusEnrollment.rawValue,
                    SiswaKelasColumns.tanggalKeluar <- tanggalLulus
                ))
            }
            guard registerUndo else { return }
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: DatabaseController.shared) { _ in
                if tanggalLulus != nil {
                    DatabaseController.shared.editSiswaLulus(siswaID: siswaID, tanggalLulus: nil, statusEnrollment: .aktif)
                } else {
                    DatabaseController.shared.editSiswaLulus(siswaID: siswaID, tanggalLulus: ReusableFunc.buatFormatTanggal(Date())!, statusEnrollment: .lulus)
                }
            }
        } catch {
            #if DEBUG
                print("Gagal meluluskan siswa: \(error)")
            #endif
        }
    }

    /// Menghitung jumlah siswa berdasarkan status yang diberikan.
    ///
    /// - Parameter statusFilter: `String` yang merepresentasikan status siswa yang ingin dihitung (misalnya, "Aktif", "Tidak Aktif").
    /// - Returns: Jumlah siswa (`Int`) yang memiliki status sesuai `statusFilter`. Mengembalikan 0 jika terjadi kesalahan.
    func countSiswaByStatus(statusFilter: StatusSiswa) -> Int {
        do {
            return try db.scalar(SiswaColumns.tabel.filter(SiswaColumns.status == statusFilter.rawValue).count)
        } catch {
            return 0
        }
    }

    /// Menghitung total jumlah siswa dalam database.
    ///
    /// - Returns: Jumlah seluruh siswa (`Int`) yang terdaftar. Mengembalikan 0 jika terjadi kesalahan.
    func countAllSiswa() -> Int {
        do {
            return try db.scalar(SiswaColumns.tabel.count)
        } catch {
            return 0
        }
    }
}
