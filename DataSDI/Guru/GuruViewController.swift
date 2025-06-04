//
//  GuruViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//
import Cocoa
import Foundation

class GuruViewController: NSViewController, NSSearchFieldDelegate {
    @IBOutlet weak var scrollView: NSScrollView!
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            outlineView.rowHeight += 5
            outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<outlineView.numberOfRows))
        })
        saveRowHeight()
    }
    @IBAction func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            outlineView.rowHeight = max(outlineView.rowHeight - 3, 16)
            outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<outlineView.numberOfRows))
        })
        saveRowHeight()
    }
    
    // Fungsi untuk menyimpan rowHeight ke UserDefaults
    func saveRowHeight() {
        UserDefaults.standard.setValue(outlineView.rowHeight, forKey: "GuruOutlineViewRowHeight")
    }
    @IBOutlet weak var outlineView: EditableOutlineView!
    var guruu: [GuruModel] = []
    var selectedIndex: Int!
    var myUndoManager: UndoManager = UndoManager()
    // Cek apakah ada item yang dipilih
    var warnaAlternatif = true
    static let identifier = NSUserInterfaceItemIdentifier("GuruViewController")
    let dbController = DatabaseController.shared
    var mapelList: [MapelModel] = []
    private var suggestionManager: SuggestionManager!
    private var activeText: NSTextField!
    var isDataLoaded: Bool = false
    lazy var stringPencarian: String = ""
    var toolbarMenu = NSMenu()
    var editorMager: OverlayEditorManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let savedRowHeight = UserDefaults.standard.value(forKey: "GuruOutlineViewRowHeight") as? CGFloat {
            outlineView.rowHeight = savedRowHeight
        }
        outlineView.refusesFirstResponder = false
        outlineView.setAccessibilityIdentifier("GuruViewController")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(self.view, isDataLoaded: isDataLoaded)
            for nabila in kolomTabelGuru {
                guard let salsabila = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(nabila.identifier)) else {
                    continue
                }
                let headerKolom = MyHeaderCell()
                headerKolom.title = nabila.customTitle
                salsabila.headerCell = headerKolom
                editorMager = OverlayEditorManager(tableView: outlineView, containingWindow: self.view.window!)
                editorMager?.delegate = self
                editorMager?.dataSource = self
                outlineView.editAction = { [weak self] (row, column) in
                    guard let self = self else { return }
                    self.editorMager?.startEditing(row: row, column: column)
                }
            }
            outlineView.dataSource = self
            outlineView.delegate = self
            outlineView.doubleAction = #selector(outlineViewDoubleClick(_:))
            let urutan = NSSortDescriptor(key: "NamaGuru", ascending: true)
            outlineView.sortDescriptors = [urutan]
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).sync { [weak self] in
                guard let self = self else {
                    group.leave()
                    if let s = self, let window = s.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    return
                }
                self.muatUlang(self)
                self.isDataLoaded = true
                group.leave()
            }
            group.notify(queue: .main) {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { timer in
                    if let window = self.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    timer.invalidate()
                }
            }
            
            suggestionManager = SuggestionManager(suggestions: [""])
            ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
        }
        if adaUpdateNamaGuru {
            guard isDataLoaded else {return}
            muatUlang(self)
        }
        setupSortDescriptor()
        let menu = buatMenuItem()
        toolbarMenu = buatMenuItem()
        toolbarMenu.delegate = self
        menu.delegate = self
        outlineView.menu = menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            self.view.window?.makeFirstResponder(self.outlineView)
            ReusableFunc.resetMenuItems()
            updateMenuItem(self)
            updateUndoRedo(self)
            ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: stringPencarian)
//            if let window = self.view.window, let group = window.tabGroup, !group.isTabBarVisible {
//                if self.scrollView.contentInsets.top != 38 {
//                    self.scrollView.contentInsets.top = 38
//                    self.scrollView.layoutSubtreeIfNeeded()
//                }
//            } else {
//                if self.scrollView.contentInsets.top == 38 {
//                    self.scrollView.contentInsets.top = 63
//                    self.scrollView.layoutSubtreeIfNeeded()
//                }
//            }
        }
        outlineView.refusesFirstResponder = false
        setupToolbar()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.guruDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNamaGuruUpdate(_:)), name: DatabaseController.namaGuruUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
    }
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }
        
        if column.identifier.rawValue == "NamaGuru" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        
        if column.identifier.rawValue == "Mapel" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden
        
        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }
    private func setupToolbar() {
        guard let toolbar = self.view.window?.toolbar else { return }
        let isItemSelected = outlineView.selectedRow != -1
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.isEnabled = true
            searchField.target = self
            searchField.action = #selector(procSearchFieldInput(sender:))
            searchField.delegate = self
            if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
                textFieldInsideSearchField.placeholderString = "Cari guru..."
            }
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton {
            hapus.isEnabled = isItemSelected
            hapus.target = self
            hapus.action = #selector(hapusSerentak(_:))
        }

        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton {
            edit.isEnabled = isItemSelected
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton {
            add.toolTip = "Catat Guru Baru"
            add.isEnabled = true
        }

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton {
            tambah.isEnabled = false
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton {
            popUpButton.menu = toolbarMenu
        }
    }

//    @objc func tabBarDidHide(_ notification: Notification) {
//
//        guard let window = self.view.window,
//           let tabGroup = window.tabGroup,
//           !tabGroup.isTabBarVisible else {
//            return
//        }
//        if self.scrollView.contentInsets.top != 38 {
//            DispatchQueue.main.async {
//                self.scrollView.contentInsets.top = 38
//            }
//        }
//    }
    
    @objc func saveData(_ notification: Notification) {
        // Gunakan dispatch group untuk memastikan semua operasi selesai
        let group = DispatchGroup()
        
        
        guard isDataLoaded else {return}
        group.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self = self else { return }
            // Bersihkan semua array
            self.deleteAllRedoArray()
            SingletonData.deletedGuru.removeAll()
            self.undoHapus.removeAll()
            self.guruu.removeAll()
            self.mapelList.removeAll()
            group.leave()
        }
        
        // Setelah semua operasi pembersihan selesai
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.myUndoManager.removeAllActions()
            self.updateUndoRedo(self)
            
            // Tunggu sebentar untuk memastikan database sudah ter-update
            self.dbController.notifQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                // Kembali ke main thread untuk update UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.muatUlang(self)
                }
            }
        }
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: "")
        searchWork?.cancel()
        searchWork = nil
        ReusableFunc.resetMenuItems()
    }
    var adaUpdateNamaGuru: Bool = false
    @objc func handleNamaGuruUpdate(_ Notification: Notification) {
        if !adaUpdateNamaGuru {
            adaUpdateNamaGuru = true
        } else {
            return
        }
    }
    var sortDescriptors: NSSortDescriptor?
    @IBAction func muatUlang(_ sender: Any) {
        let sortDescriptor = sortDescriptors ?? NSSortDescriptor(key: "NamaGuru", ascending: sortDescriptors?.ascending ?? true)
        
        Task { [unowned self] in
            // Bersihkan data yang ada
            guruu.removeAll()
            mapelList.removeAll()
            
            // Refresh data dari database secara asinkron
            guruu = await dbController.getGuru()
            
            // Kelompokkan data guru berdasarkan mapel
            var mapelDict: [String: [GuruModel]] = [:]
            for guru in guruu {
                mapelDict[guru.mapel, default: []].append(guru)
            }
            
            // Reset dan isi ulang mapelList berdasarkan mapelDict
            mapelList.removeAll()
            for (mapel, guruList) in mapelDict {
                let mapelModel = MapelModel(id: UUID(), namaMapel: mapel, guruList: guruList)
                mapelList.append(mapelModel)
            }
            
            // Update UI di MainActor
            await MainActor.run {
                adaUpdateNamaGuru = false
                sortDescriptors = outlineView.sortDescriptors.first!
                sortModel(by: sortDescriptor)
                outlineView.reloadData()
            }
            
            // Tunda selama 0.1 detik sebagai pengganti asyncAfter
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik
            
            // Lanjutkan update UI tambahan di MainActor
            await MainActor.run {
                self.loadExpandedItems()
                self.saveExpandedItems()
                self.updateUndoRedo(self)
            }
        }
    }

    @objc func handleDataDidChangeNotification(_ notification: Notification) {
        muatUlang(self)
    }
    
    @objc func updateUndoRedo(_ sender: Any?) {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" }) else {
            return
        }
        DispatchQueue.main.async { [unowned self] in
            let canRedo = myUndoManager.canRedo
            let canUndo = myUndoManager.canUndo
            // Set target dan action seperti sebelumnya
            if canUndo {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(urung(_:))
                undoMenuItem.isEnabled = true
            } else {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            }
            
            if canRedo {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(ulang(_:))
                redoMenuItem.isEnabled = true
            } else {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            }
            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
    }
    func deleteAllRedoArray() {
        if !redoHapus.isEmpty {
            redoHapus.removeAll()
        }
        if !SingletonData.undoAddGuru.isEmpty {
            SingletonData.undoAddGuru.removeAll()
        }
    }
    var undoHapus: [Int64] = []
    var redoHapus: [Int64] = []
    @objc func urung(_ sender: Any) {
        myUndoManager.undo()
    }
    @objc func ulang(_ sender: Any) {
        myUndoManager.redo()
    }
    @objc func hapusSerentak(_ sender: Any) {
        // Mendapatkan indeks baris yang dipilih
        let selectedRows = outlineView.selectedRowIndexes

        // Memastikan ada baris yang dipilih
        guard selectedRows.count > 0 else {return}

        var namaguru = Set<String>()
        var idToDelete = Set<Int64>() // Menggunakan set untuk menyimpan idGuru yang akan dihapus

        // Looping melalui setiap indeks yang dipilih
        for row in selectedRows {
            // Mendapatkan item di row yang dipilih
            if let selectedItem = outlineView.item(atRow: row) {
                if let guru = selectedItem as? GuruModel {
                    // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                    namaguru.insert(guru.namaGuru)
                    idToDelete.insert(guru.idGuru)
                } else if let mapel = selectedItem as? MapelModel {
                    // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                    namaguru.insert(mapel.namaMapel)
                    for guru in mapel.guruList {
                        idToDelete.insert(guru.idGuru)
                    }
                }
            }
        }
        let namaGuruString = namaguru.joined(separator: ", ")

        // Menampilkan peringatan konfirmasi sebelum menghapus
        let alert = NSAlert()
        alert.messageText = "Konfirmasi Penghapusan \(namaGuruString)"
        alert.informativeText = "Apakah Anda yakin akan menghapus data \(namaGuruString)?"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusGuruAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        alert.showsSuppressionButton = true
        
        guard !isSuppressed else { hapusRow(selectedRows, idToDelete: idToDelete); return}
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { // Tombol "Hapus" diklik
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            self.hapusRow(selectedRows, idToDelete: idToDelete)
        }
    }
    func deleteData(_ sender: Any) {
        let clickedRow = outlineView.clickedRow
        
        // Pastikan clickedRow valid
        guard clickedRow >= 0 else {
            return
        }
        
        var idToDelete = Set<Int64>() // Menggunakan set untuk menyimpan idGuru yang akan dihapus
        var nama = String()
        // Mendapatkan item di row yang dipilih
        if let selectedItem = outlineView.item(atRow: clickedRow) {
            if let guru = selectedItem as? GuruModel {
                // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                nama = guru.namaGuru
                idToDelete.insert(guru.idGuru)
            } else if let mapel = selectedItem as? MapelModel {
                // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                nama = mapel.namaMapel
                for guru in mapel.guruList {
                    idToDelete.insert(guru.idGuru)
                }
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Konfirmasi Penghapusan \(nama)"
        alert.informativeText = "Apakah Anda yakin akan menghapus data \(nama)?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusGuruAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        alert.showsSuppressionButton = true
        
        guard !isSuppressed else { hapusRow([clickedRow], idToDelete: idToDelete); return}
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { // Tombol "Hapus" diklik
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            self.hapusRow([clickedRow], idToDelete: idToDelete)
        }
    }
    func hapusRow(_ selectedRows: IndexSet, idToDelete: Set<Int64>) {
        var groupedDeletedData: [String: [GuruModel]] = [:]
        var mapelsToDelete: Set<MapelModel> = []
        var gurusToDelete: [(guru: GuruModel, parentMapel: MapelModel)] = []
        
        // Pertama, kumpulkan semua item yang akan dihapus
        for row in selectedRows.reversed() {
            if let selectedItem = outlineView.item(atRow: row) {
                if let mapel = selectedItem as? MapelModel {
                    mapelsToDelete.insert(mapel)
                    groupedDeletedData[mapel.namaMapel, default: []].append(contentsOf: mapel.guruList)
                } else if let guru = selectedItem as? GuruModel,
                          let parentItem = outlineView.parent(forItem: selectedItem) as? MapelModel {
                    gurusToDelete.append((guru, parentItem))
                    groupedDeletedData[parentItem.namaMapel, default: []].append(guru)
                }
            }
        }
        
        outlineView.beginUpdates()
        myUndoManager.beginUndoGrouping()
        
        // Hapus Mapel terlebih dahulu
        for mapel in mapelsToDelete {
            if let indexInMapelList = mapelList.firstIndex(where: { $0 === mapel }) {
                mapelList.remove(at: indexInMapelList)
                outlineView.removeItems(at: IndexSet(integer: indexInMapelList),
                                      inParent: nil,
                                      withAnimation: .effectFade)
            }
        }
        
        // Hapus Guru-guru individual
        for (guru, parentMapel) in gurusToDelete {
            if !mapelsToDelete.contains(parentMapel) { // Hanya hapus jika parent belum dihapus
                if let indexInGuruList = parentMapel.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                    SingletonData.deletedGuru.insert(guru.idGuru)
                    parentMapel.guruList.remove(at: indexInGuruList)
                    
                    outlineView.removeItems(at: IndexSet([indexInGuruList]),
                                          inParent: parentMapel,
                                          withAnimation: .slideDown)
                    
                    // Hapus parent mapel jika kosong
                    if parentMapel.guruList.isEmpty,
                       let indexInMapelList = mapelList.firstIndex(where: { $0 === parentMapel }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList),
                                              inParent: nil,
                                              withAnimation: .effectFade)
                    }
                }
            }
        }
        
        // Update selection setelah penghapusan
        DispatchQueue.main.async {
            if self.outlineView.numberOfRows > 0 {
                let newSelectedRow = min(selectedRows.first ?? 0, self.outlineView.numberOfRows - 1)
                self.outlineView.selectRowIndexes(IndexSet([newSelectedRow]),
                                                byExtendingSelection: false)
                self.outlineView.scrollRowToVisible(newSelectedRow)
            }
        }
        
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoHapus(groupedDeletedData: groupedDeletedData)
        }
        myUndoManager.endUndoGrouping()
        outlineView.endUpdates()
        
        deleteAllRedoArray()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUndoRedo(self)
        }
        self.confirmDelete(idsToDelete: idToDelete)
    }

//    func undoHapus(groupedDeletedData: [String: [GuruModel]]) {
//        
//        var dataGuru = groupedDeletedData
//        let sortDescriptor = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? false)
//        var newMapels: [MapelModel] = []
//        var updatedMapels: [MapelModel] = []
//        var itemIndex = IndexSet()
//        outlineView.beginUpdates()
//        for data in dataGuru.reversed() {
//            let targetMapel: MapelModel
//            let isNewMapel: Bool
//            var mapelIndex: Int!
//            if let uuidKey = UUID(uuidString: data.key),
//               let existingMapel = mapelList.first(where: { $0.id == uuidKey }) {
//                targetMapel = existingMapel
//                updatedMapels.append(targetMapel)
//                dataGuru.removeValue(forKey: data.key)
//                isNewMapel = false
//            } else {
//                // Jika tidak ditemukan, buat MapelModel baru
//                targetMapel = MapelModel(id: UUID(), namaMapel: data.key, guruList: [])
//                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
//                mapelIndex = mapelList.insertionIndex(for: targetMapel, using: sortMapel)
//                mapelList.insert(targetMapel, at: mapelIndex)
//                newMapels.append(targetMapel)
//                isNewMapel = true
//            }
//            if isNewMapel {
//                DispatchQueue.main.async {
//                    self.outlineView.insertItems(at: IndexSet(integer: mapelIndex), inParent: nil, withAnimation: .effectFade)
//                }
//            }
//
//            for guru in data.value {
//                if !targetMapel.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
//                    // Menentukan posisi insersi yang aman
//                    let insertionIndex = self.safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)
//                    targetMapel.guruList.insert(guru, at: insertionIndex)
//                    self.redoHapus.append(guru.idGuru)
//                    self.undoHapus.removeAll(where: {$0 == guru.idGuru})
//
//                    // Insert ke outlineView
//                    self.outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: targetMapel, withAnimation: .effectGap)
//                }
//                if SingletonData.deletedGuru.contains(guru.idGuru) {
//                    if let index = SingletonData.deletedGuru.firstIndex(of: guru.idGuru) {
//                        SingletonData.deletedGuru.remove(at: index)
//                    } else {
//                        
//                    }
//                } else {
//                    
//                }
//            }
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//                
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    for guru in data.value {
//                        let fullIndex = self.outlineView.row(forItem: guru)
//                        if fullIndex != -1 {
//                            itemIndex.insert(fullIndex)
//                        }
//                    }
//                    self.outlineView.selectRowIndexes(itemIndex, byExtendingSelection: false)
//                }
//            }
//        }
//        outlineView.endUpdates()
//        myUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
//            targetSelf.redoHapus(data: groupedDeletedData)
//
//        })
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
//            self.updateUndoRedo(self)
//        }
//    }

    func undoHapus(groupedDeletedData: [String: [GuruModel]]) {
        let sortDescriptor = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: true)
        var itemIndex = IndexSet()
        
        outlineView.beginUpdates()
        
        for (namaMapel, deletedGurus) in groupedDeletedData {
            let targetMapel: MapelModel
//            let isNewMapel: Bool
            var mapelIndex: Int!
            
            if let existingMapel = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                targetMapel = existingMapel
//                isNewMapel = false
            } else {
                targetMapel = MapelModel(id: UUID(), namaMapel: namaMapel, guruList: [])
                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
                mapelIndex = mapelList.insertionIndex(for: targetMapel, using: sortMapel)
                mapelList.insert(targetMapel, at: mapelIndex)
//                isNewMapel = true
                
                outlineView.insertItems(at: IndexSet(integer: mapelIndex), inParent: nil, withAnimation: .effectFade)
            }
            outlineView.expandItem(targetMapel)
            for guru in deletedGurus {
                if !targetMapel.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
                    let insertionIndex = safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)
                    targetMapel.guruList.insert(guru, at: insertionIndex)
                    redoHapus.append(guru.idGuru)
                    undoHapus.removeAll(where: { $0 == guru.idGuru })
                    
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: targetMapel, withAnimation: .effectGap)
                }
                
                if let index = SingletonData.deletedGuru.firstIndex(of: guru.idGuru) {
                    SingletonData.deletedGuru.remove(at: index)
                }
            }
        }
        
        outlineView.endUpdates()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for (_, deletedGurus) in groupedDeletedData {
                for guru in deletedGurus {
                    let fullIndex = self.outlineView.row(forItem: guru)
                    if fullIndex != -1 {
                        itemIndex.insert(fullIndex)
                    }
                }
            }
            self.outlineView.selectRowIndexes(itemIndex, byExtendingSelection: false)
            if let max = itemIndex.max() {
                self.outlineView.scrollRowToVisible(max)
            }
        }
        
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoHapus(data: groupedDeletedData)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUndoRedo(self)
        }
    }
    func redoHapus(data: [String: [GuruModel]]) {
        outlineView.beginUpdates()
        for (namaMapel, guruList) in data {
            if let parentItem = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                for guru in guruList {
                    if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                        SingletonData.deletedGuru.insert(guru.idGuru)
                        self.redoHapus.removeAll(where: {$0 == guru.idGuru})
                        self.undoHapus.append(guru.idGuru)
                        // Hapus guru dari parentItem
                        
                        parentItem.guruList.remove(at: indexInGuruList)
                        
                        // Hapus dari outlineView
                        let row = outlineView.row(forItem: guru) + 1
                        if row != -1, !outlineView.isExpandable(guru), row <= outlineView.numberOfRows {
                            outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                            outlineView.scrollRowToVisible(row)
                        } else {
                            guard row <= outlineView.numberOfRows else {
                                outlineView.scrollRowToVisible(row - 1)
                                return
                            }
                            outlineView.selectRowIndexes(IndexSet([row + 1]), byExtendingSelection: false)
                        }
                        outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .slideDown)
                        // outlineView.selectRowIndexes(IndexSet([indexInGuruList]), byExtendingSelection: false)
                    }
                }
                // Hapus mapel jika tidak ada guru yang tersisa
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoHapus(groupedDeletedData: data)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            updateUndoRedo(self)
        }
    }
    func undoTambah(data: [String: [GuruModel]]) {
        outlineView.beginUpdates()
        for (namaMapel, guruList) in data {
            if let parentItem = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                for guru in guruList {
                    if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                        SingletonData.undoAddGuru.insert(guru.idGuru)
                        self.undoHapus.removeAll(where: {$0 == guru.idGuru})
                        self.redoHapus.append(guru.idGuru)
                        // Hapus guru dari parentItem
                        
                        parentItem.guruList.remove(at: indexInGuruList)
                        
                        // Hapus dari outlineView
                        let row = outlineView.row(forItem: guru) + 1
                        if row != -1, !outlineView.isExpandable(guru), row <= outlineView.numberOfRows {
                            outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                            outlineView.scrollRowToVisible(row)
                        } else {
                            guard row <= outlineView.numberOfRows else {
                                outlineView.scrollRowToVisible(row - 1)
                                return
                            }
                            outlineView.selectRowIndexes(IndexSet([row + 1]), byExtendingSelection: false)
                        }
                        outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .slideDown)
                    }
                }
                // Hapus mapel jika tidak ada guru yang tersisa
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoTambah(groupedDeletedData: data)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            updateUndoRedo(self)
        }
    }
    func redoTambah(groupedDeletedData: [String: [GuruModel]]) {
        let sortDescriptor = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: true)
        var newMapels: [MapelModel] = []
        var updatedMapels: [MapelModel] = []
        var itemIndex = IndexSet()
        for data in groupedDeletedData.reversed() {
            let targetMapel: MapelModel
            let isNewMapel: Bool
            var mapelIndex: Int!
            if let existingMapel = mapelList.first(where: { $0.namaMapel == data.key }) {
                targetMapel = existingMapel
                updatedMapels.append(targetMapel)
                isNewMapel = false
            } else {
                targetMapel = MapelModel(id: UUID(), namaMapel: data.key, guruList: [])
                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
                mapelIndex = mapelList.insertionIndex(for: targetMapel, using: sortMapel)
                mapelList.insert(targetMapel, at: mapelIndex)
                newMapels.append(targetMapel)
                isNewMapel = true
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.outlineView.beginUpdates()
                
                if isNewMapel {
                    self.outlineView.insertItems(at: IndexSet(integer: mapelIndex), inParent: nil, withAnimation: .effectFade)
                }
                
                for guru in data.value {
                    if !targetMapel.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
                        // Menentukan posisi insersi yang aman
                        let insertionIndex = self.safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)
                        targetMapel.guruList.insert(guru, at: insertionIndex)
                        self.undoHapus.append(guru.idGuru)
                        self.redoHapus.removeAll(where: {$0 == guru.idGuru})

                        // Insert ke outlineView
                        self.outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: targetMapel, withAnimation: .effectGap)
                        self.outlineView.expandItem(targetMapel)
                    }
                    if SingletonData.undoAddGuru.contains(guru.idGuru) {
                        if let index = SingletonData.undoAddGuru.firstIndex(of: guru.idGuru) {
                            SingletonData.undoAddGuru.remove(at: index)
                        } else {
                            
                        }
                    } else {
                        
                    }
                }
                
                
                self.outlineView.endUpdates()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    for guru in data.value {
                        let fullIndex = self.outlineView.row(forItem: guru)
                        if fullIndex != -1 {
                            itemIndex.insert(fullIndex)
                        }
                    }
                    self.outlineView.selectRowIndexes(itemIndex, byExtendingSelection: false)
                    if let max = itemIndex.max() {
                        self.outlineView.scrollRowToVisible(max)
                    }
                }
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoTambah(data: groupedDeletedData)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            self.updateUndoRedo(self)
        }
    }
    // Fungsi helper untuk menentukan indeks insersi yang aman
    func safeInsertionIndex(for guru: GuruModel, in mapel: MapelModel, using sortDescriptor: NSSortDescriptor) -> Int {
        let comparator: (GuruModel, GuruModel) -> Bool
        switch sortDescriptor.key {
        case "NamaGuru":
            comparator = { sortDescriptor.ascending ? $0.namaGuru < $1.namaGuru : $0.namaGuru > $1.namaGuru }
        case "AlamatGuru":
            comparator = { sortDescriptor.ascending ? $0.alamatGuru < $1.alamatGuru : $0.alamatGuru > $1.alamatGuru }
        case "TahunAktif":
            comparator = { sortDescriptor.ascending ? $0.tahunaktif < $1.tahunaktif : $0.tahunaktif > $1.tahunaktif }
        case "Mapel":
            comparator = { sortDescriptor.ascending ? $0.mapel < $1.mapel : $0.mapel > $1.mapel }
        case "Struktural":
            comparator = { sortDescriptor.ascending ? $0.struktural < $1.struktural : $0.struktural > $1.struktural }
        default:
            comparator = { _, _ in true }
        }
        
        return mapel.guruList.firstIndex(where: { comparator(guru, $0) }) ?? mapel.guruList.count
    }
    func confirmDelete(idsToDelete: Set<Int64>) {
        SingletonData.deletedGuru.formUnion(idsToDelete)
    }
    
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
    
    var nameTextField: NSTextField!
    var addressTextField: NSTextField!
    var yearTextField: NSTextField!
    var mapelTextField: NSTextField!
    var strukturTextField: NSTextField!
    var selectedRowToEdit: [GuruModel] = []
    var kapitalkan = false {
        didSet {
            if kapitalkan {
                [nameTextField, addressTextField, mapelTextField, strukturTextField].kapitalkanSemua()
                if selectedRowToEdit.count > 1 {
                    let fields = [nameTextField, addressTextField, mapelTextField, strukturTextField]
                    fields.forEach { field in
                        field?.placeholderString = (field?.placeholderString?.capitalized ?? "")
                    }
                }
            }
        }
    }
    var hurufBesar = false {
        didSet {
            if hurufBesar {
                [nameTextField, addressTextField, mapelTextField, strukturTextField].hurufBesarSemua()
                if selectedRowToEdit.count > 1 {
                    let fields = [nameTextField, addressTextField, mapelTextField, strukturTextField]
                    fields.forEach { field in
                        field?.placeholderString = (field?.placeholderString?.uppercased() ?? "")
                    }
                }
            }
        }
    }
    
    // Properti contentView akan diinisialisasi hanya sekali saat pertama kali diakses
    lazy var contentView: NSVisualEffectView = {
        let windowWidth: CGFloat = 430
        let windowHeight: CGFloat = 290
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        view.wantsLayer = true
        // Setup layout atau subview statis yang tidak berubah di sini (jika ada)
        return view
    }()
    
    lazy var guruWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 280),
                                   styleMask: [.titled, .closable],
                                   backing: .buffered,
                                   defer: false)
    
    func createTextFieldView(_ opsi: String, guru: [GuruModel]) {
        // Cek dulu apakah subview-subview sudah pernah dibuat
        if contentView.subviews.isEmpty {
            contentView.blendingMode = .behindWindow
            contentView.material = .windowBackground
            contentView.state = .followsWindowActiveState
            // Hanya lakukan inisialisasi subview sekali saja
            let fieldNames = ["Nama Guru:", "Alamat Guru:", "Tahun Aktif:", "Mata Pelajaran:", "Sebagai:"]
            let verticalSpacing: CGFloat = 33
            let labelWidth: CGFloat = 120
            let fieldWidth: CGFloat = 260
            let startY: CGFloat = 190
            let labelStartY: CGFloat = 235
            let buttonSize: CGFloat = 24
            
            // Label Title
            let labelString = (opsi == "edit") ? "Perbarui Data Guru" : "Masukkan Informasi Guru"
            let titleLabel = NSTextField(labelWithString: labelString)
            titleLabel.font = NSFont.preferredFont(forTextStyle: .title1)
            titleLabel.frame = NSRect(x: 20, y: labelStartY, width: 350, height: 30)
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.identifier = NSUserInterfaceItemIdentifier(rawValue: "titleLabel")
            contentView.addSubview(titleLabel)
            
            // Tombol kontrol (hanya dibuat sekali)
            let kapitalButton = NSButton(image: NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(kapitalkan(_:)))
            kapitalButton.isBordered = false
            kapitalButton.bezelStyle = .smallSquare
            kapitalButton.frame = NSRect(x: 409 - buttonSize, y: labelStartY + 1, width: buttonSize, height: buttonSize)
            contentView.addSubview(kapitalButton)
            
            let uppercaseButton = NSButton(image: NSImage(systemSymbolName: "character", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(hurufBesar(_:)))
            uppercaseButton.isBordered = false
            uppercaseButton.bezelStyle = .smallSquare
            uppercaseButton.frame = NSRect(x: 390 - buttonSize, y: labelStartY + 1, width: 19, height: buttonSize)
            contentView.addSubview(uppercaseButton)
            
            // Separator
            let separator = NSBox(frame: NSRect(x: 20, y: startY + 37, width: 430 - 40, height: 1))
            separator.boxType = .separator
            contentView.addSubview(separator)
            
            // Inisialisasi TextFields dan Label untuk setiap field
            for (i, labelText) in fieldNames.enumerated() {
                let y = startY - CGFloat(i) * verticalSpacing
                let label = NSTextField(labelWithString: labelText)
                label.frame = NSRect(x: 20, y: y - 4, width: labelWidth, height: 24)
                contentView.addSubview(label)
                
                let textField = NSTextField(frame: NSRect(x: 20 + labelWidth + 10, y: y, width: fieldWidth, height: 24))
                textField.bezelStyle = .roundedBezel
                textField.lineBreakMode = .byTruncatingTail
                textField.usesSingleLineMode = true
                textField.tag = i + 1
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                textField.delegate = self
                contentView.addSubview(textField)
                
                // Simpan referensi textField pada property kelas
                switch i {
                case 0: self.nameTextField = textField
                case 1: self.addressTextField = textField
                case 2: self.yearTextField = textField
                case 3: self.mapelTextField = textField
                case 4: self.strukturTextField = textField
                default: break
                }
            }
            
            // Tombol Simpan dan Batal (juga dibuat satu kali)
            let simpanButton = NSButton(title: "Simpan", target: self, action: (opsi == "edit") ? #selector(simpanEditedGuru(_:)) : #selector(simpanGuru(_:)))
            simpanButton.frame = NSRect(x: 430 - 95, y: 15, width: 80, height: 30)
            simpanButton.bezelStyle = .rounded
            simpanButton.keyEquivalent = "\r" // enter key
            simpanButton.identifier = NSUserInterfaceItemIdentifier(rawValue: "simpan")
            contentView.addSubview(simpanButton)
            
            let batalButton = NSButton(title: "Tutup", target: self, action: #selector(closeSheets(_:)))
            batalButton.frame = NSRect(x: 430 - 175, y: 15, width: 80, height: 30)
            batalButton.bezelStyle = .rounded
            batalButton.keyEquivalent = "\u{1b}" // escape key
            contentView.addSubview(batalButton)
        } else {
            // Jika contentView sudah dibuat,
            // kamu bisa memperbarui elemen-elemen seperti titleLabel jika diperlukan
            // atau reset nilai textField dengan cara yang lebih ringan
            
            contentView.window?.makeFirstResponder(nameTextField)
            
            self.nameTextField.stringValue = ""
            self.addressTextField.stringValue = ""
            self.yearTextField.stringValue = ""
            self.mapelTextField.stringValue = ""
            self.strukturTextField.stringValue = ""
            
            
            if let simpanButton = contentView.subviews.first(where: {$0.identifier?.rawValue == "simpan"}) as? NSButton {
                simpanButton.action = (opsi == "edit") ? #selector(simpanEditedGuru(_:)) : #selector(simpanGuru(_:))
            }
            
            if let label = contentView.subviews.first(where: {$0.identifier?.rawValue == "titleLabel"}) as? NSTextField {
                label.stringValue = (opsi == "edit") ? "Edit data guru" : "Tambah data guru"
            }
        }
        
        // Update placeholder dan nilai sesuai kondisi opsi
        nameTextField.placeholderString = "ketik nama guru"
        addressTextField.placeholderString = "ketik alamat guru"
        yearTextField.placeholderString = "ketik tahun aktif"
        mapelTextField.placeholderString = "ketik mata pelajaran"
        strukturTextField.placeholderString = "ketik jabatan guru"
        
        if opsi == "edit" {
            if guru.count > 1 {
                nameTextField.placeholderString = "memuat \(guru.count) data"
                addressTextField.placeholderString = "memuat \(guru.count) data"
                yearTextField.placeholderString = "memuat \(guru.count) data"
                mapelTextField.placeholderString = "memuat \(guru.count) data"
                strukturTextField.placeholderString = "memuat \(guru.count) data"
            } else if let guruData = guru.first {
                nameTextField.stringValue = guruData.namaGuru
                addressTextField.stringValue = guruData.alamatGuru
                yearTextField.stringValue = guruData.tahunaktif
                mapelTextField.stringValue = guruData.mapel
                strukturTextField.stringValue = guruData.struktural
            }
        } else {
            nameTextField.stringValue = ""
            addressTextField.stringValue = ""
            yearTextField.stringValue = ""
            mapelTextField.stringValue = ""
            strukturTextField.stringValue = ""
        }
        
        // Buat atau update window untuk menampilkan contentView jika diperlukan
        guruWindow.center()

        guruWindow.contentView = contentView
        guruWindow.title = (opsi == "edit") ? "Edit Data Guru" : "Tambah Data Guru"
        guruWindow.makeKeyAndOrderFront(nil)
        
        // Misalnya, untuk menampilkan sebagai sheet dari window induk:
        self.view.window?.beginSheet(guruWindow, completionHandler: nil)
    }
    @objc func addSiswa(_ sender: Any) {
        createTextFieldView("add", guru: [GuruModel]())
    }
    @objc func simpanGuru(_ sender: Any) {
        var groupedDeletedData: [String: [GuruModel]] = [:]

        // User clicked "Tambah"
        // Get the input values and add a new row to the table view
        var newNamaGuru = ""
        var newAlamatGuru = ""
        let tahunAktif = ""
        var newMapel = ""
        var sebagai = ""
        
        if hurufBesar {
            newNamaGuru = nameTextField.stringValue.uppercased()
            if newNamaGuru.isEmpty {
                newNamaGuru = "GURU"
            }
            newAlamatGuru = addressTextField.stringValue.uppercased()
            newMapel = mapelTextField.stringValue.uppercased()
            sebagai = strukturTextField.stringValue.uppercased()
        } else {
            newNamaGuru = nameTextField.stringValue.capitalizedAndTrimmed()
            if newNamaGuru.isEmpty {
                newNamaGuru = "Guru"
            }
            newAlamatGuru = addressTextField.stringValue.capitalizedAndTrimmed()
            newMapel = mapelTextField.stringValue.capitalizedAndTrimmed()
            sebagai = strukturTextField.stringValue.capitalizedAndTrimmed()
        }
        
        // Add the new data to the database
        guard let id = dbController.addGuruID(namaGuruValue: newNamaGuru, alamatGuruValue: newAlamatGuru, tahunaktifValue: tahunAktif, mapelValue: newMapel, struktur: sebagai) else {return}
        let guruBaru = GuruModel(idGuru: id, nama: newNamaGuru, alamat: newAlamatGuru, tahunaktif: tahunAktif, mapel: newMapel, struktural: sebagai)
        // Cek apakah MapelModel untuk mapel baru sudah ada di mapelList
        if let parentItem = mapelList.first(where: { $0.namaMapel == newMapel }) {
            // Jika sudah ada, tambahkan guru baru ke MapelModel tersebut
            let sortDescriptor = NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
            let insertionIndex = parentItem.guruList.insertionIndex(for: guruBaru, using: sortDescriptor)

            parentItem.guruList.insert(guruBaru, at: insertionIndex)
            if groupedDeletedData[newMapel] == nil {
                groupedDeletedData[newMapel] = []
            }
            groupedDeletedData[newMapel]?.append(guruBaru)

            // Update outlineView
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                outlineView.beginUpdates()
                outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: parentItem, withAnimation: .effectGap)
                outlineView.expandItem(parentItem)  // Pastikan group row diexpand
                outlineView.endUpdates()
                // Pilih row guru yang baru ditambahkan
                let rowIndex = outlineView.row(forItem: guruBaru)
                if rowIndex != -1 && rowIndex <= outlineView.numberOfRows {
                    outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
                }
            }

        } else {
            // Jika mapel belum ada, buat MapelModel baru dan tambahkan ke mapelList
            let newMapelModel = MapelModel(id: UUID(), namaMapel: newMapel, guruList: [guruBaru])
            let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
            let insertionIndex = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)

            mapelList.insert(newMapelModel, at: insertionIndex)
            if groupedDeletedData[newMapel] == nil {
                groupedDeletedData[newMapel] = []
            }
            groupedDeletedData[newMapel]?.append(guruBaru)
            // Update outlineView dengan mapel baru dan guru
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                outlineView.beginUpdates()
                outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: nil, withAnimation: .effectGap)
                outlineView.expandItem(newMapelModel)  // Pastikan group row diexpand
                outlineView.endUpdates()
                // Pilih row guru yang baru ditambahkan
                let rowIndex = outlineView.row(forItem: guruBaru)
                if rowIndex != -1 && rowIndex <= outlineView.numberOfRows {
                    outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
                }
            }
        }
        
        let deepCopied: [String: [GuruModel]] = groupedDeletedData.mapValues { list in
            list.map { $0.copy() }
        }
        
        for (_, guru) in deepCopied {
            for i in guru {
                undoHapus.append(i.idGuru)
            }
        }
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoTambah(data: deepCopied)
        }
        updateUndoRedo(self)
        updateMenuItem(self)
        closeSheets(self)
        // Update the table view data and reload
        // guruu = dbController.getGuru()
        // outlineView.reloadData()
    }
    @objc func simpanEditedGuru(_ sender: Any) {
        guard !selectedRowToEdit.isEmpty else { return }
        outlineView.deselectAll(self)
        var oldData: [GuruModel] = []

        outlineView.beginUpdates()
        for editedGuru in selectedRowToEdit {
            let id = editedGuru.idGuru
            
            guard let parentItem = mapelList.first(where: { $0.guruList.contains(where: { $0.idGuru == id }) }) else {
                continue
            }
            
            // Mencari indeks guru dalam guruList di parentItem
            guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == id }) else {
                continue
            }
            let oldGuru = parentItem.guruList[indexInGuruList]
            oldData.append(oldGuru)
            
            let selectedGuru = parentItem.guruList[indexInGuruList]

            let updatedNamaGuru = ReusableFunc.teksFormat(nameTextField.stringValue, oldValue: oldGuru.namaGuru, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedAlamatGuru = ReusableFunc.teksFormat(addressTextField.stringValue, oldValue: oldGuru.alamatGuru, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedTahunAktif = ReusableFunc.teksFormat(yearTextField.stringValue, oldValue: oldGuru.tahunaktif, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedMapel = ReusableFunc.teksFormat(mapelTextField.stringValue, oldValue: oldGuru.mapel, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedSebagai = ReusableFunc.teksFormat(strukturTextField.stringValue, oldValue: oldGuru.struktural, hurufBesar: hurufBesar, kapital: kapitalkan)
            
            let updatedGuru = GuruModel(
                idGuru: selectedGuru.idGuru,
                nama: updatedNamaGuru,
                alamat: updatedAlamatGuru,
                tahunaktif: updatedTahunAktif,
                mapel: updatedMapel,
                struktural: updatedSebagai
            )
            
            // Update the selected data in the database
            updateDataGuru(selectedGuru.idGuru, dataLama: selectedGuru, baru: updatedGuru)
            
            if let parentItem = outlineView.parent(forItem: selectedGuru) as? MapelModel {
                if selectedGuru.mapel != updatedMapel {
                    // Jika mapel berubah, pindahkan guru ke MapelModel baru
                    let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
                    guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == selectedGuru.idGuru }) else { continue }
                    // 1. Hapus guru dari mapel lama
                    
                    // Hapus guru dari list mapel lama
                    parentItem.guruList.remove(at: indexInGuruList)
                    
                    // Hapus dari outlineView jika indeks valid
                    outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .effectFade)
                    if parentItem.guruList.isEmpty {
                        if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                            mapelList.remove(at: indexInMapelList)
                            self.outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .slideUp)
                        }
                    }
                    // 2. Cek apakah mapel baru sudah ada di mapelList
                    if mapelList.first(where: { $0.namaMapel == updatedMapel }) == nil {
                        // Buat parent baru dengan array kosong
                        let newMapelModel = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                        let insertion = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)
                        mapelList.insert(newMapelModel, at: insertion)
                        outlineView.insertItems(at: IndexSet(integer: insertion), inParent: nil, withAnimation: .effectGap)
                        outlineView.expandItem(newMapelModel)
                        
                        // Sekarang insert guru ke dalam guruList
                        let insertionIndex = newMapelModel.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                        newMapelModel.guruList.insert(updatedGuru, at: insertionIndex)
                        outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newMapelModel, withAnimation: .effectGap)
                        
                        let row = self.outlineView.row(forItem: updatedGuru)
                        #if DEBUG
                        print("insertionRow:", row)
                        #endif
                        self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                        self.outlineView.scrollRowToVisible(row)
                        continue
                    }

                    
                    if let newParentItem = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                        // Tambahkan guru ke mapel baru
                        let insertionIndex = newParentItem.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                        newParentItem.guruList.insert(updatedGuru, at: insertionIndex)
                        
                        // Update outlineView
                        self.outlineView.expandItem(newParentItem)
                        self.outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                        let row = self.outlineView.row(forItem: updatedGuru)
                        if row >= 0 {
                            self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                            self.outlineView.scrollRowToVisible(row)
                        }
                    }
                }
                else if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == selectedGuru.idGuru }) {
                    parentItem.guruList.remove(at: indexInGuruList)
                    // Tentukan posisi penyisipan untuk guru yang diperbarui
                    guard let sortDescriptor = outlineView.sortDescriptors.first else { return }
                    let insertionIndex = parentItem.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                    parentItem.guruList.insert(updatedGuru, at: insertionIndex)
                    self.outlineView.expandItem(parentItem)
                    // Pindahkan guru ke posisi baru dalam outlineView
                    if indexInGuruList < self.outlineView.numberOfChildren(ofItem: parentItem) &&
                        insertionIndex < self.outlineView.numberOfChildren(ofItem: parentItem) {
                        self.outlineView.moveItem(at: indexInGuruList, inParent: parentItem, to: insertionIndex, inParent: parentItem)
                    }
                    self.outlineView.reloadItem(selectedGuru)
                    // Pilih kembali baris yang telah diperbarui
                    let row = self.outlineView.row(forItem: updatedGuru)
                    if row >= 0 {
                        self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                        self.outlineView.scrollRowToVisible(row)
                    }
                    // Jika guruList menjadi kosong, hapus parentItem
                    if parentItem.guruList.isEmpty {
                        if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                            mapelList.remove(at: indexInMapelList)
                            if indexInMapelList < self.outlineView.numberOfRows {
                                self.outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                            }
                        }
                    }
                }
            }
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] object in
            self?.undoEdit(guru: oldData)
        })
        deleteAllRedoArray()
        updateUndoRedo(self)
        updateMenuItem(self)
        closeSheets(self)
        selectedRowToEdit.removeAll()
    }
    @objc func closeSheets(_ sender: Any) {
        view.window?.endSheet(guruWindow)
        updateUndoRedo(self)
        updateMenuItem(self)
        kapitalkan = false
        hurufBesar = false
    }
    @objc func edit(_ sender: Any) {
        selectedRowToEdit.removeAll()
        var selectedRow = IndexSet()
        /// clickedRow berada di luar baris selectedRow
        if outlineView.clickedRow != -1, !outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
            selectedRow = [outlineView.clickedRow]
            outlineView.selectRowIndexes(IndexSet([outlineView.clickedRow]), byExtendingSelection: false)
        }
        /// clickedRow berada pada baris selectedRow
        else if outlineView.clickedRow != -1, outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
            selectedRow = outlineView.selectedRowIndexes
        } else {
            selectedRow = outlineView.selectedRowIndexes
        }
        
        guard !selectedRow.isEmpty else {return}

        selectedRow.forEach { row in
            guard let item = outlineView.item(atRow: row) else { return }
            
            // Jika item merupakan MapelModel, ambil dan tambahkan semua child (misalnya: GuruModel)
            if let mapelItem = item as? MapelModel {
                let childCount = outlineView.numberOfChildren(ofItem: mapelItem)
                for childIndex in 0..<childCount {
                    if let child = outlineView.child(childIndex, ofItem: mapelItem) as? GuruModel {
                        // Tambahkan setiap child (guru) yang ditemukan
                        selectedRowToEdit.append(child)
                    }
                }
            }
            // Jika item merupakan GuruModel secara langsung, tambahkan saja
            else if let guruItem = item as? GuruModel {
                selectedRowToEdit.append(guruItem)
            }
        }
        createTextFieldView("edit", guru: selectedRowToEdit)
    }
    @objc func kapitalkan( _ sender: Any) {
        kapitalkan = true
        hurufBesar = false
    }
    @objc func hurufBesar(_ sender: Any) {
        hurufBesar = true
        kapitalkan = false
    }
    
    private func undoEdit(guru: [GuruModel]) {
        var editedID: [Int64] = []
        var editedGuru: [GuruModel] = []
        outlineView.deselectAll(self)
        
        outlineView.beginUpdates()
        for guru in guru {
            let id = guru.idGuru
            let updatedMapel = guru.mapel
            editedID.append(id)
            // Menelusuri semua item di outlineView untuk menemukan parent yang sesuai
            guard let parentItem = mapelList.first(where: { $0.guruList.contains(where: { $0.idGuru == id }) }) else {
                continue
            }
            
            // Mencari indeks guru dalam guruList di parentItem
            guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == id }) else {
                continue
            }
            
            let selectedGuru = parentItem.guruList[indexInGuruList]
            
            updateDataGuru(guru.idGuru, dataLama: selectedGuru, baru: guru)
            
            // Update data guru
            parentItem.guruList[indexInGuruList] = guru
            
            if selectedGuru.mapel != updatedMapel {
                // Jika mapel berubah, pindahkan guru ke MapelModel baru
                // Hapus guru lama dari guruList mapel lama
                let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
                parentItem.guruList.remove(at: indexInGuruList)
                outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .effectFade)
                // Jika mapel lama menjadi kosong, hapus dari mapelList
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .slideUp)
                    }
                }
                
                if mapelList.first(where: { $0.namaMapel == updatedMapel }) == nil {
                    // Buat parent baru dengan array kosong
                    let newMapelModel = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                    let insertion = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)
                    mapelList.insert(newMapelModel, at: insertion)
                    outlineView.insertItems(at: IndexSet(integer: insertion), inParent: nil, withAnimation: .effectGap)
                    outlineView.expandItem(newMapelModel)
                    
                    // Sekarang insert guru ke dalam guruList
                    let insertionIndex = newMapelModel.guruList.insertionIndex(for: guru, using: sortDescriptor)
                    newMapelModel.guruList.insert(guru, at: insertionIndex)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newMapelModel, withAnimation: .effectGap)
                    
                    let row = self.outlineView.row(forItem: guru)
                    #if DEBUG
                    print("insertionRow:", row)
                    #endif
                    self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    editedGuru.append(selectedGuru)
                    continue
                }

                
                // Cek apakah mapel baru sudah ada di mapelList
                if let newParentItem = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                    // Tambahkan guru ke MapelModel baru yang sudah ada
                    let insertionIndex = newParentItem.guruList.insertionIndex(for: guru, using: sortDescriptor)
                    newParentItem.guruList.insert(guru, at: insertionIndex)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                    self.outlineView.expandItem(newParentItem)
                    
                    let row = self.outlineView.row(forItem: guru)
                    #if DEBUG
                    print("insertionRow:", row)
                    #endif
                    self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    self.outlineView.scrollRowToVisible(row)
                }
            } else {
                let newParentItem: MapelModel
                parentItem.guruList.remove(at: indexInGuruList)
                
                // Find or create the new parent item
                if let existingMapel = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                    newParentItem = existingMapel
                } else {
                    newParentItem = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                    mapelList.append(newParentItem)
                    outlineView.insertItems(at: IndexSet(integer: mapelList.count - 1), inParent: nil, withAnimation: .effectGap)
                }
                
                // Insert the updated guru into the new parent item
                let insertionIndex = newParentItem.guruList.insertionIndex(for: guru, using: outlineView.sortDescriptors.first!)
                newParentItem.guruList.insert(guru, at: insertionIndex)
                
                outlineView.expandItem(newParentItem)
                if indexInGuruList != insertionIndex {
                    outlineView.removeItems(at: IndexSet(integer: indexInGuruList), inParent: parentItem, withAnimation: .effectFade)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                } else {
                    outlineView.reloadItem(selectedGuru)
                }
                let row = self.outlineView.row(forItem: guru)
                if row >= 0 {
                    self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    self.outlineView.scrollRowToVisible(row)
                }
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
            editedGuru.append(selectedGuru)
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self) { guru in
            guru.undoEdit(guru: editedGuru)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateUndoRedo(self)
        }
    }
    
    let kolomTabelGuru: [ColumnInfo] = [
        ColumnInfo(identifier: "NamaGuru", customTitle: "Nama Guru"),
        ColumnInfo(identifier: "AlamatGuru", customTitle: "Alamat"),
        ColumnInfo(identifier: "TahunAktif", customTitle: "Tahun Aktif"),
        ColumnInfo(identifier: "Mapel", customTitle: "Mata Pelajaran"),
        ColumnInfo(identifier: "Struktural", customTitle: "Sebagai")
    ]
    func loadExpandedItems() {
        if let expandedMapelNames = UserDefaults.standard.array(forKey: "expandedGuruItems") as? [String] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [unowned self] in
                outlineView.beginUpdates()
                expandedMapelNames.forEach { namaMapel in
                    if let mapelToExpand = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                        outlineView.animator().expandItem(mapelToExpand, expandChildren: false)
                    }
                }
                outlineView.endUpdates()
            }
        }
    }

    func saveExpandedItems() {
        // Simpan nama `mapel` yang saat ini di-expand
        let expandedMapelNames = mapelList.compactMap { mapel -> String? in
            return outlineView.isItemExpanded(mapel) ? mapel.namaMapel : nil
        }
        UserDefaults.standard.set(expandedMapelNames, forKey: "expandedGuruItems")
    }
    
    func outlineViewColumnDidMove(_ notification: Notification) {
        ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // Ambil sort descriptor pertama atau gunakan default
        let indicator = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            sortModel(by: indicator)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.outlineView.reloadData()
                self.loadExpandedItems()
            }
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        if columnIndex == 0 {
            outlineView.setNeedsDisplay(outlineView.rect(ofColumn: columnIndex))
            return false
        }
        
        if newColumnIndex == 0 {
            outlineView.setNeedsDisplay(outlineView.rect(ofColumn: columnIndex))
            return false
        }
        
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        if let mapel = item as? MapelModel {
            return mapel.namaMapel
        } else if let guru = item as? GuruModel {
            return guru.namaGuru
        }
        return nil
    }
    
    private func sortModel(by sortDescriptor: NSSortDescriptor) {
        let indicator = sortDescriptor
        mapelList.sort { (mapel1, mapel2) -> Bool in
            switch indicator.key {
            case "NamaGuru": // Ganti dengan kunci yang sesuai untuk MapelModel
                return indicator.ascending ? mapel1.namaMapel < mapel2.namaMapel : mapel1.namaMapel > mapel2.namaMapel
            default:
                return true // Jika tidak ada kunci yang cocok, tidak ada pengurutan
            }
        }

        // Sortir child (GuruModel) untuk setiap parent (MapelModel)
        for mapel in mapelList { // Gantilah dengan list yang berisi item parent
            mapel.guruList.sort { (guru1, guru2) -> Bool in
                switch indicator.key {
                case "NamaGuru":
                    return indicator.ascending ? guru1.namaGuru < guru2.namaGuru : guru1.namaGuru > guru2.namaGuru
                case "AlamatGuru":
                    return indicator.ascending ? guru1.alamatGuru < guru2.alamatGuru : guru1.alamatGuru > guru2.alamatGuru
                case "TahunAktif":
                    return indicator.ascending ? guru1.tahunaktif < guru2.tahunaktif : guru1.tahunaktif > guru2.tahunaktif
//                case "Mapel":
//                    return indicator.ascending ? guru1.mapel < guru2.mapel : guru1.mapel > guru2.mapel
                case "Struktural":
                    return indicator.ascending ? guru1.struktural < guru2.struktural : guru1.struktural > guru2.struktural
                default:
                    return true // Jika tidak ada kunci yang cocok, tidak ada pengurutan
                }
            }
        }
        sortDescriptors = sortDescriptor
    }
    @objc func outlineViewDoubleClick(_ sender: Any) {
        guard outlineView.selectedRow >= 0 else { return }
        editorMager?.startEditing(row: outlineView.clickedRow, column: outlineView.clickedColumn)
    }
    func setupSortDescriptor() {
        let nama = NSSortDescriptor(key: "NamaGuru", ascending: false)
        let alamat = NSSortDescriptor(key: "AlamatGuru", ascending: false)
        let tahunaktif = NSSortDescriptor(key: "TahunAktif", ascending: false)
        let mapel = NSSortDescriptor(key: "Mapel", ascending: false)
        let posisi = NSSortDescriptor(key: "Struktural", ascending: false)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("NamaGuru"): nama,
            NSUserInterfaceItemIdentifier("AlamatGuru"): alamat,
            NSUserInterfaceItemIdentifier("TahunAktif"): tahunaktif,
            NSUserInterfaceItemIdentifier("Mapel"): mapel,
            NSUserInterfaceItemIdentifier("Struktural"): posisi
        ]
        for kolom in outlineView.tableColumns {
            let identifikasi = kolom.identifier
            let tukangIdentifikasi = identifikasiKolom[identifikasi]
            kolom.sortDescriptorPrototype = tukangIdentifikasi
        }
    }
    func search(_ searchText: String) {
        if searchText == stringPencarian {return}
        stringPencarian = searchText
        Task { [unowned self] in
            mapelList.removeAll()
            guruu = await self.dbController.searchGuru(query: searchText)
            var mapelDict: [String: [GuruModel]] = [:]
            
            for guru in guruu {
                if mapelDict[guru.mapel] == nil {
                    mapelDict[guru.mapel] = [GuruModel]()
                }
                mapelDict[guru.mapel]?.append(guru)
            }
            
            // Membuat list MapelModel dari dictionary
            for (mapel, guruList) in mapelDict {
                let mapelModel = MapelModel(id: UUID(), namaMapel: mapel, guruList: guruList)
                mapelList.append(mapelModel)
            }
            await MainActor.run { [unowned self] in
                let indicator = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
                sortModel(by: indicator)
                outlineView.reloadData()
                outlineView.expandItem(nil, expandChildren: true)
            }
        }
    }
    var searchWork: DispatchWorkItem?
    @objc func procSearchFieldInput (sender:NSSearchField) {
        searchWork?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.search(sender.stringValue)
            self?.stringPencarian = sender.stringValue
        }
        searchWork = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchWork!)
    }
    deinit {
        searchWork?.cancel()
        searchWork = nil
        saveRowHeight()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editButtonClicked, object: nil)
        NotificationCenter.default.removeObserver(self, name: .deleteButtonClicked, object: nil)
    }
}

extension GuruViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let mapel = item as? MapelModel {
            
            return mapel.guruList.count // Jumlah guru dalam mapel
        }
        return mapelList.count // Jumlah mapel jika item adalah nil
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let mapel = item as? MapelModel {
            
            return mapel.guruList[index] // Kembalikan guru dari mapel tersebut
        }
        
        return mapelList[index] // Kembalikan mapel jika item adalah nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "GuruCell"), owner: self) as? NSTableCellView else {
            return nil
        }
        func applyCommonConstraints(to textField: NSTextField, in cell: NSTableCellView, isNamaGuru: Bool) {
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            var leadingConstant: CGFloat = isNamaGuru ? 0 : 5
            var trailingConstant: CGFloat = isNamaGuru ? -5 : -20
            if item is MapelModel && isNamaGuru {
                leadingConstant = 5
                trailingConstant = -20
            }

            // Memperbarui constraint yang sudah ada untuk mencegah duplikasi
            cell.constraints.forEach { constraint in
                if constraint.firstAnchor == textField.leadingAnchor {
                    cell.removeConstraint(constraint)
                }
                if constraint.firstAnchor == textField.trailingAnchor {
                    cell.removeConstraint(constraint)
                }
            }

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: trailingConstant),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }


        guard let textField = cell.textField else {return cell}
        let isNamaGuru = tableColumn?.identifier.rawValue == "NamaGuru"
        applyCommonConstraints(to: textField, in: cell, isNamaGuru: isNamaGuru)
        if let mapel = item as? MapelModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = mapel.namaMapel
                if mapel.namaMapel.isEmpty {
                    cell.textField?.stringValue = "-"
                }
            } else {
                textField.stringValue = ""
            }
        } else if let guru = item as? GuruModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = guru.namaGuru
            } else if tableColumn?.identifier.rawValue == "AlamatGuru" {
                textField.stringValue = guru.alamatGuru
            } else if tableColumn?.identifier.rawValue == "TahunAktif" {
                textField.stringValue = String(guru.tahunaktif)
            } else if tableColumn?.identifier.rawValue == "Struktural" {
                textField.stringValue = guru.struktural
            }
        }
        if tableColumn?.identifier.rawValue == "Mapel" {
            tableColumn?.isHidden = true
        }
        return cell
    }

    
    
    func outlineView(_ outlineView: NSOutlineView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, item: Any, mouseLocation: NSPoint) -> String {
        guard let tableColumn = tableColumn else { return "" }
        
        if let mapel = item as? MapelModel {
            switch tableColumn.identifier.rawValue {
            case "NamaGuru":
                return "Mata Pelajaran: \(mapel.namaMapel)"
            default:
                return ""
            }
        } else if let guru = item as? GuruModel {
            switch tableColumn.identifier.rawValue {
            case "NamaGuru":
                return guru.namaGuru
            case "AlamatGuru":
                return guru.alamatGuru
            case "TahunAktif":
                return guru.tahunaktif
            case "Struktural":
                return guru.struktural
            default:
                return ""
            }
        }
        return ""
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is MapelModel // Mapel dapat diperluas, guru tidak
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let toolbar = self.view.window?.toolbar else { return }
        guard let outlineView = notification.object as? NSOutlineView else { return }
        
        // Dapatkan indeks item yang dipilih
        selectedIndex = outlineView.selectedRow
        // Cek apakah ada item yang dipilih
        let isItemSelected = selectedIndex != -1
        // Dapatkan toolbar item yang ingin Anda atur
        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton {
            if isItemSelected {
            hapus.isEnabled = true
            hapus.target = self
            hapus.action = #selector(hapusSerentak(_:))
            } else {
                hapus.isEnabled = false
            }
        }
        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton {
            if isItemSelected {
                edit.isEnabled = true
            } else {
                // Jika tidak ada item yang dipilih, nonaktifkan tombol edit
                edit.isEnabled = false
            }
        }
        NSApp.sendAction(#selector(GuruViewController.updateMenuItem(_:)), to: nil, from: self)
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        saveExpandedItems()
    }
    func outlineViewItemDidCollapse(_ notification: Notification) {
        saveExpandedItems()
    }
        
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return outlineView.rowHeight
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        return false
    }
}
extension GuruViewController: NSMenuDelegate {
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let outlineView = outlineView else {
            return
        }
        
        let clickedRow = outlineView.clickedRow
        
        if clickedRow != -1 {
            // Dapatkan item yang diklik
            guard let clickedItem = outlineView.item(atRow: clickedRow) else {
                return
            }
            // Periksa apakah item yang diklik adalah item level teratas (parent)
            if let parentItem = outlineView.parent(forItem: clickedItem), parentItem is NSTreeNode {
                // Jika item memiliki parent, ini bukan item level teratas
                return
            }
            // Jika sampai di sini, berarti item yang diklik adalah item level teratas (parent)
            if outlineView.selectedRowIndexes.contains(clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, panggil fungsi deleteDataClicked
                hapusSerentak(sender)
            } else {
                deleteData(sender)
            }
        } else {
            guard outlineView.numberOfSelectedRows >= 1 else {return}
            hapusSerentak(sender)
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menu)
        }
        view.window?.makeFirstResponder(outlineView)
    }

    @objc func salinData(_ sender: NSMenuItem) {
        let selectedRows = outlineView.selectedRowIndexes
        guard let rows = sender.representedObject as? IndexSet else {
            salinBaris(selectedRows, outlineView: outlineView)
            return
        }
        let clickedRow = outlineView.clickedRow
        
        if rows.contains(clickedRow) && clickedRow >= 0 {
            salinBaris(selectedRows, outlineView: outlineView)
        } else if !rows.contains(clickedRow) && clickedRow >= 0 {
            salinBaris(IndexSet([clickedRow]), outlineView: outlineView)
        } else {
            salinBaris(selectedRows, outlineView: outlineView)
        }
    }
    func salinBaris(_ rows: IndexSet, outlineView: NSOutlineView) {
        // Array untuk menyimpan semua data baris
        var allRowData: [String] = []

        // Iterasi melalui semua baris yang dipilih
        for row in rows {
            // Ambil item dari baris saat ini
            guard let item = outlineView.item(atRow: row) else {
                continue // Lewati jika item tidak ditemukan
            }

            // Simpan data untuk baris ini
            var rowData: [String] = []

            // Iterasi melalui semua kolom di NSOutlineView
            for column in outlineView.tableColumns {
                let identifier = column.identifier.rawValue

                if let mapel = item as? MapelModel {
                    if identifier == "NamaGuru" {
                        rowData.append(mapel.namaMapel.isEmpty ? "-" : mapel.namaMapel)
                    } else {
                        rowData.append("") // Kolom yang tidak sesuai dengan MapelModel
                    }
                } else if let guru = item as? GuruModel {
                    if identifier == "NamaGuru" {
                        rowData.append("\(guru.namaGuru)\t\(guru.mapel)")
                    } else if identifier == "AlamatGuru" {
                        rowData.append(guru.alamatGuru)
                    } else if identifier == "TahunAktif" {
                        rowData.append(String(guru.tahunaktif))
                    } else if identifier == "Struktural" {
                        rowData.append(guru.struktural)
                    } else {
                        rowData.append("") // Kolom yang tidak sesuai dengan GuruModel
                    }
                }
            }

            // Gabungkan data baris saat ini menjadi satu string
            let rowString = rowData.joined(separator: "\t")
            allRowData.append(rowString)
        }

        // Gabungkan semua data baris menjadi satu string dengan baris baru
        let allDataString = allRowData.joined(separator: "\n")

        // Salin semua data ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(allDataString, forType: .string)
    }

    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: {$0.identifier?.rawValue == "copy"}),
           let deleteMenuItem = editMenu.items.first(where: {$0.identifier?.rawValue == "hapus"}),
           let fileMenu = mainMenu.item(withTitle: "File"),
           let fileMenuItem = fileMenu.submenu,
           let new = fileMenuItem.items.first(where: {$0.identifier?.rawValue == "new"}) {
            let adaBarisDipilih = outlineView.selectedRowIndexes.count > 0
            deleteMenuItem.isEnabled = adaBarisDipilih
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinData(_:))
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(hapusSerentak(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
            }
            new.target = self
            new.action = #selector(addSiswa(_:))
        }
    }
}
extension GuruViewController: NSTextFieldDelegate  {
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        ReusableFunc.resetMenuItems()
        if let textField = obj.object as? NSTextField, !(textField.superview is NSTableCellView) {
            activeText = textField
            switch textField.tag {
            case 1:  // Nama Guru
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.namaguru)
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
                
            case 2:  // Alamat Guru
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.alamat)
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 3:  // Tahun Aktif
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.ttl)
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 4:  // Mata Pelajaran
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.mapel)
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
             case 5:  // Sebagai (Struktur)
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.jabatan)
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            default:
                break
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            let currentText = activeTextField.stringValue
            
            // Find the last word (after the last space)
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])
                
                // Update the text field with only the last word
                suggestionManager.typing = lastWord
                
            } else {
                suggestionManager.typing = activeText.stringValue
            }
            if activeText?.stringValue.isEmpty == true {
                suggestionManager.hideSuggestions()
            } else {
                suggestionManager.controlTextDidChange(obj)
            }
        }
        if let searchField = obj.object as? NSSearchField {
            searchWork?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.search(searchField.stringValue)
            }
            searchWork = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchWork!)
        }
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
        if obj.object is NSSearchField {
            updateUndoRedo(self)
            return
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return false}
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.moveUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.moveDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            if control is NSSearchField {
                return true
            }
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.enterSuggestions()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.hideSuggestions()
            return true
        case #selector(NSResponder.insertTab(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.hideSuggestions()
            return false
        default:
            return false
        }
    }
    func updateDataGuru(_ id: Int64, dataLama: GuruModel, baru: GuruModel) {
        if dataLama.namaGuru != baru.namaGuru {
            dbController.updateKolomGuru(id, kolom: "Nama", baru: baru.namaGuru)
        }
        if dataLama.alamatGuru != baru.alamatGuru {
            dbController.updateKolomGuru(id, kolom: "Alamat", baru: baru.alamatGuru) // <- fix
        }
        if dataLama.tahunaktif != baru.tahunaktif {
            dbController.updateKolomGuru(id, kolom: "Tahun Aktif", baru: baru.tahunaktif) // <- fix
        }
        if dataLama.mapel != baru.mapel {
            dbController.updateKolomGuru(id, kolom: "Mata Pelajaran", baru: baru.mapel) // <- fix
        }
        if dataLama.struktural != baru.struktural {
            dbController.updateKolomGuru(id, kolom: "Jabatan", baru: baru.struktural) // <- fix
        }
    }

    @objc func beralihWarnaAlternatif() {
        warnaAlternatif.toggle()
        if warnaAlternatif {
            outlineView.usesAlternatingRowBackgroundColors = true
        } else {
            outlineView.usesAlternatingRowBackgroundColors = false
        }
        if let menu = outlineView.menu,
           let beralihWarna = menu.item(withTitle: "Gunakan Warna Alternatif") {
            beralihWarna.state = warnaAlternatif ? .on : .off
        }
        outlineView.reloadData()
    }
}


extension GuruViewController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        if row >= 0, let item = outlineView.item(atRow: row) as? GuruModel,
           let parentItem = outlineView.parent(forItem: item) as? MapelModel,
           let indexInGuruList = parentItem.guruList.firstIndex(where: {$0.idGuru == item.idGuru}) {
            let oldGuru = item.copy()
            #if DEBUG
            print("oldGuru", oldGuru.alamatGuru)
            #endif
            let columnIdentifier = outlineView.tableColumns[column].identifier.rawValue
            
            switch columnIdentifier {
            case "NamaGuru": item.namaGuru = newText
            case "AlamatGuru": item.alamatGuru = newText
            case "TahunAktif": item.tahunaktif = newText
            case "Struktural": item.struktural = newText
            default:
                break
            }

            updateDataGuru(item.idGuru, dataLama: oldGuru, baru: item)
            parentItem.guruList.remove(at: indexInGuruList)
            // Tentukan posisi penyisipan untuk guru yang diperbarui
            guard let sortDescriptor = outlineView.sortDescriptors.first else { return }
            let insertionIndex = parentItem.guruList.insertionIndex(for: item, using: sortDescriptor)
            parentItem.guruList.insert(item, at: insertionIndex)
            if indexInGuruList != insertionIndex {
                outlineView.moveItem(at: indexInGuruList, inParent: parentItem, to: insertionIndex, inParent: parentItem)
            }
            myUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.undoEdit(guru: [oldGuru])
            })
            deleteAllRedoArray()
        }
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        if row >= 0, let item = outlineView.item(atRow: row) as? GuruModel,
           outlineView.parent(forItem: item) is MapelModel {
            return true
        } else {
            return false
        }
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let cell = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else { return "return" }
        return cell.textField?.stringValue ?? ""
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        return outlineView.tableColumns[column].width
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = outlineView.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "NamaGuru":  // Nama Guru
            return Array(ReusableFunc.namaguru)
        case "AlamatGuru":  // Alamat Guru
            return Array(ReusableFunc.alamat)
        case "TahunAktif":
            return Array(ReusableFunc.mapel)
        case "Mapel":
            return Array(ReusableFunc.mapel)
         case "Struktural":  // Sebagai (Struktur)
            return Array(ReusableFunc.jabatan)
        default:
            return []
        }
    }
}
