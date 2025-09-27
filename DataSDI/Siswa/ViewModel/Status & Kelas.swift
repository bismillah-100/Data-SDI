//
//  Status & Kelas.swift
//  Data SDI
//
//  Created by MacBook on 18/09/25.
//

import Foundation

extension SiswaViewModel {
    // MARK: - Constants

    /// Konstanta internal untuk prefix nama kelas, semester, dan nama default kelas.
    /// Kumpulan konstanta internal yang digunakan di `SiswaViewModel`
    /// untuk standarisasi nilai default dan prefix string terkait kelas.
    ///
    /// - Note: Enum ini bersifat `private` sehingga hanya dapat diakses di dalam `SiswaViewModel`.
    private enum Constants {
        /// Prefix default untuk nama kelas, digunakan saat memproses atau memformat string kelas.
        static let kelasPrefix = "Kelas "

        /// Prefix default untuk nama semester, digunakan saat memproses atau memformat string semester.
        static let semesterPrefix = "Semester "

        /// Nama default kelas yang digunakan jika tidak ada nama kelas yang ditentukan.
        static let defaultKelasNama = "A"
    }

    // MARK: - Helper Methods

    /// Mengatur status siswa menjadi aktif, baik di database maupun cache lokal.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan diaktifkan.
    ///   - kelas: Nama kelas opsional untuk memperbarui tingkat kelas aktif.
    func setAktif(for siswa: ModelSiswa, kelas: String? = nil) {
        setAktifDatabase(for: siswa)
        setAktifCache(for: siswa, kelas: kelas)
    }

    /// Memperbarui cache lokal siswa menjadi status aktif.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan diperbarui.
    ///   - kelas: Nama kelas opsional untuk memperbarui tingkat kelas aktif.
    private func setAktifCache(for siswa: ModelSiswa, kelas: String? = nil) {
        siswa.status = .aktif
        siswa.tanggalberhenti.removeAll()

        if let kelas, !kelas.isEmpty {
            siswa.tingkatKelasAktif = KelasAktif(rawValue: kelas) ?? .belumDitentukan
        }

        updateSiswa(siswa)
    }

    /// Memperbarui status siswa menjadi aktif di database.
    ///
    /// - Parameter siswa: Objek `ModelSiswa` yang akan diperbarui di database.
    private func setAktifDatabase(for siswa: ModelSiswa) {
        dbController.updateKolomSiswa(siswa.id, kolom: SiswaColumns.tanggalberhenti, data: "")
        dbController.updateStatusSiswa(idSiswa: siswa.id, newStatus: .aktif)
    }

    /// Menghapus prefix tertentu dari sebuah string.
    ///
    /// - Parameters:
    ///   - string: String yang akan diproses.
    ///   - prefix: Prefix yang akan dihapus.
    /// - Returns: String tanpa prefix yang ditentukan.
    private func removePrefix(_ string: String, prefix: String) -> String {
        string.replacingOccurrences(of: prefix, with: "")
    }

    /// Menentukan tingkat kelas dari string kelas aktif atau current.
    ///
    /// - Parameters:
    ///   - kelasAktif: String kelas aktif saat ini.
    ///   - current: String kelas fallback jika `kelasAktif` kosong.
    /// - Returns: Tingkat kelas tanpa prefix.
    @inline(__always)
    private func resolveTingkat(_ kelasAktif: String, current: String) -> String {
        removePrefix((!kelasAktif.isEmpty ? kelasAktif : current), prefix: Constants.kelasPrefix)
    }

    /// Mengirim event perubahan kelas untuk satu siswa.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang terkait dengan event.
    ///   - status: Status siswa yang memicu event.
    ///   - undo: Menandakan apakah event ini merupakan aksi undo.
    private func sendKelasEvent(for siswa: ModelSiswa, status: StatusSiswa, undo: Bool = false) {
        let kelas = siswa.tingkatKelasAktif.rawValue

        switch (status, undo) {
        case (.aktif, false): kelasEvent.send(.aktifkanSiswa(siswa.id, kelas: kelas))
        case (.aktif, true): kelasEvent.send(.nonaktifkanSiswa(siswa.id, kelas: kelas))
        case (_, false): kelasEvent.send(.kelasBerubah(siswa.id, fromKelas: kelas))
        case (_, true): kelasEvent.send(.undoUbahKelas(siswa.id, toKelas: kelas, status: siswa.status))
        }
    }

    /// Mengirim event perubahan kelas untuk beberapa siswa.
    ///
    /// - Parameters:
    ///   - siswa: Array `ModelSiswa` yang akan diproses.
    ///   - status: Status siswa yang memicu event.
    ///   - undo: Menandakan apakah event ini merupakan aksi undo.
    private func sendKelasEvents(_ siswa: [ModelSiswa], status: StatusSiswa, undo: Bool = false) {
        siswa.forEach { sendKelasEvent(for: $0, status: status, undo: undo) }
    }

    /// Mengirim event nonaktifkan kelas untuk beberapa siswa.
    ///
    /// - Parameter siswa: Array `ModelSiswa` yang akan dinonaktifkan.
    private func nonaktifkanStatusKelasEvents(_ siswa: [ModelSiswa]) {
        siswa.forEach { kelasEvent.send(.nonaktifkanSiswa($0.id, kelas: $0.tingkatKelasAktif.rawValue)) }
    }

    /// Memperbarui tanggal berhenti siswa berdasarkan status.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan diperbarui.
    ///   - status: Status siswa yang menentukan apakah tanggal berhenti dihapus atau diisi.
    private func updateTanggalBerhenti(for siswa: ModelSiswa, with status: StatusSiswa) {
        siswa.tanggalberhenti = (status == .naik) ? "" : ReusableFunc.todayString()
    }

    // MARK: - Kelas ID Management

    /// Mengambil atau membuat ID kelas berdasarkan tingkat, tahun ajaran, dan semester.
    ///
    /// - Parameters:
    ///   - tingkat: Tingkat kelas.
    ///   - tahunAjaran: Tahun ajaran.
    ///   - semester: Semester.
    /// - Returns: ID kelas (`Int64`) jika berhasil, atau `nil` jika gagal.
    private func getKelasID(tingkat: String, tahunAjaran: String, semester: String) async -> Int64? {
        await dbController.insertOrGetKelasID(
            nama: Constants.defaultKelasNama,
            tingkat: tingkat,
            tahunAjaran: tahunAjaran,
            semester: semester
        )
    }

    // MARK: - Batch Processing

    /// Memproses payload kenaikan kelas untuk beberapa siswa.
    ///
    /// - Parameter payload: Data `NaikKelasPayload` yang berisi informasi siswa, kelas baru, tahun ajaran, semester, status, dan opsi pembaruan kelas.
    /// - Returns: Tuple berisi array siswa yang diperbarui dan array konteks undo kenaikan kelas.
    func processNaikKelasPayload(_ payload: NaikKelasPayload) async -> ([ModelSiswa], [UndoNaikKelasContext]) {
        let tingkatKelas = removePrefix(payload.kelas, prefix: Constants.kelasPrefix)
        let formatSemester = removePrefix(payload.semester, prefix: Constants.semesterPrefix)

        let intoKelasID = await getKelasID(
            tingkat: tingkatKelas,
            tahunAjaran: payload.tahunAjaran,
            semester: formatSemester
        )

        return await processSiswaBatch(
            ids: payload.ids,
            intoKelasID: intoKelasID,
            tingkatBaru: tingkatKelas,
            tahunAjaran: payload.tahunAjaran,
            semester: formatSemester,
            status: payload.status,
            updateKelas: payload.updateKelas
        )
    }

    /// Memproses batch siswa berdasarkan daftar ID untuk kenaikan kelas atau pembaruan status.
    ///
    /// Fungsi ini berjalan secara asinkron dan memproses setiap siswa dalam `TaskGroup`
    /// untuk efisiensi. Jika `updateKelas` bernilai `true`, akan dibuat snapshot
    /// `UndoNaikKelasContext` untuk setiap siswa yang diproses.
    ///
    /// - Parameters:
    ///   - ids: Array ID siswa yang akan diproses.
    ///   - intoKelasID: ID kelas tujuan (opsional).
    ///   - tingkatBaru: Tingkat kelas baru.
    ///   - tahunAjaran: Tahun ajaran.
    ///   - semester: Semester.
    ///   - status: Status siswa baru.
    ///   - updateKelas: Menentukan apakah kelas siswa akan diperbarui.
    /// - Returns: Tuple berisi array siswa yang berhasil diproses dan array snapshot undo.
    private func processSiswaBatch(
        ids: [Int64],
        intoKelasID: Int64?,
        tingkatBaru: String,
        tahunAjaran: String,
        semester: String,
        status: StatusSiswa,
        updateKelas: Bool
    ) async -> ([ModelSiswa], [UndoNaikKelasContext]) {
        var combinedSiswa = [ModelSiswa]()
        var combinedSnapshot = [UndoNaikKelasContext]()

        await withTaskGroup(of: (ModelSiswa?, UndoNaikKelasContext?).self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard let self else { return (nil, nil) }

                    var snapshot: UndoNaikKelasContext? = nil
                    if updateKelas {
                        snapshot = dbController.naikkanSiswa(
                            id,
                            intoKelasId: intoKelasID,
                            tingkatBaru: tingkatBaru,
                            tahunAjaran: tahunAjaran,
                            semester: semester,
                            tanggalNaik: ReusableFunc.todayString(),
                            statusEnrollment: status
                        )
                    }

                    guard let siswa = dataSource.siswa(for: id) else { return (nil, nil) }
                    return (siswa, snapshot)
                }
            }

            for await (siswa, snapshot) in group {
                if let siswa { combinedSiswa.append(siswa) }
                if let snapshot { combinedSnapshot.append(snapshot) }
            }
        }

        return (combinedSiswa, combinedSnapshot)
    }

    // MARK: - Status Management

    /// Memperbarui status sekelompok siswa ke status baru.
    ///
    /// Fungsi ini juga memperbarui tanggal berhenti di database, membuat konteks undo,
    /// memperbarui status di memori, dan mengirim event nonaktifkan kelas jika diperlukan.
    ///
    /// - Parameters:
    ///   - siswa: Array siswa yang akan diperbarui.
    ///   - newStatus: Status baru yang akan diterapkan.
    func updateStatus(siswa: [ModelSiswa], to newStatus: StatusSiswa) async {
        let tanggalSekarang = ReusableFunc.todayString()
        var contexts: [UndoNaikKelasContext] = []

        for s in siswa {
            dbController.updateKolomSiswa(s.id, kolom: SiswaColumns.tanggalberhenti, data: tanggalSekarang)
            dbController.updateStatusSiswa(idSiswa: s.id, newStatus: newStatus)

            if let ctx = dbController.naikkanSiswa(
                s.id,
                tanggalNaik: tanggalSekarang,
                statusEnrollment: newStatus
            ) {
                contexts.append(ctx)
            }

            if let siswa = dataSource.siswa(for: s.id) {
                siswa.status = newStatus
                updateTanggalBerhenti(for: s, with: newStatus)
            }
        }

        nonaktifkanStatusKelasEvents(siswa)
        registerUndo(undoContexts: contexts, siswa: siswa)
    }

    // MARK: - Naik Kelas Operations

    /// Menjalankan operasi kenaikan kelas untuk sekelompok siswa.
    ///
    /// Fungsi ini membuat snapshot siswa sebelum perubahan, menghitung ID kelas tujuan,
    /// memproses batch kenaikan kelas, mengirim event kelas, dan mendaftarkan undo jika ada perubahan.
    ///
    /// - Parameters:
    ///   - siswa: Array siswa yang akan dinaikkan.
    ///   - kelasAktif: Nama kelas aktif tujuan.
    ///   - tahunAjaran: Tahun ajaran.
    ///   - semester: Semester.
    ///   - status: Status siswa setelah kenaikan.
    /// - Returns: Array konteks undo untuk setiap siswa yang diproses.
    func naikkanSiswaBatch(
        siswa: [ModelSiswa],
        ke kelasAktif: String,
        tahunAjaran: String,
        semester: String,
        status: StatusSiswa
    ) async -> [UndoNaikKelasContext] {
        let snapshotSiswa = createSnapshot(of: siswa)
        let tingkat = removePrefix(kelasAktif, prefix: Constants.kelasPrefix)

        let intoKelasID = (status == .naik && !kelasAktif.isEmpty) ?
            await getKelasID(tingkat: tingkat, tahunAjaran: tahunAjaran, semester: semester) :
            nil

        let tanggalNaik = ReusableFunc.todayString()
        let contexts = await processSiswaBatch(
            siswa: siswa,
            tingkatBaru: tingkat,
            tahunAjaran: tahunAjaran,
            semester: semester,
            status: status,
            intoKelasID: intoKelasID,
            tanggalNaik: tanggalNaik
        )

        sendKelasEvents(snapshotSiswa, status: status)

        if !contexts.isEmpty {
            registerUndo(undoContexts: contexts, siswa: snapshotSiswa, aktifkanSiswa: status == .aktif)
        }

        return contexts
    }

    /// Memproses batch siswa untuk kenaikan kelas berdasarkan objek siswa.
    ///
    /// Fungsi ini memperbarui data di database, membuat konteks undo, dan mengatur status siswa menjadi aktif
    /// dengan kelas baru yang sesuai.
    ///
    /// - Parameters:
    ///   - siswa: Array siswa yang akan diproses.
    ///   - tingkatBaru: Tingkat kelas baru.
    ///   - tahunAjaran: Tahun ajaran.
    ///   - semester: Semester.
    ///   - status: Status siswa baru.
    ///   - intoKelasID: ID kelas tujuan (opsional).
    ///   - tanggalNaik: Tanggal kenaikan kelas.
    /// - Returns: Array konteks undo untuk setiap siswa yang diproses.
    private func processSiswaBatch(
        siswa: [ModelSiswa],
        tingkatBaru: String,
        tahunAjaran: String,
        semester: String,
        status: StatusSiswa,
        intoKelasID: Int64?,
        tanggalNaik: String
    ) async -> [UndoNaikKelasContext] {
        var contexts: [UndoNaikKelasContext] = []

        for s in siswa {
            let tingkatKelas = resolveTingkat(tingkatBaru, current: s.tingkatKelasAktif.rawValue)
            if let context = dbController.naikkanSiswa(
                s.id,
                intoKelasId: intoKelasID,
                tingkatBaru: tingkatKelas,
                tahunAjaran: tahunAjaran,
                semester: semester,
                tanggalNaik: tanggalNaik,
                statusEnrollment: status
            ) {
                contexts.append(context)
            }

            setAktif(for: s, kelas: "Kelas \(tingkatKelas)")
        }

        return contexts
    }

    // MARK: - Undo/Redo Operations

    /// Membatalkan operasi kenaikan kelas untuk sekelompok siswa.
    ///
    /// Fungsi ini akan:
    /// - Mengambil data siswa yang relevan dari cache atau database.
    /// - Mengembalikan state database ke kondisi sebelum kenaikan kelas.
    /// - Mengirim event undo ke UI.
    /// - Mendaftarkan aksi redo ke `siswaUndoManager`.
    ///
    /// - Parameters:
    ///   - contexts: Array konteks undo yang berisi informasi perubahan sebelumnya.
    ///   - siswa: Array siswa yang akan dikembalikan statusnya.
    ///   - aktifkanSiswa: Menentukan apakah undo adalah undo untuk aktifasi status siswa.
    func undoNaikKelas(
        contexts: [UndoNaikKelasContext],
        siswa: [ModelSiswa],
        aktifkanSiswa: Bool = false
    ) {
        let shouldFetch = UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") ||
            !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        let dataToProcess = flattenedData()
        let dataDict = buildDataDict(from: dataToProcess)
        let idsToProcess = siswa.map(\.id)

        let currentData = idsToProcess.compactMap { dataDict[$0] }
        let idsToFetch = Set(idsToProcess)
            .subtracting(currentData.map(\.id))
            .filter { _ in shouldFetch }

        let updatedModels = idsToFetch.isEmpty ? currentData : fetchMissingData(ids: idsToFetch)

        restoreDatabaseState(contexts: contexts)
        undoEditSiswa(siswa, registerUndo: false)
        sendAfterUndoEvents(siswa: siswa, currentSiswa: updatedModels, aktifkanSiswa: aktifkanSiswa)

        Self.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.redoNaikKelas(
                contexts: contexts,
                siswa: updatedModels,
                oldData: siswa,
                aktifkanSiswa: aktifkanSiswa
            )
        }
    }

    /// Mengulangi kembali operasi kenaikan kelas yang sebelumnya di-undo.
    ///
    /// Fungsi ini akan:
    /// - Memproses kenaikan kelas kembali berdasarkan konteks yang disimpan.
    /// - Memperbarui UI dan database.
    /// - Mendaftarkan aksi undo kembali.
    ///
    /// - Parameters:
    ///   - contexts: Array konteks undo yang digunakan untuk redo.
    ///   - siswa: Array siswa yang akan dinaikkan kembali.
    ///   - oldData: Data siswa sebelum redo.
    ///   - aktifkanSiswa: Menentukan apakah redo adalah redo untuk aktifasi status siswa.
    func redoNaikKelas(
        contexts: [UndoNaikKelasContext],
        siswa: [ModelSiswa],
        oldData: [ModelSiswa],
        aktifkanSiswa: Bool
    ) {
        Task.detached { [weak self] in
            guard let self else { return }

            let updatedSiswa = await processNaikKelas(
                contexts: contexts,
                siswa: siswa,
                aktifkanSiswa: aktifkanSiswa
            )

            await MainActor.run {
                self.completeRedoProcess(
                    updatedSiswa: updatedSiswa,
                    oldData: oldData,
                    aktifkanSiswa: aktifkanSiswa
                )
            }
        }
        registerUndo(undoContexts: contexts, siswa: oldData, aktifkanSiswa: aktifkanSiswa)
    }

    // MARK: - Helper Methods for Undo/Redo

    /// Membuat dictionary dari array siswa dengan key berupa ID siswa
    /// untuk mempercepat proses iterasi.
    ///
    /// - Parameter data: Array siswa.
    /// - Returns: Dictionary dengan key `Int64` (ID siswa) dan value `ModelSiswa`.
    private func buildDataDict(from data: [ModelSiswa]) -> [Int64: ModelSiswa] {
        Dictionary(uniqueKeysWithValues: data.map { ($0.id, $0) })
    }

    /// Mengambil data dari database untuk siswa yang belum ada di cache berdasarkan ID.
    ///
    /// - Parameter ids: Set ID siswa yang perlu diambil.
    /// - Returns: Array `ModelSiswa` hasil fetch dari database.
    ///
    /// - Note: Fungsi ini menjalankan fetch ke database secara paralel.
    private func fetchMissingData(ids: Set<Int64>) -> [ModelSiswa] {
        var results: [ModelSiswa] = []
        let group = DispatchGroup()
        let lock = NSLock()

        for id in ids {
            group.enter()
            DispatchQueue.global().async {
                let fetched = DatabaseController.shared.getSiswa(idValue: id)
                lock.lock()
                results.append(fetched)
                lock.unlock()
                group.leave()
            }
        }

        group.wait()
        return results
    }

    /// Mengembalikan state database ke kondisi sebelum kenaikan kelas.
    ///
    /// - Parameter contexts: Array konteks undo yang digunakan untuk mengembalikan data.
    @inline(__always)
    private func restoreDatabaseState(contexts: [UndoNaikKelasContext]) {
        dbController.undoNaikKelas(using: contexts)
        #if DEBUG
            print("🔧 Database dikembalikan dengan \(contexts.count) context")
        #endif
    }

    /// Mengirim event ke UI setelah operasi undo kenaikan kelas.
    ///
    /// - Parameters:
    ///   - siswa: Array siswa sebelum undo.
    ///   - currentSiswa: Array siswa setelah undo.
    ///   - aktifkanSiswa: Menentukan apakah undo untuk aktifasi status siswa..
    private func sendAfterUndoEvents(siswa: [ModelSiswa], currentSiswa: [ModelSiswa], aktifkanSiswa: Bool) {
        for data in siswa {
            if let newData = currentSiswa.first(where: { $0.id == data.id }),
               data.status == .aktif, newData.status != .aktif
            {
                // Jika status siswa == .aktif langsung kirim event aktfkan siswa
                kelasEvent.send(.aktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
                continue
            }

            if aktifkanSiswa {
                /// Jika aktifkan siswa == true yang diset ketika mengubah status siswa ke aktif di `undoNaikKelas`
                kelasEvent.send(.nonaktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
            } else {
                kelasEvent.send(.undoUbahKelas(data.id, toKelas: data.tingkatKelasAktif.rawValue, status: data.status))
            }
        }
    }

    /// Mengirim event ke UI setelah operasi redo kenaikan kelas.
    ///
    /// - Parameters:
    ///   - siswa: Array siswa setelah redo.
    ///   - oldSiswa: Array siswa sebelum redo.
    ///   - aktifkanSiswa:  Menentukan apakah redo untuk aktifasi status siswa.
    private func sendAfterRedoEvents(_ siswa: [ModelSiswa], oldSiswa: [ModelSiswa], aktifkanSiswa: Bool) {
        if !aktifkanSiswa {
            for data in oldSiswa {
                kelasEvent.send(.kelasBerubah(data.id, fromKelas: data.tingkatKelasAktif.rawValue))
            }
        }

        for data in siswa {
            if data.status != .aktif {
                kelasEvent.send(.nonaktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
            } else {
                kelasEvent.send(.aktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
            }
        }
    }

    /// Memproses kenaikan kelas berdasarkan konteks undo/redo.
    ///
    /// - Parameters:
    ///   - contexts: Array konteks undo/redo.
    ///   - siswa: Array siswa yang akan diproses.
    ///   - aktifkanSiswa: Menentukan apakah memproses untuk aktifasi status siswa.
    /// - Returns: Array siswa yang telah diperbarui.
    private func processNaikKelas(
        contexts: [UndoNaikKelasContext],
        siswa: [ModelSiswa],
        aktifkanSiswa: Bool
    ) async -> [ModelSiswa] {
        var updated: [ModelSiswa] = []

        for context in contexts {
            guard let currentSiswa = findSiswa(for: context, in: siswa) else { continue }

            let status = determineStatus(for: currentSiswa, aktifkanSiswa: aktifkanSiswa)
            updateTanggalBerhenti(for: currentSiswa, with: status)

            let intoKelasID = await determineKelasID(for: context, from: currentSiswa)

            dbController.naikkanSiswa(
                context.siswaId,
                intoKelasId: intoKelasID,
                tingkatBaru: removePrefix(currentSiswa.tingkatKelasAktif.rawValue, prefix: Constants.kelasPrefix),
                tahunAjaran: context.tahunAjaran,
                semester: context.semester,
                tanggalNaik: context.newEntryTanggal,
                statusEnrollment: status
            )

            updated.append(currentSiswa)
        }

        return updated
    }

    /// Mendaftarkan aksi undo ke `siswaUndoManager`.
    ///
    /// - Parameters:
    ///   - undoContexts: Array konteks undo.
    ///   - siswa: Array siswa yang terkait.
    ///   - aktifkanSiswa: Menentukan apakah undo untuk aktifasi status siswa.
    private func registerUndo(undoContexts: [UndoNaikKelasContext], siswa: [ModelSiswa], aktifkanSiswa: Bool = false) {
        Self.siswaUndoManager.registerUndo(withTarget: self) { target in
            target.undoNaikKelas(contexts: undoContexts, siswa: siswa, aktifkanSiswa: aktifkanSiswa)
        }
    }

    /// Mencari objek siswa berdasarkan konteks undo/redo.
    ///
    /// - Parameters:
    ///   - context: Konteks undo/redo.
    ///   - siswa: Array siswa yang akan dicari.
    /// - Returns: Objek `ModelSiswa` jika ditemukan, atau `nil` jika tidak ada yang cocok.
    @inline(__always)
    private func findSiswa(for context: UndoNaikKelasContext, in siswa: [ModelSiswa]) -> ModelSiswa? {
        siswa.first { $0.id == context.siswaId }
    }

    /// Menentukan status siswa berdasarkan kondisi undo/redo.
    ///
    /// - Parameters:
    ///   - siswa: Objek siswa.
    ///   - aktifkanSiswa: Menentukan apakah memproses untuk aktifasi status siswa.
    /// - Returns: Status siswa yang sesuai.
    @inline(__always)
    private func determineStatus(for siswa: ModelSiswa, aktifkanSiswa: Bool) -> StatusSiswa {
        aktifkanSiswa || siswa.status != .aktif ? siswa.status : .naik
    }

    /// Menentukan ID kelas tujuan berdasarkan konteks dan data siswa.
    ///
    /// - Parameters:
    ///   - context: Konteks undo/redo.
    ///   - siswa: Objek siswa.
    /// - Returns: ID kelas tujuan atau `nil` jika tidak dapat ditentukan.
    private func determineKelasID(for context: UndoNaikKelasContext, from siswa: ModelSiswa) async -> Int64? {
        guard !context.tahunAjaran.isEmpty, !context.semester.isEmpty else {
            return nil
        }

        let tingkat = removePrefix(siswa.tingkatKelasAktif.rawValue, prefix: Constants.kelasPrefix)
        return await getKelasID(
            tingkat: tingkat,
            tahunAjaran: context.tahunAjaran,
            semester: context.semester
        )
    }

    /// Menyelesaikan proses redo kenaikan kelas.
    ///
    /// - Parameters:
    ///   - updatedSiswa: Array siswa setelah redo.
    ///   - oldData: Array siswa sebelum redo.
    ///   - aktifkanSiswa: Menentukan apakah redo untuk aktifasi status siswa.
    private func completeRedoProcess(
        updatedSiswa: [ModelSiswa],
        oldData: [ModelSiswa],
        aktifkanSiswa: Bool
    ) {
        undoEditSiswa(updatedSiswa, registerUndo: false)
        sendAfterRedoEvents(updatedSiswa, oldSiswa: oldData, aktifkanSiswa: aktifkanSiswa)
    }

    /// Membuat snapshot (salinan) array siswa.
    ///
    /// - Parameter siswa: Array siswa yang akan disalin.
    /// - Returns: Array salinan `ModelSiswa`.
    private func createSnapshot(of siswa: [ModelSiswa]) -> [ModelSiswa] {
        siswa.compactMap { $0.copy() as? ModelSiswa }
    }
}
