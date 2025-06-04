//
//  DetailSiswa.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 25/10/23.
//

import Cocoa
import SQLite
import PDFKit.PDFView
import PDFKit.PDFDocument

class DetailSiswaController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTabViewDelegate, WindowWillCloseDetailSiswa {
    @IBOutlet weak var shareMenu: NSMenu!
    @IBOutlet weak var printButton: NSButton!
    @IBOutlet weak var statistik: NSButton!
    @IBOutlet weak var namaSiswa: NSTextField!
    @IBOutlet weak var smstr: NSPopUpButton!
    weak var topLevelObjects: NSArray? = nil
    weak var tabView: NSTabView!
    weak var table1: EditableTableView!
    weak var table2: EditableTableView!
    weak var table3: EditableTableView!
    weak var table4: EditableTableView!
    weak var table5: EditableTableView!
    weak var table6: EditableTableView!
    @IBOutlet weak var labelCount: NSTextField!
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    @IBOutlet weak var labelAverage: NSTextField!
    @IBOutlet weak var imageView: NSButton!
    @IBOutlet weak var kelasSC: NSSegmentedControl!
    @IBOutlet weak var opsiSiswa: NSPopUpButton!
    @IBOutlet weak var tmblTambah: NSButton!
    let alert = NSAlert()
    let viewModel = KelasViewModel()
    lazy var isDataLoaded: [NSTableView: Bool] = [:]
    var siswa: ModelSiswa?
    lazy var siswaData: [ModelSiswa] = []
    let dbController = DatabaseController.shared
    var selectedSiswa: ModelSiswa?
    var tableInfo: [(table: NSTableView, type: TableType)] = []
    var activeTableType: TableType = .kelas1
    var headerMenu = NSMenu()
    let bgTask = AppDelegate.shared.operationQueue
    var editorManager: OverlayEditorManager!
    
    // AutoComplete Teks
    private var suggestionManager: SuggestionManager!
    
    @IBOutlet weak var nilaiKelasAktif: NSButton!
    @IBOutlet weak var bukanNilaiKelasAktif: NSButton!
    @IBOutlet weak var semuaNilai: NSButton!
    var tableData: [KelasModels] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabView.delegate = self
        visualEffect.blendingMode = .withinWindow
        tableInfo = [
        (table1, .kelas1),
        (table2, .kelas2),
        (table3, .kelas3),
        (table4, .kelas4),
        (table5, .kelas5),
        (table6, .kelas6),
        ]
        let tableNames = ["table1DetailSiswa", "table2DS", "table3DS", "table4DS", "table5DS", "table6DS"]
        for (index, (table, _)) in tableInfo.enumerated() {
            table.target = self
            table.delegate = self
            table.selectionHighlightStyle = .regular
            table.allowsMultipleSelection = true
            table.dataSource = self
            table.autosaveName = tableNames[index]
            table.autosaveTableColumns = true

            let menu = createContextMenu(tableView: table)
            table.menu = menu
            menu?.delegate = self

            for columnInfo in ReusableFunc.columnInfos {
                guard let column = table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else { continue }
                let customHeaderCell = MyHeaderCell()
                customHeaderCell.title = columnInfo.customTitle
                column.headerCell = customHeaderCell
            }

            table.doubleAction = #selector(tableViewDoubleClick(_:))
            table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        }
        shareMenu.delegate = self
    }
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }
        
        // Kolom mapel tidak dapat disembunyikan
        if column.identifier.rawValue == "mapel" { return }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden
        
        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        if let siswa = siswa {
            viewModel.loadSiswaData(siswaID: siswa.id)
            namaSiswa.stringValue = siswa.nama
            view.window?.title = "\(siswa.nama)"
            
            let kelasSekarang = siswa.kelasSekarang
            if kelasSekarang.lowercased() == "lulus" {
                kelasSC.setLabel("Kelas 6", forSegment: 5)
                kelasSC.setSelected(true, forSegment: 5)
                tabView.selectTabViewItem(at: 5)
            } else if let kelasIndex = Int(kelasSekarang.replacingOccurrences(of: "Kelas ", with: "")) { // Mendapatkan indeks kelasSekarang dari string (misal: "Kelas 1" menjadi 0)
                
                // Menambahkan label "Kelas" sebelum angka pada segmentedControl
                let label = String("Kelas \(kelasIndex)")
                kelasSC.setLabel(label, forSegment: kelasIndex - 1)
                // Mengatur selected segment pada segmentedControl
                kelasSC.setSelected(true, forSegment: kelasIndex - 1)
                // Mengatur tabView sesuai dengan indeks kelas
                tabView.selectTabViewItem(at: kelasIndex - 1)
            } else {
                kelasSC.setLabel("Kelas 1", forSegment: 0)
                kelasSC.setSelected(true, forSegment: 0)
                tabView.selectTabViewItem(at: 0)
            }
        }
        
        for segmentIndex in 0..<kelasSC.segmentCount {
            if segmentIndex != kelasSC.selectedSegment {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
        semuaNilai.state = .on
    }
    @IBAction private func ubahFilterNilai(_ sender: NSButton) {
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }

        let selectedTabViewItem = tabView.selectedTabViewItem!
        // Menentukan model kelas berdasarkan tab yang aktif
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        populateSemesterPopUpButton()
        updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: smstr.titleOfSelectedItem ?? "")
    }
    
    override func keyDown(with event: NSEvent) {
        // keyCode 36 adalah tombol Enter/Return
        if event.keyCode == 36, let tableView = activeTable() {
            let selectedIndexes = tableView.selectedRowIndexes
            if let lastSelectedRow = selectedIndexes.last {
                let columnToEdit = 0 // kolom pertama
                tableView.editColumn(columnToEdit, row: lastSelectedRow, with: event, select: true)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        siswaData = [dbController.getSiswa(idValue: siswa?.id ?? 0)]
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        activateSelectedTable()
        guard let table = activeTable() else {
            setupSortDescriptor()
            return
        }
        if !(isDataLoaded[table] ?? false) {
            // Load data for the table view
            loadTableData(tableView: table)
        }
        setupSortDescriptor()
        if !(isDataLoaded[table] ?? false) {
            table.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            populateSemesterPopUpButton()
            updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabViewItem), semesterName: smstr.titleOfSelectedItem ?? "Semester 1")
            updateMenuItem(self)
        }
        
        suggestionManager = SuggestionManager(suggestions: [""])
        //opsiSiswa.menu?.delegate = self
        smstr.menu?.delegate = self
        alert.addButton(withTitle: "OK")
        NotificationCenter.default.addObserver(self, selector: #selector(handleSiswaDihapusNotification(_:)), name: .siswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoSiswaDihapusNotification(_:)), name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKelasDihapusNotification(_:)), name: .kelasDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoKelasDihapusNotification(_:)), name: .undoKelasDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoUpdate(_:)), name: .updateUndoArray, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateEditedKelas(_:)), name: .editDataSiswaKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatedGuruKelas(_:)), name: .editNamaGuruKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedSaveDataNotification(_:)), name: .saveData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNamaSiswaDiedit(_:)), name: .dataSiswaDiEditDiSiswaView, object: nil)
    }
    @objc func saveDataWillTerminate(_ sender: Any) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            NSApp.reply(toApplicationShouldTerminate: true)
            return}
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan di rincian siswa belum disimpan. Simpan sekarang?"
        alert.informativeText = "Aplikasi segera ditutup. Perubahan terbaru akan disimpan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Tutup Aplikasi")
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [weak self] (response) in
                guard let self = self else { return }
                if response == .alertFirstButtonReturn {
                    window.endSheet(window, returnCode: .OK)
                    
                    let storyboard = NSStoryboard.init(name: "ProgressBar", bundle: nil)
                    guard let windowProgress = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let viewController = windowProgress.contentViewController as? ProgressBarVC else {return}
                    window.beginSheet(windowProgress.window!)
                    DispatchQueue.main.async {
                        viewController.progressIndicator.isIndeterminate = true
                        viewController.progressIndicator.startAnimation(self)
                    }
                    self.bgTask.addOperation { [unowned self] in
                        for deletedData in self.deletedDataArray {
                            let currentClassTable = deletedData.table
                            let dataArray = deletedData.data
                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                        // Loop melalui pastedData
                        for pastedDataItem in self.pastedData {
                            let currentClassTable = pastedDataItem.table
                            let dataArray = pastedDataItem.data
                            
                            for data in dataArray.sorted(by: { $0.kelasID < $1.kelasID }) {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                    }
                    OperationQueue.main.addOperation { [unowned self] in
                        self.saveData(self)
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] timer in
                            window.endSheet(windowProgress.window!)
                            self?.dataButuhDisimpan = false
                            NotificationCenter.default.post(name: .dataSaved, object: nil)
                            timer.invalidate()
                        })
                    }
                } else if response == .alertSecondButtonReturn {
                    window.endSheet(window, returnCode: .cancel)
                    NSApp.reply(toApplicationShouldTerminate: false)
                } else if response == .alertThirdButtonReturn {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
        }
    }
    @objc private func saveData(_ sender: Any) {
        undoArray.removeAll()
        deletedDataArray.removeAll()
        pastedKelasID.removeAll()
        pastedData.removeAll()
        deleteRedoArray(self)
        undoManager?.removeAllActions(withTarget: self)
        updateUndoRedo(self)
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self, name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidReloadNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        deleteRedoArray(self)
        tabView.delegate = nil
        viewModel.removeAllData()
        for (table, _) in tableInfo {
            table.target = nil
            // table.doubleAction = #selector(editDataClicked)
            table.delegate = nil
            table.menu = nil // Hapus menu yang ditambahkan sebelumnya
            table.dataSource = nil
        }
        NotificationCenter.default.removeObserver(self, name: .saveData, object: nil)
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        if Bundle.main.loadNibNamed("TabContentView", owner: nil, topLevelObjects: &topLevelObjects) {
            guard let tabView = topLevelObjects?.first(where: { $0 is NSTabView }) as? NSTabView else {
                fatalError("Tidak menemukan NSTabView")
            }

            // Atur tabView ke dalam view
            view.addSubview(tabView, positioned: .below, relativeTo: nil)
            tabView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tabView.topAnchor.constraint(equalTo: self.view.topAnchor),
                tabView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                tabView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                tabView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
            ])
            self.tabView = tabView
            // print("tabView Dikonfigurasi")

            // Pastikan ada 6 tab
            guard tabView.numberOfTabViewItems >= 6 else {
                fatalError("Tidak ada 6 tab di TabContentView.xib")
            }
            
            let tables = (0..<6).map { ReusableFunc.getTableView(from: tabView.tabViewItem(at: $0)) }

            for table in tables {
                if let scrollView = table.enclosingScrollView {
                    scrollView.removeConstraints(scrollView.constraints)
                    scrollView.contentInsets.top = 129

                    if let kolomNama = table.tableColumns.first(where: { $0.identifier.rawValue == "namasiswa" }) {
                        table.removeTableColumn(kolomNama)
                    }
                }
            }

            // Ambil masing-masing table dari tab item
            (table1, table2, table3, table4, table5, table6) = (tables[0], tables[1], tables[2], tables[3], tables[4], tables[5])
            
            
            // print("table dikonfigurasi")
        } else {
            fatalError("tidak dapat load TabContentView.xib")
        }
        
        // NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: .hapusDataKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDataNotification(_:)), name: .updateDataKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: DatabaseController.dataDidReloadNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTable(_:)), name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(addDetilPopUpDidClose(_:)), name: .addDetilSiswaUITertutup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSemesterTeks), name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateInsertedKelasId(_:)), name: .findInsertedKelasIdFromKelas, object: nil)
    }
    @objc func updateDataNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let editedKelasID = userInfo["editedKelasIDs"] as? Int64,
           let editedSiswaID = userInfo["siswaID"] as? Int64,
           let columnIdentifier = userInfo["columnIdentifier"] as? String,
           let dataBaru = userInfo["dataBaru"] as? String
        else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            // Pilih model berdasarkan tableType dan lakukan operasi yang sesuai
            let modifiableModel = self.viewModel.kelasModelForTable(tableType)
            guard modifiableModel.contains(where: {$0.siswaID == editedSiswaID}),
                  let indexOfKelasID = modifiableModel.firstIndex(where: {$0.kelasID == editedKelasID}),
                  let table = self.getTableView(for: tableType.rawValue)
            else { return }
            self.viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: indexOfKelasID, newValue: dataBaru, modelArray: modifiableModel, tableView: table, kelasId: editedKelasID)
            
            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: IndexSet([indexOfKelasID]), columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
                self.updateSemesterTeks()
            }
        }
        
    }
    private func activateSelectedTable() {
        if let selectedTable = activeTable() {
            view.window?.makeFirstResponder(selectedTable)
        }
    }
    @IBOutlet weak var tmblSimpan: NSButton!
    @objc func addDetilPopUpDidClose(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateUndoRedo(notification)
            self.tmblTambah.state = .off
        }
    }
    @IBAction func saveButton(_ sender: Any) {
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }
        
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "checkmark.icloud.fill", accessibilityDescription: .none)
            alert.messageText = "Data saat ini adalah yang terbaru"
            alert.informativeText = "Tidak ada data yang baru-baru ini diubah di database atau perubahan data telah disimpan ke database."
            alert.addButton(withTitle: "OK")
            if let window = NSApplication.shared.mainWindow {
                // Menampilkan alert sebagai sheet dari jendela utama
                alert.beginSheetModal(for: window) { (response) in
                    if response == .alertFirstButtonReturn {
                        window.endSheet(window, returnCode: .stop)
                    }
                }
            }
            return
        }
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan akan disimpan. Lanjutkan?"
        alert.informativeText = "Data yang telah dihapus/diedit tidak dapat diurungkan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [self] (response) in
                if response == .alertFirstButtonReturn {
                    self.performDatabaseOperations {
                        return
                    }
                } else {
                    self.dataButuhDisimpan = true
                    return
                }
            }
        }
    }
    var pastedKelasIDs: [Int64] = []
    var pastedKelasID: [[Int64]] = []
    var pastedData: [(table: Table, data: [KelasModels])] = []
    
    func pilihKelas(_ tableType: TableType) {
        switch tableType {
        case .kelas1:
            kelasSC.selectSegment(withTag: 0)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 1", forSegment: 0)
        case .kelas2:
            kelasSC.selectSegment(withTag: 1)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 2", forSegment: 1)
        case .kelas3:
            kelasSC.selectSegment(withTag: 2)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 3", forSegment: 2)
        case .kelas4:
            kelasSC.selectSegment(withTag: 3)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 4", forSegment: 3)
        case .kelas5:
            kelasSC.selectSegment(withTag: 4)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 5", forSegment: 4)
        case .kelas6:
            kelasSC.selectSegment(withTag: 5)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 6", forSegment: 5)
        }
    }
    
    private func undoPaste(table: NSTableView, tableType: TableType) {
        guard !pastedKelasID.isEmpty, let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        pilihKelas(tableType)
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = pastedKelasID.removeLast()
        // Tentukan model target berdasarkan tableType
        switch tableType {
        case .kelas1:
            targetModel = viewModel.kelas1Model
        case .kelas2:
            targetModel = viewModel.kelas2Model
        case .kelas3:
            targetModel = viewModel.kelas3Model
        case .kelas4:
            targetModel = viewModel.kelas4Model
        case .kelas5:
            targetModel = viewModel.kelas5Model
        case .kelas6:
            targetModel = viewModel.kelas6Model
        }
        
        // Simpan data yang dihapus untuk kemudian di-undo
        var dataDihapus: [KelasModels] = []
        // Simpan indeks yang akan dihapus dari targetModel
        var indexesToRemove: [Int] = []
        table.beginUpdates()
        // Iterasi melalui model data untuk mencari kelasID yang sesuai
        for (index, model) in targetModel.enumerated().reversed() {
            if allIDs.contains(model.kelasID) {
                // Buat instance baru dari KelasModels dengan menggunakan properti dari data yang dihapus
                let deletedData = KelasModels(
                    kelasID: model.kelasID,
                    siswaID: model.siswaID,
                    namasiswa: model.namasiswa,
                    mapel: model.mapel,
                    nilai: model.nilai,
                    namaguru: model.namaguru,
                    semester: model.semester,
                    tanggal: model.tanggal
                )
                
                // Tambahkan data yang dihapus ke dalam array dataDihapus
                dataDihapus.append(deletedData)
                viewModel.removeData(index: index, tableType: tableType)
                // Tambahkan indeks ke dalam array indexesToRemove
                indexesToRemove.append(index)
            }
        }
        
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
        pastedData.append((table: lastDeletedTable, data: dataDihapus))
        
        if let maxIndex = indexesToRemove.max() {
            if maxIndex == table.numberOfRows {
                table.scrollRowToVisible(maxIndex - 1)
            } else {
                table.scrollRowToVisible(maxIndex)
            }
            for segmentIndex in 0..<kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
        }
        undoManager?.beginUndoGrouping()
        // Daftarkan undo untuk aksi redo yang dilakukan
        undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.redoPaste(tableType: tableType, table: table)
        }
        undoManager?.endUndoGrouping()
        // Perbarui tampilan setelah penghapusan berhasil dilakukan
        
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        updateUndoRedo(self)
        updateSemesterTeks()
    }
    private func redoPaste(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = KelasModels.siswaSortDescriptor else {
            return
        }
        pilihKelas(tableType)
        
        // Buat array baru untuk menyimpan semua id yang dihasilkan
        var allIDs: [Int64] = []
        var indexesToAdd: [Int] = []
        var dataArray: [(index: Int, data: KelasModels)] = []
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        let pasteData = pastedData.removeLast()
        table.deselectAll(self)
        for deletedData in pasteData.data {
            let id = deletedData.kelasID
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else {return}
            indexesToAdd.append(insertionIndex)
            dataArray.append((index: selectedIndex, data: deletedData))
            allIDs.append(id)
        }
        table.beginUpdates()
        for index in indexesToAdd {
            table.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: true)
        }
        table.endUpdates()
        if let maxIndex = indexesToAdd.max() {
            table.scrollRowToVisible(maxIndex)
            for segmentIndex in 0..<kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
        }
        // Tambahkan semua id yang dihasilkan ke dalam kelasID
        pastedKelasID.append(allIDs)
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": dataArray])
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoPaste(table: table, tableType: tableType)
        }
        undoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
    }
    @objc private func updateTable(_ notification: Notification) {
        var table: NSTableView?
        var dataArray: [(index: Int, data: KelasModels)] = []
        // Panggil insertRow atau fungsi terkait di sini
        if let userInfo = notification.userInfo {
            if let index = userInfo["index"] as? Int, let data = userInfo["data"] as? KelasModels {
                #if DEBUG
                print("index:", index, "data", data.mapel)
                #endif
                dataArray.append((index: index, data: data))
                guard data.siswaID == siswa?.id else {return}
                insertRow(forIndex: index, withData: data)
                switch index {
                case 0:
                    table = table1
                    activateSelectedTable()
                    if isDataLoaded[table1] == nil || !(isDataLoaded[table1] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table1)
                        isDataLoaded[table1] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 0)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 1", forSegment: 0)
                case 1:
                    kelasSC.selectSegment(withTag: 1)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 2", forSegment: 1)
                    table = table2
                    if isDataLoaded[table2] == nil || !(isDataLoaded[table2] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table2)
                        isDataLoaded[table2] = true
                    }
                    setupSortDescriptor()
                case 2:
                    if isDataLoaded[table3] == nil || !(isDataLoaded[table3] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table3)
                        isDataLoaded[table3] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 2)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 3", forSegment: 2)
                    table = table3
                case 3:
                    if isDataLoaded[table4] == nil || !(isDataLoaded[table4] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table4)
                        isDataLoaded[table4] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 3)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 4", forSegment: 3)
                    table = table4
                case 4:
                    if isDataLoaded[table2] == nil || !(isDataLoaded[table2] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table2)
                        isDataLoaded[table2] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 4)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 5", forSegment: 4)
                    table = table5
                case 5:
                    if isDataLoaded[table6] == nil || !(isDataLoaded[table6] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table6)
                        isDataLoaded[table6] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 5)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 6", forSegment: 5)
                    table = table6
                default:
                    break
                }
                if isPasteing == false {
                    pastedKelasIDs.append(data.kelasID)
                }
            }
        }
        guard let activeTable = table else {return}
        let tableType = tableTypeForTable(activeTable)
        deleteRedoArray(notification)
        if isPasteing == false {
            undoManager?.beginUndoGrouping()
            undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
                self?.undoPaste(table: activeTable, tableType: tableType)
            }
            undoManager?.endUndoGrouping()
            pastedKelasID.append(pastedKelasIDs)
            pastedKelasIDs.removeAll()
            for segmentIndex in 0..<kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
            updateUndoRedo(self)
            updateSemesterTeks()
        }
        let notif = notification.userInfo
        guard notif?["kelasAktif"] as? Bool == true else {return}
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": index, "data": dataArray])
    }
    private func getTableView(for index: Int) -> NSTableView? {
        switch index {
        case 0: return table1
        case 1: return table2
        case 2: return table3
        case 3: return table4
        case 4: return table5
        case 5: return table6
        default: return nil
        }
    }
    private func getCurrentSortDescriptor(for index: Int) -> NSSortDescriptor? {
        let tableView = getTableView(for: index)
        KelasModels.siswaSortDescriptor = tableView?.sortDescriptors.first
        return KelasModels.siswaSortDescriptor
    }
    private func insertRow(forIndex index: Int, withData data: KelasModels) {
        // Determine the NSTableView based on index
        guard let sortDescriptor = getCurrentSortDescriptor(for: index) else {
            
            return
        }
        guard let tableType = TableType(rawValue: index) else {
            
            return
        }
        
        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else {return}
        let tableView = getTableView(for: index)
        // Insert the new row in the NSTableView
        tableView?.insertRows(at: IndexSet(integer: rowInsertion), withAnimation: .slideUp)
        tableView?.selectRowIndexes(IndexSet(integer: rowInsertion), byExtendingSelection: true)
        tableView?.scrollRowToVisible(rowInsertion)
    }
//    private func insertRow(forIndex index: Int, withData data: KelasModels) {
//        // Determine the NSTableView based on index
//        var tableView: NSTableView?
//
//        // Update array model yang sesuai dengan indeks
//        switch index {
//        case 0:
//            if !viewModel.kelas1Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas1Model.insert(data as! viewModel.kelas1Model, at: 0)
//                tableView = table1
//            }
//        case 1:
//            if !viewModel.kelas2Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas2Model.insert(data as! viewModel.kelas2Model, at: 0)
//                tableView = table2
//            }
//        case 2:
//            if !viewModel.kelas3Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas3Model.insert(data as! viewModel.kelas3Model, at: 0)
//                tableView = table3
//            }
//        case 3:
//            if !viewModel.kelas4Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas4Model.insert(data as! viewModel.kelas4Model, at: 0)
//                tableView = table4
//            }
//        case 4:
//            if !viewModel.kelas5Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas5Model.insert(data as! viewModel.kelas5Model, at: 0)
//                tableView = table5
//            }
//        case 5:
//            if !viewModel.kelas6Model.contains(where: { $0.kelasID == data.kelasID }) {
//                viewModel.kelas6Model.insert(data as! viewModel.kelas6Model, at: 0)
//                tableView = table6
//            }
//        default:
//            break
//        }
//
//        // Insert the new row in the NSTableView
//        tableView?.insertRows(at: IndexSet(integer: 0), withAnimation: .slideUp)
//        tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: true)
//    }
    private func loadTableData(tableView: NSTableView) {
        guard let activeTable = activeTable() else {return}
        setupSortDescriptor()
        self.setActiveTable(activeTable)
        activeTable.sortDescriptors.removeAll()
        let sortDescriptor = viewModel.getSortDescriptorDetil(forTableIdentifier: createStringForActiveTable())
        applySortDescriptor(tableView: activeTable, sortDescriptor: sortDescriptor)
        updateSemesterTeks()
        KelasModels.siswaSortDescriptor = activeTable.sortDescriptors.first
        viewModel.loadSiswaData(forTableType: tableTypeForTable(activeTable), siswaID: siswa?.id ?? 0)
        ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: ["mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
        activeTable.reloadData()
        guard let containingWindow = self.view.window else {
            // Ini seharusnya tidak terjadi jika ViewController ditampilkan dengan benar
            fatalError("MyCoolTableViewController's view is not in a window.")
        }
        editorManager = OverlayEditorManager(tableView: activeTable, containingWindow: containingWindow)
        
        editorManager.delegate = self // Untuk metode standar NSTableViewDelegate
        editorManager.dataSource = self // Untuk metode standar NSTableViewDataSource
        
        activeTable.editAction = { [weak self] (row, column) in
            self?.editorManager.startEditing(row: row, column: column)
        }
    }
    @objc func tableViewDoubleClick(_ sender: Any) {
        guard let table = activeTable(), table.selectedRow >= 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
            // Mendapatkan cell view dari table view untuk baris yang ditentukan
            if let cellView = table.view(atColumn: 0, row: table.selectedRow, makeIfNecessary: false) as? NSTableCellView {
                // Mencari NSTextField dalam cell view
                if let textField = cellView.textField {
                    // Mengatur fokus dan memulai pengeditan
                    textField.becomeFirstResponder()
                    textField.selectText(self)
                }
            }
        }
    }
    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            let resizedColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            let rowCount = tableView.numberOfRows
            let siswaList = viewModel.kelasModelForTable(tableTypeForTable(tableView))
            
            guard siswaList.count == rowCount else {
                
                return
            }
            for row in 0..<rowCount {
                let siswa = siswaList[row]
                if let cellView = tableView.view(atColumn: resizedColumn, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let textField = cellView.textField
                    let tanggalString = siswa.tanggal
                    guard !tanggalString.isEmpty else {continue}
                    let dateFormatter = DateFormatter()
                    // Tentukan format tanggal berdasarkan lebar kolom
                    if let textWidth = textField?.cell?.cellSize(forBounds: textField!.bounds).width, textWidth < textField!.bounds.width {
                        let availableWidth = textField?.bounds.width
                        if availableWidth! <= 80 {
                            // Teks dipotong, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d/M/yy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else if availableWidth! <= 120 {
                            // Lebar tersedia kurang dari atau sama dengan 80, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d MMM yyyy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else {
                            // Teks tidak dipotong dan lebar tersedia lebih dari 80, gunakan format tanggal lengkap
                            dateFormatter.dateFormat = "dd MMMM yyyy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        }
                    }
                    // Convert string date to Date object
                    if let date = dateFormatter.date(from: tanggalString) {
                        // Update text field dengan format tanggal yang baru
                        textField?.stringValue = dateFormatter.string(from: date)
                    }
                }
            }
        } else {
            
        }
    }
    func tableViewColumnDidMove(_ notification: Notification) {
        guard let table = activeTable() else {return}
        let tableColumns = table.tableColumns
        ReusableFunc.updateColumnMenu(table, tableColumns: tableColumns, exceptions: ["mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return tableView.rowHeight
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let tableType = tableTypeForTable(tableView)
        return viewModel.numberOfRows(forTableType: tableType)
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableType = tableTypeForTable(tableView)
        guard let kelasModel = viewModel.modelForRow(at: row, tableType: tableType) else {return nil}
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                switch tableColumn?.identifier {
                case NSUserInterfaceItemIdentifier("mapel"):
                    textField.stringValue = kelasModel.mapel
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 350
                case NSUserInterfaceItemIdentifier("nilai"):
                    let nilai = kelasModel.nilai
                    textField.stringValue = nilai == 00 ? "" : String(nilai)
                    textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.controlTextColor
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 40
                case NSUserInterfaceItemIdentifier("semester"):
                    textField.stringValue = kelasModel.semester
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 150
                case NSUserInterfaceItemIdentifier("namaguru"):
                    textField.stringValue = kelasModel.namaguru
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
                case NSUserInterfaceItemIdentifier("tgl"):
                    textField.alphaValue = 0.6
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd MMMM yyyy"
                    let availableWidth = tableColumn?.width ?? 0
                    if availableWidth <= 80 {
                        dateFormatter.dateFormat = "d/M/yy"
                    } else if availableWidth <= 120 {
                        dateFormatter.dateFormat = "d MMM yyyy"
                    } else {
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                    }
                    // Ambil tanggal dari siswa menggunakan KeyPath
                    let tanggalString = kelasModel.tanggal
                    if let date = dateFormatter.date(from: tanggalString) {
                        textField.stringValue = dateFormatter.string(from: date)
                    } else {
                        textField.stringValue = tanggalString // fallback jika parsing gagal
                    }
                    tableColumn?.minWidth = 70
                    tableColumn?.maxWidth = 140
                default:
                    break
                }
            }
            return cell
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        // Membuat tooltip sesuai dengan data yang ada di sel tertentu
        let kelasModel = viewModel.kelasModelForTable(tableTypeForTable(tableView))
        let columnName = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let currentData: String
        
        switch columnName {
        case NSUserInterfaceItemIdentifier("namasiswa"):
            currentData = kelasModel[row].namasiswa
        case NSUserInterfaceItemIdentifier("mapel"):
            currentData = kelasModel[row].mapel
        case NSUserInterfaceItemIdentifier("nilai"):
            currentData = String(kelasModel[row].nilai)
        case NSUserInterfaceItemIdentifier("semester"):
            currentData = kelasModel[row].semester
        case NSUserInterfaceItemIdentifier("namaguru"):
            currentData = kelasModel[row].namaguru
        case NSUserInterfaceItemIdentifier("tgl"):
            currentData = kelasModel[row].tanggal
        default:
            currentData = ""
        }
        
        return currentData
    }
    
    @objc private func periksaTampilan(_ sender: Any) {
        activateSelectedTable()
        if let table = activeTable() {
            loadTableData(tableView: table)
            isDataLoaded[table] = true
        }
        setupSortDescriptor()
    }
    @objc private func muatUlang(_ sender: NSMenuItem) {
        guard let (tableView, tableType) = sender.representedObject as? (NSTableView, TableType) else {
            periksaTampilan(self)
            return
        }
        let group = DispatchGroup()
        
        let selectedTabViewItem = tabView.selectedTabViewItem!
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        
        group.enter()
        viewModel.loadSiswaData(forTableType: tableType, siswaID: siswa!.id)
        group.leave()
        
        group.notify(queue: .main) { [weak self] in
            tableView.beginUpdates()
            tableView.reloadData()
            self?.populateSemesterPopUpButton()
            self?.updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: self?.smstr.titleOfSelectedItem ?? "")
            tableView.endUpdates()
        }
    }
    private func createContextMenu(tableView: NSTableView) -> NSMenu? {
        let tipeTabel = tableTypeForTable(tableView)
        let contextMenu = NSMenu()
        
        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.target = self
        refresh.representedObject = (tableView, tipeTabel)
        contextMenu.addItem(refresh)
        contextMenu.addItem(.separator())
        
        contextMenu.addItem(withTitle: "Salin", action: #selector(copyMenuItemClicked), keyEquivalent: "")
        contextMenu.items[2].target = self
        contextMenu.items[2].representedObject = tableView
        let paste = NSMenuItem(title: "Tempel", action: #selector(updateDataArrayMenuItemClicked(_:)), keyEquivalent: "")
        contextMenu.addItem(paste)
        paste.target = self
        paste.representedObject = tableView
        contextMenu.addItem(.separator())
        let deleteMenuItem = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        deleteMenuItem.target = self
        deleteMenuItem.representedObject = (tableView, tipeTabel)
        contextMenu.addItem(deleteMenuItem)
        return contextMenu
    }
    @IBAction private func paste(_ sender: Any) {
        updateDataArrayMenuItemClicked(self)
    }
    var isPasteing: Bool = false
    @objc private func updateDataArrayMenuItemClicked(_ sender: Any?) {
        // Dapatkan tabel yang dipilih
        guard let selectedTable = activeTable() else { return}
        // Dapatkan tipe tabel berdasarkan tabel yang dipilih
        guard let tableType = tableInfo.first(where: { $0.table == selectedTable })?.type else { return}
        // Dapatkan data yang terpilih dari tabel
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        selectedTable.deselectAll(self)
        let pastedDataRows = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        // Inisialisasi array untuk menampung pesan kesalahan
        var errorMessages: [String] = []
        isPasteing = true
        selectedTable.beginUpdates()
        for rowData in pastedDataRows {
            // Data berdasarkan format tab
            let pastedData = rowData.components(separatedBy: "\t")
            // Validasi dan tambahkan pesan kesalahan ke array
            if let errorMessage = validateAndAddData(tableView: selectedTable, forTableType: tableType, withPastedData: pastedData) {
                errorMessages.append(errorMessage)
            }
        }
        selectedTable.endUpdates()
        for segmentIndex in 0..<kelasSC.segmentCount {
            if segmentIndex != kelasSC.selectedSegment {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
        if !pastedKelasIDs.isEmpty {
            undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
                self?.undoPaste(table: selectedTable, tableType: tableType)
            }
            pastedKelasID.append(pastedKelasIDs)
            updateSemesterTeks()
            pastedKelasIDs.removeAll()
        }
        // Tampilkan NSAlert jika ada pesan kesalahan
        if !errorMessages.isEmpty {
            showWarningAlert(message: "Data Tidak Lengkap", informativeText: errorMessages.joined(separator: "\n"))
        }
        
        isPasteing = false
        updateUndoRedo(self)
    }
    private func validateAndAddData(tableView: NSTableView, forTableType tableType: TableType, withPastedData pastedData: [String]) -> String? {
        // Validasi Clipboard Kosong
        guard !pastedData.isEmpty else {
            return "Clipboard Kosong"
        }
        
        // Validasi Jumlah Elemen di Clipboard
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: Date())

        // Validasi Nilai
        if pastedData.count >= 2 {
            let nilaiString = pastedData[1]

            guard !nilaiString.isEmpty, let nilai = Int(nilaiString) else {
                return "Format Nilai Salah. Pisahkan setiap kolom menggunakan [TAB]"
            }

            // Seluruh bagian di bawah ini tetap sama
            var dataArray: [KelasModels] = []

            switch tableType {
            case .kelas1, .kelas2, .kelas3, .kelas4, .kelas5, .kelas6:
                dataArray = viewModel.kelasModelForTable(tableType)
            }
            let newKelasData = KelasModels(kelasID: 0, siswaID: siswa?.id ?? 0, namasiswa: siswa?.nama ?? "", mapel: pastedData[0], nilai: Int64(nilai), namaguru: pastedData[3], semester: pastedData[2], tanggal: tanggalSekarang)

            dataArray.append(newKelasData)
            
            var lastInsertedKelasIds: [Int] = []
            if let selectedTable = SingletonData.dbTable(forTableType: tableType) {
                if let kelasId = dbController.insertDataToKelas(table: selectedTable, siswaID: newKelasData.siswaID, namaSiswa: newKelasData.namasiswa, mapel: newKelasData.mapel, namaguru: newKelasData.namaguru, nilai: newKelasData.nilai, semester: newKelasData.semester, tanggal: newKelasData.tanggal) {
                    lastInsertedKelasIds.append(Int(kelasId))
                    updateModelData(withKelasId: Int64(kelasId), siswaID: newKelasData.siswaID, namasiswa: newKelasData.namasiswa, mapel: newKelasData.mapel, nilai: newKelasData.nilai, semester: newKelasData.semester, namaguru: newKelasData.namaguru, tanggal: newKelasData.tanggal)
                    pastedKelasIDs.append(kelasId)
                } else {}
            }
        } else {
            // Jika tidak ada elemen nilai, tambahkan pesan kesalahan
            return "Format Nilai Salah"
        }

        // Tidak ada kesalahan, kembalikan nil
        return nil
    }
    private func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        // Mendapatkan indeks yang dipilih dari kelasPopUpButton
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        // Menggunakan case statement untuk menentukan model data berdasarkan indeks
        var kelasModel: KelasModels?
        switch selectedIndex {
        case 0:
            kelasModel = Kelas1Model()
        case 1:
            kelasModel = Kelas2Model()
        case 2:
            kelasModel = Kelas3Model()
        case 3:
            kelasModel = Kelas4Model()
        case 4:
            kelasModel = Kelas5Model()
        case 5:
            kelasModel = Kelas6Model()
        default:
            break
        }

        // Pastikan kelasModel tidak nil sebelum mengakses propertinya
        guard let validKelasModel = kelasModel else {return}
        // Update the model data based on kelasId
        validKelasModel.kelasID = kelasId
        validKelasModel.siswaID = siswaID
        validKelasModel.namasiswa = namasiswa
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal
        
        if siswa?.id == siswaID {
            NotificationCenter.default.post(name: .updateTableNotificationDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": validKelasModel])
        } else {
            return
        }
    }
    @IBAction private func pilihanSiswa(_ sender: NSPopUpButton) {
        guard let id = siswa?.id else {return}
        let selectedSiswa = dbController.getSiswa(idValue: id)
        if sender.titleOfSelectedItem == "Salin NIK/NIS" {
            let copiedData = "\(selectedSiswa.nis)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(self.view, pesan: "NIK/NIS \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin NISN" {
            let copiedData = "\(selectedSiswa.nisn)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(self.view, pesan: "NISN \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin Semua Data" {
            let copiedData = "\(selectedSiswa.nama)\t\(selectedSiswa.alamat)\t\(selectedSiswa.ttl)\t\(selectedSiswa.tahundaftar)\t\(selectedSiswa.namawali)\t\(selectedSiswa.nis)\t \(selectedSiswa.nisn)\t\(selectedSiswa.ayah)\t\(selectedSiswa.ibu)\t\(selectedSiswa.tlv)\t\(selectedSiswa.jeniskelamin)\t\(selectedSiswa.kelasSekarang)\t\(selectedSiswa.status)\t\(selectedSiswa.tanggalberhenti)\n"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(self.view, pesan: "Data Lengkap \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Info Lengkap Siswa" {
            alert.messageText = "\(selectedSiswa.nama)"
            self.alert.icon = NSImage(named: "image")
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                let foto = self.dbController.bacaFotoSiswa(idValue: self.siswa?.id ?? 0)
                let data = foto.foto
                if let image = NSImage(data: data) {
                    // Ukuran asli gambar
                    let originalSize = image.size
                    
                    // Ukuran maksimum area ikon di NSAlert
                    let maxIconSize = NSSize(width: 64, height: 64) // Sesuaikan sesuai kebutuhan Anda
                    
                    // Hitung skala untuk menjaga proporsi gambar
                    let scale = min(maxIconSize.width / originalSize.width, maxIconSize.height / originalSize.height)
                    let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
                    
                    // Buat gambar baru dengan area transparan
                    let paddedImage = NSImage(size: maxIconSize)
                    paddedImage.lockFocus()
                    
                    // Hitung posisi tengah untuk menggambar gambar asli
                    let xOffset = (maxIconSize.width - newSize.width) / 2
                    let yOffset = (maxIconSize.height - newSize.height) / 2
                    let drawingRect = NSRect(origin: NSPoint(x: xOffset, y: yOffset), size: newSize)
                    
                    // Gambar gambar asli pada area transparan
                    image.draw(in: drawingRect)
                    
                    paddedImage.unlockFocus()
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // Gunakan gambar baru sebagai ikon
                        self.alert.icon = paddedImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alert.icon = NSImage(named: "image")
                    }
                }
            }
            alert.informativeText = "Alamat: \(selectedSiswa.alamat)\nTTL: \(selectedSiswa.ttl)\nTahun Daftar: \(selectedSiswa.tahundaftar)\nNama Wali: \(selectedSiswa.namawali)\nNIK: \(selectedSiswa.nis)\nNISN: \(selectedSiswa.nisn)\nAyah Kandung: \(selectedSiswa.ayah)\nIbu Kandung: \(selectedSiswa.ibu)\nNo. Tlv: \(selectedSiswa.tlv)\nJenis Kelamin: \(selectedSiswa.jeniskelamin)\nStatus: \(selectedSiswa.status)\nKelas Sekarang: \(selectedSiswa.kelasSekarang)\nTanggal Berhenti: \(selectedSiswa.tanggalberhenti)"
            alert.beginSheetModal(for: view.window!, completionHandler: nil)
        }
    }
    @IBAction private func copy(_ sender: Any) {
        // Assuming you have a reference to your active table view
        guard let activeTableView = activeTable() else {
            return
        }

        // Create a dummy NSMenuItem
        let dummyMenuItem = NSMenuItem()

        // Set the representedObject to the active table view
        dummyMenuItem.representedObject = activeTableView

        // Call copySelectedRows with the dummy NSMenuItem
        copySelectedRows(dummyMenuItem)
    }
    
    @IBAction private func kelasSC(_ sender: NSSegmentedControl) {
        let nabila = sender.selectedSegment
        let salsabila = "Kelas \(nabila + 1)"
        if kelasSC.label(forSegment: nabila) != nil {
            // Mengganti label dengan menambahkan string "Kelas"
            kelasSC.setLabel("\(salsabila)", forSegment: nabila)
        }
        tabView.selectTabViewItem(at: nabila)
        activateSelectedTable()
        if let table = activeTable() {
            if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
                // Load data for the table view
                loadTableData(tableView: table)
                isDataLoaded[table] = true
            }
        }
        setupSortDescriptor()
        for segmentIndex in 0..<sender.segmentCount {
            if segmentIndex != nabila {
                sender.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
    }
    private func showWarningAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "No Data Bordered")
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func copyMenuItemClicked(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
            let tableInfo = tableInfo.first(where: { $0.table == tableView }) else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        
        if tableView.clickedRow >= 0 && tableView.clickedRow < selectedDataArray.count {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, maka panggil fungsi copySelectedRows
                copySelectedRows(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih, maka panggil fungsi copyClickedRow
                copyClickedRow(sender)
            }
        }
    }
    @objc private func copyClickedRow(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
            let tableInfo = tableInfo.first(where: { $0.table == tableView }) else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.clickedRow >= 0 && tableView.clickedRow < selectedDataArray.count else {return}
        let selectedRow = tableView.clickedRow
        let dataToCopy = selectedDataArray[selectedRow]

        // Gabungkan semua data dari baris yang diklik dengan tab sebagai separator
        let klikData = "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)"

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(klikData, forType: .string)
    }

    @objc private func copySelectedRows(_ sender: NSMenuItem) {
        guard let tableView = activeTable(),
            !tableView.selectedRowIndexes.isEmpty else {return}
        let selectedDataArray = viewModel.kelasModelForTable(tableTypeForTable(tableView))
        // Membuat string untuk menyimpan data yang akan disalin
        var combinedData = ""
        // Mengumpulkan data dari seluruh baris yang dipilih dengan tab sebagai separator
        for rowIndex in tableView.selectedRowIndexes {
            let selectedRow = rowIndex
            let dataToCopy = selectedDataArray[selectedRow]
            combinedData += "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)\n"
        }

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedData, forType: .string)
    }
    @objc private func copyRows(_ sender: Any) {
        guard let tableView = activeTable(),
            let tableInfo = tableInfo.first(where: { $0.table == tableView }),
            !tableView.selectedRowIndexes.isEmpty else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        var combinedData = ""

        // Mengumpulkan data dari seluruh baris yang dipilih dengan tab sebagai separator
        for rowIndex in tableView.selectedRowIndexes {
            let selectedRow = rowIndex
            let dataToCopy = selectedDataArray[selectedRow]
            combinedData += "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)\n"
        }

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedData, forType: .string)
    }

    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
            let editMenuItem = mainMenu.item(withTitle: "Edit"),
            let editMenu = editMenuItem.submenu,
            let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
            let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
            let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            // Mendapatkan NSTableView aktif
            if let activeTableView = activeTable() {
                let isRowSelected = activeTableView.selectedRowIndexes.count > 0
                copyMenuItem.isEnabled = isRowSelected
                pasteMenuItem.target = self
                pasteMenuItem.action = #selector(updateDataArrayMenuItemClicked(_:))
                // Update item menu "Delete"
                delete.isEnabled = isRowSelected
                if isRowSelected {
                    copyMenuItem.target = self
                    copyMenuItem.action = #selector(copySelectedRows(_:))

                    // Set representedObject dengan benar
                    let tableType = tableTypeForTable(activeTableView)
                    let representedObject: (NSTableView, TableType, IndexSet) = (activeTableView, tableType, activeTableView.selectedRowIndexes)
                    delete.representedObject = representedObject
                    delete.target = self
                    // Set action sebagai sebuah closure
                    delete.action = #selector(hapus(_:))
                } else {
                    copyMenuItem.target = nil
                    copyMenuItem.action = nil
                    copyMenuItem.isEnabled = false
                    delete.target = nil
                    delete.action = nil
                    delete.isEnabled = false
                    delete.representedObject = nil
                }
            }
        }
    }
    
    @objc private func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType),
              let _ = SingletonData.dbTable(forTableType: tableType) else {return}
        
        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes
        
        guard selectedRow >= 0 else {return}
        if selectedIndexes.contains(selectedRow) {
            hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
        } else {
            // Jika clickedRow bukan bagian dari selectedRows, panggil fungsi hapusKlik
            hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
        }
    }
    @objc private func hapus(_ sender: Any) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
        
            // Karena Anda menggunakan [weak self], tidak perlu optional binding di sini
            // Gunakan deleteMenuItem?.representedObject sebagai opsi terkini
            guard let representedObject = delete.representedObject as? (NSTableView, TableType, IndexSet) else {
                return
            }
        
            let (table, tableType, selectedIndexes) = representedObject

            // Memeriksa apakah ada indeks terpilih
            guard !selectedIndexes.isEmpty else {
                return
            }

            // Membuat Set untuk menyimpan nama siswa secara unik
            var uniqueSelectedMapel = Set<String>()

            // Mengisi Set dengan nama siswa dari indeks terpilih
            let modelArray = viewModel.kelasModelForTable(tableType)

            for index in selectedIndexes {
                if modelArray.indices.contains(index) {
                    uniqueSelectedMapel.insert(modelArray[index].mapel)
                } else {
                    
                }
            }
            // Menggabungkan Set menjadi satu string dengan koma
            let selectedMapelString = uniqueSelectedMapel.joined(separator: ", ")

            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
            alert.messageText = "Apakah anda yakin akan menghapus data ini dari \(siswa?.nama ?? "")"
            alert.informativeText = "\(selectedMapelString) akan dihapus dari \(siswa?.nama ?? "")."
            alert.addButton(withTitle: "Hapus")
            alert.addButton(withTitle: "Batalkan")
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Hanya melanjutkan jika pengguna menekan tombol "Hapus"
                // Tidak perlu optional binding pada self karena sudah menggunakan [weak self] di deklarasi metode
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }
    var deletedDataArray: [(table: Table, data: [KelasModels])] = []
    var kelasID: [[Int64]] = []
    var targetModel: [KelasModels] = []
    private func hapusKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        deleteRedoArray(self)
        let kelasID = dataArray[clickedRow].kelasID

        // Simpan data sebelum dihapus ke dalam deletedDataArray
        let deletedData = dataArray[clickedRow]
        deletedDataArray.append((table: currentClassTable, data: [deletedData]))
        SingletonData.deletedKelasAndSiswaIDs.append([(kelasID: deletedData.kelasID, siswaID: deletedData.siswaID)])

        if clickedRow == table.numberOfRows {
            table.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            table.selectRowIndexes(IndexSet(integer: clickedRow + 1), byExtendingSelection: false)
        }
        table.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideDown)
        viewModel.removeData(index: clickedRow, tableType: tableType)
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        undoManager?.setActionName("Undo Hapus Data Siswa")
        undoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": kelasID, "hapusData": true])
        }
    }
    private func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        // Bersihkan array kelasID
        deleteRedoArray(self)
        // Tampung semua data yang akan dihapus ke dalam deletedDataArray di luar loop
        var selectedDataToDelete: [KelasModels] = []
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []
        var allIDs: [Int64] = []
        // Ambil indeks baris terakhir yang dipilih sebelumnya
        var rowToSelect: Int?
        for selectedRow in selectedIndexes.reversed() {
            if selectedRow < dataArray.count {
                let deletedData = dataArray[selectedRow]
                allIDs.append(deletedData.kelasID)
                selectedDataToDelete.append(deletedData)
                deletedKelasAndSiswaIDs.append((kelasID: deletedData.kelasID, siswaID: deletedData.siswaID))
                // Hapus data dari model berdasarkan tableType
                viewModel.removeData(index: selectedRow, tableType: tableType)
            }
        }
        
        // Setelah loop, tambahkan semua data yang akan dihapus ke dalam deletedDataArray
        deletedDataArray.append((table: currentClassTable, data: selectedDataToDelete))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Mulai dan akhiri update tabel untuk menghapus baris terpilih
        table.beginUpdates()
        table.removeRows(at: selectedIndexes, withAnimation: .slideUp)
        table.endUpdates()
        let totalRowsAfterDeletion = table.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            rowToSelect = min(totalRowsAfterDeletion - 1, selectedIndexes.first ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect!), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            table.deselectAll(nil)
        }

        // Daftarkan undo untuk aksi hapus yang dilakukan
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoHapus(tableType: tableType, table: table)
        })
        undoManager?.endUndoGrouping()

        // Cetak jumlah data yang telah dihapus ke konsol
        
        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        }
    }
    private func undoHapus(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = KelasModels.siswaSortDescriptor else {
            return
        }
        activateTable(table)
        table.deselectAll(self)
        var lastIndex: [Int] = []
        // Buat array baru untuk menyimpan semua id yang dihasilkan
        var allIDs: [Int64] = []
        var dataArray: [(index: Int, data: KelasModels)] = []
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        table.beginUpdates()
        let dataYangDihapus = deletedDataArray.removeLast()
        for deletedData in dataYangDihapus.data {
            let id = deletedData.kelasID
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else {return}
            if let newData = viewModel.modelForRow(at: insertionIndex, tableType: tableType) {
                dataArray.append((index: selectedIndex, data: newData))
            }
            table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
            lastIndex.append(insertionIndex)
            allIDs.append(id)
        }
        table.endUpdates()
        if let indeksAkhir = lastIndex.max() {
            table.scrollRowToVisible(indeksAkhir)
        }
        // Tambahkan semua id yang dihasilkan ke dalam kelasID
        kelasID.append(allIDs)
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": dataArray])
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.redoHapus(table: table, tableType: tableType)
        }
        undoManager?.setActionName("Redo Hapus Data Siswa")
        undoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        SingletonData.deletedKelasAndSiswaIDs.removeAll { kelasSiswaPairs in
            kelasSiswaPairs.contains { pair in
                allIDs.contains(pair.kelasID)
            }
        }
    }
    private func redoHapus(table: NSTableView, tableType: TableType) {
        guard !kelasID.isEmpty, let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {return}
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = kelasID.removeLast()
        activateTable(table)
        // Tentukan model target berdasarkan tableType
        switch tableType {
        case .kelas1:
            targetModel = viewModel.kelas1Model
        case .kelas2:
            targetModel = viewModel.kelas2Model
        case .kelas3:
            targetModel = viewModel.kelas3Model
        case .kelas4:
            targetModel = viewModel.kelas4Model
        case .kelas5:
            targetModel = viewModel.kelas5Model
        case .kelas6:
            targetModel = viewModel.kelas6Model
        }

        guard let result = viewModel.removeData(withIDs: allIDs, fromModel: &targetModel, forTableType: tableType) else {
            return
        }
        // Iterasi melalui model data untuk mencari kelasID yang sesuai
        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result
        // Hapus baris-baris yang sesuai dari targetModel dan NSTableView
        table.beginUpdates()
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
        deletedDataArray.append((table: currentClassTable, data: dataDihapus))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Daftarkan undo untuk aksi redo yang dilakukan
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        undoManager?.setActionName("Redo Hapus Data Siswa")
        undoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {return}
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        }
    }
    @objc private func deleteMenuItemPress(_ sender: Any) {
        guard let tableView = activeTable(),
            let tableInfo = tableInfo.first(where: { $0.table == tableView }) else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.selectedRow >= 0 && tableView.selectedRow < selectedDataArray.count else {return}
        let selectedRow = tableView.selectedRow
        let idDipilih = selectedDataArray[selectedRow].kelasID

        if let table = SingletonData.dbTable(forTableType: tableInfo.type) {
            dbController.deleteDataFromKelas(table: table, kelasID: idDipilih)
        }
        tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideDown)
        updateSemesterTeks()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .hapusDataSiswa, object: self)
        }
    }

    @objc private func deleteMenuItemClicked(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
            let tableInfo = tableInfo.first(where: { $0.table == tableView }) else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.clickedRow >= 0 && tableView.clickedRow < selectedDataArray.count else {return}
        let selectedRow = tableView.clickedRow
        let idDipilih = selectedDataArray[selectedRow].kelasID
        if let table = SingletonData.dbTable(forTableType: tableInfo.type) {
            dbController.deleteDataFromKelas(table: table, kelasID: idDipilih)
        }
        tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideDown)
        updateSemesterTeks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .hapusDataSiswa, object: self)
        }
    }

    var selectedIDs: Set<Int64> = []
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIDs.removeAll()
        guard let tableView = notification.object as? NSTableView,
              tableView.numberOfRows != 0
        else { return }
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
        let table = activeTable()!
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                guard index >= 0 && index < model.count else {
                    return nil  // Mengabaikan indeks yang tidak valid
                }
                return model[index].kelasID
            })
        }
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
    }
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        return false
    }
    
    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        if columnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        
        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        
        return true
    }
    private func setupSortDescriptor() {
        let table = activeTable()
        let mapel = NSSortDescriptor(key: "mapel", ascending: true)
        let nilai = NSSortDescriptor(key: "nilai", ascending: true)
        let semester = NSSortDescriptor(key: "semester", ascending: true)
        let namaguru = NSSortDescriptor(key: "namaguru", ascending: true)
        let tgl = NSSortDescriptor(key: "tgl", ascending: true)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("mapel"): mapel,
            NSUserInterfaceItemIdentifier("nilai"): nilai,
            NSUserInterfaceItemIdentifier("semester"): semester,
            NSUserInterfaceItemIdentifier("namaguru"): namaguru,
            NSUserInterfaceItemIdentifier("tgl"): tgl
        ]
        guard let tableColumn = table?.tableColumns else { return }
        
        for column in tableColumn {
            let identifikasi = column.identifier
            let pengidentifikasi = identifikasiKolom[identifikasi]
            column.sortDescriptorPrototype = pengidentifikasi
            
        }
    }
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let table = activeTable()!
        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        let tableType = tableTypeForTable(tableView)
        viewModel.sort(tableType: tableType, sortDescriptor: sortDescriptor)
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        var indexset = IndexSet()
        selectedIDs.forEach { id in
            if let index = model.firstIndex(where: {$0.kelasID == id }) {
                indexset.insert(index)
            }
        }
        saveSortDescriptor(sortDescriptor, forTableIdentifier: createStringForActiveTable())
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        table.selectRowIndexes(indexset, byExtendingSelection: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let max = indexset.max() {
                table.scrollRowToVisible(max)
            }
        }
    }
    private func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?, forTableIdentifier identifier: String) {
        if let sortDescriptor = sortDescriptor {
            let sortDescriptorData = try? NSKeyedArchiver.archivedData(withRootObject: sortDescriptor, requiringSecureCoding: false)
            UserDefaults.standard.set(sortDescriptorData, forKey: "SortDescriptorSiswa_\(identifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "SortDescriptorSiswa_\(identifier)")
        }
    }

    // Terapkan sort descriptor dari UserDefaults ke table view
    private func applySortDescriptor(tableView: NSTableView, sortDescriptor: NSSortDescriptor?) {
        guard let sortDescriptor = sortDescriptor else {
            return
        }
        // Terapkan sort descriptor ke table view
        tableView.sortDescriptors = [sortDescriptor]
    }

//    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
//        let identifier = tableColumn.identifier.rawValue
//        var ascending = false
//        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
//        guard let sortDescriptor = tableView.sortDescriptors.first else {
//            return
//        }
//
//        if tableView.sortDescriptors.contains(NSSortDescriptor(key: identifier, ascending: false)) {
//            ascending = true
//        }
//        
//
//        switch sortDescriptor.key {
//        case "mapel":
//            switch tableView {
//            case table1: viewModel.kelas1Model.sort { $0.mapel < $1.mapel }
//            case table2: viewModel.kelas2Model.sort { $0.mapel < $1.mapel }
//            case table3: viewModel.kelas3Model.sort { $0.mapel < $1.mapel }
//            case table4: viewModel.kelas4Model.sort { $0.mapel < $1.mapel }
//            case table5: viewModel.kelas5Model.sort { $0.mapel < $1.mapel }
//            case table6: viewModel.kelas6Model.sort { $0.mapel < $1.mapel }
//            default:
//                break
//            }
//        case "nilai":
//            switch tableView {
//            case table1: viewModel.kelas1Model.sort { $0.nilai < $1.nilai }
//            case table2: viewModel.kelas2Model.sort { $0.nilai < $1.nilai }
//            case table3: viewModel.kelas3Model.sort { $0.nilai < $1.nilai }
//            case table4: viewModel.kelas4Model.sort { $0.nilai < $1.nilai }
//            case table5: viewModel.kelas5Model.sort { $0.nilai < $1.nilai }
//            case table6: viewModel.kelas6Model.sort { $0.nilai < $1.nilai }
//            default:
//                break
//            }
//        case "semester":
//            switch tableView {
//            case table1: viewModel.kelas1Model.sort { $0.semester < $1.semester }
//            case table2: viewModel.kelas2Model.sort { $0.semester < $1.semester }
//            case table3: viewModel.kelas3Model.sort { $0.semester < $1.semester }
//            case table4: viewModel.kelas4Model.sort { $0.semester < $1.semester }
//            case table5: viewModel.kelas5Model.sort { $0.semester < $1.semester }
//            case table6: viewModel.kelas6Model.sort { $0.semester < $1.semester }
//            default:
//                break
//            }
//        case "namaguru":
//            switch tableView {
//            case table1: viewModel.kelas1Model.sort { $0.namaguru < $1.namaguru }
//            case table2: viewModel.kelas2Model.sort { $0.namaguru < $1.namaguru }
//            case table3: viewModel.kelas3Model.sort { $0.namaguru < $1.namaguru }
//            case table4: viewModel.kelas4Model.sort { $0.namaguru < $1.namaguru }
//            case table5: viewModel.kelas5Model.sort { $0.namaguru < $1.namaguru }
//            case table6: viewModel.kelas6Model.sort { $0.namaguru < $1.namaguru }
//            default:
//                break
//            }
//        default:
//            break
//        }
//        
//
//        if !ascending {
//            switch tableView {
//            case table1: viewModel.kelas1Model = viewModel.kelas1Model.reversed()
//            case table2: viewModel.kelas2Model = viewModel.kelas2Model.reversed()
//            case table3: viewModel.kelas3Model = viewModel.kelas3Model.reversed()
//            case table4: viewModel.kelas4Model = viewModel.kelas4Model.reversed()
//            case table5: viewModel.kelas5Model = viewModel.kelas5Model.reversed()
//            case table6: viewModel.kelas6Model = viewModel.kelas6Model.reversed()
//            default:
//                break
//            }
//        }
//
//        // Perbarui tampilan tabel
//        tableView.reloadData()
//    }
    
    
    @IBAction private func handlePrint(_ sender: Any) {
        guard self.view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Data belum siap"
            alert.informativeText = "Pilih kelas terlebih dahulu untuk menyiapkan data."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.generatePDFForPrint(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    func generatePDFForPrint(header: [String], siswaData: [KelasModels], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?) {
        // Tentukan lokasi sementara untuk menyimpan file PDF
        let csvFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(namaFile).csv")
        
        do {
            // Simpan data sebagai CSV sementara
            try self.saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
            
            // Konversi CSV ke PDF
            ReusableFunc.runPythonScriptPDF(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                if let progressVC = sheetWindow?.contentViewController as? ProgressBarVC {
                    progressVC.progressLabel.stringValue = "Mengunggu dialog print selesai..."
                }

                // Dialog print file PDF
                self.printPDFDocument(at: xlsxFileURL!)
                
                self.view.window?.endSheet(sheetWindow!)
                
                // Hapus file sementara jika perlu
                try? FileManager.default.removeItem(at: csvFileURL)
                try? FileManager.default.removeItem(at: xlsxFileURL!)
            })
        } catch {
            print("Gagal menyimpan CSV sementara: \(error)")
            window?.endSheet(sheetWindow!)
        }
    }


    func printPDFDocument(at pdfFileURL: URL) {
        guard let pdfDocument = PDFDocument(url: pdfFileURL) else {
            print("Gagal memuat file PDF untuk dicetak di lokasi: \(pdfFileURL.path)")
            return
        }

        // Membuat PDFView untuk mencetak
        let pdfView = PDFView()
        pdfView.document = pdfDocument

        // Konfigurasi NSPrintInfo
        let printInfo = NSPrintInfo.shared
        printInfo.leftMargin = 0.0
        printInfo.rightMargin = 0.0
        printInfo.topMargin = 0.0
        printInfo.bottomMargin = 0.0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .clip
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        
        //Frame
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayBox = .mediaBox // Gunakan ukuran media penuh
        pdfView.backgroundColor = .clear // Hilangkan latar belakang
        pdfView.displaysPageBreaks = false // Hilangkan garis antar halaman
        pdfView.frame = CGRect(x: 0, y: 0, width: printInfo.paperSize.width, height: printInfo.paperSize.height)


        // Membuat NSPrintOperation
        let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOperation.jobTitle = "PDF \(siswa?.nama ?? "") \(createLabelForActiveTable())"
        
        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printOperation.run()
    }

    
    func saveToCSV(header: [String], siswaData: [KelasModels], destinationURL: URL) throws {
        // Membuat baris data siswa sebagai array dari string
        let rows = siswaData.map { [$0.mapel, String($0.nilai), String($0.semester), $0.namaguru] }
        
        // Menggabungkan header dengan data dan mengubahnya menjadi string CSV
        let csvString = ([header] + rows).map { $0.joined(separator: ";") }.joined(separator: "\n")

        // Menulis string CSV ke file
        try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
    
    @IBAction func exportToExcel(_ sender: NSMenuItem) {
        guard self.view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.chooseFolderAndSaveCSV(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: false)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }
    @IBAction func exportToPDF(_ sender: NSMenuItem) {
        guard self.view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.chooseFolderAndSaveCSV(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: true)
            } else {
                
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    func chooseFolderAndSaveCSV(header: [String], siswaData: [KelasModels], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?, pdf: Bool) {
        // Tentukan lokasi untuk menyimpan file CSV di folder aplikasi
        let csvFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(namaFile).csv")
        do {
            if pdf {
                try self.saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScriptPDF(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: true)
                })
            } else {
                try self.saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScript(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: false)
                })
            }
        } catch {
            
            window?.endSheet(sheetWindow!)
        }
    }
    
    
    @IBAction func shareButton(_ sender: NSButton) {
        shareMenu.popUp(positioning: nil, at: NSPoint(x: -2, y: sender.bounds.height + 4), in: sender)
    }
    
    @IBAction private func tampilkanStatistik(_ sender: AnyObject) {
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }
        if let siswa = siswa, siswa.id > 0 {
            let siswaID = siswa.id
            
            bukaDetil(siswaID: siswaID)
        }
    }
    private func bukaDetil(siswaID: Int64) {
        // Lakukan sesuatu dengan siswaID, misalnya, buka jendela statistik siswa.
        let statistikSiswaVC = StatistikMurid(nibName: "StatistikMurid", bundle: nil)
        statistikSiswaVC.siswaID = siswaID // Mengirim siswaID ke jendela baru.
        // Set nama murid untuk digunakan dalam judul jendela dari StatistikMurid.
        statistikSiswaVC.setNamaMurid(forClassIndex: 0)
        // Buka jendela statistik siswa.
        let window = NSWindow(contentViewController: statistikSiswaVC)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @IBAction private func pratinjauFoto(_ sender: NSButton) {
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }
        if let siswa = siswa {
            let selectedSiswa = siswaData.first { $0.id == siswa.id }
            if let viewController = NSStoryboard(name: NSStoryboard.Name("PratinjauFoto"), bundle: nil)
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ImagePreviewViewController")) as? PratinjauFoto {
                viewController.selectedSiswa = selectedSiswa
                viewController.loadView()
                // Menampilkan popover atau sheet, sesuai kebutuhan Anda
                let popover = NSPopover()
                popover.contentViewController = viewController
                popover.behavior = .semitransient

                // Tampilkan popover di dekat tombol yang memicunya
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            }
        }
    }
    @IBAction private func tambahSiswaButtonClicked(_ sender: Any) {
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }
        if let siswa = siswa {
            // Ambil data siswa baru dari antarmuka pengguna
            let selectedSiswa = siswaData.first { $0.id == siswa.id }

            // persiapan view controller dengan XIB ID (misalnya, "AddDetilSiswaUI")
            let detailViewController = AddDetilSiswaUI(nibName: "AddDetilSiswaUI", bundle: nil)
            // Atur data siswa pada tampilan detail
            detailViewController.siswa = selectedSiswa
            detailViewController.loadView()
            detailViewController.viewDidLoad()
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                detailViewController.tabDidChange(index: selectedTabIndex)
            }                // persiapkan NSPopover
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.contentViewController = detailViewController
            
            // Tampilkan popover di dekat tombol yang memicunya
            if let button = sender as? NSButton {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    @IBAction private func filterBySemester(_ sender: NSPopUpButton) {
        guard sender.menu?.item(at: 0)?.identifier?.rawValue != "emptyData" else {
            #if DEBUG
            print("emptyData clicked")
            #endif
            return
        }
        if let table = activeTable() {
            self.view.window?.makeFirstResponder(table)
        }
        let selectedSemester = sender.titleOfSelectedItem ?? ""
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabViewItem), semesterName: selectedSemester)
        }
    }

//    @objc private func updateValuesForSelectedTab(tabIndex: Int, semesterIndex: Int) {
//        // 1. Ambil pilihan semester yang dipilih
//        let selectedSemesterIndex = smstr.indexOfSelectedItem
//        var totalNilai = 0
//        var averageNilai = 0.0
//
//        switch tabIndex {
//        case 0:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas1Model, semesterIndex: selectedSemesterIndex)
//        case 1:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas2Model, semesterIndex: selectedSemesterIndex)
//        case 2:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas3Model, semesterIndex: selectedSemesterIndex)
//        case 3:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas4Model, semesterIndex: selectedSemesterIndex)
//        case 4:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas5Model, semesterIndex: selectedSemesterIndex)
//        case 5:
//            (totalNilai, averageNilai) = updateValuesForKelasData(kelasData: viewModel.kelas6Model, semesterIndex: selectedSemesterIndex)
//        default:
//            break
//        }
//
//        labelCount.isSelectable = true
//        labelAverage.isSelectable = true
//        labelCount.stringValue = "Jumlah: \(totalNilai)"
//        labelAverage.stringValue = String(format: "Rata-rata: %.2f", averageNilai)
//    }
    var allSemesters: Set<String>!
    private func populateSemesterPopUpButton() {
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {
            return
        }
        smstr.removeAllItems()

        // Menentukan model kelas berdasarkan tab yang aktif
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let kelasData: [KelasModels]

        switch tabIndex {
        case 0:
            kelasData = viewModel.kelas1Model
        case 1:
            kelasData = viewModel.kelas2Model
        case 2:
            kelasData = viewModel.kelas3Model
        case 3:
            kelasData = viewModel.kelas4Model
        case 4:
            kelasData = viewModel.kelas5Model
        case 5:
            kelasData = viewModel.kelas6Model
        default:
            kelasData = []
        }

        if nilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.namasiswa != "" }.map { $0.semester })
        } else if semuaNilai.state == .on {
            allSemesters = Set(kelasData.filter { !$0.semester.isEmpty && $0.nilai > 0 }.map { $0.semester })
        } else if bukanNilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.namasiswa == "" }.map { $0.semester })
        }

        // Format semester dan urutkan
        let sortedSemesters = allSemesters.sorted { ReusableFunc.semesterOrder($0, $1) }
        let formattedSemesters = sortedSemesters.map { ReusableFunc.formatSemesterName($0) }

        // Update NSPopUpButton
        if formattedSemesters.isEmpty {
            // Tambahkan pesan placeholder jika tidak ada data
            smstr.removeAllItems()
            let emptyData = NSMenuItem(title: "Item blm. dipilih", action: nil, keyEquivalent: "")
            emptyData.identifier = NSUserInterfaceItemIdentifier(rawValue: "emptyData")
            smstr.menu?.addItem(emptyData)
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.isEnabled = false
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.isHidden = true
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.state = .mixed
            smstr.isEnabled = true
//            if state == .on {
//                nilaiKelasAktif.title = "Tdk. ada data \"\(self.createLabelForActiveTable())\""
//            } else if state == .off {
//                nilaiKelasAktif.title = "Tdk. ada data di Kelas Aktif \"\(self.createLabelForActiveTable())\""
//            } else if state == .mixed {
//                nilaiKelasAktif.title = "Tdk. ada nilai yang bukan di Kelas Aktif \"\(self.createLabelForActiveTable())\""
//            }
        } else {
//            if state == .on {
//                nilaiKelasAktif.title = "Hanya nilai di Kelas Aktif"
//            } else if state == .off {
//                nilaiKelasAktif.title = "Hanya nilai di Kelas Aktif"
//            } else if state == .mixed {
//                nilaiKelasAktif.title = "Hanya nilai yang bukan di Kelas Aktif"
//            }
            smstr.removeAllItems()
            smstr.addItems(withTitles: formattedSemesters)
            smstr.isEnabled = true
        }
    }
    var filteredData: [KelasModels]!
    @objc private func updateValuesForSelectedTab(tabIndex: Int, semesterName: String) {
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        
        var totalNilai = 0
        var averageNilai = 0.0
        // Dapatkan data kelas berdasarkan tabIndex
        var kelasData: [KelasModels] = []
        var filteredIndices: IndexSet = []
        let kelasAktifState = nilaiKelasAktif.state == .on
        let bukanKelasAktifState = bukanNilaiKelasAktif.state == .on
        let semuaNilaiState = semuaNilai.state == .on
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {return}
            let semesterValue = semesterName.replacingOccurrences(of: "Semester ", with: "")
            
            kelasData = self.viewModel.setModel(TableType(rawValue: tabIndex)!, model: self.viewModel.getModel(for: (TableType(rawValue: tabIndex)!)))
            
            // Filter data sesuai dengan semester dan status
            if kelasAktifState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue && !$0.namasiswa.isEmpty }
                self.tableData = kelasData.filter { !$0.namasiswa.isEmpty }
            } else if semuaNilaiState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue }
                self.tableData = kelasData
            } else if bukanKelasAktifState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue && $0.namasiswa.isEmpty }
                self.tableData = kelasData.filter { $0.namasiswa.isEmpty }
            }
            
            // Hitung total nilai dan rata-rata
            totalNilai = self.filteredData.map { Int($0.nilai) }.reduce(0, +)
            let filteredDataCount = self.filteredData.count
            if filteredDataCount > 0 {
                averageNilai = Double(totalNilai) / Double(filteredDataCount)
            }
            
            // Cari indeks dari data yang difilter
            for (index, item) in kelasData.enumerated() {
                if !self.tableData.contains(where: { $0.kelasID == item.kelasID }) {
                    filteredIndices.insert(index)
                }
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            if let table = self?.activeTable() {
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = true
                    context.duration = 0.3
                    
                    table.beginUpdates()
                    table.unhideRows(at: table.hiddenRowIndexes, withAnimation: .slideDown)
                    table.hideRows(at: filteredIndices, withAnimation: .slideUp)
                    table.endUpdates()
                }, completionHandler: { [weak self] in
                    guard let self = self else {return}
                    // Update label
                    self.labelCount.isSelectable = true
                    self.labelAverage.isSelectable = true
                    self.labelCount.stringValue = "Jumlah: \(totalNilai)"
                    self.labelAverage.stringValue = String(format: "Rata-rata: %.2f", averageNilai)
                })
            }
        }
    }
//    private func updateValuesForKelasData(kelasData: [KelasModels], semesterIndex: Int) -> (Int, Double) {
//        var totalNilai = 0
//        var averageNilai = 0.0
//
//        switch semesterIndex {
//        case 0...2:
//            totalNilai = kelasData.filter { $0.semester == "\(semesterIndex + 1)" }.map { Int($0.nilai) }.reduce(0, +)
//            let filteredDataCount = kelasData.filter { $0.semester == "\(semesterIndex + 1)" }.count
//            if filteredDataCount > 0 {
//                averageNilai = Double(totalNilai) / Double(filteredDataCount)
//            }
//        default:
//            break
//        }
//        return (totalNilai, averageNilai)
//    }
    @objc private func updateSemesterTeks() {
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            let selectedSemester = smstr.titleOfSelectedItem ?? ""
            updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        self.activateSelectedTable()
        if let table = activeTable() { self.view.window?.makeFirstResponder(table) }
        else { self.view.window?.makeFirstResponder(table1) }
        DispatchQueue.main.async { [unowned self] in
            self.populateSemesterPopUpButton()
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                // Mendapatkan indeks semester yang dipilih dari NSPopUpButton
                let selectedSemester = smstr.titleOfSelectedItem ?? ""
                updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
            }
        }
    }
    private func setActiveTable(_ table: NSTableView) {
        if table == table1 {
            activeTableType = .kelas1
        } else if table == table2 {
            activeTableType = .kelas2
        } else if table == table3 {
            activeTableType = .kelas3
        } else if table == table4 {
            activeTableType = .kelas4
        } else if table == table5 {
            activeTableType = .kelas5
        } else if table == table6 {
            activeTableType = .kelas6
        }
    }

    @IBAction private func undoDetil(_ sender: Any) {
        if ((undoManager?.canUndo) != nil) {
            undoManager?.undo()
        }
    }
    @IBAction private func redoDetil(_ sender: Any) {
        if ((undoManager?.canRedo) != nil) {
        undoManager?.redo()
        }
    }
    
    // Fungsi untuk mereset target dan action menu item ke nilai aslinya
    func resetMenuItems() {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
              let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
              let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" }) else {
            return
        }

        // Kembalikan target dan action ke nilai aslinya
        undoMenuItem.target = SingletonData.originalUndoTarget
        undoMenuItem.action = SingletonData.originalUndoAction
        redoMenuItem.target = SingletonData.originalRedoTarget
        redoMenuItem.action = SingletonData.originalRedoAction
        copyMenuItem.target = SingletonData.originalCopyTarget
        copyMenuItem.action = SingletonData.originalCopyAction
        copyMenuItem.isEnabled = activeTable()!.numberOfSelectedRows != 0
        pasteMenuItem.target = SingletonData.originalPasteTarget
        pasteMenuItem.action = SingletonData.originalPasteAction
        deleteMenuItem.target = SingletonData.originalDeleteTarget
        deleteMenuItem.action = SingletonData.originalDeleteAction
    }
    var undoArray: [OriginalData] = []
    var redoArray: [OriginalData] = []
    var originalModel: OriginalData?

    @objc func updateUndoRedo(_ sender: Any?) {
        if !deletedDataArray.isEmpty || !pastedData.isEmpty {
            dataButuhDisimpan = true
            if tmblSimpan.image != NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none) {
                tmblSimpan.image = NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none)
            }
        } else {
            dataButuhDisimpan = false
            if tmblSimpan.image != NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none) {
                tmblSimpan.image = NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none)
            }
        }
    }
    var undoUpdateStack: [String: [[KelasModels]]] = [:] // Key adalah nama kelas,
    @IBOutlet weak var redoButton: NSButton!
    @IBOutlet weak var undoButton: NSButton!
    @objc private func handleSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["deletedStudentIDs"] as? [Int64],
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let isDeleted = userInfo["isDeleted"] as? Bool {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false
            guard let siswaID = siswa?.id, deletedIDs.contains(siswaID) else {
                return
            }
            if isDeleted && hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
                    tmblTambah.isEnabled = false
                    let text = "Nama Siswa"
                    let attributedString = NSMutableAttributedString(string: text)
                    // Menambahkan atribut strikethrough
                    attributedString.addAttributes([
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ], range: NSMakeRange(0, text.count))
                    // Mengatur attributed string ke NSTextField
                    namaSiswa.attributedStringValue = attributedString
                    
                    namaSiswa.isEnabled = false
                    tmblSimpan.isEnabled = false
                    undoButton.isEnabled = false
                    redoButton.isEnabled = false
                    statistik.isEnabled = false
                    imageView.isEnabled = false
                    opsiSiswa.isEnabled = false
                    kelasSC.isEnabled = false
                    nilaiKelasAktif.isEnabled = false
                    smstr.isEnabled = false
                    alert.window.close()
                    for (table, _) in tableInfo {
                        table.isEnabled = false
                    }
                }
            }
            var modifiableModel: [KelasModels] = []
            TableType.fromString(kelasSekarang) { kelas in
                switch kelas {
                case .kelas1:
                    modifiableModel = viewModel.kelas1Model
                case .kelas2:
                    modifiableModel = viewModel.kelas2Model
                case .kelas3:
                    modifiableModel = viewModel.kelas3Model
                case .kelas4:
                    modifiableModel = viewModel.kelas4Model
                case .kelas5:
                    modifiableModel = viewModel.kelas5Model
                case .kelas6:
                    modifiableModel = viewModel.kelas6Model
                }
                guard let table = getTableView(for: kelas.rawValue) else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang, isDeleted: isDeleted, hapusSiswa: hapusSiswa, hapusData: false, naikKelas: false)
                _ = viewModel.setModel(kelas, model: modifiableModel)
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    private func updateRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String, isDeleted: Bool, hapusSiswa: Bool, hapusData: Bool, naikKelas: Bool) {
        var indexesToUpdate = IndexSet()
        var indexesToDelete = IndexSet()
        var itemsToDelete: [KelasModels] = []
        // Simpan state model sebelum penghapusan untuk undo
        if undoUpdateStack[kelasSekarang] == nil {
            undoUpdateStack[kelasSekarang] = []
        }
        if isDeleted == true {
            undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels })
        }
        if hapusData == true && naikKelas == false {
        undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })
        }
        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if hapusData == false {
                if deletedIDs.contains(item.siswaID) {
                    if hapusSiswa == true {
                        indexesToDelete.insert(index)
                        itemsToDelete.append(item)
                    } else {
                        
                        model[index].namasiswa = ""
                        indexesToUpdate.insert(index)
                        
                    }
                }
            } else if naikKelas == true {
                if deletedIDs.contains(item.siswaID) {
                    
                    model[index].namasiswa = ""
                    
                    indexesToUpdate.insert(index)
                }
            } else {
                if deletedIDs.contains(item.kelasID) {
                    
                    model[index].namasiswa = ""
                    indexesToUpdate.insert(index)
                    
                }
            }
        }
            
        
        // Hapus data dari model
        if hapusSiswa == true {
            for index in indexesToDelete.sorted(by: >) {
                TableType.fromString(kelasSekarang) { kelas in
                    viewModel.removeData(index: index, tableType: kelas)
                }
            }
            model.removeAll { item in deletedIDs.contains(item.siswaID) }
            
            
            
            OperationQueue.main.addOperation { [weak self] in
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
                self?.updateSemesterTeks()
            }
        } else {
            OperationQueue.main.addOperation { [weak self] in
                tableView.reloadData(forRowIndexes: indexesToUpdate, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
                self?.updateSemesterTeks()
            }
        }
    }
    @objc private func handleUndoSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let kelasSekarang = userInfo["kelasSekarang"] as? String {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false
            
            if hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
                    self.tmblTambah.isEnabled = true
                    let text = "\(siswa?.nama ?? "")"
                    let attributedString = NSMutableAttributedString(string: text)
                    // Menambahkan atribut strikethrough
                    attributedString.addAttributes([
                        .foregroundColor: NSColor.textColor
                    ], range: NSMakeRange(0, text.count))
                    namaSiswa.attributedStringValue = attributedString
                    namaSiswa.isEnabled = true
                    tmblSimpan.isEnabled = true
                    undoButton.isEnabled = true
                    redoButton.isEnabled = true
                    statistik.isEnabled = true
                    imageView.isEnabled = true
                    opsiSiswa.isEnabled = true
                    kelasSC.isEnabled = true
                    nilaiKelasAktif.isEnabled = true
                    smstr.isEnabled = true
                    for (table, _) in tableInfo {
                        table.isEnabled = true
                    }
                }
            }
            switch kelasSekarang {
            case "Kelas 1":
                let model = viewModel.kelas1Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 2":
                let model = viewModel.kelas2Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table2, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 3":
                let model = viewModel.kelas3Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table3, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 4":
                let model = viewModel.kelas4Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table4, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 5":
                let model = viewModel.kelas5Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table5, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 6":
                let model = viewModel.kelas6Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table6, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            default:
                break
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    private func undoUpdateRows(from model: inout [KelasModels], tableView: NSTableView, kelasSekarang: String, hapusSiswa: Bool, hapusData: Bool) {
        guard var undoStackForKelas = undoUpdateStack[kelasSekarang], !undoStackForKelas.isEmpty else { return }
        let sortDescriptor = KelasModels.siswaSortDescriptor ?? NSSortDescriptor(key: "mapel", ascending: true)
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        undoUpdateStack[kelasSekarang] = undoStackForKelas // Perbarui stack undo

        var insertionIndexes = IndexSet()
        
        tableView.beginUpdates()
        for deletedData in previousState.sorted() {
            if hapusSiswa == true {
                TableType.fromString(kelasSekarang) { kelas in
                    guard let insertIndex = viewModel.insertData(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
                    insertionIndexes.insert(insertIndex)
                    tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                }
            } else if hapusSiswa == false || hapusData == true {
                TableType.fromString(kelasSekarang) { kelas in
                    viewModel.updateModel(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor)
                    let table = kelas.stringValue.replacingOccurrences(of: " ", with: "").lowercased()
                    dbController.undoHapusDataKelas(kelasID: deletedData.kelasID, fromTabel: Table("\(table)"), siswa: deletedData.namasiswa)
                }
            }
        }
        tableView.endUpdates()
        // Update table view untuk menampilkan baris yang diinsert
        if hapusSiswa == false {
            
            tableView.reloadData(forRowIndexes: insertionIndexes, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    var undoStack: [TableType: [[KelasModels]]] = [:] // Key adalah nama kelas,
//    @objc private func handleKelasDihapusNotification(_ notification: Notification) {
//        // Ambil informasi dari notifikasi
//        if let userInfo = notification.userInfo,
//           let tableType = userInfo["tableType"] as? TableType,
//           let deletedKelasIDs = userInfo["deletedKelasIDs"] as? [Int64] {
//            // Pilih model berdasarkan tableType dan hapus baris yang sesuai
//            switch tableType {
//            case .kelas1:
//                let model = viewModel.kelas1Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table1, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 1", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table1, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 1", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                    deleteKelasRows(from: &modifiableModel, tableView: table1, tableType: .kelas1, deletedKelasIDs: deletedKelasIDs)
//                    
//                }
//                viewModel.kelas1Model = modifiableModel as! [Kelas1Model]
//            case .kelas2:
//                let model = viewModel.kelas2Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table2, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 2", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table2, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 2", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                    deleteKelasRows(from: &modifiableModel, tableView: table2, tableType: .kelas2, deletedKelasIDs: deletedKelasIDs)
//                }
//                viewModel.kelas2Model = modifiableModel as! [Kelas2Model]
//            case .kelas3:
//                let model = viewModel.kelas3Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table3, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 3", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table3, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 3", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                deleteKelasRows(from: &modifiableModel, tableView: table3, tableType: .kelas3, deletedKelasIDs: deletedKelasIDs)
//                }
//                viewModel.kelas3Model = modifiableModel as! [Kelas3Model]
//            case .kelas4:
//                let model = viewModel.kelas4Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table4, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 4", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table4, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 4", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                deleteKelasRows(from: &modifiableModel, tableView: table4, tableType: .kelas4, deletedKelasIDs: deletedKelasIDs)
//                }
//                viewModel.kelas4Model = modifiableModel as! [Kelas4Model]
//            case .kelas5:
//                let model = viewModel.kelas5Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table5, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 5", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table5, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 5", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                deleteKelasRows(from: &modifiableModel, tableView: table5, tableType: .kelas5, deletedKelasIDs: deletedKelasIDs)
//                }
//                viewModel.kelas5Model = modifiableModel as! [Kelas5Model]
//            case .kelas6:
//                let model = viewModel.kelas6Model
//                var modifiableModel: [KelasModels] = model
//                if let hapusData = userInfo["hapusData"] as? Bool {
//                    guard hapusData == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table6, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 6", isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
//                    
//                } else if let naikKelas = userInfo["naikKelas"] as? Bool {
//                    guard naikKelas == true else {return}
//                    updateRows(from: &modifiableModel, tableView: table6, deletedIDs: deletedKelasIDs, kelasSekarang: "Kelas 6", isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
//                    
//                } else {
//                    deleteKelasRows(from: &modifiableModel, tableView: table6, tableType: .kelas6, deletedKelasIDs: deletedKelasIDs)
//                }
//                viewModel.kelas6Model = modifiableModel as! [Kelas6Model]
//            }
//        }
//    }
    @objc private func handleKelasDihapusNotification(_ notification: Notification) {
        // Ambil informasi dari notifikasi
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let deletedKelasIDs = userInfo["deletedKelasIDs"] as? [Int64] {
            
            // Pilih model berdasarkan tableType dan lakukan operasi yang sesuai
            var modifiableModel: [KelasModels] = []
            
            switch tableType {
            case .kelas1:
                modifiableModel = viewModel.kelas1Model
            case .kelas2:
                modifiableModel = viewModel.kelas2Model
            case .kelas3:
                modifiableModel = viewModel.kelas3Model
            case .kelas4:
                modifiableModel = viewModel.kelas4Model
            case .kelas5:
                modifiableModel = viewModel.kelas5Model
            case .kelas6:
                modifiableModel = viewModel.kelas6Model
            }
            guard let table = getTableView(for: tableType.rawValue) else { return }
            
            // Cek apakah hapus data atau naik kelas
            if let hapusData = userInfo["hapusData"] as? Bool {
                guard hapusData == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)
                
            } else if let naikKelas = userInfo["naikKelas"] as? Bool {
                guard naikKelas == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)
                
            } else {
                deleteKelasRows(from: &modifiableModel, tableView: table, tableType: tableType, deletedKelasIDs: deletedKelasIDs)
                
            }
            
            // Update model menggunakan setModel
            _ = viewModel.setModel(tableType, model: modifiableModel)
        }
    }

    private func deleteKelasRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType, deletedKelasIDs: [Int64]) {
        var indexesToDelete = IndexSet()
        // Temukan indeks dari kelasID di model
        if undoStack[tableType] == nil {
            undoStack[tableType] = []
        }
        
        undoStack[tableType]?.append(model.filter { deletedKelasIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })

        for (index, item) in model.enumerated() {
            if deletedKelasIDs.contains(item.kelasID) {
                indexesToDelete.insert(index) // Tambahkan indeks ke IndexSet untuk penghapusan
            }
        }
        // Hapus data dari model
        model.removeAll { item in
            deletedKelasIDs.contains(item.kelasID)
        }
        
        // Hapus baris dari NSTableView
        if !indexesToDelete.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    @objc private func handleUndoKelasDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let id = userInfo["deletedKelasIDs"] as? [Int64] {
            switch tableType {
            case .kelas1:
                let model = viewModel.kelas1Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: "Kelas 1", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table1, tableType: tableType, idBaru: id)
                }
            case .kelas2:
                let model = viewModel.kelas2Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table2, kelasSekarang: "Kelas 2", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table2, tableType: tableType, idBaru: id)
                }
            case .kelas3 :
                let model = viewModel.kelas3Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table3, kelasSekarang: "Kelas 3", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table3, tableType: tableType, idBaru: id)
                }
            case .kelas4 :
                let model = viewModel.kelas4Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table4, kelasSekarang: "Kelas 4", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table4, tableType: tableType, idBaru: id)
                }
            case .kelas5 :
                let model = viewModel.kelas5Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table5, kelasSekarang: "Kelas 5", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table5, tableType: tableType, idBaru: id)
                }
            case .kelas6 :
                let model = viewModel.kelas6Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else {return}
                    undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: "Kelas 1", hapusSiswa: false, hapusData: hapusData)
                    
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table6, tableType: tableType, idBaru: id)
                }
            }
        } else {
            
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    private func undoDeleteRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType, idBaru: [Int64]) {
        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
        guard var undoStackForKelas = undoStack[tableType], let sortDescriptor = KelasModels.siswaSortDescriptor, !undoStackForKelas.isEmpty else { return }
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        undoStack[tableType] = undoStackForKelas // Perbarui stack undo

        var insertionIndexes = IndexSet()
        for deletedData in previousState.sorted() {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            insertionIndexes.insert(insertionIndex)
        }
        // Update table view untuk menampilkan baris yang diinsert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tableView.beginUpdates()
            tableView.insertRows(at: insertionIndexes, withAnimation: .slideDown)
            tableView.endUpdates()
            DispatchQueue.main.async { [unowned self] in
                updateSemesterTeks()
            }
        }
    }
    @objc private func handleUndoUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newKelasID = userInfo["updatedID"] as? Int64,
              let oldKelasID = userInfo["oldKelasID"] as? Int64 else { return }
        
        // Cari kelasID lama di undoArray dan perbarui dengan kelasID baru
        if let index = undoArray.firstIndex(where: { $0.kelasId == oldKelasID }) {
            undoArray[index].kelasId = newKelasID
            
        } else {
            
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
    var dataButuhDisimpan = false
    func shouldAllowWindowClose() -> Bool {
        return !dataButuhDisimpan
    }
    
    @objc func receivedSaveDataNotification(_ notification: Notification) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {return}
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = 0.3
            namaSiswa.animator().alphaValue = 0
        }, completionHandler: { [unowned self] in
            // Menghapus data dari deletedDataArray
            for deletedData in deletedDataArray {
                let currentClassTable = deletedData.table
                let dataArray = deletedData.data
                
                for data in dataArray {
                    dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                }
            }
            
            // Menghapus data dari pastedData
            for pastedDataItem in pastedData {
                let currentClassTable = pastedDataItem.table
                let dataArray = pastedDataItem.data
                
                for data in dataArray {
                    dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                }
            }
            
            saveData(self)
            dataButuhDisimpan = false
            
            // Menjalankan animasi untuk menunjukkan perubahan
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                context.duration = 0.3
                namaSiswa.animator().alphaValue = 1
                namaSiswa.animator().stringValue = "Perubahan telah disimpan"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.namaSiswa.animator().alphaValue = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.namaSiswa.animator().alphaValue = 1
                        self.namaSiswa.stringValue = self.siswa?.nama ?? ""
                    }
                }
            }, completionHandler: nil)
        })
    }

    @objc func processDatabaseOperations(completion: @escaping () -> Void) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            return
        }
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan akan disimpan. Lanjutkan?"
        alert.informativeText = "Data yang telah dihapus/diedit tidak dapat diurungkan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [self] (response) in
                if response == .alertFirstButtonReturn {
                    self.performDatabaseOperations {
                        completion()
                    }
                } else {
                    self.dataButuhDisimpan = true
                    return
                }
            }
        }
    }
    private func performDatabaseOperations(completion: @escaping () -> Void) {
        let storyboard = NSStoryboard.init(name: "ProgressBar", bundle: nil)
        guard let windowProgress = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let viewController = windowProgress.contentViewController as? ProgressBarVC else {return}
        bgTask.addOperation {
            OperationQueue.main.addOperation { [weak self] in
                guard let self = self else {return}
                if let windowSheet = NSApplication.shared.mainWindow {
                    viewController.progressIndicator.isIndeterminate = true
                    viewController.progressIndicator.startAnimation(self)
                    windowSheet.beginSheet(windowProgress.window!)
                    self.bgTask.addOperation { [unowned self] in
                        for deletedData in self.deletedDataArray {
                            let currentClassTable = deletedData.table
                            let dataArray = deletedData.data

                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }

                        // Loop melalui pastedData
                        for pastedDataItem in self.pastedData {
                            let currentClassTable = pastedDataItem.table
                            let dataArray = pastedDataItem.data

                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                        OperationQueue.main.addOperation { [unowned self] in
                            self.saveData(self)
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] timer in
                                self?.dataButuhDisimpan = false
                                windowProgress.close()
                                windowSheet.endSheet(windowProgress.window!)
                                timer.invalidate()
                                completion()
                            })
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        #if DEBUG
        print("deinit detailSiswaViewController")
        #endif
        topLevelObjects = nil
        viewModel.removeAllData()
        for (table, _) in tableInfo {
            table.menu = nil
            table.target = nil
            table.dataSource = nil
            table.delegate = nil
            table.headerView = nil
            table.removeFromSuperviewWithoutNeedingDisplay()
            suggestionManager = nil
        }
        table1 = nil
        table2 = nil
        table3 = nil
        table4 = nil
        table5 = nil
        table6 = nil
        siswa = nil
        siswaData.removeAll()
        viewModel.clearState()
        tableData.removeAll()
        tabView.removeFromSuperviewWithoutNeedingDisplay()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .siswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .kelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoKelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateUndoArray, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editDataSiswaKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editNamaGuruKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .saveData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .dataSiswaDiEditDiSiswaView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateDataKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: .addDetilSiswaUITertutup, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.removeObserver(self, name: .findInsertedKelasIdFromKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidReloadNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        view.removeFromSuperviewWithoutNeedingDisplay()
    }
}
extension DetailSiswaController {
    private func deleteRedoArray(_ sender: Any) {
        if !redoArray.isEmpty {redoArray.removeAll()}
        if !kelasID.isEmpty {kelasID.removeAll()}
    }
    private func undoAction(originalModel: OriginalData) {
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        if let rowIndexToUpdate = viewModel.kelasModelForTable(originalModel.tableType).firstIndex(where: { $0.kelasID == originalModel.kelasId }) {
            // Lakukan pembaruan model dan database dengan nilai lama
            updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(originalModel.tableType), table: originalModel.table, tableView: originalModel.tableView, kelasId: originalModel.kelasId, undo: true)
            
            // Daftarkan aksi redo ke NSUndoManager
            undoManager?.beginUndoGrouping()
            undoManager?.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
                self?.redoAction(originalModel: originalModel)
            })
            undoManager?.endUndoGrouping()
            
            // Hapus nilai lama dari array undo
            undoArray.removeAll(where: { $0 == originalModel })
            
            // Mendapatkan columnIdentifier dan columnIndex
            let columnIdentifier = originalModel.columnIdentifier
            if let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) {
                // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                guard columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count else { return }
                
                // Mendapatkan sel yang diperbarui
                if let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView {
                    // Mendapatkan nilai status dari originalModel
                    let newString = originalModel.newValue
                    cellView.textField?.stringValue = newString
                    // Perbarui tampilan tabel hanya untuk baris yang diubah
                    originalModel.tableView.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
                    originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
                    originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)
                }
            }
            
            // Simpan nilai lama ke dalam array redo
            redoArray.append(originalModel)
            updateUndoRedo(self)
            updateSemesterTeks()
//            NotificationCenter.default.post(name: .updateNilaiTeks, object: nil)
        }
    }
    private func redoAction(originalModel: OriginalData) {
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        if let rowIndexToUpdate = viewModel.kelasModelForTable(originalModel.tableType).firstIndex(where: { $0.kelasID == originalModel.kelasId }) {
            // Lakukan pembaruan model dan database dengan nilai baru
            updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.newValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(originalModel.tableType), table: originalModel.table, tableView: originalModel.tableView, kelasId: originalModel.kelasId, undo: true)
            
            // Daftarkan aksi undo ke NSUndoManager
            undoManager?.beginUndoGrouping()
            undoManager?.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
                self?.undoAction(originalModel: originalModel)
            })
            undoManager?.endUndoGrouping()
            
            // Hapus nilai lama dari array redo
            redoArray.removeAll(where: { $0 == originalModel })
            
            // Mendapatkan columnIdentifier dan columnIndex
            let columnIdentifier = originalModel.columnIdentifier
            if let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) {
                // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                guard columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count else { return }
                
                // Mendapatkan sel yang diperbarui
                if let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView {
                    // Mendapatkan nilai status dari originalModel
                    let newString = originalModel.newValue
                    cellView.textField?.stringValue = newString
                    // Perbarui tampilan tabel hanya untuk baris yang diubah
                    originalModel.tableView.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
                    originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
                    originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)
                }
            }
            
            // Simpan nilai baru ke dalam array undo
            undoArray.append(originalModel)
            updateUndoRedo(self)
            updateSemesterTeks()
//            NotificationCenter.default.post(name: .updateNilaiTeks, object: nil)
        }
    }
    @objc private func updateEditedKelas(_ notification: Notification) {
        var table: EditableTableView!
        guard let userInfo = notification.userInfo as? [String: Any],
              let columnIdentifier = userInfo["columnIdentifier"] as? String,
              let activeTable = userInfo["tableView"] as? String,
              let newValue = userInfo["newValue"] as? String,
              let kelasId = userInfo["kelasId"] as? Int64 else {
            return
        }
        switch activeTable {
        case "table1": table = self.table1
        case "table2": table = self.table2
        case "table3": table = self.table3
        case "table4": table = self.table4
        case "table5": table = self.table5
        case "table6": table = self.table6
        default: break
        }
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(table)).firstIndex(where: { $0.kelasID == kelasId }) else {return}
        guard let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else {return}
        guard let cellView = table.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView else {return}
        updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(table)), tableView: table, kelasId: kelasId)
        if columnIdentifier == "nilai" {
            let numericValue = Int(newValue) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }
        table.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
    }
    @objc private func updatedGuruKelas(_ notification: Notification) {
        var table: EditableTableView!
        guard let userInfo = notification.userInfo as? [String: Any],
              let columnIdentifier = userInfo["columnIdentifier"] as? String,
              let activeTable = userInfo["tableView"] as? String,
              let newValue = userInfo["newValue"] as? String,
              let guruLama = userInfo["guruLama"] as? String,
              let currentMapel = userInfo["mapel"] as? String else {
            
            return
        }
        switch activeTable {
        case "table1": table = self.table1
        case "table2": table = self.table2
        case "table3": table = self.table3
        case "table4": table = self.table4
        case "table5": table = self.table5
        case "table6": table = self.table6
        default: break
        }
        var columnIndex = Int()
        guard table != nil else {
            return
        }
        DispatchQueue.main.async {
            guard let index = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else {return}
            columnIndex = index
        }
        let modelArray = viewModel.kelasModelForTable(tableTypeForTable(table))
        if UserDefaults.standard.bool(forKey: "updateNamaGuruDiMapelDanKelasSama") {
            for (index, data) in modelArray.enumerated() {
                let mapel = data.mapel
                let namaGuru = data.namaguru
                if mapel == currentMapel {
                    guard namaGuru != newValue, !data.namasiswa.isEmpty else {continue}
                    if !UserDefaults.standard.bool(forKey: "timpaNamaGuruSebelumnya") {
                        guard namaGuru == guruLama else {continue}
                    }
                    viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: index, newValue: newValue, modelArray: modelArray, tableView: table, kelasId: data.kelasID)
                }
                DispatchQueue.main.async {
                    table.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: columnIndex))
                }
            }
        } else {
            guard let ID = userInfo["kelasId"] as? Int64,
                  let index = modelArray.firstIndex(where: {$0.kelasID == ID}),
                  modelArray[index].namaguru != newValue else { return }
            viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: index, newValue: newValue, modelArray: modelArray, tableView: table, kelasId: ID)
            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: IndexSet([index]), columnIndexes: IndexSet([columnIndex]))
            }
        }
    }
    private func updateKelasModel(columnIdentifier: String, rowIndex: Int, newValue: String, modelArray: [KelasModels], tableView: NSTableView, kelasId: Int64) {
        for (index, data) in modelArray.enumerated() {
            if data.kelasID == kelasId {
                viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: index, newValue: newValue, modelArray: modelArray, tableView: tableView, kelasId: kelasId)
            }
        }
    }
    private func updateModelAndDatabase(columnIdentifier: String, rowIndex: Int, newValue: String, oldValue: String, modelArray: [KelasModels], table: Table, tableView: NSTableView, kelasId: Int64, undo: Bool = false) {
        let namaTable = createStringForActiveTable()
        switch columnIdentifier {
        case "mapel":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].mapel = newValue
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: newValue, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: modelArray[rowIndex].semester, table: table)
            }
            
        case "nilai":
            // Handle editing for "nilai" columns
            if rowIndex < modelArray.count {
                if let newValueAsInt64 = Int64(newValue), !newValue.isEmpty {
                    var updatedNilaiValue = modelArray[rowIndex].nilai
                    updatedNilaiValue = newValueAsInt64
                    modelArray[rowIndex].nilai = updatedNilaiValue
                    dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: updatedNilaiValue, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: modelArray[rowIndex].semester, table: table)
                } else {
                    dbController.deleteNilaiFromKelas(table: table, kelasID: modelArray[rowIndex].kelasID)
                    modelArray[rowIndex].nilai = 0
                }
            }
        case "semester":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].semester = newValue
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: newValue, table: table)
            }
        case "namaguru":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].namaguru = newValue
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: newValue, semesterValue: modelArray[rowIndex].semester, table: table)
            }
            guard !undo else { return}
            if UserDefaults.standard.bool(forKey: "tambahkanDaftarGuruBaru") == true {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.2) {
                    self.dbController.addGuruMapel(namaGuruValue: newValue)
                    NotificationCenter.default.post(name: DatabaseController.guruDidChangeNotification, object: nil)
                }
            }
        default:
            break
        }
        NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": namaTable , "newValue": newValue, "kelasId": kelasId])
    }
    @objc private func updateInsertedKelasId(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let kelasId = userInfo["InsertedKelasIdTuple"] as? (Int64, [Int64]) else {
            return
        }
        
//        let id = kelasId.0
        let allIDs = kelasId.1
        for data in allIDs {
            if let index = undoArray.firstIndex(where: { $0.kelasId == data }) {
                undoArray[index].kelasId = data
                
            } else {
                
            }
        }
    }
    @objc private func updateDeletedData(_ notification: Notification) {
//        guard let userInfo = notification.userInfo, let dataArray = userInfo["DeletedData"] as? [(index: Int, data: KelasModels)] else {
//            return
//        }
    }
    private func getOldValueForColumn(tableType: TableType, rowIndex: Int, columnIdentifier: String, modelArray: [KelasModels], table: Table) -> String {
        guard !modelArray.isEmpty && rowIndex >= 0 else {return ""}
        switch columnIdentifier {
        case "mapel":
            return modelArray[rowIndex].mapel
        case "nilai":
            return String(modelArray[rowIndex].nilai)
        case "semester":
            return modelArray[rowIndex].semester
        case "namaguru":
            return modelArray[rowIndex].namaguru
        default:
            return ""
        }
    }
   private func activeTable() -> EditableTableView? {
        if table1.isDescendant(of: self.view) {
            return table1
        } else if table2.isDescendant(of: self.view) {
            return table2
        } else if table3.isDescendant(of: self.view) {
            return table3
        } else if table4.isDescendant(of: self.view) {
            return table4
        } else if table5.isDescendant(of: self.view) {
            return table5
        } else if table6.isDescendant (of: self.view) {
            return table6
        }
        return nil
    }

    private func tableTypeForTable(_ table: NSTableView) -> TableType {
        if table == table1 {
            return .kelas1
        } else if table == table2 {
            return .kelas2
        } else if table == table3 {
            return .kelas3
        } else if table == table4 {
            return .kelas4
        } else if table == table5 {
            return .kelas5
        } else if table == table6 {
            return .kelas6
        }
        return .kelas1 // Gantilah dengan nilai default yang sesuai jika perlu.
    }
    private func activateTable(_ table: NSTableView) {
        switch table {
        case table1: tabView.selectTabViewItem(at: 0); kelasSC.selectSegment(withTag: 0)
        case table2: tabView.selectTabViewItem(at: 1); kelasSC.selectSegment(withTag: 1)
        case table3: tabView.selectTabViewItem(at: 2); kelasSC.selectSegment(withTag: 2)
        case table4: tabView.selectTabViewItem(at: 3); kelasSC.selectSegment(withTag: 3)
        case table5: tabView.selectTabViewItem(at: 4); kelasSC.selectSegment(withTag: 4)
        case table6: tabView.selectTabViewItem(at: 5); kelasSC.selectSegment(withTag: 5)
        default: break
        }
        let nabila = kelasSC.selectedSegment; let salsabila = "Kelas \(nabila + 1)"
        if kelasSC.label(forSegment: nabila) != nil {
            kelasSC.setLabel("\(salsabila)", forSegment: nabila)
        }
        for segmentIndex in 0..<kelasSC.segmentCount {
            if segmentIndex != nabila {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
    }
    
    private func createLabelForActiveTable() -> String {
        if let activeTable = activeTable() {
            // Mendapatkan label sesuai dengan tabel aktif
            switch activeTable {
            case table1:
                return "Kelas 1"
            case table2:
                return "Kelas 2"
            case table3:
                return "Kelas 3"
            case table4:
                return "Kelas 4"
            case table5:
                return "Kelas 5"
            case table6:
                return "Kelas 6"
            default:
                return "Tabel Aktif Tidak Memiliki Nama"
            }
        }
        return "Tabel Aktif Tidak Memiliki Nama"
    }
    
    private func createStringForActiveTable() -> String {
        if let activeTable = activeTable() {
            // Mendapatkan label sesuai dengan tabel aktif
            switch activeTable {
            case table1:
                return "table1"
            case table2:
                return "table2"
            case table3:
                return "table3"
            case table4:
                return "table4"
            case table5:
                return "table5"
            case table6:
                return "table6"
            default:
                return "Tabel Aktif Tidak Memiliki Nama"
            }
        }
        return "Tabel Aktif Tidak Memiliki Nama"
    }
}
extension DetailSiswaController {
    @objc func handleNamaSiswaDiedit(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["updateStudentIDs"] as? Int64,
           let namaBaru = userInfo["namaSiswa"] as? String {
            
            guard deletedIDs == siswa?.id else { return }
            
            if let kelasSekarang = userInfo["kelasSekarang"] as? String {
                TableType.fromString(kelasSekarang) { kelas in
                    _ = viewModel.findAllIndices(for: kelas, matchingID: deletedIDs, namaBaru: namaBaru)
                }
                
                DispatchQueue.main.async { [unowned self] in
                    namaSiswa.stringValue = namaBaru
                }
                
            }
        }
    }
    @IBAction private func increaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight += 5
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
            })
        }
    }
    @IBAction private func decreaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight = max(tableView.rowHeight - 3, 16)
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
            })
        }
    }
}

extension DetailSiswaController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let table = activeTable() else { return }
        
        if menu == smstr.menu {
            let selectedSemester = smstr.titleOfSelectedItem
            populateSemesterPopUpButton()
            if selectedSemester != nil {
                smstr.selectItem(withTitle: selectedSemester!)
            }
            return
        }
        
        self.view.window?.makeFirstResponder(table)
        
        if menu == shareMenu {
            let pdf = menu.items.first(where: {$0.identifier?.rawValue == "exportPDF"})
            pdf?.representedObject = (table, tableTypeForTable(table))
            
            let xcl = menu.items.first(where: {$0.identifier?.rawValue == "exportExcel"})
            xcl?.representedObject = (table, tableTypeForTable(table))
            
            return
        }
        
        let salin = menu.item(at: 2)
        let hapus = menu.item(at: 5)
        
        guard table.clickedRow >= 0 else {
            for i in 0..<menu.items.count {
                let menuItem = menu.item(at: i)
                if i == 5 || i == 2  {
                    menuItem?.isHidden = true
                } else {
                    menuItem?.isHidden = false
                }
            }
            return
        }
        for i in 0..<menu.items.count {
            let menuItem = menu.item(at: i)
            menuItem?.isHidden = false
        }
        if table.selectedRowIndexes.contains(table.clickedRow) {
            salin?.title = "Salin \(table.numberOfSelectedRows) data..."
            hapus?.title = "Hapus \(table.numberOfSelectedRows) data..."
        } else {
            salin?.title = "Salin 1 data..."
            hapus?.title = "Hapus 1 data..."
        }
    }
}


extension DetailSiswaController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard let activeTable = self.activeTable(),
              !viewModel.kelasModelForTable(tableTypeForTable(activeTable)).isEmpty,
              let table = SingletonData.dbTable(forTableType: tableTypeForTable(activeTable)) else {return}
        
            let columnIdentifier = activeTable.tableColumns[column].identifier.rawValue
            var newValue = newText
            let selectedTabView = tabView.selectedTabViewItem!
                switch columnIdentifier {
                case "mapel", "semester", "namaguru":
                    let oldValue = getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table)
                    if newValue != oldValue {
                        let kelasId = viewModel.kelasModelForTable(tableTypeForTable(activeTable))[row].kelasID
                        let updatedValue = newValue.capitalizedAndTrimmed()
                        newValue = updatedValue
                        // Simpan originalModel untuk undo
                        let originalModel = OriginalData(kelasId: kelasId, tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue, table: table, tableView: activeTable)
                        
                        updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table, tableView: activeTable, kelasId: kelasId, undo: false)
                        
                        // Daftarkan aksi undo ke NSUndoManager
                        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
                            targetSelf.undoAction(originalModel: originalModel)
                        })
                        _ = originalModel
                        undoArray.append(originalModel)
                        updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabView), semesterName: smstr.titleOfSelectedItem ?? "")
//                            NotificationCenter.default.post(name: NSNotification.Name("UpdateUndoArrayKelas"), object: nil, userInfo: ["kelasID": kelasID, "columnIdentifier": columnIdentifier, "newValue": newValue])
                    }
                case "nilai":
                    let oldValue = getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table)
                    if newValue != oldValue {
                        // Dapatkan kelasId dari model data
                        let kelasId = viewModel.kelasModelForTable(tableTypeForTable(activeTable))[row].kelasID
                        // Simpan originalModel untuk undo dengan kelasId
                        let originalModel = OriginalData(
                            kelasId: kelasId, tableType: tableTypeForTable(activeTable),
                            rowIndex: row,
                            columnIdentifier: columnIdentifier,
                            oldValue: oldValue,
                            newValue: newValue,
                            table: table,
                            tableView: activeTable
                        )
                        
                        updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table, tableView: activeTable, kelasId: kelasId, undo: false)
                        
                        // Daftarkan aksi undo ke NSUndoManager
                        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
                            targetSelf.undoAction(originalModel: originalModel)
                        })
                        
                        _ = originalModel
                        undoArray.append(originalModel)
                        
                        let numericValue = Int(newValue) ?? 0
                        if let cell = activeTable.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                            cell.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
                        }
                        updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabView), semesterName: smstr.titleOfSelectedItem ?? "")
                    }
                default:
                    break
                }
                deleteRedoArray(self)
                updateUndoRedo(self)
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        guard let tableView = self.activeTable() else {
            return false
        }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        if columnIdentifier == "tgl" {
            return false
        }
        return true
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let tableView = self.activeTable(), let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView, let textField = cell.textField else {
            return ""
        }
        return textField.stringValue
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        return tableView.tableColumns[column].width
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        guard let activeTable = self.activeTable() else { return [] }
        let columnIdentifier = activeTable.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "mapel":
            return Array(ReusableFunc.mapel)
        case "namaguru":
            return Array(ReusableFunc.namaguru)
        case "semester":
            return Array(ReusableFunc.semester)
        default:
            return []
        }
    }
}
