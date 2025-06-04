//
//  Sidebar.swift
//  Data Manager
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa

protocol SidebarDelegate: AnyObject {
    func didSelectSidebarItem(index: Int)
    func didSelectKelasItem(index: Int)
}

protocol KelasVCDelegate: AnyObject {
    func didUpdateTable(_ index: Int)
    func didCompleteUpdate()
}

class SidebarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, KelasVCDelegate {
    var selectedSidebarItem: SidebarItem?
    weak var delegate: SidebarDelegate?
    @IBOutlet weak var outlineView: EditableOutlineView!
    var sidebarItems: [Any] = []
    var windowIdentifier: String?
    var selectedOutlineItemIndex: Int = 11 {
        didSet {
            UserDefaults.standard.set(selectedOutlineItemIndex, forKey: "SelectedOutlineItemIndex")
        }
    }
    
    let ringkasanGuru = UserDefaults.standard.string(forKey: "sidebarRingkasanGuru")
    let ringkasanSiswa = UserDefaults.standard.string(forKey: "sidebarRingkasanSiswa")
    let ringkasanKelas = UserDefaults.standard.string(forKey: "sidebarRingkasanKelas")
    var editorManager: OverlayEditorManager?
    
    @IBOutlet weak var outlineMenu: NSMenu!
    private lazy var isExpanding = false
    private lazy var shouldUpdateDelegate = true
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.floatsGroupRows = false
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        
        // MARK: - Grup Transaksi (prefix: "transaksi")
        let transaksiItem = SidebarItem(name: "Transaksi", identifier: "transaksiTransaksi", image: NSImage(named: "catatan"))
        let pengeluaranItem = SidebarItem(name: "Pengeluaran", identifier: "transaksiPengeluaran", image: NSImage(named: "uangkeluar"))
        let pemasukanItem = SidebarItem(name: "Pemasukan", identifier: "transaksiPemasukan", image: NSImage(named: "uangmasuk"))
        let lainnyaItem = SidebarItem(name: "Lainnya", identifier: "transaksiLainnya", image: NSImage(named: "lainnya"))
        let saldoItem = SidebarItem(name: "Saldo", identifier: "transaksiSaldo", image: NSImage(named: "saldo"))
        let transaksiGroup = AdministrasiParentItem(name: NameConstants.transaksi, children: [transaksiItem, pengeluaranItem, pemasukanItem, lainnyaItem, saldoItem])
        sidebarItems.append(transaksiGroup)

        // MARK: - Grup Daftar (prefix: "daftar")
        let guruItem = SidebarItem(name: "Guru", identifier: "daftarGuru", image: NSImage(named: "guru"))
        let siswaItem = SidebarItem(name: "Siswa", identifier: "daftarSiswa", image: NSImage(named: "siswa"))
        let inventarisItem = SidebarItem(name: "Inventaris", identifier: "daftarInventaris", image: NSImage(named: "pensil"))
        let daftarGroup = DaftarParentItem(name: NameConstants.daftar, children: [guruItem, siswaItem, inventarisItem])
        sidebarItems.append(daftarGroup)

        // MARK: - Grup Ringkasan (prefix: "ringkasan")
        let statistikImage = NSImage(systemSymbolName: "chart.pie.fill", accessibilityDescription: nil)!
        let statistikItem = SidebarItem(name: ringkasanKelas ?? "Kelas", identifier: "ringkasanKelas", image: statistikImage.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration))
        let jumlahsiswaItem = SidebarItem(name: ringkasanSiswa ?? "Siswa", identifier: "ringkasanSiswa", image: NSImage(named: "siswa"))
        let struktur = SidebarItem(name: ringkasanGuru ?? "Guru", identifier: "ringkasanGuru", image: NSImage(named: "guru"))
        let statistikGroup = StatistikParentItem(name: "Ringkasan", children: [statistikItem, jumlahsiswaItem, struktur])
        sidebarItems.append(statistikGroup)

        // MARK: - Grup Kelas (prefix: "kelas")
        let kelas1Item = SidebarItem(name: "Kelas 1", identifier: "kelasAktif1", image: NSImage(named: "Kelas 1"))
        let kelas2Item = SidebarItem(name: "Kelas 2", identifier: "kelasAktif2", image: NSImage(named: "Kelas 2"))
        let kelas3Item = SidebarItem(name: "Kelas 3", identifier: "kelasAktif3", image: NSImage(named: "Kelas 3"))
        let kelas4Item = SidebarItem(name: "Kelas 4", identifier: "kelasAktif4", image: NSImage(named: "Kelas 4"))
        let kelas5Item = SidebarItem(name: "Kelas 5", identifier: "kelasAktif5", image: NSImage(named: "Kelas 5"))
        let kelas6Item = SidebarItem(name: "Kelas 6", identifier: "kelasAktif6", image: NSImage(named: "Kelas 6"))

        // menyiapkan grup "Kelas" dan menambahkan kelas1-6 ke grup tersebut
        let kelasGroup = KelasParentItem(name: NameConstants.kelas, children: [kelas1Item, kelas2Item, kelas3Item, kelas4Item, kelas5Item, kelas6Item])
        sidebarItems.append(kelasGroup)
        outlineView.reloadData()
        outlineView.refusesFirstResponder = true
        outlineView.wantsLayer = true
        
        outlineView.menu = outlineMenu
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveExpandedItems()
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        if UserDefaults.standard.object(forKey: "expandedItems") == nil {
            sidebarItems.forEach {
                outlineView.expandItem($0)
            }
            UserDefaults.standard.set(true, forKey: "expandedItems")
        }
    }
    private var isUserInteractionEnabled = false
    override func viewDidAppear() {
        super.viewDidAppear()
        shouldUpdateDelegate = false
        loadExpandedItems()
        
        outlineMenu.delegate = self
        if let selfWindow = self.view.window {
            editorManager = OverlayEditorManager(tableView: outlineView, containingWindow: selfWindow)
            outlineView.editAction = { [weak self] (row, column) in
                guard let self = self else { return }
                self.editorManager?.startEditing(row: row, column: column)
            }
            editorManager?.delegate = self
            editorManager?.dataSource = self
        }
        
        //selectedOutlineItemIndex = UserDefaults.standard.integer(forKey: "SelectedOutlineItemIndex")
        guard outlineView.selectedRow == -1 else {
            isUserInteractionEnabled = true
            shouldUpdateDelegate = true
            return
        }
        outlineView.selectRowIndexes(IndexSet(integer: UserDefaults.standard.integer(forKey: "SelectedOutlineItemIndex")), byExtendingSelection: false)
        isUserInteractionEnabled = true
        shouldUpdateDelegate = true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedIndex = outlineView.selectedRow
        
        // Memastikan pemilihan tidak kosong
        guard selectedIndex != -1 else { return }
        
        selectedSidebarItem = outlineView.item(atRow: selectedIndex) as? SidebarItem
        
        if !isExpanding && shouldUpdateDelegate {
            if let selectedItem = selectedSidebarItem {
                if let indexToOpen = indexToOpenForSidebarItem(selectedItem) {
                    delegate?.didSelectSidebarItem(index: indexToOpen)
                    UserDefaults.standard.set(selectedIndex, forKey: "SelectedOutlineItemIndex")
                }
            }
        }
    }
    @objc func selectClass(_ notification: Notification) {
        guard let updatedClass = notification.userInfo?["updatedClass"] as? Int else {return}
        DispatchQueue.main.async { [unowned self] in
            outlineView.selectRowIndexes(IndexSet(integer: updatedClass), byExtendingSelection: false)
        }
        UserDefaults.standard.set(updatedClass, forKey: "SelectedOutlineItemIndex")
    }
    // MARK: - NSOutlineViewDataSource
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let parentItem = item as? SidebarGroup {
            return parentItem.children[index]
        }
        return sidebarItems[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let group = item as? SidebarGroup {
            return !group.children.isEmpty
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let group = item as? SidebarGroup {
            return group.children.count
        }
        return sidebarItems.count
    }
    
    // MARK: NSOutlineViewDelegate
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let groupNode = item as? SidebarGroup {
            // Jika item adalah grup, gunakan sel dengan identifier "GroupCell"
            if let cell = self.outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = groupNode.name
                cell.textField?.font = NSFont.systemFont(ofSize: 11, weight: .black)
                // Lakukan penyesuaian tambahan sesuai kebutuhan untuk sel grup
                return cell
            }
        } else if let dataNode = item as? SidebarItem {
            // Jika item adalah data, gunakan sel dengan identifier "DataCell"
            if let cell = self.outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DataCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = dataNode.name
                cell.textField?.delegate = self
                cell.textField?.isEditable = false
                cell.imageView?.image = dataNode.image // Tambahkan gambar ke sel
                return cell
            }
        }
        return nil
    }
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is SidebarGroup
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return !(item is SidebarGroup) // Anda mungkin ingin menyesuaikan kondisi ini sesuai kebutuhan
    }
    func saveExpandedItems() {
        let expandedItems = sidebarItems.enumerated().compactMap { (index, item) -> Int? in
            if outlineView.isItemExpanded(item) {
                return index
            }
            return nil
        }
        
        UserDefaults.standard.set(expandedItems, forKey: "expandedItems")
    }
    func loadExpandedItems() {
        if let expandedItems = UserDefaults.standard.array(forKey: "expandedItems") as? [Int] {
            expandedItems.forEach { index in
                if index < sidebarItems.count {
                    outlineView.expandItem(sidebarItems[index])
                }
            }
        }
    }
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        
        isExpanding = true
        
        // Memastikan pemilihan tidak kosong
        if outlineView.selectedRow == -1, let lastSelectedItem = selectedSidebarItem {
            let rowIndex = outlineView.row(forItem: lastSelectedItem)
            outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
        }
        
        isExpanding = false
    }
//    func updateSelection(withoutDelegateCall: Bool) {
//        shouldUpdateDelegate = !withoutDelegateCall
//        // Trigger pemilihan ulang
//        if let outlineView = view as? NSOutlineView, let selectedItem = selectedSidebarItem {
//            let rowIndex = outlineView.row(forItem: selectedItem)
//            outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
//        }
//        shouldUpdateDelegate = true
//    }
    func didUpdateTable(_ index: Int) {
        
        
        guard index != outlineView.selectedRow else {return}
        DispatchQueue.main.async { [unowned self] in
            outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        UserDefaults.standard.set(index, forKey: "SelectedOutlineItemIndex")
    }
    
    // MARK: Properties
    func didCompleteUpdate() {
        // Tangani penyelesaian pembaruan di sini
        
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedOutlineItemIndex": 11])
        selectedOutlineItemIndex = UserDefaults.standard.integer(forKey: "SelectedOutlineItemIndex")
        
        super.init(nibName: "Sidebar", bundle: nil)
    }
    required init?(coder: NSCoder) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedOutlineItemIndex": 11])
        selectedOutlineItemIndex = UserDefaults.standard.integer(forKey: "SelectedOutlineItemIndex")
        super.init(coder: coder)
    }
    private func indexToOpenForSidebarItem(_ sidebarItem: SidebarItem) -> Int? {
        switch sidebarItem.identifier {
        case "daftarSiswa":
            return 1
        case "daftarGuru":
            return 2
        case let kelasName where kelasName.hasPrefix("kelasAktif"):
            // Extract the number from "Kelas X" and convert it to Int
            if let index = Int(kelasName.replacingOccurrences(of: "kelasAktif", with: "")) {
                return index + 2 // Offset untuk siswa dan guru
            }
        case "ringkasanKelas":
            return 14
        case "transaksiTransaksi":
            return 9
        case "transaksiPemasukan":
            return 10
        case "transaksiPengeluaran":
            return 11
        case "transaksiLainnya":
            return 12
        case "transaksiSaldo":
            return 13
        case "ringkasanSiswa":
            return 15
        case "ringkasanGuru":
            return 16
        case "daftarInventaris":
            return 17
        default:
            return nil
        }
        return nil
    }
    
    @IBAction func bantuanApl(_ sender: Any) {
        guard let mainMenu = NSApp.mainMenu,
              let menuItem = mainMenu.items.first(where: {
                $0.identifier?.rawValue == "bantuan" }),
              let menu = menuItem.submenu,
              let preferensiMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "tampilkanBantuan" })
        else {return}
        NSApp.sendAction(preferensiMenuItem.action!, to: preferensiMenuItem.target, from: self)
    }
    
//    @objc func openOnNewTab(_ sender: Any) {
//        let clickedRow = outlineView.clickedRow
//        UserDefaults.standard.set(clickedRow, forKey: "SelectedOutlineItemIndex")
//        guard clickedRow >= 0 && clickedRow < outlineView.numberOfRows,
//              let selectedSidebarItem = outlineView.item(atRow: clickedRow) as? SidebarItem,
//              let indexToOpen = indexToOpenForSidebarItem(selectedSidebarItem) else {
//            return
//        }
//
//        UserDefaults.standard.set(indexToOpen, forKey: "SelectedSidebarItemIndex")
//        saveExpandedItems()
//        self.view.window?.newWindowForTab(sender)
//    }
//    @objc func openNewTab(_ sender: Any) {
//        saveExpandedItems()
//        self.view.window?.newWindowForTab(sender)
//    }
//    @objc func openInNewWindow(_ sender: Any) {
//        UserDefaults.standard.set(outlineView.clickedRow, forKey: "SelectedOutlineItemIndex")
//        guard let outlineView = outlineView else {
//            return
//        }
//        saveExpandedItems()
//        let clickedRow = outlineView.clickedRow
//
//        guard clickedRow >= 0 && clickedRow < outlineView.numberOfRows else {
//            return
//        }
//
//        guard let selectedItem = outlineView.item(atRow: clickedRow) as? SidebarItem else {
//            return
//        }
//
//        guard let indexToOpen = indexToOpenForSidebarItem(selectedItem) else {
//            return
//        }
//        if let mainMenu = NSApp.mainMenu {
//            if let menuItem = AppDelegate.shared.findMenuItem(in: mainMenu, withIdentifier: "halamanawal") {
//                // Perform the action and add additional logging
//
//
//                // Capture the current run loop
//                DispatchQueue.main.async {
//                    // Send action with additional debugging
//                    _ = NSApp.sendAction(menuItem.action!, to: menuItem.target, from: menuItem)
//
//
//                    // Additional diagnostic information
//                    if let windowController = NSApp.keyWindow?.windowController as? WindowController {
//                        if let windowFrameData = UserDefaults.standard.data(forKey: "WindowFrame"),
//                           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData) {
//
//                            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
//                            var frame = windowFrame.rectValue
//
//                            // Menggeser posisi window ke kiri dan ke bawah sejauh 20 piksel
//                            frame.origin.x += 20
//                            frame.origin.y -= 20
//
//                            windowController.window?.setFrame(frame, display: true)
//                            // Manually trigger layout update
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                                if let splitVC = windowController.contentViewController as? SplitVC {
//                                    splitVC.didSelectSidebarItem(index: indexToOpen)
//                                    splitVC.setWindowIdentifier(windowController.windowIdentifier)
//                                    splitVC.resetDelegates()
//                                }
//                            }
//                        }
//                    }
//                }
//            } else {
//
//            }
//        }
//    }
//    @objc func openMainWindow(_ sender: Any) {
//        if let mainMenu = NSApp.mainMenu {
//            if let menuItem = AppDelegate.shared.findMenuItem(in: mainMenu, withIdentifier: "halamanawal") {
//                // Perform the action and add additional logging
//
//
//                // Capture the current run loop
//                DispatchQueue.main.async {
//                    // Send action with additional debugging
//                    _ = NSApp.sendAction(menuItem.action!, to: menuItem.target, from: menuItem)
//
//
//                    // Additional diagnostic information
//                    if let windowController = NSApp.keyWindow?.windowController as? WindowController {
//                        if let windowFrameData = UserDefaults.standard.data(forKey: "WindowFrame"),
//                           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData) {
//
//                            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
//                            var frame = windowFrame.rectValue
//
//                            // Menggeser posisi window ke kiri dan ke bawah sejauh 20 piksel
//                            frame.origin.x += 20
//                            frame.origin.y -= 20
//
//                            windowController.window?.setFrame(frame, display: true)
//                            // Manually trigger layout update
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                                if let splitVC = windowController.contentViewController as? SplitVC {
//                                    splitVC.setWindowIdentifier(windowController.windowIdentifier)
//                                    splitVC.resetDelegates()
//                                }
//                            }
//                        }
//                    }
//                }
//            } else {
//
//            }
//        }
//    }

    @IBAction func openSetting(_ sender: Any) {
        guard let mainMenu = NSApp.mainMenu,
              let menuItem = mainMenu.items.first(where: {
                $0.identifier?.rawValue == "app" }),
              let menu = menuItem.submenu,
              let preferensiMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "preferences" })
        else {return}
        NSApp.sendAction(preferensiMenuItem.action!, to: preferensiMenuItem.target, from: self)
    }
    
    @objc func ubahNama(_ sender: Any) {
        guard let item = outlineView.item(atRow: outlineView.clickedRow), outlineView.parent(forItem: item) is StatistikParentItem else { return }
        editorManager?.startEditing(row: outlineView.clickedRow, column: outlineView.clickedColumn)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

//enum SidebarCategory: Int {
//    case siswa = 1
//    case guru = 2
//    case kelas1 = 3
//    case kelas2 = 4
//    case kelas3 = 5
//    case kelas4 = 6
//    case kelas5 = 7
//    case kelas6 = 8
//    case transaksi = 9
//    case pemasukan = 10
//    case pengeluaran = 11
//    case lainnya = 12
//    case saldo = 13
//    case nilai = 14
//    case sekilas = 15
//    case struktur = 16
//    case inventaris = 17
//}
struct NameConstants {
    // The places group title.
    static let transaksi = NSLocalizedString("Administrasi", comment: "")
    static let daftar = NSLocalizedString("Daftar", comment: "")
    // The pictures group title.
    static let statistik = NSLocalizedString("Ringkasan", comment: "")
    static let kelas = NSLocalizedString("Kelas Aktif", comment: "")
}

extension SidebarViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard outlineView.clickedRow != -1,
              let ubahNamaItem = menu.items.first(where: { $0.identifier?.rawValue == "ubahnama"}) else {
            menu.items.first(where: { $0.identifier?.rawValue == "bantuan"})?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "preferensi"})?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "ubahnama"})?.isHidden = true
            return
        }
        
        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? SidebarItem,
              outlineView.parent(forItem: item) is StatistikParentItem else {
            menu.items.first(where: { $0.identifier?.rawValue == "bantuan"})?.isHidden = true
            menu.items.first(where: { $0.identifier?.rawValue == "preferensi"})?.isHidden = true
            ubahNamaItem.isHidden = true
            return
        }
        menu.items.first(where: { $0.identifier?.rawValue == "bantuan"})?.isHidden = true
        menu.items.first(where: { $0.identifier?.rawValue == "preferensi"})?.isHidden = true
        ubahNamaItem.isHidden = false
        ubahNamaItem.action = #selector(ubahNama(_:))
        ubahNamaItem.target = self
        ubahNamaItem.title = "Ubah nama \"\(item.name)\""
    }
}

extension SidebarViewController: NSTextFieldDelegate {}

extension SidebarViewController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        if let item = outlineView.item(atRow: row) as? SidebarItem,
           outlineView.parent(forItem: item) is StatistikParentItem {
            let namaBaru = newText
            switch item.identifier {
            case "ringkasanKelas": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanKelas")
            case "ringkasanSiswa": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanSiswa")
            case "ringkasanGuru": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanGuru")
            default: break
            }
        }
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        return true
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let cell = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else { return "return" }
        return cell.textField?.stringValue ?? ""
    }
    
    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        return outlineView.tableColumns[column].width
    }
    
    
}
