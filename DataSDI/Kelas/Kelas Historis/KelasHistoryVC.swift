//
//  KelasHistoryVC.swift
//  Data SDI
//
//  Created by MacBook on 30/07/25.
//

import Cocoa

/// View Controller untuk menampilkan riwayat kelas
///
/// View Controller ini bertanggung jawab untuk mengelola tampilan dan interaksi yang berhubungan dengan
/// riwayat atau histori kelas yang pernah ada.
class KelasHistoryVC: NSViewController {
    /// Outlet tombol untuk memilih kelas.
    @IBOutlet weak var kelasPopup: NSPopUpButton!
    /// Outlet judul ``DataSDI/KelasHistoryVC``.
    @IBOutlet weak var kelasTitle: NSTextField!
    /// Outlet textField tahun ajaran.
    @IBOutlet weak var tahunAjaranTextField1: NSTextField!
    /// Outlet textField tahun ajaran.
    @IBOutlet weak var tahunAjaranTextField2: NSTextField!

    /// Properti untuk menyimpan tahun ajaran sebelumnya ke-1
    /// Nilai akan otomatis tersimpan ke UserDefaults dengan key "ThnAjrn1-KelasHistoris" saat nilainya berubah
    var previousTahunAjaran1: String? {
        didSet {
            ud.setValue(previousTahunAjaran1, forKey: "ThnAjrn1-KelasHistoris")
        }
    }

    /// Menyimpan tahun ajaran sebelumnya yang kedua
    /// - Property ini akan otomatis menyimpan nilainya ke UserDefaults saat nilainya diubah
    /// - UserDefaults key: "ThnAjrn2-KelasHistoris"
    var previousTahunAjaran2: String? {
        didSet {
            ud.setValue(previousTahunAjaran2, forKey: "ThnAjrn2-KelasHistoris")
        }
    }

    /// TableView yang menampilkan histori data kelas.
    var tableView: NSTableView!
//    /// ScrollView yang memuat ``tableView``.
//    var scrollView: NSScrollView!

    /// Menu untuk ``tableView``.
    var tableMenu: NSMenu!
    /// Menu untuk action toolbar.
    var toolbarMenu: NSMenu!

    /// ``TableType`` yang sedang aktif sesuai kelas.
    var activeTableType: TableType!

    /// Instansi viewModel ``KelasViewModel`` yang bertanggung jawab
    /// untuk mengelola data yang ditampilkan di ``tableView``.
    let viewModel: KelasViewModel = .shared

    /// `DispatchWorkItem` yang hanya dapat diakses dari
    /// ``DataSDI/KelasHistoryVC``.
    var workItem: DispatchWorkItem?

    /// Teks pencarian.
    var searchText: String = ""

    /// UserDefaults.standard
    private let ud: UserDefaults = .standard

    /// Properti untuk menyimpan referensi jika data telah dimuat.
    private var isDataLoaded: Bool = false

    override func loadView() {
        super.loadView()
        // 2. Prepare single‐table nib
        let tableNib = NSNib(nibNamed: "SingleTableView", bundle: nil)

        // 3. Untuk tiap tab, instantiate tableNib

        var tlObjects: NSArray?
        tableNib?.instantiate(withOwner: nil, topLevelObjects: &tlObjects)

        // Ambil scrollView & tableView
        guard let scrollView = tlObjects?
            .first(where: { $0 is NSScrollView }) as? NSScrollView,
            let table = scrollView.documentView as? NSTableView
        else {
            return
        }

        // Tambah scrollView ke dalam tabViewItem(i).view
        view.addSubview(scrollView, positioned: .below, relativeTo: nil)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsets.top = 79

        guard let superView = scrollView.superview else { return }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: superView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: superView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
        ])

        table.autosaveName = "KelasHistoris-NSTableView"
        table.autosaveTableColumns = true
        table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle

        tableView = table
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        tahunAjaranTextField1.delegate = self
        tahunAjaranTextField2.delegate = self

        let a = ud.string(forKey: "ThnAjrn1-KelasHistoris") ?? ""
        let b = ud.string(forKey: "ThnAjrn2-KelasHistoris") ?? ""

        tahunAjaranTextField1.stringValue = a
        tahunAjaranTextField2.stringValue = b

        previousTahunAjaran1 = a
        previousTahunAjaran2 = b

        ud.register(defaults: ["Selected-KelasHistoris": "Kelas 1"])

        if let userDefaultSelectedKelas = ud.string(forKey: "Selected-KelasHistoris") {
            kelasPopup.selectItem(withTitle: userDefaultSelectedKelas)

            TableType.fromString(userDefaultSelectedKelas) { type in
                activeTableType = type
            }
        }
        // Do view setup here.
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = "Histori Data Kelas"

        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: false)

            setupTable()

            ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(toggleColumnVisibility(_:)))

            muatUlang(self)
        }

        kelasTitle.stringValue = kelasPopup.titleOfSelectedItem ?? "Tidak ada Kelas yang dipilih."
        setupToolbar()
        view.window?.makeFirstResponder(tableView)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        viewModel.clearArsipKelas(exept: activeTableType)
    }

    /// Mengatur tampilan dan konfigurasi tabel
    ///
    /// Fungsi ini melakukan beberapa hal:
    /// - Mengatur descriptor pengurutan
    /// - Menyiapkan sel header kustom untuk setiap kolom
    /// - Mengatur gaya pengubahan ukuran kolom secara otomatis
    /// - Membuat dan mengatur menu konteks untuk tabel dan toolbar
    /// - Memulihkan tinggi baris tabel yang tersimpan dari UserDefaults
    ///
    /// Menu konteks yang dibuat akan didelegasikan ke view controller ini sebagai delegate-nya.
    /// Tinggi baris tabel akan diambil dari UserDefaults dengan key "KelasHistoris-TableViewRowHeight" jika tersedia.
    func setupTable() {
        setupSortDescriptor()
        for columnInfo in ReusableFunc.columnInfos {
            guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else { continue }
            let customHeaderCell = MyHeaderCell()
            customHeaderCell.title = columnInfo.customTitle
            column.headerCell = customHeaderCell
        }

        tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle

        /// ** NSMenu
        tableMenu = buatMenu()
        tableMenu.delegate = self
        tableView.menu = tableMenu
        toolbarMenu = buatMenu()
        toolbarMenu.delegate = self

        if let savedRowHeight = UserDefaults.standard.value(forKey: "KelasHistoris-TableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }
    }

    /// Fungsi ini menangani aksi toggle visibilitas kolom pada tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc
    func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        if column.identifier.rawValue == "namasiswa" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }

    ///  Fungsi untuk mengatur toolbar pada window controller.
    func setupToolbar() {
        guard let wc = view.window?.windowController as? WindowController else { return }

        wc.searchField.isEnabled = true
        wc.searchField.isEditable = true
        wc.searchField.target = self
        wc.searchField.action = #selector(procSearchField(_:))
        wc.searchField.delegate = self
        wc.searchField.placeholderString = "Arsip Kelas Aktif"

        wc.tambahSiswa.isEnabled = false
        wc.tambahSiswa.toolTip = ""
        wc.tambahDetaildiKelas.isEnabled = false
        wc.actionPopUpButton.menu = toolbarMenu
        wc.tmbledit.isEnabled = false

        // Kalkulasi nilai kelas
        wc.kalkulasiButton.isEnabled = true

        wc.hapusToolbar.isEnabled = false
        wc.hapusToolbar.target = nil
        wc.hapusToolbar.action = nil

        wc.segmentedControl.isEnabled = true
        wc.segmentedControl.target = self
        wc.segmentedControl.action = #selector(segmentedControlValueChanged(_:))
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/KelasHistoryVC``.
    @objc func updateMenuItem() {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let deleteMenuItem = ReusableFunc.deleteMenuItem
        {
            let adaBarisDipilih = tableView.selectedRowIndexes.count > 0
            deleteMenuItem.isEnabled = adaBarisDipilih
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salin(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
            }
        }
    }

    /// Mengatur deskriptor pengurutan untuk kolom-kolom pada `tableView`
    ///
    /// Fungsi ini mengambil deskriptor pengurutan dari `viewModel` dan
    /// mengaitkannya dengan setiap kolom dalam `tableView`. Selain itu,
    /// fungsi ini juga memuat deskriptor pengurutan yang mungkin telah
    /// disimpan sebelumnya. Jika tidak ada deskriptor yang ditemukan,
    /// fungsi ini akan menggunakan deskriptor default.
    func setupSortDescriptor() {
        // Mengambil deskriptor pengurutan dari viewModel
        let identifikasiKolom = viewModel.setupSortDescriptors()
        let tableColumn = tableView.tableColumns
        // Mengiterasi setiap kolom dalam tableView
        for column in tableColumn {
            let identifikasi = column.identifier // Mendapatkan identifikasi kolom
            let pengidentifikasi = identifikasiKolom[identifikasi] // Mencari deskriptor pengurutan yang sesuai
            column.sortDescriptorPrototype = pengidentifikasi // Mengatur deskriptor pengurutan untuk kolom
        }

        // Memuat deskriptor pengurutan yang tersimpan
        guard let sortDescriptor = ReusableFunc.loadSortDescriptor(
            forKey: "KelasHistoris-SortDescriptor", // Kunci untuk mengambil deskriptor
            defaultKey: "namasiswa" // Kunci default jika tidak ada deskriptor yang tersimpan
        ) else { return } // Keluar jika tidak ada deskriptor yang ditemukan

        // Menetapkan deskriptor pengurutan di tableView
        tableView.sortDescriptors = [sortDescriptor]
    }

    /// Mengambil data dan memperbarui tampilan tabel berdasarkan tahun ajaran yang dipilih
    /// - Parameter tahunAjaran: String tahun ajaran yang akan difilter
    /// - Important: Fungsi ini berjalan secara asynchronous
    ///
    /// Fungsi ini melakukan beberapa operasi secara berurutan:
    /// 1. Memuat data arsip kelas berdasarkan tipe tabel aktif dan tahun ajaran
    /// 2. Mengurutkan data yang telah dimuat
    /// 3. Memperbarui tampilan tabel pada thread utama
    /// 4. Menutup progress window setelah delay 300ms
    ///
    /// - Note: Progress window akan ditutup hanya jika window view tersedia
    func fetchDataAndReloadTable(_ tahunAjaran: String) async {
        await viewModel.loadArsipKelas(activeTableType, tahunAjaran: tahunAjaran)
        await sortData()
        await MainActor.run {
            tableView.reloadData()
            isDataLoaded = true
        }
        if let window = view.window {
            try? await Task.sleep(nanoseconds: 30_000_000)
            await MainActor.run {
                ReusableFunc.closeProgressWindow(window)
            }
        }
    }

    /// Mengurutkan data kelas historis berdasarkan descriptor pengurutan yang aktif di table view
    ///
    /// Fungsi ini melakukan pengurutan data kelas historis menggunakan sort descriptor yang dipilih pada table view.
    /// Jika tidak ada sort descriptor yang aktif, data akan diurutkan berdasarkan nama siswa secara ascending.
    /// Setelah pengurutan, data yang sudah terurut akan di-update ke dalam view model.
    ///
    /// Properti yang digunakan untuk pengurutan:
    /// - `namasiswa`: Nama siswa sebagai default pengurutan
    ///
    /// - Note: Fungsi ini berjalan secara asynchronous
    func sortData() async {
        let sortDesc = tableView.sortDescriptors.first ?? NSSortDescriptor(key: "namasiswa", ascending: true)

        guard let model = viewModel.arsipKelasData[activeTableType] else { return }
        let sortedModel = viewModel.sortModel(model, by: sortDesc)

        viewModel.setModel(sortedModel, for: activeTableType, arsip: true)
    }

    /**
     Menggabungkan dua tahun ajaran menjadi satu string dengan format "tahun1/tahun2".

     Fungsi ini mengambil nilai dari dua text field tahun ajaran, memeriksa apakah kedua nilai tersebut:
     - Tidak kosong
     - Hanya berisi angka

     - Returns: String dengan format "tahun1/tahun2" jika kedua input valid, atau `nil` jika salah satu kondisi tidak terpenuhi.
     */
    private func setTahunAjaran() -> String? {
        let thnAjrn1 = tahunAjaranTextField1.stringValue
        let thnAjrn2 = tahunAjaranTextField2.stringValue

        guard !thnAjrn1.isEmpty, !thnAjrn2.isEmpty,
              thnAjrn1.allSatisfy(\.isNumber),
              thnAjrn2.allSatisfy(\.isNumber)
        else { return nil }

        return thnAjrn1 + "/" + thnAjrn2
    }

    /// Fungsi ini menangani aksi untuk memuat ulang data kelas historis
    /// - Parameter sender: Objek yang memicu aksi ini
    ///
    /// Fungsi akan:
    /// 1. Memvalidasi kelas yang dipilih dan tahun ajaran
    /// 2. Menampilkan progress window jika data sebelumnya sudah dimuat
    /// 3. Mengkonversi string kelas ke enum TableType
    /// 4. Memperbarui activeTableType
    /// 5. Memulai task background untuk mengambil dan memuat ulang data tabel
    ///
    /// Jika validasi gagal, fungsi akan menutup progress window (jika ada) dan keluar
    @IBAction
    func muatUlang(_: Any) {
        guard let kelas = kelasPopup.titleOfSelectedItem,
              let tahunAjaran = setTahunAjaran()
        else {
            if let window = view.window {
                ReusableFunc.closeProgressWindow(window)
            }
            return
        }

        if isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: false)
        }

        TableType.fromString(kelas) { type in
            activeTableType = type
            Task(priority: .background, operation: { [weak self] in
                guard let self else { return }
                await fetchDataAndReloadTable(tahunAjaran)
            })
        }
    }

    /// Menangani aksi ketika user memilih kelas dari popup button
    /// - Parameter sender: NSPopUpButton yang memicu aksi ini
    /// - Note: Fungsi ini akan:
    /// 1. Memperbarui label judul kelas
    /// 2. Memuat ulang data
    /// 3. Mengatur state visual dari menu item
    /// 4. Menyimpan pilihan kelas ke UserDefaults
    @IBAction
    func didSelectKelas(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? "Tidak ada Kelas yang dipilih."

        kelasTitle.stringValue = title
        muatUlang(sender)

        sender.menu?.items.forEach { $0.state = .off }
        sender.menu?.item(withTitle: title)?.state = .on

        ud.setValue(title, forKey: "Selected-KelasHistoris")
    }

    /**
     Menangani perubahan nilai dari segmented control untuk mengatur ukuran baris tabel.

     Fungsi ini dipanggil ketika pengguna berinteraksi dengan segmented control dan mengubah ukuran baris tabel:
     - Segmen 0: Mengurangi ukuran tinggi baris tabel
     - Segmen 1: Menambah ukuran tinggi baris tabel

     - Parameter sender: NSSegmentedControl yang memicu aksi ini
     */
    @IBAction
    func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "KelasHistoris-TableViewRowHeight")
        case 1:
            ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "KelasHistoris-TableViewRowHeight")
        default:
            break
        }
    }

    /// Fungsi untuk memperbesar tinggi ``tableView``.
    ///
    /// - Parameter sender: Objek pemicu
    @IBAction
    func increaseSize(_: Any?) {
        ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "KelasHistoris-TableViewRowHeight")
    }

    /// Fungsi untuk memperkecil tinggi ``tableView``.
    ///
    /// - Parameter sender: Objek pemicu.
    @IBAction
    func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "KelasHistoris-TableViewRowHeight")
    }

    /**
     Menampilkan rekapitulasi nilai kelas dalam bentuk popover

     Fungsi ini memunculkan tampilan popover yang berisi rekapitulasi nilai untuk kelas tertentu. Tampilan ini dimuat dari NIB NilaiKelas dan ditampilkan di atas tombol yang memicu aksi.

     - Parameter sender: Objek yang memicu aksi, diharapkan berupa NSButton

     # Alur kerja:
     1. Membuat popover baru
     2. Memuat tampilan NilaiKelas dari NIB
     3. Mengatur properti data yang diperlukan (nama kelas, tahun ajaran)
     4. Menampilkan popover relatif terhadap posisi tombol
     5. Menyembunyikan tombol "inNewWindow"

     - Important: Tombol inNewWindow akan disembunyikan setelah popover ditampilkan
     */
    @IBAction
    func rekapNilai(_ sender: Any) {
        guard let popover = AppDelegate.shared.popoverTableNilaiSiswa,
              let nilaiSiswaVC = popover.contentViewController as? NilaiKelas
        else { return }

        ReusableFunc.resetMenuItems()
        // Setel data StudentSummary untuk ditampilkan
        nilaiSiswaVC.namaKelas = activeTableType.stringValue
        nilaiSiswaVC.tahunAjaran = tahunAjaranTextField1.stringValue + "/" + tahunAjaranTextField2.stringValue
        nilaiSiswaVC.kelasAktif = false

        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            // Objek tampilan harus diset ketika popover sudah siap dan telah ditampilkan.
            nilaiSiswaVC.inNewWindow.isHidden = true
        }
    }
}
