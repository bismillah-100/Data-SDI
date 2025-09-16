//
//  SiswaVC.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa
import Combine

/// Class yang bertanggung jawab menampilkan dan mengelola interaksi untuk semua data siswa baik aktif, berhenti, maupun lulus.
class SiswaViewController: NSViewController, NSDatePickerCellDelegate, DetilWindowDelegate {
    /// Outlet tableView.
    @IBOutlet weak var tableView: EditableTableView!
    /// Outlet scrollView yang memuat ``tableView``.
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

    /// Indeks kolom ``tahunDaftarColumn`` di tableView.
    var columnIndexOfThnDaftar: Int {
        ReusableFunc.columnIndex(of: tahunDaftarColumn, in: tableView)
    }

    /// Indeks kolom ``statusColumn`` di tableView.
    var columnIndexOfStatus: Int {
        ReusableFunc.columnIndex(of: statusColumn, in: tableView)
    }

    /// Indeks kolom ``tglLulusColumn`` di tableView.
    var columnIndexOfTglBerhenti: Int {
        ReusableFunc.columnIndex(of: tglLulusColumn, in: tableView)
    }

    /// Indeks kolom ``namaColumn`` di tableView.
    var columnIndexOfKelasAktif: Int {
        ReusableFunc.columnIndex(of: namaColumn, in: tableView)
    }

    /// *Computed property* untuk akses comparator dengan cepat.
    ///
    /// Penggunaan ini menggunakan func ``SortableKey/comparator(from:)``.
    var comparator: (ModelSiswa, ModelSiswa) -> Bool {
        guard let sortDesc = tableView.sortDescriptors.first else {
            return { $0.nama < $1.nama }
        }
        return ModelSiswa.comparator(from: sortDesc)
            ?? { $0.nama < $1.nama }
    }

    /// Outlet menu item "Edit" yang terdapat di ``itemSelectedMenu`` untuk mengedit data siswa.
    @IBOutlet weak var editItem: NSMenuItem!

    /// Outlet menu "Status" yang terdapat di ``itemSelectedMenu`` yang menampilkan menu item aktif, berhenti, dan lulus.
    @IBOutlet weak var statusMenu: NSMenu!

    /// Outlet menu item "Hapus" yang terdapat di ``itemSelectedMenu`` untuk mengedit data siswa.
    @IBOutlet weak var hapusMenuItem: NSMenuItem!

    /// Outlet menu item "Salin" yang terdapat di ``itemSelectedMenu`` untuk mengedit data siswa.
    @IBOutlet weak var salinMenuItem: NSMenuItem!

    /// Outlet menu untuk ``tableView`` maupun ``WindowController/actionToolbar``.
    @IBOutlet var itemSelectedMenu: NSMenu!

    /// Outlet `NSView` untuk digunakan sebagai menu item yang memuat ``tagMenuItem`` di menu ``tableView`` ``itemSelectedMenu``.
    @IBOutlet var customViewMenu: NSView!

    /// Outlet `NSView` untuk digunakan sebagai menu item yang memuat ``tagMenuItem2`` di menu toolbar ``WindowController/actionToolbar``.
    @IBOutlet var customViewMenu2: NSView!

    /// Menu item pilihan untuk mengubah  kelas aktif siswa di ``WindowController/actionToolbar``.
    let tagMenuItem2: NSMenuItem = .init()

    /// Menu item pilihan untuk mengubah  kelas aktif siswa di ``itemSelectedMenu``.
    let tagMenuItem: NSMenuItem = .init()

    /// Properti untuk menyimpan referensi penggunaan `usesAlternatingRowBackgroundColors` di ``tableView``.
    lazy var useAlternateColor = true

    /// Instance singleton ``DatabaseController``.
    let dbController: DatabaseController = .shared

    /// Properti yang menyimpan indeks baris-baris yang dipilih di ``tableView``
    /// untuk digunakan ketika akan mengedit atau menambahkan data.
    lazy var rowDipilih: [IndexSet] = []

    /// Properti Instance ``SiswaViewModel`` sekaligus initiate nya.
    let viewModel: SiswaViewModel = .shared

    /// Diperlukan oleh ``DataSDI/MyHeaderCell`` dan diset dari ``tableView(_:sortDescriptorsDidChange:)``
    ///
    /// Memeriksa apakah tabel sedang diurutkan pada kolom pertama.
    /// Jika tabel diurutkan pada kolom pertama. Semua teks di section group akan menggunakan teks tebal.
    var isSortedByFirstColumn = false

    /// Properti yang menyimpan kondisi tampilan ``tableView`` saat ini.
    var currentTableViewMode: TableViewMode = .plain {
        didSet {
            viewModel.isGrouped = currentTableViewMode == .grouped
        }
    }

    /// Properti yang menyimpan data-data siswa yang dipilih/diklik
    /// dari ``tableView`` ketika akan diedit.
    lazy var selectedSiswaList: [ModelSiswa] = []

    /// Array nama-nama kelas yang akan digunakan baris grup dalam tampilan grup.
    let kelasNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "Lulus", "Tanpa Kelas"]

    /// Properti teks string ketika toolbar ``WindowController/search``
    /// menerima input pengetikan.
    lazy var stringPencarian: String = ""

    /// Informasi kolom dengan identifier dan title kustom ``tableView``.
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
        ColumnInfo(identifier: "Nomor Telepon", customTitle: "Nomor Telepon"),
    ]

    /**
         * `isBerhentiHidden` adalah variabel yang menentukan apakah siswa yang berhenti ditampilkan atau tidak.
         * Nilai variabel ini disimpan dan diambil dari `UserDefaults` dengan kunci "sembunyikanSiswaBerhenti".
         * Setiap kali nilai variabel ini diubah, nilai tersebut juga diperbarui di `UserDefaults`.
     */
    var isBerhentiHidden = UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
        didSet {
            UserDefaults.standard.setValue(isBerhentiHidden, forKey: "sembunyikanSiswaBerhenti")
        }
    }

    /**
         * `tampilkanSiswaLulus` adalah variabel yang menentukan apakah siswa yang lulus ditampilkan atau tidak.
         * Nilai variabel ini disimpan dan diambil dari `UserDefaults` dengan kunci "tampilkanSiswaLulus".
         * Setiap kali nilai variabel ini diubah, nilai tersebut juga diperbarui di `UserDefaults`.
     */
    var tampilkanSiswaLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
        didSet {
            UserDefaults.standard.setValue(tampilkanSiswaLulus, forKey: "tampilkanSiswaLulus")
        }
    }

    /**
         Variabel ini digunakan untuk menyimpan array dua dimensi dari objek `ModelSiswa`.
         Setiap elemen array luar adalah array dari ``ModelSiswa``, yang mewakili
         kelompok siswa `batch data siswa` yang ditempel (pasted) dari sumber eksternal.
     */
    var pastedSiswasArray: [[ModelSiswa]] = .init()

    /// Digunakan untuk membuat `Data` kosong ketika akan menempelkan data ke tableView.
    lazy var selectedImageData: Data = .init()

    /**
         Variabel ini digunakan untuk menyimpan array dua dimensi dari objek `ModelSiswa`.
         Setiap elemen array luar adalah array dari ``ModelSiswa``, yang mewakili
         kelompok siswa `batch data siswa` yang dihapus setelah melakukan undo.
     */
    var redoDeletedSiswaArray: [[ModelSiswa]] = .init()

    /// Instance `NSOperationQueue`
    let operationQueue: OperationQueue = .init()

    /// Properti untuk menyimpan referensi jika ``viewModel`` telah mendapatkan data yang ada
    /// di database dan telah ditampilkan setiap barisnya di ``tableView``
    var isDataLoaded: Bool = false

    /// Array untuk menyimpan data yang baru ditambahkan untuk keperluan undo/redo.
    var urungsiswaBaruArray: [ModelSiswa] = []
    /// Array untuk menyimpan data yang baru durungkan ditambahkan untuk keperluan undo/redo.
    var ulangsiswaBaruArray: [ModelSiswa] = []

    /// Instance `NSPopOver`.
    var popover: NSPopover = .init()

    /// Array untuk menyimpan kumpulan ID unik dari data pada baris yang dipilih. Digunakan untuk memilihnya kembali setelah tabel diperbarui.
    var selectedIds: Set<Int64> = []

    /// Work item untuk menangani input pencarian di toolbar.
    var searchItem: DispatchWorkItem?

    /// Delegate untuk menampilkan siswa dari ``SidebarViewController``.
    weak var delegate: KelasVCDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self

        // MARK: CUSTOM HEADER TITLE CELL

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
           let mode = TableViewMode(rawValue: savedMode)
        {
            currentTableViewMode = mode
        }
        setupDescriptor()
        if let sortDescriptor = loadSortDescriptor() {
            // Mengatur sort descriptor tabel
            tableView.sortDescriptors = [sortDescriptor]
        }
        setupTable()
        tableView.editAction = { row, column in
            // Anda bisa menambahkan logika tambahan di sini jika perlu sebelum memanggil startEditing
            AppDelegate.shared.editorManager.startEditing(row: row, column: column)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: false)
            filterDeletedSiswa()
            updateHeaderMenuOrder()
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] timer in
            guard let self, let window = view.window else { timer.invalidate(); return }
            updateUndoRedo(self)
            window.makeFirstResponder(tableView)
            ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian)
        }
        toolbarItem()
        updateMenuItem(self)
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: .hapusCacheFotoKelasAktif, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePopupDismissed(_:)), name: .popupDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        NotificationCenter.default.addObserver(forName: .undoActionNotification) { [weak self] (payload: UndoActionNotification) in
            self?.handleUndoActionNotification(payload)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(undoEditSiswa(_:)), name: .updateEditSiswa, object: nil)
        viewModel.isGrouped = currentTableViewMode == .grouped
        updateGroupMenuBar()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        cekQuickLook()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        ReusableFunc.resetMenuItems()
        searchItem?.cancel()
        searchItem = nil
    }

    /**
         Memfilter data siswa yang telah dihapus (deleted) dari tampilan.

         Fungsi ini melakukan langkah-langkah berikut:
         1. Memuat descriptor pengurutan (sort descriptor) yang disimpan. Jika tidak ada, fungsi akan berhenti.
         2. Mengonversi descriptor pengurutan mentah (raw sort descriptor) menjadi objek `SortDescriptorWrapper`.
         3. Menentukan apakah tampilan saat ini dalam mode pengelompokan (grouped) atau tidak.
         4. Secara asinkron melakukan:
             - Mengambil data siswa menggunakan `viewModel.fetchSiswaData()`.
             - Memfilter data siswa yang dihapus menggunakan `viewModel.filterDeletedSiswa()`, dengan mempertimbangkan descriptor pengurutan, mode pengelompokan, dan apakah siswa yang berhenti (berhenti) disembunyikan atau tidak.
             - Memperbarui UI di thread utama:
                 - Jika dalam mode pengelompokan, memperbarui tampilan dari `updateGroupedUI()`.
                 - Jika tidak dalam mode pengelompokan, mengurutkan data menggunakan `sortData(with:)`.
             - Jika data belum dimuat sebelumnya (pertama kali dijalankan):
                 - Mengatur properti `tableView` untuk mendukung operasi drag and drop.
                 - Mendaftarkan tipe data yang dapat diseret ke `tableView`.
                 - Mengatur gaya umpan balik (feedback style) untuk operasi drag and drop.
                 - Mengonfigurasi menu konteks (context menu) `itemSelectedMenu`.
                 - Membuat dan memasukkan item menu kustom (custom menu item) ke dalam menu konteks.
                 - Menetapkan menu yang telah dikonfigurasi ke `tableView`.
                 - Menutup jendela progress (progress window) jika ada.
                 - Menandai bahwa data telah dimuat (`isDataLoaded = true`).
     */
    func filterDeletedSiswa() {
        guard let rawSortDescriptor = loadSortDescriptor() else { return }
        let isGrouped = currentTableViewMode != .plain
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            await viewModel.fetchSiswaData()
            await viewModel.filterDeletedSiswa(group: isGrouped)

            await MainActor.run {
                if isGrouped {
                    self.updateGroupedUI()
                } else {
                    self.sortData(with: rawSortDescriptor)
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                if !isDataLoaded {
                    tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
                    tableView.registerForDraggedTypes([.tiff, .png, .fileURL, .string])
                    tableView.draggingDestinationFeedbackStyle = .regular

                    // Configure menus
                    let newMenu = itemSelectedMenu.copy() as! NSMenu
                    newMenu.delegate = self
                    itemSelectedMenu.delegate = self

                    // Setup first custom menu
                    createCustomMenu()
                    let tagView = customViewMenu
                    customViewMenu.frame = NSRect(x: 0, y: 0, width: 224, height: 45)
                    tagMenuItem.view = tagView
                    tagMenuItem.target = self
                    tagMenuItem.identifier = NSUserInterfaceItemIdentifier("kelasAktif")
                    newMenu.insertItem(tagMenuItem, at: 21)
                    newMenu.insertItem(NSMenuItem.separator(), at: 22)

                    // Setup second custom menu
                    createCustomMenu2()
                    let tagView2 = customViewMenu2
                    customViewMenu2.frame = NSRect(x: 0, y: 0, width: 224, height: 45)
                    tagMenuItem2.view = tagView2
                    tagMenuItem2.target = self
                    tagMenuItem2.identifier = NSUserInterfaceItemIdentifier("kelasAktif")
                    itemSelectedMenu.insertItem(tagMenuItem2, at: 21)
                    itemSelectedMenu.insertItem(NSMenuItem.separator(), at: 22)
                    tableView.menu = newMenu
                    if let window = view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    isDataLoaded = true
                }
            }
        }
    }

    /**
         Memperbarui tampilan antarmuka pengguna yang dikelompokkan.

         Fungsi ini melakukan langkah-langkah berikut:
         1. Menghapus garis grid vertikal dari tampilan tabel.
         2. Jika ada informasi kolom, memperbarui judul kolom pertama menjadi "Kelas 1".
         3. Jika ada deskriptor pengurutan yang dimuat, mengurutkan data dengan deskriptor tersebut.
         4. Menambahkan observer untuk memantau perubahan batas scroll view dan memanggil `scrollViewDidScroll(_:)` saat terjadi perubahan.
     */
    func updateGroupedUI() {
        tableView.gridStyleMask.remove(.solidVerticalGridLineMask)
        if let columnInfo = kolomTabelSiswa.first {
            if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) {
                column.title = "Kelas 1"
            }
        }
        if let sdsc = loadSortDescriptor() {
            sortData(with: sdsc)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    /// Menangani aksi ketika tampilan popup ditutup.
    ///
    /// Fungsi ini dipanggil sebagai respons terhadap notifikasi `.popupDismissed`. Fungsi ini melakukan penundaan singkat
    /// untuk memastikan bahwa setiap pembaruan antarmuka pengguna yang diperlukan diselesaikan setelah popup ditutup.
    /// Fungsi ini memeriksa apakah ada baris yang dipilih dan memperbarui tampilan tabel yang sesuai.
    /// Selain itu, fungsi ini memanggil `updateUndoRedo` setelah penundaan singkat.
    ///
    /// - Parameter sender: Objek yang mengirim notifikasi.
    @objc func handlePopupDismissed(_: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [unowned self] in
            guard !rowDipilih.isEmpty else { return }
            if tableView.selectedRow > -1 {
            } else {
                for indexSet in rowDipilih {
                    tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                }
            }
        }
        updateUndoRedo(self)
    }

    /// Func untuk menyembunyikan/menampilkan kolom tertentu.
    /// - Parameter sender: Objek `NSMenuItem` dengan representedObject yang merupakan NSTableColumn.
    /// representedObject bisa diset saat menu item tersebut pertama kali dibuat.
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

    /**
         Mengatur item-item pada toolbar jendela. Fungsi ini mencari item-item toolbar berdasarkan identifier mereka dan mengkonfigurasi properti seperti target, action, status enabled, dan tooltips.

         - Parameter: Tidak ada. Fungsi ini beroperasi pada toolbar jendela saat ini.

         Fungsi ini melakukan hal berikut:
         1. Mengaktifkan dan mengkonfigurasi search field (jika ada) untuk pencarian siswa.
         2. Mengaktifkan dan mengkonfigurasi segmented control (jika ada) untuk zoom tabel.
         3. Mengatur status enabled tombol "Hapus" dan "Edit" berdasarkan apakah ada baris yang dipilih di tabel.
         4. Menonaktifkan tombol "Tambah" (jika ada).
         5. Mengaktifkan dan mengkonfigurasi tombol "add" (jika ada) untuk menambahkan data siswa baru, termasuk mengatur tooltip.
         6. Mengatur menu pop-up (jika ada) dengan menu yang telah dipilih.
     */
    func toolbarItem() {
        guard let wc = view.window?.windowController as? WindowController else { return }

        // SearchField
        wc.searchField.isEnabled = true
        wc.searchField.isEditable = true
        wc.searchField.target = self
        wc.searchField.action = #selector(procSearchFieldInput(sender:))
        wc.searchField.delegate = self
        if let textFieldInsideSearchField = wc.searchField.cell as? NSSearchFieldCell {
            textFieldInsideSearchField.placeholderString = "Cari siswa..."
        }

        // Tambah Data
        wc.tambahSiswa.isEnabled = true
        wc.tambahSiswa.toolTip = "Tambahkan Data Siswa Baru"
        wc.addDataToolbar.label = "Tambah Siswa"
        addButton = wc.tambahSiswa

        // Tambah nilai kelas
        wc.tambahDetaildiKelas.isEnabled = false

        // Kalkulasi nilai kelas
        wc.kalkulasiButton.isEnabled = false

        // Action Menu
        wc.actionPopUpButton.menu = itemSelectedMenu

        // Edit
        wc.tmbledit.isEnabled = tableView.selectedRow != -1

        // Hapus
        wc.hapusToolbar.isEnabled = tableView.selectedRow != -1
        wc.hapusToolbar.target = self

        // Zoom Segment
        wc.segmentedControl.isEnabled = true
        wc.segmentedControl.target = self
        wc.segmentedControl.action = #selector(segmentedControlValueChanged(_:))
    }

    /// Properti `NSButton` yang digunakan ketika toolbar untuk menambahkan
    /// data baru ``WindowController/addDataToolbar`` dihapus dari jendela.
    var addButton: NSButton!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        ReusableFunc.resetMenuItems()
    }

    // MARK: - UI

    /// Fungsi untuk menerapkan tinggi ``tableView`` ketika pertama kali dimuat.
    func setupTable() {
        if let savedRowHeight = UserDefaults.standard.value(forKey: "SiswaTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }
    }

    fileprivate func toggleVisibility(
        flag: inout Bool,
        userDefaultsKey: String?,
        filterTask: @escaping (Bool) async -> [Int],
        groupedTask: @escaping () async -> Void,
        removeDelay: UInt64 = 300_000_000
    ) {
        ReusableFunc.showProgressWindow(view, isDataLoaded: false)
        flag.toggle()

        let shouldHide: Bool = if userDefaultsKey == "tampilkanSiswaLulus" {
            flag == false
        } else {
            flag == true
        }

        let sortDescriptor = loadSortDescriptor()!
        let isGrouped = (currentTableViewMode != .plain)

        Task(priority: .userInitiated) { [unowned self, flag, shouldHide] in
            if !isGrouped {
                let index = await filterTask(flag)
                if shouldHide {
                    // Hapus baris
                    for i in index.reversed() {
                        viewModel.removeSiswa(at: i)
                    }
                    try? await Task.sleep(nanoseconds: removeDelay)
                    await MainActor.run {
                        tableView.removeRows(at: IndexSet(index), withAnimation: .slideDown)
                    }
                } else {
                    // Tambah baris
                    await MainActor.run {
                        tableView.insertRows(at: IndexSet(index), withAnimation: .effectGap)
                        if let full = index.max() {
                            tableView.scrollRowToVisible(min(full, tableView.numberOfRows - 1))
                        }
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    tableView.selectRowIndexes(IndexSet(index), byExtendingSelection: false)
                }
            } else {
                await groupedTask()
                await MainActor.run {
                    sortData(with: sortDescriptor)
                }
            }
            await MainActor.run {
                if let window = view.window {
                    ReusableFunc.closeProgressWindow(window)
                }
            }
        }
    }

    /**
     Menangani aksi ketika tombol untuk beralih tampilan siswa lulus/tidak lulus ditekan.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengubah (toggle) pengaturan `tampilkanSiswaLulus` yang disimpan di `UserDefaults`.
     2. Memuat `SortDescriptor` yang digunakan untuk pengurutan data.
     3. Melakukan pemfilteran dan pembaruan tampilan tabel secara asinkron berdasarkan status `tampilkanSiswaLulus` dan mode tampilan tabel saat ini (grouped/plain).
     4. Jika mode tampilan adalah `plain`:
        - Memfilter data siswa berdasarkan status kelulusan.
        - Menghapus atau menambahkan baris pada tabel dengan animasi yang sesuai.
        - Menggulir tampilan ke baris yang baru ditambahkan (jika ada).
        - Memilih baris yang baru ditambahkan.
     5. Jika mode tampilan adalah `grouped`:
        - Mengambil ulang data siswa.
        - Memfilter siswa yang dihapus (berhenti) dan mengelompokkan data.
        - Mengurutkan ulang data.

     - Parameter:
        - sender: Objek yang memicu aksi.
     */
    @IBAction func beralihSiswaLulus(_: Any) {
        toggleVisibility(
            flag: &tampilkanSiswaLulus,
            userDefaultsKey: "tampilkanSiswaLulus",
            filterTask: { [unowned self] show in
                await viewModel.filterSiswaLulus(show, sortDesc: SortDescriptorWrapper.from(loadSortDescriptor()!))
            },
            groupedTask: { [unowned self] in
                await viewModel.fetchSiswaData()
                await viewModel.filterDeletedSiswa(group: true)
            }
        )
    }

    /**
     * @IBAction Memuat ulang data siswa dari sumber data.
     *
     * Fungsi ini dipanggil ketika tombol muat ulang di menu klik kanan atau di menu toolbar ditekan. Fungsi ini akan mengambil data siswa terbaru,
     * menyaring siswa yang dihapus, dan mengurutkan data berdasarkan deskriptor pengurutan yang dipilih.
     * Proses ini dilakukan secara asinkron untuk menjaga responsivitas UI.
     *
     * - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func muatUlang(_ sender: Any) {
        guard let sortDescriptor = loadSortDescriptor() else { return }
        if currentTableViewMode == .grouped {
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await viewModel.fetchSiswaData()
                await viewModel.filterDeletedSiswa(group: true)

                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        } else {
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await viewModel.fetchSiswaData()
                await viewModel.filterDeletedSiswa(group: false)

                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        }
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/SiswaViewController``
    @objc func updateMenuItem(_: Any?) {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let deleteMenuItem = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem,
           let pasteMenuItem = ReusableFunc.pasteMenuItem
        {
            let isRowSelected = tableView.selectedRowIndexes.count > 0

            // Update item menu "Copy"
            copyMenuItem.isEnabled = isRowSelected
            pasteMenuItem.target = self
            pasteMenuItem.action = SingletonData.originalPasteAction
            // Update item menu "Delete"
            deleteMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(hapusMenu(_:))
                copyMenuItem.target = self
                copyMenuItem.action = #selector(copyDataClicked(_:))
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

    /// Action untuk menu item "Kelompokkan Data" di Menu Bar.
    /// - Parameter sender: Objek pemicu.
    @IBAction func groupMode(_: NSMenuItem) {
        searchItem?.cancel()
        let menu = NSMenuItem()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            menu.tag = currentTableViewMode == .plain ? 1 : 0
            changeTableViewMode(menu)
        }
        searchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: searchItem!)
    }

    /**
     * Menangani aksi ketika tombol untuk menampilkan/menyembunyikan siswa yang berhenti ditekan.
     *
     * Fungsi ini melakukan toggle visibilitas siswa yang berhenti (`isBerhentiHidden`) dan memperbarui tampilan tabel sesuai dengan status tersebut.
     * Jika `currentTableViewMode` adalah `.plain`, fungsi ini akan memfilter siswa yang berhenti dan memperbarui baris tabel secara langsung.
     * Jika `currentTableViewMode` bukan `.plain`, fungsi ini akan mengambil ulang data siswa dan memfilter siswa yang dihapus, kemudian mengurutkan data dan memperbarui UI.
     *
     * - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func toggleBerhentiVisibility(_: Any) {
        toggleVisibility(
            flag: &isBerhentiHidden,
            userDefaultsKey: nil,
            filterTask: { [unowned self] hidden in
                await viewModel.filterSiswaBerhenti(hidden, sortDescriptor: SortDescriptorWrapper.from(loadSortDescriptor()!))
            },
            groupedTask: { [unowned self] in
                await viewModel.fetchSiswaData()
                await viewModel.filterDeletedSiswa(group: true)
            },
            removeDelay: 200_000_000
        )
    }

    /**
     Menangani perubahan nilai pada `NSDatePicker` yang muncul ketika baris di kolom `tanggalBerhenti` atau `tahunDaftar` diedit.

     Fungsi ini dipanggil ketika nilai pada `NSDatePicker` diubah. Fungsi ini akan memperbarui data siswa yang sesuai di dalam model dan database, serta menyiapkan aksi undo.

     - Parameter sender: `NSDatePicker` yang mengirimkan aksi. Tag pada `NSDatePicker` digunakan untuk menentukan kolom mana yang sedang diubah.
     */
    @objc func datePickerValueChanged(_ sender: NSDatePicker) {
        let clickedRow = tableView.selectedRow

        // Check if a valid row is selected
        guard clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count,
              let dateFormatter = ReusableFunc.dateFormatter
        else { return }

        let siswa = viewModel.filteredSiswaData[clickedRow]
        // Set up date formatters
        let editedDate = sender.dateValue

        let editedTanggal = dateFormatter.string(from: editedDate)

        // Get the tag of the date picker to identify the column
        let datePickerTag = sender.tag

        guard let (oldValue, column, columnIndex) = columnInfo(for: datePickerTag, siswa: siswa) else { return }
        updateTanggal(column, id: siswa.id, row: clickedRow, columnIndex: columnIndex, oldValue: oldValue, newValue: editedTanggal)
    }

    fileprivate func columnInfo(for tag: Int, siswa: ModelSiswa) -> (String, SiswaColumn, Int)? {
        switch tag {
        case 1: (siswa.tahundaftar, .tahundaftar, columnIndexOfThnDaftar)
        case 2: (siswa.tanggalberhenti, .tanggalberhenti, columnIndexOfTglBerhenti)
        default: nil
        }
    }

    fileprivate func updateTanggal(_ column: SiswaColumn,
                                   id: Int64,
                                   row: Int,
                                   columnIndex: Int,
                                   oldValue: String,
                                   newValue: String)
    {
        viewModel.updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: row, newValue: newValue, oldValue: oldValue)
        // Reload tabel hanya untuk kolom yang berubah
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet([columnIndex]))
        // Simpan data asli untuk undo
        let originalModel = DataAsli(ID: id, columnIdentifier: column, oldValue: oldValue, newValue: newValue)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.viewModel.undoAction(originalModel: originalModel)
        })
    }

    /// Fungsi untuk memperbarui status menu item di Menu Bar "Gunakan Grup" ke on/off.
    func updateGroupMenuBar() {
        AppDelegate.shared.groupMenuItem.state = currentTableViewMode == .grouped ? .on : .off
    }

    /**
     Mengubah mode tampilan tabel antara mode polos (plain) dan mode berkelompok (grouped).

     - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini. Tag dari menu item menentukan mode tampilan tabel yang akan diterapkan. Nilai tag 0 = .plain, nilai tag 1 = .grouped.

     Mode yang tersedia:
        - `.plain`: Menampilkan data dalam format tabel standar tanpa pengelompokan.
        - `.grouped`: Menampilkan data yang dikelompokkan berdasarkan kriteria tertentu.

     Saat mode diubah:
        - Tampilan tabel diperbarui sesuai dengan mode yang dipilih.
        - Nilai `currentTableViewMode` disimpan ke `UserDefaults` untuk persistensi.
        - Kolom-kolom tabel dikonfigurasi ulang, termasuk visibilitas dan menu header.
        - Data siswa difilter ulang berdasarkan mode yang baru.
        - UI diperbarui untuk mencerminkan perubahan mode, termasuk tampilan header dan pengelompokan baris.
        - Observer untuk notifikasi perubahan batas tampilan dihapus atau ditambahkan sesuai kebutuhan.

     - Note: Fungsi ini juga memanggil `updateGroupMenuBar()` untuk memperbarui tampilan menu bar sesuai dengan mode tampilan tabel yang aktif.
     */
    @IBAction func changeTableViewMode(_ sender: NSMenuItem) {
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
                if let columnInfo = kolomTabelSiswa.first {
                    if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) {
                        let customHeaderCell = MyHeaderCell()
                        customHeaderCell.title = "Nama" // Menggunakan nama section yang sesuai
                        column.headerCell = customHeaderCell
                    }
                }
                filterDeletedSiswa()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
                    for id in selectedIds {
                        if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
                            indexset.insert(index)
                        } else {}
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
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await viewModel.fetchSiswaData()
                    await viewModel.filterDeletedSiswa(group: true)

                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        // Setelah filtering selesai, update UI di sini
                        updateGroupedUI()
                    }
                }
            }
        }
        updateGroupMenuBar()
    }

    /// Menangani event scroll pada ``tableView`` dalam mode grup untuk menciptakan efek header "sticky"
    /// dan transisi antar judul section.
    ///
    /// Fungsi ini dipanggil setiap kali `scrollView` mendeteksi adanya pergerakan scroll.
    /// Tujuannya adalah untuk menjaga judul `section` tetap terlihat di bagian atas tampilan
    /// tabel saat pengguna menggulir, dan juga untuk mengelola transisi visual (fade-in/fade-out)
    /// antara judul `section` saat mereka masuk atau keluar dari area yang terlihat.
    ///
    /// - Parameter notification: Notifikasi `Notification` yang dikirim oleh `NSScrollView`
    ///   ketika ada event scroll. Objek notifikasi diharapkan adalah `NSClipView`.
    ///
    /// - Keterkaitan dengan properti dan func:
    ///   - `tableView`: `NSTableView` yang sedang di-scroll.
    ///   - `dataSections`: Array data yang mengelola struktur section dan entitas tabel.
    ///   - `headerView`: `NSTableHeaderView` bawaan dari `tableView`.
    ///   - `nextSectionHeaderView`: `NSView?` opsional yang digunakan untuk menampilkan
    ///     judul section berikutnya selama transisi.
    ///   - `tabBarFrame`: `CGFloat` yang merepresentasikan tinggi elemen UI di atas tabel,
    ///     digunakan untuk menyesuaikan offset scroll.
    ///   - `getRowInfoForRow(_:)`: Metode pembantu untuk mendapatkan indeks section dan baris
    ///     relatif dari indeks baris absolut.
    ///   - `findFirstRowInSection(_:)`: Metode pembantu untuk menemukan indeks baris absolut
    ///     dari baris pertama section tertentu.
    ///   - `createHeaderViewCopy(title:)`: Metode pembantu untuk membuat salinan `headerView`
    ///     dengan judul yang diberikan.
    ///   - `updateHeaderTitle(for:in:)`: Metode pembantu untuk memperbarui teks pada `headerView`.
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              currentTableViewMode == .grouped,
              let headerView = tableView.headerView
        else {
            return
        }

        var offsetY = clipView.documentVisibleRect.origin.y
        offsetY += 20
        let topRow = tableView.row(at: CGPoint(x: 0, y: offsetY))

        // Handle top position
        if clipView.bounds.origin.y <= -42 {
            updateHeaderTitle(for: 0)
            headerView.frame.origin.y = 0
            // headerView.alphaValue = 1
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
        let defaultSectionSpacing: CGFloat = 19 // berdasarkan pengamatan visual
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
            // let currentAlpha = 1.0 - progress
            let nextAlpha = progress

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Update current header
                headerView.frame.origin.y = -headerY
                //                headerView.alphaValue = currentAlpha
                updateHeaderTitle(for: currentSectionIndex)

                // Update next section header
                nextSectionHeaderView?.frame.origin.y = nextSectionY - 1
                nextSectionHeaderView?.alphaValue = nextAlpha

                // Remove next header when transition is complete
                if nextAlpha >= 1.0 {
                    nextSectionHeaderView?.removeFromSuperview()
                    nextSectionHeaderView = nil

                    // Update current header for next section
                    if headerView.frame.origin.y != 0 {
                        headerView.frame.origin.y = 0
                        updateHeaderTitle(for: nextSectionIndex)
                        // headerView.alphaValue = 1.0
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

    /// Membuat salinan NSTableHeaderView saat scrolling dalam mode grup dan topView akan berganti section.
    private var nextSectionHeaderView: NSTableHeaderView?

    /**
         Membuat salinan (copy) dari header view tabel dengan judul yang ditentukan.

         Fungsi ini membuat header view baru yang merupakan salinan dari header view tabel yang ada,
         kemudian mengganti judulnya dengan judul yang diberikan. Header view yang baru dibuat adalah
         instance dari `CustomTableHeaderView` dan memiliki `MyHeaderCell` sebagai cell header custom.

         - Parameter title: Judul yang akan diterapkan pada header view yang baru.
         - Returns: Sebuah instance `NSTableHeaderView` yang telah dikonfigurasi, atau `nil` jika header view asli tidak ditemukan.
     */
    func createHeaderViewCopy(title: String) -> NSTableHeaderView? {
        guard let originalHeader = tableView.headerView else { return nil }
        let modFrame = NSRect(
            x: originalHeader.frame.origin.x,
            y: originalHeader.frame.origin.y,
            width: originalHeader.frame.width,
            height: originalHeader.frame.height
        )

        let newHeader = CustomTableHeaderView(frame: modFrame)
        newHeader.tableView = tableView
        newHeader.isSorted = isSortedByFirstColumn
        // Buat custom header cell dengan title kosong
        let emptyHeaderCell = MyHeaderCell()
        emptyHeaderCell.title = title

        // Set custom header cell
        newHeader.customHeaderCell = emptyHeaderCell

        return newHeader
    }

    /**
         Memperbarui judul header untuk bagian tertentu dalam tabel.

         Fungsi ini memperbarui judul header dari kolom pertama dalam tabel, jika ada, dengan nama kelas yang sesuai dengan indeks bagian yang diberikan.
         Fungsi ini memastikan bahwa indeks bagian valid dan bahwa kolom pertama memiliki `MyHeaderCell` sebagai sel headernya.
         Jika judul baru berbeda dari judul sebelumnya, judul akan diperbarui dan tampilan header akan dipaksa untuk menggambar ulang.

         - Parameter:
            - sectionIndex: Indeks bagian yang judul headernya akan diperbarui.
     */
    func updateHeaderTitle(for sectionIndex: Int) {
        guard sectionIndex >= 0, sectionIndex < kelasNames.count else { return }

        if let columnInfo = kolomTabelSiswa.first,
           let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)),
           let customHeaderCell = column.headerCell as? MyHeaderCell
        {
            let newTitle = kelasNames[sectionIndex]
            if customHeaderCell.customTitle != newTitle {
                customHeaderCell.customTitle = newTitle
                customHeaderCell.title = newTitle
                // Paksa headerView menggambar ulang
                tableView.headerView?.needsDisplay = true
            }
        }
    }

    /**
         Mencari baris pertama dalam sebuah bagian (section) pada tabel.

         - Parameter sectionIndex: Indeks bagian yang ingin dicari.
         - Returns: Indeks baris pertama pada bagian yang ditentukan. Mengembalikan -1 jika bagian tidak ditemukan atau kosong.
     */
    func findFirstRowInSection(_ sectionIndex: Int) -> Int {
        for row in 0 ..< tableView.numberOfRows {
            let (_, section, _) = getRowInfoForRow(row)
            if section == sectionIndex {
                return row
            }
        }
        return -1
    }

    /**
     Mengubah status penggunaan warna latar belakang alternatif pada tabel.

     Saat diaktifkan, baris pada tabel akan memiliki warna latar belakang yang berbeda secara bergantian.
     Status item menu "Gunakan Warna Alternatif" juga akan diperbarui sesuai dengan status penggunaan warna.
     Setelah perubahan, semua baris yang dipilih akan di-deselect dan tampilan tabel akan di-reload.

     - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func toggleColorAction(_ sender: Any) {
        useAlternateColor.toggle()
        if useAlternateColor {
            tableView.usesAlternatingRowBackgroundColors = true
        } else {
            tableView.usesAlternatingRowBackgroundColors = false
        }
        // Perbarui state item menu
        if let contextMenu = tableView.menu,
           let toggleColorMenuItem = contextMenu.item(withTitle: "Gunakan Warna Alternatif")
        {
            toggleColorMenuItem.state = useAlternateColor ? .on : .off
        }
        tableView.deselectAll(sender)
        tableView.reloadData()
    }

    // MARK: - Group Section tableView reusable func

    /**
     Mendapatkan informasi tentang baris tertentu dalam tampilan tabel siswa.

     Fungsi ini menentukan apakah suatu baris adalah baris header grup (kelas) atau baris data siswa,
     dan mengembalikan indeks bagian (section) dan indeks baris relatif terhadap bagian tersebut.

     - Parameter:
        - row: Nomor baris yang ingin dicari informasinya.

     - Returns:
        Sebuah tuple yang berisi:
           - isGroupRow: `true` jika baris adalah header grup (kelas), `false` jika baris adalah data siswa.
           - sectionIndex: Indeks bagian (kelas) tempat baris berada.
           - rowIndexInSection: Indeks baris relatif terhadap bagian (kelas) tersebut.  Jika `isGroupRow` adalah `true`, maka nilai ini adalah -1.
     */
    func getRowInfoForRow(_ row: Int) -> (isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) {
        // Mendapatkan informasi baris untuk nomor baris yang diberikan
        var currentRow = 0

        for (index, section) in viewModel.groupedSiswa.enumerated() {
            let sectionRowCount = section.count + 1 // Jumlah siswa + 1 untuk header kelas
            if row >= currentRow, row < currentRow + sectionRowCount {
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

    /**
      Menghitung indeks baris absolut dalam NSTableView yang dikelompokkan, yang diperlukan untuk menghapus/memperbarui/menambahkan baris.

      Indeks absolut dihitung berdasarkan jumlah total baris di semua grup sebelumnya, ditambah dengan indeks baris dalam grup saat ini.
      Setiap grup dianggap memiliki header (kelas) yang juga dihitung sebagai baris.

      - Parameter groupIndex: Indeks grup tempat baris berada.
      - Parameter rowIndexInSection: Indeks baris dalam grup tertentu.
      - Returns: Indeks baris absolut dalam NSTableView.
     */
    func calculateAbsoluteRowIndex(groupIndex: Int, rowIndexInSection: Int) -> Int {
        var absoluteRowIndex = 0
        for i in 0 ..< groupIndex {
            let section = viewModel.groupedSiswa[i]
            absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
        }
        return absoluteRowIndex + rowIndexInSection
    }

    // MARK: - SORTDESCRIPTOR FUNC

    /**
         Mengatur deskriptor pengurutan untuk setiap kolom dalam tabel. Fungsi ini mengiterasi melalui setiap kolom tabel,
         mengambil pengidentifikasi kolom, dan menetapkan deskriptor pengurutan yang sesuai dari kamus `identifikasiKolom`.
         Deskriptor pengurutan ini kemudian digunakan sebagai prototipe untuk memungkinkan pengurutan data dalam kolom tersebut.
     */
    func setupDescriptor() {
        let mapping: [NSUserInterfaceItemIdentifier: SiswaColumn] = [
            .init("Nama"): .nama,
            .init("Alamat"): .alamat,
            .init("T.T.L"): .ttl,
            .init("Tahun Daftar"): .tahundaftar,
            .init("Nama Wali"): .namawali,
            .init("NIS"): .nis,
            .init("Jenis Kelamin"): .jeniskelamin,
            .init("Status"): .status,
            .init("Tgl. Lulus"): .tanggalberhenti,
            .init("Ayah"): .ayah,
            .init("Ibu"): .ibu,
            .init("NISN"): .nisn,
            .init("Nomor Telepon"): .tlv,
        ]
        let descriptors = ReusableFunc.makeSortDescriptors(for: mapping)
        for column in tableView.tableColumns {
            column.sortDescriptorPrototype = descriptors[column.identifier]
        }
    }

    /**
         Mengurutkan data siswa berdasarkan deskriptor pengurutan yang diberikan.

         Fungsi ini mengurutkan data siswa baik dalam mode tampilan biasa (tanpa grup) maupun dalam mode tampilan grup.
         Dalam mode tampilan biasa, fungsi ini mengurutkan `filteredSiswaData` dan mempertahankan pilihan siswa yang ada.
         Dalam mode tampilan grup, fungsi ini mengurutkan `groupedSiswa` dan mempertahankan pilihan siswa yang ada.
         Setelah pengurutan, tabel diperbarui dan baris yang sebelumnya dipilih akan tetap dipilih, dan tampilan akan di-scroll ke baris terakhir yang dipilih jika ada.

         - Parameter:
             - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan data.
     */
    func sortData(with sortDescriptor: NSSortDescriptor) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        var indexset = IndexSet()
        if currentTableViewMode == .plain {
            // Lakukan pengurutan untuk mode tanpa grup
            viewModel.sortSiswa(by: sortDescriptor, isBerhenti: isBerhentiHidden)
            for id in selectedIds {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
                    indexset.insert(index)
                }
            }
        } else {
            viewModel.sortGroupSiswa(by: sortDescriptor)

            // Dapatkan indeks siswa terpilih di `groupedSiswa`
            for id in selectedIds {
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
        tableView.reloadData()
        if currentTableViewMode == .grouped {}
        tableView.selectRowIndexes(indexset, byExtendingSelection: false)
        if let max = indexset.max() {
            tableView.scrollRowToVisible(max)
        }
    }

    /**
     Menyimpan `NSSortDescriptor` ke UserDefaults.

     - Parameter sortDescriptor: `NSSortDescriptor` yang akan disimpan. Jika nil, maka sort descriptor akan dihapus dari UserDefaults.
     */
    func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?) {
        // Simpan sort descriptor ke UserDefaults
        if let sortDescriptor {
            ReusableFunc.saveSortDescriptor(sortDescriptor, key: "sortDescriptor")
        }
    }

    /**
     Memuat descriptor pengurutan dari UserDefaults.

     Fungsi ini mencoba memuat NSSortDescriptor dari UserDefaults menggunakan kunci "sortDescriptor".
     Jika data ditemukan dan berhasil di-unarchive, descriptor pengurutan akan dikembalikan.
     Jika tidak, fungsi ini akan mengembalikan NSSortDescriptor default yang mengurutkan berdasarkan properti "nama" secara ascending.

     - Returns: NSSortDescriptor yang dimuat dari UserDefaults, atau NSSortDescriptor default jika tidak ada yang ditemukan.
     */
    func loadSortDescriptor() -> NSSortDescriptor? {
        // Muat sort descriptor dari UserDefaults
        ReusableFunc.loadSortDescriptor(forKey: "sortDescriptor", defaultKey: SiswaColumn.nama.rawValue)
    }

    // MARK: - OPERATION. MENUITEMS, ADD/EDIT/DELETE, UNDO-REDO.

    @IBAction func handlePrint(_: Any) {
        let alert = NSAlert()
        alert.messageText = "Tidak dapat menjalankan print data siswa"
        alert.informativeText = "Jumlah kolom di data siswa terlalu banyak untuk diprint di ukuran kertas yang tersedia."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Menangani perubahan nilai pada `NSSegmentedControl`, yang digunakan untuk menyesuaikan ukuran baris tabel.
    ///
    /// Fungsi ini bertindak sebagai action method untuk `NSSegmentedControl`. Berdasarkan segmen yang dipilih
    /// (indeks 0 atau 1), fungsi ini akan memicu peningkatan atau pengurangan tinggi baris `tableView`.
    ///
    /// - Parameter sender: `NSSegmentedControl` yang mengirim aksi. `sender.selectedSegment`
    ///   digunakan untuk menentukan segmen mana yang dipilih (0 untuk segmen pertama, 1 untuk segmen kedua).
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

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``.
    @IBAction func increaseSize(_: Any?) {
        ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "SiswaTableViewRowHeight")
    }

    /// Lihat: ``DataSDI/ReusableFunc/decreaseSize(_:)``.
    @IBAction func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "SiswaTableViewRowHeight")
    }

    // MARK: - EXPORT CSV & PDF

    /**
     * @IBAction exportToExcel
     *
     * Fungsi ini memanggil func ``exportToFile(pdf:data:)`` dan mengirim nilai false untuk pdf.
     *
     * Fungsi ini dipanggil ketika menu item "Ekspor data siswa ke file excel" dipilih.
     *
     * - Parameter sender: Objek NSMenuItem yang memicu aksi ini.
     */
    @IBAction func exportToExcel(_: NSMenuItem) {
        exportToFile(pdf: false, data: viewModel.filteredSiswaData)
    }

    /**
     * @IBAction exportToPDF
     *
     * Fungsi ini memanggil func ``exportToFile(pdf:data:)`` dan mengirim nilai true untuk pdf.
     *
     * Fungsi ini dipanggil ketika menu item "Export data siswa ke file PDF" dipilih.
     * - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini.
     */
    @IBAction func exportToPDF(_: NSMenuItem) {
        exportToFile(pdf: true, data: viewModel.filteredSiswaData)
    }

    /**
     * Fungsi ini melakukan serangkaian langkah untuk mengekspor data siswa yang telah difilter ke dalam format PDF.
     *
     * Langkah-langkah:
     * 1. Memeriksa apakah Python dan Pandas sudah terinstal menggunakan `ReusableFunc.checkPythonAndPandasInstallation`.
     * 2. Jika Python dan Pandas terinstal:
     *    - Memproses data ke file CSV untuk dikonversi ke PDF/XLSX.
     *    - Memanggil ``ReusableFunc/chooseFolderAndSaveCSV(header:rows:namaFile:window:sheetWindow:pythonPath:pdf:rowMapper:)`` untuk memilih folder penyimpanan, menyimpan data ke format CSV, dan mengonversi CSV ke PDF.
     * 3. Jika Python tidak terinstal, menutup sheet progress yang ditampilkan.
     * 4. Jika Pandas belum terinstal, mencoba mengunduh pandas dan menginstal di lever User(bukan admin).
     *
     * - Parameters:
     *   - pdf: Jika nilai `true`, file CSV akan dikonversi ke PDF. jika `false`, file CSV dikonversi ke XLSX.
     *   - data: data yang digunakan untuk diproses ``ModelSiswa``.
     */
    func exportToFile(pdf: Bool, data: [ModelSiswa]) {
        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { [weak self] isInstalled, progressWindow, pythonFound in
            guard let self else { return }
            if isInstalled {
                let header = ["Nama", "Alamat", "NISN", "NIS", "Wali", "Ayah", "Ibu", "No. Telepon", "Jenis Kelamin", "Kelas Aktif", "Tanggal Pendaftaran", "Status", "Tanggal Berhenti / Lulus"]
                ReusableFunc.chooseFolderAndSaveCSV(header: header, rows: data, namaFile: "Data Siswa", window: view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: pdf) { data in
                    [data.nama, data.alamat, String(data.nisn), String(data.nis), data.namawali, data.ayah, data.ibu, data.tlv, data.jeniskelamin.description, data.tingkatKelasAktif.rawValue, data.tahundaftar, data.status.description, data.tanggalberhenti]
                }
            } else {
                view.window?.endSheet(progressWindow!)
            }
        }
    }

    /// Action untuk double-klik di ``tableView.
    @IBAction func showDetail(_ sender: Any) {
        guard let tableView else {
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

    /// Delegasi dari ``DetilWindowDelegate`` ketika jendela
    /// DetilWindow yang menampilkan siswa ditutup.
    /// - Parameter window: Jendela yang akan dibersihkan dari referensi yang tersimpan di ``AppDelegate/openedSiswaWindows``.
    @objc func detailWindowDidClose(_ window: DetilWindow) {
        // Cari siswaID yang sesuai dengan jendela yang ditutup
        if let detailViewController = window.contentViewController as? DetailSiswaController,
           let siswaID = detailViewController.siswa?.id
        {
            AppDelegate.shared.openedSiswaWindows.removeValue(forKey: siswaID)
        }
    }

    /**
     Menangani aksi ketika baris pada tabel dipilih untuk menampilkan detail siswa.
     Baik melalui menu item klik kanan, toolbar, atau dari double-klik.

     Fungsi ini dipanggil ketika sebuah baris atau beberapa baris dipilih pada `tableView`. Fungsi ini akan mengambil data siswa yang sesuai dengan baris yang dipilih, baik dalam mode tampilan biasa (plain) maupun mode tampilan berkelompok (grouped), dan kemudian membuka tampilan rincian siswa.

     - Parameter:
        - sender: Objek yang mengirimkan aksi (misalnya, tombol atau gesture).

     Tindakan:
        1. Memeriksa apakah ada baris yang dipilih. Jika tidak ada, fungsi akan keluar.
        2. Memeriksa mode tampilan tabel (`currentTableViewMode`).
        3. Jika mode tampilan adalah `.plain`:
           - Mengambil indeks baris yang dipilih.
           - Memastikan indeks tersebut valid dalam rentang `viewModel.filteredSiswaData`.
           - Mengambil data siswa yang sesuai dan menambahkannya ke array `selectedSiswas`.
        4. Jika mode tampilan adalah `.grouped`:
           - Iterasi melalui setiap indeks baris yang dipilih.
           - Menggunakan `getRowInfoForRow(_:)` untuk mendapatkan informasi indeks grup dan indeks baris dalam grup.
           - Memastikan indeks grup dan indeks baris dalam grup valid dalam rentang `viewModel.groupedSiswa`.
           - Mengambil data siswa yang sesuai dari `viewModel.groupedSiswa` dan menambahkannya ke array `selectedSiswas`.
        5. Memanggil `ReusableFunc.bukaRincianSiswa(_:viewController:)` untuk membuka tampilan rincian siswa dengan data siswa yang dipilih dan `viewController` saat ini.
     */
    @objc func detailSelectedRow(_: Any) {
        let selectedSiswas: [ModelSiswa]
        guard tableView.selectedRowIndexes.count > 0 else { return }

        if currentTableViewMode == .plain {
            selectedSiswas = tableView.selectedRowIndexes.compactMap { index in
                guard index < viewModel.filteredSiswaData.count else { return nil }
                return viewModel.filteredSiswaData[index]
            }
        } else {
            // Menggunakan compactMap untuk menyederhanakan loop
            selectedSiswas = tableView.selectedRowIndexes.compactMap { index in
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection

                guard groupIndex < viewModel.groupedSiswa.count,
                      rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else { return nil }

                return viewModel.groupedSiswa[groupIndex][rowIndexInSection]
            }
        }
        ReusableFunc.bukaRincianSiswa(selectedSiswas, viewController: self)
    }

    /// Seperti logika ``detailSelectedRow(_:)``, tetapi hanya untuk satu baris yang diklik kanan.
    /// Penjelasan lebih lanjut lihat: ``showDetail(_:)``.
    @objc func detailClickedRow(_: Any) {
        // Pastikan ada baris yang dipilih di tabel
        guard tableView.clickedRow >= 0 else { return }
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

    // MARK: - COPY DATA

    /**
         * Fungsi ini dipanggil ketika tombol salin data diklik.
         *
         * Fungsi ini menangani penyalinan data berdasarkan baris yang dipilih atau diklik pada tabel.
         * Jika ada baris yang diklik, fungsi akan memeriksa apakah baris tersebut termasuk dalam baris yang dipilih.
         * Jika ya, maka fungsi `copySelectedRows` akan dipanggil. Jika tidak, fungsi `copyClickedRow` akan dipanggil.
         * Jika tidak ada baris yang diklik, tetapi ada baris yang dipilih, maka fungsi `copySelectedRows` akan dipanggil.
         *
         * - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func copyDataClicked(_ sender: Any) {
        guard let tableView else {
            return
        }

        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow

        // Jika ada baris yang diklik
        if clickedRow >= 0 {
            if selectedRows.contains(clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, maka panggil fungsi copySelectedRows
                copySelectedRows(sender, indexes: selectedRows)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih, maka panggil fungsi copyClickedRow
                copySelectedRows(sender, indexes: IndexSet(integer: clickedRow))
            }
        } else if tableView.numberOfSelectedRows >= 1 {
            copySelectedRows(sender, indexes: selectedRows)
        }
    }

    /**
         Menyalin baris yang dipilih dari tabel ke clipboard.

         Fungsi ini akan mengambil data dari setiap sel pada baris yang dipilih dalam `tableView`,
         mengonversinya menjadi string, dan menyalinnya ke clipboard dalam format yang dapat ditempelkan
         ke aplikasi lain seperti spreadsheet.

         - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol atau item menu).

         Tindakan yang dilakukan:
         1. Memastikan bahwa `tableView` tidak nil dan ada baris yang dipilih. Jika tidak, fungsi akan keluar.
         2. Mengiterasi setiap baris yang dipilih.
         3. Untuk setiap baris, mengiterasi setiap kolom.
         4. Mendapatkan data dari sel berdasarkan jenis tampilan sel (CustomTableCellView atau NSTableCellView).
            Jika sel adalah CustomTableCellView, data diambil dari `textField` atau `datePicker`.
            Jika sel adalah NSTableCellView, data diambil dari `textField`.
         5. Memformat data sel dan menambahkannya ke string baris, dipisahkan oleh tab.
         6. Menambahkan setiap baris ke string data yang disalin, dipisahkan oleh baris baru.
         7. Menghapus konten clipboard saat ini dan menyalin string data yang diformat ke clipboard.
     */
    @objc func copySelectedRows(_: Any, indexes: IndexSet) {
        guard let tableView else {
            return
        }
        ReusableFunc.salinBaris(indexes, from: tableView)
    }

    /**
         *   Fungsi ini dipanggil ketika tombol salin ditekan.
         *   Jika ada baris yang dipilih di tabel, fungsi `copySelectedRows` akan dipanggil.
         *   Jika tidak ada baris yang dipilih, sebuah alert akan ditampilkan yang memberitahukan pengguna untuk memilih baris terlebih dahulu.
         *
         *   @param sender Objek yang memicu aksi ini.
     */
    @IBAction func copy(_: Any) {
        let isRowSelected = tableView.selectedRowIndexes.count > 0
        if isRowSelected {
            copySelectedRows(self, indexes: tableView.selectedRowIndexes)
        } else {
            let alert = NSAlert()
            alert.messageText = "Tidak ada baris yang dipilih"
            alert.informativeText = "Pilih salah satu baris untuk menyalin data."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    deinit {
        operationQueue.cancelAllOperations()
        searchItem?.cancel()
        searchItem = nil
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .dataSiswaDiEdit, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.removeObserver(self, name: .popupDismissed, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
    }
}

// MARK: - NSSEARCHFIELD & TEXTVIEW EDITING OPERATIONS

extension SiswaViewController: NSSearchFieldDelegate {
    /**
     Menangani input dari field pencarian.

     - Parameter sender: NSSearchField yang mengirimkan aksi.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Membatalkan pencarian sebelumnya jika ada.
     2. Membuat DispatchWorkItem untuk melakukan pencarian setelah penundaan.
     3. Me-resign first responder dari tableView.
     4. Memanggil fungsi `search(_:)` dengan string dari field pencarian.
     5. Menyimpan string pencarian ke properti `stringPencarian`.
     6. Menjalankan DispatchWorkItem setelah penundaan 0.5 detik.
     */
    @objc func procSearchFieldInput(sender: NSSearchField) {
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

    /**
         Melakukan pencarian siswa berdasarkan teks yang diberikan.

         Fungsi ini melakukan pencarian siswa berdasarkan teks yang dimasukkan oleh pengguna.
         Pencarian dilakukan secara asinkron dan memperbarui tampilan setelah data selesai diproses.

         - Parameter searchText: Teks yang digunakan untuk mencari siswa.

         - Precondition: `searchText` tidak boleh nil.

         - Postcondition: Data siswa yang ditampilkan pada tabel akan diperbarui sesuai dengan hasil pencarian.

         - Note: Fungsi ini menggunakan `stringPencarian` untuk menghindari pemanggilan pencarian yang berulang dengan teks yang sama.

         - Important: Fungsi ini memanggil `viewModel.cariSiswa` atau `viewModel.fetchSiswaData` tergantung pada apakah `searchText` kosong atau tidak, dan juga memanggil `viewModel.filterDeletedSiswa` untuk menyaring data berdasarkan status penghapusan dan mode tampilan tabel.
     */
    func search(_ searchText: String) {
        if searchText == stringPencarian { return }
        // Update previousSearchText dengan nilai baru
        stringPencarian = searchText
        guard let sortDescriptor = loadSortDescriptor() else { return }
        if currentTableViewMode == .plain {
            if !stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await viewModel.cariSiswa(stringPencarian)
                    await viewModel.filterDeletedSiswa(group: false)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await viewModel.fetchSiswaData()
                    await viewModel.filterDeletedSiswa(group: false)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            }
        } else {
            if !stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await viewModel.cariSiswa(stringPencarian)
                    await viewModel.filterDeletedSiswa(group: true)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await viewModel.fetchSiswaData()
                    await viewModel.filterDeletedSiswa(group: true)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            }
        }
    }
}

// MARK: - OVERLAY EDITOR

extension SiswaViewController: OverlayEditorManagerDataSource {
    func overlayEditorManager(_: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let columnIdentifier = SiswaColumn(rawValue: tableView.tableColumns[column].identifier.rawValue) else { return "" }

        if currentTableViewMode == .grouped {
            let selectedRowInfo = getRowInfoForRow(row)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            guard rowIndexInSection != -1 else { return "" }
            return viewModel.getOldValueForColumn(columnIdentifier: columnIdentifier, isGrouped: true, groupIndex: groupIndex, rowInSection: rowIndexInSection)
        }

        guard row < viewModel.filteredSiswaData.count else { return "" }
        return viewModel.getOldValueForColumn(rowIndex: row, columnIdentifier: columnIdentifier, data: viewModel.filteredSiswaData)
    }

    func overlayEditorManager(_: OverlayEditorManager, originalColumnWidthForCellAtRow _: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        tableView.tableColumns[column].width
    }

    func overlayEditorManager(_: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        guard let columnIdentifier = SiswaColumn(rawValue: tableView.tableColumns[column].identifier.rawValue) else { return [] }
        switch columnIdentifier {
        case .nama:
            return Array(ReusableFunc.namasiswa)
        case .alamat:
            return Array(ReusableFunc.alamat)
        case .ttl:
            return Array(ReusableFunc.ttl)
        case .nis:
            return Array(ReusableFunc.nis)
        case .nisn:
            return Array(ReusableFunc.nisn)
        case .namawali:
            return Array(ReusableFunc.namawali)
        case .ayah:
            return Array(ReusableFunc.namaAyah)
        case .ibu:
            return Array(ReusableFunc.namaIbu)
        case .tlv:
            return Array(ReusableFunc.tlvString)
        default:
            return []
        }
    }
}

extension SiswaViewController: OverlayEditorManagerDelegate {
    func overlayEditorManager(_: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard column < tableView.tableColumns.count,
              let columnIdentifier = SiswaColumn(rawValue: tableView.tableColumns[column].identifier.rawValue)
        else { return }

        let newValue = newText.capitalizedAndTrimmed()
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
                originalModel = DataAsli(ID: id, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue)
                viewModel.updateModelAndDatabase(id: id, columnIdentifier: columnIdentifier, newValue: newValue, oldValue: oldValue, isGrouped: true, groupIndex: groupIndex, rowInSection: rowIndexInSection)
                // Daftarkan aksi undo ke NSUndoManager
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    targetSelf.viewModel.undoAction(originalModel: originalModel!)
                })
            }
        } else {
            let id = viewModel.filteredSiswaData[row].id
            oldValue = viewModel.getOldValueForColumn(rowIndex: row, columnIdentifier: columnIdentifier, data: viewModel.filteredSiswaData)
            originalModel = DataAsli(ID: id, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue)
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

    func overlayEditorManager(_: OverlayEditorManager, perbolehkanEdit column: Int, row _: Int) -> Bool {
        guard let column = SiswaColumn(rawValue: tableView.tableColumns[column].identifier.rawValue) else { return false }
        if column == .tahundaftar ||
            column == .tanggalberhenti ||
            column == .status ||
            column == .jeniskelamin
        {
            return false
        }
        return true
    }
}
