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
    func didSelectSidebarItem(index: Int)
    func didSelectKelasItem(index: Int)
}

/// Protokol untuk menangani pembaruan pada kelas, mendefinisikan metode yang akan dipanggil ketika tabel kelas diperbarui,
/// dan juga mendefinisikan metode yang akan dipanggil ketika pembaruan selesai.
protocol KelasVCDelegate: AnyObject {
    func didUpdateTable(_ index: Int)
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
    /// Setiap grup diwakili oleh kelas yang mengadopsi protokol SidebarGroup, seperti AdministrasiParentItem, DaftarParentItem, StatistikParentItem, dan KelasParentItem.
    /// Item ini juga menyimpan informasi tentang grup dan item yang akan ditampilkan di sidebar.
    var sidebarItems: [Any] = []

    /// Identifier untuk jendela yang menampilkan sidebar.
    var windowIdentifier: String?

    /// Indeks item sidebar yang dipilih saat ini.
    /// Nilai ini disimpan di UserDefaults untuk mempertahankan status pemilihan antara sesi aplikasi.
    /// Nilai defaultnya adalah 11, yang berarti item dengan indeks 11 akan dipilih secara default.
    var selectedOutlineItemIndex: Int = 11 {
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
            for sidebarItem in sidebarItems {
                outlineView.expandItem(sidebarItem)
            }
            UserDefaults.standard.set(true, forKey: "expandedItems")
        }
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
                self.editorManager?.startEditing(row: row, column: column)
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

        if !isExpanding, shouldUpdateDelegate {
            if let selectedItem = selectedSidebarItem {
                if let indexToOpen = indexToOpenForSidebarItem(selectedItem) {
                    delegate?.didSelectSidebarItem(index: indexToOpen)
                    UserDefaults.standard.set(selectedIndex, forKey: "SelectedOutlineItemIndex")
                }
            }
        }
    }

    /// Fungsi untuk menangani pemilihan kelas yang diperbarui melalui notifikasi.
    /// Fungsi ini akan dipanggil ketika notifikasi "selectClass" diterima.
    /// - Parameter notification: Objek `Notification` yang berisi informasi tentang kelas yang diperbarui.
    @objc func selectClass(_ notification: Notification) {
        guard let updatedClass = notification.userInfo?["updatedClass"] as? Int else { return }
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
                cell.textField?.isEditable = false
                cell.imageView?.image = dataNode.image // Tambahkan gambar ke sel
                return cell
            }
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is SidebarGroup
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
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

    /// Fungsi untuk mendapatkan indeks yang akan dibuka berdasarkan item sidebar yang dipilih.
    /// - Parameter sidebarItem: Item sidebar yang dipilih.
    /// - Returns: Indeks yang sesuai untuk item sidebar yang dipilih, atau `nil` jika tidak ada indeks yang sesuai.
    func indexToOpenForSidebarItem(_ sidebarItem: SidebarItem) -> Int? {
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

    /// Action menu `Pengaturan...` untuk menampilkan bantuan aplikasi.
    /// Fungsi ini akan mencari menu bantuan di menu bar aplikasi dan mengirimkan aksi untuk menampilkan bantuan.
    /// - Parameter sender: Objek pemicu.
    @IBAction func bantuanApl(_ sender: Any) {
        guard let mainMenu = NSApp.mainMenu,
              let menuItem = mainMenu.items.first(where: {
                  $0.identifier?.rawValue == "bantuan"
              }),
              let menu = menuItem.submenu,
              let preferensiMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "tampilkanBantuan" })
        else { return }
        NSApp.sendAction(preferensiMenuItem.action!, to: preferensiMenuItem.target, from: self)
    }

    /// Action menu `Bantuan Aplikasi` untuk membuka pengaturan aplikasi.
    /// Fungsi ini akan mencari menu preferensi di menu bar aplikasi dan mengirimkan aksi untuk membuka pengaturan.
    /// - Parameter sender: Objek pemicu.
    @IBAction func openSetting(_ sender: Any) {
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
    /// Fungsi ini akan memulai proses pengeditan nama item sidebar yang dipilih dengan menggunakan `OverlayEditorManager`.
    /// - Parameter sender: Objek pemicu.
    /// Fungsi ini akan memeriksa apakah item yang dipilih adalah bagian dari grup StatistikParentItem sebelum memulai pengeditan.
    /// Jika item yang dipilih bukan bagian dari grup StatistikParentItem, maka fungsi ini tidak akan melakukan apa-apa.
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

/// Struktur untuk menyimpan nama-nama grup sidebar yang digunakan dalam aplikasi.
/// Struktur ini berisi nama-nama grup yang digunakan dalam sidebar, seperti "Transaksi", "Daftar", "Ringkasan", dan "Kelas Aktif".
enum NameConstants {
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
              let ubahNamaItem = menu.items.first(where: { $0.identifier?.rawValue == "ubahnama" })
        else {
            menu.items.first(where: { $0.identifier?.rawValue == "bantuan" })?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "preferensi" })?.isHidden = false
            menu.items.first(where: { $0.identifier?.rawValue == "ubahnama" })?.isHidden = true
            return
        }

        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? SidebarItem,
              outlineView.parent(forItem: item) is StatistikParentItem
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
        ubahNamaItem.title = "Ubah nama \"\(item.name)\""
    }
}

extension SidebarViewController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        if let item = outlineView.item(atRow: row) as? SidebarItem,
           outlineView.parent(forItem: item) is StatistikParentItem
        {
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
        true
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let cell = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else { return "return" }
        return cell.textField?.stringValue ?? ""
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        outlineView.tableColumns[column].width
    }
}

extension SidebarViewController: KelasVCDelegate {
    /// Fungsi untuk menangani pembaruan tabel kelas.
    /// Fungsi ini akan dipanggil ketika tabel kelas diperbarui, dan akan memperbarui pemilihan item di outlineView.
    /// Fungsi ini akan memastikan bahwa item yang diperbarui tidak sama dengan item yang saat ini dipilih di outlineView.
    /// Jika item yang diperbarui adalah item yang saat ini dipilih, maka tidak akan ada perubahan pada pemilihan.
    /// - Parameter index: Indeks item yang diperbarui di tabel kelas.
    func didUpdateTable(_ index: Int) {
        guard index != outlineView.selectedRow else { return }
        DispatchQueue.main.async { [unowned self] in
            outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        UserDefaults.standard.set(index, forKey: "SelectedOutlineItemIndex")
    }

    /// Fungsi untuk menangani penyelesaian pembaruan pada kelas.
    func didCompleteUpdate() {
        // Tangani penyelesaian pembaruan di sini
    }
}
