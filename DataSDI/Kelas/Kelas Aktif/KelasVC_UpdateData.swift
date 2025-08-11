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
        // Memastikan pastedKelasID tidak kosong dan ada table yang terakhir dihapus.
        guard !pastedKelasID.isEmpty, let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else {
            print("Tidak ada data yang dapat di-undo paste.")
            return
        }

        // Ambil semua ID dari array kelasID terakhir
        let allIDs = pastedKelasID.removeLast()

        // Panggil ViewModel untuk menghapus data
        guard let result = viewModel.removeData(withIDs: allIDs, forTableType: tableType) else {
            return
        }

        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result

        guard !indexesToRemove.isEmpty else {
            ReusableFunc.showProgressWindow(5, pesan: "Data kelas tidak ada. Siswa sudah berpindah kelas atau tidak aktif di \(tableType.stringValue).")
            return
        }

        // Update NSTableView
        table.beginUpdates()
        for index in indexesToRemove {
            table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            if index == table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: table.numberOfRows - 1), byExtendingSelection: false)
                table.scrollRowToVisible(table.numberOfRows - 1)
            } else {
                table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                table.scrollRowToVisible(index)
            }
        }
        table.endUpdates()
        // Simpan data yang dihapus ke dalam SingletonData.pastedData
        SingletonData.pastedData.append((table: lastDeletedTable, data: dataDihapus))
        // Simpan ID kelas dan siswa yang dihapus ke dalam SingletonData.deletedKelasAndSiswaIDs
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)

        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.redoPaste(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs])
        selectSidebar(table)
    }

    func redoPaste(tableType: TableType, table: NSTableView) {
        // Memastikan sortDescriptor di KelasModels tersedia.
        guard let sortDescriptor = KelasModels.currentSortDescriptor else {
            return
        }
        // Pindah ke tabel yang akan diperbarui.
        activateTable(table)

        var indexesToAdd: [Int] = []
        var allIDs: [Int64] = []
        table.deselectAll(self)
        let pasteData = SingletonData.pastedData.removeLast()

        // Cek apakah data yang akan di-paste sudah ada untuk menghindari duplikasi
        for (_, deletedData) in pasteData.data.enumerated().reversed() {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
            indexesToAdd.append(insertionIndex)
            allIDs.append(deletedData.kelasID)
        }
        // Update tableView dengan indeks yang baru ditambahkan
        if !allIDs.isEmpty {
            pastedKelasID.append(allIDs)
            SingletonData.deletedKelasAndSiswaIDs.removeAll { kelasSiswaPairs in
                kelasSiswaPairs.contains { pair in
                    allIDs.contains(pair.kelasID)
                }
            }
        }

        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoPaste(table: table, tableType: tableType)
        }
        NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedData": pasteData.data])
        updateUndoRedo(self)
    }

    private func findAddDetailInKelas() -> (AddDetaildiKelas?, NSWindow?) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("AddDetaildiKelas"), bundle: nil)
        guard let addDataKelas = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas")) as? AddDetaildiKelas else { return (nil, nil) }
        let detailWindow = NSWindow(contentViewController: addDataKelas)
        detailWindow.setFrame(NSRect(x: 0, y: 0, width: 296, height: 420), display: true, animate: false)

        addDataKelas.onSimpanClick = { [weak self] dataArray, tambah, _, _ in
            self?.updateTable(dataArray, tambahData: tambah)
        }

        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            addDataKelas.appDelegate = false
            addDataKelas.tabKelas(index: selectedTabIndex)
        }

        return (addDataKelas, detailWindow)
    }

    /// Fungsi ini menangani penambahan data baru ke kelas.
    /// - Parameter sender: Objek pemicu yang dapat berupa apapun.
    @objc func addData(_: Any?) {
        if let window = NSApp.mainWindow?.windowController as? WindowController,
           let toolbar = window.datakelas, toolbar.isVisible, let button = window.tambahDetaildiKelas,
           let popover = AppDelegate.shared.popoverAddDataKelas,
           let addDataKelas = popover.contentViewController as? AddDetaildiKelas,
           let selectedTabViewItem = tabView.selectedTabViewItem
        {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)

            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            addDataKelas.appDelegate = true
            addDataKelas.tabKelas(index: selectedTabIndex)
        }

        else {
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                AppDelegate.shared.showInputNilai(selectedTabIndex)
            }
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
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
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
    func insertRow(forIndex index: Int, withData data: KelasModels) -> Int? {
        guard let sortDescriptor = getCurrentSortDescriptor(for: index) else {
            #if DEBUG
                print("Sort descriptor tidak ditemukan untuk indeks \(index)")
            #endif
            return nil
        }
        guard let tableType = TableType(rawValue: index) else {
            #if DEBUG
                print("Tipe tabel tidak ditemukan untuk indeks \(index)")
            #endif
            return nil
        }
        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else {
            #if DEBUG
                print("Gagal menyisipkan data untuk indeks \(index)")
            #endif
            return nil
        }
        // Mendapatkan tableView yang sesuai dengan indeks
        let tableView = getTableView(for: index)
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

        // Jumlah data yang akan diperbarui.
        let totalStudents = dataArray.count

        // Membuka progress window
        guard let (progressWindowController, progressViewController) = openProgressWindow(totalItems: totalStudents, controller: controller ?? "data kelas") else { return }
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
                id.insert(data.kelasID)
                switch index {
                case 0:
                    table = table1
                    updatedClass = .kelas1
                case 1:
                    table = table2
                    updatedClass = .kelas2
                case 2:
                    table = table3
                    updatedClass = .kelas3
                case 3:
                    table = table4
                    updatedClass = .kelas4
                case 4:
                    table = table5
                    updatedClass = .kelas5
                case 5:
                    table = table6
                    updatedClass = .kelas6
                default:
                    break
                }
                OperationQueue.main.addOperation { [unowned self] in
                    if controller != createLabelForActiveTable() {
                        // Jika controller tidak sesuai dengan label aktif, buat label baru
                        controller = createLabelForActiveTable()
                        progressViewController.controller = controller
                    }

                    // delegate untuk memperbarui seleksi tabel di ``SidebarViewController``.
                    self.delegate?.didUpdateTable(updatedClass ?? .kelas1)

                    self.delegate?.didCompleteUpdate()

                    // Memastikan nama siswa tidak kosong sebelum memasukkan baris.
                    insertRow(forIndex: index, withData: data)

                    processedStudentsCount += 1

                    // Update progress
                    if processedStudentsCount % updateFrequency == 0 || processedStudentsCount == totalStudents {
                        progressViewController.currentStudentIndex = processedStudentsCount
                    }
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedKelasIDs.append(data.kelasID)
            }
            OperationQueue.main.addOperation { [weak self] in
                guard let self, let table, let tipeTable = tableType(forTableView: table) else {
                    print("Tipe tabel tidak ditemukan untuk tableView.")
                    progressWindowController.close()
                    return
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedKelasID.append(pastedKelasIDs)
                // hapus kelasIDs yang sudah disimpan.
                pastedKelasIDs.removeAll()

                myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.undoPaste(table: table, tableType: tipeTable)
                }

                self.view.window?.makeFirstResponder(table)

                table.beginUpdates()

                // Memastikan bahwa ID yang baru ditambahkan ada di dalam model kelas untuk tabel yang sesuai.
                for ID in id {
                    let model = viewModel.kelasModelForTable(tableTypeForTable(table))
                    if let index = model.firstIndex(where: { $0.kelasID == ID }) {
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

    @objc func hapus(_: Any) {
        // Memastikan menu utama aplikasi, item menu "Edit", dan submenunya dapat diakses.
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           // Mencari item menu "hapus" berdasarkan identifier-nya.
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" })
        {
            // Memastikan objek `representedObject` dari item menu "hapus" dapat di-cast
            // ke dalam bentuk tuple yang diharapkan: (NSTableView, TableType, IndexSet).
            guard let representedObject = delete.representedObject as? (NSTableView, TableType, IndexSet) else {
                return // Jika gagal, hentikan eksekusi fungsi.
            }

            let (table, tableType, selectedIndexes) = representedObject

            // Memastikan ada indeks yang terpilih sebelum melanjutkan proses penghapusan.
            guard !selectedIndexes.isEmpty else {
                return // Jika tidak ada, hentikan eksekusi fungsi.
            }

            // Menginisialisasi Set untuk menyimpan nama siswa dan mata pelajaran unik dari baris yang terpilih.
            var uniqueSelectedStudentNames = Set<String>()
            var uniqueSelectedMapel = Set<String>()

            // Mengisi Set dengan nama siswa dan mata pelajaran dari model data
            // yang sesuai dengan indeks yang terpilih.
            for index in selectedIndexes {
                uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
                uniqueSelectedMapel.insert(viewModel.kelasModelForTable(tableType)[index].mapel)
            }

            // Menggabungkan nama siswa dan mata pelajaran unik menjadi string yang dipisahkan koma
            // untuk ditampilkan di dalam dialog konfirmasi.
            let selectedStudentNamesString = uniqueSelectedStudentNames.sorted().joined(separator: ", ")
            let selectedMapelString = uniqueSelectedMapel.sorted().joined(separator: ", ")

            // Membuat dan mengkonfigurasi objek NSAlert untuk meminta konfirmasi penghapusan dari pengguna.
            let alert = NSAlert()
            alert.messageText = "Apakah Anda yakin akan menghapus data ini dari〝\(selectedStudentNamesString)〞"
            alert.informativeText = "〝\(selectedMapelString)〞 akan dihapus dari \(selectedStudentNamesString)."
            alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
            alert.addButton(withTitle: "Hapus") // Tombol "Hapus"
            alert.addButton(withTitle: "Batalkan") // Tombol "Batalkan"

            // Memeriksa pengaturan UserDefaults untuk melihat apakah peringatan penghapusan harus disembunyikan.
            let userDefaults = UserDefaults.standard
            let suppressAlert = userDefaults.bool(forKey: "hapusKelasAktifAlert")
            alert.showsSuppressionButton = true // Menampilkan kotak centang "Jangan tampilkan lagi"

            // Jika peringatan disembunyikan (berdasarkan pengaturan pengguna),
            // lanjutkan langsung dengan fungsi penghapusan tanpa menampilkan dialog.
            guard !suppressAlert else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
                return
            }

            // Menjalankan dialog peringatan dan menangkap respons dari pengguna.
            let response = alert.runModal()

            // Jika pengguna menekan tombol "Hapus":
            if response == .alertFirstButtonReturn {
                // Jika kotak centang "Jangan tampilkan lagi" dicentang, perbarui UserDefaults.
                if alert.suppressionButton?.state == .on {
                    UserDefaults.standard.set(true, forKey: "hapusKelasAktifAlert")
                }
                // Memanggil fungsi `hapusPilih` untuk melakukan tindakan penghapusan sebenarnya.
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /// Fungsi ini menangani aksi hapus menu untuk menghapus data siswa dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType) else { return }

        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes

        var uniqueSelectedStudentNames = Set<String>()
        var uniqueSelectedMapel = Set<String>()

        // Mengisi Set dengan nama siswa dari indeks terpilih
        for index in selectedIndexes {
            uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
            uniqueSelectedMapel.insert(viewModel.kelasModelForTable(tableType)[index].mapel)
        }
        var siswaTerpilih = ""
        var mapelTerpilih = ""
        var namasiswa = ""
        var mapel = ""
        if selectedRow >= 0 {
            namasiswa = viewModel.kelasModelForTable(tableType)[selectedRow].namasiswa
            mapel = viewModel.kelasModelForTable(tableType)[selectedRow].mapel
        }
        siswaTerpilih.insert(contentsOf: namasiswa, at: siswaTerpilih.startIndex)
        mapelTerpilih.insert(contentsOf: mapel, at: mapelTerpilih.startIndex)
        // Menggabungkan Set menjadi satu string dengan koma
        let selectedStudentNamesString = uniqueSelectedStudentNames.sorted().joined(separator: ", ")
        let selectedMapelString = uniqueSelectedMapel.sorted().joined(separator: ", ")
        let alert = NSAlert()

        // Cek apakah baris yang diklik adalah bagian dari baris yang dipilih
        if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert.messageText = "Apakah anda yakin akan menghapus data dari〝\(selectedStudentNamesString)〞?"
            alert.informativeText = "〝\(selectedMapelString)〞 juga akan dihapus di informasi siswa \(selectedStudentNamesString)."
        } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert.messageText = "Apakah anda yakin akan menghapus data dari〝\(siswaTerpilih)〞?"
            alert.informativeText = "〝\(mapelTerpilih)〞 juga akan dihapus di informasi siswa \(siswaTerpilih)."
        } else {
            alert.messageText = "Apakah anda yakin akan menghapus data dari〝\(selectedStudentNamesString)〞?"
            alert.informativeText = "〝\(selectedMapelString)〞 akan dihapus di informasi siswa \(selectedStudentNamesString)."
        }
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let userDefaults = UserDefaults.standard
        let suppressAlert = userDefaults.bool(forKey: "hapusKelasAktifAlert")
        alert.showsSuppressionButton = true
        guard !suppressAlert else {
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
            return
        }
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "hapusKelasAktifAlert")
            }
            // Jika clickedRow ada di dalam selectedIndexes, panggil fungsi hapusPilih
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /// Fungsi ini menangani aksi hapus untuk menghapus data siswa yang diklik di tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    /// - clickedRow: Baris yang diklik di tabel.
    func hapusKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        deleteRedoArray(self)
        // Simpan data sebelum dihapus ke dalam deletedDataArray
        let deletedData = dataArray[clickedRow]
        SingletonData.deletedDataArray.append((table: currentClassTable, data: [deletedData]))
        SingletonData.deletedKelasAndSiswaIDs.append([(kelasID: deletedData.kelasID, siswaID: deletedData.siswaID)])
        table.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideDown)
        if clickedRow == table.numberOfRows {
            table.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            table.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        viewModel.removeData(index: clickedRow, tableType: tableType)

        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }
        updateUndoRedo(self)

        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": [deletedData.kelasID]])
    }

    /// Fungsi ini menangani aksi hapus untuk menghapus data siswa yang dipilih di tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    /// - selectedIndexes: Baris yang dipilih di tabel.
    func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)

        // Bersihkan array kelasID
        deleteRedoArray(self)

        // Tampung semua data yang akan dihapus ke dalam deletedDataArray di luar loop
        var selectedDataToDelete: [KelasModels] = []
        var deletedKelasIDs: [Int64] = [] // Tambahkan array untuk menyimpan kelasID yang dihapus
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []

        // Variabel untuk menyimpan indeks baris yang akan dipilih setelah penghapusan
        var rowToSelect: Int?

        for selectedRow in selectedIndexes.reversed() {
            let deletedData = dataArray[selectedRow]
            selectedDataToDelete.append(deletedData)
            deletedKelasIDs.append(deletedData.kelasID)
            deletedKelasAndSiswaIDs.append((kelasID: deletedData.kelasID, siswaID: deletedData.siswaID))
            // Hapus data dari model berdasarkan tableType
            viewModel.removeData(index: selectedRow, tableType: tableType)
        }

        // Setelah loop, tambahkan semua data yang akan dihapus ke dalam deletedDataArray
        SingletonData.deletedDataArray.append((table: currentClassTable, data: selectedDataToDelete))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Register undo action
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }
        updateUndoRedo(self)

        // Mulai dan akhiri update tabel untuk menghapus baris terpilih
        table.beginUpdates()
        table.removeRows(at: selectedIndexes, withAnimation: .slideUp)

        // Tentukan baris yang akan dipilih setelah penghapusan
        let totalRowsAfterDeletion = table.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            rowToSelect = min(totalRowsAfterDeletion - 1, selectedIndexes.first ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect!), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            table.deselectAll(nil)
        }
        table.endUpdates()
        // Post notifikasi untuk pembaruan tampilan
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": deletedKelasIDs])
    }

    /// Fungsi ini menghapus data yang telah dihapus sebelumnya dari undo stack dan redo stack.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    func undoHapus(tableType: TableType, table: NSTableView) {
        KelasModels.currentSortDescriptor = table.sortDescriptors.first
        guard let sortDescriptor = KelasModels.currentSortDescriptor,
              !SingletonData.deletedDataArray.isEmpty
        else {
            return
        }
        // Buat array baru untuk menyimpan semua id yang dihasilkan
        let semuaElemen: [KelasModels] = SingletonData.deletedDataArray.last?.data ?? []
        let deletedDatas = SingletonData.deletedDataArray.removeLast()
        SingletonData.dataArray.removeAll()
        operationQueue.maxConcurrentOperationCount = 1
        activateTable(table)
        if deletedDatas.data.count >= 100 {
            viewModel.restoreDeletedDataWithProgress(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                operationQueue: operationQueue,
                window: view.window!,
                onlyDataKelasAktif: false,
                kelasID: &kelasID
            )
        } else {
            viewModel.restoreDeletedDataDirectly(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                onlyDataKelasAktif: false,
                kelasID: &kelasID
            )
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
                    alert.informativeText = "Seluruh data \(self.createLabelForActiveTable()) dimuat ulang karena terdapat inkonsistensi data:\nSiswa tidak di Kelas Aktif \(self.createLabelForActiveTable())"
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
        guard !SingletonData.deletedKelasID.isEmpty,
              let lastDeletedTable = SingletonData.dbTable(forTableType: tableType)
        else {
            print("Tidak ada data yang bisa di-Redo untuk \(tableType.stringValue)")
            return
        }
        activateTable(table)
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = SingletonData.deletedKelasID.last!.kelasID
        SingletonData.deletedKelasID.removeLast()

        // Panggil ViewModel untuk menghapus data
        guard let result = viewModel.removeData(withIDs: allIDs, forTableType: tableType) else {
            return
        }

        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result
        table.beginUpdates()
        // Hapus baris-baris yang sesuai dari targetModel dan NSTableView
        for index in indexesToRemove {
            // Hapus baris dari NSTableView
            table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            if index == table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: table.numberOfRows - 1), byExtendingSelection: false)
                table.scrollRowToVisible(table.numberOfRows - 1)
            } else {
                table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                table.scrollRowToVisible(index)
            }
        }
        table.endUpdates()
        // Tambahkan data yang dihapus ke dalam deletedDataArray
        SingletonData.deletedDataArray.append((table: lastDeletedTable, data: dataDihapus))

        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Daftarkan undo untuk aksi redo yang dilakukan
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }
        if !kelasID.isEmpty {
            kelasID.removeLast()
        }
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs])
        // Perbarui tampilan setelah penghapusan berhasil dilakukan
        updateUndoRedo(self)
        selectSidebar(table)
    }

    /// Fungsi ini menghapus baris yang telah ditentukan ``handleSiswaDihapusNotification(_:)``
    /// dari model dan tabel.
    func deleteRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String, isDeleted: Bool, tahunAjaran _: String? = nil) {
        guard tableView.numberOfRows != 0 else { return }

        var indexesToDelete = IndexSet()

        // Simpan state model sebelum penghapusan untuk undo
        if SingletonData.undoStack[kelasSekarang] == nil {
            SingletonData.undoStack[kelasSekarang] = []
        }

        if isDeleted == true {
            // Simpan data yang akan dihapus ke dalam undo stack
            let itemsToUndo = model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels }
            SingletonData.undoStack[kelasSekarang]?.append(itemsToUndo)
        }

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
                viewModel.removeData(index: index, tableType: kelas)
            }
        }

        model.removeAll { item in
            // Cek apakah siswaID ada di deletedIDs
            deletedIDs.contains(item.siswaID)
        }

        // Hapus baris dari NSTableView
        OperationQueue.main.addOperation {
            tableView.beginUpdates()
            tableView.removeRows(at: indexesToDelete, withAnimation: [])
            tableView.endUpdates()
        }
        if var kelasUndoStack = SingletonData.undoStack[kelasSekarang] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[kelasSekarang] = kelasUndoStack
        }
    }

    /// Fungsi ini menangani ketika siswa ditambahkan kembali setelah dihapus.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Objek `Notification` pemicu aksi ini.
    @objc func handleUndoSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let kelasSekarang = userInfo["kelasSekarang"] as? String
        {
            TableType.fromString(kelasSekarang) { [weak self] kelas in
                guard let self, let tableView = getTableView(for: kelas.rawValue) else { return }
                let model = viewModel.kelasModelForTable(kelas)
                var modifiableModel: [KelasModels] = model
                if !(self.isDataLoaded[tableView] ?? false) {
                    guard let undoStack = SingletonData.undoStack[kelasSekarang], !undoStack.isEmpty else { return }
                    SingletonData.undoStack[kelasSekarang]?.removeLast()
                    viewModel.setModel(modifiableModel, for: kelas)
                } else {
                    self.undoDeleteRows(from: &modifiableModel, tableView: tableView, kelasSekarang: kelasSekarang)
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
        guard var undoStackForKelas = SingletonData.undoStack[kelasSekarang], !undoStackForKelas.isEmpty, let sortDescriptor = KelasModels.currentSortDescriptor else { return }
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        SingletonData.undoStack[kelasSekarang] = undoStackForKelas

        tableView.beginUpdates()
        for deletedData in previousState.sorted() {
            // let kelasID = deletedData.kelasID
            TableType.fromString(kelasSekarang) { kelas in
                // Panggil fungsi insert untuk setiap kelas
                guard let insertIndex = viewModel.insertData(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: [])
            }
        }
        tableView.endUpdates()
    }

    // MARK: - Notifikasi Siswa dari Daftar Siswa

    /// Fungsi ini menangani notifikasi ketika siswa dihapus dari kelas.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Notifikasi yang diterima.
    @objc func handleSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["deletedStudentIDs"] as? [Int64],
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let isDeleted = userInfo["isDeleted"] as? Bool
        {
            let tahunAjaran = userInfo["tahunAjaran"] as? String ?? nil
            var modifiableModel: [KelasModels] = []
            TableType.fromString(kelasSekarang) { kelas in
                modifiableModel = viewModel.kelasModelForTable(kelas)
                guard let table = getTableView(for: kelas.rawValue) else { return }
                deleteRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang, isDeleted: isDeleted, tahunAjaran: tahunAjaran)
                viewModel.setModel(modifiableModel, for: kelas)
            }
        }
    }

    // MARK: - EDIT DATA

    /// Fungsi ini menangani aksi naik kelas untuk siswa yang dipilih di tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func naikKelasMenu(_: NSMenuItem) {
        ReusableFunc.showAlert(title: "Kelas hanya dapat diubah dari Daftar Siswa.", message: "Ubah kelas dari daftar siswa. Anda akan diarahkan ke Daftar Siswa setelah konfirmasi.")
        delegate?.didUpdateTable(.siswa)
    }

    /// Fungsi ini menangani notifikasi ketika siswa naik kelas.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Notifikasi yang diterima.
    @objc func handleSiswaNaik(_ notification: Notification) {
        // Pastikan userInfo berisi siswaIDs dan tableType yang valid
        guard let userInfo = notification.userInfo,
              let siswaIDs = userInfo["siswaIDs"] as? [Int64],
              let notifTableType = userInfo["tableType"] as? TableType
        else {
            return
        }

        func removeSiswaFromData(table: NSTableView) {
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelasData[notifTableType]?.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                guard let matchingIndexes else { return }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
        }

        switch notifTableType {
        case .kelas1:
            table1.beginUpdates()
            removeSiswaFromData(table: table1)
            table1.endUpdates()
        case .kelas2:
            table2.beginUpdates()
            removeSiswaFromData(table: table2)
            table2.endUpdates()
        case .kelas3:
            table3.beginUpdates()
            removeSiswaFromData(table: table3)
            table3.endUpdates()
        case .kelas4:
            table4.beginUpdates()
            removeSiswaFromData(table: table4)
            table4.endUpdates()
        case .kelas5:
            table5.beginUpdates()
            removeSiswaFromData(table: table5)
            table5.endUpdates()
        case .kelas6:
            table6.beginUpdates()
            removeSiswaFromData(table: table6)
            table6.endUpdates()
        }
    }

    /// Fungsi ini menangani aksi undo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func undoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)).firstIndex(where: { $0.kelasID == originalModel.kelasId }),
              let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == originalModel.columnIdentifier.rawValue }),
              let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView,
              columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count else { return }

        // Lakukan pembaruan model dan database dengan nilai lama
        viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

        // Daftarkan aksi redo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoAction(originalModel: originalModel)
        })

        // Hapus nilai lama dari array undo
        undoArray.removeAll(where: { $0 == originalModel })

        // Mendapatkan nilai status dari originalModel
        let newString = originalModel.oldValue
        cellView.textField?.stringValue = newString
        if originalModel.columnIdentifier == .nilai {
            let numericValue = Int(newString) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }

        originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
        originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)

        // Simpan nilai lama ke dalam array redo
        redoArray.append(originalModel)
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": originalModel.tableType as Any, "editedKelasIDs": originalModel.kelasId, "siswaID": viewModel.kelasModelForTable(originalModel.tableType)[rowIndexToUpdate].siswaID, "columnIdentifier": originalModel.columnIdentifier, "dataBaru": newString])
    }

    /// Fungsi ini menangani aksi redo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func redoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)).firstIndex(where: { $0.kelasID == originalModel.kelasId }),
              let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == originalModel.columnIdentifier.rawValue }),
              let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView,
              columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count
        else {
            return
        }

        // Lakukan pembaruan model dan database dengan nilai baru
        viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.newValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        })

        // Hapus nilai lama dari array redo
        redoArray.removeAll(where: { $0 == originalModel })

        // Mendapatkan nilai status dari originalModel
        let newString = originalModel.newValue
        cellView.textField?.stringValue = newString
        if originalModel.columnIdentifier == .nilai {
            let numericValue = Int(newString) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }

        originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
        originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)

        // Simpan nilai baru ke dalam array undo
        undoArray.append(originalModel)
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": originalModel.tableType as Any, "editedKelasIDs": originalModel.kelasId, "siswaID": viewModel.kelasModelForTable(originalModel.tableType)[rowIndexToUpdate].siswaID, "columnIdentifier": originalModel.columnIdentifier, "dataBaru": newString])
    }

    /// Fungsi ini menangani pembaruan data siswa yang diedit di tabel kelas
    /// dari ``DetailSiswaController``.
    /// - Parameter notification:
    @objc func updateEditedDetilSiswa(_ notification: Notification) {
        var table: NSTableView!
        guard let userInfo = notification.userInfo as? [String: Any],
              let columnIdentifier = userInfo["columnIdentifier"] as? KelasColumn,
              let activeTable = userInfo["tableView"] as? String,
              let newValue = userInfo["newValue"] as? String,
              let kelasId = userInfo["kelasId"] as? Int64
        else {
            return
        }
        switch activeTable {
        case "table1": table = table1
        case "table2": table = table2
        case "table3": table = table3
        case "table4": table = table4
        case "table5": table = table5
        case "table6": table = table6
        default: break
        }
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(table)).firstIndex(where: { $0.kelasID == kelasId }) else { return }
        guard let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier.rawValue }) else { return }
        guard let cellView = table.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView else { return }
        // Lakukan pembaruan model dan database dengan nilai baru
        viewModel.updateKelasModel(tableType: tableTypeForTable(table), columnIdentifier: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, kelasId: kelasId)
        if columnIdentifier == .nilai {
            let numericValue = Int(newValue) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }
        cellView.textField?.stringValue = newValue
        table.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
    }

    /// Menangani notifikasi dari .findDeletedData
    /// untuk menghapus row di tabel.
    /// - Parameter notification: Objek `Notification` pemicu.
    @objc func updateDeletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let kelasId = userInfo["ID"] as? [Int64],
              let index = userInfo["index"] as? Int,
              let table = getTableView(for: index)
        else {
            return
        }
        table.beginUpdates()
        for id in kelasId {
            guard let kelasIDIndex = viewModel.deleteNotif(index, id: id) else { continue }
            table.removeRows(at: IndexSet(integer: kelasIDIndex), withAnimation: .slideUp)
        }
        table.endUpdates()
    }

    // MARK: - NOTIFICATION DATA

    /// Fungsi ini menangani notifikasi ketika data siswa ditambahkan dari ``DetailSiswaController``.
    /// Baik itu dari undo ataupun redo.
    /// - Parameter notification: Objek `Notification` yang memicu.
    @objc func updateRedoInDetilSiswa(_ notification: Notification) {
        // Memastikan tableView yang aktif.
        guard let table = activeTable() else { return }
        // Memastikan bahwa notifikasi memiliki userInfo yang berisi data yang diperlukan.
        if let userInfo = notification.userInfo {
            if let dataArray = userInfo["data"] as? [(index: Int, data: KelasModels)] {
                table.beginUpdates()
                for data in dataArray {
                    // Memastikan bahwa nama siswa tidak kosong sebelum memasukkan baris.
                    guard !data.data.namasiswa.isEmpty else {
                        continue
                    }
                    let index = data.index
                    let data = data.data
                    // Memastikan bahwa data yang akan dimasukkan tidak duplikat.
                    insertRow(forIndex: index, withData: data)
                }
                table.endUpdates()
            }
        }
    }

    /**
     * @function updateNamaGuruNotification
     * @abstract Menangani notifikasi pembaruan nama guru, mengelola sinkronisasi antara UI dan database secara asinkron.
     * @discussion Fungsi ini dipicu oleh sebuah notifikasi yang berisi data pembaruan nama guru.
     * Ia melakukan validasi data, membaca informasi UI di main thread,
     * memproses pembaruan data dan interaksi database di background thread
     * untuk menjaga responsivitas UI, dan kemudian memperbarui UI kembali di main thread.
     * Fungsionalitas undo juga didukung dengan menyimpan data asli sebelum perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi informasi pembaruan.
     * Diharapkan `userInfo` dari notifikasi ini mengandung kunci `"mapelData"`
     * dengan nilai `[[String: Any]]` yang merinci pembaruan nama guru.
     *
     * @returns: void
     */
    @objc func updateNamaGuruNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let namaGuru = userInfo["namaGuru"] as? String,
              let idGuru = userInfo["idGuru"] as? Int64
        else { return }
        // Loop melalui semua tabel yang Anda miliki di `tableInfo`
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            for info in tableInfo {
                let type = info.type // TableType terkait

                // Dapatkan model data untuk tabel tipe ini
                let model = viewModel.kelasModelForTable(type)

                for (row, data) in model.enumerated() {
                    // Periksa apakah guruID di data cocok dengan idGuru yang diterima
                    if data.guruID == idGuru {
                        // Update model data
                        viewModel.updateKelasModel(tableType: type, columnIdentifier: .guru, rowIndex: row, newValue: namaGuru, kelasId: data.kelasID)
                        needsReloadForTableType[type] = true
                        pendingReloadRows[type, default: []].insert(idGuru)
                    }
                }
                
                for (_, data) in SingletonData.deletedDataArray {
                    for siswa in data where siswa.guruID == idGuru {
                        siswa.namaguru = namaGuru
                    }
                }
                
                guard let siswaNaikArray = KelasViewModel.siswaNaikArray[type] else { continue }
                for data in siswaNaikArray where data.guruID == idGuru {
                    data.namaguru = namaGuru
                }
            }
        }
    }

    /**
     * Menangani notifikasi ketika nama siswa telah diedit, memperbarui UI untuk baris yang relevan.
     * @discussion Fungsi ini dipicu oleh notifikasi yang berisi informasi tentang perubahan nama siswa.
     * Ini mengambil ID siswa, kelas saat ini, dan nama baru dari notifikasi, kemudian
     * menemukan semua indeks baris yang cocok di tabel yang relevan. Setelah itu,
     * ia memuat ulang baris dan kolom yang terpengaruh di `NSTableView` untuk mencerminkan perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi data perubahan.
     * Diharapkan `userInfo` berisi:
     * - `"updateStudentIDs"`: `Int64` (ID siswa yang diperbarui).
     * - `"kelasSekarang"`: `String` (nama kelas tempat siswa berada).
     * - `"namaSiswa"`: `String` (nama siswa yang baru).
     *
     * @returns: void
     */
    @objc func handleNamaSiswaDiedit(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["updateStudentIDs"] as? Int64,
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let namaBaru = userInfo["namaSiswa"] as? String
        {
            TableType.fromString(kelasSekarang) { kelas in
                let index = viewModel.findAllIndices(for: kelas, matchingID: deletedIDs, namaBaru: namaBaru)
                guard !index.isEmpty else {
                    return
                }

                guard let table = getTableView(for: kelas.rawValue) else { return }
                let columnIndex = table.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "namasiswa"))
                table.reloadData(forRowIndexes: IndexSet(index), columnIndexes: IndexSet([columnIndex]))
            }
        }
    }
}
