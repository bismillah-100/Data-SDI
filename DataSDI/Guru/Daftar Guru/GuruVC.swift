//
//  GuruVC.swift
//  Data SDI
//
//  Created by MacBook on 09/07/25.
//

import AppKit
import Combine

class GuruVC: NSViewController {
    /// Instance ``DatabaseController``.
    let dbController: DatabaseController = .shared

    weak var tableView: EditableTableView!
    /// Properti yang menunjukkan jika data guru telah dimuat dari database.
    var isDataLoaded: Bool = false
    /// Properti untuk menyimpan informasi kolom dengan judul kustom.
    let kolomTabelGuru: [ColumnInfo] = [
        ColumnInfo(identifier: "NamaGuru", customTitle: "Nama Guru"),
        ColumnInfo(identifier: "AlamatGuru", customTitle: "Alamat"),
    ]
    /// Properti `NSSortDescriptor` untuk pengurutan data
    /// sesuai dengan kolom.
    var sortDescriptor: NSSortDescriptor?
    /// Instance ``GuruViewModel``.
    let viewModel: GuruViewModel = .shared

    /// Jendela untuk menambah/mengedit data.
    lazy var addVCWindow: NSWindow = .init()

    /// Set referensi `AnyCancellable` yang digunakan untuk mengelola langganan combine.
    var cancellables: Set<AnyCancellable> = .init()

    /// Properti yang menyimpan data guru untuk diperbarui.
    lazy var dataToEdit: [GuruModel] = .init()

    /// DispatchWorkItem khusus ``DataSDI/GuruVC``.
    /// Berguna untuk debounce (delay) seperti pengetikan untuk mencari data dll..
    var workItem: DispatchWorkItem?

    /// NSMenu yang digunakan toolbar ``DataSDI/WindowController/actionPopUpButton``.
    private(set) var toolbarMenu: NSMenu!

    /// Mengatur sort descriptor untuk kolom-kolom pada `tableView`.
    /// Fungsi ini membuat dua buah `NSSortDescriptor` untuk kolom "NamaGuru" dan "AlamatGuru" dengan urutan menurun (descending).
    /// Kemudian, fungsi ini memasangkan sort descriptor yang sesuai ke setiap kolom tabel berdasarkan identifier-nya.
    /// Dengan demikian, pengguna dapat mengurutkan data pada tabel berdasarkan nama atau alamat guru.
    /// - Catatan: Pastikan identifier kolom pada Interface Builder sesuai dengan key yang digunakan di dalam dictionary.
    func setupSortDescriptor() {
        let nama = NSSortDescriptor(key: "NamaGuru", ascending: false)
        let alamat = NSSortDescriptor(key: "AlamatGuru", ascending: false)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("NamaGuru"): nama,
            NSUserInterfaceItemIdentifier("AlamatGuru"): alamat,
        ]
        for kolom in tableView.tableColumns {
            let identifikasi = kolom.identifier
            let tukangIdentifikasi = identifikasiKolom[identifikasi]
            kolom.sortDescriptorPrototype = tukangIdentifikasi
        }
    }

    override func loadView() {
        // Buat root view
        let rootView = NSView()

        // ScrollView
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // TableView
        let tableView = EditableTableView()

        // Set up table view
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.allowsTypeSelect = true
        tableView.autosaveTableColumns = true
        tableView.autosaveName = "MasterGuruTableView"
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle

        let namaColumn = NSTableColumn(identifier: .init("NamaGuru"))
        namaColumn.maxWidth = 400
        tableView.addTableColumn(namaColumn)

        let alamatColumn = NSTableColumn(identifier: .init("AlamatGuru"))
        alamatColumn.maxWidth = 600
        tableView.addTableColumn(alamatColumn)

        tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle

        // Embed table view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        // Tambahkan ke rootView
        rootView.addSubview(scrollView)
        // Auto Layout
        NSLayoutConstraint.activate([
            rootView.widthAnchor.constraint(greaterThanOrEqualToConstant: 700),
            rootView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: -1),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
        view = rootView
        self.tableView = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSortDescriptor()
        if let sortDesc = loadSortDescriptor() {
            tableView.sortDescriptors = [sortDesc]
        }
        // Setup tinggi bari syang telah disimpan sebelumnya di UserDefault.
        if let savedRowHeight = UserDefaults.standard.value(forKey: "GuruTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }

        for column in kolomTabelGuru {
            guard let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column.identifier)) else {
                continue
            }
            let headerKolom = MyHeaderCell()
            headerKolom.title = column.customTitle
            tableColumn.headerCell = headerKolom
        }

        tableView.dataSource = self
        tableView.delegate = self
        // Do view setup here.
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: false)
            muatUlang(self)
            setupCombine()
            let tableMenu = buatMenuItem()
            tableMenu.delegate = self
            tableView.menu = tableMenu
            toolbarMenu = tableMenu.copy() as? NSMenu
            toolbarMenu.delegate = self
            NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            updateMenuItem()
            setupToolbar()
            updateUndoRedo(self)
            view.window?.makeFirstResponder(tableView)
        }
    }

    /// Fungsi yang dijalankan saat menerima notifikasi `.saveData`.
    /// - Parameter sender: Objek pemicu.
    @objc
    private func saveData(_: Any) {
        // Gunakan dispatch group untuk memastikan semua operasi selesai
        let group = DispatchGroup()

        group.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            viewModel.removeAllGuruData()
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            viewModel.guruUndoManager.removeAllActions()
            updateUndoRedo(self)
            // Tunggu sebentar untuk memastikan database sudah ter-update
            dbController.notifQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                // Kembali ke main thread untuk update UI
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    muatUlang(self)
                }
            }
        }
    }

    /// Fungsi untuk memuat ulang data dan ``tableView``.
    /// - Parameter sender: Objek pemicu.
    @IBAction
    func muatUlang(_: Any) {
        let selectedRows = tableView.selectedRowIndexes
        Task { [unowned self] in
            await viewModel.queryDataGuru(forceLoad: true)
            viewModel.urutkanGuru(
                loadSortDescriptor()
                    ?? NSSortDescriptor(key: "NamaGuru", ascending: true)
            )
            await MainActor.run {
                tableView.reloadData()
                isDataLoaded = true
                if let window = self.view.window {
                    ReusableFunc.closeProgressWindow(window)
                }
                tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
                if let max = selectedRows.max() {
                    tableView.scrollRowToVisible(max)
                }
            }
        }
    }

    /// Konfigurasi toolbar untuk ``DataSDI/GuruVC``.
    func setupToolbar() {
        guard let wc = view.window?.windowController as? WindowController else { return }

        wc.searchField.isEnabled = true
        wc.searchField.isEditable = true
        wc.searchField.target = self
        wc.searchField.action = #selector(procSearchFieldInput(_:))
        wc.searchField.delegate = self
        wc.searchField.placeholderString = "Cari guru..."

        let isItemSelected = tableView.selectedRow != -1
        wc.tambahSiswa.isEnabled = true
        wc.tambahSiswa.toolTip = "Catat Guru Baru"
        wc.tambahDetaildiKelas.isEnabled = false
        wc.actionPopUpButton.menu = toolbarMenu
        wc.tmbledit.isEnabled = isItemSelected

        wc.hapusToolbar.isEnabled = isItemSelected
        wc.hapusToolbar.target = self
        wc.hapusToolbar.action = #selector(hapusGuru(_:))

        wc.segmentedControl.isEnabled = true
        wc.segmentedControl.target = self
        wc.segmentedControl.action = #selector(segmentedControlValueChanged(_:))
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/GuruVC``.
    @objc func updateMenuItem() {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let deleteMenuItem = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem
        {
            let adaBarisDipilih = tableView.selectedRowIndexes.count > 0
            deleteMenuItem.isEnabled = adaBarisDipilih
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salin(_:))
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(hapusGuru(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
            }
            new.target = self
            new.action = #selector(tambahGuru(_:))
        }
    }

    /// Berguna untuk memperbarui action/target menu item undo/redo di Menu Bar.
    @objc func updateUndoRedo(_: Any?) {
        ReusableFunc.workItemUpdateUndoRedo?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let undoMenuItem = ReusableFunc.undoMenuItem,
                  let redoMenuItem = ReusableFunc.redoMenuItem
            else {
                return
            }
            let canRedo = viewModel.guruUndoManager.canRedo
            let canUndo = viewModel.guruUndoManager.canUndo
            // Set target dan action seperti sebelumnya
            if canUndo {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(urung(_:))
                undoMenuItem.isEnabled = true
            } else {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            }

            if canRedo {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(ulang(_:))
                redoMenuItem.isEnabled = true
            } else {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            }
            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    @objc
    private func urung(_: Any) {
        if viewModel.guruUndoManager.canUndo {
            viewModel.guruUndoManager.undo()
        }
    }

    @objc
    private func ulang(_: Any) {
        if viewModel.guruUndoManager.canRedo {
            viewModel.guruUndoManager.redo()
        }
    }

    /**
     Menyimpan `NSSortDescriptor` ke UserDefaults.

     - Parameter sortDescriptor: `NSSortDescriptor` yang akan disimpan. Jika nil, maka sort descriptor akan dihapus dari UserDefaults.
     */
    func saveSortDescriptor(_ sortDescriptor: NSSortDescriptor?) {
        // Simpan sort descriptor ke UserDefaults
        if let sortDescriptor {
            ReusableFunc.saveSortDescriptor(sortDescriptor, key: "sortDescriptor_MasterGuru")
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
        let savedSortDesc = ReusableFunc.loadSortDescriptor(forKey: "sortDescriptor_MasterGuru", defaultKey: "NamaGuru")
        return savedSortDesc
    }

    /// Action dari ``DataSDI/WindowController/segmentedControl``.
    /// - Parameter sender: ``DataSDI/WindowController/segmentedControl``.
    @IBAction func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "GuruTableViewRowHeight")
        case 1:
            ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "GuruTableViewRowHeight")
        default:
            break
        }
    }

    /// Fungsi untuk memperbesar tinggi ``tableView``.
    ///
    /// - Parameter sender: Objek pemicu
    @IBAction func increaseSize(_: Any?) {
        ReusableFunc.increaseSizeStep(tableView, userDefaultKey: "GuruTableViewRowHeight")
    }

    /// Fungsi untuk memperkecil tinggi ``tableView``.
    ///
    /// - Parameter sender: Objek pemicu.
    @IBAction func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSizeStep(tableView, userDefaultKey: "GuruTableViewRowHeight")
    }
}
