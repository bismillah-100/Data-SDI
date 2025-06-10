// لا إله إلا الله مخمد رسول الله
//  KelasVC.swift
//  Bismillah
//
//  Created by SDI on 29/10/23.
//  Copyright © 2023 SDI. All rights reserved.
//
import Cocoa

/// Class yang bertanggung jawab menampilkan dan mengelola interaksi untuk semua data kelas aktif dan siswa yang ada di dalamnya.
class KelasVC: NSViewController, NSTableViewDataSource, NSTabViewDelegate, DetilWindowDelegate, NSSearchFieldDelegate {
    /// Identifier untuk window tempat kelasVC berada.
    var windowIdentifier: String?

    /// Delegate untuk penambahan data kelas dan memilih kelas yang sesuai di ``SidebarViewController`` dan ``tabView``.
    weak var delegate: KelasVCDelegate?

    /// `NSUndoManager` khusus ``DataSDI/KelasVC``
    var myUndoManager: UndoManager = .init()

    /// `NSTabView` untuk menampung beberapa tableView.
    weak var tabView: NSTabView!
    /// `NSTableView` untuk kelas 1.
    weak var table1: EditableTableView!
    /// `NSTableView` untuk kelas 2.
    weak var table2: EditableTableView!
    /// `NSTableView` untuk kelas 3.
    weak var table3: EditableTableView!
    /// `NSTableView` untuk kelas 4.
    weak var table4: EditableTableView!
    /// `NSTableView` untuk kelas 5.
    weak var table5: EditableTableView!
    /// `NSTableView` untuk kelas 6.
    weak var table6: EditableTableView!
    /// Outlet `NSTextView`. Deprecated.
    @IBOutlet var resultTextView: NSTextView!
    /// Outlet `NSScrollView` yang berisi ``resultTextView`.`
    @IBOutlet var scrollView: NSScrollView!
    /// Array untuk undo.
    var undoArray: [OriginalData] = []
    /// Array untuk redo.
    var redoArray: [OriginalData] = []
    /// Instans ``DatabaseController``
    let dbController = DatabaseController.shared
    /// Instans ``KelasViewModel``
    let viewModel = KelasViewModel()
    /// Properti kamus table dan tableType nya.
    var tableInfo: [(table: NSTableView, type: TableType)] = []
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
    /// Properti untuk menentukan subclass yang benar dari ``KelasModels``.
    lazy var targetModel: [KelasModels] = []
    /// Properti untuk menyimpan tableType untuk tableView yang sedang aktif.
    lazy var activeTableType: TableType = .kelas1
    /// Instans `OperationQueue`.
    let operationQueue = OperationQueue()

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

    /// Properti ``OverlayEditorManager`` untuk prediksi pengetikan
    /// di dalam cell tableView.
    var editorManager: OverlayEditorManager!

    /// Instans `NSPopOver` untuk menampilkan``NilaiKelas``
    let popover = NSPopover()

    /// `NSMenu` khusus ``KelasVC`` yang digunakan ``WindowController/actionToolbar``.
    var toolbarMenu = NSMenu()

    override func loadView() {
        // Load XIB dari KelasVC untuk memastikan outlet lain terhubung
        var topLevelObjects: NSArray? = nil
        Bundle.main.loadNibNamed("KelasVC", owner: self, topLevelObjects: &topLevelObjects)

        // load XIB untuk TabContentView
        if Bundle.main.loadNibNamed("TabContentView", owner: nil, topLevelObjects: &topLevelObjects) {
            guard let tabView = topLevelObjects?.first(where: { $0 is NSTabView }) as? NSTabView else {
                fatalError("Tidak menemukan NSTabView")
            }

            // Atur tabView ke dalam view KelasVC
            self.tabView = tabView
            if let view = topLevelObjects?.first(where: { $0 is NSTabView }) as? NSTabView {
                self.view = view
            }

            // Pastikan ada 6 tab
            guard tabView.numberOfTabViewItems >= 6 else {
                fatalError("Tidak ada 6 tab di TabContentView.xib")
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

        } else {
            fatalError("tidak dapat load TabContentView.xib")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabView.delegate = self
        siapkantableView()
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoSiswaDihapusNotification(_:)), name: .undoSiswaDihapus, object: nil)
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
        guard let table = activeTable() else {
            setupSortDescriptor()
            return
        }
        if !(isDataLoaded[table] ?? false) {
            // Load data for the table view
            loadTableData(tableView: table)
        }
        setupSortDescriptor()
        if !(isDataLoaded[table] ?? false) {
            table.reloadData()
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 detik

            guard let self, let table = self.activeTable(), let window = self.view.window else { return }
            window.makeFirstResponder(table)

            switch table {
            case self.table1: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian1)
            case self.table2: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian2)
            case self.table3: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian3)
            case self.table4: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian4)
            case self.table5: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian5)
            case self.table6: ReusableFunc.updateSearchFieldToolbar(window, text: self.stringPencarian6)
            default:
                break
            }

            updateUndoRedo(self)
        }

        switchTextView()
        updateTextViewWithCalculations()
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            if let window = view.window {
                window.title = judulTitleBarForTabIndex(selectedTabIndex)
            }
        }
        toolbarItem()
        updateMenuItem(self)
        operationQueue.maxConcurrentOperationCount = 1
        setupNotification()
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
    }

    /// Mereset dan memuat ulang semua data di UI tabel setelah menerima notifikasi perubahan data terbaru
    /// telah disimpan.
    /// - Parameter notification:  Objek `Notification` yang memicu.
    @objc func saveData(_ notification: Notification) {
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            self.undoArray.removeAll()
            self.pastedKelasID.removeAll()
            self.deleteRedoArray(self)
            for (table, tableType) in self.tableInfo {
                guard self.isDataLoaded[table] ?? false else { continue }
                Task { [weak self] in
                    guard let self else { return }
                    await self.viewModel.loadKelasData(forTableType: tableType)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik
                    table.reloadData()
                    self.myUndoManager.removeAllActions(withTarget: self)
                    self.updateUndoRedo(self)
                }
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        searchItem?.cancel()
        searchItem = nil
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.removeObserver(self, name: .updateTableNotification, object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    /// Fungsi ini menangani notifikasi ketika data siswa ditambahkan dari ``DetailSiswaController``.
    /// Baik itu dari undo ataupun redo.
    /// - Parameter notification: Objek `Notification` yang memicu.
    @objc func updateRedoInDetilSiswa(_ notification: Notification) {
        // Memastikan tableView yang aktif.
        guard let table = activeTable() else { return }
        // Memastikan bahwa notifikasi memiliki userInfo yang berisi data yang diperlukan.
        if let userInfo = notification.userInfo {
            if let dataArray = userInfo["data"] as? [(index: Int, data: KelasModels)] {
                table.beginUpdates()
                for data in dataArray {
                    // Memastikan bahwa nama siswa tidak kosong sebelum memasukkan baris.
                    guard !data.data.namasiswa.isEmpty else {
                        continue
                    }
                    let index = data.index
                    let data = data.data
                    // Memastikan bahwa data yang akan dimasukkan tidak duplikat.
                    _ = insertRow(forIndex: index, withData: data)
                }
                table.endUpdates()
            }
        }
    }

    /// Menyisipkan baris baru pada tableView yang sesuai dengan data yang diberikan.
    /// - Parameters:
    ///   - index: Indeks untuk tableView yang sesuai dengan data yang akan disisipkan.
    ///   - data: Data kelas yang akan disisipkan ke dalam tableView.
    /// - Returns: Nilai indeks baris yang disisipkan, atau `nil` jika penyisipan gagal.
    func insertRow(forIndex index: Int, withData data: KelasModels) -> Int? {
        guard let sortDescriptor = getCurrentSortDescriptor(for: index) else {
            print("Sort descriptor tidak ditemukan untuk indeks \(index)")
            return nil
        }
        guard let tableType = TableType(rawValue: index) else {
            print("Tipe tabel tidak ditemukan untuk indeks \(index)")
            return nil
        }
        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else {
            print("Gagal menyisipkan data untuk indeks \(index)")
            return nil
        }
        // Mendapatkan tableView yang sesuai dengan indeks
        let tableView = getTableView(for: index)
        tableView?.insertRows(at: IndexSet(integer: rowInsertion), withAnimation: .slideDown)
        tableView?.scrollRowToVisible(rowInsertion)
        return rowInsertion
    }

    /// Fungsi ini menangani notifikasi ketika data kelas ditambah.
    /// - Parameter notification: Objek `Notification` yang memicu.
    @objc func updateTable(_ notification: Notification) {
        var table: EditableTableView!
        var updatedClass: Int?
        // Nama Kelas yang sedang diperbarui.
        var controller: String?
        // Mendapatkan indeks baris di tableView yang telah diinsert untuk dipilih.
        var rowIndex = IndexSet()
        // Menyimpan ID unik kelas yang akan di-tambahkan.
        var id = Set<Int64>()
        // Memastikan bahwa ada data yang diterima dari notifikasi.
        guard let userInfo = notification.userInfo,
              let dataArray = userInfo["data"] as? [(index: Int, data: KelasModels)]
        else { return }

        // Jumlah data yang akan diperbarui.
        let totalStudents = dataArray.count

        // Membuka progress window
        guard let (progressWindowController, progressViewController) = openProgressWindow(totalItems: totalStudents, controller: controller ?? "data kelas") else { return }
        // Mengatur progress view controller
        var processedStudentsCount = 0
        // Mengatur operasi antrian untuk pembaruan data
        operationQueue.maxConcurrentOperationCount = 1

        // Menghitung frekuensi pembaruan untuk progress view
        let updateFrequency = totalStudents > 100 ? max(totalStudents / 10, 1) : 1

        operationQueue.addOperation { [unowned self] in
            // Iterasi melalui dataArray dari belakang untuk menghindari masalah saat menambahkan baris.
            for data in dataArray.reversed() {
                let index = data.index
                let data = data.data
                id.insert(data.kelasID)
                switch index {
                case 0:
                    table = table1
                    updatedClass = 15
                case 1:
                    updatedClass = 16
                    table = table2
                case 2:
                    updatedClass = 17
                    table = table3
                case 3:
                    updatedClass = 18
                    table = table4
                case 4:
                    updatedClass = 19
                    table = table5
                case 5:
                    updatedClass = 20
                    table = table6
                default:
                    break
                }
                OperationQueue.main.addOperation { [unowned self] in
                    if controller != createLabelForActiveTable() {
                        // Jika controller tidak sesuai dengan label aktif, buat label baru
                        controller = createLabelForActiveTable()
                        progressViewController.controller = controller
                    }

                    // delegate untuk memperbarui seleksi tabel di ``SidebarViewController``.
                    self.delegate?.didUpdateTable(updatedClass ?? 15)

                    self.delegate?.didCompleteUpdate()

                    // Memastikan nama siswa tidak kosong sebelum memasukkan baris.
                    _ = insertRow(forIndex: index, withData: data)

                    processedStudentsCount += 1

                    // Update progress
                    if processedStudentsCount % updateFrequency == 0 || processedStudentsCount == totalStudents {
                        progressViewController.currentStudentIndex = processedStudentsCount
                    }
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedKelasIDs.append(data.kelasID)
            }
            OperationQueue.main.addOperation { [unowned self] in
                guard let table, let tipeTable = tableType(forTableView: table) else {
                    print("Tipe tabel tidak ditemukan untuk tableView.")
                    progressWindowController.close()
                    return
                }
                // Menyimpan ID kelas yang baru ditambahkan untuk keperluan undo.
                pastedKelasID.append(pastedKelasIDs)
                // hapus kelasIDs yang sudah disimpan.
                pastedKelasIDs.removeAll()

                myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
                    guard let strongSelf = self else { return }
                    strongSelf.undoPaste(table: table, tableType: tipeTable)
                }

                table.beginUpdates()

                // Memastikan bahwa ID yang baru ditambahkan ada di dalam model kelas untuk tabel yang sesuai.
                for ID in id {
                    let model = viewModel.kelasModelForTable(tableTypeForTable(table))
                    if let index = model.firstIndex(where: { $0.kelasID == ID }) {
                        rowIndex.insert(index)
                    }
                }

                table.selectRowIndexes(rowIndex, byExtendingSelection: false)
                table.endUpdates()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.view.window?.endSheet(progressWindowController.window!)
                }
                NotificationCenter.default.post(name: .hapusDataKelas, object: self)
            }
        }

        guard userInfo["tambahData"] as? Bool == true else { return }
        // Jika data yang ditambahkan adalah data baru, maka kita perlu menghapus redoArray.
        deleteRedoArray(self)
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

    /// Fungsi ini untuk menjalankan undo paste pada tableView yang sesuai dengan tipe tabel yang diberikan.
    /// - Parameters:
    ///   - table: `NSTableView` yang akan di-undo paste.
    ///   - tableType: `TableType` yang sesuai dengan tipe tabel yang akan di-undo paste.
    func undoPaste(table: NSTableView, tableType: TableType) {
        // Memastikan pastedKelasID tidak kosong dan ada table yang terakhir dihapus.
        guard !pastedKelasID.isEmpty, let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else {
            print("Tidak ada data yang dapat di-undo paste.")
            return
        }

        // Ambil semua ID dari array kelasID terakhir
        let allIDs = pastedKelasID.removeLast()

        // Tentukan targetModel berdasarkan tipe table
        switch tableType {
        case .kelas1:
            targetModel = viewModel.kelas1Model
        case .kelas2:
            targetModel = viewModel.kelas2Model
        case .kelas3:
            targetModel = viewModel.kelas3Model
        case .kelas4:
            targetModel = viewModel.kelas4Model
        case .kelas5:
            targetModel = viewModel.kelas5Model
        case .kelas6:
            targetModel = viewModel.kelas6Model
        }

        // Panggil ViewModel untuk menghapus data
        guard let result = viewModel.removeData(withIDs: allIDs, fromModel: &targetModel, forTableType: tableType) else {
            return
        }

        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result

        // Update NSTableView
        table.beginUpdates()
        for index in indexesToRemove {
            table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            if index == table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: table.numberOfRows - 1), byExtendingSelection: false)
                table.scrollRowToVisible(table.numberOfRows - 1)
            } else {
                table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                table.scrollRowToVisible(index)
            }
        }
        table.endUpdates()
        // Simpan data yang dihapus ke dalam SingletonData.pastedData
        SingletonData.pastedData.append((table: lastDeletedTable, data: dataDihapus))
        // Simpan ID kelas dan siswa yang dihapus ke dalam SingletonData.deletedKelasAndSiswaIDs
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)

        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.redoPaste(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        NotificationCenter.default.post(name: .hapusDataKelas, object: self)
        selectSidebar(table)
    }

    func redoPaste(tableType: TableType, table: NSTableView) {
        // Memastikan sortDescriptor di KelasModels tersedia.
        guard let sortDescriptor = KelasModels.currentSortDescriptor else {
            return
        }
        // Pindah ke tabel yang akan diperbarui.
        activateTable(table)

        var indexesToAdd: [Int] = []
        var allIDs: [Int64] = []
        table.deselectAll(self)
        let pasteData = SingletonData.pastedData.removeLast()

        // Cek apakah data yang akan di-paste sudah ada untuk menghindari duplikasi
        for (_, deletedData) in pasteData.data.enumerated().reversed() {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
            indexesToAdd.append(insertionIndex)
            allIDs.append(deletedData.kelasID)
        }
        // Update tableView dengan indeks yang baru ditambahkan
        if !allIDs.isEmpty {
            pastedKelasID.append(allIDs)
            SingletonData.deletedKelasAndSiswaIDs.removeAll { kelasSiswaPairs in
                kelasSiswaPairs.contains { pair in
                    allIDs.contains(pair.kelasID)
                }
            }
        }

        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoPaste(table: table, tableType: tableType)
        }

        updateUndoRedo(self)
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
    @IBAction func increaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight += 5
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
            }
            saveRowHeight()
        }
    }

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``.
    @IBAction func decreaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight = max(tableView.rowHeight - 3, 16)
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
            }
            saveRowHeight()
        }
    }

    /// Func untuk menyimpan konfigurasi tinggi baris tabel ke UserDefaults.
    func saveRowHeight() {
        if let tableView = activeTable() {
            UserDefaults.standard.setValue(tableView.rowHeight, forKey: "KelasTableHeight")
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
            await self.viewModel.loadKelasData(forTableType: tableType)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.5 detik
            tableView.reloadData()
        }
        tableView.endUpdates()
        updateUndoRedo(sender)
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
            await self.viewModel.search(searchText, tableType: self.activeTableType)
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
    func loadTableData(tableView: NSTableView) {
        // Membuka progress window.
        ReusableFunc.showProgressWindow(view, isDataLoaded: false)
        Task { [weak self] in
            guard let self else { return }
            guard let activeTable = self.activeTable() else { return }
            guard let tableType = self.tableType(forTableView: activeTable) else { return }

            let sortDescriptor = self.viewModel.getSortDescriptor(forTableIdentifier: self.createStringForActiveTable())
            KelasModels.currentSortDescriptor = sortDescriptor

            await self.viewModel.loadKelasData(forTableType: tableType)

            switch activeTable {
            case self.table1: SingletonData.table1dimuat = true
            case self.table2: SingletonData.table2dimuat = true
            case self.table3: SingletonData.table3dimuat = true
            case self.table4: SingletonData.table4dimuat = true
            case self.table5: SingletonData.table5dimuat = true
            case self.table6: SingletonData.table6dimuat = true
            default:
                break
            }
            // Hapus sort descriptor yang ada sebelumnya
            activeTable.sortDescriptors.removeAll()
            // Terapkan sort descriptor yang baru
            self.applySortDescriptor(tableView: activeTable, sortDescriptor: sortDescriptor)
            // Simpan sort descriptor ke dalam KelasModels
            self.setupSortDescriptor()
            // Memastikan bahwa data telah dimuat. Muat ulang tabel dengan data terbaru.
            activeTable.reloadData()
            self.isDataLoaded[activeTable] = true

            // Perbarui menu item untuk kolom yang terlihat. Kecuali "namasiswa".
            ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(self.toggleColumnVisibility(_:)))

            await MainActor.run { [weak self] in
                if let self, let window = self.view.window {
                    ReusableFunc.closeProgressWindow(window)
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik

            guard let containingWindow = self.view.window else {
                fatalError("MyCoolTableViewController's view is not in a window.")
            }

            self.editorManager = OverlayEditorManager(tableView: activeTable, containingWindow: containingWindow)
            self.editorManager.delegate = self
            self.editorManager.dataSource = self

            activeTable.editAction = { [weak self] row, column in
                self?.editorManager.startEditing(row: row, column: column)
            }
        }
    }

    /// Fungsi ini memperbarui action dan target menu item di Menu Bar.
    /// - Parameter sender: Objek pemicu yang dapat berupa `Any?`.
    @objc func updateMenuItem(_ sender: Any?) {
        let isRowSelected = activeTable()!.selectedRowIndexes.count > 0
        if let toolbar = view.window?.toolbar,
           let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = isRowSelected
            hapus.target = self
            hapus.action = #selector(hapus(_:))
        }
        if let toolbar = view.window?.toolbar,
           let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            // Aktifkan tombol Edit jika ada baris yang dipilih
            edit.isEnabled = isRowSelected
        }

        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let fileMenu = mainMenu.item(withTitle: "File"),
           let fileMenuItem = fileMenu.submenu,
           let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" }),
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
           let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" })
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

    @objc func hapus(_ sender: Any) {
        // Memastikan menu utama aplikasi, item menu "Edit", dan submenunya dapat diakses.
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           // Mencari item menu "hapus" berdasarkan identifier-nya.
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" })
        {
            // Memastikan objek `representedObject` dari item menu "hapus" dapat di-cast
            // ke dalam bentuk tuple yang diharapkan: (NSTableView, TableType, IndexSet).
            guard let representedObject = delete.representedObject as? (NSTableView, TableType, IndexSet) else {
                return // Jika gagal, hentikan eksekusi fungsi.
            }

            let (table, tableType, selectedIndexes) = representedObject

            // Memastikan ada indeks yang terpilih sebelum melanjutkan proses penghapusan.
            guard !selectedIndexes.isEmpty else {
                return // Jika tidak ada, hentikan eksekusi fungsi.
            }

            // Menginisialisasi Set untuk menyimpan nama siswa dan mata pelajaran unik dari baris yang terpilih.
            var uniqueSelectedStudentNames = Set<String>()
            var uniqueSelectedMapel = Set<String>()

            // Mengisi Set dengan nama siswa dan mata pelajaran dari model data
            // yang sesuai dengan indeks yang terpilih.
            for index in selectedIndexes {
                uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
                uniqueSelectedMapel.insert(viewModel.kelasModelForTable(tableType)[index].mapel)
            }

            // Menggabungkan nama siswa dan mata pelajaran unik menjadi string yang dipisahkan koma
            // untuk ditampilkan di dalam dialog konfirmasi.
            let selectedStudentNamesString = uniqueSelectedStudentNames.sorted().joined(separator: ", ")
            let selectedMapelString = uniqueSelectedMapel.sorted().joined(separator: ", ")

            // Membuat dan mengkonfigurasi objek NSAlert untuk meminta konfirmasi penghapusan dari pengguna.
            let alert = NSAlert()
            alert.messageText = "Apakah Anda yakin akan menghapus data ini dari \"\(selectedStudentNamesString)\""
            alert.informativeText = "\"\(selectedMapelString)\" akan dihapus dari \(selectedStudentNamesString)."
            alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
            alert.addButton(withTitle: "Hapus") // Tombol "Hapus"
            alert.addButton(withTitle: "Batalkan") // Tombol "Batalkan"

            // Memeriksa pengaturan UserDefaults untuk melihat apakah peringatan penghapusan harus disembunyikan.
            let userDefaults = UserDefaults.standard
            let suppressAlert = userDefaults.bool(forKey: "hapusKelasAktifAlert")
            alert.showsSuppressionButton = true // Menampilkan kotak centang "Jangan tampilkan lagi"

            // Jika peringatan disembunyikan (berdasarkan pengaturan pengguna),
            // lanjutkan langsung dengan fungsi penghapusan tanpa menampilkan dialog.
            guard !suppressAlert else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
                return
            }

            // Menjalankan dialog peringatan dan menangkap respons dari pengguna.
            let response = alert.runModal()

            // Jika pengguna menekan tombol "Hapus":
            if response == .alertFirstButtonReturn {
                // Jika kotak centang "Jangan tampilkan lagi" dicentang, perbarui UserDefaults.
                if alert.suppressionButton?.state == .on {
                    UserDefaults.standard.set(true, forKey: "hapusKelasAktifAlert")
                }
                // Memanggil fungsi `hapusPilih` untuk melakukan tindakan penghapusan sebenarnya.
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    // MARK: - OPERATION

    // Konfigurasi untuk notifikasi yang akan didengarkan oleh controller ini.
    func setupNotification() {
        NotificationCenter.default.removeObserver(self, name: .updateTableNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(muatUlang(_:)), name: .hapusDataSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTable(_:)), name: .updateTableNotification, object: nil)
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
//        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoArray(_:)), name: Notification.Name("UpdateUndoArrayKelas"), object: nil)
    }

    // MARK: - EXPORT CSV & PDF

    /// Fungsi ini menyimpan data siswa ke dalam file CSV.
    /// - Parameters:
    /// - header: Array dari string yang berisi header untuk file CSV.
    /// - siswaData: Array dari `KelasModels` yang berisi data siswa yang akan disimpan.
    /// - destinationURL: URL tujuan untuk menyimpan file CSV.
    func saveToCSV(header: [String], siswaData: [KelasModels], destinationURL: URL) throws {
        // Membuat baris data siswa sebagai array dari string
        let rows = siswaData.map { [$0.namasiswa, $0.mapel, String($0.nilai), String($0.semester), $0.namaguru] }

        // Menggabungkan header dengan data dan mengubahnya menjadi string CSV
        let csvString = ([header] + rows).map { $0.joined(separator: ";") }.joined(separator: "\n")

        // Menulis string CSV ke file
        try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    /// Fungsi ini menangani ekspor data ke file Excel (XLSX) atau PDF.
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
        // Memeriksa apakah Python dan Pandas sudah terinstal.
        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { [unowned self] isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.viewModel.kelasModelForTable(tipeTable!)
                self.chooseFolderAndSaveCSV(header: ["Nama Siswa", "Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "data \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: false)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /// Fungsi ini menangani ekspor data ke file PDF.
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

        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { [unowned self] isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.viewModel.kelasModelForTable(tipeTable!)
                self.chooseFolderAndSaveCSV(header: ["Nama Siswa", "Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "data \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: true)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /// Fungsi ini meminta pengguna untuk memilih folder dan menyimpan data siswa ke dalam file CSV.
    /// - Parameters:
    /// - header: Array dari string yang berisi header untuk file CSV.
    /// - siswaData: Array dari `KelasModels` yang berisi data siswa yang akan disimpan.
    /// - namaFile: Nama file yang akan digunakan untuk menyimpan data.
    /// - window: `NSWindow` yang akan digunakan untuk menampilkan dialog penyimpanan.
    /// - sheetWindow: `NSWindow` yang akan digunakan sebagai sheet untuk dialog penyimpanan.
    /// - pythonPath: Path ke interpreter Python yang akan digunakan untuk menjalankan skrip konversi.
    /// - pdf: Boolean yang menentukan apakah data akan disimpan sebagai PDF atau tidak.
    func chooseFolderAndSaveCSV(header: [String], siswaData: [KelasModels], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?, pdf: Bool) {
        // Tentukan lokasi untuk menyimpan file CSV di folder aplikasi
        let csvFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(namaFile).csv")
        do {
            if pdf {
                try saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScriptPDF(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: true)
                })
            } else {
                try saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScript(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: false)
                })
            }
        } catch {
            window?.endSheet(sheetWindow!)
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
    @IBAction func handlePrint(_ sender: Any) {
        // Memastikan bahwa ada tabel yang aktif.
        if let activeTable = activeTable() {
            if activeTable == table1 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.prnt1()

            } else if activeTable == table2 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.printkls2()
            } else if activeTable == table3 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.printkls3()

            } else if activeTable == table4 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.printkls4()

            } else if activeTable == table5 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.printkls5()
            } else if activeTable == table6 {
                let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
                if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
                    self.printKelas = printKelas
                }
                printKelas.loadView()
                printKelas.printkls6()
            }
        }
    }

    /// Fungsi ini menangani aksi ekspor data ke file CSV.
    /// - Parameter sender: Objek yang memicu aksi ekspor, biasanya berupa `NSMenuItem`.
    @objc func exportButtonClicked(_ sender: NSMenuItem) {
        if let (table, _) = sender.representedObject as? (NSTableView, TableType) {
            exportToCSV(table)
        }
    }

    /// Lihat: ``pasteWindow(_:)`` untuk penjelasan lebih lanjut.
    @IBAction func paste(_ sender: Any) {
        pasteWindow(self)
    }

    /// Fungsi ini menangani aksi tempel data ke dalam tabel yang sedang aktif.
    /// - Parameter sender: Objek yang memicu aksi tempel.
    @objc func pasteWindow(_ sender: Any?) {
        // Instantiate PastediKelas storyboard
        let storyboard = NSStoryboard(name: NSStoryboard.Name("PastediKelas"), bundle: nil)

        if let pastediKelasVC = storyboard.instantiateController(withIdentifier: "PasteItem") as? PastediKelas {
            // Buat window controller
            let windowController = NSWindowController(window: NSWindow(contentViewController: pastediKelasVC))
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                pastediKelasVC.loadView()
                pastediKelasVC.windowIdentifier = windowIdentifier
                pastediKelasVC.kelasTerpilih(index: selectedTabIndex)
            }
            // Begin the sheet
            NSApp.keyWindow?.beginSheet(windowController.window!, completionHandler: nil)
        }
        activeTable()?.deselectAll(sender)
    }

    /// Fungsi ini untuk kalkulasi nilai total dari semua siswa dalam kelas.
    /// - Parameter kelas: Array dari `KelasModels` yang berisi data siswa.
    func calculateTotalNilai(forKelas kelas: [KelasModels]) -> Int {
        var total = 0
        for siswa in kelas {
            total += Int(siswa.nilai)
        }
        return total
    }

    /// Fungsi ini untuk menghitung total nilai dan siswa teratas berdasarkan semester yang dipilih.
    /// - Parameters:
    ///  - kelas: Array dari `KelasModels` yang berisi data siswa.
    ///  - semester: String yang menunjukkan semester yang ingin dihitung.
    /// - Returns: Tuple yang berisi total nilai dan daftar siswa teratas.
    func calculateTotalAndTopSiswa(forKelas kelas: [KelasModels], semester: String) -> (totalNilai: Int64, topSiswa: [String]) {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Calculate total nilai for the selected semester
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }

        // Calculate top siswa for the selected semester
        let topSiswa = calculateTopSiswa(forKelas: siswaSemester, semester: semester)

        return (totalNilai, topSiswa)
    }

    /// Fungsi ini menghitung siswa teratas berdasarkan nilai mereka dalam kelas untuk semester tertentu.
    /// - Parameters:
    ///   - kelas: Array dari `KelasModels` yang berisi data siswa.
    ///   - semester: String yang menunjukkan semester yang ingin dihitung.
    /// - Returns: Array dari string yang berisi nama siswa beserta total nilai dan rata-rata nilai mereka.
    func calculateTopSiswa(forKelas kelas: [KelasModels], semester: String) -> [String] {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Hitung jumlah nilai dan rata-rata untuk setiap siswa.
        var nilaiSiswaDictionary: [String: (totalNilai: Int64, jumlahSiswa: Int64)] = [:]
        for siswa in siswaSemester {
            if var siswaData = nilaiSiswaDictionary[siswa.namasiswa] {
                siswaData.totalNilai += siswa.nilai
                siswaData.jumlahSiswa += 1
                nilaiSiswaDictionary[siswa.namasiswa] = siswaData
            } else {
                nilaiSiswaDictionary[siswa.namasiswa] = (totalNilai: siswa.nilai, jumlahSiswa: 1)
            }
        }
        // Urutkan siswa berdasarkan total nilai dari yang tertinggi ke terendah.
        let sortedSiswa = nilaiSiswaDictionary.sorted { $0.value.totalNilai > $1.value.totalNilai }

        // Kembalikan hasil dalam format yang sesuai.
        var result: [String] = []
        for (namaSiswa, dataSiswa) in sortedSiswa {
            let totalNilai = dataSiswa.totalNilai
            let jumlahSiswa = dataSiswa.jumlahSiswa
            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)
            result.append("\(namaSiswa) (Jumlah Nilai: \(totalNilai), Rata-rata Nilai: \(formattedRataRataNilai))")
        }
        return result
    }

    /// Fungsi ini menghitung rata-rata nilai umum kelas untuk semester tertentu.
    /// - Parameters:
    ///   - kelas: Array dari `KelasModels` yang berisi data siswa.
    ///   - semester: String yang menunjukkan semester yang ingin dihitung.
    /// - Returns: String yang berisi rata-rata nilai umum kelas untuk semester tersebut, atau `nil` jika tidak ada siswa pada semester tersebut.
    func calculateRataRataNilaiUmumKelas(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Jumlah total nilai untuk semua siswa pada semester tersebut.
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }

        // Jumlah siswa pada semester tersebut.
        let jumlahSiswa = siswaSemester.count

        // Hitung rata-rata nilai umum kelas untuk semester tersebut.
        guard jumlahSiswa > 0 else {
            return nil // Menghindari pembagian oleh nol.
        }

        let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)

        // Mengubah nilai rata-rata menjadi format dua desimal
        let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)

        return formattedRataRataNilai
    }

    /// Fungsi ini menghitung rata-rata nilai per mata pelajaran untuk kelas tertentu pada semester yang dipilih.
    /// - Parameters:
    ///   - kelas: Array dari `KelasModels` yang berisi data siswa.
    ///   - semester: String yang menunjukkan semester yang ingin dihitung.
    /// - Returns: String yang berisi rata-rata nilai per mata pelajaran, atau `nil` jika tidak ada siswa pada semester tersebut.
    func calculateRataRataNilaiPerMapel(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Membuat set unik dari semua mata pelajaran yang ada di semester tersebut.
        let uniqueMapels = Set(siswaSemester.map(\.mapel))

        // Dictionary untuk menyimpan hasil per-mapel.
        var totalNilaiPerMapel: [String: Int] = [:]
        var jumlahSiswaPerMapel: [String: Int] = [:]

        // Menghitung total nilai per-mapel dan jumlah siswa per-mapel.
        for mapel in uniqueMapels {
            // Filter siswa berdasarkan mata pelajaran.
            let siswaMapel = siswaSemester.filter { $0.mapel == mapel }

            // Jumlah total nilai untuk semua siswa pada mata pelajaran tersebut.
            let totalNilai = siswaMapel.reduce(0) { $0 + $1.nilai }

            // Jumlah siswa pada mata pelajaran tersebut.
            let jumlahSiswa = siswaMapel.count

            // Menyimpan hasil total nilai dan jumlah siswa per-mapel.
            totalNilaiPerMapel[mapel] = totalNilaiPerMapel[mapel, default: 0] + Int(totalNilai)
            jumlahSiswaPerMapel[mapel] = jumlahSiswaPerMapel[mapel, default: 0] + jumlahSiswa
        }

        // Menghitung rata-rata nilai per-mapel.
        var rataRataPerMapel: [String: String] = [:]
        for mapel in uniqueMapels {
            guard let totalNilai = totalNilaiPerMapel[mapel], let jumlahSiswa = jumlahSiswaPerMapel[mapel], jumlahSiswa > 0 else {
                rataRataPerMapel[mapel] = "Data tidak tersedia"
                continue
            }

            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)

            // Mengubah nilai rata-rata menjadi format dua desimal.
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)

            // Menyimpan hasil rata-rata per-mapel dengan paragraf baru.
            rataRataPerMapel[mapel] = formattedRataRataNilai
        }

        // Menggabungkan hasil rata-rata per-mapel dengan paragraf baru.
        let resultString = rataRataPerMapel.map { "\($0.key): \($0.value)" }.joined(separator: " | ")

        return resultString
    }

    /// Fungsi ini menangani penambahan data baru ke kelas.
    /// - Parameter sender: Objek pemicu yang dapat berupa apapun.
    @objc func addData(_ sender: Any?) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("AddDetaildiKelas"), bundle: nil)
        // Check if contentViewController is an instance of SplitVC
        if let detailViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas")) as? AddDetaildiKelas {
            let detailWindow = NSWindow(contentViewController: detailViewController)
            detailWindow.title = "Tambah Data Kelas"
            // Set properties to display as sheet window
            detailWindow.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            detailWindow.isReleasedWhenClosed = false
            detailWindow.standardWindowButton(.zoomButton)?.isHidden = true // Optional: Hide zoom button
            detailWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true // Optional: Hide miniaturize button
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                detailViewController.loadView()
                detailViewController.appDelegate = false
                detailViewController.windowIdentifier = windowIdentifier
                detailViewController.tabKelas(index: selectedTabIndex)
            }
            // Present as a sheet window
            if let mainWindow = view.window {
                mainWindow.beginSheet(detailWindow, completionHandler: nil)
            }
        }
        ReusableFunc.resetMenuItems()
    }

    /// Fungsi ini menangani penambahan siswa baru.
    @objc func addSiswa(_ sender: Any?) {
        let addDataViewController = AddDataViewController(nibName: "AddData", bundle: nil)
        // Ganti "AddDataViewController" dengan ID view controller yang benar
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            addDataViewController.loadView()
            addDataViewController.sourceViewController = .kelasViewController
            addDataViewController.kelasTerpilih(index: selectedTabIndex)

            // Tentukan titik tampilan untuk menempatkan popover
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.contentViewController = addDataViewController

            if let button = sender as? NSButton {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
            }
        }
        ReusableFunc.resetMenuItems()
    }

    /// Fungsi ini menangani pembaruan teks di `resultTextView` dengan perhitungan nilai siswa.
    @objc func updateTextViewWithCalculations() {
        if let selectedTable = activeTable() {
            // Get the label for the active table
            let classLabel = createLabelForActiveTable()

            // Determine the table type based on the selected table
            guard let tableType = tableType(forTableView: selectedTable) else { return }

            let kelasModel: [KelasModels] = switch tableType {
            case .kelas1:
                viewModel.kelas1Model
            case .kelas2:
                viewModel.kelas2Model
            case .kelas3:
                viewModel.kelas3Model
            case .kelas4:
                viewModel.kelas4Model
            case .kelas5:
                viewModel.kelas5Model
            case .kelas6:
                viewModel.kelas6Model
            }

            // Get all unique semesters
            let uniqueSemesters = Set(kelasModel.map(\.semester)).sorted { ReusableFunc.semesterOrder($0, $1) }

            // Initialize the text view string
            var resultText = "\(classLabel)\nJumlah Nilai Semua Semester: \(calculateTotalNilai(forKelas: kelasModel))\n\n"

            // Process each semester
            for semester in uniqueSemesters {
                let formattedSemester = ReusableFunc.formatSemesterName(semester)
                let (totalNilai, topSiswa) = calculateTotalAndTopSiswa(forKelas: kelasModel, semester: semester)
                if let rataRataNilaiUmum = calculateRataRataNilaiUmumKelas(forKelas: kelasModel, semester: semester) {
                    resultText += """
                    Jumlah Nilai \(formattedSemester): \(totalNilai)\n
                    Rata-rata Nilai Umum \(formattedSemester): \(rataRataNilaiUmum)
                    \(topSiswa.joined(separator: "\n"))\n
                    Rata-rata Nilai Per Mapel \(formattedSemester):
                    \(calculateRataRataNilaiPerMapel(forKelas: kelasModel, semester: semester) ?? "")\n\n_______________________________________________________________

                    """
                }
            }

            // Update the resultTextView with the combined results
            resultTextView.string = resultText
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let table = activeTable() {
            if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
                // Load data for the table view
                loadTableData(tableView: table)
                isDataLoaded[table] = true
            }
            activeTableType = tableTypeForTable(table)
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                updateSearchFieldPlaceholder(for: selectedTabIndex)
            }
        }
    }

    /// Fungsi ini menangani aksi cetak teks yang ditampilkan di `resultTextView`.
    @objc func printText() {
        updateTextViewWithCalculations()

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
        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
        if let mainWindow = NSApplication.shared.mainWindow {
            printOperation.runModal(for: mainWindow, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            // Handle the case when the main window is nil
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
        // Load NilaiSiswa XIB
        let nilaiSiswaVC = NilaiKelas(nibName: "NilaiKelas", bundle: nil)
        // Setel data StudentSummary untuk ditampilkan
        nilaiSiswaVC.jumlahnilai = "\(calculateTotalNilai(forKelas: viewModel.kelasModelForTable(tableTypeForTable(activeTable()!))))"
        nilaiSiswaVC.namaKelas = namaKelas
        nilaiSiswaVC.kelasModel = viewModel.kelasModelForTable(tableTypeForTable(activeTable()!))
        // Tampilkan NilaiSiswa sebagai popover
        popover.contentViewController = nilaiSiswaVC
        popover.behavior = .semitransient

        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
        nilaiSiswaVC.popover = popover
    }

    /// Fungsi ini menangani aksi salin data dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func copyDataContextMenu(_ sender: NSMenuItem) {
        if let (table, tableType) = sender.representedObject as? (NSTableView, TableType) {
            let selectedRow = table.clickedRow
            let selectedRowIndexes = table.selectedRowIndexes
            if !selectedRowIndexes.contains(selectedRow), selectedRow != -1 {
                let dataToCopy = switch tableType {
                case .kelas1:
                    "\(viewModel.kelas1Model[selectedRow].namasiswa)\t\(viewModel.kelas1Model[selectedRow].mapel)\t\(viewModel.kelas1Model[selectedRow].nilai)\t\(viewModel.kelas1Model[selectedRow].semester)\t\(viewModel.kelas1Model[selectedRow].namaguru)"
                case .kelas2:
                    "\(viewModel.kelas2Model[selectedRow].namasiswa)\t\(viewModel.kelas2Model[selectedRow].mapel)\t\(viewModel.kelas2Model[selectedRow].nilai)\t\(viewModel.kelas2Model[selectedRow].semester)\t\(viewModel.kelas2Model[selectedRow].namaguru)"
                case .kelas3:
                    "\(viewModel.kelas3Model[selectedRow].namasiswa)\t\(viewModel.kelas3Model[selectedRow].mapel)\t\(viewModel.kelas3Model[selectedRow].nilai)\t\(viewModel.kelas3Model[selectedRow].semester)\t\(viewModel.kelas3Model[selectedRow].namaguru)"
                case .kelas4:
                    "\(viewModel.kelas4Model[selectedRow].namasiswa)\t\(viewModel.kelas4Model[selectedRow].mapel)\t\(viewModel.kelas4Model[selectedRow].nilai)\t\(viewModel.kelas4Model[selectedRow].semester)\t\(viewModel.kelas4Model[selectedRow].namaguru)"
                case .kelas5:
                    "\(viewModel.kelas5Model[selectedRow].namasiswa)\t\(viewModel.kelas5Model[selectedRow].mapel)\t\(viewModel.kelas5Model[selectedRow].nilai)\t\(viewModel.kelas5Model[selectedRow].semester)\t\(viewModel.kelas5Model[selectedRow].namaguru)"
                case .kelas6:
                    "\(viewModel.kelas6Model[selectedRow].namasiswa)\t\(viewModel.kelas6Model[selectedRow].mapel)\t\(viewModel.kelas6Model[selectedRow].nilai)\t\(viewModel.kelas6Model[selectedRow].semester)\t\(viewModel.kelas6Model[selectedRow].namaguru)"
                }
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
    @IBAction func copy(_ sender: Any) {
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
            switch tableType {
            case .kelas1:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas1Model[$0].namasiswa)\t\(viewModel.kelas1Model[$0].mapel)\t\(viewModel.kelas1Model[$0].nilai)\t\(viewModel.kelas1Model[$0].semester)\t\(viewModel.kelas1Model[$0].namaguru)" }
                    .joined(separator: "\n")
            case .kelas2:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas2Model[$0].namasiswa)\t\(viewModel.kelas2Model[$0].mapel)\t\(viewModel.kelas2Model[$0].nilai)\t\(viewModel.kelas2Model[$0].semester)\t\(viewModel.kelas2Model[$0].namaguru)" }
                    .joined(separator: "\n")
            case .kelas3:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas3Model[$0].namasiswa)\t\(viewModel.kelas3Model[$0].mapel)\t\(viewModel.kelas3Model[$0].nilai)\t\(viewModel.kelas3Model[$0].semester)\t\(viewModel.kelas3Model[$0].namaguru)" }
                    .joined(separator: "\n")
            case .kelas4:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas4Model[$0].namasiswa)\t\(viewModel.kelas4Model[$0].mapel)\t\(viewModel.kelas4Model[$0].nilai)\t\(viewModel.kelas4Model[$0].semester)\t\(viewModel.kelas4Model[$0].namaguru)" }
                    .joined(separator: "\n")
            case .kelas5:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas5Model[$0].namasiswa)\t\(viewModel.kelas5Model[$0].mapel)\t\(viewModel.kelas5Model[$0].nilai)\t\(viewModel.kelas5Model[$0].semester)\t\(viewModel.kelas5Model[$0].namaguru)" }
                    .joined(separator: "\n")
            case .kelas6:
                dataToCopy = selectedRows
                    .map { "\(viewModel.kelas6Model[$0].namasiswa)\t\(viewModel.kelas6Model[$0].mapel)\t\(viewModel.kelas6Model[$0].nilai)\t\(viewModel.kelas6Model[$0].semester)\t\(viewModel.kelas6Model[$0].namaguru)" }
                    .joined(separator: "\n")
            }

            if !dataToCopy.isEmpty {
                // Salin data ke clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(dataToCopy, forType: .string)
            }
        }
    }

    /// Fungsi ini menangani aksi naik kelas untuk siswa yang dipilih di tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func naikKelasMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)
        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes
        var uniqueSelectedStudentNames = Set<String>()

        // Mengisi Set dengan nama siswa dari indeks terpilih
        for index in selectedIndexes {
            uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
        }
        var siswaTerpilih = ""
        var namasiswa = ""
        if selectedRow >= 0 {
            namasiswa = viewModel.kelasModelForTable(tableType)[selectedRow].namasiswa
        }
        siswaTerpilih.insert(contentsOf: namasiswa, at: siswaTerpilih.startIndex)

        // Menggabungkan Set menjadi satu string dengan koma
        let selectedStudentNamesString = uniqueSelectedStudentNames.joined(separator: ", ")

        var alert: NSAlert?

        // Cek apakah baris yang diklik adalah bagian dari baris yang dipilih
        if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi Kenaikan \(selectedStudentNamesString)"
            alert?.informativeText = "\(selectedStudentNamesString) akan dinaikkan dari \(createLabelForActiveTable()). Semua data nilai disimpan. Tindakan ini tidak dapat diurungkan."
        } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi Kenaikan \(siswaTerpilih)"
            alert?.informativeText = "\(siswaTerpilih) akan dinaikkan dari \(createLabelForActiveTable()). Semua data nilai disimpan. Tindakan ini tidak dapat diurungkan."
        } else {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi Kenaikan \(selectedStudentNamesString)"
            alert?.informativeText = "\(selectedStudentNamesString) akan dinaikkan dari \(createLabelForActiveTable()). Semua data nilai disimpan. Tindakan ini tidak dapat diurungkan."
        }

        alert?.addButton(withTitle: "OK")
        alert?.addButton(withTitle: "Batalkan")

        guard let unwrappedAlert = alert else { return }
        // 1. Set untuk siswaID yang akan dipilih
        var siswaIDsToSelect: Set<Int64> = []

        // Ambil siswaID dari clickedRow
        var clickedRowSiswaID: Int64 = 0
        if selectedRow >= 0 {
            clickedRowSiswaID = dataArray[selectedRow].siswaID
        }

        // 2. Jika clickedRow tidak ada di selectedIndexes, pilih hanya baris yang sesuai dengan clickedRow
        if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            // Pilih hanya baris dengan siswaID dari clickedRow
            siswaIDsToSelect.insert(clickedRowSiswaID)
        } else if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            // 3. Jika clickedRow ada di selectedIndexes, pilih semua baris di selectedIndexes dan siswaID dari clickedRow
            siswaIDsToSelect.insert(clickedRowSiswaID)

            // Tambahkan siswaID dari semua baris di selectedIndexes
            for rowIndex in selectedIndexes {
                let siswaIDValue = dataArray[rowIndex].siswaID
                siswaIDsToSelect.insert(siswaIDValue)
            }
        } else {
            // Tambahkan siswaID dari semua baris di selectedIndexes
            for rowIndex in selectedIndexes {
                let siswaIDValue = dataArray[rowIndex].siswaID
                siswaIDsToSelect.insert(siswaIDValue)
            }
        }

        // 4. Mencari semua index yang memiliki siswaID yang sesuai dari siswaIDsToSelect
        var indexesToSelect: [Int] = []
        for (index, data) in dataArray.enumerated() {
            if siswaIDsToSelect.contains(data.siswaID) {
                indexesToSelect.append(index)
            }
        }

        // 5. Pilih baris yang sesuai dengan siswaID dari clickedRow dan selectedIndexes (jika ada)
        table.selectRowIndexes(IndexSet(indexesToSelect), byExtendingSelection: false)

        // Dapatkan window dari tabel atau dari aplikasi
        if let window = table.window {
            // Menampilkan alert sebagai sheet
            unwrappedAlert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Jika clickedRow ada di dalam selectedIndexes, panggil fungsi naikKelasPilih
                    if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                        self.naikKelasPilih(tableType: tableType, table: table, selectedIndexes: table.selectedRowIndexes)
                    } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                        self.naikKelasKlik(tableType: tableType, table: table, clickedRow: selectedRow)
                    } else {
                        self.naikKelasPilih(tableType: tableType, table: table, selectedIndexes: table.selectedRowIndexes)
                    }
                } else {
                    // Jika pengguna membatalkan
                    table.deselectAll(sender)
                    if selectedIndexes.count == 1, selectedIndexes.last == 0 {
                        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: true)
                    } else {
                        table.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
                    }
                }
            }
        }
    }

    /// Fungsi ini menangani aksi naik kelas untuk siswa yang diklik di tabel.
    /// - Parameters
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    func naikKelasKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        var dataArray: [KelasModels] = []
        switch tableType {
        case .kelas1:
            dataArray = viewModel.kelas1Model
        case .kelas2:
            dataArray = viewModel.kelas2Model
        case .kelas3:
            dataArray = viewModel.kelas3Model
        case .kelas4:
            dataArray = viewModel.kelas4Model
        case .kelas5:
            dataArray = viewModel.kelas5Model
        case .kelas6:
            dataArray = viewModel.kelas6Model
        }
        let nextClassName = createLabelForNextClass()
        let namaSiswaValue = dataArray[clickedRow].namasiswa
        let siswaIDValue = dataArray[clickedRow].siswaID
        var kelasIDValue: [Int64] = []
        if tableType == .kelas6 {
            dbController.siswaLulus(namaSiswa: namaSiswaValue, siswaID: siswaIDValue, kelasBerikutnya: "Lulus")
        }
        var indexesToDelete: [Int] = []
        table.deselectAll(self)
        for (index, data) in dataArray.enumerated() {
            if data.siswaID == siswaIDValue {
                indexesToDelete.append(index)
                kelasIDValue.append(data.kelasID)
            }
        }
        var selectedRowAfterDeletion: Int?
        if indexesToDelete.sorted(by: <).last != nil {
            selectedRowAfterDeletion = indexesToDelete.last! + 1 // Pilih baris selanjutnya
            if selectedRowAfterDeletion! >= dataArray.count {
                selectedRowAfterDeletion = nil
            }
        }
        table.deselectAll(self)
        if let rowToSelect = selectedRowAfterDeletion {
            table.selectRowIndexes(IndexSet([rowToSelect]), byExtendingSelection: false)
        }
        if selectedRowAfterDeletion == nil {
            table.selectRowIndexes(IndexSet(integer: dataArray.count - indexesToDelete.count - 1), byExtendingSelection: false)
        }
        for indexToDelete in indexesToDelete.reversed() {
            viewModel.removeData(index: indexToDelete, tableType: tableType)
        }
        // Hapus baris-baris yang sesuai dari dataArray dan tabel
        table.beginUpdates()
        for index in indexesToDelete.reversed() {
            table.removeRows(at: IndexSet([index]), withAnimation: .slideDown)
        }
        table.endUpdates()
        dbController.hapusSiswa(fromTabel: currentClassTable, siswaID: siswaIDValue)
        dbController.updateKelasAktif(idSiswa: siswaIDValue, newKelasAktif: nextClassName)
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": [siswaIDValue], "naikKelas": true])
        let userInfo: [String: Any] = [
            "tableType": tableType,
            "siswaIDs": [siswaIDValue],
        ]
        NotificationCenter.default.post(name: .naikKelas, object: self, userInfo: userInfo)

        pastedKelasID = pastedKelasID.map { arrayOfIDs in
            arrayOfIDs.filter { !kelasIDValue.contains($0) }
        }
        // Hapus array kosong
        pastedKelasID.removeAll { $0.isEmpty }
    }

    /// Fungsi ini menangani aksi naik kelas untuk siswa yang dipilih di tabel.
    /// - Parameters
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    func naikKelasPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)

        var deletedSiswaIDs: [Int64] = []
        var siswaIDsToDelete: Set<Int64> = []
        var deletedKelasIDs: [Int64] = []
        for rowIndex in selectedIndexes {
            let siswaIDValue = dataArray[rowIndex].siswaID
            siswaIDsToDelete.insert(siswaIDValue)
        }

        let nextClassName = createLabelForNextClass()
        table.deselectAll(self)

        // Proses penghapusan siswa
        for rowIndex in selectedIndexes.reversed() {
            let namaSiswaValue = dataArray[rowIndex].namasiswa
            let siswaIDValue = dataArray[rowIndex].siswaID
            deletedSiswaIDs.append(siswaIDValue)
            deletedKelasIDs.append(dataArray[rowIndex].kelasID)
            if tableType == .kelas6 {
                dbController.siswaLulus(namaSiswa: namaSiswaValue, siswaID: siswaIDValue, kelasBerikutnya: "Lulus")
                let userInfo = ["siswaID": siswaIDValue, "kelasBaru": String("Lulus")] as [String: Any]
                NotificationCenter.default.post(name: .siswaNaikDariKelasVC, object: nil, userInfo: userInfo)
            }
            viewModel.removeData(index: rowIndex, tableType: tableType)
            dbController.hapusSiswa(fromTabel: currentClassTable, siswaID: siswaIDValue)
            dbController.updateKelasAktif(idSiswa: siswaIDValue, newKelasAktif: nextClassName)
            let userInfo = ["siswaID": siswaIDValue, "kelasBaru": nextClassName] as [String: Any]
            NotificationCenter.default.post(name: .siswaNaikDariKelasVC, object: nil, userInfo: userInfo)
        }

        // Menghapus baris dari dataArray dan tabel
        var indexesToRemove: [Int] = []
        for (index, data) in dataArray.enumerated() {
            if siswaIDsToDelete.contains(data.siswaID) {
                indexesToRemove.append(index)
            }
        }

        table.beginUpdates()
        for index in indexesToRemove.reversed() {
            table.removeRows(at: IndexSet([index]), withAnimation: .slideDown)
        }
        table.endUpdates()

        // Cek apakah ada baris tersisa
        if table.numberOfRows > 0 {
            // Jika ada baris tersisa, pilih baris terakhir
            let rowToSelect = min(table.numberOfRows - 1, selectedIndexes.min() ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect), byExtendingSelection: false)
        } else {
            // Jika tidak ada baris tersisa, batalkan seleksi
            table.deselectAll(nil)
        }

        // Kirim notifikasi untuk pembaruan detailsiswa setelah baris dihapus
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": deletedSiswaIDs, "naikKelas": true])
        let userInfo: [String: Any] = [
            "tableType": tableType,
            "siswaIDs": deletedSiswaIDs,
        ]
        NotificationCenter.default.post(name: .naikKelas, object: self, userInfo: userInfo)
        pastedKelasID = pastedKelasID.map { arrayOfIDs in
            arrayOfIDs.filter { !deletedKelasIDs.contains($0) }
        }
        // Hapus array kosong
        pastedKelasID.removeAll { $0.isEmpty }
        updateUndoRedo(self)
    }

    /// Fungsi ini menangani notifikasi ketika siswa naik kelas.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Notifikasi yang diterima.
    @objc func handleSiswaNaik(_ notification: Notification) {
        // Pastikan userInfo berisi siswaIDs dan tableType yang valid
        guard let userInfo = notification.userInfo,
              let siswaIDs = userInfo["siswaIDs"] as? [Int64],
              let notifTableType = userInfo["tableType"] as? TableType
        else {
            return
        }
        switch notifTableType {
        case .kelas1:
            table1.beginUpdates()
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas1Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table1.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
            table1.endUpdates()
        case .kelas2:
            table2.beginUpdates()
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas2Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table2.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
            table2.endUpdates()
        case .kelas3:
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas3Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table3.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
        case .kelas4:
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas4Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table4.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
        case .kelas5:
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas5Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table5.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
        case .kelas6:
            for id in siswaIDs {
                let matchingIndexes = viewModel.kelas6Model.enumerated().compactMap { index, element -> Int? in
                    return element.siswaID == id ? index : nil
                }
                for index in matchingIndexes.reversed() {
                    viewModel.removeData(index: index, tableType: notifTableType)
                    table6.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }
            }
        }
    }

    /// Fungsi ini menangani aksi hapus menu untuk menghapus data siswa dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType),
              let _ = SingletonData.dbTable(forTableType: tableType) else { return }

        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes

        var uniqueSelectedStudentNames = Set<String>()
        var uniqueSelectedMapel = Set<String>()

        // Mengisi Set dengan nama siswa dari indeks terpilih
        for index in selectedIndexes {
            uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
            uniqueSelectedMapel.insert(viewModel.kelasModelForTable(tableType)[index].mapel)
        }
        var siswaTerpilih = ""
        var mapelTerpilih = ""
        var namasiswa = ""
        var mapel = ""
        if selectedRow >= 0 {
            namasiswa = viewModel.kelasModelForTable(tableType)[selectedRow].namasiswa
            mapel = viewModel.kelasModelForTable(tableType)[selectedRow].mapel
        }
        siswaTerpilih.insert(contentsOf: namasiswa, at: siswaTerpilih.startIndex)
        mapelTerpilih.insert(contentsOf: mapel, at: mapelTerpilih.startIndex)
        // Menggabungkan Set menjadi satu string dengan koma
        let selectedStudentNamesString = uniqueSelectedStudentNames.sorted().joined(separator: ", ")
        let selectedMapelString = uniqueSelectedMapel.sorted().joined(separator: ", ")
        let alert = NSAlert()

        // Cek apakah baris yang diklik adalah bagian dari baris yang dipilih
        if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert.messageText = "Apakah anda yakin akan menghapus data dari \"\(selectedStudentNamesString)\"?"
            alert.informativeText = "\"\(selectedMapelString)\" juga akan dihapus di informasi siswa \(selectedStudentNamesString)."
        } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert.messageText = "Apakah anda yakin akan menghapus data dari \"\(siswaTerpilih)\"?"
            alert.informativeText = "\"\(mapelTerpilih)\" juga akan dihapus di informasi siswa \(siswaTerpilih)."
        } else {
            alert.messageText = "Apakah anda yakin akan menghapus data dari \"\(selectedStudentNamesString)\"?"
            alert.informativeText = "\"\(selectedMapelString)\" akan dihapus di informasi siswa \(selectedStudentNamesString)."
        }
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let userDefaults = UserDefaults.standard
        let suppressAlert = userDefaults.bool(forKey: "hapusKelasAktifAlert")
        alert.showsSuppressionButton = true
        guard !suppressAlert else {
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
            return
        }
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "hapusKelasAktifAlert")
            }
            // Jika clickedRow ada di dalam selectedIndexes, panggil fungsi hapusPilih
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /// Fungsi ini menangani aksi hapus untuk menghapus data siswa yang diklik di tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    /// - clickedRow: Baris yang diklik di tabel.
    func hapusKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        deleteRedoArray(self)
        // Simpan data sebelum dihapus ke dalam deletedDataArray
        let deletedData = dataArray[clickedRow]
        SingletonData.deletedDataArray.append((table: currentClassTable, data: [deletedData]))
        SingletonData.deletedKelasAndSiswaIDs.append([(kelasID: deletedData.kelasID, siswaID: deletedData.siswaID)])
        table.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideDown)
        if clickedRow == table.numberOfRows {
            table.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            table.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        viewModel.removeData(index: clickedRow, tableType: tableType)

        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        updateUndoRedo(self)
        // NotificationCenter.default.post(name: .hapusDataKelas, object: self)
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": deletedData.kelasID])
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": [deletedData.kelasID]])
    }

    /// Fungsi ini menangani aksi hapus untuk menghapus data siswa yang dipilih di tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang sedang aktif.
    /// - table: Tabel yang sedang aktif.
    /// - selectedIndexes: Baris yang dipilih di tabel.
    func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)

        // Bersihkan array kelasID
        deleteRedoArray(self)

        // Tampung semua data yang akan dihapus ke dalam deletedDataArray di luar loop
        var selectedDataToDelete: [KelasModels] = []
        var deletedKelasIDs: [Int64] = [] // Tambahkan array untuk menyimpan kelasID yang dihapus
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []

        // Variabel untuk menyimpan indeks baris yang akan dipilih setelah penghapusan
        var rowToSelect: Int?

        for selectedRow in selectedIndexes.reversed() {
            let deletedData = dataArray[selectedRow]
            selectedDataToDelete.append(deletedData)
            deletedKelasIDs.append(deletedData.kelasID)
            deletedKelasAndSiswaIDs.append((kelasID: deletedData.kelasID, siswaID: deletedData.siswaID))
            // Hapus data dari model berdasarkan tableType
            viewModel.removeData(index: selectedRow, tableType: tableType)
        }

        // Setelah loop, tambahkan semua data yang akan dihapus ke dalam deletedDataArray
        SingletonData.deletedDataArray.append((table: currentClassTable, data: selectedDataToDelete))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Register undo action
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        updateUndoRedo(self)

        // Mulai dan akhiri update tabel untuk menghapus baris terpilih
        table.beginUpdates()
        table.removeRows(at: selectedIndexes, withAnimation: .slideUp)

        // Tentukan baris yang akan dipilih setelah penghapusan
        let totalRowsAfterDeletion = table.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            rowToSelect = min(totalRowsAfterDeletion - 1, selectedIndexes.first ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect!), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            table.deselectAll(nil)
        }
        table.endUpdates()
        // Post notifikasi untuk pembaruan tampilan
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": deletedKelasIDs])
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex

        // Notifikasi untuk pembaruan di semua Window kelasVC
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": deletedKelasIDs])
    }

    /// Fungsi ini menghapus data yang telah dihapus sebelumnya dari undo stack dan redo stack.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    func undoHapus(tableType: TableType, table: NSTableView) {
        KelasModels.currentSortDescriptor = table.sortDescriptors.first
        guard let sortDescriptor = KelasModels.currentSortDescriptor,
              let selectedTabViewItem = tabView.selectedTabViewItem,
              !SingletonData.deletedDataArray.isEmpty
        else {
            return
        }
        // Buat array baru untuk menyimpan semua id yang dihasilkan
        let semuaElemen: [KelasModels] = SingletonData.deletedDataArray.last?.data ?? []
        let deletedDatas = SingletonData.deletedDataArray.removeLast()
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        SingletonData.dataArray.removeAll()
        operationQueue.maxConcurrentOperationCount = 1
        activateTable(table)
        if deletedDatas.data.count >= 100 {
            viewModel.restoreDeletedDataWithProgress(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                operationQueue: operationQueue,
                window: view.window!,
                onlyDataKelasAktif: false,
                kelasID: &kelasID
            )
        } else {
            viewModel.restoreDeletedDataDirectly(
                deletedData: deletedDatas,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                onlyDataKelasAktif: false,
                kelasID: &kelasID
            )
        }

        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": SingletonData.dataArray])
        DispatchQueue.main.async {
            if let currentStackData = SingletonData.undoStack[tableType.stringValue] {
                var hasFilteredData = false

                for (stackIndex, stackModels) in currentStackData.enumerated() {
                    let filteredModels = stackModels.filter { model in
                        let shouldKeep = !semuaElemen.contains { $0.siswaID == model.siswaID }

                        return shouldKeep
                    }

                    SingletonData.undoStack[tableType.stringValue]?[stackIndex] = filteredModels

                    if filteredModels.count != stackModels.count {
                        hasFilteredData = true
                    }
                }

                // Menampilkan alert jika ada data yang terfilter
                if hasFilteredData {
                    let alert = NSAlert()
                    alert.icon = NSImage(named: "NSCaution")
                    alert.messageText = "Inkonsistensi data"
                    alert.informativeText = "Seluruh data \(self.createLabelForActiveTable()) dimuat ulang karena terdapat inkonsistensi data:\nSiswa tidak di Kelas Aktif \(self.createLabelForActiveTable())"
                    alert.addButton(withTitle: "OK")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        if !SingletonData.siswaNaikId.isEmpty {
                            SingletonData.siswaNaikId.removeLast()
                        }
                        self.muatUlang(self)
                    }
                }
            }
        }

        if var kelasUndoStack = SingletonData.undoStack[tableType.stringValue] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[tableType.stringValue] = kelasUndoStack
        }

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.updateUndoRedo(self)
        }
    }

    /// Fungsi ini menangani aksi redo untuk menghapus data siswa yang telah dihapus sebelumnya.
    /// - Parameters:
    /// - table: Tabel yang sedang aktif.
    /// - tableType: Tipe tabel yang sedang aktif.
    func redoHapus(table: NSTableView, tableType: TableType) {
        guard !SingletonData.deletedKelasID.isEmpty,
              let lastDeletedTable = SingletonData.dbTable(forTableType: tableType)
        else {
            print("Tidak ada data yang bisa di-Redo untuk \(tableType.stringValue)")
            return
        }
        activateTable(table)
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = SingletonData.deletedKelasID.last!.kelasID
        SingletonData.deletedKelasID.removeLast()
        // Tentukan model target berdasarkan tableType
        switch tableType {
        case .kelas1:
            targetModel = viewModel.kelas1Model
        case .kelas2:
            targetModel = viewModel.kelas2Model
        case .kelas3:
            targetModel = viewModel.kelas3Model
        case .kelas4:
            targetModel = viewModel.kelas4Model
        case .kelas5:
            targetModel = viewModel.kelas5Model
        case .kelas6:
            targetModel = viewModel.kelas6Model
        }

        // Panggil ViewModel untuk menghapus data
        guard let result = viewModel.removeData(withIDs: allIDs, fromModel: &targetModel, forTableType: tableType) else {
            return
        }

        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result
        table.beginUpdates()
        // Hapus baris-baris yang sesuai dari targetModel dan NSTableView
        for index in indexesToRemove {
            // Hapus baris dari NSTableView
            table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            if index == table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: table.numberOfRows - 1), byExtendingSelection: false)
                table.scrollRowToVisible(table.numberOfRows - 1)
            } else {
                table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                table.scrollRowToVisible(index)
            }
        }
        table.endUpdates()
        // Tambahkan data yang dihapus ke dalam deletedDataArray
        SingletonData.deletedDataArray.append((table: lastDeletedTable, data: dataDihapus))

        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Daftarkan undo untuk aksi redo yang dilakukan
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        if !kelasID.isEmpty {
            kelasID.removeLast()
        }
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs])
        // Perbarui tampilan setelah penghapusan berhasil dilakukan
        updateUndoRedo(self)
        selectSidebar(table)
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs])
    }

    /// Fungsi ini menangani notifikasi ketika siswa dihapus dari kelas.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Notifikasi yang diterima.
    @objc func handleSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["deletedStudentIDs"] as? [Int64],
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let isDeleted = userInfo["isDeleted"] as? Bool
        {
            var modifiableModel: [KelasModels] = []
            TableType.fromString(kelasSekarang) { kelas in
                modifiableModel = viewModel.getModel(for: kelas)
                guard let table = getTableView(for: kelas.rawValue) else { return }
                deleteRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang, isDeleted: isDeleted)
                _ = viewModel.setModel(kelas, model: modifiableModel)
            }
            DispatchQueue.main.async {
                self.updateUndoRedo(self)
            }
        }
    }

    /// Fungsi ini menghapus baris yang telah ditentukan ``handleSiswaDihapusNotification(_:)``
    /// dari model dan tabel.
    func deleteRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String, isDeleted: Bool) {
        guard tableView.numberOfRows != 0 else { return }

        var indexesToDelete = IndexSet()

        // Simpan state model sebelum penghapusan untuk undo
        if SingletonData.undoStack[kelasSekarang] == nil {
            SingletonData.undoStack[kelasSekarang] = []
        }

        if isDeleted == true {
            // Simpan data yang akan dihapus ke dalam undo stack
            let itemsToUndo = model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels }
            SingletonData.undoStack[kelasSekarang]?.append(itemsToUndo)
        }

        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if deletedIDs.contains(item.siswaID) {
                indexesToDelete.insert(index)
            }
        }

        // Hapus data dari model
        for index in indexesToDelete.sorted(by: >) {
            // Panggil fungsi removeData untuk setiap kelas
            TableType.fromString(kelasSekarang) { kelas in
                viewModel.removeData(index: index, tableType: kelas)
            }
        }

        model.removeAll { item in
            // Cek apakah siswaID ada di deletedIDs
            deletedIDs.contains(item.siswaID)
        }

        // Hapus baris dari NSTableView
        OperationQueue.main.addOperation {
            tableView.beginUpdates()
            tableView.removeRows(at: indexesToDelete, withAnimation: [])
            tableView.endUpdates()
        }
        if var kelasUndoStack = SingletonData.undoStack[kelasSekarang] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[kelasSekarang] = kelasUndoStack
        }
    }

    /// Fungsi ini menangani ketika siswa ditambahkan kembali setelah dihapus.
    ///
    /// Pengirim notifikasi ini adalah ``SiswaViewController``.
    /// - Parameter notification: Objek `Notification` pemicu aksi ini.
    @objc func handleUndoSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let kelasSekarang = userInfo["kelasSekarang"] as? String
        {
            TableType.fromString(kelasSekarang) { [weak self] kelas in
                guard let self, let tableView = getTableView(for: kelas.rawValue) else { return }
                let model = viewModel.getModel(for: kelas)
                var modifiableModel: [KelasModels] = model
                if !(self.isDataLoaded[tableView] ?? false) {
                    guard let undoStack = SingletonData.undoStack[kelasSekarang], !undoStack.isEmpty else { return }
                    SingletonData.undoStack[kelasSekarang]?.removeLast()
                    _ = viewModel.setModel(kelas, model: modifiableModel)
                } else {
                    self.undoDeleteRows(from: &modifiableModel, tableView: tableView, kelasSekarang: kelasSekarang)
                }
            }
            DispatchQueue.main.async {
                self.updateUndoRedo(self)
            }
        }
    }

    /// Fungsi ini mengembalikan baris yang telah dihapus sebelumnya ke dalam tabel.
    /// - Parameters:
    ///  - model: Model yang berisi data kelas.
    /// - tableView: Tabel yang akan diperbarui.
    /// - kelasSekarang: Nama kelas yang akan diperbarui.
    func undoDeleteRows(from model: inout [KelasModels], tableView: NSTableView, kelasSekarang: String) {
        guard var undoStackForKelas = SingletonData.undoStack[kelasSekarang], !undoStackForKelas.isEmpty, let sortDescriptor = KelasModels.currentSortDescriptor else { return }
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        SingletonData.undoStack[kelasSekarang] = undoStackForKelas

        tableView.beginUpdates()
        for deletedData in previousState.sorted() {
            // let kelasID = deletedData.kelasID
            TableType.fromString(kelasSekarang) { kelas in
                // Panggil fungsi insert untuk setiap kelas
                guard let insertIndex = viewModel.insertData(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: [])
            }
        }
        tableView.endUpdates()
    }

    /// Fungsi ini menangani aksi hapus data menu untuk menghapus data siswa dari tabel yang sedang aktif.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func hapusDataMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType),
              let _ = SingletonData.dbTable(forTableType: tableType)
        else {
            return
        }

        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes

        var uniqueSelectedStudentNames = Set<String>()
        var uniqueSelectedMapel = Set<String>()

        // Mengisi Set dengan nama siswa dari indeks terpilih
        for index in selectedIndexes {
            uniqueSelectedStudentNames.insert(viewModel.kelasModelForTable(tableType)[index].namasiswa)
            uniqueSelectedMapel.insert(viewModel.kelasModelForTable(tableType)[index].mapel)
        }

        var siswaTerpilih = ""
        var mapelTerpilih = ""
        var namasiswa = ""
        var mapel = ""
        if selectedRow >= 0 {
            namasiswa = viewModel.kelasModelForTable(tableType)[selectedRow].namasiswa
            mapel = viewModel.kelasModelForTable(tableType)[selectedRow].mapel
        }

        siswaTerpilih.insert(contentsOf: namasiswa, at: siswaTerpilih.startIndex)
        mapelTerpilih.insert(contentsOf: mapel, at: mapelTerpilih.startIndex)

        // Menggabungkan Set menjadi satu string dengan koma
        let selectedStudentNamesString = uniqueSelectedStudentNames.sorted().joined(separator: ", ")
        let selectedMapelString = uniqueSelectedMapel.sorted().joined(separator: ", ")

        var alert: NSAlert?
        let kelasAktif = createLabelForActiveTable()
        // Cek apakah baris yang diklik adalah bagian dari baris yang dipilih
        if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi penghapusan catatan \"\(selectedStudentNamesString)\" di Kelas Aktif \"\(kelasAktif)\""
            alert?.informativeText = "\"\(selectedMapelString)\" akan dihapus di Kelas Aktif ini dan disimpan di informasi siswa."
        } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi penghapusan catatan \"\(siswaTerpilih)\" di Kelas Aktif \"\(kelasAktif)\""
            alert?.informativeText = "\"\(mapelTerpilih)\" akan dihapus di Kelas Aktif ini dan disimpan di informasi siswa."
        } else {
            alert = NSAlert()
            alert?.messageText = "Konfirmasi penghapusan catatan \"\(selectedStudentNamesString)\" di Kelas Aktif \"\(kelasAktif)\""
            alert?.informativeText = "\"\(selectedMapelString)\" akan dihapus di Kelas Aktif ini dan disimpan di informasi siswa."
        }

        alert?.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert?.addButton(withTitle: "OK")
        alert?.addButton(withTitle: "Batalkan")

        guard let unwrappedAlert = alert else {
            return
        }
        let userDefaults = UserDefaults.standard
        let suppressAlert = userDefaults.bool(forKey: "hapusDataKelasAktifAlert")
        alert?.showsSuppressionButton = true
        guard !suppressAlert else {
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusDataPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                // Jika clickedRow bukan bagian dari selectedRows, panggil fungsi hapusDataKlik
                hapusDataKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusDataPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
            return
        }
        let response = unwrappedAlert.runModal()

        if response == .alertFirstButtonReturn {
            if alert?.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "hapusDataKelasAktifAlert")
            }
            // Jika clickedRow ada di dalam selectedIndexes, panggil fungsi hapusDataPilih
            if selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                hapusDataPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            } else if !selectedIndexes.contains(selectedRow), selectedRow >= 0 {
                // Jika clickedRow bukan bagian dari selectedRows, panggil fungsi hapusDataKlik
                hapusDataKlik(tableType: tableType, table: table, clickedRow: selectedRow)
            } else {
                hapusDataPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /// Fungsi ini menghapus data yang diklik di tabel berdasarkan tipe tabel yang diberikan.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    ///   - clickedRow: Baris yang diklik di tabel.
    func hapusDataKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)
        // Simpan data yang dihapus untuk kemungkinan undo
        let deletedData = [dataArray[clickedRow]]
        SingletonData.deletedDataKelas.append((table: currentClassTable, data: deletedData))
        deleteRedoArray(self)
        viewModel.removeData(index: clickedRow, tableType: tableType)
        table.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideDown)
        if clickedRow == table.numberOfRows {
            table.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            table.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        // Daftarkan undo
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapusData(tableType: tableType, table: table)
        }
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": [dataArray[clickedRow].kelasID], "hapusData": true])
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": [dataArray[clickedRow].kelasID]])
    }

    /// Fungsi ini menghapus data yang dipilih di tabel berdasarkan tipe tabel yang diberikan.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    ///   - selectedIndexes: Baris yang dipilih di tabel.
    func hapusDataPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        // Pastikan tabel yang sesuai dengan tipe tabel yang diberikan ada
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        let dataArray = viewModel.kelasModelForTable(tableType)
        var rowToSelect: Int?
        // Simpan data yang dihapus untuk kemungkinan undo
        var selectedDataToDelete: [KelasModels] = []
        deleteRedoArray(self)
        var deletedKelasIDs: [Int64] = []
        // Hapus data dari tabel dan database
        for selectedRow in selectedIndexes.reversed() {
            // Simpan data yang akan dihapus ke dalam array
            let deletedData = dataArray[selectedRow]
            selectedDataToDelete.append(deletedData)
            deletedKelasIDs.append(deletedData.kelasID)
            // Hapus data dari model berdasarkan tableType
            viewModel.removeData(index: selectedRow, tableType: tableType)
        }
        table.beginUpdates()
        table.removeRows(at: selectedIndexes, withAnimation: .slideDown)
        let totalRowsAfterDeletion = table.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            rowToSelect = min(totalRowsAfterDeletion - 1, selectedIndexes.first ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect!), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            table.deselectAll(nil)
        }
        table.endUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
            SingletonData.deletedDataKelas.append((table: currentClassTable, data: selectedDataToDelete))

            myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
                self?.undoHapusData(tableType: tableType, table: table)
            }
            updateUndoRedo(self)
        }
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": deletedKelasIDs, "hapusData": true])
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": deletedKelasIDs])
    }

    /// Fungsi ini mengembalikan data yang telah dihapus sebelumnya ke dalam tabel.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang akan diperbarui.
    ///   - table: Table yang akan diperbarui
    func undoHapusData(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = KelasModels.currentSortDescriptor,
              let selectedTabViewItem = tabView.selectedTabViewItem
        else {
            return
        }
        activateTable(table)
        SingletonData.dataArray.removeAll()
        let deletedData = SingletonData.deletedDataKelas.removeLast()
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        SingletonData.dataArray.removeAll()
        operationQueue.maxConcurrentOperationCount = 1
        if deletedData.data.count >= 100 {
            viewModel.restoreDeletedDataWithProgress(
                deletedData: deletedData,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager,
                operationQueue: operationQueue,
                window: view.window!, onlyDataKelasAktif: true,
                kelasID: &kelasID
            )
        } else {
            viewModel.restoreDeletedDataDirectly(
                deletedData: deletedData,
                tableType: tableType,
                sortDescriptor: sortDescriptor,
                table: table,
                viewController: self,
                undoManager: myUndoManager, onlyDataKelasAktif: true,
                kelasID: &kelasID
            )
        }
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": SingletonData.dataArray])
        DispatchQueue.main.async {
            if let currentStackData = SingletonData.undoStack[tableType.stringValue] {
                var hasFilteredData = false

                for (stackIndex, stackModels) in currentStackData.enumerated() {
                    // Debug print untuk melihat data sebelum filtering

                    let filteredModels = stackModels.filter { model in
                        let shouldKeep = !deletedData.data.contains { $0.siswaID == model.siswaID }

                        return shouldKeep
                    }

                    // Debug print untuk melihat hasil filtering

                    SingletonData.undoStack[tableType.stringValue]?[stackIndex] = filteredModels

                    if filteredModels.count != stackModels.count {
                        hasFilteredData = true
                    }
                }

                // Menampilkan alert jika ada data yang terfilter
                if hasFilteredData {
                    let alert = NSAlert()
                    alert.icon = NSImage(named: "NSCaution")
                    alert.messageText = "Inkonsistensi data"
                    alert.informativeText = "Seluruh data \(self.createLabelForActiveTable()) dimuat ulang karena terdapat inkonsistensi data:\nSiswa tidak di Kelas Aktif \(self.createLabelForActiveTable())"
                    alert.addButton(withTitle: "OK")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        self.muatUlang(self)
                    }
                }
            }
        }

        if var kelasUndoStack = SingletonData.undoStack[tableType.stringValue] {
            // Hapus array kosong
            kelasUndoStack.removeAll(where: { $0.isEmpty })
            SingletonData.undoStack[tableType.stringValue] = kelasUndoStack
        }
        SingletonData.dataArray.removeAll()
        selectSidebar(table)
    }

    /// Fungsi ini menangani aksi redo untuk menghapus data kelas.
    /// - Parameters:
    /// - tableType: Tipe tabel yang akan diperbarui.
    /// - table: Tabel yang akan diperbarui.
    func redoHapusData(tableType: TableType, table: NSTableView) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        activateTable(table)
        // Cari dataArray yang sesuai dengan tableType
        var dataArrayToUpdate: [KelasModels] = []

        switch tableType {
        case .kelas1:
            dataArrayToUpdate = viewModel.kelas1Model
        case .kelas2:
            dataArrayToUpdate = viewModel.kelas2Model
        case .kelas3:
            dataArrayToUpdate = viewModel.kelas3Model
        case .kelas4:
            dataArrayToUpdate = viewModel.kelas4Model
        case .kelas5:
            dataArrayToUpdate = viewModel.kelas5Model
        case .kelas6:
            dataArrayToUpdate = viewModel.kelas6Model
        }
        let id = kelasID.removeLast()
        var dataDihapus: [KelasModels] = []
        var indexesToRemove: [Int] = []
        // Loop through each deleted row index
        for (_, deletedRowIndex) in id.enumerated().reversed() {
            // Hapus data dari dataArrayToUpdate
            if let index = dataArrayToUpdate.firstIndex(where: { $0.kelasID == deletedRowIndex }) {
                dataDihapus.append(dataArrayToUpdate[index])
                viewModel.removeData(index: index, tableType: tableType)
                indexesToRemove.append(index)
            }
        }
        table.beginUpdates()
        for index in indexesToRemove {
            // Hapus baris dari NSTableView
            table.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            if index == table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: table.numberOfRows - 1), byExtendingSelection: false)
                table.scrollRowToVisible(table.numberOfRows - 1)
            } else {
                table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                table.scrollRowToVisible(index)
            }
        }
        table.endUpdates()
        SingletonData.deletedDataKelas.append((table: currentClassTable, data: dataDihapus))
        // Register undo action for the redo
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapusData(tableType: tableType, table: table)
        }
        // Update the undo and redo buttons
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": id, "hapusData": true])
        selectSidebar(table)
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": id])
    }

    /// Fungsi ini menangani aksi edit mapel dari toolbar.
    /// - Parameter sender: Objek pemicu
    @objc func editMapelToolbar(_ sender: Any) {
        guard let table = activeTable(), table.selectedRow != -1 else { return }
        let tipeTable = tableTypeForTable(table)
        let selectedRow = table.selectedRowIndexes
        let modelData = viewModel.kelasModelForTable(tipeTable)
        var mapelData: [(String, String, TableType)] = []
        var processedMapels = Set<String>() // Set untuk melacak mapel yang sudah diproses

        for row in selectedRow {
            let mapel = modelData[row].mapel
            let namaguru = modelData[row].namaguru

            // Cek apakah mapel sudah diproses sebelumnya
            if !processedMapels.contains(mapel) {
                // Tambahkan mapel ke dalam Set
                processedMapels.insert(mapel)

                // Tambahkan data ke mapelData dengan mapel sebagai Set
                mapelData.append((mapel, namaguru, tipeTable))
            }
        }
        mapelData.sort { $0.0 < $1.0 } // Mengurutkan berdasarkan elemen pertama yaitu mapel

        editMapels(tableType: tipeTable, table: table, data: mapelData)
    }

    /// Fungsi ini menangani aksi edit mapel dari menu konteks.
    /// - Parameter sender:
    @objc func editMapelMenu(_ sender: NSMenuItem) {
        guard let (table, tipeTable) = sender.representedObject as? (NSTableView, TableType) else { return }
        let selectedRow = table.selectedRowIndexes
        let clickedRow = table.clickedRow
        let modelData = viewModel.kelasModelForTable(tipeTable)
        var mapelData: [(String, String, TableType)] = []
        var processedMapels = Set<String>() // Set untuk melacak mapel yang sudah diproses

        for row in selectedRow {
            let mapel = modelData[row].mapel
            let namaguru = modelData[row].namaguru

            // Cek apakah mapel sudah diproses sebelumnya
            if !processedMapels.contains(mapel) {
                // Tambahkan mapel ke dalam Set
                processedMapels.insert(mapel)
                // Tambahkan data ke mapelData dengan mapel sebagai Set
                mapelData.append((mapel, namaguru, tipeTable))
            }
        }
        mapelData.sort { $0.0 < $1.0 } // Mengurutkan berdasarkan elemen pertama yaitu mapel
        if selectedRow.contains(clickedRow), table.clickedRow != -1 {
            editMapels(tableType: tipeTable, table: table, data: mapelData)
        } else if !selectedRow.contains(clickedRow), table.clickedRow != -1 {
            table.selectRowIndexes(IndexSet([clickedRow]), byExtendingSelection: false)
            editMapel(tableType: tipeTable, table: table, data: [(modelData[clickedRow].mapel, modelData[clickedRow].namaguru, tipeTable)])
        } else {
            editMapels(tableType: tipeTable, table: table, data: mapelData)
        }
    }

    /// Fungsi ini mengedit mapel yang dipilih di tabel berdasarkan tipe tabel yang diberikan.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang sedang aktif.
    ///   - table: Tabel yang sedang aktif.
    ///   - data: Data mapel yang akan diedit, berupa tuple yang berisi nama mapel, nama guru, dan tipe tabel.
    func editMapels(tableType: TableType, table: NSTableView, data: [(String, String, TableType)]) {
        var mapelData = [String]()
        var cleanedMapelData = [String]()
        let dispathcGroup = DispatchGroup()
        dispathcGroup.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            mapelData = data.map { $0.0.trimmingCharacters(in: .whitespacesAndNewlines) }
            cleanedMapelData = mapelData.filter { !$0.isEmpty }
            dispathcGroup.leave()
        }

        dispathcGroup.notify(queue: .main) {
            let editMapelController = EditMapel(nibName: "EditMapel", bundle: nil)
            if cleanedMapelData.isEmpty {
                let alert = NSAlert()
                alert.icon = NSImage(named: "No Data Bordered")
                alert.messageText = "Mapel tidak valid"
                alert.informativeText = "Nama mata pelajaran yang valid tidak ditemukan. Tidak dapat mengedit mapel yang kosong."
                alert.runModal()
                return
            }
            editMapelController.loadView()
            // Set data mapel ke EditMapel
            editMapelController.loadMapelData(mapelData: data)

            // Tampilkan sebagai sheet
            self.presentAsSheet(editMapelController)
        }
    }

    /// Fungsi ini mengedit mapel yang dipilih di tabel berdasarkan tipe tabel yang diberikan.
    /// - Parameters:
    ///  - tableType: Tipe tabel yang sedang aktif.
    ///  - table: Tabel yang sedang aktif.
    ///  - data: Data mapel yang akan diedit, berupa tuple yang berisi nama mapel, nama guru, dan tipe tabel.
    func editMapel(tableType: TableType, table: NSTableView, data: [(String, String, TableType)]) {
        let editMapelController = EditMapel(nibName: "EditMapel", bundle: nil)

        editMapelController.loadView()
        editMapelController.loadMapelData(mapelData: data)

        // Tampilkan sebagai sheet
        presentAsSheet(editMapelController)
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
        let nama = NSSortDescriptor(key: "namasiswa", ascending: false)
        let mapel = NSSortDescriptor(key: "mapel", ascending: true)
        let nilai = NSSortDescriptor(key: "nilai", ascending: true)
        let semester = NSSortDescriptor(key: "semester", ascending: true)
        let namaguru = NSSortDescriptor(key: "namaguru", ascending: true)
        let tgl = NSSortDescriptor(key: "tgl", ascending: true)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("namasiswa"): nama,
            NSUserInterfaceItemIdentifier("mapel"): mapel,
            NSUserInterfaceItemIdentifier("nilai"): nilai,
            NSUserInterfaceItemIdentifier("semester"): semester,
            NSUserInterfaceItemIdentifier("namaguru"): namaguru,
            NSUserInterfaceItemIdentifier("tgl"): tgl,
        ]
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
                selectedSiswa.append(dbController.getSiswa(idValue: data[rowIndex].siswaID))
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

    /// Fungsi untuk menjalankan undo.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func urung(_ sender: Any) {
        if myUndoManager.canUndo {
            myUndoManager.undo()
        }
    }

    /// Fungsi untuk menjalankan redo.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func ulang(_ sender: Any) {
        if myUndoManager.canRedo {
            myUndoManager.redo()
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_ sender: Any?) {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
        else {
            return
        }

        let canUndo = !undoArray.isEmpty || !SingletonData.deletedDataArray.isEmpty || !pastedKelasID.isEmpty || !SingletonData.deletedDataKelas.isEmpty
        let canRedo = !redoArray.isEmpty || !kelasID.isEmpty || !SingletonData.pastedData.isEmpty || !SingletonData.deletedKelasID.isEmpty
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

    deinit {
        searchItem?.cancel()
        searchItem = nil
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .naikKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .siswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateTableNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .findDeletedData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editDataSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editButtonClicked, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.removeObserver(self, name: .addDetil, object: nil)
        NotificationCenter.default.removeObserver(self, name: .hapusDataSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: .popupDismissedKelas, object: nil)
        operationQueue.cancelAllOperations()
    }
}

extension KelasVC {
    /// Fungsi ini menangani aksi undo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func undoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)).firstIndex(where: { $0.kelasID == originalModel.kelasId }),
              let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == originalModel.columnIdentifier }),
              let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView,
              columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count else { return }

        // Lakukan pembaruan model dan database dengan nilai lama
        viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

        // Daftarkan aksi redo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.redoAction(originalModel: originalModel)
        })

        // Hapus nilai lama dari array undo
        undoArray.removeAll(where: { $0 == originalModel })

        // Mendapatkan nilai status dari originalModel
        let newString = originalModel.oldValue
        cellView.textField?.stringValue = newString
        if originalModel.columnIdentifier == "nilai" {
            let numericValue = Int(newString) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }

        originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
        originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)

        // Simpan nilai lama ke dalam array redo
        redoArray.append(originalModel)
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": originalModel.tableType as Any, "editedKelasIDs": originalModel.kelasId, "siswaID": viewModel.kelasModelForTable(originalModel.tableType)[rowIndexToUpdate].siswaID, "columnIdentifier": originalModel.columnIdentifier, "dataBaru": newString])
    }

    /// Fungsi ini menangani aksi redo untuk mengembalikan nilai yang telah diubah pada tabel kelas.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    func redoAction(originalModel: OriginalData) {
        activateTable(originalModel.tableView)
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)).firstIndex(where: { $0.kelasID == originalModel.kelasId }),
              let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == originalModel.columnIdentifier }),
              let cellView = originalModel.tableView.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView,
              columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count
        else {
            return
        }

        // Lakukan pembaruan model dan database dengan nilai baru
        viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.newValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(originalModel.tableView)), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.undoAction(originalModel: originalModel)
        })

        // Hapus nilai lama dari array redo
        redoArray.removeAll(where: { $0 == originalModel })

        // Mendapatkan nilai status dari originalModel
        let newString = originalModel.newValue
        cellView.textField?.stringValue = newString
        if originalModel.columnIdentifier == "nilai" {
            let numericValue = Int(newString) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }

        originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
        originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)

        // Simpan nilai baru ke dalam array undo
        undoArray.append(originalModel)
        updateUndoRedo(self)
        NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": originalModel.tableType as Any, "editedKelasIDs": originalModel.kelasId, "siswaID": viewModel.kelasModelForTable(originalModel.tableType)[rowIndexToUpdate].siswaID, "columnIdentifier": originalModel.columnIdentifier, "dataBaru": newString])
    }

    /// Fungsi ini menangani pembaruan data siswa yang diedit di tabel kelas
    /// dari ``DetailSiswaController``.
    /// - Parameter notification:
    @objc func updateEditedDetilSiswa(_ notification: Notification) {
        var table: EditableTableView!
        guard let userInfo = notification.userInfo as? [String: Any],
              let columnIdentifier = userInfo["columnIdentifier"] as? String,
              let activeTable = userInfo["tableView"] as? String,
              let newValue = userInfo["newValue"] as? String,
              let kelasId = userInfo["kelasId"] as? Int64
        else {
            return
        }
        switch activeTable {
        case "table1": table = table1
        case "table2": table = table2
        case "table3": table = table3
        case "table4": table = table4
        case "table5": table = table5
        case "table6": table = table6
        default: break
        }
        guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(table)).firstIndex(where: { $0.kelasID == kelasId }) else { return }
        guard let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else { return }
        guard let cellView = table.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView else { return }
        // Lakukan pembaruan model dan database dengan nilai baru
        viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(table)), tableView: table, kelasId: kelasId)
        if columnIdentifier == "nilai" {
            let numericValue = Int(newValue) ?? 0
            cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
        }
        cellView.textField?.stringValue = newValue
        table.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
    }

    /// Menangani notifikasi dari .findDeletedData
    /// untuk menghapus row di tabel.
    /// - Parameter notification: Objek `Notification` pemicu.
    @objc func updateDeletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let kelasId = userInfo["ID"] as? [Int64],
              let index = userInfo["index"] as? Int,
              let table = getTableView(for: index)
        else {
            return
        }
        table.beginUpdates()
        for id in kelasId {
            guard let kelasIDIndex = viewModel.deleteNotif(index, id: id) else { continue }
            table.removeRows(at: IndexSet(integer: kelasIDIndex), withAnimation: .slideUp)
        }
        table.endUpdates()
    }

    /// Mengupdate menu item di Menu Bar ketik popover ditutup.
    @objc func handlePopupDismissed(_ sender: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            updateUndoRedo(self)
            NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
        }
    }

    /// Mengidentifikasi dan mengembalikan instance `EditableTableView` yang saat ini aktif (terlihat dan bagian dari hierarki tampilan).
    ///
    /// Fungsi ini memastikan bahwa pemeriksaan tabel aktif selalu dilakukan di **main thread**
    /// karena melibatkan interaksi dengan elemen UI. Jika dipanggil dari thread latar belakang,
    /// ia akan secara sinkron beralih ke main thread untuk melakukan pemeriksaan dan mengembalikan hasilnya.
    ///
    /// - Returns: `EditableTableView?` - Tabel yang teridentifikasi sebagai aktif, atau `nil` jika tidak ada
    ///            tabel yang ditemukan dalam hierarki tampilan (meskipun secara default akan mengembalikan `table1`
    ///            sebagai fallback di `checkActiveTable`).
    func activeTable() -> EditableTableView? {
        // Jalankan secara sinkron di main thread dan kembalikan hasilnya
        if Thread.isMainThread {
            checkActiveTable()
        } else {
            DispatchQueue.main.sync {
                checkActiveTable()
            }
        }
    }

    /// Memeriksa tabel `EditableTableView` mana yang saat ini merupakan turunan dari tampilan utama (`self.view`).
    ///
    /// Fungsi ini dirancang untuk beroperasi di main thread dan secara berurutan memeriksa setiap tabel
    /// (`table1` hingga `table6`) untuk menentukan tabel mana yang sedang ditampilkan dalam hierarki UI.
    /// Sebagai fallback, ia akan selalu mengembalikan `table1` jika tidak ada tabel lain yang ditemukan.
    ///
    /// - Returns: `EditableTableView?` - Tabel `EditableTableView` yang aktif. Secara default,
    ///            akan mengembalikan `table1` jika tidak ada tabel lain yang ditemukan aktif.
    func checkActiveTable() -> EditableTableView? {
        if table1.isDescendant(of: view) {
            return table1
        } else if table2.isDescendant(of: view) {
            return table2
        } else if table3.isDescendant(of: view) {
            return table3
        } else if table4.isDescendant(of: view) {
            return table4
        } else if table5.isDescendant(of: view) {
            return table5
        } else if table6.isDescendant(of: view) {
            return table6
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
        var updatedClass: Int?
        switch table {
        case table1: tabView.selectTabViewItem(at: 0); updatedClass = 15
        case table2: tabView.selectTabViewItem(at: 1); updatedClass = 16
        case table3: tabView.selectTabViewItem(at: 2); updatedClass = 17
        case table4: tabView.selectTabViewItem(at: 3); updatedClass = 18
        case table5: tabView.selectTabViewItem(at: 4); updatedClass = 19
        case table6: tabView.selectTabViewItem(at: 5); updatedClass = 20
        default:
            break
        }

        delegate?.didUpdateTable(updatedClass ?? 15)

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
        if table == table1 {
            return .kelas1
        } else if table == table2 {
            return .kelas2
        } else if table == table3 {
            return .kelas3
        } else if table == table4 {
            return .kelas4
        } else if table == table5 {
            return .kelas5
        } else if table == table6 {
            return .kelas6
        }
        return .kelas1 // Gantilah dengan nilai default yang sesuai jika perlu.
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

extension KelasVC: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let table = activeTable(),
              let tipeTabel = tableType(forTableView: table)
        else {
            return
        }
        if menu != toolbarMenu {
            updateTableMenu(table: table, tipeTabel: tipeTabel, menu: menu)
        } else {
            updateToolbarMenu(table: table, tipeTabel: tipeTabel, menu: menu)
        }
        view.window?.makeFirstResponder(table)
    }

    /**
     * @function updateNamaGuruNotification
     * @abstract Menangani notifikasi pembaruan nama guru, mengelola sinkronisasi antara UI dan database secara asinkron.
     * @discussion Fungsi ini dipicu oleh sebuah notifikasi yang berisi data pembaruan nama guru.
     * Ia melakukan validasi data, membaca informasi UI di main thread,
     * memproses pembaruan data dan interaksi database di background thread
     * untuk menjaga responsivitas UI, dan kemudian memperbarui UI kembali di main thread.
     * Fungsionalitas undo juga didukung dengan menyimpan data asli sebelum perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi informasi pembaruan.
     * Diharapkan `userInfo` dari notifikasi ini mengandung kunci `"mapelData"`
     * dengan nilai `[[String: Any]]` yang merinci pembaruan nama guru.
     *
     * @returns: void
     */
    @objc func updateNamaGuruNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let data = userInfo["mapelData"] as? [[String: Any]] else { return }
        var originalModel: [OriginalData] = []
        var selectRow: IndexSet = []
        var columnIndex = Int()
        var activeTable = NSTableView()
        var dataUIDibaca = false
        DispatchQueue.main.async { [unowned self] in
            guard !dataUIDibaca else { return }
            for mapelDict in data {
                guard let tipeTabel = mapelDict["tipeTabel"] as? TableType,
                      let tableView = getTableView(for: tipeTabel.rawValue) else { return }
                columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "namaguru"))
                activeTable = tableView
                dataUIDibaca = true
            }
        }
        // Simpan originalModel untuk undo dengan kelasId
        DispatchQueue.global(qos: .background).async { [unowned self] in
            for mapelDict in data {
                guard let mapel = mapelDict["mapel"] as? String,
                      let tipeTabel = mapelDict["tipeTabel"] as? TableType,
                      let guruBaru = mapelDict["guruBaru"] as? String,
                      let guruLama = mapelDict["guruLama"] as? String,
                      let tableView = getTableView(for: tipeTabel.rawValue),
                      let table = SingletonData.dbTable(forTableType: tipeTabel) else { return }

                let modelArray = viewModel.kelasModelForTable(tipeTabel)
                for (index, model) in modelArray.enumerated() {
                    // Ambil nilai mapel dari row yang sedang diedit
                    if mapel == model.mapel {
                        guard guruBaru != model.namaguru, !model.namasiswa.isEmpty else { continue }
                        if !UserDefaults.standard.bool(forKey: "timpaNamaGuruSebelumnya") {
                            // nama guru sebelumnya harus sama dengan namaguru di modeldata, jika nama guru berbeda maka akan dilanjutkan ke item berikutnya.
                            guard model.namaguru == guruLama else { continue }
                        }
                        let kelasIdForThisIndex = model.kelasID
                        // Update kolom nama guru di indeks ini
                        let oldData = OriginalData(
                            kelasId: kelasIdForThisIndex,
                            tableType: tipeTabel,
                            rowIndex: index,
                            columnIdentifier: "namaguru",
                            oldValue: model.namaguru,
                            newValue: guruBaru,
                            table: table,
                            tableView: tableView
                        )
                        viewModel.updateModelAndDatabase(
                            columnIdentifier: "namaguru",
                            rowIndex: index,
                            newValue: guruBaru,
                            oldValue: model.namaguru,
                            modelArray: modelArray,
                            table: table,
                            tableView: createStringForActiveTable(),
                            kelasId: kelasIdForThisIndex
                        )
                        originalModel.append(oldData)
                        selectRow.insert(index)
                    }
                }
            }
            DispatchQueue.main.async { [unowned self] in
                activeTable.reloadData(forRowIndexes: selectRow, columnIndexes: IndexSet(integer: columnIndex))
                activeTable.selectRowIndexes(selectRow, byExtendingSelection: true)
                undoArray.append(contentsOf: originalModel)
                self.updateUndoRedo(self)
            }
        }
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoUpdateNamaGuru(originalModel: originalModel)
        }
        deleteRedoArray(self)
    }

    /**
     * Mengembalikan perubahan pada nama guru di UI dan database yang sebelumnya dilakukan.
     * @discussion Fungsi ini merupakan bagian penting dari fungsionalitas 'undo' (pembatalan).
     * Ia mengambil data asli dari operasi yang dibatalkan, kemudian mengaplikasikan kembali
     * nilai-nilai lama ke model data dan UI, serta memperbarui database.
     * Operasi UI dan database ditangani di antrean yang sesuai (main/background)
     * untuk memastikan responsivitas aplikasi.
     *
     * @param originalModel: [OriginalData] - Sebuah array yang berisi objek `OriginalData`.
     * Setiap objek merepresentasikan status data sebelum perubahan, termasuk `kelasID`,
     * `tableType`, `rowIndex`, `columnIdentifier`, `oldValue`, `newValue`, serta
     * referensi ke tabel database (`table`) dan tampilan tabel (`tableView`).
     *
     * @returns: void
     */
    func undoUpdateNamaGuru(originalModel: [OriginalData]) {
        var selectRow: IndexSet = []
        var columnIndex = Int()
        var table = NSTableView()
        var isTableActivated = false
        // Pindahkan logika terkait UI ke main thread
        DispatchQueue.main.async { [unowned self] in
            if !isTableActivated {
                for model in originalModel {
                    if activeTable() != model.tableView {
                        activateTable(model.tableView) // Operasi UI harus di main thread
                    }
                    table = model.tableView
                    table.deselectAll(self)
                    columnIndex = model.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == model.columnIdentifier })!
                    // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                    guard columnIndex >= 0, columnIndex < model.tableView.tableColumns.count else { return }
                }
                isTableActivated = true
            }
        }
        DispatchQueue.global(qos: .background).async { [unowned self] in
            for model in originalModel.sorted(by: { $0.rowIndex < $1.rowIndex }) {
                // Cari indeks kelasModels yang memiliki id yang cocok dengan model
                guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableTypeForTable(model.tableView)).firstIndex(where: { $0.kelasID == model.kelasId }) else { return }

                // Mendapatkan nilai status dari model
                let newString = model.oldValue
                let modelData = viewModel.kelasModelForTable(model.tableType)
                let data = modelData[rowIndexToUpdate]
                let currentMapel = modelData[rowIndexToUpdate].mapel
                let currentGuru = modelData[rowIndexToUpdate].namaguru
                guard newString != data.namaguru, !data.namasiswa.isEmpty else { continue }
                let mapel = data.mapel
                let kelasID = data.kelasID
                if mapel == currentMapel {
                    if !undoArray.isEmpty {
                        undoArray.removeAll(where: { $0 == model })
                    } else {}
                    if !UserDefaults.standard.bool(forKey: "timpaNamaGuruSebelumnya") {
                        let guru = data.namaguru
                        guard guru == currentGuru else { continue }
                    }
                    viewModel.updateModelAndDatabase(columnIdentifier: "namaguru", rowIndex: rowIndexToUpdate, newValue: newString, oldValue: data.namaguru, modelArray: modelData, table: model.table, tableView: createStringForActiveTable(), kelasId: kelasID, undo: true)
                    selectRow.insert(rowIndexToUpdate)
                }
                // Hapus nilai lama dari array undo
            }
            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: selectRow, columnIndexes: IndexSet([columnIndex]))
                table.selectRowIndexes(selectRow, byExtendingSelection: true)
                self.updateUndoRedo(self)
                if let last = selectRow.max() {
                    table.scrollRowToVisible(last)
                }
            }
        }

        // Daftarkan aksi redo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.redoUpdateNamaGuru(originalModel: originalModel)
        })

        // Simpan nilai lama ke dalam array redo
        redoArray.append(contentsOf: originalModel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }
    }

    /**
     * Menerapkan kembali (redo) perubahan pada nama guru di UI dan database yang sebelumnya telah di-undo.
     * @discussion Fungsi ini adalah bagian penting dari fungsionalitas 'redo'.
     * Ia mengambil kembali nilai-nilai yang telah diubah sebelumnya dari `originalModel`
     * dan mengaplikasikannya kembali ke model data dan UI, serta memperbarui database.
     * Operasi UI dan database ditangani di antrean yang sesuai (main/background)
     * untuk memastikan responsivitas aplikasi.
     *
     * @param originalModel: [OriginalData] - Sebuah array yang berisi objek `OriginalData`.
     * Setiap objek merepresentasikan status data sebelum perubahan yang asli, termasuk `kelasID`,
     * `tableType`, `rowIndex`, `columnIdentifier`, `oldValue`, `newValue`, serta
     * referensi ke tabel database (`table`) dan tampilan tabel (`tableView`).
     *
     * @returns: void
     */
    func redoUpdateNamaGuru(originalModel: [OriginalData]) {
        var selectRow: IndexSet = []
        var columnIndex = Int()
        var table = NSTableView()
        var isTableActivated = false
        // Pindahkan logika terkait UI ke main thread
        DispatchQueue.main.async { [unowned self] in
            if !isTableActivated {
                for model in originalModel {
                    if activeTable() != model.tableView {
                        activateTable(model.tableView) // Operasi UI harus di main thread
                    }
                    table = model.tableView
                    table.deselectAll(self)
                    columnIndex = model.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == model.columnIdentifier })!
                    // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                    guard columnIndex >= 0, columnIndex < model.tableView.tableColumns.count else { return }
                }
                isTableActivated = true
            }
        }

        // Pekerjaan berat dilakukan di background
        DispatchQueue.global(qos: .background).async { [unowned self] in
            for model in originalModel.sorted(by: { $0.rowIndex < $1.rowIndex }) {
                guard let rowIndexToUpdate = viewModel.kelasModelForTable(tableType(forTableView: model.tableView)!).firstIndex(where: { $0.kelasID == model.kelasId }) else { return }

                // Mendapatkan nilai status dari model
                let newString = model.newValue
                let modelData = viewModel.kelasModelForTable(model.tableType)
                let data = modelData[rowIndexToUpdate]
                let currentMapel = modelData[rowIndexToUpdate].mapel
                let currentGuru = modelData[rowIndexToUpdate].namaguru
                let mapel = data.mapel
                let kelasID = data.kelasID

                if mapel == currentMapel {
                    guard newString != data.namaguru, !data.namasiswa.isEmpty else { continue }
                    // Hapus nilai lama dari array redo
                    if !redoArray.isEmpty {
                        redoArray.removeAll(where: { $0 == model })
                    }
                    if !UserDefaults.standard.bool(forKey: "timpaNamaGuruSebelumnya") {
                        let guru = data.namaguru
                        guard guru == currentGuru else { continue }
                    }

                    // Update model dan database
                    viewModel.updateModelAndDatabase(
                        columnIdentifier: "namaguru",
                        rowIndex: rowIndexToUpdate,
                        newValue: newString,
                        oldValue: data.namaguru,
                        modelArray: modelData,
                        table: model.table,
                        tableView: createStringForActiveTable(),
                        kelasId: kelasID,
                        undo: true
                    )
                    selectRow.insert(rowIndexToUpdate)
                }
            }

            // Operasi yang mengubah tampilan harus dilakukan di main thread
            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: selectRow, columnIndexes: IndexSet([columnIndex]))
                table.selectRowIndexes(selectRow, byExtendingSelection: true)
                if let last = selectRow.max() {
                    table.scrollRowToVisible(last)
                }
                self.updateUndoRedo(self)
            }
        }

        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
            self?.undoUpdateNamaGuru(originalModel: originalModel)
        })

        // Simpan nilai baru ke dalam array undo
        undoArray.append(contentsOf: originalModel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
        }
    }

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
        guard let toolbar = view.window?.toolbar else {
            return
        }

        guard let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem else { return }

        let searchField = searchFieldToolbarItem.searchField
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
        if let toolbar = view.window?.toolbar {
            // Search Field Toolbar Item
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
                let searchField = searchFieldToolbarItem.searchField
                searchField.isEnabled = true
                searchField.target = self
                searchField.action = #selector(procSearchFieldInput(sender:))
                searchField.delegate = self
                if let selectedTabViewItem = tabView.selectedTabViewItem {
                    let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                    updateSearchFieldPlaceholder(for: selectedTabIndex)
                }
            }

            // Kalkulasi Toolbar Item
            if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
               let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
            {
                kalkulasiNilai.isEnabled = true
                kalkulasiNilai.isHidden = false
            }

            // Tambah Toolbar Item
            if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
               let tambah = tambahToolbarItem.view as? NSButton
            {
                tambah.isEnabled = true
                if let image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: .none) {
                    let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)
                    tambahToolbarItem.image = largeImage
                }
                tambahToolbarItem.label = "Catat Nilai"
                tambahToolbarItem.toolTip = "Tambahkan Nilai Baru untuk Siswa yang Sudah Ada"
                tambah.toolTip = "Tambahkan Nilai Baru Siswa yang Sudah Ada"
            }

            // Hapus Toolbar Item
            if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
               let hapus = hapusToolbarItem.view as? NSButton
            {
                hapus.isEnabled = false
            }

            // Edit Toolbar Item
            if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
               let edit = editToolbarItem.view as? NSButton
            {
                edit.isEnabled = activeTable()?.selectedRow != -1
            }

            // Zoom Toolbar Item
            if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
               let zoom = zoomToolbarItem.view as? NSSegmentedControl
            {
                zoom.isEnabled = true
                zoom.target = self
                zoom.action = #selector(segmentedControlValueChanged(_:))
            }

            // Add Toolbar Item
            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
               let add = addToolbarItem.view as? NSButton
            {
                add.isEnabled = true
                addToolbarItem.toolTip = "Tambahkan Data Siswa Baru"
                add.toolTip = "Tambahkan Data Siswa Baru"
            }

            // PopUp Menu Toolbar Item
            if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
               let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
            {
                popUpButton.menu = toolbarMenu
                toolbarMenu.delegate = self
            }
        }
    }

    /// Hapus semua array untuk redo.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteRedoArray(_ sender: Any) {
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
    func selectSidebar(_ table: NSTableView) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch table {
            case self.table1: self.delegate?.didUpdateTable(15)
            case self.table2: self.delegate?.didUpdateTable(16)
            case self.table3: self.delegate?.didUpdateTable(17)
            case self.table4: self.delegate?.didUpdateTable(18)
            case self.table5: self.delegate?.didUpdateTable(19)
            case self.table6: self.delegate?.didUpdateTable(20)
            default:
                break
            }
        }
    }
}

extension KelasVC: NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let tableType = tableType(forTableView: tableView) else { return 0 }
        return viewModel.numberOfRows(forTableType: tableType)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableType = tableType(forTableView: tableView),
              let kelasModel = viewModel.modelForRow(at: row, tableType: tableType)
        else {
            return NSView()
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                textField.lineBreakMode = .byTruncatingMiddle
                textField.usesSingleLineMode = true
                switch tableColumn?.identifier {
                case NSUserInterfaceItemIdentifier("namasiswa"):
                    textField.stringValue = kelasModel.namasiswa
                    textField.isEditable = false
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
                case NSUserInterfaceItemIdentifier("mapel"):
                    textField.stringValue = kelasModel.mapel
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 350
                case NSUserInterfaceItemIdentifier("nilai"):
                    let nilai = kelasModel.nilai
                    textField.stringValue = nilai == 00 ? "" : String(nilai)
                    textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.controlTextColor
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 40
                case NSUserInterfaceItemIdentifier("semester"):
                    textField.stringValue = kelasModel.semester
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 150
                case NSUserInterfaceItemIdentifier("namaguru"):
                    textField.stringValue = kelasModel.namaguru
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
                case NSUserInterfaceItemIdentifier("tgl"):
                    textField.alphaValue = 0.6
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd MMMM yyyy"
                    let availableWidth = tableColumn?.width ?? 0
                    if availableWidth <= 80 {
                        dateFormatter.dateFormat = "d/M/yy"
                    } else if availableWidth <= 120 {
                        dateFormatter.dateFormat = "d MMM yyyy"
                    } else {
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                    }
                    // Ambil tanggal dari siswa menggunakan KeyPath
                    let tanggalString = kelasModel.tanggal
                    if let date = dateFormatter.date(from: tanggalString) {
                        textField.stringValue = dateFormatter.string(from: date)
                    } else {
                        textField.stringValue = tanggalString // fallback jika parsing gagal
                    }
                    tableColumn?.minWidth = 70
                    tableColumn?.maxWidth = 140
                default:
                    break
                }
            }
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = activeTable(), let _ = tableType(forTableView: tableView) else { return }
        guard tableView.numberOfRows != 0 else {
            return
        }

        selectedIDs.removeAll()

        NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
        let table = activeTable()!
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                guard index >= 0, index < model.count else {
                    return nil // Mengabaikan indeks yang tidak valid
                }
                return model[index].kelasID
            })
        }
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let column = tableView.tableColumns[columnIndex].identifier.rawValue
        if column == "namasiswa" {
            // Menghapus highlight secara eksplisit
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }

        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }

        return true
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let table = activeTable()!
        KelasModels.currentSortDescriptor = tableView.sortDescriptors.first
        guard let sortDescriptor = tableView.sortDescriptors.first, let tableType = tableType(forTableView: tableView) else {
            return
        }
        viewModel.sort(tableType: tableType, sortDescriptor: sortDescriptor)
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        var indexset = IndexSet()
        for id in selectedIDs {
            if let index = model.firstIndex(where: { $0.kelasID == id }) {
                indexset.insert(index)
            }
        }
        saveSortDescriptor(sortDescriptor, forTableIdentifier: createStringForActiveTable())
        tableView.reloadData()
        table.selectRowIndexes(indexset, byExtendingSelection: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let max = indexset.max() {
                table.scrollRowToVisible(max)
            }
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            let resizedColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            // Pastikan jumlah baris dalam tableView sesuai dengan jumlah data di model
            let rowCount = tableView.numberOfRows
            let siswaList = viewModel.kelasModelForTable(tableTypeForTable(tableView))

            guard siswaList.count == rowCount else {
                return
            }
            for row in 0 ..< rowCount {
                let siswa = siswaList[row]
                if let cellView = tableView.view(atColumn: resizedColumn, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let textField = cellView.textField
                    let tanggalString = siswa.tanggal
                    guard !tanggalString.isEmpty else { continue }
                    let dateFormatter = DateFormatter()
                    // Tentukan format tanggal berdasarkan lebar kolom
                    if let textWidth = textField?.cell?.cellSize(forBounds: textField!.bounds).width, textWidth < textField!.bounds.width {
                        let availableWidth = textField?.bounds.width
                        if availableWidth! <= 80 {
                            // Teks dipotong, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d/M/yy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else if availableWidth! <= 120 {
                            // Lebar tersedia kurang dari atau sama dengan 80, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d MMM yyyy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else {
                            // Teks tidak dipotong dan lebar tersedia lebih dari 80, gunakan format tanggal lengkap
                            dateFormatter.dateFormat = "dd MMMM yyyy"
                            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        }
                    }
                    // Convert string date to Date object
                    if let date = dateFormatter.date(from: tanggalString) {
                        // Update text field dengan format tanggal yang baru
                        textField?.stringValue = dateFormatter.string(from: date)
                    }
                }
            }
        }
    }

    func tableViewColumnDidMove(_ notification: Notification) {
        guard let activeTable = activeTable() else {
            return
        }
        ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        // Membuat tooltip sesuai dengan data yang ada di sel tertentu
        guard let tableType = tableType(forTableView: tableView) else { return "" }
        let kelasModel = viewModel.kelasModelForTable(tableType)
        let columnName = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let currentData: String = switch columnName {
        case NSUserInterfaceItemIdentifier("namasiswa"):
            kelasModel[row].namasiswa
        case NSUserInterfaceItemIdentifier("mapel"):
            kelasModel[row].mapel
        case NSUserInterfaceItemIdentifier("nilai"):
            String(kelasModel[row].nilai)
        case NSUserInterfaceItemIdentifier("semester"):
            kelasModel[row].semester
        case NSUserInterfaceItemIdentifier("namaguru"):
            kelasModel[row].namaguru
        case NSUserInterfaceItemIdentifier("tgl"):
            kelasModel[row].tanggal
        default:
            ""
        }

        return currentData
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        let table = activeTable()!
        if edge == .trailing, let tabtype = tableType(forTableView: table) {
            var actions: [NSTableViewRowAction] = []
            let hapusData = NSTableViewRowAction(style: .regular, title: "Hapus Catatan") { [weak self] rowAction, rowIndex in
                self?.hapusDataPilih(tableType: tabtype, table: table, selectedIndexes: IndexSet(integer: rowIndex))
            }
            hapusData.backgroundColor = NSColor.systemOrange
            actions.append(hapusData)
            let hapus = NSTableViewRowAction(style: .regular, title: "Hapus Data") { [weak self] rowAction, rowIndex in
                self?.hapusPilih(tableType: tabtype, table: table, selectedIndexes: IndexSet(integer: rowIndex))
            }
            hapus.backgroundColor = NSColor.systemRed
            actions.append(hapus)
            return actions
        } else if edge == .leading, let tabtype = tableType(forTableView: table) {
            table.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            let naikKelas = NSTableViewRowAction(style: .destructive, title: "Naik Kelas") { [weak self] rowAction, rowIndex in
                let menuItem = NSMenuItem(title: "", action: #selector(self?.naikKelasMenu(_:)), keyEquivalent: "")
                menuItem.representedObject = (table, tabtype)
                menuItem.target = self
                self?.naikKelasMenu(menuItem)
            }
            return [naikKelas]
        }

        return []
    }
}

extension KelasVC {
    /**
     * Menangani notifikasi ketika nama siswa telah diedit, memperbarui UI untuk baris yang relevan.
     * @discussion Fungsi ini dipicu oleh notifikasi yang berisi informasi tentang perubahan nama siswa.
     * Ini mengambil ID siswa, kelas saat ini, dan nama baru dari notifikasi, kemudian
     * menemukan semua indeks baris yang cocok di tabel yang relevan. Setelah itu,
     * ia memuat ulang baris dan kolom yang terpengaruh di `NSTableView` untuk mencerminkan perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi data perubahan.
     * Diharapkan `userInfo` berisi:
     * - `"updateStudentIDs"`: `Int64` (ID siswa yang diperbarui).
     * - `"kelasSekarang"`: `String` (nama kelas tempat siswa berada).
     * - `"namaSiswa"`: `String` (nama siswa yang baru).
     *
     * @returns: void
     */
    @objc func handleNamaSiswaDiedit(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["updateStudentIDs"] as? Int64,
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let namaBaru = userInfo["namaSiswa"] as? String
        {
            TableType.fromString(kelasSekarang) { kelas in
                let index = viewModel.findAllIndices(for: kelas, matchingID: deletedIDs, namaBaru: namaBaru)
                guard !index.isEmpty else {
                    return
                }

                guard let table = getTableView(for: kelas.rawValue) else { return }
                let columnIndex = table.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "namasiswa"))
                table.reloadData(forRowIndexes: IndexSet(index), columnIndexes: IndexSet([columnIndex]))
            }
        }
    }
}

extension KelasVC: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard let activeTable = activeTable() else { return }
        let columnIdentifier = activeTable.tableColumns[column].identifier.rawValue

        var newValue = newText
        newValue = newValue.capitalizedAndTrimmed()
        if let table = SingletonData.dbTable(forTableType: tableTypeForTable(activeTable)),
           let tableType = tableType(forTableView: activeTable)
        {
            let oldValue = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableType), table: table)
            // Dapatkan kelasId dari model data
            let kelasId = viewModel.kelasModelForTable(tableType)[row].kelasID
            switch columnIdentifier {
            case "mapel", "semester":
                // Bandingkan nilai baru dengan nilai lama
                if newValue != oldValue {
                    // Simpan originalModel untuk undo dengan kelasId
                    let originalModel = OriginalData(
                        kelasId: kelasId, tableType: tableTypeForTable(activeTable),
                        rowIndex: row,
                        columnIdentifier: columnIdentifier,
                        oldValue: oldValue,
                        newValue: newValue,
                        table: table,
                        tableView: activeTable
                    )
                    viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableType), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

                    // Daftarkan aksi undo ke NSUndoManager
                    myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
                        self?.undoAction(originalModel: originalModel)
                    }

                    // Tambahkan originalModel ke dalam array undoArray
                    undoArray.append(originalModel)
                    deleteRedoArray(self)
                    NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": tableType, "editedKelasIDs": kelasId, "siswaID": viewModel.kelasModelForTable(tableType)[row].siswaID, "columnIdentifier": columnIdentifier, "dataBaru": newValue])
                }
            case "namaguru":
                // let namaguruColumn = activeTable.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "namaguru"))
                // Bandingkan nilai baru dengan nilai lama
                if newValue != oldValue {
                    // Cek setting update semua namaGuru mapel
                    if UserDefaults.standard.bool(forKey: "updateNamaGuruDiMapelDanKelasSama") {
//                                // Iterasi semua data dan cari yang mapelnya sama
                        let currentMapel = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: "mapel", modelArray: viewModel.kelasModelForTable(tableType), table: table)
                        let currentGuru = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: "namaguru", modelArray: viewModel.kelasModelForTable(tableType), table: table)
                        let updatedMapelData: [[String: Any]] = [[
                            "mapel": currentMapel,
                            "guruBaru": newValue,
                            "guruLama": currentGuru,
                            "tipeTabel": tableType,
                        ]]

                        let userInfo: [String: Any] = ["mapelData": updatedMapelData]
                        let notification = Notification(name: .updateNamaGuru, userInfo: userInfo)
                        updateNamaGuruNotification(notification)
                    } else {
                        let originalModel = OriginalData(
                            kelasId: kelasId, tableType: tableTypeForTable(activeTable),
                            rowIndex: row,
                            columnIdentifier: columnIdentifier,
                            oldValue: oldValue,
                            newValue: newValue,
                            table: table,
                            tableView: activeTable
                        )
                        viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableType), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

                        // Daftarkan aksi undo ke NSUndoManager
                        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
                            self?.undoAction(originalModel: originalModel)
                        }

                        // Tambahkan originalModel ke dalam array undoArray
                        undoArray.append(originalModel)
                    }
                    deleteRedoArray(self)
                    NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": tableType, "editedKelasIDs": kelasId, "siswaID": viewModel.kelasModelForTable(tableType)[row].siswaID, "columnIdentifier": columnIdentifier, "dataBaru": newValue])
                }
            case "nilai":
                let oldValue = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableType), table: table)
                // Bandingkan nilai baru dengan nilai lama
                if newValue != oldValue {
                    // Simpan originalModel untuk undo dengan kelasId
                    let originalModel = OriginalData(
                        kelasId: kelasId, tableType: tableTypeForTable(activeTable),
                        rowIndex: row,
                        columnIdentifier: columnIdentifier,
                        oldValue: oldValue,
                        newValue: newValue,
                        table: table,
                        tableView: activeTable
                    )
                    viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableType), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

                    // Daftarkan aksi undo ke NSUndoManager
                    myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
                        self?.undoAction(originalModel: originalModel)
                    }

                    // Tambahkan originalModel ke dalam array undoArray
                    undoArray.append(originalModel)
                    deleteRedoArray(self)
                    let numericValue = Int(newValue) ?? 0
                    if let cell = activeTable.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView {
                        cell.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
                    }
                    NotificationCenter.default.post(name: .updateDataKelas, object: self, userInfo: ["tableType": tableType, "editedKelasIDs": kelasId, "siswaID": viewModel.kelasModelForTable(tableType)[row].siswaID, "columnIdentifier": columnIdentifier, "dataBaru": newValue])
                }
            default:
                break
            }
        }
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        guard let tableView = activeTable() else {
            return false
        }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        if columnIdentifier == "namasiswa" || columnIdentifier == "tgl" {
            return false
        }
        return true
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let tableView = activeTable(), let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView, let textField = cell.textField else {
            return ""
        }
        return textField.stringValue
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        tableView.tableColumns[column].width
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        guard let activeTable = activeTable() else { return [] }
        let columnIdentifier = activeTable.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "mapel":
            return Array(ReusableFunc.mapel)
        case "namaguru":
            return Array(ReusableFunc.namaguru)
        case "semester":
            return Array(ReusableFunc.semester)
        default:
            return []
        }
    }
}
