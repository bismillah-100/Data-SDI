//
//  InventoryView.swift
//  Dynamic Table
//
//  Created by Bismillah on 19/10/24.
//

import Cocoa
import Quartz

class InventoryView: NSViewController {
    /// Outlet ScrollView yang menampung ``tableView``
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet `NSTableView`.
    @IBOutlet weak var tableView: EditableTableView!

    /// Task `Swift Concurency`
    var searchTask: Task<Void, Never>? = nil

    /// Kamus array untuk [Nama Kolom: Tipe Data]
    var data: [[String: Any]] = []

    /// Lihat: ``DynamicTable/shared``
    let manager = DynamicTable.shared

    /// Oultet column default di XIB.
    ///
    /// Kolom ini ditimpa oleh kolom-kolom yang ada di database.
    @IBOutlet weak var defaultColumn: NSTableColumn!

    /// Menu untuk header kolom ``tableView``
    let headerMenu = NSMenu()

    /// Instans FileManager.default
    let defaults = UserDefaults.standard

    /// Properti `NSUndoManager` khusus ``DataSDI/InventoryView``
    var myUndoManager: UndoManager = .init()

    /// Properti untuk menyimpan referensi jika ``data`` telah diisi dengan data yang ada
    /// di database dan telah ditampilkan setiap barisnya di ``tableView``
    var isDataLoaded: Bool = false

    /// Instans untuk format tanggal. Lihat: ``DataSDI/SingletonData/dateFormatter``
    let dateFormatter = SingletonData.dateFormatter

    // MARK: - UNDOSTACK

    /// Properti yang menyimpan ID unik setiap data baru untuk keperluan undo/redo.
    var newData: Set<Int64> = []

    /// Properti ukuran foto di dalam baris kolom Nama Barang.
    var size = NSSize()

    /// Teks prediksi ketik untuk setiap kolom
    var databaseSuggestions = NSCache<NSString, NSArray>()

    /// Properti string pencarian d toolbar ``DataSDI/WindowController/search``.
    var stringPencarian: String = ""

    /// Menu untuk ``tableView``.
    var actionMenu = NSMenu()

    /// Menu untuk action toolbar ``DataSDI/WindowController/actionToolbar``.
    var toolbarMenu = NSMenu()

    /// Properti kumpulan ID unik dari setiap row yang dipilih.
    ///
    /// Digunakan untuk memilih baris  di ``tableView``yang berisi ID yang sesuai
    /// setelah mengurutkan data dan memuat ulang ``tableView``.
    var selectedIDs: Set<Int64> = []

    // MARK: - TAMPILAN

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.removeTableColumn(defaultColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tampilkanFoto(_:))
        setupTableDragAndDrop()
        setupTable()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // ini harus di viewdidappear karena menunggu window siap
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: isDataLoaded)
            loadSavedColumns()
            Task { [unowned self] in
                data = await manager.loadData()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setupDescriptor()
                    for tableColumn in self.tableView.tableColumns {
                        let columnIdentifier = tableColumn.identifier.rawValue
                        if let savedWidth = self.defaults.object(forKey: "Inventaris_tableColumnWidth_\(columnIdentifier)") as? CGFloat {
                            tableColumn.width = savedWidth
                        }

                        let customHeaderCell = MyHeaderCell()
                        customHeaderCell.title = tableColumn.title
                        tableColumn.headerCell = customHeaderCell
                    }
                    self.tableView(self.tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
                    isDataLoaded = true
                    if let window = self.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    self.tableView.defaultEditColumn = self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Nama Barang"))
                    self.refreshSuggestions()
                }
            }

            tableView.editAction = { row, column in
                // Anda bisa menambahkan logika tambahan di sini jika perlu sebelum memanggil startEditing
                AppDelegate.shared.editorManager.startEditing(row: row, column: column)
            }
        }

        actionMenu = buatMenuItem()
        toolbarMenu = buatMenuItem()
        actionMenu.delegate = self
        tableView.menu = actionMenu
        toolbarItem()
        // HeigtRowImage
        if tableView.rowHeight <= 18 { size = NSSize(width: 16, height: 16) } else if tableView.rowHeight >= 34 { size = NSSize(width: 36, height: 36) }
        updateMenuItem(self)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.updateUndoRedo()
//            if let window = self.view.window, let group = window.tabGroup {
//                DispatchQueue.main.async { [weak self] in
//                    guard let self = self else {return}
//                    if !group.isTabBarVisible {
//                        if self.scrollView.contentInsets.top != 38 {
//                            self.scrollView.contentInsets.top = 38
//                            self.scrollView.layoutSubtreeIfNeeded()
//                        }
//                    } else {
//                        if self.scrollView.contentInsets.top == 38 {
//                            self.scrollView.contentInsets.top = 63
//                            self.scrollView.layoutSubtreeIfNeeded()
//                        }
//                    }
//                }
//            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.tableView)
                self.setupColumnMenu()
                ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: self.stringPencarian)
            }
        }
    }

    /// Func untuk emuat ulang seluruh ``data`` dari table *main_table* di database
    /// dan memperbarui ``tableView`` dengan data terbaru.
    @objc func muatUlang(_ sender: Any) {
        Task { [weak self] in
            guard let self else { return }
            self.data = await self.manager.loadData()
            Task { [weak self] in
                guard let self else { return }
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
                self.updateUndoRedo()
            }
        }
    }

    /// Func untuk menyimpan semua informasi tabel. Urutan kolom, kolom yang disembunyikan, lebar kolom, urutan tabel sesuai kolom.
    func saveTableInfo() {
        // Simpan urutan kolom
        let columnOrder = tableView.tableColumns.map(\.identifier.rawValue)
        defaults.set(columnOrder, forKey: "ColumnOrder")

        // Simpan visibilitas kolom
        var hiddenColumns: [String] = []
        for column in tableView.tableColumns {
            if column.isHidden {
                hiddenColumns.append(column.identifier.rawValue)
            }
        }
        defaults.set(hiddenColumns, forKey: "HiddenColumns")

        // Simpan lebar kolom
        var columnWidths: [String: CGFloat] = [:]
        for column in tableView.tableColumns {
            columnWidths[column.identifier.rawValue] = column.width
        }
        defaults.set(columnWidths, forKey: "ColumnWidths")

        // Simpan sort descriptor saat ini
        if let sortDescriptor = tableView.sortDescriptors.first {
            let sortInfo: [String: Any] = [
                "key": sortDescriptor.key ?? "",
                "ascending": sortDescriptor.ascending,
            ]
            defaults.set(sortInfo, forKey: "SortInfo")
        }
    }

    /// Func untuk menyembunyikan/menampilkan kolom tertentu.
    /// - Parameter sender: Objek `NSMenuItem` dengan representedObject yang merupakan NSTableColumn.
    /// representedObject bisa diset saat menu item tersebut pertama kali dibuat.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        if column.identifier.rawValue == "Nama Barang" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
        saveTableInfo()
    }

    /// Bertanggung jawab untuk konfigurasi item-item menu
    /// kolom di ``tableView`` yang ditampilkan ketika diklik kanan.
    func setupColumnMenu() {
        DispatchQueue.main.async { [unowned self] in
            ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["Nama Barang"], target: self, selector: #selector(toggleColumnVisibility(_:)))
            tableView.headerView?.menu?.addItem(NSMenuItem.separator())
            // Menambahkan opsi untuk menghapus kolom
            for column in tableView.tableColumns {
                guard !headerMenu.items.contains(where: { $0.title == "Hapus \(column.title)" }) else { continue }
                // Gunakan && (dan) untuk memastikan kolom yang tidak boleh dihapus
                if column.identifier.rawValue != "id",
                   column.identifier.rawValue != "Nama Barang",
                   column.identifier.rawValue != "Kondisi",
                   column.identifier.rawValue != "Lokasi",
                   column.identifier.rawValue != "Tanggal Dibuat",
                   column.identifier.rawValue != "Foto"
                {
                    let menuItem = NSMenuItem(title: column.title, action: #selector(deleteColumnButtonClicked(_:)), keyEquivalent: "")
                    menuItem.representedObject = column.identifier
                    let smallFont = NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small))
                    menuItem.attributedTitle = NSAttributedString(string: "Hapus \(column.title)", attributes: [.font: smallFont])

                    let editMenuItem = NSMenuItem(title: column.title, action: #selector(editNamaKolom(_:)), keyEquivalent: "")
                    editMenuItem.representedObject = column.identifier
                    editMenuItem.attributedTitle = NSAttributedString(string: "Edit \(column.title)", attributes: [.font: smallFont])

                    tableView.headerView?.menu?.addItem(editMenuItem)
                    tableView.headerView?.menu?.addItem(menuItem)
                    tableView.headerView?.menu?.addItem(NSMenuItem.separator())
                }
            }
        }
    }

    /// Func untuk memuat konfigurasi kolom-kolom yang disimpan
    /// sebelumnya dari ``saveTableInfo()`` dan menambahkannya
    /// ke ``tableView``.
    func loadSavedColumns() {
        DispatchQueue.main.async { [unowned self] in
            // Muat urutan kolom yang tersimpan
            let savedColumnOrder = defaults.array(forKey: "ColumnOrder") as? [String] ?? []

            // Muat informasi kolom tersembunyi
            let hiddenColumns = defaults.array(forKey: "HiddenColumns") as? [String] ?? []

            // Hapus semua kolom yang ada
            for column in tableView.tableColumns {
                tableView.removeTableColumn(column)
            }

            // Fungsi helper untuk menambahkan kolom dengan urutan dan pengaturan yang benar
            func addColumnWithSavedSettings(name: String) {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
                column.title = name
                column.isHidden = hiddenColumns.contains(name)
                let widthKey = "Inventaris_tableColumnWidth_\(name)"
                if let savedWidth = defaults.object(forKey: widthKey) as? CGFloat {
                    column.width = savedWidth
                }
                tableView.addTableColumn(column)
            }

            // Tambahkan kolom sesuai urutan yang tersimpan
            for columnName in savedColumnOrder {
                if SingletonData.columns.contains(where: { $0.name == columnName }) {
                    addColumnWithSavedSettings(name: columnName)
                    #if DEBUG
                        print("columnName:", columnName)
                    #endif
                }
            }

            // Tambahkan kolom baru yang mungkin belum ada dalam urutan tersimpan
            for column in SingletonData.columns {
                if !savedColumnOrder.contains(column.name) {
                    addColumnWithSavedSettings(name: column.name)
                    #if DEBUG
                        print("savedColumnOrder columnName:", column.name)
                    #endif
                }
            }

            // Terapkan sort descriptor
            if let sortInfo = defaults.dictionary(forKey: "SortInfo"),
               let key = sortInfo["key"] as? String,
               let ascending = sortInfo["ascending"] as? Bool
            {
                let sortDescriptor = NSSortDescriptor(key: key, ascending: ascending)
                tableView.sortDescriptors = [sortDescriptor]
            } else {
                tableView.sortDescriptors = [NSSortDescriptor(key: "Nama Barang", ascending: true)]
            }
            self.tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
            self.tableView.sizeToFit()
            self.tableView.tile()
        }
    }

    /// Func untuk mengkonfigurasi `NSSortDescriptor` untuk setiap kolom ``tableView``.
    ///
    /// Key `NSSortDescriptor` diset sesuai nama kolom.
    func setupDescriptor() {
        for column in SingletonData.columns {
            let sortDescriptor = NSSortDescriptor(key: column.name, ascending: true, selector: #selector(ReusableFunc.compareValues(_:_:)))
            if let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column.name)) {
                tableColumn.sortDescriptorPrototype = sortDescriptor
            }
        }
    }

    /// Konfigurasi action dan target toolbar.
    func toolbarItem() {
        if let toolbar = view.window?.toolbar {
            // Search Field Toolbar Item
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                let searchField = searchFieldToolbarItem.searchField
                searchField.isEnabled = true
                searchField.target = self
                searchField.action = #selector(procSearchFieldInput(sender:))
                searchField.delegate = self
                if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
                    textFieldInsideSearchField.placeholderString = "Cari inventaris..."
                }
            }

            // Zoom Toolbar Item
            if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
               let zoom = zoomToolbarItem.view as? NSSegmentedControl
            {
                zoom.isEnabled = true
                zoom.target = self
                zoom.action = #selector(segmentedControlValueChanged(_:))
            }

            // Kalkulasi Toolbar Item
            if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
               let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
            {
                kalkulasiNilai.isEnabled = false
            }

            // Hapus Toolbar Item
            if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
               let hapus = hapusToolbarItem.view as? NSButton
            {
                hapus.isEnabled = tableView.selectedRow != -1
            }

            // Edit Toolbar Item
            if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
               let edit = editToolbarItem.view as? NSButton
            {
                edit.isEnabled = tableView.selectedRow != -1
            }

            // Tambah Toolbar Item
            if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
               let tambah = tambahToolbarItem.view as? NSButton
            {
                tambah.isEnabled = true
                let image = NSImage(named: "add-pos")
                image?.isTemplate = true
                tambahToolbarItem.image = image
                tambahToolbarItem.label = "Tambah Kolom"
                tambahToolbarItem.paletteLabel = "Tambahkan Kolom Baru"
                tambah.toolTip = "Tambahkan Kolom Baru ke dalam Tabel"
            }

            // Add Toolbar Item
            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
               let add = addToolbarItem.view as? NSButton
            {
                add.toolTip = "Catat Inventaris Baru"
                add.isEnabled = true
            }

            // PopUp Menu Toolbar Item
            if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
               let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
            {
                popUpButton.menu = toolbarMenu
                toolbarMenu.delegate = self
            }
        }
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/InventoryView``
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
           let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
           let fileMenu = mainMenu.item(withTitle: "File"),
           let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
           let fileMenuItem = fileMenu.submenu,
           let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" })
        {
            let isRowSelected = tableView.selectedRowIndexes.count > 0
            // Update item menu "Copy"
            copyMenuItem.isEnabled = isRowSelected
            copyMenuItem.target = self
            copyMenuItem.action = #selector(salinData(_:))
            pasteMenuItem.target = self
            pasteMenuItem.action = SingletonData.originalPasteAction
            // Update item menu "Delete"
            deleteMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(delete(_:))
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinData(_:))
            } else {
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
                copyMenuItem.target = SingletonData.originalCopyTarget
                copyMenuItem.action = SingletonData.originalCopyAction
                copyMenuItem.isEnabled = false
            }
            new.target = self
            new.action = #selector(addRowButtonClicked(_:))
        }
    }

    /// Action untuk toolbar ``DataSDI/WindowController/segmentedControl``
    /// - Parameter sender: Objek pemicu `NSSegmentedControl` dengan dua segmen.
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

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``
    @IBAction func increaseSize(_ sender: Any?) {
        ReusableFunc.increaseSize(tableView)
        saveRowHeight()
    }

    /// Lihat: ``DataSDI/ReusableFunc/decreaseSize(_:)``
    @IBAction func decreaseSize(_ sender: Any?) {
        ReusableFunc.decreaseSize(tableView)
        saveRowHeight()
    }

    /// Func untuk menyimpan konfigurasi tinggi baris ``tableView`` ke UserDefaults.
    func saveRowHeight() {
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "InventoryTableViewRowHeight")
    }

    /// func untuk menyiapkan konfigurasi awal ``tableView``.
    func setupTable() {
        if let savedRowHeight = UserDefaults.standard.value(forKey: "InventoryTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if SharedQuickLook.shared.isQuickLookVisible() {
            SharedQuickLook.shared.closeQuickLook()
        }
        saveTableInfo()
        ReusableFunc.resetMenuItems()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        searchTask?.cancel()
        searchTask = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension InventoryView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView.rowHeight <= 18 {
            size = NSSize(width: 16, height: 16)
        } else if tableView.rowHeight >= 34 {
            size = NSSize(width: 36, height: 36)
        }
        DispatchQueue.global(qos: .background).async { [unowned self] in
            if let imageData = data[row]["Foto"] as? Data, let image = NSImage(data: imageData) {
                let resizedImage = ReusableFunc.resizeImage(image: image, to: size)
                DispatchQueue.main.async {
                    let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                    if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                        cell.imageView?.image = resizedImage
                        //
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                    if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                        cell.imageView?.image = NSImage(named: "pensil")
                    }
                }
            }
        }
        return tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }

        let key = sortDescriptor.key ?? ""
        let ascending = sortDescriptor.ascending

        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            let sortedData = data.sorted { item1, item2 -> Bool in
                guard let column = SingletonData.columns.first(where: { $0.name == key }) else {
                    return false
                }

                let value1 = ["column": column, "value": item1[key], "item": item1]
                let value2 = ["column": column, "value": item2[key], "item": item2]

                let result = ReusableFunc.compareValues(value1 as [String: Any], value2 as [String: Any])
                if result != .orderedSame {
                    return ascending ? result == .orderedAscending : result == .orderedDescending
                }
                return false
            }

            // Set data ke hasil yang sudah diurutkan
            self.data = sortedData

            // Dapatkan indeks dari item yang dipilih
            var indexSet = IndexSet()
            for id in selectedIDs {
                if let index = data.firstIndex(where: { $0["id"] as? Int64 == id }) {
                    indexSet.insert(index)
                }
            }

            // Reload data di main thread
            DispatchQueue.main.async {
                tableView.reloadData()
                tableView.selectRowIndexes(indexSet, byExtendingSelection: false)

                if let maxIndex = indexSet.max() {
                    tableView.scrollRowToVisible(maxIndex)
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation drop: NSTableView.DropOperation) -> NSDragOperation {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return []
        }
        // Izinkan kedua jenis operasi: .above untuk insert dan .on untuk replace
        return .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return false
        }

        let pasteboard = info.draggingPasteboard
        tableView.deselectAll(self)

        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !fileURLs.isEmpty
        else {
            return false
        }

        if dragSourceIsFromOurTable(draggingInfo: info) {
            return false
        }

        // Jika drop .above
        if dropOperation == .above {
            var success = false
            Task { [weak self] in
                guard let self else { return }

                await MainActor.run {
                    self.myUndoManager.beginUndoGrouping()
                    tableView.beginUpdates()
                }

                success = await self.handleInsertNewRows(at: row, fileURLs: fileURLs, tableView: tableView)

                await MainActor.run {
                    tableView.endUpdates()
                    self.myUndoManager.endUndoGrouping()
                }
            }
            return success
        } else {
            // Drop bukan di .above → proses file pertama saja
            guard let imageURL = fileURLs.first,
                  let image = NSImage(contentsOf: imageURL),
                  let imageData = image.tiffRepresentation
            else {
                return false
            }
            return handleReplaceExistingRow(at: row, withImageData: imageData, tableView: tableView)
        }
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        // Simpan lebar kolom ke UserDefaults
        for column in tableView.tableColumns {
            let identifier = column.identifier.rawValue
            var width = column.width
            if width <= 5 {
                width += 10
            }
            defaults.set(width, forKey: "Inventaris_tableColumnWidth_\(identifier)")
        }

        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat")) != nil {
            let resizedColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
            // Pastikan jumlah baris dalam tableView sesuai dengan jumlah data di model
            let rowCount = tableView.numberOfRows
            let inventoryList = data

            guard inventoryList.count == rowCount else {
                return
            }
            for row in 0 ..< rowCount {
                let inventory = inventoryList[row]
                if let cellView = tableView.view(atColumn: resizedColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let tanggalString = inventory["Tanggal Dibuat"] as? String
                {
                    let textField = cellView.textField

                    guard !tanggalString.isEmpty else { continue }
                    let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
                    // Tentukan format tanggal berdasarkan lebar kolom
                    if let textWidth = textField?.cell?.cellSize(forBounds: textField!.bounds).width, textWidth < textField!.bounds.width {
                        let availableWidth = textField?.bounds.width
                        if availableWidth! <= 80 {
                            // Teks dipotong, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d/M/yy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else if availableWidth! <= 120 {
                            // Lebar tersedia kurang dari atau sama dengan 80, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d-MMM-yyyy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else {
                            // Teks tidak dipotong dan lebar tersedia lebih dari 80, gunakan format tanggal panjang
                            dateFormatter.dateFormat = "dd-MMMM-yyyy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        }
                    }
                    // Convert string date to Date object
                    if let date = dateFormatter.date(from: tanggalString) {
                        // Update text field dengan format tanggal yang baru
                        textField?.stringValue = dateFormatter.string(from: date)
                    } else {
                        print("error")
                    }
                }
            }
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.numberOfRows != 0 else { return }
        selectedIDs.removeAll()
        let selectedRow = tableView.selectedRow
        if let toolbar = view.window?.toolbar {
            // Aktifkan isEditable pada baris yang sedang dipilih
            if selectedRow != -1 {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton
                {
                    hapus.isEnabled = true
                    hapus.target = self
                    hapus.action = #selector(delete(_:))
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton
                {
                    edit.isEnabled = true
                }
                let idColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "id"))
                let foto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                let tanggalDibuat = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
                if let cell = tableView.view(atColumn: foto, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
                if let cell = tableView.view(atColumn: idColumn, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
                if let cell = tableView.view(atColumn: tanggalDibuat, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
            } else {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton
                {
                    hapus.isEnabled = false
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton
                {
                    edit.isEnabled = false
                }
            }
        }
        NSApp.sendAction(#selector(InventoryView.updateMenuItem(_:)), to: nil, from: self)
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                data[index]["id"] as? Int64
            })
        }
        if SharedQuickLook.shared.isQuickLookVisible() {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    func tableViewColumnDidMove(_ notification: Notification) {
        saveTableInfo()
        setupColumnMenu()
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let columnIdentifier = tableView.tableColumns[columnIndex].identifier.rawValue
        let columnIndexBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
        let columnIndexID = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "id"))
        if columnIdentifier == "Nama Barang" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if columnIdentifier == "id" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if newColumnIndex == columnIndexBarang || newColumnIndex == columnIndexID {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        return true
    }
}

extension InventoryView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        data.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = "DataCell"
        let imageCellIdentifier = "imageCell"

        guard let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView,
              let cellImage = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(imageCellIdentifier), owner: self) as? NSTableCellView
        else {
            return nil
        }

        let rowData = data[row]
        let columnName = tableColumn?.identifier.rawValue

        if let columnName {
            if columnName == "id" {
                configureIdCell(cellView: cellView, rowData: rowData, tableView: tableView)
            } else if columnName == "Foto" {
                configureFotoCell(cellView: cellView, rowData: rowData)
            } else if columnName == "Nama Barang" {
                return configureNamaBarangCell(cellImage: cellImage, rowData: rowData, row: row)
            } else if columnName == "Tanggal Dibuat" {
                cellView.textField?.alphaValue = 0.6
                if let tgl = rowData["Tanggal Dibuat"] as? String {
                    dateFormatter.dateFormat = "dd-MMMM-yyyy"
                    let availableWidth = tableColumn?.width ?? 0
                    if availableWidth <= 80 {
                        dateFormatter.dateFormat = "d/M/yy"
                    } else if availableWidth <= 120 {
                        dateFormatter.dateFormat = "d-MMM-yyyy"
                    } else {
                        dateFormatter.dateFormat = "dd-MMMM-yyyy"
                    }
                    // Ambil tanggal dari siswa menggunakan KeyPath
                    if let date = dateFormatter.date(from: tgl) {
                        cellView.textField?.stringValue = dateFormatter.string(from: date)
                    } else {
                        cellView.textField?.stringValue = tgl // fallback jika parsing gagal
                    }
                    tableColumn?.minWidth = 70
                    tableColumn?.maxWidth = 140
                } else {
                    cellView.textField?.stringValue = ""
                }
            } else {
                configureDefaultCell(cellView: cellView, columnName: columnName, rowData: rowData, tableView: tableView, row: row)
            }
        }

        return cellView
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan ID entitas.
    /// Fungsi ini mengatur properti tampilan sel seperti opasitas teks, lebar kolom,
    /// dan menampilkan nilai ID dari data baris yang diberikan.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi.
    ///   - rowData: Data `[String: Any]` untuk baris saat ini, diharapkan berisi kunci "id".
    ///   - tableView: `NSTableView` tempat sel ini berada.
    func configureIdCell(cellView: NSTableCellView, rowData: [String: Any], tableView: NSTableView) {
        cellView.textField?.alphaValue = 0.6
        if let idColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("id")) {
            idColumn.maxWidth = 40
        }
        cellView.textField?.isEditable = false
        if let idValue = rowData["id"] as? Int64 {
            cellView.textField?.stringValue = "\(idValue)"
        } else {
            cellView.textField?.stringValue = ""
        }
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan ukuran foto
    /// di database dalam format KB/MB.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi.
    ///   - rowData: Data `[String: Any]` untuk baris saat ini, diharapkan berisi kunci "Foto".
    ///   - tableView: `NSTableView` tempat sel ini berada.
    func configureFotoCell(cellView: NSTableCellView, rowData: [String: Any]) {
        cellView.textField?.isEditable = false
        cellView.textField?.alphaValue = 0.6

        if let imageData = rowData["Foto"] as? Data {
            let byteCount = imageData.count
            let sizeInMB = Double(byteCount) / (1024.0 * 1024.0)

            if sizeInMB < 1.0 {
                // Tampilkan dalam KB
                let sizeInKB = Double(byteCount) / 1024.0
                cellView.textField?.stringValue = String(format: "%.2f KB", sizeInKB)
            } else {
                // Tampilkan dalam MB
                cellView.textField?.stringValue = String(format: "%.2f MB", sizeInMB)
            }
        } else {
            cellView.textField?.stringValue = "-"
        }
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan nama barang beserta fotonya.
    /// Fungsi ini menangani pemuatan dan penyesuaian ukuran gambar secara asinkron
    /// untuk menjaga responsivitas UI, serta menampilkan nama barang.
    ///
    /// - Parameters:
    ///   - cellImage: `NSTableCellView` yang akan dikonfigurasi. Cell ini diharapkan memiliki `imageView` dan `textField`.
    ///   - rowData: `Dictionary` `[String: Any]` yang berisi data untuk baris saat ini.
    ///              Diharapkan memiliki kunci "Foto" (berisi `Data` gambar) dan "Nama Barang" (berisi `String`).
    ///   - row: Indeks baris saat ini dalam tabel. Parameter ini tidak digunakan secara langsung dalam implementasi ini,
    ///          tetapi umum disertakan dalam fungsi konfigurasi sel tabel.
    /// - Returns: `NSView` yang telah dikonfigurasi (dalam hal ini, `cellImage` itu sendiri).
    func configureNamaBarangCell(cellImage: NSTableCellView, rowData: [String: Any], row: Int) -> NSView {
        cellImage.imageView?.isEditable = false
        cellImage.imageView?.image = NSImage(named: "pensil") // Placeholder image saat gambar belum dimuat
        let rowHeight = tableView.rowHeight
        DispatchQueue.global(qos: .background).async {
            if let imageData = rowData["Foto"] as? Data, let image = NSImage(data: imageData) {
                let resizedImage = ReusableFunc.resizeImage(image: image, to: NSSize(width: rowHeight, height: rowHeight)) // Resize gambar di background
                DispatchQueue.main.async {
                    cellImage.imageView?.image = resizedImage // Update UI di main thread
                }
            } else {
                DispatchQueue.main.async {
                    cellImage.imageView?.image = NSImage(named: "pensil")
                }
            }
        }

        /// Mengkonfigurasi teks di baris ``tableView`` sesuai dengan teks yang ada di
        /// rowData["Nama Barang"].
        cellImage.textField?.stringValue = rowData["Nama Barang"] as? String ?? ""
        return cellImage
    }

    /// Mengkonfigurasi `NSTableCellView` umum untuk menampilkan data teks dari sebuah kolom tabel.
    /// Fungsi ini mengatur lebar minimum dan maksimum kolom yang terkait,
    /// serta menampilkan nilai string dari `rowData` ke dalam `textField` sel.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi. Cell ini diharapkan memiliki `textField`.
    ///   - columnName: `String` yang merupakan nama kolom (identifier) yang sedang dikonfigurasi.
    ///                 Ini juga digunakan sebagai kunci untuk mengambil data dari `rowData`.
    ///   - rowData: `Dictionary` `[String: Any]` yang berisi data untuk baris saat ini.
    ///              Diharapkan memiliki kunci yang sesuai dengan `columnName`.
    ///   - tableView: `NSTableView` tempat sel ini berada. Digunakan untuk mengakses dan mengatur properti kolom.
    ///   - row: Indeks baris saat ini dalam tabel. Parameter ini tidak digunakan secara langsung dalam implementasi ini,
    ///          tetapi umum disertakan dalam fungsi konfigurasi sel tabel.
    func configureDefaultCell(cellView: NSTableCellView, columnName: String, rowData: [String: Any], tableView: NSTableView, row: Int) {
        if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnName)) {
            // Mengatur lebar maksimum kolom menjadi 400 poin.
            column.maxWidth = 400
            // Mengatur lebar minimum kolom menjadi 80 poin.
            column.minWidth = 80
        }
        cellView.textField?.stringValue = rowData[columnName] as? String ?? ""
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let columnIdentifier = tableColumn?.identifier.rawValue,
              let newValue = object,
              let _ = data[row]["id"] as? Int64 else { return }

        _ = data[row][columnIdentifier]

        // Perbarui data
        data[row][columnIdentifier] = newValue
    }
}

// MARK: - Handle drop row table

extension InventoryView {
    /// Menangani penyisipan beberapa baris baru ke dalam tabel berdasarkan daftar URL file gambar yang diberikan. Fungsi ini akan memproses setiap URL, mengubah gambar menjadi data, dan kemudian memanggil handleInsertNewRow untuk menyisipkan setiap baris secara individual. Ini dirancang sebagai operasi asinkron untuk menghindari pemblokiran UI saat memproses beberapa file.
    ///
    /// - Parameters:
    ///    - startRow: Int yang menunjukkan indeks baris awal di mana penyisipan akan dimulai di NSTableView.
    ///    - fileURLs: Array URL yang berisi lokasi file gambar yang akan disisipkan sebagai baris baru.
    ///    - tableView: NSTableView tempat baris-baris baru akan disisipkan.
    /// - Returns: Bool true jika setidaknya satu baris berhasil disisipkan, false jika tidak ada baris yang berhasil disisipkan.
    func handleInsertNewRows(at startRow: Int, fileURLs: [URL], tableView: NSTableView) async -> Bool {
        var currentRow = startRow // Menginisialisasi indeks baris saat ini untuk penyisipan.
        var success = false // Menandai apakah ada setidaknya satu penyisipan yang berhasil.
        var ids: [Int64] = [] // Menyimpan ID dari data yang berhasil disisipkan untuk operasi undo.

        // Loop melalui setiap URL file yang diberikan.
        for fileURL in fileURLs {
            // Guard statement untuk memastikan URL menunjuk ke gambar yang valid dan dapat diubah menjadi Data.
            guard let image = NSImage(contentsOf: fileURL), // Coba muat gambar dari URL.
                  let imageData = image.tiffRepresentation
            else { // Dapatkan representasi TIFF dari gambar.
                // Jika gagal memuat gambar atau mendapatkan data gambar, lewati ke URL berikutnya.
                continue
            }

            // Dapatkan nama file (tanpa ekstensi) dari URL, yang akan digunakan sebagai nama barang.
            let fileName = fileURL.deletingPathExtension().lastPathComponent

            // Memanggil `handleInsertNewRow` secara asinkron untuk menyisipkan satu baris baru.
            // `handleInsertNewRow` diasumsikan melakukan penyisipan data ke model dan memperbarui tabel.
            let (inserted, id) = await handleInsertNewRow(at: currentRow, withImageData: imageData, tableView: tableView, fileName: fileName)

            // Periksa apakah penyisipan berhasil dan ID data tersedia.
            if inserted, let dataID = id {
                currentRow += 1 // Tingkatkan indeks baris untuk penyisipan berikutnya.
                ids.append(dataID) // Tambahkan ID ke daftar untuk operasi undo.
                success = true // Setel `success` menjadi true karena setidaknya satu baris berhasil disisipkan.
            }
        }

        // Daftarkan operasi undo untuk semua ID yang baru saja disisipkan.
        // Ini memungkinkan pengguna untuk membatalkan penyisipan baris-baris ini.
        registerUndoForInsert(ids)

        // Kembalikan status keberhasilan keseluruhan operasi.
        return success
    }

    /// Menangani penyisipan satu baris data baru ke dalam tabel dan Core Data secara asinkron.
    /// Fungsi ini menginisialisasi data untuk baris baru berdasarkan skema kolom yang ditentukan
    /// di `SingletonData.columns`, menetapkan gambar, dan kemudian menyisipkan data tersebut
    /// ke dalam model data aplikasi dan Core Data. Setelah penyisipan berhasil, ia memperbarui
    /// tampilan tabel dan menyimpan gambar ke database.
    ///
    /// - Parameters:
    ///   - row: `Int` yang menunjukkan indeks baris di mana data baru akan disisipkan dalam tabel.
    ///   - withImageData: `Data` dari gambar yang akan dikaitkan dengan baris baru ini.
    ///   - tableView: `NSTableView` tempat baris baru akan disisipkan.
    ///   - fileName: `String` yang akan digunakan sebagai nilai awal untuk kolom "Nama Barang".
    ///
    /// - Returns: Tuple `(Bool, Int64?)`
    ///   - `Bool`: `true` jika penyisipan dan penyimpanan ke Core Data berhasil, `false` jika gagal.
    ///   - `Int64?`: ID unik dari data yang baru disisipkan, atau `nil` jika penyisipan gagal.
    func handleInsertNewRow(at row: Int, withImageData imageData: Data, tableView: NSTableView, fileName: String) async -> (Bool, Int64?) {
        var newData: [String: Any] = [:] // Inisialisasi dictionary untuk menyimpan data baris baru.
        dateFormatter.dateFormat = "dd-MMMM-yyyy" // Mengatur format tanggal.
        let currentDate = dateFormatter.string(from: Date()) // Mendapatkan tanggal saat ini dalam format string.

        // Mengisi `newData` berdasarkan definisi kolom di `SingletonData.columns`.
        for column in SingletonData.columns {
            if column.type == String.self {
                // Jika tipe kolom adalah String.
                if column.name == "Tanggal Dibuat" {
                    newData[column.name] = currentDate // Set nilai "Tanggal Dibuat" dengan tanggal saat ini.
                } else if column.name == "Nama Barang" {
                    newData[column.name] = fileName // Set nilai "Nama Barang" dengan `fileName` yang diberikan.
                } else {
                    newData[column.name] = "" // Untuk kolom String lainnya, set nilai default string kosong.
                }
            } else if column.type == Int64.self {
                // Jika tipe kolom adalah Int64, set nilai default 0.
                newData[column.name] = 0
            }
        }

        // Memproses data gambar yang diberikan.
        if let image = NSImage(data: imageData) {
            // Mengubah ukuran gambar ke dimensi yang telah ditentukan (`size`).
            let resizedImage = ReusableFunc.resizeImage(image: image, to: size)
            newData["Foto"] = resizedImage // Menyimpan gambar yang telah diubah ukurannya ke `newData`.
        }

        // Memperbarui model data utama (`self.data`) di MainActor karena ini adalah perubahan UI-related.
        await MainActor.run {
            self.data.insert(newData, at: row) // Sisipkan baris baru ke dalam array data.
        }

        // Menyimpan data baru ke Core Data menggunakan `manager.insertData`.
        // `guard let` digunakan untuk memastikan operasi penyimpanan berhasil dan mengembalikan ID.
        guard let newId = await manager.insertData(newData) else {
            // Jika penyimpanan gagal, kembalikan `false` dan `nil` ID.
            return (false, nil)
        }

        // Setelah berhasil menyimpan ke Core Data, perbarui `newData` di model dengan ID yang dihasilkan.
        data[row]["id"] = newId
        // Memastikan "Tanggal Dibuat" di data model juga sudah sesuai dengan yang ditetapkan.
        data[row]["Tanggal Dibuat"] = currentDate
        // Menambahkan ID baru ke set `newData` (mungkin untuk pelacakan perubahan atau undo).
        self.newData.insert(newId)

        // Melakukan pembaruan UI di MainActor.
        await MainActor.run {
            // Memberi tahu `tableView` untuk menyisipkan baris baru dengan animasi.
            tableView.insertRows(at: IndexSet([row]), withAnimation: .effectGap)
            // Menyimpan gambar ke database (kemungkinan ke lokasi spesifik setelah ID diketahui).
            saveImageToDatabase(atRow: row, imageData: imageData)
            // Memfokuskan pada kolom "Nama Barang" dari baris yang baru disisipkan.
            focusOnNamaBarang(row: row)
        }

        // Kembalikan `true` untuk menandakan keberhasilan dan ID dari data yang baru disisipkan.
        return (true, newId)
    }

    /// Menggantikan data gambar pada baris yang sudah ada di tabel dan database.
    /// Fungsi ini dirancang untuk memperbarui hanya kolom "Foto" dari sebuah entitas
    /// yang sudah ada tanpa mengubah data lainnya. Ia juga mendukung fungsionalitas undo
    /// dengan menyimpan data gambar lama sebelum penggantian.
    ///
    /// - Parameters:
    ///   - row: `Int` yang menunjukkan indeks baris di `NSTableView` yang akan diperbarui.
    ///   - withImageData: `Data` dari gambar baru yang akan digunakan untuk menggantikan gambar lama.
    ///   - tableView: `NSTableView` tempat operasi penggantian baris dilakukan.
    ///
    /// - Returns: `Bool` yang selalu `true` setelah operasi dimulai.
    ///   Perhatikan bahwa operasi asinkron di dalam `Task` tidak memengaruhi nilai kembalian ini secara langsung,
    ///   dan keberhasilan pembaruan database ditangani di dalam `Task` itu sendiri.
    func handleReplaceExistingRow(at row: Int, withImageData imageData: Data, tableView: NSTableView) -> Bool {
        guard row < data.count else { return false }
        Task {
            // Simpan data lama untuk undo
            let oldData = data[row]
            let oldImageData = await self.manager.getImage(oldData["id"] as! Int64)

            // Update hanya field Foto
            data[row]["Foto"] = imageData

            // Update di database
            guard let id = data[row]["id"] as? Int64 else { return false }
            tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            saveImageToDatabase(atRow: row, imageData: imageData)
            // Register undo untuk replace
            registerUndoForReplace(id: id, oldImageData: oldImageData)
            return true
        }
        return true
    }

    /// Seleksi baris yang baru saja diupdate melalui drop foto.
    func focusOnNamaBarang(row: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        }
    }

    /// Pendaftaran ke ``myUndoManager`` untuk keperluan undo
    /// setelah baru menambahkan data melalui drop foto ke ``tableView``.
    func registerUndoForInsert(_ newId: [Int64]) {
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.undoAddRows(newId)
        })
        updateUndoRedo()
    }

    /// Pendaftaran ke ``myUndoManager`` untuk keperluan undo
    /// setelah memperbarui foto di suat baris melalui drop foto
    /// ke baris yang sudah ada di ``tableView``.
    func registerUndoForReplace(id: Int64, oldImageData: Data?) {
        // Simpan data lama untuk undo
        let oldImage = oldImageData ?? Data() // Jika oldImageData nil, gunakan Data kosong
        if let bitmapImage = NSBitmapImageRep(data: oldImage),
           let imageData = bitmapImage.representation(using: .png, properties: [:])
        {
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                self?.undoReplaceImage(id, imageData: imageData) // Menggunakan imageData yang sudah dikonversi
            })
            updateUndoRedo()
        }
    }

    /// Berguna untuk mencari row di ``data``
    /// yang sesuai dengan `id` yang diterima.
    /// baris ini juga sama urutannya dengan yang ada di ``tableView``.
    /// - Parameter id: `id` pada baris yang akan dicari.
    /// - Returns: Properti baris yang ditemukan.
    /// Properti ini akan`nil` jika `id` tidak ditemukan.
    func findRowIndex(forId id: Int64) -> Int? {
        data.firstIndex { ($0["id"] as? Int64) == id }
    }
}

// MARK: - Cache untuk prediksi ketik

extension InventoryView {
    /// Mendapatkan daftar saran (suggestions) untuk kolom tertentu.
    /// Fungsi ini pertama-tama mencoba mengambil saran dari cache memori (`databaseSuggestions`).
    /// Jika saran tidak ditemukan di cache, ia akan memuatnya secara asinkron dari database
    /// di antrean latar belakang untuk menghindari pemblokiran UI.
    ///
    /// Setelah saran dimuat dari database, mereka akan disimpan ke dalam cache untuk penggunaan di masa mendatang.
    ///
    /// - Parameter column: Objek `Column` yang mewakili kolom yang ingin Anda dapatkan sarannya.
    ///                     `column.name` digunakan sebagai kunci untuk cache dan pengambilan database.
    ///
    /// - Returns: Sebuah array `[String]` yang berisi saran yang ditemukan di cache.
    ///            Jika saran tidak ada di cache, array kosong (`[]`) akan dikembalikan segera,
    ///            sementara pemuatan dari database dilakukan di latar belakang.
    func getSuggestions(for column: Column) -> [String] {
        if let cachedSuggestions = databaseSuggestions.object(forKey: column.name as NSString) as? [String] {
            return cachedSuggestions
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            self.loadSuggestionsFromDatabase(for: column) { suggestions in
                self.databaseSuggestions.setObject(suggestions as NSArray, forKey: column.name as NSString)
            }
        }

        return []
    }

    /// Mengambil saran unik dari basis data untuk kolom tertentu dengan keanggunan.
    /// Fungsi ini dirancang untuk secara asinkron memuat dan menyaring nilai-nilai yang berbeda
    /// dari kolom yang ditunjuk dalam 'main_table', kemudian menyajikannya sebagai
    /// daftar saran yang terurut secara alfabetis. Ini termasuk ekstraksi kata-kata
    /// individual untuk memberikan spektrum saran yang lebih luas.
    ///
    /// - Parameters:
    ///   - column: Objek `Column` yang menjadi fokus pencarian saran.
    ///             Nama kolomnya (`column.name`) adalah kunci penentu dalam eksekusi kueri.
    ///   - completion: Sebuah closure escapable yang akan dieksekusi setelah proses pengambilan data
    ///                 selesai. Closure ini menerima sebuah array `[String]` yang berisi
    ///                 saran-saran yang telah dikurasi dan diurutkan. Jika terjadi kesalahan
    ///                 atau data tidak ditemukan, array kosong akan disajikan.
    func loadSuggestionsFromDatabase(for column: Column, completion: @escaping ([String]) -> Void) {
        // Memastikan koneksi ke basis data tersedia. Tanpa itu, tidak ada saran yang dapat diambil.
        guard let db = DynamicTable.shared.db else {
            completion([]) // Segera selesaikan dengan daftar kosong jika basis data tidak terhubung.
            return
        }

        // Sebuah set digunakan untuk mengumpulkan saran-saran unik, menghindari duplikasi.
        var suggestionsSet: Set<String> = []

        do {
            // Merangkai kueri SQL untuk mengambil nilai-nilai unik dan non-kosong dari kolom yang ditentukan.
            // Kueri ini memastikan hanya nilai yang relevan yang dipertimbangkan sebagai saran.
            let query = """
                SELECT DISTINCT "\(column.name)"
                FROM "main_table"
                WHERE "\(column.name)" IS NOT NULL
                AND "\(column.name)" != ''
            """
            // Menyiapkan pernyataan SQL untuk eksekusi yang aman.
            let statement = try db.prepare(query)

            // Mengiterasi setiap baris hasil kueri.
            for row in statement {
                if let value = row[0] as? String, !value.isEmpty {
                    suggestionsSet.insert(value)
                    // Pisahkan nilai menjadi kata-kata individual untuk memperkaya daftar saran.
                    // Filter kata-kata yang terlalu pendek atau hanya spasi.
                    let words = value.components(separatedBy: .whitespacesAndNewlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first?.isLetter == true)) }
                    suggestionsSet.formUnion(words)
                }
            }

            // Setelah semua saran terkumpul, ubah set menjadi array, urutkan secara alfabetis,
            // dan sajikan melalui completion handler.
            completion(Array(suggestionsSet).sorted())
        } catch {
            print(error.localizedDescription)
            completion([])
        }
    }

    /// Fungsi untuk memperbarui cache suggestions
    func updateSuggestionsCache() {
        databaseSuggestions.removeAllObjects()
        for column in SingletonData.columns {
            loadSuggestionsFromDatabase(for: column, completion: { [weak self] suggestions in
                self?.databaseSuggestions.setObject(suggestions as NSArray, forKey: column.name as NSString)
            })
        }
    }

    /// Panggil ini ketika data berubah untuk memperbarui cache prediksi.
    func refreshSuggestions() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.updateSuggestionsCache()
        }
    }

    /// Fungsi untuk menyimpan kolom baru ke UserDefaults
    func saveColumnToDefaults(name: String, type: Any.Type) {
        var savedColumns = defaults.array(forKey: "savedColumns") as? [[String: String]] ?? []
        let typeString = (type == String.self) ? "String" : "Int64"
        savedColumns.append(["name": name, "type": typeString])
        defaults.set(savedColumns, forKey: "savedColumns")
    }
}

// MARK: - CRUD

extension InventoryView {
    /// Fungsi untuk menambah kolom baru
    /// - Parameters:
    ///   - name: Nama kolom yang akan ditambahkan.
    ///   - type: Tipe kolom di database. Untuk saat ini hanya mendukung tipe string saja.
    func addColumn(name: String, type: Any.Type) async {
        // Menambah kolom baru ke database
        await manager.addColumn(name: name, type: String.self)
        addTableColumn(name: name) // Menambah kolom baru ke NSTableView
        data = await manager.loadData() // Mendapatkan data yang baru di database
        await MainActor.run {
            tableView(self.tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
            // muat ulang seluruh baris di tableView
        }
    }

    /// Fungsi untuk menambah kolom ke NSTableView
    /// - Parameter name: Nama kolom yang akan ditambahkan
    func addTableColumn(name: String) {
        /// Membuat instans `NSTableColumn` dengan identifier yang sesuai nama.
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
        tableColumn.title = name
        tableView.addTableColumn(tableColumn)
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.undoAddColumn(name)
        })
        setupDescriptor()
        updateUndoRedo()
    }

    /// Fungsi untuk membatalkan penambahan kolom yang dicatat di ``myUndoManager``
    ///
    /// Kolom tidak langsung dihapus di database. Akan tetapi disimpan
    /// di dalam Array ``DataSDI/SingletonData/undoAddColumns``
    /// semua kolom yang ada di array ini akan dihapus ketika:
    /// - Aplikasi akan ditutup.
    /// - Pengguna mengklik toolbar item ``DataSDI/WindowController/simpanToolbar``
    /// - Pengguna menyimpan melalui ⌘S.
    /// - Parameter name: Nama kolom yang akan dicari.
    func undoAddColumn(_ name: String) {
        guard let index = SingletonData.columns.firstIndex(where: { $0.name == name }) else { return }

        // Pastikan index valid
        guard index < SingletonData.columns.count else { return }

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[name] ?? "")) // Simpan ID dan nilai kolom
            }
        }
        SingletonData.undoAddColumns.append((columnName: name, columnData: columnData))

        guard let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == name }) else { return }
        tableView.removeTableColumn(column)

        // Reload data pada table view
        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
                self.removeMenuItem(for: name)
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.redoAddColumn(columnName: name)
        })
        updateUndoRedo()
        setupDescriptor()
    }

    /// Fungsi untuk mengulangi penambahan kolom yang dicatat di ``myUndoManager``
    /// - Parameter columnName: Nama kolom yang akan dicari.
    func redoAddColumn(columnName: String) {
        guard !SingletonData.undoAddColumns.isEmpty else { return }
        let lastDeleted = SingletonData.undoAddColumns.removeLast()
        let columnName = lastDeleted.columnName
        let columnData = lastDeleted.columnData

        // Tambahkan kolom kembali ke database dan table view

        let newColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
        newColumn.title = columnName
        tableView.addTableColumn(newColumn)

        // Kembalikan data kolom ke baris dengan ID yang sesuai
        for (index, row) in data.enumerated() {
            if let id = row["id"] as? Int64 {
                // Cari nilai yang sesuai dengan ID
                if let matchedData = columnData.first(where: { $0.id == id }) {
                    data[index][columnName] = matchedData.value // Mengembalikan data berdasarkan ID yang cocok
                }
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.undoAddColumn(columnName)
        })
        // Reload table view dengan data yang diperbarui
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu()
        updateUndoRedo()
        setupDescriptor()
    }

    /// Fungsi untuk menghapus kolom dari database dan NSTableView
    /// - Parameter name: Nama kolom yang akan dihapus.
    func deleteColumn(at name: String) {
        guard let index = SingletonData.columns.firstIndex(where: { $0.name == name }) else { return }

        // Pastikan index valid
        guard index < SingletonData.columns.count else { return }

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[name] ?? "")) // Simpan ID dan nilai kolom
            }
        }
        SingletonData.deletedColumns.append((columnName: name, columnData: columnData))

        // Hapus kolom dari database dan tabel
        // manager.deleteColumn(table: "main_table", nama: columnToDelete)

        guard let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == name }) else { return }
        tableView.removeTableColumn(column)

        // Reload data pada table view
        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)

                self.removeMenuItem(for: name)
                self.myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                    self?.undoDeleteColumn()
                })
                self.updateUndoRedo()
                self.setupDescriptor()
            }
        }
    }

    /// Fungsi untuk untuk menghapus menu item di header menu ``tableView``
    /// yang berkaitan dengan nama kolom yang diberikan.
    ///
    /// Dijalankan ketika menghapus kolom dari ``tableView``.
    /// - Parameter columnName: Nama menu item yang akan dihapus.
    func removeMenuItem(for columnName: String) {
        if let headerMenu = tableView.headerView?.menu {
            // Mencari item menu yang ingin dihapus
            if let itemToRemove = headerMenu.item(withTitle: "Hapus \(columnName)") {
                headerMenu.removeItem(itemToRemove)
            }
            if let hideToRemove = headerMenu.item(withTitle: "\(columnName)") {
                headerMenu.removeItem(hideToRemove)
            }
            if let editToRemove = headerMenu.item(withTitle: "Edit \(columnName)") {
                headerMenu.removeItem(editToRemove)
            }
        }
    }

    /// Fungsi untuk menangani tombol tambah kolom.
    ///
    /// Memeriksa beberapa kondisi sebelum menambahkan kolom baru:
    /// 1. Nama kolom tidak kosong.
    /// 2. Kolom tidak sama dengan nama kolom yang sudah ada (case-insensitive dan setelah normalisasi).
    ///    Normalisasi meliputi:
    ///    - Mengganti `;` dengan `:` (ini mungkin digunakan untuk membersihkan input).
    ///    - Mengubah ke huruf kecil untuk perbandingan yang tidak peka huruf besar/kecil.
    ///    - Menghapus spasi dan baris baru di awal/akhir string.
    @IBAction func addColumnButtonClicked(_ sender: Any) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "add-pos")
        alert.messageText = "Tambah Kolom Baru"
        alert.informativeText = "Masukkan nama kolom baru:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 285, height: 24))
        inputTextField.placeholderString = "Nama kolom baru"
        inputTextField.bezelStyle = .roundedBezel
        alert.accessoryView = inputTextField

        alert.window.initialFirstResponder = inputTextField
        alert.beginSheetModal(for: view.window!) { [self] response in
            if response == .alertFirstButtonReturn {
                // Mendapatkan nilai nama kolom dari input pengguna.
                let columnName = inputTextField.stringValue

                if !columnName.isEmpty, !SingletonData.columns.contains(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == columnName.replacingOccurrences(of: ";", with: ":").lowercased() }) {
                    // Jika semua kondisi terpenuhi, inisiasi Task asinkron.
                    // Task ini akan memanggil fungsi `addColumn` untuk menambahkan kolom baru.
                    // Nama kolom akan dinormalisasi (mengganti `;` dengan `:`, kapitalisasi, dan trim spasi)
                    // dan tipenya akan diatur sebagai `String.self`.
                    Task {
                        await addColumn(name: columnName.replacingOccurrences(of: ";", with: ":").capitalizedAndTrimmed(), type: String.self)
                    }
                } else {
                    let aler = NSAlert()
                    aler.messageText = "Format Kolom Tidak Didukung"
                    aler.informativeText = "Nama kolom tidak boleh sama dan tidak boleh kosong."
                    aler.runModal()
                }
            }
        }
    }

    /// Fungsi untuk menangani tombol edit kolom.
    @IBAction func editNamaKolom(_ sender: NSMenuItem) {
        guard let columnIdentifier = sender.representedObject as? NSUserInterfaceItemIdentifier else { return }
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.messageText = "Edit Nama Kolom"
        alert.informativeText = "Masukkan nama kolom baru:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 285, height: 24))
        inputTextField.placeholderString = "Nama kolom baru"
        inputTextField.bezelStyle = .roundedBezel
        alert.accessoryView = inputTextField

        alert.window.initialFirstResponder = inputTextField

        alert.beginSheetModal(for: view.window!) { [self] response in
            if response == .alertFirstButtonReturn {
                editNamaKolom(columnIdentifier.rawValue, kolomBaru: inputTextField.stringValue)
            }
        }
    }

    /// Mengubah nama sebuah kolom yang ada, baik pada struktur database maupun pada tampilan UI tabel.
    /// Fungsi ini dirancang untuk beroperasi secara asinkron untuk menjaga responsivitas aplikasi.
    /// Ia juga secara cerdas mencatat perubahan ini untuk memungkinkan fungsionalitas undo/redo.
    ///
    /// - Parameters:
    ///   - kolomLama: `String` yang menunjukkan nama kolom saat ini yang akan diubah.
    ///   - kolomBaru: `String` yang menunjukkan nama baru yang diinginkan untuk kolom tersebut.
    func editNamaKolom(_ kolomLama: String, kolomBaru: String) {
        // Sebuah dictionary untuk menyimpan nilai-nilai lama dari kolom yang diubah,
        // diindeks berdasarkan ID (Int64) dari setiap entitas. Ini penting untuk operasi undo.
        var previousValues: [Int64: Any] = [:]

        // Memulai tugas asinkron dengan prioritas latar belakang (`.background`).
        // Ini memastikan bahwa operasi yang memakan waktu (seperti interaksi database)
        // tidak memblokir antrean utama (UI) aplikasi.
        Task(priority: .background) { [weak self] in
            // Verifikasi dua hal penting:
            // 1. Pastikan operasi penggantian nama kolom di database berhasil.
            //    `DynamicTable.shared.renameColumn` sebagai fungsi yang menangani hal ini.
            // 2. Pastikan `self` (instans kelas saat ini) masih ada dan belum dilepaskan dari memori.
            guard await ((try? DynamicTable.shared.renameColumn("main_table", kolomLama: kolomLama, kolomBaru: kolomBaru)) != nil),
                  let self
            else {
                // Jika salah satu kondisi gagal, hentikan eksekusi Task ini.
                return
            }

            // Iterasi melalui setiap baris data dalam model lokal (`self.data`).
            for i in 0 ..< self.data.count {
                // Dapatkan ID dari baris saat ini. Jika tidak ada ID, lewati baris ini.
                guard let id = self.data[i]["id"] as? Int64 else { continue }
                // Coba hapus nilai lama dari kolom `kolomLama` dan simpan nilai tersebut.
                if let oldValue = self.data[i].removeValue(forKey: kolomLama) {
                    // Simpan nilai lama ke dalam `previousValues` menggunakan ID sebagai kunci.
                    previousValues[id] = oldValue
                    // Tetapkan nilai lama tersebut ke kolom dengan nama `kolomBaru` di model data.
                    self.data[i][kolomBaru] = oldValue
                }
            }

            // Kembali ke antrean utama (`MainActor`) untuk melakukan pembaruan UI.
            // Semua manipulasi UI harus dilakukan di sini untuk memastikan thread-safety.
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Perbarui objek `NSTableColumn` yang sesuai di `tableView`.
                if let column = self.tableView.tableColumn(withIdentifier: .init(kolomLama)) {
                    column.title = kolomBaru // Ganti judul kolom di UI.
                    column.identifier = .init(kolomBaru) // Ganti identifier kolom.
                    // Perbarui prototipe sort descriptor untuk kolom, agar pengurutan tetap berfungsi.
                    column.sortDescriptorPrototype = NSSortDescriptor(key: kolomBaru, ascending: true)
                }

                // Perbarui deskriptor pengurutan yang aktif di tabel.
                // Jika ada sort descriptor yang menggunakan `kolomLama` sebagai kunci,
                // ubah kuncinya menjadi `kolomBaru` sambil mempertahankan arah pengurutan.
                self.tableView.sortDescriptors = self.tableView.sortDescriptors.map {
                    $0.key == kolomLama ? NSSortDescriptor(key: kolomBaru, ascending: $0.ascending) : $0
                }

                // Memanggil `setupColumnMenu` untuk meregenerasi menu kolom,
                // memastikan nama kolom yang baru ditampilkan dengan benar.
                self.setupColumnMenu()
                // Muat ulang data tabel untuk merefleksikan perubahan nama kolom di sel-selnya.
                self.tableView.reloadData()
            }
        }
        myUndoManager.registerUndo(withTarget: self) { [weak self] handler in
            self?.undoEditNamaKolom(kolomLama: kolomLama, kolomBaru: kolomBaru, previousValues: previousValues)
        }

        updateUndoRedo()
    }

    /// Membatalkan perubahan nama kolom yang sebelumnya telah dilakukan.
    /// Fungsi ini mengembalikan nama kolom baik di database maupun di UI tabel
    /// ke kondisi semula, dan mengembalikan nilai-nilai data ke kolom yang benar.
    /// Ini adalah bagian penting dari fungsionalitas undo, yang juga menyiapkan operasi redo.
    ///
    /// - Parameters:
    ///   - kolomLama: `String` yang merupakan nama kolom asli (sebelum diubah).
    ///   - kolomBaru: `String` yang merupakan nama kolom setelah diubah (saat ini).
    ///   - previousValues: `[Int64: Any]` sebuah dictionary yang berisi nilai-nilai data lama,
    ///                     diindeks berdasarkan ID entitas, yang disimpan saat operasi `editNamaKolom` terjadi.
    func undoEditNamaKolom(kolomLama: String, kolomBaru: String, previousValues: [Int64: Any]) {
        Task(priority: .background) { [weak self] in
            guard await ((try? DynamicTable.shared.renameColumn("main_table", kolomLama: kolomBaru, kolomBaru: kolomLama)) != nil), let self else { return }
            for i in 0 ..< data.count {
                guard let id = data[i]["id"] as? Int64 else { continue }
                // Periksa apakah ada nilai lama yang disimpan untuk ID ini.
                if let oldValue = previousValues[id] {
                    // Hapus nilai dari kolom dengan `kolomBaru` (nama saat ini).
                    self.data[i].removeValue(forKey: kolomBaru)
                    // Tetapkan `oldValue` (nilai asli) ke kolom dengan `kolomLama` (nama asli).
                    self.data[i][kolomLama] = oldValue
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                // Perbarui objek `NSTableColumn` yang sesuai di `tableView`.
                // Kita mencari kolom dengan `identifier` `kolomBaru` (nama yang diubah).
                if let column = self.tableView.tableColumn(withIdentifier: .init(kolomBaru)) {
                    column.title = kolomLama
                    column.identifier = .init(kolomLama)
                    // Perbarui prototipe sort descriptor untuk kolom, agar pengurutan tetap berfungsi.
                    column.sortDescriptorPrototype = NSSortDescriptor(key: kolomLama, ascending: true)
                }

                // Perbarui deskriptor pengurutan yang aktif di tabel.
                // Jika ada sort descriptor yang menggunakan `kolomBaru` sebagai kunci,
                // ubah kuncinya kembali menjadi `kolomLama` sambil mempertahankan arah pengurutan.
                self.tableView.sortDescriptors = self.tableView.sortDescriptors.map {
                    $0.key == kolomBaru ? NSSortDescriptor(key: kolomLama, ascending: $0.ascending) : $0
                }
                self.setupColumnMenu()
                self.tableView.reloadData()
            }
        }
        // Redo
        myUndoManager.registerUndo(withTarget: self) { [weak self] handler in
            self?.editNamaKolom(kolomLama, kolomBaru: kolomBaru)
        }
        updateUndoRedo()
    }

    /// Fungsi yang menangani tombol hapus.
    ///
    /// Bisa juga melalui Menu Bar atau pintasan ⌘⌫.
    /// - Catatan:
    ///     - Data tidak langsung dihapus dari database
    /// melainkan disimpan di ``DataSDI/SingletonData/deletedInvID``
    /// dan dihapus ketika pengguna menyiimpan perubahan
    /// atau ketika pengguna mengkonfirmasi alert ketika aplikasi akan ditutup.
    @IBAction func delete(_ sender: Any) {
        let rows = tableView.selectedRowIndexes

        // Dapatkan ID untuk setiap baris yang dipilih
        for row in rows {
            if let idValue = data[row]["id"] as? Int64 {
                SingletonData.deletedInvID.insert(idValue)
            }
        }

        // Memulai pembaruan batch untuk `tableView`.
        // Ini mengoptimalkan kinerja dengan menunda pembaruan visual hingga `endUpdates()` dipanggil.
        tableView.beginUpdates()
        // Memulai kelompok undo. Semua operasi undo yang didaftarkan antara `beginUndoGrouping()`
        // dan `endUndoGrouping()` akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()
        // Mengiterasi baris yang dipilih dalam urutan terbalik.
        // Mengiterasi secara terbalik penting saat menghapus item dari array
        // agar indeks baris yang tersisa tidak bergeser secara tidak terduga.
        for row in rows.reversed() {
            // Menghapus data dari array model lokal (`self.data`) pada indeks baris saat ini.
            let deletedData = data.remove(at: row)
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                self?.undoHapus(deletedData)
            })
            // Memberi tahu `tableView` untuk menghapus baris secara visual dengan animasi `slideDown`.
            tableView.removeRows(at: IndexSet([row]), withAnimation: .slideDown)
            // Logika untuk memilih baris setelah penghapusan.
            // Jika baris yang dihapus adalah baris terakhir, pilih baris sebelumnya.
            if row == tableView.numberOfRows { // Perhatikan: `numberOfRows` sudah diperbarui setelah `removeRows`
                tableView.selectRowIndexes(IndexSet([row - 1]), byExtendingSelection: false)
            } else {
                // Jika tidak, pilih baris yang sekarang berada di posisi baris yang dihapus.
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            }
        }
        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()
        tableView.endUpdates()
        updateUndoRedo()
    }

    /// Memanggil ``deleteColumn(at:)`` ketika menghapus kolom.
    @IBAction func deleteColumnButtonClicked(_ sender: NSMenuItem) {
        guard let columnIdentifier = sender.representedObject as? NSUserInterfaceItemIdentifier else { return }

        // Mencari index kolom yang sesuai dengan identifier
        if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier == columnIdentifier }) {
            let alert = NSAlert()
            alert.messageText = "Hapus Kolom"
            alert.informativeText = "Apakah Anda yakin ingin menghapus kolom \(tableView.tableColumns[columnIndex].title)?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Hapus")
            alert.addButton(withTitle: "Batalkan")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                deleteColumn(at: columnIdentifier.rawValue)
            }
        }
        updateUndoRedo()
    }

    /// Fungsi yang menangani tombol tambah data.
    @IBAction func addRowButtonClicked(_ sender: Any) {
        // Membuat dictionary baru berdasarkan kolom yang ada

        Task { [weak self] in
            guard let self else { return }
            var newData: [String: Any] = [:]
            let currentDate = SingletonData.dateFormatter.string(from: Date())

            for column in SingletonData.columns {
                if column.type == String.self {
                    if column.name == "Nama Barang" {
                        newData[column.name] = "Nama Barang"
                    } else if column.name == "Tanggal Dibuat" {
                        newData[column.name] = currentDate
                    } else {
                        newData[column.name] = "" // Nilai default untuk kolom String lainnya
                    }
                } else if column.type == Int64.self {
                    newData[column.name] = 0 // Nilai default untuk kolom Integer
                }
            }

            // Menambahkan data baru ke array data di baris pertama
            data.insert(newData, at: 0)

            // Simpan data baru ke database dan dapatkan ID yang baru
            guard let newId = await manager.insertData(newData) else { return }

            // Update newData dengan ID yang baru
            data[0]["id"] = newId // Menyimpan ID baru ke dictionary data
            data[0]["Tanggal Dibuat"] = currentDate // Hari ini
            data[0]["Nama Barang"] = "Nama Barang" // default: Nama barang
            self.newData.insert(newId) // insert ke data

            await MainActor.run { [weak self] in
                guard let self else { return }
                // Tambahkan baris ke table view setelah menambahkan data
                tableView.insertRows(at: IndexSet([0]), withAnimation: .slideUp)
                tableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang")) //
                AppDelegate.shared.editorManager.startEditing(row: 0, column: columnIndexNamaBarang)
                myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                    self?.undoAddRows([newId])
                })
            }
        }
    }

    /// Fungsi untuk menambahkan foto baru ke database.
    ///
    /// Foto dapat ditambahkan melalui drop ke row atau ke tableView.
    /// - Parameters:
    ///   - row: Baris di ``tableView`` dan ``data``
    ///   - imageData: `Data` foto yang ditambahkan.
    func saveImageToDatabase(atRow row: Int, imageData: Data) {
        let rowData = data[row]
        guard let id = rowData["id"] as? Int64,
              let imageView = NSImage(data: imageData) else { return }
        Task {
            // Cek apakah gambar memiliki alpha channel
            let hasAlpha = imageView.representations.contains { rep in
                guard let bitmapRep = rep as? NSBitmapImageRep else { return false }
                return bitmapRep.hasAlpha
            }

            // Kompres gambar dengan mempertahankan transparansi jika diperlukan
            let compressedImageData = imageView.compressImage(
                quality: 0.5,
                preserveTransparency: hasAlpha
            ) ?? Data()

            await manager.saveImageToDatabase(id, foto: compressedImageData)
            data[row]["Foto"] = compressedImageData

            await MainActor.run { [weak self] in
                guard let self else { return }
                let columnIndexOfNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                if let cell = tableView.view(atColumn: columnIndexOfNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let resizedImage = ReusableFunc.resizeImage(image: imageView, to: size)
                    cell.imageView?.image = resizedImage
                }

                let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                let sizeInMB = Double(compressedImageData.count) / (1024 * 1024)
                if let cell = tableView.view(atColumn: columnIndexOfFoto, row: row, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.stringValue = String(format: "%.2f MB", sizeInMB)
                }
            }
        }
    }
}

// MARK: - UNDO REDO

extension InventoryView {
    /// Berguna untuk memperbarui action/target menu item undo/redo di Menu Bar.
    func updateUndoRedo() {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
        else {
            return
        }

        let canUndo = myUndoManager.canUndo
        let canRedo = myUndoManager.canRedo

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
            redoMenuItem.action = #selector(performRedo(_:))
            redoMenuItem.isEnabled = canRedo
        }

        NotificationCenter.default.post(name: .bisaUndo, object: nil)
    }

    /// Fungsi untuk menjalankan undo.
    @objc func performUndo(_ sender: Any) {
        myUndoManager.undo()
        updateUndoRedo()
    }

    /// Fungsi untuk menjalankan redo.
    @objc func performRedo(_ sender: Any) {
        myUndoManager.redo()
        updateUndoRedo()
    }

    /// Fungsi untuk mengurungkan penggantian gambar setelah *drop* gambar
    /// ke salah satu row di ``tableView``
    /// - Parameters:
    ///   - id: `id` unik data yang akan diperbarui.
    ///   - imageData: `Data` gambar yang digunakan untuk memperbarui.
    func undoReplaceImage(_ id: Int64, imageData: Data) {
        guard let row = findRowIndex(forId: id) else {
            return
        }
        let newImage = data[row]["Foto"] as? Data
        data[row]["Foto"] = imageData
        Task {
            await self.manager.saveImageToDatabase(id, foto: imageData)
        }
        let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))

        if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
            if !imageData.isEmpty {
                cell.imageView?.image = NSImage(data: imageData)
            } else {
                cell.imageView?.image = NSImage(named: "pensil")
            }
        }
        let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
        let sizeInMB = Double(imageData.count) / (1024 * 1024)
        if let cell = tableView.view(atColumn: columnIndexOfFoto, row: row, makeIfNecessary: false) as? NSTableCellView {
            cell.textField?.stringValue = String(format: "%.2f MB", sizeInMB)
        }
        tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.redoReplaceImage(id, imageData: newImage ?? Data())
        })
    }

    /// Fungsi untuk mengulangi penggantian gambar setelah *drop* gambar
    /// ke salah satu row di ``tableView``
    /// - Parameters:
    ///   - id: `id` unik data yang akan diperbarui.
    ///   - imageData: `Data` gambar yang digunakan untuk memperbarui.
    func redoReplaceImage(_ id: Int64, imageData: Data) {
        guard let row = findRowIndex(forId: id) else {
            return
        }
        let oldImage = data[row]["Foto"] as? Data
        data[row]["Foto"] = imageData

        Task {
            await self.manager.saveImageToDatabase(id, foto: imageData)
        }

        let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
        if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
            if !imageData.isEmpty {
                cell.imageView?.image = NSImage(data: imageData)
            } else {
                cell.imageView?.image = NSImage(named: "pensil")
            }
        }
        let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
        let sizeInMB = Double(imageData.count) / (1024 * 1024)
        if let cell = tableView.view(atColumn: columnIndexOfFoto, row: row, makeIfNecessary: false) as? NSTableCellView {
            cell.textField?.stringValue = String(format: "%.2f MB", sizeInMB)
        }
        tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.undoReplaceImage(id, imageData: oldImage ?? Data())
        })
    }

    /// Fungsi untuk mengulangi hapus kolom.
    /// - Parameter columnName: Nama kolom yang akan dihapus
    func redoDeleteColumn(columnName: String) {
        let columnToDelete = columnName

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[columnToDelete] ?? "")) // Simpan ID dan nilai kolom
            }
        }

        /* Data tidak langsung dihapus di database. tetapi disimpan terlebih dahulu dalam array untuk dihapus nanti ketika pengguna memilih untuk menyimpan perubahan data. */
        SingletonData.deletedColumns.append((columnName: columnToDelete, columnData: columnData))

        guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnName)) else { return }
        tableView.removeTableColumn(column)

        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
                self.myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                    self?.undoDeleteColumn()
                })
                self.removeMenuItem(for: columnName)
                self.updateUndoRedo()
                self.setupDescriptor()
            }
        }
    }

    /// Membatalkan operasi penghapusan kolom sebelumnya.
    /// Fungsi ini mengembalikan kolom yang dihapus ke tampilan tabel dan juga mengembalikan
    /// data yang terkait dengan kolom tersebut ke posisi aslinya di setiap baris.
    func undoDeleteColumn() {
        // Pastikan ada kolom yang dihapus sebelumnya untuk dibatalkan.
        guard !SingletonData.deletedColumns.isEmpty else { return }

        // Ambil detail kolom yang terakhir dihapus dari daftar `deletedColumns`.
        let lastDeleted = SingletonData.deletedColumns.removeLast()
        let columnName = lastDeleted.columnName // Nama kolom yang akan dikembalikan.
        let columnData = lastDeleted.columnData // Data yang terkait dengan kolom ini.

        // Tambahkan kolom kembali ke `NSTableView`.
        // Baris yang dikomentari `manager.addColumn` menunjukkan bahwa penambahan kolom ke database
        // kemungkinan ditangani secara otomatis atau di tempat lain yang relevan.
        let newColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
        newColumn.title = columnName // Atur judul kolom sesuai nama aslinya.
        tableView.addTableColumn(newColumn) // Tambahkan kolom baru ke tabel.

        // Kembalikan data kolom ke baris yang sesuai berdasarkan ID.
        // Iterasi melalui setiap baris dalam model data lokal (`self.data`).
        for (index, row) in data.enumerated() {
            // Pastikan setiap baris memiliki ID.
            if let id = row["id"] as? Int64 {
                // Cari data yang cocok di `columnData` berdasarkan ID.
                if let matchedData = columnData.first(where: { $0.id == id }) {
                    // Jika data ditemukan, kembalikan nilai ke kolom yang sesuai (`columnName`)
                    // di baris `data` pada indeks saat ini.
                    data[index][columnName] = matchedData.value
                }
            }
        }

        // Daftarkan operasi redo untuk operasi undo ini.
        // Jika pengguna memilih "redo", fungsi `redoDeleteColumn` akan dipanggil
        // untuk menghapus kembali kolom tersebut.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.redoDeleteColumn(columnName: columnName)
        })

        // Memuat ulang dan memperbarui tampilan tabel setelah perubahan.
        // Ini mensimulasikan pembaruan tabel seolah-olah sort descriptors baru saja diubah,
        // memastikan tampilan yang benar.
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu() // Perbarui menu kolom agar kolom yang dikembalikan terlihat.
        updateUndoRedo() // Perbarui status tombol undo/redo.
        setupDescriptor() // Setel ulang deskriptor (mungkin untuk menyelaraskan dengan kolom yang dikembalikan).
    }

    /// Membatalkan (undo) serangkaian perubahan pada tabel dan database.
    /// Fungsi ini mengembalikan nilai-nilai data ke kondisi sebelumnya berdasarkan model perubahan yang disediakan.
    /// Pembaruan dilakukan baik pada model data lokal maupun database, dengan pembaruan UI yang sesuai.
    /// Ini juga mendaftarkan operasi "ulang" (redo) untuk membatalkan undo ini.
    ///
    /// - Parameter model: Sebuah array `[TableChange]` yang berisi detail perubahan yang akan dibatalkan.
    ///                    Setiap `TableChange` diharapkan berisi `id` entitas, `columnName` yang diubah,
    ///                    dan `oldValue` yang akan dikembalikan.
    func urung(_ model: [TableChange]) {
        tableView.deselectAll(nil)

        // Variabel untuk melacak indeks baris tertinggi yang dimodifikasi,
        // yang nantinya akan digunakan untuk menggulir tabel.
        var maxRow: Int?
        // Iterasi melalui setiap perubahan yang perlu dibatalkan.
        for change in model { // Mengganti nama parameter `model` menjadi `change` agar lebih jelas
            // Cari indeks baris dalam model data lokal (`self.data`) yang cocok dengan ID dari perubahan.
            if let rowIndex = data.firstIndex(where: { $0["id"] as? Int64 == change.id }) {
                // Perbarui data di model lokal dengan `oldValue` yang ingin dikembalikan.
                data[rowIndex][change.columnName] = change.oldValue

                // Gulir tabel agar baris yang dimodifikasi terlihat.
                tableView.scrollRowToVisible(rowIndex)

                // Dapatkan indeks kolom di `tableView` yang sesuai dengan `columnName` dari perubahan.
                if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == change.columnName }) {
                    // Pastikan indeks kolom valid untuk menghindari crash.
                    guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return }

                    // Dapatkan tampilan sel (`NSTableCellView`) untuk baris dan kolom yang relevan.
                    // `makeIfNecessary: false` berarti kita hanya ingin mengambil sel jika sudah ada.
                    if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        // Jika `oldValue` adalah String, perbarui secara asinkron.
                        if let newString = change.oldValue as? String {
                            Task { [weak self] in
                                guard let self else { return }
                                // Perbarui database dengan nilai lama.
                                await manager.updateDatabase(ID: change.id, column: change.columnName, value: newString)

                                // Kembali ke MainActor untuk pembaruan UI.
                                await MainActor.run { [weak self] in
                                    guard let self else { return }
                                    // Pembaruan UI spesifik untuk kolom "Nama Barang" (langsung set stringValue).
                                    if change.columnName == "Nama Barang" {
                                        cellView.textField?.stringValue = newString
                                    } else {
                                        // Untuk kolom lain, muat ulang sel spesifik di tabel.
                                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndex]))
                                    }
                                }
                            }
                        } else {
                            // Jika `oldValue` bukan String (misalnya `nil` atau tipe lain), set ke string kosong.
                            Task { [weak self] in
                                // Perbarui database dengan string kosong.
                                await self?.manager.updateDatabase(ID: change.id, column: change.columnName, value: "")
                                // Kembali ke MainActor untuk pembaruan UI.
                                await MainActor.run {
                                    cellView.textField?.stringValue = "" // Perbarui UI sel.
                                }
                            }
                        }
                        // Pilih baris yang telah dimodifikasi di tabel.
                        tableView.selectRowIndexes(IndexSet([rowIndex]), byExtendingSelection: true)
                    }

                    // Perbarui `maxRow` jika `rowIndex` saat ini lebih besar.
                    if rowIndex > maxRow ?? 0 {
                        maxRow = rowIndex
                    }
                }
            }
        }

        if let maxRow {
            tableView.scrollRowToVisible(maxRow)
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.ulang(model)
        })
        updateUndoRedo()
    }

    /// Membatalkan (ulang) serangkaian perubahan pada tabel dan database.
    /// Fungsi ini mengembalikan nilai-nilai data ke kondisi sebelumnya (setelah undo) berdasarkan model perubahan yang disediakan.
    /// Pembaruan dilakukan baik pada model data lokal maupun database, dengan pembaruan UI yang sesuai.
    /// Ini juga mendaftarkan operasi "urung" (undo) untuk membatalkan redo ini.
    ///
    /// - Parameter model: Sebuah array `[TableChange]` yang berisi detail perubahan yang telah diterapkan.
    ///                    Setiap `TableChange` diharapkan berisi `id` entitas, `columnName` yang diubah,
    ///                    dan `oldValue` yang akan dikembalikan.
    func ulang(_ model: [TableChange]) {
        tableView.deselectAll(nil)
        var maxRow: Int?
        for model in model {
            if let rowIndex = data.firstIndex(where: { $0["id"] as? Int64 == model.id }) {
                data[rowIndex][model.columnName] = model.newValue
                tableView.scrollRowToVisible(rowIndex)
                if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == model.columnName }) {
                    // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                    guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return }
                    if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        if let newString = model.newValue as? String {
                            Task { [weak self] in
                                guard let self else { return }
                                await manager.updateDatabase(ID: model.id, column: model.columnName, value: newString)
                                await MainActor.run { [weak self] in
                                    guard let self else { return }
                                    if model.columnName == "Nama Barang" {
                                        cellView.textField?.stringValue = newString
                                    } else {
                                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndex]))
                                    }
                                }
                            }
                        } else {
                            Task { [weak self] in
                                await self?.manager.updateDatabase(ID: model.id, column: model.columnName, value: "")
                                await MainActor.run {
                                    cellView.textField?.stringValue = ""
                                }
                            }
                        }
                    }
                    tableView.selectRowIndexes(IndexSet([rowIndex]), byExtendingSelection: true)
                    if rowIndex > maxRow ?? 0 {
                        maxRow = rowIndex
                    }
                }
            }
        }
        if let maxRow {
            tableView.scrollRowToVisible(maxRow)
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.urung(model)
        })
        updateUndoRedo()
    }

    /// Membatalkan operasi penghapusan baris data sebelumnya.
    /// Fungsi ini mengembalikan baris yang dihapus ke dalam model data aplikasi dan `NSTableView`
    /// pada posisi yang benar berdasarkan kriteria pengurutan yang aktif.
    ///
    /// - Parameter model: Sebuah `Dictionary` `[String: Any]` yang berisi data dari baris yang dihapus
    ///                    yang perlu dikembalikan.
    func undoHapus(_ model: [String: Any]) {
        // Memulai kelompok undo. Operasi yang terjadi di antara `beginUndoGrouping()`
        // dan `endUndoGrouping()` akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()

        // Menghapus semua pilihan baris di tabel.
        tableView.deselectAll(self)

        // Memastikan ada deskriptor pengurutan yang aktif di tabel.
        // Jika tidak ada, fungsi akan berhenti karena tidak dapat menentukan posisi penyisipan.
        guard let sort = tableView.sortDescriptors.first else { return }

        // Menentukan indeks yang benar untuk menyisipkan kembali `model`
        // agar tabel tetap terurut sesuai dengan deskriptor pengurutan yang aktif.
        let rowInsertion = data.insertionIndex(for: model, using: sort)

        // Menyisipkan kembali data `model` ke dalam array data lokal (`self.data`)
        // pada indeks yang telah ditentukan.
        data.insert(model, at: rowInsertion)

        // Mendaftarkan operasi redo untuk operasi undo ini.
        // Jika pengguna melakukan redo, fungsi `redoHapus` akan dipanggil dengan `model` asli
        // untuk menghapus kembali item tersebut.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.redoHapus(model)
        })

        // Jika `model` memiliki ID, hapus ID tersebut dari set `SingletonData.deletedInvID`.
        // Ini membalikkan tindakan yang dilakukan saat baris dihapus.
        if let id = model["id"] as? Int64 {
            SingletonData.deletedInvID.remove(id)
        }

        // Memberi tahu `tableView` untuk menyisipkan baris secara visual
        // pada `rowInsertion` dengan animasi `.effectGap`.
        tableView.insertRows(at: IndexSet([rowInsertion]), withAnimation: .effectGap)

        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()

        // Menunda eksekusi blok kode ini ke antrean utama setelah 0.2 detik.
        // Ini memberikan waktu bagi animasi penyisipan untuk selesai sebelum memilih dan menggulir.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            // Setelah baris disisipkan, cari indeksnya lagi (untuk memastikan lokasi yang akurat).
            if let index = data.firstIndex(where: { $0["id"] as? Int64 == model["id"] as? Int64 }) {
                // Pilih baris yang baru disisipkan.
                tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: true)
                // Gulir tabel agar baris yang dipilih terlihat.
                tableView.scrollRowToVisible(index)
            } else {
                // Jika baris tidak ditemukan (mungkin terjadi kesalahan atau kondisi yang tidak terduga).
                // Anda bisa menambahkan penanganan kesalahan atau logging di sini.
            }
        }

        // Memperbarui status tombol undo/redo di UI.
        updateUndoRedo()
    }

    /// Mengulangi operasi penghapusan baris data yang sebelumnya diurungkan.
    /// Fungsi ini menghapus baris yang sebelumnya telah dihapus dan urungkan
    /// ke dalam model data aplikasi dan `NSTableView`
    /// pada posisi yang benar berdasarkan kriteria pengurutan yang aktif.
    ///
    /// - Parameter model: Sebuah `Dictionary` `[String: Any]` yang berisi data dari baris yang dihapus
    ///                    yang perlu dikembalikan
    func redoHapus(_ model: [String: Any]) {
        myUndoManager.beginUndoGrouping()
        tableView.beginUpdates()
        if let id = model["id"] as? Int64 {
            SingletonData.deletedInvID.insert(id)
        }
        if let index = data.firstIndex(where: { $0["id"] as? Int64 == model["id"] as? Int64 }) {
            data.remove(at: index)
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                self?.undoHapus(model)
            })
            tableView.removeRows(at: IndexSet([index]), withAnimation: .slideDown)
            if index == tableView.numberOfRows {
                //
                tableView.selectRowIndexes(IndexSet([index - 1]), byExtendingSelection: false)
            } else {
                tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
                //
            }
        } else {}
        tableView.endUpdates()
        myUndoManager.endUndoGrouping()
        updateUndoRedo()
    }

    /// Membatalkan operasi penambahan baris sebelumnya.
    /// Fungsi ini menghapus baris-baris yang baru ditambahkan dari model data aplikasi dan `NSTableView`
    /// berdasarkan daftar ID yang diberikan. Ia juga menangani pembaruan UI dan mendaftarkan operasi redo.
    ///
    /// - Parameter ids: Sebuah array `[Int64]` yang berisi ID unik dari baris-baris yang sebelumnya ditambahkan
    ///                  dan sekarang akan dihapus (dibatalkan penambahannya).
    func undoAddRows(_ ids: [Int64]) {
        var oldDatas = [[String: Any]]() // Menyimpan data dari baris yang dihapus untuk kemungkinan redo.
        var rowsToSelect = IndexSet() // Indeks baris yang akan dipilih setelah operasi selesai.

        tableView.beginUpdates()
        // Iterasi melalui setiap ID yang disediakan (yang mewakili baris yang baru ditambahkan).
        for id in ids {
            // Cari indeks baris dalam model data lokal (`self.data`) yang cocok dengan ID saat ini.
            guard let index = data.firstIndex(where: { $0["id"] as? Int64 == id }) else { continue }

            // Hapus data dari array model lokal dan simpan sebagai `oldData` untuk operasi redo.
            let oldData = data.remove(at: index)
            oldDatas.append(oldData)

            // Hapus ID dari set `newData` (asumsi ini melacak data yang baru dibuat/belum disimpan).
            newData.remove(id)

            // Tambahkan ID ke `SingletonData.deletedInvID`. Ini mungkin digunakan
            // untuk menandai item ini sebagai "dihapus" di database, bahkan jika itu adalah undo dari "tambah".
            SingletonData.deletedInvID.insert(id)

            // Catat indeks baris yang dihapus untuk kemungkinan seleksi di kemudian hari.
            rowsToSelect.insert(index)

            // Memberi tahu `tableView` untuk menghapus baris secara visual
            // pada indeks yang ditentukan dengan animasi `slideDown`.
            tableView.removeRows(at: IndexSet([index]), withAnimation: .slideDown)

            // Pilih baris yang sekarang berada di posisi baris yang baru saja dihapus.
            // Ini memberikan umpan balik visual kepada pengguna.
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
        }
        tableView.endUpdates()

        if let endOfRow = rowsToSelect.max(), endOfRow < tableView.numberOfRows {
            tableView.scrollRowToVisible(endOfRow)
        } else {
            if tableView.numberOfRows > 0 {
                tableView.scrollRowToVisible(rowsToSelect.min() ?? 0)
            }
        }

        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.redoAddRows(oldDatas)
        })
        updateUndoRedo()
    }

    /// Mengulangi operasi penambahan baris sebelumnya.
    /// Fungsi ini menambahkan kembali baris-baris yang baru ditambahkan yang kemudian diurungkan
    /// ke model data aplikasi dan `NSTableView`
    /// berdasarkan daftar ID yang diberikan. Ia juga menangani pembaruan UI dan mendaftarkan operasi redo.
    ///
    /// - Parameter ids: Sebuah array `[Int64]` yang berisi ID unik dari baris-baris yang sebelumnya ditambahkan
    ///                  dan sekarang akan dihapus (dibatalkan penambahannya).
    func redoAddRows(_ newDatas: [[String: Any]]) {
        // Menambahkan data baru ke array data di baris pertama
        var ids = [Int64]()
        tableView.deselectAll(nil)
        tableView.beginUpdates()
        for newData in newDatas {
            guard let sort = tableView.sortDescriptors.first else { return }
            let rowInsertion = data.insertionIndex(for: newData, using: sort)
            data.insert(newData, at: rowInsertion)
            guard let id = newData["id"] as? Int64 else { return }
            data[rowInsertion]["id"] = id // Menyimpan ID baru ke dictionary data
            self.newData.insert(id)
            ids.append(id)
            SingletonData.deletedInvID.remove(id)
            // Reload table view setelah menambahkan data
            tableView.insertRows(at: IndexSet([rowInsertion]), withAnimation: .effectGap)
            tableView.selectRowIndexes(IndexSet([rowInsertion]), byExtendingSelection: true)
        }
        tableView.endUpdates()

        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.undoAddRows(ids)
        })
        updateUndoRedo()
    }
}

// MARK: - TABLEVIEW MENU

extension InventoryView: NSMenuDelegate {
    /// Fungsi yang dijalankan ketika menerima notifikasi dari `.saveData`.
    ///
    /// Menjalankan logika untuk menyiapkan ulang database, memperbarui `data` dari database,
    /// dan memuat ulang seluruh baris di ``tableView``.
    /// - Parameter sender: Objek apapun.
    @objc func saveData(_ sender: Any) {
        guard isDataLoaded else { return }

        Task(priority: .background) { [weak self] in
            guard let self else { return }
            self.newData.removeAll()

            await manager.setupDatabase()
            await self.data = self.manager.loadData()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.myUndoManager.removeAllActions()
                self.updateUndoRedo()
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
            }
        }
    }

    /// Fungsi yang dijalankan ketika menu item `hapus` diklik.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        let klikRow = tableView.clickedRow
        let rows = tableView.selectedRowIndexes
        // jika row yang diklik kanan termasuk dari row yang dipilih(baris yang disorot dengan warna aksen sistem)
        if rows.contains(klikRow) {
            delete(sender)
        }
        // jika row yang diklik kanan tidak termasuk dari row yang dipilih.
        else {
            tableView.selectRowIndexes(IndexSet([klikRow]), byExtendingSelection: false)
            delete(sender)
        }
    }

    /// Membuka antarmuka pengguna untuk mengedit data baris yang dipilih.
    /// Fungsi ini menginisialisasi jendela edit (`CariDanGanti`) dengan data dari baris-baris
    /// yang dipilih di tabel dan daftar kolom yang dapat diedit.
    /// Setelah perubahan data dilakukan di jendela edit, fungsi ini menangani pembaruan
    /// pada model data lokal dan database secara asinkron, sambil memastikan
    /// fungsionalitas undo/redo yang mulus.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol Edit).
    @objc func edit(_ sender: Any) {
        // Membuat instance dari ViewController `CariDanGanti`
        // yang menangani logika pencarian dan penggantian/pengeditan.
        let editVC = CariDanGanti.instantiate()

        // Mengisi `objectData` di `editVC` dengan data dari baris-baris yang dipilih di `tableView`.
        // Iterasi terbalik memastikan urutan data tetap konsisten jika ada perubahan.
        for row in tableView.selectedRowIndexes.reversed() {
            editVC.objectData.append(data[row])
        }

        // Mengisi `columns` di `editVC` dengan nama-nama kolom yang dapat diedit.
        // Kolom "id", "Tanggal Dibuat", dan "Foto" secara eksplisit dikecualikan
        // karena biasanya tidak diedit secara langsung oleh pengguna.
        for column in tableView.tableColumns {
            guard column.identifier.rawValue != "id",
                  column.identifier.rawValue != "Tanggal Dibuat",
                  column.identifier.rawValue != "Foto"
            else { continue } // Lewati kolom-kolom yang tidak boleh diedit.
            editVC.columns.append(column.identifier.rawValue) // Tambahkan nama kolom yang dapat diedit.
        }

        // Menetapkan closure `onUpdate` yang akan dipanggil oleh `editVC` ketika data berhasil diperbarui.
        editVC.onUpdate = { [weak self] updatedRows, selectedColumn in
            // Memastikan `self` (instans kelas saat ini) masih ada.
            guard let self else { return }

            /*
             `updatedRows` adalah array dari dictionary `[String: Any]`,
             yang berisi data yang telah dimodifikasi dari jendela edit.
             Contoh strukturnya:
             [
             ["id": 123, "Nama Barang": "Buku Tulis (edited)", ...],
             ["id": 456, "Nama Barang": "Pensil (edited)", ...]
             ]
             */

            // Memulai Task asinkron untuk menangani pembaruan database dan model data.
            // Ini menjaga UI tetap responsif selama operasi yang berpotensi memakan waktu.
            Task {
                var undoChanges = [TableChange]() // Array untuk menyimpan perubahan demi fungsionalitas undo.

                // Iterasi melalui setiap baris data yang telah diperbarui dari `editVC`.
                for updatedData in updatedRows {
                    // Memastikan `id` dan `newValue` (nilai baru dari kolom yang diedit) valid.
                    guard let idValue = updatedData["id"] as? Int64,
                          let newValue = updatedData[selectedColumn] as? String
                    else {
                        continue // Lewati jika data tidak valid.
                    }

                    // Perbarui database dengan nilai baru untuk ID dan kolom yang sesuai.
                    await self.manager.updateDatabase(ID: idValue, column: selectedColumn, value: newValue)

                    // Cari indeks baris yang relevan dalam model data lokal (`self.data`).
                    if let rowIndex = self.data.firstIndex(where: { ($0["id"] as? Int64) == idValue }) {
                        // Ambil nilai lama dari kolom sebelum diperbarui, untuk keperluan undo.
                        let oldValue = self.data[rowIndex][selectedColumn]
                        // Tambahkan perubahan ke `undoChanges`.
                        undoChanges.append(TableChange(id: idValue, columnName: selectedColumn, oldValue: oldValue as Any, newValue: newValue as Any))

                        // Perbarui seluruh baris dalam model data lokal dengan `updatedData` yang baru.
                        self.data[rowIndex] = updatedData

                        // Kembali ke `MainActor` untuk memperbarui UI tabel secara spesifik.
                        await MainActor.run {
                            // Muat ulang sel tertentu di `tableView` untuk merefleksikan perubahan.
                            // Ini lebih efisien daripada memuat ulang seluruh tabel.
                            self.tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                        }
                    }
                }

                // Daftarkan operasi undo untuk semua perubahan yang baru saja dilakukan.
                // Saat di-undo, fungsi `urung` akan dipanggil dengan kumpulan `undoChanges`.
                self.myUndoManager.registerUndo(withTarget: self, handler: { inventory in
                    inventory.urung(undoChanges)
                })

                // Kembali ke `MainActor` untuk menampilkan pesan keberhasilan dan memperbarui status undo/redo.
                await MainActor.run {
                    // Tampilkan jendela progres atau notifikasi keberhasilan.
                    ReusableFunc.showProgressWindow(3, pesan: "Pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) ?? ReusableFunc.menuOnStateImage!)
                    // Perbarui status tombol undo/redo di UI.
                    self.updateUndoRedo()
                }
            }
        }

        // Menetapkan closure `onClose` yang akan dipanggil saat jendela edit ditutup.
        editVC.onClose = {
            self.updateUndoRedo() // Perbarui status undo/redo setelah jendela ditutup.
        }

        // Menampilkan `editVC` sebagai sheet yang menempel pada jendela utama.
        presentAsSheet(editVC)
        // Mengatur ulang item menu di Menu Bar.
        ReusableFunc.resetMenuItems()
    }

    /// Fungsi yang dijalankan ketika menu item **Buka Foto** diklik.
    ///
    /// Menu item dibuat dari func ``buatMenuItem()``.
    @objc func tampilkanFoto(_ sender: NSMenuItem) {
        let klikRow = tableView.clickedRow
        let rows = tableView.selectedRowIndexes

        // Memeriksa apakah baris yang diklik (`klikRow`) termasuk dalam kumpulan baris yang saat ini dipilih (`rows`),
        // dan memastikan `klikRow` adalah indeks baris yang valid (bukan -1).
        if rows.contains(klikRow), klikRow != -1 {
            // Menangani kasus di mana **beberapa baris dipilih dan baris yang diklik adalah salah satunya**.
            // Iterasi melalui setiap baris yang dipilih.
            for row in rows {
                // Memulai Task asinkron untuk membuka gambar dari setiap baris yang dipilih di jendela pratinjau.
                // Ini memastikan UI tetap responsif.
                Task {
                    await openImageInPreview(forRow: row)
                }
            }
        } else if !rows.contains(klikRow), klikRow != -1 {
            // Menangani kasus di mana **baris yang diklik tidak termasuk dalam pilihan yang ada,
            // tetapi merupakan baris yang valid (pemilihan tunggal baru)**.
            // Ini mungkin terjadi ketika pengguna mengklik baris yang tidak dipilih tanpa menekan tombol modifikasi.
            Task {
                // Membuka gambar hanya untuk baris yang baru saja diklik di jendela pratinjau.
                await openImageInPreview(forRow: klikRow)
            }
        } else {
            // Menangani kasus lain, termasuk skenario di mana `klikRow` adalah -1 (tidak ada baris yang diklik,
            // atau konteks lainnya), atau di mana `rows` tidak berisi `klikRow` tetapi `klikRow` juga -1
            // (kondisi yang mungkin redundan atau perlu klarifikasi lebih lanjut).
            // Dalam kasus ini, semua baris yang saat ini dipilih akan diproses.
            for row in rows {
                // Memulai Task asinkron untuk membuka gambar dari setiap baris yang dipilih di jendela pratinjau.
                Task {
                    await openImageInPreview(forRow: row)
                }
            }
        }
    }

    /// Membuka gambar yang terkait dengan baris tertentu di aplikasi Pratinjau macOS.
    /// Fungsi ini mengambil data gambar dari database secara asinkron, menyimpannya ke file sementara,
    /// dan kemudian meluncurkan aplikasi Pratinjau untuk menampilkan gambar tersebut.
    /// Penanganan kesalahan disertakan untuk kasus di mana gambar tidak dapat dimuat atau dibuka.
    ///
    /// - Parameter row: `Int` yang menunjukkan indeks baris di `NSTableView` yang gambarnya ingin dibuka.
    func openImageInPreview(forRow row: Int) async {
        // Memastikan baris yang diberikan valid dan memiliki "id" yang dapat diakses sebagai Int64.
        guard let id = data[row]["id"] as? Int64 else { return }

        // Mengambil data gambar (Data) dari database menggunakan `manager.getImage(id)`.
        // Asumsi `manager.getImage` adalah fungsi asinkron.
        let imageData = await manager.getImage(id)

        // Membuat direktori sementara untuk menyimpan file gambar.
        // Ini memastikan gambar disimpan di lokasi yang aman dan dapat diakses sementara.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TempImages", isDirectory: true)

        do {
            // Coba buat direktori sementara jika belum ada.
            // `withIntermediateDirectories: true` akan membuat direktori induk yang diperlukan.
            try FileManager.default.createDirectory(at: tempDir,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)

            // Membuat nama file unik untuk gambar.
            // Nama file menggunakan "Nama Barang" (jika ada) dan UUID untuk menghindari konflik.
            let filename = "\(data[row]["Nama Barang"] ?? "Foto")-\(UUID().uuidString).png"
            // Menggabungkan direktori sementara dengan nama file untuk mendapatkan URL file lengkap.
            let fileURL = tempDir.appendingPathComponent(filename)

            // Menulis data gambar ke file sementara.
            try imageData.write(to: fileURL)

            // Mendapatkan URL untuk aplikasi Pratinjau (Preview.app) menggunakan bundle identifier.
            if let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
                // Membuat objek konfigurasi opsional untuk membuka aplikasi.
                let configuration = NSWorkspace.OpenConfiguration()

                // Membuka file gambar dengan aplikasi Pratinjau.
                // Closure completion akan dipanggil setelah operasi selesai.
                NSWorkspace.shared.open([fileURL], withApplicationAt: previewAppURL, configuration: configuration) { app, error in
                    // Jika aplikasi berhasil dibuka, cetak pesan debug (hanya di mode DEBUG).
                    if let app {
                        #if DEBUG
                            print("File opened successfully in \(app.localizedName ?? "Preview").")
                        #endif
                    } else if let error {
                        // Jika terjadi kesalahan saat membuka file, tampilkan peringatan di antrean utama.
                        DispatchQueue.main.async {
                            ReusableFunc.showAlert(title: "Error", message: error.localizedDescription)
                        }
                    }
                }
            }
        } catch {
            // Menangani kesalahan yang terjadi selama proses (misalnya, gagal membuat direktori, gagal menulis file).
            // Tampilkan `NSAlert` untuk memberi tahu pengguna tentang masalah tersebut.
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            // Tampilkan alert sebagai sheet modal yang melekat pada jendela utama.
            alert.beginSheetModal(for: view.window ?? NSWindow()) { _ in }
        }
    }

    /// Menangani aksi untuk menyimpan foto, baik untuk baris tunggal yang diklik maupun beberapa baris yang dipilih.
    /// Fungsi ini memeriksa konteks pemilihan baris di `NSTableView` untuk menentukan
    /// apakah akan memicu penyimpanan foto untuk satu baris (berdasarkan klik) atau beberapa baris (berdasarkan seleksi).
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu atau tombol).
    @objc func simpanFoto(_ sender: Any) {
        // Memeriksa apakah ada baris yang diklik (`tableView.clickedRow != -1`).
        if tableView.clickedRow != -1 {
            // Kondisi pertama: Jika baris yang diklik termasuk dalam baris yang dipilih,
            // dan ada setidaknya satu baris yang dipilih yang valid dalam batas data.
            if tableView.selectedRowIndexes.contains(tableView.clickedRow), let selectedRow = tableView.selectedRowIndexes.first,
               selectedRow < data.count
            {
                // Memanggil fungsi untuk menangani penyimpanan foto untuk beberapa baris yang dipilih.
                simpanMultipleFoto(sender)
            }
            // Kondisi kedua: Jika baris yang diklik TIDAK termasuk dalam baris yang dipilih.
            else if !tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Memulai `Task` asinkron untuk menangani penyimpanan foto untuk baris tunggal yang diklik.
                // Ini menjaga UI tetap responsif.
                Task { [weak self] in
                    await self?.simpanFotoKlik(sender)
                }
            }
        }
        // Kondisi ketiga: Jika tidak ada baris yang diklik (`tableView.clickedRow == -1`),
        // tetapi ada setidaknya satu baris yang dipilih (`tableView.numberOfSelectedRows >= 1`).
        else if tableView.numberOfSelectedRows >= 1 {
            // Memanggil fungsi untuk menangani penyimpanan foto untuk beberapa baris yang dipilih.
            simpanMultipleFoto(sender)
        }
        // Kondisi default: Jika tidak ada baris yang diklik maupun dipilih, tidak ada aksi yang dilakukan.
        else {
            return
        }
    }

    /// Menyimpan foto dari baris yang diklik oleh pengguna ke lokasi yang dipilih pada sistem berkas.
    /// Fungsi ini mengambil data foto dari database berdasarkan ID baris yang diklik,
    /// kemudian menampilkan panel penyimpanan untuk memungkinkan pengguna memilih lokasi dan nama file.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu konteks).
    @objc func simpanFotoKlik(_ sender: Any) async {
        var id: Int64 = 0 // Variabel untuk menyimpan ID data yang terkait dengan foto.
        var namaBarang = "" // Variabel untuk menyimpan nama barang yang terkait dengan foto.

        // Mendapatkan indeks baris yang diklik dari `tableView`.
        let klikRow = tableView.clickedRow

        // Menginisialisasi `id` dan `namaBarang` dengan data dari baris yang diklik.
        id = data[klikRow]["id"] as? Int64 ?? -1
        namaBarang = data[klikRow]["Nama Barang"] as? String ?? ""

        // Memverifikasi ID dari data yang dipilih (misalnya dari table view).
        // Logika ini tampaknya mencoba menangani skenario di mana ada pilihan tunggal atau klik tunggal.
        if tableView.clickedRow != -1 {
            // Jika baris yang diklik juga termasuk dalam baris yang dipilih,
            // dan baris pertama yang dipilih valid dalam batas data.
            if tableView.selectedRowIndexes.contains(tableView.clickedRow), let selectedRow = tableView.selectedRowIndexes.first,
               selectedRow < data.count
            {
                // Perbarui `id` dan `namaBarang` berdasarkan baris yang dipilih (yang pertama).
                id = data[selectedRow]["id"] as? Int64 ?? -1
                namaBarang = data[selectedRow]["Nama Barang"] as? String ?? ""
            }
            // Jika baris yang diklik tidak termasuk dalam baris yang dipilih (ini berarti hanya satu baris yang diklik).
            else if !tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Perbarui `id` dan `namaBarang` berdasarkan baris yang diklik.
                let klikRow = tableView.clickedRow // Variabel ini sudah dideklarasikan di awal, bisa dihapus duplikasinya.
                id = data[klikRow]["id"] as? Int64 ?? -1
                namaBarang = data[klikRow]["Nama Barang"] as? String ?? ""
            }
        }

        // Memastikan ID yang valid telah ditemukan sebelum melanjutkan.
        guard id != -1 else { return }

        // Mengambil data foto dari database secara asinkron menggunakan `manager.getImage(id)`.
        let fotoData = await manager.getImage(id)

        // Memastikan bahwa `fotoData` tidak kosong sebelum mencoba menyimpannya.
        guard fotoData.count > 0,
              let pngFoto = NSImage(data: fotoData)?.pngRepresentation
        else {
            // Jika `fotoData` kosong, Anda bisa menambahkan notifikasi kepada pengguna di sini.
            // ReusableFunc.showAlert(title: "Info", message: "Tidak ada foto untuk disimpan.")
            return
        }

        // Membuat instance `NSSavePanel` untuk memungkinkan pengguna memilih lokasi penyimpanan.
        let savePanel = NSSavePanel()
        savePanel.title = "Simpan Foto" // Judul panel penyimpanan.
        savePanel.nameFieldLabel = "Nama Foto:" // Label untuk bidang nama file.
        // Menetapkan nama file default yang menggabungkan ID dan nama barang.
        savePanel.nameFieldStringValue = "\(id)_\(namaBarang).tiff"
        // Menentukan tipe konten yang diizinkan untuk penyimpanan (TIFF, JPEG, PNG).
        savePanel.allowedContentTypes = [.tiff, .jpeg, .png]

        // Membuka panel penyimpanan sebagai sheet modal yang melekat pada jendela aplikasi.
        savePanel.beginSheetModal(for: view.window!) { result in
            // Memeriksa apakah pengguna mengklik tombol "Save" (OK).
            if result == .OK {
                // Mendapatkan URL lokasi penyimpanan yang dipilih oleh pengguna.
                if let saveURL = savePanel.url {
                    do {
                        // Coba tulis `fotoData` ke URL yang dipilih.
                        try pngFoto.write(to: saveURL)

                        // Opsional: Tampilkan pesan sukses kepada pengguna di sini.
                        // await MainActor.run {
                        //     ReusableFunc.showProgressWindow(3, pesan: "Foto berhasil disimpan!", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)!)
                        // }
                    } catch {
                        // Jika terjadi kesalahan saat menulis file, tangani di sini.
                        // Contoh: Tampilkan peringatan kepada pengguna.
                        // DispatchQueue.main.async {
                        //     ReusableFunc.showAlert(title: "Error", message: "Gagal menyimpan foto: \(error.localizedDescription)")
                        // }
                    }
                }
            }
        }
    }

    /// Menyimpan beberapa foto dari baris yang dipilih di tabel ke folder yang ditentukan oleh pengguna.
    /// Fungsi ini pertama-tama meminta pengguna untuk memilih direktori penyimpanan.
    /// Setelah folder dipilih, ia secara asinkron mengambil data foto untuk setiap baris yang dipilih dari database,
    /// dan menyimpannya sebagai file terpisah di folder yang dipilih.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu atau tombol).
    @objc func simpanMultipleFoto(_ sender: Any) {
        // Memastikan ada setidaknya satu baris yang dipilih di tabel.
        // Jika tidak, fungsi akan berhenti karena tidak ada foto yang akan disimpan.
        guard tableView.numberOfSelectedRows > 0 else {
            // Anda bisa menambahkan umpan balik UI di sini, misalnya alert "Pilih setidaknya satu baris".
            return
        }

        // Membuat instance `NSOpenPanel` yang dikonfigurasi sebagai pemilih folder.
        let openPanel = NSOpenPanel()
        openPanel.title = "Pilih Folder Penyimpanan Foto" // Judul panel.
        openPanel.canChooseDirectories = true // Izinkan pengguna memilih direktori.
        openPanel.canCreateDirectories = true // Izinkan pengguna membuat direktori baru.
        openPanel.canChooseFiles = false // Jangan izinkan pengguna memilih file.
        openPanel.allowsMultipleSelection = false // Hanya izinkan pemilihan satu folder.
        openPanel.prompt = "Simpan disini" // Teks tombol konfirmasi.

        // Membuka panel pemilih folder sebagai sheet modal yang menempel pada jendela aplikasi.
        openPanel.beginSheetModal(for: view.window!) { result in
            // Memastikan pengguna mengklik tombol "Simpan disini" (OK) dan folder telah dipilih.
            guard result == .OK, let selectedFolderURL = openPanel.url else {
                return // Jika tidak, keluar dari closure.
            }

            // Iterasi melalui setiap indeks baris yang dipilih di `tableView`.
            for selectedRow in self.tableView.selectedRowIndexes {
                // Memastikan indeks baris valid dalam batas array data lokal.
                guard selectedRow < self.data.count else { continue }

                // Mendapatkan ID dan "Nama Barang" dari data baris yang dipilih.
                let id = self.data[selectedRow]["id"] as? Int64 ?? -1
                let namaBarang = self.data[selectedRow]["Nama Barang"] as? String ?? ""

                // Memastikan ID valid sebelum melanjutkan untuk baris ini.
                guard id != -1 else { continue }

                // Memulai `Task` asinkron untuk setiap foto. Ini memungkinkan operasi pengambilan
                // dan penyimpanan gambar berjalan secara paralel tanpa memblokir UI utama.
                Task { [weak self] in
                    guard let self else { return } // Memastikan `self` masih ada.

                    // Mengambil data foto dari database berdasarkan ID.
                    let fotoData = await self.manager.getImage(id)

                    // Memastikan `fotoData` tidak kosong. Jika kosong, tidak ada yang disimpan untuk baris ini.
                    guard fotoData.count > 0,
                          let pngFoto = NSImage(data: fotoData)?.pngRepresentation
                    else { return }

                    // Membuat URL lengkap untuk file foto di dalam folder yang dipilih,
                    // menggunakan ID dan nama barang untuk nama file yang unik.
                    let saveURL = selectedFolderURL.appendingPathComponent("\(id)_\(namaBarang).png")

                    do {
                        // Menyimpan data foto ke lokasi file yang ditentukan.
                        try pngFoto.write(to: saveURL)

                        // Opsional: Anda bisa menambahkan log atau pembaruan UI kecil di sini
                        // untuk setiap foto yang berhasil disimpan.
                    } catch {
                        // Mencetak deskripsi kesalahan jika terjadi masalah saat menyimpan foto.
                        // Anda bisa menambahkan notifikasi kepada pengguna di sini juga.
                        print(error.localizedDescription)
                    }
                }
            }

            // Setelah semua operasi penyimpanan dimulai (secara asinkron), tampilkan pemberitahuan.
            // Pemberitahuan ini memberi tahu pengguna bahwa proses penyimpanan telah diinisiasi.
            let alert = NSAlert()
            alert.messageText = "Penyimpanan Foto Selesai"
            alert.informativeText = "Semua foto yang dipilih telah disimpan."
            alert.alertStyle = .informational
            // Menampilkan alert sebagai sheet modal. `completionHandler: nil` berarti tidak ada aksi
            // khusus yang dilakukan setelah pengguna menutup alert.
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
    }

    /// Menyalin data dari baris yang dipilih atau yang diklik di tabel ke papan klip sistem.
    /// Fungsi ini menentukan apakah operasi penyalinan harus berdasarkan multi-seleksi
    /// atau hanya pada baris yang terakhir diklik jika tidak termasuk dalam seleksi aktif.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu konteks atau tombol).
    @objc func salinData(_ sender: Any) {
        // Mendapatkan indeks baris yang saat ini dipilih di `tableView`.
        let rows = tableView.selectedRowIndexes
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let klikRow = tableView.clickedRow

        // Memeriksa apakah baris yang diklik termasuk dalam baris yang saat ini dipilih.
        if rows.contains(klikRow) {
            // Jika baris yang diklik sudah termasuk dalam seleksi, lanjutkan dengan menyalin
            // semua baris yang dipilih. Memastikan ada baris yang dipilih.
            guard rows.count > 0 else { return }
            copyDataToClipboard(rows)
        }
        // Jika tidak ada baris yang diklik (klikRow adalah -1), tetapi ada baris yang dipilih.
        else if klikRow == -1 {
            // Lanjutkan dengan menyalin semua baris yang dipilih. Memastikan ada baris yang dipilih.
            guard rows.count > 0 else { return }
            copyDataToClipboard(rows)
        }
        // Jika baris yang diklik tidak termasuk dalam baris yang dipilih,
        // dan `klikRow` adalah baris yang valid (bukan -1).
        else {
            // Salin hanya data dari baris yang diklik. Memastikan `klikRow` valid.
            guard klikRow != -1 else { return }
            copyDataToClipboard(IndexSet([klikRow])) // Mengubah `[klikRow]` menjadi `IndexSet([klikRow])` agar sesuai dengan parameter.
        }
    }

    /// Menyalin data dari baris-baris yang dipilih di tabel ke papan klip sistem.
    /// Data disalin dalam format teks yang dipisahkan oleh tab, cocok untuk ditempelkan ke spreadsheet
    /// atau editor teks, dengan baris header yang berisi nama-nama kolom.
    ///
    /// - Parameter selectedRows: Sebuah `IndexSet` yang berisi indeks baris-baris yang dipilih
    ///                           yang datanya akan disalin.
    func copyDataToClipboard(_ selectedRows: IndexSet) {
        var copiedString = "" // String yang akan berisi data yang disalin, dalam format teks.

        // Mengambil nama kolom secara dinamis dari `SingletonData.columns`.
        // Ini memastikan bahwa urutan dan nama kolom sesuai dengan konfigurasi saat ini.
        let columnNames = SingletonData.columns.map(\.name)

        // Menambahkan baris header ke `copiedString`.
        // Nama-nama kolom digabungkan dengan tab (`\t`) dan diakhiri dengan karakter baris baru (`\n`).
        copiedString += columnNames.joined(separator: "\t") + "\n"

        // Mengiterasi setiap indeks baris dalam `selectedRows`.
        for rowIndex in selectedRows {
            // Mengambil seluruh data (sebagai Dictionary) untuk baris yang sedang diiterasi.
            let rowData = data[rowIndex]

            // Membuat array sementara untuk menampung nilai-nilai string dari setiap kolom
            // untuk baris saat ini.
            var rowString: [String] = []

            // Mengiterasi setiap `columnName` yang telah diambil secara dinamis.
            // Ini memastikan bahwa data disalin sesuai urutan kolom yang benar.
            for columnName in columnNames {
                // Memeriksa tipe data dari nilai di `rowData` untuk `columnName` tertentu.
                if let value = rowData[columnName] as? String {
                    // Jika nilai adalah String, tambahkan langsung ke `rowString`.
                    rowString.append(value)
                } else if let value = rowData[columnName] as? Int64 {
                    // Jika nilai adalah Int64, konversi ke String lalu tambahkan.
                    rowString.append(String(value))
                } else {
                    // Jika nilai adalah `nil` atau tipe data lain yang tidak ditangani,
                    // tambahkan string kosong untuk menjaga konsistensi kolom.
                    rowString.append("")
                }
            }

            // Menggabungkan nilai-nilai di `rowString` dengan tab (`\t`) dan menambahkan
            // karakter baris baru (`\n`) untuk menandai akhir baris data.
            copiedString += rowString.joined(separator: "\t") + "\n"
        }

        // Menyalin `copiedString` yang telah diformat ke papan klip umum sistem (`NSPasteboard.general`).
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents() // Menghapus konten sebelumnya dari papan klip.
        pasteboard.setString(copiedString, forType: .string) // Menetapkan string baru.
    }

    /// Menghapus data foto yang terkait dengan baris-baris yang dipilih di tabel.
    /// Fungsi ini memperbarui model data lokal dan database secara asinkron untuk menghapus foto,
    /// lalu memperbarui UI tabel untuk merefleksikan perubahan. Ini juga mendukung fungsionalitas undo/redo.
    ///
    /// - Parameter row: `IndexSet` yang berisi indeks baris-baris yang fotonya akan dihapus.
    @objc func hapusFoto(_ row: IndexSet) {
        // Memulai pembaruan batch untuk `tableView` untuk kinerja yang lebih baik.
        tableView.beginUpdates()
        // Memulai kelompok undo. Semua operasi undo yang didaftarkan di dalam blok ini
        // akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()

        // Iterasi melalui setiap indeks baris yang dipilih dalam `IndexSet` yang diberikan.
        for selectedRow in row {
            // Memastikan `selectedRow` berada dalam batas array `data` (model lokal).
            guard selectedRow < data.count else { return }
            // Mendapatkan ID dari baris yang dipilih. Jika tidak ada ID, lewati baris ini.
            guard let id = data[selectedRow]["id"] as? Int64 else { return }

            // Mencari indeks baris (lagi) berdasarkan ID. Ini mungkin redundan jika `selectedRow`
            // sudah valid, tetapi memastikan data yang benar jika ada pengurutan atau perubahan lain.
            if let actualRowIndex = findRowIndex(forId: id) {
                // Menyimpan `newImage` (sebenarnya `oldImage` atau `currentImage`) sebelum menghapus.
                // Ini penting untuk operasi undo. Jika tidak ada gambar, gunakan `Data()` kosong.
                let newImage = data[actualRowIndex]["Foto"] as? Data

                // Menyetel nilai "Foto" di model data lokal menjadi `Data()` kosong,
                // yang secara efektif menghapus referensi gambar.
                data[actualRowIndex]["Foto"] = Data()

                // Memulai `Task` asinkron untuk melakukan operasi yang memakan waktu di latar belakang.
                Task { [weak self] in
                    guard let self else { return } // Memastikan `self` masih ada.

                    // Memanggil `manager.hapusImage(id)` untuk menghapus gambar dari database.
                    await self.manager.hapusImage(id)

                    // Kembali ke `MainActor` untuk melakukan pembaruan UI.
                    await MainActor.run { [weak self] in
                        guard let self else { return } // Memastikan `self` masih ada.

                        // Mendapatkan indeks kolom "Nama Barang" di tabel.
                        let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                        // Jika sel untuk "Nama Barang" ditemukan, perbarui gambar sel menjadi "pensil" (placeholder).
                        if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: actualRowIndex, makeIfNecessary: false) as? NSTableCellView {
                            cell.imageView?.image = NSImage(named: "pensil")
                        }

                        // Mendapatkan indeks kolom "Foto" di tabel.
                        let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                        // Jika sel untuk "Foto" ditemukan, perbarui teksnya menjadi "0.00 MB" (menunjukkan tidak ada foto).
                        if let cell = tableView.view(atColumn: columnIndexOfFoto, row: actualRowIndex, makeIfNecessary: false) as? NSTableCellView {
                            cell.textField?.stringValue = "0.00 MB"
                        }

                        // Mendaftarkan operasi undo untuk penghapusan foto ini.
                        // Saat di-undo, `redoReplaceImage` akan dipanggil dengan ID dan data gambar yang lama
                        // untuk mengembalikan foto tersebut.
                        self.myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
                            self?.redoReplaceImage(id, imageData: newImage ?? Data())
                        })
                    }
                }
            }
        }
        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()
        // Mengakhiri pembaruan batch untuk `tableView`, memicu pembaruan visual.
        tableView.endUpdates()
        // Memperbarui status tombol undo/redo di UI.
        updateUndoRedo()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menu)
        }
        view.window?.makeFirstResponder(tableView)
    }
}

// MARK: - SEARCH

extension InventoryView: NSSearchFieldDelegate {
    /// Menangani input dari `NSSearchField` untuk memicu pencarian dengan penundaan (debouncing).
    /// Fungsi ini membatalkan operasi pencarian sebelumnya yang sedang berjalan dan memulai tugas baru
    /// dengan penundaan singkat. Ini mencegah terlalu banyak pembaruan pencarian saat pengguna mengetik,
    /// sehingga meningkatkan kinerja dan responsivitas aplikasi.
    ///
    /// - Parameter sender: `NSSearchField` yang memicu aksi ini, yang berisi string pencarian.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        // Batalkan `searchTask` yang sedang berjalan (jika ada).
        // Ini adalah teknik debouncing: setiap kali input baru datang, tugas sebelumnya dibatalkan
        // agar hanya tugas terakhir yang selesai.
        searchTask?.cancel()

        // Membuat `Task` asinkron baru untuk melakukan pencarian.
        searchTask = Task { [weak self] in
            // Menunggu selama 0.5 detik sebelum melanjutkan.
            // Ini memberikan jeda singkat sehingga jika pengguna mengetik cepat,
            // tugas ini akan dibatalkan oleh input berikutnya.
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik

            // Memeriksa apakah `Task` telah dibatalkan atau jika `self` telah dilepaskan dari memori.
            // Jika salah satu kondisi benar, hentikan eksekusi.
            guard !Task.isCancelled, let self else { return }

            // Memanggil fungsi `search` dengan nilai string dari `NSSearchField`.
            // Fungsi `search` diasumsikan akan melakukan logika pencarian data yang sebenarnya.
            await self.search(sender.stringValue)

            // Meminta `tableView` untuk melepaskan status first responder-nya.
            // Ini mungkin untuk menghilangkan fokus keyboard dari tabel setelah pencarian selesai.
            self.tableView.resignFirstResponder()
        }
    }

    /// Melakukan pencarian data secara asinkron berdasarkan teks pencarian yang diberikan.
    /// Fungsi ini memuat semua data, lalu memfilter data tersebut untuk menemukan baris yang cocok
    /// dengan teks pencarian di kolom mana pun. Proses pemfilteran dilakukan secara paralel
    /// untuk efisiensi. Hasil pencarian kemudian diperbarui pada tampilan tabel.
    ///
    /// - Parameter searchText: `String` yang berisi teks yang akan digunakan untuk pencarian.
    func search(_ searchText: String) async {
        // Jika teks pencarian sama dengan `stringPencarian` yang terakhir, tidak perlu melakukan pencarian ulang.
        if searchText == stringPencarian { return }

        // Memperbarui `stringPencarian` dengan teks pencarian yang baru.
        stringPencarian = searchText

        // Jika `searchText` kosong, berarti pengguna telah menghapus teks pencarian.
        // Dalam kasus ini, muat ulang semua data asli ke tabel.
        if searchText.isEmpty {
            data = await manager.loadData() // Muat semua data dari manager.
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Beri tahu tabel untuk memperbarui tampilan berdasarkan deskriptor pengurutan saat ini.
                self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
            }
            return // Hentikan eksekusi fungsi karena pencarian selesai.
        }

        // Muat semua data asli dari manager untuk kemudian difilter.
        let originalData = await manager.loadData()

        // Memfilter data menggunakan `withTaskGroup` untuk melakukan pencarian secara paralel.
        // Ini meningkatkan kinerja dengan mendistribusikan pekerjaan pencarian ke beberapa tugas.
        let filteredData = await withTaskGroup(of: [String: Any]?.self) { group in
            // Iterasi melalui setiap baris dalam `originalData`.
            for row in originalData {
                // Menambahkan tugas baru ke grup untuk setiap baris.
                group.addTask {
                    // Untuk setiap baris, iterasi melalui semua kolom yang didefinisikan di `SingletonData.columns`.
                    for column in SingletonData.columns {
                        // Periksa apakah nilai kolom (setelah dikonversi ke String dan diubah menjadi huruf kecil)
                        // mengandung `searchText` (juga dalam huruf kecil).
                        if let value = row[column.name],
                           "\(value)".lowercased().contains(searchText.lowercased())
                        {
                            return row // Jika cocok, kembalikan baris tersebut.
                        }
                    }
                    return nil // Jika tidak ada kolom yang cocok di baris ini, kembalikan `nil`.
                }
            }

            var hasil: [[String: Any]] = [] // Array untuk menyimpan hasil pencarian.
            // Kumpulkan hasil dari semua tugas yang telah selesai di grup.
            for await item in group {
                if let data = item {
                    hasil.append(data) // Tambahkan baris yang cocok ke hasil.
                }
            }
            return hasil // Kembalikan data yang sudah difilter.
        }

        // Kembali ke `MainActor` untuk memperbarui UI.
        await MainActor.run { [unowned self] in
            // Ganti data tabel dengan data yang sudah difilter.
            self.data = filteredData
            // Beri tahu tabel untuk memperbarui tampilan berdasarkan deskriptor pengurutan saat ini.
            self.tableView(self.tableView, sortDescriptorsDidChange: self.tableView.sortDescriptors)
        }
    }
}

// MARK: - DRAG ROW KE APLIKASI LAIN

extension InventoryView: NSFilePromiseProviderDelegate {
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let mouseLocation = tableView.window?.mouseLocationOutsideOfEventStream ?? .zero
        let locationInView = tableView.convert(mouseLocation, from: nil)

        // Dapatkan kolom di posisi mouse
        let column = tableView.column(at: locationInView)

        guard column == 1 else { return nil }

        // Dapatkan cell view
        guard let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cellView.textField else { return nil }
        // Buat semaphore untuk menunggu operasi selesai
        let customQueue = DispatchQueue(label: "sdi.Data-SDI.pasteboardWriterQueue", qos: .userInteractive)

        if tableView.selectedRowIndexes.contains(row) {
            // Buat file promise provider dengan userInfo yang lengkap
            let provider = FilePromiseProvider(
                fileType: UTType.data.identifier,
                delegate: self
            )
            // Siapkan data foto untuk setiap item yang didrag.
            customQueue.async { [weak self] in
                guard let self else { return }
                let nama = self.data[row]["Nama Barang"] as? String ?? "Nama Barang"
                let foto = self.data[row]["Foto"] as? Data
                // Send over the row number and photo's url dictionary.
                provider.userInfo = [FilePromiseProvider.UserInfoKeys.namaKey: nama,
                                     FilePromiseProvider.UserInfoKeys.imageKey: foto as Any]
            }
            return provider
        }

        // Konversi posisi mouse ke koordinat cell
        let locationInCell = cellView.convert(locationInView, from: tableView)

        // Hitung lebar teks sebenarnya
        let text = textField.stringValue
        let font = textField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)

        // Pastikan mouse berada dalam area teks, bukan di area kosong textfield
        guard locationInCell.x <= textSize.width else { return nil }
        // Buat file promise provider dengan userInfo yang lengkap
        let provider = FilePromiseProvider(
            fileType: UTType.data.identifier,
            delegate: self
        )

        // Siapkan data foto untuk setiap item yang didrag.
        customQueue.async { [weak self] in
            guard let self else { return }
            let nama = self.data[row]["Nama Barang"] as? String ?? "Nama Barang"
            let foto = self.data[row]["Foto"] as? Data
            // Send over the row number and photo's url dictionary.
            provider.userInfo = [FilePromiseProvider.UserInfoKeys.namaKey: nama,
                                 FilePromiseProvider.UserInfoKeys.imageKey: foto as Any]
        }
        return provider
    }

    /// Mengatur fungsionalitas _drag and drop_ untuk `NSTableView`.
    /// Fungsi ini mengonfigurasi tabel agar dapat menerima data yang diseret dari aplikasi lain,
    /// khususnya file gambar dan teks. Ini juga mengaktifkan _multiple selection_
    /// dan mengatur _feedback style_ visual saat _dragging_ ke tabel.
    func setupTableDragAndDrop() {
        // Mengatur jenis operasi _dragging source_ yang didukung oleh tabel ketika bertindak
        // sebagai sumber seretan. `.copy` berarti tabel memungkinkan data-nya disalin (bukan dipindahkan)
        // ke aplikasi lain, dan `forLocal: false` menunjukkan bahwa ini berlaku untuk target non-lokal.
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        // Mendaftarkan tabel untuk tipe data yang dapat diterima saat menjadi _dragging destination_.
        // Ini berarti tabel dapat menerima data gambar TIFF, PNG, URL file, dan string.
        tableView.registerForDraggedTypes([.tiff, .png, .fileURL, .string])

        // Mengaktifkan _multiple selection_ pada tabel, memungkinkan pengguna memilih
        // lebih dari satu baris secara bersamaan.
        tableView.allowsMultipleSelection = true

        // Mengatur _feedback style_ visual yang ditampilkan saat item diseret di atas tabel.
        // `.regular` biasanya menampilkan indikator penyisipan di antara baris.
        tableView.draggingDestinationFeedbackStyle = .regular
    }

    /// Memeriksa apakah sumber operasi _drag_ berasal dari `NSTableView` ini sendiri.
    /// Fungsi ini membantu membedakan antara operasi _drag and drop_ internal (di dalam aplikasi ini)
    /// dan eksternal (dari aplikasi lain).
    ///
    /// - Parameter draggingInfo: Objek `NSDraggingInfo` yang berisi informasi tentang operasi _drag_ yang sedang berlangsung.
    /// - Returns: `Bool` yang bernilai `true` jika sumber _drag_ adalah `tableView` ini,
    ///            dan `false` jika bukan.
    func dragSourceIsFromOurTable(draggingInfo: NSDraggingInfo) -> Bool {
        // Memeriksa apakah `draggingSource` dari `draggingInfo` adalah instance dari `NSTableView`,
        // dan jika `NSTableView` tersebut sama dengan `tableView` ini (`self.tableView`).
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableView {
            true // Jika ya, sumber drag berasal dari tabel kita.
        } else {
            false // Jika tidak, sumber drag bukan dari tabel kita.
        }
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let nama = userInfoDict[FilePromiseProvider.UserInfoKeys.namaKey] as? String else { return "unknown.dat" }
        
        return nama.replacingOccurrences(of: "/", with: "-") + ".png"
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let fotoData = userInfoDict[FilePromiseProvider.UserInfoKeys.imageKey] as? Data
        else {
            completionHandler(NSError(domain: "", code: -1))
            return
        }
        DispatchQueue.global(qos: .background).async {
            guard let fotoJPEG = NSImage(data: fotoData)?.pngRepresentation else { print("error"); return }
            do {
                try fotoJPEG.write(to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                             didFailToWritePromiseTo url: URL,
                             error: Error) {}
}

// MARK: - EKSTENSI PENGURUTAN INDEKS

extension [[String: Any]] {
    /// Menentukan indeks yang tepat untuk menyisipkan sebuah elemen baru ke dalam koleksi yang sudah terurut.
    /// Fungsi ini mencari posisi di mana `element` harus disisipkan agar koleksi tetap terurut
    /// sesuai dengan `sortDescriptor` yang diberikan.
    ///
    /// - Parameters:
    ///   - element: Elemen (data) yang akan disisipkan. `Element` diasumsikan sebagai alias untuk `[String: Any]`.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan (kunci dan arah).
    ///
    /// - Returns: `Index` (Int) di mana `element` harus disisipkan. Jika `element` harus ditempatkan
    ///            di akhir koleksi, `endIndex` akan dikembalikan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        // Menggunakan `firstIndex` untuk mencari elemen pertama yang memenuhi kondisi.
        // Jika tidak ada elemen yang memenuhi, `nil` akan dikembalikan, dan operator `??` akan
        // mengembalikan `endIndex`, artinya elemen baru harus ditambahkan di akhir.
        firstIndex { item in
            // Memastikan `sortDescriptor` memiliki kunci (nama kolom) yang valid.
            guard let key = sortDescriptor.key else { return false }

            // Membungkus nilai dari `item` (elemen yang ada di koleksi) dan `element` (elemen baru)
            // dalam dictionary yang diformat khusus. Ini diperlukan karena `ReusableFunc.compareValues`
            // mengharapkan format input tertentu yang mencakup kolom, nilai, dan seluruh item.
            let value1 = [
                "column": SingletonData.columns.first(where: { $0.name == key })!, // Informasi kolom.
                "value": item[key], // Nilai dari `item` pada kunci kolom.
                "item": item, // Seluruh data `item`.
            ]
            let value2 = [
                "column": SingletonData.columns.first(where: { $0.name == key })!, // Informasi kolom.
                "value": element[key], // Nilai dari `element` pada kunci kolom.
                "item": element, // Seluruh data `element`.
            ]

            // Membandingkan `value1` (item yang ada) dengan `value2` (elemen yang akan disisipkan)
            // menggunakan fungsi `ReusableFunc.compareValues`. Fungsi ini akan mengembalikan
            // `ComparisonResult` (.orderedAscending, .orderedSame, atau .orderedDescending).
            let result = ReusableFunc.compareValues(value1 as [String: Any], value2 as [String: Any])

            // Logika untuk menentukan apakah `element` harus disisipkan *sebelum* `item` saat ini.
            // Jika pengurutan `ascending` (naik):
            //   - Kita mencari item pertama yang `result`nya `.orderedDescending` (artinya `element` lebih kecil dari `item`).
            // Jika pengurutan `descending` (turun):
            //   - Kita mencari item pertama yang `result`nya `.orderedAscending` (artinya `element` lebih besar dari `item`).
            return sortDescriptor.ascending ?
                result == .orderedDescending : // Untuk ascending, cari yang lebih besar dari element
                result == .orderedAscending // Untuk descending, cari yang lebih kecil dari element
        } ?? endIndex // Jika tidak ada item yang memenuhi kondisi, sisipkan di akhir.
    }
}

// MARK: - QUICK LOOK

extension InventoryView {
    /// Menampilkan foto-foto yang terkait dengan baris yang dipilih atau yang diklik di tabel menggunakan Quick Look.
    /// Fungsi ini menentukan apakah akan menampilkan pratinjau untuk satu baris (berdasarkan klik)
    /// atau untuk beberapa baris (berdasarkan seleksi), kemudian memanggil fungsi `showQuickLook` yang sesuai.
    ///
    /// - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini.
    @objc func tampilkanFotos(_ sender: NSMenuItem) {
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let klikRow = tableView.clickedRow

        // Memeriksa apakah ada baris yang diklik (`klikRow` valid).
        if klikRow != -1 {
            // Kondisi pertama: Jika baris yang diklik termasuk dalam baris yang saat ini dipilih
            // dan `klikRow` adalah indeks yang valid (tidak negatif).
            if tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                // Tampilkan Quick Look untuk semua baris yang dipilih.
                showQuickLook(tableView.selectedRowIndexes)
            }
            // Kondisi kedua: Jika baris yang diklik TIDAK termasuk dalam baris yang dipilih
            // dan `klikRow` adalah indeks yang valid. Ini berarti hanya satu baris yang diklik
            // tanpa memengaruhi seleksi lainnya.
            else if !tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                // Tampilkan Quick Look hanya untuk baris yang diklik.
                showQuickLook(IndexSet([klikRow]))
            }
        }
        // Kondisi default: Jika tidak ada baris yang diklik (`klikRow == -1`),
        // atau jika kondisi di atas tidak terpenuhi, secara default tampilkan
        // Quick Look untuk semua baris yang saat ini dipilih.
        else {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    /// Menampilkan pratinjau cepat (Quick Look) untuk foto-foto yang terkait dengan baris yang dipilih.
    /// Fungsi ini menyiapkan file gambar sementara di direktori sementara sistem dan kemudian
    /// menginisialisasi atau memperbarui `QLPreviewPanel` untuk menampilkan gambar-gambar tersebut.
    ///
    /// - Parameter index: Sebuah `IndexSet` yang berisi indeks baris-baris di tabel
    ///                    yang foto-fotonya akan ditampilkan di Quick Look.
    func showQuickLook(_ index: IndexSet) {
        guard !index.isEmpty else { return }
        
        SharedQuickLook.shared.sourceTableView = tableView
        
        // Bersihkan preview items yang lama
        SharedQuickLook.shared.cleanTempDir()
        SharedQuickLook.shared.cleanPreviewItems()
        SharedQuickLook.shared.columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Nama Barang"))

        // Buat temporary directory baru
        let sessionID = UUID().uuidString
        SharedQuickLook.shared.setTempDir(FileManager.default.temporaryDirectory.appendingPathComponent(sessionID))

        guard let tempDir = SharedQuickLook.shared.getTempDir() else { return }
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            for row in index.reversed() {
                guard let imageData = data[row]["Foto"] as? Data, let nama = data[row]["Nama Barang"] as? String else { continue }
                let trimmedNama = nama.replacingOccurrences(of: "/", with: "-")
                let fileName = "\(trimmedNama).png"
                let fileURL = tempDir.appendingPathComponent(fileName)
                
                try imageData.write(to: fileURL)
                SharedQuickLook.shared.setPreviewItems(fileURL)
            }
            
            SharedQuickLook.shared.showQuickLook()
            
        } catch {
            #if DEBUG
            print(error.localizedDescription)
            #endif
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space key
            if SharedQuickLook.shared.isQuickLookVisible() {
                SharedQuickLook.shared.closeQuickLook()
            } else {
                showQuickLook(tableView.selectedRowIndexes)
            }
        } else if event.keyCode == 53 { // Key code 53 adalah tombol Esc
            if SharedQuickLook.shared.isQuickLookVisible() {
                SharedQuickLook.shared.closeQuickLook()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: EDITOR OVERLAY DATA SOURCE

extension InventoryView: OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard row < data.count else { return "" }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue

        return data[row][columnIdentifier] as? String ?? "" // Sesuaikan dengan model data Anda
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        // Asumsi hanya ada satu kolom atau kolom yang diedit adalah kolom yang diketahui
        tableView.tableColumns[column].width // Sesuaikan jika perlu
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        guard let column = SingletonData.columns.first(where: { $0.name == columnIdentifier }) else { return [] }
        // Ambil suggestions berdasarkan tipe kolom
        return getSuggestions(for: column)
    }
}

// MARK: EDITOR OVERLAY DATA DELEGATE

extension InventoryView: OverlayEditorManagerDelegate {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard row < data.count, column < tableView.tableColumns.count else { return }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue

        if let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
           let textField = cell.textField,
           let oldString = data[row][columnIdentifier] as? String
        {
            if newText == oldString || (columnIdentifier == "Nama Barang" && newText.isEmpty) {
                textField.stringValue = oldString
                return
            }
        }

        let oldValw = data[row][columnIdentifier]
        data[row][columnIdentifier] = newText.capitalizedAndTrimmed()

        // Dapatkan ID dari data
        guard let id = data[row]["id"] as? Int64 else {
            return
        }
        let model = TableChange(id: data[row]["id"] as! Int64, columnName: columnIdentifier, oldValue: oldValw as Any, newValue: data[row][columnIdentifier] as Any)
//        recordChange(id: data[row]["id"] as! Int64, columnName: columnKey, oldValue: oldValw as Any, newValue: data[row][columnKey] as Any)

        // Update database dengan nilai baru
        Task {
            await DynamicTable.shared.updateDatabase(ID: id, column: columnIdentifier, value: newText.capitalizedAndTrimmed())
        }
        myUndoManager.beginUndoGrouping()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] handler in
            self?.urung([model])
        })
        myUndoManager.endUndoGrouping()
        updateSuggestionsCache()
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        let identifier = tableView.tableColumns[column].identifier.rawValue
        if identifier == "id" || identifier == "Foto" || identifier == "Tanggal Dibuat" {
            return false
        }
        return true
    }
}
