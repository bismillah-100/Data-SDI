//
//  TugasMapelVC.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//
import AppKit
import Combine

class TugasMapelVC: NSViewController, NSSearchFieldDelegate {
    /// Outlet scrollView yang menampung ``outlineView``.
    @IBOutlet weak var scrollView: NSScrollView!

    /// Fungsi untuk memperbesar tinggi ``outlineView``.
    ///
    /// - Parameter sender: Objek pemicu
    @IBAction func increaseSize(_: Any?) {
        ReusableFunc.increaseSizeStep(outlineView, userDefaultKey: "GuruOutlineViewRowHeight")
    }

    /// Fungsi untuk memperkecil tinggi ``outlineView``.
    ///
    /// - Parameter sender: Objek pemicu.
    @IBAction func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSizeStep(outlineView, userDefaultKey: "GuruOutlineViewRowHeight")
    }

    /// Outlet outlineView di XIB
    @IBOutlet weak var outlineView: NSOutlineView!

    /// Membuat deskripsi kolom di ``outlineView``.
    ///
    /// Mengatur properti `identifier` dan `customTitle`.
    let kolomTabelGuru: [ColumnInfo] = [
        ColumnInfo(identifier: "NamaGuru", customTitle: "Nama Guru"),
        ColumnInfo(identifier: "TahunAktif", customTitle: "Tahun Ajaran"),
        ColumnInfo(identifier: "Mapel", customTitle: "Mata Pelajaran"),
        ColumnInfo(identifier: "Struktural", customTitle: "Sebagai"),
        ColumnInfo(identifier: "Kelas", customTitle: "Kelas - Semester"),
        ColumnInfo(identifier: "Tanggal Mulai", customTitle: "Tgl. Mulai"),
        ColumnInfo(identifier: "Tanggal Selesai", customTitle: "Tgl. Selesai"),
    ]

    /// `UndoManager` untuk ``DataSDI/TugasMapelVC``
    let myUndoManager = GuruViewModel.shared.myUndoManager

    /// Properti untuk menyimpan status penggunaan `alternateRow`.
    var warnaAlternatif = true

    /// Instans untuk ``DatabaseController/shared``
    let dbController: DatabaseController = .shared

    /// Properti untuk menyimpan referensi jika ``GuruViewModel/guru`` telah diisi dengan data yang ada
    /// di database dan telah diatur hierarki dalam ``GuruViewModel/daftarMapel``
    /// serta sudah ditampilkan setiap barisnya di ``outlineView``.
    var isDataLoaded: Bool = false

    /// Properti string dari pengetikan di ``DataSDI/WindowController/search``.
    lazy var stringPencarian: String = ""

    /// Menu yang akan digunakan toolbar ``DataSDI/WindowController/actionToolbar``.
    var toolbarMenu: NSMenu = .init()

    /// Properti untuk memperbarui semua data dan ``outlineView``
    /// jika nilainya adalah true ketika ``viewDidAppear()``.
    ///
    /// Properti ini diset ketika ada interaksi pengeditan nama guru di ``DataSDI/KelasVC``.
    var adaUpdateNamaGuru: Bool = false

    /// Properti `NSSortDescriptor` untuk pengurutan data
    /// sesuai dengan kolom.
    var sortDescriptors: NSSortDescriptor?

    /// Instans ``GuruViewModel``.
    let viewModel: GuruViewModel = .shared

    /// Cancellables untuk event ``DataSDI/GuruViewModel/tugasGuruEvent``.
    var cancellables: Set<AnyCancellable> = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSortDescriptor()
        // Setup tinggi bari syang telah disimpan sebelumnya di UserDefault.
        if let savedRowHeight = UserDefaults.standard.value(forKey: "GuruOutlineViewRowHeight") as? CGFloat {
            outlineView.rowHeight = savedRowHeight
        }
        if let indicator = ReusableFunc.loadSortDescriptor(forKey: "TugasMapelSortDescriptor", defaultKey: "NamaGuru") {
            sortDescriptors = indicator
            outlineView.sortDescriptors = [indicator]
        }
        /// Properti untuk menghalangi ``outlineView`` menjadi firstResponder keyboard jika diset ke `true`.
        outlineView.refusesFirstResponder = false
        outlineView.setAccessibilityIdentifier("OutlineTugasMapelVC")
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
                muatUlang(self)
                group.leave()
            }
            group.notify(queue: .main) {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] timer in
                    guard let self else {
                        if let self, let window = view.window {
                            ReusableFunc.closeProgressWindow(window)
                        }
                        return
                    }
                    if let window = view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }

                    setupCombine()
                    timer.invalidate()
                }
            }

            // Perbarui menu item untuk kolom-kolom outelinView.
            ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
        }

        /// perbarui semua data ketika adaUpdateNamaGuru bernilai `true`.
        if adaUpdateNamaGuru {
            guard isDataLoaded else { return }
            muatUlang(self)
        }

        toolbarMenu = buatMenuItem()
        toolbarMenu.delegate = self

        let menu = buatMenuItem()
        menu.delegate = self
        outlineView.menu = menu

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            view.window?.makeFirstResponder(outlineView)
            ReusableFunc.resetMenuItems()
            updateMenuItem(self)
            updateUndoRedo(self)
            ReusableFunc.updateSearchFieldToolbar(view.window!, text: stringPencarian)
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

    /// Mengatur event combine dari ``DataSDI/GuruViewModel/tugasGuruEvent``
    /// untuk insert, delete, move, dan update data di ``outlineView``.
    func setupCombine() {
        viewModel.tugasGuruEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .guruAndMapelRemoved(gurus, mapelIndices, fallbackItem):
                    removeMapelAndGurusAndSelectNext(
                        gurus: gurus,
                        mapelIndices: IndexSet(mapelIndices),
                        fallback: fallbackItem
                    )
                case let .guruAndMapelInserted(mapelIndices, guruDict):
                    outlineView.beginUpdates()
                    for index in mapelIndices {
                        outlineView.insertItems(at: IndexSet(integer: index), inParent: nil, withAnimation: .effectFade)
                    }
                    insertAndExpandGuru(guruDict)
                    outlineView.endUpdates()
                    // Delay select setelah insert selesai
                    Just(guruDict)
                        .delay(for: .milliseconds(500), scheduler: RunLoop.main)
                        .sink { [weak self] delayedGuruDict in
                            guard let self else { return }
                            selectInsertedGuru(delayedGuruDict)
                            updateUndoRedo(event)
                        }
                        .store(in: &cancellables) // Pastikan self masih ada
                case let .updated(items):
                    outlineView.deselectAll(event)
                    outlineView.beginUpdates()
                    for (parent, index) in items {
                        guard let guru = parent?.guruList[index] else { continue }
                        outlineView.reloadItem(guru, reloadChildren: false)
                        selectInsertedGuru([parent!: [(guru: guru, index: index)]], extendSelection: true)
                    }
                    outlineView.endUpdates()
//                case .updated(let parent, let index):
//                    guard let guru = parent?.guruList[index] else {
//                        print("error: GuruList index out of bounds for update.")
//                        return
//                    }
//                    self.outlineView.reloadItem(guru)
//                    self.selectInsertedGuru([parent!: [index]], extendSelection: true)
//                    self.updateUndoRedo(nil)
                case let .moved(oldIndex, oldParent, newIndex, newParent): // 1. Pindahkan item secara visual
                    outlineView.moveItem(at: oldIndex, inParent: oldParent, to: newIndex, inParent: newParent)

                    // 2. Dapatkan item yang baru dipindahkan dari data source
                    guard let guruToReload = newParent?.guruList[newIndex] else { return }

                    // 3. Muat ulang datanya untuk menampilkan perubahan
                    outlineView.reloadItem(guruToReload, reloadChildren: false)
                    selectInsertedGuru([newParent!: [(guru: guruToReload, index: newIndex)]], extendSelection: true)
                    updateUndoRedo(nil)
                case let .updateNama(parentMapel: parent, index: index):
                    let item = parent.guruList[index]
                    outlineView.reloadItem(item)
                case .reloadData:
                    muatUlang(event)
                }
            }
            .store(in: &cancellables)
    }

    private func removeMapelAndGurusAndSelectNext(
        gurus: [MapelModel: [Int]],
        mapelIndices: IndexSet,
        fallback: Any? = nil
    ) {
        if let fallback {
            let row = outlineView.row(forItem: fallback)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
            }
        }

        outlineView.beginUpdates()

        // 1️⃣ Hapus semua guru dulu
        for (mapel, rows) in gurus {
            for row in rows.sorted(by: >) {
                outlineView.removeItems(at: IndexSet(integer: row), inParent: mapel, withAnimation: .slideUp)
            }
        }

        // 2️⃣ Hapus Mapel di root
        for row in mapelIndices.sorted(by: >) {
            outlineView.removeItems(at: IndexSet(integer: row), inParent: nil, withAnimation: .slideUp)
        }

        outlineView.endUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateUndoRedo(nil)
        }
    }

    private func insertAndExpandGuru(_ guruDict: GuruInsertDict) {
        for (mapel, guruTuples) in guruDict {
            for (_, index) in guruTuples {
                outlineView.insertItems(at: IndexSet(integer: index), inParent: mapel, withAnimation: .effectGap)
            }
            outlineView.expandItem(mapel)
        }
    }

    private func selectInsertedGuru(_ guruDict: GuruInsertDict, extendSelection: Bool? = false) {
        var rowSet = IndexSet()
        for (_, guruTuples) in guruDict {
            for (guru, _) in guruTuples {
                let row = outlineView.row(forItem: guru)
                if row != -1 {
                    rowSet.insert(row)
                }
            }
        }

        if !rowSet.isEmpty {
            outlineView.selectRowIndexes(rowSet, byExtendingSelection: extendSelection ?? false)
            if let max = rowSet.max() {
                outlineView.scrollRowToVisible(max)
            }
        }
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

    /// Konfigurasi action dan target toolbarItem untuk ``DataSDI/TugasMapelVC``.
    func setupToolbar() {
        guard let wc = view.window?.windowController as? WindowController else { return }
        let isItemSelected = outlineView.selectedRow != -1

        // SearchField
        wc.searchField.isEnabled = true
        wc.searchField.delegate = self
        wc.searchField.target = self
        wc.searchField.isEditable = true
        wc.searchField.action = #selector(procSearchFieldInput(sender:))
        if let textFieldInsideSearchField = wc.searchField.cell as? NSSearchFieldCell {
            textFieldInsideSearchField.placeholderString = "Cari guru..."
        }

        // Tambah Data
        wc.tambahSiswa.isEnabled = true
        wc.tambahSiswa.toolTip = "Tambah Penugasan Guru"

        // Tambah nilai kelas
        wc.tambahDetaildiKelas.isEnabled = false

        // Action Menu
        wc.actionPopUpButton.menu = toolbarMenu

        // Edit
        wc.tmbledit.isEnabled = isItemSelected

        // Hapus
        wc.hapusToolbar.isEnabled = isItemSelected
        wc.hapusToolbar.target = self
        wc.hapusToolbar.action = #selector(hapusSerentak(_:))

        // Zoom Segment
        wc.segmentedControl.isEnabled = true
        wc.segmentedControl.target = self
        wc.segmentedControl.action = #selector(segmentedControlValueChanged(_:))
    }

    /// Fungsi yang dijalankan ketika menerima notifikasi dari `.saveData`.
    ///
    /// Menjalankan logika untuk menyiapkan ulang database, memperbarui ``GuruViewModel/guru`` dari database,
    /// membuat struktur hierarki untuk ``GuruViewModel/daftarMapel`` dengan menjalankan ``GuruViewModel/buatKamusMapel(statusTugas:query:semester:tahunAjaran:forceLoad:)``,
    /// dan memuat ulang seluruh baris di ``outlineView`` dengan data terbaru.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func saveData(_: Notification) {
        // Gunakan dispatch group untuk memastikan semua operasi selesai
        let group = DispatchGroup()

        guard isDataLoaded else { return }
        group.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            // Bersihkan semua array
            SingletonData.deletedGuru.removeAll()
            viewModel.removeAllMapelDict()
            group.leave()
        }

        // Setelah semua operasi pembersihan selesai
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            viewModel.myUndoManager.removeAllActions()
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

    /// Memperbarui properti ``adaUpdateNamaGuru`` ketika ada nama guru
    /// yang diperbarui.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func handleNamaGuruUpdate(_: Notification) {
        if !adaUpdateNamaGuru {
            adaUpdateNamaGuru = true
        } else {
            return
        }
    }

    /// Fungsi untuk membersihkan semua array ``GuruViewModel/guru`` dan hierarki di ``GuruViewModel/daftarMapel``,
    /// memuat ulang data dari database menggunakan ``GuruViewModel/buatKamusMapel(statusTugas:query:semester:tahunAjaran:forceLoad:)``,
    /// dan memuat ulang suluruh ``outlineView`` dengan data terbaru.
    @IBAction func muatUlang(_: Any) {
        let sortDescriptor = sortDescriptors ?? NSSortDescriptor(key: "NamaGuru", ascending: sortDescriptors?.ascending ?? true)

        DatabaseController.shared.notifQueue.async { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                await viewModel.buatKamusMapel(statusTugas: viewModel.filterTugas, forceLoad: true)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // Update UI di MainActor
                    adaUpdateNamaGuru = false
                    viewModel.sortDescriptor = outlineView.sortDescriptors.first!
                    viewModel.sortModel(by: sortDescriptor)
                    outlineView.reloadData()
                }

                // Tunda selama 0.1 detik sebagai pengganti asyncAfter
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik

                // Lanjutkan update UI tambahan di MainActor
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    loadExpandedItems()
                    saveExpandedItems()
                    updateUndoRedo(self)
                    if let window = view.window, isDataLoaded {
                        ReusableFunc.closeProgressWindow(window)
                    } else {
                        isDataLoaded = true
                    }
                }
            }
        }
    }

    /// Menjalankan fungsi ``muatUlang(_:)`` ketika mendapatkan
    /// notifikasi `DatabaseController.guruDidChangeNotification`.
    ///
    /// Pengirim notifikasi ini hanya terdapat di ``DataSDI/DetailSiswaController``.
    /// - Parameter notification: Objek notifikasi yang memicu.
    @objc func handleDataDidChangeNotification(_: Notification) {
        muatUlang(self)
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
        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    /// Fungsi untuk menjalankan undo.
    @objc func urung(_: Any) {
        myUndoManager.undo()
    }

    /// Fungsi untuk menjalankan redo.
    @objc func ulang(_: Any) {
        myUndoManager.redo()
    }

    /// Action dari toolbar ``DataSDI/WindowController/hapusToolbar``.
    /// Fungsi untuk mendapatkan indeks baris yang dipilih, kemudian mengiterasi setiap index
    /// untuk mendapatkan id dan nama guru, menampilkan `NSAlert` dan kemudian menjalankan fungsi ``hapusRow(_:idToDelete:)``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func hapusSerentak(_: Any) {
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
    func deleteData(_: Any) {
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
    func hapusRow(_ selectedRows: IndexSet, idToDelete _: Set<Int64>) {
        var groupedDeletedData: [String: [GuruModel]] = [:] // Menyimpan data guru yang dihapus, dikelompokkan per Mapel.

        // --- Fase 1: Kumpulkan Semua Item yang Akan Dihapus ---
        // Iterasi melalui indeks baris yang dipilih dalam urutan terbalik.
        // Iterasi terbalik penting saat menghapus item dari koleksi untuk mencegah masalah indeks.
        for row in selectedRows.reversed() {
            // Mendapatkan item dari `outlineView` pada baris tertentu.
            if let selectedItem = outlineView.item(atRow: row) {
                // Jika item adalah `MapelModel` (item level teratas).
                if let mapel = selectedItem as? MapelModel {
                    // Tambahkan semua guru di bawah Mapel ini ke `groupedDeletedData`
                    // untuk keperluan undo.
                    groupedDeletedData[mapel.namaMapel, default: []].append(contentsOf: mapel.guruList)
                }
                // Jika item adalah `GuruModel` (anak dari `MapelModel`).
                else if let guru = selectedItem as? GuruModel,
                        let parentItem = outlineView.parent(forItem: selectedItem) as? MapelModel
                {
                    // Tambahkan guru ini ke `groupedDeletedData` di bawah nama Mapel induknya.
                    groupedDeletedData[parentItem.namaMapel, default: []].append(guru)
                }
            }
        }

        viewModel.hapusDaftarMapel(data: groupedDeletedData)

        // Tunda pembaruan status tombol undo/redo sedikit untuk memastikan UI telah stabil.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUndoRedo(self) // Memperbarui status tombol undo/redo di UI.
        }
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

    /// Properti data guru dari baris-baris yang dipilih di ``outlineView`` yang akan diedit.
    var selectedRowToEdit: [GuruModel] = []

    /// Properti `NSWindow`. Jendela untuk ditampilkan ketika
    /// akan menambahkan data atau mengedit data.
    lazy var guruWindow: NSWindow = .init()

    /// Fungsi untuk membuka ``AddTugasGuruVC``  dengan opsi "addTugasGuru"
    /// Menampilkan ``guruWindow`` untuk menambahkan guru baru.
    @objc func addGuru(_: Any) {
        let addGuru = AddTugasGuruVC()
        addGuru.options = "addTugasGuru"
        addGuru.statusTugas = true
        addGuru.onSimpanGuru = { [unowned self] newData in
            simpanGuru(newData)
        }
        addGuru.onClose = { [unowned self] in
            closeSheets(self)
        }
        guruWindow.contentViewController = addGuru
        guruWindow.makeKeyAndOrderFront(nil)

        // Misalnya, untuk menampilkan sebagai sheet dari window induk:
        view.window?.beginSheet(guruWindow, completionHandler: nil)
    }

    /// Fungsi untuk menyimpan guru baru setelah selesai menambahkan data guru baru
    /// melalui ``addGuru(_:)``.
    /// - Parameter sender: Objek pemicu.
    func simpanGuru(_ newData: [GuruWithUpdate]) {
        guard let data = newData.first else { return }
        let newMapel = data.guru.mapel!
        // Ketika pengguna mengklik "Tambah"
        viewModel.undoHapus(groupedDeletedData: [newMapel: [data.guru]])

        updateUndoRedo(self)
        updateMenuItem(self)
        closeSheets(self)
    }

    /// Fungsi untuk menyimpan guru baru setelah selesai mengedit
    /// melalui ``edit(_:)``
    /// - Parameter sender: Objek pemicu.
    func simpanEditedGuru(_ newData: [GuruWithUpdate]) async {
        guard !selectedRowToEdit.isEmpty else { return }
        outlineView.deselectAll(self)

        // 1. Jalankan updateGuru di background
        let dataToRestore = await Task.detached(priority: .background) {
            await self.viewModel.updateGuru(newData: newData)
        }.value

        viewModel.myUndoManager.registerUndo(withTarget: self) { [unowned self] _ in
            undoEdit(dataToRestore, currentData: newData)
        }
        closeSheets(self)
    }

    private func undoEdit(_ oldData: [GuruWithUpdate], currentData: [GuruWithUpdate]) {
        Task.detached(priority: .background) {
            await self.viewModel.updateGuru(newData: oldData)
        }
        viewModel.myUndoManager.registerUndo(withTarget: self) { [unowned self] _ in
            undoEdit(currentData, currentData: oldData)
        }
    }

    /// Fungsi untuk menutup jendela sheet ``guruWindow``.
    /// Menjalankan ``updateUndoRedo(_:)`` dan ``updateMenuItem(_:)``.
    /// - Parameter sender:
    @objc func closeSheets(_: Any) {
        view.window?.endSheet(guruWindow)
        guruWindow.contentViewController = nil
        selectedRowToEdit.removeAll()
        updateUndoRedo(self)
        updateMenuItem(self)
    }

    /// Action dari toolbar item ``DataSDI/WindowController/editToolbar``
    /// dan juga menu item klik kanan atau menu item edit di ``DataSDI/WindowController/actionToolbar``.
    /// Fungsi untuk mengedit data guru pada baris yang dipilih.
    /// Mengiterasi setiap data yang akan diedit dan menambahkannya ke ``selectedRowToEdit``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func edit(_: Any) {
        selectedRowToEdit.removeAll()
        var selectedRow = IndexSet()

        if outlineView.clickedRow != -1,
           !outlineView.selectedRowIndexes.contains(outlineView.clickedRow)
        {
            selectedRow = [outlineView.clickedRow]
            outlineView.selectRowIndexes(selectedRow, byExtendingSelection: false)
        } else {
            selectedRow = outlineView.selectedRowIndexes
        }

        guard !selectedRow.isEmpty else { return }

        // Kumpulkan semua item yang terseleksi
        let selectedItems: [Any] = selectedRow.compactMap { outlineView.item(atRow: $0) }

        // Filter: jika parent terseleksi, abaikan child-nya
        var mapelSelected: Set<MapelModel> = []
        var guruSelected: Set<GuruModel> = []

        for item in selectedItems {
            if let mapel = item as? MapelModel {
                mapelSelected.insert(mapel)
            } else if let guru = item as? GuruModel {
                guruSelected.insert(guru)
            }
        }

        // Tambahkan guru dari parent yang terseleksi
        for mapel in mapelSelected {
            let childCount = outlineView.numberOfChildren(ofItem: mapel)
            for i in 0 ..< childCount {
                if let guru = outlineView.child(i, ofItem: mapel) as? GuruModel {
                    selectedRowToEdit.append(guru)
                }
            }
        }

        // Tambahkan guru yang terseleksi langsung, tapi hanya jika parent-nya tidak terseleksi
        for guru in guruSelected {
            let parent = outlineView.parent(forItem: guru) as? MapelModel
            if parent == nil || !mapelSelected.contains(parent!) {
                selectedRowToEdit.append(guru)
            }
        }

        guard !selectedRowToEdit.isEmpty else { return }

        let addGuru = AddTugasGuruVC()
        addGuru.dataToEdit = selectedRowToEdit
        addGuru.options = "editTugasGuru"
        if selectedRow.count > 1 {
            addGuru.statusTugas = true
        } else {
            addGuru.statusTugas = selectedRowToEdit.first!.statusTugas == .aktif ? true : false
        }
        addGuru.onSimpanGuru = { [unowned self] newData in
            Task {
                await self.simpanEditedGuru(newData)
            }
        }
        addGuru.onClose = { [unowned self] in
            closeSheets(self)
        }
        guruWindow.contentViewController = addGuru
        guruWindow.makeKeyAndOrderFront(nil)

        // Misalnya, untuk menampilkan sebagai sheet dari window induk:
        view.window?.beginSheet(guruWindow, completionHandler: nil)
    }

    /// Muat semua mata pelajaran yang telah diluaskan ke UserDefault.
    func loadExpandedItems() {
        if let expandedMapelNames = UserDefaults.standard.array(forKey: "expandedGuruItems") as? [String] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [unowned self] in
                outlineView.beginUpdates()
                for namaMapel in expandedMapelNames {
                    if let mapelToExpand = viewModel.daftarMapel.first(where: { $0.namaMapel == namaMapel }) {
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
        let expandedMapelNames = viewModel.daftarMapel.compactMap { mapel -> String? in
            return outlineView.isItemExpanded(mapel) ? mapel.namaMapel : nil
        }
        UserDefaults.standard.set(expandedMapelNames, forKey: "expandedGuruItems")
    }

    /// Fungsi yang dijalankan ketika baris di ``outlineView`` diklik dua kali.
    /// - Parameter sender: Objek pemicu.
    @objc func outlineViewDoubleClick(_: Any) {
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
        let status = NSSortDescriptor(key: "Status", ascending: false)
        let kelas = NSSortDescriptor(key: "Kelas", ascending: false)
        let tglMulai = NSSortDescriptor(key: "Tgl. Mulai", ascending: false)
        let tglSelesai = NSSortDescriptor(key: "TglSelesai", ascending: false)
        let identifikasiKolom: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("NamaGuru"): nama,
            NSUserInterfaceItemIdentifier("AlamatGuru"): alamat,
            NSUserInterfaceItemIdentifier("TahunAktif"): tahunaktif,
            NSUserInterfaceItemIdentifier("Mapel"): mapel,
            NSUserInterfaceItemIdentifier("Struktural"): posisi,
            NSUserInterfaceItemIdentifier("Status"): status,
            NSUserInterfaceItemIdentifier("Kelas"): kelas,
            NSUserInterfaceItemIdentifier("Tanggal Mulai"): tglMulai,
            NSUserInterfaceItemIdentifier("Tanggal Selesai"): tglSelesai,
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
            await viewModel.buatKamusMapel(statusTugas: viewModel.filterTugas, query: searchText, forceLoad: true)

            // Memastikan pembaruan UI dilakukan di thread utama (`MainActor`).
            await MainActor.run { [unowned self] in
                // Mendapatkan `sortDescriptor` yang saat ini digunakan oleh `outlineView`.
                // Jika tidak ada, gunakan default "NamaGuru" ascending.
                let indicator = outlineView.sortDescriptors.first ?? NSSortDescriptor(key: "NamaGuru", ascending: outlineView.sortDescriptors.first?.ascending ?? true)

                // Mengurutkan model data (`mapelList` dan `guruList` di dalamnya)
                // berdasarkan `sortDescriptor` yang ditemukan.
                viewModel.sortModel(by: indicator)

                // Memuat ulang semua data di `NSOutlineView` untuk menampilkan hasil pencarian yang baru.
                outlineView.reloadData()

                // Memperluas semua item di `outlineView` (baik parent maupun child)
                // agar semua hasil pencarian terlihat.
                outlineView.expandItem(nil, expandChildren: true)
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
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.dataDidChangeNotification, object: nil)
    }
}

extension TugasMapelVC: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let mapel = item as? MapelModel {
            return mapel.guruList.count // Jumlah guru dalam mapel
        }
        return viewModel.daftarMapel.count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let mapel = item as? MapelModel {
            return mapel.guruList[index] // Kembalikan guru dari mapel tersebut
        }

        return viewModel.daftarMapel[index] // Kembalikan mapel jika item adalah nil
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
        textField.textColor = .controlTextColor
        let columnWidth = outlineView.tableColumn(withIdentifier: tableColumn!.identifier)?.width ?? 100
        let isNamaGuru = tableColumn?.identifier.rawValue == "NamaGuru"
        applyCommonConstraints(to: textField, in: cell, isNamaGuru: isNamaGuru)
        if let mapel = item as? MapelModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = mapel.namaMapel
                if mapel.namaMapel.isEmpty {
                    textField.stringValue = "-"
                }
                textField.font = NSFont.boldSystemFont(ofSize: 13) // Opsi: Teks tebal untuk parent
            } else {
                textField.stringValue = ""
            }
        } else if let guru = item as? GuruModel {
            if tableColumn?.identifier.rawValue == "NamaGuru" {
                textField.stringValue = guru.namaGuru
            } else if tableColumn?.identifier.rawValue == "TahunAktif" {
                textField.stringValue = guru.tahunaktif ?? ""
            } else if tableColumn?.identifier.rawValue == "Struktural" {
                textField.stringValue = guru.struktural ?? ""
            } else if tableColumn?.identifier.rawValue == "Status" {
                textField.stringValue = guru.statusTugas.description
            } else if tableColumn?.identifier.rawValue == "Kelas" {
                textField.stringValue = guru.kelas ?? ""
                textField.textColor = .secondaryLabelColor
            } else if tableColumn?.identifier.rawValue == "Tanggal Mulai" {
                ReusableFunc.updateDateFormat(for: cell, dateString: guru.tglMulai ?? "", columnWidth: columnWidth)
            } else if tableColumn?.identifier.rawValue == "Tanggal Selesai" {
                ReusableFunc.updateDateFormat(for: cell, dateString: guru.tglSelesai ?? "", columnWidth: columnWidth)
            }
            textField.font = NSFont.systemFont(ofSize: 13)
        }
        if tableColumn?.identifier.rawValue == "Mapel" {
            tableColumn?.isHidden = true
        }
        return cell
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let mapel = item as? MapelModel {
            return !mapel.guruList.isEmpty
        }
        return false
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView,
              let wc = AppDelegate.shared.mainWindow.windowController as? WindowController
        else { return }

        // Dapatkan indeks item yang dipilih
        let selectedIndex = outlineView.selectedRow
        // Cek apakah ada item yang dipilih
        let isItemSelected = selectedIndex != -1
        // Dapatkan toolbar item yang ingin Anda atur
        if let hapusToolbarItem = wc.hapusToolbar,
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = isItemSelected
            hapus.target = isItemSelected ? self : nil
            hapus.action = isItemSelected ? #selector(hapusSerentak(_:)) : nil
        }
        if let editToolbarItem = wc.editToolbar,
           let edit = editToolbarItem.view as? NSButton
        {
            edit.isEnabled = isItemSelected
        }
        NSApp.sendAction(#selector(TugasMapelVC.updateMenuItem(_:)), to: nil, from: self)
    }

    func outlineViewItemDidExpand(_: Notification) {
        saveExpandedItems()
    }

    func outlineViewItemDidCollapse(_: Notification) {
        saveExpandedItems()
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem _: Any) -> CGFloat {
        outlineView.rowHeight
    }

    func outlineView(_: NSOutlineView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    func outlineViewColumnDidMove(_: Notification) {
        ReusableFunc.updateColumnMenu(outlineView, tableColumns: outlineView.tableColumns, exceptions: ["NamaGuru", "Mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        // Ambil sort descriptor pertama atau gunakan default
        if let indicator = outlineView.sortDescriptors.first {
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                viewModel.sortModel(by: indicator)
                ReusableFunc.saveSortDescriptor(indicator, key: "TugasMapelSortDescriptor")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.outlineView.reloadData()
                    self?.loadExpandedItems()
                }
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

    func outlineView(_: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        if let mapel = item as? MapelModel {
            return mapel.namaMapel
        } else if let guru = item as? GuruModel {
            return guru.namaGuru
        }
        return nil
    }

    func outlineViewColumnDidResize(_: Notification) {
        outlineView.beginUpdates()
        for row in 0 ..< outlineView.numberOfRows {
            guard let item = outlineView.item(atRow: row) as? GuruModel else { continue }

            if let columnTglMulai = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Mulai")),
               let column = outlineView?.column(withIdentifier: columnTglMulai.identifier),
               let cellView = outlineView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView
            {
                ReusableFunc.updateDateFormat(for: cellView, dateString: item.tglMulai ?? "", columnWidth: columnTglMulai.width)
            }
            if let columnTglSelesai = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Seleai")),
               let column1 = outlineView?.column(withIdentifier: columnTglSelesai.identifier),
               let cellView = outlineView.view(atColumn: column1, row: row, makeIfNecessary: false) as? NSTableCellView
            {
                ReusableFunc.updateDateFormat(for: cellView, dateString: item.tglSelesai ?? "", columnWidth: columnTglSelesai.width)
            }
        }
        outlineView.endUpdates()
    }
}

extension TugasMapelVC: NSMenuDelegate {
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
        guard let representedRows = sender.representedObject as? IndexSet else {
            // Jika `representedObject` bukan `IndexSet` (atau `nil`),
            // asumsikan bahwa operasi penyalinan berlaku untuk semua baris yang dipilih.
            ReusableFunc.salinBaris(selectedRows, from: outlineView)
            return // Hentikan eksekusi fungsi di sini.
        }

        // Mendapatkan indeks baris yang terakhir diklik di `outlineView`.
        let clickedRow = outlineView.clickedRow

        let rowsToProcess = ReusableFunc.determineRelevantRows(
            clickedRow: clickedRow,
            selectedRows: selectedRows,
            representedRows: representedRows
        )
        ReusableFunc.salinBaris(rowsToProcess, from: outlineView)
    }

    @objc func filterTugas(_ sender: NSMenuItem) {
        if viewModel.filterTugas == .aktif {
            viewModel.filterTugas = nil
        } else {
            viewModel.filterTugas = .aktif
        }
        sender.state = viewModel.filterTugas == nil ? .on : .off
    }

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/TugasMapelVC``.
    @objc func updateMenuItem(_: Any?) {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let deleteMenuItem = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem
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
