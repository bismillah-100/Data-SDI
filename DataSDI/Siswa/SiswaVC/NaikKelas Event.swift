//
//  NaikKelas Event.swift
//  Data SDI
//
//  Created by MacBook on 05/08/25.
//

import AppKit
import Combine

/// Event yang digunakan untuk mengelola perubahan kelas siswa
/// dan mengaktifkan siswa.
/// Event ini digunakan dalam `SiswaViewController` untuk menangani aksi terkait kelas siswa,
/// seperti mengubah kelas, mengaktifkan siswa, dan mengelola undo/redo perubahan kelas.
enum NaikKelasEvent {
    /// Event untuk mengubah kelas siswa.
    /// - Parameters:
    ///   - id: ID siswa yang kelasnya akan diubah.
    ///   - fromKelas: Kelas asal siswa sebelum perubahan.
    case kelasBerubah(_ id: Int64, fromKelas: String)

    /// Event untuk mengubah kelas siswa dengan undo/redo.
    /// - Parameters:
    ///   - id: ID siswa yang kelasnya akan diubah.
    ///   - toKelas: Kelas baru yang akan diterapkan pada siswa.
    ///   - status: Status siswa setelah perubahan kelas.
    case undoUbahKelas(_ id: Int64, toKelas: String, status: StatusSiswa)

    /// Event untuk mengaktifkan siswa.
    /// - Parameters:
    ///   - id: ID siswa yang akan diaktifkan.
    ///  - kelas: Kelas yang akan diterapkan pada siswa yang diaktifkan.
    case aktifkanSiswa(_ id: Int64, kelas: String)

    /// Event untuk mengaktifkan siswa dengan undo/redo.
    /// - Parameters:
    ///   - id: ID siswa yang akan diaktifkan.
    ///   - kelas: Kelas yang akan diterapkan pada siswa yang diaktifkan.
    case undoAktifkanSiswa(_ id: Int64, kelas: String)
}

extension SiswaViewController {
    /**
     Mengubah status siswa yang dipilih berdasarkan item menu yang dipilih.

     Fungsi ini menampilkan dialog konfirmasi untuk mengubah status siswa yang dipilih.
     Jika pengguna mengkonfirmasi, status siswa akan diperbarui di database dan tampilan tabel.
     Fungsi ini juga menangani logika khusus untuk status "Lulus", termasuk menghapus siswa dari kelas aktif
     dan menampilkan peringatan konfirmasi tambahan.

     - Parameter sender: Item menu yang memicu aksi ini. `representedObject` dari pengirim harus berupa `String`
        yang merepresentasikan status yang akan diubah.

     - Precondition: `tableView.selectedRowIndexes` harus berisi indeks baris yang valid.
     `viewModel.filteredSiswaData` harus berisi data siswa yang sesuai dengan indeks yang dipilih.
     */
    @IBAction func ubahStatus(_ sender: NSMenuItem) {
        // 1. Dapatkan status baru dari menu item
        guard let statusString = sender.representedObject as? String,
              let newStatus = StatusSiswa.from(description: statusString)
        else {
            print("Error: Status tidak valid atau tidak ditemukan.")
            return
        }

        // 2. Dapatkan data siswa yang relevan dari table view
        guard let selection = getSelectedSiswaAndRows() else { return }

        // 3. Arahkan ke handler yang sesuai berdasarkan status
        if newStatus == .aktif {
            // Menampilkan popover untuk proses aktivasi/kenaikan kelas
            showAktivasiPopover(for: selection.siswa, at: selection.rows)
        } else {
            // Menjalankan proses perubahan status di background
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await processStatusChangeInBackground(
                    for: selection.siswa,
                    at: selection.rows,
                    to: newStatus
                )
            }
        }
    }

    // MARK: - Fungsi Pembantu (Hasil Refactor)

    /**
     Mengambil siswa dan indeks baris yang dipilih dari table view.
     Menangani logika kompleks dari baris yang diklik kanan vs. baris yang sudah dipilih.
     - Returns: Sebuah tuple (siswa: [ModelSiswa], rows: IndexSet)? atau nil jika tidak ada yang dipilih.
     */
    private func getSelectedSiswaAndRows() -> (siswa: [ModelSiswa], rows: IndexSet)? {
        let selectedRows: IndexSet
        var selectedSiswa: [ModelSiswa] = []

        // Cek jika ada baris yang diklik kanan
        if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
            // Jika baris yang diklik kanan adalah bagian dari seleksi yang sudah ada
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                selectedRows = tableView.selectedRowIndexes
            } else {
                // Jika baris yang diklik kanan bukan bagian dari seleksi, anggap itu satu-satunya seleksi
                selectedRows = IndexSet(integer: tableView.clickedRow)
            }
        } else {
            selectedRows = tableView.selectedRowIndexes
        }

        // Jika tidak ada baris yang dipilih sama sekali, kembalikan nil
        guard !selectedRows.isEmpty else { return nil }

        // Ambil model siswa berdasarkan indeks baris yang valid
        selectedSiswa = selectedRows.compactMap { row in
            guard row < viewModel.filteredSiswaData.count else { return nil }
            // Buat salinan untuk memastikan data asli aman sebelum proses undo/redo
            return viewModel.filteredSiswaData[row].copy() as? ModelSiswa
        }

        return (selectedSiswa, selectedRows)
    }

    /**
     Memproses perubahan status siswa (non-aktif) di background thread untuk menjaga UI tetap responsif.
     */
    private func processStatusChangeInBackground(for siswa: [ModelSiswa], at rows: IndexSet, to newStatus: StatusSiswa) async {
        let tanggalSekarang = ReusableFunc.buatFormatTanggal(Date())!
        var undoRedoContexts: [UndoNaikKelasContext] = []

        // Proses setiap siswa secara sekuensial untuk menghindari race condition database
        for siswaModel in siswa {
            // Panggilan ke fungsi async di dalam loop akan dieksekusi satu per satu
            dbController.updateKolomSiswa(siswaModel.id, kolom: SiswaColumns.tanggalberhenti, data: tanggalSekarang)
            dbController.updateStatusSiswa(idSiswa: siswaModel.id, newStatus: newStatus)

            // Panggilan terakhir yang mengembalikan context untuk undo
            let context = dbController.naikkanSiswa(
                siswaModel.id,
                tanggalNaik: tanggalSekarang,
                statusEnrollment: newStatus
            )

            if let ctx = context {
                undoRedoContexts.append(ctx)
            }
        }

        // Kembali ke MainActor untuk memperbarui UI dan mendaftarkan Undo
        await MainActor.run { [weak self, undoRedoContexts] in
            guard let self else { return }

            // Daftarkan aksi undo
            let mgr = SiswaViewModel.siswaUndoManager
            mgr.registerUndo(withTarget: self) { target in
                target.handleUndoNaikKelas(contexts: undoRedoContexts, siswa: siswa)
            }

            // Update UI
            let showLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")
            let showBerhenti = !isBerhentiHidden

            for rowIndex in rows.reversed() {
                // Perbarui model lokal di ViewModel
                if let originalIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == self.viewModel.filteredSiswaData[rowIndex].id }) {
                    let siswaToUpdate = viewModel.filteredSiswaData[originalIndex]
                    siswaToUpdate.status = newStatus
                    siswaToUpdate.tanggalberhenti = tanggalSekarang
                }

                // Jika siswa seharusnya disembunyikan setelah perubahan status
                if (newStatus == .lulus && !showLulus) || (newStatus == .berhenti && !showBerhenti) {
                    viewModel.removeSiswa(at: rowIndex)
                    tableView.removeRows(at: IndexSet(integer: rowIndex), withAnimation: .slideUp)
                } else {
                    let cols = IndexSet([columnIndexOfStatus, columnIndexOfTglBerhenti])
                    tableView.reloadData(forRowIndexes: IndexSet(integer: rowIndex), columnIndexes: cols)
                }
            }

            // Kirim event dan perbarui status undo/redo
            for a in siswa {
                viewModel.kelasEvent.send(.undoAktifkanSiswa(a.id, kelas: a.tingkatKelasAktif.rawValue))
            }
            deleteAllRedoArray(self)
        }
    }

    // MARK: - Pembaruan Kelas

    /// Mengembalikan instance NaikKelasVC dan rect jangkar untuk NSPopover.
    /// - Parameters:
    ///   - tableView: NSTableView tempat cell berada.
    ///   - columnIndex: Indeks kolom target.
    ///   - row: Indeks baris target.
    /// - Returns: Tuple (NaikKelasVC, NSRect) atau nil jika input tidak valid.
    private func makeNaikKelasComponents(
        tableView: NSTableView,
        columnIndex: Int, row: Int
    ) -> (viewController: NaikKelasVC, anchorRect: NSRect)? {
        // Pastikan kolom/baris valid dan superview tersedia
        guard columnIndex >= 0,
              row >= 0,
              let superview = tableView.superview
        else {
            return nil
        }

        // Instantiate NaikKelasVC dari storyboard
        let naikVC = NaikKelasVC(nibName: "NaikKelasVC", bundle: nil)

        // Hitung frame cell di coordinate superview
        let cellRect = tableView.frameOfCell(atColumn: columnIndex, row: row)
        let targetRect = tableView.convert(cellRect, to: superview)

        // Buat leading edge rect untuk anchor popover
        let anchorRect = NSRect(
            x: targetRect.minX,
            y: targetRect.minY,
            width: 14,
            height: targetRect.height
        )

        return (viewController: naikVC, anchorRect: anchorRect)
    }

    /**
     * Memperbarui kelas yang dipilih untuk siswa yang dipilih dalam tampilan tabel.
     *
     * Fungsi ini melakukan beberapa tindakan:
     * 1. Memastikan ada baris yang dipilih. Jika tidak ada, fungsi akan keluar.
     * 2. Menyimpan data siswa yang dipilih sebelum perubahan untuk keperluan undo.
     * 3. Mengiterasi setiap siswa yang dipilih:
     *    - Memeriksa apakah kelas siswa saat ini berbeda dengan kelas yang baru dipilih. Jika sama, iterasi dilanjutkan ke siswa berikutnya.
     *    - Memperbarui kelas siswa saat ini dengan kelas yang baru dipilih.
     *    - Memperbarui data siswa di view model dan database.
     *    - Menampilkan dialog konfirmasi untuk menghapus data siswa dari kelas sebelumnya.
     *    - Menangani opsi "Terapkan ke semua" dan "Batalkan semua" pada dialog konfirmasi.
     * 4. Setelah semua siswa diproses, fungsi memperbarui tampilan tabel untuk mencerminkan perubahan kelas.
     * 5. Mendaftarkan aksi undo untuk mengembalikan perubahan jika diperlukan.
     *
     * - Parameter kelasAktifString: String yang merepresentasikan kelas yang baru dipilih.
     */
    @objc func updateKelasDipilih(_ kelasAktifString: String, selectedRowIndexes: IndexSet) {
        // Ensure there's a selected row to present the popover from
        guard let selectedRow = getFirstVisibleRow(selectedRowIndexes) else { return }

        let popover = NSPopover()

        // 1. Get the target cell's frame
        // Make sure the column exists and is visible
        guard columnIndexOfKelasAktif != -1 else { return }

        // 2. Instantiate your popover content view controller
        guard let (naikKelas, leadingEdgeRect) = makeNaikKelasComponents(
            tableView: tableView,
            columnIndex: columnIndexOfKelasAktif,
            row: selectedRow
        )
        else { return }

        naikKelas.onSimpanKelas = { [unowned self] _, tahunAjaran, semester in
            prosesSiswaNaik(
                kelasAktifString,
                selectedRowIndexes: selectedRowIndexes,
                tahunAjaran: tahunAjaran,
                semester: semester
            )
            popover.performClose(nil) // Close the popover after saving
        }

        naikKelas.onClose = {
            popover.performClose(nil) // Close the popover if cancelled
        }

        // 3. Configure the popover
        popover.contentViewController = naikKelas
        popover.behavior = .semitransient

        // 4. Show the popover
        // Present the popover from the calculated rectangle in the table view's superview
        tableView.scrollColumnToVisible(columnIndexOfKelasAktif)
        popover.show(relativeTo: leadingEdgeRect, of: tableView.superview!, preferredEdge: .maxY)
    }

    // MARK: - Langkah 2: Perbaiki `prosesSiswaNaik` dengan TaskGroup (Anti Race Condition)

    private func prosesSiswaNaik(_ kelasAktifString: String, selectedRowIndexes: IndexSet, tahunAjaran: String, semester: String, statusSiswa: StatusSiswa = .naik) {
        guard !selectedRowIndexes.isEmpty else { return }

        // Buat snapshot dari model asli untuk pemulihan UI
        let originalSiswaModels: [ModelSiswa] = selectedRowIndexes.compactMap {
            viewModel.filteredSiswaData[$0].copy() as? ModelSiswa
        }

        // Lakukan semua pekerjaan database di background
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Kembali ke MainActor dan siapkan kelas aktif terlebih dahulu.
            await MainActor.run {
                for data in originalSiswaModels {
                    let kelasSekarang = data.tingkatKelasAktif.rawValue
                    if statusSiswa != .aktif {
                        TableType.fromString(kelasSekarang) { type in
                            guard !(KelasViewModel.shared.isDataLoaded[type] ?? false) else {
                                self.viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: kelasSekarang))
                                return
                            }
                            Task {
                                await KelasViewModel.shared.loadKelasData(forTableType: type)
                                if let splitVC = AppDelegate.shared.mainWindow.contentViewController as? SplitVC,
                                   let contentContainerView = splitVC.contentContainerView?.viewController as? ContainerSplitView
                                {
                                    #if DEBUG
                                        print("loadView + send event")
                                    #endif
                                    _ = contentContainerView.kelasVC.view
                                }
                            }
                        }
                    }
                }
            }
            var intoKelasID: Int64?
            if statusSiswa == .naik, !kelasAktifString.isEmpty {
                guard let kelasID = await dbController.insertOrGetKelasID(
                    nama: "A",
                    tingkat: kelasAktifString.replacingOccurrences(of: "Kelas ", with: ""),
                    tahunAjaran: tahunAjaran, semester: semester
                ) else { return }
                intoKelasID = kelasID
            } else {
                intoKelasID = nil
            }
            // Menggunakan for-loop biasa untuk menjalankan operasi secara sequential
            var undoRedoContexts: [UndoNaikKelasContext] = []
            for siswa in originalSiswaModels {
                let tingkatKelas = !kelasAktifString.isEmpty
                    ? kelasAktifString.replacingOccurrences(of: "Kelas ", with: "")
                    : siswa.tingkatKelasAktif.rawValue.replacingOccurrences(of: "Kelas ", with: "")

                // 'await' di sini akan menunggu setiap operasi selesai sebelum melanjutkan ke iterasi berikutnya
                let context = dbController.naikkanSiswa(
                    siswa.id,
                    intoKelasId: intoKelasID,
                    tingkatBaru: tingkatKelas,
                    tahunAjaran: tahunAjaran,
                    semester: semester,
                    tanggalNaik: ReusableFunc.buatFormatTanggal(Date())!,
                    statusEnrollment: statusSiswa
                )

                if let ctx = context {
                    undoRedoContexts.append(ctx)
                }
            }

            // Sekarang `undoRedoContexts` dijamin sudah terisi penuh.
            guard !undoRedoContexts.isEmpty else {
                await MainActor.run {
                    ReusableFunc.showAlert(title: "Error ketika membuat context untuk undo/redo.", message: "Perubahan mungkin tidak dapat diurungkan.")
                }
                return
            }

            // Kembali ke Main Thread untuk memperbarui UI dan mendaftarkan Undo
            await MainActor.run { [undoRedoContexts] in
                var updatedSiswa: [ModelSiswa] = []
                // Perbarui ViewModel dengan data baru
                for context in undoRedoContexts {
                    if let row = self.viewModel.filteredSiswaData.firstIndex(where: { $0.id == context.siswaId }) {
                        if statusSiswa == .naik, !kelasAktifString.isEmpty {
                            self.dbController.updateStatusSiswa(idSiswa: context.siswaId, newStatus: .aktif)
                        }
                        let siswa = self.viewModel.filteredSiswaData[row]
                        // Jika mengubah kelas aktif siswa.
                        if statusSiswa != .aktif {
                            siswa.status = .aktif
                            siswa.tanggalberhenti.removeAll()

                            /* Hanya perbarui siswa tingkat kelas aktif jika dalam pembaruan kelas
                             (bukan ketika nonaktifkan atau aktifkan status)
                             */
                            siswa.tingkatKelasAktif = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
                        }
                        self.viewModel.updateSiswa(siswa, at: row)
                        updatedSiswa.append(siswa)
                    }
                }
                if statusSiswa != .aktif {
                    self.refreshTableViewCells(for: selectedRowIndexes)
                }

                // Daftarkan aksi UNDO yang bersih
                let mgr = SiswaViewModel.siswaUndoManager
                mgr.registerUndo(withTarget: self) { [weak self] _ in
                    guard let self else { return }
                    handleUndoNaikKelas(
                        contexts: undoRedoContexts,
                        siswa: originalSiswaModels,
                        aktifkanSiswa: statusSiswa == .aktif
                    )
                }

                self.deleteAllRedoArray(self)

                for data in originalSiswaModels {
                    let kelasSekarang = data.tingkatKelasAktif.rawValue
                    if statusSiswa != .aktif {
                        self.viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: kelasSekarang))
                    } else {
                        self.viewModel.kelasEvent.send(.aktifkanSiswa(data.id, kelas: kelasSekarang))
                    }
                }
            }
        }
    }

    // MARK: - Langkah 3: Buat Handler Terpisah untuk Undo dan Redo

    /// Menangani proses UNDO kenaikan kelas pada data siswa,
    /// mengembalikan state database dan UI sesuai konteks yang diberikan.
    ///
    /// Langkah-langkah yang dijalankan:
    /// 1. Memanggil `undoNaikKelas` pada database controller untuk rollback data.
    /// 2. Memperbarui model siswa pada ViewModel sesuai daftar `siswa` lama.
    /// 3. Mendaftarkan aksi REDO pada `UndoManager` untuk memungkinkan redo kenaikan kelas.
    ///
    /// - Parameters:
    ///   - contexts: Array ``UndoNaikKelasContext`` yang berisi detail operasi undo untuk tiap siswa.
    ///   - siswa: Array ``ModelSiswa`` sebelum kenaikan kelas (state lama) untuk referensi pengembalian UI.
    func handleUndoNaikKelas(contexts: [UndoNaikKelasContext], siswa: [ModelSiswa], aktifkanSiswa: Bool = false) {
        delegate?.didUpdateTable(.siswa)
        #if DEBUG
            print("--- 🔄 Melakukan UNDO Naik Kelas ---")
        #endif

        let shouldFetch = isBerhentiHidden || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        let dataToProcess = buildDataToProcess()
        let dataDict = buildDataDict(from: dataToProcess)

        let idsToProcess = siswa.map(\.id)
        let currentData = idsToProcess.compactMap { dataDict[$0] }
        let idsToFetch = Set(idsToProcess)
            .subtracting(currentData.map(\.id))
            .filter { _ in shouldFetch }

        let updatedModels = idsToFetch.isEmpty ? currentData : fetchMissingData(ids: idsToFetch)

        restoreDatabaseState(contexts: contexts)
        restoreUIState(siswa: siswa, currentSiswa: updatedModels, aktifkanSiswa: aktifkanSiswa)

        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let self else { return }
            handleRedoNaikKelas(contexts: contexts, siswa: updatedModels, oldData: siswa, aktifkanSiswa: aktifkanSiswa)
        }
    }

    /// Menangani proses REDO kenaikan kelas pada data siswa,
    /// menerapkan kembali perubahan pada database dan memperbarui UI.
    ///
    /// Langkah-langkah:
    /// 1. Jalankan Task detached dengan TaskGroup untuk paralel semua operasi DB.
    /// 2. Lakukan kenaikan kelas per context menggunakan
    /// ``DatabaseController/nainaikkanSiswa(_:namaKelasBaru:tingkatBaru:tahunAjaran:semester:tanggalNaik:statusEnrollment:)
    /// 3. Kumpulkan dan kembalikan daftar ModelSiswa yang diupdate.
    /// 4. Jalankan update UI di MainActor dengan undoEditSiswa jika diperlukan.
    /// 5. Daftarkan aksi UNDO untuk kembali ke state sebelumnya.
    ///
    /// - Parameters:
    ///   - contexts: Array ``UndoNaikKelasContext`` yang berisi detail redo untuk tiap siswa.
    ///   - siswa: Array ``ModelSiswa`` hasil state sebelum redo, untuk lookup dan update.
    ///   - oldData: Array ``ModelSiswa`` state lama sebelum undo, digunakan untuk mendaftar UNDO.
    func handleRedoNaikKelas(contexts: [UndoNaikKelasContext], siswa: [ModelSiswa], oldData: [ModelSiswa], aktifkanSiswa: Bool = false) {
        delegate?.didUpdateTable(.siswa)
        #if DEBUG
            print("--- 🔁 Melakukan REDO Naik Kelas ---")
        #endif
        Task.detached { [weak self] in
            guard let self,
                  !siswa.isEmpty, !oldData.isEmpty
            else { return }

            // Gunakan TaskGroup untuk redo semua perubahan DB
            var updatedModels = [ModelSiswa]()
            updatedModels.reserveCapacity(contexts.count)

            // 1) Proses redo secara serial (aman untuk SQLite)
            for context in contexts {
                // Cari siswa terkait
                guard let row = siswa.firstIndex(where: { $0.id == context.siswaId }) else {
                    #if DEBUG
                        print("⚠️ ID \(context.siswaId) ga ketemu, skip.")
                    #endif
                    continue
                }

                let s = siswa[row] // pastikan var agar bisa dimodifikasi lokal

                // Mutasi lokal model
                let kelasAktifString = s.tingkatKelasAktif.rawValue

                s.tingkatKelasAktif = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
                let tingkat = kelasAktifString.replacingOccurrences(of: "Kelas ", with: "")
                let status = aktifkanSiswa || s.status != .aktif
                    ? s.status
                    : .naik

                s.tanggalberhenti = status == .naik
                    ? ""
                    : s.tanggalberhenti

                #if DEBUG
                    print("⏩ REDO: \(s.nama) [id: \(s.id)] → \(tingkat), [status: \(s.status.description))")
                #endif
                var intoKelasID: Int64?
                if !context.tahunAjaran.isEmpty, !context.semester.isEmpty {
                    intoKelasID = await dbController.insertOrGetKelasID(
                        nama: "A", tingkat: tingkat,
                        tahunAjaran: context.tahunAjaran,
                        semester: context.semester
                    )
                }

                // Tulis ke DB: serial
                dbController.naikkanSiswa(
                    context.siswaId,
                    intoKelasId: intoKelasID,
                    tingkatBaru: tingkat,
                    tahunAjaran: context.tahunAjaran,
                    semester: context.semester,
                    tanggalNaik: context.newEntryTanggal,
                    statusEnrollment: status
                )
                updatedModels.append(s)
            }

            await MainActor.run { [weak self, updatedModels] in
                guard let self else { return }
                viewModel.undoEditSiswa(updatedModels, registerUndo: false)
                for data in oldData {
                    if aktifkanSiswa {
                        viewModel.kelasEvent.send(.undoAktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
                    } else {
                        viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: data.tingkatKelasAktif.rawValue))
                    }
                }
            }
        }
        let mgr = SiswaViewModel.siswaUndoManager
        mgr.registerUndo(withTarget: self) { [weak self] _ in
            guard let self else { return }
            handleUndoNaikKelas(contexts: contexts, siswa: oldData, aktifkanSiswa: aktifkanSiswa)
        }
    }

    // MARK: - HELPER

    // 1. Ambil data yang sedang ditampilkan di UI
    private func buildDataToProcess() -> [ModelSiswa] {
        if currentTableViewMode == .plain {
            viewModel.filteredSiswaData
        } else {
            viewModel.groupedSiswa.flatMap { $0 }
        }
    }

    // 2. Ubah array menjadi dictionary untuk lookup cepat
    private func buildDataDict(from data: [ModelSiswa]) -> [Int64: ModelSiswa] {
        Dictionary(uniqueKeysWithValues: data.map { ($0.id, $0) })
    }

    // 3. Fetch data yang belum ada di memori
    private func fetchMissingData(ids: Set<Int64>) -> [ModelSiswa] {
        var results: [ModelSiswa] = []
        let concurrentQueue = DispatchQueue(label: "siswa.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()

        for id in ids {
            group.enter()
            concurrentQueue.async {
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

    // 4. Kembalikan state database
    private func restoreDatabaseState(contexts: [UndoNaikKelasContext]) {
        dbController.undoNaikKelas(using: contexts)
        #if DEBUG
            print("🔧 Database dikembalikan dengan \(contexts.count) context")
        #endif
    }

    // 5. Kembalikan state UI
    private func restoreUIState(siswa: [ModelSiswa], currentSiswa: [ModelSiswa], aktifkanSiswa: Bool) {
        viewModel.undoEditSiswa(siswa, registerUndo: false)
        for data in siswa {
            if let newData = currentSiswa.first(where: { $0.id == data.id }),
               data.status == .aktif, newData.status != .aktif
            {
                viewModel.kelasEvent.send(.aktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
                continue
            }

            if aktifkanSiswa {
                viewModel.kelasEvent.send(.undoAktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
            } else {
                viewModel.kelasEvent.send(.undoUbahKelas(data.id, toKelas: data.tingkatKelasAktif.rawValue, status: data.status))
            }
        }
    }

    // MARK: - POPOVER

    private func getFirstVisibleRow(_ selectedRowIndexes: IndexSet,
                                    toolbarHeight: CGFloat = 70,
                                    toleranceRows: CGFloat = 0.5) -> Int?
    {
        guard !selectedRowIndexes.isEmpty, selectedRowIndexes.count > 1,
              var vr = scrollView?.contentView.bounds
        else {
            if let firstRow = selectedRowIndexes.first {
                tableView.scrollRowToVisible(firstRow)
                return firstRow
            }
            return nil
        }

        // Tambahkan toleransi dalam pixel
        let tolerancePx = toleranceRows * tableView.rowHeight

        // Potong offset toolbar + toleransi
        let totalSkipPx = toolbarHeight + tolerancePx
        let rowsToSkip = Int(floor(totalSkipPx / tableView.rowHeight))

        if rowsToSkip > 0 {
            if tableView.isFlipped {
                let deltaY = CGFloat(rowsToSkip) * tableView.rowHeight
                let newMinY = min(vr.minY + deltaY, vr.maxY)
                vr = NSRect(x: vr.minX, y: newMinY, width: vr.width,
                            height: max(0, vr.maxY - newMinY))
            } else {
                vr.size.height = max(0, vr.height - CGFloat(rowsToSkip) * tableView.rowHeight)
            }
        }

        // Hitung range baris visible setelah penyesuaian
        let nsr = tableView.rows(in: vr)
        guard nsr.location != NSNotFound, nsr.length > 0 else { return nil }

        let start = nsr.location
        let end = min(nsr.location + nsr.length, tableView.numberOfRows)
        let visibleIndexes = IndexSet(integersIn: start ..< end)

        // Interseksi dengan yang terpilih
        let visibleSelected = selectedRowIndexes.intersection(visibleIndexes)

        // Kalau nggak ada yang kelihatan (bahkan setelah toleransi), baru scroll
        guard let visibleRow = visibleSelected.first else {
            if let firstSel = selectedRowIndexes.first {
                tableView.scrollRowToVisible(firstSel)
                return firstSel
            }
            return nil
        }
        tableView.scrollRowToVisible(visibleRow)
        return visibleRow
    }

    /**
     Menampilkan NSPopover untuk proses aktivasi siswa atau kenaikan kelas.
     */
    private func showAktivasiPopover(for siswa: [ModelSiswa], at rows: IndexSet) {
        guard let visibleRow = getFirstVisibleRow(rows),
              let (naikKelasVC, anchorRect) = makeNaikKelasComponents(
                  tableView: tableView,
                  columnIndex: columnIndexOfKelasAktif,
                  row: visibleRow
              )
        else { return }

        let popover = NSPopover()
        popover.contentViewController = naikKelasVC
        popover.behavior = .semitransient

        naikKelasVC.onSimpanKelas = { [weak self, weak popover] _, tahunAjaran, semester in
            guard let self else { return }

            // Memanggil logika proses inti
            prosesSiswaNaik(
                "",
                selectedRowIndexes: rows,
                tahunAjaran: tahunAjaran,
                semester: semester,
                statusSiswa: .aktif
            )

            // Lakukan update UI sederhana secara langsung untuk responsivitas
            // (Logika update yang lebih kompleks sudah ada di dalam prosesSiswaNaik)
            for siswaModel in siswa {
                dbController.updateKolomSiswa(siswaModel.id, kolom: SiswaColumns.tanggalberhenti, data: "")
                dbController.updateStatusSiswa(idSiswa: siswaModel.id, newStatus: .aktif)
                siswaModel.status = .aktif
                siswaModel.tanggalberhenti = ""
                if let index = viewModel.filteredSiswaData.firstIndex(of: siswaModel) {
                    viewModel.updateSiswa(siswaModel, at: index)
                }
            }
            let cols = IndexSet([columnIndexOfStatus, columnIndexOfTglBerhenti])
            tableView.reloadData(forRowIndexes: rows, columnIndexes: cols)

            popover?.performClose(nil)
        }

        naikKelasVC.onClose = { [weak popover] in
            popover?.performClose(nil)
        }

        tableView.scrollColumnToVisible(columnIndexOfKelasAktif)
        popover.show(relativeTo: anchorRect, of: tableView.superview!, preferredEdge: .maxY)
    }
}
