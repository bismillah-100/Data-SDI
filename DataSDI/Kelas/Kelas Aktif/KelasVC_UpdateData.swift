//
//  KelasVC_UpdateData.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Cocoa

extension KelasVC {
    // MARK: - UNDO ACTION

    /// Fungsi untuk menjalankan undo.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func urung(_: Any) {
        if myUndoManager.canUndo {
            myUndoManager.undo()
        }
    }

    /// Fungsi untuk menjalankan redo.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func ulang(_: Any) {
        if myUndoManager.canRedo {
            myUndoManager.redo()
        }
    }

    // MARK: - ADD DATA

    /// Fungsi ini menangani aksi tempel data ke dalam tabel yang sedang aktif.
    /// - Parameter sender: Objek yang memicu aksi tempel.
    @IBAction func paste(_: Any) {
        let (addNilai, addWindow) = findAddDetailInKelas()
        let (mapel, guru, nilai) = viewModel.parsePasteboard()

        guard let addNilai, let addWindow, let mapel, let guru, let nilai else { return }

        AppDelegate.shared.mainWindow.beginSheet(addWindow)

        addNilai.titleText.stringValue = "Paste nilai"

        addNilai.mapelTextField.stringValue = mapel
        addNilai.guruMapel.stringValue = guru
        addNilai.nilaiTextField.stringValue = nilai
        addNilai.updateItemCount()
    }

    /// Fungsi ini untuk menjalankan undo paste pada tableView yang sesuai dengan tipe tabel yang diberikan.
    /// - Parameters:
    ///   - table: `NSTableView` yang akan di-undo paste.
    ///   - tableType: `TableType` yang sesuai dengan tipe tabel yang akan di-undo paste.
    func undoPaste(table: NSTableView, tableType: TableType) {
        guard !pastedNilaiID.isEmpty else {
            #if DEBUG
                print("Tidak ada data yang dapat di-undo paste.")
            #endif
            return
        }

        activateTable(table)

        // Ambil semua ID dari array nilaiID terakhir
        let allIDs = pastedNilaiID.removeLast()

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &SingletonData.pastedData, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.redoPaste(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .kelasDihapus)
    }

    func redoPaste(tableType: TableType, table: NSTableView) {
        // Memastikan sortDescriptor di KelasModels tersedia.
        guard let sortDescriptor = table.sortDescriptors.first else {
            return
        }
        // Pindah ke tabel yang akan diperbarui.
        activateTable(table)

        table.deselectAll(self)
        let pasteData = SingletonData.pastedData.removeLast()

        tableViewManager.restoreDeletedDataDirectly(
            deletedData: pasteData,
            tableType: tableType,
            sortDescriptor: sortDescriptor,
            table: table,
            viewController: self,
            undoManager: myUndoManager,
            onlyDataKelasAktif: false,
            nilaiID: &pastedNilaiID
        ) { [weak self] _ in
            self?.undoPaste(table: table, tableType: tableType)
        }

        updateUndoRedo(self)
        NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedData": pasteData])
    }

    private func findAddDetailInKelas() -> (AddDetaildiKelas?, NSWindow?) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("AddDetaildiKelas"), bundle: nil)
        guard let addDataKelas = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas")) as? AddDetaildiKelas else { return (nil, nil) }
        let detailWindow = NSWindow(contentViewController: addDataKelas)
        detailWindow.setFrame(NSRect(x: 0, y: 0, width: 296, height: 420), display: true, animate: false)

        addDataKelas.onSimpanClick = { [weak self] dataArray, tambah, _, _ in
            self?.updateTable(dataArray, tambahData: tambah)
        }

        if let selectedTabIndex = tableViewManager.selectedTabViewItem() {
            addDataKelas.appDelegate = false
            addDataKelas.tabKelas(index: selectedTabIndex)
        }

        return (addDataKelas, detailWindow)
    }

    /// Fungsi ini menangani penambahan data baru ke kelas.
    /// - Parameter sender: Objek pemicu yang dapat berupa apapun.
    @objc func addData(_: Any?) {
        guard let selectedTabIndex = tableViewManager.selectedTabViewItem() else { return }
        if let window = NSApp.mainWindow?.windowController as? WindowController,
           let toolbar = window.datakelas, toolbar.isVisible, let button = window.tambahDetaildiKelas,
           let popover = AppDelegate.shared.popoverAddDataKelas,
           let addDataKelas = popover.contentViewController as? AddDetaildiKelas
        {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)

            addDataKelas.appDelegate = true
            addDataKelas.tabKelas(index: selectedTabIndex)
        }

        else {
            AppDelegate.shared.showInputNilai(selectedTabIndex)
        }
        ReusableFunc.resetMenuItems()
    }

    /// Fungsi ini menangani penambahan siswa baru.
    @objc func addSiswa(_ sender: Any?) {
        // Tentukan titik tampilan untuk menempatkan popover
        let popover = AppDelegate.shared.popoverAddSiswa

        if let button = sender as? NSButton {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
        }

        if let vc = popover?.contentViewController as? AddDataViewController {
            vc.sourceViewController = .siswaViewController
            if let selectedTabIndex = tableViewManager.selectedTabViewItem() {
                vc.sourceViewController = .kelasViewController
                vc.kelasTerpilih(index: selectedTabIndex)
            }
        }
        ReusableFunc.resetMenuItems()
    }

    // MARK: - INSERT DATA KE TABLEVIEW

    /// Menyisipkan baris baru pada tableView yang sesuai dengan data yang diberikan.
    /// - Parameters:
    ///   - index: Indeks untuk tableView yang sesuai dengan data yang akan disisipkan.
    ///   - data: Data kelas yang akan disisipkan ke dalam tableView.
    /// - Returns: Nilai indeks baris yang disisipkan, atau `nil` jika penyisipan gagal.
    @discardableResult
    func insertRow(forIndex index: Int, withData data: KelasModels,
                   comparator: @escaping (KelasModels, KelasModels) -> Bool) -> Int?
    {
        guard let tableType = TableType(rawValue: index) else {
            #if DEBUG
                print("Tipe tabel tidak ditemukan untuk indeks \(index)")
            #endif
            return nil
        }
        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, comparator: comparator) else {
            #if DEBUG
                print("Gagal menyisipkan data untuk indeks \(index)")
            #endif
            return nil
        }
        // Mendapatkan tableView yang sesuai dengan indeks
        let tableView = tableViewManager.getTableView(for: index)
        tableView?.insertRows(at: IndexSet(integer: rowInsertion), withAnimation: .slideDown)
        tableView?.scrollRowToVisible(rowInsertion)
        return rowInsertion
    }

    /// Fungsi ini menangani notifikasi ketika data kelas ditambah.
    /// - Parameter notification: Objek `Notification` yang memicu.
    func updateTable(_ dataArray: [(index: Int, data: KelasModels)], tambahData: Bool) {
        var table: NSTableView!
        var updatedClass: SidebarIndex?
        // Nama Kelas yang sedang diperbarui.
        var controller: String?
        // Mendapatkan indeks baris di tableView yang telah diinsert untuk dipilih.
        var rowIndex = IndexSet()
        // Menyimpan ID unik kelas yang akan di-tambahkan.
        var id = Set<Int64>()

        let indexes = dataArray.map(\.index)

        // Jumlah data yang akan diperbarui.
        let totalStudents = dataArray.count

        // Membuka progress window
        guard let index = indexes.first,
              let sortDescriptor = getCurrentSortDescriptor(for: index),
              let comparator = KelasModels.comparator(from: sortDescriptor),
              let window = view.window,
              let (progressWindowController, progressViewController) = tableViewManager.openProgressWindow(
                  totalItems: totalStudents,
                  controller: controller ?? "data kelas",
                  viewWindow: window
              )
        else { return }

        // Mengatur progress view controller
        var processedStudentsCount = 0
        // Mengatur operasi antrian untuk pembaruan data
        operationQueue.maxConcurrentOperationCount = 1

        // Menghitung frekuensi pembaruan untuk progress view
        let updateFrequency = totalStudents > 100 ? max(totalStudents / 10, 1) : 1

        operationQueue.addOperation { [unowned self] in
            // Iterasi melalui dataArray dari belakang untuk menghindari masalah saat menambahkan baris.
            for data in dataArray.reversed() {
                let index = data.index
                let data = data.data
                id.insert(data.nilaiID)
                table = tableViewManager.tables[index]
                updatedClass = SidebarIndex(rawValue: index + 3)
                OperationQueue.main.addOperation { [unowned self] in
                    if controller != activeTableType.stringValue {
                        // Jika controller tidak sesuai dengan label aktif, buat label baru
                        controller = activeTableType.stringValue
                        progressViewController.controller = controller
                    }

                    // delegate untuk memperbarui seleksi tabel di ``SidebarViewController``.
                    delegate?.didUpdateTable(updatedClass ?? .kelas1)

                    delegate?.didCompleteUpdate()

                    // Memastikan nama siswa tidak kosong sebelum memasukkan baris.
                    insertRow(forIndex: index, withData: data, comparator: comparator)

                    processedStudentsCount += 1

                    // Update progress
                    if processedStudentsCount % updateFrequency == 0 || processedStudentsCount == totalStudents {
                        progressViewController.currentStudentIndex = processedStudentsCount
                    }
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedNilaiIDs.append(data.nilaiID)
            }
            OperationQueue.main.addOperation { [weak self] in
                guard let self, let table, let tipeTable = tableType(table) else {
                    #if DEBUG
                        print("Tipe tabel tidak ditemukan untuk tableView.")
                    #endif
                    progressWindowController.close()
                    return
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedNilaiID.append(pastedNilaiIDs)
                // hapus nilaiIDs yang sudah disimpan.
                pastedNilaiIDs.removeAll()

                myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.undoPaste(table: table, tableType: tipeTable)
                }

                view.window?.makeFirstResponder(table)

                table.beginUpdates()

                // Memastikan bahwa ID yang baru ditambahkan ada di dalam model kelas untuk tabel yang sesuai.
                for ID in id {
                    let model = viewModel.kelasModelForTable(tipeTable)
                    if let index = model.firstIndex(where: { $0.nilaiID == ID }) {
                        rowIndex.insert(index)
                    }
                }

                table.selectRowIndexes(rowIndex, byExtendingSelection: false)
                table.endUpdates()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.view.window?.endSheet(progressWindowController.window!)
                }
            }
        }

        guard tambahData == true else { return }
        // Jika data yang ditambahkan adalah data baru, maka kita perlu menghapus redoArray.
        deleteRedoArray(self)
    }

    // MARK: - HAPUS DATA NILAI KELAS

    private func uniqueNamesAndMapel(for tableType: TableType, indexes: IndexSet) -> (names: String, mapel: String) {
        var namesSet = Set<String>()
        var mapelSet = Set<String>()
        for index in indexes {
            let model = viewModel.kelasModelForTable(tableType)[index]
            namesSet.insert(model.namasiswa)
            mapelSet.insert(model.mapel)
        }
        return (
            names: namesSet.sorted().joined(separator: ", "),
            mapel: mapelSet.sorted().joined(separator: ", ")
        )
    }

    private func showDeleteConfirmation(
        tableType: TableType,
        indexes: IndexSet
    ) -> Bool {
        let (names, mapel) = uniqueNamesAndMapel(for: tableType, indexes: indexes)
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        alert.showsSuppressionButton = true
        alert.messageText = "Apakah Anda yakin akan menghapus data dari〝\(names)〞?"
        alert.informativeText = "Data〝\(mapel)〞yang dipilih dari〝\(names)〞akan dihapus di rincian siswa."

        let suppressAlert = UserDefaults.standard.bool(forKey: "hapusKelasAktifAlert")
        if suppressAlert { return true }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "hapusKelasAktifAlert")
            }
            return true
        }
        return false
    }

    /// Fungsi ini menangani aksi hapus menu untuk menghapus data siswa dari tabel dan model data.
    /// - Parameter _: Objek pemicu.
    @objc func hapus(_: Any) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
           let (table, tableType, selectedIndexes) = delete.representedObject as? (NSTableView, TableType, IndexSet),
           !selectedIndexes.isEmpty
        {
            if showDeleteConfirmation(tableType: tableType, indexes: selectedIndexes) {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /// Fungsi ini menangani aksi hapus menu untuk menghapus data siswa dari tabel dan model data.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType) else { return }
        let rows = ReusableFunc.resolveRowsToProcess(
            selectedRows: table.selectedRowIndexes,
            clickedRow: table.clickedRow
        )
        guard !rows.isEmpty else { return }

        if showDeleteConfirmation(tableType: tableType, indexes: rows) {
            hapusPilih(tableType: tableType, table: table, selectedIndexes: rows)
        }
    }

    /// Fungsi ini menangani aksi hapus untuk menghapus data siswa yang dipilih di tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    /// - selectedIndexes: Baris yang dipilih di tabel.
    func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        let dataArray = viewModel.kelasModelForTable(tableType)
        let allIDs = selectedIndexes.map { index in
            dataArray[index].nilaiID
        }

        // Bersihkan array nilaiID
        deleteRedoArray(self)

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &SingletonData.deletedDataArray, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        // Post notifikasi untuk pembaruan tampilan
        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .kelasDihapus)
    }

    /// Fungsi ini menghapus data yang telah dihapus sebelumnya dari undo stack dan redo stack.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    func undoHapus(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = table.sortDescriptors.first,
              !SingletonData.deletedDataArray.isEmpty,
              // Buat array baru untuk menyimpan semua id yang dihasilkan
              let semuaElemen = SingletonData.deletedDataArray.last
        else {
            return
        }

        let deletedDatas = SingletonData.deletedDataArray.removeLast()
        SingletonData.dataArray.removeAll()
        operationQueue.maxConcurrentOperationCount = 1
        activateTable(table)
        if deletedDatas.count >= 100 {
            tableViewManager.restoreDeletedDataWithProgress(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                operationQueue: operationQueue,
                window: view.window!,
                onlyDataKelasAktif: false,
                nilaiID: &nilaiID
            )
        } else {
            tableViewManager.restoreDeletedDataDirectly(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                onlyDataKelasAktif: false,
                nilaiID: &nilaiID
            ) { [weak self] _ in
                self?.redoHapus(table: table, tableType: tableType)
            }
        }

        DispatchQueue.main.async {
            if let currentStackData = SingletonData.undoStack[tableType.stringValue] {
                var hasFilteredData = false

                for (stackIndex, stackModels) in currentStackData.enumerated() {
                    let filteredModels = stackModels.filter { model in
                        let shouldKeep = !semuaElemen.contains { $0.siswaID == model.siswaID }

                        return shouldKeep
                    }

                    SingletonData.undoStack[tableType.stringValue]?[stackIndex] = filteredModels

                    if filteredModels.count != stackModels.count {
                        hasFilteredData = true
                    }
                }

                // Menampilkan alert jika ada data yang terfilter
                if hasFilteredData {
                    let alert = NSAlert()
                    alert.icon = NSImage(named: "NSCaution")
                    alert.messageText = "Inkonsistensi data"
                    alert.informativeText = "Seluruh data \(self.activeTableType.stringValue) dimuat ulang karena terdapat inkonsistensi data:\nSiswa tidak di Kelas Aktif \(self.activeTableType.stringValue)"
                    alert.addButton(withTitle: "OK")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        self.muatUlang(self)
                    }
                }
            }
        }

        if var kelasUndoStack = SingletonData.undoStack[tableType.stringValue] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[tableType.stringValue] = kelasUndoStack
        }

        updateUndoRedo(self)
    }

    /// Fungsi ini menangani aksi redo untuk menghapus data siswa yang telah dihapus sebelumnya.
    /// - Parameters:
    /// - table: Tabel yang sedang aktif.
    /// - tableType: Tipe tabel yang sedang aktif.
    func redoHapus(table: NSTableView, tableType: TableType) {
        guard !SingletonData.deletedNilaiID.isEmpty else {
            #if DEBUG
                print("Tidak ada data yang bisa di-Redo untuk \(tableType.stringValue)")
            #endif
            return
        }
        activateTable(table)
        let allIDs = SingletonData.deletedNilaiID.removeLast()

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &SingletonData.deletedDataArray, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }

        if !nilaiID.isEmpty {
            nilaiID.removeLast()
        }

        // Perbarui tampilan setelah penghapusan berhasil dilakukan
        updateUndoRedo(self)

        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .kelasDihapus)
    }

    /// Fungsi ini menghapus baris yang telah ditentukan ``handleSiswaDihapusNotification(_:)``
    /// dari model dan tabel.
    func deleteRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String) {
        var indexesToDelete = IndexSet()

        // Simpan state model sebelum penghapusan untuk undo
        if SingletonData.undoStack[kelasSekarang] == nil {
            SingletonData.undoStack[kelasSekarang] = []
        }

        let itemsToUndo = model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels }
        SingletonData.undoStack[kelasSekarang]?.append(itemsToUndo)

        var updates: [UpdateData] = []

        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if deletedIDs.contains(item.siswaID) {
                indexesToDelete.insert(index)
            }
        }

        // Hapus data dari model
        for index in indexesToDelete.sorted(by: >) {
            // Panggil fungsi removeData untuk setiap kelas
            TableType.fromString(kelasSekarang) { kelas in
                let update = viewModel.removeData(index: index, tableType: kelas)
                updates.append(update)
            }
        }

        model.removeAll { item in
            // Cek apakah siswaID ada di deletedIDs
            deletedIDs.contains(item.siswaID)
        }

        if var kelasUndoStack = SingletonData.undoStack[kelasSekarang] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[kelasSekarang] = kelasUndoStack
        }

        // Hapus baris dari NSTableView
        Task { @MainActor [updates] in
            UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: false)
        }
    }

    /// Fungsi ini menangani ketika siswa ditambahkan kembali setelah dihapus.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter payload: Objek ``NotifSiswaDihapus`` untuk informasi data dari pengirim.
    func handleUndoSiswaDihapusNotification(_ payload: NotifSiswaDihapus) {
        let kelasSekarang = payload.kelasSekarang

        TableType.fromString(kelasSekarang) { [weak self] kelas in
            guard let self, let tableView = tableViewManager.getTableView(for: kelas.rawValue) else { return }
            let model = viewModel.kelasModelForTable(kelas)
            var modifiableModel: [KelasModels] = model
            if !(isDataLoaded[tableView] ?? false) {
                guard let undoStack = SingletonData.undoStack[kelasSekarang], !undoStack.isEmpty else { return }
                SingletonData.undoStack[kelasSekarang]?.removeLast()
                viewModel.setModel(modifiableModel, for: kelas)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.undoDeleteRows(from: &modifiableModel, tableView: tableView, kelasSekarang: kelasSekarang)
                }
            }
        }
    }

    /// Fungsi ini mengembalikan baris yang telah dihapus sebelumnya ke dalam tabel.
    /// - Parameters:
    ///  - model: Model yang berisi data kelas.
    /// - tableView: Tabel yang akan diperbarui.
    /// - kelasSekarang: Nama kelas yang akan diperbarui.
    func undoDeleteRows(from _: inout [KelasModels], tableView: NSTableView, kelasSekarang: String) {
        guard var undoStackForKelas = SingletonData.undoStack[kelasSekarang], !undoStackForKelas.isEmpty,
              let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = KelasModels.comparator(from: sortDescriptor)
        else { return }
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        SingletonData.undoStack[kelasSekarang] = undoStackForKelas

        tableView.beginUpdates()
        for deletedData in previousState.sorted() {
            TableType.fromString(kelasSekarang) { kelas in
                // Panggil fungsi insert untuk setiap kelas
                guard let insertIndex = viewModel.insertData(for: kelas, deletedData: deletedData, comparator: comparator) else { return }
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: [])
            }
        }
        tableView.endUpdates()
    }

    // MARK: - Notifikasi Siswa dari Daftar Siswa

    /// Fungsi ini menangani notifikasi ketika siswa dihapus dari kelas.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter payload: ``NotifSiswaDihapus`` untuk informasi data dari pengirim.
    func handleSiswaDihapusNotification(_ payload: NotifSiswaDihapus) {
        let kelasSekarang = payload.kelasSekarang
        let deletedIDs = payload.deletedStudentIDs
        var modifiableModel: [KelasModels] = []
        TableType.fromString(kelasSekarang) { kelas in
            modifiableModel = viewModel.kelasModelForTable(kelas)
            guard let table = tableViewManager.getTableView(for: kelas.rawValue) else { return }
            deleteRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang)
            viewModel.setModel(modifiableModel, for: kelas)
        }
    }

    // MARK: - EDIT DATA

    /// Fungsi ini menangani aksi naik kelas untuk siswa yang dipilih di tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func naikKelasMenu(_: NSMenuItem) {
        ReusableFunc.showAlert(title: "Kelas hanya dapat diubah dari Daftar Siswa.", message: "Ubah kelas dari daftar siswa. Anda akan diarahkan ke Daftar Siswa setelah konfirmasi.")
        delegate?.didUpdateTable(.siswa)
    }

    /// Fungsi ini menangani aksi undo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func undoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        tableViewManager.updateNilai(originalModel, newValue: originalModel.oldValue)
        // Daftarkan aksi redo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoAction(originalModel: originalModel)
        })
        // Hapus nilai lama dari array undo
        undoArray.removeAll(where: { $0 == originalModel })
        // Simpan nilai lama ke dalam array redo
        redoArray.append(originalModel)
        updateUndoRedo(self)
    }

    /// Fungsi ini menangani aksi redo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func redoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        tableViewManager.updateNilai(originalModel, newValue: originalModel.newValue)
        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        })
        // Hapus nilai lama dari array redo
        redoArray.removeAll(where: { $0 == originalModel })
        // Simpan nilai baru ke dalam array undo
        undoArray.append(originalModel)
        updateUndoRedo(self)
    }

    // MARK: - NOTIFICATION DATA

    /**
     * Menangani notifikasi ketika nama siswa telah diedit, memperbarui UI untuk baris yang relevan.
     * @discussion Fungsi ini dipicu oleh notifikasi yang berisi informasi tentang perubahan nama siswa.
     * Ini mengambil ID siswa, kelas saat ini, dan nama baru dari notifikasi, kemudian
     * menemukan semua indeks baris yang cocok di tabel yang relevan. Setelah itu,
     * ia memuat ulang baris dan kolom yang terpengaruh di `NSTableView` untuk mencerminkan perubahan.
     *
     * @param notification: payload - Objek ``NotifSiswaDiedit`` yang berisi data perubahan.
     *
     * @returns: void
     */
    func handleNamaSiswaDiedit(_ payload: NotifSiswaDiedit) {
        let kelasSekarang = payload.kelasSekarang
        let id = payload.updateStudentID
        let namaBaru = payload.namaSiswa

        TableType.fromString(kelasSekarang) { kelas in
            let index = viewModel.findAllIndices(for: kelas, matchingID: id, namaBaru: namaBaru)
            guard !index.isEmpty else {
                return
            }

            guard let table = tableViewManager.getTableView(for: kelas.rawValue) else { return }
            let columnIndex = table.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "namasiswa"))
            table.reloadData(forRowIndexes: IndexSet(index), columnIndexes: IndexSet([columnIndex]))
        }
    }
}
