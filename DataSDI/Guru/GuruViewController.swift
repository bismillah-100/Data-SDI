//
//  GuruViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//
import Cocoa
import Foundation

class GuruViewController: NSViewController, NSSearchFieldDelegate {
    /// Outlet scrollView yang menampung ``outlineView``.
    @IBOutlet weak var scrollView: NSScrollView!

    /// Fungsi untuk memperbesar tinggi ``outlineView``.
    ///
    /// - Parameter sender: Objek pemicu
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            outlineView.rowHeight += 5
            outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< outlineView.numberOfRows))
        }
        saveRowHeight()
    }

    /// Fungsi untuk memperkecil tinggi ``outlineView``.
    ///
    /// - Parameter sender: Objek pemicu.
    @IBAction func decreaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            outlineView.rowHeight = max(outlineView.rowHeight - 3, 16)
            outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< outlineView.numberOfRows))
        }
        saveRowHeight()
    }

    /// Fungsi untuk menyimpan rowHeight ke UserDefaults
    func saveRowHeight() {
        UserDefaults.standard.setValue(outlineView.rowHeight, forKey: "GuruOutlineViewRowHeight")
    }

    /// Outlet outlineView di XIB
    @IBOutlet weak var outlineView: EditableOutlineView!

    /// Properti untuk menyimpan data guru yang
    /// dibaca dari database.
    var guruu: [GuruModel] = []

    /// Properti untuk membuat tampilan Hierarki sesuai dengan nama mapel.
    var mapelList: [MapelModel] = []

    /// Membuat deskripsi kolom di ``outlineView``.
    ///
    /// Mengatur properti `identifier` dan `customTitle`.
    let kolomTabelGuru: [ColumnInfo] = [
        ColumnInfo(identifier: "NamaGuru", customTitle: "Nama Guru"),
        ColumnInfo(identifier: "AlamatGuru", customTitle: "Alamat"),
        ColumnInfo(identifier: "TahunAktif", customTitle: "Tahun Aktif"),
        ColumnInfo(identifier: "Mapel", customTitle: "Mata Pelajaran"),
        ColumnInfo(identifier: "Struktural", customTitle: "Sebagai"),
    ]

    /// `NSUndoManager` khusus untuk ``DataSDI/GuruViewController``
    var myUndoManager: UndoManager = .init()

    /// Properti untuk menyimpan data yang dihapus
    /// untuk keperluan undo.
    var undoHapus: [Int64] = []
    /// Properti untuk menyimpan data yang dihapus
    /// untuk keperluan redo.
    var redoHapus: [Int64] = []

    /// Properti untuk menyimpan status penggunaan `alternateRow`.
    var warnaAlternatif = true

    /// Identifier untuk class ``DataSDI/GuruViewController``
    static let identifier = NSUserInterfaceItemIdentifier("GuruViewController")

    /// Instans untuk ``DatabaseController/shared``
    let dbController = DatabaseController.shared

    /// Properti instans ``DataSDI/SuggestionManager``
    var suggestionManager: SuggestionManager!

    /// Properti untuk mengatur `NSTextField` yang sedang aktif editing.
    ///
    /// Berguna untuk menampilkan prediksi yang sesuai ketika menambah atau mengedit data
    /// melalui ``edit(_:)``.
    var activeText: NSTextField!

    /// Properti untuk menyimpan referensi jika ``guruu`` telah diisi dengan data yang ada
    /// di database dan telah diatur hierarki dalam ``mapelList``
    /// serta sudah ditampilkan setiap barisnya di ``outlineView``.
    var isDataLoaded: Bool = false

    /// Properti string dari pengetikan di ``DataSDI/WindowController/search``.
    lazy var stringPencarian: String = ""

    /// Menu yang akan digunakan toolbar ``DataSDI/WindowController/actionToolbar``.
    var toolbarMenu = NSMenu()

    /// Properti untuk memperbarui semua data dan ``outlineView``
    /// jika nilainya adalah true ketika ``viewDidAppear()``.
    ///
    /// Properti ini diset ketika ada interaksi pengeditan nama guru di ``DataSDI/KelasVC``.
    var adaUpdateNamaGuru: Bool = false

    /// Properti `NSSortDescriptor` untuk pengurutan data
    /// sesuai dengan kolom.
    var sortDescriptors: NSSortDescriptor?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Setup tinggi bari syang telah disimpan sebelumnya di UserDefault.
        if let savedRowHeight = UserDefaults.standard.value(forKey: "GuruOutlineViewRowHeight") as? CGFloat {
            outlineView.rowHeight = savedRowHeight
        }
        /// Properti untuk menghalangi ``outlineView`` menjadi firstResponder keyboard jika diset ke `true`.
        outlineView.refusesFirstResponder = false
        outlineView.setAccessibilityIdentifier("GuruViewController")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: isDataLoaded)
            // Iterasi setiap kolom untuk menggunakan customTitle dari kolomTabelGuru
            for column in kolomTabelGuru {
                guard let tableColumn = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column.identifier)) else {
                    continue
                }
                let headerKolom = MyHeaderCell()
                headerKolom.title = column.customTitle
                tableColumn.headerCell = headerKolom
            }
            outlineView.dataSource = self
            outlineView.delegate = self
            outlineView.doubleAction = #selector(outlineViewDoubleClick(_:))
            // Set urutan default untuk kolom "NamaGuru".
            let urutan = NSSortDescriptor(key: "NamaGuru", ascending: true)
            outlineView.sortDescriptors = [urutan]

            // menggunakan dispatchGroup untuk proses yang lebih terstuktur.
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .background).sync { [weak self] in
                guard let self else {
                    group.leave()
                    if let s = self, let window = s.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    return
                }
                self.muatUlang(self)
                self.isDataLoaded = true
                group.leave()
            }
            group.notify(queue: .main) {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] timer in
                    guard let self else { return }
                    if let window = self.view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    self.outlineView.editAction = { row, column in
                        AppDelegate.shared.editorManager?.startEditing(row: row, column: column)
                    }
                    timer.invalidate()
                }
            }

            // Perbarui instans `suggestionManager`
            suggestionManager = SuggestionManager(suggestions: [""])

            // Perbarui menu item untuk kolom-kolom outelinView.
            ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
        }

        /// perbarui semua data ketika adaUpdateNamaGuru bernilai `true`.
        if adaUpdateNamaGuru {
            guard isDataLoaded else { return }
            muatUlang(self)
        }
        setupSortDescriptor()

        toolbarMenu = buatMenuItem()
        toolbarMenu.delegate = self

        let menu = buatMenuItem()
        menu.delegate = self
        outlineView.menu = menu

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            self.view.window?.makeFirstResponder(self.outlineView)
            ReusableFunc.resetMenuItems()
            updateMenuItem(self)
            updateUndoRedo(self)
            ReusableFunc.updateSearchFieldToolbar(self.view.window!, text: stringPencarian)
        }
        outlineView.refusesFirstResponder = false
        setupToolbar()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.guruDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNamaGuruUpdate(_:)), name: DatabaseController.namaGuruUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        searchWork?.cancel()
        searchWork = nil
        ReusableFunc.resetMenuItems()
    }

    /// Mengubah status visibilitas (`isHidden`) sebuah kolom tabel berdasarkan `NSMenuItem` yang diklik.
    /// Fungsi ini dirancang untuk bekerja dengan menu item yang merepresentasikan kolom tabel tertentu.
    /// Kolom "NamaGuru" dan "Mapel" dikecualikan dan tidak dapat disembunyikan.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini. `representedObject` dari item menu
    ///                     diharapkan berisi `NSTableColumn` yang visibilitasnya akan di-_toggle_.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        // Memastikan bahwa `representedObject` dari `sender` adalah instance dari `NSTableColumn`.
        // Jika tidak, fungsi akan berhenti karena tidak ada kolom yang dapat diubah visibilitasnya.
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        // Memeriksa apakah kolom yang akan di-_toggle_ adalah kolom "NamaGuru".
        if column.identifier.rawValue == "NamaGuru" {
            // Jika ya, kolom ini tidak dapat disembunyikan, jadi fungsi berhenti.
            // Anda mungkin ingin menambahkan umpan balik visual atau pesan kepada pengguna di sini.
            return
        }

        // Memeriksa apakah kolom yang akan di-_toggle_ adalah kolom "Mapel".
        if column.identifier.rawValue == "Mapel" {
            // Jika ya, kolom ini juga tidak dapat disembunyikan, jadi fungsi berhenti.
            // Mirip dengan kolom "NamaGuru", umpan balik kepada pengguna bisa ditambahkan.
            return
        }

        // Mengubah status visibilitas kolom. Jika kolom saat ini tersembunyi (`true`),
        // akan menjadi terlihat (`false`), dan sebaliknya.
        column.isHidden = !column.isHidden

        // Memperbarui status tampilan `NSMenuItem` (`sender`).
        // Jika kolom sekarang tersembunyi (`column.isHidden` adalah `true`), setel status menu item menjadi `.off`.
        // Jika kolom sekarang terlihat (`column.isHidden` adalah `false`), setel status menu item menjadi `.on`.
        sender.state = column.isHidden ? .off : .on
    }

    /// Konfigurasi action dan target toolbarItem untuk ``DataSDI/GuruViewController``.
    func setupToolbar() {
        guard let toolbar = view.window?.toolbar else { return }
        let isItemSelected = outlineView.selectedRow != -1
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.isEnabled = true
            searchField.isEditable = true
            searchField.target = self
            searchField.action = #selector(procSearchFieldInput(sender:))
            searchField.delegate = self
            if let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell {
                textFieldInsideSearchField.placeholderString = "Cari guru..."
            }
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = isItemSelected
            hapus.target = self
            hapus.action = #selector(hapusSerentak(_:))
        }

        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            edit.isEnabled = isItemSelected
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl
        {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton
        {
            add.toolTip = "Catat Guru Baru"
            add.isEnabled = true
        }

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton
        {
            tambah.isEnabled = false
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
        {
            popUpButton.menu = toolbarMenu
        }
    }

    /// Fungsi yang dijalankan ketika menerima notifikasi dari `.saveData`.
    ///
    /// Menjalankan logika untuk menyiapkan ulang database, memperbarui ``guruu`` dari database,
    /// membuat struktur hierarki untuk ``mapelList``,
    /// dan memuat ulang seluruh baris di ``outlineView``.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func saveData(_ notification: Notification) {
        // Gunakan dispatch group untuk memastikan semua operasi selesai
        let group = DispatchGroup()

        guard isDataLoaded else { return }
        group.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            // Bersihkan semua array
            self.deleteAllRedoArray()
            SingletonData.deletedGuru.removeAll()
            self.undoHapus.removeAll()
            self.guruu.removeAll()
            self.mapelList.removeAll()
            group.leave()
        }

        // Setelah semua operasi pembersihan selesai
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.myUndoManager.removeAllActions()
            self.updateUndoRedo(self)

            // Tunggu sebentar untuk memastikan database sudah ter-update
            self.dbController.notifQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                // Kembali ke main thread untuk update UI
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.muatUlang(self)
                }
            }
        }
    }

    /// Memperbarui properti ``adaUpdateNamaGuru`` ketika ada nama guru
    /// yang diperbarui.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func handleNamaGuruUpdate(_ notification: Notification) {
        if !adaUpdateNamaGuru {
            adaUpdateNamaGuru = true
        } else {
            return
        }
    }

    /// Fungsi untuk membersihkan semua array ``guruu`` dan hierarki di ``mapelList``
    /// dan memuat ulang suluruh ``outlineView``.
    @IBAction func muatUlang(_ sender: Any) {
        let sortDescriptor = sortDescriptors ?? NSSortDescriptor(key: "NamaGuru", ascending: sortDescriptors?.ascending ?? true)

        Task { [unowned self] in
            // Bersihkan data yang ada
            guruu.removeAll()
            mapelList.removeAll()

            // Refresh data dari database secara asinkron
            guruu = await dbController.getGuru()

            // Kelompokkan data guru berdasarkan mapel
            var mapelDict: [String: [GuruModel]] = [:]
            for guru in guruu {
                mapelDict[guru.mapel, default: []].append(guru)
            }

            // Reset dan isi ulang mapelList berdasarkan mapelDict
            mapelList.removeAll()
            for (mapel, guruList) in mapelDict {
                let mapelModel = MapelModel(id: UUID(), namaMapel: mapel, guruList: guruList)
                mapelList.append(mapelModel)
            }

            // Update UI di MainActor
            await MainActor.run {
                adaUpdateNamaGuru = false
                sortDescriptors = outlineView.sortDescriptors.first!
                sortModel(by: sortDescriptor)
                outlineView.reloadData()
            }

            // Tunda selama 0.1 detik sebagai pengganti asyncAfter
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik

            // Lanjutkan update UI tambahan di MainActor
            await MainActor.run {
                self.loadExpandedItems()
                self.saveExpandedItems()
                self.updateUndoRedo(self)
            }
        }
    }

    /// Menjalankan fungsi ``muatUlang(_:)`` ketika mendapatkan
    /// notifikasi `DatabaseController.guruDidChangeNotification`.
    ///
    /// Pengirim notifikasi ini hanya terdapat di ``DataSDI/DetailSiswaController``.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func handleDataDidChangeNotification(_ notification: Notification) {
        muatUlang(self)
    }

    /// Berguna untuk memperbarui action/target menu item undo/redo di Menu Bar.
    @objc func updateUndoRedo(_ sender: Any?) {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
        else {
            return
        }
        DispatchQueue.main.async { [unowned self] in
            let canRedo = myUndoManager.canRedo
            let canUndo = myUndoManager.canUndo
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
    }

    /// Fungsi yang digunakan untuk menghapus semua data Redo.
    ///
    /// Fungsi ini dijalankan ketika data diubah bukan dari undo/redo.
    func deleteAllRedoArray() {
        if !redoHapus.isEmpty {
            redoHapus.removeAll()
        }
        if !SingletonData.undoAddGuru.isEmpty {
            SingletonData.undoAddGuru.removeAll()
        }
    }

    /// Fungsi untuk menjalankan undo.
    @objc func urung(_ sender: Any) {
        myUndoManager.undo()
    }

    /// Fungsi untuk menjalankan redo.
    @objc func ulang(_ sender: Any) {
        myUndoManager.redo()
    }

    /// Action dari toolbar ``DataSDI/WindowController/hapusToolbar``.
    /// Fungsi untuk mendapatkan indeks baris yang dipilih, kemudian mengiterasi setiap index
    /// untuk mendapatkan id dan nama guru, menampilkan `NSAlert` dan kemudian menjalankan fungsi ``hapusRow(_:idToDelete:)``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func hapusSerentak(_ sender: Any) {
        // Mendapatkan indeks baris yang dipilih
        let selectedRows = outlineView.selectedRowIndexes

        // Memastikan ada baris yang dipilih
        guard selectedRows.count > 0 else { return }

        var namaguru = Set<String>()
        var idToDelete = Set<Int64>() // Menggunakan set untuk menyimpan idGuru yang akan dihapus

        // Looping melalui setiap indeks yang dipilih
        for row in selectedRows {
            // Mendapatkan item di row yang dipilih
            if let selectedItem = outlineView.item(atRow: row) {
                if let guru = selectedItem as? GuruModel {
                    // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                    namaguru.insert(guru.namaGuru)
                    idToDelete.insert(guru.idGuru)
                } else if let mapel = selectedItem as? MapelModel {
                    // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                    namaguru.insert(mapel.namaMapel)
                    for guru in mapel.guruList {
                        idToDelete.insert(guru.idGuru)
                    }
                }
            }
        }
        let namaGuruString = namaguru.joined(separator: ", ")

        // Menampilkan peringatan konfirmasi sebelum menghapus
        let alert = NSAlert()
        alert.messageText = "Konfirmasi Penghapusan \(namaGuruString)"
        alert.informativeText = "Apakah Anda yakin akan menghapus data \(namaGuruString)?"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusGuruAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        alert.showsSuppressionButton = true

        guard !isSuppressed else { hapusRow(selectedRows, idToDelete: idToDelete); return }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { // Tombol "Hapus" diklik
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            hapusRow(selectedRows, idToDelete: idToDelete)
        }
    }

    /// Fungsi untuk mendapatkan indeks baris yang diklik kanan, kemudian mengiterasi index
    /// untuk mendapatkan id dan nama guru, menampilkan `NSAlert` dan kemudian menjalankan fungsi ``hapusRow(_:idToDelete:)``.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteData(_ sender: Any) {
        let clickedRow = outlineView.clickedRow

        // Pastikan clickedRow valid
        guard clickedRow >= 0 else {
            return
        }

        var idToDelete = Set<Int64>() // Menggunakan set untuk menyimpan idGuru yang akan dihapus
        var nama = String()
        // Mendapatkan item di row yang dipilih
        if let selectedItem = outlineView.item(atRow: clickedRow) {
            if let guru = selectedItem as? GuruModel {
                // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                nama = guru.namaGuru
                idToDelete.insert(guru.idGuru)
            } else if let mapel = selectedItem as? MapelModel {
                // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                nama = mapel.namaMapel
                for guru in mapel.guruList {
                    idToDelete.insert(guru.idGuru)
                }
            }
        }

        let alert = NSAlert()
        alert.messageText = "Konfirmasi Penghapusan \(nama)"
        alert.informativeText = "Apakah Anda yakin akan menghapus data \(nama)?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusGuruAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        alert.showsSuppressionButton = true

        guard !isSuppressed else { hapusRow([clickedRow], idToDelete: idToDelete); return }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { // Tombol "Hapus" diklik
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            hapusRow([clickedRow], idToDelete: idToDelete)
        }
    }

    /// Menangani penghapusan baris (baik `MapelModel` maupun `GuruModel`) dari `NSOutlineView`
    /// dan model data terkait. Fungsi ini mendukung penghapusan multi-item, manajemen undo,
    /// dan memperbarui UI tabel serta memicu penghapusan data dari database.
    ///
    /// - Parameters:
    ///   - selectedRows: `IndexSet` yang berisi indeks baris-baris yang dipilih di `outlineView`
    ///                   yang akan dihapus.
    ///   - idToDelete: `Set` dari `Int64` yang berisi ID unik dari item-item (`GuruModel`)
    ///                 yang akan dihapus dari database.
    func hapusRow(_ selectedRows: IndexSet, idToDelete: Set<Int64>) {
        var groupedDeletedData: [String: [GuruModel]] = [:] // Menyimpan data guru yang dihapus, dikelompokkan per Mapel.
        var mapelsToDelete: Set<MapelModel> = [] // Menyimpan objek Mapel yang akan dihapus.
        var gurusToDelete: [(guru: GuruModel, parentMapel: MapelModel)] = [] // Menyimpan objek Guru dan Mapel induknya.

        // --- Fase 1: Kumpulkan Semua Item yang Akan Dihapus ---
        // Iterasi melalui indeks baris yang dipilih dalam urutan terbalik.
        // Iterasi terbalik penting saat menghapus item dari koleksi untuk mencegah masalah indeks.
        for row in selectedRows.reversed() {
            // Mendapatkan item dari `outlineView` pada baris tertentu.
            if let selectedItem = outlineView.item(atRow: row) {
                // Jika item adalah `MapelModel` (item level teratas).
                if let mapel = selectedItem as? MapelModel {
                    mapelsToDelete.insert(mapel) // Tambahkan Mapel ke set untuk dihapus.
                    // Tambahkan semua guru di bawah Mapel ini ke `groupedDeletedData`
                    // untuk keperluan undo.
                    groupedDeletedData[mapel.namaMapel, default: []].append(contentsOf: mapel.guruList)
                }
                // Jika item adalah `GuruModel` (anak dari `MapelModel`).
                else if let guru = selectedItem as? GuruModel,
                        let parentItem = outlineView.parent(forItem: selectedItem) as? MapelModel
                {
                    // Tambahkan Guru dan Mapel induknya ke daftar untuk dihapus.
                    gurusToDelete.append((guru, parentItem))
                    // Tambahkan guru ini ke `groupedDeletedData` di bawah nama Mapel induknya.
                    groupedDeletedData[parentItem.namaMapel, default: []].append(guru)
                }
            }
        }

        // --- Fase 2: Mulai Pembaruan UI dan Grup Undo ---
        outlineView.beginUpdates() // Memulai pembaruan batch untuk `outlineView` untuk kinerja.
        myUndoManager.beginUndoGrouping() // Memulai grup undo untuk mengelompokkan semua operasi penghapusan ini.

        // --- Fase 3: Hapus Mapel dari Model Data dan UI ---
        for mapel in mapelsToDelete {
            // Cari indeks Mapel dalam daftar `mapelList` global.
            if let indexInMapelList = mapelList.firstIndex(where: { $0 === mapel }) {
                mapelList.remove(at: indexInMapelList) // Hapus Mapel dari model data.
                // Hapus item dari `outlineView` dengan animasi `effectFade`.
                outlineView.removeItems(at: IndexSet(integer: indexInMapelList),
                                        inParent: nil, // `nil` karena ini adalah item level teratas.
                                        withAnimation: .effectFade)
            }
        }

        // --- Fase 4: Hapus Guru dari Model Data dan UI ---
        // Pastikan untuk tidak menghapus guru jika Mapel induknya sudah dihapus secara keseluruhan.
        for (guru, parentMapel) in gurusToDelete {
            if !mapelsToDelete.contains(parentMapel) { // Hanya hapus guru jika parent-nya belum dihapus sebelumnya.
                // Cari indeks guru dalam daftar `guruList` dari Mapel induknya.
                if let indexInGuruList = parentMapel.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                    SingletonData.deletedGuru.insert(guru.idGuru) // Tambahkan ID guru ke set guru yang dihapus di SingletonData.
                    parentMapel.guruList.remove(at: indexInGuruList) // Hapus guru dari daftar guru Mapel induknya.

                    // Hapus item guru dari `outlineView` dengan animasi `slideDown`.
                    outlineView.removeItems(at: IndexSet([indexInGuruList]),
                                            inParent: parentMapel, // Tentukan parent item guru.
                                            withAnimation: .slideDown)

                    // --- Sub-Fase: Hapus Mapel Induk Jika Menjadi Kosong ---
                    // Jika setelah menghapus guru, `guruList` dari Mapel induk menjadi kosong,
                    // dan Mapel tersebut belum ditandai untuk dihapus sebelumnya (oleh penghapusan langsung Mapel),
                    // maka hapus juga Mapel induknya.
                    if parentMapel.guruList.isEmpty,
                       let indexInMapelList = mapelList.firstIndex(where: { $0 === parentMapel })
                    {
                        mapelList.remove(at: indexInMapelList) // Hapus Mapel dari model data.
                        // Hapus Mapel dari `outlineView`.
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList),
                                                inParent: nil,
                                                withAnimation: .effectFade)
                    }
                }
            }
        }

        // --- Fase 5: Perbarui Seleksi UI Setelah Penghapusan ---
        // Dispatch ke antrean utama untuk memastikan pembaruan UI terjadi setelah operasi batch selesai.
        DispatchQueue.main.async {
            // Jika masih ada baris di tabel setelah penghapusan.
            if self.outlineView.numberOfRows > 0 {
                // Tentukan baris baru yang harus dipilih: baris pertama yang dipilih sebelumnya,
                // atau baris terakhir jika baris yang dipilih sebelumnya sudah dihapus.
                let newSelectedRow = min(selectedRows.first ?? 0, self.outlineView.numberOfRows - 1)
                // Pilih baris baru.
                self.outlineView.selectRowIndexes(IndexSet([newSelectedRow]),
                                                  byExtendingSelection: false)
                // Gulir tabel agar baris yang dipilih terlihat.
                self.outlineView.scrollRowToVisible(newSelectedRow)
            }
        }

        // --- Fase 6: Daftarkan Operasi Undo ---
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            // Saat undo dipicu, panggil `undoHapus` dengan data yang dikelompokkan yang telah dihapus.
            targetSelf.undoHapus(groupedDeletedData: groupedDeletedData)
        }
        myUndoManager.endUndoGrouping() // Mengakhiri grup undo.
        outlineView.endUpdates() // Mengakhiri pembaruan batch untuk `outlineView`.

        // Hapus semua operasi redo yang ada karena status aplikasi telah berubah.
        deleteAllRedoArray()
        // Tunda pembaruan status tombol undo/redo sedikit untuk memastikan UI telah stabil.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUndoRedo(self) // Memperbarui status tombol undo/redo di UI.
        }

        // --- Fase 7: Konfirmasi Penghapusan Database ---
        // Panggil fungsi `confirmDelete` untuk secara permanen menghapus data dari database.
        // Ini biasanya merupakan operasi yang tidak dapat di-undo dari sisi database.
        confirmDelete(idsToDelete: idToDelete)
    }

    /// Melakukan operasi 'undo' (pembatalan) untuk tindakan penghapusan data guru dan mapel.
    /// Fungsi ini mengembalikan item-item yang sebelumnya dihapus ke `NSOutlineView` dan model data
    /// terkait, sambil mempertahankan urutan pengurutan yang benar. Ini juga mengatur ulang status undo/redo
    /// dan menghapus ID guru dari daftar yang dihapus secara permanen.
    ///
    /// - Parameter groupedDeletedData: Sebuah `Dictionary` yang berisi data `GuruModel`
    ///                                 yang dihapus, dikelompokkan berdasarkan nama Mapel-nya.
    ///                                 Kunci dictionary adalah `namaMapel` (String), dan nilai
    ///                                 adalah array `GuruModel` yang dihapus dari Mapel tersebut.
    func undoHapus(groupedDeletedData: [String: [GuruModel]]) {
        // Mendapatkan `NSSortDescriptor` pertama dari `outlineView`. Jika tidak ada, gunakan default
        // yang mengurutkan berdasarkan "NamaGuru" secara ascending. Ini penting untuk
        // memastikan item dikembalikan ke posisi yang benar dalam urutan yang diurutkan.
        let sortDescriptor = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: true)
        var itemIndex = IndexSet() // Digunakan untuk menyimpan indeks baris yang dikembalikan untuk seleksi nanti.

        // Memulai pembaruan batch untuk `outlineView` untuk meningkatkan kinerja saat
        // melakukan beberapa operasi penyisipan.
        outlineView.beginUpdates()

        // Iterasi melalui data guru yang dihapus, dikelompokkan berdasarkan nama Mapel.
        for (namaMapel, deletedGurus) in groupedDeletedData {
            let targetMapel: MapelModel // Akan menyimpan objek Mapel tempat guru akan dikembalikan.
            var mapelIndex: Int! // Indeks tempat Mapel (jika baru) akan disisipkan.

            // Mencoba menemukan Mapel yang sudah ada dengan `namaMapel` yang sama di `mapelList` (model data utama).
            if let existingMapel = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                targetMapel = existingMapel // Gunakan Mapel yang sudah ada.
            } else {
                // Jika Mapel tidak ditemukan (berarti Mapel itu sendiri yang dihapus sebelumnya),
                // buat instance `MapelModel` baru.
                targetMapel = MapelModel(id: UUID(), namaMapel: namaMapel, guruList: [])

                // Tentukan indeks penyisipan untuk Mapel baru agar tetap terurut dalam `mapelList`.
                // Gunakan `sortDescriptor` dari tabel, tetapi terapkan pada kolom "Mapel".
                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
                mapelIndex = mapelList.insertionIndex(for: targetMapel, using: sortMapel)

                // Sisipkan Mapel baru ke dalam `mapelList` pada indeks yang dihitung.
                mapelList.insert(targetMapel, at: mapelIndex)

                // Sisipkan item Mapel ke dalam `outlineView` pada posisi yang benar dengan animasi fade.
                outlineView.insertItems(at: IndexSet(integer: mapelIndex), inParent: nil, withAnimation: .effectFade)
            }

            // Memastikan Mapel diperluas di outline view agar guru-guru di dalamnya terlihat.
            outlineView.expandItem(targetMapel)

            // Iterasi melalui setiap guru yang dihapus dari Mapel ini.
            for guru in deletedGurus {
                // Periksa apakah guru ini belum ada di `guruList` Mapel target.
                // Ini mencegah duplikasi jika undo dipanggil berulang kali atau jika guru sudah ditambahkan kembali.
                if !targetMapel.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
                    // Tentukan indeks penyisipan yang aman untuk guru baru di dalam `guruList` Mapel target.
                    // Menggunakan `safeInsertionIndex` untuk menjaga urutan.
                    let insertionIndex = safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)

                    // Sisipkan guru kembali ke `guruList` Mapel target pada indeks yang dihitung.
                    targetMapel.guruList.insert(guru, at: insertionIndex)

                    // Tambahkan ID guru ini ke `redoHapus` array. Ini menyiapkan operasi 'redo'
                    // jika pengguna memutuskan untuk membatalkan undo ini.
                    redoHapus.append(guru.idGuru)
                    // Hapus ID guru ini dari `undoHapus` karena sekarang sudah di-undo.
                    undoHapus.removeAll(where: { $0 == guru.idGuru })

                    // Sisipkan item guru ke dalam `outlineView` di bawah Mapel induknya
                    // dengan animasi `effectGap` (animasi celah).
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: targetMapel, withAnimation: .effectGap)
                }

                // Jika ID guru ini masih ada di `SingletonData.deletedGuru` (daftar ID yang akan dihapus dari DB),
                // hapus dari sana karena sekarang sudah di-undo dan tidak perlu dihapus secara permanen.
                if let index = SingletonData.deletedGuru.firstIndex(of: guru.idGuru) {
                    SingletonData.deletedGuru.remove(at: index)
                }
            }
        }

        // Mengakhiri pembaruan batch untuk `outlineView`, memicu pembaruan visual.
        outlineView.endUpdates()

        // --- Pembaruan Seleksi Setelah Undo ---
        // Jadwalkan pembaruan seleksi dan scroll ke antrean utama setelah sedikit penundaan.
        // Ini memastikan UI telah selesai memproses semua penyisipan.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Iterasi melalui data yang baru saja di-undo untuk mengumpulkan indeks baris penuhnya di `outlineView`.
            for (_, deletedGurus) in groupedDeletedData {
                for guru in deletedGurus {
                    // Mendapatkan indeks baris di `outlineView` untuk objek guru yang dikembalikan.
                    let fullIndex = self.outlineView.row(forItem: guru)
                    if fullIndex != -1 {
                        itemIndex.insert(fullIndex) // Tambahkan indeks ke set `itemIndex`.
                    }
                }
            }
            // Pilih semua baris yang baru saja di-undo.
            self.outlineView.selectRowIndexes(itemIndex, byExtendingSelection: false)
            // Gulir ke baris terakhir yang dipilih (jika ada) agar terlihat di tampilan.
            if let max = itemIndex.max() {
                self.outlineView.scrollRowToVisible(max)
            }
        }

        // --- Mendaftarkan Operasi Redo ---
        // Mendaftarkan operasi 'redo' ke `myUndoManager`. Ini memungkinkan pengguna
        // untuk membatalkan 'undo' ini (yaitu, melakukan 'redo' penghapusan).
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            // Saat redo dipicu, panggil `redoHapus` dengan data yang dikelompokkan.
            targetSelf.redoHapus(data: groupedDeletedData)
        }

        // Memperbarui status tombol undo/redo di UI setelah penundaan singkat
        // untuk memungkinkan `myUndoManager` dan UI stabil.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUndoRedo(self)
        }
    }

    /// Melakukan operasi 'redo' (pengulangan) untuk tindakan penghapusan data guru dan mapel yang diurungkan.
    /// Fungsi ini menghapus item-item yang sebelumnya dihapus kemudian diurungkan ke `NSOutlineView` dan model data
    /// terkait, sambil mempertahankan urutan pengurutan yang benar. Ini juga mengatur ulang status undo/redo
    /// dan menghapus ID guru dari daftar yang dihapus secara permanen.
    ///
    /// - Parameter groupedDeletedData: Sebuah `Dictionary` yang berisi data `GuruModel`
    ///                                 yang dihapus, dikelompokkan berdasarkan nama Mapel-nya.
    ///                                 Kunci dictionary adalah `namaMapel` (String), dan nilai
    ///                                 adalah array `GuruModel` yang dihapus dari Mapel tersebut.
    func redoHapus(data: [String: [GuruModel]]) {
        outlineView.beginUpdates()
        for (namaMapel, guruList) in data {
            if let parentItem = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                for guru in guruList {
                    if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                        SingletonData.deletedGuru.insert(guru.idGuru)
                        redoHapus.removeAll(where: { $0 == guru.idGuru })
                        undoHapus.append(guru.idGuru)
                        // Hapus guru dari parentItem

                        parentItem.guruList.remove(at: indexInGuruList)

                        // Hapus dari outlineView
                        let row = outlineView.row(forItem: guru) + 1
                        if row != -1, !outlineView.isExpandable(guru), row <= outlineView.numberOfRows {
                            outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                            outlineView.scrollRowToVisible(row)
                        } else {
                            guard row <= outlineView.numberOfRows else {
                                outlineView.scrollRowToVisible(row - 1)
                                return
                            }
                            outlineView.selectRowIndexes(IndexSet([row + 1]), byExtendingSelection: false)
                        }
                        outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .slideDown)
                        // outlineView.selectRowIndexes(IndexSet([indexInGuruList]), byExtendingSelection: false)
                    }
                }
                // Hapus mapel jika tidak ada guru yang tersisa
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoHapus(groupedDeletedData: data)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            updateUndoRedo(self)
        }
    }

    /// Melakukan operasi 'undo' (pembatalan) untuk tindakan penambahan data guru.
    /// Fungsi ini akan menghapus kembali guru-guru yang sebelumnya ditambahkan
    /// ke dalam `NSOutlineView` dan model data terkait. Jika penghapusan guru
    /// menyebabkan sebuah mapel menjadi kosong, mapel tersebut juga akan dihapus.
    /// Ini juga mengelola status undo/redo.
    ///
    /// - Parameter data: Sebuah `Dictionary` yang berisi data `GuruModel` yang sebelumnya
    ///                   ditambahkan, dikelompokkan berdasarkan nama Mapel-nya.
    ///                   Kunci dictionary adalah `namaMapel` (String), dan nilainya
    ///                   adalah array `GuruModel` yang akan dihapus.
    func undoTambah(data: [String: [GuruModel]]) {
        // Memulai pembaruan batch untuk `outlineView` untuk meningkatkan kinerja
        // saat melakukan beberapa operasi penghapusan.
        outlineView.beginUpdates()

        // Iterasi melalui data yang disediakan, yang mewakili guru-guru yang
        // sebelumnya ditambahkan dan sekarang perlu di-'undo' (dihapus).
        for (namaMapel, guruList) in data {
            // Mencari Mapel induk yang sesuai dalam `mapelList` (model data utama)
            // berdasarkan `namaMapel`.
            if let parentItem = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                // Iterasi melalui daftar guru yang terkait dengan Mapel ini dalam data input.
                for guru in guruList {
                    // Mencoba menemukan indeks guru dalam `guruList` dari Mapel induknya.
                    // Ini penting untuk memastikan kita menghapus instance guru yang benar.
                    if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == guru.idGuru }) {
                        // Menambahkan ID guru ke `SingletonData.undoAddGuru`.
                        // Ini menandakan bahwa guru ini telah di-'undo' dari operasi penambahan,
                        // dan mungkin perlu dihapus dari database nanti.
                        SingletonData.undoAddGuru.insert(guru.idGuru)

                        // Menghapus ID guru ini dari `undoHapus` jika ada. Ini mungkin
                        // relevan jika ada interaksi yang kompleks dengan operasi undo/redo lainnya.
                        undoHapus.removeAll(where: { $0 == guru.idGuru })
                        // Menambahkan ID guru ini ke `redoHapus`, menyiapkan operasi 'redo'
                        // jika pengguna memutuskan untuk membatalkan 'undo' ini.
                        redoHapus.append(guru.idGuru)

                        // Hapus guru dari daftar `guruList` di model data `parentItem`.
                        parentItem.guruList.remove(at: indexInGuruList)

                        // --- Logika Seleksi UI (Perlu Peninjauan) ---
                        // Dapatkan indeks baris di `outlineView` untuk guru ini, lalu tambahkan 1.
                        // Ini tampaknya mencoba memilih baris berikutnya setelah yang dihapus,
                        // namun logika `row + 1` dan kondisionalnya (`!outlineView.isExpandable(guru)`)
                        // serta `row <= outlineView.numberOfRows` terlihat kompleks dan mungkin
                        // memerlukan validasi lebih lanjut untuk memastikan perilaku yang diharapkan
                        // pada semua skenario penghapusan dan struktur outline view.
                        let row = outlineView.row(forItem: guru) + 1
                        if row != -1, !outlineView.isExpandable(guru), row <= outlineView.numberOfRows {
                            // Jika kondisinya terpenuhi, pilih baris dan gulir ke sana.
                            outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                            outlineView.scrollRowToVisible(row)
                        } else {
                            // Jika tidak, ada kondisi lain, misalnya baris sudah tidak ada,
                            // atau mencoba menggulir ke baris sebelumnya.
                            guard row <= outlineView.numberOfRows else {
                                outlineView.scrollRowToVisible(row - 1)
                                return
                            }
                            outlineView.selectRowIndexes(IndexSet([row + 1]), byExtendingSelection: false)
                        }

                        // Hapus item guru dari `outlineView` dengan animasi `slideDown`.
                        outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .slideDown)
                    }
                }

                // --- Hapus Mapel Jika Kosong ---
                // Setelah menghapus guru, periksa apakah `guruList` dari `parentItem` menjadi kosong.
                if parentItem.guruList.isEmpty {
                    // Jika ya, cari indeks Mapel dalam daftar `mapelList` global.
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        // Hapus Mapel dari model data `mapelList`.
                        mapelList.remove(at: indexInMapelList)
                        // Hapus item Mapel dari `outlineView` dengan animasi fade.
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
        }

        // Mengakhiri pembaruan batch untuk `outlineView`.
        outlineView.endUpdates()

        // Mendaftarkan operasi 'redo' ke `myUndoManager`. Ini memungkinkan pengguna
        // untuk membatalkan 'undo' ini (yaitu, melakukan 'redo' penambahan).
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoTambah(groupedDeletedData: data)
        }

        // Memperbarui status tombol undo/redo di UI setelah penundaan singkat
        // untuk memungkinkan `myUndoManager` dan UI stabil.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            self.updateUndoRedo(self)
        }
    }

    /// Melakukan operasi 'redo' (pengulangan) untuk tindakan penambahan data guru yang diurungkan.
    /// Fungsi ini akan menambahkan kembali guru-guru yang sebelumnya ditambahkan kemudian diurungkan
    /// ke dalam `NSOutlineView` dan model data terkait. Jika penambahan guru
    /// ke sebuah mapel baru, mapel tersebut juga akan dibuat.
    /// Ini juga mengelola status undo/redo.
    ///
    /// - Parameter data: Sebuah `Dictionary` yang berisi data `GuruModel` yang sebelumnya
    ///                   ditambahkan kemudian diurungkan, dikelompokkan berdasarkan nama Mapel-nya.
    ///                   Kunci dictionary adalah `namaMapel` (String), dan nilainya
    ///                   adalah array `GuruModel` yang akan dihapus.
    func redoTambah(groupedDeletedData: [String: [GuruModel]]) {
        let sortDescriptor = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: true)
        var newMapels: [MapelModel] = []
        var updatedMapels: [MapelModel] = []
        var itemIndex = IndexSet()
        for data in groupedDeletedData.reversed() {
            let targetMapel: MapelModel
            let isNewMapel: Bool
            var mapelIndex: Int!
            if let existingMapel = mapelList.first(where: { $0.namaMapel == data.key }) {
                targetMapel = existingMapel
                updatedMapels.append(targetMapel)
                isNewMapel = false
            } else {
                targetMapel = MapelModel(id: UUID(), namaMapel: data.key, guruList: [])
                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
                mapelIndex = mapelList.insertionIndex(for: targetMapel, using: sortMapel)
                mapelList.insert(targetMapel, at: mapelIndex)
                newMapels.append(targetMapel)
                isNewMapel = true
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.outlineView.beginUpdates()

                if isNewMapel {
                    self.outlineView.insertItems(at: IndexSet(integer: mapelIndex), inParent: nil, withAnimation: .effectFade)
                }

                for guru in data.value {
                    if !targetMapel.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
                        // Menentukan posisi insersi yang aman
                        let insertionIndex = self.safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)
                        targetMapel.guruList.insert(guru, at: insertionIndex)
                        self.undoHapus.append(guru.idGuru)
                        self.redoHapus.removeAll(where: { $0 == guru.idGuru })

                        // Insert ke outlineView
                        self.outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: targetMapel, withAnimation: .effectGap)
                        self.outlineView.expandItem(targetMapel)
                    }
                    if SingletonData.undoAddGuru.contains(guru.idGuru) {
                        if let index = SingletonData.undoAddGuru.firstIndex(of: guru.idGuru) {
                            SingletonData.undoAddGuru.remove(at: index)
                        } else {}
                    } else {}
                }

                self.outlineView.endUpdates()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    for guru in data.value {
                        let fullIndex = self.outlineView.row(forItem: guru)
                        if fullIndex != -1 {
                            itemIndex.insert(fullIndex)
                        }
                    }
                    self.outlineView.selectRowIndexes(itemIndex, byExtendingSelection: false)
                    if let max = itemIndex.max() {
                        self.outlineView.scrollRowToVisible(max)
                    }
                }
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoTambah(data: groupedDeletedData)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            self.updateUndoRedo(self)
        }
    }

    /// Fungsi helper untuk menentukan indeks insersi yang aman
    /// Menentukan indeks penyisipan yang aman untuk objek `GuruModel` baru ke dalam daftar `guruList`
    /// dari sebuah `MapelModel`, berdasarkan `NSSortDescriptor` yang diberikan.
    /// Fungsi ini menciptakan komparator dinamis berdasarkan kunci pengurutan dan arahnya,
    /// kemudian mencari posisi yang tepat untuk menyisipkan guru baru sambil menjaga urutan.
    ///
    /// - Parameters:
    ///   - guru: Objek `GuruModel` yang akan disisipkan.
    ///   - mapel: Objek `MapelModel` di mana `guru` akan disisipkan ke dalam `guruList` miliknya.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan
    ///                     (kunci kolom dan arah ascending/descending).
    /// - Returns: `Int` yang merupakan indeks penyisipan yang direkomendasikan. Jika `guru`
    ///            harus ditempatkan di akhir daftar, jumlah elemen dalam `guruList` akan dikembalikan.
    func safeInsertionIndex(for guru: GuruModel, in mapel: MapelModel, using sortDescriptor: NSSortDescriptor) -> Int {
        // Mendeklarasikan closure `comparator` yang akan digunakan untuk membandingkan dua objek `GuruModel`.
        // Closure ini akan ditentukan berdasarkan `sortDescriptor.key`.
        let comparator: (GuruModel, GuruModel) -> Bool

            // Menggunakan `switch` untuk menentukan logika perbandingan berdasarkan `sortDescriptor.key`.
            = switch sortDescriptor.key
        {
        case "NamaGuru":
            // Jika kunci adalah "NamaGuru", bandingkan berdasarkan properti `namaGuru`.
            // Jika ascending, `guru1.namaGuru < guru2.namaGuru`. Jika descending, `guru1.namaGuru > guru2.namaGuru`.
            { sortDescriptor.ascending ? $0.namaGuru < $1.namaGuru : $0.namaGuru > $1.namaGuru }
        case "AlamatGuru":
            // Jika kunci adalah "AlamatGuru", bandingkan berdasarkan properti `alamatGuru`.
            { sortDescriptor.ascending ? $0.alamatGuru < $1.alamatGuru : $0.alamatGuru > $1.alamatGuru }
        case "TahunAktif":
            // Jika kunci adalah "TahunAktif", bandingkan berdasarkan properti `tahunaktif`.
            { sortDescriptor.ascending ? $0.tahunaktif < $1.tahunaktif : $0.tahunaktif > $1.tahunaktif }
        case "Mapel":
            // Jika kunci adalah "Mapel", bandingkan berdasarkan properti `mapel`.
            { sortDescriptor.ascending ? $0.mapel < $1.mapel : $0.mapel > $1.mapel }
        case "Struktural":
            // Jika kunci adalah "Struktural", bandingkan berdasarkan properti `struktural`.
            { sortDescriptor.ascending ? $0.struktural < $1.struktural : $0.struktural > $1.struktural }
        default:
            // Jika kunci tidak cocok dengan kasus di atas, gunakan komparator default yang selalu mengembalikan `true`.
            // Ini berarti elemen baru akan disisipkan di awal jika tidak ada kriteria pengurutan spesifik.
            { _, _ in true }
        }

        // Mencari indeks pertama dalam `mapel.guruList` di mana `comparator` mengembalikan `true`.
        // Ini adalah posisi di mana `guru` yang baru harus disisipkan agar urutan tetap terjaga.
        // Jika tidak ada elemen yang memenuhi kondisi (yaitu, `guru` harus ditempatkan di akhir),
        // maka `firstIndex(where:)` akan mengembalikan `nil`, dan operator `??` akan
        // mengembalikan `mapel.guruList.count`, yang merupakan indeks di luar elemen terakhir
        // (posisi yang tepat untuk penambahan di akhir).
        return mapel.guruList.firstIndex(where: { comparator(guru, $0) }) ?? mapel.guruList.count
    }

    /// Menambahkan ID guru yang akan dihapus ke dalam set `deletedGuru` di `SingletonData`.
    /// Fungsi ini bertindak sebagai penampung untuk ID-ID guru yang telah ditandai untuk dihapus
    /// dari database, memastikan bahwa ID tersebut tercatat untuk operasi penghapusan permanen nanti.
    ///
    /// - Parameter idsToDelete: `Set` dari `Int64` yang berisi ID unik dari guru-guru
    ///                          yang telah dihapus dari UI/model data lokal dan siap
    ///                          untuk dihapus secara permanen dari database.
    func confirmDelete(idsToDelete: Set<Int64>) {
        // Menggabungkan (union) `idsToDelete` ke dalam `SingletonData.deletedGuru`.
        // Ini berarti semua ID yang ada di `idsToDelete` akan ditambahkan ke `deletedGuru`
        // jika belum ada, memastikan setiap ID unik tercatat sekali untuk penghapusan.
        SingletonData.deletedGuru.formUnion(idsToDelete)
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

    /// Properti `NSTextField` nama untuk menambah/mengedit data.
    var nameTextField: NSTextField!
    /// Properti `NSTextField` alamat untuk menambah/mengedit data.
    var addressTextField: NSTextField!
    /// Properti `NSTextField` tahun aktif untuk menambah/mengedit data.
    var yearTextField: NSTextField!
    /// Properti `NSTextField` mata pelajaran untuk menambah/mengedit data.
    var mapelTextField: NSTextField!
    /// Properti `NSTextField` struktur untuk menambah/mengedit data.
    var strukturTextField: NSTextField!

    /// Properti data guru dari baris-baris yang dipilih di ``outlineView`` yang akan diedit.
    var selectedRowToEdit: [GuruModel] = []

    /// Properti `Bool` yang mengontrol apakah teks di beberapa `NSTextField` harus dikapitalisasi
    /// secara otomatis atau tidak.
    ///
    /// Ketika nilai `kapitalkan` berubah menjadi `true`:
    /// 1. Semua teks di `nameTextField`, `addressTextField`, `mapelTextField`, dan `strukturTextField`
    ///    akan dikonversi menjadi huruf kapital. Ini dilakukan dengan memanggil metode `kapitalkanSemua()`
    ///    pada array `NSTextField` tersebut.
    /// 2. Jika `selectedRowToEdit.count` (jumlah baris yang dipilih untuk diedit) lebih dari satu,
    ///    maka `placeholderString` dari setiap `NSTextField` tersebut juga akan dikapitalisasi.
    ///    Ini berguna untuk memberikan indikasi visual pada placeholder bahwa input akan dikapitalisasi
    ///    saat dalam mode pengeditan multi-baris.
    ///
    /// Properti ini tidak melakukan tindakan apa pun jika `kapitalkan` diatur menjadi `false`.
    var kapitalkan: Bool = false {
        didSet {
            if kapitalkan { // Memeriksa apakah nilai baru `kapitalkan` adalah `true`.
                // Mengkapitalisasi teks di semua text field yang relevan.
                [nameTextField, addressTextField, mapelTextField, strukturTextField].kapitalkanSemua()

                // Logika khusus untuk pengeditan multi-baris.
                if selectedRowToEdit.count > 1 {
                    let fields = [nameTextField, addressTextField, mapelTextField, strukturTextField]
                    // Mengkapitalisasi placeholder string untuk setiap field.
                    for field in fields {
                        field?.placeholderString = (field?.placeholderString?.capitalized ?? "")
                    }
                }
            }
        }
    }

    /// Properti `Bool` yang mengontrol apakah teks di beberapa `NSTextField` harus dikonversi
    /// menjadi huruf besar secara otomatis atau tidak.
    ///
    /// Ketika nilai `hurufBesar` berubah menjadi `true`:
    /// 1. Semua teks yang ada di dalam `nameTextField`, `addressTextField`, `mapelTextField`, dan `strukturTextField`
    ///    akan dikonversi menjadi huruf besar. Ini dilakukan dengan memanggil metode ekstensi `hurufBesarSemua()`
    ///    pada koleksi `NSTextField` tersebut.
    /// 2. Jika ada lebih dari satu baris yang dipilih untuk diedit (`selectedRowToEdit.count > 1`),
    ///    maka teks `placeholderString` dari setiap `NSTextField` tersebut juga akan dikonversi menjadi huruf besar.
    ///    Ini memberikan isyarat visual kepada pengguna bahwa input yang diharapkan akan dalam format huruf besar
    ///    ketika melakukan pengeditan multi-baris.
    ///
    /// Properti ini tidak melakukan tindakan apa pun jika `hurufBesar` diatur menjadi `false`.
    var hurufBesar: Bool = false {
        didSet {
            if hurufBesar { // Memeriksa apakah nilai baru `hurufBesar` adalah `true`.
                // Mengkonversi teks di semua `NSTextField` yang relevan menjadi huruf besar.
                [nameTextField, addressTextField, mapelTextField, strukturTextField].hurufBesarSemua()

                // Logika tambahan khusus untuk skenario pengeditan multi-baris.
                if selectedRowToEdit.count > 1 {
                    let fields = [nameTextField, addressTextField, mapelTextField, strukturTextField]
                    // Mengkonversi `placeholderString` dari setiap field menjadi huruf besar.
                    for field in fields {
                        field?.placeholderString = (field?.placeholderString?.uppercased() ?? "")
                    }
                }
            }
        }
    }

    /// Properti contentView akan diinisialisasi hanya sekali saat pertama kali diakses.
    lazy var contentView: NSVisualEffectView = {
        let windowWidth: CGFloat = 430
        let windowHeight: CGFloat = 290
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        view.wantsLayer = true
        // Setup layout atau subview statis yang tidak berubah di sini (jika ada)
        return view
    }()

    /// Properti `NSWindow`. Jendela untuk ditampilkan ketika
    /// akan menambahkan data atau mengedit data.
    lazy var guruWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 280),
                                   styleMask: [.titled, .closable],
                                   backing: .buffered,
                                   defer: false)

    /// Fungsi ini membuat konfigurasi``contentView`` yang menampung ``nameTextField``, ``addressTextField``, ``mapelTextField``, ``yearTextField``,  dan``strukturTextField``.
    /// ``contentView`` dimuat dalam jendela ``guruWindow``.
    ///
    /// Untuk menambah dan mengedit data.
    /// - Parameters:
    ///   - opsi: Opsi ini diperlukan untuk konfigurasi tampilan textField.
    ///   - guru: Data-data guru yang akan diedit jika opsi adalah "edit".
    func createTextFieldView(_ opsi: String, guru: [GuruModel]) {
        // Cek dulu apakah subview-subview sudah pernah dibuat
        if contentView.subviews.isEmpty {
            contentView.blendingMode = .behindWindow
            contentView.material = .windowBackground
            contentView.state = .followsWindowActiveState
            // Hanya lakukan inisialisasi subview sekali saja
            let fieldNames = ["Nama Guru:", "Alamat Guru:", "Tahun Aktif:", "Mata Pelajaran:", "Sebagai:"]
            let verticalSpacing: CGFloat = 33
            let labelWidth: CGFloat = 120
            let fieldWidth: CGFloat = 260
            let startY: CGFloat = 190
            let labelStartY: CGFloat = 235
            let buttonSize: CGFloat = 24

            // Label Title
            let labelString = (opsi == "edit") ? "Perbarui Data Guru" : "Masukkan Informasi Guru"
            let titleLabel = NSTextField(labelWithString: labelString)
            titleLabel.font = NSFont.preferredFont(forTextStyle: .title1)
            titleLabel.frame = NSRect(x: 20, y: labelStartY, width: 350, height: 30)
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.identifier = NSUserInterfaceItemIdentifier(rawValue: "titleLabel")
            contentView.addSubview(titleLabel)

            // Tombol kontrol (hanya dibuat sekali)
            let kapitalButton = NSButton(image: NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(kapitalkan(_:)))
            kapitalButton.isBordered = false
            kapitalButton.bezelStyle = .smallSquare
            kapitalButton.frame = NSRect(x: 409 - buttonSize, y: labelStartY + 1, width: buttonSize, height: buttonSize)
            contentView.addSubview(kapitalButton)

            let uppercaseButton = NSButton(image: NSImage(systemSymbolName: "character", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(hurufBesar(_:)))
            uppercaseButton.isBordered = false
            uppercaseButton.bezelStyle = .smallSquare
            uppercaseButton.frame = NSRect(x: 390 - buttonSize, y: labelStartY + 1, width: 19, height: buttonSize)
            contentView.addSubview(uppercaseButton)

            // Separator
            let separator = NSBox(frame: NSRect(x: 20, y: startY + 37, width: 430 - 40, height: 1))
            separator.boxType = .separator
            contentView.addSubview(separator)

            // Inisialisasi TextFields dan Label untuk setiap field
            for (i, labelText) in fieldNames.enumerated() {
                let y = startY - CGFloat(i) * verticalSpacing
                let label = NSTextField(labelWithString: labelText)
                label.frame = NSRect(x: 20, y: y - 4, width: labelWidth, height: 24)
                contentView.addSubview(label)

                let textField = NSTextField(frame: NSRect(x: 20 + labelWidth + 10, y: y, width: fieldWidth, height: 24))
                textField.bezelStyle = .roundedBezel
                textField.lineBreakMode = .byTruncatingTail
                textField.usesSingleLineMode = true
                textField.tag = i + 1
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                textField.delegate = self
                contentView.addSubview(textField)

                // Simpan referensi textField pada property kelas
                switch i {
                case 0: nameTextField = textField
                case 1: addressTextField = textField
                case 2: yearTextField = textField
                case 3: mapelTextField = textField
                case 4: strukturTextField = textField
                default: break
                }
            }

            // Tombol Simpan dan Batal (juga dibuat satu kali)
            let simpanButton = NSButton(title: "Simpan", target: self, action: (opsi == "edit") ? #selector(simpanEditedGuru(_:)) : #selector(simpanGuru(_:)))
            simpanButton.frame = NSRect(x: 430 - 95, y: 15, width: 80, height: 30)
            simpanButton.bezelStyle = .rounded
            simpanButton.keyEquivalent = "\r" // enter key
            simpanButton.identifier = NSUserInterfaceItemIdentifier(rawValue: "simpan")
            contentView.addSubview(simpanButton)

            let batalButton = NSButton(title: "Tutup", target: self, action: #selector(closeSheets(_:)))
            batalButton.frame = NSRect(x: 430 - 175, y: 15, width: 80, height: 30)
            batalButton.bezelStyle = .rounded
            batalButton.keyEquivalent = "\u{1b}" // escape key
            contentView.addSubview(batalButton)
        } else {
            // Jika contentView sudah dibuat,
            // kamu bisa memperbarui elemen-elemen seperti titleLabel jika diperlukan
            // atau reset nilai textField dengan cara yang lebih ringan

            contentView.window?.makeFirstResponder(nameTextField)

            nameTextField.stringValue = ""
            addressTextField.stringValue = ""
            yearTextField.stringValue = ""
            mapelTextField.stringValue = ""
            strukturTextField.stringValue = ""

            // Set action ketika tombol diklik.
            if let simpanButton = contentView.subviews.first(where: { $0.identifier?.rawValue == "simpan" }) as? NSButton {
                simpanButton.action = (opsi == "edit") ? #selector(simpanEditedGuru(_:)) : #selector(simpanGuru(_:))
            }
            // Set nama titel guruu window
            if let label = contentView.subviews.first(where: { $0.identifier?.rawValue == "titleLabel" }) as? NSTextField {
                label.stringValue = (opsi == "edit") ? "Edit data guru" : "Tambah data guru"
            }
        }

        // Update placeholder dan nilai sesuai kondisi opsi
        nameTextField.placeholderString = "ketik nama guru"
        addressTextField.placeholderString = "ketik alamat guru"
        yearTextField.placeholderString = "ketik tahun aktif"
        mapelTextField.placeholderString = "ketik mata pelajaran"
        strukturTextField.placeholderString = "ketik jabatan guru"

        // Ketika pilihan adalah edit.
        if opsi == "edit" {
            if guru.count > 1 {
                nameTextField.placeholderString = "memuat \(guru.count) data"
                addressTextField.placeholderString = "memuat \(guru.count) data"
                yearTextField.placeholderString = "memuat \(guru.count) data"
                mapelTextField.placeholderString = "memuat \(guru.count) data"
                strukturTextField.placeholderString = "memuat \(guru.count) data"
            } else if let guruData = guru.first {
                nameTextField.stringValue = guruData.namaGuru
                addressTextField.stringValue = guruData.alamatGuru
                yearTextField.stringValue = guruData.tahunaktif
                mapelTextField.stringValue = guruData.mapel
                strukturTextField.stringValue = guruData.struktural
            }
        } else {
            // Ketika pilihan adalah tambah data.
            nameTextField.stringValue = ""
            addressTextField.stringValue = ""
            yearTextField.stringValue = ""
            mapelTextField.stringValue = ""
            strukturTextField.stringValue = ""
        }

        // Buat atau update window untuk menampilkan contentView jika diperlukan
        guruWindow.center()

        guruWindow.contentView = contentView
        guruWindow.title = (opsi == "edit") ? "Edit Data Guru" : "Tambah Data Guru"
        guruWindow.makeKeyAndOrderFront(nil)

        // Misalnya, untuk menampilkan sebagai sheet dari window induk:
        view.window?.beginSheet(guruWindow, completionHandler: nil)
    }

    /// Fungsi untuk menjalankan logika ``createTextFieldView(_:guru:)`` dengan opsi "add"
    /// Menampilkan ``guruWindow`` untuk menambahkan guru baru.
    @objc func addGuru(_ sender: Any) {
        createTextFieldView("add", guru: [GuruModel]())
    }

    /// Fungsi untuk menyimpan guru baru setelah selesai menambahkan data guru baru
    /// melalui ``addGuru(_:)``.
    /// - Parameter sender: Objek pemicu.
    @objc func simpanGuru(_ sender: Any) {
        var groupedDeletedData: [String: [GuruModel]] = [:]

        // Ketika pengguna mengklik "Tambah"
        // Get the input values and add a new row to the table view
        var newNamaGuru = ""
        var newAlamatGuru = ""
        let tahunAktif = ""
        var newMapel = ""
        var sebagai = ""

        if hurufBesar {
            newNamaGuru = nameTextField.stringValue.uppercased()
            if newNamaGuru.isEmpty {
                newNamaGuru = "GURU"
            }
            newAlamatGuru = addressTextField.stringValue.uppercased()
            newMapel = mapelTextField.stringValue.uppercased()
            sebagai = strukturTextField.stringValue.uppercased()
        } else {
            newNamaGuru = nameTextField.stringValue.capitalizedAndTrimmed()
            if newNamaGuru.isEmpty {
                newNamaGuru = "Guru"
            }
            newAlamatGuru = addressTextField.stringValue.capitalizedAndTrimmed()
            newMapel = mapelTextField.stringValue.capitalizedAndTrimmed()
            sebagai = strukturTextField.stringValue.capitalizedAndTrimmed()
        }

        // Add the new data to the database
        guard let id = dbController.addGuruID(namaGuruValue: newNamaGuru, alamatGuruValue: newAlamatGuru, tahunaktifValue: tahunAktif, mapelValue: newMapel, struktur: sebagai) else { return }
        let guruBaru = GuruModel(idGuru: id, nama: newNamaGuru, alamat: newAlamatGuru, tahunaktif: tahunAktif, mapel: newMapel, struktural: sebagai)
        // Cek apakah MapelModel untuk mapel baru sudah ada di mapelList
        if let parentItem = mapelList.first(where: { $0.namaMapel == newMapel }) {
            // Jika sudah ada, tambahkan guru baru ke MapelModel tersebut
            let sortDescriptor = NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
            let insertionIndex = parentItem.guruList.insertionIndex(for: guruBaru, using: sortDescriptor)

            parentItem.guruList.insert(guruBaru, at: insertionIndex)
            if groupedDeletedData[newMapel] == nil {
                groupedDeletedData[newMapel] = []
            }
            groupedDeletedData[newMapel]?.append(guruBaru)

            // Update outlineView
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                outlineView.beginUpdates()
                outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: parentItem, withAnimation: .effectGap)
                outlineView.expandItem(parentItem) // Pastikan group row diexpand
                outlineView.endUpdates()
                // Pilih row guru yang baru ditambahkan
                let rowIndex = outlineView.row(forItem: guruBaru)
                if rowIndex != -1, rowIndex <= outlineView.numberOfRows {
                    outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
                }
            }

        } else {
            // Jika mapel belum ada, buat MapelModel baru dan tambahkan ke mapelList
            let newMapelModel = MapelModel(id: UUID(), namaMapel: newMapel, guruList: [guruBaru])
            let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
            let insertionIndex = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)

            mapelList.insert(newMapelModel, at: insertionIndex)
            if groupedDeletedData[newMapel] == nil {
                groupedDeletedData[newMapel] = []
            }
            groupedDeletedData[newMapel]?.append(guruBaru)
            // Update outlineView dengan mapel baru dan guru
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                outlineView.beginUpdates()
                outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: nil, withAnimation: .effectGap)
                outlineView.expandItem(newMapelModel) // Pastikan group row diexpand
                outlineView.endUpdates()
                // Pilih row guru yang baru ditambahkan
                let rowIndex = outlineView.row(forItem: guruBaru)
                if rowIndex != -1, rowIndex <= outlineView.numberOfRows {
                    outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
                }
            }
        }

        let deepCopied: [String: [GuruModel]] = groupedDeletedData.mapValues { list in
            list.map { $0.copy() }
        }

        for (_, guru) in deepCopied {
            for i in guru {
                undoHapus.append(i.idGuru)
            }
        }
        myUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoTambah(data: deepCopied)
        }
        updateUndoRedo(self)
        updateMenuItem(self)
        closeSheets(self)
    }

    /// Fungsi untuk menyimpan guru baru setelah selesai mengedit
    /// melalui ``edit(_:)``
    /// - Parameter sender: Objek pemicu.
    @objc func simpanEditedGuru(_ sender: Any) {
        guard !selectedRowToEdit.isEmpty else { return }
        outlineView.deselectAll(self)
        var oldData: [GuruModel] = []

        // Mulai pembaruan batch outlineView.
        outlineView.beginUpdates()
        for editedGuru in selectedRowToEdit { /* iterasi semua row yang dipilih untuk diedit. */
            let id = editedGuru.idGuru

            guard let parentItem = mapelList.first(where: { $0.guruList.contains(where: { $0.idGuru == id }) }) else {
                continue
            }

            // Mencari indeks guru dalam guruList di parentItem
            guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == id }) else {
                continue
            }
            let oldGuru = parentItem.guruList[indexInGuruList]
            oldData.append(oldGuru)

            let selectedGuru = parentItem.guruList[indexInGuruList]

            let updatedNamaGuru = ReusableFunc.teksFormat(nameTextField.stringValue, oldValue: oldGuru.namaGuru, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedAlamatGuru = ReusableFunc.teksFormat(addressTextField.stringValue, oldValue: oldGuru.alamatGuru, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedTahunAktif = ReusableFunc.teksFormat(yearTextField.stringValue, oldValue: oldGuru.tahunaktif, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedMapel = ReusableFunc.teksFormat(mapelTextField.stringValue, oldValue: oldGuru.mapel, hurufBesar: hurufBesar, kapital: kapitalkan)
            let updatedSebagai = ReusableFunc.teksFormat(strukturTextField.stringValue, oldValue: oldGuru.struktural, hurufBesar: hurufBesar, kapital: kapitalkan)

            let updatedGuru = GuruModel(
                idGuru: selectedGuru.idGuru,
                nama: updatedNamaGuru,
                alamat: updatedAlamatGuru,
                tahunaktif: updatedTahunAktif,
                mapel: updatedMapel,
                struktural: updatedSebagai
            )

            // Update the selected data in the database
            updateDataGuru(selectedGuru.idGuru, dataLama: selectedGuru, baru: updatedGuru)

            if let parentItem = outlineView.parent(forItem: selectedGuru) as? MapelModel {
                if selectedGuru.mapel != updatedMapel {
                    // Jika mapel berubah, pindahkan guru ke MapelModel baru
                    let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
                    guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == selectedGuru.idGuru }) else { continue }
                    // 1. Hapus guru dari mapel lama

                    // Hapus guru dari list mapel lama
                    parentItem.guruList.remove(at: indexInGuruList)

                    // Hapus dari outlineView jika indeks valid
                    outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .effectFade)
                    if parentItem.guruList.isEmpty {
                        if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                            mapelList.remove(at: indexInMapelList)
                            outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .slideUp)
                        }
                    }
                    // 2. Cek apakah mapel baru sudah ada di mapelList
                    if mapelList.first(where: { $0.namaMapel == updatedMapel }) == nil {
                        // Buat parent baru dengan array kosong
                        let newMapelModel = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                        let insertion = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)
                        mapelList.insert(newMapelModel, at: insertion)
                        outlineView.insertItems(at: IndexSet(integer: insertion), inParent: nil, withAnimation: .effectGap)
                        outlineView.expandItem(newMapelModel)

                        // Sekarang insert guru ke dalam guruList
                        let insertionIndex = newMapelModel.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                        newMapelModel.guruList.insert(updatedGuru, at: insertionIndex)
                        outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newMapelModel, withAnimation: .effectGap)

                        let row = outlineView.row(forItem: updatedGuru)
                        #if DEBUG
                            print("insertionRow:", row)
                        #endif
                        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                        outlineView.scrollRowToVisible(row)
                        continue
                    }

                    if let newParentItem = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                        // Tambahkan guru ke mapel baru
                        let insertionIndex = newParentItem.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                        newParentItem.guruList.insert(updatedGuru, at: insertionIndex)

                        // Update outlineView
                        outlineView.expandItem(newParentItem)
                        outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                        let row = outlineView.row(forItem: updatedGuru)
                        if row >= 0 {
                            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                            outlineView.scrollRowToVisible(row)
                        }
                    }
                } else if let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == selectedGuru.idGuru }) {
                    parentItem.guruList.remove(at: indexInGuruList)
                    // Tentukan posisi penyisipan untuk guru yang diperbarui
                    guard let sortDescriptor = outlineView.sortDescriptors.first else { return }
                    let insertionIndex = parentItem.guruList.insertionIndex(for: updatedGuru, using: sortDescriptor)
                    parentItem.guruList.insert(updatedGuru, at: insertionIndex)
                    outlineView.expandItem(parentItem)
                    // Pindahkan guru ke posisi baru dalam outlineView
                    if indexInGuruList < outlineView.numberOfChildren(ofItem: parentItem),
                       insertionIndex < outlineView.numberOfChildren(ofItem: parentItem)
                    {
                        outlineView.moveItem(at: indexInGuruList, inParent: parentItem, to: insertionIndex, inParent: parentItem)
                    }
                    outlineView.reloadItem(selectedGuru)
                    // Pilih kembali baris yang telah diperbarui
                    let row = outlineView.row(forItem: updatedGuru)
                    if row >= 0 {
                        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                        outlineView.scrollRowToVisible(row)
                    }
                    // Jika guruList menjadi kosong, hapus parentItem
                    if parentItem.guruList.isEmpty {
                        if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                            mapelList.remove(at: indexInMapelList)
                            if indexInMapelList < outlineView.numberOfRows {
                                outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                            }
                        }
                    }
                }
            }
        }
        // Akhiri pembaruan batch outlineView.
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] object in
            self?.undoEdit(guru: oldData)
        })
        deleteAllRedoArray()
        updateUndoRedo(self)
        updateMenuItem(self)
        closeSheets(self)
        selectedRowToEdit.removeAll()
    }

    /// Fungsi untuk menutup jendela sheet ``guruWindow``. dan mereset properti ``kapitalkan`` dan ``hurufBesar``.
    /// Menjalankan ``updateUndoRedo(_:)`` dan ``updateMenuItem(_:)``.
    /// - Parameter sender:
    @objc func closeSheets(_ sender: Any) {
        view.window?.endSheet(guruWindow)
        updateUndoRedo(self)
        updateMenuItem(self)
        kapitalkan = false
        hurufBesar = false
    }

    /// Action dari toolbar item ``DataSDI/WindowController/editToolbar``
    /// dan juga menu item klik kanan atau menu item edit di ``DataSDI/WindowController/actionToolbar``.
    /// Fungsi untuk mengedit data guru pada baris yang dipilih.
    /// Mengiterasi setiap data yang akan diedit dan menambahkannya ke ``selectedRowToEdit``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func edit(_ sender: Any) {
        selectedRowToEdit.removeAll()
        var selectedRow = IndexSet()
        /// clickedRow berada di luar baris selectedRow
        if outlineView.clickedRow != -1, !outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
            selectedRow = [outlineView.clickedRow]
            outlineView.selectRowIndexes(IndexSet([outlineView.clickedRow]), byExtendingSelection: false)
        }
        /// clickedRow berada pada baris selectedRow
        else if outlineView.clickedRow != -1, outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
            selectedRow = outlineView.selectedRowIndexes
        } else {
            selectedRow = outlineView.selectedRowIndexes
        }

        guard !selectedRow.isEmpty else { return }

        for row in selectedRow {
            guard let item = outlineView.item(atRow: row) else { continue }

            // Jika item merupakan MapelModel, ambil dan tambahkan semua child (misalnya: GuruModel)
            if let mapelItem = item as? MapelModel {
                let childCount = outlineView.numberOfChildren(ofItem: mapelItem)
                for childIndex in 0 ..< childCount {
                    if let child = outlineView.child(childIndex, ofItem: mapelItem) as? GuruModel {
                        // Tambahkan setiap child (guru) yang ditemukan
                        selectedRowToEdit.append(child)
                    }
                }
            }
            // Jika item merupakan GuruModel secara langsung, tambahkan saja
            else if let guruItem = item as? GuruModel {
                selectedRowToEdit.append(guruItem)
            }
        }
        createTextFieldView("edit", guru: selectedRowToEdit)
    }

    /// Action untuk tombol yang mengubah nilai ``kapitalkan`` ke true.
    /// Dan mengubah nilai ``hurufBesar`` ke false.
    @objc func kapitalkan(_ sender: Any) {
        kapitalkan = true
        hurufBesar = false
    }

    /// Action untuk tombol yang mengubah nilai ``hurufBesar`` ke true.
    /// Dan mengubah nilai ``kapitalkan`` ke false.
    @objc func hurufBesar(_ sender: Any) {
        hurufBesar = true
        kapitalkan = false
    }

    /// Logika yang mengurungkan pengeditan data guru.
    /// - Parameter guru: Data dari ``guruu`` yang akan diperbarui.
    func undoEdit(guru: [GuruModel]) {
        var editedID: [Int64] = []
        var editedGuru: [GuruModel] = []
        outlineView.deselectAll(self)

        outlineView.beginUpdates()
        for guru in guru {
            let id = guru.idGuru
            let updatedMapel = guru.mapel
            editedID.append(id)
            // Menelusuri semua item di outlineView untuk menemukan parent yang sesuai
            guard let parentItem = mapelList.first(where: { $0.guruList.contains(where: { $0.idGuru == id }) }) else {
                continue
            }

            // Mencari indeks guru dalam guruList di parentItem
            guard let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == id }) else {
                continue
            }

            let selectedGuru = parentItem.guruList[indexInGuruList]

            updateDataGuru(guru.idGuru, dataLama: selectedGuru, baru: guru)

            // Update data guru
            parentItem.guruList[indexInGuruList] = guru

            if selectedGuru.mapel != updatedMapel {
                // Jika mapel berubah, pindahkan guru ke MapelModel baru
                // Hapus guru lama dari guruList mapel lama
                let sortDescriptor = NSSortDescriptor(key: "Mapel", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
                parentItem.guruList.remove(at: indexInGuruList)
                outlineView.removeItems(at: IndexSet([indexInGuruList]), inParent: parentItem, withAnimation: .effectFade)
                // Jika mapel lama menjadi kosong, hapus dari mapelList
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .slideUp)
                    }
                }

                if mapelList.first(where: { $0.namaMapel == updatedMapel }) == nil {
                    // Buat parent baru dengan array kosong
                    let newMapelModel = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                    let insertion = mapelList.insertionIndex(for: newMapelModel, using: sortDescriptor)
                    mapelList.insert(newMapelModel, at: insertion)
                    outlineView.insertItems(at: IndexSet(integer: insertion), inParent: nil, withAnimation: .effectGap)
                    outlineView.expandItem(newMapelModel)

                    // Sekarang insert guru ke dalam guruList
                    let insertionIndex = newMapelModel.guruList.insertionIndex(for: guru, using: sortDescriptor)
                    newMapelModel.guruList.insert(guru, at: insertionIndex)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newMapelModel, withAnimation: .effectGap)

                    let row = outlineView.row(forItem: guru)
                    #if DEBUG
                        print("insertionRow:", row)
                    #endif
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    editedGuru.append(selectedGuru)
                    continue
                }

                // Cek apakah mapel baru sudah ada di mapelList
                if let newParentItem = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                    // Tambahkan guru ke MapelModel baru yang sudah ada
                    let insertionIndex = newParentItem.guruList.insertionIndex(for: guru, using: sortDescriptor)
                    newParentItem.guruList.insert(guru, at: insertionIndex)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                    outlineView.expandItem(newParentItem)

                    let row = outlineView.row(forItem: guru)
                    #if DEBUG
                        print("insertionRow:", row)
                    #endif
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    outlineView.scrollRowToVisible(row)
                }
            } else {
                let newParentItem: MapelModel
                parentItem.guruList.remove(at: indexInGuruList)

                // Find or create the new parent item
                if let existingMapel = mapelList.first(where: { $0.namaMapel == updatedMapel }) {
                    newParentItem = existingMapel
                } else {
                    newParentItem = MapelModel(id: UUID(), namaMapel: updatedMapel, guruList: [])
                    mapelList.append(newParentItem)
                    outlineView.insertItems(at: IndexSet(integer: mapelList.count - 1), inParent: nil, withAnimation: .effectGap)
                }

                // Insert the updated guru into the new parent item
                let insertionIndex = newParentItem.guruList.insertionIndex(for: guru, using: outlineView.sortDescriptors.first!)
                newParentItem.guruList.insert(guru, at: insertionIndex)

                outlineView.expandItem(newParentItem)
                if indexInGuruList != insertionIndex {
                    outlineView.removeItems(at: IndexSet(integer: indexInGuruList), inParent: parentItem, withAnimation: .effectFade)
                    outlineView.insertItems(at: IndexSet(integer: insertionIndex), inParent: newParentItem, withAnimation: .effectGap)
                } else {
                    outlineView.reloadItem(selectedGuru)
                }
                let row = outlineView.row(forItem: guru)
                if row >= 0 {
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    outlineView.scrollRowToVisible(row)
                }
                if parentItem.guruList.isEmpty {
                    if let indexInMapelList = mapelList.firstIndex(where: { $0 === parentItem }) {
                        mapelList.remove(at: indexInMapelList)
                        outlineView.removeItems(at: IndexSet(integer: indexInMapelList), inParent: nil, withAnimation: .effectFade)
                    }
                }
            }
            editedGuru.append(selectedGuru)
        }
        outlineView.endUpdates()
        myUndoManager.registerUndo(withTarget: self) { guru in
            guru.undoEdit(guru: editedGuru)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateUndoRedo(self)
        }
    }

    /// Muat semua mata pelajaran yang telah diluaskan ke UserDefault.
    func loadExpandedItems() {
        if let expandedMapelNames = UserDefaults.standard.array(forKey: "expandedGuruItems") as? [String] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [unowned self] in
                outlineView.beginUpdates()
                for namaMapel in expandedMapelNames {
                    if let mapelToExpand = mapelList.first(where: { $0.namaMapel == namaMapel }) {
                        outlineView.animator().expandItem(mapelToExpand, expandChildren: false)
                    }
                }
                outlineView.endUpdates()
            }
        }
    }

    /// Simpan semua mata pelajaran yang telah diluaskan ke UserDefault.
    func saveExpandedItems() {
        // Simpan nama `mapel` yang saat ini di-expand
        let expandedMapelNames = mapelList.compactMap { mapel -> String? in
            return outlineView.isItemExpanded(mapel) ? mapel.namaMapel : nil
        }
        UserDefaults.standard.set(expandedMapelNames, forKey: "expandedGuruItems")
    }

    /// Mengurutkan data model (baik `MapelModel` maupun `GuruModel`) berdasarkan
    /// `NSSortDescriptor` yang diberikan. Fungsi ini akan mengurutkan daftar utama
    /// `mapelList` dan kemudian mengurutkan daftar `guruList` di dalam setiap `MapelModel`
    /// sesuai dengan kunci pengurutan yang ditentukan.
    ///
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang berisi kunci kolom
    ///                             dan arah pengurutan (ascending/descending).
    func sortModel(by sortDescriptor: NSSortDescriptor) {
        let indicator = sortDescriptor // Menyimpan sort descriptor untuk akses mudah.

        // --- Pengurutan MapelModel (Parent Items) ---
        // Mengurutkan `mapelList` (daftar utama Mapel) berdasarkan kunci pengurutan.
        mapelList.sort { mapel1, mapel2 -> Bool in
            switch indicator.key {
            // Saat ini, pengurutan `MapelModel` hanya didukung berdasarkan "NamaGuru"
            // yang secara implisit berarti "NamaMapel" karena ini adalah kolom di level Mapel.
            case "NamaGuru": // Menggunakan "NamaGuru" sebagai kunci untuk MapelModel (yang merujuk ke NamaMapel)
                // Mengembalikan `true` jika `mapel1` harus datang sebelum `mapel2`
                // sesuai dengan arah ascending/descending.
                return indicator.ascending ? mapel1.namaMapel < mapel2.namaMapel : mapel1.namaMapel > mapel2.namaMapel
            default:
                // Jika kunci pengurutan tidak cocok, tidak ada perubahan urutan untuk Mapel.
                return true // Atau false, tergantung pada perilaku default yang diinginkan jika kunci tidak cocok.
            }
        }

        // --- Pengurutan GuruModel (Child Items) ---
        // Iterasi melalui setiap `MapelModel` dalam `mapelList` untuk mengurutkan `guruList` (anak-anaknya).
        // Urutkan Guru di setiap Mapel
        for mapel in mapelList {
            mapel.guruList.sort {
                $0.compare(to: $1, using: sortDescriptor) == .orderedAscending
            }
        }
        // Menyimpan `sortDescriptor` yang terakhir digunakan. Ini sering digunakan untuk
        // mempertahankan status pengurutan tabel atau untuk operasi seperti penyisipan.
        sortDescriptors = sortDescriptor
    }

    /// Fungsi yang dijalankan ketika baris di ``outlineView`` diklik dua kali.
    /// - Parameter sender: Objek pemicu.
    @objc func outlineViewDoubleClick(_ sender: Any) {
        guard outlineView.selectedRow >= 0 else { return }
        AppDelegate.shared.editorManager?.startEditing(row: outlineView.clickedRow, column: outlineView.clickedColumn)
    }

    /// Konfigurasi awal `NSSortDescriptor` untuk setiap kolom di ``outlineView``.
    func setupSortDescriptor() {
        let nama = NSSortDescriptor(key: "NamaGuru", ascending: false)
        let alamat = NSSortDescriptor(key: "AlamatGuru", ascending: false)
        let tahunaktif = NSSortDescriptor(key: "TahunAktif", ascending: false)
        let mapel = NSSortDescriptor(key: "Mapel", ascending: false)
        let posisi = NSSortDescriptor(key: "Struktural", ascending: false)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("NamaGuru"): nama,
            NSUserInterfaceItemIdentifier("AlamatGuru"): alamat,
            NSUserInterfaceItemIdentifier("TahunAktif"): tahunaktif,
            NSUserInterfaceItemIdentifier("Mapel"): mapel,
            NSUserInterfaceItemIdentifier("Struktural"): posisi,
        ]
        for kolom in outlineView.tableColumns {
            let identifikasi = kolom.identifier
            let tukangIdentifikasi = identifikasiKolom[identifikasi]
            kolom.sortDescriptorPrototype = tukangIdentifikasi
        }
    }

    /// Properti `DispatchWorkItem` untuk workItem pencarian untuk penundaan pencarian setelah pengetikan.
    var searchWork: DispatchWorkItem?

    /// Melakukan pencarian guru berdasarkan teks yang diberikan dan memperbarui `NSOutlineView`
    /// dengan hasil yang difilter dan dikelompokkan berdasarkan mata pelajaran (`MapelModel`).
    /// Operasi pencarian dilakukan secara asinkron untuk menjaga responsivitas UI.
    ///
    /// - Parameter searchText: `String` yang digunakan sebagai kueri pencarian.
    func search(_ searchText: String) {
        // Memeriksa apakah teks pencarian baru sama dengan teks pencarian sebelumnya.
        // Jika ya, tidak perlu melakukan pencarian ulang, jadi fungsi berhenti.
        if searchText == stringPencarian { return }

        // Memperbarui `stringPencarian` dengan teks pencarian yang baru.
        stringPencarian = searchText

        // Membuat `Task` asinkron untuk melakukan operasi pencarian di latar belakang
        // agar UI tetap responsif. `[unowned self]` digunakan untuk mencegah retain cycle.
        Task { [unowned self] in
            // Menghapus semua data Mapel yang ada di `mapelList` sebelum mengisi dengan hasil pencarian baru.
            self.mapelList.removeAll()

            // Melakukan pencarian guru di database menggunakan `dbController`.
            // Hasilnya (daftar `GuruModel`) disimpan dalam variabel `guruu`.
            self.guruu = await self.dbController.searchGuru(query: searchText)

            // Membuat dictionary untuk mengelompokkan `GuruModel` berdasarkan nama mapel mereka.
            var mapelDict: [String: [GuruModel]] = [:]

            // Iterasi melalui setiap guru yang ditemukan dari hasil pencarian.
            for guru in self.guruu {
                // Memeriksa apakah nama mapel guru sudah ada sebagai kunci dalam `mapelDict`.
                // Jika belum ada, inisialisasi dengan array kosong.
                if mapelDict[guru.mapel] == nil {
                    mapelDict[guru.mapel] = [GuruModel]()
                }
                // Menambahkan guru saat ini ke array guru yang sesuai dengan mapelnya di `mapelDict`.
                mapelDict[guru.mapel]?.append(guru)
            }

            // Mengubah dictionary `mapelDict` menjadi list `MapelModel`.
            for (mapel, guruList) in mapelDict {
                // Membuat instance `MapelModel` baru dengan nama mapel dan daftar gurunya.
                let mapelModel = MapelModel(id: UUID(), namaMapel: mapel, guruList: guruList)
                // Menambahkan `mapelModel` yang baru dibuat ke `mapelList` utama.
                self.mapelList.append(mapelModel)
            }

            // Memastikan pembaruan UI dilakukan di thread utama (`MainActor`).
            await MainActor.run { [unowned self] in
                // Mendapatkan `sortDescriptor` yang saat ini digunakan oleh `outlineView`.
                // Jika tidak ada, gunakan default "NamaGuru" ascending.
                let indicator = self.outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: self.outlineView.sortDescriptors.first?.ascending ?? true)

                // Mengurutkan model data (`mapelList` dan `guruList` di dalamnya)
                // berdasarkan `sortDescriptor` yang ditemukan.
                self.sortModel(by: indicator)

                // Memuat ulang semua data di `NSOutlineView` untuk menampilkan hasil pencarian yang baru.
                self.outlineView.reloadData()

                // Memperluas semua item di `outlineView` (baik parent maupun child)
                // agar semua hasil pencarian terlihat.
                self.outlineView.expandItem(nil, expandChildren: true)
            }
        }
    }

    /// Menangani input dari `NSSearchField`, menerapkan debounce untuk mencegah pencarian yang berlebihan
    /// saat pengguna mengetik. Fungsi ini membatalkan operasi pencarian sebelumnya yang tertunda
    /// dan menjadwalkan pencarian baru setelah penundaan singkat.
    ///
    /// - Parameter sender: `NSSearchField` yang memicu aksi ini, yang berisi teks pencarian saat ini.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        // Batalkan `DispatchWorkItem` pencarian yang sedang berjalan atau tertunda.
        // Ini adalah teknik "debounce" yang memastikan hanya pencarian terakhir
        // setelah jeda mengetik yang akan dieksekusi.
        searchWork?.cancel()

        // Membuat `DispatchWorkItem` baru yang akan melakukan pencarian.
        let workItem = DispatchWorkItem { [weak self] in
            // Memanggil fungsi `search` dengan teks dari `NSSearchField`.
            self?.search(sender.stringValue)
            // Memperbarui properti `stringPencarian` dengan teks pencarian saat ini.
            self?.stringPencarian = sender.stringValue
        }

        // Menyimpan `workItem` yang baru dibuat ke `searchWork`.
        searchWork = workItem

        // Menjadwalkan `workItem` untuk dieksekusi di antrean utama setelah penundaan 0,5 detik.
        // Ini memberikan waktu bagi pengguna untuk menyelesaikan pengetikan sebelum pencarian dipicu.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchWork!)
    }

    deinit {
        searchWork?.cancel()
        searchWork = nil
        saveRowHeight()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
    }
}

extension GuruViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let mapel = item as? MapelModel {
            return mapel.guruList.count // Jumlah guru dalam mapel
        }
        return mapelList.count // Jumlah mapel jika item adalah nil
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let mapel = item as? MapelModel {
            return mapel.guruList[index] // Kembalikan guru dari mapel tersebut
        }

        return mapelList[index] // Kembalikan mapel jika item adalah nil
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "GuruCell"), owner: self) as? NSTableCellView else {
            return nil
        }
        func applyCommonConstraints(to textField: NSTextField, in cell: NSTableCellView, isNamaGuru: Bool) {
            textField.translatesAutoresizingMaskIntoConstraints = false

            var leadingConstant: CGFloat = isNamaGuru ? 0 : 5
            var trailingConstant: CGFloat = isNamaGuru ? -5 : -20
            if item is MapelModel, isNamaGuru {
                leadingConstant = 5
                trailingConstant = -20
            }

            // Memperbarui constraint yang sudah ada untuk mencegah duplikasi
            for constraint in cell.constraints {
                if constraint.firstAnchor == textField.leadingAnchor {
                    cell.removeConstraint(constraint)
                }
                if constraint.firstAnchor == textField.trailingAnchor {
                    cell.removeConstraint(constraint)
                }
            }

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: trailingConstant),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        guard let textField = cell.textField else { return cell }
        let isNamaGuru = tableColumn?.identifier.rawValue == "NamaGuru"
        applyCommonConstraints(to: textField, in: cell, isNamaGuru: isNamaGuru)
        if let mapel = item as? MapelModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = mapel.namaMapel
                if mapel.namaMapel.isEmpty {
                    cell.textField?.stringValue = "-"
                }
            } else {
                textField.stringValue = ""
            }
        } else if let guru = item as? GuruModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = guru.namaGuru
            } else if tableColumn?.identifier.rawValue == "AlamatGuru" {
                textField.stringValue = guru.alamatGuru
            } else if tableColumn?.identifier.rawValue == "TahunAktif" {
                textField.stringValue = String(guru.tahunaktif)
            } else if tableColumn?.identifier.rawValue == "Struktural" {
                textField.stringValue = guru.struktural
            }
        }
        if tableColumn?.identifier.rawValue == "Mapel" {
            tableColumn?.isHidden = true
        }
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is MapelModel // Mapel dapat diperluas, guru tidak
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let toolbar = view.window?.toolbar else { return }
        guard let outlineView = notification.object as? NSOutlineView else { return }

        // Dapatkan indeks item yang dipilih
        let selectedIndex = outlineView.selectedRow
        // Cek apakah ada item yang dipilih
        let isItemSelected = selectedIndex != -1
        // Dapatkan toolbar item yang ingin Anda atur
        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            if isItemSelected {
                hapus.isEnabled = true
                hapus.target = self
                hapus.action = #selector(hapusSerentak(_:))
            } else {
                hapus.isEnabled = false
            }
        }
        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            if isItemSelected {
                edit.isEnabled = true
            } else {
                // Jika tidak ada item yang dipilih, nonaktifkan tombol edit
                edit.isEnabled = false
            }
        }
        NSApp.sendAction(#selector(GuruViewController.updateMenuItem(_:)), to: nil, from: self)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        saveExpandedItems()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        saveExpandedItems()
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        outlineView.rowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }

    func outlineViewColumnDidMove(_ notification: Notification) {
        ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // Ambil sort descriptor pertama atau gunakan default
        let indicator = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            sortModel(by: indicator)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.outlineView.reloadData()
                self.loadExpandedItems()
            }
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        if columnIndex == 0 {
            outlineView.setNeedsDisplay(outlineView.rect(ofColumn: columnIndex))
            return false
        }

        if newColumnIndex == 0 {
            outlineView.setNeedsDisplay(outlineView.rect(ofColumn: columnIndex))
            return false
        }

        return true
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        if let mapel = item as? MapelModel {
            return mapel.namaMapel
        } else if let guru = item as? GuruModel {
            return guru.namaGuru
        }
        return nil
    }
}

extension GuruViewController: NSMenuDelegate {
    /// Action untuk menu item hapus dari menu  klik kanan ``outlineView`` atau dari toolbar menu ``DataSDI/WindowController/actionToolbar``.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        guard let outlineView else {
            return
        }

        let clickedRow = outlineView.clickedRow

        if clickedRow != -1 {
            // Dapatkan item yang diklik
            guard let clickedItem = outlineView.item(atRow: clickedRow) else {
                return
            }
            // Periksa apakah item yang diklik adalah item level teratas (parent)
            if let parentItem = outlineView.parent(forItem: clickedItem), parentItem is NSTreeNode {
                // Jika item memiliki parent, ini bukan item level teratas
                return
            }
            // Jika sampai di sini, berarti item yang diklik adalah item level teratas (parent)
            if outlineView.selectedRowIndexes.contains(clickedRow) {
                // Jika baris yang diklik adalah bagian dari baris yang dipilih.
                hapusSerentak(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari baris yang dipilih.
                deleteData(sender)
            }
        } else {
            // Jika tidak ada item yang diklik.
            guard outlineView.numberOfSelectedRows >= 1 else { return }
            hapusSerentak(sender)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menu)
        }
        view.window?.makeFirstResponder(outlineView)
    }

    /// Menangani aksi penyalinan data dari `NSOutlineView` yang dipicu oleh sebuah `NSMenuItem`.
    /// Fungsi ini menentukan baris mana yang harus disalin, baik itu baris yang diklik secara individual
    /// atau beberapa baris yang telah dipilih, lalu memanggil fungsi `salinBaris` untuk melakukan
    /// operasi penyalinan data yang sebenarnya.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini. `representedObject` dari item menu
    ///                     dapat berisi `IndexSet` dari baris yang ingin disalin secara spesifik.
    @objc func salinData(_ sender: NSMenuItem) {
        // Mendapatkan semua indeks baris yang saat ini dipilih di `outlineView`.
        let selectedRows = outlineView.selectedRowIndexes

        // Mencoba mendapatkan `IndexSet` dari `sender.representedObject`.
        // Ini biasanya digunakan ketika item menu secara eksplisit membawa informasi tentang baris yang relevan.
        guard let rows = sender.representedObject as? IndexSet else {
            // Jika `representedObject` bukan `IndexSet` (atau `nil`),
            // asumsikan bahwa operasi penyalinan berlaku untuk semua baris yang dipilih.
            salinBaris(selectedRows, outlineView: outlineView)
            return // Hentikan eksekusi fungsi di sini.
        }

        // Mendapatkan indeks baris yang terakhir diklik di `outlineView`.
        let clickedRow = outlineView.clickedRow

        // --- Logika Penentuan Baris untuk Disalin ---
        // Skenario 1: Baris yang diklik adalah bagian dari baris yang dipilih, dan baris yang diklik valid.
        if rows.contains(clickedRow), clickedRow >= 0 {
            // Dalam kasus ini, salin semua baris yang saat ini dipilih.
            salinBaris(selectedRows, outlineView: outlineView)
        }
        // Skenario 2: Baris yang diklik *bukan* bagian dari baris yang dipilih, tetapi baris yang diklik valid.
        // Ini terjadi ketika pengguna mengklik kanan pada baris yang tidak terpilih di antara beberapa baris yang sudah terpilih.
        else if !rows.contains(clickedRow), clickedRow >= 0 {
            // Hanya salin baris yang diklik saja.
            salinBaris(IndexSet([clickedRow]), outlineView: outlineView)
        }
        // Skenario 3: Tidak ada item yang diklik (misalnya, `clickedRow` adalah -1),
        // atau `rows` yang berasal dari `representedObject` kosong/tidak valid.
        else {
            // Salin semua baris yang saat ini dipilih.
            salinBaris(selectedRows, outlineView: outlineView)
        }
    }

    /// Menyalin data dari baris-baris `NSOutlineView` yang dipilih ke clipboard.
    /// Data disalin sebagai teks yang dipisahkan oleh tab (`\t`) untuk kolom, dan baris baru (`\n`)
    /// untuk setiap baris, membuatnya cocok untuk ditempel ke spreadsheet atau editor teks.
    ///
    /// - Parameters:
    ///   - rows: `IndexSet` yang berisi indeks baris-baris yang akan disalin dari `outlineView`.
    ///   - outlineView: `NSOutlineView` tempat data akan disalin.
    func salinBaris(_ rows: IndexSet, outlineView: NSOutlineView) {
        // Array untuk menyimpan semua data baris yang akan disalin, di mana setiap elemen adalah string representasi satu baris.
        var allRowData: [String] = []

        // Iterasi melalui setiap indeks baris yang dipilih dalam `IndexSet`.
        for row in rows {
            // Mendapatkan item (data model) yang terkait dengan baris saat ini di `outlineView`.
            // Jika item tidak ditemukan (misalnya, indeks tidak valid), lewati ke baris berikutnya.
            guard let item = outlineView.item(atRow: row) else {
                continue // Lewati jika item tidak ditemukan.
            }

            // Array sementara untuk menyimpan data kolom dari baris saat ini.
            var rowData: [String] = []

            // Iterasi melalui setiap kolom yang terlihat di `NSOutlineView`.
            for column in outlineView.tableColumns {
                let identifier = column.identifier.rawValue // Mengambil identifier string dari kolom.

                // Memeriksa apakah item saat ini adalah `MapelModel` (item level teratas).
                if let mapel = item as? MapelModel {
                    // Jika kolom adalah "NamaGuru" (yang digunakan untuk menampilkan nama mapel di level parent),
                    // tambahkan nama mapel ke `rowData`. Jika kosong, gunakan "-".
                    if identifier == "NamaGuru" {
                        rowData.append(mapel.namaMapel.isEmpty ? "-" : mapel.namaMapel)
                    } else {
                        // Untuk kolom lain yang tidak relevan dengan `MapelModel`, tambahkan string kosong.
                        rowData.append("")
                    }
                }
                // Memeriksa apakah item saat ini adalah `GuruModel` (item anak).
                else if let guru = item as? GuruModel {
                    // Menambahkan data guru ke `rowData` berdasarkan identifier kolom.
                    if identifier == "NamaGuru" {
                        // Untuk "NamaGuru", gabungkan `namaGuru` dan `mapel` yang dipisahkan oleh tab.
                        rowData.append("\(guru.namaGuru)\t\(guru.mapel)")
                    } else if identifier == "AlamatGuru" {
                        rowData.append(guru.alamatGuru)
                    } else if identifier == "TahunAktif" {
                        // Konversi `tahunaktif` (Int) menjadi `String`.
                        rowData.append(String(guru.tahunaktif))
                    } else if identifier == "Struktural" {
                        rowData.append(guru.struktural)
                    } else {
                        // Untuk kolom lain yang tidak sesuai dengan `GuruModel`, tambahkan string kosong.
                        rowData.append("")
                    }
                }
            }

            // Menggabungkan semua data kolom untuk baris saat ini menjadi satu string,
            // dipisahkan oleh karakter tab (`\t`).
            let rowString = rowData.joined(separator: "\t")
            // Menambahkan string baris yang telah digabungkan ke `allRowData`.
            allRowData.append(rowString)
        }

        // Menggabungkan semua string baris dalam `allRowData` menjadi satu string besar,
        // dipisahkan oleh karakter baris baru (`\n`).
        let allDataString = allRowData.joined(separator: "\n")

        // Mendapatkan `NSPasteboard` umum (clipboard sistem).
        let pasteboard = NSPasteboard.general
        // Mengosongkan konten clipboard yang ada.
        pasteboard.clearContents()
        // Menetapkan string data yang telah disiapkan ke clipboard dengan tipe `.string`.
        pasteboard.setString(allDataString, forType: .string)
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/GuruViewController``
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
           let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
           let fileMenu = mainMenu.item(withTitle: "File"),
           let fileMenuItem = fileMenu.submenu,
           let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" })
        {
            let adaBarisDipilih = outlineView.selectedRowIndexes.count > 0
            deleteMenuItem.isEnabled = adaBarisDipilih
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinData(_:))
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(hapusSerentak(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
            }
            new.target = self
            new.action = #selector(addGuru(_:))
        }
    }
}

extension GuruViewController: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        ReusableFunc.resetMenuItems()
        if let textField = obj.object as? NSTextField, !(textField.superview is NSTableCellView) {
            activeText = textField
            switch textField.tag {
            case 1: // Nama Guru
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.namaguru),
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 2: // Alamat Guru
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.alamat),
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 3: // Tahun Aktif
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.ttl),
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 4: // Mata Pelajaran
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.mapel),
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            case 5: // Sebagai (Struktur)
                let suggestionsDict: [NSTextField: [String]] = [
                    textField: Array(ReusableFunc.jabatan),
                ]
                suggestionManager.suggestions = suggestionsDict[textField] ?? []
            default:
                break
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            let currentText = activeTextField.stringValue

            // Find the last word (after the last space)
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])

                // Update the text field with only the last word
                suggestionManager.typing = lastWord

            } else {
                suggestionManager.typing = activeText.stringValue
            }
            if activeText?.stringValue.isEmpty == true {
                suggestionManager.hideSuggestions()
            } else {
                suggestionManager.controlTextDidChange(obj)
            }
        }
        if let searchField = obj.object as? NSSearchField {
            searchWork?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.search(searchField.stringValue)
            }
            searchWork = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: searchWork!)
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
        if obj.object is NSSearchField {
            updateUndoRedo(self)
            return
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return false }
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.moveUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.moveDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            if control is NSSearchField {
                return true
            }
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.enterSuggestions()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.hideSuggestions()
            return true
        case #selector(NSResponder.insertTab(_:)):
            if !suggestionManager.suggestionWindow.isVisible {
                return false
            }
            suggestionManager.hideSuggestions()
            return false
        default:
            return false
        }
    }

    /// Memperbarui data guru di database jika ada perubahan antara data lama dan baru.
    /// Fungsi ini membandingkan setiap properti `GuruModel` dan hanya memanggil
    /// metode pembaruan database jika properti tersebut berbeda.
    ///
    /// - Parameters:
    ///   - id: `Int64` yang merupakan ID unik dari guru yang akan diperbarui.
    ///   - dataLama: Objek `GuruModel` yang merepresentasikan data guru sebelum perubahan.
    ///   - baru: Objek `GuruModel` yang merepresentasikan data guru setelah perubahan.
    func updateDataGuru(_ id: Int64, dataLama: GuruModel, baru: GuruModel) {
        // Memeriksa apakah `namaGuru` telah berubah.
        if dataLama.namaGuru != baru.namaGuru {
            // Jika berbeda, perbarui kolom "Nama" di database.
            dbController.updateKolomGuru(id, kolom: "Nama", baru: baru.namaGuru)
        }

        // Memeriksa apakah `alamatGuru` telah berubah.
        if dataLama.alamatGuru != baru.alamatGuru {
            // Jika berbeda, perbarui kolom "Alamat" di database.
            dbController.updateKolomGuru(id, kolom: "Alamat", baru: baru.alamatGuru) // <- fix
        }

        // Memeriksa apakah `tahunaktif` telah berubah.
        if dataLama.tahunaktif != baru.tahunaktif {
            // Jika berbeda, perbarui kolom "Tahun Aktif" di database.
            dbController.updateKolomGuru(id, kolom: "Tahun Aktif", baru: baru.tahunaktif) // <- fix
        }

        // Memeriksa apakah `mapel` telah berubah.
        if dataLama.mapel != baru.mapel {
            // Jika berbeda, perbarui kolom "Mata Pelajaran" di database.
            dbController.updateKolomGuru(id, kolom: "Mata Pelajaran", baru: baru.mapel) // <- fix
        }

        // Memeriksa apakah `struktural` telah berubah.
        if dataLama.struktural != baru.struktural {
            // Jika berbeda, perbarui kolom "Jabatan" di database.
            dbController.updateKolomGuru(id, kolom: "Jabatan", baru: baru.struktural) // <- fix
        }
    }

    /// Fungsi untuk berganti antara `usesAlternatingRowBackgroundColors`.
    @objc func beralihWarnaAlternatif() {
        warnaAlternatif.toggle()
        if warnaAlternatif {
            outlineView.usesAlternatingRowBackgroundColors = true
        } else {
            outlineView.usesAlternatingRowBackgroundColors = false
        }
        if let menu = outlineView.menu,
           let beralihWarna = menu.item(withTitle: "Gunakan Warna Alternatif")
        {
            beralihWarna.state = warnaAlternatif ? .on : .off
        }
        outlineView.reloadData()
    }
}

extension GuruViewController: OverlayEditorManagerDelegate, OverlayEditorManagerDataSource {
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        if row >= 0, let item = outlineView.item(atRow: row) as? GuruModel,
           let parentItem = outlineView.parent(forItem: item) as? MapelModel,
           let indexInGuruList = parentItem.guruList.firstIndex(where: { $0.idGuru == item.idGuru })
        {
            let oldGuru = item.copy()
            #if DEBUG
                print("oldGuru", oldGuru.alamatGuru)
            #endif
            let columnIdentifier = outlineView.tableColumns[column].identifier.rawValue

            switch columnIdentifier {
            case "NamaGuru": item.namaGuru = newText
            case "AlamatGuru": item.alamatGuru = newText
            case "TahunAktif": item.tahunaktif = newText
            case "Struktural": item.struktural = newText
            default:
                break
            }

            updateDataGuru(item.idGuru, dataLama: oldGuru, baru: item)
            parentItem.guruList.remove(at: indexInGuruList)
            // Tentukan posisi penyisipan untuk guru yang diperbarui
            guard let sortDescriptor = outlineView.sortDescriptors.first else { return }
            let insertionIndex = parentItem.guruList.insertionIndex(for: item, using: sortDescriptor)
            parentItem.guruList.insert(item, at: insertionIndex)
            if indexInGuruList != insertionIndex {
                outlineView.moveItem(at: indexInGuruList, inParent: parentItem, to: insertionIndex, inParent: parentItem)
            }
            myUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.undoEdit(guru: [oldGuru])
            })
            deleteAllRedoArray()
        }
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool {
        if row >= 0, let item = outlineView.item(atRow: row) as? GuruModel,
           outlineView.parent(forItem: item) is MapelModel
        {
            true
        } else {
            false
        }
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let cell = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else { return "return" }
        return cell.textField?.stringValue ?? ""
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        outlineView.tableColumns[column].width
    }

    func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = outlineView.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "NamaGuru": // Nama Guru
            return Array(ReusableFunc.namaguru)
        case "AlamatGuru": // Alamat Guru
            return Array(ReusableFunc.alamat)
        case "TahunAktif":
            return Array(ReusableFunc.mapel)
        case "Mapel":
            return Array(ReusableFunc.mapel)
        case "Struktural": // Sebagai (Struktur)
            return Array(ReusableFunc.jabatan)
        default:
            return []
        }
    }
}
