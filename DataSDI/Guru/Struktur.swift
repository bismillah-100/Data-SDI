//
//  Struktur.swift
//  Data Manager
//
//  Created by Bismillah on 28/11/23.
//

import Cocoa

/// Class yang mengelola struktur guru.
class Struktur: NSViewController {
    /// Singleton untuk mengakses database.
    let dbController = DatabaseController.shared
    /// Model yang menyimpan data guru.
    var guruData: [GuruModel] = []
    /// Dictionary yang menyimpan guru berdasarkan struktural.
    var strukturalDict: [String: [GuruModel]] = [:]
    /// Array yang menyimpan hierarki struktural guru.
    var hierarkiStruktural: [(struktural: String, guruList: [GuruModel])] = []
    /// Menu item yang digunakan untuk menampilkan menu konteks.
    @IBOutlet var menuItem: NSMenu!
    /// Outlet untuk NSOutlineView yang menampilkan struktur guru.
    @IBOutlet weak var outlineView: NSOutlineView!
    /// Outlet untuk NSStackView yang menampilkan ``label``.
    @IBOutlet weak var labelStack: NSStackView!
    /// Outlet untuk NSMenuItem yang digunakan untuk filter tahun.
    @IBOutlet weak var filterTahun: NSMenuItem!
    /// Outlet untuk NSBox yang digunakan sebagai garis horizontal di antara ``labelStack`` dan ``outlineView``.
    @IBOutlet weak var hLine: NSBox!
    /// Outlet untuk NSTextField yang menampilkan label struktur guru.
    @IBOutlet weak var label: NSTextField!
    /// Outlet untuk NSScrollView yang menampilkan ``outlineView``.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk NSVisualEffectView yang digunakan untuk efek visual pada header.
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    /// Variabel yang menandakan apakah data sudah dimuat.
    var isDataLoaded: Bool = false
    /// Menu yang digunakan untuk toolbar.
    var toolbarMenu = NSMenu()
    /// Outlet constraint untuk jarak atas dari stack header.
    @IBOutlet weak var stackHeaderTopConstraint: NSLayoutConstraint!

    /// Variabel yang menyimpan tahun terpilih, diambil dari UserDefaults.
    /// Jika tidak ada nilai yang disimpan, akan menggunakan tahun saat ini.
    var tahunTerpilih: Int = UserDefaults.standard.integer(forKey: "tahunTerpilih") {
        didSet {
            UserDefaults.standard.setValue(tahunTerpilih, forKey: "tahunTerpilih")
            label.stringValue = "Struktur Guru Tahun \(tahunTerpilih)"
        }
    }

    /// Urutan struktural yang digunakan untuk menentukan prioritas dalam hierarki.
    /// Urutan ini digunakan untuk mengurutkan guru berdasarkan jabatan struktural mereka.
    /// Urutan ini akan digunakan untuk menentukan prioritas dalam tampilan hierarki.
    let urutanStruktural: [String] = ["Pelindung", "Kepala Sekolah", "Wakil Kepala Sekolah", "Sekretaris", "Bendahara"]

    /// Array yang menyimpan tahun aktif guru.
    /// Tahun aktif ini diambil dari database dan digunakan untuk filter tahun.
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
        label.alphaValue = 0.6
        visualEffect.material = .headerView
        // Do view setup here.
    }

    override func viewWillAppear() {
        if !isDataLoaded {
            DispatchQueue.main.async {
                self.muatUlang(self)
            }
            label.stringValue = "Struktur Guru Tahun \(tahunTerpilih)"
        }
    }

    override func viewDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.view.window?.makeFirstResponder(self.outlineView)
        }
        ReusableFunc.resetMenuItems()
        guard let toolbar = view.window?.toolbar else { return }
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
        {
            let searchField = searchFieldToolbarItem.searchField
            searchField.placeholderAttributedString = nil
            searchField.delegate = nil
            searchField.placeholderString = "Struktur Guru"
            searchField.isEditable = false
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl
        {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
           let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
        {
            kalkulasiNilai.isEnabled = false
        }

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

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton
        {
            tambah.isEnabled = false
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton
        {
            add.isEnabled = false
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
        {
            popUpButton.menu = toolbarMenu
        }
    }

    /// Fungsi untuk memperbarui menu ``filterTahun``.
    /// Fungsi ini akan mengambil tahun aktif dari database, menghapus semua subitem dari menu filter tahun,
    /// dan menambahkan subitem untuk setiap tahun yang ditemukan.
    /// Setelah itu, fungsi ini juga akan memperbarui menu filter tahun di toolbar.
    /// Pastikan untuk memanggil fungsi ini setelah data guru diambil dari database.
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

    /// Fungsi untuk memperbarui menu filter tahun pada toolbar menu ``toolbarMenu``.
    /// Fungsi ini akan mengambil tahun aktif dari database, menghapus semua subitem dari menu filter tahun pada toolbar,
    /// dan menambahkan subitem untuk setiap tahun yang ditemukan.
    /// Fungsi ini juga akan memperbarui status subitem berdasarkan tahun terpilih.
    /// Jika tidak ada tahun terpilih, maka akan menampilkan tahun aktif saat ini.
    func updateFilterTahunToolbarMenu() {
        tahunAktif = dbController.getTahunAktifGuru()
        // Hapus semua subitem dari filterTahun
        guard let filterTahunToolbar = toolbarMenu.items.first(where: { $0.title == "Tahun" }) else { return }
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

    /// Fungsi untuk mendapatkan prioritas struktural berdasarkan nama struktural.
    /// - Parameter struktural: Nama struktural yang ingin diperiksa.
    /// - Returns: Prioritas struktural sebagai `Int`.
    func prioritasStruktural(for struktural: String) -> Int {
        if let index = urutanStruktural.firstIndex(of: struktural) {
            return index // Memberikan prioritas sesuai dengan urutan
        }
        return urutanStruktural.count // Jika tidak ada dalam urutanStruktural, beri prioritas paling tinggi
    }

    /// Menyaring data berdasarkan tahun yang dipilih dari menu.
    /// - Parameter sender: Objek `NSMenuItem` yang merepresentasikan tahun yang dipilih oleh pengguna.
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

    /// Mengambil data guru berdasarkan tahun yang diberikan.
    /// - Parameter tahun: Tahun yang digunakan sebagai filter data. Jika tidak diisi, akan mengambil semua data guru.
    /// - Note: Fungsi ini berjalan secara asynchronous.
    func fetchGuru(_ tahun: String = "") async {
        await Task { [weak self] in
            guard let self else { return }
            self.guruData = self.dbController.getGuru(forYear: !tahun.isEmpty ? tahun : String(self.tahunTerpilih))
        }.value
    }

    /// Membangun dan menginisialisasi dictionary secara asynchronous.
    /// Fungsi ini digunakan untuk membuat struktur data dictionary yang diperlukan,
    /// serta melakukan proses inisialisasi data secara asynchronous.
    /// - Note: Pastikan pemanggilan fungsi ini dilakukan di dalam konteks asynchronous.
    func buildDict() async {
        await Task { [weak self] in
            guard let self else { return }
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

    /// Membangun hierarki data secara asinkron.
    ///
    /// Fungsi ini digunakan untuk membangun struktur hierarki yang diperlukan.
    /// Proses dilakukan secara asinkron untuk memastikan performa aplikasi tetap optimal.
    func buildHierarchy() async {
        // Siapkan hierarki dan urutkan
        await Task { [weak self] in
            guard let self else { return }
            self.hierarkiStruktural.removeAll()
            for (struktural, guruList) in self.strukturalDict {
                self.hierarkiStruktural.append((struktural: struktural, guruList: guruList))
            }
            self.hierarkiStruktural.sort { a, b -> Bool in
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

    /// Membangun tampilan outline view untuk menampilkan struktur data.
    /// Fungsi ini bertanggung jawab untuk menginisialisasi dan mengatur komponen outline view
    /// sesuai dengan kebutuhan aplikasi.
    /// Pastikan data sumber telah tersedia sebelum memanggil fungsi ini.
    func buildOutlineView() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.outlineView.reloadData()
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.outlineView.beginUpdates()
            self.outlineView.animator().expandItem(nil, expandChildren: true)
            self.outlineView.endUpdates()
        }
    }

    /// Fungsi untuk memuat ulang data guru dan membangun struktur hierarki.
    /// Fungsi ini akan mengambil data guru dari database, membangun dictionary berdasarkan struktural,
    /// dan membangun hierarki struktural. Setelah itu, outline view akan diperbarui untuk menampilkan data yang baru.
    /// - Parameter sender: Objek yang memicu aksi ini.
    @IBAction func muatUlang(_ sender: Any) {
        Task(priority: .background) { [unowned self] in
            await self.fetchGuru()
            await self.buildDict()
            await self.buildHierarchy()

            self.buildOutlineView()
        }
    }

    /// Menangani aksi ketika menu "Salin" dipilih oleh pengguna.
    /// - Parameter sender: NSMenuItem yang memicu aksi ini.
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

    /// Menyalin data berdasarkan baris yang dipilih.
    ///
    /// - Parameter row: Kumpulan indeks baris yang akan disalin.
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

    /// Menyalin seluruh data yang tersedia.
    ///
    /// Fungsi ini dipicu ketika pengguna menekan tombol "Salin Semua".
    /// Biasanya digunakan untuk menyalin semua informasi yang ditampilkan ke clipboard.
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya tombol pada antarmuka pengguna.
    @IBAction func salinSemua(_ sender: Any) {
        // Variabel untuk menampung teks hasil salinan
        var salinan: [String] = []
        salinan.append("Struktur Guru Tahun \(String(tahunTerpilih)):")
        // Iterasi melalui data hierarki
        for strukturalItem in hierarkiStruktural {
            // Tambahkan nama struktural ke salinan
            salinan.append("\n\(strukturalItem.struktural):")

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

    /// Fungsi yang dipanggil ketika nilai segmented control berubah.
    /// Fungsi ini akan memanggil fungsi `increaseSize` atau `decreaseSize` sesuai dengan segment yang dipilih.
    /// - Parameter sender: NSSegmentedControl yang memicu aksi ini.
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

    /// Fungsi untuk memperbesar ukuran baris pada outline view.
    /// - Parameter sender: Objek pemicu.
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.outlineView.rowHeight += 5
            self.outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< self.outlineView.numberOfRows))
        }
        saveRowHeight()
    }

    /// Fungsi untuk memperkecil ukuran baris pada outline view.
    /// - Parameter sender: Objek pemicu.
    @IBAction func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.outlineView.rowHeight = max(self.outlineView.rowHeight - 5, 16)
            self.outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< self.outlineView.numberOfRows))
        }
        saveRowHeight()
    }

    /// Fungsi untuk menyimpan tinggi baris outline view ke UserDefaults.
    func saveRowHeight() {
        UserDefaults.standard.setValue(outlineView.rowHeight, forKey: "StrukturOutlineViewRowHeight")
    }

    deinit {
        guruData.removeAll()
        hierarkiStruktural.removeAll()
        strukturalDict.removeAll()
        NotificationCenter.default.removeObserver(self)
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
        item is (struktural: String, guruList: [GuruModel])
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
                var leadingConstant: CGFloat = 5
                if item is (struktural: String, guruList: [GuruModel]) {
                    leadingConstant = 5
                }

                // Menghapus constraint yang sudah ada untuk mencegah duplikasi
                for constraint in cell.constraints {
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
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
                for constraint in cell.constraints {
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20),
                ])

                textField.stringValue = guruItem.namaGuru
                textField.font = NSFont.systemFont(ofSize: 13) // Opsi: Teks normal untuk child
                return cell
            }
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        outlineView.rowHeight
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

    /// Fungsi untuk memperbarui menu tabel berdasarkan kondisi saat ini.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan menyesuaikan visibilitas item menu sesuai dengan kondisi tersebut.
    /// Jika tidak ada baris yang dipilih, maka akan menampilkan item filter, muat ulang, dan salin semua.
    /// Jika ada baris yang dipilih, maka akan menampilkan item salin dengan jumlah baris yang dipilih.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateTableMenu(_ menu: NSMenu) {
        guard let filterItem = menu.items.first(where: { $0.title == "Filter" }), let muatUlang = menu.items.first(where: { $0.title == "Muat Ulang" }), let salinSemua = menu.items.first(where: { $0.title == "Salin Semua" }), let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) else { return }

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

    /// Fungsi untuk memperbarui menu toolbar berdasarkan kondisi saat ini.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan menyesuaikan visibilitas item menu sesuai dengan kondisi tersebut.
    /// Jika tidak ada baris yang dipilih, maka akan menampilkan item filter, muat ulang, dan salin semua.
    /// Jika ada baris yang dipilih, maka akan menampilkan item salin dengan jumlah baris yang dipilih.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateToolbarMenu(_ menu: NSMenu) {
        guard let filterTahunToolbar = menu.items.first(where: { $0.title == "Tahun" }), let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) else { return }

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

    /// Fungsi untuk memperbarui item menu "Salin" pada menu utama.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan mengaktifkan atau menonaktifkan item menu "Salin" sesuai dengan kondisi tersebut.
    /// Jika ada baris yang dipilih, item menu "Salin" akan diaktifkan dan diarahkan ke fungsi `salinMenu`.
    /// Jika tidak ada baris yang dipilih, item menu "Salin" akan dinonaktifkan.
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya berupa menu item.
    /// - Note: Pastikan untuk memanggil fungsi ini ketika ada perubahan pada pemilihan baris di outline view.
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" })
        {
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
