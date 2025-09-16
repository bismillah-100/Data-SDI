//
//  RincianVC.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 25/10/23.
//

import Cocoa
import Combine
import PDFKit.PDFDocument
import PDFKit.PDFView
import SQLite

/// Class DetailSiswaController mengelola tampilan untuk siswa tertentu, termasuk tabel nilai, semester, dan opsi lainnya.
class DetailSiswaController: NSViewController, WindowWillCloseDetailSiswa {
    /// Manajer `NSTableView`.
    var tableViewManager: KelasTableManager!
    /// Outlet untuk menu konteks yang digunakan untuk ekspor data siswa ke file XLSX/PDF.
    @IBOutlet weak var shareMenu: NSMenu!
    /// Outlet untuk tombol cetak yang digunakan untuk mencetak data siswa.
    @IBOutlet weak var printButton: NSButton!
    /// Outlet untuk tombol statistik yang digunakan untuk menampilkan statistik grafis semester 1 dan 2 siswa di semua kelas.
    @IBOutlet weak var statistik: NSButton!
    /// Outlet untuk nama siswa.
    @IBOutlet weak var namaSiswa: NSTextField!
    /// Outlet untuk menu popup semester.
    @IBOutlet weak var smstr: NSPopUpButton!

    /// Receiver untuk publisher ``NaikKelasEvent``.
    var cancellables: Set<AnyCancellable> = .init()

    /// Properti ID siswa.
    var siswaID: Int64!

    /// Outlet untuk label yang menampilkan rata-rata nilai di kelas.
    @IBOutlet weak var labelAverage: NSTextField!

    /// Outlet untuk NSVisualEffectView yang memberikan efek visual pada tampilan.
    @IBOutlet weak var visualEffect: NSVisualEffectView!

    /// Outlet untuk NSButton yang menampilkan pratinjau foto siswa.
    @IBOutlet weak var imageView: NSButton!

    /// Outlet untuk NSSegmentedControl yang digunakan untuk memilih kelas.
    @IBOutlet weak var kelasSC: NSSegmentedControl!

    /// Outlet untuk tombol yang digunakan untuk menampilkan menu pilihan siswa.
    @IBOutlet weak var opsiSiswa: NSPopUpButton!

    /// Outlet untuk tombol yang digunakan untuk menambahkan data siswa.
    @IBOutlet weak var tmblTambah: NSButton!

    /// Instance `NSAlert` untuk menampilkan pesan.
    let alert: NSAlert = .init()

    /// Instance ``KelasViewModel`` yang mengelola data untuk ditampilkan.
    let viewModel: KelasViewModel = .shared

    /// Properti yang menyimpan referensi jika data di ``viewModel``
    /// telah dimuat menggunakan data dari database dan telah ditampilkan
    /// di tableView yang sesuai.
    lazy var isDataLoaded: [NSTableView: Bool] = [:]

    /// Referensi data untuk siswa yang sedang ditampilkan.
    var siswa: ModelSiswa?

    /// Instance ``DatabaseController``.
    let dbController: DatabaseController = .shared

    /// Properti kamus table dan tableType nya.
    var tableInfo: [(table: NSTableView, type: TableType)] {
        tableViewManager.tableInfo
    }

    /// `NSOperationQueue` khusus untuk penyimpanan data.
    let bgTask = DatabaseController.shared.notifQueue

    /// Properti undoManager khusus untuk ``DetailSiswaController``.
    var myUndoManager: UndoManager?

    /// Outlet tombol untuk menampilkan hanya nilai yang ada di kelas aktif.
    @IBOutlet weak var nilaiKelasAktif: NSButton!
    /// Outlet tombol untuk menampilkan hanya nilai yang bukan di kelas aktif.
    @IBOutlet weak var bukanNilaiKelasAktif: NSButton!
    /// Outlet tombol untuk menampilkan semua nilai.
    @IBOutlet weak var semuaNilai: NSButton!

    /// Properti untuk menyimpan data kelas yang difilter.
    /// Juga untuk referensi data ``siswa`` untuk kalkulasi nilai yang direpresentasikan di dalam
    /// ``labelAverage``.
    var tableData: [KelasModels] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(addDetilPopUpDidClose(_:)), name: .addDetilSiswaUITertutup, object: nil)
    }

    override init(nibName _: NSNib.Name?, bundle _: Bundle?) {
        super.init(nibName: "DetailSiswa", bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init(siswaID: Int64, siswa: ModelSiswa) {
        self.init()
        self.siswaID = siswaID
        self.siswa = siswa
    }

    override func loadView() {
        super.loadView()
        // 1. buat NSTabView
        let tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder

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

            scrollView.removeConstraints(scrollView.constraints)
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            if let statusColumn = table.tableColumns.first(where: { $0.identifier.rawValue == "status" }) {
                table.removeTableColumn(statusColumn)
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

            // Custom tweak per table
            scrollView.contentInsets.top = 129
            if let kolomNama = table.tableColumns
                .first(where: { $0.identifier.rawValue == "namasiswa" })
            {
                table.removeTableColumn(kolomNama)
            }
        }

        // 4. Pasang tabView ke self.view
        view.addSubview(tabView, positioned: .below, relativeTo: nil)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // 5. Simpan referensi bila perlu
        tableViewManager = .init(siswaID: siswaID, tabView: tabView, tableViews: tables, selectionDelegate: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        myUndoManager = UndoManager()
        visualEffect.blendingMode = .withinWindow
        let tableNames = ["table1DetailSiswa", "table2DS", "table3DS", "table4DS", "table5DS", "table6DS"]
        for (index, (table, _)) in tableInfo.enumerated() {
            table.target = self
            table.delegate = tableViewManager
            table.selectionHighlightStyle = .regular
            table.allowsMultipleSelection = true
            table.dataSource = tableViewManager
            table.autosaveName = tableNames[index]
            table.autosaveTableColumns = true

            let menu = createContextMenu(tableView: table)
            table.menu = menu
            menu?.delegate = self

            for columnInfo in ReusableFunc.columnInfos {
                guard let column = table.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier)) else { continue }
                let customHeaderCell = MyHeaderCell()
                customHeaderCell.title = columnInfo.customTitle
                column.headerCell = customHeaderCell
            }

            table.doubleAction = #selector(tableViewDoubleClick(_:))
            table.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        }
        shareMenu.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let siswa else { return }
        let kelasSekarang = siswa.tingkatKelasAktif

        Task { [weak self] in
            guard let self else { return }
            await viewModel.loadSiswaData(siswaID: siswa.id)
            await MainActor.run { [weak self] in
                guard let self else { return }
                namaSiswa.stringValue = siswa.nama
                view.window?.title = "\(siswa.nama)"
                if kelasSekarang == .lulus {
                    kelasSC.setLabel("Kelas 6", forSegment: 5)
                    kelasSC.setSelected(true, forSegment: 5)
                    tableViewManager.selectTabViewItem(at: 5)
                } else if let kelasIndex = Int(kelasSekarang.rawValue.replacingOccurrences(of: "Kelas ", with: "")) { // Mendapatkan indeks kelasSekarang dari string (misal: "Kelas 1" menjadi 0)
                    // Menambahkan label "Kelas" sebelum angka pada segmentedControl
                    let label = String("Kelas \(kelasIndex)")
                    kelasSC.setLabel(label, forSegment: kelasIndex - 1)
                    // Mengatur selected segment pada segmentedControl
                    kelasSC.setSelected(true, forSegment: kelasIndex - 1)
                    // Mengatur tabView sesuai dengan indeks kelas
                    tableViewManager.selectTabViewItem(at: kelasIndex - 1)
                } else {
                    kelasSC.setLabel("Kelas 1", forSegment: 0)
                    kelasSC.setSelected(true, forSegment: 0)
                    tableViewManager.selectTabViewItem(at: 0)
                }

                for segmentIndex in 0 ..< kelasSC.segmentCount {
                    if segmentIndex != kelasSC.selectedSegment {
                        kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                    }
                }
                semuaNilai.state = .on
                tableViewManager.selectTabView()
                guard let table = tableViewManager.activeTableView else { return }
                loadTableData(tableView: table)
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupCombine()
        setupSortDescriptor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            populateSemesterPopUpButton()
            updateMenuItem(self)
        }

        smstr.menu?.delegate = self
        alert.addButton(withTitle: "OK")
        NotificationCenter.default.addObserver(
            forName: .siswaDihapus,
            queue: .main,
            filter: { [weak self] in $0.deletedStudentIDs.contains(self?.siswaID ?? -1) }
        ) { [weak self] (payload: NotifSiswaDihapus) in
            self?.handleSiswaDihapusNotification(payload)
        }

        NotificationCenter.default.addObserver(
            forName: .undoSiswaDihapus,
            queue: .main,
            filter: { [weak self] in $0.deletedStudentIDs.contains(self?.siswaID ?? -1) }
        ) { [weak self] (payload: NotifSiswaDihapus) in
            self?.handleUndoSiswaDihapusNotification(payload)
        }

        NotificationCenter.default.addObserver(
            forName: .dataSiswaDiEditDiSiswaView,
            queue: .main,
            filter: { [weak self] in $0.updateStudentID == self?.siswaID ?? -1 }
        ) { [weak self] (payload: NotifSiswaDiedit) in
            self?.handleNamaSiswaDiedit(payload)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(updateNilaiFromKelasAktif(_:)), name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedSaveDataNotification(_:)), name: .saveData, object: nil)

        if let tableViewManager {
            NotificationCenter.default.addObserver(
                forName: .kelasDihapus,
                object: nil,
                queue: .main
            ) { [weak self] (payload: DeleteNilaiKelasNotif) in
                tableViewManager.updateDeletion(payload)
                self?.updateSemesterTeks()
            }
            NotificationCenter.default.addObserver(
                forName: .undoKelasDihapus,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                tableViewManager.handleUndoKelasDihapusNotification(notification)
                self?.updateSemesterTeks()
            }
        }
    }

    /// Action untuk tombol ``nilaiKelasAktif``, ``bukanNilaiKelasAktif``, dan ``semuaNilai``.
    @IBAction func ubahFilterNilai(_: NSButton) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        let tabIndex = tableViewManager.selectedTabViewItem()!
        populateSemesterPopUpButton()
        updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: smstr.titleOfSelectedItem ?? "")
    }

    /// Menangani proses penyimpanan data saat aplikasi akan dihentikan.
    /// Fungsi ini memeriksa apakah ada perubahan yang belum disimpan (`deletedDataArray` atau `pastedData` tidak kosong).
    /// Jika ada perubahan, sebuah `NSAlert` ditampilkan untuk meminta konfirmasi pengguna apakah mereka ingin menyimpan perubahan tersebut.
    /// Berdasarkan respons pengguna, data akan disimpan, proses penghentian dibatalkan, atau aplikasi ditutup tanpa menyimpan.
    /// Sebuah indikator progres ditampilkan selama proses penyimpanan.
    ///
    /// - Parameter sender: Objek yang memicu panggilan fungsi ini (biasanya digunakan untuk `@objc` selector).
    @objc func saveDataWillTerminate(_ sender: Any) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan di rincian siswa belum disimpan. Simpan sekarang?"
        alert.informativeText = "Aplikasi segera ditutup. Perubahan terbaru akan disimpan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Tutup Aplikasi")
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
            guard let windowProgress = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let viewController = windowProgress.contentViewController as? ProgressBarVC else { return }
            windowProgress.showWindow(sender)
            viewController.progressIndicator.isIndeterminate = true
            viewController.progressIndicator.startAnimation(self)
            bgTask.async { [weak self] in
                guard let self else { return }
                processDeleteNilaiDatabase()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                saveData(self)
                windowProgress.close()
                NSApp.reply(toApplicationShouldTerminate: true)
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] timer in
                    self?.dataButuhDisimpan = false
                    NotificationCenter.default.post(name: .dataSaved, object: nil)
                    timer.invalidate()
                })
            }
        } else if response == .alertSecondButtonReturn {
            NSApp.reply(toApplicationShouldTerminate: false)
        } else if response == .alertThirdButtonReturn {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    /// Fungsi ini dijalankan setelah proses penyimpanan data
    /// untuk membersihkan array yang menyimpan undo/redo dan action undoManager.
    @objc func saveData(_: Any) {
        deletedDataArray.removeAll()
        pastedNilaiID.removeAll()
        pastedData.removeAll()
        deleteRedoArray(self)
        myUndoManager?.removeAllActions(withTarget: self)
        ReusableFunc.resetMenuItems()
        updateMenuItem(nil)
        updateUndoRedo(self)
    }

    /// Membuat tabel yang aktif sebagai firstResponder.
    func activateSelectedTable() {
        if let selectedTable = activeTable() {
            view.window?.makeFirstResponder(selectedTable)
        }
    }

    /// Outlet untuk tombol simpan.
    @IBOutlet weak var tmblSimpan: NSButton!

    /// Dijalankan ketika popover ``tambahSiswaButtonClicked(_:)`` ditutup.
    /// Notifikasi yang memicu adalah `.addDetilSiswaUITertutup`.
    /// - Parameter notification: Objek `Notification` yang memicu.
    @objc func addDetilPopUpDidClose(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateUndoRedo(notification)
            self.tmblTambah.state = .off
        }
    }

    /// Action untuk menyimpan perubahan pada data di tabel yang belum disimpan.
    /// - Parameter sender: Objek yang memicu, bisa objek apapun.
    @IBAction func saveButton(_: Any) {
        activateSelectedTable()

        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "checkmark.icloud.fill", accessibilityDescription: .none)
            alert.messageText = "Data saat ini adalah yang terbaru"
            alert.informativeText = "Tidak ada data yang baru-baru ini diubah di database atau perubahan data telah disimpan ke database."
            alert.addButton(withTitle: "OK")
            if let window = NSApplication.shared.mainWindow {
                // Menampilkan alert sebagai sheet dari jendela utama
                alert.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        window.endSheet(window, returnCode: .stop)
                    }
                }
            }
            return
        }
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan akan disimpan. Lanjutkan?"
        alert.informativeText = "Data yang telah dihapus/diedit tidak dapat diurungkan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [self] response in
                if response == .alertFirstButtonReturn {
                    performDatabaseOperations {}
                } else {
                    dataButuhDisimpan = true
                    return
                }
            }
        }
    }

    /// Menyimpan riwayat batch ``KelasModels/nilaiID`` sebagai array bertingkat (array of arrays)
    /// setelah menambahkan data untuk mendukung undo/redo.
    /// Setiap elemen batch mewakili satu aksi tempel (paste) data.
    var pastedNilaiID: [[Int64]] = []

    /// Array tuple dictionary yang menyimpan data yang di-paste untuk keperluan undo/redo.
    var pastedData: [[KelasModels]] = []

    /// Memilih dan menampilkan tab yang sesuai untuk kelas tertentu.
    /// Fungsi ini memperbarui `NSSegmentedControl` (``kelasSC``) dan `NSTabView`
    /// untuk menyorot dan menampilkan kelas yang dipilih berdasarkan `TableType` yang diberikan.
    ///
    /// - Parameter tableType: Enum `TableType` yang merepresentasikan kelas yang akan dipilih.
    func pilihKelas(_ tableType: TableType) {
        kelasSC.selectSegment(withTag: tableType.rawValue)
        kelasSC.setLabel(tableType.stringValue, forSegment: tableType.rawValue)
        tableViewManager.selectTabViewItem(at: kelasSC.selectedSegment)
    }

    /// Mengimplementasikan fungsionalitas "undo" untuk operasi penempelan (paste) data ke tabel.
    /// Fungsi ini membatalkan penempelan data terbaru dengan menghapus entri yang baru saja ditambahkan
    /// ke `NSTableView` dan model data yang sesuai. Ini juga mendaftarkan operasi "redo"
    /// untuk membalikkan tindakan "undo" ini.
    ///
    /// - Parameters:
    ///   - table: Objek `NSTableView` tempat operasi penempelan dilakukan.
    ///   - tableType: Enum `TableType` yang mengidentifikasi tabel kelas yang terpengaruh.
    func undoPaste(table: NSTableView, tableType: TableType) {
        guard !pastedNilaiID.isEmpty, let myUndoManager else {
            return
        }
        pilihKelas(tableType)
        // Ambil semua ID dari array nilaiID terakhir
        let allIDs = pastedNilaiID.removeLast()

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &pastedData, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.redoPaste(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        updateSemesterTeks()
        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .findDeletedData)
    }

    /// Melakukan aksi redo dan paste pada tabel yang ditentukan.
    ///
    /// - Parameter tableType: Tipe tabel yang akan diproses.
    /// - Parameter table: Objek `NSTableView` yang akan dilakukan aksi redo dan paste.
    func redoPaste(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = table.sortDescriptors.first,
              !pastedData.isEmpty, let myUndoManager
        else {
            return
        }
        pilihKelas(tableType)

        // Buat array baru untuk menyimpan semua id yang dihasilkan
        let pasteData = pastedData.removeLast()
        tableViewManager.restoreDeletedDataDirectly(
            deletedData: pasteData,
            tableType: tableType,
            sortDescriptor: sortDescriptor,
            table: table,
            viewController: self,
            undoManager: myUndoManager,
            onlyDataKelasAktif: false,
            nilaiID: &pastedNilaiID,
            siswaID: siswaID
        ) { [weak self] _ in
            self?.undoPaste(table: table, tableType: tableType)
        }

        updateUndoRedo(self)
        updateSemesterTeks()
    }

    /// Memperbarui tampilan tabel ketika ada notifikasi data yang baru ditambahkan.
    /// - Parameter notification: Notifikasi yang memicu pembaruan tabel.
    func updateTable(_ dataArray: [(index: Int, data: KelasModels)], tambahData _: Bool, undoIsHandled: Bool = true, aktif: Bool? = false) {
        var tableType: TableType!
        let dataToInsert = dataArray.map(\.data)
        let index = dataArray.map(\.index)

        guard let firstIndex = index.first, firstIndex < 5 else { return }

        let table = tableViewManager.tables[firstIndex]

        // 1. Tetapkan tabel yang dipilih
        tableType = tableTypeForTable(table)
        pilihKelas(tableType)
        // 2. Muat data jika belum dimuat
        if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
            // Panggil fungsi pemuatan data
            loadTableData(tableView: table)
            // Tandai data sebagai sudah dimuat
            isDataLoaded[table] = true
        }

        // 3. Atur sort descriptor
        setupSortDescriptor()

        for tuple in dataArray {
            let index = tuple.index
            let data = tuple.data
            insertRow(forIndex: index, withData: data, selectInsertedRow: undoIsHandled == false)
        }

        if undoIsHandled == false {
            pastedNilaiID.append(dataToInsert.map(\.nilaiID))
            myUndoManager?.registerUndo(withTarget: self) { [weak self] _ in
                self?.undoPaste(table: table, tableType: tableType)
            }
        }

        activateSelectedTable()

        deleteRedoArray(self)

        updateSemesterTeks()

        guard aktif == true else { return }

        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": firstIndex, "data": dataToInsert])
    }

    /// Fungsi ini akan menentukan sortdescriptor pertama di tableView sesuai index
    /// yang didapat dari ``KelasTableManager/getTableView(for:)-9fjtk``.
    /// - Parameter index: Indeks dari tableView yang ingin diambil sort descriptor-nya.
    /// - Returns: `NSSortDescriptor?` yang merupakan sort descriptor saat ini dari tableView yang sesuai dengan indeks.
    func getCurrentSortDescriptor(for index: Int) -> NSSortDescriptor? {
        let tableView = tableViewManager.getTableView(for: index)
        return tableView?.sortDescriptors.first
    }

    /// Menyisipkan baris baru pada tableView yang sesuai dengan data yang diberikan.
    /// - Parameters:
    ///   - index: Indeks untuk tableView yang sesuai dengan data yang akan disisipkan.
    ///   - data: Data kelas yang akan disisipkan ke dalam tableView.
    /// - Returns: Nilai indeks baris yang disisipkan, atau `nil` jika penyisipan gagal.
    func insertRow(forIndex index: Int, withData data: KelasModels, selectInsertedRow: Bool? = true) {
        // Determine the NSTableView based on index
        guard let sortDescriptor = getCurrentSortDescriptor(for: index),
              let comparator = KelasModels.comparator(from: sortDescriptor),
              let tableType = TableType(rawValue: index)
        else { return }

        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, comparator: comparator, siswaID: siswaID) else { return }
        let tableView = tableViewManager.getTableView(for: index)
        // Insert the new row in the NSTableView
        tableView?.insertRows(at: IndexSet(integer: rowInsertion), withAnimation: .slideUp)
        if selectInsertedRow == true {
            tableView?.selectRowIndexes(IndexSet(integer: rowInsertion), byExtendingSelection: true)
            tableView?.scrollRowToVisible(rowInsertion)
        }
    }

    ///  Fungsi untuk memuat data dari database. Dijalankan ketika suatu tabel
    /// ditampilkan pertama kali atau ketika memuat ulang tabel.
    /// - Parameter tableView: `NSTableView` yang ingin dimuat datanya.
    func loadTableData(tableView: NSTableView) {
        setupSortDescriptor()
        tableView.sortDescriptors.removeAll()
        let sortDescriptor = viewModel.getSortDescriptorDetil(forTableIdentifier: tableViewManager.createStringForActiveTable())
        applySortDescriptor(tableView: tableView, sortDescriptor: sortDescriptor)
        updateSemesterTeks()
        ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["mapel"], target: tableViewManager, selector: #selector(tableViewManager.toggleColumnVisibility(_:)))
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self, weak tableView] in
            guard let tableView else { return }
            tableView.reloadData()
            self?.isDataLoaded[tableView] = true
        }
    }

    /// Fungsi ini menangani aksi klik ganda pada tabel untuk membuka rincian siswa.
    /// - Parameter sender: Objek pemicu `NSTableView`.
    @objc func tableViewDoubleClick(_: Any) {
        guard let table = activeTable(), table.selectedRow >= 0 else { return }
        let column = table.clickedColumn
        let row = table.clickedRow

        guard column >= 0, row >= 0 else { return }

        // Memulai editing sel pada kolom & baris yang diklik
        table.editColumn(column, row: row, with: nil, select: true)
    }

    /// Memeriksa tampilan dan memuat ulang semua data di tabel.
    /// - Parameter sender:
    @objc func periksaTampilan(_: Any) {
        activateSelectedTable()
        if let table = activeTable() {
            Task { [weak self, weak table] in
                guard let self, let table,
                      let tableType = tableTypeForTable(table)
                else { return }
                await viewModel.reloadSiswaKelasData(tableType, siswaID: siswaID)
                table.reloadData()
            }
            isDataLoaded[table] = true
        }
        setupSortDescriptor()
    }

    /// Memuat ulang data dan tabel ketika menu item dipilih.
    /// - Parameter sender: NSMenuItem yang memicu aksi ini.
    @objc func muatUlang(_ sender: NSMenuItem) {
        // 1. Validate input and get table view and type
        guard let (tableView, tableType) = sender.representedObject as? (NSTableView, TableType) else {
            periksaTampilan(self) // Ensure this function handles UI updates safely if needed
            return
        }

        // 2. Capture the current tab index and semester name BEFORE the async operation
        //    These values might change if the user interacts with the UI quickly.
        guard let tabIndex = tableViewManager.selectedTabViewItem() else { return }

        let currentSemesterName = smstr.titleOfSelectedItem ?? ""
        let selectedRows = tableView.selectedRowIndexes

        // 3. Use a Task to perform the asynchronous data loading
        Task { [weak self] in
            // Ensure self is still valid and siswa is not nil.
            // It's crucial to handle the potential for `self` to be nil if the view controller
            // is deallocated while the async task is running.
            guard let self, let siswaID = siswa?.id else {
                // Log or handle the case where self or siswa is no longer available
                #if DEBUG
                    print("Error: Self or siswa is nil during data reload.")
                #endif
                return
            }

            // Await the completion of the data loading operation.
            // The UI will be blocked during this data load. If you want the UI to
            // remain responsive, consider showing a loading indicator before this line
            // and hiding it afterwards.
            await viewModel.loadSiswaData(forTableType: tableType, siswaID: siswaID)

            // 4. Perform all UI updates on the main actor after data is loaded.
            //    Since this Task is marked with `@MainActor`, these operations are guaranteed
            //    to run on the main thread.
            await MainActor.run {
                tableView.beginUpdates()
                tableView.reloadData()
                self.populateSemesterPopUpButton()
                self.updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: currentSemesterName)
                tableView.endUpdates()
                tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
                if let max = selectedRows.max() {
                    tableView.scrollRowToVisible(max)
                }
            }
        }
    }

    /// Membuat dan mengembalikan menu konteks (context menu) untuk NSTableView yang diberikan.
    /// - Parameter tableView: NSTableView yang akan diberikan menu konteks.
    /// - Returns: NSMenu opsional yang berisi menu konteks untuk tabel, atau nil jika tidak ada menu yang dibuat.
    func createContextMenu(tableView: NSTableView) -> NSMenu? {
        let tipeTabel = tableTypeForTable(tableView)
        let contextMenu = NSMenu()

        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.target = self
        refresh.representedObject = (tableView, tipeTabel)
        contextMenu.addItem(refresh)
        contextMenu.addItem(.separator())

        contextMenu.addItem(withTitle: "Salin", action: #selector(copyMenuItemClicked), keyEquivalent: "")
        contextMenu.items[2].target = self
        contextMenu.items[2].representedObject = tableView
        let paste = NSMenuItem(title: "Tempel", action: #selector(paste(_:)), keyEquivalent: "")
        contextMenu.addItem(paste)
        paste.target = self
        paste.representedObject = tableView
        contextMenu.addItem(.separator())
        let deleteMenuItem = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        deleteMenuItem.target = self
        deleteMenuItem.representedObject = (tableView, tipeTabel)
        contextMenu.addItem(deleteMenuItem)
        return contextMenu
    }

    func findAddDetailInKelas() -> AddDetaildiKelas? {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("AddDetaildiKelas"), bundle: nil)
        guard let detailViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas")) as? AddDetaildiKelas
        else { return nil }

        _ = detailViewController.view
        detailViewController.isKelasStatusActive = false
        detailViewController.statusSiswaKelas.state = .off
        detailViewController.appDelegate = false

        detailViewController.onSimpanClick = { [weak self] dataArray, tambah, undoIsHandled, kelasAktif in
            self?.updateTable(dataArray, tambahData: tambah, undoIsHandled: undoIsHandled, aktif: kelasAktif)
        }
        if let selectedTabIndex = tableViewManager.selectedTabViewItem() {
            detailViewController.appDelegate = false
            detailViewController.tabKelas(index: selectedTabIndex)
        }

        return detailViewController
    }

    /// Action untuk tombol/menu item paste atau ⌘V
    /// - Parameter sender:
    @IBAction func paste(_: Any) {
        let addNilai = findAddDetailInKelas()
        let (mapel, guru, nilai) = viewModel.parsePasteboard()

        guard let siswa, let addNilai, let mapel, let guru, let nilai else { return }

        addNilai.isDetailSiswa = true
        addNilai.namaPopUpButton.isEnabled = false
        addNilai.titleText.stringValue = "Paste nilai"
        addNilai.siswaNama = siswa.nama
        addNilai.idSiswa = siswa.id
        addNilai.mapelTextField.stringValue = mapel
        addNilai.guruMapel.stringValue = guru
        addNilai.nilaiTextField.stringValue = nilai
        addNilai.updateItemCount()

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 296, height: 420)
        popover.contentViewController = addNilai

        popover.show(relativeTo: tmblTambah.bounds, of: tmblTambah, preferredEdge: .maxY)
    }

    /// Fungsi ini menangani notifikasi ketika data siswa ditambahkan dari ``DetailSiswaController``.
    /// Baik itu dari undo ataupun redo.
    /// - Parameter notification: Objek `Notification` yang memicu.
    @objc func updateNilaiFromKelasAktif(_ notification: Notification) {
        // Memastikan tableView yang aktif.
        guard let table = activeTable() else { return }
        // Memastikan bahwa notifikasi memiliki userInfo yang berisi data yang diperlukan.
        if let userInfo = notification.userInfo {
            if let dataArray = userInfo["data"] as? [(index: Int, data: KelasModels)] {
                table.beginUpdates()
                for data in dataArray where data.data.siswaID == siswaID {
                    // Memastikan bahwa nama siswa tidak kosong sebelum memasukkan baris.
                    guard !data.data.namasiswa.isEmpty else {
                        continue
                    }
                    let index = data.index
                    let data = data.data
                    // Memastikan bahwa data yang akan dimasukkan tidak duplikat.
                    insertRow(forIndex: index, withData: data)
                }
                table.endUpdates()
            }
        }
    }

    /// Action untuk ``opsiSiswa``.
    /// - Parameter sender: Harus berupa `NSPopUpButton`.
    @IBAction func pilihanSiswa(_ sender: NSPopUpButton) {
        guard let selectedSiswa = siswa else { return }
        if sender.titleOfSelectedItem == "Salin NIK/NIS" {
            let copiedData = "\(selectedSiswa.nis)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "NIK/NIS〝\(selectedSiswa.nama)〞Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin NISN" {
            let copiedData = "\(selectedSiswa.nisn)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "NISN〝\(selectedSiswa.nama)〞Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin Semua Data" {
            let copiedData = "\(selectedSiswa.nama)\t\(selectedSiswa.alamat)\t\(selectedSiswa.ttl)\t\(selectedSiswa.tahundaftar)\t\(selectedSiswa.namawali)\t\(selectedSiswa.nis)\t \(selectedSiswa.nisn)\t\(selectedSiswa.ayah)\t\(selectedSiswa.ibu)\t\(selectedSiswa.tlv)\t\(selectedSiswa.jeniskelamin)\t\(selectedSiswa.tingkatKelasAktif)\t\(selectedSiswa.status)\t\(selectedSiswa.tanggalberhenti)\n"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "Data Lengkap〝\(selectedSiswa.nama)〞Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Info Lengkap Siswa" {
            alert.messageText = "\(selectedSiswa.nama)"
            alert.icon = NSImage(named: .siswa)
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self else { return }
                let data = dbController.bacaFotoSiswa(idValue: siswa?.id ?? 0)
                if let image = NSImage(data: data) {
                    // Ukuran asli gambar
                    let originalSize = image.size

                    // Ukuran maksimum area ikon di NSAlert
                    let maxIconSize = NSSize(width: 64, height: 64) // Sesuaikan sesuai kebutuhan Anda

                    // Hitung skala untuk menjaga proporsi gambar
                    let scale = min(maxIconSize.width / originalSize.width, maxIconSize.height / originalSize.height)
                    let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

                    // Buat gambar baru dengan area transparan
                    let paddedImage = NSImage(size: maxIconSize)
                    paddedImage.lockFocus()

                    // Hitung posisi tengah untuk menggambar gambar asli
                    let xOffset = (maxIconSize.width - newSize.width) / 2
                    let yOffset = (maxIconSize.height - newSize.height) / 2
                    let drawingRect = NSRect(origin: NSPoint(x: xOffset, y: yOffset), size: newSize)

                    // Gambar gambar asli pada area transparan
                    image.draw(in: drawingRect)

                    paddedImage.unlockFocus()
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        // Gunakan gambar baru sebagai ikon
                        alert.icon = paddedImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alert.icon = NSImage(named: .siswa)
                    }
                }
            }
            alert.informativeText = "Alamat: \(selectedSiswa.alamat)\nTTL: \(selectedSiswa.ttl)\nTahun Daftar: \(selectedSiswa.tahundaftar)\nNama Wali: \(selectedSiswa.namawali)\nNIK: \(selectedSiswa.nis)\nNISN: \(selectedSiswa.nisn)\nAyah Kandung: \(selectedSiswa.ayah)\nIbu Kandung: \(selectedSiswa.ibu)\nNo. Tlv: \(selectedSiswa.tlv)\nJenis Kelamin: \(selectedSiswa.jeniskelamin.description)\nStatus: \(selectedSiswa.status.description)\nKelas Sekarang: \(selectedSiswa.tingkatKelasAktif.rawValue)\nTanggal Berhenti: \(selectedSiswa.tanggalberhenti)"
            alert.beginSheetModal(for: view.window!, completionHandler: nil)
        }
    }

    /// Action untuk ``kelasSC``.
    /// Fungsi ini digunakan untuk memilih kelas apa yang akan ditampilkan.
    /// - Parameter sender:
    @IBAction func kelasSC(_ sender: NSSegmentedControl) {
        let selectedSegment = sender.selectedSegment
        let formatSegmentLabel = "Kelas \(selectedSegment + 1)"
        if kelasSC.label(forSegment: selectedSegment) != nil {
            // Mengganti label dengan menambahkan string "Kelas"
            kelasSC.setLabel("\(formatSegmentLabel)", forSegment: selectedSegment)
        }
        tableViewManager.selectTabViewItem(at: selectedSegment)
        activateSelectedTable()
        if let table = activeTable() {
            if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
                // Load data for the table view
                loadTableData(tableView: table)
                isDataLoaded[table] = true
            }
        }
        setupSortDescriptor()
        for segmentIndex in 0 ..< sender.segmentCount {
            if segmentIndex != selectedSegment {
                sender.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
    }

    /**
     Handler untuk menu konteks "Salin" pada tabel nilai siswa.

     Fungsi ini akan menyalin data baris pada tabel sesuai konteks klik kanan:
     - Jika baris yang diklik juga sedang terseleksi (bagian dari beberapa baris yang dipilih), maka akan menyalin semua baris yang terseleksi.
     - Jika baris yang diklik **tidak** sedang terseleksi, maka hanya baris yang diklik saja yang akan disalin.

     - Parameter sender: NSMenuItem yang memicu aksi ini.
     */
    @objc func copyMenuItemClicked(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView else { return }

        let clickedRow = tableView.clickedRow
        let selectedRows = tableView.selectedRowIndexes

        let rows = ReusableFunc.resolveRowsToProcess(selectedRows: selectedRows, clickedRow: clickedRow)

        ReusableFunc.salinBaris(rows, from: tableView)
    }

    /// Fungsi ini memperbarui action dan target menu item di Menu Bar.
    /// - Parameter sender: Objek pemicu yang dapat berupa `Any?`.
    @objc func updateMenuItem(_: Any?) {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let delete = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem,
           let pasteMenuItem = ReusableFunc.pasteMenuItem
        {
            new.target = self
            new.isEnabled = true
            new.action = #selector(tambahSiswaButtonClicked(_:))

            // Mendapatkan NSTableView aktif
            if let activeTableView = activeTable(),
               let tableType = tableTypeForTable(activeTableView)
            {
                let isRowSelected = activeTableView.selectedRowIndexes.count > 0
                copyMenuItem.isEnabled = isRowSelected
                pasteMenuItem.target = self
                pasteMenuItem.action = #selector(paste(_:))
                // Update item menu "Delete"
                delete.isEnabled = isRowSelected
                if isRowSelected {
                    copyMenuItem.target = self
                    copyMenuItem.action = #selector(copyMenuItemClicked(_:))
                    copyMenuItem.representedObject = activeTableView

                    // Set representedObject dengan benar
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
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_: Any?) {
        if !deletedDataArray.isEmpty || !pastedData.isEmpty {
            dataButuhDisimpan = true
            if tmblSimpan.image != NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none) {
                tmblSimpan.image = NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none)
            }
        } else {
            dataButuhDisimpan = false
            if tmblSimpan.image != NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none) {
                tmblSimpan.image = NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none)
            }
        }
        ReusableFunc.workItemUpdateUndoRedo?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let undoMenuItem = ReusableFunc.undoMenuItem,
                  let redoMenuItem = ReusableFunc.redoMenuItem,
                  let undoManager = myUndoManager
            else {
                return
            }

            let canUndo = undoManager.canUndo
            let canRedo = undoManager.canRedo
            if !canUndo {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            } else {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(undoDetil(_:))
                undoMenuItem.isEnabled = canUndo
            }

            if !canRedo {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            } else {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(redoDetil(_:))
                redoMenuItem.isEnabled = canRedo
            }
        }

        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    /**
         Menangani aksi penghapusan item dari tabel berdasarkan item menu yang diklik.

         Fungsi ini dipanggil ketika sebuah item menu yang terkait dengan penghapusan dipilih. Fungsi ini menentukan item mana yang akan dihapus berdasarkan baris yang diklik dan baris yang dipilih dalam tabel.

         - Parameter sender: `NSMenuItem` yang memicu aksi ini. `representedObject` dari menu item harus berupa tuple yang berisi `NSTableView` dan `TableType`.

         Proses:
         1. Memastikan bahwa `representedObject` dari `sender` dapat di-cast menjadi tuple `(NSTableView, TableType)` dan bahwa database untuk `TableType` yang diberikan tersedia. Jika tidak, fungsi akan keluar.
         2. Mendapatkan indeks baris yang diklik (`clickedRow`) dan set indeks baris yang dipilih (`selectedRowIndexes`) dari tabel.
         4. Fungsi ``hapusPilih(tableType:table:selectedIndexes:)`` dipanggil untuk menghapus data
            sesuai konteks row.
     */
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType) else { return }

        let selectedRow = table.clickedRow
        let selectedRows = table.selectedRowIndexes
        let selectedIndexes: IndexSet = if selectedRows.contains(selectedRow) {
            table.selectedRowIndexes
        } else {
            [selectedRow]
        }

        guard selectedRow >= 0 else { return }
        hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
    }

    /**
         Menangani aksi penghapusan data siswa.

         Fungsi ini dipanggil ketika pengguna memilih opsi "Hapus" dari menu Edit. Fungsi ini akan menampilkan dialog konfirmasi
         kepada pengguna, menanyakan apakah mereka yakin ingin menghapus data yang dipilih. Jika pengguna mengkonfirmasi,
         fungsi ini akan memanggil `hapusPilih` untuk melakukan penghapusan data yang sebenarnya.

         - Parameter:
             - sender: Objek yang memicu aksi ini (biasanya tombol atau item menu).

         - Catatan:
             - Fungsi ini menggunakan `NSApp.mainMenu` untuk mengakses menu utama aplikasi dan menemukan item menu "Edit" dan "Hapus".
             - Fungsi ini menggunakan `representedObject` dari item menu "Hapus" untuk mendapatkan informasi tentang tabel, tipe tabel, dan indeks yang dipilih.
             - Fungsi ini menampilkan `NSAlert` untuk meminta konfirmasi pengguna sebelum menghapus data.
             - Fungsi ini memanggil `hapusPilih` untuk melakukan penghapusan data setelah pengguna mengkonfirmasi.
     */
    @objc func hapus(_: Any) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" })
        {
            // Karena Anda menggunakan [weak self], tidak perlu optional binding di sini
            // Gunakan deleteMenuItem?.representedObject sebagai opsi terkini
            guard let representedObject = delete.representedObject as? (NSTableView, TableType, IndexSet) else {
                return
            }

            let (table, tableType, selectedIndexes) = representedObject

            // Memeriksa apakah ada indeks terpilih
            guard !selectedIndexes.isEmpty else {
                return
            }

            // Membuat Set untuk menyimpan nama siswa secara unik
            var uniqueSelectedMapel = Set<String>()

            // Mengisi Set dengan nama siswa dari indeks terpilih
            let modelArray = viewModel.kelasModelForTable(tableType, siswaID: siswaID)

            for index in selectedIndexes {
                if modelArray.indices.contains(index) {
                    uniqueSelectedMapel.insert(modelArray[index].mapel)
                } else {}
            }
            // Menggabungkan Set menjadi satu string dengan koma
            let selectedMapelString = uniqueSelectedMapel.joined(separator: ", ")

            let alert = NSAlert()
            alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
            alert.messageText = "Apakah anda yakin akan menghapus data ini dari \(siswa?.nama ?? "")"
            alert.informativeText = "\(selectedMapelString) akan dihapus dari \(siswa?.nama ?? "")."
            alert.addButton(withTitle: "Hapus")
            alert.addButton(withTitle: "Batalkan")
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Hanya melanjutkan jika pengguna menekan tombol "Hapus"
                // Tidak perlu optional binding pada self karena sudah menggunakan [weak self] di deklarasi metode
                hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
            }
        }
    }

    /**
         Array untuk menyimpan data yang dihapus. Setiap elemen dalam array ini berisi tuple yang terdiri dari:
         - `table`: `Table` database yang merepresentasikan tabel tempat data dihapus.
         - `data`: Array `KelasModels` yang berisi data yang dihapus dari tabel tersebut.
     */
    var deletedDataArray: [[KelasModels]] = []
    /**
         nilaiID adalah array dua dimensi yang menyimpan ID kelas.

         Setiap elemen dalam array luar mewakili satu set ID kelas.
         Setiap elemen dalam array dalam mewakili satu ID kelas dalam set tersebut.
     */
    var nilaiID: [[Int64]] = []

    /**
     *  Menghapus baris yang dipilih dari tabel yang ditentukan.
     *
     *  Fungsi ini menghapus baris yang dipilih dari `NSTableView` berdasarkan `IndexSet` yang diberikan.
     *  Data yang dihapus disimpan untuk kemungkinan operasi undo. Fungsi ini juga menangani pembaruan UI
     *  terkait dengan seleksi baris dan memicu pembaruan lain yang diperlukan.
     *
     *  - Parameter:
     *    - tableType: Jenis tabel yang sedang dimodifikasi (misalnya, kelas, siswa).
     *    - table: `NSTableView` tempat baris akan dihapus.
     *    - selectedIndexes: `IndexSet` yang berisi indeks baris yang akan dihapus.
     *
     *  - Catatan: Fungsi ini mengasumsikan keberadaan `viewModel`, `deletedDataArray`, `undoManager`, `tabView`,
     *    dan fungsi pembantu seperti
     *    `viewModel.kelasModelForTable(_:)`, `deleteRedoArray(_:)`, `viewModel.removeData(index:tableType:)`,
     *    `undoHapus(tableType:table:)`, `updateUndoRedo(_:)`, dan `updateSemesterTeks()`.
     *
     *  - Versi: 1.0
     */
    func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        let allIDs = selectedIndexes.map { index in
            viewModel.kelasModelForTable(tableType, siswaID: siswaID)[index].nilaiID
        }
        guard !allIDs.isEmpty else { return }

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &deletedDataArray, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }

        // Bersihkan array kelasID
        deleteRedoArray(self)

        updateUndoRedo(self)
        updateSemesterTeks()
        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .findDeletedData)
    }

    /**
     * Fungsi ini membatalkan (undo) operasi penghapusan data siswa dari tabel tertentu.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Mengaktifkan tabel yang diberikan.
     * 2. Menghapus semua pilihan (deselection) pada tabel.
     * 3. Mengambil data yang dihapus terakhir dari array `deletedDataArray`.
     * 4. Untuk setiap data yang dihapus:
     *      - Menyisipkan kembali data ke dalam sumber data menggunakan `viewModel.insertData`.
     *      - Menyisipkan baris baru ke dalam tabel pada indeks yang sesuai dengan animasi slide down.
     *      - Memilih baris yang baru disisipkan.
     *      - Menambahkan indeks penyisipan ke array `lastIndex`.
     * 5. Mengakhiri pembaruan tabel.
     * 6. Menggulir tabel ke baris terakhir yang disisipkan (jika ada).
     * 7. Memposting pemberitahuan untuk memperbarui status redo di detail siswa.
     * 8. Mendaftarkan operasi redo ke undo manager.
     * 9. Memperbarui status undo/redo.
     * 10. Memperbarui teks semester.
     * 11. Menghapus ID kelas dan siswa yang terkait dari `SingletonData.deletedKelasAndSiswaIDs`.
     *
     * - Parameters:
     *   - tableType: Jenis tabel yang sedang dioperasikan.
     *   - table: Tabel NSTableView yang akan di-undo penghapusannya.
     */
    func undoHapus(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = table.sortDescriptors.first,
              let myUndoManager, !deletedDataArray.isEmpty
        else { return }
        activateTable(table)
        table.deselectAll(self)

        let dataYangDihapus = deletedDataArray.removeLast()
        tableViewManager.restoreDeletedDataDirectly(
            deletedData: dataYangDihapus,
            tableType: tableType,
            sortDescriptor: sortDescriptor,
            table: table,
            viewController: self,
            undoManager: myUndoManager,
            onlyDataKelasAktif: false,
            nilaiID: &nilaiID,
            siswaID: siswaID
        ) { [weak self] _ in
            self?.redoHapus(table: table, tableType: tableType)
        }

        updateUndoRedo(self)
        updateSemesterTeks()
    }

    /**
     * Fungsi ini melakukan operasi "redo" untuk menghapus data siswa dari tabel tertentu.
     *
     * Fungsi ini mengambil data yang sebelumnya dihapus dan menghapusnya kembali dari tampilan tabel dan model data.
     * Fungsi ini juga mendaftarkan operasi "undo" yang sesuai untuk memungkinkan pemulihan data yang dihapus.
     *
     * - Parameter table: NSTableView yang datanya akan diubah.
     * - Parameter tableType: TableType yang menunjukkan jenis tabel yang sedang dimodifikasi (misalnya, kelas1, kelas2, dll.).
     *
     * - Precondition: `nilaiID` tidak boleh kosong.
     *
     * - Postcondition: Data yang sesuai akan dihapus dari `targetModel` dan `NSTableView`, dan operasi "undo" akan didaftarkan.
     *
     * - Note: Fungsi ini menggunakan `undoManager` untuk mendaftarkan operasi "undo" dan `NotificationCenter` untuk mengirim notifikasi tentang data yang dihapus.
     */
    func redoHapus(table: NSTableView, tableType: TableType) {
        guard !nilaiID.isEmpty else { return }
        // Ambil semua ID dari array nilaiID terakhir
        let allIDs = nilaiID.removeLast()
        activateTable(table)

        tableViewManager.hapusModelTabel(tableType: tableType, tableView: table, allIDs: allIDs, deletedDataArray: &deletedDataArray, undoManager: myUndoManager, undoTarget: self) { [weak self] _ in
            self?.undoHapus(tableType: tableType, table: table)
        }

        updateUndoRedo(self)
        updateSemesterTeks()
        DeleteNilaiKelasNotif.sendNotif(tableType: tableType, nilaiIDs: allIDs, notificationName: .findDeletedData)
    }

    /**
         Mengatur deskriptor pengurutan untuk setiap kolom dalam tabel. Fungsi ini mengiterasi melalui setiap kolom tabel,
         mengambil pengidentifikasi kolom, dan menetapkan deskriptor pengurutan yang sesuai dari kamus `identifikasiKolom`.
         Deskriptor pengurutan ini kemudian digunakan sebagai prototipe untuk memungkinkan pengurutan data dalam kolom tersebut.
     */
    func setupSortDescriptor() {
        let table = activeTable()
        guard let tableColumn = table?.tableColumns else { return }

        let identifikasiKolom = viewModel.setupSortDescriptors()

        for column in tableColumn {
            let identifikasi = column.identifier
            let pengidentifikasi = identifikasiKolom[identifikasi]
            column.sortDescriptorPrototype = pengidentifikasi
        }
    }

    /// Terapkan sort descriptor dari UserDefaults yang telah disimpan ke tableView.
    func applySortDescriptor(tableView: NSTableView, sortDescriptor: NSSortDescriptor?) {
        guard let sortDescriptor else {
            return
        }
        // Terapkan sort descriptor ke table view
        tableView.sortDescriptors = [sortDescriptor]
    }

    /**
     Menangani aksi tombol cetak. Memeriksa apakah jendela tampilan tersedia, menampilkan peringatan jika data belum siap,
     dan memanggil fungsi untuk memeriksa instalasi Python dan Pandas. Jika Python dan Pandas terinstal, fungsi ini
     memanggil ``generatePDFForPrint(header:siswaData:namaFile:window:sheetWindow:pythonPath:)`` untuk menghasilkan PDF dari data siswa. Jika tidak, fungsi ini menutup jendela progress.

     - Parameter sender: Objek yang memicu aksi (tombol cetak).
     */

    @IBAction func handlePrint(_: Any) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Data belum siap"
            alert.informativeText = "Pilih kelas terlebih dahulu untuk menyiapkan data."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.generatePDFForPrint(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.tableViewManager.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /**
     * Menghasilkan file PDF untuk dicetak dari data siswa.
     *
     * - Parameter header: Array string yang berisi header untuk data.
     * - Parameter siswaData: Array objek `KelasModels` yang berisi data siswa.
     * - Parameter namaFile: Nama file yang akan digunakan untuk file CSV dan PDF sementara.
     * - Parameter window: Jendela utama aplikasi.
     * - Parameter sheetWindow: Jendela sheet yang menampilkan progress.
     * - Parameter pythonPath: Path ke interpreter Python yang akan digunakan untuk konversi CSV ke PDF.
     *
     * Fungsi ini menyimpan data siswa ke file CSV sementara, mengonversi CSV ke PDF menggunakan script Python,
     * menampilkan dialog print untuk file PDF, dan menghapus file sementara setelah selesai.
     */
    func generatePDFForPrint(header: [String], siswaData: [KelasModels], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?) {
        // Tentukan lokasi sementara untuk menyimpan file PDF
        let csvFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(namaFile).csv")

        do {
            // Simpan data sebagai CSV sementara
            try ReusableFunc.saveToCSV(header: header, rows: siswaData, destinationURL: csvFileURL) { data in
                [data.mapel, String(data.nilai), data.semester, data.namaguru]
            }
            // Konversi CSV ke PDF
            ReusableFunc.runPythonScriptPDF(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                if let progressVC = sheetWindow?.contentViewController as? ProgressBarVC {
                    progressVC.progressLabel.stringValue = "Mengunggu dialog print selesai..."
                }

                // Dialog print file PDF
                self.printPDFDocument(at: xlsxFileURL!)

                self.view.window?.endSheet(sheetWindow!)

                // Hapus file sementara jika perlu
                try? FileManager.default.removeItem(at: csvFileURL)
                try? FileManager.default.removeItem(at: xlsxFileURL!)
            })
        } catch {
            #if DEBUG
                print("Gagal menyimpan CSV sementara: \(error)")
            #endif
            window?.endSheet(sheetWindow!)
        }
    }

    /**
         Mencetak dokumen PDF dari URL file yang diberikan.

         Fungsi ini memuat dokumen PDF dari URL yang diberikan, mengkonfigurasi tampilan PDF untuk pencetakan,
         dan memulai operasi pencetakan menggunakan NSPrintOperation.

         - Parameter pdfFileURL: URL file PDF yang akan dicetak.
     */
    func printPDFDocument(at pdfFileURL: URL) {
        guard let pdfDocument = PDFDocument(url: pdfFileURL) else {
            #if DEBUG
                print("Gagal memuat file PDF untuk dicetak di lokasi: \(pdfFileURL.path)")
            #endif
            return
        }

        // Membuat PDFView untuk mencetak
        let pdfView = PDFView()
        pdfView.document = pdfDocument

        // Konfigurasi NSPrintInfo
        let printInfo = NSPrintInfo.shared
        printInfo.leftMargin = 0.0
        printInfo.rightMargin = 0.0
        printInfo.topMargin = 0.0
        printInfo.bottomMargin = 0.0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .clip
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        // Frame
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayBox = .mediaBox // Gunakan ukuran media penuh
        pdfView.backgroundColor = .clear // Hilangkan latar belakang
        pdfView.displaysPageBreaks = false // Hilangkan garis antar halaman
        pdfView.frame = CGRect(x: 0, y: 0, width: printInfo.paperSize.width, height: printInfo.paperSize.height)

        // Membuat NSPrintOperation
        let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOperation.jobTitle = "PDF \(siswa?.nama ?? "") \(tableViewManager.createLabelForActiveTable())"

        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printOperation.run()
    }

    /**
         Mengekspor data siswa ke file Excel dengan cara menjalankan func ``exportKelasToFile(pdf:data:)``.

         - Parameter sender: Item menu yang memicu fungsi ini.
     */
    @IBAction func exportToExcel(_: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        exportKelasToFile(pdf: false, data: tableData)
    }

    /**
         Ekspor data nilai siswa ke dalam format PDF dengan cara menjalankan func ``exportKelasToFile(pdf:data:)``.
         - Parameter:
             - sender: Objek NSMenuItem yang memicu aksi ekspor.
     */
    @IBAction func exportToPDF(_: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        exportKelasToFile(pdf: true, data: tableData)
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
                let header = ["Mapel", "Nilai", "Semester", "Nama Guru"]
                ReusableFunc.chooseFolderAndSaveCSV(header: header, rows: data, namaFile: "Data \(tableViewManager.createLabelForActiveTable())", window: view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: pdf) { siswa in
                    [
                        siswa.mapel, String(siswa.nilai), siswa.semester, siswa.namaguru,
                    ]
                }
            } else {
                view.window?.endSheet(progressWindow!)
            }
        }
    }

    /**
     Menampilkan menu berbagi (share menu) ketika tombol berbagi ditekan.

     - Parameter sender: Tombol yang memicu aksi ini.
     */
    @IBAction func shareButton(_ sender: NSButton) {
        shareMenu.popUp(positioning: nil, at: NSPoint(x: -2, y: sender.bounds.height + 4), in: sender)
    }

    /**
     Menampilkan statistik siswa.

     Fungsi ini dipanggil ketika tombol atau aksi yang terkait dengan tampilan statistik siswa diaktifkan.
     Fungsi ini akan membuat tabel menjadi responder pertama jika ada tabel aktif.
     Jika objek siswa tersedia dan ID siswa lebih besar dari 0, fungsi ini akan memanggil `bukaDetil(siswaID:)`
     untuk menampilkan detail siswa berdasarkan ID siswa.

     - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func tampilkanStatistik(_: AnyObject) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        if let siswa {
            Task(priority: .userInitiated) {
                await self.bukaDetil(siswaID: siswa.id)
            }
        }
    }

    private func filterKelasPerTableType(
        siswaID: Int64
    ) async -> [TableType: [KelasModels]] {
        guard let siswaData = viewModel.siswaKelasData[siswaID] else { return [:] }

        let predicate: (KelasModels) -> Bool = {
            if nilaiKelasAktif.state == .on { return { $0.aktif } }
            if bukanNilaiKelasAktif.state == .on { return { !$0.aktif } }
            if semuaNilai.state == .on { return { _ in true } }
            return { _ in false }
        }()

        return await withTaskGroup(
            of: (TableType, [KelasModels]).self,
            returning: [TableType: [KelasModels]].self
        ) { group in
            for type in TableType.allCases {
                let list = siswaData[type] ?? []
                group.addTask {
                    (type, list.filter(predicate))
                }
            }
            var result: [TableType: [KelasModels]] = [:]
            for await (type, filtered) in group {
                result[type] = filtered
            }
            return result
        }
    }

    /**
     * Membuka jendela detail untuk siswa dengan ID yang diberikan.
     *
     * Fungsi ini membuat instance dari ``SiswaChart``, mengirimkan `siswaID` ke instance tersebut,
     * mengatur nama murid untuk digunakan dalam judul jendela, dan menampilkan jendela statistik siswa.
     *
     * - Parameter:
     *   - siswaID: ID unik siswa yang akan ditampilkan detailnya.
     */
    func bukaDetil(siswaID: Int64) async {
        // Lakukan sesuatu dengan siswaID, misalnya, buka jendela statistik siswa.
        let chartData = await filterKelasPerTableType(
            siswaID: siswaID
        )

        let statistikSiswaVC = SiswaChart(data: chartData)
        let popover = NSPopover()
        popover.contentViewController = statistikSiswaVC
        popover.show(relativeTo: statistik.bounds, of: statistik, preferredEdge: .maxY)
        popover.behavior = .transient
        // Buka jendela statistik siswa.
        statistikSiswaVC.namaSiswa.stringValue = "Statistik " + (siswa?.nama ?? "")
        statistikSiswaVC.namaSiswa.toolTip = siswa?.nama ?? ""
    }

    /**
     Menampilkan pratinjau foto siswa yang dipilih dalam popover.

     Fungsi ini akan:
     1. Memastikan bahwa tabel yang aktif menjadi first responder.
     2. Memeriksa apakah ada siswa yang dipilih.
     3. Menginisialisasi `PratinjauFoto` dari storyboard.
     4. Mengatur siswa yang dipilih pada `PratinjauFoto`.
     5. Menampilkan `PratinjauFoto` dalam popover yang muncul di dekat tombol yang memicu aksi ini.

     - Parameter sender: Tombol yang memicu aksi pratinjau foto.
     */
    @IBAction func pratinjauFoto(_ sender: NSButton) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        if let selectedSiswa = siswa {
            if let viewController = NSStoryboard(name: NSStoryboard.Name("PratinjauFoto"), bundle: nil)
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ImagePreviewViewController")) as? PratinjauFoto
            {
                viewController.selectedSiswa = selectedSiswa
                viewController.loadView()
                // Menampilkan popover atau sheet, sesuai kebutuhan Anda
                let popover = NSPopover()
                popover.contentViewController = viewController
                popover.behavior = .semitransient

                // Tampilkan popover di dekat tombol yang memicunya
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            }
        }
    }

    /**
     Menangani aksi ketika tombol "Tambah Siswa" diklik.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Menjalankan ``findAddDetailInKelas()``.
     2. Mengatur data di ``AddDetaildiKelas`` yang didapatkan dari ``findAddDetailInKelas()``:
        - Menetapkan ``AddDetaildiKelas/isDetailSiswa`` ke `true`.
        - Mengatur ``AddDetaildiKelas/siswaNama`` dan ``AddDetaildiKelas/idSiswa`` sesuai dengan ``siswa``
     - Parameter:
        - sender: Objek yang memicu aksi (biasanya tombol).
     */
    @IBAction func tambahSiswaButtonClicked(_: Any) {
        let addNilai = findAddDetailInKelas()

        guard let siswa, let addNilai else { return }

        addNilai.isDetailSiswa = true
        addNilai.namaPopUpButton.isEnabled = false
        addNilai.siswaNama = siswa.nama
        addNilai.idSiswa = siswa.id
        addNilai.titleText.stringValue = "Nilai siswa"

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 296, height: 420)
        popover.contentViewController = addNilai

        popover.show(relativeTo: tmblTambah.bounds, of: tmblTambah, preferredEdge: .maxY)
    }

    /**
         Filter data berdasarkan semester yang dipilih dari `NSPopUpButton`.

         Fungsi ini dipanggil ketika sebuah semester dipilih dari `NSPopUpButton`. Fungsi ini melakukan beberapa hal:

         1. Memastikan bahwa `NSPopUpButton` tidak dalam keadaan "emptyData". Jika ya, maka fungsi akan keluar.
         2. Membuat tabel yang aktif menjadi first responder.
         3. Mengambil semester yang dipilih.
         4. Memanggil `updateValuesForSelectedTab` untuk memperbarui tampilan berdasarkan semester yang dipilih.

         - Parameter:
             - sender: `NSPopUpButton` yang mengirimkan aksi.
     */
    @IBAction func filterBySemester(_ sender: NSPopUpButton) {
        guard sender.menu?.item(at: 0)?.identifier?.rawValue != "emptyData" else {
            #if DEBUG
                print("emptyData clicked")
            #endif
            return
        }
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        let selectedSemester = sender.titleOfSelectedItem ?? ""
        if let selectedTabIndex = tableViewManager.selectedTabViewItem() {
            updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
        }
    }

    /// Menyimpan referensi semester yang tersedia di database untuk data ``siswa``.
    var allSemesters: Set<String>!

    /**
         Mengisi NSPopUpButton `smstr` dengan daftar semester yang difilter berdasarkan kondisi toggle button yang aktif.

         Fungsi ini melakukan langkah-langkah berikut:
         1. Menentukan data kelas yang sesuai berdasarkan tab yang sedang aktif di `tabView`.
         2. Memfilter data kelas untuk mendapatkan daftar semester yang unik berdasarkan status dari `nilaiKelasAktif`, `semuaNilai`, dan `bukanNilaiKelasAktif`.
            - Jika `nilaiKelasAktif` aktif, semester diambil dari data dengan nama siswa tidak kosong.
            - Jika `semuaNilai` aktif, semester diambil dari data dengan nilai lebih besar dari 0 dan semester tidak kosong.
            - Jika `bukanNilaiKelasAktif` aktif, semester diambil dari data dengan nama siswa kosong.
         3. Mengurutkan daftar semester menggunakan fungsi `ReusableFunc.semesterOrder`.
         4. Memformat nama semester menggunakan fungsi `ReusableFunc.formatSemesterName`.
         5. Memperbarui `smstr` dengan daftar semester yang telah diformat. Jika daftar semester kosong, menambahkan item placeholder "Item blm. dipilih" dan menonaktifkan interaksi.

         - Note: Fungsi ini bergantung pada properti `tabView`, `viewModel`, `nilaiKelasAktif`, `semuaNilai`, `bukanNilaiKelasAktif`, dan `smstr`.
     */
    func populateSemesterPopUpButton() {
        guard let selectedTabIndex = tableViewManager.selectedTabViewItem(),
              let tableType = TableType(rawValue: selectedTabIndex)
        else {
            return
        }
        let kelasData = viewModel.kelasModelForTable(tableType, siswaID: siswaID)

        if nilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.namasiswa != "" }.map(\.semester))
        } else if semuaNilai.state == .on {
            allSemesters = Set(kelasData.filter { !$0.semester.isEmpty && $0.nilai > 0 }.map(\.semester))
        } else if bukanNilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.aktif == false }.map(\.semester))
        }

        // Format semester dan urutkan
        let sortedSemesters = allSemesters.sorted { ReusableFunc.semesterOrder($0, $1) }
        let formattedSemesters = sortedSemesters.map { ReusableFunc.formatSemesterName($0) }

        // Update NSPopUpButton
        if formattedSemesters.isEmpty {
            // Tambahkan pesan placeholder jika tidak ada data
            smstr.removeAllItems()
            let emptyData = NSMenuItem(title: "Item blm. dipilih", action: nil, keyEquivalent: "")
            emptyData.identifier = NSUserInterfaceItemIdentifier(rawValue: "emptyData")
            smstr.menu?.addItem(emptyData)
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.isEnabled = false
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.isHidden = true
            smstr.menu?.item(withTitle: "Item blm. dipilih")?.state = .mixed
            smstr.isEnabled = true
        } else {
            smstr.removeAllItems()
            smstr.addItems(withTitles: formattedSemesters)
            smstr.isEnabled = true
        }
    }

    /**
     Memperbarui nilai-nilai yang ditampilkan berdasarkan tab yang dipilih dan nama semester.

     Fungsi ini melakukan pembaruan nilai secara asinkron berdasarkan tab yang dipilih dan nama semester.
     Fungsi ini melakukan filter data, menghitung total nilai dan rata-rata, serta memperbarui tampilan tabel.

     - Parameter tabIndex: Indeks tab yang dipilih.
     - Parameter semesterName: Nama semester yang dipilih.
     */
    @objc func updateValuesForSelectedTab(tabIndex: Int, semesterName: String) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        let kelasAktifState = nilaiKelasAktif.state == .on
        let bukanKelasAktifState = bukanNilaiKelasAktif.state == .on
        let semuaNilaiState = semuaNilai.state == .on

        var result: (
            tableData: [KelasModels],
            totalNilai: Int,
            averageNilai: Double,
            hiddenIndices: IndexSet
        )?

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            result = viewModel.filterNilai(
                tabIndex: tabIndex,
                semesterName: semesterName,
                kelasAktifState: kelasAktifState,
                semuaNilaiState: semuaNilaiState,
                bukanKelasAktifState: bukanKelasAktifState,
                siswaID: siswaID
            )
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self, let result, let table = activeTable() else { return }

            tableData = result.tableData

            NSAnimationContext.runAnimationGroup({ context in
                guard !result.hiddenIndices.isEmpty || !table.hiddenRowIndexes.isEmpty else { return }
                context.allowsImplicitAnimation = true
                context.duration = 0.2
                table.beginUpdates()
                table.unhideRows(at: table.hiddenRowIndexes, withAnimation: .slideDown)
                table.hideRows(at: result.hiddenIndices, withAnimation: .slideUp)
                table.endUpdates()
            }, completionHandler: { [weak self] in
                guard let self else { return }
                labelAverage.stringValue = String(format: "Rata-rata: %.2f", result.averageNilai) + " ・ " + "Jumlah: \(result.totalNilai)"
            })
        }
    }

    /**
     Memperbarui teks semester berdasarkan tab yang dipilih.

     Fungsi ini dipanggil ketika tab pada `tabView` berubah. Fungsi ini mengambil indeks tab yang dipilih dan teks semester yang dipilih dari `smstr`, kemudian memanggil `updateValuesForSelectedTab` untuk memperbarui nilai-nilai yang sesuai dengan tab dan semester yang dipilih.
     */
    @objc func updateSemesterTeks() {
        guard let selectedTabIndex = tableViewManager.selectedTabViewItem() else { return }
        let selectedSemester = smstr.titleOfSelectedItem ?? ""
        updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
    }

    /// Fungsi untuk menjalankan undo.
    @IBAction func undoDetil(_: Any) {
        if (myUndoManager?.canUndo) != nil {
            myUndoManager?.undo()
        }
    }

    /// Fungsi untuk menjalankan redo.
    @IBAction func redoDetil(_: Any) {
        if (myUndoManager?.canRedo) != nil {
            myUndoManager?.redo()
        }
    }

    /// Properti untuk menyimpan data sebelumnya yang diperbarui
    /// dari class lain dan diperbarui juga di class ``DetailSiswaController``
    /// setelah menerima notifikasi.
    ///
    /// Properti ini digunakan untuk menangani ketika class yang mengirim notifikas
    /// melakukan pengurungan sehingga class ``DetailSiswaController`` dapat kembali
    /// memperbarui datanya dengan data terbaru tanpa memuat ulang seluruh data
    /// dari database atau memuat ulang seluruh baris di tableView.
    var undoUpdateStack: [String: [[KelasModels]]] = [:] // Key adalah nama kelas

    /// Outlet tombol redo.
    @IBOutlet weak var redoButton: NSButton!
    /// Outlet tombol undo.
    @IBOutlet weak var undoButton: NSButton!

    /// Referensi untuk menandakan bahwa data butuh disimpan.
    /// Digunakan ketika window ``DetilWindow``
    /// yang memuat ``DetailSiswaController`` akan ditutup.
    var dataButuhDisimpan = false

    /// Fungsi ini dijalankan dan mencegah ``DetilWindow`` menutup jendela
    /// ketika ada data yang belum disimpan.
    func shouldAllowWindowClose() -> Bool {
        !dataButuhDisimpan
    }

    fileprivate func processDeleteNilaiDatabase() {
        // Menghapus data dari deletedDataArray
        for deletedData in deletedDataArray {
            let dataArray = deletedData

            for data in dataArray {
                dbController.deleteSpecificNilai(nilaiID: data.nilaiID)
                SingletonData.deletedKelasAndSiswaIDs.removeAll { pairList in
                    pairList.contains { $0.nilaiID == data.nilaiID }
                }
            }
        }

        // Menghapus data dari pastedData
        for pastedDataItem in pastedData {
            let dataArray = pastedDataItem

            for data in dataArray {
                dbController.deleteSpecificNilai(nilaiID: data.nilaiID)
                SingletonData.deletedKelasAndSiswaIDs.removeAll { pairList in
                    pairList.contains { $0.nilaiID == data.nilaiID }
                }
            }
        }
    }

    /// Dijalankan setelah menerima notifikasi `.saveData` untuk menyimpan
    /// data yang dihapus.
    @objc func receivedSaveDataNotification(_: Notification) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = 0.3
            namaSiswa.animator().alphaValue = 0
        }, completionHandler: { [unowned self] in
            processDeleteNilaiDatabase()

            saveData(self)
            dataButuhDisimpan = false

            // Menjalankan animasi untuk menunjukkan perubahan
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                context.duration = 0.3
                namaSiswa.animator().alphaValue = 1
                namaSiswa.animator().stringValue = "Perubahan telah disimpan"

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.namaSiswa.animator().alphaValue = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.namaSiswa.animator().alphaValue = 1
                        self.namaSiswa.stringValue = self.siswa?.nama ?? ""
                    }
                }
            }, completionHandler: nil)
        })
    }

    /**
     Menangani operasi database seperti penghapusan dan penambahan data.

     Fungsi ini menampilkan dialog konfirmasi sebelum melakukan operasi database. Jika pengguna memilih untuk melanjutkan,
     operasi database akan dilakukan secara asynchronous. Jika tidak ada data yang perlu dihapus atau ditambahkan,
     fungsi ini akan langsung kembali tanpa melakukan apa pun.

     - Parameter completion: Sebuah closure yang akan dieksekusi setelah operasi database selesai.
     */
    @objc func processDatabaseOperations(completion: @escaping () -> Void) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else {
            return
        }
        let alert = NSAlert()
        alert.icon = ReusableFunc.cloudArrowUp
        alert.messageText = "Perubahan akan disimpan. Lanjutkan?"
        alert.informativeText = "Data yang telah dihapus/diedit tidak dapat diurungkan setelah konfirmasi OK."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [self] response in
                if response == .alertFirstButtonReturn {
                    performDatabaseOperations {
                        completion()
                    }
                } else {
                    dataButuhDisimpan = true
                    return
                }
            }
        }
    }

    /**
     Melakukan operasi database seperti menghapus data yang ditandai untuk dihapus dan data yang ditempel (pasted).

     Fungsi ini menampilkan progress bar selama operasi berlangsung dan menjalankan operasi database di background
     agar tidak menghambat UI utama. Setelah operasi selesai, progress bar akan ditutup dan completion handler
     akan dipanggil.

     - Parameter completion: Sebuah closure yang akan dieksekusi setelah operasi database selesai dan progress bar ditutup.
     */
    func performDatabaseOperations(completion: @escaping () -> Void) {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let windowProgress = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let viewController = windowProgress.contentViewController as? ProgressBarVC else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let windowSheet = NSApplication.shared.mainWindow {
                viewController.progressIndicator.isIndeterminate = true
                viewController.progressIndicator.startAnimation(self)
                windowSheet.beginSheet(windowProgress.window!)
                bgTask.async { [weak self] in
                    guard let self else { return }
                    processDeleteNilaiDatabase()
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        saveData(self)
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] timer in
                            self?.dataButuhDisimpan = false
                            windowProgress.close()
                            windowSheet.endSheet(windowProgress.window!)
                            timer.invalidate()
                            completion()
                        })
                    }
                }
            }
        }
    }

    deinit {
        myUndoManager?.removeAllActions()
        #if DEBUG
            print("deinit detailSiswaViewController")
        #endif
        viewModel.removeSiswaData(siswaID: siswaID)
        for (table, _) in tableViewManager.tableInfo {
            table.menu = nil
            table.target = nil
            table.dataSource = nil
            table.delegate = nil
            table.headerView = nil
            table.removeFromSuperviewWithoutNeedingDisplay()
        }
        siswa = nil
        tableData.removeAll()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .siswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .kelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoKelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editDataSiswaKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editNamaGuruKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .saveData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .dataSiswaDiEditDiSiswaView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateDataKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: .addDetilSiswaUITertutup, object: nil)
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        view.removeFromSuperviewWithoutNeedingDisplay()
    }
}

extension DetailSiswaController {
    /// Menghapus semua array untuk redo. Ini dijalankan ketika melakukan perubahan
    /// pada data selain dari undo/redo.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    func deleteRedoArray(_: Any) {
        if !nilaiID.isEmpty { nilaiID.removeAll() }
    }

    /**
     Melakukan aksi 'undo' untuk mengembalikan nilai suatu kolom tabel dan data ke nilai sebelumnya berdasarkan data `originalModel`.

     Fungsi ini mencari indeks model kelas yang sesuai, memperbarui model dan database dengan nilai lama,
     mendaftarkan aksi 'redo' ke `NSUndoManager`, menghapus nilai lama dari array 'undo',
     memperbarui tampilan sel tabel yang sesuai, dan menyimpan nilai lama ke dalam array 'redo'.

     - Parameter originalModel: Objek `OriginalData` yang berisi informasi tentang perubahan yang akan dibatalkan,
                              termasuk `nilaiId`, `columnIdentifier`, `oldValue`, `tableType`, `table`, dan `tableView`.
     */
    func undoAction(originalModel: OriginalData) {
        pilihKelas(originalModel.tableType)

        tableViewManager.updateNilai(originalModel, newValue: originalModel.oldValue)
        // Daftarkan aksi redo ke NSUndoManager
        myUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoAction(originalModel: originalModel)
        })

        updateSemesterTeks()
        updateUndoRedo(self)
    }

    /**
     Melakukan aksi redo berdasarkan model data asli yang diberikan.

     Fungsi ini mencari indeks `kelasModels` yang sesuai dengan `originalModel`,
     kemudian memperbarui model dan database dengan nilai baru. Setelah itu,
     mendaftarkan aksi undo ke `NSUndoManager`.

     - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang akan di-redo.
     */
    func redoAction(originalModel: OriginalData) {
        pilihKelas(originalModel.tableType)

        tableViewManager.updateNilai(originalModel, newValue: originalModel.newValue)
        myUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        })

        updateUndoRedo(self)
        updateSemesterTeks()
    }

    /**
     Mendapatkan tabel yang saat ini aktif dan merupakan turunan dari tampilan ini.

      Fungsi ini memeriksa setiap tabel (table1 hingga table6) untuk melihat apakah tabel tersebut adalah turunan dari tampilan saat ini.
     Jika sebuah tabel ditemukan sebagai turunan, tabel tersebut akan dikembalikan. Jika tidak ada tabel yang ditemukan sebagai turunan, fungsi ini akan mengembalikan nil.

     - Returns: Tabel `NSTableView` yang aktif, atau nil jika tidak ada tabel yang aktif.
     */
    func activeTable() -> NSTableView? {
        tableViewManager.activeTableView
    }

    /**
         Menentukan jenis tabel berdasarkan objek `NSTableView` yang diberikan.

         - Parameter table: Objek `NSTableView` yang akan diperiksa jenisnya.
         - Returns: Nilai enum `TableType` yang sesuai dengan tabel yang diberikan. Mengembalikan `.kelas1` sebagai nilai default jika tabel tidak cocok dengan tabel yang dikenal.
     */
    func tableTypeForTable(_ table: NSTableView) -> TableType? {
        tableViewManager.tableInfo.first(where: { $0.table == table })?.type
    }

    /// Mengaktifkan tabel yang diberikan dan memperbarui tampilan tab serta kontrol segmen kelas.
    ///
    /// Fungsi ini memilih item tab yang sesuai dengan tabel yang diaktifkan dan memilih segmen yang sesuai pada kontrol segmen kelas.
    /// Fungsi ini juga memperbarui label pada kontrol segmen kelas untuk menunjukkan kelas yang dipilih.
    ///
    /// - Parameter table: NSTableView yang akan diaktifkan.
    func activateTable(_ table: NSTableView) {
        // Cari indeks dari tabel yang diberikan
        if let index = tableViewManager.tables.firstIndex(of: table) {
            // Gunakan indeks untuk memilih item tab dan segmen segmented control
            tableViewManager.selectTabViewItem(at: index)
            kelasSC.selectSegment(withTag: index)

            // Atur label segmen terpilih
            let kelasLabel = "Kelas \(index + 1)"
            kelasSC.setLabel(kelasLabel, forSegment: index)

            // Atur label untuk segmen lainnya
            for segmentIndex in 0 ..< kelasSC.segmentCount {
                if segmentIndex != index {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
        }
    }
}

extension DetailSiswaController {
    /**
     * Fungsi ini dipanggil ketika tombol untuk memperbesar ukuran baris ditekan.
     * Fungsi ini akan meningkatkan tinggi baris pada tabel yang aktif sebesar 5 poin.
     * Animasi digunakan untuk memberikan transisi yang halus saat ukuran baris berubah.
     *
     * - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func increaseSize(_: Any) {
        if let tableView = activeTable() {
            ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "")
        }
    }

    /**
     * Mengurangi tinggi baris pada tabel yang aktif.
     *
     * Fungsi ini mengurangi tinggi baris pada tabel yang sedang aktif (jika ada) sebesar 3 poin,
     * dengan batasan minimum tinggi baris adalah 16 poin. Animasi digunakan untuk memberikan
     * transisi yang halus saat perubahan tinggi baris terjadi.
     *
     * - Parameter sender: Objek yang memicu aksi ini (misalnya, sebuah tombol).
     */
    @IBAction func decreaseSize(_: Any) {
        if let tableView = activeTable() {
            ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "")
        }
    }
}

extension DetailSiswaController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { updateItemMenus(menu) }

    /**
     Memperbarui item menu berdasarkan menu yang diberikan.

     Fungsi ini menangani pembaruan item menu yang berbeda berdasarkan menu yang aktif.
     - Jika menu adalah menu semester (`smstr.menu`):
        - Memilih semester yang dipilih sebelumnya dari pop-up button semester.
     - Jika menu adalah menu berbagi (`shareMenu`):
        - Mengatur `representedObject` dari item menu "exportPDF" dan "exportExcel" dengan tabel aktif dan tipe tabelnya.
     - Untuk menu lainnya:
        - Menyembunyikan atau menampilkan item menu "Salin" dan "Hapus" berdasarkan apakah baris diklik pada tabel aktif.
        - Jika tidak ada baris yang diklik, item "Salin" dan "Hapus" disembunyikan.
        - Jika ada baris yang diklik, item "Salin" dan "Hapus" ditampilkan dan judulnya diperbarui berdasarkan jumlah baris yang dipilih.

     - Parameter:
        - menu: Menu yang akan diperbarui.
     */
    func updateItemMenus(_ menu: NSMenu) {
        guard let table = activeTable() else { return }

        if menu == smstr.menu {
            let selectedSemester = smstr.titleOfSelectedItem
            populateSemesterPopUpButton()
            if selectedSemester != nil {
                smstr.selectItem(withTitle: selectedSemester!)
            }
            return
        }

        view.window?.makeFirstResponder(table)

        if menu == shareMenu {
            let pdf = menu.items.first(where: { $0.identifier?.rawValue == "exportPDF" })
            pdf?.representedObject = (table, tableTypeForTable(table))

            let xcl = menu.items.first(where: { $0.identifier?.rawValue == "exportExcel" })
            xcl?.representedObject = (table, tableTypeForTable(table))

            return
        }

        let salin = menu.item(at: 2)
        let hapus = menu.item(at: 5)

        guard table.clickedRow >= 0 else {
            for i in 0 ..< menu.items.count {
                let menuItem = menu.item(at: i)
                if i == 5 || i == 2 {
                    menuItem?.isHidden = true
                } else {
                    menuItem?.isHidden = false
                }
            }
            return
        }
        for i in 0 ..< menu.items.count {
            let menuItem = menu.item(at: i)
            menuItem?.isHidden = false
        }
        if table.selectedRowIndexes.contains(table.clickedRow) {
            salin?.title = "Salin \(table.numberOfSelectedRows) data..."
            hapus?.title = "Hapus \(table.numberOfSelectedRows) data..."
        } else {
            salin?.title = "Salin 1 data..."
            hapus?.title = "Hapus 1 data..."
        }
    }
}
