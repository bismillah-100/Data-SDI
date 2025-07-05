//
//  SiswaViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa

/// Enum untuk menentukan tableView dalam mode group atau non-grup.
enum TableViewMode: Int {
    case plain //  0
    case grouped // 1
}

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
    let tagMenuItem2 = NSMenuItem()

    /// Menu item pilihan untuk mengubah  kelas aktif siswa di ``itemSelectedMenu``.
    let tagMenuItem = NSMenuItem()

    /// Properti untuk menyimpan referensi penggunaan `usesAlternatingRowBackgroundColors` di ``tableView``.
    lazy var useAlternateColor = true

    /// Kolom pertama sebelumnya yang dipin di topView clipView.
    ///
    /// Berguna untuk mengetahui apakah nama kolom pertama sama ketika scrolling.
    /// - Ketika nama kolom pertama berbeda dengan kolom selanjutnya ketika scrolling, ``scrollViewDidScroll(_:)`` akan memperbarui nama kolom pertama dengan nama kolom pertama berikutnya yang sedang discroll.
    var previousColumnTitle: String = ""

    /// Instans singleton ``DatabaseController``.
    let dbController = DatabaseController.shared

    /// Properti yang menyimpan indeks baris-baris yang dipilih di ``tableView``
    /// untuk digunakan ketika akan mengedit atau menambahkan data.
    lazy var rowDipilih: [IndexSet] = []

    /// Properti instans ``SiswaViewModel`` sekaligus initiate nya.
    let viewModel = SiswaViewModel.shared

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
         Variabel ini digunakan untuk menyimpan array dua dimensi dari objek `ModelSiswa`.
         Setiap elemen array luar adalah array dari ``ModelSiswa``, yang mewakili
         kelompok siswa `batch data siswa` yang ditempel (pasted) dari sumber eksternal.
     */
    var pastedSiswasArray = [[ModelSiswa]]()

    /// Digunakan untuk membuat `Data` kosong ketika akan menempelkan data ke tableView.
    lazy var selectedImageData = Data()

    /**
         Variabel ini digunakan untuk menyimpan array dua dimensi dari objek `ModelSiswa`.
         Setiap elemen array luar adalah array dari ``ModelSiswa``, yang mewakili
         kelompok siswa `batch data siswa` yang dihapus setelah melakukan undo.
     */
    var redoDeletedSiswaArray = [[ModelSiswa]]()

    /// Instans `NSOperationQueue`
    let operationQueue = OperationQueue()

    /// Properti untuk menyimpan referensi jika ``viewModel`` telah mendapatkan data yang ada
    /// di database dan telah ditampilkan setiap barisnya di ``tableView``
    var isDataLoaded: Bool = false

    /// Properti indeks untuk menyimpan baris-baris yang dipilih sebelumnya.
    var previouslySelectedRows: IndexSet = .init()

    /// Array untuk menyimpan data yang baru ditambahkan untuk keperluan undo/redo.
    var urungsiswaBaruArray: [ModelSiswa] = []
    /// Array untuk menyimpan data yang baru durungkan ditambahkan untuk keperluan undo/redo.
    var ulangsiswaBaruArray: [ModelSiswa] = []

    /// Instans `NSPopOver`.
    var popover = NSPopover()

    /// Array untuk menyimpan kumpulan ID unik dari data pada baris yang dipilih. Digunakan untuk memilihnya kembali setelah tabel diperbarui.
    var selectedIds: Set<Int64> = []

    /// Menu untuk header di kolom ``tableView``.
    let headerMenu = NSMenu()

    /// Work item untuk menangani input pencarian di toolbar.
    var searchItem: DispatchWorkItem?

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
            guard let self else { timer.invalidate(); return }
            self.updateUndoRedo(self)
            self.view.window?.makeFirstResponder(self.tableView)
            ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: self.stringPencarian)
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
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        ReusableFunc.resetMenuItems()
        searchItem?.cancel()
        searchItem = nil
    }

    /**
     Menyimpan data siswa setelah menerima notifikasi.

     Fungsi ini dipanggil sebagai respons terhadap notifikasi, dan melakukan serangkaian operasi asinkron untuk menyimpan data siswa,
     membersihkan array yang tidak diperlukan, memfilter siswa yang dihapus, dan memperbarui status undo/redo.

     - Parameter:
        - notification: Notifikasi yang memicu penyimpanan data.
     */
    @objc func saveData(_ notification: Notification) {
        guard isDataLoaded else { return }

        // Inisialisasi DispatchGroup
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            self.urungsiswaBaruArray.removeAll()
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
            guard let self else { return }
            self.dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    SiswaViewModel.siswaUndoManager.removeAllActions()
                    self.updateUndoRedo(self)
                }
            }
        }
    }

    /**
     Menangani notifikasi `.kelasDihapus` untuk memperbarui data siswa dan tampilan tabel.

     Fungsi ini dipanggil ketika menerima notifikasi `kelasDihapus` yang berisi informasi tentang kelas yang dihapus dan siswa yang perlu diperbarui. Fungsi ini memperbarui properti `kelasSekarang` siswa dan memuat ulang baris yang sesuai di tampilan tabel.

     - Parameter notification: Objek `Notification` yang berisi informasi tentang kelas yang dihapus dan siswa yang perlu diperbarui. `userInfo` dari notifikasi harus berisi kunci berikut:
        - `"tableType"`: `TableType` yang menunjukkan kelas mana yang dihapus.
        - `"deletedKelasIDs"`: Array `Int64` yang berisi ID siswa yang kelasnya dihapus.
        - `"naikKelas"`: `Bool` yang menunjukkan apakah siswa naik kelas atau tidak.

     - Catatan: Fungsi ini menggunakan `DispatchQueue.main.asyncAfter` untuk menunda pemuatan ulang tampilan tabel untuk memberikan efek visual yang lebih baik.
     */
    @objc func kelasAktifDiupdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tableType = userInfo["tableType"] as? TableType,
              let siswaIDs = userInfo["deletedKelasIDs"] as? [Int64],
              let naik = userInfo["naikKelas"] as? Bool,
              naik == true
        else {
            return
        }

        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama"))

        // Tentukan kelas baru berdasarkan tableType
        let newKelas = switch tableType {
        case .kelas1: "Kelas 2"
        case .kelas2: "Kelas 3"
        case .kelas3: "Kelas 4"
        case .kelas4: "Kelas 5"
        case .kelas5: "Kelas 6"
        case .kelas6: "Lulus"
        }

        // Update data siswa
        for (index, siswa) in viewModel.filteredSiswaData.enumerated() {
            guard siswaIDs.contains(siswa.id),
                  siswa.kelasSekarang.rawValue != newKelas else { continue }
            siswa.kelasSekarang = KelasAktif(rawValue: newKelas) ?? .belumDitentukan

            // Update data siswa menggunakan method baru
            viewModel.updateSiswa(siswa, at: index)

            // Update UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }

                // Reload specific row
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: index),
                                          columnIndexes: IndexSet([columnIndexOfKelasAktif]))
            }
        }
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
                 - Menginisialisasi `SuggestionManager`.
                 - Mengonfigurasi menu konteks (context menu) `itemSelectedMenu`.
                 - Membuat dan memasukkan item menu kustom (custom menu item) ke dalam menu konteks.
                 - Menetapkan menu yang telah dikonfigurasi ke `tableView`.
                 - Menutup jendela progress (progress window) jika ada.
                 - Menandai bahwa data telah dimuat (`isDataLoaded = true`).
     */
    func filterDeletedSiswa() {
        guard let rawSortDescriptor = loadSortDescriptor() else { return }
        let descriptorWrapper = SortDescriptorWrapper.from(rawSortDescriptor)
        let isGrouped = currentTableViewMode != .plain
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

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
                guard let self else { return }
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
    @objc func handlePopupDismissed(_ sender: Any) {
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
        guard let toolbar = view.window?.toolbar else { return }
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.isEnabled = true
            searchField.isEditable = true
            searchField.target = self
            searchField.action = #selector(procSearchFieldInput(sender:))
            searchField.delegate = self
            if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
                textFieldInsideSearchField.placeholderString = "Cari siswa..."
            }
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl
        {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = tableView.selectedRow != -1
        }

        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            edit.isEnabled = tableView.selectedRow != -1
        }

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton
        {
            tambah.isEnabled = false
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton
        {
            add.isEnabled = true
            addToolbarItem.toolTip = "Tambahkan Data Siswa Baru"
            add.toolTip = "Tambahkan Data Siswa Baru"
            addButton = add
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButtom = popUpMenuToolbarItem.view as? NSPopUpButton
        {
            popUpButtom.menu = itemSelectedMenu
        }
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

    /**
     Menangani saat aplikasi menjadi aktif (foreground). Fungsi ini memberikan efek visual (border) pada baris yang dipilih di `tableView` jika ada baris yang dipilih dan `currentTableViewMode` adalah `.plain`.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Memastikan ada baris yang dipilih dan mode tampilan adalah `.plain`. Jika tidak, fungsi akan langsung kembali.
     2. Mendapatkan indeks dari baris-baris yang dipilih.
     3. Melakukan iterasi pada setiap indeks baris yang dipilih.
     4. Untuk setiap baris, mendapatkan `NSTableCellView` yang sesuai.
     5. Mengambil data siswa yang sesuai dengan baris tersebut dari `viewModel.filteredSiswaData`.
     6. Meminta gambar dengan border dari `viewModel` menggunakan `getImageForKelas` berdasarkan kelas siswa saat ini.
     7. Setelah gambar diterima, memperbarui `imageView` dari `selectedCellView` dengan gambar yang baru (dengan border) secara asinkron di main thread.
     8. Menghapus observer untuk notifikasi `windowControllerBecomeKey`.
     9. Menambahkan observer untuk notifikasi `windowControllerResignKey` dan menunjuk ke fungsi `appNonAktif(_:)`.

     - Parameter sender: Objek yang mengirimkan notifikasi.
     */
    @objc func appAktif(_ sender: Any) {
        guard tableView.selectedRow != -1, currentTableViewMode == .plain else { return }
        let selectedRowIndexes = tableView.selectedRowIndexes

        // Tambahkan border ke semua baris yang dipilih
        for row in selectedRowIndexes {
            guard row < viewModel.filteredSiswaData.count else { continue }
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                let image = self.viewModel.determineImageName(for: siswa.kelasSekarang.rawValue, bordered: true)
                DispatchQueue.main.async { [weak selectedCellView] in
                    selectedCellView?.imageView?.image = NSImage(named: image)
                }
            }
        }
        NotificationCenter.default.removeObserver(self, name: .windowControllerBecomeKey, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appNonAktif(_:)), name: .windowControllerResignKey, object: nil)
    }

    /**
     Fungsi ini dipanggil ketika aplikasi tidak aktif setelah menerima notifikas `.windowControllerResignKey`.

     Fungsi ini melakukan hal berikut:
     1. Memastikan ada baris yang dipilih di `tableView` dan mode `tableView` adalah `.plain`. Jika tidak, fungsi akan langsung kembali.
     2. Mendapatkan indeks dari baris-baris yang dipilih.
     3. Untuk setiap baris yang dipilih, fungsi akan:
        - Mendapatkan `NSTableCellView` yang sesuai.
        - Mendapatkan data siswa untuk baris tersebut dari `viewModel`.
        - Meminta `viewModel` untuk mendapatkan gambar kelas tanpa border untuk siswa tersebut.
        - Setelah gambar diperoleh, gambar tersebut akan ditampilkan di `imageView` dari `selectedCellView` pada thread utama.
     4. Menghapus observer untuk notifikasi `windowControllerResignKey`.
     5. Menambahkan observer untuk notifikasi `windowControllerBecomeKey` dan menautkannya ke fungsi `appAktif(_:)`.

     - Parameter:
        - sender: Objek yang mengirimkan notifikasi.
     */
    @objc func appNonAktif(_ sender: Any) {
        guard tableView.selectedRow != -1, currentTableViewMode == .plain else { return }
        let selectedRowIndexes = tableView.selectedRowIndexes

        // Tambahkan border ke semua baris yang dipilih
        for row in selectedRowIndexes {
            guard row < viewModel.filteredSiswaData.count else { continue }
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                let image = self.viewModel.determineImageName(for: siswa.kelasSekarang.rawValue, bordered: false)
                DispatchQueue.main.async { [weak selectedCellView] in
                    selectedCellView?.imageView?.image = NSImage(named: image)
                }
            }
        }
        NotificationCenter.default.removeObserver(self, name: .windowControllerResignKey, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appAktif(_:)), name: .windowControllerBecomeKey, object: nil)
    }

    /// Fungsi untuk menerapkan tinggi ``tableView`` ketika pertama kali dimuat.
    func setupTable() {
        if let savedRowHeight = UserDefaults.standard.value(forKey: "SiswaTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
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
    @IBAction func beralihSiswaLulus(_ sender: Any) {
        // Toggle pengaturan "tampilkanSiswaLulus"
        var tampilkanSiswaLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")
        tampilkanSiswaLulus.toggle()
        UserDefaults.standard.setValue(tampilkanSiswaLulus, forKey: "tampilkanSiswaLulus")

        let isGrouped = (currentTableViewMode != .plain)

        let sortDescriptor = loadSortDescriptor()!
        Task(priority: .userInitiated) { [unowned self] in
            if !isGrouped {
                let index = await self.viewModel.filterSiswaLulus(tampilkanSiswaLulus, sortDesc: SortDescriptorWrapper.from(sortDescriptor))
                if !tampilkanSiswaLulus {
                    // Hapus baris siswa yang berhenti
                    for i in index.reversed() {
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
                        guard let self else { return }
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
                await self.viewModel.fetchSiswaData()
                await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: self.isBerhentiHidden)

                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        } else {
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await self.viewModel.fetchSiswaData()
                await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: self.isBerhentiHidden)

                await MainActor.run { [weak self] in
                    self?.sortData(with: sortDescriptor)
                }
            }
        }
        updateUndoRedo(sender)
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/SiswaViewController``
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

    /// Action untuk menu item "Kelompokkan Data" di Menu Bar.
    /// - Parameter sender: Objek pemicu.
    @IBAction func groupMode(_ sender: NSMenuItem) {
        searchItem?.cancel()
        let menu = NSMenuItem()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            menu.tag = self.currentTableViewMode == .plain ? 1 : 0
            self.changeTableViewMode(menu)
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
    @IBAction func toggleBerhentiVisibility(_ sender: Any) {
        isBerhentiHidden.toggle()
        let sortDescriptor = loadSortDescriptor()!
        Task(priority: .userInitiated) { [unowned self] in
            if currentTableViewMode == .plain {
                let index = await viewModel.filterSiswaBerhenti(isBerhentiHidden, sortDescriptor: SortDescriptorWrapper.from(sortDescriptor))
                if self.isBerhentiHidden {
                    // Hapus baris siswa yang berhenti
                    for i in index.reversed() {
                        self.viewModel.removeSiswa(at: i)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        self.tableView.removeRows(at: IndexSet(index), withAnimation: .slideDown)
                    }
                } else {
                    await MainActor.run { [weak self] in
                        guard let self else { return }
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

    /**
     Menangani perubahan nilai pada `NSDatePicker` yang muncul ketika baris di kolom `tanggalBerhenti` atau `tahunDaftar` diedit.

     Fungsi ini dipanggil ketika nilai pada `NSDatePicker` diubah. Fungsi ini akan memperbarui data siswa yang sesuai di dalam model dan database, serta menyiapkan aksi undo.

     - Parameter sender: `NSDatePicker` yang mengirimkan aksi. Tag pada `NSDatePicker` digunakan untuk menentukan kolom mana yang sedang diubah.
     */
    @objc func datePickerValueChanged(_ sender: NSDatePicker) {
        let clickedRow = tableView.selectedRow

        // Check if a valid row is selected
        guard clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count else {
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
                // tableView.gridStyleMask = .solidHorizontalGridLineMask
                // tableView.gridStyleMask = .solidVerticalGridLineMask
                for column in tableView.tableColumns {
                    if column.identifier.rawValue != "Nama" {
                        if !headerMenu.items.contains(where: { $0.title == column.title }) {
                            let menuItem = NSMenuItem(title: column.title, action: #selector(toggleColumnVisibility(_:)), keyEquivalent: "")
                            menuItem.representedObject = column
                            menuItem.state = column.isHidden ? .off : .on
                            let smallFont = NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small))
                            menuItem.attributedTitle = NSAttributedString(string: column.title, attributes: [.font: smallFont])
                            headerMenu.addItem(menuItem)
                        }
                    }
                }
                tableView.headerView?.menu = headerMenu
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
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [weak self] in
                        guard let self else { return }
                        await self.viewModel.fetchSiswaData()
                        await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)

                        await MainActor.run { [weak self] in
                            guard let self else { return }
                            // Setelah filtering selesai, update UI di sini
                            self.updateGroupedUI()
                        }
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
        offsetY += 18
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
            // let currentAlpha = 1.0 - progress
            let nextAlpha = progress

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

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
                previousColumnTitle = newTitle
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

    /**
         Menentukan indeks grup berdasarkan nama kelas siswa.

         Fungsi ini menerima nama kelas sebagai input dan mengembalikan indeks grup yang sesuai.
         Kelas "Lulus" akan dimasukkan ke dalam grup dengan indeks 6. Kelas dengan nama kosong "" akan dimasukkan ke grup dengan indeks 7.
         Untuk kelas dengan format "Kelas [nomor]", fungsi akan mengekstrak nomor kelas dan menggunakannya untuk menentukan indeks grup.
         Nomor kelas 1-6 akan menghasilkan indeks grup 0-5 secara berurutan.

         - Parameter:
             - className: Nama kelas siswa (misalnya, "Kelas 1", "Kelas 6", "Lulus").

         - Returns:
             Indeks grup yang sesuai dengan nama kelas. Mengembalikan `nil` jika nama kelas tidak valid atau tidak dikenali.
     */
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
                if kelasIndex >= 1, kelasIndex <= 6 {
                    // Mengembalikan indeks grup berdasarkan nomor kelas (kurangi 1 karena array dimulai dari indeks 0)
                    return kelasIndex - 1
                }
            }
        }
        // Jika kelas tidak ditemukan atau nomor kelas tidak valid, kembalikan nilai nil
        return nil
    }

    // MARK: - GENERAL REUSABLE FUNC

    /**
         Mengembalikan tipe tabel yang sesuai berdasarkan kelas yang diberikan.

         - Parameter kelas: String yang merepresentasikan nama kelas (contoh: "Kelas 1", "Kelas 2", dst.).
         - Returns: Nilai enum `TableType` yang sesuai dengan kelas yang diberikan, atau `nil` jika kelas tidak dikenali.
     */
    func tableType(forKelas kelas: String) -> TableType? {
        switch kelas {
        case "Kelas 1":
            .kelas1
        case "Kelas 2":
            .kelas2
        case "Kelas 3":
            .kelas3
        case "Kelas 4":
            .kelas4
        case "Kelas 5":
            .kelas5
        case "Kelas 6":
            .kelas6
        default:
            nil
        }
    }

    /**
     Memperbarui tampilan tabel setelah operasi pemindahan siswa.

     Fungsi ini menangani pembaruan tampilan tabel setelah sebuah siswa dipindahkan dari satu posisi ke posisi lain.
     Ini termasuk pembatalan pencarian yang sedang berlangsung, pemindahan baris pada tabel, pemuatan ulang data untuk baris yang dipindahkan,
     pengguliran ke posisi baru, dan penyesuaian tampilan header tabel.

     - Parameter from: Tuple yang menunjukkan indeks grup dan baris asal siswa yang dipindahkan.
     - Parameter to: Tuple yang menunjukkan indeks grup dan baris tujuan siswa yang dipindahkan.

     - Note: Fungsi ini menggunakan `DispatchWorkItem` untuk menunda beberapa operasi UI agar animasi dan pembaruan terjadi dengan lancar.
     */
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
        tableView.reloadData(forRowIndexes: IndexSet(integer: toRow), columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
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

    // MARK: - SORTDESCRIPTOR FUNC

    /**
         Mengatur deskriptor pengurutan untuk setiap kolom dalam tabel. Fungsi ini mengiterasi melalui setiap kolom tabel,
         mengambil pengidentifikasi kolom, dan menetapkan deskriptor pengurutan yang sesuai dari kamus `identifikasiKolom`.
         Deskriptor pengurutan ini kemudian digunakan sebagai prototipe untuk memungkinkan pengurutan data dalam kolom tersebut.
     */
    func setupDescriptor() {
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
        Task(priority: .userInitiated) { [unowned self] in
            if currentTableViewMode == .plain {
                // Lakukan pengurutan untuk mode tanpa grup
                await self.viewModel.sortSiswa(by: SortDescriptorWrapper.from(sortDescriptor), isBerhenti: self.isBerhentiHidden)
                for id in self.selectedIds {
                    if let index = self.viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
                        indexset.insert(index)
                    }
                }
            } else {
                await viewModel.sortGroupSiswa(by: SortDescriptorWrapper.from(sortDescriptor))

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
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.tableView.reloadData()
                if self.currentTableViewMode == .grouped {}
                self.tableView.selectRowIndexes(indexset, byExtendingSelection: false)
                if let max = indexset.max() {
                    self.tableView.scrollRowToVisible(max)
                }
            }
        }
    }

    /**
         Mengurutkan data pencarian siswa berdasarkan descriptor pengurutan yang diberikan.

         Fungsi ini melakukan pengurutan data siswa, baik secara individual maupun dalam grup,
         berdasarkan `NSSortDescriptor` yang diberikan. Setelah pengurutan selesai, tampilan tabel
         akan diperbarui untuk mencerminkan urutan data yang baru.

         - Parameter sortDescriptor: Descriptor pengurutan yang akan digunakan untuk mengurutkan data.
     */
    func urutkanDataPencarian(with sortDescriptor: NSSortDescriptor) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        // Lakukan pengurutan untuk mode dengan grup
        await viewModel.sortGroupSiswa(by: SortDescriptorWrapper.from(sortDescriptor))
        await MainActor.run {
            let row = tableView.selectedRowIndexes
            tableView.reloadData()
            tableView.selectRowIndexes(row, byExtendingSelection: true)
        }
    }

    /**
     Menyimpan `NSSortDescriptor` ke UserDefaults.

     - Parameter sortDescriptor: `NSSortDescriptor` yang akan disimpan. Jika nil, maka sort descriptor akan dihapus dari UserDefaults.
     */
    func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?) {
        // Simpan sort descriptor ke UserDefaults
        if let sortDescriptor {
            let sortDescriptorData = try? NSKeyedArchiver.archivedData(withRootObject: sortDescriptor, requiringSecureCoding: false)
            UserDefaults.standard.set(sortDescriptorData, forKey: "sortDescriptor")
        } else {
            UserDefaults.standard.removeObject(forKey: "sortDescriptor")
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
        if let sortDescriptorData = UserDefaults.standard.data(forKey: "sortDescriptor"),
           let sortDescriptor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSortDescriptor.self, from: sortDescriptorData)
        {
            sortDescriptor
        } else {
            NSSortDescriptor(key: "nama", ascending: true)
        }
    }

    // MARK: - OPERATION. MENUITEMS, ADD/EDIT/DELETE, UNDO-REDO.

    /**
     Menangani aksi penambahan siswa baru.

     Fungsi ini dipanggil ketika tombol "Tambah Siswa" ditekan. Fungsi ini akan:
     1. Mengosongkan array `rowDipilih`.
     2. Membuat dan menampilkan popover yang berisi `AddDataViewController`.
     3. Mengatur `sourceViewController` pada `AddDataViewController` menjadi `.siswaViewController`.
     4. Menampilkan popover relatif terhadap tombol yang ditekan.
     5. Menonaktifkan fitur drag pada `AddDataViewController`.
     6. Menambahkan indeks baris yang dipilih ke array `rowDipilih` jika ada baris yang dipilih.
     7. Menghapus semua pilihan baris pada `tableView`.
     8. Mereset menu items.

     - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
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

        guard tableView.selectedRowIndexes.count > 0 else { return }
        rowDipilih.append(tableView.selectedRowIndexes)
        tableView.deselectAll(sender)
        ReusableFunc.resetMenuItems()
    }

    /**
         Menangani aksi untuk menambahkan siswa melalui jendela baru.

         Fungsi ini mencoba untuk memicu aksi tombol "add" yang ada di toolbar jendela utama. Jika tombol "add" tidak ditemukan di toolbar, fungsi ini akan membuka jendela baru untuk menambahkan data siswa.

         Jika jendela dengan identifier "addSiswaWindow" sudah ada, jendela tersebut akan ditampilkan dan dijadikan key window. Jika tidak, jendela baru akan dibuat dengan `AddDataViewController` sebagai kontennya. Jendela baru ini memiliki beberapa konfigurasi khusus seperti tombol zoom dan minimize yang dinonaktifkan, titlebar yang transparan, dan animasi fade-in saat ditampilkan.

         - Parameter:
            - sender: Objek yang memicu aksi ini. Bisa berupa `Any?`.
     */
    @IBAction func addSiswaNewWindow(_ sender: Any?) {
        if let toolbar = view.window?.toolbar, let addItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }) {
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

    @IBAction func handlePrint(_ sender: Any) {
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
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight += 5
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
        }, completionHandler: nil)
        saveRowHeight()
    }

    /// Lihat: ``DataSDI/ReusableFunc/decreaseSize(_:)``.
    @IBAction func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight = max(tableView.rowHeight - 3, 16)
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
        }, completionHandler: nil)

        saveRowHeight()
    }

    /// Menyimpan tinggi baris `tableView` saat ini ke `UserDefaults`.
    ///
    /// Fungsi ini digunakan untuk menyimpan preferensi tinggi baris pengguna secara persisten.
    /// Tinggi baris `tableView` saat ini akan disimpan di bawah kunci "SiswaTableViewRowHeight"
    /// di `UserDefaults`, memungkinkan aplikasi untuk memuatnya kembali di lain waktu.
    func saveRowHeight() {
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "SiswaTableViewRowHeight")
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
    @IBAction func exportToExcel(_ sender: NSMenuItem) {
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
    @IBAction func exportToPDF(_ sender: NSMenuItem) {
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
                ReusableFunc.chooseFolderAndSaveCSV(header: header, rows: data, namaFile: "Data Siswa", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: pdf) { data in
                    [data.nama, data.alamat, String(data.nisn), String(data.nis), data.namawali, data.ayah, data.ibu, data.tlv, data.jeniskelamin.rawValue, data.kelasSekarang.rawValue, data.tahundaftar, data.status.rawValue, data.tanggalberhenti]
                }
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /**
     * Fungsi ini dijalankan ketika mengubah status siswa dari menu klik kanan atau dari menu di toolbar.
     * Fungsi ini menangani logika untuk mengubah status siswa, baik ketika baris tertentu diklik atau ketika tidak ada baris yang diklik tetapi ada baris yang dipilih.
     *
     * - Parameter sender: Objek NSMenuItem yang memicu aksi ini.
     */
    @IBAction func ubahStatus(_ sender: NSMenuItem) {
        guard let tableView else { return }
        // Jika ada baris yang diklik
        if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                pilihubahStatus(sender)
            } else {
                klikubahStatus(sender)
            }
        } else if tableView.clickedRow == -1, tableView.selectedRowIndexes.last ?? 0 < viewModel.filteredSiswaData.count {
            pilihubahStatus(sender)
        }
    }

    /**
         Menangani penempelan data dari clipboard ke dalam tampilan tabel siswa.

         Fungsi ini mengambil data dari clipboard, menguraikannya menjadi objek `ModelSiswa`,
         dan menambahkannya ke database dan tampilan tabel. Fungsi ini mendukung format
         yang dipisahkan oleh tab dan dipisahkan oleh koma. Fungsi ini juga menangani
         pelaporan kesalahan untuk format data yang tidak valid dan menyediakan
         fungsionalitas undo untuk operasi tempel.

         - Parameter:
            - sender: Objek yang memicu aksi.
     */
    @IBAction func pasteClicked(_ sender: Any) {
        if tableView.numberOfRows == 0 {
            tableView.reloadData()
        }

        // Dapatkan data yang ada di clipboard
        let pasteboard = NSPasteboard.general
        var errorMessages: [String] = []
        guard let stringData = pasteboard.string(forType: .string) else { return }

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

            } else {}
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
                siswa.jeniskelamin = JenisKelamin(rawValue: rowComponents[index]) ?? .lakiLaki
            }
            if let index = columnIndexTahunDaftar {
                siswa.tahundaftar = rowComponents[index]
            }
            if let index = columnIndexOfStatus {
                siswa.status = StatusSiswa(rawValue: rowComponents[index]) ?? .aktif
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
                dbController.catatSiswa(namaValue: siswa.nama, alamatValue: siswa.alamat, ttlValue: siswa.ttl, tahundaftarValue: siswa.tahundaftar, namawaliValue: siswa.namawali, nisValue: siswa.nis, nisnValue: siswa.nisn, namaAyah: siswa.ayah, namaIbu: siswa.ibu, jeniskelaminValue: siswa.jeniskelamin.rawValue, statusValue: siswa.status.rawValue, tanggalberhentiValue: siswa.tanggalberhenti, kelasAktif: "", noTlv: siswa.tlv, fotoPath: selectedImageData)

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

    /// Action dari menu item paste di Menu Bar yang menjalankan
    /// ``paste(_:)``.
    /// - Parameter sender: Objek yang memicu.
    @IBAction func paste(_ sender: Any) {
        pasteClicked(self)
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
    @objc func detailSelectedRow(_ sender: Any) {
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

                if groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count {
                    selectedSiswas.append(viewModel.groupedSiswa[groupIndex][rowIndexInSection])
                }
            }
        }
        ReusableFunc.bukaRincianSiswa(selectedSiswas, viewController: self)
    }

    /// Seperti logika ``detailSelectedRow(_:)``, tetapi hanya untuk satu baris yang diklik kanan.
    /// Penjelasan lebih lanjut lihat: ``showDetail(_:)``.
    @objc func detailClickedRow(_ sender: Any) {
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

    // MARK: - TAMBAHKAN DATA BARU

    /**
     Menangani notifikasi DatabaseController.siswaBaru.
     Fungsi ini akan menyisipkan siswa baru ke dalam tampilan tabel,
     baik dalam mode tampilan biasa maupun mode tampilan berkelompok, dan memperbarui tampilan tabel sesuai.

     - Parameter notification: Notifikasi yang berisi informasi tentang perubahan data siswa.

     - Catatan: Fungsi ini juga menangani pendaftaran dan pembatalan undo untuk operasi penyisipan siswa,
       serta memperbarui status tombol undo/redo.
     */
    @objc func handleDataDidChangeNotification(_ notification: Notification) {
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
            guard let group = getGroupIndex(forClassName: insertedSiswa.kelasSekarang.rawValue),
                  let sortDescriptor = ModelSiswa.currentSortDescriptor
            else {
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
                result + section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
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

    /**
     * Fungsi ini membatalkan penambahan siswa baru.
     *
     * Fungsi ini menghapus siswa terakhir dari array `urungsiswaBaruArray`, memperbarui tampilan tabel,
     * dan mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager`.
     * Fungsi ini juga memperbarui `SingletonData` dan mengirimkan pemberitahuan (`NotificationCenter`)
     * tentang penghapusan siswa.
     *
     * - Parameter sender: Objek yang memicu tindakan ini (misalnya, tombol undo).
     */
    func urungSiswaBaru(_ sender: Any) {
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
                    // Dapatkan informasi baris untuk id siswa yang dihapus
                    let rowInfo = getRowInfoForRow(siswaIndex)
                    // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas

                    // Hitung indeks absolut untuk menghapus baris dari NSTableView
                    var absoluteRowIndex = 0
                    for i in 0 ..< groupIndex {
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
                "kelasSekarang": siswa.kelasSekarang.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            self.updateUndoRedo(sender)
        }
    }

    /**
     * Fungsi ini mengembalikan data siswa yang baru ditambahkan ke tampilan tabel dan memperbarui antrian undo/redo.
     *
     * - Parameter sender: Objek yang memicu aksi ini.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Mengambil descriptor pengurutan saat ini. Jika tidak ada, fungsi akan keluar.
     * 2. Menghapus siswa terakhir dari array `ulangsiswaBaruArray` dan menambahkannya ke array `urungsiswaBaruArray`.
     * 3. Membatalkan pilihan semua baris di tampilan tabel.
     * 4. Memulai pembaruan tampilan tabel.
     * 5. Jika tampilan tabel dalam mode plain:
     *    - Menemukan indeks yang sesuai untuk memasukkan siswa kembali sesuai dengan descriptor pengurutan saat ini.
     *    - Memasukkan siswa ke dalam array `viewModel.filteredSiswaData` pada indeks yang ditemukan.
     *    - Memperbarui tampilan tabel dengan memasukkan baris baru pada indeks yang sesuai.
     *    - Menggulir tampilan tabel ke baris yang baru dimasukkan.
     *    - Memilih baris yang baru dimasukkan.
     * 6. Jika tampilan tabel dalam mode grup:
     *    - Mendapatkan indeks grup untuk kelas siswa saat ini. Jika tidak ada, fungsi akan keluar.
     *    - Menghitung ulang indeks penyisipan berdasarkan grup yang baru.
     *    - Memasukkan siswa kembali ke dalam array `viewModel.groupedSiswa` pada grup dan indeks yang tepat.
     *    - Memperbarui tampilan tabel dengan menyisipkan baris baru pada indeks yang sesuai.
     *    - Menggulir tampilan tabel ke baris yang baru dimasukkan.
     *    - Memilih baris yang baru dimasukkan.
     * 7. Mengakhiri pembaruan tampilan tabel.
     * 8. Mencatat tindakan redo ke dalam `SiswaViewModel.siswaUndoManager`.
     * 9. Menetapkan nama aksi undo menjadi "Redo Add New Data".
     * 10. Menghapus siswa terakhir dari array `SingletonData.undoAddSiswaArray`.
     * 11. Menghapus ID siswa dari array `SingletonData.deletedStudentIDs`.
     * 12. Memposting notifikasi `undoSiswaDihapus` untuk memberitahu komponen lain tentang tindakan undo.
     * 13. Memperbarui status tombol undo/redo.
     */
    func ulangSiswaBaru(_ sender: Any) {
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
            guard let group = getGroupIndex(forClassName: siswa.kelasSekarang.rawValue) else { return }

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
            for i in 0 ..< group {
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
                "kelasSekarang": siswa.kelasSekarang.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
            self.updateUndoRedo(sender)
        }
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

    /**
         Menangani aksi saat baris yang diklik disalin.

         Fungsi ini menyalin data dari baris yang diklik pada `tableView` ke clipboard.
         Data yang disalin mencakup semua kolom pada baris tersebut, dipisahkan oleh tab,
         dan setiap baris diakhiri dengan newline.

         - Parameter sender: Objek yang memicu aksi (misalnya, tombol atau item menu).

         ## Detail Implementasi:
         1. Memastikan ada baris yang diklik pada `tableView`. Jika tidak ada, fungsi akan keluar.
         2. Mendapatkan indeks baris yang diklik.
         3. Iterasi melalui setiap kolom pada baris yang diklik.
         4. Mendapatkan data dari setiap sel, baik itu dari `textField` pada `CustomTableCellView` atau `NSTableCellView`,
            atau dari `datePicker` pada `CustomTableCellView` (dalam format "dd MMMM yyyy").
         5. Menggabungkan data dari setiap kolom dengan pemisah tab.
         6. Menghapus tab terakhir dan menambahkan newline di akhir data yang disalin.
         7. Menyalin data yang telah diformat ke clipboard sistem.
     */
    @objc func copyClickedRow(_ sender: Any) {
        // Periksa apakah ada baris yang diklik
        guard tableView.clickedRow >= 0 else {
            return
        }

        // Dapatkan baris yang diklik
        let clickedRow = tableView.clickedRow
        var copiedData = ""

        let columnCount = tableView.tableColumns.count

        for columnIndex in 0 ..< columnCount {
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
                      let textField = cellView.textField
            {
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
    @objc func copySelectedRows(_ sender: Any) {
        guard let tableView, !tableView.selectedRowIndexes.isEmpty else {
            return
        }
        var copiedData = ""
        let columnCount = tableView.tableColumns.count

        for rowIndex in tableView.selectedRowIndexes {
            var rowData = ""

            for columnIndex in 0 ..< columnCount {
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
                          let textField = cellView.textField
                {
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

    /**
         *   Fungsi ini dipanggil ketika tombol salin ditekan.
         *   Jika ada baris yang dipilih di tabel, fungsi `copySelectedRows` akan dipanggil.
         *   Jika tidak ada baris yang dipilih, sebuah alert akan ditampilkan yang memberitahukan pengguna untuk memilih baris terlebih dahulu.
         *
         *   @param sender Objek yang memicu aksi ini.
     */
    @IBAction func copy(_ sender: Any) {
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

    // MARK: - EDIT DATA

    /**
      Menangani aksi penyuntingan data siswa.

      Fungsi ini dipanggil ketika tombol edit ditekan. Fungsi ini menangani logika pemilihan baris pada tabel,
      baik dalam mode tampilan `.grouped` maupun mode lainnya, dan mempersiapkan tampilan `EditData`
      untuk menampilkan dan mengedit data siswa yang dipilih.

      - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol edit).

      - Catatan: Fungsi ini mempertimbangkan beberapa skenario pemilihan baris, termasuk pemilihan tunggal,
         pemilihan ganda, dan tidak ada baris yang dipilih. Fungsi ini juga membedakan antara mode tampilan
         `.grouped` dan mode lainnya untuk menentukan cara mengambil data siswa yang sesuai.

      - Precondition: `tableView` harus sudah diinisialisasi dan memiliki data yang valid.
         `viewModel` harus sudah diinisialisasi dengan data siswa yang sesuai.

      - Postcondition: Tampilan `EditData` akan ditampilkan sebagai sheet dengan data siswa yang dipilih,
         dan menu item akan direset.
     */
    @IBAction func edit(_ sender: Any) {
        rowDipilih.removeAll()
        let clickedRow = tableView.clickedRow
        var selectedRows = tableView.selectedRowIndexes
        selectedSiswaList.removeAll()
        let editView = EditData(nibName: "EditData", bundle: nil)

        // Jika mode adalah .grouped
        if currentTableViewMode == .grouped {
            if selectedRows.contains(clickedRow), selectedRows.count > 1 {
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
            } else if !selectedRows.isEmpty, clickedRow < 0 {
                // Lebih dari satu baris yang dipilih
                for rowIndex in selectedRows {
                    let selectedRowInfo = getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                    // Tambahkan selectedSiswa ke dalam array
                    selectedSiswaList.append(selectedSiswa)
                }
                editView.selectedSiswaList = selectedSiswaList
            } else if selectedRows.count == 1, selectedRows.contains(clickedRow) {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
            } else if selectedRows.isEmpty, clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            } else if !selectedRows.isEmpty, clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
        } else {
            selectedSiswaList = selectedRows.map { viewModel.filteredSiswaData[$0] }
            // Jika mode bukan .grouped, menggunakan pendekatan sebelumnya
            if selectedRows.contains(clickedRow) {
                guard !selectedRows.isEmpty else { return }
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty, clickedRow < 0 {
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty, clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            } else if selectedRows.isEmpty, clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            }
        }
        presentAsSheet(editView)
        ReusableFunc.resetMenuItems()
    }

    /**
     Menampilkan tampilan untuk mencari dan mengganti data siswa.

     Metode ini menangani logika pemilihan baris pada `tableView`, baik dalam mode tampilan berkelompok (`grouped`) maupun datar (`plain`),
     untuk menentukan data siswa mana yang akan diedit. Kemudian, data yang dipilih ditampilkan dalam tampilan `CariDanGanti`.

     - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol atau item menu).

     - Catatan:
        - Jika tidak ada baris yang dipilih atau diklik, tampilan `CariDanGanti` tetap ditampilkan, memungkinkan pengguna untuk mencari dan mengganti data secara manual.
        - Metode ini juga menangani pendaftaran `undo` untuk mengembalikan perubahan yang dilakukan pada data siswa.
        - Setelah pembaruan selesai, sebuah jendela progress akan ditampilkan untuk memberi tahu pengguna bahwa pembaruan telah berhasil disimpan.
     */
    @IBAction func findAndReplace(_ sender: Any) {
        // Metode tidak ada row yang diklik dan juga dipilih
        let editVC = CariDanGanti.instantiate()

        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow

        var dataToEdit = IndexSet()

        if currentTableViewMode == .grouped {
            if (selectedRows.contains(clickedRow) && selectedRows.count > 1) || (!selectedRows.isEmpty && clickedRow < 0) {
                dataToEdit = selectedRows
            } else if (selectedRows.count == 1 && selectedRows.contains(clickedRow)) ||
                (selectedRows.isEmpty && clickedRow >= 0) ||
                (!selectedRows.isEmpty && clickedRow >= 0)
            {
                dataToEdit = IndexSet([clickedRow])
                tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
            }
        } else if currentTableViewMode == .plain {
            if clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count {
                if tableView.selectedRowIndexes.contains(clickedRow) {
                    dataToEdit = selectedRows
                } else {
                    dataToEdit = IndexSet([clickedRow])
                    tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
                }
            } else {
                dataToEdit = selectedRows
            }
        }

        for row in dataToEdit {
            if currentTableViewMode == .plain {
                editVC.objectData.append(viewModel.filteredSiswaData[row].toDictionary())
            } else {
                let selectedRowInfo = getRowInfoForRow(row)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                guard rowIndexInSection >= 0 else { continue }
                editVC.objectData.append(viewModel.groupedSiswa[groupIndex][rowIndexInSection].toDictionary())
            }
        }
        for column in tableView.tableColumns {
            guard column.identifier.rawValue != "Status",
                  column.identifier.rawValue != "Tahun Daftar",
                  column.identifier.rawValue != "Tgl. Lulus",
                  column.identifier.rawValue != "Jenis Kelamin",
                  column.identifier.rawValue != "Status"
            else { continue }
            editVC.columns.append(column.identifier.rawValue)
        }

        editVC.onUpdate = { [weak self] updatedRows, selectedColumn in
            guard let self else { return }
            if self.currentTableViewMode == .plain {
                let selectedSiswaRow: [ModelSiswa] = self.tableView.selectedRowIndexes.compactMap { row in
                    let originalSiswa = self.viewModel.filteredSiswaData[row]
                    return originalSiswa.copy() as? ModelSiswa
                }
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            } else {
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
                } else if self.currentTableViewMode == .grouped, let (groupIndex, rowIndex) = self.viewModel.findSiswaInGroups(id: idValue) {
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

    /**
         * Fungsi ini menangani proses pembatalan (undo) perubahan data siswa.
         * Fungsi ini dipanggil ketika ada notifikasi yang menandakan bahwa operasi undo edit siswa perlu dilakukan.
         *
         * - Parameter notification: Notifikasi yang berisi informasi tentang data siswa yang akan dikembalikan.
         *   Notifikasi ini diharapkan memiliki `userInfo` yang berisi:
         *     - "data": Array `ModelSiswa` yang berisi snapshot data siswa sebelum perubahan.
         *
         * Proses:
         * 1. Memastikan bahwa notifikasi memiliki data yang diperlukan dan data tidak kosong.
         * 2. Membatalkan semua pilihan baris di tabel.
         * 3. Memulai pembaruan tabel secara batch.
         * 4. Berdasarkan mode tampilan tabel (`.plain` atau `.grouped`), lakukan langkah-langkah berikut:
         *    - Mode `.plain`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Memeriksa apakah siswa tersebut harus ditampilkan berdasarkan status "berhenti" atau "lulus".
         *      - Memperbarui data siswa di `viewModel`.
         *      - Menghapus baris yang sesuai dari tabel dan menyisipkan kembali di posisi yang benar.
         *      - Memindahkan baris di tabel untuk mencerminkan perubahan urutan.
         *      - Memuat ulang data di kolom yang sesuai.
         *    - Mode `.grouped`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Mencari data siswa yang sesuai di setiap grup.
         *      - Memperbarui data siswa di `viewModel`.
         *      - Memindahkan siswa antar grup jika kelasnya berubah.
         *      - Memperbarui tampilan tabel untuk mencerminkan perubahan grup dan urutan.
         * 5. Mengakhiri pembaruan tabel secara batch.
         * 6. Memperbarui tampilan tombol undo dan redo setelah beberapa saat.
         * 7. Memposting notifikasi jika ada perubahan pada tanggal berhenti siswa.
         *
         * Catatan:
         * - Fungsi ini menggunakan `viewModel` untuk mengelola data siswa.
         * - Fungsi ini menggunakan `dbController` untuk mengakses data siswa dari database.
         * - Fungsi ini menggunakan `SingletonData.siswaNaikArray` dan `SingletonData.siswaNaikId` untuk menyimpan data siswa yang naik kelas.
         * - Animasi yang digunakan adalah `.effectGap` untuk penyisipan dan `.effectFade` untuk penghapusan.
     */
    @objc func undoEditSiswa(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let snapshotSiswas = userInfo["data"] as? [ModelSiswa],
              !snapshotSiswas.isEmpty,
              let sortDescriptor = ModelSiswa.currentSortDescriptor
        else { return }

        var updateJumlahSiswa = false
        // Buat array untuk menyimpan data baris yang belum diubah
        tableView.deselectAll(self)
        tableView.beginUpdates()
        if currentTableViewMode == .plain {
            for snapshotSiswa in snapshotSiswas {
                // Ambil nilai kelasSekarang dari objek viewModel.filteredSiswaData yang sesuai dengan snapshotSiswa
                let siswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden, siswa.status.rawValue.lowercased() == "berhenti" {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswa.id }) else { continue }
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .effectGap)
                    tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: true)
                    tableView.scrollRowToVisible(insertIndex)
                } else if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus"), siswa.status.rawValue.lowercased() == "lulus" {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswa.id }) else { continue }
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
                SingletonData.siswaNaikId.removeAll(where: { $0 == snapshotSiswa.id })

                viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)

                if let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == snapshotSiswa.id }) {
                    var siswa = viewModel.filteredSiswaData[rowIndex]
                    siswa = dbController.getSiswa(idValue: viewModel.filteredSiswaData[rowIndex].id)
                    viewModel.removeSiswa(at: rowIndex)

                    if isBerhentiHidden && snapshotSiswa.status.rawValue.lowercased() == "berhenti" {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }

                    if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && snapshotSiswa.status.rawValue.lowercased() == "lulus" {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }

                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    let namaSiswaColumnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama"))
                    // Reload baris yang diperbarui
                    tableView.moveRow(at: rowIndex, to: insertIndex)
                    for columnIndex in 0 ..< tableView.numberOfColumns {
                        guard columnIndex != namaSiswaColumnIndex else { continue }
                        tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: columnIndex))
                    }
                    tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: namaSiswaColumnIndex))
                    updateFotoKelasAktifBordered(insertIndex, kelas: snapshotSiswa.kelasSekarang.rawValue)
                    tableView.scrollRowToVisible(insertIndex)
                    if matchedSiswaData.tahundaftar != siswa.tahundaftar || matchedSiswaData.tanggalberhenti != siswa.tanggalberhenti {
                        updateJumlahSiswa = true

                    } else {}
                }
            }
        } else if currentTableViewMode == .grouped {
            // Loop melalui setiap siswa di snapshot
            for snapshotSiswa in snapshotSiswas {
                let siswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden, siswa.status.rawValue.lowercased() == "berhenti" {
                    let newGroupIndex = getGroupIndex(forClassName: siswa.kelasSekarang.rawValue)
                    if !viewModel.groupedSiswa[newGroupIndex!].contains(where: { $0.id == siswa.id }) {
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
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id })
                    {
                        if !SingletonData.siswaNaikArray.isEmpty {
                            SingletonData.siswaNaikArray.removeLast()
                        }
                        SingletonData.siswaNaikId.removeAll(where: { $0 == snapshotSiswa.id })

                        viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)

                        let updated = dbController.getSiswa(idValue: snapshotSiswa.id)
                        viewModel.updateGroupSiswa(updated, groupIndex: groupIndex, index: siswaIndex)

                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let newGroupIndex = getGroupIndex(forClassName: updated.kelasSekarang.rawValue) ?? groupIndex
                        let insertIndex = viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: updated, using: sortDescriptor)

                        // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        if isBerhentiHidden && snapshotSiswa.status.rawValue.lowercased() == "berhenti" {
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
                    } else {}
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

    /// Fungsi untuk menjalankan undo.
    @objc func mulaiRedo(_ sender: Any) {
        if SiswaViewModel.siswaUndoManager.canRedo {
            SiswaViewModel.siswaUndoManager.redo()
        }
    }

    /**
         Melakukan operasi undo pada `SiswaViewModel.siswaUndoManager`.

         Fungsi ini memeriksa apakah operasi undo dapat dilakukan. Jika ya, fungsi ini akan melakukan undo,
         dengan penanganan khusus jika ada string pencarian dan mode tampilan tabel adalah `.grouped`.
         Jika ada string pencarian, fungsi ini akan mengurutkan data pencarian sebelum melakukan undo.

         - Parameter:
             - sender: Objek yang memicu aksi undo (misalnya, tombol undo).
     */
    @objc func performUndo(_ sender: Any) {
        if SiswaViewModel.siswaUndoManager.canUndo {
            if !stringPencarian.isEmpty {
                guard currentTableViewMode == .grouped else {
                    SiswaViewModel.siswaUndoManager.undo()
                    return
                }
                if let sortDescriptor = tableView.sortDescriptors.first {
                    Task(priority: .userInitiated) { [weak self] in
                        guard let self else { return }
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

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// yang sesuai dengan class ``SiswaViewController``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_ sender: Any?) {
        DispatchQueue.main.async { [unowned self] in
            guard let mainMenu = NSApp.mainMenu,
                  let editMenuItem = mainMenu.item(withTitle: "Edit"),
                  let editMenu = editMenuItem.submenu,
                  let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
                  let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
            else {
                return
            }

            let canUndo = SiswaViewModel.siswaUndoManager.canUndo
            let canRedo = SiswaViewModel.siswaUndoManager.canRedo
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

    /**
         Menghapus baris yang dipilih dari tabel.

         Fungsi ini menampilkan dialog konfirmasi sebelum menghapus data siswa yang dipilih.
         Jika pengguna memilih untuk menghapus, data akan dihapus dari sumber data dan tabel akan diperbarui.
         Pengguna juga memiliki opsi untuk menekan (suppress) peringatan di masa mendatang.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func deleteSelectedRowsAction(_ sender: Any) {
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
                guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
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

    /**
     Menampilkan dialog konfirmasi penghapusan data siswa.

     Fungsi ini menampilkan peringatan (alert) untuk mengonfirmasi apakah pengguna yakin ingin menghapus data siswa yang dipilih.
     Peringatan ini mencakup opsi untuk menekan (suppress) peringatan di masa mendatang.

     - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini.

     Fungsi ini menangani beberapa skenario:
     1. **Mode Tampilan Datar (Plain):**
        - Jika ada baris yang diklik dan dipilih, fungsi `hapus(sender)` dipanggil untuk menghapus semua baris yang dipilih.
        - Jika ada baris yang diklik tetapi tidak dipilih, fungsi `deleteDataClicked(clickedRow)` dipanggil untuk menghapus hanya baris yang diklik.
        - Jika tidak ada baris yang diklik, fungsi `hapus(sender)` dipanggil untuk menghapus semua baris yang dipilih.

     2. **Mode Tampilan Berkelompok (Grouped):**
        - Jika baris yang diklik termasuk dalam baris yang dipilih dan jumlah baris yang dipilih lebih dari 1, fungsi `hapus(sender)` dipanggil.
        - Jika ada baris yang dipilih tetapi tidak ada baris yang diklik, fungsi `hapus(sender)` dipanggil.
        - Jika hanya satu baris yang dipilih dan baris yang diklik termasuk di dalamnya, fungsi `deleteDataClicked(clickedRow)` dipanggil.
        - Jika tidak ada baris yang dipilih tetapi ada baris yang diklik, fungsi `deleteDataClicked(clickedRow)` dipanggil.
        - Jika ada baris yang dipilih dan ada baris yang diklik, fungsi `deleteDataClicked(clickedRow)` dipanggil.

     Jika pengguna memilih untuk menekan peringatan, pilihan ini akan disimpan di `UserDefaults` dan peringatan tidak akan ditampilkan lagi di masa mendatang sampai diubah.
     */
    @IBAction func hapusMenu(_ sender: NSMenuItem) {
        guard let tableView else { return }
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
            guard selectedRows.count > 0 else { return }
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
                    guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
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
            guard clickedRow >= 0 else { return }
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
                if selectedRows.contains(clickedRow), selectedRows.count > 1 { hapus(sender) }
                else if !selectedRows.isEmpty, clickedRow < 0 { hapus(sender) }
                else if selectedRows.count == 1, selectedRows.contains(clickedRow) { deleteDataClicked(clickedRow) }
                else if selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
                else if !selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
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
                if selectedRows.contains(clickedRow), selectedRows.count > 1 { hapus(sender) }
                else if !selectedRows.isEmpty, clickedRow < 0 { hapus(sender) }
                else if selectedRows.count == 1, selectedRows.contains(clickedRow) { deleteDataClicked(clickedRow) }
                else if selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
                else if !selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count {
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

    /**
         * Fungsi ini menangani aksi penghapusan data siswa dari tampilan tabel.
         *
         * Fungsi ini dipanggil ketika pengguna menekan tombol "Hapus". Fungsi ini menghapus baris yang dipilih dari tampilan tabel,
         * baik dalam mode tampilan biasa maupun mode tampilan yang dikelompokkan. Fungsi ini juga menangani pendaftaran aksi undo
         * dan mengirimkan notifikasi tentang penghapusan siswa.
         *
         * - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol "Hapus").
         *
         * - Precondition: `tableView` harus sudah diinisialisasi dan diisi dengan data siswa.
         * - Postcondition: Baris yang dipilih akan dihapus dari `tableView`, dan aksi undo akan didaftarkan.
     */
    @IBAction func hapus(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        // Pastikan ada baris yang dipilih
        guard selectedRows.count > 0 else { return }
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
                let kelasSekarang = viewModel.filteredSiswaData[index].kelasSekarang.rawValue
                deletedRows.insert(index) // Tambahkan indeks yang dihapus ke Set
                deletedStudentIDs.append(siswaID)
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": deletedStudentIDs,
                        "kelasSekarang": kelasSekarang as String,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
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
                guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
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
                        "kelasSekarang": deletedSiswa.kelasSekarang.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                }
            }

            SingletonData.deletedSiswasArray.append(tempDeletedSiswaArray)

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

    /**
     *  Fungsi ini dipanggil ketika sebuah baris (data siswa) dipilih untuk dihapus.
     *  Fungsi ini menangani penghapusan data siswa dari sumber data dan memperbarui tampilan tabel.
     *  Selain itu, fungsi ini juga mencatat tindakan penghapusan untuk mendukung fitur undo.
     *
     *  @param row Indeks baris yang diklik kanan dan akan dihapus.
     *
     *  Proses:
     *  1. Memastikan indeks baris yang diberikan valid.
     *  2. Mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager`.
     *  3. Menentukan mode tampilan tabel saat ini (plain atau grouped).
     *  4. Menghapus data siswa yang sesuai dari sumber data berdasarkan mode tampilan.
     *  5. Memposting pemberitahuan (`siswaDihapus`) untuk memberitahu komponen lain tentang penghapusan.
     *  6. Menghapus baris dari tampilan tabel dengan animasi slide up.
     *  7. Memperbarui pilihan baris setelah penghapusan.
     *  8. Memperbarui status undo/redo setelah penundaan singkat.
     */
    @objc func deleteDataClicked(_ row: Int) {
        // Dapatkan baris yang diklik kanan
        let clickedRow = row
        guard row >= 0 else { return }
        deleteAllRedoArray(self)
        // Catat tindakan undo dengan data yang dihapus
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(self)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Data")
        if currentTableViewMode == .plain {
            let deletedSiswa = viewModel.filteredSiswaData[clickedRow]
            SingletonData.deletedSiswasArray.append([deletedSiswa])
            viewModel.removeSiswa(at: clickedRow)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                let userInfo: [String: Any] = [
                    "deletedStudentIDs": [deletedSiswa.id],
                    "kelasSekarang": deletedSiswa.kelasSekarang.rawValue,
                    "isDeleted": true,
                    "hapusDiSiswa": true,
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
            // Remove the student from viewModel.groupedSiswa
            viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndexInSection)
            SingletonData.deletedStudentIDs.append(deletedSiswa.id)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [deletedSiswa.id],
                "kelasSekarang": deletedSiswa.kelasSekarang.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            }
        }
        // Hapus data dari tabel
        tableView.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideUp)

        if clickedRow == tableView.numberOfRows {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }
    }

    /**
     Mengembalikan tindakan penghapusan data siswa yang sebelumnya dibatalkan.

     Fungsi ini mengembalikan data siswa yang terakhir dihapus dari array `SingletonData.deletedSiswasArray` ke tampilan tabel.
     Fungsi ini menangani penyisipan data yang dikembalikan ke dalam tampilan tabel, baik dalam mode tampilan biasa maupun berkelompok,
     dan juga menangani pemulihan pilihan baris sebelumnya.

     - Parameter sender: Objek yang memicu tindakan undo.
     */
    func undoDeleteMultipleData(_ sender: Any) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor, !SingletonData.deletedSiswasArray.isEmpty else {
            return
        }
        if currentTableViewMode == .plain, !stringPencarian.isEmpty {
            filterDeletedSiswa()
            if let toolbar = view.window?.toolbar,
               let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
            {
                stringPencarian.removeAll()
                searchFieldToolbarItem.searchField.stringValue = ""
            }
        }
        var tempDeletedIndexes = Set<Int>()
        let lastDeletedSiswaArray = SingletonData.deletedSiswasArray.last!
        tableView.beginUpdates()
        for siswa in lastDeletedSiswaArray {
            if (isBerhentiHidden && siswa.status.rawValue.lowercased() == "berhenti") || (!UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && siswa.status.rawValue.lowercased() == "lulus") {
                SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [siswa.id],
                        "kelasSekarang": siswa.kelasSekarang.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
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
                        "kelasSekarang": siswa.kelasSekarang.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]
                    NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                }
            } else if currentTableViewMode == .grouped {
                if let groupIndex = getGroupIndex(forClassName: siswa.kelasSekarang.rawValue) {
                    let insertIndex = viewModel.groupedSiswa[groupIndex].insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertGroupSiswa(siswa, groupIndex: groupIndex, index: insertIndex)
                    let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: insertIndex)
                    tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                    tempDeletedIndexes.insert(absoluteRowIndex + 1)
                    SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                    DispatchQueue.main.async {
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": [siswa.id],
                            "kelasSekarang": siswa.kelasSekarang.rawValue,
                            "isDeleted": true,
                            "hapusDiSiswa": true,
                        ]
                        NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                    }
                }
            }
        }
        previouslySelectedRows = tableView.selectedRowIndexes
        for index in tableView.selectedRowIndexes {
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
        let hasBerhentiAndFiltered = lastDeletedSiswaArray.contains(where: { $0.status.rawValue == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastDeletedSiswaArray.contains(where: { $0.status.rawValue == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

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

    /**
     *  Melakukan penghapusan kembali data siswa yang sebelumnya telah dibatalkan penghapusannya (redo).
     *
     *  Fungsi ini mengambil data siswa yang terakhir kali dibatalkan penghapusannya dari `redoDeletedSiswaArray`,
     *  menghapusnya dari tampilan tabel, dan menyimpannya dalam `deletedSiswasArray` untuk kemungkinan pembatalan (undo) di masa mendatang.
     *  Fungsi ini juga menangani pembaruan UI, notifikasi, dan pendaftaran tindakan undo.
     *
     *  - Parameter:
     *      - sender: Objek yang memicu aksi ini (misalnya, tombol redo).
     *
     *  - Catatan:
     *      - Fungsi ini mempertimbangkan mode tampilan tabel saat ini (`.plain` atau `.grouped`) untuk menghapus data dengan benar.
     *      - Fungsi ini juga menangani kasus di mana data yang dihapus adalah data yang difilter atau data dengan status tertentu (misalnya, "Berhenti" atau "Lulus") dan menampilkan peringatan yang sesuai.
     *      - Fungsi ini menggunakan `SingletonData` untuk menyimpan data yang dihapus dan `NotificationCenter` untuk mengirim notifikasi tentang penghapusan siswa.
     *
     *  - Versi: 1.0
     */
    func redoDeleteMultipleData(_ sender: Any) {
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                {
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
                            "kelasSekarang": deletedSiswa.kelasSekarang.rawValue,
                            "isDeleted": true,
                            "hapusDiSiswa": true,
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
                                "kelasSekarang": deletedSiswa.kelasSekarang.rawValue,
                                "isDeleted": true,
                                "hapusDiSiswa": true,
                            ]
                            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                        }
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
                tableView.scrollRowToVisible(maxIndeks)
            }
        }
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }

        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
        let hasBerhentiAndFiltered = lastRedoDeletedSiswaArray.contains(where: { $0.status.rawValue == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastRedoDeletedSiswaArray.contains(where: { $0.status.rawValue == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

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

    /**
     * Fungsi ini membatalkan operasi tempel terakhir yang dilakukan pada tabel siswa.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Membatalkan pilihan semua baris yang dipilih pada tabel.
     * 2. Jika ada string pencarian yang aktif, fungsi ini akan membersihkan string pencarian dan memperbarui tampilan tabel sesuai.
     * 3. Mengambil array siswa yang terakhir ditempel dari `pastedSiswasArray`.
     * 4. Menyimpan array siswa yang dihapus ke `SingletonData.redoPastedSiswaArray` untuk operasi redo.
     * 5. Menghapus siswa dari sumber data dan tabel.
     * 6. Memilih baris yang sesuai setelah penghapusan dan menggulir tampilan ke baris tersebut.
     * 7. Mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager` untuk memungkinkan operasi redo.
     * 8. Memperbarui status undo/redo setelah penundaan singkat.
     *
     * - Parameter:
     *   - sender: Objek yang memicu tindakan undo.
     */
    func undoPaste(_ sender: Any) {
        tableView.deselectAll(sender)
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                {
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
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id })
                    {
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        tempDeletedIndexes.append(rowIndex)
                    }
                }
            }
            // dbController.hapusDaftar(idValue: deletedSiswa.id)
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

    /**
     *  Melakukan operasi 'redo' untuk tindakan 'paste' (tempel).
     *
     *  Fungsi ini mengembalikan tindakan 'paste' yang sebelumnya dibatalkan (undo), menyisipkan kembali data siswa yang telah dihapus ke dalam tampilan tabel.
     *  Fungsi ini menangani penyisipan data baik dalam mode tampilan 'plain' maupun 'grouped', memastikan data disisipkan pada indeks yang tepat berdasarkan urutan yang ditentukan.
     *
     *  - Parameter:
     *      - sender: Objek yang memicu tindakan ini (misalnya, tombol 'redo').
     *
     *  - Catatan:
     *      - Fungsi ini menggunakan `SingletonData.redoPastedSiswaArray` untuk mendapatkan data siswa yang akan dikembalikan.
     *      - Fungsi ini memperbarui tampilan tabel dengan animasi slide-down.
     *      - Fungsi ini mendaftarkan tindakan 'undo' baru untuk memungkinkan pembatalan tindakan 'redo' ini.
     *      - Fungsi ini memanggil `updateUndoRedo` untuk memperbarui status tombol 'undo' dan 'redo' pada antarmuka pengguna.
     */
    func redoPaste(_ sender: Any) {
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            return
        }
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                {
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

    /// Hapus semua array untuk redo.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteAllRedoArray(_ sender: Any) {
        if !redoDeletedSiswaArray.isEmpty { redoDeletedSiswaArray.removeAll() }
        if !SingletonData.redoPastedSiswaArray.isEmpty { SingletonData.redoPastedSiswaArray.removeAll() }
        ulangsiswaBaruArray.removeAll()
    }

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
            viewModel.filteredSiswaData.count
        } else {
            viewModel.groupedSiswa.reduce(0) { $0 + $1.count + 1 }
        }
    }

    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.groupedSiswa[section].count
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
            guard row < viewModel.filteredSiswaData.count else { return NSView() }
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

    /**
         Mengkonfigurasi tampilan cell untuk tabel siswa.

         - Parameter tableView: NSTableView yang akan dikonfigurasi cell-nya.
         - Parameter siswa: ModelSiswa yang datanya akan ditampilkan pada cell.
         - Parameter row: Indeks baris dari cell yang sedang dikonfigurasi.
         - Returns: NSView yang telah dikonfigurasi sebagai cell siswa, atau nil jika gagal.
     */
    func configureSiswaCell(for tableView: NSTableView, siswa: ModelSiswa, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SiswaCell"), owner: self) as? NSTableCellView,
              let imageView = cell.imageView
        else { return nil }

        cell.textField?.stringValue = siswa.nama
        let selected = tableView.selectedRowIndexes.contains(row)
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let image = self.viewModel.determineImageName(for: siswa.kelasSekarang.rawValue, bordered: selected)
            DispatchQueue.main.async { [weak imageView] in
                imageView?.image = NSImage(named: image)
            }
        }

        return cell
    }

    /**
         Mengonfigurasi sel umum untuk NSTableView berdasarkan pengidentifikasi kolom yang diberikan.

         - Parameter tableView: NSTableView yang selnya akan dikonfigurasi.
         - Parameter columnIdentifier: String yang mengidentifikasi kolom yang akan dikonfigurasi.
         - Parameter siswa: ModelSiswa yang datanya akan ditampilkan dalam sel.
         - Parameter row: Indeks baris sel yang sedang dikonfigurasi.

         - Returns: NSView? yang merupakan sel yang telah dikonfigurasi, atau nil jika gagal membuat sel. Sel dikonfigurasi berdasarkan `columnIdentifier` yang sesuai dengan properti pada objek `siswa`.
     */
    func configureGeneralCell(for tableView: NSTableView, columnIdentifier: String, siswa: ModelSiswa, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cellUmum"), owner: self) as? NSTableCellView else { return nil }

        switch columnIdentifier {
        case "Alamat": cell.textField?.stringValue = siswa.alamat
        case "T.T.L": cell.textField?.stringValue = siswa.ttl
        case "Nama Wali": cell.textField?.stringValue = siswa.namawali
        case "NIS": cell.textField?.stringValue = siswa.nis
        case "NISN": cell.textField?.stringValue = siswa.nisn
        case "Ayah": cell.textField?.stringValue = siswa.ayah
        case "Ibu": cell.textField?.stringValue = siswa.ibu
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin.rawValue
        case "Status": cell.textField?.stringValue = siswa.status.rawValue
        case "Nomor Telepon": cell.textField?.stringValue = siswa.tlv
        default: break
        }

        return cell
    }

    /**
         Mengonfigurasi tampilan sel untuk NSTableView, menangani tampilan header grup dan baris data.

         - Parameter tableView: NSTableView yang selnya sedang dikonfigurasi.
         - Parameter tableColumn: Kolom tabel yang selnya sedang dikonfigurasi. Bisa jadi nil jika ini adalah baris grup.
         - Parameter isGroupRow: Boolean yang menunjukkan apakah baris tersebut adalah baris grup (header).
         - Parameter sectionIndex: Indeks bagian tempat sel berada.
         - Parameter rowIndexInSection: Indeks baris dalam bagian tempat sel berada.

         - Returns: NSView yang dikonfigurasi untuk sel, bisa berupa tampilan header atau tampilan baris data. Mengembalikan nil jika konfigurasi gagal.
     */
    func configureGroupedCell(for tableView: NSTableView, tableColumn: NSTableColumn?, isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
        if isGroupRow {
            configureHeaderView(for: tableView, sectionIndex: sectionIndex)
        } else {
            configureGroupedRowView(for: tableView, tableColumn: tableColumn, sectionIndex: sectionIndex, rowIndexInSection: rowIndexInSection)
        }
    }

    /**
         Mengonfigurasi tampilan header untuk bagian tertentu dalam tabel.

         - Parameter tableView: Tabel yang akan dikonfigurasi header-nya.
         - Parameter sectionIndex: Indeks bagian yang akan dikonfigurasi header-nya.
         - Returns: Tampilan header yang telah dikonfigurasi, atau `nil` jika header tidak ditampilkan atau terjadi kesalahan.

         Fungsi ini membuat atau menggunakan kembali tampilan header (`GroupTableCellView`) untuk bagian tertentu dalam tabel.
         Jika `sectionIndex` adalah 0, maka header tidak akan ditampilkan (mengembalikan `nil`).
         Jika tidak, fungsi ini akan mengatur properti `isGroupView`, `sectionTitle` (mengambil nama kelas dari array `kelasNames`),
         `sectionIndex`, dan `isBoldFont` pada tampilan header.
     */
    func configureHeaderView(for tableView: NSTableView, sectionIndex: Int) -> NSView? {
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

    /**
         Mengonfigurasi tampilan baris yang dikelompokkan untuk NSTableView.

         Fungsi ini membuat dan mengembalikan tampilan untuk baris tertentu dalam NSTableView yang dikelompokkan,
         berdasarkan indeks bagian dan baris dalam bagian tersebut. Tampilan dikonfigurasi berdasarkan
         identifier kolom tabel.

         - Parameter tableView: NSTableView yang meminta tampilan.
         - Parameter tableColumn: Kolom tabel yang tampilan ini untuknya.
         - Parameter sectionIndex: Indeks bagian dari baris yang diminta.
         - Parameter rowIndexInSection: Indeks baris dalam bagian yang diminta.

         - Returns: NSView yang dikonfigurasi untuk baris tersebut, atau nil jika terjadi kesalahan
                    (misalnya, indeks di luar batas, atau gagal membuat tampilan sel).
     */
    func configureGroupedRowView(for tableView: NSTableView, tableColumn: NSTableColumn?, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
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
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin.rawValue
        case "Status": cell.textField?.stringValue = siswa.status.rawValue
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
            getRowInfoForRow(row).isGroupRow
        } else {
            false // Jika mode adalah .plain, maka tidak ada header kelas yang perlu ditampilkan
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.numberOfRows != 0 else {
            return
        }
        selectedIds.removeAll()

        let selectedRow = tableView.selectedRow
        if let toolbar = view.window?.toolbar {
            // Aktifkan isEditable pada baris yang sedang dipilih
            if selectedRow != -1 {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton
                {
                    hapus.isEnabled = true
                    hapus.target = self
                    hapus.action = #selector(deleteSelectedRowsAction(_:))
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton
                {
                    edit.isEnabled = true
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
                for row in previouslySelectedRows {
                    guard row <= maxRow else { continue }
                    if !selectedRowIndexes.contains(row),
                       let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
                    {
                        let previousSiswa = viewModel.filteredSiswaData[row]
                        let image = viewModel.determineImageName(for: previousSiswa.kelasSekarang.rawValue, bordered: false)
                        DispatchQueue.main.async {
                            previousCellView.imageView?.image = NSImage(named: image)
                        }
                    }
                }
            }

            // Tambahkan border ke semua baris yang dipilih
            for row in selectedRowIndexes {
                guard row <= maxRow else { continue }
                if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let siswa = viewModel.filteredSiswaData[row]
                    let image = viewModel.determineImageName(for: siswa.kelasSekarang.rawValue, bordered: true)
                    DispatchQueue.main.async {
                        selectedCellView.imageView?.image = NSImage(named: image)
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
                        if index >= startRowIndex, index < endRowIndex {
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
        if SharedQuickLook.shared.isQuickLookVisible() {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    func tableViewSelectionIsChanging(_ notification: Notification) {
        guard currentTableViewMode == .plain,
              tableView.numberOfRows > 0
        else { return }
        
        let selectedRowIndexes = tableView.selectedRowIndexes

        // Hapus border dari baris yang tidak lagi dipilih
        if let full = previouslySelectedRows.max() {
            guard full < tableView.numberOfRows else {
                previouslySelectedRows.remove(full)
                return
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
                            if index >= startRowIndex, index < endRowIndex {
                                let siswaIndex = index - startRowIndex
                                return siswaGroup[siswaIndex].id
                            }
                        }
                        return nil
                    })
                }
            }
            for row in previouslySelectedRows {
                if !selectedRowIndexes.contains(row), let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let previousSiswa = viewModel.filteredSiswaData[row]
                    let image = viewModel.determineImageName(for: previousSiswa.kelasSekarang.rawValue, bordered: false)
                    DispatchQueue.main.async {
                        previousCellView.imageView?.image = NSImage(named: image)
                    }
                }
            }
        }

        // Tambahkan border ke semua baris yang dipilih
        for row in selectedRowIndexes {
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                let image = viewModel.determineImageName(for: siswa.kelasSekarang.rawValue, bordered: true)
                DispatchQueue.main.async {
                    selectedCellView.imageView?.image = NSImage(named: image)
                }
            }
        }

        // Simpan baris yang saat ini dipilih
        previouslySelectedRows = selectedRowIndexes
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if currentTableViewMode == .grouped {
            let (isGroupRow, _, _) = getRowInfoForRow(row)
            if isGroupRow, row == 0 { return 0.1 }
            else if isGroupRow { return 28.0 }
            else { return tableView.rowHeight }
        } else {
            return tableView.rowHeight
        }
    }

    /**
         Mengonfigurasi cell untuk DatePicker pada NSTableView.

         Fungsi ini membuat atau menggunakan kembali cell kustom yang berisi DatePicker dan TextField,
         kemudian mengonfigurasi DatePicker dengan target, action, dan tag yang sesuai.
         Tanggal yang ditampilkan pada TextField dan DatePicker diformat berdasarkan lebar kolom tabel.
         Data tanggal diambil dari objek `ModelSiswa` menggunakan KeyPath yang diberikan.

         - Parameter tableView: NSTableView yang akan menampilkan cell.
         - Parameter tableColumn: Kolom tabel yang terkait dengan cell.
         - Parameter siswa: Objek `ModelSiswa` yang berisi data tanggal.
         - Parameter dateKeyPath: KeyPath yang menentukan properti tanggal pada `ModelSiswa`.
         - Parameter tag: Tag yang akan diberikan ke DatePicker.

         - Returns: Cell kustom yang telah dikonfigurasi, atau nil jika pembuatan cell gagal.
     */
    func configureDatePickerCell(for tableView: NSTableView, tableColumn: NSTableColumn?, siswa: ModelSiswa, dateKeyPath: KeyPath<ModelSiswa, String>, tag: Int) -> CustomTableCellView? {
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

    /**
         Memperbarui format tanggal pada cell tabel berdasarkan lebar kolom yang tersedia.

         Fungsi ini menerima sebuah `NSTableCellView`, sebuah objek `ModelSiswa`, identifier kolom, dan string tanggal sebagai input.
         Fungsi ini kemudian menentukan format tanggal yang sesuai berdasarkan lebar kolom yang tersedia pada cell tabel.
         Jika lebar kolom kurang dari atau sama dengan 80, format tanggal yang digunakan adalah "d/M/yy".
         Jika lebar kolom kurang dari atau sama dengan 120, format tanggal yang digunakan adalah "d MMM yyyy".
         Jika lebar kolom lebih besar dari 120, format tanggal yang digunakan adalah "dd MMMM yyyy".
         String tanggal kemudian dikonversi menjadi objek `Date` menggunakan format tanggal yang ditentukan,
         dan text field pada cell tabel diperbarui dengan string tanggal yang diformat.

         - Parameter cellView: Cell tabel yang akan diperbarui format tanggalnya.
         - Parameter siswa: Objek `ModelSiswa` yang berisi data siswa.
         - Parameter columnIdentifier: Identifier kolom yang sedang diperbarui.
         - Parameter dateString: String tanggal yang akan diformat.
     */
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
            for row in 0 ..< tableView.numberOfRows {
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

    /**
     Memperbarui sel-sel pada NSTableView untuk kolom tertentu dengan data siswa.

     Fungsi ini digunakan untuk memperbarui tampilan sel dalam NSTableView berdasarkan data siswa yang diberikan.
     Fungsi ini akan mencari kolom berdasarkan identifier yang diberikan, dan kemudian memperbarui setiap sel
     dalam kolom tersebut dengan data yang sesuai dari array `siswaData`. Jika kolom yang sesuai ditemukan dan
     sel adalah instance dari `CustomTableCellView`, fungsi ini akan memanggil `updateDateFormat` untuk
     memformat dan menampilkan tanggal yang sesuai.

     - Parameter tableView: NSTableView yang sel-selnya akan diperbarui.
     - Parameter columnIdentifier: Identifier kolom yang akan diperbarui.
     - Parameter siswaData: Array data siswa yang akan digunakan untuk memperbarui sel-sel.
     */
    // Fungsi untuk memperbarui sel pada mode plain
    func updateCells(for tableView: NSTableView, columnIdentifier: String, siswaData: [ModelSiswa]) {
        if let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: columnIdentifier)) {
            let columnIndex = tableView.column(withIdentifier: resizedColumn.identifier)
            for row in 0 ..< siswaData.count {
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

    /**
         Membuat gambar teks untuk nama yang diberikan.

         - Parameter name: Nama untuk membuat gambar teks.
         - Returns: NSImage yang berisi teks nama, atau nil jika terjadi kesalahan.
     */
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

    /**
         Memeriksa apakah sumber seret berasal dari tabel kita.

         - Parameter draggingInfo: Informasi seret.
         - Returns: `true` jika sumber seret adalah tabel kita, jika tidak, `false`.
     */
    func dragSourceIsFromOurTable(draggingInfo: NSDraggingInfo) -> Bool {
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableView {
            true
        } else {
            false
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
               let image = NSImage(data: fotoData), let nama = pasteboardItem.string(forType: NSPasteboard.PasteboardType.string)
            {
                // Gunakan foto dari database sebagai drag image
                let dragSize = NSSize(width: tableView.rowHeight, height: tableView.rowHeight)
                let resizedImage = ReusableFunc.resizeImage(image: image, to: dragSize)

                // Menghitung lebar teks dengan atribut font
                let font = NSFont.systemFont(ofSize: 13) // Anda bisa menggunakan font yang sesuai
                let textSize = nama.size(withAttributes: [.font: font])

                // Mengatur ukuran drag item
                let textWidth = textSize.width
                let textVerticalPosition = (dragSize.height - 17) / 2 // Posisi tengah vertikal

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
                // session.draggingFormation = .list

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

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
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
            guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return false }
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
              let image = NSImage(contentsOf: imageURL)
        else {
            return false
        }

        guard row != -1, row < viewModel.filteredSiswaData.count else {
            return false
        }
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
                        if siswaIndex >= 0, siswaIndex < siswaGroup.count {
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
                self?.undoDragFoto(id, image: imageData)
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
           sourceView === tableView
        {
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

    /**
     Mengurungkan operasi drag foto siswa.

     Fungsi ini membatalkan perubahan foto siswa yang sebelumnya diseret dan dijatuhkan.
     Ini mendaftarkan operasi 'redo' dengan `UndoManager` untuk memungkinkan pengembalian perubahan.
     Fungsi ini juga memperbarui foto di database dan memilih baris yang sesuai di tabel.

     - Parameter:
        - id: ID siswa yang foto-nya akan dikembalikan.
        - image: Data gambar asli yang akan dikembalikan.
     */
    func undoDragFoto(_ id: Int64, image: Data) {
        tableView.deselectAll(self)

        let data = dbController.bacaFotoSiswa(idValue: id)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.redoDragFoto(id, image: data)
        })
        dbController.updateFotoInDatabase(with: image, idx: id)
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) else { return }
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

    /**
     Melakukan perubahan foto siswa dan mendaftarkan operasi undo.

     Fungsi ini memperbarui foto siswa dengan ID tertentu dalam database, mendaftarkan operasi undo untuk mengembalikan ke foto sebelumnya,
     dan memilih baris yang sesuai di `tableView`.

     - Parameter id: ID siswa yang fotonya akan diubah.
     - Parameter image: Data gambar baru yang akan disimpan.
     */
    func redoDragFoto(_ id: Int64, image: Data) {
        tableView.deselectAll(self)

        let data = dbController.bacaFotoSiswa(idValue: id)
        dbController.updateFotoInDatabase(with: image, idx: id)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.undoDragFoto(id, image: data)
        })
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) else { return }
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
                    await self.viewModel.cariSiswa(stringPencarian)
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: isBerhentiHidden)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await self.viewModel.fetchSiswaData()
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: false, filterBerhenti: isBerhentiHidden)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            }
        } else {
            if !stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await self.viewModel.cariSiswa(stringPencarian)
                    await self.viewModel.filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper.from(sortDescriptor), group: true, filterBerhenti: isBerhentiHidden)

                    await MainActor.run { [weak self] in
                        self?.sortData(with: sortDescriptor)
                    }
                }
            } else if stringPencarian.isEmpty {
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
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

// MARK: - TABLEVIEW MENU RELATED FUNC.

extension SiswaViewController: NSMenuDelegate {
    /**
     Mengubah status siswa yang dipilih berdasarkan item menu yang dipilih.

     Fungsi ini menampilkan dialog konfirmasi untuk mengubah status siswa yang dipilih.
     Jika pengguna mengkonfirmasi, status siswa akan diperbarui di database dan tampilan tabel.
     Fungsi ini juga menangani logika khusus untuk status "Lulus", termasuk menghapus siswa dari kelas aktif
     dan menampilkan peringatan konfirmasi tambahan.

     - Parameter sender: Item menu yang memicu aksi ini. `representedObject` dari pengirim harus berupa `String`
        yang merepresentasikan status yang akan diubah.

     - Precondition: `tableView.selectedRowIndexes` harus berisi indeks baris yang valid.
     `viewModel.filteredSiswaData` harus berisi data siswa yang sesuai dengan indeks yang dipilih.
     */
    @IBAction func pilihubahStatus(_ sender: NSMenuItem) {
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
            return originalSiswa.copy() as? ModelSiswa
        }
        // Menampilkan peringatan dan menunggu respons
        let response = alert.runModal()
        // Jika pengguna menekan tombol "Hapus"
        guard response == .alertFirstButtonReturn else { return }
        let selectedRows = tableView.selectedRowIndexes
        let columnIndexOfStatus = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Status"))
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah identifier sesuai dengan yang sebenarnya
        var terproses = selectedSiswa.count
        var processAll = false
        var cancelAll = false

        // Melakukan update status siswa ke database untuk setiap siswa yang dipilih
        for rowIndex in selectedRows.reversed() {
            let siswa = viewModel.filteredSiswaData[rowIndex]
            guard siswa.status.rawValue != statusString else { continue }
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
                    dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [idSiswa],
                        "kelasSekarang": siswa.kelasSekarang.rawValue,
                        "isDeleted": true,
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    siswa.status = StatusSiswa.lulus
                    siswa.kelasSekarang = KelasAktif.lulus
                    siswa.tanggalberhenti = tanggalSekarang
                    viewModel.updateSiswa(siswa, at: rowIndex)
                    // Memperbarui hanya baris dan kolom status pada tableView
                    DispatchQueue.main.async { [unowned self] in
                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndexOfStatus, columnIndexOfKelasAktif])) // Memperbarui kedua kolom yang terlibat
                        if let cellView = tableView.view(atColumn: columnIndexOfStatus, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                            cellView.textField?.stringValue = statusString
                        }
                        if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                           let imageView = namaView.imageView
                        {
                            // Mendapatkan gambar baru berdasarkan status siswa
                            if statusString == "Lulus" {
                                imageView.image = NSImage(named: "lulus Bordered")
                            }
                        }
                    }
                    if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                        if statusString == StatusSiswa.lulus.rawValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                guard let self else { return }
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
                    siswa.status = StatusSiswa.lulus
                    siswa.kelasSekarang = KelasAktif.lulus
                    siswa.tanggalberhenti = tanggalSekarang
                    viewModel.updateSiswa(siswa, at: rowIndex)
                    continue
                }

                let confirmAlert = NSAlert()
                confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
                confirmAlert.messageText = "Status Siswa Lulus! Hapus data siswa di Kelas Aktif sebelumnya?"
                confirmAlert.informativeText = "Apakah Anda yakin menghapus data siswa di Kelas Aktif \(siswa.kelasSekarang.rawValue)?"
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
                    dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [idSiswa],
                        "kelasSekarang": siswa.kelasSekarang.rawValue,
                        "isDeleted": true,
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    siswa.status = StatusSiswa.lulus
                    siswa.kelasSekarang = KelasAktif.lulus
                    siswa.tanggalberhenti = tanggalSekarang
                    viewModel.updateSiswa(siswa, at: rowIndex)
                } else {
                    siswa.status = StatusSiswa.lulus
                    siswa.kelasSekarang = KelasAktif.lulus
                    siswa.tanggalberhenti = tanggalSekarang
                    viewModel.updateSiswa(siswa, at: rowIndex)
                }
                terproses -= 1
            } else if statusString == StatusSiswa.berhenti.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: "")
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.berhenti
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
                siswa.status = StatusSiswa.aktif
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
                   let imageView = namaView.imageView
                {
                    // Mendapatkan gambar baru berdasarkan status siswa
                    if statusString == "Lulus" {
                        imageView.image = NSImage(named: "lulus Bordered")
                    } else {
                        imageView.image = NSImage(named: "\(viewModel.filteredSiswaData[rowIndex].kelasSekarang.rawValue) Bordered")
                    }
                }
            }
            if isBerhentiHidden {
                if statusString == StatusSiswa.berhenti.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self else { return }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self else { return }
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

    /// Lihat: ``pilihubahStatus(_:)`` dengan perbedaan func ini untuk baris yang diklik.
    @objc func klikubahStatus(_ sender: NSMenuItem) {
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
        
        
        let tglsekarang = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: tglsekarang)

        // Menampilkan peringatan dan menunggu respons
        let response = alert.runModal()
        guard let snapshot = siswa.copy() as? ModelSiswa, // Copy semua properti yang diperlukan
              siswa.status.rawValue != statusString
        else { return }
        // Jika pengguna menekan tombol "Hapus"
        if response == .alertFirstButtonReturn {
            let idSiswa = siswa.id

            let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // identifier
            let columnIndexOfStatus = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Status"))
            let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))

            // Melakukan update status siswa ke database
            if statusString == StatusSiswa.lulus.rawValue {
                let namaSiswa = siswa.nama
                siswa.status = .lulus
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }
                }
                DispatchQueue.main.async {
                    let confirmAlert = NSAlert()
                    confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
                    confirmAlert.messageText = "Status Siswa Lulus! Hapus juga data siswa di Kelas Aktif sebelumnya?"
                    confirmAlert.informativeText = "Apakah Anda yakin menghapus data \(siswa.nama) di Kelas Aktif \(siswa.kelasSekarang.rawValue)?"
                    confirmAlert.addButton(withTitle: "OK")
                    confirmAlert.addButton(withTitle: "Batalkan")

                    let secondResponse = confirmAlert.runModal()
                    if secondResponse == .alertFirstButtonReturn {
                        self.dbController.siswaLulus(namaSiswa: namaSiswa, siswaID: idSiswa, kelasBerikutnya: "Lulus")
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": [idSiswa],
                            "kelasSekarang": siswa.kelasSekarang.rawValue,
                            "isDeleted": true,
                        ]
                        NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                        siswa.kelasSekarang = KelasAktif.lulus
                        siswa.tanggalberhenti = tanggalSekarang
                        self.viewModel.updateSiswa(siswa, at: clickedRow)

                    } else {
                        siswa.kelasSekarang = KelasAktif.lulus
                        siswa.tanggalberhenti = tanggalSekarang
                        self.viewModel.updateSiswa(siswa, at: clickedRow)
                    }
                }
            } else if statusString == StatusSiswa.berhenti.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: tanggalSekarang)
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = StatusSiswa.berhenti
                siswa.tanggalberhenti = tanggalSekarang
                viewModel.updateSiswa(siswa, at: clickedRow)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = tanggalSekarang
                    }
                }
            } else if statusString == StatusSiswa.aktif.rawValue {
                dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: "")
                dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: statusString)
                siswa.status = .aktif
                siswa.tanggalberhenti = ""
                viewModel.updateSiswa(siswa, at: clickedRow)
                DispatchQueue.main.async { [unowned self] in
                    if let tglView = tableView.view(atColumn: columnIndexOfTglBerhenti, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                        tglView.textField?.stringValue = ""
                    }
                }
            }
            // Memperbarui hanya kolom "Status" pada tableView
            DispatchQueue.main.async { [unowned self] in
                tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfStatus]))
                if let cellView = tableView.view(atColumn: columnIndexOfStatus, row: clickedRow, makeIfNecessary: false) as? NSTableCellView {
                    cellView.textField?.stringValue = statusString
                }
                if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
                   let imageView = namaView.imageView
                {
                    // Mendapatkan gambar baru berdasarkan status siswa
                    if statusString == StatusSiswa.lulus.rawValue {
                        imageView.image = NSImage(named: "lulus")
                    } else {
                        imageView.image = NSImage(named: "\(viewModel.filteredSiswaData[clickedRow].kelasSekarang.rawValue)")
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

    /**
     * Memperbarui kelas yang dipilih untuk siswa yang dipilih dalam tampilan tabel.
     *
     * Fungsi ini melakukan beberapa tindakan:
     * 1. Memastikan ada baris yang dipilih. Jika tidak ada, fungsi akan keluar.
     * 2. Menyimpan data siswa yang dipilih sebelum perubahan untuk keperluan undo.
     * 3. Mengiterasi setiap siswa yang dipilih:
     *    - Memeriksa apakah kelas siswa saat ini berbeda dengan kelas yang baru dipilih. Jika sama, iterasi dilanjutkan ke siswa berikutnya.
     *    - Memperbarui kelas siswa saat ini dengan kelas yang baru dipilih.
     *    - Memperbarui data siswa di view model dan database.
     *    - Menampilkan dialog konfirmasi untuk menghapus data siswa dari kelas sebelumnya.
     *    - Menangani opsi "Terapkan ke semua" dan "Batalkan semua" pada dialog konfirmasi.
     * 4. Setelah semua siswa diproses, fungsi memperbarui tampilan tabel untuk mencerminkan perubahan kelas.
     * 5. Mendaftarkan aksi undo untuk mengembalikan perubahan jika diperlukan.
     *
     * - Parameter kelasAktifString: String yang merepresentasikan kelas yang baru dipilih.
     */
    @objc func updateKelasDipilih(_ kelasAktifString: String) {
        guard !tableView.selectedRowIndexes.isEmpty else { return }
        let selectedSiswa: [ModelSiswa] = tableView.selectedRowIndexes.compactMap { row in
            let originalSiswa = viewModel.filteredSiswaData[row]
            return originalSiswa.copy() as? ModelSiswa
        }

        let selectedRowIndexes = tableView.selectedRowIndexes

        var terproses = selectedRowIndexes.count
        var processAll = false
        var cancelAll = false
        for rowIndex in selectedRowIndexes {
            let siswa = viewModel.filteredSiswaData[rowIndex]
            guard siswa.kelasSekarang.rawValue != kelasAktifString else { continue }
            let idSiswa = siswa.id
            let kelasAwal = siswa.kelasSekarang.rawValue
            let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
            // let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
            if siswa.kelasSekarang.rawValue != kelasAktifString {
                siswa.kelasSekarang = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
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
            confirmAlert.informativeText = "Data \(siswa.nama) akan dihapus dari Kelas Aktif \(siswa.kelasSekarang.rawValue). Lanjutkan?"
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
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus"))
        DispatchQueue.main.async { [unowned self] in
            for rowIndex in selectedRowIndexes {
                if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
                   let imageView = namaView.imageView
                {
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

    /// Lihat: ``updateKelasDipilih(_:)`` dengan perbedaan func ini untuk baris yang diklik kanan.
    @objc func updateKelasKlik(_ kelasAktifString: String, clickedRow: Int) {
        guard clickedRow >= 0 else { return }
        let siswa = viewModel.filteredSiswaData[clickedRow]
        
        guard siswa.kelasSekarang.rawValue != kelasAktifString,
              let snapshot = siswa.copy() as? ModelSiswa
        else { return }
        let idSiswa = siswa.id

        let kelasAwal = siswa.kelasSekarang.rawValue
        let kelasYangDikecualikan = kelasAktifString.replacingOccurrences(of: " ", with: "").lowercased()
        if siswa.kelasSekarang.rawValue != kelasAktifString {
            siswa.kelasSekarang = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
            viewModel.updateSiswa(siswa, at: clickedRow)
            dbController.updateKelasAktif(idSiswa: idSiswa, newKelasAktif: kelasAktifString)
        }
        let confirmAlert = NSAlert()
        confirmAlert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        confirmAlert.messageText = "Hapus juga data \(siswa.nama) di Kelas Aktif sebelumnya?"
        confirmAlert.informativeText = "Data \(siswa.nama) akan dihapus dari Kelas Aktif \(siswa.kelasSekarang.rawValue). Lanjutkan?"
        confirmAlert.addButton(withTitle: "OK")
        confirmAlert.addButton(withTitle: "Batalkan")
        let confirmResponse = confirmAlert.runModal()

        // Jika pengguna menekan tombol "OK" pada konfirmasi kedua
        if confirmResponse == .alertFirstButtonReturn {
            // Hanya memanggil updateKelasAktif untuk kelas yang tidak sama dengan yang dipilih
            hapusKelasLama(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
        }

        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        let columnIndexOfTglBerhenti = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tgl. Lulus")) // Ubah
        DispatchQueue.main.async { [unowned self] in
            // tableView.reloadData(forRowIndexes: IndexSet(integer: clickedRow), columnIndexes: IndexSet([columnIndexOfKelasAktif]))
            if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
               let imageView = namaView.imageView
            {
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

    /**
         Menghapus kelas lama seorang siswa dari database dan mengirimkan notifikasi.

         Fungsi ini memperbarui tabel kelas aktif untuk menandai kelas sebelumnya sebagai tidak aktif,
         kemudian mengirimkan notifikasi bahwa siswa telah dihapus dari kelas tersebut.

         - Parameter:
             - idSiswa: ID siswa yang kelasnya akan dihapus.
             - kelasAwal: Nama kelas awal siswa yang akan dihapus.
             - kelasYangDikecualikan: Nama kelas yang dikecualikan dari penghapusan (kelas baru siswa).
     */
    func hapusKelasLama(idSiswa: Int64, kelasAwal: String, kelasYangDikecualikan: String) {
        dbController.updateTabelKelasAktif(idSiswa: idSiswa, kelasAwal: kelasAwal, kelasYangDikecualikan: kelasYangDikecualikan)
        NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
            "deletedStudentIDs": [idSiswa],
            "kelasSekarang": kelasAwal,
            "isDeleted": true,
        ])
    }

    /**
         Memperbarui tampilan foto kelas aktif dengan border pada baris tertentu dalam tabel.

         Fungsi ini secara asinkron memperbarui gambar (image view) pada sel tabel yang sesuai dengan baris yang diberikan.
         Gambar yang ditampilkan bergantung pada nilai `kelas`. Jika `kelas` adalah "Lulus", gambar "lulus Bordered" akan ditampilkan.
         Jika `kelas` kosong, gambar "No Data Bordered" akan ditampilkan. Jika tidak, gambar dengan nama "\(kelas) Bordered" akan ditampilkan.

         - Parameter:
            - row: Indeks baris yang akan diperbarui.
            - kelas: String yang menentukan kelas yang akan ditampilkan. String ini digunakan untuk menentukan gambar yang akan ditampilkan.
     */
    func updateFotoKelasAktifBordered(_ row: Int, kelas: String) {
        Task(priority: .userInitiated) { @MainActor [unowned self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik
            let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
            if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: row, makeIfNecessary: false) as? NSTableCellView,
               let imageView = namaView.imageView
            {
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

    /**
         Merespon notifikasi `siswaNaik` yang menandakan adanya perubahan kelas siswa.

         Fungsi ini menangani pembaruan data siswa ketika seorang siswa naik kelas atau lulus, baik dalam mode tampilan daftar biasa (plain) maupun mode tampilan grup. Fungsi ini melakukan langkah-langkah berikut:

         1.  **Mengambil Informasi dari Notifikasi:**
             *   Mendapatkan `siswaID` dan `kelasBaru` dari `userInfo` notifikasi.

         2.  **Mode Tampilan Daftar Biasa (Plain):**
             *   Mencari siswa dalam `filteredSiswaData` berdasarkan `deletedIDs`.
             *   Memperbarui `kelasSekarang` siswa dalam database.
             *   Memperbarui data siswa dalam `viewModel`.
             *   Menyimpan referensi gambar siswa ke disk.
             *   Memuat ulang baris yang sesuai pada `tableView` untuk memperbarui tampilan kelas.
             *   Memperbarui gambar pada `imageView` di sel tabel jika kelas siswa berubah menjadi "Lulus" atau kelas lainnya.

         3.  **Mode Tampilan Grup:**
             *   Mencari siswa dalam `groupedSiswa` berdasarkan `deletedIDs`.
             *   Menghapus siswa dari grup lama.
             *   Menentukan grup baru berdasarkan `kelasBaru`.
             *   Memasukkan siswa ke dalam grup baru pada indeks yang sesuai berdasarkan pengurutan.
             *   Menyimpan referensi gambar siswa ke disk.
             *   Memperbarui `tableView` untuk mencerminkan perpindahan siswa antar grup.

         - Parameter:
             - notification: Notifikasi `siswaNaik` yang berisi informasi tentang siswa yang naik kelas. Notifikasi ini harus memiliki `userInfo` dengan kunci "siswaID" (Int64) dan "kelasBaru" (String).

         - Catatan:
             - Fungsi ini menggunakan `Task` untuk melakukan operasi asinkronus di latar belakang.
             - Fungsi ini menggunakan `@MainActor` untuk memperbarui tampilan antarmuka pengguna pada thread utama.
             - Fungsi ini mengasumsikan bahwa `dbController`, `viewModel`, dan `tableView` telah diinisialisasi dengan benar.
             - Fungsi ini menggunakan `NSUserInterfaceItemIdentifier` dengan rawValue "Nama" untuk mengidentifikasi kolom kelas aktif pada tabel. Pastikan identifier ini sesuai dengan konfigurasi kolom pada Interface Builder.
     */
    @objc func siswaNaik(_ notification: Notification) {
        let columnIndexOfKelasAktif = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama")) // Ubah
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["siswaID"] as? Int64,
           let kelasBaru = userInfo["kelasBaru"] as? String
        {
            Task(priority: .background) { [weak self] in
                if self?.currentTableViewMode == .plain {
                    guard let s = self else { return }
                    if let index = s.viewModel.filteredSiswaData.firstIndex(where: { $0.id == deletedIDs }) {
                        let siswa = s.dbController.getSiswa(idValue: deletedIDs)
                        if siswa.kelasSekarang.rawValue != kelasBaru {
                            siswa.kelasSekarang = KelasAktif(rawValue: kelasBaru) ?? .belumDitentukan
                            s.viewModel.updateSiswa(siswa, at: index)
                        }
                        Task(priority: .userInitiated) { @MainActor [unowned s] in
                            s.tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet([columnIndexOfKelasAktif]))
                            if let namaView = s.tableView.view(atColumn: columnIndexOfKelasAktif, row: index, makeIfNecessary: false) as? NSTableCellView,
                               let imageView = namaView.imageView
                            {
                                // Mendapatkan gambar baru berdasarkan kelas siswa
                                if siswa.kelasSekarang.rawValue == kelasBaru {
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
                    guard let self, let (groupIndex, rowIndex) = self.viewModel.findSiswaInGroups(id: deletedIDs), let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }

                    // Mengambil data siswa dari grup yang ditemukan
                    let siswa = self.dbController.getSiswa(idValue: deletedIDs)

                    // Memperbarui kelas siswa jika diperlukan
                    self.viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)
                    let newGroupIndex = self.getGroupIndex(forClassName: kelasBaru) ?? groupIndex
                    let insertIndex = self.viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: siswa, using: sortDescriptor)
                    self.viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex, index: insertIndex)

                    self.updateTableViewForSiswaMove(from: (groupIndex, rowIndex), to: (newGroupIndex, insertIndex))
                }
            }
        }
    }
}

extension SiswaViewController: OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue

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

    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        tableView.tableColumns[column].width
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

extension SiswaViewController: OverlayEditorManagerDelegate {
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
        } else {
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
        if identifier == "Nama Siswa" || identifier == "Tahun Daftar" || identifier == "Tgl. Lulus" || identifier == "Status", identifier == "Jenis Kelamin" {
            return false
        }
        return true
    }
}
