//
//  DetailSiswaController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 25/10/23.
//

import Cocoa
import PDFKit.PDFDocument
import PDFKit.PDFView
import SQLite

/// Class DetailSiswaController mengelola tampilan untuk siswa tertentu, termasuk tabel nilai, semester, dan opsi lainnya.
class DetailSiswaController: NSViewController, NSTabViewDelegate, WindowWillCloseDetailSiswa {
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
    /// Referensi lemah ke array objek tingkat atas, digunakan untuk menampung objek-objek yang dimuat dari file XIB ``TabContentView``.
    /// Menggunakan `weak` untuk mencegah terjadinya strong reference cycle.
    /// Tipe data menggunakan `NSArray?` sehingga dapat bernilai `nil` jika belum ada objek yang dimuat.
    weak var topLevelObjects: NSArray? = nil
    /// Referensi lemah ke NSTabView yang digunakan untuk menampilkan tab pada antarmuka pengguna.
    /// Properti ini diatur sebagai weak untuk mencegah terjadinya strong reference cycle.
    weak var tabView: NSTabView!
    /// Referensi lemah ke NSTableView yang digunakan untuk menampilkan tab pada antarmuka pengguna.
    /// Properti ini diatur sebagai weak untuk mencegah terjadinya strong reference cycle.
    weak var table1: EditableTableView!
    /// Lihat: ``table1``.
    weak var table2: EditableTableView!
    /// Lihat: ``table1``.
    weak var table3: EditableTableView!
    /// Lihat: ``table1``.
    weak var table4: EditableTableView!
    /// Lihat: ``table1``.
    weak var table5: EditableTableView!
    /// Lihat: ``table1``.
    weak var table6: EditableTableView!

    /// Outlet untuk label yang menampilkan jumlah nilai di kelas.
    @IBOutlet weak var labelCount: NSTextField!
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

    /// Instans `NSAlert` untuk menampilkan pesan.
    let alert = NSAlert()

    /// Instans ``KelasViewModel`` yang mengelola data untuk ditampilkan.
    let viewModel = KelasViewModel()

    /// Properti yang menyimpan referensi jika data di ``viewModel``
    /// telah dimuat menggunakan data dari database dan telah ditampilkan
    /// di tableView yang sesuai.
    lazy var isDataLoaded: [NSTableView: Bool] = [:]

    /// Referensi data untuk siswa yang sedang ditampilkan.
    var siswa: ModelSiswa?

    /// Instans ``DatabaseController``.
    let dbController = DatabaseController.shared

    /// Properti kamus table dan tableType nya.
    var tableInfo: [(table: NSTableView, type: TableType)] = []

    /// Properti untuk menyimpan tableType untuk tableView yang sedang aktif.
    var activeTableType: TableType = .kelas1

    /// `NSOperationQueue` khusus untuk penyimpanan data.
    let bgTask = AppDelegate.shared.operationQueue

    /// Properti undoManager khusus untuk ``DetailSiswaController``.
    var myUndoManager: UndoManager?

    /// Outlet tombol untuk menampilkan hanya nilai yang ada di kelas aktif.
    @IBOutlet weak var nilaiKelasAktif: NSButton!
    /// Outlet tombol untuk menampilkan hanya nilai yang bukan di kelas aktif.
    @IBOutlet weak var bukanNilaiKelasAktif: NSButton!
    /// Outlet tombol untuk menampilkan semua nilai.
    @IBOutlet weak var semuaNilai: NSButton!

    /// Properti untuk menyimpan data kelas sebelum difilter.
    var tableData: [KelasModels] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tabView.delegate = self
        myUndoManager = UndoManager()
        visualEffect.blendingMode = .withinWindow
        tableInfo = [
            (table1, .kelas1),
            (table2, .kelas2),
            (table3, .kelas3),
            (table4, .kelas4),
            (table5, .kelas5),
            (table6, .kelas6),
        ]
        let tableNames = ["table1DetailSiswa", "table2DS", "table3DS", "table4DS", "table5DS", "table6DS"]
        for (index, (table, _)) in tableInfo.enumerated() {
            table.target = self
            table.delegate = self
            table.selectionHighlightStyle = .regular
            table.allowsMultipleSelection = true
            table.dataSource = self
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

    /// Fungsi ini menangani aksi toggle visibilitas kolom pada tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        // Kolom mapel tidak dapat disembunyikan
        if column.identifier.rawValue == "mapel" { return }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if let siswa {
            viewModel.loadSiswaData(siswaID: siswa.id)
            namaSiswa.stringValue = siswa.nama
            view.window?.title = "\(siswa.nama)"

            let kelasSekarang = siswa.kelasSekarang
            if kelasSekarang.lowercased() == "lulus" {
                kelasSC.setLabel("Kelas 6", forSegment: 5)
                kelasSC.setSelected(true, forSegment: 5)
                tabView.selectTabViewItem(at: 5)
            } else if let kelasIndex = Int(kelasSekarang.replacingOccurrences(of: "Kelas ", with: "")) { // Mendapatkan indeks kelasSekarang dari string (misal: "Kelas 1" menjadi 0)
                // Menambahkan label "Kelas" sebelum angka pada segmentedControl
                let label = String("Kelas \(kelasIndex)")
                kelasSC.setLabel(label, forSegment: kelasIndex - 1)
                // Mengatur selected segment pada segmentedControl
                kelasSC.setSelected(true, forSegment: kelasIndex - 1)
                // Mengatur tabView sesuai dengan indeks kelas
                tabView.selectTabViewItem(at: kelasIndex - 1)
            } else {
                kelasSC.setLabel("Kelas 1", forSegment: 0)
                kelasSC.setSelected(true, forSegment: 0)
                tabView.selectTabViewItem(at: 0)
            }
        }

        for segmentIndex in 0 ..< kelasSC.segmentCount {
            if segmentIndex != kelasSC.selectedSegment {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
        semuaNilai.state = .on
    }

    /// Action untuk tombol ``nilaiKelasAktif``, ``bukanNilaiKelasAktif``, dan ``semuaNilai``.
    @IBAction func ubahFilterNilai(_ sender: NSButton) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }

        let selectedTabViewItem = tabView.selectedTabViewItem!
        // Menentukan model kelas berdasarkan tab yang aktif
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        populateSemesterPopUpButton()
        updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: smstr.titleOfSelectedItem ?? "")
    }

    override func keyDown(with event: NSEvent) {
        // keyCode 36 adalah tombol Enter/Return
        if event.keyCode == 36, let tableView = activeTable() {
            let selectedIndexes = tableView.selectedRowIndexes
            if let lastSelectedRow = selectedIndexes.last {
                let columnToEdit = 0 // kolom pertama
                tableView.editColumn(columnToEdit, row: lastSelectedRow, with: event, select: true)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        activateSelectedTable()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.populateSemesterPopUpButton()
            self.updateValuesForSelectedTab(tabIndex: self.tabView.indexOfTabViewItem(selectedTabViewItem), semesterName: self.smstr.titleOfSelectedItem ?? "Semester 1")
            self.updateMenuItem(self)
        }

        smstr.menu?.delegate = self
        alert.addButton(withTitle: "OK")
        NotificationCenter.default.addObserver(self, selector: #selector(handleSiswaDihapusNotification(_:)), name: .siswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoSiswaDihapusNotification(_:)), name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKelasDihapusNotification(_:)), name: .kelasDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoKelasDihapusNotification(_:)), name: .undoKelasDihapus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoUpdate(_:)), name: .updateUndoArray, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateEditedKelas(_:)), name: .editDataSiswaKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatedGuruKelas(_:)), name: .editNamaGuruKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedSaveDataNotification(_:)), name: .saveData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNamaSiswaDiedit(_:)), name: .dataSiswaDiEditDiSiswaView, object: nil)
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
        if let window = NSApplication.shared.mainWindow {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self else { return }
                if response == .alertFirstButtonReturn {
                    window.endSheet(window, returnCode: .OK)

                    let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
                    guard let windowProgress = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let viewController = windowProgress.contentViewController as? ProgressBarVC else { return }
                    window.beginSheet(windowProgress.window!)
                    DispatchQueue.main.async {
                        viewController.progressIndicator.isIndeterminate = true
                        viewController.progressIndicator.startAnimation(self)
                    }
                    self.bgTask.addOperation { [weak self] in
                        guard let self else { return }
                        for deletedData in self.deletedDataArray {
                            let currentClassTable = deletedData.table
                            let dataArray = deletedData.data
                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                        // Loop melalui pastedData
                        for pastedDataItem in self.pastedData {
                            let currentClassTable = pastedDataItem.table
                            let dataArray = pastedDataItem.data

                            for data in dataArray.sorted(by: { $0.kelasID < $1.kelasID }) {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                    }
                    OperationQueue.main.addOperation { [weak self] in
                        guard let self else { return }
                        self.saveData(self)
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] timer in
                            window.endSheet(windowProgress.window!)
                            self?.dataButuhDisimpan = false
                            NotificationCenter.default.post(name: .dataSaved, object: nil)
                            timer.invalidate()
                        })
                    }
                } else if response == .alertSecondButtonReturn {
                    window.endSheet(window, returnCode: .cancel)
                    NSApp.reply(toApplicationShouldTerminate: false)
                } else if response == .alertThirdButtonReturn {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
        }
    }

    /// Fungsi ini dijalankan setelah proses penyimpanan data
    /// untuk membersihkan array yang menyimpan undo/redo dan action undoManager.
    @objc func saveData(_ sender: Any) {
        undoArray.removeAll()
        deletedDataArray.removeAll()
        pastedKelasID.removeAll()
        pastedData.removeAll()
        deleteRedoArray(self)
        myUndoManager?.removeAllActions(withTarget: self)
        resetMenuItems()
        updateMenuItem(nil)
        updateUndoRedo(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if Bundle.main.loadNibNamed("TabContentView", owner: nil, topLevelObjects: &topLevelObjects) {
            guard let tabView = topLevelObjects?.first(where: { $0 is NSTabView }) as? NSTabView else {
                fatalError("Tidak menemukan NSTabView")
            }

            // Atur tabView ke dalam view
            view.addSubview(tabView, positioned: .below, relativeTo: nil)
            tabView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tabView.topAnchor.constraint(equalTo: view.topAnchor),
                tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            self.tabView = tabView
            // print("tabView Dikonfigurasi")

            // Pastikan ada 6 tab
            guard tabView.numberOfTabViewItems >= 6 else {
                fatalError("Tidak ada 6 tab di TabContentView.xib")
            }

            let tables = (0 ..< 6).map { ReusableFunc.getTableView(from: tabView.tabViewItem(at: $0)) }

            for table in tables {
                if let scrollView = table.enclosingScrollView {
                    scrollView.removeConstraints(scrollView.constraints)
                    scrollView.contentInsets.top = 129

                    if let kolomNama = table.tableColumns.first(where: { $0.identifier.rawValue == "namasiswa" }) {
                        table.removeTableColumn(kolomNama)
                    }
                }
            }

            // Ambil masing-masing table dari tab item
            (table1, table2, table3, table4, table5, table6) = (tables[0], tables[1], tables[2], tables[3], tables[4], tables[5])

            // print("table dikonfigurasi")
        } else {
            fatalError("tidak dapat load TabContentView.xib")
        }

        // NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: .hapusDataKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDataNotification(_:)), name: .updateDataKelas, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: DatabaseController.dataDidReloadNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(periksaTampilan(_:)), name: DatabaseController.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTable(_:)), name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(addDetilPopUpDidClose(_:)), name: .addDetilSiswaUITertutup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSemesterTeks), name: .updateNilaiTeks, object: nil)
    }

    /// Memperbarui baris data yang diedit dari ``KelasVC``.
    /// Notifikasi ini berasal dari `.updateDataKelas`
    /// - Parameter notification: Objek `Notification` yang membawah data notifikasi.
    @objc func updateDataNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tableType = userInfo["tableType"] as? TableType,
              let editedKelasID = userInfo["editedKelasIDs"] as? Int64,
              let editedSiswaID = userInfo["siswaID"] as? Int64,
              let columnIdentifier = userInfo["columnIdentifier"] as? String,
              let dataBaru = userInfo["dataBaru"] as? String
        else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            // Pilih model berdasarkan tableType dan lakukan operasi yang sesuai
            let modifiableModel = self.viewModel.kelasModelForTable(tableType)
            guard modifiableModel.contains(where: { $0.siswaID == editedSiswaID }),
                  let indexOfKelasID = modifiableModel.firstIndex(where: { $0.kelasID == editedKelasID }),
                  let table = self.getTableView(for: tableType.rawValue)
            else { return }
            self.viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: indexOfKelasID, newValue: dataBaru, modelArray: modifiableModel, tableView: table, kelasId: editedKelasID)

            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: IndexSet([indexOfKelasID]), columnIndexes: IndexSet(integersIn: 0 ..< table.numberOfColumns))
                self.updateSemesterTeks()
            }
        }
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
    @IBAction func saveButton(_ sender: Any) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }

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
                    self.performDatabaseOperations {}
                } else {
                    self.dataButuhDisimpan = true
                    return
                }
            }
        }
    }

    /// Menyimpan ID unik dari data yang baru dimasukkan ke tabel dan database.
    /// Nilai-nilai ini kemudian dikumpulkan sebagai satu batch ke dalam ``pastedKelasID`` untuk mendukung undo/redo.
    var pastedKelasIDs: [Int64] = []

    /// Menyimpan riwayat batch ``pastedKelasIDs`` sebagai array bertingkat (array of arrays) untuk mendukung undo/redo.
    /// Setiap elemen mewakili satu aksi tempel (paste) data.
    var pastedKelasID: [[Int64]] = []

    /// Array tuple dictionary yang menyimpan data yang di-paste untuk keperluan undo/redo.
    var pastedData: [(table: Table, data: [KelasModels])] = []

    /// Memilih dan menampilkan tab yang sesuai untuk kelas tertentu.
    /// Fungsi ini memperbarui `NSSegmentedControl` (``kelasSC``) dan `NSTabView` (``tabView``)
    /// untuk menyorot dan menampilkan kelas yang dipilih berdasarkan `TableType` yang diberikan.
    ///
    /// - Parameter tableType: Enum `TableType` yang merepresentasikan kelas yang akan dipilih.
    func pilihKelas(_ tableType: TableType) {
        switch tableType {
        case .kelas1:
            kelasSC.selectSegment(withTag: 0)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 1", forSegment: 0)
        case .kelas2:
            kelasSC.selectSegment(withTag: 1)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 2", forSegment: 1)
        case .kelas3:
            kelasSC.selectSegment(withTag: 2)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 3", forSegment: 2)
        case .kelas4:
            kelasSC.selectSegment(withTag: 3)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 4", forSegment: 3)
        case .kelas5:
            kelasSC.selectSegment(withTag: 4)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 5", forSegment: 4)
        case .kelas6:
            kelasSC.selectSegment(withTag: 5)
            tabView.selectTabViewItem(at: kelasSC.selectedSegment)
            kelasSC.setLabel("Kelas 6", forSegment: 5)
        }
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
        guard !pastedKelasID.isEmpty, let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        pilihKelas(tableType)
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = pastedKelasID.removeLast()
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

        // Simpan data yang dihapus untuk kemudian di-undo
        var dataDihapus: [KelasModels] = []
        // Simpan indeks yang akan dihapus dari targetModel
        var indexesToRemove: [Int] = []
        table.beginUpdates()
        // Iterasi melalui model data untuk mencari kelasID yang sesuai
        for (index, model) in targetModel.enumerated().reversed() {
            if allIDs.contains(model.kelasID) {
                // Buat instance baru dari KelasModels dengan menggunakan properti dari data yang dihapus
                let deletedData = KelasModels(
                    kelasID: model.kelasID,
                    siswaID: model.siswaID,
                    namasiswa: model.namasiswa,
                    mapel: model.mapel,
                    nilai: model.nilai,
                    namaguru: model.namaguru,
                    semester: model.semester,
                    tanggal: model.tanggal
                )

                // Tambahkan data yang dihapus ke dalam array dataDihapus
                dataDihapus.append(deletedData)
                viewModel.removeData(index: index, tableType: tableType)
                // Tambahkan indeks ke dalam array indexesToRemove
                indexesToRemove.append(index)
            }
        }

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
        pastedData.append((table: lastDeletedTable, data: dataDihapus))

        if let maxIndex = indexesToRemove.max() {
            if maxIndex == table.numberOfRows {
                table.scrollRowToVisible(maxIndex - 1)
            } else {
                table.scrollRowToVisible(maxIndex)
            }
            for segmentIndex in 0 ..< kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
        }
        myUndoManager?.beginUndoGrouping()
        // Daftarkan undo untuk aksi redo yang dilakukan
        myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.redoPaste(tableType: tableType, table: table)
        }
        myUndoManager?.endUndoGrouping()
        // Perbarui tampilan setelah penghapusan berhasil dilakukan

        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        updateUndoRedo(self)
        updateSemesterTeks()
    }

    /// Melakukan aksi redo dan paste pada tabel yang ditentukan.
    ///
    /// - Parameter tableType: Tipe tabel yang akan diproses.
    /// - Parameter table: Objek `NSTableView` yang akan dilakukan aksi redo dan paste.
    func redoPaste(tableType: TableType, table: NSTableView) {
        guard let sortDescriptor = KelasModels.siswaSortDescriptor else {
            return
        }
        pilihKelas(tableType)

        // Buat array baru untuk menyimpan semua id yang dihasilkan
        var allIDs: [Int64] = []
        var indexesToAdd: [Int] = []
        var dataArray: [(index: Int, data: KelasModels)] = []
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        let pasteData = pastedData.removeLast()
        table.deselectAll(self)
        for deletedData in pasteData.data {
            let id = deletedData.kelasID
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            indexesToAdd.append(insertionIndex)
            dataArray.append((index: selectedIndex, data: deletedData))
            allIDs.append(id)
        }
        table.beginUpdates()
        for index in indexesToAdd {
            table.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: true)
        }
        table.endUpdates()
        if let maxIndex = indexesToAdd.max() {
            table.scrollRowToVisible(maxIndex)
            for segmentIndex in 0 ..< kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
        }
        // Tambahkan semua id yang dihasilkan ke dalam kelasID
        pastedKelasID.append(allIDs)
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": dataArray])
        myUndoManager?.beginUndoGrouping()
        myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoPaste(table: table, tableType: tableType)
        }
        myUndoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
    }

    /// Memperbarui tampilan tabel ketika ada notifikasi data yang baru ditambahkan.
    /// - Parameter notification: Notifikasi yang memicu pembaruan tabel.
    @objc func updateTable(_ notification: Notification) {
        var table: NSTableView?
        var dataArray: [(index: Int, data: KelasModels)] = []
        // Panggil insertRow atau fungsi terkait di sini
        if let userInfo = notification.userInfo {
            if let index = userInfo["index"] as? Int, let data = userInfo["data"] as? KelasModels {
                #if DEBUG
                    print("index:", index, "data", data.mapel)
                #endif
                dataArray.append((index: index, data: data))
                guard data.siswaID == siswa?.id else { return }
                insertRow(forIndex: index, withData: data)
                switch index {
                case 0:
                    table = table1
                    activateSelectedTable()
                    if isDataLoaded[table1] == nil || !(isDataLoaded[table1] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table1)
                        isDataLoaded[table1] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 0)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 1", forSegment: 0)
                case 1:
                    kelasSC.selectSegment(withTag: 1)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 2", forSegment: 1)
                    table = table2
                    if isDataLoaded[table2] == nil || !(isDataLoaded[table2] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table2)
                        isDataLoaded[table2] = true
                    }
                    setupSortDescriptor()
                case 2:
                    if isDataLoaded[table3] == nil || !(isDataLoaded[table3] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table3)
                        isDataLoaded[table3] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 2)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 3", forSegment: 2)
                    table = table3
                case 3:
                    if isDataLoaded[table4] == nil || !(isDataLoaded[table4] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table4)
                        isDataLoaded[table4] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 3)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 4", forSegment: 3)
                    table = table4
                case 4:
                    if isDataLoaded[table2] == nil || !(isDataLoaded[table2] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table2)
                        isDataLoaded[table2] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 4)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 5", forSegment: 4)
                    table = table5
                case 5:
                    if isDataLoaded[table6] == nil || !(isDataLoaded[table6] ?? false) {
                        // Load data for the table view
                        loadTableData(tableView: table6)
                        isDataLoaded[table6] = true
                    }
                    setupSortDescriptor()
                    kelasSC.selectSegment(withTag: 5)
                    tabView.selectTabViewItem(at: kelasSC.selectedSegment)
                    kelasSC.setLabel("Kelas 6", forSegment: 5)
                    table = table6
                default:
                    break
                }
                if isPasteing == false {
                    pastedKelasIDs.append(data.kelasID)
                }
            }
        }
        guard let activeTable = table else { return }
        let tableType = tableTypeForTable(activeTable)
        deleteRedoArray(notification)
        if isPasteing == false {
            myUndoManager?.beginUndoGrouping()
            myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
                self?.undoPaste(table: activeTable, tableType: tableType)
            }
            myUndoManager?.endUndoGrouping()
            pastedKelasID.append(pastedKelasIDs)
            pastedKelasIDs.removeAll()
            for segmentIndex in 0 ..< kelasSC.segmentCount {
                if segmentIndex != kelasSC.selectedSegment {
                    kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
                }
            }
            updateSemesterTeks()
        }
        let notif = notification.userInfo
        guard notif?["kelasAktif"] as? Bool == true else { return }
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": index, "data": dataArray])
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
        KelasModels.siswaSortDescriptor = tableView?.sortDescriptors.first
        return KelasModels.siswaSortDescriptor
    }

    /// Menyisipkan baris baru pada tableView yang sesuai dengan data yang diberikan.
    /// - Parameters:
    ///   - index: Indeks untuk tableView yang sesuai dengan data yang akan disisipkan.
    ///   - data: Data kelas yang akan disisipkan ke dalam tableView.
    /// - Returns: Nilai indeks baris yang disisipkan, atau `nil` jika penyisipan gagal.
    func insertRow(forIndex index: Int, withData data: KelasModels) {
        // Determine the NSTableView based on index
        guard let sortDescriptor = getCurrentSortDescriptor(for: index) else {
            return
        }
        guard let tableType = TableType(rawValue: index) else {
            return
        }

        // Memanggil viewModel untuk menyisipkan data
        guard let rowInsertion = viewModel.insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else { return }
        let tableView = getTableView(for: index)
        // Insert the new row in the NSTableView
        tableView?.insertRows(at: IndexSet(integer: rowInsertion), withAnimation: .slideUp)
        tableView?.selectRowIndexes(IndexSet(integer: rowInsertion), byExtendingSelection: true)
        tableView?.scrollRowToVisible(rowInsertion)
    }

    ///  Fungsi untuk memuat data dari database. Dijalankan ketika suatu tabel
    /// ditampilkan pertama kali atau ketika memuat ulang tabel.
    /// - Parameter tableView: `NSTableView` yang ingin dimuat datanya.
    func loadTableData(tableView: NSTableView) {
        guard let activeTable = activeTable() else { return }
        setupSortDescriptor()
        setActiveTable(activeTable)
        activeTable.sortDescriptors.removeAll()
        let sortDescriptor = viewModel.getSortDescriptorDetil(forTableIdentifier: createStringForActiveTable())
        applySortDescriptor(tableView: activeTable, sortDescriptor: sortDescriptor)
        updateSemesterTeks()
        KelasModels.siswaSortDescriptor = activeTable.sortDescriptors.first
        viewModel.loadSiswaData(forTableType: tableTypeForTable(activeTable), siswaID: siswa?.id ?? 0)
        ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: ["mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
        activeTable.reloadData()
    
        ReusableFunc.delegateEditorManager(activeTable, viewController: self)
    }

    /// Fungsi ini menangani aksi klik ganda pada tabel untuk membuka rincian siswa.
    /// - Parameter sender: Objek pemicu `NSTableView`.
    @objc func tableViewDoubleClick(_ sender: Any) {
        guard let table = activeTable(), table.selectedRow >= 0 else { return }
        AppDelegate.shared.editorManager.startEditing(row: table.clickedRow, column: table.clickedColumn)
    }

    /// Memeriksa tampilan dan memuat ulang semua data di tabel.
    /// - Parameter sender:
    @objc func periksaTampilan(_ sender: Any) {
        activateSelectedTable()
        if let table = activeTable() {
            loadTableData(tableView: table)
            isDataLoaded[table] = true
        }
        setupSortDescriptor()
    }

    /// Memuat ulang data dan tabel ketika menu item dipilih.
    /// - Parameter sender: NSMenuItem yang memicu aksi ini.
    @objc func muatUlang(_ sender: NSMenuItem) {
        guard let (tableView, tableType) = sender.representedObject as? (NSTableView, TableType) else {
            periksaTampilan(self)
            return
        }
        let group = DispatchGroup()

        let selectedTabViewItem = tabView.selectedTabViewItem!
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)

        group.enter()
        viewModel.loadSiswaData(forTableType: tableType, siswaID: siswa!.id)
        group.leave()

        group.notify(queue: .main) { [weak self] in
            tableView.beginUpdates()
            tableView.reloadData()
            self?.populateSemesterPopUpButton()
            self?.updateValuesForSelectedTab(tabIndex: tabIndex, semesterName: self?.smstr.titleOfSelectedItem ?? "")
            tableView.endUpdates()
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
        let paste = NSMenuItem(title: "Tempel", action: #selector(updateDataArrayMenuItemClicked(_:)), keyEquivalent: "")
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

    /// Action untuk tombol/menu item paste atau ⌘V
    /// - Parameter sender:
    @IBAction func paste(_ sender: Any) {
        updateDataArrayMenuItemClicked(self)
    }

    /// Referensi untu mengetahui pakah data yang akan ditambah adalah input dari paste atau tidak.
    var isPasteing: Bool = false

    /// Fungsi yang dipanggil ketika menu item "Tempel" diklik.
    /// - Parameter sender: Objek yang memicu aksi ini, bisa berupa menu item atau komponen UI lainnya.
    @objc func updateDataArrayMenuItemClicked(_ sender: Any?) {
        // Dapatkan tabel yang dipilih
        guard let selectedTable = activeTable() else { return }
        // Dapatkan tipe tabel berdasarkan tabel yang dipilih
        guard let tableType = tableInfo.first(where: { $0.table == selectedTable })?.type else { return }
        // Dapatkan data yang terpilih dari tabel
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        selectedTable.deselectAll(self)
        let pastedDataRows = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        // Inisialisasi array untuk menampung pesan kesalahan
        var errorMessages: [String] = []
        isPasteing = true
        selectedTable.beginUpdates()
        for rowData in pastedDataRows {
            // Data berdasarkan format tab
            let pastedData = rowData.components(separatedBy: "\t")
            // Validasi dan tambahkan pesan kesalahan ke array
            if let errorMessage = validateAndAddData(tableView: selectedTable, forTableType: tableType, withPastedData: pastedData) {
                errorMessages.append(errorMessage)
            }
        }
        selectedTable.endUpdates()
        for segmentIndex in 0 ..< kelasSC.segmentCount {
            if segmentIndex != kelasSC.selectedSegment {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
        if !pastedKelasIDs.isEmpty {
            myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
                self?.undoPaste(table: selectedTable, tableType: tableType)
            }
            pastedKelasID.append(pastedKelasIDs)
            updateSemesterTeks()
            pastedKelasIDs.removeAll()
        }
        // Tampilkan NSAlert jika ada pesan kesalahan
        if !errorMessages.isEmpty {
            showWarningAlert(message: "Data Tidak Lengkap", informativeText: errorMessages.joined(separator: "\n"))
        }

        isPasteing = false
        updateUndoRedo(self)
    }

    /**
         Validasi dan tambahkan data ke tabel berdasarkan jenis tabel dan data yang ditempelkan.

         - Parameter tableView: NSTableView yang akan ditambahkan datanya.
         - Parameter tableType: Jenis tabel yang akan ditambahkan datanya.
         - Parameter pastedData: Array string yang berisi data yang ditempelkan.

         - Returns: Nilai string opsional. Mengembalikan pesan error jika validasi gagal, atau nil jika berhasil.
     */
    func validateAndAddData(tableView: NSTableView, forTableType tableType: TableType, withPastedData pastedData: [String]) -> String? {
        // Validasi Clipboard Kosong
        guard !pastedData.isEmpty else {
            return "Clipboard Kosong"
        }

        // Validasi Jumlah Elemen di Clipboard
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: Date())

        // Validasi Nilai
        if pastedData.count >= 2 {
            let nilaiString = pastedData[1]

            guard !nilaiString.isEmpty, let nilai = Int(nilaiString) else {
                return "Format Nilai Salah. Pisahkan setiap kolom menggunakan [TAB]"
            }

            // Seluruh bagian di bawah ini tetap sama
            var dataArray: [KelasModels] = []

            switch tableType {
            case .kelas1, .kelas2, .kelas3, .kelas4, .kelas5, .kelas6:
                dataArray = viewModel.kelasModelForTable(tableType)
            }
            let newKelasData = KelasModels(kelasID: 0, siswaID: siswa?.id ?? 0, namasiswa: siswa?.nama ?? "", mapel: pastedData[0], nilai: Int64(nilai), namaguru: pastedData[3], semester: pastedData[2], tanggal: tanggalSekarang)

            dataArray.append(newKelasData)

            var lastInsertedKelasIds: [Int] = []
            if let selectedTable = SingletonData.dbTable(forTableType: tableType) {
                if let kelasId = dbController.insertDataToKelas(table: selectedTable, siswaID: newKelasData.siswaID, namaSiswa: newKelasData.namasiswa, mapel: newKelasData.mapel, namaguru: newKelasData.namaguru, nilai: newKelasData.nilai, semester: newKelasData.semester, tanggal: newKelasData.tanggal) {
                    lastInsertedKelasIds.append(Int(kelasId))
                    updateModelData(withKelasId: Int64(kelasId), siswaID: newKelasData.siswaID, namasiswa: newKelasData.namasiswa, mapel: newKelasData.mapel, nilai: newKelasData.nilai, semester: newKelasData.semester, namaguru: newKelasData.namaguru, tanggal: newKelasData.tanggal)
                    pastedKelasIDs.append(kelasId)
                } else {}
            }
        } else {
            // Jika tidak ada elemen nilai, tambahkan pesan kesalahan
            return "Format Nilai Salah"
        }

        // Tidak ada kesalahan, kembalikan nil
        return nil
    }

    /**
     Memperbarui data model dengan informasi siswa yang diberikan untuk notifikasi.

     - Parameter kelasId: ID kelas siswa.
     - Parameter siswaID: ID siswa.
     - Parameter namasiswa: Nama siswa.
     - Parameter mapel: Mata pelajaran.
     - Parameter nilai: Nilai siswa.
     - Parameter semester: Semester.
     - Parameter namaguru: Nama guru.
     - Parameter tanggal: Tanggal.
     */
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        // Mendapatkan indeks yang dipilih dari kelasPopUpButton
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        // Menggunakan case statement untuk menentukan model data berdasarkan indeks
        var kelasModel: KelasModels?
        switch selectedIndex {
        case 0:
            kelasModel = Kelas1Model()
        case 1:
            kelasModel = Kelas2Model()
        case 2:
            kelasModel = Kelas3Model()
        case 3:
            kelasModel = Kelas4Model()
        case 4:
            kelasModel = Kelas5Model()
        case 5:
            kelasModel = Kelas6Model()
        default:
            break
        }

        // Pastikan kelasModel tidak nil sebelum mengakses propertinya
        guard let validKelasModel = kelasModel else { return }
        // Update the model data based on kelasId
        validKelasModel.kelasID = kelasId
        validKelasModel.siswaID = siswaID
        validKelasModel.namasiswa = namasiswa
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal

        if siswa?.id == siswaID {
            NotificationCenter.default.post(name: .updateTableNotificationDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": validKelasModel])
        } else {
            return
        }
    }

    /// Action untuk ``opsiSiswa``.
    /// - Parameter sender: Harus berupa `NSPopUpButton`.
    @IBAction func pilihanSiswa(_ sender: NSPopUpButton) {
        guard let id = siswa?.id else { return }
        let selectedSiswa = dbController.getSiswa(idValue: id)
        if sender.titleOfSelectedItem == "Salin NIK/NIS" {
            let copiedData = "\(selectedSiswa.nis)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "NIK/NIS \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin NISN" {
            let copiedData = "\(selectedSiswa.nisn)"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "NISN \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Salin Semua Data" {
            let copiedData = "\(selectedSiswa.nama)\t\(selectedSiswa.alamat)\t\(selectedSiswa.ttl)\t\(selectedSiswa.tahundaftar)\t\(selectedSiswa.namawali)\t\(selectedSiswa.nis)\t \(selectedSiswa.nisn)\t\(selectedSiswa.ayah)\t\(selectedSiswa.ibu)\t\(selectedSiswa.tlv)\t\(selectedSiswa.jeniskelamin)\t\(selectedSiswa.kelasSekarang)\t\(selectedSiswa.status)\t\(selectedSiswa.tanggalberhenti)\n"
            // Salin data ke clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(copiedData, forType: .string)
            ReusableFunc.showProgressWindow(view, pesan: "Data Lengkap \"\(selectedSiswa.nama)\" Berhasil Disalin", image: NSImage(named: NSImage.menuOnStateTemplateName)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ReusableFunc.closeProgressWindow()
            }
        } else if sender.titleOfSelectedItem == "Info Lengkap Siswa" {
            alert.messageText = "\(selectedSiswa.nama)"
            alert.icon = NSImage(named: "image")
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self else { return }
                let foto = self.dbController.bacaFotoSiswa(idValue: self.siswa?.id ?? 0)
                let data = foto.foto
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
                        self.alert.icon = paddedImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alert.icon = NSImage(named: "image")
                    }
                }
            }
            alert.informativeText = "Alamat: \(selectedSiswa.alamat)\nTTL: \(selectedSiswa.ttl)\nTahun Daftar: \(selectedSiswa.tahundaftar)\nNama Wali: \(selectedSiswa.namawali)\nNIK: \(selectedSiswa.nis)\nNISN: \(selectedSiswa.nisn)\nAyah Kandung: \(selectedSiswa.ayah)\nIbu Kandung: \(selectedSiswa.ibu)\nNo. Tlv: \(selectedSiswa.tlv)\nJenis Kelamin: \(selectedSiswa.jeniskelamin)\nStatus: \(selectedSiswa.status)\nKelas Sekarang: \(selectedSiswa.kelasSekarang)\nTanggal Berhenti: \(selectedSiswa.tanggalberhenti)"
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
        tabView.selectTabViewItem(at: selectedSegment)
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

    /// Menampilkan dialog peringatan.
    /// - Parameters:
    ///   - message: String untuk `alert.messageText`.
    ///   - informativeText: String untuk `alert.informativeText`.
    func showWarningAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "No Data Bordered")
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /**
     Handler untuk menu konteks "Salin" pada tabel nilai siswa.

     Fungsi ini akan menyalin data baris pada tabel sesuai konteks klik kanan:
     - Jika baris yang diklik juga sedang terseleksi (bagian dari beberapa baris yang dipilih), maka akan menyalin semua baris yang terseleksi.
     - Jika baris yang diklik **tidak** sedang terseleksi, maka hanya baris yang diklik saja yang akan disalin.

     - Parameter sender: NSMenuItem yang memicu aksi ini.
     */
    @objc func copyMenuItemClicked(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
              let tableInfo = tableInfo.first(where: { $0.table == tableView })
        else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)

        if tableView.clickedRow >= 0, tableView.clickedRow < selectedDataArray.count {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih, maka panggil fungsi copySelectedRows
                copySelectedRows(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih, maka panggil fungsi copyClickedRow
                copyClickedRow(sender)
            }
        }
    }

    /**
     Menyalin data dari baris yang diklik di tampilan tabel yang ditentukan ke clipboard.

     Fungsi ini adalah tindakan yang dipicu oleh klik item menu. Ia mengambil data dari baris yang dipilih dari tampilan tabel, memformatnya sebagai string yang dipisahkan tab, dan menyalinnya ke clipboard sistem.

     - Parameter sender: `NSMenuItem` yang memicu tindakan. `representedObject` dari item menu harus berupa `NSTableView` dari mana data disalin.
     */
    @objc func copyClickedRow(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
              let tableInfo = tableInfo.first(where: { $0.table == tableView })
        else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.clickedRow >= 0, tableView.clickedRow < selectedDataArray.count else { return }
        let selectedRow = tableView.clickedRow
        let dataToCopy = selectedDataArray[selectedRow]

        // Gabungkan semua data dari baris yang diklik dengan tab sebagai separator
        let klikData = "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)"

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(klikData, forType: .string)
    }

    /**
     Menyalin data dari seluruh baris yang dipilih pada tabel ke clipboard.

     Fungsi ini akan mengambil semua baris yang sedang dipilih (selectedRowIndexes) pada tabel aktif,
     lalu menggabungkan data setiap baris (mapel, nilai, semester, nama guru, tanggal) menjadi satu string
     dengan pemisah tab (`\t`) antar kolom dan baris baru (`\n`) antar baris.
     Hasil gabungan ini kemudian disalin ke clipboard (NSPasteboard) sehingga bisa ditempel di aplikasi lain.

     - Parameter sender: NSMenuItem yang memicu aksi ini.
     */
    @objc func copySelectedRows(_ sender: NSMenuItem) {
        guard let tableView = activeTable(),
              !tableView.selectedRowIndexes.isEmpty else { return }
        let selectedDataArray = viewModel.kelasModelForTable(tableTypeForTable(tableView))
        // Membuat string untuk menyimpan data yang akan disalin
        var combinedData = ""
        // Mengumpulkan data dari seluruh baris yang dipilih dengan tab sebagai separator
        for rowIndex in tableView.selectedRowIndexes {
            let selectedRow = rowIndex
            let dataToCopy = selectedDataArray[selectedRow]
            combinedData += "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)\n"
        }

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedData, forType: .string)
    }

    @objc func copyRows(_ sender: Any) {
        guard let tableView = activeTable(),
              let tableInfo = tableInfo.first(where: { $0.table == tableView }),
              !tableView.selectedRowIndexes.isEmpty
        else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        var combinedData = ""

        // Mengumpulkan data dari seluruh baris yang dipilih dengan tab sebagai separator
        for rowIndex in tableView.selectedRowIndexes {
            let selectedRow = rowIndex
            let dataToCopy = selectedDataArray[selectedRow]
            combinedData += "\(dataToCopy.mapel)\t\(dataToCopy.nilai)\t\(dataToCopy.semester)\t\(dataToCopy.namaguru)\t\(dataToCopy.tanggal)\n"
        }

        // Salin data ke clipboard (pasteboard)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedData, forType: .string)
    }

    /// Fungsi ini memperbarui action dan target menu item di Menu Bar.
    /// - Parameter sender: Objek pemicu yang dapat berupa `Any?`.
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
           let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
           let delete = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" })
        {
            // Mendapatkan NSTableView aktif
            if let activeTableView = activeTable() {
                let isRowSelected = activeTableView.selectedRowIndexes.count > 0
                copyMenuItem.isEnabled = isRowSelected
                pasteMenuItem.target = self
                pasteMenuItem.action = #selector(updateDataArrayMenuItemClicked(_:))
                // Update item menu "Delete"
                delete.isEnabled = isRowSelected
                if isRowSelected {
                    copyMenuItem.target = self
                    copyMenuItem.action = #selector(copySelectedRows(_:))

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
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_ sender: Any?) {
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let mainMenu = NSApp.mainMenu,
                  let editMenuItem = mainMenu.item(withTitle: "Edit"),
                  let editMenu = editMenuItem.submenu,
                  let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
                  let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" }),
                  let undoManager = self.myUndoManager
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
                undoMenuItem.action = #selector(self.undoDetil(_:))
                undoMenuItem.isEnabled = canUndo
            }

            if !canRedo {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            } else {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(self.redoDetil(_:))
                redoMenuItem.isEnabled = canRedo
            }
        }
    }

    /**
         Menangani aksi penghapusan item dari tabel berdasarkan item menu yang diklik.

         Fungsi ini dipanggil ketika sebuah item menu yang terkait dengan penghapusan dipilih. Fungsi ini menentukan item mana yang akan dihapus berdasarkan baris yang diklik dan baris yang dipilih dalam tabel.

         - Parameter sender: `NSMenuItem` yang memicu aksi ini. `representedObject` dari menu item harus berupa tuple yang berisi `NSTableView` dan `TableType`.

         Proses:
         1. Memastikan bahwa `representedObject` dari `sender` dapat di-cast menjadi tuple `(NSTableView, TableType)` dan bahwa database untuk `TableType` yang diberikan tersedia. Jika tidak, fungsi akan keluar.
         2. Mendapatkan indeks baris yang diklik (`clickedRow`) dan set indeks baris yang dipilih (`selectedRowIndexes`) dari tabel.
         3. Memastikan bahwa `clickedRow` valid (yaitu, lebih besar atau sama dengan 0). Jika tidak, fungsi akan keluar.
         4. Memeriksa apakah `clickedRow` termasuk dalam `selectedRowIndexes`.
            - Jika ya, fungsi `hapusPilih(tableType:table:selectedIndexes:)` dipanggil untuk menghapus semua baris yang dipilih.
            - Jika tidak, fungsi `hapusKlik(tableType:table:clickedRow:)` dipanggil untuk menghapus hanya baris yang diklik.
     */
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let (table, tableType) = sender.representedObject as? (NSTableView, TableType),
              let _ = SingletonData.dbTable(forTableType: tableType) else { return }

        let selectedRow = table.clickedRow
        let selectedIndexes = table.selectedRowIndexes

        guard selectedRow >= 0 else { return }
        if selectedIndexes.contains(selectedRow) {
            hapusPilih(tableType: tableType, table: table, selectedIndexes: selectedIndexes)
        } else {
            // Jika clickedRow bukan bagian dari selectedRows, panggil fungsi hapusKlik
            hapusKlik(tableType: tableType, table: table, clickedRow: selectedRow)
        }
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
    @objc func hapus(_ sender: Any) {
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
            let modelArray = viewModel.kelasModelForTable(tableType)

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
    var deletedDataArray: [(table: Table, data: [KelasModels])] = []
    /**
         KelasID adalah array dua dimensi yang menyimpan ID kelas.

         Setiap elemen dalam array luar mewakili satu set ID kelas.
         Setiap elemen dalam array dalam mewakili satu ID kelas dalam set tersebut.
     */
    var kelasID: [[Int64]] = []

    /// Menentukan subclass yang benar dari ``KelasModels`` untuk setiap data kelas.
    var targetModel: [KelasModels] = []

    /**
         Menghapus baris yang diklik dari tabel yang ditentukan.

         Fungsi ini menghapus data siswa dari tabel yang dipilih, menyimpan data yang dihapus untuk keperluan undo,
         dan memperbarui tampilan serta data yang terkait.

         - Parameter tableType: Jenis tabel yang sedang dioperasikan (misalnya, `TableType.kelas`, `TableType.siswa`).
         - Parameter table: Objek `NSTableView` yang sedang dimodifikasi.
         - Parameter clickedRow: Indeks baris yang diklik dan akan dihapus.

         **Proses:**
         1.  Memastikan `currentClassTable` tersedia berdasarkan `tableType`.
         2.  Mengambil array data yang sesuai dengan `tableType` dari `viewModel`.
         3.  Menghapus data dari `redoArray`.
         4.  Mendapatkan `kelasID` dari data yang akan dihapus.
         5.  Menyimpan data yang dihapus ke dalam `deletedDataArray` untuk keperluan undo.
         6.  Menyimpan `kelasID` dan `siswaID` yang dihapus ke dalam `SingletonData.deletedKelasAndSiswaIDs`.
         7.  Memperbarui seleksi baris pada tabel. Jika baris yang dihapus adalah baris terakhir, baris sebelumnya akan dipilih. Jika tidak, baris berikutnya akan dipilih.
         8.  Menghapus baris dari tabel dengan animasi slide down.
         9.  Menghapus data dari `viewModel` berdasarkan indeks dan `tableType`.
         10. Mendaftarkan operasi undo dengan `UndoManager`.
         11. Memperbarui status undo/redo.
         12. Memperbarui teks semester.
         13. Memposting notifikasi untuk mencari data yang dihapus setelah penundaan singkat.

         **Catatan:** Fungsi ini menggunakan `SingletonData` untuk mengakses dan memanipulasi data tabel. Fungsi ini juga menggunakan `viewModel` untuk mengelola data dan `undoManager` untuk mendukung operasi undo/redo.
     */
    func hapusKlik(tableType: TableType, table: NSTableView, clickedRow: Int) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        deleteRedoArray(self)
        let kelasID = dataArray[clickedRow].kelasID

        // Simpan data sebelum dihapus ke dalam deletedDataArray
        let deletedData = dataArray[clickedRow]
        deletedDataArray.append((table: currentClassTable, data: [deletedData]))
        SingletonData.deletedKelasAndSiswaIDs.append([(kelasID: deletedData.kelasID, siswaID: deletedData.siswaID)])

        if clickedRow == table.numberOfRows {
            table.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            table.selectRowIndexes(IndexSet(integer: clickedRow + 1), byExtendingSelection: false)
        }
        table.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideDown)
        viewModel.removeData(index: clickedRow, tableType: tableType)
        myUndoManager?.beginUndoGrouping()
        myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        myUndoManager?.setActionName("Undo Hapus Data Siswa")
        myUndoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": kelasID, "hapusData": true])
        }
    }

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
     *    dan fungsi pembantu seperti `SingletonData.dbTable(forTableType:)`,
     *    `viewModel.kelasModelForTable(_:)`, `deleteRedoArray(_:)`, `viewModel.removeData(index:tableType:)`,
     *    `undoHapus(tableType:table:)`, `updateUndoRedo(_:)`, dan `updateSemesterTeks()`.
     *
     *  - Versi: 1.0
     */
    func hapusPilih(tableType: TableType, table: NSTableView, selectedIndexes: IndexSet) {
        guard let currentClassTable = SingletonData.dbTable(forTableType: tableType) else {
            return
        }
        let dataArray = viewModel.kelasModelForTable(tableType)
        // Bersihkan array kelasID
        deleteRedoArray(self)
        // Tampung semua data yang akan dihapus ke dalam deletedDataArray di luar loop
        var selectedDataToDelete: [KelasModels] = []
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []
        var allIDs: [Int64] = []
        // Ambil indeks baris terakhir yang dipilih sebelumnya
        var rowToSelect: Int?
        for selectedRow in selectedIndexes.reversed() {
            if selectedRow < dataArray.count {
                let deletedData = dataArray[selectedRow]
                allIDs.append(deletedData.kelasID)
                selectedDataToDelete.append(deletedData)
                deletedKelasAndSiswaIDs.append((kelasID: deletedData.kelasID, siswaID: deletedData.siswaID))
                // Hapus data dari model berdasarkan tableType
                viewModel.removeData(index: selectedRow, tableType: tableType)
            }
        }

        // Setelah loop, tambahkan semua data yang akan dihapus ke dalam deletedDataArray
        deletedDataArray.append((table: currentClassTable, data: selectedDataToDelete))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Mulai dan akhiri update tabel untuk menghapus baris terpilih
        table.beginUpdates()
        table.removeRows(at: selectedIndexes, withAnimation: .slideUp)
        table.endUpdates()
        let totalRowsAfterDeletion = table.numberOfRows
        if totalRowsAfterDeletion > 0 {
            // Pilih baris terakhir yang valid
            rowToSelect = min(totalRowsAfterDeletion - 1, selectedIndexes.first ?? 0)
            table.selectRowIndexes(IndexSet(integer: rowToSelect!), byExtendingSelection: false)
        } else {
            // Tidak ada baris yang tersisa, batalkan seleksi
            table.deselectAll(nil)
        }

        // Daftarkan undo untuk aksi hapus yang dilakukan
        myUndoManager?.beginUndoGrouping()
        myUndoManager?.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoHapus(tableType: tableType, table: table)
        })
        myUndoManager?.endUndoGrouping()

        // Cetak jumlah data yang telah dihapus ke konsol

        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        }
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
        guard let sortDescriptor = KelasModels.siswaSortDescriptor else {
            return
        }
        activateTable(table)
        table.deselectAll(self)
        var lastIndex: [Int] = []
        // Buat array baru untuk menyimpan semua id yang dihasilkan
        var allIDs: [Int64] = []
        var dataArray: [(index: Int, data: KelasModels)] = []
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        table.beginUpdates()
        let dataYangDihapus = deletedDataArray.removeLast()
        for deletedData in dataYangDihapus.data {
            let id = deletedData.kelasID
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            if let newData = viewModel.modelForRow(at: insertionIndex, tableType: tableType) {
                dataArray.append((index: selectedIndex, data: newData))
            }
            table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: .slideDown)
            table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
            lastIndex.append(insertionIndex)
            allIDs.append(id)
        }
        table.endUpdates()
        if let indeksAkhir = lastIndex.max() {
            table.scrollRowToVisible(indeksAkhir)
        }
        // Tambahkan semua id yang dihasilkan ke dalam kelasID
        kelasID.append(allIDs)
        NotificationCenter.default.post(name: .updateRedoInDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": dataArray])
        myUndoManager?.beginUndoGrouping()
        myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.redoHapus(table: table, tableType: tableType)
        }
        myUndoManager?.setActionName("Redo Hapus Data Siswa")
        myUndoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        SingletonData.deletedKelasAndSiswaIDs.removeAll { kelasSiswaPairs in
            kelasSiswaPairs.contains { pair in
                allIDs.contains(pair.kelasID)
            }
        }
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
     * - Precondition: `kelasID` tidak boleh kosong dan `SingletonData.dbTable(forTableType: tableType)` harus mengembalikan nilai yang valid.
     *
     * - Postcondition: Data yang sesuai akan dihapus dari `targetModel` dan `NSTableView`, dan operasi "undo" akan didaftarkan.
     *
     * - Note: Fungsi ini menggunakan `undoManager` untuk mendaftarkan operasi "undo" dan `NotificationCenter` untuk mengirim notifikasi tentang data yang dihapus.
     */
    func redoHapus(table: NSTableView, tableType: TableType) {
        guard !kelasID.isEmpty, let currentClassTable = SingletonData.dbTable(forTableType: tableType) else { return }
        // Ambil semua ID dari array kelasID terakhir
        let allIDs = kelasID.removeLast()
        activateTable(table)
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

        guard let result = viewModel.removeData(withIDs: allIDs, fromModel: &targetModel, forTableType: tableType) else {
            return
        }
        // Iterasi melalui model data untuk mencari kelasID yang sesuai
        let (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs) = result
        // Hapus baris-baris yang sesuai dari targetModel dan NSTableView
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
        // Tambahkan data yang dihapus ke dalam deletedDataArray
        deletedDataArray.append((table: currentClassTable, data: dataDihapus))
        SingletonData.deletedKelasAndSiswaIDs.append(deletedKelasAndSiswaIDs)
        // Daftarkan undo untuk aksi redo yang dilakukan
        myUndoManager?.beginUndoGrouping()
        myUndoManager?.registerUndo(withTarget: self) { [weak self] targetSelf in
            self?.undoHapus(tableType: tableType, table: table)
        }
        myUndoManager?.setActionName("Redo Hapus Data Siswa")
        myUndoManager?.endUndoGrouping()
        updateUndoRedo(self)
        updateSemesterTeks()
        guard let selectedTabViewItem = tabView.selectedTabViewItem else { return }
        let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let selectedIndex = selectedTabIndex
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .findDeletedData, object: nil, userInfo: ["index": selectedIndex, "ID": allIDs, "hapusData": true])
        }
    }

    /**
     Menangani aksi ketika item menu hapus ditekan.

     Fungsi ini menghapus data kelas yang dipilih dari tabel yang aktif.
     Pertama, fungsi ini memastikan bahwa tabel yang aktif dan informasi tabel tersedia.
     Kemudian, fungsi ini mendapatkan array data yang sesuai dengan jenis tabel.
     Selanjutnya, fungsi ini memastikan bahwa baris yang dipilih valid.
     Setelah itu, fungsi ini mendapatkan ID kelas dari data yang dipilih.
     Kemudian, fungsi ini menghapus data dari database menggunakan `dbController`.
     Setelah data dihapus dari database, baris yang dipilih dihapus dari tampilan tabel.
     Fungsi ini juga memperbarui teks semester.
     Terakhir, fungsi ini memposting notifikasi `hapusDataSiswa` setelah penundaan singkat.

     - Parameter sender: Objek yang mengirim aksi.
     */
    @objc func deleteMenuItemPress(_ sender: Any) {
        guard let tableView = activeTable(),
              let tableInfo = tableInfo.first(where: { $0.table == tableView })
        else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.selectedRow >= 0, tableView.selectedRow < selectedDataArray.count else { return }
        let selectedRow = tableView.selectedRow
        let idDipilih = selectedDataArray[selectedRow].kelasID

        if let table = SingletonData.dbTable(forTableType: tableInfo.type) {
            dbController.deleteDataFromKelas(table: table, kelasID: idDipilih)
        }
        tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideDown)
        updateSemesterTeks()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .hapusDataSiswa, object: self)
        }
    }

    /**
     Menangani aksi ketika item menu hapus diklik.

     Fungsi ini dipanggil ketika pengguna mengklik item menu "Hapus" pada sebuah `NSTableView`. Fungsi ini menghapus baris yang dipilih dari tabel, menghapus data terkait dari database, memperbarui tampilan semester, dan mengirimkan notifikasi bahwa data siswa telah dihapus.

     - Parameter sender: `NSMenuItem` yang memicu aksi ini. `representedObject` dari menu item ini diharapkan menjadi `NSTableView`.
     */
    @objc func deleteMenuItemClicked(_ sender: NSMenuItem) {
        guard let tableView = sender.representedObject as? NSTableView,
              let tableInfo = tableInfo.first(where: { $0.table == tableView })
        else {
            return
        }
        let selectedDataArray = viewModel.kelasModelForTable(tableInfo.type)
        guard tableView.clickedRow >= 0, tableView.clickedRow < selectedDataArray.count else { return }
        let selectedRow = tableView.clickedRow
        let idDipilih = selectedDataArray[selectedRow].kelasID
        if let table = SingletonData.dbTable(forTableType: tableInfo.type) {
            dbController.deleteDataFromKelas(table: table, kelasID: idDipilih)
        }
        tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideDown)
        updateSemesterTeks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .hapusDataSiswa, object: self)
        }
    }

    /// Properti yang menyimpan ID unik di setiap data pada baris tabel yang dipilih
    /// yang digunakan untuk diseleksi ulang ketika UI tableView di muat ulang atau setelah
    /// memuat ulang seluruh data tableView.
    var selectedIDs: Set<Int64> = []

    /**
         Mengatur deskriptor pengurutan untuk setiap kolom dalam tabel. Fungsi ini mengiterasi melalui setiap kolom tabel,
         mengambil pengidentifikasi kolom, dan menetapkan deskriptor pengurutan yang sesuai dari kamus `identifikasiKolom`.
         Deskriptor pengurutan ini kemudian digunakan sebagai prototipe untuk memungkinkan pengurutan data dalam kolom tersebut.
     */
    func setupSortDescriptor() {
        let table = activeTable()
        let mapel = NSSortDescriptor(key: "mapel", ascending: true)
        let nilai = NSSortDescriptor(key: "nilai", ascending: true)
        let semester = NSSortDescriptor(key: "semester", ascending: true)
        let namaguru = NSSortDescriptor(key: "namaguru", ascending: true)
        let tgl = NSSortDescriptor(key: "tgl", ascending: true)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
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

    /**
         Menyimpan deskriptor pengurutan untuk pengidentifikasi tabel tertentu ke dalam UserDefaults.

         - Parameter sortDescriptor: Deskriptor pengurutan yang akan disimpan. Jika nil, deskriptor pengurutan yang ada akan dihapus.
         - Parameter identifier: Pengidentifikasi tabel yang terkait dengan deskriptor pengurutan. Ini digunakan sebagai bagian dari kunci UserDefaults.
     */
    func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?, forTableIdentifier identifier: String) {
        if let sortDescriptor {
            let sortDescriptorData = try? NSKeyedArchiver.archivedData(withRootObject: sortDescriptor, requiringSecureCoding: false)
            UserDefaults.standard.set(sortDescriptorData, forKey: "SortDescriptorSiswa_\(identifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "SortDescriptorSiswa_\(identifier)")
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

    @IBAction func handlePrint(_ sender: Any) {
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
                self.generatePDFForPrint(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!)
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
            try saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)

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
            print("Gagal menyimpan CSV sementara: \(error)")
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
            print("Gagal memuat file PDF untuk dicetak di lokasi: \(pdfFileURL.path)")
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
        printOperation.jobTitle = "PDF \(siswa?.nama ?? "") \(createLabelForActiveTable())"

        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printOperation.run()
    }

    /**
         Menyimpan data siswa ke dalam format CSV.

         - Parameter header: Array string yang berisi header untuk kolom CSV.
         - Parameter siswaData: Array objek `KelasModels` yang berisi data siswa yang akan disimpan.
         - Parameter destinationURL: URL tempat file CSV akan disimpan.

         - Throws: Melempar kesalahan jika terjadi masalah saat menulis ke file.
     */
    func saveToCSV(header: [String], siswaData: [KelasModels], destinationURL: URL) throws {
        // Membuat baris data siswa sebagai array dari string
        let rows = siswaData.map { [$0.mapel, String($0.nilai), String($0.semester), $0.namaguru] }

        // Menggabungkan header dengan data dan mengubahnya menjadi string CSV
        let csvString = ([header] + rows).map { $0.joined(separator: ";") }.joined(separator: "\n")

        // Menulis string CSV ke file
        try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    /**
         Mengekspor data siswa ke file Excel.

         Fungsi ini dipicu ketika pengguna memilih item menu "Ekspor ke Excel".
         Pertama, fungsi ini memeriksa apakah kelas aktif sudah siap. Jika belum, ia menampilkan pesan peringatan.
         Jika kelas aktif sudah siap, ia memeriksa apakah Python dan Pandas sudah terinstal.
         Jika Python dan Pandas sudah terinstal, ia memanggil fungsi `chooseFolderAndSaveCSV` untuk menyimpan data ke file CSV.
         Jika Python dan Pandas belum terinstal, ia menutup jendela progress.

         - Parameter sender: Item menu yang memicu fungsi ini.
     */
    @IBAction func exportToExcel(_ sender: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.chooseFolderAndSaveCSV(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: false)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /**
         Ekspor data nilai siswa ke dalam format PDF.

         Fungsi ini akan melakukan langkah-langkah berikut:
         1. Memastikan jendela tampilan tersedia. Jika tidak, menampilkan peringatan.
         2. Memeriksa apakah Python dan Pandas sudah terinstal.
         3. Jika sudah terinstal, data nilai siswa akan diekspor ke file CSV, kemudian dikonversi ke PDF.
         4. Jika belum terinstal, menutup jendela progress.

         - Parameter:
             - sender: Objek NSMenuItem yang memicu aksi ekspor.
     */
    @IBAction func exportToPDF(_ sender: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.icon = NSImage(named: "NSCaution")
            alert.messageText = "Kelas Aktif belum siap"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        ReusableFunc.checkPythonAndPandasInstallation(window: view.window!) { isInstalled, progressWindow, pythonFound in
            if isInstalled {
                let data = self.tableData
                self.chooseFolderAndSaveCSV(header: ["Mapel", "Nilai", "Semester", "Nama Guru"], siswaData: data, namaFile: "Nilai \(self.siswa!.nama) \(self.createLabelForActiveTable())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: true)
            } else {
                self.view.window?.endSheet(progressWindow!)
            }
        }
    }

    /**
         Menyimpan data siswa ke dalam format CSV dan kemudian mengonversinya ke format XLSX menggunakan skrip Python.

         Fungsi ini pertama-tama menyimpan data siswa yang diberikan ke dalam file CSV di direktori dukungan aplikasi.
         Kemudian, fungsi ini menjalankan skrip Python untuk mengonversi file CSV tersebut ke format XLSX.
         Setelah konversi selesai, pengguna akan diminta untuk memilih lokasi penyimpanan untuk file XLSX yang dihasilkan.

         - Parameter header: Array string yang berisi header untuk file CSV.
         - Parameter siswaData: Array objek `KelasModels` yang berisi data siswa yang akan disimpan.
         - Parameter namaFile: Nama file CSV yang akan dibuat (tanpa ekstensi).
         - Parameter window: Jendela NSWindow yang digunakan untuk menampilkan dialog penyimpanan.
         - Parameter sheetWindow: Jendela sheet NSWindow yang terkait dengan operasi ini.
         - Parameter pythonPath: Path ke interpreter Python yang akan digunakan untuk menjalankan skrip konversi.
         - Parameter pdf: Boolean yang menunjukkan apakah akan menghasilkan PDF atau tidak. Jika `true`, skrip Python yang berbeda akan dijalankan untuk menghasilkan PDF.

         - Catatan: Fungsi ini menggunakan ``ReusableFunc/runPythonScript(csvFileURL:window:pythonPath:completion:)`` atau ``ReusableFunc/runPythonScriptPDF(csvFileURL:window:pythonPath:completion:)`` untuk menjalankan skrip Python dan ``ReusableFunc/promptToSaveXLSXFile(from:previousFileName:window:sheetWindow:pdf:)`` untuk meminta pengguna menyimpan file XLSX.
         - Catatan: Jika terjadi kesalahan selama penyimpanan atau konversi, sheet window akan diakhiri.
     */
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
    @IBAction func tampilkanStatistik(_ sender: AnyObject) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        if let siswa {
            bukaDetil(siswaID: siswa.id)
        }
    }

    /**
     * Membuka jendela detail untuk siswa dengan ID yang diberikan.
     *
     * Fungsi ini membuat instance dari ``StatistikMurid``, mengirimkan `siswaID` ke instance tersebut,
     * mengatur nama murid untuk digunakan dalam judul jendela, dan menampilkan jendela statistik siswa.
     *
     * - Parameter:
     *   - siswaID: ID unik siswa yang akan ditampilkan detailnya.
     */
    func bukaDetil(siswaID: Int64) {
        // Lakukan sesuatu dengan siswaID, misalnya, buka jendela statistik siswa.
        let statistikSiswaVC = StatistikMurid(nibName: "StatistikMurid", bundle: nil)
        statistikSiswaVC.siswaID = siswaID // Mengirim siswaID ke jendela baru.
        let popover = NSPopover()
        popover.contentViewController = statistikSiswaVC
        popover.show(relativeTo: statistik.bounds, of: statistik, preferredEdge: .maxY)
        popover.behavior = .transient
        // Buka jendela statistik siswa.
        statistikSiswaVC.namaMurid.stringValue = "Statistik " + (siswa?.nama ?? "")
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
     1. Membuat `table` menjadi responder pertama jika ada `activeTable`.
     2. Memeriksa apakah ada siswa yang dipilih (`siswa`).
     3. Jika ada siswa yang dipilih:
        - Menginisialisasi `AddDetilSiswaUI` dari XIB.
        - Mengatur data siswa yang dipilih ke `detailViewController`.
        - Memuat dan memanggil `viewDidLoad` pada `detailViewController`.
        - Memanggil `tabDidChange` pada `detailViewController` dengan indeks tab yang dipilih.
        - Membuat dan mengkonfigurasi `NSPopover`.
        - Menetapkan `detailViewController` sebagai `contentViewController` dari popover.
        - Menampilkan popover relatif terhadap tombol yang memicu aksi.

     - Parameter:
        - sender: Objek yang memicu aksi (biasanya tombol).
     */
    @IBAction func tambahSiswaButtonClicked(_ sender: Any) {
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
        }
        if let selectedSiswa = siswa {
            // persiapan view controller dengan XIB ID (misalnya, "AddDetilSiswaUI")
            let detailViewController = AddDetilSiswaUI(nibName: "AddDetilSiswaUI", bundle: nil)
            // Atur data siswa pada tampilan detail
            detailViewController.siswa = selectedSiswa
            detailViewController.loadView()
            detailViewController.viewDidLoad()
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                detailViewController.tabDidChange(index: selectedTabIndex)
            } // persiapkan NSPopover
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.contentViewController = detailViewController

            // Tampilkan popover di dekat tombol yang memicunya
            if let button = sender as? NSButton {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                resetMenuItems()
            }
        }
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
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabViewItem), semesterName: selectedSemester)
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
        guard let selectedTabViewItem = tabView.selectedTabViewItem else {
            return
        }
        smstr.removeAllItems()

        // Menentukan model kelas berdasarkan tab yang aktif
        let tabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
        let kelasData: [KelasModels] = switch tabIndex {
        case 0:
            viewModel.kelas1Model
        case 1:
            viewModel.kelas2Model
        case 2:
            viewModel.kelas3Model
        case 3:
            viewModel.kelas4Model
        case 4:
            viewModel.kelas5Model
        case 5:
            viewModel.kelas6Model
        default:
            []
        }

        if nilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.namasiswa != "" }.map(\.semester))
        } else if semuaNilai.state == .on {
            allSemesters = Set(kelasData.filter { !$0.semester.isEmpty && $0.nilai > 0 }.map(\.semester))
        } else if bukanNilaiKelasAktif.state == .on {
            allSemesters = Set(kelasData.filter { $0.namasiswa == "" }.map(\.semester))
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

    /// Referensi data ``siswa`` untuk kalkulasi nilai yang direpresentasikan di dalam
    /// ``labelCount`` dan ``labelAverage``.
    var filteredData: [KelasModels]!

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

        var totalNilai = 0
        var averageNilai = 0.0
        // Dapatkan data kelas berdasarkan tabIndex
        var kelasData: [KelasModels] = []
        var filteredIndices: IndexSet = []
        let kelasAktifState = nilaiKelasAktif.state == .on
        let bukanKelasAktifState = bukanNilaiKelasAktif.state == .on
        let semuaNilaiState = semuaNilai.state == .on
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let semesterValue = semesterName.replacingOccurrences(of: "Semester ", with: "")

            kelasData = self.viewModel.setModel(TableType(rawValue: tabIndex)!, model: self.viewModel.getModel(for: TableType(rawValue: tabIndex)!))

            // Filter data sesuai dengan semester dan status
            if kelasAktifState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue && !$0.namasiswa.isEmpty }
                self.tableData = kelasData.filter { !$0.namasiswa.isEmpty }
            } else if semuaNilaiState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue }
                self.tableData = kelasData
            } else if bukanKelasAktifState {
                self.filteredData = kelasData.filter { $0.semester == semesterValue && $0.namasiswa.isEmpty }
                self.tableData = kelasData.filter(\.namasiswa.isEmpty)
            }

            // Hitung total nilai dan rata-rata
            totalNilai = self.filteredData.map { Int($0.nilai) }.reduce(0, +)
            let filteredDataCount = self.filteredData.count
            if filteredDataCount > 0 {
                averageNilai = Double(totalNilai) / Double(filteredDataCount)
            }

            // Cari indeks dari data yang difilter
            for (index, item) in kelasData.enumerated() {
                if !self.tableData.contains(where: { $0.kelasID == item.kelasID }) {
                    filteredIndices.insert(index)
                }
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            if let table = self?.activeTable() {
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = true
                    context.duration = 0.3

                    table.beginUpdates()
                    table.unhideRows(at: table.hiddenRowIndexes, withAnimation: .slideDown)
                    table.hideRows(at: filteredIndices, withAnimation: .slideUp)
                    table.endUpdates()
                }, completionHandler: { [weak self] in
                    guard let self else { return }
                    // Update label
                    self.labelCount.isSelectable = true
                    self.labelAverage.isSelectable = true
                    self.labelCount.stringValue = "Jumlah: \(totalNilai)"
                    self.labelAverage.stringValue = String(format: "Rata-rata: %.2f", averageNilai)
                })
            }
        }
    }

    /**
     Memperbarui teks semester berdasarkan tab yang dipilih.

     Fungsi ini dipanggil ketika tab pada `tabView` berubah. Fungsi ini mengambil indeks tab yang dipilih dan teks semester yang dipilih dari `smstr`, kemudian memanggil `updateValuesForSelectedTab` untuk memperbarui nilai-nilai yang sesuai dengan tab dan semester yang dipilih.
     */
    @objc func updateSemesterTeks() {
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
            let selectedSemester = smstr.titleOfSelectedItem ?? ""
            updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        activateSelectedTable()
        
        if let table = activeTable() {
            view.window?.makeFirstResponder(table)
            ReusableFunc.delegateEditorManager(table, viewController: self)
        }
        else {
            view.window?.makeFirstResponder(table1)
        }
        
        DispatchQueue.main.async { [unowned self] in
            self.populateSemesterPopUpButton()
            if let selectedTabViewItem = tabView.selectedTabViewItem {
                let selectedTabIndex = tabView.indexOfTabViewItem(selectedTabViewItem)
                // Mendapatkan indeks semester yang dipilih dari NSPopUpButton
                let selectedSemester = smstr.titleOfSelectedItem ?? ""
                updateValuesForSelectedTab(tabIndex: selectedTabIndex, semesterName: selectedSemester)
            }
        }
    }

    /**
     * Mengatur tabel yang aktif dan menentukan jenis tabel yang sesuai.
     *
     * Fungsi ini menerima sebuah objek `NSTableView` sebagai input dan menentukan jenis tabel yang aktif berdasarkan tabel yang diberikan.
     * Jenis tabel yang aktif disimpan dalam properti `activeTableType`.
     *
     * - Parameter table: Objek `NSTableView` yang akan diatur sebagai tabel aktif.
     *
     * - Note: Fungsi ini membandingkan objek `table` dengan setiap properti tabel (`table1`, `table2`, `table3`, `table4`, `table5`, `table6`)
     *         dan mengatur `activeTableType` sesuai dengan jenis tabel yang cocok.
     */
    func setActiveTable(_ table: NSTableView) {
        if table == table1 {
            activeTableType = .kelas1
        } else if table == table2 {
            activeTableType = .kelas2
        } else if table == table3 {
            activeTableType = .kelas3
        } else if table == table4 {
            activeTableType = .kelas4
        } else if table == table5 {
            activeTableType = .kelas5
        } else if table == table6 {
            activeTableType = .kelas6
        }
    }

    /// Fungsi untuk menjalankan undo.
    @IBAction func undoDetil(_ sender: Any) {
        if (myUndoManager?.canUndo) != nil {
            myUndoManager?.undo()
        }
    }

    /// Fungsi untuk menjalankan redo.
    @IBAction func redoDetil(_ sender: Any) {
        if (myUndoManager?.canRedo) != nil {
            myUndoManager?.redo()
        }
    }

    /// Fungsi untuk mereset target dan action menu item di Menu Bar ke nilai aslinya
    func resetMenuItems() {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
              let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
              let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
        else {
            return
        }
        // Reset target dan action ke nilai aslinya
        undoMenuItem.target = SingletonData.originalUndoTarget
        undoMenuItem.action = SingletonData.originalUndoAction
        redoMenuItem.target = SingletonData.originalRedoTarget
        redoMenuItem.action = SingletonData.originalRedoAction
        copyMenuItem.target = SingletonData.originalCopyTarget
        copyMenuItem.action = SingletonData.originalCopyAction
        copyMenuItem.isEnabled = activeTable()!.numberOfSelectedRows != 0
        pasteMenuItem.target = SingletonData.originalPasteTarget
        pasteMenuItem.action = SingletonData.originalPasteAction
        deleteMenuItem.target = SingletonData.originalDeleteTarget
        deleteMenuItem.action = SingletonData.originalDeleteAction
    }

    /// Properti untuk menyimpan data sebelumnya yang diperbarui.
    var undoArray: [OriginalData] = []
    /// Properti untuk menyimpan data setelah pengeditan diurungkan.
    var redoArray: [OriginalData] = []

    /// Properti untuk menyimpan data sebelumnya yang diperbarui
    /// dari class lain dan diperbarui juga di class ``DetailSiswaController``
    /// setelah menerima notifikasi.
    ///
    /// Properti ini digunakan untuk menangani ketika class yang mengirim notifikas
    /// melakukan pengurungan sehingga class ``DetailSiswaController`` dapat kembali
    /// memperbarui datanya dengan data terbaru tanpa memuat ulang seluruh data
    /// dari database atau memuat ulang seluruh baris di tableView.
    var undoUpdateStack: [String: [[KelasModels]]] = [:] // Key adalah nama kelas

    /// Properti untuk menyimpan data sebelumnya yang dihapus
    /// dari class lain dan diperbarui juga di class ``DetailSiswaController``
    /// setelah menerima notifikasi.
    ///
    /// Properti ini digunakan untuk menangani ketika class yang mengirim notifikas
    /// melakukan pengurungan sehingga class ``DetailSiswaController`` dapat kembali
    /// memperbarui datanya dengan data terbaru tanpa memuat ulang seluruh data
    /// dari database atau memuat ulang seluruh baris di tableView.
    var undoStack: [TableType: [[KelasModels]]] = [:] // Key adalah nama kelas

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

    /// Dijalankan setelah menerima notifikasi `.saveData` untuk menyimpan
    /// data yang dihapus.
    @objc func receivedSaveDataNotification(_ notification: Notification) {
        guard !deletedDataArray.isEmpty || !pastedData.isEmpty else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = 0.3
            namaSiswa.animator().alphaValue = 0
        }, completionHandler: { [unowned self] in
            // Menghapus data dari deletedDataArray
            for deletedData in deletedDataArray {
                let currentClassTable = deletedData.table
                let dataArray = deletedData.data

                for data in dataArray {
                    dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                }
            }

            // Menghapus data dari pastedData
            for pastedDataItem in pastedData {
                let currentClassTable = pastedDataItem.table
                let dataArray = pastedDataItem.data

                for data in dataArray {
                    dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                }
            }

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
                    self.performDatabaseOperations {
                        completion()
                    }
                } else {
                    self.dataButuhDisimpan = true
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
        bgTask.addOperation {
            OperationQueue.main.addOperation { [weak self] in
                guard let self else { return }
                if let windowSheet = NSApplication.shared.mainWindow {
                    viewController.progressIndicator.isIndeterminate = true
                    viewController.progressIndicator.startAnimation(self)
                    windowSheet.beginSheet(windowProgress.window!)
                    self.bgTask.addOperation { [unowned self] in
                        for deletedData in self.deletedDataArray {
                            let currentClassTable = deletedData.table
                            let dataArray = deletedData.data

                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }

                        // Loop melalui pastedData
                        for pastedDataItem in self.pastedData {
                            let currentClassTable = pastedDataItem.table
                            let dataArray = pastedDataItem.data

                            for data in dataArray {
                                self.dbController.deleteDataFromKelas(table: currentClassTable, kelasID: data.kelasID)
                            }
                        }
                        OperationQueue.main.addOperation { [unowned self] in
                            self.saveData(self)
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
    }

    deinit {
        #if DEBUG
            print("deinit detailSiswaViewController")
        #endif
        topLevelObjects = nil
        viewModel.removeAllData()
        for (table, _) in tableInfo {
            table.menu = nil
            table.target = nil
            table.dataSource = nil
            table.delegate = nil
            table.headerView = nil
            table.removeFromSuperviewWithoutNeedingDisplay()
        }
        table1 = nil
        table2 = nil
        table3 = nil
        table4 = nil
        table5 = nil
        table6 = nil
        siswa = nil
        viewModel.removeAllData()
        tableData.removeAll()
        tabView.removeFromSuperviewWithoutNeedingDisplay()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .siswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoSiswaDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .kelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .undoKelasDihapus, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateUndoArray, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editDataSiswaKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editNamaGuruKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .saveData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .dataSiswaDiEditDiSiswaView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateDataKelas, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateTableNotificationDetilSiswa, object: nil)
        NotificationCenter.default.removeObserver(self, name: .addDetilSiswaUITertutup, object: nil)
        NotificationCenter.default.removeObserver(self, name: .updateNilaiTeks, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidReloadNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        view.removeFromSuperviewWithoutNeedingDisplay()
    }
}

extension DetailSiswaController {
    /// Menghapus semua array untuk redo. Ini dijalankan ketika melakukan perubahan
    /// pada data selain dari undo/redo.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    func deleteRedoArray(_ sender: Any) {
        if !redoArray.isEmpty { redoArray.removeAll() }
        if !kelasID.isEmpty { kelasID.removeAll() }
    }

    /**
     Melakukan aksi 'undo' untuk mengembalikan nilai suatu kolom tabel dan data ke nilai sebelumnya berdasarkan data `originalModel`.

     Fungsi ini mencari indeks model kelas yang sesuai, memperbarui model dan database dengan nilai lama,
     mendaftarkan aksi 'redo' ke `NSUndoManager`, menghapus nilai lama dari array 'undo',
     memperbarui tampilan sel tabel yang sesuai, dan menyimpan nilai lama ke dalam array 'redo'.

     - Parameter originalModel: Objek `OriginalData` yang berisi informasi tentang perubahan yang akan dibatalkan,
                              termasuk `kelasId`, `columnIdentifier`, `oldValue`, `tableType`, `table`, dan `tableView`.
     */
    func undoAction(originalModel: OriginalData) {
        pilihKelas(originalModel.tableType)
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        if let rowIndexToUpdate = viewModel.kelasModelForTable(originalModel.tableType).firstIndex(where: { $0.kelasID == originalModel.kelasId }) {
            // Lakukan pembaruan model dan database dengan nilai lama
            viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(originalModel.tableType), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

            // Daftarkan aksi redo ke NSUndoManager
            myUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.redoAction(originalModel: originalModel)
            })

            let userInfo: [String: Any] = [
                "columnIdentifier": originalModel.columnIdentifier,
                "tableView": createStringForActiveTable(),
                "newValue": originalModel.oldValue,
                "kelasId": originalModel.kelasId,
            ]
            NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: userInfo)
            originalModel.tableView.selectRowIndexes(IndexSet(integer: rowIndexToUpdate), byExtendingSelection: false)
            originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)
            updateSemesterTeks()
            updateUndoRedo(self)
        }
    }

    /**
     Melakukan aksi redo berdasarkan model data asli yang diberikan.

     Fungsi ini mencari indeks `kelasModels` yang sesuai dengan `originalModel`,
     kemudian memperbarui model dan database dengan nilai baru. Setelah itu,
     mendaftarkan aksi undo ke `NSUndoManager`, menghapus nilai lama dari array `redoArray`,
     memperbarui tampilan tabel, dan menyimpan nilai baru ke dalam array `undoArray`.

     - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang akan di-redo.
     */
    func redoAction(originalModel: OriginalData) {
        pilihKelas(originalModel.tableType)
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        if let rowIndexToUpdate = viewModel.kelasModelForTable(originalModel.tableType).firstIndex(where: { $0.kelasID == originalModel.kelasId }) {
            // Lakukan pembaruan model dan database dengan nilai baru
            viewModel.updateModelAndDatabase(columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.newValue, oldValue: originalModel.oldValue, modelArray: viewModel.kelasModelForTable(originalModel.tableType), table: originalModel.table, tableView: createStringForActiveTable(), kelasId: originalModel.kelasId, undo: true)

            // Daftarkan aksi undo ke NSUndoManager
            myUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.undoAction(originalModel: originalModel)
            })
            let userInfo: [String: Any] = [
                "columnIdentifier": originalModel.columnIdentifier,
                "tableView": createStringForActiveTable(),
                "newValue": originalModel.newValue,
                "kelasId": originalModel.kelasId,
            ]
            NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: userInfo)
            originalModel.tableView.selectRowIndexes(IndexSet(integer: rowIndexToUpdate), byExtendingSelection: false)
            originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)
            updateUndoRedo(self)
            updateSemesterTeks()
        }
    }

    /// Fungsi ini dijalankan ketika menerima notifikasi .editDataSiswa
    @objc func updateEditedKelas(_ notification: Notification) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
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
            case "table1": table = self.table1
            case "table2": table = self.table2
            case "table3": table = self.table3
            case "table4": table = self.table4
            case "table5": table = self.table5
            case "table6": table = self.table6
            default: break
            }
            guard let rowIndexToUpdate = self.viewModel.kelasModelForTable(tableTypeForTable(table)).firstIndex(where: { $0.kelasID == kelasId }) else { return }
            self.viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(table)), tableView: table, kelasId: kelasId)

            DispatchQueue.main.async {
                guard let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else { return }
                guard let cellView = table.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView else { return }
                if columnIdentifier == "nilai" {
                    let numericValue = Int(newValue) ?? 0
                    cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
                }
                table.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
            }
        }
    }

    /// Fungsi ini dijalankan ketika menerima notifikasi dari .editDataSiswa
    /// yang berguna untuk memperbarui baris di tableView dan data dengan data
    /// terbaru setelah pengeditan baik dari class ini ``DetailSiswaController``
    /// ataupun dari class ``KelasVC``.
    /// - Parameter notification: Notifikasi yang membawa informasi data terbaru
    ///  yang dibutuhkan untuk pembaruan.
    @objc func updatedGuruKelas(_ notification: Notification) {
        var table: EditableTableView!
        guard let userInfo = notification.userInfo as? [String: Any],
              let columnIdentifier = userInfo["columnIdentifier"] as? String,
              let activeTable = userInfo["tableView"] as? String,
              let newValue = userInfo["newValue"] as? String,
              let guruLama = userInfo["guruLama"] as? String,
              let currentMapel = userInfo["mapel"] as? String
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
        var columnIndex = Int()
        guard table != nil else {
            return
        }
        DispatchQueue.main.async {
            guard let index = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else { return }
            columnIndex = index
        }
        let modelArray = viewModel.kelasModelForTable(tableTypeForTable(table))
        if UserDefaults.standard.bool(forKey: "updateNamaGuruDiMapelDanKelasSama") {
            for (index, data) in modelArray.enumerated() {
                let mapel = data.mapel
                let namaGuru = data.namaguru
                if mapel == currentMapel {
                    guard namaGuru != newValue, !data.namasiswa.isEmpty else { continue }
                    if !UserDefaults.standard.bool(forKey: "timpaNamaGuruSebelumnya") {
                        guard namaGuru == guruLama else { continue }
                    }
                    viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: index, newValue: newValue, modelArray: modelArray, tableView: table, kelasId: data.kelasID)
                }
                DispatchQueue.main.async {
                    table.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: columnIndex))
                }
            }
        } else {
            guard let ID = userInfo["kelasId"] as? Int64,
                  let index = modelArray.firstIndex(where: { $0.kelasID == ID }),
                  modelArray[index].namaguru != newValue else { return }
            viewModel.updateKelasModel(columnIdentifier: columnIdentifier, rowIndex: index, newValue: newValue, modelArray: modelArray, tableView: table, kelasId: ID)
            DispatchQueue.main.async {
                table.reloadData(forRowIndexes: IndexSet([index]), columnIndexes: IndexSet([columnIndex]))
            }
        }
    }

    /**
     Mendapatkan tabel yang saat ini aktif dan merupakan turunan dari tampilan ini.

      Fungsi ini memeriksa setiap tabel (table1 hingga table6) untuk melihat apakah tabel tersebut adalah turunan dari tampilan saat ini.
     Jika sebuah tabel ditemukan sebagai turunan, tabel tersebut akan dikembalikan. Jika tidak ada tabel yang ditemukan sebagai turunan, fungsi ini akan mengembalikan nil.

     - Returns: Tabel `EditableTableView` yang aktif, atau nil jika tidak ada tabel yang aktif.
     */
    func activeTable() -> EditableTableView? {
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
        return nil
    }

    /**
         Menentukan jenis tabel berdasarkan objek `NSTableView` yang diberikan.

         - Parameter table: Objek `NSTableView` yang akan diperiksa jenisnya.
         - Returns: Nilai enum `TableType` yang sesuai dengan tabel yang diberikan. Mengembalikan `.kelas1` sebagai nilai default jika tabel tidak cocok dengan tabel yang dikenal.
     */
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

    /// Mengaktifkan tabel yang diberikan dan memperbarui tampilan tab serta kontrol segmen kelas.
    ///
    /// Fungsi ini memilih item tab yang sesuai dengan tabel yang diaktifkan dan memilih segmen yang sesuai pada kontrol segmen kelas.
    /// Fungsi ini juga memperbarui label pada kontrol segmen kelas untuk menunjukkan kelas yang dipilih.
    ///
    /// - Parameter table: NSTableView yang akan diaktifkan.
    func activateTable(_ table: NSTableView) {
        switch table {
        case table1: tabView.selectTabViewItem(at: 0); kelasSC.selectSegment(withTag: 0)
        case table2: tabView.selectTabViewItem(at: 1); kelasSC.selectSegment(withTag: 1)
        case table3: tabView.selectTabViewItem(at: 2); kelasSC.selectSegment(withTag: 2)
        case table4: tabView.selectTabViewItem(at: 3); kelasSC.selectSegment(withTag: 3)
        case table5: tabView.selectTabViewItem(at: 4); kelasSC.selectSegment(withTag: 4)
        case table6: tabView.selectTabViewItem(at: 5); kelasSC.selectSegment(withTag: 5)
        default: break
        }
        let nabila = kelasSC.selectedSegment; let salsabila = "Kelas \(nabila + 1)"
        if kelasSC.label(forSegment: nabila) != nil {
            kelasSC.setLabel("\(salsabila)", forSegment: nabila)
        }
        for segmentIndex in 0 ..< kelasSC.segmentCount {
            if segmentIndex != nabila {
                kelasSC.setLabel("\(segmentIndex + 1)", forSegment: segmentIndex)
            }
        }
    }

    /**
         Mengembalikan label yang sesuai dengan tabel yang sedang aktif.

         Fungsi ini memeriksa tabel mana yang sedang aktif (table1, table2, table3, table4, table5, atau table6) dan mengembalikan string yang sesuai dengan nama kelas. Jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali, fungsi ini mengembalikan pesan "Tabel Aktif Tidak Memiliki Nama".

         - Returns: String yang merepresentasikan nama kelas dari tabel yang aktif, atau "Tabel Aktif Tidak Memiliki Nama" jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali.
     */
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

    /**
         Mengembalikan string yang merepresentasikan nama tabel aktif.

         Fungsi ini memeriksa tabel mana yang sedang aktif dan mengembalikan string yang sesuai dengan nama tabel tersebut.
         Jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali, fungsi ini akan mengembalikan pesan yang menyatakan bahwa tabel aktif tidak memiliki nama.

         - Returns: String yang merepresentasikan nama tabel aktif, atau pesan kesalahan jika tabel aktif tidak dikenali atau tidak ada.
     */
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
}

extension DetailSiswaController {
    /**
     * Fungsi ini dipanggil ketika tombol untuk memperbesar ukuran baris ditekan.
     * Fungsi ini akan meningkatkan tinggi baris pada tabel yang aktif sebesar 5 poin.
     * Animasi digunakan untuk memberikan transisi yang halus saat ukuran baris berubah.
     *
     * - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func increaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight += 5
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
            }
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
    @IBAction func decreaseSize(_ sender: Any) {
        if let tableView = activeTable() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2 // Durasi animasi
                tableView.rowHeight = max(tableView.rowHeight - 3, 16)
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
            }
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

// MARK: - FUNGSI UNTUK MENANGANI NOTIFIKASI PEMBARUAN DATA.

extension DetailSiswaController {
    /**
         Menangani notifikasi `.dataSiswaDiEditDiSiswaView` ketika nama siswa diedit.

         Fungsi ini dipanggil ketika ada notifikasi yang memberitahukan bahwa nama siswa telah diedit.
         Fungsi ini akan memperbarui tampilan nama siswa jika ID siswa yang diedit sesuai dengan ID siswa yang ditampilkan.

         - Parameter notification: Notifikasi yang berisi informasi tentang siswa yang diedit.
                                    Notifikasi ini diharapkan memiliki `userInfo` yang berisi:
                                        - "updateStudentIDs": `Int64` ID siswa yang diedit.
                                        - "namaSiswa": `String` Nama siswa yang baru.
                                        - "kelasSekarang": `String` Kelas siswa saat ini.

         - Note: Fungsi ini menggunakan ``TableType/fromString(_:completion:)`` untuk mengkonversi string kelas menjadi enum `TableType`.
                 Fungsi ini juga menggunakan ``KelasViewModel/findAllIndices(for:matchingID:namaBaru:)`` untuk memperbarui data siswa di view model.
                 Fungsi ini memperbarui tampilan nama siswa pada thread utama.
     */
    @objc func handleNamaSiswaDiedit(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["updateStudentIDs"] as? Int64,
           let namaBaru = userInfo["namaSiswa"] as? String
        {
            guard deletedIDs == siswa?.id else { return }

            if let kelasSekarang = userInfo["kelasSekarang"] as? String {
                TableType.fromString(kelasSekarang) { kelas in
                    _ = viewModel.findAllIndices(for: kelas, matchingID: deletedIDs, namaBaru: namaBaru)
                }

                DispatchQueue.main.async { [unowned self] in
                    namaSiswa.stringValue = namaBaru
                }
            }
        }
    }

    /**
         Menangani notifikasi bahwa siswa telah dihapus.

         Fungsi ini dipanggil ketika notifikasi `.siswaDihapus` diposting. Fungsi ini akan memeriksa informasi yang diberikan dalam notifikasi,
         dan jika ID siswa yang dihapus cocok dengan ID siswa yang sedang ditampilkan, fungsi ini akan menonaktifkan berbagai elemen UI dan menandai nama siswa dengan strikethrough.
         Fungsi ini juga memperbarui data model dan tampilan tabel yang sesuai berdasarkan kelas siswa yang dihapus.

         - Parameter notification: Notifikasi yang berisi informasi tentang siswa yang dihapus. Informasi ini mencakup:
             - deletedStudentIDs: Array ID siswa yang dihapus.
             - kelasSekarang: String yang merepresentasikan kelas siswa yang dihapus.
             - isDeleted: Boolean yang menunjukkan apakah siswa telah dihapus.
             - hapusDiSiswa: Boolean yang menunjukkan apakah penghapusan dilakukan dari tampilan detail siswa.

         - Catatan: Fungsi ini berjalan pada thread utama untuk memperbarui UI.
     */
    @objc func handleSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["deletedStudentIDs"] as? [Int64],
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let isDeleted = userInfo["isDeleted"] as? Bool
        {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false
            guard let siswaID = siswa?.id, deletedIDs.contains(siswaID) else {
                return
            }
            if isDeleted, hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
                    tmblTambah.isEnabled = false
                    let text = "Nama Siswa"
                    let attributedString = NSMutableAttributedString(string: text)
                    // Menambahkan atribut strikethrough
                    attributedString.addAttributes([
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ], range: NSMakeRange(0, text.count))
                    // Mengatur attributed string ke NSTextField
                    namaSiswa.attributedStringValue = attributedString

                    namaSiswa.isEnabled = false
                    tmblSimpan.isEnabled = false
                    undoButton.isEnabled = false
                    redoButton.isEnabled = false
                    statistik.isEnabled = false
                    imageView.isEnabled = false
                    opsiSiswa.isEnabled = false
                    kelasSC.isEnabled = false
                    nilaiKelasAktif.isEnabled = false
                    smstr.isEnabled = false
                    alert.window.close()
                    for (table, _) in tableInfo {
                        table.isEnabled = false
                    }
                }
            }
            var modifiableModel: [KelasModels] = []
            TableType.fromString(kelasSekarang) { kelas in
                switch kelas {
                case .kelas1:
                    modifiableModel = viewModel.kelas1Model
                case .kelas2:
                    modifiableModel = viewModel.kelas2Model
                case .kelas3:
                    modifiableModel = viewModel.kelas3Model
                case .kelas4:
                    modifiableModel = viewModel.kelas4Model
                case .kelas5:
                    modifiableModel = viewModel.kelas5Model
                case .kelas6:
                    modifiableModel = viewModel.kelas6Model
                }
                guard let table = getTableView(for: kelas.rawValue) else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang, isDeleted: isDeleted, hapusSiswa: hapusSiswa, hapusData: false, naikKelas: false)
                _ = viewModel.setModel(kelas, model: modifiableModel)
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }

    /**
         Memperbarui baris pada tampilan tabel berdasarkan perubahan pada model data.

         Fungsi ini memungkinkan untuk memperbarui atau menghapus baris pada `NSTableView` berdasarkan ID yang diberikan.
         Fungsi ini juga menangani penyimpanan state model sebelum perubahan untuk mendukung fungsi undo.

         - Parameter model: Array `KelasModels` yang akan diperbarui.
         - Parameter tableView: `NSTableView` yang akan diperbarui tampilannya.
         - Parameter deletedIDs: Array berisi ID (`Int64`) dari item yang akan dihapus atau diperbarui.
         - Parameter kelasSekarang: String yang merepresentasikan kelas saat ini.
         - Parameter isDeleted: Boolean yang menandakan apakah item dihapus.
         - Parameter hapusSiswa: Boolean yang menandakan apakah siswa dihapus. Jika `true`, baris akan dihapus dari tabel.
         - Parameter hapusData: Boolean yang menandakan apakah data dihapus.
         - Parameter naikKelas: Boolean yang menandakan apakah siswa naik kelas.
     */
    func updateRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String, isDeleted: Bool, hapusSiswa: Bool, hapusData: Bool, naikKelas: Bool) {
        var indexesToUpdate = IndexSet()
        var indexesToDelete = IndexSet()
        var itemsToDelete: [KelasModels] = []
        // Simpan state model sebelum penghapusan untuk undo
        if undoUpdateStack[kelasSekarang] == nil {
            undoUpdateStack[kelasSekarang] = []
        }
        if isDeleted == true {
            undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels })
        }
        if hapusData == true, naikKelas == false {
            undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })
        }
        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if hapusData == false {
                if deletedIDs.contains(item.siswaID) {
                    if hapusSiswa == true {
                        indexesToDelete.insert(index)
                        itemsToDelete.append(item)
                    } else {
                        model[index].namasiswa = ""
                        indexesToUpdate.insert(index)
                    }
                }
            } else if naikKelas == true {
                if deletedIDs.contains(item.siswaID) {
                    model[index].namasiswa = ""

                    indexesToUpdate.insert(index)
                }
            } else {
                if deletedIDs.contains(item.kelasID) {
                    model[index].namasiswa = ""
                    indexesToUpdate.insert(index)
                }
            }
        }

        // Hapus data dari model
        if hapusSiswa == true {
            for index in indexesToDelete.sorted(by: >) {
                TableType.fromString(kelasSekarang) { kelas in
                    viewModel.removeData(index: index, tableType: kelas)
                }
            }
            model.removeAll { item in deletedIDs.contains(item.siswaID) }

            OperationQueue.main.addOperation { [weak self] in
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
                self?.updateSemesterTeks()
            }
        } else {
            OperationQueue.main.addOperation { [weak self] in
                tableView.reloadData(forRowIndexes: indexesToUpdate, columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
                self?.updateSemesterTeks()
            }
        }
    }

    /**
     Menangani notifikasi `.undoSiswaDihapus` yang diposting ketika operasi penghapusan siswa dibatalkan.

     Fungsi ini memperbarui tampilan antarmuka pengguna untuk mencerminkan status siswa yang dipulihkan,
     termasuk mengaktifkan kembali elemen UI yang relevan dan memperbarui tampilan tabel yang sesuai.

     - Parameter notification: Objek `Notification` yang berisi informasi tentang operasi undo,
                         termasuk kelas siswa saat ini dan apakah siswa dihapus.
                         `userInfo` diharapkan mengandung kunci "kelasSekarang" (String) dan "hapusDiSiswa" (Bool).

     - Catatan: Fungsi ini berjalan pada antrian utama untuk pembaruan UI.
     */
    @objc
    func handleUndoSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let kelasSekarang = userInfo["kelasSekarang"] as? String
        {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false

            if hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
                    self.tmblTambah.isEnabled = true
                    let text = "\(siswa?.nama ?? "")"
                    let attributedString = NSMutableAttributedString(string: text)
                    // Menambahkan atribut strikethrough
                    attributedString.addAttributes([
                        .foregroundColor: NSColor.textColor,
                    ], range: NSMakeRange(0, text.count))
                    namaSiswa.attributedStringValue = attributedString
                    namaSiswa.isEnabled = true
                    tmblSimpan.isEnabled = true
                    undoButton.isEnabled = true
                    redoButton.isEnabled = true
                    statistik.isEnabled = true
                    imageView.isEnabled = true
                    opsiSiswa.isEnabled = true
                    kelasSC.isEnabled = true
                    nilaiKelasAktif.isEnabled = true
                    smstr.isEnabled = true
                    for (table, _) in tableInfo {
                        table.isEnabled = true
                    }
                }
            }
            switch kelasSekarang {
            case "Kelas 1":
                let model = viewModel.kelas1Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 2":
                let model = viewModel.kelas2Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table2, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 3":
                let model = viewModel.kelas3Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table3, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 4":
                let model = viewModel.kelas4Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table4, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 5":
                let model = viewModel.kelas5Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table5, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            case "Kelas 6":
                let model = viewModel.kelas6Model
                var modifiableModel: [KelasModels] = model
                undoUpdateRows(from: &modifiableModel, tableView: table6, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            default:
                break
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }

    /**
        Mengembalikan perubahan terakhir yang dilakukan pada data siswa dalam tabel, berdasarkan kelas yang dipilih.

        Fungsi ini mengambil state data siswa sebelumnya dari stack undo, dan mengembalikan data tersebut ke tabel.
        Fungsi ini mendukung pengembalian data baik untuk penghapusan siswa maupun penghapusan data lainnya.

        - Parameter:
           - model: Array `KelasModels` yang akan dimodifikasi. Parameter ini bersifat `inout` sehingga perubahan akan langsung mempengaruhi array asli.
           - tableView: `NSTableView` yang akan diperbarui untuk mencerminkan perubahan data.
           - kelasSekarang: String yang merepresentasikan kelas yang datanya akan dikembalikan.
           - hapusSiswa: Boolean yang menandakan apakah operasi sebelumnya adalah penghapusan siswa. Jika `true`, fungsi akan mengembalikan baris siswa yang dihapus.
           - hapusData: Boolean yang menandakan apakah operasi sebelumnya adalah penghapusan data selain siswa. Jika `true`, fungsi akan mengembalikan data yang dihapus.

        - Catatan:
           - Fungsi ini menggunakan stack undo (`undoUpdateStack`) untuk menyimpan state data sebelumnya.
           - Fungsi ini menggunakan `TableType` untuk mengidentifikasi tabel yang sesuai berdasarkan nama kelas.
           - Fungsi ini menggunakan `viewModel` untuk melakukan operasi insert dan update data.
           - Fungsi ini menggunakan `dbController` untuk melakukan operasi undo penghapusan data di database.
           - Setelah pengembalian data, tabel akan diperbarui untuk menampilkan data yang dikembalikan.
     */
    func undoUpdateRows(from model: inout [KelasModels], tableView: NSTableView, kelasSekarang: String, hapusSiswa: Bool, hapusData: Bool) {
        guard var undoStackForKelas = undoUpdateStack[kelasSekarang], !undoStackForKelas.isEmpty else { return }
        let sortDescriptor = KelasModels.siswaSortDescriptor ?? NSSortDescriptor(key: "mapel", ascending: true)
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        undoUpdateStack[kelasSekarang] = undoStackForKelas // Perbarui stack undo

        var insertionIndexes = IndexSet()

        tableView.beginUpdates()
        for deletedData in previousState.sorted() {
            if hapusSiswa == true {
                TableType.fromString(kelasSekarang) { kelas in
                    guard let insertIndex = viewModel.insertData(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
                    insertionIndexes.insert(insertIndex)
                    tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                }
            } else if hapusSiswa == false || hapusData == true {
                TableType.fromString(kelasSekarang) { kelas in
                    viewModel.updateModel(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor)
                    let table = kelas.stringValue.replacingOccurrences(of: " ", with: "").lowercased()
                    dbController.undoHapusDataKelas(kelasID: deletedData.kelasID, fromTabel: Table("\(table)"), siswa: deletedData.namasiswa)
                }
            }
        }
        tableView.endUpdates()
        // Update table view untuk menampilkan baris yang diinsert
        if hapusSiswa == false {
            tableView.reloadData(forRowIndexes: insertionIndexes, columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }

    /**
     Menangani notifikasi penghapusan kelas. Fungsi ini dipanggil ketika notifikasi `kelasDihapusNotification` diposting.

     - Parameter notification: Objek `Notification` yang berisi informasi tentang kelas yang dihapus.
                               Informasi ini mencakup `tableType` (jenis tabel kelas yang terpengaruh) dan
                               `deletedKelasIDs` (array ID kelas yang dihapus).

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengambil informasi dari notifikasi, termasuk `tableType` dan `deletedKelasIDs`.
     2. Memilih model data yang sesuai berdasarkan `tableType`.
     3. Mendapatkan referensi ke `UITableView` yang sesuai berdasarkan `tableType`.
     4. Memeriksa apakah operasi yang dilakukan adalah penghapusan data, kenaikan kelas, atau penghapusan kelas biasa.
     5. Memanggil fungsi yang sesuai (`updateRows` atau `deleteKelasRows`) untuk memperbarui tampilan tabel dan model data.
     6. Memperbarui model data di `viewModel` dengan model yang telah dimodifikasi.

     - Note: Fungsi ini mengasumsikan bahwa `notification.userInfo` berisi kunci "tableType" dengan nilai `TableType` dan
             kunci "deletedKelasIDs" dengan nilai array `Int64`.
     */
    @objc func handleKelasDihapusNotification(_ notification: Notification) {
        // Ambil informasi dari notifikasi
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let deletedKelasIDs = userInfo["deletedKelasIDs"] as? [Int64]
        {
            // Pilih model berdasarkan tableType dan lakukan operasi yang sesuai
            var modifiableModel: [KelasModels] = []

            switch tableType {
            case .kelas1:
                modifiableModel = viewModel.kelas1Model
            case .kelas2:
                modifiableModel = viewModel.kelas2Model
            case .kelas3:
                modifiableModel = viewModel.kelas3Model
            case .kelas4:
                modifiableModel = viewModel.kelas4Model
            case .kelas5:
                modifiableModel = viewModel.kelas5Model
            case .kelas6:
                modifiableModel = viewModel.kelas6Model
            }
            guard let table = getTableView(for: tableType.rawValue) else { return }

            // Cek apakah hapus data atau naik kelas
            if let hapusData = userInfo["hapusData"] as? Bool {
                guard hapusData == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)

            } else if let naikKelas = userInfo["naikKelas"] as? Bool {
                guard naikKelas == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)

            } else {
                deleteKelasRows(from: &modifiableModel, tableView: table, tableType: tableType, deletedKelasIDs: deletedKelasIDs)
            }

            // Update model menggunakan setModel
            _ = viewModel.setModel(tableType, model: modifiableModel)
        }
    }

    /**
         Menghapus baris kelas dari model data dan NSTableView.

         Fungsi ini menghapus baris kelas berdasarkan daftar ID kelas yang diberikan, memperbarui model data, dan menghapus baris yang sesuai dari NSTableView dengan animasi. Fungsi ini juga menyimpan data yang dihapus ke dalam undo stack.

         - Parameter:
             - model: Array `KelasModels` yang akan dimodifikasi. Parameter ini bersifat `inout` sehingga perubahan akan memengaruhi array asli.
             - tableView: NSTableView yang barisnya akan dihapus.
             - tableType: Enum `TableType` yang mengidentifikasi jenis tabel (misalnya, tabel utama atau tabel arsip). Ini digunakan untuk mengelola undo stack secara terpisah untuk setiap jenis tabel.
             - deletedKelasIDs: Array berisi `kelasID` dari baris yang akan dihapus.

         - Catatan:
             - Fungsi ini menggunakan `IndexSet` untuk menghapus baris secara efisien dari NSTableView.
             - Penghapusan baris dari NSTableView dilakukan secara asinkron dengan penundaan singkat untuk memungkinkan animasi berjalan dengan lancar.
             - Fungsi ini juga memanggil `updateSemesterTeks()` setelah penghapusan untuk memperbarui tampilan semester.
             - Data yang dihapus disimpan dalam `undoStack` untuk memungkinkan operasi undo di masa mendatang.
     */
    func deleteKelasRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType, deletedKelasIDs: [Int64]) {
        var indexesToDelete = IndexSet()
        // Temukan indeks dari kelasID di model
        if undoStack[tableType] == nil {
            undoStack[tableType] = []
        }

        undoStack[tableType]?.append(model.filter { deletedKelasIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })

        for (index, item) in model.enumerated() {
            if deletedKelasIDs.contains(item.kelasID) {
                indexesToDelete.insert(index) // Tambahkan indeks ke IndexSet untuk penghapusan
            }
        }
        // Hapus data dari model
        model.removeAll { item in
            deletedKelasIDs.contains(item.kelasID)
        }

        // Hapus baris dari NSTableView
        if !indexesToDelete.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }

    /**
     Menangani notifikasi pembatalan penghapusan kelas. Fungsi ini dipanggil ketika notifikasi `undoKelasDihapusNotification` diterima.

     - Parameter notification: Notifikasi yang berisi informasi tentang kelas yang dibatalkan penghapusannya.
                                 Informasi ini mencakup `tableType` (tipe tabel kelas), `deletedKelasIDs` (daftar ID kelas yang dihapus),
                                 dan `hapusData` (bendera yang menunjukkan apakah data telah dihapus).

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengekstrak informasi dari `userInfo` notifikasi.
     2. Berdasarkan `tableType`, menentukan model data dan tabel yang sesuai.
     3. Memeriksa nilai `hapusData`. Jika `true`, memanggil ``undoUpdateRows(from:tableView:kelasSekarang:hapusSiswa:hapusData:)`` untuk membatalkan pembaruan baris.
        Jika `false`, memanggil ``undoDeleteRows(from:tableView:tableType:idBaru:)`` untuk membatalkan penghapusan baris.
     4. Memperbarui tampilan semester setelah operasi selesai.

     */
    @objc
    func handleUndoKelasDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let id = userInfo["deletedKelasIDs"] as? [Int64]
        {
            switch tableType {
            case .kelas1:
                let model = viewModel.kelas1Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: "Kelas 1", hapusSiswa: false, hapusData: hapusData)
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table1, tableType: tableType, idBaru: id)
                }
            case .kelas2:
                let model = viewModel.kelas2Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table2, kelasSekarang: "Kelas 2", hapusSiswa: false, hapusData: hapusData)

                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table2, tableType: tableType, idBaru: id)
                }
            case .kelas3:
                let model = viewModel.kelas3Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table3, kelasSekarang: "Kelas 3", hapusSiswa: false, hapusData: hapusData)
                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table3, tableType: tableType, idBaru: id)
                }
            case .kelas4:
                let model = viewModel.kelas4Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table4, kelasSekarang: "Kelas 4", hapusSiswa: false, hapusData: hapusData)

                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table4, tableType: tableType, idBaru: id)
                }
            case .kelas5:
                let model = viewModel.kelas5Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table5, kelasSekarang: "Kelas 5", hapusSiswa: false, hapusData: hapusData)

                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table5, tableType: tableType, idBaru: id)
                }
            case .kelas6:
                let model = viewModel.kelas6Model
                var modifiableModel: [KelasModels] = model
                if let hapusData = userInfo["hapusData"] as? Bool {
                    guard hapusData == true else { return }
                    undoUpdateRows(from: &modifiableModel, tableView: table1, kelasSekarang: "Kelas 1", hapusSiswa: false, hapusData: hapusData)

                } else {
                    undoDeleteRows(from: &modifiableModel, tableView: table6, tableType: tableType, idBaru: id)
                }
            }
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }

    /**
     Membatalkan penghapusan baris pada tabel. Fungsi ini mengambil state sebelumnya dari data yang dihapus dari stack undo,
     memasukkan kembali data tersebut ke dalam model, dan memperbarui tampilan tabel untuk mencerminkan perubahan.

     - Parameter model: Model data yang akan dimodifikasi.
     - Parameter tableView: Tampilan tabel yang akan diperbarui.
     - Parameter tableType: Jenis tabel yang sedang dioperasikan (misalnya, siswa, guru, dll.).
     - Parameter idBaru: Array berisi ID baru yang akan di insert.
     */
    func undoDeleteRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType, idBaru: [Int64]) {
        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
        guard var undoStackForKelas = undoStack[tableType], let sortDescriptor = KelasModels.siswaSortDescriptor, !undoStackForKelas.isEmpty else { return }
        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        undoStack[tableType] = undoStackForKelas // Perbarui stack undo

        var insertionIndexes = IndexSet()
        for deletedData in previousState.sorted() {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor) else { return }
            insertionIndexes.insert(insertionIndex)
        }
        // Update table view untuk menampilkan baris yang diinsert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tableView.beginUpdates()
            tableView.insertRows(at: insertionIndexes, withAnimation: .slideDown)
            tableView.endUpdates()
            DispatchQueue.main.async { [unowned self] in
                updateSemesterTeks()
            }
        }
    }

    /**
     Menangani aksi undo pembaruan kelas siswa.

     Fungsi ini dipanggil ketika ada notifikasi `.updateUndoArray` yang dikirimkan. Fungsi ini akan memperbarui `kelasId` di dalam `undoArray` dari `oldKelasID` menjadi `newKelasID`. Setelah pembaruan selesai, fungsi ini akan memanggil `updateSemesterTeks` untuk memperbarui tampilan.

     - Parameter notification: Notifikasi yang mengandung informasi `updatedID` (kelasID baru) dan `oldKelasID` (kelasID lama).
     */
    @objc
    func handleUndoUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newKelasID = userInfo["updatedID"] as? Int64,
              let oldKelasID = userInfo["oldKelasID"] as? Int64 else { return }

        // Cari kelasID lama di undoArray dan perbarui dengan kelasID baru
        if let index = undoArray.firstIndex(where: { $0.kelasId == oldKelasID }) {
            undoArray[index].kelasId = newKelasID
        }
        DispatchQueue.main.async { [unowned self] in
            updateSemesterTeks()
        }
    }
}

extension DetailSiswaController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard let activeTable = activeTable(),
              !viewModel.kelasModelForTable(tableTypeForTable(activeTable)).isEmpty,
              let table = SingletonData.dbTable(forTableType: tableTypeForTable(activeTable)) else { return }

        let columnIdentifier = activeTable.tableColumns[column].identifier.rawValue
        var newValue = newText
        let selectedTabView = tabView.selectedTabViewItem!
        let oldValue = viewModel.getOldValueForColumn(tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table)
        switch columnIdentifier {
        case "mapel", "semester", "namaguru":
            if newValue != oldValue {
                let kelasId = viewModel.kelasModelForTable(tableTypeForTable(activeTable))[row].kelasID
                let updatedValue = newValue.capitalizedAndTrimmed()
                newValue = updatedValue
                // Simpan originalModel untuk undo
                let originalModel = OriginalData(kelasId: kelasId, tableType: tableTypeForTable(activeTable), rowIndex: row, columnIdentifier: columnIdentifier, oldValue: oldValue, newValue: newValue, table: table, tableView: activeTable)

                viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

                // Daftarkan aksi undo ke NSUndoManager
                NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": createStringForActiveTable(), "newValue": newValue, "kelasId": originalModel.kelasId])
                // Daftarkan aksi undo ke NSUndoManager
                myUndoManager?.registerUndo(withTarget: self) { [weak self] _ in
                    self?.undoAction(originalModel: originalModel)
                }

                updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabView), semesterName: smstr.titleOfSelectedItem ?? "")
                deleteRedoArray(self)
            }
        case "nilai":
            if newValue != oldValue {
                // Dapatkan kelasId dari model data
                let kelasId = viewModel.kelasModelForTable(tableTypeForTable(activeTable))[row].kelasID
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

                viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableTypeForTable(activeTable)), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

                NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": createStringForActiveTable(), "newValue": newValue, "kelasId": originalModel.kelasId])
                // Daftarkan aksi undo ke NSUndoManager
                myUndoManager?.registerUndo(withTarget: self) { [weak self] _ in
                    self?.undoAction(originalModel: originalModel)
                }
                deleteRedoArray(self)
                updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabView), semesterName: smstr.titleOfSelectedItem ?? "")
            }
        default:
            break
        }
        updateUndoRedo(nil)
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        guard let tableView = activeTable() else {
            return false
        }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        if columnIdentifier == "tgl" {
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

extension DetailSiswaController: NSTableViewDataSource, NSTableViewDelegate {
    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            let resizedColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
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
        guard let table = activeTable() else { return }
        let tableColumns = table.tableColumns
        ReusableFunc.updateColumnMenu(table, tableColumns: tableColumns, exceptions: ["mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        tableView.rowHeight
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        let tableType = tableTypeForTable(tableView)
        return viewModel.numberOfRows(forTableType: tableType)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableType = tableTypeForTable(tableView)
        guard let kelasModel = viewModel.modelForRow(at: row, tableType: tableType) else { return nil }
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                switch tableColumn?.identifier {
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

    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        // Membuat tooltip sesuai dengan data yang ada di sel tertentu
        let kelasModel = viewModel.kelasModelForTable(tableTypeForTable(tableView))
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

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIDs.removeAll()
        guard let tableView = notification.object as? NSTableView,
              tableView.numberOfRows != 0
        else { return }
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
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
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
    }

    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        if columnIndex == 0 {
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
        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        let tableType = tableTypeForTable(tableView)
        viewModel.sort(tableType: tableType, sortDescriptor: sortDescriptor)
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        var indexset = IndexSet()
        for id in selectedIDs {
            if let index = model.firstIndex(where: { $0.kelasID == id }) {
                indexset.insert(index)
            }
        }
        saveSortDescriptor(sortDescriptor, forTableIdentifier: createStringForActiveTable())
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfRows), columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
        table.selectRowIndexes(indexset, byExtendingSelection: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let max = indexset.max() {
                table.scrollRowToVisible(max)
            }
        }
    }
}
