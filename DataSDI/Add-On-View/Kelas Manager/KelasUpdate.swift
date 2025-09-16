//
//  KelasUpdate.swift
//  Data SDI
//
//  Created by MacBook on 12/09/25.
//

import Cocoa

extension KelasTableManager {
    /// Menghapus item dari tabel dan menyiapkan undo.
    /// - Parameters:
    ///   - tableType: Jenis tabel yang sedang dihapus.
    ///   - tableView: Tabel tempat baris dihapus.
    ///   - allIDs: ID unik data yang akan dihapus.
    ///   - deletedDataArray: Referensi array untuk menyimpan data terhapus (jika lokal).
    ///   - undoManager: Undo manager untuk mendaftarkan aksi undo.
    ///   - undoTarget: Target object untuk aksi undo.
    ///   - undoHandler: Closure yang dipanggil saat undo.
    /// - Returns: Tuple berisi daftar ID yang dihapus dan data yang dihapus.
    @MainActor
    @discardableResult
    func hapusModelTabel(
        tableType: TableType,
        tableView: NSTableView,
        allIDs: [Int64],
        deletedDataArray: inout [[KelasModels]],
        undoManager: UndoManager?,
        undoTarget: AnyObject,
        undoHandler: @escaping (AnyObject) -> Void
    ) -> (allIDs: [Int64], result: [KelasModels])? {
        guard !allIDs.isEmpty else { return nil }

        guard let result = viewModel.removeData(
            withIDs: allIDs,
            forTableType: tableType,
            siswaID: siswaID,
            arsip: arsip
        )
        else {
            return nil
        }

        deletedDataArray.append(result.kelasModels)

        let deletedIndexes = IndexSet(result.intArray)

        SingletonData.deletedKelasAndSiswaIDs.append(result.relationArray)
        UpdateData.applyUpdates(result.updates, tableView: tableView)
        selectRowAfterDeletion(deletedIndexes, tableView: tableView)

        undoManager?.registerUndo(withTarget: undoTarget, handler: undoHandler)

        return (allIDs, result.kelasModels)
    }

    /// Memilih baris yang sesuai di `NSTableView` setelah satu atau beberapa baris dihapus.
    ///
    /// Fungsi ini memastikan bahwa setelah operasi penghapusan, selalu ada baris
    /// yang dipilih (jika ada baris yang tersisa). Logikanya akan mencoba memilih
    /// baris yang terletak tepat di atas posisi baris yang baru saja dihapus
    /// atau baris terakhir yang tersisa jika penghapusan terjadi di bagian akhir tabel.
    ///
    /// - Parameters:
    ///   - indexes: `IndexSet` yang berisi indeks baris-baris yang telah dihapus.
    ///   - tableView: `NSTableView` tempat operasi penghapusan terjadi.
    func selectRowAfterDeletion(_ indexes: IndexSet, tableView: NSTableView) {
        let totalRowsAfterDeletion = tableView.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            let rowToSelect = min(totalRowsAfterDeletion - 1, indexes.first ?? 0)
            tableView.selectRowIndexes(IndexSet(integer: rowToSelect), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            tableView.deselectAll(nil)
        }
    }

    /// Fungsi ini akan mengembalikan data yang telah dihapus ke dalam tabel yang sesuai.
    ///
    /// Fungsi ini juga akan memperbarui tampilan tabel dan mengelola undo manager untuk memungkinkan pengguna membatalkan tindakan pemulihan jika diperlukan.
    /// - Parameters:
    ///   - deletedData: Tuple yang berisi tabel dan data yang telah dihapus.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperbarui.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan data yang akan dipulihkan.
    ///   - table: Tabel yang digunakan untuk menampilkan data kelas.
    ///   - viewController: NSViewController yang digunakan untuk mengelola tampilan dan interaksi pengguna.
    ///   - undoManager: UndoManager yang digunakan untuk mengelola tindakan undo dan redo.
    ///   - window: NSWindow yang digunakan untuk menampilkan jendela progres.
    ///   - onlyDataKelasAktif: Boolean yang menentukan apakah hanya data kelas aktif yang akan dipulihkan.
    ///   - nilaiID: Array yang digunakan untuk menyimpan ID kelas yang telah dipulihkan.
    ///   - siswaID: ID Siswa unik. Opsional untuk memilih data yang sesuai.
    func restoreDeletedDataDirectly(
        deletedData: [KelasModels],
        tableType: TableType,
        sortDescriptor: NSSortDescriptor,
        table: NSTableView,
        viewController: NSViewController,
        undoManager: UndoManager,
        onlyDataKelasAktif _: Bool,
        nilaiID: inout [[Int64]],
        siswaID: Int64? = nil,
        undoHandler: @escaping (AnyObject) -> Void
    ) {
        // 1) Validasi cepat
        guard validateInput(deletedData),
              let comparator = getComparator(sortDescriptor)
        else { return }

        // 2) Nested helper: insert data & kumpulkan indeks/ID
        let restoreBatch: () -> (indices: [Int], ids: [Int64]) = { [weak self] in
            guard let self else { return ([], []) }
            var rows: [Int] = []
            var ids: [Int64] = []
            for model in deletedData.reversed() {
                guard let idx = viewModel.insertData(
                    for: tableType,
                    deletedData: model,
                    comparator: comparator,
                    siswaID: siswaID
                ) else { continue }
                viewModel.updateDataArray(tableType, dataToInsert: model)
                rows.append(idx)
                ids.append(model.nilaiID)
            }
            return (rows, ids)
        }

        let (restoredRows, restoredIDs) = restoreBatch()
        table.beginUpdates()
        table.insertRows(at: IndexSet(restoredRows), withAnimation: .slideDown)
        table.selectRowIndexes(IndexSet(restoredRows), byExtendingSelection: false)
        table.endUpdates()
        // 4) Scroll
        if let maxRow = restoredRows.max() {
            table.scrollRowToVisible(maxRow)
        }
        nilaiID.append(restoredIDs)

        undoManager.registerUndo(withTarget: viewController, handler: undoHandler)

        // 5) Undo & Notification
        postRestorationNotification(for: viewController, tableType: tableType, deletedData: deletedData)
        updateSingletonData(with: restoredIDs)
    }

    private func validateInput(_ deletedData: [KelasModels]) -> Bool {
        guard !deletedData.isEmpty else {
            #if DEBUG
                print("Tidak ada data yang dihapus untuk dipulihkan.")
            #endif
            return false
        }

        return true
    }

    private func getComparator(_ sortDescriptor: NSSortDescriptor) -> ((KelasModels, KelasModels) -> Bool)? {
        guard let comparator = KelasModels.comparator(from: sortDescriptor) else {
            #if DEBUG
                print("Invalid sort descriptor.")
            #endif
            return nil
        }
        return comparator
    }

    private func postRestorationNotification(
        for viewController: NSViewController,
        tableType: TableType,
        deletedData: [KelasModels]
    ) {
        let userInfo: [String: Any] = [
            "tableType": tableType,
            "deletedData": deletedData,
        ]
        if viewController is KelasVC {
            NotificationCenter.default.post(
                name: .undoKelasDihapus,
                object: self,
                userInfo: userInfo
            )
        } else if viewController is DetailSiswaController {
            NotificationCenter.default.post(
                name: .updateRedoInDetilSiswa,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func updateSingletonData(with restoredIDs: [Int64]) {
        SingletonData.deletedNilaiID.append(restoredIDs)
        SingletonData.deletedKelasAndSiswaIDs.removeAll { pairList in
            pairList.contains { restoredIDs.contains($0.nilaiID) }
        }
    }

    /**
     * Membuka dan mengkonfigurasi jendela progres baru sebagai lembar (sheet) di atas jendela utama.
     * @discussion Fungsi ini bertanggung jawab untuk memuat `NSWindowController` dan `ProgressBarVC`
     * dari storyboard "ProgressBar". Setelah berhasil memuat, ia mengatur total item yang akan diperbarui
     * dan pengenal controller di `ProgressBarVC`. Jendela progres kemudian disajikan
     * sebagai lembar modal di atas jendela aplikasi utama.
     *
     * @param totalItems: Int - Jumlah total item yang akan diproses atau diperbarui, yang akan ditampilkan di bilah progres.
     * @param controller: String - String pengenal yang menunjukkan controller mana yang memicu jendela progres ini (misalnya, untuk tujuan pelacakan atau logika).
     * @param viewWindow: NSWindow - Jendela untuk menampilkan sheet.
     *
     * @returns: (NSWindowController, ProgressBarVC)? - Sebuah tuple yang berisi `NSWindowController` dan ``ProgressBarVC``
     * dari jendela progres, atau `nil` jika gagal memuat dari storyboard atau mengkonversi controller.
     */
    func openProgressWindow(totalItems: Int, controller: String, viewWindow: NSWindow) -> (NSWindowController, ProgressBarVC)? {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC,
              let window = progressWindowController.window
        else {
            return nil
        }

        progressViewController.totalStudentsToUpdate = totalItems
        progressViewController.controller = controller
        viewWindow.beginSheet(window)

        return (progressWindowController, progressViewController)
    }

    /// Fungsi ini akan mengembalikan data yang telah dihapus ke dalam tabel yang sesuai, dengan menampilkan progres selama proses pemulihan.
    /// Fungsi ini juga akan memperbarui tampilan tabel dan mengelola undo manager untuk memungkinkan pengguna membatalkan tindakan pemulihan jika diperlukan.
    /// - Parameters:
    ///   - deletedData: Tuple yang berisi tabel dan data yang telah dihapus.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperbarui.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan data yang akan dipulihkan.
    ///   - table: Tabel yang digunakan untuk menampilkan data kelas.
    ///   - viewController: NSViewController yang digunakan untuk mengelola tampilan dan interaksi pengguna.
    ///   - undoManager: UndoManager yang digunakan untuk mengelola tindakan undo dan redo.
    ///   - operationQueue: NSOperationQueue yang digunakan untuk menjalankan operasi pemulihan secara asinkron.
    ///   - window: NSWindow yang digunakan untuk menampilkan jendela progres.
    ///   - onlyDataKelasAktif: Boolean yang menentukan apakah hanya data kelas aktif yang akan dipulihkan.
    ///   - nilaiID: Array yang digunakan untuk menyimpan ID kelas yang telah dipulihkan.
    func restoreDeletedDataWithProgress(
        deletedData: [KelasModels],
        tableType: TableType,
        sortDescriptor: NSSortDescriptor,
        table: NSTableView,
        viewController: NSViewController,
        undoManager: UndoManager,
        operationQueue: OperationQueue,
        window: NSWindow,
        onlyDataKelasAktif _: Bool,
        nilaiID: inout [[Int64]]
    ) {
        // Pastikan bahwa deletedData.data tidak kosong
        guard !deletedData.isEmpty,
              let comparator = KelasModels.comparator(from: sortDescriptor)
        else {
            #if DEBUG
                print("Tidak ada data yang dihapus untuk dipulihkan.")
            #endif
            return
        }
        guard let (progressWindowController, progressViewController) = openProgressWindow(totalItems: deletedData.count, controller: "data kelas", viewWindow: window) else { return }

        let totalStudents = deletedData.count
        var processedStudentsCount = 0
        let batchSize = max(totalStudents / 20, 1)
        var allIDs: [Int64] = []
        var lastIndex: [Int] = []
        progressViewController.totalStudentsToUpdate = totalStudents
        progressViewController.controller = "Kelas Aktif"

        operationQueue.addOperation { [weak self, weak table] in
            guard let self, let table else { return }
            for (_, data) in deletedData.enumerated().reversed() {
                allIDs.append(data.nilaiID)
                guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: data, comparator: comparator) else { return }
                OperationQueue.main.addOperation { [weak viewModel] in
                    viewModel?.updateDataArray(tableType, dataToInsert: data)
                    table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: [])
                    table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
                    lastIndex.append(insertionIndex)
                    processedStudentsCount += 1

                    if processedStudentsCount == totalStudents || processedStudentsCount % batchSize == 0 {
                        progressViewController.currentStudentIndex = processedStudentsCount
                    }
                }
            }
        }

        nilaiID.append(allIDs)
        operationQueue.addOperation {
            OperationQueue.main.addOperation {
                if let maxIndex = lastIndex.max() {
                    table.scrollRowToVisible(maxIndex)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    window.endSheet(progressWindowController.window!)
                }
            }
        }

        undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
            (viewController as? KelasVC)?.redoHapus(table: table, tableType: tableType)
        }
        updateSingletonData(with: allIDs)
        postRestorationNotification(for: viewController, tableType: tableType, deletedData: deletedData)
    }

    /**
     Membatalkan penghapusan baris pada tabel. Fungsi ini mengambil state sebelumnya dari data yang dihapus dari stack undo,
     memasukkan kembali data tersebut ke dalam model, dan memperbarui tampilan tabel untuk mencerminkan perubahan.

     - Parameter model: Model data yang akan dimodifikasi.
     - Parameter tableType: Jenis tabel yang sedang dioperasikan (misalnya, siswa, guru, dll.).
     - Parameter completion: Closure yang dijalankan ketika proses selesai dengan mengirim indeks baris
                             yang baru ditambahkan.
     */
    func undoDeleteRows(from model: inout [KelasModels], tableType: TableType, completion: (() -> Void)? = nil) {
        guard let tableView = getTableView(for: tableType.rawValue),
              let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = KelasModels.comparator(from: sortDescriptor)
        else { return }

        var updates = [UpdateData]()

        func updateData(deletedData: KelasModels) {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, comparator: comparator, siswaID: siswaID) else {
                #if DEBUG
                    print("error insertionIndex undoDeleteRows DetailSiswaController")
                #endif
                return
            }
            updates.append(.insert(index: insertionIndex, selectRow: false, extendSelection: false))
        }

        for deletedData in model {
            if siswaID != nil {
                if deletedData.siswaID == siswaID {
                    updateData(deletedData: deletedData)
                }
            } else {
                updateData(deletedData: deletedData)
            }
        }
        Task { @MainActor [updates] in
            UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: false)
        }

        // Update table view untuk menampilkan baris yang diinsert
        completion?()
    }
}
