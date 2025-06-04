//
//  Siswaviewcontroller.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa

enum TableViewMode: Int {
    case plain //  0
    case grouped // 1
}
class SiswaViewController: NSViewController, NSDatePickerCellDelegate, DetilWindowDelegate {
    @IBOutlet weak var tableView: EditableTableView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var namaColumn: NSTableColumn!
    @IBOutlet weak var alamatColumn: NSTableColumn!
    @IBOutlet weak var ttlColumn: NSTableColumn!
    @IBOutlet weak var tahunDaftarColumn: NSTableColumn!
    @IBOutlet weak var ortuColumn: NSTableColumn!
    @IBOutlet weak var nisColumn: NSTableColumn!
    @IBOutlet weak var kelaminColumn: NSTableColumn!
    @IBOutlet weak var statusColumn: NSTableColumn!
    @IBOutlet weak var tglLulusColumn: NSTableColumn!
    @IBOutlet weak var editItem: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    // @IBOutlet weak var kelasAktifMenu: NSMenu!
    @IBOutlet weak var hapusMenuItem: NSMenuItem!
    @IBOutlet weak var salinMenuItem: NSMenuItem!
    @IBOutlet var itemSelectedMenu: NSMenu!
    @IBOutlet var itemMenu: NSMenu!
    @IBOutlet var customViewMenu: NSView!
    @IBOutlet var customViewMenu2: NSView!
    lazy var useAlternateColor = true
    var previousColumnTitle: String = ""
    let dbController = DatabaseController.shared
    lazy var rowDipilih: [IndexSet] = []
    var undoEdit: [DataAsli] = []
    var redoEdit: [DataAsli] = []
    var viewModel = SiswaViewModel(dbController: DatabaseController.shared)
    
    var isSortedByFirstColumn = false
    
    var currentTableViewMode: TableViewMode = .plain {
        didSet {
            self.viewModel.isGrouped = currentTableViewMode == .grouped
        }
    }
    var deletedSiswa = ModelSiswa()
    lazy var columnNames = [""]
    var selectedSiswaList: [ModelSiswa] = []
    let kelasNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "Lulus", "Tanpa Kelas"]
    lazy var stringPencarian: String = ""
//    var headerCells = [NSTableColumn: NSCell]()  // Simpan header cell untuk setiap kolom
    let kolomTabelSiswa: [ColumnInfo] = [
        ColumnInfo(identifier: "Nama", customTitle: "Nama Siswa"),
        ColumnInfo(identifier: "Alamat", customTitle: "Alamat Siswa"),
        ColumnInfo(identifier: "T.T.L", customTitle: "Tempat Tgl. Lahir"),
        ColumnInfo(identifier: "Tahun Daftar", customTitle: "Tahun Daftar"),
        ColumnInfo(identifier: "Nama Wali", customTitle: "Nama Wali"),
        ColumnInfo(identifier: "NIS", customTitle: "NIK/NIS"),
        ColumnInfo(identifier: "Jenis Kelamin", customTitle: "Kelamin"),
        ColumnInfo(identifier: "Status", customTitle: "Status"),
        ColumnInfo(identifier: "Tgl. Lulus", customTitle: "Tgl. Berhenti"),
        ColumnInfo(identifier: "Ayah", customTitle: "Ayah Kandung"),
        ColumnInfo(identifier: "NISN", customTitle: "NISN"),
        ColumnInfo(identifier: "Ibu", customTitle: "Ibu Kandung"),
        ColumnInfo(identifier: "Nomor Telepon", customTitle: "Nomor Telepon")
    ]
    var isBerhentiHidden = UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
        didSet {
            UserDefaults.standard.setValue(isBerhentiHidden, forKey: "sembunyikanSiswaBerhenti")
        }
    }
    var kelasYangDikecualikanArray: [String] = []
    var snapshotSiswaStack: [[ModelSiswa]] = []
    var redoSnapshotSiswaStack: [[ModelSiswa]] = []
    var originalNewTarget: AnyObject?
    var originalNewAction: Selector?
    var pastedSiswasArray = [[ModelSiswa]]()
    var selectedImageData = Data()
    // var restoredSiswaArray: [ModelSiswa] = []
    var deletedIndexes = [[Int]]() // Array untuk menyimpan indeks yang dihapus secara bertahap
    var redoDeletedIndexes = [[Int]]()
    var redoDeletedSiswaArray = [[ModelSiswa]]() // Array untuk menyimpan data yang dihapus setelah melakukan undo
    let operationQueue = OperationQueue()
    var isDataLoaded: Bool = false
    var previouslySelectedRows: IndexSet = IndexSet()
    var urungsiswaBaruArray: [ModelSiswa] = []
    var ulangsiswaBaruArray: [ModelSiswa] = []
    var popover = NSPopover()
    var selectedIds: Set<Int64> = []
    
    var overlayEditor: OverlayEditorManager?
    
    
    var previewItems: [URL] = []
    var tempDir: URL?
    var isQuickLookActive = false
    var tabBarFrame: CGFloat = 0
    let headerMenu = NSMenu()
    var searchItem: DispatchWorkItem?
    let tagMenuItem2 = NSMenuItem()
    let tagMenuItem = NSMenuItem()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self

        // MARK: CUSTOM HEADER TITLE CELL
        previousColumnTitle = "Kelas 1"
        for columnInfo in kolomTabelSiswa {
            guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else {
                continue
            }
            let customHeaderCell = MyHeaderCell()
            customHeaderCell.title = columnInfo.customTitle
            column.headerCell = customHeaderCell
        }

        tableView.allowsColumnReordering = true
        tableView.doubleAction = #selector(detailSelectedRow(_:))
        tableView.allowsMultipleSelection = true
        NotificationCenter.default.addObserver(self, selector: #selector(receivedNotification(_:)), name: .dataSiswaDiEdit, object: nil)
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .utility
        if let savedMode = UserDefaults.standard.value(forKey: "tableViewMode") as? Int,
           let mode = TableViewMode(rawValue: savedMode) {
            currentTableViewMode = mode
        }
        setupDescriptor()
        if let sortDescriptor = loadSortDescriptor() {
            // Mengatur sort descriptor tabel
            tableView.sortDescriptors = [sortDescriptor]
        }
        self.setupTable()
        tableView.editAction = { [weak self] (row, column) in
            guard let self = self else { return }
            // Anda bisa menambahkan logika tambahan di sini jika perlu sebelum memanggil startEditing
            self.overlayEditor?.startEditing(row: row, column: column)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(self.view, isDataLoaded: false)
            guard let containingWindow = self.view.window else {
                // Ini seharusnya tidak terjadi jika ViewController ditampilkan dengan benar
                fatalError("TableView's view is not in a window.")
            }
            overlayEditor = OverlayEditorManager(tableView: tableView, containingWindow: containingWindow)
            overlayEditor?.dataSource = self
            overlayEditor?.delegate = self
            self.filterDeletedSiswa()
            self.updateHeaderMenuOrder()
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] timer in
            guard let self = self else {timer.invalidate(); return}
            self.updateUndoRedo(self)
            self.view.window?.makeFirstResponder(self.tableView)
            ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: self.stringPencarian)
//            if let window = self.view.window, let group = window.tabGroup, !group.isTabBarVisible, self.tabBarFrame == 25 {
//                DispatchQueue.main.async {
//                    self.scrollView.contentInsets.top = 38
//                    self.tabBarFrame = 0
//                    self.scrollView.layoutSubtreeIfNeeded()
//                    timer.invalidate()
//                }
//            } else if self.tabBarFrame != 25 {
//                if let window = self.view.window, let group = window.tabGroup, group.isTabBarVisible {
//                    self.scrollView.contentInsets.top += 25
//                    self.tabBarFrame = 25
//                    self.scrollView.layoutSubtreeIfNeeded()
//                    timer.invalidate()
//                }
//            }
        }
        toolbarItem()
        updateMenuItem(self)
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: .hapusCacheFotoKelasAktif, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePopupDismissed(_:)), name: .popupDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(siswaNaik(_:)), name: .siswaNaikDariKelasVC, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kelasAktifDiupdate(_:)), name: .kelasDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appNonAktif(_:)), name: .windowControllerResignKey, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appAktif(_:)), name: .windowControllerBecomeKey, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoActionNotification(_:)), name: .undoActionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(undoEditSiswa(_:)), name: .updateEditSiswa, object: nil)
        viewModel.isGrouped = currentTableViewMode == .grouped
        updateGroupMenuBar()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        cekQuickLook()
        NotificationCenter.default.removeObserver(self, name: .windowControllerResignKey, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .windowControllerBecomeKey, object: nil)
        ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: "")
        ReusableFunc.resetMenuItems()
        searchItem?.cancel()
        searchItem = nil
    }
    @objc private func saveData(_ notification: Notification) {
        guard isDataLoaded else { return }
        
        // Inisialisasi DispatchGroup
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self = self else { return }
            self.snapshotSiswaStack.removeAll()
            self.urungsiswaBaruArray.removeAll()
            self.undoEdit.removeAll()
            self.pastedSiswasArray.removeAll()
            self.deleteAllRedoArray(self)
            dispatchGroup.leave()
        }
        dispatchGroup.enter()
        dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) {
            self.filterDeletedSiswa()
            dispatchGroup.leave()
        }
        // Setelah semua tugas selesai
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    SiswaViewModel.siswaUndoManager.removeAllActions()
                    self.updateUndoRedo(self)
                }
            }
        }
    }
    
//    @objc func tabBarDidHide(_ notification: Notification) {
//        guard let window = self.view.window,
//           let tabGroup = window.tabGroup,
//           !tabGroup.isTabBarVisible else {
//            return
//        }
//        if self.tabBarFrame == 25 {
//            DispatchQueue.main.async {
//                self.scrollView.contentInsets.top = 38
//                self.tabBarFrame = 0
//            }
//        }
//    }
    
    @objc private func kelasAktifDiupdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tableType = userInfo["tableType"] as? TableType,
              let siswaIDs = userInfo["deletedKelasIDs"] as? [Int64],
              let naik = userInfo["naikKelas"] as? Bool,
              naik == true else {
            return
        }
        
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama"))
        
        // Tentukan kelas baru berdasarkan tableType
        let newKelas: String = {
            switch tableType {
            case .kelas1: return "Kelas 2"
            case .kelas2: return "Kelas 3"
            case .kelas3: return "Kelas 4"
            case .kelas4: return "Kelas 5"
            case .kelas5: return "Kelas 6"
            case .kelas6: return "Lulus"
            }
        }()
        
        // Update data siswa
        for (index, siswa) in viewModel.filteredSiswaData.enumerated() {
            guard siswaIDs.contains(siswa.id),
                  siswa.kelasSekarang != newKelas else { continue }
            siswa.kelasSekarang = newKelas
            
            // Update data siswa menggunakan method baru
            viewModel.updateSiswa(siswa, at: index)
            
            // Update UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                
                // Reload specific row
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: index),
                                          columnIndexes: IndexSet([columnIndexOfKelasAktif]))                
            }
        }
    }
    
    func filterDeletedSiswa() {
        guard let rawSortDescriptor = loadSortDescriptor() else { return }
        let descriptorWrapper = SortDescriptorWrapper.from(rawSortDescriptor)
        let isGrouped = self.currentTableViewMode != .plain
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            await self.viewModel.fetchSiswaData()
            await self.viewModel.filterDeletedSiswa(sortDescriptor: descriptorWrapper, group: isGrouped, filterBerhenti: self.isBerhentiHidden)
            
            await MainActor.run {
                if isGrouped {
                    self.updateGroupedUI()
                } else {
                    self.sortData(with: rawSortDescriptor)
                }
            }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if !self.isDataLoaded {
                    self.tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
                    self.tableView.registerForDraggedTypes([.tiff, .png, .fileURL, .string])
                    self.tableView.draggingDestinationFeedbackStyle = .regular
                    // Setup remaining UI components
                    self.suggestionManager = SuggestionManager(suggestions: [""])
                    
                    // Configure menus
                    let newMenu = self.itemSelectedMenu.copy() as! NSMenu
                    newMenu.delegate = self
                    self.itemSelectedMenu.delegate = self
                    
                    // Setup first custom menu
                    self.createCustomMenu()
                    let tagView = self.customViewMenu
                    self.customViewMenu.frame = NSRect(x: 0, y: 0, width: 224, height: 45)
                    self.tagMenuItem.view = tagView
                    self.tagMenuItem.target = self
                    self.tagMenuItem.identifier = NSUserInterfaceItemIdentifier("kelasAktif")
                    newMenu.insertItem(self.tagMenuItem, at: 21)
                    newMenu.insertItem(NSMenuItem.separator(), at: 22)
                    
                    // Setup second custom menu
                    self.createCustomMenu2()
                    let tagView2 = self.customViewMenu2
                    self.customViewMenu2.frame = NSRect(x: 0, y: 0, width: 224, height: 45)
                    self.tagMenuItem2.view = tagView2
                    self.tagMenuItem2.target = self
                    self.tagMenuItem2.identifier = NSUserInterfaceItemIdentifier("kelasAktif")
                    self.itemSelectedMenu.insertItem(self.tagMenuItem2, at: 21)
                    self.itemSelectedMenu.insertItem(NSMenuItem.separator(), at: 22)
                    self.tableView.menu = newMenu
                    if let window = self.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    self.isDataLoaded = true
                    
                }
            }
        }
    }
    
    // Fungsi pembaruan UI jika mode grup diaktifkan
    func updateGroupedUI() {
        tableView.gridStyleMask.remove(.solidVerticalGridLineMask)
        if let columnInfo = kolomTabelSiswa.first {
            if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) {
                column.title = "Kelas 1"
            }
        }
        if let sdsc = loadSortDescriptor() {
            self.sortData(with: sdsc)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    @objc private func handlePopupDismissed(_ sender: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [unowned self] in
            guard !rowDipilih.isEmpty else { return }
            if tableView.selectedRow > -1 {
                
            } else {
                for indexSet in rowDipilih {
                    self.tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            updateUndoRedo(self)
        }
    }
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }
        
        if column.identifier.rawValue == "Nama" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden
        
        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }
    private func toolbarItem() {
        guard let toolbar = self.view.window?.toolbar else {return}
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.isEnabled = true
            searchField.target = self
            searchField.action = #selector(procSearchFieldInput(sender:))
            searchField.delegate = self
            if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
                textFieldInsideSearchField.placeholderString = "Cari siswa..."
            }
        }
        
        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel"}),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton {
            hapus.isEnabled = tableView.selectedRow != -1
        }
        
        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton {
            edit.isEnabled = tableView.selectedRow != -1
        }
        
        if let tambahToolbarItem = toolbar.items.first(where: {$0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton {
            tambah.isEnabled = false
        }
        
        if let addToolbarItem = toolbar.items.first(where: {$0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton {
            add.isEnabled = true
            addToolbarItem.toolTip = "Tambahkan Data Siswa Baru"
            add.toolTip = "Tambahkan Data Siswa Baru"
            addButton = add
        }
        
        if let popUpMenuToolbarItem = toolbar.items.first(where: {$0.itemIdentifier.rawValue == "popUpMenu"}),
           let popUpButtom = popUpMenuToolbarItem.view as? NSPopUpButton {
            popUpButtom.menu = itemSelectedMenu
        }
    }

    var addButton: NSButton!
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        ReusableFunc.resetMenuItems()
    }

    
    // MARK: - UI
    @objc private func appAktif(_ sender: Any) {
        guard tableView.selectedRow != -1, currentTableViewMode == .plain else { return }
        let selectedRowIndexes = tableView.selectedRowIndexes

        // Tambahkan border ke semua baris yang dipilih
        selectedRowIndexes.forEach { row in
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                viewModel.getImageForKelas(bordered: true, kelasSekarang: siswa.kelasSekarang) { image in
                    DispatchQueue.main.async {
                        selectedCellView.imageView?.image = image
                    }
                }
            }
        }
        NotificationCenter.default.removeObserver(self, name: .windowControllerBecomeKey, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appNonAktif(_:)), name: .windowControllerResignKey, object: nil)
    }
    @objc private func appNonAktif(_ sender: Any) {
        guard tableView.selectedRow != -1, currentTableViewMode == .plain else { return }
        let selectedRowIndexes = tableView.selectedRowIndexes

        // Tambahkan border ke semua baris yang dipilih
        selectedRowIndexes.forEach { row in
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                viewModel.getImageForKelas(bordered: false, kelasSekarang: siswa.kelasSekarang) { image in
                    DispatchQueue.main.async {
                        selectedCellView.imageView?.image = image
                    }
                }
            }
        }
        NotificationCenter.default.removeObserver(self, name: .windowControllerResignKey, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appAktif(_:)), name: .windowControllerBecomeKey, object: nil)
    }
    
    private func setupTable() {
        if let savedRowHeight = UserDefaults.standard.value(forKey: "SiswaTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }
    }
    
    @IBAction private func beralihSiswaLulus(_ sender: Any) {
        // Toggle pengaturan "tampilkanSiswaLulus"
        var tampilkanSiswaLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")
        tampilkanSiswaLulus.toggle()
        UserDefaults.standard.setValue(tampilkanSiswaLulus, forKey: "tampilkanSiswaLulus")
        
        let isGrouped = (self.currentTableViewMode != .plain)
        
        let sortDescriptor = loadSortDescriptor()!
        Task(priority: .userInitiated) { [unowned self] in
            if !isGrouped {
                let index = await self.viewModel.filterSiswaLulus(tampilkanSiswaLulus, sortDesc: SortDescriptorWrapper.from(sortDescriptor))
                if !tampilkanSiswaLulus {
                    // Hapus baris siswa yang berhenti
                    index.reversed().forEach { i in
                        self.viewModel.removeSiswa(at: i)
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 detik
                    await MainActor.run {
                        self.tableView.beginUpdates()
                        self.tableView.removeRows(at: IndexSet(index), withAnimation: .slideDown)
                        self.tableView.endUpdates()
                    }
                } else if tampilkanSiswaLulus {
                    await MainActor.run { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Tambahkan kembali baris siswa yang berhenti
                        self.tableView.insertRows(at: IndexSet(index), withAnimation: .effectGap)
                        if let full = index.max() {
                            if full <= tableView.numberOfRows {
                                self.tableView.scrollRowToVisible(full)
                            } else {
                                self.tableView.scrollRowToVisible(self.tableView.numberOfRows)
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 detik
                    self.tableView.selectRowIndexes(IndexSet(index), byExtendingSelection: false)
                }
            } else {
                await self.viewModel.fetchSiswaData()
                await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: self.isBerhentiHidden)
                
                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        }
    }

    @IBAction private func muatUlang(_ sender: Any) {
        guard let sortDescriptor = loadSortDescriptor() else { return }
        if currentTableViewMode == .grouped {
            Task(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                await self.viewModel.fetchSiswaData()
                await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: self.isBerhentiHidden)
                
                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        } else {
            Task(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                await self.viewModel.fetchSiswaData()
                await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: self.isBerhentiHidden)
                
                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        }
        self.updateUndoRedo(sender)
    }
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
            let editMenuItem = mainMenu.item(withTitle: "Edit"),
            let editMenu = editMenuItem.submenu,
            let copyMenuItem = editMenu.items.first(where: {$0.identifier?.rawValue == "copy"}),
            let deleteMenuItem = editMenu.items.first(where: {$0.identifier?.rawValue == "hapus"}),
            let fileMenu = mainMenu.item(withTitle: "File"),
            let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
            let fileMenuItem = fileMenu.submenu,
            let new = fileMenuItem.items.first(where: {$0.identifier?.rawValue == "new"}) {
            
            let isRowSelected = tableView.selectedRowIndexes.count > 0

            // Update item menu "Copy"
            copyMenuItem.isEnabled = isRowSelected
            pasteMenuItem.target = self
            pasteMenuItem.action = SingletonData.originalPasteAction
            // Update item menu "Delete"
            deleteMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(deleteSelectedRowsAction(_:))
                copyMenuItem.target = self
                copyMenuItem.action = #selector(copySelectedRows(_:))
            } else {
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
            }
                new.target = self
                new.action = #selector(addSiswaNewWindow(_:))
        }
    }
    
    @IBAction private func toggleBerhentiVisibility(_ sender: Any) {
        isBerhentiHidden.toggle()
        let sortDescriptor = loadSortDescriptor()!
        Task(priority: .userInitiated) { [unowned self] in
            if currentTableViewMode == .plain {
                let index = await viewModel.filterSiswaBerhenti(isBerhentiHidden, sortDescriptor: SortDescriptorWrapper.from(sortDescriptor))
                if self.isBerhentiHidden {
                    // Hapus baris siswa yang berhenti
                    index.reversed().forEach { i in
                        self.viewModel.removeSiswa(at: i)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        self.tableView.removeRows(at: IndexSet(index), withAnimation: .slideDown)
                    }
                } else {
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Tambahkan kembali baris siswa yang berhenti
                        self.tableView.insertRows(at: IndexSet(index), withAnimation: .effectGap)
                        if let full = index.max() {
                            if full <= self.tableView.numberOfRows {
                                self.tableView.scrollRowToVisible(full)
                            } else {
                                self.tableView.scrollRowToVisible(self.tableView.numberOfRows)
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self.tableView.selectRowIndexes(IndexSet(index), byExtendingSelection: false)
                }
            } else {
                await self.viewModel.fetchSiswaData()
                if let sortDescriptor = tableView.sortDescriptors.first {
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)
                }
                // Setelah filtering selesai, update UI di sini
                self.sortData(with: sortDescriptor)
            }
        }
    }
    @objc private func datePickerValueChanged(_ sender: NSDatePicker) {
        let clickedRow = tableView.selectedRow
        
        // Check if a valid row is selected
        guard clickedRow >= 0 && clickedRow < viewModel.filteredSiswaData.count else {
            
            return
        }
        let siswa = viewModel.filteredSiswaData[clickedRow]
        // Set up date formatters
        let editedDate = sender.dateValue
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let editedTanggal = dateFormatter.string(from: editedDate)

        // Get the tag of the date picker to identify the column
        let datePickerTag = sender.tag
        let columnIndexOfThnDaftar = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tahun Daftar"))
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))

        switch datePickerTag {
        case 1:
            let oldValue = siswa.tahundaftar

            // Update database
            viewModel.updateModelAndDatabase(id: siswa.id, columnIdentifier: "Tahun Daftar", rowIndex: clickedRow, newValue: editedTanggal, oldValue: oldValue)

            // Reload tabel hanya untuk kolom yang berubah
            tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfThnDaftar]))

            // Simpan data asli untuk undo
            let originalModel = DataAsli(ID: siswa.id, rowIndex: clickedRow, columnIdentifier: "Tahun Daftar", oldValue: oldValue, newValue: editedTanggal)

            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.viewModel.undoAction(originalModel: originalModel)
            })
        case 2:
            let oldValue = siswa.tanggalberhenti

            // Update model array
            viewModel.updateModelAndDatabase(id: siswa.id, columnIdentifier: "Tgl. Lulus", rowIndex: clickedRow, newValue: editedTanggal, oldValue: oldValue)
            
            // Reload tabel hanya untuk kolom yang berubah
            tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfTglBerhenti]))

            // Simpan data asli untuk undo
            let originalModel = DataAsli(ID: siswa.id, rowIndex: clickedRow, columnIdentifier: "Tgl. Lulus", oldValue: oldValue, newValue: editedTanggal)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.viewModel.undoAction(originalModel: originalModel)
            })
        default:
            break
        }
        
    }
    @IBAction func groupMode(_ sender: NSMenuItem) {
        if currentTableViewMode == .plain {
            sender.tag = 1
        } else {
            sender.tag = 0
        }
        changeTableViewMode(sender)
    }
    func updateGroupMenuBar() {
        AppDelegate.shared.groupMenuItem.state = currentTableViewMode == .grouped ? .on : .off
    }
    @IBAction private func changeTableViewMode(_ sender: NSMenuItem) {
        // Periksa tag dari opsi menu yang dipilih
        if let mode = TableViewMode(rawValue: sender.tag) {
            // Perbarui tampilan tabel sesuai dengan tipe yang dipilih
            var indexset = IndexSet()
            switch mode {
            case .plain:
                nextSectionHeaderView?.removeFromSuperviewWithoutNeedingDisplay()
                currentTableViewMode = .plain
                // Menyimpan nilai currentTableViewMode ke UserDefaults
                UserDefaults.standard.set(currentTableViewMode.rawValue, forKey: "tableViewMode")
                // tableView.gridStyleMask = .solidHorizontalGridLineMask
                // tableView.gridStyleMask = .solidVerticalGridLineMask
                let headerMenu = NSMenu()
                for column in tableView.tableColumns {
                    if column.identifier.rawValue != "Nama" {
                        let menuItem = NSMenuItem(title: column.title, action: #selector(toggleColumnVisibility(_:)), keyEquivalent: "")
                        menuItem.representedObject = column
                        menuItem.state = column.isHidden ? .off : .on
                        let smallFont = NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small))
                        menuItem.attributedTitle = NSAttributedString(string: column.title, attributes: [.font: smallFont])
                        headerMenu.addItem(menuItem)
                    }
                }
                tableView.headerView?.menu = headerMenu
                if let columnInfo = kolomTabelSiswa.first {
                    if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) {
                        let customHeaderCell = MyHeaderCell()                        
                        customHeaderCell.title = "Nama"  // Menggunakan nama section yang sesuai
                        column.headerCell = customHeaderCell
                    }
                }
                filterDeletedSiswa()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
                    selectedIds.forEach { id in
                        if let index = viewModel.filteredSiswaData.firstIndex(where: {$0.id == id}) {
                            indexset.insert(index)
                        } else {
                            
                        }
                    }
                    tableView.selectRowIndexes(indexset, byExtendingSelection: false)
                    if let max = indexset.max() {
                        tableView.scrollRowToVisible(max)
                    }
                    tableView.headerView?.frame.origin.y = 0
                }
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            case .grouped:
                currentTableViewMode = .grouped
                UserDefaults.standard.set(currentTableViewMode.rawValue, forKey: "tableViewMode")
                tableView.floatsGroupRows = false
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return }
                        await self.viewModel.fetchSiswaData()
                        await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)
                        
                        await MainActor.run { [weak self] in
                            guard let self = self else { return }
                            // Setelah filtering selesai, update UI di sini
                            self.updateGroupedUI()
                        }
                    }
                }
            }
        }
        updateGroupMenuBar()
    }
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              currentTableViewMode == .grouped,
              let headerView = tableView.headerView else {
            return
        }
        
        var offsetY = clipView.documentVisibleRect.origin.y
        offsetY += (18 + tabBarFrame)
        let topRow = tableView.row(at: CGPoint(x: 0, y: offsetY))
        
        // Handle top position
        if (clipView.bounds.origin.y + tabBarFrame) <= -42 {
            updateHeaderTitle(for: 0)
            headerView.frame.origin.y = 0
            //headerView.alphaValue = 1
            // Remove any existing next section header
            if nextSectionHeaderView != nil {
                nextSectionHeaderView?.removeFromSuperview()
                nextSectionHeaderView = nil
            }
            return
        }
        
        guard topRow != -1 else { return }
        
        let (_, currentSectionIndex, _) = getRowInfoForRow(topRow)
        let nextSectionIndex = currentSectionIndex + 1
        
        guard nextSectionIndex <= kelasNames.count else {
            nextSectionHeaderView?.removeFromSuperview()
            nextSectionHeaderView = nil
            return
        }
        
        let nextSectionFirstRow = findFirstRowInSection(nextSectionIndex)
        let nextSectionY = tableView.rect(ofRow: nextSectionFirstRow).minY
        let defaultSectionSpacing: CGFloat = 20 // berdasarkan pengamatan visual
        let transitionDistance: CGFloat = 26
        let transitionStart = nextSectionY - defaultSectionSpacing - transitionDistance

        if offsetY > transitionStart {
            // Create next section header if it doesn't exist
            if nextSectionIndex >= 0, nextSectionIndex < kelasNames.count {
                let nextSectionTitle = kelasNames[nextSectionIndex]
                if nextSectionHeaderView == nil {
                    nextSectionHeaderView = createHeaderViewCopy(title: nextSectionTitle)
                    if let nextHeader = nextSectionHeaderView {
                        clipView.addSubview(nextHeader)
                    }
                }
            }
            
            // Calculate transition
            let progress = min(max((offsetY - transitionStart) / transitionDistance, 0.0), 1.0)
            let headerY = progress * transitionDistance
            //let currentAlpha = 1.0 - progress
            let nextAlpha = progress
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update current header
                headerView.frame.origin.y = -headerY
                //                headerView.alphaValue = currentAlpha
                self.updateHeaderTitle(for: currentSectionIndex)
                
                // Update next section header
                self.nextSectionHeaderView?.frame.origin.y = nextSectionY - 1
                self.nextSectionHeaderView?.alphaValue = nextAlpha
                
                // Remove next header when transition is complete
                if nextAlpha >= 1.0 {
                    self.nextSectionHeaderView?.removeFromSuperview()
                    self.nextSectionHeaderView = nil
                    
                    // Update current header for next section
                    if headerView.frame.origin.y != 0 {
                        headerView.frame.origin.y = 0
                        self.updateHeaderTitle(for: nextSectionIndex)
                        //headerView.alphaValue = 1.0
                    }
                }
            }
        } else {
            // Update current header
            DispatchQueue.main.async { [weak self] in
                headerView.frame.origin.y = 0
                // Remove next section header when not in transition
                self?.nextSectionHeaderView?.removeFromSuperview()
                self?.nextSectionHeaderView = nil
                
                self?.updateHeaderTitle(for: currentSectionIndex)
            }
        }
        
    }

    private var nextSectionHeaderView: NSTableHeaderView?
    
    private func createHeaderViewCopy(title: String) -> NSTableHeaderView? {
        guard let originalHeader = tableView.headerView else { return nil }
        let modFrame = NSRect(
            x: originalHeader.frame.origin.x,
            y: originalHeader.frame.origin.y,
            width: originalHeader.frame.width,
            height: originalHeader.frame.height
        )
        
        let newHeader = CustomTableHeaderView(frame: modFrame)
        newHeader.tableView = tableView
        newHeader.isSorted = self.isSortedByFirstColumn
        // Buat custom header cell dengan title kosong
        let emptyHeaderCell = MyHeaderCell()
        emptyHeaderCell.title = title

        
        // Set custom header cell
        newHeader.customHeaderCell = emptyHeaderCell
        
        return newHeader
    }

    private func updateHeaderTitle(for sectionIndex: Int) {
        guard sectionIndex >= 0, sectionIndex < kelasNames.count else { return }

        if let columnInfo = kolomTabelSiswa.first,
           let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)),
           let customHeaderCell = column.headerCell as? MyHeaderCell {

            let newTitle = kelasNames[sectionIndex]
            if customHeaderCell.customTitle != newTitle {
                customHeaderCell.customTitle = newTitle
                customHeaderCell.title = newTitle
                previousColumnTitle = newTitle
                // Paksa headerView menggambar ulang
                tableView.headerView?.needsDisplay = true
            }
        }
    }

    // Tambahkan method helper
    private func findFirstRowInSection(_ sectionIndex: Int) -> Int {
        for row in 0..<tableView.numberOfRows {
            let (_, section, _) = getRowInfoForRow(row)
            if section == sectionIndex {
                return row
            }
        }
        return -1
    }
    
    @IBAction private func toggleColorAction(_ sender: Any) {
        useAlternateColor.toggle()
        if useAlternateColor {
            tableView.usesAlternatingRowBackgroundColors = true
        } else {
            tableView.usesAlternatingRowBackgroundColors = false
        }
        // Perbarui state item menu
        if let contextMenu = tableView.menu,
           let toggleColorMenuItem = contextMenu.item(withTitle: "Gunakan Warna Alternatif") {
            toggleColorMenuItem.state = useAlternateColor ? .on : .off
        }
        if currentTableViewMode == .grouped {
            tableView.deselectAll(sender)
            tableView.reloadData()
            tableView.hideRows(at: IndexSet([0]), withAnimation: [])
        } else {
            tableView.deselectAll(sender)
            tableView.reloadData()
        }
    }
    //MARK: - Group Section tableView reusable func
    func getRowInfoForRow(_ row: Int) -> (isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) {
        // Mendapatkan informasi baris untuk nomor baris yang diberikan
        var currentRow = 0
        
        for (index, section) in viewModel.groupedSiswa.enumerated() {
            let sectionRowCount = section.count + 1 // Jumlah siswa + 1 untuk header kelas
            if row >= currentRow && row < currentRow + sectionRowCount {
                if row == currentRow {
                    return (true, index, -1) // Ini adalah header kelas
                } else {
                    return (false, index, row - currentRow - 1) // Ini adalah baris siswa dalam kelas
                }
            }
            currentRow += sectionRowCount
        }
        
        return (false, 0, 0)
    }
    
    func getGroupIndex(forClassName className: String) -> Int? {
        if className == "Lulus" {
            return 6 // Jika kelas adalah "Lulus", masukkan ke indeks ke-7 (indeks dimulai dari 0)
        } else if className == "" {
            return 7
        } else {
            // Menghapus "Kelas " dari string untuk mendapatkan nomor kelas
            let cleanedString = className.replacingOccurrences(of: "Kelas ", with: "")
            
            // Konversi nomor kelas dari String ke Int
            if let kelasIndex = Int(cleanedString) {
                // Periksa apakah kelasIndex berada dalam rentang yang diharapkan (1 hingga 6)
                if kelasIndex >= 1 && kelasIndex <= 6 {
                    // Mengembalikan indeks grup berdasarkan nomor kelas (kurangi 1 karena array dimulai dari indeks 0)
                    return kelasIndex - 1
                }
            }
        }
        // Jika kelas tidak ditemukan atau nomor kelas tidak valid, kembalikan nilai nil
        return nil
    }
    // MARK: GENERAL REUSABLE FUNC
    private func tableType(forKelas kelas: String) -> TableType? {
        switch kelas {
        case "Kelas 1":
            return .kelas1
        case "Kelas 2":
            return .kelas2
        case "Kelas 3":
            return .kelas3
        case "Kelas 4":
            return .kelas4
        case "Kelas 5":
            return .kelas5
        case "Kelas 6":
            return .kelas6
        default:
            return nil
        }
    }
    func updateTableViewForSiswaMove(from: (Int, Int), to: (Int, Int)) {
        searchItem?.cancel()
        var fromRow = viewModel.getAbsoluteRowIndex(groupIndex: from.0, rowIndex: from.1)
        let toRow = viewModel.getAbsoluteRowIndex(groupIndex: to.0, rowIndex: to.1)
        
        // Penanganan kasus khusus
        if to.0 < from.0 || (to.0 == from.0 && to.1 < from.1) {
            // Pindah ke grup sebelumnya atau ke atas dalam grup yang sama
            fromRow -= 1
        }
        
        tableView.selectRowIndexes(IndexSet(integer: fromRow), byExtendingSelection: true)
        tableView.moveRow(at: fromRow, to: toRow)
        tableView.reloadData(forRowIndexes: IndexSet(integer: toRow), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.tableView.scrollRowToVisible(toRow) // Scroll to the NEW position
            if let frame = self.tableView.headerView?.frame {
                let modFrame = NSRect(x: frame.origin.x, y: 0, width: frame.width, height: 28)
                self.tableView.headerView = NSTableHeaderView(frame: modFrame)   
            }
            NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self.scrollView.contentView)
        }
        searchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: searchItem!)
    }
    //MARK: - SORTDESCRIPTOR FUNC
    private func setupDescriptor() {
        let descriptorNama = NSSortDescriptor(key: "nama", ascending: true)
        let descriptorAlamat = NSSortDescriptor(key: "alamat", ascending: true)
        let descriptorTTL = NSSortDescriptor(key: "ttl", ascending: true)
        let descriptorTahunDaftar = NSSortDescriptor(key: "tahundaftar", ascending: true)
        let descriptorNamaWali = NSSortDescriptor(key: "namawali", ascending: true)
        let descriptorNIS = NSSortDescriptor(key: "nis", ascending: true)
        let descriptorJenisKelamin = NSSortDescriptor(key: "jeniskelamin", ascending: true)
        let descriptorStatus = NSSortDescriptor(key: "status", ascending: true)
        let descriptorTanggalBerhenti = NSSortDescriptor(key: "tanggalberhenti", ascending: true)
        let ayahKandung = NSSortDescriptor(key: "ayahkandung", ascending: true)
        let ibuKandung = NSSortDescriptor(key: "ibukandung", ascending: true)
        let nisn = NSSortDescriptor(key: "nisn", ascending: true)
        let tlv = NSSortDescriptor(key: "tlv", ascending: true)
        let columnSortDescriptors: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("Nama"): descriptorNama,
            NSUserInterfaceItemIdentifier("Alamat"): descriptorAlamat,
            NSUserInterfaceItemIdentifier("T.T.L"): descriptorTTL,
            NSUserInterfaceItemIdentifier("Tahun Daftar"): descriptorTahunDaftar,
            NSUserInterfaceItemIdentifier("Nama Wali"): descriptorNamaWali,
            NSUserInterfaceItemIdentifier("NIS"): descriptorNIS,
            NSUserInterfaceItemIdentifier("Jenis Kelamin"): descriptorJenisKelamin,
            NSUserInterfaceItemIdentifier("Status"): descriptorStatus,
            NSUserInterfaceItemIdentifier("Tgl. Lulus"): descriptorTanggalBerhenti,
            NSUserInterfaceItemIdentifier("Ayah"): ayahKandung,
            NSUserInterfaceItemIdentifier("Ibu"): ibuKandung,
            NSUserInterfaceItemIdentifier("NISN"): nisn,
            NSUserInterfaceItemIdentifier("Nomor Telepon"): tlv,
        ]

        // Mengaitkan sort descriptor dengan setiap kolom berdasarkan identifier
        for column in tableView.tableColumns {
            let identifier = column.identifier
            let sortDescriptor = columnSortDescriptors[identifier]
            column.sortDescriptorPrototype = sortDescriptor
        }
    }
    private func sortData(with sortDescriptor: NSSortDescriptor) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        
        var indexset = IndexSet()
        Task(priority: .userInitiated) { [unowned self] in
            if currentTableViewMode == .plain {
                // Lakukan pengurutan untuk mode tanpa grup
                await self.viewModel.sortSiswa(by: SortDescriptorWrapper.from(sortDescriptor), isBerhenti: self.isBerhentiHidden)
                self.selectedIds.forEach { id in
                    if let index = self.viewModel.filteredSiswaData.firstIndex(where: {$0.id == id}) {
                        indexset.insert(index)
                    }
                }
            } else {
                await viewModel.sortGroupSiswa(by: SortDescriptorWrapper.from(sortDescriptor))
                
                // Dapatkan indeks siswa terpilih di `groupedSiswa`
                selectedIds.forEach { id in
                    for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                        if let rowIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                            // Konversikan indeks ke IndexSet untuk NSTableView
                            let tableIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: rowIndex)
                            indexset.insert(tableIndex)
                            break
                        }
                    }
                }
            }
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.tableView.reloadData()
                if self.currentTableViewMode == .grouped {
                    //self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
                }
                self.tableView.selectRowIndexes(indexset, byExtendingSelection: false)
                if let max = indexset.max() {
                    self.tableView.scrollRowToVisible(max)
                }
                if self.stringPencarian.isEmpty {
                    self.view.window?.makeFirstResponder(self.tableView)
                }
            }
        }
    }
    private func urutkanDataPencarian(with sortDescriptor: NSSortDescriptor) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        // Lakukan pengurutan untuk mode dengan grup
        await viewModel.sortGroupSiswa(by: SortDescriptorWrapper.from(sortDescriptor))
        await MainActor.run {
            let row = tableView.selectedRowIndexes
            tableView.reloadData()
            if currentTableViewMode == .grouped {
                tableView.hideRows(at: IndexSet([0]), withAnimation: [])
            }
            tableView.selectRowIndexes(row, byExtendingSelection: true)
        }
    }
    private func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?) {
        // Simpan sort descriptor ke UserDefaults
        if let sortDescriptor = sortDescriptor {
            let sortDescriptorData = try? NSKeyedArchiver.archivedData(withRootObject: sortDescriptor, requiringSecureCoding: false)
            UserDefaults.standard.set(sortDescriptorData, forKey: "sortDescriptor")
        } else {
            UserDefaults.standard.removeObject(forKey: "sortDescriptor")
        }
    }
    private func loadSortDescriptor() -> NSSortDescriptor? {
        // Muat sort descriptor dari UserDefaults
        if let sortDescriptorData = UserDefaults.standard.data(forKey: "sortDescriptor"),
           let sortDescriptor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSortDescriptor.self, from: sortDescriptorData) {
            return sortDescriptor
        } else {
            return NSSortDescriptor(key: "nama", ascending: true)
        }
    }
    
    // MARK: - OPERATION. MENUITEMS, ADD/EDIT/DELETE, UNDO-REDO.
    @IBAction func addSiswa(_ sender: Any?) {
        rowDipilih.removeAll()
        popover = NSPopover()
        let addDataViewController = AddDataViewController(nibName: "AddData", bundle: nil)
        // Ganti "AddDataViewController" dengan ID view controller yang benar
        addDataViewController.sourceViewController = .siswaViewController
        popover.behavior = .semitransient
        popover.contentViewController = addDataViewController
        
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
        }
        addDataViewController.enableDrag = false
        guard tableView.selectedRowIndexes.count > 0 else {return}
        rowDipilih.append(tableView.selectedRowIndexes)
        tableView.deselectAll(sender)
        ReusableFunc.resetMenuItems()
    }
    @IBAction private func addSiswaNewWindow(_ sender: Any?) {
        if let toolbar = self.view.window?.toolbar, let addItem = toolbar.items.first(where: {$0.itemIdentifier.rawValue == "add"}) {
            if addButton == nil {
                addButton = addItem.view as? NSButton
            }
            addButton.performClick(sender)
        } else {
            if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "addSiswaWindow" }) {
                // Jika ada window dengan identifier yang sama, buat window tersebut menjadi key window dan tampilkan
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }
            let addDataViewController = AddDataViewController(nibName: "AddData", bundle: nil)
            addDataViewController.enableDrag = false
            let window = NSWindow(contentViewController: addDataViewController)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.setFrameAutosaveName("addSiswaWindow")
            window.identifier = NSUserInterfaceItemIdentifier("addSiswaWindow")
            // Set initial window alpha value to 0 for fade-in animation
            window.alphaValue = 0
            
            // Show window with animation
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // Animation duration
                window.animator().alphaValue = 1 // Fade-in animation
            }, completionHandler: nil)
            
            window.makeKeyAndOrderFront(nil)
        }
    }
    @IBAction private func handlePrint(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Tidak dapat menjalankan print data siswa"
        alert.informativeText = "Jumlah kolom di data siswa terlalu banyak untuk diprint di ukuran kertas yang tersedia."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
//    @objc private func addColumnButtonClicked(_ sender: NSButton) {
//        // Munculkan dialog NSAlert
//        let alert = NSAlert()
//        alert.messageText = "Tambah Kolom Baru"
//        alert.informativeText = "Masukkan nama kolom baru:"
//
//        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
//        alert.accessoryView = inputField
//
//        alert.addButton(withTitle: "Tambah")
//        alert.addButton(withTitle: "Batalkan")
//
//        let response = alert.runModal()
//
//        if response == .alertFirstButtonReturn {
//            let newColumnName = inputField.stringValue
//            if !newColumnName.isEmpty {
//                // Tambahkan kolom baru ke SQLite
//                dbController.addColumnToSiswa(columnName: newColumnName)
//
//                // Tambahkan kolom baru ke tabel
//                addColumn(columnName: newColumnName)
//            }
//        }
//    }
//    private func addColumn(columnName: String) {
//        columnNames.append(columnName)
//        updateTableColumns()
//    }
//    // Fungsi untuk mengupdate kolom-kolom di tabel
//    private func updateTableColumns() {
//        // Tambahkan kolom baru ke tabel
//        for columnName in columnNames {
//            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: columnName))
//            tableColumn.title = columnName
//            tableView.addTableColumn(tableColumn)
//        }
//        viewModel.filteredSiswaData = dbController.getSiswa()
//        // Menggambar ulang tabel dengan kolom-kolom baru
//        tableView.reloadData()
//    }
    @IBAction func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            decreaseSize(sender)
        case 1:
            increaseSize(sender)
        default:
            break
        }
    }
    @IBAction private func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight += 5
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
        }, completionHandler: nil)
        saveRowHeight()
    }

    @IBAction private func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight = max(tableView.rowHeight - 3, 16)
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
        }, completionHandler: nil)
        
        saveRowHeight()
    }

    private func saveRowHeight() {
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "SiswaTableViewRowHeight")
    }
    @IBAction func exportToExcel(_ sender: NSMenuItem) {
        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.viewModel.filteredSiswaData
                self.chooseFolderAndSaveCSV(header: ["Nama", "Alamat", "NISN", "NIS", "Wali", "Ayah", "Ibu", "No. Telepon", "Jenis Kelamin", "Kelas Aktif", "Tanggal Pendaftaran", "Status", "Tanggal Berhenti / Lulus"], siswaData: data, namaFile: "Data Siswa", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: false)
            } else {
                
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }
    @IBAction func exportToPDF(_ sender: NSMenuItem) {
        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.viewModel.filteredSiswaData
                self.chooseFolderAndSaveCSV(header: ["Nama", "Alamat", "NISN", "NIS", "Wali", "Ayah", "Ibu", "No. Telepon", "Jenis Kelamin", "Kelas Aktif", "Tanggal Pendaftaran", "Status", "Tanggal Berhenti / Lulus"], siswaData: data, namaFile: "Data Siswa", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: true)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }
    @IBAction private func ubahStatus(_ sender: NSMenuItem) {
        guard let tableView = tableView else {return}
        // Jika ada baris yang diklik
        if tableView.clickedRow >= 0 && tableView.clickedRow < viewModel.filteredSiswaData.count {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                pilihubahStatus(sender)
            } else {
                klikubahStatus(sender)
            }
        } else if tableView.clickedRow == -1 && tableView.selectedRowIndexes.last ?? 0 < viewModel.filteredSiswaData.count {
            pilihubahStatus(sender)
        }
    }
//    @IBAction private func updateKelasAktif(_ sender: NSMenuItem) {
//        guard let tableView = tableView else {
//            return
//        }
//
//        // Jika ada baris yang diklik
//        if tableView.clickedRow >= 0 && tableView.clickedRow < viewModel.filteredSiswaData.count {
//            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
//                updateKelasDipilih(sender)
//            } else {
//                updateKelasKlik(sender)
//            }
//        } else if tableView.clickedRow == -1 && tableView.selectedRowIndexes.last ?? 0 < viewModel.filteredSiswaData.count {
//            updateKelasDipilih(sender)
//        }
//    }
    @IBAction private func pasteClicked(_ sender: Any) {
        if tableView.numberOfRows == 0 {
            tableView.reloadData()
        }
        
        // Dapatkan data yang ada di clipboard
        let pasteboard = NSPasteboard.general
        var errorMessages: [String] = []
        guard let stringData = pasteboard.string(forType: .string) else {return}
        
        // Parse data yang ditempelkan
        let lines = stringData.components(separatedBy: .newlines)
        // Array untuk menyimpan siswa yang akan ditambahkan
        var siswaToAdd: [ModelSiswa] = []
        siswaToAdd.removeAll()
        let allColumns = tableView.tableColumns

        // Periksa setiap kolom dan cari yang sesuai dengan identifikasi yang Anda gunakan
        var columnIndexNamaSiswa: Int? = nil
        var columnIndexOfAlamat: Int? = nil
        var columnIndexOfTanggalLahir: Int? = nil
        var columnIndexOrtu: Int? = nil
        var columnIndexOfStatus: Int? = nil
        var columnIndexTahunDaftar: Int? = nil
        var columnIndexNIS: Int? = nil
        var columnIndexKelamin: Int? = nil
        var columnIndexOfTglBerhenti: Int? = nil
        var columnIndexNISN: Int? = nil
        var columnIndexAyah: Int? = nil
        var columnIndexIbu: Int? = nil
        var columnIndexTlv: Int? = nil
        for (index, column) in allColumns.enumerated() {
            if column.identifier.rawValue == "Nama" {
                columnIndexNamaSiswa = index
            } else if column.identifier.rawValue == "Alamat" {
                columnIndexOfAlamat = index
            } else if column.identifier.rawValue == "T.T.L" {
                columnIndexOfTanggalLahir = index
            } else if column.identifier.rawValue == "Nama Wali" {
                columnIndexOrtu = index
            } else if column.identifier.rawValue == "Tahun Daftar" {
                columnIndexTahunDaftar = index
            } else if column.identifier.rawValue == "NIS" {
                columnIndexNIS = index
            } else if column.identifier.rawValue == "Jenis Kelamin" {
                columnIndexKelamin = index
            } else if column.identifier.rawValue == "Status" {
                columnIndexOfStatus = index
            } else if column.identifier.rawValue == "Tgl. Lulus" {
                columnIndexOfTglBerhenti = index
            } else if column.identifier.rawValue == "NISN" {
                columnIndexNISN = index
            } else if column.identifier.rawValue == "Ayah" {
                columnIndexAyah = index
            } else if column.identifier.rawValue == "Ibu" {
                columnIndexIbu = index
            } else if column.identifier.rawValue == "Nomor Telepon" {
                columnIndexTlv = index
            }
        }
        for line in lines {
            // Parsing data dalam baris yang ditempelkan
            var rowComponents: [String]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                
                continue
            }
            if trimmedLine.contains("\t") {
                rowComponents = trimmedLine.components(separatedBy: "\t")
            } else if trimmedLine.contains(", ") {
                rowComponents = trimmedLine.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                // Handle jika tidak ada separator yang valid
                errorMessages.append("Format tidak valid untuk baris: \(trimmedLine)")
                continue
            }
            
            if line.contains("\t") {
                rowComponents = line.components(separatedBy: "\t")
            } else if line.contains(", ") {
                rowComponents = line.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                // Handle jika tidak ada separator yang valid
                errorMessages.append("Format tidak valid untuk baris: \(line)")
                continue
            }
            
            let isRowEmpty = rowComponents.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if isRowEmpty {
                
                continue
            }
            // Buat objek BentukSiswa dan sesuaikan dengan urutan kolom
            let siswa = ModelSiswa()
            while rowComponents.count < allColumns.count {
                rowComponents.append("") // Isi dengan string kosong
            }
            
            // Buat objek BentukSiswa dan sesuaikan dengan urutan kolom
            if let index = columnIndexNamaSiswa {
                siswa.nama = rowComponents[index]
                
            } else {
                
            }
            if let index = columnIndexOfAlamat {
                siswa.alamat = rowComponents[index]
                
            }
            if let index = columnIndexOfTanggalLahir {
                siswa.ttl = rowComponents[index]
                
            }
            if let index = columnIndexOrtu {
                siswa.namawali = rowComponents[index]
                
            }
            if let index = columnIndexNIS {
                siswa.nis = rowComponents[index]
                
            }
            if let index = columnIndexKelamin {
                siswa.jeniskelamin = rowComponents[index]
                
            }
            if let index = columnIndexTahunDaftar {
                siswa.tahundaftar = rowComponents[index]
                
            }
            if let index = columnIndexOfStatus {
                siswa.status = rowComponents[index]
                
            }
            if let index = columnIndexOfTglBerhenti {
                siswa.tanggalberhenti = rowComponents[index]
                
            }
            if let index = columnIndexNISN {
                siswa.nisn = rowComponents[index]
                
            }
            if let index = columnIndexAyah {
                siswa.ayah = rowComponents[index]
                
            }
            if let index = columnIndexIbu {
                siswa.ibu = rowComponents[index]
                
            }
            if let index = columnIndexTlv {
                siswa.tlv = rowComponents[index]
                
            }
            
            // Tambahkan objek BentukSiswa ke array siswaToAdd
            siswaToAdd.append(siswa)
        }
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            return
        }
        if !errorMessages.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Format input tidak didukung"

            // Ambil maksimal 3 error pertama
            let maxErrorsToShow = 3
            let displayedErrors = errorMessages.prefix(maxErrorsToShow)
            var informativeText = displayedErrors.joined(separator: "\n")

            // Jika ada lebih dari 3 error, tambahkan keterangan bahwa ada lebih banyak error
            if errorMessages.count > maxErrorsToShow {
                informativeText += "\n...dan \(errorMessages.count - maxErrorsToShow) lainnya"
            }

            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.icon = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        } else {
            tableView.deselectAll(sender)
        }
        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()
        
        // Buat array untuk menyimpan insertedSiswaID
        var insertedSiswaIDs: [Int64] = []

        // Background queue untuk proses database
        
        
        Task(priority: .userInitiated) { [unowned self] in
            for siswa in siswaToAdd {
                // Tambahkan siswa ke database
                dbController.catatSiswa(namaValue: siswa.nama, alamatValue: siswa.alamat, ttlValue: siswa.ttl, tahundaftarValue: siswa.tahundaftar, namawaliValue: siswa.namawali, nisValue: siswa.nis, nisnValue: siswa.nisn, namaAyah: siswa.ayah, namaIbu: siswa.ibu, jeniskelaminValue: siswa.jeniskelamin, statusValue: siswa.status, tanggalberhentiValue: siswa.tanggalberhenti, kelasAktif: "", noTlv: siswa.tlv, fotoPath: selectedImageData)
                
                // Dapatkan ID siswa yang baru ditambahkan
                if let insertedSiswaID = dbController.getInsertedSiswaID() {
                    // Simpan insertedSiswaID ke array
                    insertedSiswaIDs.append(insertedSiswaID)
                }
            }
            
            // Setelah semua siswa ditambahkan, proses hasilnya di main thread
            Task(priority: .userInitiated) { @MainActor [unowned self] in
                tableView.beginUpdates()
                for insertedSiswaID in insertedSiswaIDs {
                    // Dapatkan data siswa yang baru ditambahkan dari database
                    let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)
                    
                    if currentTableViewMode == .plain {
                        // Pastikan siswa yang baru ditambahkan belum ada di tabel
                        guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else {
                            continue
                        }
                        // Tentukan indeks untuk menyisipkan siswa baru ke dalam array viewModel.filteredSiswaData sesuai dengan urutan kolom
                        let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Masukkan siswa baru ke dalam array viewModel.filteredSiswaData
                        viewModel.insertSiswa(insertedSiswa, at: insertIndex)
                        

                        // Tambahkan baris baru ke tabel dengan animasi
                        tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                        // Pilih baris yang baru ditambahkan
                        tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)

                        // Simpan siswa yang baru ditambahkan ke array untuk dihapus nanti jika diperlukan
                        tempDeletedIndexes.append(insertIndex)
                    } else {
                        // Pastikan siswa yang baru ditambahkan belum ada di groupedSiswa
                        let siswaAlreadyExists = viewModel.groupedSiswa.flatMap { $0 }.contains(where: { $0.id == insertedSiswaID })
                        
                        if siswaAlreadyExists {
                            continue // Jika siswa sudah ada, lanjutkan ke siswa berikutnya
                        }
                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                        viewModel.insertGroupSiswa(insertedSiswa, groupIndex: 7, index: insertIndex)
                        
                        // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                        tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                        tempDeletedIndexes.append(absoluteRowIndex + 1)
                    }
                    tempDeletedSiswaArray.append(insertedSiswa)
                }
                // Tambahkan informasi siswa yang dipaste ke dalam array pastedSiswasArray
                pastedSiswasArray.append(tempDeletedSiswaArray)

                // Daftarkan aksi undo untuk paste
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
                    targetSelf.undoPaste(sender)
                }

                // Hapus semua informasi dari array redo
                deleteAllRedoArray(sender)

                // Perbarui tombol undo dan redo
                updateUndoRedo(self)
                tableView.endUpdates()
                if let maxIndex = tempDeletedIndexes.max() {
                    if maxIndex >= tableView.numberOfRows - 1 {
                        tableView.scrollToEndOfDocument(sender)
                    } else {
                        tableView.scrollRowToVisible(maxIndex + 1)
                    }
                }
            }
        }
    }
    @IBAction private func paste(_ sender: Any) {
//        guard currentTableViewMode == .plain else {
//            let alert = NSAlert()
//            alert.messageText = "Tidak dapat menempel data dalam mode group."
//            alert.informativeText = "Gunakan tampilan data secara utuh untuk memulai menempel data baru."
//            alert.alertStyle = .warning
//            alert.addButton(withTitle: "OK")
//            alert.runModal()
//            return
//        }
        pasteClicked(self)
    }
    @IBAction private func showDetail(_ sender: Any) {
        guard let tableView = tableView else {
            return
        }

        // Jika ada baris yang diklik
        if tableView.clickedRow >= 0 {
            ReusableFunc.resetMenuItems()
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, maka panggil fungsi copySelectedRows
                detailSelectedRow(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih, maka panggil fungsi copyClickedRow
                detailClickedRow(sender)
            }
        } else if tableView.selectedRowIndexes.count > 0 {
            detailSelectedRow(sender)
        }
    }
    @objc func detailWindowDidClose(_ window: DetilWindow) {
        // Cari siswaID yang sesuai dengan jendela yang ditutup
        if let detailViewController = window.contentViewController as? DetailSiswaController,
           let siswaID = detailViewController.siswa?.id {
            AppDelegate.shared.openedSiswaWindows.removeValue(forKey: siswaID)
        }
    }
    
    @objc private func detailSelectedRow(_ sender: Any) {
        var selectedSiswas = [ModelSiswa]()
        guard tableView.selectedRowIndexes.count > 0 else { return }

        if currentTableViewMode == .plain {
            selectedSiswas = tableView.selectedRowIndexes.compactMap { index in
                guard index < viewModel.filteredSiswaData.count else { return nil }
                return viewModel.filteredSiswaData[index]
            }
        } else {
            for selectedIndex in tableView.selectedRowIndexes {
                let rowInfo = getRowInfoForRow(selectedIndex)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection

                if groupIndex < viewModel.groupedSiswa.count && rowIndexInSection < viewModel.groupedSiswa[groupIndex].count {
                    selectedSiswas.append(viewModel.groupedSiswa[groupIndex][rowIndexInSection])
                }
            }
        }
        ReusableFunc.bukaRincianSiswa(selectedSiswas, viewController: self)
    }

    @objc private func detailClickedRow(_ sender: Any) {
        // Pastikan ada baris yang dipilih di tabel
        guard tableView.clickedRow >= 0 else {return}
        var selectedSiswa: ModelSiswa!
        
        if currentTableViewMode == .plain {
            selectedSiswa = viewModel.filteredSiswaData[tableView.clickedRow]
        } else {
            let (isGroupRow, sectionIndex, rowIndexInSection) = getRowInfoForRow(tableView.clickedRow)
            if isGroupRow {
                return
            }
            selectedSiswa = viewModel.groupedSiswa[sectionIndex][rowIndexInSection]
        }
        ReusableFunc.bukaRincianSiswa([selectedSiswa], viewController: self)
    }
    @objc private func handleDataDidChangeNotification(_ notification: Notification) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
        guard let insertedSiswaID = dbController.getInsertedSiswaID() else { return }
        let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)
        // Hanya tambahkan data baru ke tabel jika belum ada dalam viewModel.filteredSiswaData
        if currentTableViewMode == .plain {
            guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else { return }
            let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)
            viewModel.insertSiswa(insertedSiswa, at: insertIndex)
            // Perbarui tampilan tabel setelah memasukkan data yang dihapus
            tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
            tableView.scrollRowToVisible(insertIndex)
            tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
            NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        } else {
            guard let group = getGroupIndex(forClassName: insertedSiswa.kelasSekarang),
                  let sortDescriptor = ModelSiswa.currentSortDescriptor else {
                return
            }
            let updatedGroupIndex = min(group, viewModel.groupedSiswa.count - 1)

            // Hitung ulang indeks penyisipan berdasarkan grup yang baru
            let insertIndex = viewModel.groupedSiswa[updatedGroupIndex].insertionIndex(for: insertedSiswa, using: sortDescriptor)

            // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
            viewModel.insertGroupSiswa(insertedSiswa, groupIndex: group, index: insertIndex)
            // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
            let rowInfo = getRowInfoForRow(insertIndex)
            // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas
            
            // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
            let absoluteRowIndex = viewModel.groupedSiswa.prefix(group).reduce(0) { result, section in
                return result + section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
            }

            // Tambahkan indeks baris dalam grup ke indeks absolut
            let rowToInsert = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
            tableView.insertRows(at: IndexSet(integer: rowToInsert + 1), withAnimation: .slideDown)
            tableView.selectRowIndexes(IndexSet(integer: rowToInsert + 1), byExtendingSelection: true)
            tableView.scrollRowToVisible(rowToInsert + 1)
            
            NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        }
        urungsiswaBaruArray.append(insertedSiswa)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.urungSiswaBaru(self)
        }
        deleteAllRedoArray(self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.siswaBaru, object: nil)
    }
    private func urungSiswaBaru(_ sender: Any) {
        let siswa = urungsiswaBaruArray.removeLast()

        tableView.beginUpdates()
        if currentTableViewMode == .plain {
            if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) {
                ulangsiswaBaruArray.append(viewModel.filteredSiswaData[index])
                viewModel.removeSiswa(at: index)
                // Hapus data dari tabel
                if index + 1 < tableView.numberOfRows - 1 {
                    tableView.selectRowIndexes(IndexSet([index + 1]), byExtendingSelection: false)
                }
                tableView.scrollRowToVisible(index)
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            }
        } else {
            if let groupIndex = viewModel.groupedSiswa.firstIndex(where: { $0.contains { $0.id == siswa.id } }) {
                // Temukan indeks siswa dalam grup tersebut
                if let siswaIndex = viewModel.groupedSiswa[groupIndex].firstIndex(where: { $0.id == siswa.id }) {
                    // Hapus siswa dari grup
                    ulangsiswaBaruArray.append(viewModel.groupedSiswa[groupIndex][siswaIndex])
                    viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
//                    tableView.reloadData()
//                    tableView.hideRows(at: IndexSet(integer: 0), withAnimation: .slideUp)
                    // Dapatkan informasi baris untuk id siswa yang dihapus
                    let rowInfo = getRowInfoForRow(siswaIndex)
                    // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas
                    
                    // Hitung indeks absolut untuk menghapus baris dari NSTableView
                    var absoluteRowIndex = 0
                    for i in 0..<groupIndex {
                        let section = viewModel.groupedSiswa[i]
                        // Tambahkan jumlah baris dalam setiap grup sebelum grup saat ini
                        absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
                    }
                    // Tambahkan indeks baris dalam grup ke indeks absolut
                    let rowtoDelete = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
                    // Hapus baris dari NSTableView
                    if rowtoDelete + 2 < tableView.numberOfRows {
                        tableView.scrollRowToVisible(rowtoDelete + 1)
                        tableView.selectRowIndexes(IndexSet([rowtoDelete + 2]), byExtendingSelection: false)
                    } else {
                        tableView.scrollRowToVisible(rowtoDelete)
                    }
                    tableView.removeRows(at: IndexSet(integer: rowtoDelete + 1), withAnimation: .slideUp)
                }
            }
        }
        tableView.endUpdates()
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.ulangSiswaBaru(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Undo Add New Data")
        SingletonData.undoAddSiswaArray.append([siswa])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SingletonData.deletedStudentIDs.append(siswa.id)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [siswa.id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true,
                "hapusDiSiswa": true
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            self.updateUndoRedo(sender)
        }
    }
    private func ulangSiswaBaru(_ sender: Any) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
        let siswa = ulangsiswaBaruArray.removeLast()
        urungsiswaBaruArray.append(siswa)
        tableView.deselectAll(sender)
        // Kembalikan data yang dihapus ke array
        tableView.beginUpdates()
        if currentTableViewMode == .plain {
            // Temukan indeks yang sesuai untuk memasukkan siswa kembali sesuai dengan sort descriptor saat ini
            let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
            viewModel.insertSiswa(siswa, at: insertIndex)
            #if DEBUG
            print("siswa:", viewModel.filteredSiswaData[insertIndex].alamat)
            #endif
            // Perbarui tampilan tabel setelah memasukkan data yang dihapus
            tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
            tableView.scrollRowToVisible(insertIndex)
            tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
        } else {
            guard let group = getGroupIndex(forClassName: siswa.kelasSekarang) else { return }
            
            // Kemudian, hitung kembali indeks penyisipan berdasarkan grup yang baru
            let updatedGroupIndex = min(group, viewModel.groupedSiswa.count - 1)
            
            // Hitung ulang indeks penyisipan berdasarkan grup yang baru
            let insertIndex = viewModel.groupedSiswa[updatedGroupIndex].insertionIndex(for: siswa, using: sortDescriptor)
            
            // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
            viewModel.insertGroupSiswa(siswa, groupIndex: group, index: insertIndex)
            // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
            let rowInfo = getRowInfoForRow(insertIndex)
            // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas
            
            // Hitung indeks absolut untuk menghapus baris dari NSTableView
            var absoluteRowIndex = 0
            for i in 0..<group {
                let section = viewModel.groupedSiswa[i]
                // Tambahkan jumlah baris dalam setiap grup sebelum grup saat ini
                absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
            }
            
            // Tambahkan indeks baris dalam grup ke indeks absolut
            let rowtoDelete = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
            tableView.insertRows(at: IndexSet(integer: rowtoDelete + 1), withAnimation: .slideDown)
            tableView.scrollRowToVisible(rowtoDelete + 1)
            tableView.selectRowIndexes(IndexSet(integer: rowtoDelete + 1), byExtendingSelection: true)
        }
        tableView.endUpdates()
        //()
        //
        //dbController.catatSiswa(namaValue: siswa.nama, alamatValue: siswa.alamat, ttlValue: siswa.ttl, tahundaftarValue: siswa.tahundaftar, namawaliValue: siswa.namawali, nisValue: siswa.nis, nisnValue: siswa.nisn, namaAyah: siswa.ayah, namaIbu: siswa.ibu, jeniskelaminValue: siswa.jeniskelamin, statusValue: siswa.status, tanggalberhentiValue: siswa.tanggalberhenti, kelasAktif: siswa.kelasSekarang, noTlv: siswa.tlv, fotoPath: siswa.foto)

        // Catat tindakan redo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.urungSiswaBaru(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Redo Add New Data")
        
        SingletonData.undoAddSiswaArray.removeLast()
        SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [siswa.id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true,
                "hapusDiSiswa": true
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
            self.updateUndoRedo(sender)
        }
    }
    @IBAction private func copyDataClicked(_ sender: Any) {
        guard let tableView = tableView else {
            return
        }

        // Jika ada baris yang diklik
        if tableView.clickedRow >= 0 {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, maka panggil fungsi copySelectedRows
                copySelectedRows(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih, maka panggil fungsi copyClickedRow
                copyClickedRow(sender)
            }
        } else if tableView.numberOfSelectedRows >= 1 {
            copySelectedRows(sender)
        }
    }
    @objc private func copyClickedRow(_ sender: Any) {
        // Periksa apakah ada baris yang diklik
        guard tableView.clickedRow >= 0 else {
            return
        }

        // Dapatkan baris yang diklik
        let clickedRow = tableView.clickedRow
        var copiedData = ""

        let columnCount = tableView.tableColumns.count

        for columnIndex in 0..<columnCount {
            var cellData = ""
            if let cellView = tableView.view(atColumn: columnIndex, row: clickedRow, makeIfNecessary: false) as? CustomTableCellView {
                if let textField = cellView.textField {
                    cellData = textField.stringValue
                } else {
                    let datePicker = cellView.datePicker
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd MMMM yyyy"
                    cellData = dateFormatter.string(from: datePicker.dateValue)
                }
            } else if let cellView = tableView.view(atColumn: columnIndex, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
                      let textField = cellView.textField {
                cellData = textField.stringValue
            }

            copiedData += "\(cellData)\t"
        }

        // Menghapus tab terakhir sebelum menambahkan newline
        if !copiedData.isEmpty {
            copiedData.removeLast()
            copiedData += "\n"
        }

        // Salin data ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(copiedData, forType: .string)
    }
    @objc private func copySelectedRows(_ sender: Any) {
        guard let tableView = tableView, !tableView.selectedRowIndexes.isEmpty else {
            return
        }
        var copiedData = ""
        let columnCount = tableView.tableColumns.count

        for rowIndex in tableView.selectedRowIndexes {
            var rowData = ""

            for columnIndex in 0..<columnCount {
                var cellData = ""
                if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? CustomTableCellView {
                    if let textField = cellView.textField {
                        cellData = textField.stringValue
                    } else {
                        let datePicker = cellView.datePicker
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                        cellData = dateFormatter.string(from: datePicker.dateValue)
                    }
                } else if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                          let textField = cellView.textField {
                    cellData = textField.stringValue
                }

                rowData += "\(cellData)\t"
            }

            // Menghapus tab terakhir sebelum menambahkan newline
            if !rowData.isEmpty {
                rowData.removeLast()
                rowData += "\n"
                copiedData += rowData
            }
        }

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copiedData, forType: .string)
    }
    @IBAction private func copy(_ sender: Any) {
        let isRowSelected = tableView.selectedRowIndexes.count > 0
        if isRowSelected {
            copySelectedRows(self)
        } else {
            let alert = NSAlert()
            alert.messageText = "Tidak ada baris yang dipilih"
            alert.informativeText = "Pilih salah satu baris untuk menyalin data."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    @IBAction func edit(_ sender: Any) {
        rowDipilih.removeAll()
        let clickedRow = tableView.clickedRow
        var selectedRows = tableView.selectedRowIndexes
        selectedSiswaList.removeAll()
        let editView = EditData(nibName: "EditData", bundle: nil)
        
        // Jika mode adalah .grouped
        if currentTableViewMode == .grouped {
            if selectedRows.contains(clickedRow) && selectedRows.count > 1 {
                guard !selectedRows.isEmpty else { return }
                for rowIndex in selectedRows {
                    let selectedRowInfo = getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                    
                    // Tambahkan selectedSiswa ke dalam array
                    selectedSiswaList.append(selectedSiswa)
                }
                
                // Atur selectedSiswaList ke editView.selectedSiswaList
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty && clickedRow < 0 {
                // Lebih dari satu baris yang dipilih
                for rowIndex in selectedRows {
                    let selectedRowInfo = getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                    
                    // Tambahkan selectedSiswa ke dalam array
                    selectedSiswaList.append(selectedSiswa)
                    editView.siswaID = selectedSiswa.id
                }
                editView.selectedSiswaList = selectedSiswaList
            } else if selectedRows.count == 1 && selectedRows.contains(clickedRow) {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.siswaID = selectedSiswa.id
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
            } else if selectedRows.isEmpty && clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.siswaID = selectedSiswa.id
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            } else if !selectedRows.isEmpty && clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.siswaID = selectedSiswa.id
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
        } else {
            selectedSiswaList = selectedRows.map { viewModel.filteredSiswaData[$0] }
            // Jika mode bukan .grouped, menggunakan pendekatan sebelumnya
            if selectedRows.contains(clickedRow) {
                guard !selectedRows.isEmpty else { return }
                for siswa in selectedSiswaList {
                    let id = siswa.id
                    editView.siswaID = id
                    editView.selectedSiswaList = selectedSiswaList
                }
            } else if !selectedRows.isEmpty && clickedRow < 0 {
                for siswa in selectedSiswaList {
                    let id = siswa.id
                    editView.siswaID = id
                    editView.selectedSiswaList = selectedSiswaList
                }
            } else if !selectedRows.isEmpty && clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.siswaID = viewModel.filteredSiswaData[clickedRow].id
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            } else if selectedRows.isEmpty && clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.siswaID = viewModel.filteredSiswaData[clickedRow].id
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            }
        }
        presentAsSheet(editView)
        ReusableFunc.resetMenuItems()
    }
    @IBAction func findAndReplace(_ sender: Any) {
        // Metode tidak ada row yang diklik dan juga dipilih
        let editVC = CariDanGanti.instantiate()
        
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow
        
        var dataToEdit = IndexSet()
        
        if currentTableViewMode == .grouped {
            if (selectedRows.contains(clickedRow) && selectedRows.count > 1) || (!selectedRows.isEmpty && clickedRow < 0) {
                dataToEdit = selectedRows
            }
            else if (selectedRows.count == 1 && selectedRows.contains(clickedRow)) ||
                        (selectedRows.isEmpty && clickedRow >= 0) ||
                        (!selectedRows.isEmpty && clickedRow >= 0) {
                dataToEdit = IndexSet([clickedRow])
                tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
            }
        }
        else if currentTableViewMode == .plain {
            if clickedRow >= 0 && clickedRow < viewModel.filteredSiswaData.count {
                if tableView.selectedRowIndexes.contains(clickedRow) {
                    dataToEdit = selectedRows
                }
                else {
                    dataToEdit = IndexSet([clickedRow])
                    tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
                }
            }
            else {
                dataToEdit = selectedRows
            }
        }
        
        dataToEdit.forEach({ row in
            if currentTableViewMode == .plain {
                editVC.objectData.append(viewModel.filteredSiswaData[row].toDictionary())
            } else {
                let selectedRowInfo = getRowInfoForRow(row)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                guard rowIndexInSection >= 0 else { return }
                editVC.objectData.append(viewModel.groupedSiswa[groupIndex][rowIndexInSection].toDictionary())
            }
        })
        tableView.tableColumns.forEach({ column in
            guard column.identifier.rawValue != "Status",
                  column.identifier.rawValue != "Tahun Daftar",
                  column.identifier.rawValue != "Tgl. Lulus",
                  column.identifier.rawValue != "Jenis Kelamin",
                  column.identifier.rawValue != "Status"
            else {return}
            editVC.columns.append(column.identifier.rawValue)
        })
        
        editVC.onUpdate = { [weak self] updatedRows, selectedColumn in
            guard let self = self else { return }
            if self.currentTableViewMode == .plain {
                let selectedSiswaRow: [ModelSiswa] = self.tableView.selectedRowIndexes.compactMap { row in
                    let originalSiswa = self.viewModel.filteredSiswaData[row]
                    let snapshot = ModelSiswa()
                    // Copy semua properti yang diperlukan
                    snapshot.id = originalSiswa.id
                    snapshot.nama = originalSiswa.nama
                    snapshot.alamat = originalSiswa.alamat
                    snapshot.ttl = originalSiswa.ttl
                    snapshot.tahundaftar = originalSiswa.tahundaftar
                    snapshot.namawali = originalSiswa.namawali
                    snapshot.nis = originalSiswa.nis
                    snapshot.nisn = originalSiswa.nisn
                    snapshot.ayah = originalSiswa.ayah
                    snapshot.ibu = originalSiswa.ibu
                    snapshot.jeniskelamin = originalSiswa.jeniskelamin
                    snapshot.status = originalSiswa.status
                    snapshot.kelasSekarang = originalSiswa.kelasSekarang
                    snapshot.tanggalberhenti = originalSiswa.tanggalberhenti
                    snapshot.tlv = originalSiswa.tlv
                    snapshot.index = originalSiswa.index
                    snapshot.originalIndex = originalSiswa.originalIndex
                    snapshot.menuDiupdate = originalSiswa.menuDiupdate
                    snapshot.foto = originalSiswa.foto

                    return snapshot
                }
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            }
            else {
                let selectedSiswaRow = self.tableView.selectedRowIndexes.compactMap { rowIndex -> ModelSiswa? in
                    let selectedRowInfo = self.getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    guard rowIndexInSection >= 0 else { return nil }
                    return self.viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                }
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            }
            
            // Lakukan iterasi terhadap setiap row yang di-update
            for updatedData in updatedRows {
                guard let idValue = updatedData["id"] as? Int64 else {
                    continue
                }
                
                let updatedSiswa = ModelSiswa.fromDictionary(updatedData)
                
                if self.currentTableViewMode == .plain, let siswaIndex = self.viewModel.filteredSiswaData.firstIndex(where: { $0.id == idValue }) {
                    self.viewModel.updateDataSiswa(idValue, dataLama: self.viewModel.filteredSiswaData[siswaIndex], baru: updatedSiswa)
                    self.viewModel.updateSiswa(updatedSiswa, at: siswaIndex)
                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: siswaIndex), columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                }
                else if self.currentTableViewMode == .grouped, let (groupIndex, rowIndex) = self.viewModel.findSiswaInGroups(id: idValue) {
                    self.viewModel.updateDataSiswa(idValue, dataLama: self.viewModel.groupedSiswa[groupIndex][rowIndex], baru: updatedSiswa)
                    self.viewModel.updateGroupSiswa(updatedSiswa, groupIndex: groupIndex, index: rowIndex)
                    let absoluteRowIndex = self.viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: absoluteRowIndex), columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                }
            }
            
            self.deleteAllRedoArray(self)
            ReusableFunc.showProgressWindow(3, pesan: "Pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: .none) ?? ReusableFunc.menuOnStateImage!)
        }
        editVC.onClose = {
            self.updateUndoRedo(nil)
        }
        ReusableFunc.resetMenuItems()
        presentAsSheet(editVC)
    }

    @objc func undoEditSiswa(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let snapshotSiswas = userInfo["data"] as? [ModelSiswa],
              !snapshotSiswas.isEmpty,
              let sortDescriptor = ModelSiswa.currentSortDescriptor
        else {return}
        
        var updateJumlahSiswa = false
        // Buat array untuk menyimpan data baris yang belum diubah
        tableView.deselectAll(self)
        tableView.beginUpdates()
        if currentTableViewMode == .plain {
            for snapshotSiswa in snapshotSiswas {
                // Ambil nilai kelasSekarang dari objek viewModel.filteredSiswaData yang sesuai dengan snapshotSiswa
                let siswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden && siswa.status.lowercased() == "berhenti" {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswa.id }) else {continue}
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .effectGap)
                    tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: true)
                    tableView.scrollRowToVisible(insertIndex)
                } else if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && siswa.status.lowercased() == "lulus" {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswa.id }) else {continue}
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .effectGap)
                    tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: true)
                    tableView.scrollRowToVisible(insertIndex)
                }
                guard let matchedSiswaData = viewModel.filteredSiswaData.first(where: { $0.id == snapshotSiswa.id }) else {
                    continue
                }
                if !SingletonData.siswaNaikArray.isEmpty {
                    SingletonData.siswaNaikArray.removeLast()
                }
                SingletonData.siswaNaikId.removeAll(where: {$0 == snapshotSiswa.id})
                
                self.viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)
                
                if let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == snapshotSiswa.id }) {
                    var siswa = viewModel.filteredSiswaData[rowIndex]
                    siswa = dbController.getSiswa(idValue: viewModel.filteredSiswaData[rowIndex].id)
                    viewModel.removeSiswa(at: rowIndex)
                    
                    if isBerhentiHidden && snapshotSiswa.status.lowercased() == "berhenti" {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }
                    
                    if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && snapshotSiswa.status.lowercased() == "lulus" {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }

                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    let namaSiswaColumnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama"))
                    // Reload baris yang diperbarui
                    tableView.moveRow(at: rowIndex, to: insertIndex)
                    for columnIndex in 0..<tableView.numberOfColumns {
                        guard columnIndex != namaSiswaColumnIndex else { continue }
                        tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: columnIndex))
                    }
                    tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: namaSiswaColumnIndex))
                    updateFotoKelasAktifBordered(insertIndex, kelas: snapshotSiswa.kelasSekarang)
                    tableView.scrollRowToVisible(insertIndex)
                    if matchedSiswaData.tahundaftar != siswa.tahundaftar || matchedSiswaData.tanggalberhenti != siswa.tanggalberhenti {
                            updateJumlahSiswa = true
                        
                    } else {
                        
                    }
                }
            }
        } else if currentTableViewMode == .grouped {
            // Loop melalui setiap siswa di snapshot
            for snapshotSiswa in snapshotSiswas {
                let siswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden && siswa.status.lowercased() == "berhenti" {
                    let newGroupIndex = getGroupIndex(forClassName: siswa.kelasSekarang)
                    if !viewModel.groupedSiswa[newGroupIndex!].contains(where: {$0.id == siswa.id}) {
                        let insertIndex = viewModel.groupedSiswa[newGroupIndex!].insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex!, index: insertIndex)
                    let absoluteIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex!, rowIndex: insertIndex)
                    tableView.insertRows(at: IndexSet([absoluteIndex]), withAnimation: .slideUp)
                    tableView.selectRowIndexes(IndexSet([absoluteIndex]), byExtendingSelection: true)
                        tableView.scrollRowToVisible(absoluteIndex)
                    }
                }
                
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == snapshotSiswa.id }),
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id }) {
                        
                        if !SingletonData.siswaNaikArray.isEmpty {
                            SingletonData.siswaNaikArray.removeLast()
                        }
                        SingletonData.siswaNaikId.removeAll(where: {$0 == snapshotSiswa.id})
                        
                        self.viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)

                        let updated = dbController.getSiswa(idValue: snapshotSiswa.id)
                        viewModel.updateGroupSiswa(updated, groupIndex: groupIndex, index: siswaIndex)
                        
                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let newGroupIndex = getGroupIndex(forClassName: updated.kelasSekarang) ?? groupIndex
                        let insertIndex = viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: updated, using: sortDescriptor)
                        
                        // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        if isBerhentiHidden && snapshotSiswa.status.lowercased() == "berhenti" {
                            let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                            tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                            continue
                        }
                        viewModel.insertGroupSiswa(updated, groupIndex: newGroupIndex, index: insertIndex)
                        
                        // Perbarui tampilan tabel
                        updateTableViewForSiswaMove(from: (groupIndex, siswaIndex), to: (newGroupIndex, insertIndex))
                        if matchedSiswaData.tahundaftar != updated.tahundaftar || matchedSiswaData.tanggalberhenti != updated.tanggalberhenti {
                                updateJumlahSiswa = true
                            
                        }
                    } else {
                    }
                }
            }
        }
        tableView.endUpdates()
        
        // Perbarui tampilan undo dan redo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateUndoRedo(notification)
            if updateJumlahSiswa {
                NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
            }
        }
    }
    
    @IBAction func deleteSelectedRowsAction (_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusDiSiswaAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        // Dapatkan indeks baris yang dipilih
        
        var uniqueSelectedStudentNames = Set<String>()
        var allStudentNames = [String]() // Untuk menyimpan semua nama siswa
        for index in selectedRows {
            if currentTableViewMode == .plain {
                guard index < viewModel.filteredSiswaData.count else {
                    continue
                }
                let namasiswa = viewModel.filteredSiswaData[index].nama
                allStudentNames.append(namasiswa)
                uniqueSelectedStudentNames.insert(namasiswa)
            } else if currentTableViewMode == .grouped {
                // Dapatkan informasi baris berdasarkan indeks
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection
                
                //                             Pastikan indeks valid
                guard groupIndex < viewModel.groupedSiswa.count && rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                    continue
                }
                
                let namasiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
                allStudentNames.append(namasiswa)
                uniqueSelectedStudentNames.insert(namasiswa)
            }
            // Batasi nama siswa yang ditampilkan hingga 10 nama
            let limitedNames = Array(uniqueSelectedStudentNames.sorted().prefix(10))
            let additionalCount = allStudentNames.count - limitedNames.count
            let namaSiswaText = limitedNames.joined(separator: ", ")
            
            // Tampilkan jumlah nama yang melebihi batas
            let additionalText = additionalCount > 0 ? "\n...dan \(additionalCount) lainnya" : ""
            
            // Buat peringatan konfirmasi
            alert.messageText = "Konfirmasi Penghapusan Data"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(namaSiswaText)\(additionalText)?\nData di setiap kelas juga akan dihapus."
        }
        alert.showsSuppressionButton = true // Menampilkan tombol suppress
        guard !isSuppressed else {
            hapus(sender)
            return
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            hapus(sender)
        }
    }
    @objc private func mulaiRedo(_ sender: Any) {
        if SiswaViewModel.siswaUndoManager.canRedo {
            SiswaViewModel.siswaUndoManager.redo()
        }
    }
    @objc private func performUndo(_ sender: Any) {
        if SiswaViewModel.siswaUndoManager.canUndo {
            if !stringPencarian.isEmpty {
                guard currentTableViewMode == .grouped else {
                    SiswaViewModel.siswaUndoManager.undo()
                    return
                }
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return }
                        await self.urutkanDataPencarian(with: sortDescriptor)
                        await MainActor.run {
                            SiswaViewModel.siswaUndoManager.undo()
                        }
                    }
                }
            } else {
                SiswaViewModel.siswaUndoManager.undo()
            }
        }
    }
    @objc func updateUndoRedo(_ sender: Any?) {
        DispatchQueue.main.async { [unowned self] in
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" }) else {
            return
        }
        
        let canUndo = SiswaViewModel.siswaUndoManager.canUndo
//            || !SingletonData.deletedSiswaArray.isEmpty || !SingletonData.deletedSiswasArray.isEmpty || !snapshotSiswaStack.isEmpty || !urungsiswaBaruArray.isEmpty || !undoEdit.isEmpty || !pastedSiswasArray.isEmpty
        let canRedo = SiswaViewModel.siswaUndoManager.canRedo
//            || !redoDeletedSiswaArray.isEmpty || !redoSnapshotSiswaStack.isEmpty || !ulangsiswaBaruArray.isEmpty || !redoEdit.isEmpty || !SingletonData.redoPastedSiswaArray.isEmpty
        if !canUndo {
            undoMenuItem.target = nil
            undoMenuItem.action = nil
            undoMenuItem.isEnabled = false
        } else {
            undoMenuItem.target = self
            undoMenuItem.action = #selector(performUndo(_:))
            undoMenuItem.isEnabled = canUndo
        }
        
        if !canRedo {
            redoMenuItem.target = nil
            redoMenuItem.action = nil
            redoMenuItem.isEnabled = false
        } else {
            redoMenuItem.target = self
            redoMenuItem.action = #selector(mulaiRedo(_:))
            redoMenuItem.isEnabled = canRedo
        }
        }
        NotificationCenter.default.post(name: .bisaUndo, object: nil)
    }
    @IBAction func hapusMenu(_ sender: NSMenuItem) {
        guard let tableView = tableView else {return}
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusDiSiswaAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        // Dapatkan indeks baris yang dipilih
        
        var uniqueSelectedStudentNames = Set<String>()
        var allStudentNames = [String]() // Untuk menyimpan semua nama siswa
        // Menambahkan nama-nama siswa yang unik ke dalam Set dan array
        // Pastikan ada baris yang dipilih
        if (tableView.selectedRowIndexes.contains(tableView.clickedRow) && clickedRow != -1) || (tableView.numberOfSelectedRows >= 1 && clickedRow == -1) {
            guard selectedRows.count > 0 else {return}
            for index in selectedRows {
                if currentTableViewMode == .plain {
                    if index < viewModel.filteredSiswaData.count {
                        guard index < viewModel.filteredSiswaData.count else {
                            continue
                        }
                        let namasiswa = viewModel.filteredSiswaData[index].nama
                        allStudentNames.append(namasiswa)
                        uniqueSelectedStudentNames.insert(namasiswa)
                    }
                } else if currentTableViewMode == .grouped {
                    // Dapatkan informasi baris berdasarkan indeks
                    let rowInfo = getRowInfoForRow(index)
                    let groupIndex = rowInfo.sectionIndex
                    let rowIndexInSection = rowInfo.rowIndexInSection
                    
                    //                             Pastikan indeks valid
                    guard groupIndex < viewModel.groupedSiswa.count && rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                        continue
                    }
                    
                    let namasiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
                    allStudentNames.append(namasiswa)
                    uniqueSelectedStudentNames.insert(namasiswa)
                }
                // Batasi nama siswa yang ditampilkan hingga 10 nama
                let limitedNames = Array(uniqueSelectedStudentNames.sorted().prefix(10))
                let additionalCount = allStudentNames.count - limitedNames.count
                let namaSiswaText = limitedNames.joined(separator: ", ")
                
                // Tampilkan jumlah nama yang melebihi batas
                let additionalText = additionalCount > 0 ? "\n...dan \(additionalCount) lainnya" : ""
                
                // Buat peringatan konfirmasi
                alert.messageText = "Konfirmasi Penghapusan Data"
                alert.informativeText = "Apakah Anda yakin ingin menghapus data \(namaSiswaText)\(additionalText)?\nData di setiap kelas juga akan dihapus."
            }
        } else {
            var nama = ""
            guard clickedRow >= 0 else {return}
            if currentTableViewMode == .plain {
                // Jika mode adalah .plain, ambil nama siswa dari data siswa langsung
                nama = viewModel.filteredSiswaData[clickedRow].nama
            } else {
                // Jika mode adalah .grouped, dapatkan informasi baris dari metode getRowInfoForRow
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                // Ambil nama siswa dari data siswa yang terkait dengan indeks baris yang dipilih
                nama = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
            }
            alert.messageText = "Konfirmasi Penghapusan data \(nama)"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(nama)? Data yang ada di setiap Kelas juga akan dihapus."
        }
        alert.showsSuppressionButton = true // Menampilkan tombol suppress
        // Menampilkan peringatan dan menunggu respons
        guard !isSuppressed else {
            if currentTableViewMode == .grouped {
                if selectedRows.contains(clickedRow) && selectedRows.count > 1 {hapus(sender)}
                else if !selectedRows.isEmpty && clickedRow < 0 {hapus(sender)}
                else if selectedRows.count == 1 && selectedRows.contains(clickedRow) {deleteDataClicked(clickedRow)}
                else if selectedRows.isEmpty && clickedRow >= 0 {deleteDataClicked(clickedRow)}
                else if !selectedRows.isEmpty && clickedRow >= 0 {deleteDataClicked(clickedRow)}
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if tableView.clickedRow >= 0 && tableView.clickedRow < viewModel.filteredSiswaData.count {
                    if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                        hapus(sender)
                    } else {
                        deleteDataClicked(clickedRow)
                    }
                } else {
                    hapus(sender)
                }
            }
            return
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            if currentTableViewMode == .grouped {
                if selectedRows.contains(clickedRow) && selectedRows.count > 1 {hapus(sender)}
                else if !selectedRows.isEmpty && clickedRow < 0 {hapus(sender)}
                else if selectedRows.count == 1 && selectedRows.contains(clickedRow) {deleteDataClicked(clickedRow)}
                else if selectedRows.isEmpty && clickedRow >= 0 {deleteDataClicked(clickedRow)}
                else if !selectedRows.isEmpty && clickedRow >= 0 {deleteDataClicked(clickedRow)}
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if clickedRow >= 0 && clickedRow < viewModel.filteredSiswaData.count {
                    if tableView.selectedRowIndexes.contains(clickedRow) {
                        hapus(sender)
                    } else {
                        deleteDataClicked(clickedRow)
                    }
                } else {
                    hapus(sender)
                }
            }
        }
    }
    @IBAction func hapus(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        // Pastikan ada baris yang dipilih
        guard selectedRows.count > 0 else {return}
        var deletedStudentIDs = [Int64]()
        // Jika pengguna menekan tombol "Hapus"
        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()
        deleteAllRedoArray(sender)
        // Catat tindakan undo dengan data yang dihapus
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Multiple Data")
        // Hapus data dari array
        if currentTableViewMode == .plain {
            var deletedRows = Set<Int>() // Gunakan Set untuk menyimpan indeks yang dihapus
            for index in selectedRows {
                tempDeletedSiswaArray.append(viewModel.filteredSiswaData[index])
                tempDeletedIndexes.append(index)
                let siswaID = viewModel.filteredSiswaData[index].id
                let kelasSekarang = viewModel.filteredSiswaData[index].kelasSekarang
                deletedRows.insert(index) // Tambahkan indeks yang dihapus ke Set
                deletedStudentIDs.append(siswaID)
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": deletedStudentIDs,
                        "kelasSekarang": (kelasSekarang ) as String,
                        "isDeleted": true,
                        "hapusDiSiswa": true
                    ]
                    
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    SingletonData.deletedStudentIDs.append(siswaID)
                }
            }
            let sortedIndexes = tempDeletedIndexes.sorted(by: >)
            SingletonData.deletedSiswasArray.append(tempDeletedSiswaArray)
            for index in sortedIndexes {
                viewModel.removeSiswa(at: index)
            }
            
            DispatchQueue.main.async { [unowned self] in
                // Simpan aksi penghapusan secara bertahap
                deletedIndexes.append(tempDeletedIndexes)
                tableView.beginUpdates()
                tableView.removeRows(at: IndexSet(deletedRows), withAnimation: .slideUp)
                tableView.endUpdates()
                if let lastIndex = sortedIndexes.last {
                    if lastIndex == tableView.numberOfRows { // Jika baris terakhir
                        tableView.selectRowIndexes(IndexSet(integer: lastIndex - 1), byExtendingSelection: false)
                    } else {
                        tableView.selectRowIndexes(IndexSet(integer: lastIndex), byExtendingSelection: false)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
            }
        } else {
            var deletedRows = Set<Int>() // Gunakan Set untuk menyimpan indeks yang dihapus
            
            for index in selectedRows {
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection
                guard groupIndex < viewModel.groupedSiswa.count && rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                    continue
                }
                
                // Simpan data siswa yang akan dihapus
                let deletedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                tempDeletedSiswaArray.append(deletedSiswa)
                tempDeletedIndexes.append(index)
                deletedRows.insert(index) // Tambahkan indeks yang dihapus ke Set
                deletedStudentIDs.append(deletedSiswa.id)
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                DispatchQueue.main.async { [unowned self] in
                    if index == tableView.numberOfRows - 1 {
                        tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                    } else {
                        tableView.selectRowIndexes(IndexSet(integer: index + 1), byExtendingSelection: false)
                    }
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": deletedStudentIDs,
                        "kelasSekarang": deletedSiswa.kelasSekarang,
                        "isDeleted": true,
                        "hapusDiSiswa": true
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                }
            }
            
            SingletonData.deletedSiswasArray.append(tempDeletedSiswaArray)
            deletedIndexes.append(tempDeletedIndexes)
            
            // Urutkan indeks yang dihapus secara descending
            let sortedIndexes = tempDeletedIndexes.sorted(by: >)
            
            for index in sortedIndexes {
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                // Hapus baris dari grup
                viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowInfo.rowIndexInSection)
            }
            // Hapus baris dari tabel
            DispatchQueue.main.async { [unowned self] in
                tableView.beginUpdates()
                tableView.removeRows(at: IndexSet(deletedRows), withAnimation: .slideUp)
                tableView.endUpdates()
                updateUndoRedo(sender)
            }
        }
    }
    @objc func deleteDataClicked(_ row: Int) {
        //print ("vsa")
        // Dapatkan baris yang diklik kanan
        let clickedRow = row
        guard row >= 0 else {return}
        // Simpan data yang dihapus dalam array
        redoDeletedSiswaArray.removeAll()
        redoDeletedIndexes.removeAll()
        redoSnapshotSiswaStack.removeAll()
        redoEdit.removeAll()
        ulangsiswaBaruArray.removeAll()
        // Catat tindakan undo dengan data yang dihapus
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(self)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Data")
        if currentTableViewMode == .plain {
            let deletedSiswa = viewModel.filteredSiswaData[clickedRow]
            SingletonData.deletedSiswasArray.append([deletedSiswa])
            deletedIndexes.append([clickedRow])
            viewModel.removeSiswa(at: clickedRow)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                let userInfo: [String: Any] = [
                    "deletedStudentIDs": [deletedSiswa.id],
                    "kelasSekarang": deletedSiswa.kelasSekarang,
                    "isDeleted": true,
                    "hapusDiSiswa": true
                ]
                NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            }
        } else if currentTableViewMode == .grouped {
            let selectedRowInfo = getRowInfoForRow(clickedRow)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            let deletedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
            
            // Retrieve the name of the student before removal
            // let removedSiswaName = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
            SingletonData.deletedSiswasArray.append([deletedSiswa])
            deletedIndexes.append([clickedRow])
            // Remove the student from viewModel.groupedSiswa
            viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndexInSection)
            SingletonData.deletedStudentIDs.append(deletedSiswa.id)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [deletedSiswa.id],
                "kelasSekarang": deletedSiswa.kelasSekarang,
                "isDeleted": true,
                "hapusDiSiswa": true
            ]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            }
        }
        // Hapus data dari tabel
        self.tableView.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideUp)
        
        if clickedRow == tableView.numberOfRows {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }
    }
    
    private func undoDeleteMultipleData(_ sender: Any) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor, !SingletonData.deletedSiswasArray.isEmpty else {
            return
        }
        if currentTableViewMode == .plain && !stringPencarian.isEmpty {
            filterDeletedSiswa()
            if let toolbar = self.view.window?.toolbar,
               let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                stringPencarian.removeAll()
                searchFieldToolbarItem.searchField.stringValue = ""
            }
        }
        var tempDeletedIndexes = Set<Int>()
        let lastDeletedSiswaArray = SingletonData.deletedSiswasArray.last!
        tableView.beginUpdates()
        for siswa in lastDeletedSiswaArray {
            if (isBerhentiHidden && siswa.status.lowercased() == "berhenti") || (!UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && siswa.status.lowercased() == "lulus") {
//                tableView.endUpdates()
//                ReusableFunc.showAlert(title: "Filter Tabel Siswa Berhenti Aktif", message: "Data status siswa yang akan diinsert adalah siswa berhenti.")
                SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [siswa.id],
                        "kelasSekarang": siswa.kelasSekarang,
                        "isDeleted": true,
                        "hapusDiSiswa": true
                    ]
                    NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                }
                break
            }
            if currentTableViewMode == .plain {
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                viewModel.insertSiswa(siswa, at: insertIndex)
                tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                tempDeletedIndexes.insert(insertIndex)
                SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [siswa.id],
                        "kelasSekarang": siswa.kelasSekarang,
                        "isDeleted": true,
                        "hapusDiSiswa": true
                    ]
                    NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                }
            } else if currentTableViewMode == .grouped {
                if let groupIndex = getGroupIndex(forClassName: siswa.kelasSekarang) {
                    let insertIndex = viewModel.groupedSiswa[groupIndex].insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertGroupSiswa(siswa, groupIndex: groupIndex, index: insertIndex)
                    let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: insertIndex)
                    tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                    tempDeletedIndexes.insert(absoluteRowIndex + 1)
                    SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                    DispatchQueue.main.async {
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": [siswa.id],
                            "kelasSekarang": siswa.kelasSekarang,
                            "isDeleted": true,
                            "hapusDiSiswa": true
                        ]
                        NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                    }
                }
            }
        }
        previouslySelectedRows = tableView.selectedRowIndexes
        tableView.selectedRowIndexes.forEach { index in
            tableView.deselectRow(index)
        }
        for selection in lastDeletedSiswaArray {
            if currentTableViewMode == .plain {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == selection.id }) {
                    DispatchQueue.main.async {
                        self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: true)
                    }
                }
            } else {
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    if let siswaIndex = group.firstIndex(where: { $0.id == selection.id }) {
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: siswaIndex) + 1
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex), byExtendingSelection: true)
                    }
                }
            }
        }
        tableView.endUpdates()
        SingletonData.deletedSiswasArray.removeLast()
        if let maxIndex = tempDeletedIndexes.max() {
            tableView.scrollRowToVisible(maxIndex)
        }
        // Simpan data yang dihapus untuk redo
        redoDeletedSiswaArray.append(lastDeletedSiswaArray)
        
        
        // Catat tindakan redo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoDeleteMultipleData(sender)
        }
        
        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
        let hasBerhentiAndFiltered = lastDeletedSiswaArray.contains(where: { $0.status == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastDeletedSiswaArray.contains(where: { $0.status == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        if hasBerhentiAndFiltered {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Berhenti Aktif",
                message: "Data status siswa yang akan diinsert adalah siswa yang difilter. Data yang difilter akan ditampilkan saat filter dinonaktifkan."
            )
        }
        if hasLulusAndDisplayed {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Lulus Aktif",
                message: "Data status siswa yang akan diinsert adalah siswa yang difilter. Data yang difilter akan ditampilkan saat filter dinonaktifkan."
            )
        }
    }
    private func redoDeleteMultipleData(_ sender: Any) {
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = self.view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                    stringPencarian.removeAll()
                    searchFieldToolbarItem.searchField.stringValue = ""
                }
            } else {
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [unowned self] in
                        await urutkanDataPencarian(with: sortDescriptor)
                    }
                }
            }
        }
        let lastRedoDeletedSiswaArray = redoDeletedSiswaArray.removeLast()
        // Simpan data yang dihapus untuk undo
        SingletonData.deletedSiswasArray.append(lastRedoDeletedSiswaArray)
        // Lakukan penghapusan kembali
        var lastIndex = [Int]()
        tableView.beginUpdates()
        var deletedStudentIDs = [Int64]()
        for deletedSiswa in lastRedoDeletedSiswaArray {
            if currentTableViewMode == .plain {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == deletedSiswa.id }) {
                    viewModel.removeSiswa(at: index)
                    // Hapus data dari tabel
                    tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                    if index == tableView.numberOfRows - 1 {
                        tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                        lastIndex.append(index - 1)
                    } else {
                        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                        lastIndex.append(index)
                    }
                    deletedStudentIDs.append(deletedSiswa.id)
                    SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                    DispatchQueue.main.async {
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": deletedStudentIDs,
                            "kelasSekarang": deletedSiswa.kelasSekarang,
                            "isDeleted": true,
                            "hapusDiSiswa": true
                        ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    }
                }
            } else if currentTableViewMode == .grouped {
                // Temukan grup yang berisi siswa yang dihapus
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    if let siswaIndex = group.firstIndex(where: { $0.id == deletedSiswa.id }) {
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: siswaIndex) + 1
                        // Hapus siswa dari grup dan tabel
                        if absoluteRowIndex == tableView.numberOfRows - 1 {
                            tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex - 1), byExtendingSelection: false)
                            lastIndex.append(absoluteRowIndex - 1)
                        } else {
                            tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: false)
                            lastIndex.append(absoluteRowIndex + 1)
                        }
                        deletedStudentIDs.append(deletedSiswa.id)
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        tableView.removeRows(at: IndexSet(integer: absoluteRowIndex), withAnimation: .slideUp)
                        SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                        DispatchQueue.main.async {
                            let userInfo: [String: Any] = [
                                "deletedStudentIDs": deletedStudentIDs,
                                "kelasSekarang": deletedSiswa.kelasSekarang,
                                "isDeleted": true,
                                "hapusDiSiswa": true
                            ]
                            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                        }
                        // 
                    }
                }
//                tableView.reloadData()
//                tableView.hideRows(at: IndexSet(integer: 0), withAnimation: .slideUp)
            }
        }
        tableView.endUpdates()
        if let maxIndeks = lastIndex.max() {
            if maxIndeks >= tableView.numberOfRows - 1 {
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.scrollRowToVisible(maxIndeks)}
        }
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }
        
        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
        let hasBerhentiAndFiltered = lastRedoDeletedSiswaArray.contains(where: { $0.status == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastRedoDeletedSiswaArray.contains(where: { $0.status == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        if hasBerhentiAndFiltered {
            ReusableFunc.showAlert(title: "Filter Tabel Siswa Berhenti Aktif", message: "Data status siswa yang akan dihapus adalah siswa yang difilter dan telah dihapus dari tabel. Data ini akan dihapus ketika menyimpan file ke database.")
        }
        if hasLulusAndDisplayed {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Lulus Aktif",
                message: "Data status siswa yang akan dihapus adalah siswa yang difilter dan telah dihapus dari tabel. Data ini akan dihapus ketika menyimpan file ke database."
            )
        }
    }
    private func undoPaste(_ sender: Any) {
        tableView.deselectAll(sender)
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = self.view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                    stringPencarian.removeAll()
                    searchFieldToolbarItem.searchField.stringValue = ""
                }
            } else {
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [unowned self] in
                        await self.urutkanDataPencarian(with: sortDescriptor)
                    }
                }
            }
        }
        let lastRedoDeletedSiswaArray = pastedSiswasArray.removeLast()
        var tempDeletedIndexes = [Int]()
        // Simpan data yang dihapus untuk undo
        SingletonData.redoPastedSiswaArray.append(lastRedoDeletedSiswaArray)
        // Lakukan penghapusan kembali
        tableView.beginUpdates()
        for deletedSiswa in lastRedoDeletedSiswaArray {
            if currentTableViewMode == .plain, let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == deletedSiswa.id }) {
                viewModel.removeSiswa(at: index)
                // Hapus data dari tabel
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                tempDeletedIndexes.append(index)
            } else {
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == deletedSiswa.id }),
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id }) {
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        tempDeletedIndexes.append(rowIndex)
                    }
                }
            }
            //dbController.hapusDaftar(idValue: deletedSiswa.id)
        }
        for index in tempDeletedIndexes {
            if index >= tableView.numberOfRows - 1 {
                tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index + 1)
            }
        }
        tableView.endUpdates()
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoPaste(sender)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
    }
    private func redoPaste(_ sender: Any) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            return
        }
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = self.view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                    stringPencarian.removeAll()
                    searchFieldToolbarItem.searchField.stringValue = ""
                }
            } else {
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [unowned self] in
                        await self.urutkanDataPencarian(with: sortDescriptor)
                    }
                }
            }
        }
        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()
        let lastDeletedSiswaArray = SingletonData.redoPastedSiswaArray.removeLast()
        tableView.deselectAll(sender)
        tableView.beginUpdates()
        for siswa in lastDeletedSiswaArray {
            guard let insertedSiswaID = dbController.getInsertedSiswaID() else { return }
            let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)
            if currentTableViewMode == .plain {
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                viewModel.insertSiswa(insertedSiswa, at: insertIndex)
                tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                tempDeletedSiswaArray.append(insertedSiswa)
                tempDeletedIndexes.append(insertIndex)
            } else {
                // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: insertedSiswa, using: sortDescriptor)

                // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                viewModel.insertGroupSiswa(insertedSiswa, groupIndex: 7, index: insertIndex)
                
                // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                tempDeletedSiswaArray.append(insertedSiswa)
                tempDeletedIndexes.append(insertIndex)
            }
        }
        tableView.endUpdates()
        if let maxIndex = tempDeletedIndexes.max() {
            if maxIndex >= tableView.numberOfRows - 1 {
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.scrollRowToVisible(maxIndex)
            }
        }
        // Simpan data yang dihapus untuk redo
        pastedSiswasArray.append(tempDeletedSiswaArray)
        // Catat tindakan redo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoPaste(sender)
        }
        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
    }
    func deleteAllRedoArray(_ sender: Any) {
        if !redoDeletedSiswaArray.isEmpty {redoDeletedSiswaArray.removeAll()}
        if !redoEdit.isEmpty {redoEdit.removeAll()}
        if !redoSnapshotSiswaStack.isEmpty {redoSnapshotSiswaStack.removeAll()}
        if !SingletonData.redoPastedSiswaArray.isEmpty {SingletonData.redoPastedSiswaArray.removeAll()}
        ulangsiswaBaruArray.removeAll()
        redoDeletedIndexes.removeAll()
    }
    // Fungsi untuk menghitung indeks absolut untuk menghapus baris dari NSTableView dalam mode grouped
    private func calculateAbsoluteRowIndex(groupIndex: Int, rowIndexInSection: Int) -> Int {
        var absoluteRowIndex = 0
        for i in 0..<groupIndex {
            let section = viewModel.groupedSiswa[i]
            absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
        }
        return absoluteRowIndex + rowIndexInSection
    }

//    private func addRow(_ sender: Any) {
//        // Let's assume you have text fields for each attribute (nama, alamat, ttl, tahundaftar, namawali).
//        let newNama = "Nama Baru"
//        let newAlamat = "Alamat Baru"
//        let newTtl = "TTL Baru"
//        let newTahunDaftar = "Tahun Daftar Baru"
//        let newNamaWali = "Nama Wali Baru"
//        let newNis = ""
//        let status = ""
//        let jenisKelamin = ""
//
//        // Add the new data to the database
//        dbController.addUser(namaValue: newNama, alamatValue: newAlamat, ttlValue: newTtl, tahundaftarValue: newTahunDaftar, namawaliValue: newNamaWali, nisValue: newNis, jeniskelaminValue: jenisKelamin, statusValue: status, tanggalberhentiValue: "", kelasAktif: "", fotoPath: selectedImageData ?? Data())
//
//        // Update the table view data and reload
//        viewModel.filteredSiswaData = dbController.getSiswa()
//        tableView.reloadData()
//    }
    deinit {
        operationQueue.cancelAllOperations()
        searchItem?.cancel()
        searchItem = nil
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .kelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .dataSiswaDiEdit, object: nil)
        NotificationCenter.default.removeObserver(self, name: .windowControllerBecomeKey, object: nil)
        NotificationCenter.default.removeObserver(self, name: .windowControllerResignKey, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editButtonClicked, object: nil)
        NotificationCenter.default.removeObserver(self, name: .deleteButtonClicked, object: nil)
        NotificationCenter.default.removeObserver(self, name: .popupDismissed, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .siswaNaikDariKelasVC, object: nil)
    }
    // AutoComplete Teks
    private var suggestionManager: SuggestionManager!
    
}
// MARK: - NSTableViewDataSource
extension SiswaViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        // Jumlah total baris = jumlah siswa
        if currentTableViewMode == .plain {
            return viewModel.filteredSiswaData.count
        } else {
            return viewModel.groupedSiswa.reduce(0) { $0 + $1.count + 1 }
        }
    }
    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.groupedSiswa[section].count
    }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard currentTableViewMode == .grouped else { return nil }
        let rowView = CustomRowView()
        let (isGroup, _, _) = getRowInfoForRow(row)
        if isGroup {
            rowView.isGroupRowStyle = true
            return rowView
        } else {
            return NSTableRowView()
        }
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let (isGroupRow, sectionIndex, rowIndexInSection) = getRowInfoForRow(row)
        
        if currentTableViewMode == .plain {
            guard row < viewModel.filteredSiswaData.count else {return NSView()}
            let siswa = viewModel.filteredSiswaData[row]
            
            if let columnIdentifier = tableColumn?.identifier.rawValue {
                switch columnIdentifier {
                case "Nama":
                    return configureSiswaCell(for: tableView, siswa: siswa, row: row)
                case "Tahun Daftar", "Tgl. Lulus":
                    return configureDatePickerCell(for: tableView, tableColumn: tableColumn, siswa: siswa, dateKeyPath: columnIdentifier == "Tahun Daftar" ? \.tahundaftar : \.tanggalberhenti, tag: columnIdentifier == "Tahun Daftar" ? 1 : 2)
                default:
                    return configureGeneralCell(for: tableView, columnIdentifier: columnIdentifier, siswa: siswa, row: row)
                }
            }
        } else if currentTableViewMode == .grouped {
            return configureGroupedCell(for: tableView, tableColumn: tableColumn, isGroupRow: isGroupRow, sectionIndex: sectionIndex, rowIndexInSection: rowIndexInSection)
        }
        
        return NSView()
    }

    private func configureSiswaCell(for tableView: NSTableView, siswa: ModelSiswa, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SiswaCell"), owner: self) as? NSTableCellView else { return nil }
        
        cell.textField?.stringValue = siswa.nama

        loadImageForSiswa(siswa, into: cell.imageView)
        
        return cell
    }
    
    private func loadImageForSiswa(_ siswa: ModelSiswa, into imageView: NSImageView?) {
        let cacheKey = NSString(string: "\(siswa.kelasSekarang)")
        let diskCacheKey = NSString(string: "\(siswa.id)_kelasImage")
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let cachedImage = self?.viewModel.getImageCache(cacheKey) {
                DispatchQueue.main.async(qos: .background) {
                    imageView?.image = cachedImage
                }
                return
            }
        }
        
        self.viewModel.loadImageReferenceFromDisk(for: siswa) { [weak self] kelasImageName in
            guard let self = self else { return }
            if let imageName = kelasImageName, let image = NSImage(named: imageName) {
                DispatchQueue.main.async(qos: .background) {
                    imageView?.image = image
                }
                self.viewModel.setImageCache(image, key: diskCacheKey)
            } else {
                self.viewModel.getImageForKelas(bordered: false, kelasSekarang: siswa.kelasSekarang) { [weak self]  image in
                    guard let self = self else { return }
                    if let image = image {
                        DispatchQueue.main.async(qos: .background) {
                            imageView?.image = image
                        }
                        self.viewModel.saveImageReferenceToDisk(for: siswa)
                        self.viewModel.setImageCache(image, key: diskCacheKey)
                    }
                }
            }
        }
    }

    private func configureGeneralCell(for tableView: NSTableView, columnIdentifier: String, siswa: ModelSiswa, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cellUmum"), owner: self) as? NSTableCellView else { return nil }
        
        switch columnIdentifier {
        case "Alamat": cell.textField?.stringValue = siswa.alamat
        case "T.T.L": cell.textField?.stringValue = siswa.ttl
        case "Nama Wali": cell.textField?.stringValue = siswa.namawali
        case "NIS": cell.textField?.stringValue = siswa.nis
        case "NISN": cell.textField?.stringValue = siswa.nisn
        case "Ayah": cell.textField?.stringValue = siswa.ayah
        case "Ibu": cell.textField?.stringValue = siswa.ibu
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin
        case "Status": cell.textField?.stringValue = siswa.status
        case "Nomor Telepon": cell.textField?.stringValue = siswa.tlv
        default: break
        }
        
        return cell
    }

    private func configureGroupedCell(for tableView: NSTableView, tableColumn: NSTableColumn?, isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
        if isGroupRow {
            return configureHeaderView(for: tableView, sectionIndex: sectionIndex)
        } else {
            return configureGroupedRowView(for: tableView, tableColumn: tableColumn, sectionIndex: sectionIndex, rowIndexInSection: rowIndexInSection)
        }
    }

    private func configureHeaderView(for tableView: NSTableView, sectionIndex: Int) -> NSView? {
        guard let headerView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderView"), owner: nil) as? GroupTableCellView else { return nil }
        if sectionIndex == 0 {
            return nil // Tidak menampilkan header
        }

        headerView.isGroupView = true
        let kelasNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "Lulus", "Tanpa Kelas"]
        headerView.sectionTitle = kelasNames[sectionIndex]
        headerView.sectionIndex = sectionIndex
        headerView.isBoldFont = isSortedByFirstColumn
        
        return headerView
    }

    private func configureGroupedRowView(for tableView: NSTableView, tableColumn: NSTableColumn?, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
        guard sectionIndex >= 0,
              sectionIndex < viewModel.groupedSiswa.count else { return nil }
        
        // Guard untuk memastikan rowIndexInSection valid
        guard rowIndexInSection >= 0,
              rowIndexInSection < viewModel.groupedSiswa[sectionIndex].count else { return nil }

        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CellForRowInGroup"), owner: self) as? NSTableCellView,
              let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }
        
        let siswa = viewModel.groupedSiswa[sectionIndex][rowIndexInSection]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        switch columnIdentifier {
        case "Nama":
            guard let namasiswa = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NamaSiswaGroup"), owner: self) as? NSTableCellView else { return nil }
            namasiswa.textField?.stringValue = siswa.nama
            return namasiswa
        case "Alamat": cell.textField?.stringValue = siswa.alamat
        case "T.T.L": cell.textField?.stringValue = siswa.ttl
        case "Nama Wali": cell.textField?.stringValue = siswa.namawali
        case "NIS": cell.textField?.stringValue = siswa.nis
        case "NISN": cell.textField?.stringValue = siswa.nisn
        case "Ayah": cell.textField?.stringValue = siswa.ayah
        case "Ibu": cell.textField?.stringValue = siswa.ibu
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin
        case "Status": cell.textField?.stringValue = siswa.status
        case "Tahun Daftar":
            let availableWidth = tableColumn?.width ?? 0
            if availableWidth <= 80 {
                dateFormatter.dateFormat = "d/M/yy"
            } else if availableWidth <= 120 {
                dateFormatter.dateFormat = "d MMM yyyy"
            } else {
                dateFormatter.dateFormat = "dd MMMM yyyy"
            }
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tahundaftar
            
            if let date = dateFormatter.date(from: tanggalString) {
                cell.textField?.stringValue = dateFormatter.string(from: date)
            } else {
                cell.textField?.stringValue = tanggalString // fallback jika parsing gagal
            }
        case "Tgl. Lulus":
            let availableWidth = tableColumn?.width ?? 0
            if availableWidth <= 80 {
                dateFormatter.dateFormat = "d/M/yy"
            } else if availableWidth <= 120 {
                dateFormatter.dateFormat = "d MMM yyyy"
            } else {
                dateFormatter.dateFormat = "dd MMMM yyyy"
            }
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tanggalberhenti
            
            if let date = dateFormatter.date(from: tanggalString) {
                cell.textField?.stringValue = dateFormatter.string(from: date)
            } else {
                cell.textField?.stringValue = tanggalString // fallback jika parsing gagal
            }
        case "Nomor Telepon":
            cell.textField?.stringValue = siswa.tlv
        default: break
        }
        return cell
    }
}
extension SiswaViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let columnIdentifier = tableView.tableColumns[columnIndex].identifier.rawValue
        if columnIdentifier == "Nama" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        return true
    }
    
    func tableViewColumnDidMove(_ notification: Notification) {
        updateHeaderMenuOrder()
    }
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        let sortDescriptorDidChange = sortDescriptor != ModelSiswa.currentSortDescriptor
        ModelSiswa.currentSortDescriptor = sortDescriptor
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        saveSortDescriptor(sortDescriptor)
        // Lakukan pengurutan berdasarkan sort descriptor yang dipilih
        if sortDescriptorDidChange || currentTableViewMode == .grouped {
            sortData(with: sortDescriptor)
            if let firstColumnSortDescriptor = tableView.tableColumns.first?.sortDescriptorPrototype {
                isSortedByFirstColumn = (firstColumnSortDescriptor.key == sortDescriptor.key)
            } else {
                isSortedByFirstColumn = false
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard currentTableViewMode == .grouped else { return true }
        // Periksa apakah baris tersebut adalah bagian (section)
        let (isGroupRow, _, _) = getRowInfoForRow(row)
        if isGroupRow {
            return false // Menonaktifkan seleksi untuk bagian (section)
        } else {
            return true // Mengizinkan seleksi untuk baris biasa di dalam bagian
        }
    }
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        // Periksa apakah mode adalah .grouped dan baris adalah header kelas
        if currentTableViewMode == .grouped {
            return getRowInfoForRow(row).isGroupRow
        } else {
            return false // Jika mode adalah .plain, maka tidak ada header kelas yang perlu ditampilkan
        }
    }
    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        if currentTableViewMode == . plain {
            let siswa = viewModel.filteredSiswaData[row]

            // Tentukan nilai tooltip sesuai dengan kolom yang sedang ditunjuk
            if let columnIdentifier = tableColumn?.identifier.rawValue {
                switch columnIdentifier {
                case "Nama":
                    return siswa.nama
                case "Alamat":
                    return siswa.alamat
                case "T.T.L":
                    return siswa.ttl
                case "Tahun Daftar":
                    return siswa.tahundaftar
                case "Nama Wali":
                    return siswa.namawali
                case "NIS":
                    return siswa.nis
                case "Jenis Kelamin":
                    return siswa.jeniskelamin
                case "Status":
                    return siswa.status
                case "Tgl. Lulus":
                    return siswa.tanggalberhenti
                default:
                    break
                }
            }
            return "Tooltip"
        } else {
            let (isGroupRow, sectionIndex, _) = getRowInfoForRow(row)
            if isGroupRow {
                // Ini adalah header kelas
                let kelasNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "Lulus"]
                let groupToolTip = "Tooltip untuk grup: \(kelasNames[sectionIndex])"
                return groupToolTip
            } else {
                let siswa = viewModel.groupedSiswa[sectionIndex][row]
                if let columnIdentifier = tableColumn?.identifier.rawValue {
                    switch columnIdentifier {
                    case "Nama":
                        return "Nama Siswa: \(siswa.nama)"
                    case "Alamat":
                        return "Alamat: \(siswa.alamat)"
                    case "T.T.L":
                        return "Tanggal Lahir: \(siswa.ttl)"
                    case "Tahun Daftar":
                        return "Tahun Daftar: \(siswa.tahundaftar)"
                    case "Nama Wali":
                        return "Nama Orang Tua: \(siswa.namawali)"
                    case "NIS":
                        return "NIS: \(siswa.nis)"
                    case "Jenis Kelamin":
                        return "Jenis Kelamin: \(siswa.jeniskelamin)"
                    case "Status":
                        return "Status: \(siswa.status)"
                    case "Tgl. Lulus":
                        return "Tanggal Berhenti: \(siswa.tanggalberhenti)"
                    default:
                        return "Tooltip default untuk kolom ini"
                    }
                }
                return "Tooltip"
            }
        }
    }
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        return false
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.numberOfRows != 0 else {
            return
        }
        selectedIds.removeAll()
        
        let selectedRow = tableView.selectedRow
        if let toolbar = self.view.window?.toolbar {
            // Aktifkan isEditable pada baris yang sedang dipilih
            if selectedRow != -1 {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton {
                    hapus.isEnabled = true
                    hapus.target = self
                    hapus.action = #selector(deleteSelectedRowsAction(_:))
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton {
                    edit.isEnabled = true
                }
            } else {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton {
                    hapus.isEnabled = false
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                    let edit = editToolbarItem.view as? NSButton {
                        edit.isEnabled = false
                }
            }
        }
        // Nonaktifkan isEditable pada baris yang sedang diedit sebelumnya
        if currentTableViewMode == .grouped {
            
            
        } else if currentTableViewMode == .plain {
            let selectedRowIndexes = tableView.selectedRowIndexes
            let maxRow = viewModel.filteredSiswaData.count - 1

            // Hapus border dari baris yang tidak lagi dipilih
            if let full = previouslySelectedRows.max() {
                guard full < tableView.numberOfRows else {
                    previouslySelectedRows.remove(full)
                    return
                }
                previouslySelectedRows.forEach { row in
                    guard row <= maxRow else { return }
                    if !selectedRowIndexes.contains(row),
                       let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                        let previousSiswa = viewModel.filteredSiswaData[row]
                        viewModel.getImageForKelas(bordered: false, kelasSekarang: previousSiswa.kelasSekarang) { image in
                            DispatchQueue.main.async {
                                previousCellView.imageView?.image = image
                            }
                        }
                    }
                }
            }

            // Tambahkan border ke semua baris yang dipilih
            selectedRowIndexes.forEach { row in
                guard row <= maxRow else { return }
                if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let siswa = viewModel.filteredSiswaData[row]
                    viewModel.getImageForKelas(bordered: true, kelasSekarang: siswa.kelasSekarang) { image in
                        DispatchQueue.main.async {
                            selectedCellView.imageView?.image = image
                        }
                    }
                }
            }

            // Simpan baris yang saat ini dipilih
            previouslySelectedRows = selectedRowIndexes
        }
        
        NSApp.sendAction(#selector(SiswaViewController.updateMenuItem(_:)), to: nil, from: self)
        if tableView.selectedRowIndexes.count > 0 {
            if currentTableViewMode == .plain {
                selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                    viewModel.filteredSiswaData[index].id
                })
            } else {
                selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                    for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                        let startRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: 0)
                        let endRowIndex = startRowIndex + siswaGroup.count
                        if index >= startRowIndex && index < endRowIndex {
                            let siswaIndex = index - startRowIndex
                            return siswaGroup[siswaIndex].id
                        }
                    }
                    return nil
                })
            }
        }
        if suggestionManager != nil {
            if !suggestionManager.isHidden {
                suggestionManager.hideSuggestions()
            }
        }
        if isQuickLookActive {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }
    func tableViewSelectionIsChanging(_ notification: Notification) {
        guard currentTableViewMode == .plain else {return}
        let selectedRowIndexes = tableView.selectedRowIndexes
        
        // Hapus border dari baris yang tidak lagi dipilih
        if let full = previouslySelectedRows.max() {
            guard full < tableView.numberOfRows else {
                previouslySelectedRows.remove(full)
                return
            }
            previouslySelectedRows.forEach { row in
                if !selectedRowIndexes.contains(row), let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let previousSiswa = viewModel.filteredSiswaData[row]
                    viewModel.getImageForKelas(bordered: false, kelasSekarang: previousSiswa.kelasSekarang) { image in
                        DispatchQueue.main.async {
                            previousCellView.imageView?.image = image
                        }
                    }
                }
            }
        }
        
        // Tambahkan border ke semua baris yang dipilih
        selectedRowIndexes.forEach { row in
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                viewModel.getImageForKelas(bordered: true, kelasSekarang: siswa.kelasSekarang) { image in
                    DispatchQueue.main.async {
                        selectedCellView.imageView?.image = image
                    }
                }
            }
        }
        
        // Simpan baris yang saat ini dipilih
        previouslySelectedRows = selectedRowIndexes
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if currentTableViewMode == .grouped {
            let (isGroupRow, _, _) = getRowInfoForRow(row)
            if isGroupRow && row == 0 { return 0.1 }
            else if isGroupRow { return 28.0 }
            else { return tableView.rowHeight }
        } else {
            return tableView.rowHeight
        }
    }
    private func configureDatePickerCell(for tableView: NSTableView, tableColumn: NSTableColumn?, siswa: ModelSiswa, dateKeyPath: KeyPath<ModelSiswa, String>, tag: Int) -> CustomTableCellView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "expDP"), owner: self) as? CustomTableCellView else { return nil }

        // Ambil textField dan DatePicker dari cell yang di-reuse
        let textField = cell.textField
        let pilihTanggal = cell.datePicker
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        
        // Set target dan action untuk DatePicker
        pilihTanggal.target = self
        pilihTanggal.action = #selector(datePickerValueChanged(_:))
        pilihTanggal.tag = tag
        
        
        let availableWidth = tableColumn?.width ?? 0
        
        if availableWidth <= 80 {
            dateFormatter.dateFormat = "d/M/yy"
        } else if availableWidth <= 120 {
            dateFormatter.dateFormat = "d MMM yyyy"
        } else {
            dateFormatter.dateFormat = "dd MMMM yyyy"
        }
        
        // Ambil tanggal dari siswa menggunakan KeyPath
        let tanggalString = siswa[keyPath: dateKeyPath]
        
        // Convert string date to Date object
        if let date = dateFormatter.date(from: tanggalString) {
            pilihTanggal.dateValue = date
            textField?.stringValue = dateFormatter.string(from: date)
        } else {
            textField?.stringValue = tanggalString // fallback jika parsing gagal
        }
        
        // Convert string date to Date object dan set DatePicker value
        textField?.isEditable = false
        
        return cell
    }
    // Fungsi untuk mengatur format tanggal berdasarkan lebar kolom
    func updateDateFormat(for cellView: NSTableCellView, with siswa: ModelSiswa, columnIdentifier: String, dateString: String) {
        let textField = cellView.textField
        let dateFormatter = DateFormatter()

        // Tentukan format tanggal berdasarkan lebar kolom
        if let availableWidth = textField?.bounds.width {
            if availableWidth <= 80 {
                dateFormatter.dateFormat = "d/M/yy"
            } else if availableWidth <= 120 {
                dateFormatter.dateFormat = "d MMM yyyy"
            } else {
                dateFormatter.dateFormat = "dd MMMM yyyy"
            }
        }
        guard !dateString.isEmpty else { return }
        // Convert string date to Date object
        if let date = dateFormatter.date(from: dateString) {
            // Update text field dengan format tanggal yang baru
            textField?.stringValue = dateFormatter.string(from: date)
        }
    }
    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        
        if currentTableViewMode == .plain {
            // Kode untuk mode plain
            tableView.beginUpdates()
            updateCells(for: tableView, columnIdentifier: "Tahun Daftar", siswaData: viewModel.filteredSiswaData)
            updateCells(for: tableView, columnIdentifier: "Tgl. Lulus", siswaData: viewModel.filteredSiswaData)
            tableView.endUpdates()
        } else {
            // Kode untuk mode grup
            tableView.beginUpdates()
            for row in 0..<tableView.numberOfRows {
                let rowInfo = getRowInfoForRow(row)
                // Pastikan bahwa kita tidak memperbarui header grup
                if !rowInfo.isGroupRow {
                    let groupIndex = rowInfo.sectionIndex
                    let rowIndexInSection = rowInfo.rowIndexInSection
                    
                    // Mengakses siswa dari groupedSiswa
                    let siswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                    // Update untuk kolom "Tahun Daftar"
                    if let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tahun Daftar")) {
                        guard !siswa.tahundaftar.isEmpty else { continue }
                        let column = tableView.column(withIdentifier: resizedColumn.identifier)
                        if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                            updateDateFormat(for: cellView, with: siswa, columnIdentifier: "Tahun Daftar", dateString: siswa.tahundaftar)
                        }
                    }

                    // Update untuk kolom "Tgl. Lulus"
                    if let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus")) {
                        guard !siswa.tanggalberhenti.isEmpty else { continue }
                        let column = tableView.column(withIdentifier: resizedColumn.identifier)
                        if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                            updateDateFormat(for: cellView, with: siswa, columnIdentifier: "Tgl. Lulus", dateString: siswa.tanggalberhenti)
                        }
                    }
                }
            }
            tableView.endUpdates()
        }
    }

    // Fungsi untuk memperbarui sel pada mode plain
    private func updateCells(for tableView: NSTableView, columnIdentifier: String, siswaData: [ModelSiswa]) {
        if let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: columnIdentifier)) {
            let columnIndex = tableView.column(withIdentifier: resizedColumn.identifier)
            for row in 0..<siswaData.count {
                let siswa = siswaData[row]
                if let cellView = tableView.view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? CustomTableCellView {
                    let dateString = columnIdentifier == "Tahun Daftar" ? siswa.tahundaftar : siswa.tanggalberhenti
                    if !dateString.isEmpty {
                        updateDateFormat(for: cellView, with: siswa, columnIdentifier: columnIdentifier, dateString: dateString)
                    }
                }
            }
        }
    }
    
    func createTextImage(for name: String) -> NSImage? {
        let font = NSFont.systemFont(ofSize: 13)
        let textSize = name.size(withAttributes: [.font: font])
        let imageSize = NSSize(width: textSize.width, height: tableView.rowHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.controlTextColor]
        name.draw(at: NSPoint(x: 0, y: 0), withAttributes: attributes)
        image.unlockFocus()

        return image
    }
    
    func dragSourceIsFromOurTable(draggingInfo: NSDraggingInfo) -> Bool {
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableView {
            return true
        } else {
            return false
        }
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        session.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            guard let pasteboardItem = dragItem.item as? NSPasteboardItem else {
                print("Error: Tidak dapat mengakses pasteboard item")
                return
            }

            // Ambil data dari pasteboardItem
            if let fotoData = pasteboardItem.data(forType: NSPasteboard.PasteboardType.tiff),
               let image = NSImage(data: fotoData), let nama = pasteboardItem.string(forType: NSPasteboard.PasteboardType.string) {
                // Gunakan foto dari database sebagai drag image
                let dragSize = NSSize(width: tableView.rowHeight, height: tableView.rowHeight)
                let resizedImage = ReusableFunc.resizeImage(image: image, to: dragSize)
                
                // Menghitung lebar teks dengan atribut font
                let font = NSFont.systemFont(ofSize: 13)  // Anda bisa menggunakan font yang sesuai
                let textSize = nama.size(withAttributes: [.font: font])
                
                // Mengatur ukuran drag item
                let textWidth = textSize.width
                let textVerticalPosition = (dragSize.height - 17) / 2  // Posisi tengah vertikal

                // Atur imageComponentsProvider untuk setiap dragItem
                dragItem.imageComponentsProvider = {
                    var components = [NSDraggingImageComponent(key: .icon)]
                    
                    // Komponen untuk foto
                    let fotoComponent = NSDraggingImageComponent(key: .icon)
                    fotoComponent.contents = resizedImage
                    fotoComponent.frame = NSRect(origin: .zero, size: dragSize)
                    components.append(fotoComponent)
                    
                    // Komponen untuk nama
                    let textComponent = NSDraggingImageComponent(key: .label)
                    textComponent.contents = self.createTextImage(for: nama)
                    textComponent.frame = NSRect(x: dragSize.width, y: textVerticalPosition, width: textWidth, height: dragSize.height)
                    components.append(textComponent)
                    return components
                }
                //session.draggingFormation = .list
                
                // Lakukan sesuatu dengan gambar
                #if DEBUG
                print("Foto berhasil didapatkan")
                #endif
            } else {
                #if DEBUG
                print("Error: Tidak ada foto di pasteboardItem")
                #endif
            }
        }
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if currentTableViewMode == .grouped {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                //self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView {
            return false
        }

        let pasteboard = info.draggingPasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        // Drop di luar baris tableview
        if dropOperation == .above {
            var insertedSiswaIDs: [Int64] = []
            var tempInsertedIndexes = [Int]()
            var tempDeletedSiswaArray = [ModelSiswa]()
            tableView.deselectAll(nil)
            let group = DispatchGroup()
            group.enter()
            guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {return false}
            DispatchQueue.global(qos: .background).async { [unowned self] in
                for fileURL in fileURLs {
                    if let image = NSImage(contentsOf: fileURL) {
                        let compressedImageData = image.compressImage(quality: 0.5) ?? Data()
                        let fileName = fileURL.deletingPathExtension().lastPathComponent
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                        let currentDate = dateFormatter.string(from: Date())
                        dbController.catatSiswa(namaValue: fileName, alamatValue: "", ttlValue: "", tahundaftarValue: currentDate, namawaliValue: "", nisValue: "", nisnValue: "", namaAyah: "", namaIbu: "", jeniskelaminValue: "", statusValue: "Aktif", tanggalberhentiValue: "", kelasAktif: "", noTlv: "", fotoPath: compressedImageData)
                        // Dapatkan ID siswa yang baru ditambahkan
                        if let insertedSiswaID = dbController.getInsertedSiswaID() {
                            // Simpan insertedSiswaID ke array
                            insertedSiswaIDs.append(insertedSiswaID)
                        }
                    }
                }
                // Hapus semua informasi dari array redo
                deleteAllRedoArray(self)
                // Daftarkan aksi undo untuk paste
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
                    targetSelf.undoPaste(self)
                }
                group.leave()
            }
            
            group.notify(queue: .main) { [unowned self] in
                tableView.beginUpdates()
                for insertedSiswaID in insertedSiswaIDs {
                    // Dapatkan data siswa yang baru ditambahkan dari database
                    let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)
                    
                    if currentTableViewMode == .plain {
                        // Pastikan siswa yang baru ditambahkan belum ada di tabel
                        guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else {
                            continue
                        }
                        // Tentukan indeks untuk menyisipkan siswa baru ke dalam array viewModel.filteredSiswaData sesuai dengan urutan kolom
                        let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Masukkan siswa baru ke dalam array viewModel.filteredSiswaData
                        viewModel.insertSiswa(insertedSiswa, at: insertIndex)
                        

                        // Tambahkan baris baru ke tabel dengan animasi
                        tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .effectGap)
                        // Pilih baris yang baru ditambahkan
                        tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                        tempInsertedIndexes.append(insertIndex)
                    } else {
                        // Pastikan siswa yang baru ditambahkan belum ada di groupedSiswa
                        let siswaAlreadyExists = viewModel.groupedSiswa.flatMap { $0 }.contains(where: { $0.id == insertedSiswaID })
                        
                        if siswaAlreadyExists {
                            continue // Jika siswa sudah ada, lanjutkan ke siswa berikutnya
                        }
                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                        viewModel.insertGroupSiswa(insertedSiswa, groupIndex: 7, index: insertIndex)
                        
                        // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                        tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .effectGap)
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                        tempInsertedIndexes.append(absoluteRowIndex + 1)
                    }
                    tempDeletedSiswaArray.append(insertedSiswa)
                }
                tableView.endUpdates()
                if let maxIndex = tempInsertedIndexes.max() {
                    if maxIndex >= tableView.numberOfRows - 1 {
                        tableView.scrollToEndOfDocument(self)
                    } else {
                        tableView.scrollRowToVisible(maxIndex + 1)
                    }
                }
                pastedSiswasArray.append(tempDeletedSiswaArray)
                
                updateUndoRedo(self)
            }
            return true
        }
        
        // Untuk operasi non-.above, hanya proses file pertama
        guard let imageURL = fileURLs.first,
              let image = NSImage(contentsOf: imageURL) else {
            return false
        }
        
        
        guard row != -1, row < viewModel.filteredSiswaData.count else {
            return false}
        if dragSourceIsFromOurTable(draggingInfo: info) {
            // Drag source came from our own table view.
            return false
        }
        
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            var id: Int64!
            if currentTableViewMode == .plain {
                id = viewModel.filteredSiswaData[row].id
            } else {
                var cumulativeRow = row
                for (_, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                    let groupCount = siswaGroup.count + 1 // +1 untuk header
                    if cumulativeRow < groupCount {
                        let siswaIndex = cumulativeRow - 1 // -1 untuk mengabaikan header
                        if siswaIndex >= 0 && siswaIndex < siswaGroup.count {
                            id = siswaGroup[siswaIndex].id
                        }
                        break
                    }
                    cumulativeRow -= groupCount
                }
            }
            let imageData = dbController.bacaFotoSiswa(idValue: id)
            let compressedImageData = image.compressImage(quality: 0.5) ?? Data()
            dbController.updateFotoInDatabase(with: compressedImageData, idx: id)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
                self?.undoDragFoto(id, image: imageData.foto)
            })

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                self.updateUndoRedo(self)
            }
        }
        return true
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView {
            return [] // Return empty operation to disable drop
        }
        if dropOperation == .above {
            info.animatesToDestination = true
            tableView.setDropRow(-1, dropOperation: .above)
            return .copy
        } else {
            info.animatesToDestination = true
            return .copy
        }
    }
    
    func undoDragFoto(_ id: Int64, image: Data) {
        tableView.deselectAll(self)
        
        let data = dbController.bacaFotoSiswa(idValue: id).foto
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.redoDragFoto(id, image: data)
        })
        dbController.updateFotoInDatabase(with: image, idx: id)
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: {$0.id == id}) else {return}
            index = rowIndex
        } else {
            for (groupIndex, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                // Jika dalam mode `grouped`, cari di setiap grup
                if let siswaIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                    // Dapatkan `rowIndex` absolut menggunakan `getAbsoluteRowIndex`
                    index = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                    break
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
            updateUndoRedo(self)
        }
    }
    func redoDragFoto(_ id: Int64, image: Data) {
        tableView.deselectAll(self)
        
        let data = dbController.bacaFotoSiswa(idValue: id).foto
        dbController.updateFotoInDatabase(with: image, idx: id)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.undoDragFoto(id, image: data)
        })
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: {$0.id == id}) else {return}
            index = rowIndex
        } else {
            for (groupIndex, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                // Jika dalam mode `grouped`, cari di setiap grup
                if let siswaIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                    // Dapatkan `rowIndex` absolut menggunakan `getAbsoluteRowIndex`
                    index = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                    break
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
            updateUndoRedo(self)
        }
    }
}

//MARK: -NSSEARCHFIELD & TEXTVIEW EDITING OPERATIONS
extension SiswaViewController: NSSearchFieldDelegate {
    @objc func procSearchFieldInput (sender:NSSearchField) {
        #if DEBUG
        print("search")
        #endif
        searchItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.tableView.resignFirstResponder()
            self?.search(sender.stringValue)
            self?.stringPencarian = sender.stringValue
        }
        searchItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchItem!)
    }
    func search(_ searchText: String) {
        if searchText == stringPencarian {return}
        // Update previousSearchText dengan nilai baru
        stringPencarian = searchText
        guard let sortDescriptor = loadSortDescriptor() else {return}
        if currentTableViewMode == .plain {
            if !stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    await self.viewModel.cariSiswa(stringPencarian)
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: isBerhentiHidden)
                    
                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    await self.viewModel.fetchSiswaData()
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: isBerhentiHidden)
                    
                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            }
        } else {
            if !stringPencarian.isEmpty  {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    await self.viewModel.cariSiswa(stringPencarian)
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)
                    
                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    await self.viewModel.fetchSiswaData()
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)
                    
                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            }
        }
    }
}

//MARK: - TABLEVIEW MENU RELATED FUNC.
extension SiswaViewController: NSMenuDelegate {
    @IBAction private func pilihubahStatus(_ sender: NSMenuItem) {
        guard let statusString = sender.representedObject as? String else {
            return
        }
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.messageText = "Konfirmasi Pengubahan Status"
        alert.informativeText = "Apakah Anda yakin mengubah status dari \(tableView.selectedRowIndexes.count) siswa menjadi \"\(statusString)\"?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let tglsekarang = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: tglsekarang)
        let selectedSiswa: [ModelSiswa] = tableView.selectedRowIndexes.compactMap { row in
            let originalSiswa = viewModel.filteredSiswaData[row]
            let snapshot = ModelSiswa()
            // Copy semua properti yang diperlukan
            snapshot.id = originalSiswa.id
            snapshot.nama = originalSiswa.nama
            snapshot.alamat = originalSiswa.alamat
            snapshot.ttl = originalSiswa.ttl
            snapshot.tahundaftar = originalSiswa.tahundaftar
            snapshot.namawali = originalSiswa.namawali
            snapshot.nis = originalSiswa.nis
            snapshot.nisn = originalSiswa.nisn
            snapshot.ayah = originalSiswa.ayah
            snapshot.ibu = originalSiswa.ibu
            snapshot.jeniskelamin = originalSiswa.jeniskelamin
            snapshot.status = originalSiswa.status
            snapshot.kelasSekarang = originalSiswa.kelasSekarang
            snapshot.tanggalberhenti = originalSiswa.tanggalberhenti
            snapshot.tlv = originalSiswa.tlv
            snapshot.index = originalSiswa.index
            snapshot.originalIndex = originalSiswa.originalIndex
            snapshot.menuDiupdate = originalSiswa.menuDiupdate
            snapshot.foto = originalSiswa.foto
            
            
            return snapshot
        }
        // Menampilkan peringatan dan menunggu respons
        let response = alert.runModal()
        // Jika pengguna menekan tombol "Hapus"
        guard response == .alertFirstButtonReturn else { return }
        let selectedRows = tableView.selectedRowIndexes
        self.snapshotSiswaStack.append(selectedSiswa)
        let columnIndexOfStatus = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Status"))
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah identifier sesuai dengan yang sebenarnya
        var terproses = selectedSiswa.count
        var processAll = false
        var cancelAll = false
        
        // Melakukan update status siswa ke database untuk setiap siswa yang dipilih
        for rowIndex in selectedRows.reversed() {
            let siswa = viewModel.filteredSiswaData[rowIndex]
            guard siswa.status != statusString else {continue}
            let idSiswa = siswa.id
            if statusString == StatusSiswa.lulus.rawValue {
                let namaSiswa = siswa.nama
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }
                }
                // Jika sebelumnya memilih "Terapkan ke semua", langsung jalankan tanpa konfirmasi
                if processAll {
                    self.dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [idSiswa],
                        "kelasSekarang": siswa.kelasSekarang,
                        "isDeleted": true
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    siswa.status = StatusSiswa.lulus.rawValue
                    siswa.kelasSekarang = "Lulus"
                    siswa.tanggalberhenti = tanggalSekarang
                    self.viewModel.updateSiswa(siswa, at: rowIndex)
                    // Memperbarui hanya baris dan kolom status pada tableView
                    DispatchQueue.main.async { [unowned self] in
                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndexOfStatus, columnIndexOfKelasAktif])) // Memperbarui kedua kolom yang terlibat
                        if let cellView = tableView.view(atColumn: columnIndexOfStatus, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                            cellView.textField?.stringValue = statusString
                        }
                        if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                           let imageView = namaView.imageView {
                            // Mendapatkan gambar baru berdasarkan status siswa
                            if statusString == "Lulus" {
                                imageView.image = NSImage(named: "lulus Bordered")
                            }
                        }
                    }
                    if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                        if statusString == StatusSiswa.lulus.rawValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {[weak self] in
                                guard let self = self else {return}
                                if rowIndex + 1 < self.tableView.numberOfRows {
                                    self.tableView.selectRowIndexes(IndexSet([rowIndex + 1]), byExtendingSelection: false)
                                }
                                self.tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .slideUp)
                                self.viewModel.removeSiswa(at: rowIndex)
                            }
                        }
                    }
                    continue
                }
                
                // Jika sebelumnya memilih "Batalkan Semua", lanjut ke item berikutnya
                if cancelAll {
                    siswa.status = StatusSiswa.lulus.rawValue
                    siswa.kelasSekarang = "Lulus"
                    siswa.tanggalberhenti = tanggalSekarang
                    self.viewModel.updateSiswa(siswa, at: rowIndex)
                    continue
                }
                
                let confirmAlert = NSAlert()
                confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
                confirmAlert.messageText = "Status Siswa Lulus! Hapus data siswa di Kelas Aktif sebelumnya?"
                confirmAlert.informativeText = "Apakah Anda yakin menghapus data siswa di Kelas Aktif \(siswa.kelasSekarang)?"
                confirmAlert.addButton(withTitle: "OK")
                confirmAlert.addButton(withTitle: "Batalkan")
                confirmAlert.showsSuppressionButton = true
                confirmAlert.suppressionButton?.title = "Terapkan ke (\(terproses - 1) siswa tersisa)"
                
                let secondResponse = confirmAlert.runModal()
                
                // Jika suppression button dicentang, simpan keputusan pengguna
                if let suppressionButton = confirmAlert.suppressionButton, suppressionButton.state == .on {
                    processAll = (secondResponse == .alertFirstButtonReturn)
                    cancelAll = !processAll
                }
                
                if secondResponse == .alertFirstButtonReturn {
                    self.dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [idSiswa],
                        "kelasSekarang": siswa.kelasSekarang,
                        "isDeleted": true
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    siswa.status = StatusSiswa.lulus.rawValue
                    siswa.kelasSekarang = "Lulus"
                    siswa.tanggalberhenti = tanggalSekarang
                    self.viewModel.updateSiswa(siswa, at: rowIndex)
                } else {
                    siswa.status = StatusSiswa.lulus.rawValue
                    siswa.kelasSekarang = "Lulus"
                    siswa.tanggalberhenti = tanggalSekarang
                    self.viewModel.updateSiswa(siswa, at: rowIndex)
                }
                terproses -= 1
            } else if statusString == StatusSiswa.berhenti.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: "")
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.berhenti.rawValue
                siswa.tanggalberhenti = tanggalSekarang
                viewModel.updateSiswa(siswa, at: rowIndex)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }
                }
            } else if statusString == StatusSiswa.aktif.rawValue {
                dbController.updateTglBerhenti(kunci: idSiswa, editTglBerhenti: "")
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.aktif.rawValue
                siswa.tanggalberhenti = ""
                viewModel.updateSiswa(siswa, at: rowIndex)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = ""
                    }
                }
            }
            // Memperbarui hanya baris dan kolom status pada tableView
            DispatchQueue.main.async { [unowned self] in
                tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndexOfStatus, columnIndexOfKelasAktif])) // Memperbarui kedua kolom yang terlibat
                if let cellView = tableView.view(atColumn: columnIndexOfStatus, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                    cellView.textField?.stringValue = statusString
                }
                if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                   let imageView = namaView.imageView {
                    // Mendapatkan gambar baru berdasarkan status siswa
                    if statusString == "Lulus" {
                        imageView.image = NSImage(named: "lulus Bordered")
                    } else {
                        imageView.image = NSImage(named: "\(viewModel.filteredSiswaData[rowIndex].kelasSekarang) Bordered")
                    }
                }
            }
            if isBerhentiHidden {
                if statusString == StatusSiswa.berhenti.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else {return}
                        if rowIndex + 1 < self.tableView.numberOfRows {
                            self.tableView.selectRowIndexes(IndexSet([rowIndex + 1]), byExtendingSelection: false)
                        }
                        self.tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .slideUp)
                        self.viewModel.removeSiswa(at: rowIndex)
                    }
                }
            }
            if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                if statusString == StatusSiswa.lulus.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {[weak self] in
                        guard let self = self else {return}
                        if rowIndex + 1 < self.tableView.numberOfRows {
                            self.tableView.selectRowIndexes(IndexSet([rowIndex + 1]), byExtendingSelection: false)
                        }
                        self.tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .slideUp)
                        self.viewModel.removeSiswa(at: rowIndex)
                    }
                }
            }
        }
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] target in
            self?.viewModel.undoEditSiswa(selectedSiswa)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            deleteAllRedoArray(sender)
            updateUndoRedo(sender)
        }
    }
    @objc private func klikubahStatus(_ sender: NSMenuItem) {
        guard let statusString = sender.representedObject as? String else { return }
        // Mendapatkan ID siswa yang ingin diubah statusnya
        let clickedRow = tableView.clickedRow
        let siswa = viewModel.filteredSiswaData[clickedRow]
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.messageText = "Konfirmasi Pengubahan Status"
        alert.informativeText = "Apakah Anda yakin mengubah status \(siswa.nama) menjadi \"\(statusString)\"?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let snapshot = ModelSiswa()
        // Copy semua properti yang diperlukan
        snapshot.id = siswa.id
        snapshot.nama = siswa.nama
        snapshot.alamat = siswa.alamat
        snapshot.ttl = siswa.ttl
        snapshot.tahundaftar = siswa.tahundaftar
        snapshot.namawali = siswa.namawali
        snapshot.nis = siswa.nis
        snapshot.nisn = siswa.nisn
        snapshot.ayah = siswa.ayah
        snapshot.ibu = siswa.ibu
        snapshot.jeniskelamin = siswa.jeniskelamin
        snapshot.status = siswa.status
        snapshot.kelasSekarang = siswa.kelasSekarang
        snapshot.tanggalberhenti = siswa.tanggalberhenti
        snapshot.tlv = siswa.tlv
        snapshot.index = siswa.index
        snapshot.originalIndex = siswa.originalIndex
        snapshot.menuDiupdate = siswa.menuDiupdate
        snapshot.foto = siswa.foto
        let tglsekarang = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: tglsekarang)
        

        // Menampilkan peringatan dan menunggu respons
        let response = alert.runModal()
        guard siswa.status != statusString else {return}
        // Jika pengguna menekan tombol "Hapus"
        if response == .alertFirstButtonReturn {
            self.snapshotSiswaStack.append([snapshot])
            let idSiswa = siswa.id
            
            
            
            let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // identifier
            let columnIndexOfStatus = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Status"))
            let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))
            
            // Melakukan update status siswa ke database
            if statusString == StatusSiswa.lulus.rawValue {
                let namaSiswa = siswa.nama
                siswa.status = StatusSiswa.lulus.rawValue
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }
                }
                DispatchQueue.main.async {
                    let confirmAlert = NSAlert()
                    confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
                    confirmAlert.messageText = "Status Siswa Lulus! Hapus juga data siswa di Kelas Aktif sebelumnya?"
                    confirmAlert.informativeText = "Apakah Anda yakin menghapus data \(siswa.nama) di Kelas Aktif \(siswa.kelasSekarang)?"
                    confirmAlert.addButton(withTitle: "OK")
                    confirmAlert.addButton(withTitle: "Batalkan")
                    
                    let secondResponse = confirmAlert.runModal()
                    if secondResponse == .alertFirstButtonReturn {
                        self.dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": [idSiswa],
                            "kelasSekarang": siswa.kelasSekarang,
                            "isDeleted": true
                        ]
                        NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                        siswa.kelasSekarang = "Lulus"
                        siswa.tanggalberhenti = tanggalSekarang
                        self.viewModel.updateSiswa(siswa, at: clickedRow)

                    } else {
                        siswa.kelasSekarang = "Lulus"
                        siswa.tanggalberhenti = tanggalSekarang
                        self.viewModel.updateSiswa(siswa, at: clickedRow)
                    }
                }
            } else if statusString == StatusSiswa.berhenti.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: tanggalSekarang)
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.berhenti.rawValue
                siswa.tanggalberhenti = tanggalSekarang
                viewModel.updateSiswa(siswa, at: clickedRow)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }}
            } else if statusString == StatusSiswa.aktif.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: "")
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.aktif.rawValue
                siswa.tanggalberhenti = ""
                viewModel.updateSiswa(siswa, at: clickedRow)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = ""
                    }}
            }
            // Memperbarui hanya kolom "Status" pada tableView
            DispatchQueue.main.async { [unowned self] in
                tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfStatus]))
                if let cellView = tableView.view(atColumn: columnIndexOfStatus, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                    cellView.textField?.stringValue = statusString
                }
                if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
                   let imageView = namaView.imageView {
                    // Mendapatkan gambar baru berdasarkan status siswa
                    if statusString == StatusSiswa.lulus.rawValue {
                        imageView.image = NSImage(named: "lulus")
                    } else {
                        imageView.image = NSImage(named: "\(viewModel.filteredSiswaData[clickedRow].kelasSekarang)")
                    }
                }
            }
            if isBerhentiHidden {
                if statusString == StatusSiswa.berhenti.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if clickedRow + 1 < self.tableView.numberOfRows {
                            self.tableView.selectRowIndexes(IndexSet([clickedRow + 1]), byExtendingSelection: false)
                        }
                        self.tableView.removeRows(at: IndexSet([clickedRow]), withAnimation: .slideUp)
                        self.viewModel.removeSiswa(at: clickedRow)
                    }
                }
            }
            if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                if statusString == StatusSiswa.lulus.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if clickedRow + 1 < self.tableView.numberOfRows {
                            self.tableView.selectRowIndexes(IndexSet([clickedRow + 1]), byExtendingSelection: false)
                        }
                        self.tableView.removeRows(at: IndexSet([clickedRow]), withAnimation: .slideUp)
                        self.viewModel.removeSiswa(at: clickedRow)
                    }
                }
            }
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] target in
                self?.viewModel.undoEditSiswa([snapshot])
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                deleteAllRedoArray(sender)
                updateUndoRedo(sender)
            }
        }
    }
    @objc func updateKelasDipilih(_ kelasAktifString: String) {
        guard !tableView.selectedRowIndexes.isEmpty else {return}
        let selectedSiswa: [ModelSiswa] = tableView.selectedRowIndexes.compactMap { row in
            let originalSiswa = viewModel.filteredSiswaData[row]
            let snapshot = ModelSiswa()
            // Copy semua properti yang diperlukan
            snapshot.id = originalSiswa.id
            snapshot.nama = originalSiswa.nama
            snapshot.alamat = originalSiswa.alamat
            snapshot.ttl = originalSiswa.ttl
            snapshot.tahundaftar = originalSiswa.tahundaftar
            snapshot.namawali = originalSiswa.namawali
            snapshot.nis = originalSiswa.nis
            snapshot.nisn = originalSiswa.nisn
            snapshot.ayah = originalSiswa.ayah
            snapshot.ibu = originalSiswa.ibu
            snapshot.jeniskelamin = originalSiswa.jeniskelamin
            snapshot.status = originalSiswa.status
            snapshot.kelasSekarang = originalSiswa.kelasSekarang
            snapshot.tanggalberhenti = originalSiswa.tanggalberhenti
            snapshot.tlv = originalSiswa.tlv
            snapshot.index = originalSiswa.index
            snapshot.originalIndex = originalSiswa.originalIndex
            snapshot.menuDiupdate = originalSiswa.menuDiupdate
            snapshot.foto = originalSiswa.foto

            return snapshot
        }
        
        let selectedRowIndexes = tableView.selectedRowIndexes
        
        
        var terproses = selectedRowIndexes.count
        var processAll = false
        var cancelAll = false
        for rowIndex in selectedRowIndexes {
            let siswa = viewModel.filteredSiswaData[rowIndex]
            guard siswa.kelasSekarang != kelasAktifString else{continue}
            let idSiswa = siswa.id
            let kelasAwal = siswa.kelasSekarang
            let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
            // let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
            if siswa.kelasSekarang != kelasAktifString {
                siswa.kelasSekarang = kelasAktifString
                viewModel.updateSiswa(siswa, at: rowIndex)
                dbController.updateKelasAktif(idSiswa: idSiswa, newKelasAktif: kelasAktifString)
            }
            
            if processAll {
                hapusKelasLama(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
                continue
            }
            
            // Jika sebelumnya sudah memilih "Batalkan Semua", langsung lewati iterasi ini
            if cancelAll {
                continue
            }
            
            let confirmAlert = NSAlert()
            confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
            confirmAlert.messageText = "Hapus juga data \(siswa.nama) di Kelas Aktif sebelumnya?"
            confirmAlert.informativeText = "Data \(siswa.nama) akan dihapus dari Kelas Aktif \(siswa.kelasSekarang). Lanjutkan?"
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.addButton(withTitle: "Batalkan")
            confirmAlert.showsSuppressionButton = true
            confirmAlert.suppressionButton?.title = "Terapkan ke (\(terproses) siswa tersisa)"

            let confirmResponse = confirmAlert.runModal()
            
            // Jika suppression button dicentang, simpan keputusan pengguna
            if let suppressionButton = confirmAlert.suppressionButton, suppressionButton.state == .on {
                if confirmResponse == .alertFirstButtonReturn {
                    processAll = true
                } else {
                    cancelAll = true
                }
            }
            
            // Jika pengguna menekan tombol "OK" pada konfirmasi kedua
            if confirmResponse == .alertFirstButtonReturn {
                hapusKelasLama(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
            }
            terproses -= 1
        }
        self.snapshotSiswaStack.append(selectedSiswa)
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))
        DispatchQueue.main.async { [unowned self] in
            for rowIndex in selectedRowIndexes {
                if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                   let imageView = namaView.imageView {
                    // Mendapatkan gambar baru berdasarkan kelas siswa
                    if let kelasAktif = KelasAktif(rawValue: kelasAktifString) {
                        let imageName = kelasAktif.rawValue
                        imageView.image = NSImage(named: "\(imageName) Bordered")
                    }
                }
                if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                    tglView.textField?.stringValue = ""
                }
            }
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] target in
                self?.viewModel.undoEditSiswa(selectedSiswa)
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                deleteAllRedoArray(self)
                updateUndoRedo(self)
            }
        }
    }
    @objc func updateKelasKlik(_ kelasAktifString: String, clickedRow: Int) {
        guard clickedRow >= 0 else {return}
        let siswa = viewModel.filteredSiswaData[clickedRow]
        let snapshot = ModelSiswa()
        snapshot.id = siswa.id
        snapshot.nama = siswa.nama
        snapshot.alamat = siswa.alamat
        snapshot.ttl = siswa.ttl
        snapshot.tahundaftar = siswa.tahundaftar
        snapshot.namawali = siswa.namawali
        snapshot.nis = siswa.nis
        snapshot.nisn = siswa.nisn
        snapshot.ayah = siswa.ayah
        snapshot.ibu = siswa.ibu
        snapshot.jeniskelamin = siswa.jeniskelamin
        snapshot.status = siswa.status
        snapshot.kelasSekarang = siswa.kelasSekarang
        snapshot.tanggalberhenti = siswa.tanggalberhenti
        snapshot.tlv = siswa.tlv
        snapshot.index = siswa.index
        snapshot.originalIndex = siswa.originalIndex
        snapshot.menuDiupdate = siswa.menuDiupdate
        snapshot.foto = siswa.foto
        guard siswa.kelasSekarang != kelasAktifString else{return}
        let idSiswa = siswa.id
        
        let kelasAwal = siswa.kelasSekarang
        let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
        if siswa.kelasSekarang != kelasAktifString {
            siswa.kelasSekarang = kelasAktifString
            viewModel.updateSiswa(siswa, at: clickedRow)
            dbController.updateKelasAktif(idSiswa: idSiswa, newKelasAktif: kelasAktifString)
        }
        let confirmAlert = NSAlert()
        confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        confirmAlert.messageText = "Hapus juga data \(siswa.nama) di Kelas Aktif sebelumnya?"
        confirmAlert.informativeText = "Data \(siswa.nama) akan dihapus dari Kelas Aktif \(siswa.kelasSekarang). Lanjutkan?"
        confirmAlert.addButton(withTitle: "OK")
        confirmAlert.addButton(withTitle: "Batalkan")
        let confirmResponse = confirmAlert.runModal()
        
        // Jika pengguna menekan tombol "OK" pada konfirmasi kedua
        if confirmResponse == .alertFirstButtonReturn {
            // Hanya memanggil updateKelasAktif untuk kelas yang tidak sama dengan yang dipilih
            hapusKelasLama(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
        }
        
        self.snapshotSiswaStack.append([snapshot])
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus")) // Ubah
        DispatchQueue.main.async { [unowned self] in
            // tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfKelasAktif]))
            if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
               let imageView = namaView.imageView {
                // Mendapatkan gambar baru berdasarkan kelas siswa
                if let kelasAktif = KelasAktif(rawValue: kelasAktifString) {
                    let imageName = kelasAktif.rawValue
                    imageView.image = NSImage(named: imageName)
                } else {
                    imageView.image = NSImage(named: "No Data")
                }
            }
            if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                tglView.textField?.stringValue = ""
            }
        }
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] target in
            self?.viewModel.undoEditSiswa([snapshot])
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            deleteAllRedoArray(self)
            updateUndoRedo(self)
        }
    }
    func hapusKelasLama(idSiswa: Int64, kelasAwal: String, kelasYangDikecualikan: String) {
        dbController.updateTabelKelasAktif(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
        NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
            "deletedStudentIDs": [idSiswa],
            "kelasSekarang": kelasAwal,
            "isDeleted": true
        ])
    }
    func updateFotoKelasAktifBordered(_ row: Int, kelas: String) {
        Task(priority: .userInitiated) { @MainActor [unowned self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik
            let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
            if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: row, makeIfNecessary: false) as? NSTableCellView,
               let imageView = namaView.imageView {
                
                if kelas == "Lulus" {
                    imageView.image = NSImage(named: "lulus Bordered")
                    return
                }
                
                if kelas.isEmpty {
                    imageView.image = NSImage(named: "No Data Bordered")
                    return
                }
                
                imageView.image = NSImage(named: "\(kelas) Bordered")
                
            }
        }
    }
    
    @objc private func siswaNaik(_ notification: Notification) {
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["siswaID"] as? Int64,
           let kelasBaru = userInfo["kelasBaru"] as? String {
            Task(priority: .background) { [weak self] in
                if self?.currentTableViewMode == .plain {
                    guard let s = self else { return }
                    if let index = s.viewModel.filteredSiswaData.firstIndex(where: {$0.id == deletedIDs}) {
                        let siswa = s.dbController.getSiswa(idValue: deletedIDs)
                    if siswa.kelasSekarang != kelasBaru {
                        siswa.kelasSekarang = kelasBaru
                        s.viewModel.updateSiswa(siswa, at: index)
                        s.viewModel.removeImageReferenceToDisk(for: siswa)
                        s.viewModel.saveImageReferenceToDisk(for: siswa)
                    }
                    Task(priority: .userInitiated) { @MainActor [unowned s] in
                        s.tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet([columnIndexOfKelasAktif]))
                        if let namaView = s.tableView.view(atColumn: columnIndexOfKelasAktif, row: index, makeIfNecessary: false) as? NSTableCellView,
                           let imageView = namaView.imageView {
                            // Mendapatkan gambar baru berdasarkan kelas siswa
                            if siswa.kelasSekarang == kelasBaru {
                                if kelasBaru == "Lulus" {
                                    imageView.image = NSImage(named: "lulus")
                                } else {
                                    imageView.image = NSImage(named: "\(kelasBaru)")
                                }
                            }
                        }
                    }
                }
            } else {
                guard let self = self, let (groupIndex, rowIndex) = self.viewModel.findSiswaInGroups(id: deletedIDs), let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
                    
                    // Mengambil data siswa dari grup yang ditemukan
                    let siswa = self.dbController.getSiswa(idValue: deletedIDs)
                    
                    // Memperbarui kelas siswa jika diperlukan
                    self.viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)
                    let newGroupIndex = self.getGroupIndex(forClassName: kelasBaru) ?? groupIndex
                    let insertIndex = self.viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: siswa, using: sortDescriptor)
                    self.viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex, index: insertIndex)
                    
                    // Menyimpan perubahan pada disk
                    self.viewModel.removeImageReferenceToDisk(for: siswa)
                    self.viewModel.saveImageReferenceToDisk(for: siswa)
                    self.updateTableViewForSiswaMove(from: (groupIndex, rowIndex), to: (newGroupIndex, insertIndex))
                }
            }
        }
    }
    func saveToCSV(header: [String], siswaData: [ModelSiswa], destinationURL: URL) throws {
        // Membuat baris data siswa sebagai array dari string
        let rows = siswaData.map { [$0.nama, $0.alamat, String($0.nisn), String($0.nis), $0.namawali, $0.ayah, $0.ibu, $0.tlv, $0.jeniskelamin, $0.kelasSekarang, $0.tahundaftar, $0.status, $0.tanggalberhenti] }
        
        // Menggabungkan header dengan data dan mengubahnya menjadi string CSV
        let csvString = ([header] + rows).map { $0.joined(separator: ";") }.joined(separator: "\n")

        // Menulis string CSV ke file
        try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)
        
        
    }
    
    func chooseFolderAndSaveCSV(header: [String], siswaData: [ModelSiswa], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?, pdf: Bool) {
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
}

extension SiswaViewController: OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard row < viewModel.filteredSiswaData.count else { return "" }
        
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
    
        if currentTableViewMode == .grouped {
            let selectedRowInfo = getRowInfoForRow(row)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            guard rowIndexInSection != -1 else { return "" }
            return viewModel.getOldValueForColumn(columnIdentifier: columnIdentifier, isGrouped: true, groupIndex: groupIndex, rowInSection: rowIndexInSection)
        }
        
        return viewModel.getOldValueForColumn(rowIndex: row, columnIdentifier: columnIdentifier, data: viewModel.filteredSiswaData)
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        return tableView.tableColumns[column].width
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "Nama":
            return Array(ReusableFunc.namasiswa)
        case "Alamat":
            return Array(ReusableFunc.alamat)
        case "T.T.L":
            return Array(ReusableFunc.ttl)
        case "NIS":
            return Array(ReusableFunc.nis)
        case "NISN":
            return Array(ReusableFunc.nisn)
        case "Nama Wali":
            return Array(ReusableFunc.namawali)
        case "Ayah":
            return Array(ReusableFunc.namaAyah)
        case "Ibu":
            return Array(ReusableFunc.namaIbu)
        case "Nomor Telepon":
            return Array(ReusableFunc.tlvString)
        default:
            return []
        }
    }
}


extension SiswaViewController: OverlayEditorManagerDelegate{
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard column < tableView.tableColumns.count else {
            return
        }
        let newValue = newText.capitalizedAndTrimmed()
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        var oldValue = ""
        var originalModel: DataAsli?
        
        if currentTableViewMode == .grouped {
            
            let selectedRowInfo = getRowInfoForRow(row)
            
            let groupIndex = selectedRowInfo.sectionIndex
            
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            
            guard rowIndexInSection != -1 else { return }
            
            oldValue = viewModel.getOldValueForColumn(columnIdentifier: columnIdentifier, isGrouped: true, groupIndex: groupIndex, rowInSection: rowIndexInSection)
            
            if newValue != oldValue {
                let id = viewModel.groupedSiswa[groupIndex][rowIndexInSection].id
                originalModel = DataAsli(ID: id, rowIndex: row, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue)
                viewModel.updateModelAndDatabase(id: id, columnIdentifier: columnIdentifier, newValue: newValue, oldValue: oldValue, isGrouped: true, groupIndex: groupIndex, rowInSection: rowIndexInSection)
                // Daftarkan aksi undo ke NSUndoManager
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    targetSelf.viewModel.undoAction(originalModel: originalModel!)
                })
            }
        }
        else {
            let id = viewModel.filteredSiswaData[row].id
            oldValue = viewModel.getOldValueForColumn(rowIndex: row, columnIdentifier: columnIdentifier, data: viewModel.filteredSiswaData)
            originalModel = DataAsli(ID: id, rowIndex: row, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue)
            if newValue != oldValue {
                viewModel.updateModelAndDatabase(id: id, columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue)
                // Daftarkan aksi undo ke NSUndoManager
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    targetSelf.viewModel.undoAction(originalModel: originalModel!)
                })
            }
        }
        
        // Bandingkan nilai baru dengan nilai lama
        if newValue != oldValue {
            deleteAllRedoArray(self)
        }
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        let identifier = tableView.tableColumns[column].identifier.rawValue
        if identifier == "Nama Siswa" || identifier == "Tahun Daftar" || identifier == "Tgl. Lulus" || identifier == "Status" {
            return false
        }
        return true
    }
}
