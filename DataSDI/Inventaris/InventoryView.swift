//
//  InventoryView.swift
//  Dynamic Table
//
//  Created by Bismillah on 19/10/24.
//

import Cocoa
import Quartz

class InventoryView: NSViewController {
    /// Outlet ScrollView yang menampung ``tableView``
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet `NSTableView`.
    @IBOutlet weak var tableView: EditableTableView!

    /// Task `Swift Concurency`
    var searchTask: Task<Void, Never>?

    /// Kamus array untuk [Nama Kolom: Tipe Data]
    var data: [[String: Any]] = []

    /// Lihat: ``DynamicTable/shared``
    let manager: DynamicTable = .shared

    /// Oultet column default di XIB.
    ///
    /// Kolom ini ditimpa oleh kolom-kolom yang ada di database.
    @IBOutlet weak var defaultColumn: NSTableColumn!

    /// Menu untuk header kolom ``tableView``
    let headerMenu: NSMenu = .init()

    /// Instans FileManager.default
    let defaults: UserDefaults = .standard

    /// Properti `NSUndoManager` khusus ``DataSDI/InventoryView``
    var myUndoManager: UndoManager = .init()

    /// Properti untuk menyimpan referensi jika ``data`` telah diisi dengan data yang ada
    /// di database dan telah ditampilkan setiap barisnya di ``tableView``
    var isDataLoaded: Bool = false

    /// Instans untuk format tanggal. Lihat: ``DataSDI/SingletonData/dateFormatter``
    let dateFormatter = SingletonData.dateFormatter

    // MARK: - UNDOSTACK

    /// Properti yang menyimpan ID unik setiap data baru untuk keperluan undo/redo.
    var newData: Set<Int64> = []

    /// Properti ukuran foto di dalam baris kolom Nama Barang.
    var size: NSSize = .init()

    /// Teks prediksi ketik untuk setiap kolom
    var databaseSuggestions: NSCache<NSString, NSArray> = .init()

    /// Properti string pencarian d toolbar ``DataSDI/WindowController/search``.
    var stringPencarian: String = ""

    /// Menu untuk ``tableView``.
    var actionMenu: NSMenu = .init()

    /// Menu untuk action toolbar ``DataSDI/WindowController/actionToolbar``.
    var toolbarMenu: NSMenu = .init()

    /// Properti kumpulan ID unik dari setiap row yang dipilih.
    ///
    /// Digunakan untuk memilih baris  di ``tableView``yang berisi ID yang sesuai
    /// setelah mengurutkan data dan memuat ulang ``tableView``.
    var selectedIDs: Set<Int64> = []

    // MARK: - TAMPILAN

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.removeTableColumn(defaultColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tampilkanFoto(_:))
        setupTableDragAndDrop()
        setupTable()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // ini harus di viewdidappear karena menunggu window siap
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: isDataLoaded)
            loadSavedColumns()
            Task { [unowned self] in
                data = await manager.loadData()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    setupDescriptor()
                    for tableColumn in tableView.tableColumns {
                        let columnIdentifier = tableColumn.identifier.rawValue
                        if let savedWidth = defaults.object(forKey: "Inventaris_tableColumnWidth_\(columnIdentifier)") as? CGFloat {
                            tableColumn.width = savedWidth
                        }

                        let customHeaderCell = MyHeaderCell()
                        customHeaderCell.title = tableColumn.title
                        tableColumn.headerCell = customHeaderCell
                    }
                    tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
                    isDataLoaded = true
                    if let window = view.window {
                        ReusableFunc.closeProgressWindow(window)
                    }
                    tableView.defaultEditColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Nama Barang"))
                    refreshSuggestions()
                }
            }

            tableView.editAction = { row, column in
                // Anda bisa menambahkan logika tambahan di sini jika perlu sebelum memanggil startEditing
                AppDelegate.shared.editorManager.startEditing(row: row, column: column)
            }
        }

        actionMenu = buatMenuItem()
        toolbarMenu = buatMenuItem()
        actionMenu.delegate = self
        tableView.menu = actionMenu
        toolbarItem()
        // HeigtRowImage
        if tableView.rowHeight <= 18 { size = NSSize(width: 16, height: 16) } else if tableView.rowHeight >= 34 { size = NSSize(width: 36, height: 36) }
        updateMenuItem(self)
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            updateUndoRedo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                view.window?.makeFirstResponder(tableView)
                setupColumnMenu()
                ReusableFunc.updateSearchFieldToolbar(view.window!, text: stringPencarian)
            }
        }
    }

    /// Func untuk emuat ulang seluruh ``data`` dari table *main_table* di database
    /// dan memperbarui ``tableView`` dengan data terbaru.
    @objc func muatUlang(_: Any) {
        Task { [weak self] in
            guard let self else { return }
            data = await manager.loadData()
            Task { [weak self] in
                guard let self else { return }
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
                updateUndoRedo()
            }
        }
    }

    /// Func untuk menyimpan semua informasi tabel. Urutan kolom, kolom yang disembunyikan, lebar kolom, urutan tabel sesuai kolom.
    func saveTableInfo() {
        // Simpan urutan kolom
        let columnOrder = tableView.tableColumns.map(\.identifier.rawValue)
        defaults.set(columnOrder, forKey: "ColumnOrder")

        // Simpan visibilitas kolom
        var hiddenColumns: [String] = []
        for column in tableView.tableColumns {
            if column.isHidden {
                hiddenColumns.append(column.identifier.rawValue)
            }
        }
        defaults.set(hiddenColumns, forKey: "HiddenColumns")

        // Simpan lebar kolom
        var columnWidths: [String: CGFloat] = [:]
        for column in tableView.tableColumns {
            columnWidths[column.identifier.rawValue] = column.width
        }
        defaults.set(columnWidths, forKey: "ColumnWidths")

        // Simpan sort descriptor saat ini
        if let sortDescriptor = tableView.sortDescriptors.first {
            let sortInfo: [String: Any] = [
                "key": sortDescriptor.key ?? "",
                "ascending": sortDescriptor.ascending,
            ]
            defaults.set(sortInfo, forKey: "SortInfo")
        }
    }

    /// Func untuk menyembunyikan/menampilkan kolom tertentu.
    /// - Parameter sender: Objek `NSMenuItem` dengan representedObject yang merupakan NSTableColumn.
    /// representedObject bisa diset saat menu item tersebut pertama kali dibuat.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        if column.identifier.rawValue == "Nama Barang" {
            // Kolom nama tidak dapat disembunyikan
            return
        }
        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
        saveTableInfo()
    }

    /// Bertanggung jawab untuk konfigurasi item-item menu
    /// kolom di ``tableView`` yang ditampilkan ketika diklik kanan.
    func setupColumnMenu() {
        DispatchQueue.main.async { [unowned self] in
            ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["Nama Barang"], target: self, selector: #selector(toggleColumnVisibility(_:)))
            tableView.headerView?.menu?.addItem(NSMenuItem.separator())
            // Menambahkan opsi untuk menghapus kolom
            for column in tableView.tableColumns {
                guard !headerMenu.items.contains(where: { $0.title == "Hapus \(column.title)" }) else { continue }
                // Gunakan && (dan) untuk memastikan kolom yang tidak boleh dihapus
                if column.identifier.rawValue != "id",
                   column.identifier.rawValue != "Nama Barang",
                   column.identifier.rawValue != "Kondisi",
                   column.identifier.rawValue != "Lokasi",
                   column.identifier.rawValue != "Tanggal Dibuat",
                   column.identifier.rawValue != "Foto"
                {
                    let menuItem = NSMenuItem(title: column.title, action: #selector(deleteColumnButtonClicked(_:)), keyEquivalent: "")
                    menuItem.representedObject = column.identifier
                    let smallFont = NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small))
                    menuItem.attributedTitle = NSAttributedString(string: "Hapus \(column.title)", attributes: [.font: smallFont])

                    let editMenuItem = NSMenuItem(title: column.title, action: #selector(editNamaKolom(_:)), keyEquivalent: "")
                    editMenuItem.representedObject = column.identifier
                    editMenuItem.attributedTitle = NSAttributedString(string: "Edit \(column.title)", attributes: [.font: smallFont])

                    tableView.headerView?.menu?.addItem(editMenuItem)
                    tableView.headerView?.menu?.addItem(menuItem)
                    tableView.headerView?.menu?.addItem(NSMenuItem.separator())
                }
            }
        }
    }

    /// Func untuk memuat konfigurasi kolom-kolom yang disimpan
    /// sebelumnya dari ``saveTableInfo()`` dan menambahkannya
    /// ke ``tableView``.
    func loadSavedColumns() {
        DispatchQueue.main.async { [unowned self] in
            // Muat urutan kolom yang tersimpan
            let savedColumnOrder = defaults.array(forKey: "ColumnOrder") as? [String] ?? []

            // Muat informasi kolom tersembunyi
            let hiddenColumns = defaults.array(forKey: "HiddenColumns") as? [String] ?? []

            // Hapus semua kolom yang ada
            for column in tableView.tableColumns {
                tableView.removeTableColumn(column)
            }

            // Fungsi helper untuk menambahkan kolom dengan urutan dan pengaturan yang benar
            func addColumnWithSavedSettings(name: String) {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
                column.title = name
                column.isHidden = hiddenColumns.contains(name)
                let widthKey = "Inventaris_tableColumnWidth_\(name)"
                if let savedWidth = defaults.object(forKey: widthKey) as? CGFloat {
                    column.width = savedWidth
                }
                tableView.addTableColumn(column)
            }

            // Tambahkan kolom sesuai urutan yang tersimpan
            for columnName in savedColumnOrder {
                if SingletonData.columns.contains(where: { $0.name == columnName }) {
                    addColumnWithSavedSettings(name: columnName)
                    #if DEBUG
                        print("columnName:", columnName)
                    #endif
                }
            }

            // Tambahkan kolom baru yang mungkin belum ada dalam urutan tersimpan
            for column in SingletonData.columns {
                if !savedColumnOrder.contains(column.name) {
                    addColumnWithSavedSettings(name: column.name)
                    #if DEBUG
                        print("savedColumnOrder columnName:", column.name)
                    #endif
                }
            }

            // Terapkan sort descriptor
            if let sortInfo = defaults.dictionary(forKey: "SortInfo"),
               let key = sortInfo["key"] as? String,
               let ascending = sortInfo["ascending"] as? Bool
            {
                let sortDescriptor = NSSortDescriptor(key: key, ascending: ascending)
                tableView.sortDescriptors = [sortDescriptor]
            } else {
                tableView.sortDescriptors = [NSSortDescriptor(key: "Nama Barang", ascending: true)]
            }
            tableView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
            tableView.sizeToFit()
            tableView.tile()
        }
    }

    /// Func untuk mengkonfigurasi `NSSortDescriptor` untuk setiap kolom ``tableView``.
    ///
    /// Key `NSSortDescriptor` diset sesuai nama kolom.
    func setupDescriptor() {
        for column in SingletonData.columns {
            let sortDescriptor = NSSortDescriptor(key: column.name, ascending: true, selector: #selector(InventoryView.compareValues(_:_:)))
            if let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column.name)) {
                tableColumn.sortDescriptorPrototype = sortDescriptor
            }
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
        wc.searchField.placeholderString = "Cari inventaris..."

        // Tambah Data
        wc.tambahSiswa.isEnabled = true
        wc.tambahSiswa.toolTip = "Catat Inventaris Baru"

        // Tambah nilai kelas
        wc.tambahDetaildiKelas.isEnabled = true
        let image = NSImage(named: "add-pos")
        image?.isTemplate = true
        wc.datakelas.image = image
        wc.datakelas.label = "Tambah Kolom"
        wc.datakelas.paletteLabel = "Tambahkan Kolom Baru"
        wc.tambahDetaildiKelas.toolTip = "Tambahkan Kolom Baru ke dalam Tabel"

        // Kalkulasi nilai kelas
        wc.kalkulasiButton.isEnabled = false

        // Action Menu
        wc.actionPopUpButton.menu = toolbarMenu
        toolbarMenu.delegate = self

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

    /// Func untuk konfigurasi menu item di Menu Bar.
    ///
    /// Menu item ini dikonfigurasi untuk sesuai dengan action dan target ``DataSDI/InventoryView``
    @objc func updateMenuItem(_: Any?) {
        if let copyMenuItem = ReusableFunc.salinMenuItem,
           let deleteMenuItem = ReusableFunc.deleteMenuItem,
           let new = ReusableFunc.newMenuItem,
           let pasteMenuItem = ReusableFunc.pasteMenuItem
        {
            let isRowSelected = tableView.selectedRowIndexes.count > 0
            // Update item menu "Copy"
            copyMenuItem.isEnabled = isRowSelected
            copyMenuItem.target = self
            copyMenuItem.action = #selector(salinData(_:))
            pasteMenuItem.target = self
            pasteMenuItem.action = SingletonData.originalPasteAction
            // Update item menu "Delete"
            deleteMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(delete(_:))
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinData(_:))
            } else {
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                deleteMenuItem.isEnabled = false
                copyMenuItem.target = SingletonData.originalCopyTarget
                copyMenuItem.action = SingletonData.originalCopyAction
                copyMenuItem.isEnabled = false
            }
            new.target = self
            new.action = #selector(addRowButtonClicked(_:))
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

    /// Lihat: ``DataSDI/ReusableFunc/increaseSize(_:)``
    @IBAction func increaseSize(_: Any?) {
        ReusableFunc.increaseSize(tableView)
        saveRowHeight()
    }

    /// Lihat: ``DataSDI/ReusableFunc/decreaseSize(_:)``
    @IBAction func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSize(tableView)
        saveRowHeight()
    }

    /// Func untuk menyimpan konfigurasi tinggi baris ``tableView`` ke UserDefaults.
    func saveRowHeight() {
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "InventoryTableViewRowHeight")
    }

    /// func untuk menyiapkan konfigurasi awal ``tableView``.
    func setupTable() {
        if let savedRowHeight = UserDefaults.standard.value(forKey: "InventoryTableViewRowHeight") as? CGFloat {
            tableView.rowHeight = savedRowHeight
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if SharedQuickLook.shared.isQuickLookVisible() {
            SharedQuickLook.shared.closeQuickLook()
        }
        saveTableInfo()
        ReusableFunc.resetMenuItems()
        ReusableFunc.updateSearchFieldToolbar(view.window!, text: "")
        searchTask?.cancel()
        searchTask = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Cache untuk prediksi ketik

extension InventoryView {
    /// Mendapatkan daftar saran (suggestions) untuk kolom tertentu.
    /// Fungsi ini pertama-tama mencoba mengambil saran dari cache memori (`databaseSuggestions`).
    /// Jika saran tidak ditemukan di cache, ia akan memuatnya secara asinkron dari database
    /// di antrean latar belakang untuk menghindari pemblokiran UI.
    ///
    /// Setelah saran dimuat dari database, mereka akan disimpan ke dalam cache untuk penggunaan di masa mendatang.
    ///
    /// - Parameter column: Objek `Column` yang mewakili kolom yang ingin Anda dapatkan sarannya.
    ///                     `column.name` digunakan sebagai kunci untuk cache dan pengambilan database.
    ///
    /// - Returns: Sebuah array `[String]` yang berisi saran yang ditemukan di cache.
    ///            Jika saran tidak ada di cache, array kosong (`[]`) akan dikembalikan segera,
    ///            sementara pemuatan dari database dilakukan di latar belakang.
    func getSuggestions(for column: Column) -> [String] {
        if let cachedSuggestions = databaseSuggestions.object(forKey: column.name as NSString) as? [String] {
            return cachedSuggestions
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            loadSuggestionsFromDatabase(for: column) { suggestions in
                self.databaseSuggestions.setObject(suggestions as NSArray, forKey: column.name as NSString)
            }
        }

        return []
    }

    /// Mengambil saran unik dari basis data untuk kolom tertentu dengan keanggunan.
    /// Fungsi ini dirancang untuk secara asinkron memuat dan menyaring nilai-nilai yang berbeda
    /// dari kolom yang ditunjuk dalam 'main_table', kemudian menyajikannya sebagai
    /// daftar saran yang terurut secara alfabetis. Ini termasuk ekstraksi kata-kata
    /// individual untuk memberikan spektrum saran yang lebih luas.
    ///
    /// - Parameters:
    ///   - column: Objek `Column` yang menjadi fokus pencarian saran.
    ///             Nama kolomnya (`column.name`) adalah kunci penentu dalam eksekusi kueri.
    ///   - completion: Sebuah closure escapable yang akan dieksekusi setelah proses pengambilan data
    ///                 selesai. Closure ini menerima sebuah array `[String]` yang berisi
    ///                 saran-saran yang telah dikurasi dan diurutkan. Jika terjadi kesalahan
    ///                 atau data tidak ditemukan, array kosong akan disajikan.
    func loadSuggestionsFromDatabase(for column: Column, completion: @escaping ([String]) -> Void) {
        // Memastikan koneksi ke basis data tersedia. Tanpa itu, tidak ada saran yang dapat diambil.
        guard let db = DynamicTable.shared.db else {
            completion([]) // Segera selesaikan dengan daftar kosong jika basis data tidak terhubung.
            return
        }

        // Sebuah set digunakan untuk mengumpulkan saran-saran unik, menghindari duplikasi.
        var suggestionsSet: Set<String> = []

        do {
            // Merangkai kueri SQL untuk mengambil nilai-nilai unik dan non-kosong dari kolom yang ditentukan.
            // Kueri ini memastikan hanya nilai yang relevan yang dipertimbangkan sebagai saran.
            let query = """
                SELECT DISTINCT "\(column.name)"
                FROM "main_table"
                WHERE "\(column.name)" IS NOT NULL
                AND "\(column.name)" != ''
            """
            // Menyiapkan pernyataan SQL untuk eksekusi yang aman.
            let statement = try db.prepare(query)

            // Mengiterasi setiap baris hasil kueri.
            for row in statement {
                if let value = row[0] as? String, !value.isEmpty {
                    suggestionsSet.insert(value)
                    // Pisahkan nilai menjadi kata-kata individual untuk memperkaya daftar saran.
                    // Filter kata-kata yang terlalu pendek atau hanya spasi.
                    let words = value.components(separatedBy: .whitespacesAndNewlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first?.isLetter == true)) }
                    suggestionsSet.formUnion(words)
                }
            }

            // Setelah semua saran terkumpul, ubah set menjadi array, urutkan secara alfabetis,
            // dan sajikan melalui completion handler.
            completion(Array(suggestionsSet).sorted())
        } catch {
            print(error.localizedDescription)
            completion([])
        }
    }

    /// Fungsi untuk memperbarui cache suggestions
    func updateSuggestionsCache() {
        databaseSuggestions.removeAllObjects()
        for column in SingletonData.columns {
            loadSuggestionsFromDatabase(for: column, completion: { [weak self] suggestions in
                self?.databaseSuggestions.setObject(suggestions as NSArray, forKey: column.name as NSString)
            })
        }
    }

    /// Panggil ini ketika data berubah untuk memperbarui cache prediksi.
    func refreshSuggestions() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.updateSuggestionsCache()
        }
    }
}

// MARK: - SEARCH

extension InventoryView: NSSearchFieldDelegate {
    /// Menangani input dari `NSSearchField` untuk memicu pencarian dengan penundaan (debouncing).
    /// Fungsi ini membatalkan operasi pencarian sebelumnya yang sedang berjalan dan memulai tugas baru
    /// dengan penundaan singkat. Ini mencegah terlalu banyak pembaruan pencarian saat pengguna mengetik,
    /// sehingga meningkatkan kinerja dan responsivitas aplikasi.
    ///
    /// - Parameter sender: `NSSearchField` yang memicu aksi ini, yang berisi string pencarian.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        // Batalkan `searchTask` yang sedang berjalan (jika ada).
        // Ini adalah teknik debouncing: setiap kali input baru datang, tugas sebelumnya dibatalkan
        // agar hanya tugas terakhir yang selesai.
        searchTask?.cancel()

        // Membuat `Task` asinkron baru untuk melakukan pencarian.
        searchTask = Task { [weak self] in
            // Menunggu selama 0.5 detik sebelum melanjutkan.
            // Ini memberikan jeda singkat sehingga jika pengguna mengetik cepat,
            // tugas ini akan dibatalkan oleh input berikutnya.
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 detik

            // Memeriksa apakah `Task` telah dibatalkan atau jika `self` telah dilepaskan dari memori.
            // Jika salah satu kondisi benar, hentikan eksekusi.
            guard !Task.isCancelled, let self else { return }

            // Memanggil fungsi `search` dengan nilai string dari `NSSearchField`.
            // Fungsi `search` diasumsikan akan melakukan logika pencarian data yang sebenarnya.
            await search(sender.stringValue)

            // Meminta `tableView` untuk melepaskan status first responder-nya.
            // Ini mungkin untuk menghilangkan fokus keyboard dari tabel setelah pencarian selesai.
            tableView.resignFirstResponder()
        }
    }

    /// Melakukan pencarian data secara asinkron berdasarkan teks pencarian yang diberikan.
    /// Fungsi ini memuat semua data, lalu memfilter data tersebut untuk menemukan baris yang cocok
    /// dengan teks pencarian di kolom mana pun. Proses pemfilteran dilakukan secara paralel
    /// untuk efisiensi. Hasil pencarian kemudian diperbarui pada tampilan tabel.
    ///
    /// - Parameter searchText: `String` yang berisi teks yang akan digunakan untuk pencarian.
    func search(_ searchText: String) async {
        // Jika teks pencarian sama dengan `stringPencarian` yang terakhir, tidak perlu melakukan pencarian ulang.
        if searchText == stringPencarian { return }

        // Memperbarui `stringPencarian` dengan teks pencarian yang baru.
        stringPencarian = searchText

        // Jika `searchText` kosong, berarti pengguna telah menghapus teks pencarian.
        // Dalam kasus ini, muat ulang semua data asli ke tabel.
        if searchText.isEmpty {
            data = await manager.loadData() // Muat semua data dari manager.
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Beri tahu tabel untuk memperbarui tampilan berdasarkan deskriptor pengurutan saat ini.
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
            }
            return // Hentikan eksekusi fungsi karena pencarian selesai.
        }

        // Muat semua data asli dari manager untuk kemudian difilter.
        let originalData = await manager.loadData()

        // Memfilter data menggunakan `withTaskGroup` untuk melakukan pencarian secara paralel.
        // Ini meningkatkan kinerja dengan mendistribusikan pekerjaan pencarian ke beberapa tugas.
        let filteredData = await withTaskGroup(of: [String: Any]?.self) { group in
            // Iterasi melalui setiap baris dalam `originalData`.
            for row in originalData {
                // Menambahkan tugas baru ke grup untuk setiap baris.
                group.addTask {
                    // Untuk setiap baris, iterasi melalui semua kolom yang didefinisikan di `SingletonData.columns`.
                    for column in SingletonData.columns {
                        // Periksa apakah nilai kolom (setelah dikonversi ke String dan diubah menjadi huruf kecil)
                        // mengandung `searchText` (juga dalam huruf kecil).
                        if let value = row[column.name],
                           "\(value)".lowercased().contains(searchText.lowercased())
                        {
                            return row // Jika cocok, kembalikan baris tersebut.
                        }
                    }
                    return nil // Jika tidak ada kolom yang cocok di baris ini, kembalikan `nil`.
                }
            }

            var hasil: [[String: Any]] = [] // Array untuk menyimpan hasil pencarian.
            // Kumpulkan hasil dari semua tugas yang telah selesai di grup.
            for await item in group {
                if let data = item {
                    hasil.append(data) // Tambahkan baris yang cocok ke hasil.
                }
            }
            return hasil // Kembalikan data yang sudah difilter.
        }

        // Kembali ke `MainActor` untuk memperbarui UI.
        await MainActor.run { [unowned self] in
            // Ganti data tabel dengan data yang sudah difilter.
            data = filteredData
            // Beri tahu tabel untuk memperbarui tampilan berdasarkan deskriptor pengurutan saat ini.
            tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        }
    }
}

// MARK: - QUICK LOOK

extension InventoryView {
    /// Menampilkan foto-foto yang terkait dengan baris yang dipilih atau yang diklik di tabel menggunakan Quick Look.
    /// Fungsi ini menentukan apakah akan menampilkan pratinjau untuk satu baris (berdasarkan klik)
    /// atau untuk beberapa baris (berdasarkan seleksi), kemudian memanggil fungsi `showQuickLook` yang sesuai.
    ///
    /// - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini.
    @objc func tampilkanFotos(_: NSMenuItem) {
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let klikRow = tableView.clickedRow

        // Memeriksa apakah ada baris yang diklik (`klikRow` valid).
        if klikRow != -1 {
            // Kondisi pertama: Jika baris yang diklik termasuk dalam baris yang saat ini dipilih
            // dan `klikRow` adalah indeks yang valid (tidak negatif).
            if tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                // Tampilkan Quick Look untuk semua baris yang dipilih.
                showQuickLook(tableView.selectedRowIndexes)
            }
            // Kondisi kedua: Jika baris yang diklik TIDAK termasuk dalam baris yang dipilih
            // dan `klikRow` adalah indeks yang valid. Ini berarti hanya satu baris yang diklik
            // tanpa memengaruhi seleksi lainnya.
            else if !tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                // Tampilkan Quick Look hanya untuk baris yang diklik.
                showQuickLook(IndexSet([klikRow]))
            }
        }
        // Kondisi default: Jika tidak ada baris yang diklik (`klikRow == -1`),
        // atau jika kondisi di atas tidak terpenuhi, secara default tampilkan
        // Quick Look untuk semua baris yang saat ini dipilih.
        else {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    /// Menampilkan pratinjau cepat (Quick Look) untuk foto-foto yang terkait dengan baris yang dipilih.
    /// Fungsi ini menyiapkan file gambar sementara di direktori sementara sistem dan kemudian
    /// menginisialisasi atau memperbarui `QLPreviewPanel` untuk menampilkan gambar-gambar tersebut.
    ///
    /// - Parameter index: Sebuah `IndexSet` yang berisi indeks baris-baris di tabel
    ///                    yang foto-fotonya akan ditampilkan di Quick Look.
    func showQuickLook(_ index: IndexSet) {
        guard !index.isEmpty else { return }

        SharedQuickLook.shared.sourceTableView = tableView

        // Bersihkan preview items yang lama
        SharedQuickLook.shared.cleanTempDir()
        SharedQuickLook.shared.cleanPreviewItems()
        SharedQuickLook.shared.columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Nama Barang"))

        // Buat temporary directory baru
        let sessionID = UUID().uuidString
        SharedQuickLook.shared.setTempDir(FileManager.default.temporaryDirectory.appendingPathComponent(sessionID))

        guard let tempDir = SharedQuickLook.shared.getTempDir() else { return }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for row in index.reversed() {
                var trimmedNama: String
                var fileName: String
                var fileURL: URL!

                guard let id = data[row]["id"] as? Int64,
                      let nama = data[row]["Nama Barang"] as? String
                else { continue }

                let imageData = manager.getImageSync(id)

                trimmedNama = nama.replacingOccurrences(of: "/", with: "-")
                fileName = "\(trimmedNama).png"
                fileURL = tempDir.appendingPathComponent(fileName)

                try imageData.write(to: fileURL)

                SharedQuickLook.shared.setPreviewItems(fileURL)
            }

            SharedQuickLook.shared.showQuickLook()

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space key
            if SharedQuickLook.shared.isQuickLookVisible() {
                SharedQuickLook.shared.closeQuickLook()
            } else {
                showQuickLook(tableView.selectedRowIndexes)
            }
        } else if event.keyCode == 53 { // Key code 53 adalah tombol Esc
            if SharedQuickLook.shared.isQuickLookVisible() {
                SharedQuickLook.shared.closeQuickLook()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: EDITOR OVERLAY DATA SOURCE

extension InventoryView: OverlayEditorManagerDataSource {
    func overlayEditorManager(_: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard row < data.count else { return "" }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue

        return data[row][columnIdentifier] as? String ?? "" // Sesuaikan dengan model data Anda
    }

    func overlayEditorManager(_: OverlayEditorManager, originalColumnWidthForCellAtRow _: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        // Asumsi hanya ada satu kolom atau kolom yang diedit adalah kolom yang diketahui
        tableView.tableColumns[column].width // Sesuaikan jika perlu
    }

    func overlayEditorManager(_: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        guard let column = SingletonData.columns.first(where: { $0.name == columnIdentifier }) else { return [] }
        // Ambil suggestions berdasarkan tipe kolom
        return getSuggestions(for: column)
    }
}

// MARK: EDITOR OVERLAY DATA DELEGATE

extension InventoryView: OverlayEditorManagerDelegate {
    func overlayEditorManager(_: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard row < data.count, column < tableView.tableColumns.count else { return }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue

        if let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
           let textField = cell.textField,
           let oldString = data[row][columnIdentifier] as? String
        {
            if newText == oldString || (columnIdentifier == "Nama Barang" && newText.isEmpty) {
                textField.stringValue = oldString
                return
            }
        }

        let oldValw = data[row][columnIdentifier]
        data[row][columnIdentifier] = newText.capitalizedAndTrimmed()

        // Dapatkan ID dari data
        guard let id = data[row]["id"] as? Int64 else {
            return
        }
        let model = TableChange(id: data[row]["id"] as! Int64, columnName: columnIdentifier, oldValue: oldValw as Any, newValue: data[row][columnIdentifier] as Any)
//        recordChange(id: data[row]["id"] as! Int64, columnName: columnKey, oldValue: oldValw as Any, newValue: data[row][columnKey] as Any)

        // Update database dengan nilai baru
        Task {
            await DynamicTable.shared.updateDatabase(ID: id, column: columnIdentifier, value: newText.capitalizedAndTrimmed())
        }
        myUndoManager.beginUndoGrouping()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.urung([model])
        })
        myUndoManager.endUndoGrouping()
        updateSuggestionsCache()
    }

    func overlayEditorManager(_: OverlayEditorManager, perbolehkanEdit column: Int, row _: Int) -> Bool {
        let identifier = tableView.tableColumns[column].identifier.rawValue
        if identifier == "id" || identifier == "Foto" || identifier == "Tanggal Dibuat" {
            return false
        }
        return true
    }
}
