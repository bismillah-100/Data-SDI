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
class KelasVC: NSViewController, DetilWindowDelegate, NSSearchFieldDelegate {
    var tableViewManager: KelasTableManager!

    /// Delegate untuk penambahan data kelas dan memilih kelas yang sesuai di ``SidebarViewController``.
    weak var delegate: KelasVCDelegate?

    /// `NSUndoManager` untuk ``DataSDI/KelasVC``.
    var myUndoManager: UndoManager!

    /// Set untuk menerima event dari publisher ``SiswaViewModel/kelasEvent``
    var cancellables: Set<AnyCancellable> = .init()

    /// Outlet `NSTextView`. Deprecated.
    @IBOutlet var resultTextView: NSTextView!
    /// Outlet `NSScrollView` yang berisi ``resultTextView`.`
    @IBOutlet var scrollView: NSScrollView!
    /// Array untuk undo.
    var undoArray: [OriginalData] = []
    /// Array untuk redo.
    var redoArray: [OriginalData] = []
    /// Instance ``DatabaseController``
    let dbController: DatabaseController = .shared
    /// Instance ``KelasViewModel``
    let viewModel: KelasViewModel = .shared
    /// Properti ``PrintKelas``.
    lazy var printKelas: PrintKelas = .init()

    /// Menyimpan ID unik dari data yang baru dimasukkan ke tabel dan database.
    /// Nilai-nilai ini kemudian dikumpulkan sebagai satu batch ke dalam ``pastedNilaiID`` untuk mendukung undo/redo.
    var pastedNilaiIDs: [Int64] = []
    /// Menyimpan riwayat batch ``pastedNilaiIDs`` sebagai array bertingkat (array of arrays) untuk mendukung undo/redo.
    /// Setiap elemen mewakili satu aksi tempel (paste) data.
    var pastedNilaiID: [[Int64]] = []
    /// Array untuk menyimpan ID unik data yang dihapus.
    var nilaiID: [[Int64]] = []

    /// Properti untuk menyimpan tableType untuk tableView yang sedang aktif.
    var activeTableType: TableType! {
        get {
            tableViewManager.activeTableType
        }
        set {
            tableViewManager.activeTableType = newValue
        }
    }

    /// Instance `OperationQueue`.
    let operationQueue: OperationQueue = .init()

    /// Properti yang menyimpan referensi jika data di ``viewModel``
    /// telah dimuat menggunakan data dari database dan telah ditampilkan
    /// di tableView yang sesuai.
    var isDataLoaded: [NSTableView: Bool] = [:]

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
        view = tabView

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
            if let statusColumn = table.tableColumns.first(where: { $0.identifier.rawValue == "status" }) {
                table.removeTableColumn(statusColumn)
            }

            // Tambah scrollView ke dalam tabViewItem(i).view
            let tabItem = NSTabViewItem(identifier: "tab\(i)")
            tabItem.view?.addSubview(scrollView)

            // 4d. Tambahkan ke tabView
            tabView.addTabViewItem(tabItem)

            // Atur properti tabel secara dinamis
            table.autosaveName = "kelasvc\(i + 1)"
            table.autosaveTableColumns = true

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            guard let superView = scrollView.superview else { continue }
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: superView.topAnchor, constant: -1),
                scrollView.bottomAnchor.constraint(equalTo: superView.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
            ])
        }

        tableViewManager = .init(tabView: tabView, tableViews: tables, selectionDelegate: self)
    }

    /// Untuk memastikan ``cancellables`` hanya diset sekali dan tidak mengakibatkan duplikat.
    private(set) var isCombineSetup = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let integrateUndo = UserDefaults.standard.bool(forKey: "IntegrasiUndoSiswaKelas")
        myUndoManager = integrateUndo ? SiswaViewModel.siswaUndoManager : UndoManager()

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

        tableViewManager.selectTabView()

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
            pastedNilaiID.removeAll()
            deleteRedoArray(self)
            for (table, tableType) in tableViewManager.tableInfo {
                guard isDataLoaded[table] ?? false else { continue }
                Task { [weak self] in
                    guard let self else { return }
                    await viewModel.loadKelasData(forTableType: tableType)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik
                    await MainActor.run {
                        table.reloadData()
                        self.myUndoManager.removeAllActions(withTarget: self)
                    }
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
            guard let activeTable = activeTable(),
                  let keyPath = tableSearchMapping[activeTable] else { return }

            let keyword = self[keyPath: keyPath]
            if !keyword.isEmpty, let tableType = tableType(activeTable) {
                await viewModel.reloadKelasData(tableType)
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
    }

    /// Fungsi ini akan menyimpan sort descriptor saat ini ke dalam `KelasModels.currentSortDescriptor`.
    /// - Parameter index: Indeks dari tableView yang ingin diambil sort descriptor-nya.
    /// - Returns: `NSSortDescriptor?` yang merupakan sort descriptor saat ini dari tableView yang sesuai dengan indeks.
    func getCurrentSortDescriptor(for index: Int) -> NSSortDescriptor? {
        let tableView = tableViewManager.getTableView(for: index)
        return tableView?.sortDescriptors.first
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

    /// Sebuah kamus (`Dictionary`) yang memetakan setiap `NSTableView` ke
    /// `WritableKeyPath` dari string pencarian yang sesuai di `KelasVC`.
    ///
    /// Properti ini diinisialisasi secara `lazy` karena nilainya hanya
    /// dibutuhkan saat pertama kali diakses. Pemetaan ini memungkinkan
    /// pengontrol untuk secara dinamis mengikat tampilan tabel tertentu
    /// ke properti string pencariannya, yang kemudian digunakan untuk
    /// mengelola fungsionalitas pencarian.
    ///
    /// - Key: Sebuah instance `NSTableView` yang dikelola oleh `tableViewManager`.
    /// - Value: Sebuah `WritableKeyPath` yang menunjuk ke properti `String`
    ///          yang dapat ditulis di dalam kelas `KelasVC`, seperti
    ///          `stringPencarian1`, `stringPencarian2`, dst.
    lazy var tableSearchMapping: [NSTableView: WritableKeyPath<KelasVC, String>] = [
        tableViewManager.tables[0]: \.stringPencarian1,
        tableViewManager.tables[1]: \.stringPencarian2,
        tableViewManager.tables[2]: \.stringPencarian3,
        tableViewManager.tables[3]: \.stringPencarian4,
        tableViewManager.tables[4]: \.stringPencarian5,
        tableViewManager.tables[5]: \.stringPencarian6,
    ]

    /// Fungsi ini menangani input dari `NSSearchField` di toolbar.
    /// - Parameter sender: Objek `NSSearchField` yang memicu.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        // Batalkan work item sebelumnya jika ada
        searchItem?.cancel()
        // Buat work item baru untuk menangani input pencarian
        let work = DispatchWorkItem { [weak self] in
            guard var self, let table = activeTable(),
                  let keyPath = tableSearchMapping[table] else { return }

            search(sender.stringValue)

            // Update nilai stringPencarian yang sesuai
            self[keyPath: keyPath] = sender.stringValue
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
        guard let tableView = activeTable(),
              let tableType = tableType(tableView)
        else { return }
        setupSortDescriptor()
        tableView.sortDescriptors.removeAll()
        let sortDescriptor = viewModel.getSortDescriptor(forTableIdentifier: tableViewManager.createStringForActiveTable())
        applySortDescriptor(tableView: tableView, sortDescriptor: sortDescriptor)
        let selectedRows = tableView.selectedRowIndexes
        Task { [weak self] in
            guard let self else { return }
            await viewModel.reloadKelasData(tableType)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.5 detik
            tableView.reloadData()
            tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
            if let max = selectedRows.max() {
                tableView.scrollRowToVisible(max)
            }
        }
        #if DEBUG
            print("StringInterner", StringInterner.shared.count)
        #endif
    }

    /// Fungsi ini menangani pencarian data pada tableView yang sedang aktif.
    /// - Parameter searchText: Teks yang dimasukkan ke dalam `NSSearchField` untuk pencarian.
    func search(_ searchText: String) {
        guard let table = activeTable(),
              let keyPath = tableSearchMapping[table] else { return }

        // Alias mutable untuk self
        var strongSelf = self

        // Cek apakah keyword berubah
        if strongSelf[keyPath: keyPath] == searchText {
            return
        }

        // Update keyword
        strongSelf[keyPath: keyPath] = searchText

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
    func tableType(_ tableView: NSTableView) -> TableType? {
        tableViewManager.tableInfo.first(where: { $0.table == tableView })?.type
    }

    ///  Fungsi untuk memuat data dari database. Dijalankan ketika suatu tabel
    /// ditampilkan pertama kali atau ketika memuat ulang tabel.
    /// - Parameter tableView: `NSTableView` yang ingin dimuat datanya.
    func loadTableData(tableView: NSTableView, forceLoad: Bool = false) {
        // Membuka progress window.
        ReusableFunc.showProgressWindow(view, isDataLoaded: false)
        Task { [weak self] in
            guard let self else { return }

            let sortDescriptor = viewModel.getSortDescriptor(forTableIdentifier: tableViewManager.createStringForActiveTable())

            await viewModel.loadKelasData(forTableType: activeTableType, forceLoad: forceLoad)

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
            ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["namasiswa"], target: tableViewManager, selector: #selector(tableViewManager.toggleColumnVisibility(_:)))

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
                    let representedObject: (NSTableView, TableType, IndexSet) = (activeTableView, activeTableType, activeTableView.selectedRowIndexes)
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
        if let tableViewManager {
            NotificationCenter.default.addObserver(tableViewManager, selector: #selector(tableViewManager.handleUndoKelasDihapusNotification(_:)), name: .updateRedoInDetilSiswa, object: nil)
            NotificationCenter.default.addObserver(
                forName: .findDeletedData,
                object: nil,
                queue: .main
            ) { (payload: DeleteNilaiKelasNotif) in
                tableViewManager.updateDeletion(payload)
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handlePopupDismissed(_:)), name: .popupDismissedKelas, object: nil)

        NotificationCenter.default.addObserver(
            forName: .siswaDihapus,
            queue: ReusableFunc.operationQueue,
            using: { [weak self] (payload: NotifSiswaDihapus) in
                self?.handleSiswaDihapusNotification(payload)
            }
        )

        NotificationCenter.default.addObserver(
            forName: .undoSiswaDihapus,
            queue: ReusableFunc.operationQueue,
            using: { [weak self] (payload: NotifSiswaDihapus) in
                self?.handleUndoSiswaDihapusNotification(payload)
            }
        )

        NotificationCenter.default.addObserver(
            forName: .dataSiswaDiEditDiSiswaView,
            queue: .main
        ) { [weak self] (payload: NotifSiswaDiedit) in
            self?.handleNamaSiswaDiedit(payload)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
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
            tipeTable = tableType(tableView!)
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
            tipeTable = tableType(tableView!)
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
                ReusableFunc.chooseFolderAndSaveCSV(header: header, rows: data, namaFile: "Data \(activeTableType.stringValue)", window: view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: pdf) { siswa in
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
        guard let tableType = tableType(tableView) else { return }
        let data = viewModel.kelasModelForTable(tableType)

        // Mengambil nama tabel aktif sebagai bagian dari nama file.
        var fileName = "data"
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
        fileName += activeTableType.stringValue
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
        guard let activeTable = activeTable(),
              let tableType = tableType(activeTable)
        else { return }

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

    /// Fungsi ini menangani aksi cetak teks yang ditampilkan di `resultTextView`.
    @objc func printText() {
        guard let activeTable = activeTable(),
              let tableType = tableType(activeTable)
        else { return }

        let label = "Laporan Nilai \(activeTableType.stringValue)"

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
        let classLabel = activeTableType.stringValue
        resultTextView.string = """
        Nilai Semester 1 dan 2 tidak ditemukan di \(classLabel)
        """
    }

    /// Fungsi ini menampilkan `NSPopOver` yang berisi informasi nilai siswa untuk kelas yang sedang aktif.
    @objc func showScrollView(_ sender: Any?) {
        let namaKelas = activeTableType.stringValue
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
        dummyMenuItem.representedObject = (activeTableView, tableType(activeTableView))

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
        ReusableFunc.showAlert(title: "Nama guru harus diubah dari Daftar Guru atau Tugas Guru", message: "Untuk konsistensi data, kelas hanya menampilkan referensi dari Tugas Guru dan Daftar Siswa kecuali nilai dan tanggal. Anda akan diarahkan ke Daftar Guru.")
        delegate?.didUpdateTable(.guru)
    }

    /// Fungsi ini menginisialisasi tabel-tabel yang ada di kelas.
    func siapkantableView() {
        let menu = buatMenuItem()
        toolbarMenu = buatMenuItem()
        toolbarMenu.delegate = self
        menu.delegate = self
        for (table, _) in tableViewManager.tableInfo {
            for columnInfo in ReusableFunc.columnInfos {
                guard let column = table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else {
                    continue
                }
                let customHeaderCell = MyHeaderCell()
                customHeaderCell.title = columnInfo.customTitle
                column.headerCell = customHeaderCell
            }
            table.target = self
            table.delegate = tableViewManager
            // table.doubleAction = #selector(editDataClicked)
            table.doubleAction = #selector(tableViewDoubleClick(_:))
            table.allowsMultipleSelection = true
            table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
            table.menu = menu
            table.dataSource = tableViewManager
            if let savedRowHeight = UserDefaults.standard.value(forKey: "KelasTableHeight") as? CGFloat {
                table.rowHeight = savedRowHeight
            }
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

    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        guard let tableView = sender as? NSTableView else { return }
        let selectedRows = tableView.selectedRowIndexes
        let data = viewModel.kelasModelForTable(activeTableType)
        Task { // Mengubah fungsi menjadi async dengan Task

            // Menggunakan Set untuk menghindari duplikasi ID siswa
            let uniqueSiswaIDs = Set(selectedRows.map { data[$0].siswaID })

            let selectedSiswa: [ModelSiswa] = try await withThrowingTaskGroup(of: ModelSiswa.self) { group in
                for siswaID in uniqueSiswaIDs {
                    group.addTask {
                        // Cek di cache (SiswaViewModel) terlebih dahulu
                        if let siswaData = SiswaViewModel.shared.filteredSiswaData.first(where: { $0.id == siswaID }) {
                            #if DEBUG
                                print("getFromSiswaViewModel")
                            #endif
                            return siswaData
                        } else {
                            // Jika tidak ada di cache, panggil getSiswaAsync
                            #if DEBUG
                                print("getFromDatabase")
                            #endif
                            return await self.dbController.getSiswaAsync(idValue: siswaID)
                        }
                    }
                }
                // Mengumpulkan semua hasil task ke dalam satu array
                return try await group.reduce(into: [ModelSiswa]()) { result, siswa in
                    result.append(siswa)
                }
            }

            guard !selectedSiswa.isEmpty else { return }

            // Panggil fungsi di main thread karena ini adalah UI
            await MainActor.run {
                ReusableFunc.bukaRincianSiswa(selectedSiswa, viewController: self)
                ReusableFunc.resetMenuItems()
            }
        }
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
        UndoRedoManager.shared.updateUndoRedoState(
            for: self,
            undoManager: myUndoManager,
            undoSelector: #selector(urung(_:)),
            redoSelector: #selector(ulang(_:)),
            debugName: "KelasVC"
        )
        UndoRedoManager.shared.startObserving()
    }

    deinit {
        searchItem?.cancel()
        searchItem = nil
        NotificationCenter.default.removeObserver(self)
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

    /// Mengidentifikasi dan mengembalikan instance ``KelasTableManager/activeTableView``.
    ///
    /// Fungsi ini memastikan bahwa pemeriksaan tabel aktif selalu dilakukan di **main thread**
    /// karena melibatkan interaksi dengan elemen UI. Jika dipanggil dari thread latar belakang,
    /// ia akan secara sinkron beralih ke main thread untuk melakukan pemeriksaan dan mengembalikan hasilnya.
    ///
    /// - Returns: `NSTableView?` - Tabel yang teridentifikasi sebagai aktif, atau `nil` jika tidak ada.
    @MainActor
    func activeTable() -> NSTableView? {
        tableViewManager.activeTableView
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
        // Temukan indeks tabel yang cocok di dalam array
        if let index = tableViewManager.tables.firstIndex(of: table),
           let updatedClass = sidebarIndex(forIndex: index)
        {
            // Gunakan indeks untuk memilih tab
            tableViewManager.selectTabViewItem(at: index)
            // Panggil delegate dengan nilai yang sudah diperbarui
            delegate?.didUpdateTable(updatedClass)
            delegate?.didCompleteUpdate()
        }
    }

    /// Membuat tabel sebagai firstResponder dan
    /// pengaturan delegate dan datasource tableView.
    func activateSelectedTable() {
        if let selectedTable = activeTable() {
            view.window?.makeFirstResponder(selectedTable)
            selectedTable.delegate = tableViewManager
            selectedTable.dataSource = tableViewManager
        }
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
        if activeTableType.rawValue < 5 {
            "Kelas \(activeTableType.rawValue + 2)"
        } else {
            "Lulus"
        }
    }
}

extension KelasVC {
    /**
      * Memperbarui teks placeholder pada kolom pencarian di toolbar.
      * @discussion Fungsi ini secara dinamis mengubah teks placeholder di kolom pencarian
      * agar sesuai dengan konteks tab ``KelasTableManager/activeTableType``
      * yang sedang aktif. Ini membantu pengguna
      * memahami apa yang mereka cari berdasarkan tampilan saat ini.
      *
      * @returns: void
     */
    func updateSearchFieldPlaceholder() {
        guard let wc = view.window?.windowController as? WindowController,
              let searchField = wc.searchField
        else { return }

        searchField.placeholderAttributedString = nil
        searchField.placeholderString = ""
        // Gantilah placeholder string sesuai dengan kebutuhan
        let placeholderString = "Cari \(activeTableType.stringValue)..."

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
        if !nilaiID.isEmpty { nilaiID.removeAll() }
        SingletonData.deletedNilaiID.removeAll()
        nilaiID.removeAll()
    }

    /// Mengonversi indeks tabel menjadi SidebarIndex yang sesuai.
    /// - Parameter index: Indeks tabel (0-5).
    /// - Returns: SidebarIndex yang sesuai, atau nil jika indeks tidak valid.
    private func sidebarIndex(forIndex index: Int) -> SidebarIndex? {
        switch index {
        case 0: .kelas1
        case 1: .kelas2
        case 2: .kelas3
        case 3: .kelas4
        case 4: .kelas5
        case 5: .kelas6
        default: nil
        }
    }
}

extension KelasVC {
    func didEndEditing(_ textField: NSTextField, originalModel: OriginalData) {
        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        }

        // Tambahkan originalModel ke dalam array undoArray
        undoArray.append(originalModel)
        deleteRedoArray(self)
    }
}
