//
//  Struktur.swift
//  Data Manager
//
//  Created by Bismillah on 28/11/23.
//

import Cocoa

class Struktur: NSViewController {
    let dbController = DatabaseController.shared
    var guruData: [GuruModel] = []
    var strukturalDict: [String: [GuruModel]] = [:]
    var hierarkiStruktural: [(struktural: String, guruList: [GuruModel])] = []
    @IBOutlet var menuItem: NSMenu!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var labelStack: NSStackView!
    @IBOutlet weak var filterTahun: NSMenuItem!
    @IBOutlet weak var hLine: NSBox!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    var isDataLoaded: Bool = false
    var toolbarMenu = NSMenu()
    @IBOutlet weak var stackHeaderTopConstraint: NSLayoutConstraint!
    var tahunTerpilih: Int = UserDefaults.standard.integer(forKey: "tahunTerpilih") {
        didSet {
            UserDefaults.standard.setValue(tahunTerpilih, forKey: "tahunTerpilih")
            label.stringValue = "Struktur Guru Tahun \(tahunTerpilih)"
        }
    }
    let urutanStruktural: [String] = ["Pelindung", "Kepala Sekolah", "Wakil Kepala Sekolah", "Sekretaris", "Bendahara"]
    var tahunAktif: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.menu = menuItem
        menuItem.delegate = self
        toolbarMenu = menuItem.copy() as! NSMenu
        toolbarMenu.delegate = self
        let currentYear = Calendar.current.component(.year, from: Date())
        UserDefaults.standard.register(defaults: ["tahunTerpilih": currentYear])
        tahunTerpilih = UserDefaults.standard.integer(forKey: "tahunTerpilih")
        if let savedRowHeight = UserDefaults.standard.value(forKey: "StrukturOutlineViewRowHeight") as? CGFloat {
            outlineView.rowHeight = savedRowHeight
        }
        self.label.alphaValue = 0.6
        visualEffect.material = .headerView
        // Do view setup here.
    }
    override func viewWillAppear() {
        if !isDataLoaded {
            DispatchQueue.main.async {
                self.muatUlang(self)
            }
            label.stringValue = "Struktur Guru Tahun \(tahunTerpilih)"
            // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
        }
    }
    
    override func viewDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.view.window?.makeFirstResponder(self.outlineView)
        }
        ReusableFunc.resetMenuItems()
        guard let toolbar = self.view.window?.toolbar else {return}
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }),
           let searchField = searchFieldToolbarItem.view as? NSSearchField {
            searchField.placeholderAttributedString = nil
            searchField.placeholderString = "Struktur Guru"
            searchField.isEnabled = false
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
           let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton {
            kalkulasiNilai.isEnabled = false
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton {
            hapus.isEnabled = false
        }

        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton {
            edit.isEnabled = false
        }

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton {
            tambah.isEnabled = false
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton {
            add.isEnabled = false
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton {
            popUpButton.menu = toolbarMenu
        }
    }

    func updateFilterTahunMenu() {
        
        tahunAktif = dbController.getTahunAktifGuru()
        // Hapus semua subitem dari filterTahun
        filterTahun.submenu?.removeAllItems()
        // Ambil semua tahun unik dari guruData
        let tahunSet = Set(tahunAktif).sorted()
        
        // Tambahkan subitem untuk setiap tahun
        for tahun in tahunSet {
            let tahunItem = NSMenuItem(title: tahun, action: #selector(filterByTahun(_:)), keyEquivalent: "")
            tahunItem.target = self // Pastikan targetnya adalah self
            filterTahun.submenu?.addItem(tahunItem)
        }
        updateFilterTahunToolbarMenu()
    }
    func updateFilterTahunToolbarMenu() {
        
        tahunAktif = dbController.getTahunAktifGuru()
        // Hapus semua subitem dari filterTahun
        guard let filterTahunToolbar = toolbarMenu.items.first(where: {$0.title == "Tahun"}) else {return}
        filterTahunToolbar.submenu?.removeAllItems()
        // Ambil semua tahun unik dari guruData
        let tahunSet = Set(tahunAktif).sorted()
        
        // Tambahkan subitem untuk setiap tahun
        for tahun in tahunSet {
            let tahunItem = NSMenuItem(title: tahun, action: #selector(filterByTahun(_:)), keyEquivalent: "")
            tahunItem.target = self // Pastikan targetnya adalah self
            filterTahunToolbar.submenu?.addItem(tahunItem)
        }
    }
    func prioritasStruktural(for struktural: String) -> Int {
        if let index = urutanStruktural.firstIndex(of: struktural) {
            return index // Memberikan prioritas sesuai dengan urutan
        }
        return urutanStruktural.count // Jika tidak ada dalam urutanStruktural, beri prioritas paling tinggi
    }

    @objc func filterByTahun(_ sender: NSMenuItem) {
        Task(priority: .background) { [unowned self] in
            guard let tahun = sender.title as String? else { return }
            tahunTerpilih = Int(tahun) ?? 0
            await fetchGuru(tahun)
            await buildDict()
            await buildHierarchy()
            
            self.buildOutlineView()
        }
    }
    
    func fetchGuru(_ tahun: String = "") async {
        await Task { [weak self] in
            guard let self = self else { return }
            self.guruData = self.dbController.getGuru(forYear: !tahun.isEmpty ? tahun : String(self.tahunTerpilih))
        }.value
    }
    
    func buildDict() async {
        await Task { [weak self] in
            guard let self = self else { return }
            self.strukturalDict.removeAll()
            for guru in guruData {
                let strukturalKey = guru.struktural.isEmpty ? "Lainnya" : guru.struktural
                if self.strukturalDict[strukturalKey] == nil {
                    self.strukturalDict[strukturalKey] = []
                }
                self.strukturalDict[strukturalKey]?.append(guru)
            }
        }.value
    }
    
    func buildHierarchy() async {
        // Siapkan hierarki dan urutkan
        await Task { [weak self] in
            guard let self = self else { return }
            self.hierarkiStruktural.removeAll()
            for (struktural, guruList) in self.strukturalDict {
                self.hierarkiStruktural.append((struktural: struktural, guruList: guruList))
            }
            self.hierarkiStruktural.sort { (a, b) -> Bool in
                let prioritasA = self.prioritasStruktural(for: a.struktural)
                let prioritasB = self.prioritasStruktural(for: b.struktural)
                
                if prioritasA == prioritasB {
                    return a.struktural < b.struktural
                }
                return prioritasA < prioritasB
            }
            for index in self.hierarkiStruktural.indices {
                self.hierarkiStruktural[index].guruList.sort { $0.namaGuru < $1.namaGuru }
            }
        }.value
    }
    
    func buildOutlineView() {
        Task { @MainActor [weak self] in
             guard let self = self else { return }
             self.outlineView.reloadData()
             try? await Task.sleep(nanoseconds: 200_000_000)
             self.outlineView.beginUpdates()
             self.outlineView.animator().expandItem(nil, expandChildren: true)
             self.outlineView.endUpdates()
         }
    }

    @IBAction func muatUlang(_ sender: Any) {
        Task(priority: .background) { [unowned self] in
            await self.fetchGuru()
            await self.buildDict()
            await self.buildHierarchy()
            
            self.buildOutlineView()
        }
    }

    
    @IBAction func salinMenu(_ sender: NSMenuItem) {
        if outlineView.clickedRow != -1 {
            if outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
                salin(outlineView.selectedRowIndexes)
            } else {
                salin(IndexSet([outlineView.clickedRow]))
            }
        } else {
            salin(outlineView.selectedRowIndexes)
        }
    }
    
    @IBAction func salin(_ row: IndexSet) {
        var salinan: [String] = []
        
        // Iterasi melalui setiap baris yang ada di IndexSet
        for index in row {
            // Dapatkan item di baris tertentu
            if let item = outlineView.item(atRow: index) {
                if let strukturalItem = item as? (struktural: String, guruList: [GuruModel]) {
                    // Jika item adalah parent (struktural)
                    salinan.append("\(strukturalItem.struktural):")
                } else if let guruItem = item as? GuruModel {
                    // Jika item adalah child (guru)
                    salinan.append("\(guruItem.namaGuru)")
//                    salinan.append("Guru: \(guruItem.namaGuru), Alamat: \(guruItem.alamatGuru), Tahun Aktif: \(guruItem.tahunaktif), Mapel: \(guruItem.mapel), Jabatan: \(guruItem.struktural)")
                }
            }
        }
        
        // Gabungkan semua string menjadi satu teks dengan newline sebagai pemisah
        let hasilSalinan = salinan.joined(separator: "\n")
        
        // Salin ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hasilSalinan, forType: .string)
        
        // Berikan notifikasi jika diperlukan (opsional)
        
    }


    @IBAction func salinSemua(_ sender: Any) {
        // Variabel untuk menampung teks hasil salinan
        var salinan: [String] = []
        salinan.append("Struktur Guru Tahun \(String(tahunTerpilih)):")
        // Iterasi melalui data hierarki
        for strukturalItem in hierarkiStruktural {
            // Tambahkan nama struktural ke salinan
            salinan.append("\n\(strukturalItem.struktural):")
            
            // Tambahkan semua guru dalam struktural tersebut
//            for guru in strukturalItem.guruList {
//                salinan.append("Guru: \(guru.namaGuru), Alamat: \(guru.alamatGuru), Tahun Aktif: \(guru.tahunaktif), Mapel: \(guru.mapel), Jabatan: \(guru.struktural)")
//            }
            for guru in strukturalItem.guruList {
                salinan.append("\(guru.namaGuru)")
            }
        }
        
        // Gabungkan semua string menjadi satu teks dengan newline sebagai pemisah
        let hasilSalinan = salinan.joined(separator: "\n")
        
        // Salin ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hasilSalinan, forType: .string)
        
        // Berikan notifikasi jika diperlukan (opsional)
        
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        guruData.removeAll()
    }
    //override func awakeFromNib() {
//        NotificationCenter.default.addObserver(self, selector: #selector(perbaruiData), name: DB_Controller.guruDidChangeNotification, object: nil)
    //}

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
    
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.outlineView.rowHeight += 5
            self.outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<self.outlineView.numberOfRows))
        })
        saveRowHeight()
    }
    @IBAction func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.outlineView.rowHeight = max(self.outlineView.rowHeight - 5, 16)
            self.outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<self.outlineView.numberOfRows))
        })
        saveRowHeight()
    }
    func saveRowHeight() {
        UserDefaults.standard.setValue(outlineView.rowHeight, forKey: "StrukturOutlineViewRowHeight")
    }
    deinit {
        guruData.removeAll()
        hierarkiStruktural.removeAll()
        strukturalDict.removeAll()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .windowTabDidChange, object: nil)
    }
}

extension Struktur: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // Jika item nil, maka kembalikan jumlah struktural (root level)
        if item == nil {
            return hierarkiStruktural.count
        }
        
        // Jika item adalah tuple (struktural), kembalikan jumlah guru dalam struktural tersebut
        if let strukturalItem = item as? (struktural: String, guruList: [GuruModel]) {
            return strukturalItem.guruList.count
        }
        
        // Jika bukan keduanya, kembalikan 0
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Hanya parent (struktural) yang bisa di-expand
        return item is (struktural: String, guruList: [GuruModel])
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        // Jika item nil, berikan parent (struktural)
        if item == nil {
            return hierarkiStruktural[index]
        }
        
        // Jika item adalah parent (struktural), berikan child (guru)
        if let strukturalItem = item as? (struktural: String, guruList: [GuruModel]) {
            return strukturalItem.guruList[index]
        }
        
        // Jika tidak cocok, kembalikan nilai default
        return ""
    }
}
extension Struktur: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        // Pastikan ada identifier kolom
        guard let identifier = tableColumn?.identifier else { return nil }
        // Jika item adalah parent (struktural)
        if let strukturalItem = item as? (struktural: String, guruList: [GuruModel]) {
            if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView, let textField = cell.textField {
                // Set teks untuk parent (struktural)
                textField.translatesAutoresizingMaskIntoConstraints = false
                var leadingConstant: CGFloat =  5
                if item is (struktural: String, guruList: [GuruModel]) {
                    leadingConstant = 5
                }

                // Menghapus constraint yang sudah ada untuk mencegah duplikasi
                cell.constraints.forEach { constraint in
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5)
                ])

                textField.stringValue = strukturalItem.struktural
                textField.font = NSFont.boldSystemFont(ofSize: 13) // Opsi: Teks tebal untuk parent

                return cell
            }
        }
        
        // Jika item adalah child (guru)
        if let guruItem = item as? GuruModel {
            if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView, identifier.rawValue == "NamaGuruColumn", let textField = cell.textField {
                // Set teks untuk parent (struktural)
                textField.translatesAutoresizingMaskIntoConstraints = false
                var leadingConstant: CGFloat = 0
                if item is (struktural: String, guruList: [GuruModel]) {
                    leadingConstant = 0
                }

                // Menghapus constraint yang sudah ada untuk mencegah duplikasi
                cell.constraints.forEach { constraint in
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20)
                ])
                
                textField.stringValue = guruItem.namaGuru
                textField.font = NSFont.systemFont(ofSize: 13) // Opsi: Teks normal untuk child
                return cell
            }
        }
        
        return nil
    }
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return outlineView.rowHeight
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        NSApp.sendAction(#selector(Struktur.updateMenuItem(_:)), to: nil, from: self)
    }
}

extension Struktur: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menuItem)
        }
    }
    func updateTableMenu(_ menu: NSMenu) {
        guard let filterItem = menu.items.first(where: {$0.title == "Filter"}), let muatUlang = menu.items.first(where: {$0.title == "Muat Ulang"}), let salinSemua = menu.items.first(where: {$0.title == "Salin Semua"}), let salinItem = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) else {return}
        
        if outlineView.clickedRow == -1 {
            salinItem.isHidden = true
            filterItem.isHidden = false
            filterTahun.isHidden = false
            muatUlang.isHidden = false
            salinSemua.isHidden = false
            tahunAktif = dbController.getTahunAktifGuru()
            updateFilterTahunMenu()
            if let tahun = filterTahun.submenu {
                for terpilih in tahun.items {
                    if terpilih.title == String(tahunTerpilih) {
                        terpilih.state = .on
                    } else {
                        terpilih.state = .off
                    }
                }
            }
        } else {
            salinItem.isHidden = false
            filterItem.isHidden = true
            filterTahun.isHidden = true
            muatUlang.isHidden = true
            salinSemua.isHidden = true
            
            if outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
                salinItem.title = "Salin \(outlineView.numberOfSelectedRows) data..."
            } else {
                salinItem.title = "Salin 1 data..."
            }
        }
    }
    
    func updateToolbarMenu(_ menu: NSMenu) {
        guard let filterTahunToolbar = menu.items.first(where: {$0.title == "Tahun"}), let salinItem = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) else {return}
        
        updateFilterTahunToolbarMenu()
        if outlineView.numberOfSelectedRows < 1 {
            salinItem.isHidden = true
        } else {
            salinItem.isHidden = false
            salinItem.title = "Salin \(outlineView.numberOfSelectedRows) data..."
        }
        if let tahun = filterTahunToolbar.submenu {
            for terpilih in tahun.items {
                if terpilih.title == String(tahunTerpilih) {
                    terpilih.state = .on
                } else {
                    terpilih.state = .off
                }
            }
        }
    }
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }) {
            let adaBarisDipilih = outlineView.selectedRowIndexes.count > 0
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinMenu(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
            }
        }
    }
}
