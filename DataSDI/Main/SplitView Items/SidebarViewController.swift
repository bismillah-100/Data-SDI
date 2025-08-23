//
//  SidebarViewController.swift
//  Data Manager
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa

/// Protokol untuk menangani interaksi dengan sidebar.
/// Protokol ini mendefinisikan metode yang akan dipanggil ketika item sidebar dipilih.
protocol SidebarDelegate: AnyObject {
    func didSelectSidebarItem(index: SidebarIndex)
}

/// Protokol untuk menangani pembaruan pada kelas, mendefinisikan metode yang akan dipanggil ketika tabel kelas diperbarui,
/// dan juga mendefinisikan metode yang akan dipanggil ketika pembaruan selesai.
protocol KelasVCDelegate: AnyObject {
    func didUpdateTable(_ item: SidebarIndex)
    func didCompleteUpdate()
}

/// Kelas SidebarViewController mengelola tampilan sidebar yang berisi daftar item yang dapat dipilih.
class SidebarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    /// Item yang dipilih saat ini di sidebar.
    /// Item ini akan diatur ketika pengguna memilih item di sidebar.
    var selectedSidebarItem: SidebarItem?

    /// Delegate untuk menangani interaksi dengan sidebar.
    weak var delegate: SidebarDelegate?

    /// Outlet untuk NSOutlineView yang menampilkan daftar item di sidebar.
    @IBOutlet weak var outlineView: EditableOutlineView!

    /// Daftar item yang ditampilkan di sidebar.
    /// Daftar ini berisi berbagai grup dan item yang akan ditampilkan di sidebar.
    /// Item ini diisi pada saat viewDidLoad dengan berbagai grup dan item yang telah ditentukan.
    /// Setiap grup diwakili oleh kelas yang mengadopsi protokol SidebarGroup, seperti AdministrasiParentItem dan DaftarParentItem.
    /// Item ini juga menyimpan informasi tentang grup dan item yang akan ditampilkan di sidebar.
    var sidebarItems: [SidebarGroup] = []

    /// Indeks item sidebar yang dipilih saat ini.
    /// Nilai ini disimpan di UserDefaults untuk mempertahankan status pemilihan antara sesi aplikasi.
    /// Nilai defaultnya adalah 11, yang berarti item dengan indeks 11 akan dipilih secara default.
    var selectedOutlineItemIndex: String = "daftarSiswa" {
        didSet {
            UserDefaults.standard.set(selectedOutlineItemIndex, forKey: "SelectedOutlineItemIndex")
        }
    }

    /// Sidebar grup ringkasan untuk item guru.
    let ringkasanGuru = UserDefaults.standard.string(forKey: "sidebarRingkasanGuru")
    /// Sidebar grup ringkasan untuk item siswa.
    let ringkasanSiswa = UserDefaults.standard.string(forKey: "sidebarRingkasanSiswa")
    /// Sidebar grup ringkasan untuk item kelas.
    let ringkasanKelas = UserDefaults.standard.string(forKey: "sidebarRingkasanKelas")

    /// Manajer editor overlay yang digunakan untuk mengelola pengeditan item di sidebar.
    /// Editor ini memungkinkan pengguna untuk mengedit nama item di sidebar dengan cara overlay.
    var editorManager: OverlayEditorManager?

    /// Menu klik-kanan.
    @IBOutlet weak var outlineMenu: NSMenu!

    /// Indikator apakah sidebar sedang dalam proses ekspansi.
    private lazy var isExpanding = false

    /// Indikator apakah delegate harus diperbarui ketika memilih item di sidebar.
    private lazy var shouldUpdateDelegate = true

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.floatsGroupRows = false
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true

        outlineView.registerForDraggedTypes([.string]) // atau UTType custom
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)

        // MARK: - Grup Transaksi (prefix: "transaksi")

        let transaksiItem = SidebarItem(name: "Transaksi", identifier: "transaksiTransaksi", image: NSImage(named: "catatan"), index: .transaksi)
        let pengeluaranItem = SidebarItem(name: "Pengeluaran", identifier: "transaksiPengeluaran", image: NSImage(named: "uangkeluar"), index: .pengeluaran)
        let pemasukanItem = SidebarItem(name: "Pemasukan", identifier: "transaksiPemasukan", image: NSImage(named: "uangmasuk"), index: .pemasukan)
        let lainnyaItem = SidebarItem(name: "Lainnya", identifier: "transaksiLainnya", image: NSImage(named: "lainnya"), index: .lainnya)
        let saldoItem = SidebarItem(name: "Saldo", identifier: "transaksiSaldo", image: NSImage(named: "saldo"), index: .saldo)
        let transaksiGroup = AdministrasiParentItem(name: "Administrasi", children: [transaksiItem, pengeluaranItem, pemasukanItem, lainnyaItem, saldoItem])
        sidebarItems.append(transaksiGroup)

        // MARK: - Grup Guru (prefix: "Guru")

        let masterGuru = SidebarItem(name: "Guru", identifier: "mapelGuru", image: NSImage(named: "guru"), index: .guruMapel)
        let bookImage = NSImage(systemSymbolName: "book.fill", accessibilityDescription: .none)
        let sidebarSymbolConfBlack = NSImage.SymbolConfiguration(pointSize: 18, weight: .black)
        let sidebarSymbolConf = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let largeBook = bookImage?.withSymbolConfiguration(sidebarSymbolConfBlack)
        let guruItem = SidebarItem(name: "Mapel", identifier: "daftarGuru", image: largeBook, index: .guru)
        let struktur = SidebarItem(
            name: ringkasanGuru ?? "Struktur",
            identifier: "ringkasanGuru",
            image: NSImage(systemSymbolName: "list.triangle", accessibilityDescription: nil)?
                .withSymbolConfiguration(sidebarSymbolConf)?
                .withSymbolConfiguration(.init(hierarchicalColor: .labelColor)),
            index: .strukturGuru
        )
        let tugasGuruGroup = DaftarParentItem(identifier: "DaftarGuru", name: "Guru", children: [masterGuru, guruItem, struktur])

        sidebarItems.append(tugasGuruGroup)

        // MARK: - SISWA

        let siswaItem = SidebarItem(
            name: "Siswa", identifier: "daftarSiswa",
            image: NSImage(named: "siswa"),
            index: .siswa
        )

        let jumlahsiswaItem = SidebarItem(
            name: ringkasanSiswa ?? "Sensus",
            identifier: "ringkasanSiswa",
            image: NSImage(systemSymbolName: "list.number", accessibilityDescription: nil)?
                .withSymbolConfiguration(sidebarSymbolConf)?
                .withSymbolConfiguration(.init(hierarchicalColor: .labelColor)),
            index: .jumlahSiswa
        )

        let daftarGroup = DaftarParentItem(identifier: "DaftarSiswa", name: "Siswa", children: [siswaItem, jumlahsiswaItem])
        sidebarItems.append(daftarGroup)

        // MARK: - INVENTARIS

        let inventarisItem = SidebarItem(
            name: "Inventaris", identifier: "daftarInventaris",
            image: NSImage(systemSymbolName: "building.2.fill", accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)),
            index: .inventaris
        )
        let invGroup = DaftarParentItem(identifier: "DaftarInventaris", name: "Inventaris", children: [inventarisItem])
        sidebarItems.append(invGroup)

        // MARK: - Grup Kelas (prefix: "kelas")

        let kelas1Item = SidebarItem(name: "Kelas 1", identifier: "kelasAktif1", image: NSImage(named: "Kelas 1"), index: .kelas1)
        let kelas2Item = SidebarItem(name: "Kelas 2", identifier: "kelasAktif2", image: NSImage(named: "Kelas 2"), index: .kelas2)
        let kelas3Item = SidebarItem(name: "Kelas 3", identifier: "kelasAktif3", image: NSImage(named: "Kelas 3"), index: .kelas3)
        let kelas4Item = SidebarItem(name: "Kelas 4", identifier: "kelasAktif4", image: NSImage(named: "Kelas 4"), index: .kelas4)
        let kelas5Item = SidebarItem(name: "Kelas 5", identifier: "kelasAktif5", image: NSImage(named: "Kelas 5"), index: .kelas5)
        let kelas6Item = SidebarItem(name: "Kelas 6", identifier: "kelasAktif6", image: NSImage(named: "Kelas 6"), index: .kelas6)

        let historis = SidebarItem(
            name: "Historis", identifier: "historiKelas",
            image: NSImage(systemSymbolName: "clock.arrow.2.circlepath", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .bold))?
                .withSymbolConfiguration(.init(paletteColors: [.labelColor])),
            index: .historis
        )

        let statistikImage = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: nil)
        let statistikItem = SidebarItem(
            name: ringkasanKelas ?? "Ikhtisar",
            identifier: "ringkasanKelas",
            image: statistikImage?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .bold))?
                .withSymbolConfiguration(.init(paletteColors: [.labelColor])),
            index: .nilaiKelas
        )

        // menyiapkan grup "Kelas" dan menambahkan kelas1-6 ke grup tersebut
        let kelasGroup = DaftarParentItem(identifier: "DaftarKelas", name: "Kelas Aktif", children: [kelas1Item, kelas2Item, kelas3Item, kelas4Item, kelas5Item, kelas6Item, historis, statistikItem])
        sidebarItems.append(kelasGroup)

        let savedOrder = UserDefaults.standard.stringArray(forKey: "SidebarGroupOrder")

        if let savedOrder {
            // buat dictionary sementara untuk akses cepat
            let groups = sidebarItems.compactMap { $0 }
            let groupDict: [String: SidebarGroup] = Dictionary(uniqueKeysWithValues: groups.map { ($0.identifier, $0) })

            // buat ulang sidebarItems dengan urutan disesuaikan
            sidebarItems = savedOrder.compactMap { groupDict[$0] }

            // tambahkan grup yang tidak tersimpan (mungkin baru)
            let existingIDs = Set(savedOrder)
            let newGroups = sidebarItems.filter { group in
                !existingIDs.contains(group.identifier)
            }
            sidebarItems.append(contentsOf: newGroups)
        }

        outlineView.reloadData()
        outlineView.refusesFirstResponder = true
        outlineView.wantsLayer = true

        outlineView.menu = outlineMenu
    }

    func saveSidebarOrder() {
        let groupOrder = sidebarItems.compactMap { $0.identifier }
        UserDefaults.standard.set(groupOrder, forKey: "SidebarGroupOrder")
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveExpandedItems()
    }

    /// Properti yang menunjukkan apakah interaksi pengguna diizinkan pada sidebar.
    /// Dikofigurasi ketika viewDidAppear dipanggil, dan digunakan untuk mengontrol apakah pemilihan item sidebar akan memicu delegate.
    private var isUserInteractionEnabled = false

    override func viewDidAppear() {
        super.viewDidAppear()
        shouldUpdateDelegate = false
        loadExpandedItems()

        outlineMenu.delegate = self
        if let selfWindow = view.window {
            editorManager = OverlayEditorManager(tableView: outlineView, containingWindow: selfWindow)
            outlineView.editAction = { [weak self] row, column in
                guard let self else { return }
                editorManager?.startEditing(row: row, column: column)
            }
            editorManager?.delegate = self
            editorManager?.dataSource = self
        }

        // selectedOutlineItemIndex = UserDefaults.standard.integer(forKey: "SelectedOutlineItemIndex")
        guard outlineView.selectedRow == -1 else {
            isUserInteractionEnabled = true
            shouldUpdateDelegate = true
            return
        }
        if let savedID = UserDefaults.standard.string(forKey: "SelectedOutlineItemIndex") {
            if let (rowIndex, _) = sidebarItems.enumerated()
                .flatMap({ _, parentItem in
                    parentItem.children.enumerated().map { _, child in
                        (row: outlineView.row(forItem: child), item: child)
                    }
                })
                .first(where: { $0.item.identifier == savedID })
            {
                outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            }
        }

        isUserInteractionEnabled = true
        shouldUpdateDelegate = true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedIndex = outlineView.selectedRow

        // Memastikan pemilihan tidak kosong
        guard selectedIndex != -1 else { return }

        selectedSidebarItem = outlineView.item(atRow: selectedIndex) as? SidebarItem

        if !isExpanding, shouldUpdateDelegate {
            if let selectedItem = selectedSidebarItem {
                delegate?.didSelectSidebarItem(index: indexToOpenForSidebarItem(selectedItem))
                UserDefaults.standard.set(selectedItem.identifier, forKey: "SelectedOutlineItemIndex")
            }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let parentItem = item as? SidebarGroup {
            return parentItem.children[index]
        }
        return sidebarItems[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let group = item as? SidebarGroup {
            return !group.children.isEmpty
        }
        return false
    }

    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let group = item as? SidebarGroup {
            return group.children.count
        }
        return sidebarItems.count
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let group = item as? SidebarGroup else { return nil }

        let pbItem = NSPasteboardItem()
        pbItem.setString(group.identifier, forType: .string) // gunakan identifier unik, bukan name
        return pbItem
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem _: Any?, proposedChildIndex _: Int) -> NSDragOperation {
        // 1. Style garis antar‐row
        outlineView.draggingDestinationFeedbackStyle = .gap

        // 2. Konversi lokasi drag ke koordinat outlineView
        let loc = outlineView.convert(info.draggingLocation, from: nil)

        // 3. Kumpulkan semua baris yang mewakili parent (root)
        var parentRows: [Int] = []
        for row in 0 ..< outlineView.numberOfRows {
            let item = outlineView.item(atRow: row)
            // hanya yang level root (parent(nil))
            if outlineView.parent(forItem: item) == nil {
                parentRows.append(row)
            }
        }

        // 4. Tentukan di antara parentRows mana loc.y itu
        //    dropIndex = index di array sidebarItems
        var dropIndex = parentRows.count
        for (i, parentRow) in parentRows.enumerated() {
            let rect = outlineView.rect(ofRow: parentRow)
            let midY = rect.minY + rect.height * 0.5
            if loc.y > midY {
                dropIndex = i + 1
            } else {
                break
            }
        }

        // 5. Paksa drop hanya di root, posisi dropIndex
        outlineView.setDropItem(nil, dropChildIndex: dropIndex)
        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item _: Any?, childIndex index: Int) -> Bool {
        guard let id = info.draggingPasteboard.string(forType: .string),
              let sourceIndex = sidebarItems.firstIndex(where: { $0.identifier == id })
        else {
            return false
        }

        // 1. Ambil item, hapus dari source
        let moved = sidebarItems.remove(at: sourceIndex)

        // 2. Sesuaikan targetIndex jika sourceIndex < index
        var targetIndex = index
        if sourceIndex < targetIndex {
            targetIndex -= 1
        }

        // 3. Sisipkan di model dan update outlineView
        sidebarItems.insert(moved, at: targetIndex)
        outlineView.moveItem(at: sourceIndex, inParent: nil,
                             to: targetIndex, inParent: nil)

        saveSidebarOrder()
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        if let groupNode = item as? SidebarGroup {
            // Jika item adalah grup, gunakan sel dengan identifier "GroupCell"
            if let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = groupNode.name
                cell.textField?.font = NSFont.systemFont(ofSize: 11, weight: .black)
                // Lakukan penyesuaian tambahan sesuai kebutuhan untuk sel grup
                return cell
            }
        } else if let dataNode = item as? SidebarItem {
            // Jika item adalah data, gunakan sel dengan identifier "DataCell"
            if let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DataCell"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = dataNode.name
                cell.textField?.isEditable = false
                cell.imageView?.image = dataNode.image // Tambahkan gambar ke sel
                return cell
            }
        }
        return nil
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is SidebarGroup
    }

    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item is SidebarGroup) // Anda mungkin ingin menyesuaikan kondisi ini sesuai kebutuhan
    }

    /// Fungsi untuk menyimpan item yang diperluas ke UserDefaults.
    /// Fungsi ini akan menyimpan indeks item yang diperluas ke dalam UserDefaults dengan kunci "expandedItems".
    /// Indeks yang disimpan adalah indeks dari item yang diperluas dalam daftar `sidebarItems`.
    /// Fungsi ini dipanggil ketika view akan menghilang (viewWillDisappear).
    func saveExpandedItems() {
        let expandedItems = sidebarItems.enumerated().compactMap { index, item -> Int? in
            if outlineView.isItemExpanded(item) {
                return index
            }
            return nil
        }

        UserDefaults.standard.set(expandedItems, forKey: "expandedItems")
    }

    /// Fungsi untuk memuat item yang diperluas dari UserDefaults.
    /// Fungsi ini akan mengambil array dari UserDefaults dengan kunci "expandedItems" dan memperluas item yang sesuai di `outlineView`.
    /// Fungsi ini dipanggil ketika view akan muncul (viewWillAppear).
    /// Jika tidak ada item yang diperluas, maka semua item akan diperluas.
    func loadExpandedItems() {
        if let expandedItems = UserDefaults.standard.array(forKey: "expandedItems") as? [Int] {
            for index in expandedItems {
                if index < sidebarItems.count {
                    outlineView.expandItem(sidebarItems[index])
                }
            }
        } else {
            for sidebarItem in sidebarItems {
                outlineView.expandItem(sidebarItem)
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

    // MARK: - Properties

    override init(nibName _: NSNib.Name?, bundle _: Bundle?) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedOutlineItemIndex": "daftarSiswa"])
        selectedOutlineItemIndex = UserDefaults.standard.string(forKey: "SelectedOutlineItemIndex") ?? "daftarSiswa"

        super.init(nibName: "Sidebar", bundle: nil)
    }

    required init?(coder: NSCoder) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedOutlineItemIndex": "daftarSiswa"])
        selectedOutlineItemIndex = UserDefaults.standard.string(forKey: "SelectedOutlineItemIndex") ?? "daftarSiswa"
        super.init(coder: coder)
    }

    /// Fungsi untuk mendapatkan indeks yang akan dibuka berdasarkan item sidebar yang dipilih.
    /// - Parameter sidebarItem: Item sidebar yang dipilih.
    /// - Returns: Indeks yang sesuai untuk item sidebar yang dipilih, atau `nil` jika tidak ada indeks yang sesuai.
    func indexToOpenForSidebarItem(_ sidebarItem: SidebarItem) -> SidebarIndex {
        sidebarItem.index
    }

    /// Action menu `Bantuan Aplikasi` untuk membuka pengaturan aplikasi.
    /// Fungsi ini akan mencari menu preferensi di menu bar aplikasi dan mengirimkan aksi untuk membuka pengaturan.
    /// - Parameter sender: Objek pemicu.
    @IBAction func openSetting(_: Any) {
        guard let mainMenu = NSApp.mainMenu,
              let menuItem = mainMenu.items.first(where: {
                  $0.identifier?.rawValue == "app"
              }),
              let menu = menuItem.submenu,
              let preferensiMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "preferences" })
        else { return }
        NSApp.sendAction(preferensiMenuItem.action!, to: preferensiMenuItem.target, from: self)
    }

    /// Action menu `Ubah Nama` untuk mengubah nama item sidebar yang dipilih.
    ///
    /// Fungsi ini akan memulai proses pengeditan nama item sidebar yang dipilih dengan menggunakan `OverlayEditorManager`.
    /// Fungsi ini akan memeriksa apakah item yang dipilih adalah identifier yang diawali "ringkasan" sebelum memulai pengeditan.
    /// Jika item yang dipilih tidak diawali dengan identifier "ringkasan", maka fungsi ini tidak akan melakukan apa-apa.
    /// - Parameter sender: Objek pemicu.
    @objc func ubahNama(_: Any) {
        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? SidebarItem,
              item.identifier.hasPrefix("ringkasan")
        else { return }
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

extension SidebarViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard outlineView.clickedRow != -1,
              let ubahNamaItem = menu.items.first(where: { $0.identifier?.rawValue == "ubahnama" })
        else {
            menu.items.first(where: { $0.identifier?.rawValue == "bantuan" })?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "preferensi" })?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "ubahnama" })?.isHidden = true
            return
        }

        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? SidebarItem,
              item.identifier.hasPrefix("ringkasan")
        else {
            menu.items.first(where: { $0.identifier?.rawValue == "bantuan" })?.isHidden = true
            menu.items.first(where: { $0.identifier?.rawValue == "preferensi" })?.isHidden = true
            ubahNamaItem.isHidden = true
            return
        }
        menu.items.first(where: { $0.identifier?.rawValue == "bantuan" })?.isHidden = true
        menu.items.first(where: { $0.identifier?.rawValue == "preferensi" })?.isHidden = true
        ubahNamaItem.isHidden = false
        ubahNamaItem.action = #selector(ubahNama(_:))
        ubahNamaItem.target = self
        ubahNamaItem.title = "Ubah nama 〝\(item.name)〞"
    }
}

extension SidebarViewController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column _: Int, in _: NSTableView) {
        if let item = outlineView.item(atRow: row) as? SidebarItem,
           item.identifier.hasPrefix("ringkasan")
        {
            let namaBaru = newText
            switch item.identifier {
            case "ringkasanKelas": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanKelas")
            case "ringkasanSiswa": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanSiswa")
            case "ringkasanGuru": UserDefaults.standard.setValue(namaBaru, forKey: "sidebarRingkasanGuru")
            default: break
            }
            item.name = namaBaru
            outlineView.reloadItem(item)
            outlineView.selectRowIndexes(IndexSet(integer: outlineView.selectedRow), byExtendingSelection: false)
        }
    }

    func overlayEditorManager(_: OverlayEditorManager, perbolehkanEdit _: Int, row _: Int) -> Bool {
        true
    }

    func overlayEditorManager(_: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in _: NSTableView) -> String {
        guard let cell = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else { return "return" }
        return cell.textField?.stringValue ?? ""
    }

    func overlayEditorManager(_: OverlayEditorManager, originalColumnWidthForCellAtRow _: Int, column: Int, in _: NSTableView) -> CGFloat {
        outlineView.tableColumns[column].width
    }
}

extension SidebarViewController: KelasVCDelegate {
    /// Fungsi untuk menangani pembaruan tabel kelas.
    /// Fungsi ini akan dipanggil ketika tabel kelas diperbarui, dan akan memperbarui pemilihan item di outlineView.
    /// Fungsi ini akan memastikan bahwa item yang diperbarui tidak sama dengan item yang saat ini dipilih di outlineView.
    /// Jika item yang diperbarui adalah item yang saat ini dipilih, maka tidak akan ada perubahan pada pemilihan.
    /// - Parameter item: Item kelas di sidebar yang diperbarui.
    func didUpdateTable(_ item: SidebarIndex) {
        // Pastikan kita tidak mencoba memilih ulang baris yang sudah terpilih
        // Ini penting karena outlineView.selectedRow adalah indeks baris visual,
        // bukan nilai dari SidebarIndex itu sendiri.
        // Kita akan mencari indeks baris yang benar di langkah berikutnya.
        // Untuk saat ini, kita bisa menghilangkan guard ini atau mengubahnya
        // setelah kita menemukan indeks baris yang sesuai.
        // guard index.rawValue != outlineView.selectedRow else { return } // Ini akan diubah

        // 1. Temukan item yang sesuai dengan SidebarIndex
        // Anda perlu sebuah cara untuk mencari objek SidebarItem atau ParentItem
        // yang memiliki 'index' yang cocok dengan 'item' yang diberikan.

        var foundItem: Any? = nil // Bisa berupa SidebarItem atau ParentItem

        // Contoh sederhana (asumsi sidebarItems sudah terisi dan terstruktur dengan benar)
        // Anda mungkin perlu fungsi pembantu untuk mencari secara rekursif jika ada item nested dalam grup.
        for parentItem in sidebarItems {
            let children = parentItem.children
            for child in children {
                if child.index == item {
                    foundItem = child
                    break
                }
            }
            if foundItem != nil { break }
        }

        guard let itemToSelect = foundItem else {
            #if DEBUG
                print("Error: Tidak dapat menemukan item di sidebar dengan SidebarIndex: \(item.rawValue)")
            #endif
            return
        }

        // 2. Dapatkan indeks baris (row index) untuk item yang ditemukan
        let rowIndex = outlineView.row(forItem: itemToSelect)

        // Periksa apakah item ditemukan di outline view
        guard rowIndex != NSNotFound else {
            #if DEBUG
                print("Error: Item tidak ditemukan di outlineView untuk SidebarIndex: \(item.rawValue)")
            #endif
            return
        }

        // Sekarang, Anda bisa menggunakan rowIndex ini untuk kondisi guard awal
        guard rowIndex != outlineView.selectedRow else { return }

        // 3. Pilih baris di main thread
        DispatchQueue.main.async { [unowned self] in
            outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
        }
    }

    /// Fungsi untuk menangani penyelesaian pembaruan pada kelas.
    func didCompleteUpdate() {
        // Tangani penyelesaian pembaruan di sini
    }
}
