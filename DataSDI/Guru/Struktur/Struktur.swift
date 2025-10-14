//
//  Struktur.swift
//  Data Manager
//
//  Created by Bismillah on 28/11/23.
//

import Cocoa
import Combine

/// Class yang mengelola struktur guru.
class Struktur: NSViewController {
    /// Menu item yang digunakan untuk menampilkan menu konteks.
    @IBOutlet var menuItem: NSMenu!
    /// Outlet untuk NSOutlineView yang menampilkan struktur guru.
    @IBOutlet weak var outlineView: NSOutlineView!
    /// Outlet untuk NSStackView yang menampilkan ``label``.
    @IBOutlet weak var labelStack: NSStackView!

    /// Outlet untuk NSBox yang digunakan sebagai garis horizontal di antara ``labelStack`` dan ``outlineView``.
    @IBOutlet weak var hLine: NSBox!
    /// Outlet untuk NSTextField yang menampilkan label struktur guru.
    @IBOutlet weak var label: NSTextField!
    /// Outlet untuk NSScrollView yang menampilkan ``outlineView``.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk NSVisualEffectView yang digunakan untuk efek visual pada header.
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    /// Variabel yang menandakan apakah data sudah dimuat.
    var isDataLoaded: Bool = false
    /// Menu yang digunakan untuk toolbar.
    var toolbarMenu: NSMenu = .init()
    /// Outlet constraint untuk jarak atas dari stack header.
    @IBOutlet weak var stackHeaderTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var thnAjrn1TextField: NSTextField!
    @IBOutlet weak var thnAjrn2TextField: NSTextField!

    /// viewModel yang bertugas untuk mengelola data.
    let viewModel: GuruViewModel = .shared

    /// Receiver untuk publisher ``StrukturEvent``.
    var cancellable: Set<AnyCancellable> = .init()

    /// Tahun terpilih misal: `2024/2025`.
    var tahunTerpilih = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.menu = menuItem
        menuItem.delegate = self
        toolbarMenu = menuItem.copy() as! NSMenu
        toolbarMenu.delegate = self
        if let savedRowHeight = UserDefaults.standard.value(forKey: "StrukturOutlineViewRowHeight") as? CGFloat {
            outlineView.rowHeight = savedRowHeight
        }
        label.alphaValue = 0.6
        visualEffect.material = .headerView
        thnAjrn1TextField.delegate = self
        thnAjrn2TextField.delegate = self
        thnAjrn1TextField.stringValue = UserDefaults.standard.strukturTahunAjaran1
        thnAjrn2TextField.stringValue = UserDefaults.standard.strukturTahunAjaran2
        guard !thnAjrn1TextField.stringValue.isEmpty, !thnAjrn2TextField.stringValue.isEmpty else { return }
        tahunTerpilih = thnAjrn1TextField.stringValue + "/" + thnAjrn2TextField.stringValue
        // Do view setup here.
    }

    override func viewDidAppear() {
        if !isDataLoaded {
            muatUlang(self)
            setupCombine()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.view.window?.makeFirstResponder(self.outlineView)
        }
        ReusableFunc.resetMenuItems()
        guard let toolbar = view.window?.toolbar else { return }
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.placeholderAttributedString = nil
            searchField.delegate = nil
            searchField.placeholderString = "Struktur Guru"
            searchField.isEditable = false
        }

        if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
           let zoom = zoomToolbarItem.view as? NSSegmentedControl
        {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(segmentedControlValueChanged(_:))
        }

        if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
           let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
        {
            kalkulasiNilai.isEnabled = false
        }

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

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton
        {
            tambah.isEnabled = false
        }

        if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
           let add = addToolbarItem.view as? NSButton
        {
            add.isEnabled = false
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
        {
            popUpButton.menu = toolbarMenu
        }
    }

    /// Mengambil data guru berdasarkan tahun yang diberikan.
    /// - Parameter tahun: Tahun yang digunakan sebagai filter data. Jika tidak diisi, akan mengambil semua data guru.
    /// - Note: Fungsi ini berjalan secara asynchronous.
    func fetchGuru(_: String = "") async {
        guard !tahunTerpilih.isEmpty else {
            await viewModel.buildStrukturGuru()
            return
        }

        await viewModel.buildStrukturGuru(tahunTerpilih)
    }

    /// Membangun tampilan outline view untuk menampilkan struktur data.
    /// Fungsi ini bertanggung jawab untuk menginisialisasi dan mengatur komponen outline view
    /// sesuai dengan kebutuhan aplikasi.
    /// Pastikan data sumber telah tersedia sebelum memanggil fungsi ini.
    @MainActor
    func buildOutlineView() async {
        outlineView.deselectAll(nil)
        outlineView.reloadData()
        try? await Task.sleep(nanoseconds: 200_000_000)
        outlineView.beginUpdates()
        outlineView.animator().expandItem(nil, expandChildren: true)
        outlineView.endUpdates()
        isDataLoaded = true
    }

    /// Fungsi untuk memuat ulang data guru dan membangun struktur hierarki.
    /// Fungsi ini akan mengambil data guru dari database, membangun dictionary berdasarkan struktural,
    /// dan membangun hierarki struktural. Setelah itu, outline view akan diperbarui untuk menampilkan data yang baru.
    /// - Parameter sender: Objek yang memicu aksi ini.
    @IBAction func muatUlang(_: Any) {
        Task(priority: .background) { [unowned self] in
            await fetchGuru(tahunTerpilih)
            await buildOutlineView()
        }
    }

    /// Menangani aksi ketika menu "Salin" dipilih oleh pengguna.
    /// - Parameter sender: NSMenuItem yang memicu aksi ini.
    @IBAction func salinMenu(_: NSMenuItem) {
        let clickedRow = outlineView.clickedRow
        let selectedRows = outlineView.selectedRowIndexes
        let rows = ReusableFunc.resolveRowsToProcess(
            selectedRows: selectedRows,
            clickedRow: clickedRow
        )
        ReusableFunc.salinBaris(rows, from: outlineView)
    }

    /// Menyalin seluruh data yang tersedia.
    ///
    /// Fungsi ini dipicu ketika pengguna menekan tombol "Salin Semua".
    /// Biasanya digunakan untuk menyalin semua informasi yang ditampilkan ke clipboard.
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya tombol pada antarmuka pengguna.
    @IBAction func salinSemua(_: Any) {
        // Variabel untuk menampung teks hasil salinan
        var salinan: [String] = []
        salinan.append("Struktur Guru \(tahunTerpilih)")
        // Iterasi melalui data hierarki
        for strukturalItem in viewModel.strukturDict {
            // Tambahkan nama struktural ke salinan
            salinan.append("\n\(strukturalItem.struktural):")

            for guru in strukturalItem.guruList {
                salinan.append("\(guru.namaGuru)")
            }
        }

        // Gabungkan semua string menjadi satu teks dengan newline sebagai pemisah
        let hasilSalinan = salinan.joined(separator: "\n")

        // Salin ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hasilSalinan, forType: .string)

        // Berikan notifikasi jika diperlukan (opsional)
    }

    /// Fungsi yang dipanggil ketika nilai segmented control berubah.
    /// Fungsi ini akan memanggil fungsi `increaseSize` atau `decreaseSize` sesuai dengan segment yang dipilih.
    /// - Parameter sender: NSSegmentedControl yang memicu aksi ini.
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

    /// Fungsi untuk memperbesar ukuran baris pada outline view.
    /// - Parameter sender: Objek pemicu.
    @IBAction func increaseSize(_: Any?) {
        ReusableFunc.increaseSizeStep(outlineView, userDefaultKey: "StrukturOutlineViewRowHeight")
    }

    /// Fungsi untuk memperkecil ukuran baris pada outline view.
    /// - Parameter sender: Objek pemicu.
    @IBAction func decreaseSize(_: Any?) {
        ReusableFunc.decreaseSizeStep(outlineView, userDefaultKey: "StrukturOutlineViewRowHeight")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Struktur: NSOutlineViewDataSource {
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // Jika item nil, maka kembalikan jumlah struktural (root level)
        if item == nil {
            return viewModel.strukturDict.count
        }

        // Jika item adalah tuple (struktural), kembalikan jumlah guru dalam struktural tersebut
        if let strukturalItem = item as? StrukturGuruDictionary {
            return strukturalItem.guruList.count
        }

        // Jika bukan keduanya, kembalikan 0
        return 0
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Hanya parent (struktural) yang bisa di-expand
        item is StrukturGuruDictionary
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        // Jika item nil, berikan parent (struktural)
        if item == nil {
            return viewModel.strukturDict[index]
        }

        // Jika item adalah parent (struktural), berikan child (guru)
        if let strukturalItem = item as? StrukturGuruDictionary {
            return strukturalItem.guruList[index]
        }

        // Jika tidak cocok, kembalikan nilai default
        return ""
    }
}

extension Struktur: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        // Pastikan ada identifier kolom
        guard let identifier = tableColumn?.identifier else { return nil }
        // Jika item adalah parent (struktural)
        if let strukturalItem = item as? StrukturGuruDictionary {
            if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView, let textField = cell.textField {
                // Set teks untuk parent (struktural)
                textField.translatesAutoresizingMaskIntoConstraints = false
                var leadingConstant: CGFloat = 5
                if item is (struktural: String, guruList: [GuruModel]) {
                    leadingConstant = 5
                }

                // Menghapus constraint yang sudah ada untuk mencegah duplikasi
                for constraint in cell.constraints {
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
                ])

                textField.stringValue = strukturalItem.struktural
                textField.font = NSFont.boldSystemFont(ofSize: 13) // Opsi: Teks tebal untuk parent

                return cell
            }
        }

        // Jika item adalah child (guru)
        if let guruItem = item as? GuruModel {
            if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView, identifier.rawValue == "NamaGuruColumn", let textField = cell.textField {
                // Set teks untuk parent (struktural)
                textField.translatesAutoresizingMaskIntoConstraints = false
                var leadingConstant: CGFloat = 0
                if item is (struktural: String, guruList: [GuruModel]) {
                    leadingConstant = 0
                }

                // Menghapus constraint yang sudah ada untuk mencegah duplikasi
                for constraint in cell.constraints {
                    if constraint.firstAnchor == textField.leadingAnchor {
                        cell.removeConstraint(constraint)
                    }
                }

                NSLayoutConstraint.activate([
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20),
                ])

                textField.stringValue = guruItem.namaGuru
                textField.font = NSFont.systemFont(ofSize: 13) // Opsi: Teks normal untuk child
                return cell
            }
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem _: Any) -> CGFloat {
        outlineView.rowHeight
    }

    func outlineViewSelectionDidChange(_: Notification) {
        NSApp.sendAction(#selector(Struktur.updateMenuItem(_:)), to: nil, from: self)
    }
}

extension Struktur: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menuItem)
        }
    }

    /// Fungsi untuk memperbarui menu tabel berdasarkan kondisi saat ini.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan menyesuaikan visibilitas item menu sesuai dengan kondisi tersebut.
    /// Jika tidak ada baris yang dipilih, maka akan menampilkan item filter, muat ulang, dan salin semua.
    /// Jika ada baris yang dipilih, maka akan menampilkan item salin dengan jumlah baris yang dipilih.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateTableMenu(_ menu: NSMenu) {
        guard let filterItem = menu.items.first(where: { $0.title == "Filter" }), let muatUlang = menu.items.first(where: { $0.title == "Muat Ulang" }), let salinSemua = menu.items.first(where: { $0.title == "Salin Semua" }), let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) else { return }

        if outlineView.clickedRow == -1 {
            salinItem.isHidden = true
            filterItem.isHidden = false
            muatUlang.isHidden = false
            salinSemua.isHidden = false
        } else {
            salinItem.isHidden = false
            filterItem.isHidden = true
            muatUlang.isHidden = true
            salinSemua.isHidden = true

            if outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
                salinItem.title = "Salin \(outlineView.numberOfSelectedRows) data..."
            } else {
                salinItem.title = "Salin 1 data..."
            }
        }
    }

    /// Fungsi untuk memperbarui menu toolbar berdasarkan kondisi saat ini.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan menyesuaikan visibilitas item menu sesuai dengan kondisi tersebut.
    /// Jika tidak ada baris yang dipilih, maka akan menampilkan item filter, muat ulang, dan salin semua.
    /// Jika ada baris yang dipilih, maka akan menampilkan item salin dengan jumlah baris yang dipilih.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateToolbarMenu(_ menu: NSMenu) {
        guard let filterTahunToolbar = menu.items.first(where: { $0.title == "Tahun" }), let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) else { return }

        if outlineView.numberOfSelectedRows < 1 {
            salinItem.isHidden = true
        } else {
            salinItem.isHidden = false
            salinItem.title = "Salin \(outlineView.numberOfSelectedRows) data..."
        }
        if let tahun = filterTahunToolbar.submenu {
            for terpilih in tahun.items {
                if terpilih.title == String(tahunTerpilih) {
                    terpilih.state = .on
                } else {
                    terpilih.state = .off
                }
            }
        }
    }

    /// Fungsi untuk memperbarui item menu "Salin" pada menu utama.
    /// Fungsi ini akan memeriksa apakah ada baris yang dipilih di outline view,
    /// dan akan mengaktifkan atau menonaktifkan item menu "Salin" sesuai dengan kondisi tersebut.
    /// Jika ada baris yang dipilih, item menu "Salin" akan diaktifkan dan diarahkan ke fungsi `salinMenu`.
    /// Jika tidak ada baris yang dipilih, item menu "Salin" akan dinonaktifkan.
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya berupa menu item.
    /// - Note: Pastikan untuk memanggil fungsi ini ketika ada perubahan pada pemilihan baris di outline view.
    @objc func updateMenuItem(_: Any?) {
        if let copyMenuItem = ReusableFunc.salinMenuItem {
            let adaBarisDipilih = outlineView.selectedRowIndexes.count > 0
            copyMenuItem.isEnabled = adaBarisDipilih
            if adaBarisDipilih {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(salinMenu(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
            }
        }
    }
}

extension Struktur: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.stringValue.allSatisfy(\.isNumber)
        else { return }

        let inputValue = textField.stringValue

        if textField === thnAjrn1TextField,
           let tahunAjaranInt = Int(inputValue)
        {
            UserDefaults.standard.strukturTahunAjaran1 = inputValue

            thnAjrn2TextField.stringValue = String(tahunAjaranInt + 1)
            UserDefaults.standard.strukturTahunAjaran2 = String(tahunAjaranInt + 1)
        }

        if textField === thnAjrn2TextField {
            UserDefaults.standard.strukturTahunAjaran2 = inputValue
        }

        let newTahunAjaran = thnAjrn1TextField.stringValue + "/" + thnAjrn2TextField.stringValue

        if !thnAjrn1TextField.stringValue.isEmpty,
           !thnAjrn2TextField.stringValue.isEmpty,
           tahunTerpilih != newTahunAjaran
        {
            tahunTerpilih = newTahunAjaran
            muatUlang(obj)
            view.window?.makeFirstResponder(outlineView)
        }
    }
}
