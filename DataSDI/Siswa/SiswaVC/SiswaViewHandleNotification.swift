//
//  SiswaViewHandleNotification.swift
//  Data SDI
//
//  Created by Bismillah on 12/01/25.
//

import Cocoa

extension SiswaViewController {
    // MARK: - EDIT DATA

    /// Menangani notifikasi untuk tindakan 'undo' (urungkan).
    ///
    /// Fungsi ini adalah titik masuk utama untuk memproses notifikasi
    /// penghapusan sementara (undo action). Fungsi ini akan memeriksa mode
    /// tampilan tabel saat ini (berkelompok atau biasa) dan mengarahkan
    /// logika pembaruan data dan UI ke fungsi penanganan yang sesuai.
    ///
    /// - Parameter payload: Objek notifikasi ``UndoActionNotification`` yang berisi
    ///                      informasi tentang tindakan yang diurungkan, seperti ID siswa,
    ///                      pengidentifikasi kolom, dan posisi di tabel.
    func handleUndoActionNotification(_ payload: UndoActionNotification) {
        delegate?.didUpdateTable(.siswa)

        let id = payload.id
        let columnIdentifier = payload.columnIdentifier

        guard let rowIndex = payload.rowIndex,
              let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier.rawValue })
        else {
            insertHiddenSiswa(id, mode: currentTableViewMode)
            return
        }

        let siswa: ModelSiswa = if currentTableViewMode == .grouped,
                                   payload.isGrouped == true,
                                   let groupIndex = payload.groupIndex
        {
            viewModel.groupedSiswa[groupIndex][rowIndex]
        } else {
            viewModel.filteredSiswaData[rowIndex]
        }

        guard let update = viewModel.relocateSiswa(siswa, comparator: comparator, mode: currentTableViewMode, columnIndex: columnIndex) else { return }

        UpdateData.applyUpdates([update], tableView: tableView)
    }

    /// Menangani notifikasi yang diterima, biasanya dari `.dataSiswaDiEdit`.
    ///
    /// Fungsi ini bertindak sebagai pendengar notifikasi dan memproses data yang
    /// diterima untuk memperbarui data siswa. Logika pemrosesan dijalankan
    /// secara asinkron menggunakan `Task.detached` untuk menghindari
    /// pemblokiran thread utama (main thread) saat melakukan operasi basis data
    /// yang intensif.
    ///
    /// - Parameter notification: Objek notifikasi yang berisi `userInfo` dengan
    ///                           data yang relevan untuk tindakan "naik kelas".
    ///
    /// - Note: Notifikasi ini diharapkan memiliki `userInfo` yang valid dengan
    ///         kunci-kunci berikut: "ids", "updateKelas", "tahunAjaran",
    ///         "semester", "kelas", dan "status"
    @objc func receivedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let ids = userInfo["ids"] as? [Int64],
              let updateKelas = userInfo["updateKelas"] as? Bool,
              let tahunAjaran = userInfo["tahunAjaran"] as? String,
              let semester = userInfo["semester"] as? String,
              let kelas = userInfo["kelas"] as? String,
              let status = userInfo["status"] as? StatusSiswa
        else { return }

        Task.detached(priority: .userInitiated) { [unowned self, ids, updateKelas, tahunAjaran, semester, status] in
            // Gunakan tuple untuk mengembalikan dua nilai dari setiap Task
            let results: [(ModelSiswa, UndoNaikKelasContext?)] = await withTaskGroup(of: (ModelSiswa, UndoNaikKelasContext?).self) { group in
                var results = [(ModelSiswa, UndoNaikKelasContext?)]()

                let formatSemester = semester.hasPrefix("Semester ")
                    ? semester.replacingOccurrences(of: "Semester ", with: "")
                    : semester
                let tingkatKelas = kelas.replacingOccurrences(of: "Kelas ", with: "")
                let intoKelasID = await dbController.insertOrGetKelasID(nama: "A", tingkat: tingkatKelas, tahunAjaran: tahunAjaran, semester: formatSemester)
                for id in ids {
                    var snapshot: UndoNaikKelasContext? = nil

                    if updateKelas,
                       let newSnapshot = dbController.naikkanSiswa(
                           id,
                           intoKelasId: intoKelasID,
                           tingkatBaru: tingkatKelas,
                           tahunAjaran: tahunAjaran,
                           semester: formatSemester,
                           tanggalNaik: ReusableFunc.buatFormatTanggal(Date())!,
                           statusEnrollment: status
                       )
                    {
                        snapshot = newSnapshot
                    }
                    group.addTask { [snapshot, weak self] in
                        guard let self else { return (ModelSiswa(), nil) }
                        // Cari IndexSet
                        var siswaToUpdate = ModelSiswa()
                        if await currentTableViewMode == .plain {
                            if let siswa = viewModel.filteredSiswaData.first(where: { $0.id == id }) {
                                siswaToUpdate = siswa
                            }
                        } else {
                            for (_, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                                if let siswa = siswaGroup.first(where: { $0.id == id }) {
                                    siswaToUpdate = siswa
                                    break
                                }
                            }
                        }

                        return (siswaToUpdate, snapshot)
                    }
                }

                // Kumpulkan hasil dari semua task
                for await result in group {
                    results.append(result)
                }

                return results
            }

            // Gabungkan hasil di sini
            var combinedSiswa = [ModelSiswa]()
            var combinedSnapshot = [UndoNaikKelasContext]()

            for (siswa, snapshot) in results {
                combinedSiswa.append(siswa)
                if let snapshot {
                    combinedSnapshot.append(snapshot)
                }
            }

            // Lakukan pembaruan UI di Main Actor setelah semua data siap
            await updateDataInBackground(siswaData: combinedSiswa, updateKelas: updateKelas, snapshot: combinedSnapshot)
        }
    }

    /// Memperbarui data siswa di latar belakang dan memperbarui tampilan tabel di thread utama.
    ///
    /// Fungsi ini adalah bagian dari alur kerja "naik kelas" (promosi siswa)
    /// yang dipicu oleh notifikasi. Fungsi ini menangani pembaruan data
    /// berdasarkan mode tampilan tabel saat ini (``TableViewMode/plain`` atau ``TableViewMode/grouped``)
    /// dan memastikan UI diperbarui dengan benar setelah operasi basis data
    /// selesai.
    ///
    /// - Parameters:
    ///   - siswaData: Array ``ModelSiswa`` yang berisi siswa yang
    ///                         terpengaruh oleh pembaruan.
    ///   - updateKelas: `Bool` yang menunjukkan apakah operasi "naik kelas"
    ///                  perlu dilakukan atau tidak.
    ///   - snapshot: Array ``UndoNaikKelasContext`` yang berisi data sebelum
    ///               perubahan untuk mendukung fitur 'undo'.
    func updateDataInBackground(siswaData: [ModelSiswa], updateKelas: Bool, snapshot: [UndoNaikKelasContext]) async {
        guard let progress = await showProgressWindow() else { return }

        let updates = await processSiswaUpdates(siswaData: siswaData, progressBar: progress.controller)

        await MainActor.run {
            UpdateData.applyUpdates(updates.updateData, tableView: tableView)
            registerUndoActions(updateKelas: updateKelas, snapshot: snapshot, selectedSiswaRow: siswaData)
            selectedSiswaList.removeAll()
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            UpdateData.applyUpdates(hideBerhentiLulus(updates.databaseData), tableView: tableView)
        }

        try? await Task.sleep(nanoseconds: 400_000_000)
        await MainActor.run {
            deleteRedoUpdateUndo()
            view.window?.endSheet(progress.window)
        }
    }

    private func deleteRedoUpdateUndo() {
        deleteAllRedoArray(self)
    }

    // Extract data processing logic
    private func processSiswaUpdates(
        siswaData: [ModelSiswa],
        progressBar: ProgressBarVC? = nil
    ) async
        -> (updateData: [UpdateData],
            databaseData: [ModelSiswa])
    {
        let newData = await fetchEditedSiswa(snapshotSiswas: siswaData)
        let databaseData = newData.map(\.databaseData)
        let updates = updateSiswaData(databaseData, comparator: comparator, progressBar: progressBar)
        return (updates, databaseData)
    }

    /// Memperbarui data siswa di model tampilan dan mengumpulkan pembaruan UI.
    ///
    /// Fungsi ini mengiterasi melalui array data siswa yang baru (`newData`) dan
    /// menggunakan `viewModel` untuk merelokasi setiap siswa sesuai dengan aturan
    /// pengurutan dan mode tampilan saat ini. Fungsi ini mengumpulkan semua pembaruan
    /// yang dihasilkan (`UpdateData`) ke dalam satu array untuk diterapkan nanti.
    /// Selain itu, fungsi ini memperbarui tampilan bilah progres, jika disediakan.
    ///
    /// - Parameters:
    ///   - newData: Array dari ``ModelSiswa`` yang berisi data siswa yang telah diperbarui.
    ///   - comparator: Comparator perbandingan objek ``ModelSiswa``
    ///   - progressViewController: Pengontrol tampilan opsional untuk mengelola
    ///     bilah progres.
    ///   - undo: Sebuah boolean yang menunjukkan apakah operasi ini adalah bagian dari
    ///     tindakan _undo_. Saat ini tidak digunakan di dalam fungsi.
    /// - Returns: Sebuah array dari ``UpdateData`` yang menjelaskan perubahan yang
    ///   perlu diterapkan ke tabel UI.
    private func updateSiswaData(_ newData: [ModelSiswa],
                                 comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
                                 progressBar: ProgressBarVC? = nil) -> [UpdateData]
    {
        var updates: [UpdateData] = []

        for (index, siswa) in newData.enumerated() {
            guard let update = viewModel.relocateSiswa(siswa, comparator: comparator, mode: currentTableViewMode) else { continue }
            updates.append(update)
            progressBar?.controller = siswa.nama
            progressBar?.currentStudentIndex = index + 1
        }

        return updates
    }

    /// Menyembunyikan siswa dengan status "Berhenti" atau "Lulus" dari tampilan tabel.
    ///
    /// Fungsi ini memfilter array `newData` untuk menemukan semua siswa dengan status
    /// `.berhenti` atau `.lulus`. Kemudian, fungsi ini mengiterasi melalui siswa yang difilter tersebut
    /// dan menggunakan fungsi pembantu ``handleHiddenSiswa(_:)`` untuk memeriksa apakah siswa
    /// tersebut harus disembunyikan berdasarkan pengaturan tampilan saat ini. Jika ya,
    /// siswa tersebut dihapus dari model tampilan, dan pembaruan UI yang sesuai
    /// (``UpdateData``) dikumpulkan untuk diterapkan.
    ///
    /// - Parameter newData: Array dari ``ModelSiswa`` yang mewakili data terbaru.
    /// - Returns: Sebuah array dari ``UpdateData`` yang berisi instruksi untuk
    ///   menghapus baris siswa yang tersembunyi dari tampilan.
    func hideBerhentiLulus(_ newData: [ModelSiswa]) -> [UpdateData] {
        var updates: [UpdateData] = []

        // Filter langsung siswa dengan status berhenti/lulus
        let lulusBerhentiData = newData.filter { siswa in
            siswa.status == .berhenti || siswa.status == .lulus
        }

        for siswa in lulusBerhentiData {
            if handleHiddenSiswa(siswa),
               let update = viewModel.removeSiswa(siswa, mode: currentTableViewMode)
            {
                updates.append(update)
            }
        }

        return updates
    }

    // MARK: - Helper Functions (Some new, some reusing existing patterns)

    // Small refactor untuk readability
    @MainActor
    private func showProgressWindow() async -> (window: NSWindow, controller: ProgressBarVC)? {
        guard let progressWindowController = setupProgressWindow(),
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC,
              let windowProgress = progressWindowController.window
        else {
            return nil
        }
        await MainActor.run {
            view.window?.beginSheet(windowProgress)
        }
        return (windowProgress, progressViewController)
    }

    private func setupProgressWindow() -> NSWindowController? {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC
        else {
            return nil
        }

        progressViewController.totalStudentsToUpdate = selectedSiswaList.count
        progressViewController.controller = "Siswa"

        return progressWindowController
    }

    private func registerUndoActions(updateKelas: Bool, snapshot: [UndoNaikKelasContext], selectedSiswaRow: [ModelSiswa]) {
        if updateKelas {
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                self?.handleUndoNaikKelas(contexts: snapshot, siswa: selectedSiswaRow)
            }
        } else {
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                self?.viewModel.undoEditSiswa(selectedSiswaRow)
            }
        }
        SiswaViewModel.siswaUndoManager.endUndoGrouping()
    }

    // MARK: - UNDOEDIT

    /**
         * Fungsi ini menangani proses pembatalan (undo) perubahan data siswa.
         * Fungsi ini dipanggil ketika ada notifikasi yang menandakan bahwa operasi undo edit siswa perlu dilakukan.
         *
         * - Parameter notification: Notifikasi yang berisi informasi tentang data siswa yang akan dikembalikan.
         *   Notifikasi ini diharapkan memiliki `userInfo` yang berisi:
         *     - "data": Array ``ModelSiswa`` yang berisi snapshot data siswa sebelum perubahan.
         *
         * Proses:
         * 1. Memastikan bahwa notifikasi memiliki data yang diperlukan dan data tidak kosong.
         * 2. Membatalkan semua pilihan baris di tabel.
         * 3. Memulai pembaruan tabel secara batch.
         * 4. Berdasarkan mode tampilan tabel (`.plain` atau `.grouped`), lakukan langkah-langkah berikut:
         *    - Mode `.plain`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Memeriksa apakah siswa tersebut harus ditampilkan berdasarkan status "berhenti" atau "lulus".
         *      - Memperbarui data siswa di `viewModel`.
         *      - Menghapus baris yang sesuai dari tabel dan menyisipkan kembali di posisi yang benar.
         *      - Memindahkan baris di tabel untuk mencerminkan perubahan urutan.
         *      - Memuat ulang data di kolom yang sesuai.
         *    - Mode `.grouped`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Mencari data siswa yang sesuai di setiap grup.
         *      - Memperbarui data siswa di `viewModel`.
         *      - Memindahkan siswa antar grup jika kelasnya berubah.
         *      - Memperbarui tampilan tabel untuk mencerminkan perubahan grup dan urutan.
         * 5. Mengakhiri pembaruan tabel secara batch.
         * 6. Memperbarui tampilan tombol undo dan redo setelah beberapa saat.
         * 7. Memposting notifikasi jika ada perubahan pada tanggal berhenti siswa.
         *
         * Catatan:
         * - Fungsi ini menggunakan `viewModel` untuk mengelola data siswa.
         * - Fungsi ini menggunakan `dbController` untuk mengakses data siswa dari database.
     */
    @objc func undoEditSiswa(_ notification: Notification) {
        delegate?.didUpdateTable(.siswa)
        guard let snapshotSiswas = extractUndoData(from: notification) else { return }
        let updates = updateSiswaData(snapshotSiswas, comparator: comparator)
        UpdateData.applyUpdates(updates, tableView: tableView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            UpdateData.applyUpdates(hideBerhentiLulus(snapshotSiswas), tableView: tableView)
        }
    }

    // MARK: - Helper Functions

    /// Mengekstrak array ``ModelSiswa`` dari kamus `userInfo` dalam notifikasi.
    ///
    /// Fungsi ini dirancang untuk mengambil data snapshot siswa secara aman
    /// dari kamus `userInfo` notifikasi. Fungsi ini melakukan type casting dan
    /// pemeriksaan untuk memastikan data tidak kosong sebelum mengembalikannya.
    ///
    /// - Parameter notification: Objek `Notification` yang berisi `userInfo`.
    /// - Returns: Sebuah array opsional dari ``ModelSiswa``. Mengembalikan `nil` jika
    ///   data tidak ada, tidak memiliki tipe yang diharapkan, atau kosong.
    private func extractUndoData(from notification: Notification) -> ([ModelSiswa])? {
        guard let userInfo = notification.userInfo,
              let snapshotSiswas = userInfo["data"] as? [ModelSiswa],
              !snapshotSiswas.isEmpty
        else { return nil }

        return snapshotSiswas
    }

    /// Memasukkan baris siswa yang tersembunyi ke dalam table view berdasarkan mode yang ditentukan.
    ///
    /// Fungsi ini bertindak sebagai dispatcher, mendelegasikan logika penyisipan
    /// ke fungsi pembantu tertentu (``insertHiddenSiswaTableRow(_:)`` atau ``insertHiddenGroupTableRows(_:)``)
    /// tergantung pada ``TableViewMode``. Atribut `@discardableResult`
    /// menunjukkan bahwa nilai kembalian dapat diabaikan tanpa peringatan kompilator.
    ///
    /// - Parameters:
    ///   - id: Pengenal unik (`Int64`) dari siswa yang akan dimasukkan.
    ///   - mode: Mode tampilan table view saat ini, yaitu `.plain` atau `.grouped`.
    /// - Returns: Indeks di mana baris siswa yang tersembunyi dimasukkan.
    @MainActor @discardableResult
    func insertHiddenSiswa(_ id: Int64, mode: TableViewMode) -> Int {
        switch mode {
        case .plain: insertHiddenSiswaTableRow(id)
        case .grouped: insertHiddenGroupTableRows(id)
        }
    }

    /// Memasukkan model siswa ke dalam struktur table view yang sesuai.
    ///
    /// Fungsi ini menangani penyisipan siswa baru (``ModelSiswa``) ke dalam
    /// model data yang mendasarinya dan memicu pembaruan UI yang sesuai. Fungsi ini menggunakan
    /// pernyataan `switch` untuk memanggil metode penyisipan yang benar berdasarkan
    /// ``TableViewMode``.
    ///
    /// - Parameters:
    ///   - data: Objek ``ModelSiswa`` yang akan dimasukkan.
    ///   - mode: Mode tampilan table view saat ini (``TableViewMode/plain`` atau ``TableViewMode/grouped``).
    ///   - comparator: Sebuah closure yang digunakan untuk menentukan posisi terurut yang benar
    ///     untuk data siswa baru.
    /// - Returns: Struct ``UpdateData`` yang berisi informasi tentang penyisipan.
    func insertSiswa(_ data: ModelSiswa, mode: TableViewMode,
                     comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> UpdateData
    {
        switch mode {
        case .plain: insertTableModelRows(data, comparator: comparator)
        case .grouped: insertGroupTableModelRows(data, comparator: comparator)
        }
    }

    /// Memasukkan baris siswa baru ke dalam table view biasa (tanpa grup).
    ///
    /// Ini adalah fungsi pembantu privat yang memperbarui model tampilan dengan data siswa baru
    /// dan kemudian mengembalikan informasi yang diperlukan untuk melakukan pembaruan UI.
    /// Atribut `@discardableResult` menunjukkan bahwa nilai kembalian dapat diabaikan.
    ///
    /// - Parameters:
    ///   - oldSiswa: Objek ``ModelSiswa`` yang akan dimasukkan.
    ///   - comparator: Sebuah closure yang digunakan untuk menentukan posisi terurut yang benar.
    /// - Returns: Struct ``UpdateData`` yang berisi detail pembaruan.
    @MainActor @discardableResult
    private func insertTableModelRows(_ oldSiswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> UpdateData {
        let insertIndex = viewModel.insertSiswa(oldSiswa, comparator: comparator)
        return .insert(index: insertIndex, selectRow: true, extendSelection: true)
    }

    /// Memasukkan baris siswa baru ke dalam table view yang dikelompokkan.
    ///
    /// Fungsi pembantu ini memperbarui model tampilan yang dikelompokkan dan menghitung
    /// indeks baris absolut di dalam table view. Ini memastikan bahwa pembaruan UI
    /// diterapkan ke lokasi yang benar.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan dimasukkan.
    ///   - comparator: Sebuah closure untuk menentukan posisi terurut dalam grup.
    /// - Returns: Struct `UpdateData` yang berisi detail pembaruan, termasuk indeks absolut.
    @MainActor @discardableResult
    func insertGroupTableModelRows(_ siswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> UpdateData {
        let (groupIdx, insertIndex) = viewModel.insertGroupSiswa(siswa, comparator: comparator)
        let absoluteIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIdx, rowIndex: insertIndex)
        return .insert(index: absoluteIndex, selectRow: true, extendSelection: true)
    }

    /// Memasukkan baris siswa yang tersembunyi ke dalam table view biasa.
    ///
    /// Fungsi ini menangani penyisipan siswa yang tersembunyi. Siswa dimasukkan ke dalam model
    /// tampilan dan pembaruan UI diterapkan. Setelah penundaan singkat, baris digulirkan ke tampilan
    /// dan dihapus secara kondisional jika kriteria tertentu terpenuhi, seperti
    /// tidak menampilkan siswa yang sudah lulus.
    ///
    /// - Parameter id: ID siswa yang akan dimasukkan.
    /// - Returns: Indeks baris yang dimasukkan.
    @MainActor @discardableResult
    func insertHiddenSiswaTableRow(_ id: Int64) -> Int {
        let index = viewModel.insertHiddenSiswa(id, comparator: comparator)
        UpdateData.applyUpdates([UpdateData.insert(index: index, selectRow: true, extendSelection: false)], tableView: tableView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            tableView.scrollRowToVisible(index)
            if !tampilkanSiswaLulus || isBerhentiHidden {
                viewModel.removeSiswa(at: index)
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: .effectFade)
            }
        }
        return index
    }

    /// Menangani siswa yang berhenti/lulus dalam mode group.
    ///
    /// Fungsi ini memulihkan status data siswa setelah tindakan 'undo',
    /// seperti mengembalikan siswa yang dihapus sementara. Prosedur ini
    /// termasuk memperbarui data di model dan merefleksikan perubahan
    /// tersebut pada tampilan tabel (table view).
    ///
    /// - Parameters:
    ///   - id: ID unik siswa yang akan diurungkan tindakannya.
    @MainActor @discardableResult
    func insertHiddenGroupTableRows(_ id: Int64) -> Int {
        let (groupIndex, rowIndex, absoluteIndex) = viewModel.insertHiddenSiswaGroup(id, comparator: comparator)
        UpdateData.applyUpdates([UpdateData.insert(index: absoluteIndex, selectRow: true, extendSelection: false)], tableView: tableView)
        tableView.scrollRowToVisible(absoluteIndex)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if !tampilkanSiswaLulus || isBerhentiHidden {
                viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)
                tableView.removeRows(at: IndexSet(integer: absoluteIndex), withAnimation: .effectFade)
            }
        }
        return absoluteIndex
    }

    /// Mengambil data siswa yang telah diedit secara asinkronus dan paralel.
    ///
    /// Fungsi ini membandingkan data snapshot siswa (`snapshotSiswas`) dengan data
    /// terbaru yang ada di database. Dengan menggunakan `withTaskGroup`, fungsi ini
    /// secara efisien mengambil data setiap siswa dari database secara paralel,
    /// yang secara signifikan meningkatkan kinerja untuk daftar siswa yang besar.
    ///
    /// - Parameter snapshotSiswas: Array dari `ModelSiswa` yang mewakili data
    ///   siswa sebelum perubahan.
    /// - Returns: Sebuah array dari tuple, di mana setiap tuple berisi
    ///   `snapshot` (data lama) dan `databaseData` (data terbaru dari database).
    private func fetchEditedSiswa(snapshotSiswas: [ModelSiswa]) async -> [(snapshot: ModelSiswa, databaseData: ModelSiswa)] {
        // Pre-fetch semua data siswa secara parallel
        let siswaResults = await withTaskGroup(of: (ModelSiswa, ModelSiswa).self) { group -> [(ModelSiswa, ModelSiswa)] in
            for snapshotSiswa in snapshotSiswas {
                group.addTask {
                    let databaseData = await self.dbController.getSiswaAsync(idValue: snapshotSiswa.id)
                    return (snapshotSiswa, databaseData)
                }
            }

            var results: [(ModelSiswa, ModelSiswa)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        return siswaResults
    }

    /// Menentukan apakah seorang siswa harus disembunyikan berdasarkan status mereka dan preferensi tampilan.
    ///
    /// Fungsi ini memeriksa dua kondisi untuk menentukan apakah sebuah baris siswa
    /// di table view harus disembunyikan:
    /// 1. Jika `isBerhentiHidden` bernilai `true` dan status siswa adalah `.berhenti`.
    /// 2. Jika `tampilkanSiswaLulus` bernilai `false` dan status siswa adalah `.lulus`.
    ///
    /// Jika salah satu dari kondisi ini terpenuhi, siswa harus disembunyikan.
    ///
    /// - Parameter siswa: Objek `ModelSiswa` yang akan diperiksa statusnya.
    /// - Returns: `true` jika siswa harus disembunyikan, dan `false` jika tidak.
    func handleHiddenSiswa(_ siswa: ModelSiswa) -> Bool {
        (isBerhentiHidden && siswa.status == .berhenti) ||
            (!tampilkanSiswaLulus && siswa.status == .lulus)
    }

    // MARK: - TAMBAHKAN DATA BARU

    /**
     Menangani notifikasi ``DatabaseController/siswaBaru``.
     Fungsi ini akan menyisipkan siswa baru ke dalam tampilan tabel,
     baik dalam mode tampilan biasa maupun mode tampilan berkelompok, dan memperbarui tampilan tabel sesuai.

     - Parameter notification: Notifikasi yang berisi informasi tentang perubahan data siswa.

     - Catatan: Fungsi ini juga menangani pendaftaran dan pembatalan undo untuk operasi penyisipan siswa,
       serta memperbarui status tombol undo/redo.
     */
    @objc func handleDataDidChangeNotification(_ notification: Notification) {
        delegate?.didUpdateTable(.siswa)
        guard let info = notification.userInfo,
              let insertedSiswa = info["siswaBaru"] as? ModelSiswa
        else { return }

        guard let update = insertSiswa(
            insertedSiswa,
            comparator: comparator,
            postNotification: true
        ) else {
            return
        }

        UpdateData.applyUpdates([update], tableView: tableView)

        urungsiswaBaruArray.append(insertedSiswa)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.urungSiswaBaru(self)
        }
        deleteRedoUpdateUndo()
    }

    // MARK: - NOTIFICATION

    /**
     Menyimpan data siswa setelah menerima notifikasi.

     Fungsi ini dipanggil sebagai respons terhadap notifikasi, dan melakukan serangkaian operasi asinkron untuk menyimpan data siswa,
     membersihkan array yang tidak diperlukan, memfilter siswa yang dihapus, dan memperbarui status undo/redo.

     - Parameter:
        - notification: Notifikasi yang memicu penyimpanan data.
     */
    @objc func saveData(_: Notification) {
        guard isDataLoaded else { return }

        // Inisialisasi DispatchGroup
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            urungsiswaBaruArray.removeAll()
            pastedSiswasArray.removeAll()
            dispatchGroup.leave()
        }
        dispatchGroup.enter()
        dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) {
            self.filterDeletedSiswa()
            dispatchGroup.leave()
        }
        // Setelah semua tugas selesai
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    SiswaViewModel.siswaUndoManager.removeAllActions()
                    deleteRedoUpdateUndo()
                }
            }
        }
    }
}
