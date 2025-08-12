// لا إله إلا الله مخمد رسول الله
//  KelasVC.swift
//  Bismillah
//
//  Created by SDI on 29/10/23.
//  Copyright © 2023 SDI. All rights reserved.
//
import Cocoa
import Combine

/// Class yang bertanggung jawab menampilkan dan mengelola interaksi untuk semua data kelas aktif dan siswa yang ada di dalamnya.
class KelasVC: NSViewController, NSTabViewDelegate, DetilWindowDelegate, NSSearchFieldDelegate {
    /// Delegate untuk penambahan data kelas dan memilih kelas yang sesuai di ``SidebarViewController`` dan ``tabView``.
    weak var delegate: KelasVCDelegate?

    /// `NSUndoManager` untuk ``DataSDI/KelasVC``.
    var myUndoManager: UndoManager!

    var cancellables: Set<AnyCancellable> = .init()

    /// `NSTabView` untuk menampung beberapa tableView.
    weak var tabView: NSTabView!
    /// `NSTableView` untuk kelas 1.
    weak var table1: NSTableView!
    /// `NSTableView` untuk kelas 2.
    weak var table2: NSTableView!
    /// `NSTableView` untuk kelas 3.
    weak var table3: NSTableView!
    /// `NSTableView` untuk kelas 4.
    weak var table4: NSTableView!
    /// `NSTableView` untuk kelas 5.
    weak var table5: NSTableView!
    /// `NSTableView` untuk kelas 6.
    weak var table6: NSTableView!
    /// Outlet `NSTextView`. Deprecated.
    @IBOutlet var resultTextView: NSTextView!
    /// Outlet `NSScrollView` yang berisi ``resultTextView`.`
    @IBOutlet var scrollView: NSScrollView!
    /// Array untuk undo.
    var undoArray: [OriginalData] = []
    /// Array untuk redo.
    var redoArray: [OriginalData] = []
    /// Instans ``DatabaseController``
    let dbController: DatabaseController = .shared
    /// Instans ``KelasViewModel``
    let viewModel: KelasViewModel = .shared
    /// Properti kamus table dan tableType nya.
    var tableInfo: [(table: NSTableView, type: TableType)] = []
    /// Dictionary untuk melacak apakah setiap TableType membutuhkan reload
    var needsReloadForTableType: [TableType: Bool] = [:]
    /// Dictionary untuk menyimpan iD `Int64` baris yang perlu di-reload per TableType
    var pendingReloadRows: [TableType: Set<Int64>] = [:]
    /// Properti ``PrintKelas``.
    lazy var printKelas: PrintKelas = .init()

    /// Menyimpan ID unik dari data yang baru dimasukkan ke tabel dan database.
    /// Nilai-nilai ini kemudian dikumpulkan sebagai satu batch ke dalam ``pastedKelasID`` untuk mendukung undo/redo.
    var pastedKelasIDs: [Int64] = []
    /// Menyimpan riwayat batch ``pastedKelasIDs`` sebagai array bertingkat (array of arrays) untuk mendukung undo/redo.
    /// Setiap elemen mewakili satu aksi tempel (paste) data.
    var pastedKelasID: [[Int64]] = []
    /// Array untuk menyimpan ID unik data yang dihapus.
    var kelasID: [[Int64]] = []

    /// Properti untuk menyimpan tableType untuk tableView yang sedang aktif.
    lazy var activeTableType: TableType = .kelas1
    /// Instans `OperationQueue`.
    let operationQueue: OperationQueue = .init()

    /// Properti yang menyimpan referensi jika data di ``viewModel``
    /// telah dimuat menggunakan data dari database dan telah ditampilkan
    /// di tableView yang sesuai.
    var isDataLoaded: [NSTableView: Bool] = [:]

    /// Properti yang menyimpan ID unik setiap data
    /// pada baris-baris yang dipilih di tableView
    /// untuk keperluan memilihnya ulang setelah
    /// memperbarui/mengurutkan data tableView.
    var selectedIDs: Set<Int64> = []
    /// Properti teks string ketika toolbar ``WindowController/search``
    /// menerima input pengetikan.
    lazy var stringPencarian1: String = ""
    /// Lihat: ``stringPencarian1``.
    lazy var stringPencarian2: String = ""
    /// Lihat: ``stringPencarian1``.
    lazy var stringPencarian3: String = ""
    /// Lihat: ``stringPencarian1``.
    lazy var stringPencarian4: String = ""
    /// Lihat: ``stringPencarian1``.
    lazy var stringPencarian5: String = ""
    /// Lihat: ``stringPencarian1``.
    lazy var stringPencarian6: String = ""

    /// `NSMenu` khusus ``KelasVC`` yang digunakan ``WindowController/actionToolbar``.
    var toolbarMenu: NSMenu = .init()

    override func loadView() {
        // Load XIB dari KelasVC untuk memastikan outlet lain terhubung
        var topLevelObjects: NSArray? = nil
        Bundle.main.loadNibNamed("KelasVC", owner: self, topLevelObjects: &topLevelObjects)

        let tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder

        // Atur tabView ke dalam view KelasVC
        self.tabView = tabView
        view = self.tabView

        // 2. Prepare single‐table nib
        let tableNib = NSNib(nibNamed: "SingleTableView", bundle: nil)

        // 3. Untuk tiap tab, instantiate tableNib
        var tables: [NSTableView] = []
        for i in 0 ..< 6 {
            var tlObjects: NSArray?
            tableNib?.instantiate(withOwner: nil, topLevelObjects: &tlObjects)

            // Ambil scrollView & tableView
            guard let scrollView = tlObjects?
                .first(where: { $0 is NSScrollView }) as? NSScrollView,
                let table = scrollView.documentView as? NSTableView
            else {
                continue
            }
            tables.append(table)

            // Tambah scrollView ke dalam tabViewItem(i).view
            let tabItem = NSTabViewItem(identifier: "tab\(i)")
            tabItem.view?.addSubview(scrollView)

            // 4d. Tambahkan ke tabView
            tabView.addTabViewItem(tabItem)

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            guard let superView = scrollView.superview else { continue }
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: superView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: superView.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
            ])
        }

        // Ambil masing-masing table dari tab item
        table1 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 0))
        table1.autosaveName = "kelasvc1"
        table1.autosaveTableColumns = true

        table2 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 1))
        table2.autosaveName = "kelasvc2"
        table2.autosaveTableColumns = true

        table3 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 2))
        table3.autosaveName = "kelasvc3"
        table3.autosaveTableColumns = true

        table4 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 3))
        table4.autosaveName = "kelasvc4"
        table4.autosaveTableColumns = true

        table5 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 4))
        table5.autosaveName = "kelasvc5"
        table5.autosaveTableColumns = true

        table6 = ReusableFunc.getTableView(from: tabView.tabViewItem(at: 5))
        table6.autosaveName = "kelasvc6"
        table6.autosaveTableColumns = true
    }

    /// Untuk memastikan ``cancellables`` hanya diset sekali dan tidak mengakibatkan duplikat.
    private(set) var isCombineSetup = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let integrateUndo = UserDefaults.standard.bool(forKey: "IntegrasiUndoSiswaKelas")
        myUndoManager = integrateUndo ? SiswaViewModel.siswaUndoManager : UndoManager()

        tabView.delegate = self
        siapkantableView()

        if !isCombineSetup {
            setupCombine()
            isCombineSetup = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        activateSelectedTable()
    }

    override func keyDown(with event: NSEvent) {
        // keyCode 36 adalah tombol Enter/Return
        if event.keyCode == 36, let tableView = activeTable() {
            let selectedIndexes = tableView.selectedRowIndexes
            if let lastSelectedRow = selectedIndexes.last {
                let columnToEdit = 1 // kolom kedua
                tableView.editColumn(columnToEdit, row: lastSelectedRow, with: event, select: true)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupSortDescriptor()

        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            tabView(tabView, didSelect: selectedTabViewItem)
            if let window = view.window {
                window.title = judulTitleBarForTabIndex(selectedTabIndex)
            }
        }

        operationQueue.maxConcurrentOperationCount = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }

        toolbarItem()
        updateMenuItem(self)
        setupNotification()
    }

    /// Mereset dan memuat ulang semua data di UI tabel setelah menerima notifikasi perubahan data terbaru
    /// telah disimpan.
    /// - Parameter notification:  Objek `Notification` yang memicu.
    @objc func saveData(_: Notification) {
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            undoArray.removeAll()
            pastedKelasID.removeAll()
            deleteRedoArray(self)
            for (table, tableType) in tableInfo {
                guard isDataLoaded[table] ?? false else { continue }
                Task { [weak self] in
                    guard let self else { return }
                    await viewModel.loadKelasData(forTableType: tableType)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik
                    table.reloadData()
                    myUndoManager.removeAllActions(withTarget: self)
                    updateUndoRedo(self)
                }
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        searchItem?.cancel()
        searchItem = nil
        Task {
            guard let activeTable = activeTable() else { return }
            let tableType = tableTypeForTable(activeTable)

            let stringPencarianList = [
                stringPencarian1,
                stringPencarian2,
                stringPencarian3,
                stringPencarian4,
                stringPencarian5,
                stringPencarian6,
            ]
            let index = tableType.rawValue
            if index >= 0, index < stringPencarianList.count {
                let keyword = stringPencarianList[index]
                if !keyword.isEmpty {
                    await viewModel.reloadKelasData(tableType)
                }
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
    }

    /// Metode untuk mendapatkan tableView berdasarkan indeks.
    /// - Parameter index: Indeks dari tableView yang ingin diambil.
    func getTableView(for index: Int) -> NSTableView? {
        switch index {
        case 0: table1
        case 1: table2
        case 2: table3
        case 3: table4
        case 4: table5
        case 5: table6
        default: nil
        }
    }

    /// Fungsi ini akan menyimpan sort descriptor saat ini ke dalam `KelasModels.currentSortDescriptor`.
    /// - Parameter index: Indeks dari tableView yang ingin diambil sort descriptor-nya.
    /// - Returns: `NSSortDescriptor?` yang merupakan sort descriptor saat ini dari tableView yang sesuai dengan indeks.
    func getCurrentSortDescriptor(for index: Int) -> NSSortDescriptor? {
        let tableView = getTableView(for: index)
        KelasModels.currentSortDescriptor = tableView?.sortDescriptors.first
        return KelasModels.currentSortDescriptor
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

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``.
    @IBAction func increaseSize(_: Any) {
        if let tableView = activeTable() {
            ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "KelasTableHeight")
        }
    }

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``.
    @IBAction func decreaseSize(_: Any) {
        if let tableView = activeTable() {
            ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "KelasTableHeight")
        }
    }

    /// Work item untuk menangani input pencarian di toolbar.
    var searchItem: DispatchWorkItem?

    /// Fungsi ini menangani input dari `NSSearchField` di toolbar.
    /// - Parameter sender: Objek `NSSearchField` yang memicu.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        // Batalkan work item sebelumnya jika ada
        searchItem?.cancel()
        // Buat work item baru untuk menangani input pencarian
        let work = DispatchWorkItem { [weak self] in
            self?.search(sender.stringValue)
            if let activeTable = self?.activeTable() {
                switch activeTable {
                case self?.table1: self?.stringPencarian1 = sender.stringValue
                case self?.table2: self?.stringPencarian2 = sender.stringValue
                case self?.table3: self?.stringPencarian3 = sender.stringValue
                case self?.table4: self?.stringPencarian4 = sender.stringValue
                case self?.table5: self?.stringPencarian5 = sender.stringValue
                case self?.table6: self?.stringPencarian6 = sender.stringValue
                default:
                    break
                }
            }
        }
        // Simpan work item ke dalam properti searchItem
        searchItem = work
        // Jalankan work item setelah penundaan 0.5 detik
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchItem!)
    }

    /// Fungsi ini menangani aksi muat ulang data pada tableView yang sedang aktif.
    /// - Parameter sender: Objek yang memicu aksi.
    @objc func muatUlang(_ sender: Any) {
        /// Memastikan bahwa tableView yang aktif ada.
        guard let tableView = activeTable() else { return }
        tableView.beginUpdates()
        setupSortDescriptor()
        let tableType = tableTypeForTable(tableView)
        tableView.sortDescriptors.removeAll()
        let sortDescriptor = viewModel.getSortDescriptor(forTableIdentifier: createStringForActiveTable())
        applySortDescriptor(tableView: tableView, sortDescriptor: sortDescriptor)
        KelasModels.currentSortDescriptor = tableView.sortDescriptors.first
        Task { [weak self] in
            guard let self else { return }
            await viewModel.reloadKelasData(tableType)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.5 detik
            tableView.reloadData()
        }
        tableView.endUpdates()
        updateUndoRedo(sender)
        #if DEBUG
            print("StringInterner", StringInterner.shared.count)
        #endif
    }

    /// Fungsi ini menangani pencarian data pada tableView yang sedang aktif.
    /// - Parameter searchText: Teks yang dimasukkan ke dalam `NSSearchField` untuk pencarian.
    func search(_ searchText: String) {
        guard let table = activeTable() else { return }

        if table == table1, searchText == stringPencarian1 {
            return
        } else if table == table2, searchText == stringPencarian2 {
            return
        } else if table == table3, searchText == stringPencarian3 {
            return
        } else if table == table4, searchText == stringPencarian4 {
            return
        } else if table == table5, searchText == stringPencarian5 {
            return
        } else if table == table6, searchText == stringPencarian6 {
            return
        }

        switch table {
        case table1: stringPencarian1 = searchText
        case table2: stringPencarian2 = searchText
        case table3: stringPencarian3 = searchText
        case table4: stringPencarian4 = searchText
        case table5: stringPencarian5 = searchText
        case table6: stringPencarian6 = searchText
        default:
            break
        }
        Task { [weak self] in
            guard let self else { return }
            await viewModel.search(searchText, tableType: activeTableType)
            await MainActor.run {
                table.reloadData()
            }
        }
    }

    // MARK: - STRUKTUR

    /// Fungsi ini mengembalikan tipe tabel berdasarkan `NSTableView` yang diberikan.
    /// - Parameter tableView: `NSTableView` yang ingin diperiksa.
    /// - Returns: `TableType?` yang sesuai dengan `NSTableView`, atau `nil` jika tidak ditemukan.
    func tableType(forTableView tableView: NSTableView) -> TableType? {
        switch tableView {
        case table1:
            .kelas1
        case table2:
            .kelas2
        case table3:
            .kelas3
        case table4:
            .kelas4
        case table5:
            .kelas5
        case table6:
            .kelas6
        default:
            nil
        }
    }

    ///  Fungsi untuk memuat data dari database. Dijalankan ketika suatu tabel
    /// ditampilkan pertama kali atau ketika memuat ulang tabel.
    /// - Parameter tableView: `NSTableView` yang ingin dimuat datanya.
    func loadTableData(tableView: NSTableView, forceLoad: Bool = false) {
        // Membuka progress window.
        ReusableFunc.showProgressWindow(view, isDataLoaded: false)
        Task { [weak self] in
            guard let self else { return }
            guard let tableType = tableType(forTableView: tableView) else { return }

            let sortDescriptor = viewModel.getSortDescriptor(forTableIdentifier: createStringForActiveTable())
            KelasModels.currentSortDescriptor = sortDescriptor

            await viewModel.loadKelasData(forTableType: tableType, forceLoad: forceLoad)

            // Hapus sort descriptor yang ada sebelumnya
            tableView.sortDescriptors.removeAll()
            // Terapkan sort descriptor yang baru
            applySortDescriptor(tableView: tableView, sortDescriptor: sortDescriptor)
            // Simpan sort descriptor ke dalam KelasModels
            setupSortDescriptor()
            // Memastikan bahwa data telah dimuat. Muat ulang tabel dengan data terbaru.
            tableView.reloadData()
            isDataLoaded[tableView] = true

            // Perbarui menu item untuk kolom yang terlihat. Kecuali "namasiswa".
            ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(toggleColumnVisibility(_:)))

            await MainActor.run { [weak self] in
                if let self, let window = view.window {
                    ReusableFunc.closeProgressWindow(window)
                }
            }
        }
    }

    /// Fungsi ini memperbarui action dan target menu item di Menu Bar.
    /// - Parameter sender: Objek pemicu yang dapat berupa `Any?`.
    @objc func updateMenuItem(_: Any?) {
        guard let table = activeTable(),
              let wc = AppDelegate.shared.mainWindow.windowController as? WindowController
        else { return }
        
        let isRowSelected = table.selectedRowIndexes.count > 0
        
        if let hapusToolbarItem = wc.hapusToolbar,
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = isRowSelected
            hapus.target = self
            hapus.action = #selector(hapus(_:))
        }
        if let editToolbarItem = wc.editToolbar,
           let edit = editToolbarItem.view as? NSButton
        {
            // Aktifkan tombol Edit jika ada baris yang dipilih
            edit.isEnabled = isRowSelected
        }

        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let delete = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem,
           let pasteMenuItem = ReusableFunc.pasteMenuItem
        {
            // Mendapatkan NSTableView aktif
            if let activeTableView = activeTable() {
                copyMenuItem.isEnabled = isRowSelected
                pasteMenuItem.target = self
                pasteMenuItem.action = SingletonData.originalPasteAction
                // Update item menu "Delete"
                delete.isEnabled = isRowSelected
                // Periksa apakah ada baris yang dipilih
                if isRowSelected {
                    copyMenuItem.target = SingletonData.originalCopyTarget
                    copyMenuItem.action = SingletonData.originalCopyAction

                    // Set representedObject dengan benar
                    let tableType = tableTypeForTable(activeTableView)
                    let representedObject: (NSTableView, TableType, IndexSet) = (activeTableView, tableType, activeTableView.selectedRowIndexes)
                    delete.representedObject = representedObject
                    delete.target = self
                    // Set action sebagai sebuah closure
                    delete.action = #selector(hapus(_:))
                } else {
                    copyMenuItem.target = nil
                    copyMenuItem.action = nil
                    copyMenuItem.isEnabled = false
                    delete.target = nil
                    delete.action = nil
                    delete.isEnabled = false
                    delete.representedObject = nil
                }
            }
            new.target = self
            new.action = #selector(addData(_:))
        }
    }

    // MARK: - OPERATION

    // Konfigurasi untuk notifikasi yang akan didengarkan oleh controller ini.
    func setupNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateRedoInDetilSiswa(_:)), name: .updateRedoInDetilSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePopupDismissed(_:)), name: .popupDismissedKelas, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(updateDeletion(_:)), name: .findDeletedData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateEditedDetilSiswa(_:)), name: .editDataSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSiswaDihapusNotification(_:)), name: .siswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoSiswaDihapusNotification(_:)), name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSiswaNaik(_:)), name: .naikKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateNamaGuruNotification(_:)), name: .updateGuruMapel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNamaSiswaDiedit(_:)), name: .dataSiswaDiEditDiSiswaView, object: nil)
    }

    // MARK: - EXPORT CSV & PDF

    /// Fungsi ini menangani ekspor data ke file Excel (XLSX) dengan cara menjalankan func ``exportKelasToFile(pdf:data:)``.
    /// - Parameter sender: Objek yang memicu aksi ekspor, biasanya berupa `NSMenuItem`.
    @objc func exportToExcel(_ sender: NSMenuItem) {
        var tableView: NSTableView?
        var tipeTable: TableType?
        if let (table, tipeTabel) = sender.representedObject as? (NSTableView, TableType) {
            tableView = table
            tipeTable = tipeTabel
        } else {
            tableView = activeTable()
            tipeTable = tableType(forTableView: tableView!)
        }
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        exportKelasToFile(pdf: false, data: viewModel.kelasModelForTable(tipeTable!))
    }

    /// Fungsi ini menangani ekspor data ke file PDF dengan cara menjalankan func ``exportKelasToFile(pdf:data:)``.
    /// - Parameter sender: Objek yang memicu aksi ekspor, biasanya berupa `NSMenuItem`.
    @objc func exportToPDF(_ sender: NSMenuItem) {
        var tableView: NSTableView?
        var tipeTable: TableType?
        if let (table, tipeTabel) = sender.representedObject as? (NSTableView, TableType) {
            tableView = table
            tipeTable = tipeTabel
        } else {
            tableView = activeTable()
            tipeTable = tableType(forTableView: tableView!)
        }
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        exportKelasToFile(pdf: true, data: viewModel.kelasModelForTable(tipeTable!))
    }

    /**
     * Fungsi ini melakukan serangkaian langkah untuk mengekspor data siswa yang telah difilter ke dalam format PDF.
     *
     * Langkah-langkah:
     * 1. Memeriksa apakah Python dan Pandas sudah terinstal menggunakan ``ReusableFunc/checkPythonAndPandasInstallation(window:completion:)``.
     * 2. Jika Python dan Pandas terinstal:
     *    - Memproses data ke file CSV untuk dikonversi ke PDF/XLSX.
     *    - Memanggil ``ReusableFunc/chooseFolderAndSaveCSV(header:rows:namaFile:window:sheetWindow:pythonPath:pdf:rowMapper:)`` untuk memilih folder penyimpanan, menyimpan data ke format CSV, dan mengonversi CSV ke PDF.
     * 3. Jika Python tidak terinstal, menutup sheet progress yang ditampilkan.
     * 4. Jika Pandas belum terinstal, mencoba mengunduh pandas dan menginstal di lever User(bukan admin).
     *
     * - Parameters:
     *   - pdf: Jika nilai `true`, file CSV akan dikonversi ke PDF. jika `false`, file CSV dikonversi ke XLSX.
     *   - data: data yang digunakan untuk diproses ``KelasModels``.
     */
    func exportKelasToFile(pdf: Bool, data: [KelasModels]) {
        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { [unowned self] isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let header = ["Nama Siswa", "Mapel", "Nilai", "Semester", "Nama Guru"]
                ReusableFunc.chooseFolderAndSaveCSV(header: header, rows: data, namaFile: "Data \(createLabelForActiveTable())", window: view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: pdf) { siswa in
                    [
                        siswa.namasiswa, siswa.mapel, String(siswa.nilai), siswa.semester, siswa.namaguru,
                    ]
                }
            } else {
                view.window?.endSheet(progressWindow!)
            }
        }
    }

    /// Fungsi ini menangani ekspor data ke file CSV.
    /// - Parameter tableView:
    func exportToCSV(_ tableView: NSTableView) {
        // Mendapatkan data dari model sesuai dengan tabel yang dipilih.
        guard let tableType = tableType(forTableView: tableView) else { return }
        let data = viewModel.kelasModelForTable(tableType)

        // Mengambil nama tabel aktif sebagai bagian dari nama file.
        var fileName = "data"
        guard let activeTable = activeTable() else { return }
        // Optional binding untuk memastikan window tidak nil
        guard let window = view.window else {
            // Tampilkan NSAlert karena window nil.
            let alert = NSAlert()
            alert.icon = NSImage(named: "No Data Bordered")
            alert.messageText = "Data Kelas Belum dipilih"
            alert.informativeText = "Pilih kelas untuk ekspor data ke file dengan format Excel."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if activeTable == table1 {
            fileName += "kelas1"
        } else if activeTable == table2 {
            fileName += "kelas2"
        } else if activeTable == table3 {
            fileName += "kelas3"
        } else if activeTable == table4 {
            fileName += "kelas4"
        } else if activeTable == table5 {
            fileName += "kelas5"
        } else if activeTable == table6 {
            fileName += "kelas6"
        }
        // Menggunakan NSSavePanel untuk meminta izin pengguna dan mendapatkan lokasi penyimpanan file.
        let savePanel = NSSavePanel()
        savePanel.title = "Simpan File Excel"
        savePanel.nameFieldStringValue = "\(fileName).csv"
        savePanel.canCreateDirectories = true

        // Memunculkan NSSavePanel sebagai sheet
        savePanel.beginSheetModal(for: window) { result in
            if result == .OK {
                if let url = savePanel.url {
                    // Menyimpan file CSV ke lokasi yang dipilih oleh pengguna.
                    let filePath = url

                    var csvText = "" // Mulai dengan string kosong untuk CSV

                    // Tambahkan header ke string CSV
                    let header = "Nama Siswa;Mapel;Nilai;Semester;Nama Guru\n" // Menggunakan tab sebagai pemisah
                    csvText.append(header)

                    // Tambahkan data ke string CSV
                    for row in data {
                        csvText.append("\(row.namasiswa);\(row.mapel);\(row.nilai);\(row.semester);\(row.namaguru)\n")
                    }

                    do {
                        try csvText.write(to: filePath, atomically: true, encoding: .utf8)
                        // File CSV berhasil disimpan di lokasi yang dipilih oleh pengguna.
                    } catch {
                        // Terjadi kesalahan saat menyimpan file.
                    }
                }
            }
        }
    }

    /// Fungsi ini menangani aksi cetak untuk tabel yang sedang aktif.
    /// - Parameter sender: Objek yang memicu aksi cetak.
    @IBAction func handlePrint(_: Any) {
        // Memastikan bahwa ada tabel yang aktif.
        guard let activeTable = activeTable() else { return }

        let tableType = tableTypeForTable(activeTable)

        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas.loadView()
        printKelas.print(tableType)
    }

    /// Fungsi ini menangani aksi ekspor data ke file CSV.
    /// - Parameter sender: Objek yang memicu aksi ekspor, biasanya berupa `NSMenuItem`.
    @objc func exportButtonClicked(_ sender: NSMenuItem) {
        if let (table, _) = sender.representedObject as? (NSTableView, TableType) {
            exportToCSV(table)
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let table = activeTable() else { return }
        
        activeTableType = tableTypeForTable(table)
        
        if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
            // Load data for the table view
            loadTableData(tableView: table, forceLoad: true)
            isDataLoaded[table] = true
            table.reloadData()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self else { return }
            NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
            switchTextView()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let window = view.window else { return }
            window.makeFirstResponder(table)
            
            if let selectedTabViewItem = tabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                updateSearchFieldPlaceholder(for: selectedTabIndex)
            }

            switch table {
            case self.table1: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian1)
            case self.table2: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian2)
            case self.table3: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian3)
            case self.table4: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian4)
            case self.table5: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian5)
            case self.table6: ReusableFunc.updateSearchFieldToolbar(window, text: stringPencarian6)
            default:
                break
            }
            performPendingReloads()
        }
    }

    /// Fungsi ini menangani aksi cetak teks yang ditampilkan di `resultTextView`.
    @objc func printText() {
        guard let activeTable = activeTable() else { return }
        let tableType = tableTypeForTable(activeTable)
        let label = "Laporan Nilai \(createLabelForActiveTable())"

        viewModel.updateTextViewWithCalculations(for: tableType, in: resultTextView, label: label)

        // Cetak teks daresultTextViewri
        let printOpts: [NSPrintInfo.AttributeKey: Any] = [.headerAndFooter: false, .orientation: 0]
        let printInfo = NSPrintInfo(dictionary: printOpts)

        // Set the desired width for the paper
        printInfo.paperSize = NSSize(width: printInfo.paperSize.width, height: printInfo.paperSize.height)

        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.scalingFactor = 1.0

        let printOperation = NSPrintOperation(view: resultTextView, printInfo: printInfo)
        printOperation.jobTitle = label
        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
        if let mainWindow = NSApplication.shared.mainWindow {
            printOperation.runModal(for: mainWindow, delegate: nil, didRun: nil, contextInfo: nil)
        }

        printOperation.cleanUp()
        dismiss(true)
    }

    /// Fungsi ini untuk mengubah teks di `resultTextView` dengan informasi yang relevan.
    func switchTextView() {
        let textStorage = NSTextStorage(attributedString: resultTextView.attributedString())
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14.0), range: range) // Atur ukuran font
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10 // Atur line spacing
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        resultTextView.textStorage?.setAttributedString(textStorage)
        resultTextView.textContainerInset = NSSize(width: 10, height: 10)
        let classLabel = createLabelForActiveTable()
        resultTextView.string = """
        Nilai Semester 1 dan 2 tidak ditemukan di \(classLabel)
        """
    }

    /// Fungsi ini menampilkan `NSPopOver` yang berisi informasi nilai siswa untuk kelas yang sedang aktif.
    @objc func showScrollView(_ sender: Any?) {
        let namaKelas = createLabelForActiveTable()
        if let existingWindow = AppDelegate.shared.openedKelasWindows[namaKelas] {
            existingWindow.makeKeyAndOrderFront(sender)
            return
        }

        ReusableFunc.resetMenuItems()

        guard let popover = AppDelegate.shared.popoverTableNilaiSiswa,
              let nilaiSiswaVC = popover.contentViewController as? NilaiKelas
        else { return }

        nilaiSiswaVC.namaKelas = namaKelas

        nilaiSiswaVC.tahunAjaran.removeAll()
        nilaiSiswaVC.kelasAktif = true

        // Tampilkan NilaiSiswa sebagai popover
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Fungsi ini menangani aksi salin data dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func copyDataContextMenu(_ sender: NSMenuItem) {
        if let (table, tableType) = sender.representedObject as? (NSTableView, TableType) {
            let selectedRow = table.clickedRow
            let selectedRowIndexes = table.selectedRowIndexes
            if !selectedRowIndexes.contains(selectedRow), selectedRow != -1 {
                let dataToCopy = "\(viewModel.kelasData[tableType]![selectedRow].namasiswa)\t\(viewModel.kelasData[tableType]![selectedRow].mapel)\t\(viewModel.kelasData[tableType]![selectedRow].nilai)\t\(viewModel.kelasData[tableType]![selectedRow].semester)\t\(viewModel.kelasData[tableType]![selectedRow].namaguru)"
                // Salin data ke clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(dataToCopy, forType: .string)
            } else if selectedRowIndexes.contains(selectedRow), selectedRow != -1 {
                copyAllSelectedData(sender)
            } else {
                copyAllSelectedData(sender)
            }
        }
    }

    /// Fungsi ini menangani aksi salin semua data yang dipilih dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @IBAction func copy(_: Any) {
        // Assuming you have a reference to your active table view
        guard let activeTableView = activeTable() else {
            return
        }

        // Create a dummy NSMenuItem
        let dummyMenuItem = NSMenuItem()

        // Set the representedObject to the active table view and its type
        dummyMenuItem.representedObject = (activeTableView, tableTypeForTable(activeTableView))

        // Call copyAllSelectedData with the dummy NSMenuItem
        copyAllSelectedData(dummyMenuItem)
    }

    /// Fungsi ini menangani aksi salin semua data yang dipilih dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func copyAllSelectedData(_ sender: NSMenuItem) {
        if let (table, tableType) = sender.representedObject as? (NSTableView, TableType) {
            let selectedRows = table.selectedRowIndexes
            if selectedRows.isEmpty {
                // Tidak ada baris yang dipilih, tidak ada yang harus disalin.
                return
            }

            var dataToCopy = ""
            dataToCopy = selectedRows
                .map { "\(viewModel.kelasData[tableType]![$0].namasiswa)\t\(viewModel.kelasData[tableType]![$0].mapel)\t\(viewModel.kelasData[tableType]![$0].nilai)\t\(viewModel.kelasData[tableType]![$0].semester)\t\(viewModel.kelasData[tableType]![$0].namaguru)" }
                .joined(separator: "\n")

            if !dataToCopy.isEmpty {
                // Salin data ke clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(dataToCopy, forType: .string)
            }
        }
    }

    /// Fungsi ini menangani aksi edit mapel dari toolbar.
    /// - Parameter sender: Objek pemicu
    @objc func editMapelToolbar(_: Any) {
        ReusableFunc.showAlert(title: "Nama Guru harus diubah dari Daftar Guru atau Tugas Guru", message: "Untuk konsistensi data, kelas hanya menampilkan referensi dari Tugas Guru dan Siswa kecuali nilai dan tanggal dicatat.")
    }

    /// Fungsi ini menangani aksi edit mapel dari menu konteks.
    /// - Parameter sender:
    @objc func editMapelMenu(_: NSMenuItem) {
        ReusableFunc.showAlert(title: "Nama guru harus diubah dari Daftar Guru atau Tugas Guru", message: "Untuk konsistensi data, kelas hanya menampilkan referensi dari Tugas Guru dan Daftar Siswa kecuali nilai dan tanggal.")
    }

    /// Fungsi ini menginisialisasi tabel-tabel yang ada di kelas.
    func siapkantableView() {
        tableInfo = [
            (table1, .kelas1),
            (table2, .kelas2),
            (table3, .kelas3),
            (table4, .kelas4),
            (table5, .kelas5),
            (table6, .kelas6),
        ]
        let menu = buatMenuItem()
        toolbarMenu = buatMenuItem()
        toolbarMenu.delegate = self
        menu.delegate = self
        for (table, _) in tableInfo {
            for columnInfo in ReusableFunc.columnInfos {
                guard let column = table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else {
                    continue
                }
                let customHeaderCell = MyHeaderCell()
                customHeaderCell.title = columnInfo.customTitle
                column.headerCell = customHeaderCell
            }
            table.target = self
            table.delegate = self
            // table.doubleAction = #selector(editDataClicked)
            table.doubleAction = #selector(tableViewDoubleClick(_:))
            table.allowsMultipleSelection = true
            table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
            table.menu = menu
            table.dataSource = self
            if let savedRowHeight = UserDefaults.standard.value(forKey: "KelasTableHeight") as? CGFloat {
                table.rowHeight = savedRowHeight
            }
        }
    }

    /// Fungsi ini menangani aksi toggle visibilitas kolom pada tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
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

    /// Fungsi ini menyimpan sort descriptor ke dalam UserDefaults untuk tabel tertentu.
    /// - Parameters:
    ///   - sortDescriptor: NSSortDescriptor yang akan disimpan, atau `nil` jika tidak ada.
    ///   - identifier: Identifier tabel yang digunakan sebagai kunci untuk menyimpan sort descriptor.
    func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?, forTableIdentifier identifier: String) {
        if let sortDescriptor {
            let sortDescriptorData = try? NSKeyedArchiver.archivedData(withRootObject: sortDescriptor, requiringSecureCoding: false)
            UserDefaults.standard.set(sortDescriptorData, forKey: "SortDescriptor_\(identifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "SortDescriptor_\(identifier)")
        }
    }

    // Terapkan sort descriptor dari UserDefaults ke table view
    func applySortDescriptor(tableView: NSTableView, sortDescriptor: NSSortDescriptor?) {
        guard let sortDescriptor else {
            return
        }
        // Terapkan sort descriptor ke table view
        tableView.sortDescriptors = [sortDescriptor]
    }

    /// Fungsi ini melakukan konfigurasi awal untuk sort descriptor pada tabel yang sedang aktif.
    func setupSortDescriptor() {
        let table = activeTable()
        let identifikasiKolom = viewModel.setupSortDescriptors()

        guard let tableColumn = table?.tableColumns else { return }

        for column in tableColumn {
            let identifikasi = column.identifier
            let pengidentifikasi = identifikasiKolom[identifikasi]
            column.sortDescriptorPrototype = pengidentifikasi
        }
    }

    /// Fungsi ini menangani aksi klik ganda pada tabel untuk membuka rincian siswa.
    /// - Parameter sender: Objek pemicu `NSTableView`.
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        guard let tableView = sender as? NSTableView else { return }
        let selectedRows = tableView.selectedRowIndexes
        var siswaID = [Int64]()
        var selectedSiswa = [ModelSiswa]()
        // Proses setiap baris yang dipilih
        guard let tableType = tableType(forTableView: tableView) else { return }
        let data = viewModel.kelasModelForTable(tableType)

        for rowIndex in selectedRows {
            guard rowIndex < data.count else { continue }
            if !siswaID.contains(data[rowIndex].siswaID) {
                siswaID.append(data[rowIndex].siswaID)
                if let siswaData = SiswaViewModel.shared.filteredSiswaData.first(where: { $0.id == data[rowIndex].siswaID }) {
                    selectedSiswa.append(siswaData)
                    #if DEBUG
                        print("getFromSiswaViewModel")
                    #endif
                } else {
                    selectedSiswa.append(dbController.getSiswa(idValue: data[rowIndex].siswaID))
                    #if DEBUG
                        print("getFromDatabase")
                    #endif
                }
            }
        }

        guard !selectedSiswa.isEmpty else { return }

        ReusableFunc.bukaRincianSiswa(selectedSiswa, viewController: self)

        ReusableFunc.resetMenuItems()
    }

    /// Delegasi fungsi yang dipanggil ketika jendela detail siswa ditutup.
    /// - Parameter window: Jendela detail siswa yang ditutup.
    @objc func detailWindowDidClose(_ window: DetilWindow) {
        // Cari siswaID yang sesuai dengan jendela yang ditutup
        if let detailViewController = window.contentViewController as? DetailSiswaController,
           let siswaID = detailViewController.siswa?.id
        {
            AppDelegate.shared.openedSiswaWindows.removeValue(forKey: siswaID)
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_: Any?) {
        ReusableFunc.workItemUpdateUndoRedo?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let undoMenuItem = ReusableFunc.undoMenuItem,
                  let redoMenuItem = ReusableFunc.redoMenuItem
            else {
                return
            }

            /* let canUndo = !undoArray.isEmpty || !SingletonData.deletedDataArray.isEmpty || !pastedKelasID.isEmpty || !SingletonData.deletedDataKelas.isEmpty
             let canRedo = !redoArray.isEmpty || !kelasID.isEmpty || !SingletonData.pastedData.isEmpty || !SingletonData.deletedKelasID.isEmpty
              */

            let canUndo = myUndoManager.canUndo
            let canRedo = myUndoManager.canRedo

            if !canUndo {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            } else {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(urung(_:))
                undoMenuItem.isEnabled = canUndo
            }

            if !canRedo {
                guard let mainMenu = NSApp.mainMenu,
                      let editMenuItem = mainMenu.item(withTitle: "Edit"),
                      let editMenu = editMenuItem.submenu,
                      let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
                else {
                    return
                }
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            } else {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(ulang(_:))
                redoMenuItem.isEnabled = canRedo
            }

            // Ambil semua kelasID dari SingletonData.undoStack
            let allKelasIDs = SingletonData.undoStack.values.flatMap { kelasArray in
                kelasArray.flatMap { kelasModelArray in
                    kelasModelArray.map { kelasModel in
                        kelasModel.kelasID
                    }
                }
            }

            // Memeriksa siswa yang dihapus berdasarkan kelasID yang ada di deletedDataArray
            var undoSiswa = false
            if let siswaDihapus = SingletonData.deletedKelasID.last {
                undoSiswa = siswaDihapus.kelasID.contains(where: { allKelasIDs.contains($0) })
            }

            var undoDataSiswa = false
            if let siswaDihapus = kelasID.last {
                undoDataSiswa = siswaDihapus.contains(where: { allKelasIDs.contains($0) })
            }

            var adaSiswaDitambah = false
            // Mengambil kelasID dari elemen terakhir di pastedKelasID
            if let lastPastedKelasIDs = pastedKelasID.last {
                // Memeriksa apakah ada kelasID yang sama dalam pastedKelasID
                adaSiswaDitambah = lastPastedKelasIDs.contains { allKelasIDs.contains($0) }
            } else {
                adaSiswaDitambah = false
            }

            // Jika ada duplikasi atau siswa yang dihapus, nonaktifkan undo
            if adaSiswaDitambah {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            }
            if undoSiswa || undoDataSiswa {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            }
            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    deinit {
        searchItem?.cancel()
        searchItem = nil
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .naikKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .siswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .findDeletedData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editDataSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .addDetil, object: nil)
        NotificationCenter.default.removeObserver(self, name: .popupDismissedKelas, object: nil)
        operationQueue.cancelAllOperations()
    }
}

extension KelasVC {
    /// Mengupdate menu item di Menu Bar ketik popover ditutup.
    @objc func handlePopupDismissed(_: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            updateUndoRedo(self)
            NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
        }
    }

    /// Mengidentifikasi dan mengembalikan instance `NSTableView` yang saat ini aktif (terlihat dan bagian dari hierarki tampilan).
    ///
    /// Fungsi ini memastikan bahwa pemeriksaan tabel aktif selalu dilakukan di **main thread**
    /// karena melibatkan interaksi dengan elemen UI. Jika dipanggil dari thread latar belakang,
    /// ia akan secara sinkron beralih ke main thread untuk melakukan pemeriksaan dan mengembalikan hasilnya.
    ///
    /// - Returns: `NSTableView?` - Tabel yang teridentifikasi sebagai aktif, atau `nil` jika tidak ada
    ///            tabel yang ditemukan dalam hierarki tampilan (meskipun secara default akan mengembalikan `table1`
    ///            sebagai fallback di `checkActiveTable`).
    func activeTable() -> NSTableView? {
        // Jalankan secara sinkron di main thread dan kembalikan hasilnya
        if Thread.isMainThread {
            checkActiveTable()
        } else {
            DispatchQueue.main.sync {
                checkActiveTable()
            }
        }
    }

    /// Memeriksa tabel `NSTableView` mana yang saat ini merupakan turunan dari tampilan utama (`self.view`).
    ///
    /// Fungsi ini dirancang untuk beroperasi di main thread dan secara berurutan memeriksa setiap tabel
    /// (`table1` hingga `table6`) untuk menentukan tabel mana yang sedang ditampilkan dalam hierarki UI.
    /// Sebagai fallback, ia akan selalu mengembalikan `table1` jika tidak ada tabel lain yang ditemukan.
    ///
    /// - Returns: `NSTableView?` - Tabel `NSTableView` yang aktif. Secara default,
    ///            akan mengembalikan `table1` jika tidak ada tabel lain yang ditemukan aktif.
    func checkActiveTable() -> NSTableView? {
        for info in tableInfo {
            if info.table.isDescendant(of: view) {
                return info.table
            }
        }
        return table1
    }

    /// Mengaktifkan tab yang sesuai dalam `NSTabView` berdasarkan `NSTableView` yang diberikan,
    /// dan kemudian memberi tahu delegasi tentang pembaruan tabel yang aktif supaya ``SidebarViewController``
    /// memperbarui indeks pemilihan yang sesuai dengan tabel kelas.
    /// Fungsi ini dirancang untuk menyinkronkan tampilan tabel dengan tab yang dipilih
    /// dan menginformasikan sistem tentang kelas yang diperbarui.
    ///
    /// - Parameter table: `NSTableView` yang akan diaktifkan. Fungsi ini akan mencocokkan
    ///                    tabel yang diberikan dengan salah satu dari `table1` hingga `table6`
    ///                    untuk menentukan indeks tab yang benar.
    func activateTable(_ table: NSTableView) {
        var updatedClass: SidebarIndex?
        switch table {
        case table1: tabView.selectTabViewItem(at: 0); updatedClass = .kelas1
        case table2: tabView.selectTabViewItem(at: 1); updatedClass = .kelas2
        case table3: tabView.selectTabViewItem(at: 2); updatedClass = .kelas3
        case table4: tabView.selectTabViewItem(at: 3); updatedClass = .kelas4
        case table5: tabView.selectTabViewItem(at: 4); updatedClass = .kelas5
        case table6: tabView.selectTabViewItem(at: 5); updatedClass = .kelas6
        default:
            break
        }

        delegate?.didUpdateTable(updatedClass ?? .kelas1)

        delegate?.didCompleteUpdate()
    }

    /// Membuat tabel sebagai firstResponder dan
    /// pengaturan delegate dan datasource tableView.
    func activateSelectedTable() {
        if let selectedTable = activeTable() {
            view.window?.makeFirstResponder(selectedTable)
            selectedTable.delegate = self
            selectedTable.dataSource = self
        }
    }

    /// Menentukan dan mengembalikan tipe kelas (`TableType`) yang terkait dengan instance `NSTableView` yang diberikan.
    /// Fungsi ini memetakan setiap tabel spesifik (`table1` hingga `table6`) ke enumerasi `TableType` yang sesuai.
    ///
    /// - Parameter table: Sebuah instance `NSTableView` yang tipenya ingin ditentukan.
    ///
    /// - Returns: Sebuah nilai `TableType` yang mewakili kelas yang terkait dengan tabel yang diberikan.
    ///            Jika tabel yang diberikan tidak cocok dengan tabel yang telah ditentukan, maka akan mengembalikan
    ///            `.kelas1` sebagai nilai default.
    func tableTypeForTable(_ table: NSTableView) -> TableType {
        tableInfo.first(where: { $0.table == table })?.type ?? .kelas1
    }

    /// Menghasilkan string judul untuk title bar jendela aplikasi berdasarkan indeks tab yang diberikan.
    ///
    /// Saat ini, fungsi ini mengembalikan judul yang dihasilkan oleh `createLabelForActiveTable()`
    /// untuk indeks tab 0 hingga 5, yang menunjukkan bahwa judul title bar mungkin mencerminkan
    /// tabel yang sedang aktif atau dipilih dalam `NSTabView`.
    ///
    /// - Parameter tabIndex: Sebuah `Int` yang merepresentasikan indeks tab yang aktif atau yang dipilih.
    ///
    /// - Returns: Sebuah `String` yang akan digunakan sebagai judul untuk title bar jendela aplikasi.
    ///            Mengembalikan "Judul Default" jika `tabIndex` berada di luar rentang yang ditentukan (0-5).
    func judulTitleBarForTabIndex(_ tabIndex: Int) -> String {
        switch tabIndex {
        case 0, 1, 2, 3, 4, 5:
            createLabelForActiveTable()
        default:
            "Judul Default"
        }
    }

    /// Menghasilkan sebuah string label yang sesuai dengan tabel `NSTableView` yang saat ini aktif.
    /// Fungsi ini memanggil `activeTable()` untuk mendapatkan tabel yang sedang terlihat dan kemudian
    /// mengembalikan label deskriptif berdasarkan instance tabel tersebut.
    ///
    /// - Returns: Sebuah `String` yang merepresentasikan nama atau label dari tabel yang aktif
    ///            (misalnya, "Kelas 1", "Kelas 2", dst.). Mengembalikan "Tabel Aktif Tidak Memiliki Nama"
    ///            jika tidak ada tabel aktif yang dapat diidentifikasi atau jika tabel aktif tidak cocok
    ///            dengan salah satu kasus yang ditentukan.
    func createLabelForActiveTable() -> String {
        if let activeTable = activeTable() {
            // Mendapatkan label sesuai dengan tabel aktif
            switch activeTable {
            case table1:
                return "Kelas 1"
            case table2:
                return "Kelas 2"
            case table3:
                return "Kelas 3"
            case table4:
                return "Kelas 4"
            case table5:
                return "Kelas 5"
            case table6:
                return "Kelas 6"
            default:
                return "Tabel Aktif Tidak Memiliki Nama"
            }
        }
        return "Tabel Aktif Tidak Memiliki Nama"
    }

    /// Mengidentifikasi dan mengembalikan nama string dari `NSTableView` yang saat ini aktif.
    /// Fungsi ini pertama-tama menentukan tabel mana yang aktif dalam hierarki tampilan,
    /// kemudian mengembalikan representasi string dari nama variabel tabel tersebut.
    ///
    /// - Returns: Sebuah `String` yang merepresentasikan nama variabel dari tabel yang aktif
    ///            (misalnya, "table1", "table2", dst.). Mengembalikan "Tabel Aktif Tidak Memiliki Nama"
    ///            jika tidak ada tabel aktif yang dapat diidentifikasi atau jika tabel aktif tidak cocok
    ///            dengan salah satu kasus yang ditentukan.
    func createStringForActiveTable() -> String {
        if let activeTable = activeTable() {
            // Mendapatkan label sesuai dengan tabel aktif
            switch activeTable {
            case table1:
                return "table1"
            case table2:
                return "table2"
            case table3:
                return "table3"
            case table4:
                return "table4"
            case table5:
                return "table5"
            case table6:
                return "table6"
            default:
                return "Tabel Aktif Tidak Memiliki Nama"
            }
        }
        return "Tabel Aktif Tidak Memiliki Nama"
    }

    /// Menghasilkan sebuah string label yang menunjukkan "kelas" atau status berikutnya
    /// berdasarkan tabel `NSTableView` yang saat ini aktif. Fungsi ini dirancang untuk
    /// memberikan label yang sesuai dengan progresi dari satu kelas ke kelas berikutnya,
    /// atau menandakan status "Lulus" jika tabel aktif adalah `table6`.
    ///
    /// - Returns: Sebuah `String` yang merepresentasikan kelas atau status berikutnya.
    ///            Mengembalikan "Tabel Aktif Tidak Memiliki Nama" jika tidak ada tabel aktif
    ///            yang dapat diidentifikasi atau jika tabel aktif tidak cocok dengan salah satu
    ///            kasus yang ditentukan.
    func createLabelForNextClass() -> String {
        if let activeTable = activeTable() {
            // Mendapatkan label sesuai dengan tabel aktif
            switch activeTable {
            case table1:
                return "Kelas 2"
            case table2:
                return "Kelas 3"
            case table3:
                return "Kelas 4"
            case table4:
                return "Kelas 5"
            case table5:
                return "Kelas 6"
            case table6:
                return "Lulus"
            default:
                return "Tabel Aktif Tidak Memiliki Nama"
            }
        }
        return "Tabel Aktif Tidak Memiliki Nama"
    }
}

extension KelasVC {
    /**
      * Memperbarui teks placeholder pada kolom pencarian di toolbar.
      * @discussion Fungsi ini secara dinamis mengubah teks placeholder di kolom pencarian
      * agar sesuai dengan konteks tab yang sedang aktif. Ini membantu pengguna
      * memahami apa yang mereka cari berdasarkan tampilan saat ini.
      *
      * @param tabIndex: Int - Indeks tab yang sedang dipilih atau aktif.
      *
      * @returns: void
     */
    func updateSearchFieldPlaceholder(for tabIndex: Int) {
        guard let wc = view.window?.windowController as? WindowController,
              let searchField = wc.searchField
        else { return }

        searchField.placeholderAttributedString = nil
        searchField.placeholderString = ""
        // Gantilah placeholder string sesuai dengan kebutuhan
        let placeholderString = switch tabIndex {
        case 0: "Cari Kelas 1..."
        case 1: "Cari Kelas 2..."
        case 2: "Cari Kelas 3..."
        case 3: "Cari Kelas 4..."
        case 4: "Cari Kelas 5..."
        case 5: "Cari Kelas 6..."
        default:
            "Cari..."
        }

        if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
            textFieldInsideSearchField.placeholderString = placeholderString
        }
    }

    /// Konfigurasi action dan target toolbar.
    func toolbarItem() {
        guard let wc = view.window?.windowController as? WindowController else { return }

        // SearchField
        wc.searchField.isEnabled = true
        wc.searchField.isEditable = true
        wc.searchField.target = self
        wc.searchField.action = #selector(procSearchFieldInput(sender:))
        wc.searchField.delegate = self
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            updateSearchFieldPlaceholder(for: selectedTabIndex)
        }

        // Tambah Data
        wc.tambahSiswa.isEnabled = true
        wc.tambahSiswa.toolTip = "Tambahkan Data Siswa Baru"
        wc.addDataToolbar.label = "Tambah Siswa"

        // Tambah nilai kelas
        wc.tambahDetaildiKelas.isEnabled = true
        if let image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: .none) {
            let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)
            wc.datakelas.image = largeImage
        }
        wc.datakelas.label = "Tambah Nilai"
        wc.datakelas.paletteLabel = "Tambahkan Nilai Siswa"
        wc.tambahDetaildiKelas.toolTip = "Tambahkan Nilai Baru Siswa yang Sudah Ada"

        // Kalkulasi nilai kelas
        wc.kalkulasiButton.isEnabled = true

        // Action Menu
        wc.actionPopUpButton.menu = toolbarMenu
        toolbarMenu.delegate = self

        // Edit
        wc.tmbledit.isEnabled = activeTable()?.selectedRow != -1

        // Hapus
        wc.hapusToolbar.isEnabled = activeTable()?.selectedRow != -1
        wc.hapusToolbar.target = self

        // Zoom Segment
        wc.segmentedControl.isEnabled = true
        wc.segmentedControl.target = self
        wc.segmentedControl.action = #selector(segmentedControlValueChanged(_:))
    }

    /// Hapus semua array untuk redo.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteRedoArray(_: Any) {
        if !redoArray.isEmpty { redoArray.removeAll() }
        if !kelasID.isEmpty { kelasID.removeAll() }
        SingletonData.deletedKelasID.removeAll()
        kelasID.removeAll()
    }

    /**
     * Membuka dan mengkonfigurasi jendela progres baru sebagai lembar (sheet) di atas jendela utama.
     * @discussion Fungsi ini bertanggung jawab untuk memuat `NSWindowController` dan `ProgressBarVC`
     * dari storyboard "ProgressBar". Setelah berhasil memuat, ia mengatur total item yang akan diperbarui
     * dan pengenal controller di `ProgressBarVC`. Jendela progres kemudian disajikan
     * sebagai lembar modal di atas jendela aplikasi utama.
     *
     * @param totalItems: Int - Jumlah total item yang akan diproses atau diperbarui, yang akan ditampilkan di bilah progres.
     * @param controller: String - String pengenal yang menunjukkan controller mana yang memicu jendela progres ini (misalnya, untuk tujuan pelacakan atau logika).
     *
     * @returns: (NSWindowController, ProgressBarVC)? - Sebuah tuple yang berisi `NSWindowController` dan `ProgressBarVC`
     * dari jendela progres, atau `nil` jika gagal memuat dari storyboard atau mengkonversi controller.
     */
    func openProgressWindow(totalItems: Int, controller: String) -> (NSWindowController, ProgressBarVC)? {
        /// Membuat instance `NSStoryboard` dari nama "ProgressBar".
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)

        /// Mengamankan (guard) instansiasi `NSWindowController` dan `ProgressBarVC` dari storyboard.
        /// Juga memastikan bahwa jendela terkait berhasil diambil.
        /// Jika salah satu gagal, fungsi akan mengembalikan `nil`.
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC,
              let window = progressWindowController.window
        else {
            return nil
        }

        /// Menetapkan jumlah total item yang akan diperbarui ke properti `totalStudentsToUpdate` di `ProgressBarVC`.
        progressViewController.totalStudentsToUpdate = totalItems
        /// Menetapkan string pengenal controller ke properti `controller` di `ProgressBarVC`.
        progressViewController.controller = controller

        /// Menyajikan jendela progres (`window`) sebagai lembar (sheet) di atas jendela aplikasi utama.
        /// Ini berarti jendela progres akan "meluncur" dari bagian atas jendela utama dan memblokir interaksi dengan jendela utama sampai ditutup.
        view.window?.beginSheet(window)

        /// Mengembalikan tuple yang berisi `NSWindowController` dan `ProgressBarVC` yang telah dikonfigurasi.
        return (progressWindowController, progressViewController)
    }

    /**
     * Memberi tahu delegasi tentang pemilihan tabel di sidebar.
     * @discussion Fungsi ini bertanggung jawab untuk mengomunikasikan perubahan pemilihan tabel di sidebar
     * kepada delegasi, yang kemudian dapat memperbarui tampilan konten utama aplikasi.
     * Pembaruan ini dijamin berjalan di main thread untuk keamanan UI.
     *
     * @param table: NSTableView - Instance `NSTableView` yang merepresentasikan tabel yang baru saja dipilih di sidebar.
     *
     * @returns: void
     */
    @MainActor
    func selectSidebar(_ table: NSTableView) {
        switch table {
        case table1: delegate?.didUpdateTable(.kelas1)
        case table2: delegate?.didUpdateTable(.kelas2)
        case table3: delegate?.didUpdateTable(.kelas3)
        case table4: delegate?.didUpdateTable(.kelas4)
        case table5: delegate?.didUpdateTable(.kelas5)
        case table6: delegate?.didUpdateTable(.kelas6)
        default:
            break
        }
    }

    private func performPendingReloads() {
        guard let tableView = activeTable() else { return }
        let type = tableTypeForTable(tableView)

        guard needsReloadForTableType[type] == true else { return }

        let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("namaguru"))
        guard columnIndex != -1 else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        guard let guruIDs = pendingReloadRows[type], !guruIDs.isEmpty else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        // Remap kelasID ke rowIndex saat ini
        let model = viewModel.kelasModelForTable(type)
        var indexSet = IndexSet()
        for (i, item) in model.enumerated() {
            if guruIDs.contains(item.guruID) {
                indexSet.insert(i)
                #if DEBUG
                    print("indexes to reload:", i)
                #endif
            }
        }

        guard !indexSet.isEmpty else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        tableView.reloadData(forRowIndexes: indexSet, columnIndexes: IndexSet(integer: columnIndex))

        // Reset
        needsReloadForTableType[type] = false
        pendingReloadRows[type] = []
    }
}

extension KelasVC: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        updateUndoRedo(obj)

        guard let textField = obj.object as? NSTextField,
              let editedCell = textField.superview as? NSTableCellView,
              let activeTable = activeTable() else { return }

        let row = activeTable.row(for: editedCell)
        let column = activeTable.column(for: editedCell)

        guard row >= 0, let columnIdentifier = KelasColumn(rawValue: activeTable.tableColumns[column].identifier.rawValue),
              let table = SingletonData.dbTable(forTableType: tableTypeForTable(activeTable)),
              let tableType = tableType(forTableView: activeTable)
        else {
            return
        }
        let newValue = textField.stringValue

        let oldValue = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableType), table: table)

        // Dapatkan kelasId dari model data
        let kelasId = viewModel.kelasModelForTable(tableType)[row].kelasID

        // Bandingkan nilai baru dengan nilai lama
        guard newValue != oldValue else { return }

        // Simpan originalModel untuk undo dengan kelasId
        let originalModel = OriginalData(
            kelasId: kelasId, tableType: tableTypeForTable(activeTable),
            columnIdentifier: columnIdentifier,
            oldValue: oldValue,
            newValue: newValue,
            table: table,
            tableView: activeTable
        )
        viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableType), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        }

        // Tambahkan originalModel ke dalam array undoArray
        undoArray.append(originalModel)
        deleteRedoArray(self)
        let numericValue = Int(newValue) ?? 0
        textField.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": tableType, "editedKelasIDs": kelasId, "siswaID": viewModel.kelasModelForTable(tableType)[row].siswaID, "columnIdentifier": columnIdentifier, "dataBaru": newValue])

        updateUndoRedo(obj)
    }
}
