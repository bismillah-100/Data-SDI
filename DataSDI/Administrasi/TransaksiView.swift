//
//  TransaksiView.swift
//  Administrasi
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa

/// Tampilan utama untuk pengelolaan data administrasi.
class TransaksiView: NSViewController {
    /// Jenis transaksi yang difilter.
    @IBOutlet weak var jenisText: NSTextField!
    /// Jumlah pemasukan dan pengeluaran pada item transaksi yang dipilih.
    @IBOutlet weak var jumlahTextField: NSTextField!
    /// Outlet `NSScrollView` yang memuat `NSCollectionView`.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk popup pilihan urutan.
    @IBOutlet weak var urutkanPopUp: NSPopUpButton!
    /// Outlet untuk popup pilihan filter  bulan.
    @IBOutlet weak var bulanPopUp: NSPopUpButton!
    /// Outlet untuk popup pilihan filter tahun.
    @IBOutlet weak var tahunPopUp: NSPopUpButton!
    /// Outlet `NSCollectionView`.
    @IBOutlet weak var collectionView: NSCollectionView!
    /// Outlet garis di atas `NSVisualEffectView`.
    @IBOutlet weak var hlinetop: NSBox!
    /// Outlet garis di bawah `NSVisualEffectView`.
    @IBOutlet weak var hlinebottom: NSBox!
    /// Outlet FlowLayout dari `NSCollectionView`.
    @IBOutlet weak var flowLayout: CustomFlowLayout!
    /// Outlet `NSVisualEffectView` yang menampung:
    ///
    /// - ``jumlahTextField``
    /// - ``urutkanPopUp``
    /// - ``bulanPopUp``
    /// - ``tahunPopUp``
    /// - ``cariAcara``
    /// - ``cariKategori``
    /// - ``cariKeperluan``
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    /// Outlet lebar constraint yang digunakan ``jumlahTextField``.
    ///
    /// Berguna untuk menganimasikan ``jumlahTextField`` saat lebarnya berubah.
    @IBOutlet weak var jumlahTextFieldWidthConstraint: NSLayoutConstraint!
    /// Outlet constraint bagian atas ``visualEffect``.
    ///
    /// Berguna ketika menyembunyikan ``visualEffect`` melalui ``hideTools``.
    @IBOutlet weak var visualHeaderTopConstraint: NSLayoutConstraint!
    /// Outlet constraint bagian bawah ``hlinebottom``.
    ///
    /// Berguna ketika menyembunyikan ``visualEffect`` melalui ``hideTools``.
    @IBOutlet weak var hlineBottomConstraint: NSLayoutConstraint!
    /// Outlet NSSearchField untuk mencari keperluan.
    @IBOutlet weak var cariKeperluan: NSSearchField!
    /// Outlet NSSearchField untuk mencari acara.
    @IBOutlet weak var cariAcara: NSSearchField!
    /// Outlet NSSearchField untuk mencari kategori.
    @IBOutlet weak var cariKategori: NSSearchField!
    /// Tombol di sebelah kiri ``jumlahTextField`` untuk menyembunyikan ``visualEffect``. Lihat: ``hideTools(_:)`` untuk implementasi logika yang menyembunyikan ``visualEffect``.
    @IBOutlet weak var hideTools: NSButton!
    /// Outlet constraint bagian atas ``hideTools``.
    ///
    /// Berguna ketika menyembunyikan ``visualEffect`` melalui ``hideTools``.
    @IBOutlet weak var topConstraintHideTools: NSLayoutConstraint!

    // MARK: - MENU

    /// Outlet konteks menu klik kanan jika item di ``collectionView`` diklik kanan.
    @IBOutlet var itemMenu: NSMenu!
    /// Outlet konteks menu untuk mode non-grup klik kanan di ``collectionView`` jika yang diklik kanan adalah bagian yang bukan merupakan item.
    @IBOutlet var unGroupMenu: NSMenu!
    /// Outlet konteks menu untuk mode grup klik kanan di ``collectionView`` jika yang diklik kanan adalah bagian yang bukan merupakan item.
    @IBOutlet var groupMenu: NSMenu!

    /// Outlet menu `Kelompokkan Menurut >` yang memuat menu item `Acara, Kategori, dan Keperluan`. Menu ini ditampilkan dalam mode non-grup.
    @IBOutlet weak var kelompokkanMenurut: NSMenu!
    /// Outlet menu `Urutkan Menurut >`. Menu ini ditampilkan di dalam mode grup.
    @IBOutlet weak var urutkanMenu: NSMenu!
    /// Outlet menu item untuk memberi tanda pada item di ``collectionView`` yang dipilih.
    @IBOutlet weak var markItemMenu: NSMenuItem!

    /// Menu item untuk filter tahun mode ``isGrouped``.
    var filterTahun: NSMenuItem = .init(title: "Filter Tahun...", action: #selector(filterTahunSheet(_:)), keyEquivalent: "")

    /// Array untuk menyimpan data yang didapatkan dari CoreData. Ini adalah sumber data  yang ditampilkan oleh ``collectionView``.
    var data: [Entity] = []

    /// Menyimpan nama-nama bulan yang tersedia di ``data`` untuk digunakan sebagai menu item di ``bulanPopUp``
    var bulanList: [String] = []
    /// Menyimpan tahun-tahun yang tersedia di ``data`` untuk digunakan sebagai menu item di ``tahunPopUp``
    var tahunList: [String] = []
    /// Tahun default untuk ``tahunPopUp``
    var tahun: Int {
        get {
            UserDefaults.standard.integer(forKey: "filterTahunAdministrasi")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "filterTahunAdministrasi")
            updateTitleWindow()
        }
    }

    /// Bulan default untukl ``bulanPopUp``
    var bulan: Int = 1
    /// Menyimpan tipe jenis transaksi berupa Int16 yang digunakan untuk memfilter seluruh data yang ditampilkan. Jika nilai ini berupa `nil`, maka seluruh data ditampilkan tanpa filter. Nilai ini berubah dari ``DataSDI/ContainerSplitView/didSelectSidebarItem(index:)``
    ///
    /// Menggunakan enum ``JenisTransaksi`` bisa mempermudah pengelolaan ini.
    ///
    /// Jenis ini bisa berubah ke:
    /// - Int16(2) = Pemasukan
    /// - Int16(1) = Pengeluaran
    /// - Int16(0) Lainnya
    var jenis: Int16?
    /// String teks dari ``filterAcara`` yang digunakan untuk mencari acara pada seluruh data yang sedang ditampilkan. Jika nilai ini berupa `nil`, maka seluruh data ditampilkan tanpa filter.
    var filterAcara: String?
    /// String teks dari ``filterKeperluan`` yang digunakan untuk mencari keperluan pada seluruh data yang sedang ditampilkan. Jika nilai ini berupa `nil`, maka seluruh data ditampilkan tanpa filter.
    var filterKeperluan: String?

    /// String teks dari ``filteredKategori`` yang digunakan untuk mencari kategori pada seluruh data yang sedang ditampilkan. Jika nilai ini berupa `nil`, maka seluruh data ditampilkan tanpa filter.
    var filteredKategori: String?

    /// String teks dari toolbar yang diakses melalu ``DataSDI/WindowController/search`` yang digunakan untuk mencari data yang sedang ditampilkan. Jika nilai ini berupa `nil`, maka seluruh data ditampilkan tanpa filter.
    var filterSearchToolbar: String?

    /// Urutan default untuk ``urutkanMenu`` dan ``urutkanPopUp``.
    lazy var currentSortOption: String = "terbaru"

    /// Thread khusus untuk pemrosesan beberapa data secara konkuren.
    let dataProcessingQueue: DispatchQueue = .init(label: "com.sdi.DataProcessing", qos: .userInitiated)

    /// Array untuk menampilkan data di ``collectionView`` dalam mode grup.
    ///
    /// Beberapa func akan langsung dijalankan secara berurutan jika array ini berubah dan ada data di dalamnya:
    /// - ``groupDataByType(key:)``
    /// - ``sortGroupedData(_:)``
    var groupData: [Entity] = [] {
        didSet {
            expandedSections.removeAll()
            if !groupData.isEmpty {
                groupDataByType(key: selectedGroup)
                sortGroupedData(self)
            }
        }
    }

    /// `NSUndoManager` khusus class ``DataSDI/TransaksiView``.
    let myUndoManager = DataManager.shared.myUndoManager

    /// Menyimpan pengelompokkan grup yang dipilih.
    var selectedGroup: String = "keperluan"

    /// Array kunci header section yang diurutkan (atau akan diurutkan)
    /// untuk menentukan urutan section.
    var sectionKeys: [String] = []
    /// Kamus array yang menyimpan `section: [data]` yang digunakan ``collectionView`` untuk merepresentasikan data dengan section header melalui delegate nya ``collectionView(_:viewForSupplementaryElementOfKind:at:)``
    var groupedData: [String: [Entity]] = [:]

    /// Memriksa status apakah menu item `Gunakan Grup` on(dicentang) atau off.
    var isGroupMenuItemOn: Bool = false

    /// Lihat: ``DataSDI/DataManager/managedObjectContext``
    var context: NSManagedObjectContext { DataManager.shared.managedObjectContext }

    /// Properti `Bool` yang menunjukkan apakah data ``collectionView`` sedang ditampilkan dalam mode kelompok.
    ///
    /// Digunakan untuk berbagai keperluan seperti bagaimana cara menampilkan data dan bagaimana data dikelola.
    var isGrouped: Bool = false

    /// Menyimpan referensi apakah data sudah dimuat dan ditampilkan oleh ``collectionView``.
    var isDataLoaded: Bool = false

    /// Menu untuk Toolbar ``DataSDI/WindowController/actionToolbar`` dalam mode grup.
    var toolbarGroupMenu: NSMenu = .init()
    /// Menu untuk Toolbar ``DataSDI/WindowController/actionToolbar`` dalam mode non-grup.
    var toolbarMenu: NSMenu = .init()

    /// Menyimpan lebar ``collectionView``.
    ///
    /// Ini digunakan saat lebar ``collectionView`` berubah untuk layout ``flowLayout`` yang spesifik.
    var lebarSaatIni: CGFloat = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        visualEffect.blendingMode = .withinWindow /// blending mode within window untuk menampilkan elemen di belakangnya di window yang sama.
        visualEffect.material = .headerView
        collectionView.register(NSNib(nibNamed: NSNib.Name("HeaderView"), bundle: nil), forItemWithIdentifier: NSUserInterfaceItemIdentifier("HeaderView"))
        collectionView.register(NSNib(nibNamed: NSNib.Name("CollectionViewItem"), bundle: nil), forItemWithIdentifier: NSUserInterfaceItemIdentifier("CollectionViewItem"))
        currentSortOption = UserDefaults.standard.string(forKey: "urutanTransaksi") ?? "terbaru"
        if UserDefaults.standard.bool(forKey: "grupTransaksi") {
            visualEffect.isHidden = true
        }
        jumlahTextField.alphaValue = 0.6
        jenisText.alphaValue = 0.6
        tahunPopUp.menu?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        #if DEBUG
            print("viewDidAppear TransaksiView")
        #endif
        if !isDataLoaded {
            ReusableFunc.showProgressWindow(view, isDataLoaded: isDataLoaded)
            toolbarGroupMenu = buatGroupMenu()
            toolbarGroupMenu.delegate = self
            toolbarMenu = toolbarGroupMenu
            cariKeperluan.layoutSubtreeIfNeeded()
            cariAcara.layoutSubtreeIfNeeded()
            cariKategori.layoutSubtreeIfNeeded()
            collectionView.dataSource = self
            collectionView.delegate = self
            if UserDefaults.standard.bool(forKey: "grupTransaksi"), jenis == nil {
                tampilanGroup()
                scrollView.scrollerInsets.top = 0
                AppDelegate.shared.groupMenuItem.state = .on
            } else {
                // data = DataManager.shared.fetchData()
                // Memilih tahun yang sesuai (opsional)
                urutkanPopUp.selectItem(withTitle: currentSortOption.capitalized.trimmingCharacters(in: .whitespacesAndNewlines))
                urutkanPopUp.selectedItem?.state = .on
                updateMenu()
                urutkanPopUp.target = self
                urutkanPopUp.action = #selector(sortPopUpValueChanged(_:))
                bulanPopUp.target = self
                bulanPopUp.action = #selector(bulanPopUpValueChanged(_:))
                tahunPopUp.target = self
                tahunPopUp.action = #selector(tahunPopUpValueChanged(_:))
                scrollView.scrollerInsets.top = 86
                AppDelegate.shared.groupMenuItem.state = .off
            }
            collectionView.allowsMultipleSelection = true
            urutkanPopUp.showsBorderOnlyWhileMouseInside = false
            bulanPopUp.showsBorderOnlyWhileMouseInside = false
            tahunPopUp.showsBorderOnlyWhileMouseInside = false
            urutkanPopUp.cell?.isHighlighted = false
            bulanPopUp.cell?.isHighlighted = false
            tahunPopUp.cell?.isHighlighted = false
            let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTapOutside))
            tapGesture.delegate = self // Set the delegate to filter the gesture
            collectionView.addGestureRecognizer(tapGesture)
            let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
            rightClickGesture.buttonMask = 0x2 // Mask untuk klik kanan
            collectionView.addGestureRecognizer(rightClickGesture)
            cariAcara.delegate = self
            cariKeperluan.delegate = self
            cariKategori.delegate = self
            // NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: .windowControllerClose, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(dataDitambah(_:)), name: DataManager.dataDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadEditedItems(_:)), name: DataManager.dataDieditNotif, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePopUpDismissed(_:)), name: .popUpDismissedTV, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(receivedNullID), name: .didAssignUUID, object: nil)
            Task.detached { [weak self] in
                guard let self else { return }
                await loadTahunList()
                // Muat data di core data
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if tahun != 0 {
                        tahunPopUp.selectItem(withTitle: String(tahun))
                    } else {
                        tahunPopUp.selectItem(at: 0)
                    }
                    tahunPopUpValueChanged(tahunPopUp)
                    bulanPopUp.selectItem(at: 0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, !self.isDataLoaded else { return }

                checkForDuplicateID(NSMenuItem())
                isDataLoaded = true
                if let window = view.window {
                    ReusableFunc.closeProgressWindow(window)
                }
            }
            ReusableFunc.updateSuggestionsEntity()
            context.perform {
                DataManager.shared.checkAndAssignUUIDIfNeeded()
            }
        }
        setupToolbar()
        DispatchQueue.main.async { [weak self] in
            ReusableFunc.resetMenuItems()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                updateMenuItem(self)
                view.window?.makeFirstResponder(collectionView)
                updateUndoRedo()
                if isGrouped { createLineAtTopSection() }
            }
        }
        lebarSaatIni = collectionView.bounds.width

        AppDelegate.shared.groupMenuItem.state = UserDefaults.standard.bool(forKey: "grupTransaksi") ? .on : .off
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if collectionView.bounds.width != lebarSaatIni {
            if isGrouped {
                flowLayout.invalidateLayout()
            }
            lebarSaatIni = collectionView.bounds.width
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        searchWorkItem?.cancel()
        searchWorkItem = nil
        keperluanSearchWorkItem?.cancel()
        keperluanSearchWorkItem = nil
        acaraSearchWorkItem?.cancel()
        kategoriSearchWorkItem = nil
        if let toolbar = view.window?.toolbar {
            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
               let add = addToolbarItem.view as? NSButton
            {
                add.toolTip = "Catat Siswa Baru"
            }
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem,
               !searchFieldToolbarItem.searchField.stringValue.isEmpty
            {
                searchFieldToolbarItem.searchField.stringValue = ""
                searchFieldToolbarItem.endSearchInteraction()
            }
        }
        ReusableFunc.resetMenuItems()
    }

    /// Menangani notifikasi saat ditemukan data tanpa UUID (identifikasi null).
    ///
    /// Menampilkan alert kepada pengguna, lalu memicu pengecekan dan penugasan UUID baru.
    /// Setelah sinkronisasi selesai, memuat ulang data sesuai mode tampilan yang aktif (group atau non-group).
    @objc func receivedNullID() {
        DispatchQueue.main.async { [unowned self] in
            let alert = NSAlert()
            alert.messageText = "Error Pengidentifikasi Data"
            alert.informativeText = "Klik OK untuk memuat ulang data untuk sinkronisasi identifikasi data dengan identifikasi yang baru."
            alert.icon = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            alert.addButton(withTitle: "OK")
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                context.performAndWait {
                    DataManager.shared.checkAndAssignUUIDIfNeeded(postNotification: false)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
                    if UserDefaults.standard.bool(forKey: "grupTransaksi") {
                        tampilanGroup()
                    } else {
                        loadData()
                    }
                }
            }
        }
    }

    /// Menangani notifikasi saat pop-up ditutup.
    ///
    /// Memperbarui item menu terkait dan undo/redo di Menu Bar .
    @objc func handlePopUpDismissed(_ notification: Notification) {
        updateMenuItem(notification)
        updateUndoRedo()
    }

    /// Mengecek adanya duplikat UUID dalam data, baik dalam mode grup maupun tidak.
    ///
    /// Menampilkan peringatan jika ditemukan UUID yang sama dan memilih item duplikat di `collectionView`.
    /// Berguna untuk mencegah konflik data akibat identifikasi yang sama.
    ///
    /// - Parameter sender: Objek `NSMenuItem` yang memicu pengecekan, dapat membawa flag `firstLaunch`.
    @IBAction func checkForDuplicateID(_ sender: NSMenuItem) {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [self] timer in
            var firstLaunch = false
            if let object = sender.representedObject as? Bool {
                firstLaunch = object
            } else {
                firstLaunch = true
            }

            // Menggunakan Set untuk menemukan duplikat
            var uniqueIDs = Set<UUID>()
            var duplicateIDs = [UUID]()
            var duplicateIndexPaths = Set<IndexPath>()

            if UserDefaults.standard.bool(forKey: "grupTransaksi") {
                // Mode dengan section (isGrouped)
                let sectionKeys = Array(groupedData.keys.sorted())
                for (sectionIndex, sectionKey) in sectionKeys.enumerated() {
                    if let items = groupedData[sectionKey] {
                        for (itemIndex, entity) in items.enumerated() {
                            guard let entityID = entity.id else { continue }

                            // Cek duplikasi ID
                            if !uniqueIDs.insert(entityID).inserted {
                                // ID duplikat, simpan ke daftar duplikat
                                duplicateIDs.append(entityID)
                                // Tambahkan IndexPath untuk item duplikat
                                duplicateIndexPaths.insert(IndexPath(item: itemIndex, section: sectionIndex))
                            }
                        }
                    }
                }
            } else {
                // Mode tanpa section
                for (index, item) in data.enumerated() {
                    guard let itemID = item.id else { continue }

                    // Cek duplikasi ID
                    if !uniqueIDs.insert(itemID).inserted {
                        // ID duplikat, simpan ke daftar duplikat
                        duplicateIDs.append(itemID)
                        // Tambahkan IndexPath untuk item duplikat
                        duplicateIndexPaths.insert(IndexPath(item: index, section: 0))
                    }
                }
            }

            // Tampilkan alert jika ada duplikat
            let alert = NSAlert()
            if !duplicateIDs.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
                    alert.messageText = "Ditemukan identifkasi transaksi yang sama!"
                    alert.informativeText = "Hal ini dapat menyebabkan perubahan yang tidak terduga saat mengelola data. Mohon hapus dan tambahkan ulang data tersebut untuk memperbarui identifikasi. Data dengan identifikasi yang sama akan dipilih setelah Anda mengklik tombol OK."
                    alert.icon = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
                    alert.addButton(withTitle: "OK")
                    collectionView.deselectAll(sender)
                    let response = alert.runModal()
                    timer.invalidate()
                    if response == .alertFirstButtonReturn {
                        DispatchQueue.main.async { [unowned self] in
                            collectionView.selectItems(at: duplicateIndexPaths, scrollPosition: [.centeredVertically, .centeredHorizontally])
                            isDataLoaded = true
                        }
                    }
                }
            } else {
                guard !firstLaunch else {
                    timer.invalidate()
                    return
                }
                alert.messageText = "Data Aman"
                alert.informativeText = "Tidak ditemukan pengidentifkasi yang sama di dalam data."
                alert.icon = NSImage(named: NSImage.menuOnStateTemplateName)
                alert.addButton(withTitle: "OK")
                alert.runModal()
                timer.invalidate()
            }
        }
    }

    /// Memperlebar ukuran item ``DataSDI/CollectionViewItem`` yang ditampilkan oleh ``collectionView``
    @IBAction func increaseSize(_: Any) {
        // Loop melalui semua item di collectionView
        flowLayout.updateSize(scaleFactor: 1.1)

        for item in collectionView.visibleItems() {
            guard let customItem = item as? CollectionViewItem else { continue }

            // Mengambil ukuran font saat ini dari textField dan elemen teks lainnya
            if let currentFontSize = customItem.keperluan?.font?.pointSize {
                // Menambahkan 2 poin ke ukuran font saat ini
                let newSize = min(currentFontSize + 2.0, 15.0) // Menjamin ukuran font tidak kurang dari 13 poin

                // Mengatur ukuran font pada textField dan elemen teks lainnya
                customItem.jumlahHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.untukHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.acaraHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.kategoriHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.jumlah?.font = NSFont.systemFont(ofSize: newSize)
                customItem.kategori?.font = NSFont.systemFont(ofSize: newSize)
                customItem.acara?.font = NSFont.systemFont(ofSize: newSize)
                customItem.keperluan?.font = NSFont.systemFont(ofSize: newSize)
            }
        }
    }

    /// Memperkecil lebar item ``DataSDI/CollectionViewItem`` yang ditampilkan oleh ``collectionView``
    @IBAction func decreaseSize(_: Any) {
        // Loop melalui semua item di collectionView
        for item in collectionView.visibleItems() {
            guard let customItem = item as? CollectionViewItem else { continue }

            // Mengambil ukuran font saat ini
            if let currentFontSize = customItem.keperluan?.font?.pointSize {
                // Mengurangkan 2 poin dari ukuran font saat ini
                let newSize = max(currentFontSize - 2.0, 13.0) // Menjamin ukuran font tidak kurang dari 13 poin

                // Mengatur ukuran font pada textField atau elemen lainnya
                customItem.jumlahHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.untukHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.acaraHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.kategoriHeading?.font = NSFont.systemFont(ofSize: newSize)
                customItem.jumlah?.font = NSFont.systemFont(ofSize: newSize)
                customItem.kategori?.font = NSFont.systemFont(ofSize: newSize)
                customItem.acara?.font = NSFont.systemFont(ofSize: newSize)
                customItem.keperluan?.font = NSFont.systemFont(ofSize: newSize)
            }
        }
        flowLayout.updateSize(scaleFactor: 0.9)
    }

    /// Action Toolbar ``DataSDI/WindowController/segmentedControl``  untuk memperlebar atau memperkecil lebar item ``collectionView``.
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

    /// Menyalin data dari item yang dipilih di `NSCollectionView` ke clipboard dalam format teks.
    ///
    /// Data yang disalin meliputi jenis, jumlah, keperluan, acara, kategori, dan tanggal.
    /// Jika tidak ada item yang dipilih, fungsi tidak melakukan apa-apa.
    ///
    /// - Parameter collectionView: Objek `NSCollectionView` tempat item dipilih.
    func copySelectedItemsToClipboard(collectionView: NSCollectionView) {
        // Dapatkan semua item yang dipilih
        let selectedIndexPaths = collectionView.selectionIndexPaths
        guard !selectedIndexPaths.isEmpty else {
            #if DEBUG
                print("Tidak ada item yang dipilih.")
            #endif
            return
        }

        // Array untuk menampung konten yang akan disalin
        var clipboardContents: [String] = []

        for indexPath in selectedIndexPaths.sorted() {
            // Dapatkan item berdasarkan indexPath
            guard let item = collectionView.item(at: indexPath) as? CollectionViewItem else {
                continue // Jika item tidak valid, lanjutkan ke item berikutnya
            }

            // Ambil teks dari elemen UI pada item
            let jenis = item.mytextField?.stringValue ?? ""
            let jumlah = ReusableFunc.formatNumber(item.jumlah?.doubleValue ?? 0)
            let kategori = item.kategori?.stringValue ?? ""
            let acara = item.acara?.stringValue ?? ""
            let keperluan = item.keperluan?.stringValue ?? ""
            let tanggal = item.tanggal?.stringValue ?? ""

            // Format data item
            let itemContent = """
            Jenis: \(jenis)
            Jumlah: \(jumlah)
            Keperluan: \(keperluan)
            Acara: \(acara)
            Kategori: \(kategori)
            Tanggal: \(tanggal)
            """

            // Tambahkan ke array konten
            clipboardContents.append(itemContent)
        }

        // Gabungkan semua item menjadi satu string
        let finalClipboardContent = clipboardContents.joined(separator: "\n\n")

        // Salin ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(finalClipboardContent, forType: .string)
    }

    /// Aksi menu item di Menu Bar untuk menyalin item yang dipilih dari `collectionView` ke clipboard.
    ///
    /// Memanggil ``copySelectedItemsToClipboard(collectionView:)`` jika ``collectionView`` tersedia.
    ///
    /// - Parameter sender: Objek pengirim aksi, bisa merupakan menu item atau yang lainnya.
    @IBAction func copyAction(_: Any) {
        guard let collectionView else { return }
        copySelectedItemsToClipboard(collectionView: collectionView)
    }

    /// Menempelkan data transaksi dari clipboard ke database.
    ///
    /// Format data yang ditempel harus berupa **beberapa baris**,
    /// dengan setiap baris mewakili satu transaksi.
    /// Setiap baris harus dipisahkan dengan **karakter TAB (`\t`)**,
    /// dan berisi tepat 6 kolom dengan urutan:
    ///  1. Jenis transaksi (contoh: "Pemasukan", "Pengeluaran", atau "Lainnya")
    ///  2. Jumlah (angka, contoh: "10000")
    ///  3. Keperluan (String)
    ///  4. Acara (String)
    ///  5. Kategori (String)
    ///  6. Tanggal dalam format `dd-MM-yyyy` (contoh: "01-01-2020")
    ///
    /// Contoh baris yang valid:
    /// ```
    /// Pemasukan\t10000\tBuku\tRapat Semester I\tTahun Ajaran 2021\t01-01-2024
    /// Pemasukan;20000;Paste;Fitur Request;Administrasi;20-03-2022
    /// ```
    ///
    /// - Important: Jika jumlah kolom dalam baris kurang dari 6, baris akan dilewati.
    /// - Important: Jika format tanggal tidak valid, baris juga akan dilewati.
    /// - Parameter sender: Objek pemicu aksi paste (biasanya NSMenuItem atau tombol).
    @objc func paste(_: Any) {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        let pastedDataRows = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        let separators = CharacterSet(charactersIn: "\t;")
        // Inisialisasi array untuk menampung pesan kesalahan
        for row in pastedDataRows {
            let columns = row.components(separatedBy: separators)
            guard columns.count >= 6 else {
                #if DEBUG
                    print("Baris tidak valid: \(row)")
                #endif
                continue
            }

            // Ambil data (disesuaikan index sesuai format)
            let jenis = JenisTransaksi.from(columns[0])
            let jumlah = Double(columns[1]) ?? 0
            let keperluan = columns[2]
            let acara = columns[3]
            let kategori = columns[4]
            let tanggalString = columns[5]

            // Parse tanggal
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX") // Gunakan ini

            let cleanedTanggalString = tanggalString.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let tanggal = formatter.date(from: cleanedTanggalString) else {
                #if DEBUG
                    print("Format tanggal tidak valid: \(tanggalString)")
                #endif
                continue
            }

            let components = Calendar.current.dateComponents([.month, .year], from: tanggal)
            let bulan = Int16(components.month ?? 1)
            let tahun = Int16(components.year ?? 2000)

            let id = DataManager.shared.addData(
                jenis: jenis.rawValue,
                dari: "",
                jumlah: jumlah,
                kategori: kategori,
                acara: acara,
                keperluan: keperluan,
                tanggal: tanggal,
                bulan: bulan,
                tahun: tahun,
                tanda: false
            )
            guard let id else { continue }
            NotificationCenter.default.post(name: DataManager.dataDidChangeNotification, object: nil, userInfo: ["newItem": id])
        }
    }

    /// Menghitung pemasukan dan pengeluaran pada item yang dipilih di ``collectionView``.
    ///
    /// FIXME: ada kode untuk animasi, tetapi tidak berfungsi.
    func hitungTotalTerpilih(_ selectedIndexes: Set<IndexPath>) {
        dataProcessingQueue.async {
            var totalPemasukan = 0.0
            var totalPengeluaran = 0.0

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0

            for indexPath in selectedIndexes {
                guard indexPath.item < self.data.count else { return }
                let entity = self.data[indexPath.item]
                if entity.jenis == JenisTransaksi.pemasukan.rawValue {
                    totalPemasukan += entity.jumlah
                } else if entity.jenis == JenisTransaksi.pengeluaran.rawValue {
                    totalPengeluaran += entity.jumlah
                }
            }

            var jumlahText = ""

            if selectedIndexes.count > 0 {
                let totalPemasukanFormatted = "Jumlah Pemasukan: " + (formatter.string(from: NSNumber(value: totalPemasukan)) ?? "")
                let totalPengeluaranFormatted = "Jumlah Pengeluaran: " + (formatter.string(from: NSNumber(value: totalPengeluaran)) ?? "")
                jumlahText = "\(totalPemasukanFormatted) - \(totalPengeluaranFormatted)"
            } else {
                jumlahText = "Pilih beberapa item untuk kalkulasi"
            }

            // Setelah nilai jumlahTextField diperbarui, hitung lebar teks dan animasikan perubahan lebar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
                // Hitung lebar teks baru
                let textSize = (jumlahText as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

                // Update string value
                jumlahTextField.stringValue = jumlahText
                // Update constraint untuk lebar textField
                if let widthConstraint = jumlahTextFieldWidthConstraint {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.2 // Durasi animasi dalam detik
                        context.timingFunction = CAMediaTimingFunction(name: .linear) // Mengatur timing function
                        widthConstraint.constant = textSize.width // Mengubah lebar constraint
                        self.jumlahTextField.alphaValue = 0.8
                    } completionHandler: {
                        // Kode setelah animasi selesai (opsional)
                        self.jumlahTextField.isSelectable = true
                    }
                }
            }
        }
    }

    /// Memuat daftar tahun unik dari data dan memperbarui menu popup `tahunPopUp` jika terjadi perubahan.
    ///
    /// - Mengambil data jika belum tersedia.
    /// - Mengekstrak tahun dari properti `tanggal` pada entitas yang memiliki nilai `bulan` valid.
    /// - Menggunakan `DispatchGroup` untuk sinkronisasi asynchronous antar thread Core Data dan UI.
    /// - Memastikan item "Tahun" ada di popup jika belum ada, lalu menambahkan tahun-tahun unik secara terurut menurun ke `tahunPopUp`.
    func loadTahunList() async {
        var uniqueYears = Set<String>()
        if data.isEmpty {
            await context.perform {
                let fetchedYears = DataManager.shared.fetchUniqueYears()
                uniqueYears = Set(fetchedYears.map { String($0) })
            }
        } else {
            await context.perform { [weak self] in
                guard let self else { return }
                uniqueYears = Set(data.compactMap { entity in
                    if let tanggalDate = entity.tanggal as Date?, entity.bulan != 0 {
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.month, .year], from: tanggalDate)
                        if let year = components.year {
                            return String(year)
                        }
                    }
                    return nil
                })
            }
        }
        await MainActor.run {
            if tahunList != Array(uniqueYears) {
                if !(tahunPopUp.menu?.items.contains(where: { $0.title == "Tahun" }) ?? false) {
                    tahunPopUp.addItem(withTitle: "Tahun")
                }

                tahunList = Array(uniqueYears).sorted(by: { Int($0) ?? 0 > Int($1) ?? 0 })

                // Tambahkan tahun ke popup sesuai urutan
                for i in tahunList {
                    if !(tahunPopUp.menu?.items.contains(where: { $0.title == i }) ?? false) {
                        // Temukan posisi untuk memasukkan item baru
                        let insertIndex = tahunPopUp.menu?.items.firstIndex(where: {
                            guard let existingYear = Int($0.title) else { return false }
                            return existingYear < Int(i) ?? 0
                        }) ?? tahunPopUp.menu?.items.count

                        // Insert item di posisi yang sesuai
                        tahunPopUp.insertItem(withTitle: i, at: insertIndex ?? 0)
                    }
                }
            }
        }
    }

    /// Memuat daftar bulan unik berdasarkan data dan tahun yang dipilih, lalu mengisi ulang `bulanPopUp`.
    ///
    /// - Jika "Semua Tahun" dipilih (`tahun == 0`), semua bulan dari Januari hingga Desember akan ditampilkan.
    /// - Jika tahun tertentu dipilih, hanya bulan dari data dengan tahun yang sesuai yang diambil.
    /// - Hasil akhir akan diurutkan sesuai urutan nama bulan dalam bahasa Indonesia, dengan "Semua bln." ditambahkan di awal.
    func loadBulanList() {
        // Mengambil bulan unik dari data Core Data berdasarkan tahun terpilih
        let selectedYear = tahun
        let group = DispatchGroup()
        group.enter()
        context.perform { [weak self] in
            guard let self else { group.leave(); return }
            var uniqueMonths: Set<String> = Set()
            if tahun == 0 { // Jika "Semua Tahun" dipilih
                for i in 1 ... 12 {
                    let monthName = convertToMonthString(i)
                    uniqueMonths.insert(monthName)
                }
            } else {
                uniqueMonths = Set(data.compactMap { entity in
                    guard let tanggalDate = entity.tanggal as Date? else {
                        return nil
                    }
                    let bulanInt64 = entity.bulan

                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.month, .year], from: tanggalDate)

                    if selectedYear == 0 || components.year == selectedYear { // Jika "Semua Tahun" dipilih atau tahun cocok
                        let month = Int(bulanInt64)

                        // Pastikan bahwa month ada dalam rentang 1-12
                        if 1 ... 12 ~= month {
                            let monthName = self.convertToMonthString(month)
                            return monthName
                        }
                    }
                    return nil
                })
            }

            // Urutkan bulan-bulan secara alfabetis
            var sortedMonths = uniqueMonths.sorted { month1, month2 in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "id_ID_POSIX")
                return formatter.monthSymbols.firstIndex(of: month1) ?? 0 < formatter.monthSymbols.firstIndex(of: month2) ?? 0
            }

            sortedMonths.insert("Semua bln.", at: 0) // Masukkan "Semua bln." di awal

            // Mengisi ulang NSPopUpButton bulan dengan bulan-bulan yang sudah diurutkan
            bulanList = sortedMonths
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            bulanPopUp.removeAllItems()
            bulanPopUp.addItems(withTitles: bulanList)
        }
    }

    /// Mengonversi angka bulan (1–12) menjadi nama bulan dalam format lokal default (biasanya bahasa Inggris).
    ///
    /// - Parameter month: Angka bulan (1 untuk Januari, 12 untuk Desember).
    /// - Returns: Nama bulan yang sesuai, misalnya "January" untuk `1`.
    /// - Catatan: Tidak melakukan validasi batas; jika `month` < 1 atau > 12, dapat menyebabkan crash karena out of bounds.
    ///
    /// Untuk hasil dalam bahasa Indonesia, setel lokal:
    /// ```swift
    /// let formatter = DateFormatter()
    /// formatter.locale = Locale(identifier: "id_ID")
    /// ```
    func convertToMonthString(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }

    // MARK: - FILTER

    /// `DispatchWorkItem` untuk pencarian umum melalui toolbar.
    ///
    /// Digunakan untuk melakukan debounce saat pengguna mengetik pada kolom pencarian utama.
    /// Ini mencegah pencarian dilakukan terlalu sering selama pengetikan masih berlangsung.
    var searchWorkItem: DispatchWorkItem?

    /// `DispatchWorkItem` untuk pencarian berdasarkan keperluan.
    ///
    /// Digunakan untuk melakukan debounce saat pengguna mengetik pada kolom pencarian keperluan ``cariKeperluan``.
    /// Membantu mengoptimalkan performa saat pengguna melakukan pencarian.
    var keperluanSearchWorkItem: DispatchWorkItem?

    /// `DispatchWorkItem` untuk pencarian berdasarkan acara.
    ///
    /// Digunakan untuk melakukan debounce saat pengguna mengetik pada kolom pencarian acara ``cariAcara``.
    /// Pencarian akan dilakukan setelah jeda waktu tertentu setelah pengguna berhenti mengetik.
    var acaraSearchWorkItem: DispatchWorkItem?

    /// `DispatchWorkItem` untuk pencarian berdasarkan kategori.
    ///
    /// Digunakan untuk melakukan debounce saat pengguna mengetik pada kolom pencarian kategori ``cariKategori``.
    /// Ini bertujuan untuk menghindari eksekusi pencarian berulang selama proses input.
    var kategoriSearchWorkItem: DispatchWorkItem?

    /// Filter item ``collectionView`` dari ``data`` untuk nama bulan yang dipilih.
    ///
    /// Fungsi ini hanya dijalankan di mode non-grup ketika pilihan di ``bulanPopUp`` berubah.
    /// - Parameter sender: Objek pemicu `NSPopUpButton`
    @IBAction func bulanPopUpValueChanged(_ sender: NSPopUpButton) {
        // Membuat peta hubungan antara nama bulan dan nilai bulan
        let monthMap: [String: Int] = [
            "Januari": 1, "Februari": 2, "Maret": 3, "April": 4, "Mei": 5, "Juni": 6, "Juli": 7, "Agustus": 8, "September": 9, "Oktober": 10, "November": 11, "Desember": 12, "Semua bln.": 0,
        ]

        if let selectedMonth = sender.titleOfSelectedItem, let mapMonth = monthMap[selectedMonth], mapMonth != bulan {
            // Mengambil nilai bulan dari peta
            if let mappedMonth = monthMap[selectedMonth] {
                bulan = mappedMonth
            } else {
                // Default ke bulan saat ini jika tidak ada pemetaan yang sesuai
                bulan = 0
            }

            if !UserDefaults.standard.bool(forKey: "grupTransaksi") {
                applyFilters()
            }
        }
    }

    /// Filter item ``collectionView`` dari ``data`` untuk tahun yang dipilih.
    ///
    /// Fungsi ini hanya dijalankan di mode non-grup ketika pilihan di ``tahunPopUp`` berubah.
    /// - Parameter sender: Objek pemicu `NSPopUpButton`
    @IBAction func tahunPopUpValueChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.titleOfSelectedItem else { return }
        let group = DispatchGroup()

        group.enter()
        tahun = selectedItem == "Tahun" ? 0 : Int(selectedItem) ?? 2023
        bulanPopUp.selectItem(withTitle: "Semua bln.")
        bulan = 0
        group.leave()

        if !UserDefaults.standard.bool(forKey: "grupTransaksi") {
            group.enter()
            context.perform {
                self.applyFilters()
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .background)) {
            self.loadBulanList()
        }
    }

    /// Menampilkan `NSAlert` di dalam jendela sheet dengan satu `NSTextField`
    /// untuk menentukan nilai ``tahun`` yang akan disimpan ke `UserDefaults`.
    /// - Parameter _: Objek apapun, harus tetap ada karena func ditandai sebagai `objc`.
    @objc func filterTahunSheet(_: Any) {
        let alert = NSAlert()
        alert.messageText = "Filter Data"
        alert.icon = NSImage(systemSymbolName: "slider.horizontal.below.square.fill.and.square", accessibilityDescription: nil)
        alert.addButton(withTitle: "OKE")
        alert.addButton(withTitle: "Batalkan")
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        inputTextField.placeholderString = "tahun"
        inputTextField.alignment = .center
        inputTextField.bezelStyle = .roundedBezel
        inputTextField.stringValue = tahun < 1000 ? "" : String(tahun)
        alert.accessoryView = inputTextField
        alert.window.initialFirstResponder = inputTextField
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else {
                return
            }

            ReusableFunc.showProgressWindow(view, isDataLoaded: false)

            let input = inputTextField.stringValue

            let tahunToFilter: Int = if let input = Int(input) {
                input
            } else {
                0
            }

            if !input.isEmpty, Int16(input) == nil {
                ReusableFunc.showAlert(title: "Input Error", message: "Masukkan Tahun yang Valid. Filter Tahun akan direset.")
            }

            tahun = Int(tahunToFilter)

            let itemToSelect = tahun == 0 ? "Tahun" : String(tahun)
            tahunPopUp.selectItem(withTitle: itemToSelect)

            tampilanGroup()

            if let window = view.window {
                ReusableFunc.closeProgressWindow(window)
            }
        }
    }

    /// Filter item ``collectionView`` dari ``data`` sesuai keperluan yang diketik dari `sender`.
    ///
    /// - Parameter sender: Object pemicu `NSTextField`.
    @IBAction func filterKeperluanChanged(_ sender: NSTextField) {
        filterKeperluan = sender.stringValue
        guard filterKeperluan?.trimmingCharacters(in: .whitespaces) != "" else {
            keperluanSearchWorkItem?.cancel()
            applyFilters()
            return
        }

        // Batalkan pencarian sebelumnya
        keperluanSearchWorkItem?.cancel()

        // Membuat DispatchWorkItem baru dengan delay 0.5 detik
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.applyFilters()
        }

        // Menyimpan work item yang baru dibuat
        keperluanSearchWorkItem = newWorkItem

        // Menjalankan work item setelah 0.5 detik
        dataProcessingQueue.asyncAfter(deadline: .now() + 0.5, execute: newWorkItem)
    }

    /// Filter item ``collectionView`` dari ``data`` sesuai acara yang diketik dari `sender`.
    ///
    /// - Parameter sender: Object pemicu `NSTextField`.
    @IBAction func filterAcaraChanged(_ sender: NSTextField) {
        filterAcara = sender.stringValue
        guard filterAcara?.trimmingCharacters(in: .whitespaces) != "" else {
            acaraSearchWorkItem?.cancel()
            applyFilters()
            return
        }

        // Batalkan pencarian sebelumnya
        acaraSearchWorkItem?.cancel()

        // Membuat DispatchWorkItem baru dengan delay 0.5 detik
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.applyFilters()
        }

        // Menyimpan work item yang baru dibuat
        acaraSearchWorkItem = newWorkItem

        // Menjalankan work item setelah 0.5 detik
        dataProcessingQueue.asyncAfter(deadline: .now() + 0.5, execute: newWorkItem)
    }

    /// Filter item ``collectionView`` dari ``data`` sesuai kategori yang diketik dari `sender`.
    ///
    /// - Parameter sender: Object pemicu `NSSearchField`.
    @IBAction func filterKategoriChanged(_ sender: NSSearchField) {
        filteredKategori = sender.stringValue
        guard filteredKategori?.trimmingCharacters(in: .whitespaces) != "" else {
            kategoriSearchWorkItem?.cancel()
            applyFilters()
            return
        }

        // Batalkan pencarian sebelumnya
        kategoriSearchWorkItem?.cancel()

        // Membuat DispatchWorkItem baru dengan delay 0.5 detik
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.applyFilters()
        }

        // Menyimpan work item yang baru dibuat
        kategoriSearchWorkItem = newWorkItem

        // Menjalankan work item setelah 0.5 detik
        dataProcessingQueue.asyncAfter(deadline: .now() + 0.5, execute: newWorkItem)
    }

    /// Menangani aksi pencarian dari input toolbar.
    ///
    /// - Parameter searchText: Teks pencarian yang dimasukkan oleh pengguna.
    ///
    /// Fungsi ini menyimpan teks pencarian ke dalam variabel `filterSearchToolbar`
    /// lalu memanggil fungsi `cariData()` untuk memfilter atau memperbarui data
    /// berdasarkan teks pencarian tersebut.
    @IBAction func search(_ searchText: String) {
        filterSearchToolbar = searchText
        cariData()
    }

    /// Menangani input dari `NSSearchField` dengan debounce dan memicu pencarian.
    /// Action untuk `NSSearchField` di toolbar: ``DataSDI/WindowController/searchField``.
    ///
    /// - Parameter sender: NSSearchField yang memberikan input pencarian.
    @objc func procSearchFieldInput(sender: NSSearchField) {
        let searchText = sender.stringValue

        // Batalkan pencarian yang tertunda sebelumnya
        searchWorkItem?.cancel()

        // Membuat DispatchWorkItem baru dengan delay 0.5 detik
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.search(searchText)
            if !(self?.isGrouped ?? false) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
                    if !(self?.cariAcara.stringValue.isEmpty ?? true) {
                        self?.cariAcara.stringValue.removeAll()
                    }
                    if !(self?.cariKeperluan.stringValue.isEmpty ?? true) {
                        self?.cariKeperluan.stringValue.removeAll()
                    }
                    if !(self?.cariKategori.stringValue.isEmpty ?? true) {
                        self?.cariKategori.stringValue.removeAll()
                    }
                }
            }
        }

        // Menyimpan work item yang baru dibuat
        searchWorkItem = newWorkItem

        // Menjalankan work item setelah 0.5 detik
        dataProcessingQueue.asyncAfter(deadline: .now() + 0.5, execute: newWorkItem)
    }

    /// Memuat data dari database secara asinkron dan memfilter berdasarkan kriteria saat ini.
    func loadData() {
        context.perform { [weak self] in
            guard let self else { return }
            data = DataManager.shared.fetchData()

            data = data.filter { entity in
                guard let tanggalDate = entity.tanggal as Date? else {
                    return false
                }
                let bulanInt64 = entity.bulan
                let calendar = Calendar.current
                let components = calendar.dateComponents([.month, .year], from: tanggalDate)

                // Modifikasi kondisi untuk menangani "Semua Tahun"
                let tahunMatch: Bool = if self.tahun == 0 {
                    true // Tidak menerapkan filter tahun
                } else {
                    components.year == Int(self.tahun)
                }

                let bulanMatch = self.bulan == 0 ? true : bulanInt64 == Int64(self.bulan)
                let jenisMatch = self.jenis == nil || entity.jenis == self.jenis
                let acaraMatch = self.filterAcara?.isEmpty ?? true || (entity.acara?.value?.lowercased().contains(self.filterAcara!.lowercased()) ?? false)
                let keperluanMatch = self.filterKeperluan?.isEmpty ?? true || (entity.keperluan?.value?.lowercased().contains(self.filterKeperluan!.lowercased()) ?? false)
                let kategoriMatch = self.filteredKategori?.isEmpty ?? true || (entity.kategori?.value?.lowercased().contains(self.filteredKategori!.lowercased()) ?? false)
                return tahunMatch && bulanMatch && jenisMatch && acaraMatch && keperluanMatch && kategoriMatch
            }

            urutkanDipilih()
        }
    }

    /// Melakukan pencarian dan pengambilan data dari Core Data berdasarkan beberapa kriteria filter.
    /// Fungsi ini menggunakan `NSFetchRequest` dengan kombinasi predikat untuk memfilter data sesuai:
    /// - Jenis data (`jenis`),
    /// - Filter pencarian teks pada beberapa kolom seperti `jumlah`, `kategori`, `acara`, dan `keperluan`,
    /// - Filter tahun dan bulan jika data tidak dalam mode pengelompokan (`isGrouped`).
    ///
    /// Setelah data berhasil diambil, hasilnya akan disimpan ke properti `data` jika tidak dalam mode pengelompokan,
    /// atau ke properti `groupData` jika dalam mode pengelompokan.
    /// Jika tidak dalam mode pengelompokan, data juga akan diurutkan menggunakan fungsi `urutkanDipilih()`.
    ///
    /// Fungsi ini berjalan secara asynchronous menggunakan `Task` dengan prioritas user-initiated
    /// dan melakukan operasi fetch di context Core Data dengan perform block.
    func cariData() {
        context.perform { [weak self] in
            guard let self else { return }

            let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
            var predicates: [NSPredicate] = []

            // Jenis filter
            if let jenis {
                predicates.append(NSPredicate(format: "jenis == %i", jenis))
            }

            // Kategori, Acara, Keperluan filter
            if let filterKategori = filterSearchToolbar, !filterKategori.isEmpty {
                let searchPredicates = [
                    NSPredicate(format: "jumlah CONTAINS[cd] %@", filterKategori),
                    NSPredicate(format: "kategori.value CONTAINS[cd] %@", filterKategori),
                    NSPredicate(format: "acara.value CONTAINS[cd] %@", filterKategori),
                    NSPredicate(format: "keperluan.value CONTAINS[cd] %@", filterKategori),
                ]

                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates))
            }
            if !isGrouped {
                if tahun != 0, bulan != 0 {
                    let yearMonthPredicate = NSPredicate(format: "tahun == %d AND bulan == %d", tahun, bulan)
                    predicates.append(yearMonthPredicate)
                } else if tahun != 0 {
                    let yearPredicate = NSPredicate(format: "tahun == %d", tahun)
                    predicates.append(yearPredicate)
                } else if bulan != 0 {
                    let monthPredicate = NSPredicate(format: "bulan == %d", bulan)
                    predicates.append(monthPredicate)
                }
            }

            // Combine predicates
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            do {
                let fetchedData = try DataManager.shared.internFetchedData(context.fetch(fetchRequest))
                if isGrouped {
                    groupData = fetchedData
                } else {
                    data = fetchedData
                    urutkanDipilih()
                }
            } catch {}
        }
    }

    /// Mengaplikasikan filter dan pengurutan pada data yang diambil dari Core Data.
    ///
    /// Fungsi ini membuat `NSFetchRequest` untuk entitas `Entity` dan membangun predicate berdasarkan
    /// filter yang diberikan oleh pengguna seperti `filterKeperluan`, `filterAcara`, `filteredKategori`, `jenis`,
    /// `tahun`, dan `bulan`.
    ///
    /// Predicate-predicate tersebut digabungkan menggunakan operator AND untuk membatasi hasil fetch sesuai kriteria.
    ///
    /// Selain itu, fungsi ini menambahkan `NSSortDescriptor` berdasarkan kriteria pengurutan yang dipilih (`currentSortOption`).
    /// Kriteria pengurutan meliputi tanggal terbaru, tanggal terlama, kategori, acara, keperluan, jumlah, jenis transaksi, dan status bertanda.
    ///
    /// Setelah melakukan fetch pada context Core Data secara asynchronous, data hasil fetch disimpan di properti `data`.
    ///
    /// Kemudian, fungsi ini melakukan reload pada `collectionView` dengan animasi dan pembaruan pada `jumlahTextField`
    /// yang menampilkan pesan instruksi kepada pengguna untuk memilih beberapa item.
    ///
    /// Pengaturan ini juga menyimpan pilihan urutan pengurutan ke UserDefaults agar dapat diingat pada sesi berikutnya.
    ///
    /// - Catatan:
    /// Fungsi ini menggunakan `context.perform` untuk menjalankan fetch secara thread-safe di Core Data context. Lihat: ``DataSDI/DataManager/managedObjectContext``.
    func applyFilters() {
        // Membuat fetch request untuk entitas Anda
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()

        // Membuat NSPredicate untuk menyaring data berdasarkan filter
        var predicateStrings: [String] = []
        var predicateArguments: [Any] = []

        if let keperluan = filterKeperluan, !keperluan.isEmpty {
            predicateStrings.append("keperluan.value CONTAINS[c] %@")
            predicateArguments.append(keperluan)
        }

        if let acara = filterAcara, !acara.isEmpty {
            predicateStrings.append("acara.value CONTAINS[c] %@")
            predicateArguments.append(acara)
        }

        if let kategori = filteredKategori, !kategori.isEmpty {
            predicateStrings.append("kategori.value CONTAINS[c] %@")
            predicateArguments.append(kategori)
        }

        if let jenis {
            predicateStrings.append("jenis == %i")
            predicateArguments.append(jenis)
        }

        if tahun != 0 {
            predicateStrings.append("tahun == %@")
            predicateArguments.append(tahun)
        }

        if bulan != 0, tahun != 0 {
            predicateStrings.append("tahun == %@ AND bulan == %@")
            predicateArguments.append(tahun)
            predicateArguments.append(bulan)
        }

        if bulan != 0, tahun == 0 {
            predicateStrings.append("bulan == %@")
            predicateArguments.append(bulan)
        }

        // Menggabungkan predicate untuk pencarian
        if !predicateStrings.isEmpty {
            // Menggabungkan predicate untuk pencarian
            let predicateString = predicateStrings.joined(separator: " AND ")
            let predicate = NSPredicate(format: predicateString, argumentArray: predicateArguments)
            fetchRequest.predicate = predicate
        } else {
            // Jika tidak ada filter, gunakan nil untuk fetch request
            fetchRequest.predicate = nil
        }

        // Menambahkan kriteria pengurutan
        let criteria = getSortingCriteria(for: currentSortOption)
        let sortDescriptors = criteria.compactMap { criterion -> NSSortDescriptor? in
            switch criterion {
            case .terbaru:
                return NSSortDescriptor(key: "tanggal", ascending: false)
            case .terlama:
                return NSSortDescriptor(key: "tanggal", ascending: true)
            case .kategori:
                return NSSortDescriptor(key: "kategori", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            case .acara:
                return NSSortDescriptor(key: "acara", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            case .keperluan:
                return NSSortDescriptor(key: "keperluan", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            case .jumlah:
                return NSSortDescriptor(key: "jumlah", ascending: true)
            case .transaksi:
                return NSSortDescriptor(key: "jenis", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            case .bertanda:
                return NSSortDescriptor(key: "ditandai", ascending: false)
            }
        }

        fetchRequest.sortDescriptors = sortDescriptors

        context.perform { [weak self] in
            guard let self else { return }
            do {
                data = try DataManager.shared.internFetchedData(context.fetch(fetchRequest))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self else { return }
                    collectionView.reloadData()
                    let title = "Pilih beberapa item untuk kalkulasi"
                    let textSize = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

                    // Update string value
                    jumlahTextField.stringValue = title

                    // Update constraint untuk lebar textField
                    if let widthConstraint = jumlahTextFieldWidthConstraint {
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.2 // Durasi animasi dalam detik
                            context.timingFunction = CAMediaTimingFunction(name: .linear) // Mengatur timing function
                            widthConstraint.constant = textSize.width // Mengubah lebar constraint
                            self.jumlahTextField.alphaValue = 0.6
                        } completionHandler: {
                            self.jumlahTextField.isSelectable = false
                        }
                    }
                    UserDefaults.standard.setValue("\(currentSortOption)", forKey: "urutanTransaksi")
                }
            } catch {
                #if DEBUG
                    print(error.localizedDescription)
                #endif
            }
        }
    }

    /// Menangani perubahan pilihan pada NSPopUpButton untuk pengurutan data.
    ///
    /// Fungsi ini dipanggil saat pengguna memilih opsi baru pada popup menu pengurutan ``urutkanPopUp``.
    /// Jika pilihan yang dipilih berbeda dari ``currentSortOption`` saat ini,
    /// maka fungsi akan memperbarui ``currentSortOption``, lalu memanggil fungsi ``urutkanDipilih`()`
    /// untuk menerapkan urutan data baru.
    ///
    /// Selain itu, fungsi ini memperbarui status (state) setiap item menu di popup,
    /// menandai item yang terpilih dengan `.on` dan item lainnya dengan `.off`
    /// agar tampilan menu merefleksikan pilihan pengguna.
    ///
    /// - Parameter sender: NSPopUpButton yang memicu aksi ini.
    @IBAction func sortPopUpValueChanged(_ sender: NSPopUpButton) {
        if let pilihan = sender.selectedItem?.title.lowercased(), pilihan != currentSortOption {
            currentSortOption = pilihan
            urutkanDipilih()

            // Memperbarui status pilihan untuk setiap item popupMenuItem
            for menuItem in sender.itemArray {
                let title = menuItem.title.lowercased()
                let isSelected = (title == pilihan)
                menuItem.state = isSelected ? .on : .off
            }
        }
    }

    // MARK: - Sorting Functions

    /// Mengurutkan data berdasarkan kriteria yang dipilih dan memperbarui tampilan koleksi.
    ///
    /// Fungsi ini menjalankan pengurutan data secara asynchronous pada ``context``
    /// menggunakan kriteria pengurutan yang didapat dari ``currentSortOption``.
    /// Setelah pengurutan selesai, fungsi akan reload data pada ``collectionView``
    /// dan menyimpan pilihan urutan saat ini ke `UserDefaults`.
    ///
    /// Jika mode tidak dalam ``isGrouped``, fungsi juga akan memperbarui tampilan
    /// ``jumlahTextField`` dengan teks instruksional dan mengatur ulang lebar serta
    /// animasi transisi untuk memperhalus perubahan tampilan.
    ///
    /// Proses pengurutan menggunakan `DispatchGroup` untuk sinkronisasi tugas asynchronous.
    ///
    /// - Catatan:
    ///   - `compareElements(_:_:criteria:)` adalah fungsi pembantu yang melakukan perbandingan dua elemen berdasarkan kriteria.
    ///
    /// Tidak ada parameter atau nilai kembali karena fungsi ini bersifat prosedural dan berdampak pada UI dan data model internal.
    func urutkanDipilih() {
        let group = DispatchGroup()
        group.enter()
        context.perform { [weak self] in
            guard let self else { return }

            let criteria = getSortingCriteria(for: currentSortOption)

            data.sort { e1, e2 in
                self.compareElements(e1, e2, criteria: criteria)
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            collectionView.reloadData()
            UserDefaults.standard.setValue("\(currentSortOption)", forKey: "urutanTransaksi")
            if !isGrouped {
                let title = "Pilih beberapa item untuk kalkulasi"
                let textSize = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

                // Update string value
                jumlahTextField.stringValue = title

                // Update constraint untuk lebar textField
                if let widthConstraint = jumlahTextFieldWidthConstraint {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.2 // Durasi animasi dalam detik
                        context.timingFunction = CAMediaTimingFunction(name: .linear) // Mengatur timing function
                        widthConstraint.constant = textSize.width // Mengubah lebar constraint
                        self.jumlahTextField.alphaValue = 0.6
                    } completionHandler: {
                        self.jumlahTextField.isSelectable = false
                    }
                }
            }
        }
    }

    // MARK: - - TOMBOL

    /// Mengatur visibilitas elemen UI terkait tools berdasarkan status toggle dan mode grouping.
    ///
    /// Fungsi ini dipicu saat aksi tombol atau kontrol terkait di-klik (`IBAction`).
    /// - Jika `isGrouped` bernilai true, maka tombol `hideTools` akan disembunyikan secara otomatis.
    /// - Jika toggle `hideTools` dalam keadaan off, maka beberapa elemen UI seperti
    ///   `visualEffect` dan `hlinebottom` akan disembunyikan,
    ///   serta mengatur inset scrollView menjadi 0 dan me-refresh layout collection view.
    /// - Jika toggle `hideTools` dalam keadaan on, elemen-elemen tersebut akan ditampilkan kembali,
    ///   inset scrollView diatur menjadi 86, dan layout collection view juga di-refresh.
    ///
    /// Tujuan fungsi ini adalah untuk memberi opsi pengguna menyembunyikan atau menampilkan tools visual di antarmuka,
    /// terutama menyesuaikan dengan kondisi pengelompokan data (grouping).
    ///
    /// - Parameter sender: Objek yang memicu aksi, dalam konteks saat ini adalah ``hideTools``.
    @IBAction func hideTools(_: Any) {
        hideTools.isHidden = isGrouped ? true : false
        if hideTools.state == .off {
            visualEffect.isHidden = true
            hlinebottom.isHidden = true
            scrollView.scrollerInsets.top = 0
            collectionView.collectionViewLayout?.invalidateLayout()
        } else {
            visualEffect.isHidden = false
            hlinebottom.isHidden = false
            scrollView.scrollerInsets.top = 86
            collectionView.collectionViewLayout?.invalidateLayout()
        }
    }

    /// Menghapus item yang dipilih pada collectionView dengan konfirmasi dari pengguna.
    ///
    /// Fungsi ini akan memeriksa apakah ada item yang dipilih, kemudian menampilkan
    /// konfirmasi penghapusan dengan detail maksimal 5 item yang dipilih.
    /// Jika pengguna mengkonfirmasi, item-item tersebut akan dihapus.
    /// Jika pengguna memilih opsi "Jangan tanya lagi", alert konfirmasi tidak akan muncul lagi
    /// pada penghapusan berikutnya.
    /// Fungsi juga mendukung mode grouped dan non-grouped.
    ///
    /// - Parameter sender: Sumber aksi (biasanya tombol atau menu yang memicu fungsi ini), dalam konteks ini adalah ``DataSDI/WindowController/hapusToolbar`` dan menu item di Menu Bar > Edit > Hapus.
    @IBAction func hapus(_: Any?) {
        // Pastikan ada item yang dipilih di collectionView
        guard collectionView.selectionIndexPaths.first != nil else {
            showNoItemsSelectedAlert() // Tampilkan alert jika tidak ada item yang dipilih
            return
        }

        // Ambil indeks item yang dipilih, diurutkan descending untuk penghapusan aman
        let selectedIndexes = collectionView.selectionIndexPaths.sorted(by: { $0.item > $1.item })

        // Simpan semua indeks item yang dipilih dalam array
        let selectedIndexPaths = Array(collectionView.selectionIndexPaths)

        var itemDetails = "" // Menyimpan detail deskripsi item yang dipilih untuk alert
        var selectedEntities: [Entity] = [] // Menyimpan objek Entity yang terkait item yang dipilih

        // Mendapatkan daftar key section yang sudah diurutkan (untuk grouped mode)
        let sortedSectionKeys = groupedData.keys.sorted()

        let totalItems = selectedIndexPaths.count // Total item yang dipilih
        let maxItemsToShow = 5 // Maksimal jumlah item yang akan ditampilkan detailnya di alert

        // Loop untuk membangun detail item yang akan ditampilkan di konfirmasi hapus
        for (index, indexPath) in selectedIndexPaths.enumerated() {
            // Batasi maksimal item yang ditampilkan detailnya
            if index >= maxItemsToShow {
                let remainingItems = totalItems - maxItemsToShow
                if remainingItems > 0 {
                    itemDetails += "\ndan \(remainingItems) item lainnya"
                }
                break
            }

            if isGrouped {
                // Jika mode grouped, ambil data dari groupedData dengan section dan item
                let jenisTransaksi = sortedSectionKeys[indexPath.section]
                guard let entitiesInSection = groupedData[jenisTransaksi], indexPath.item < entitiesInSection.count else {
                    return
                }
                let selectedEntity = entitiesInSection[indexPath.item]
                selectedEntities.append(selectedEntity)
                // Tambahkan detail ke string itemDetails
                itemDetails += "• Jumlah: \(selectedEntity.jumlah)\n  Acara: \(selectedEntity.acara?.value ?? "Acara Tidak Diketahui")\n  Kategori: \(selectedEntity.kategori?.value ?? "Kategori Tidak Diketahui")\n  Keperluan: \(selectedEntity.keperluan?.value ?? "Keperluan Tidak Diketahui")\n\n"
            } else {
                // Jika tidak grouped, ambil langsung dari data array
                guard indexPath.item < data.count else {
                    return
                }
                let selectedEntity = data[indexPath.item]
                selectedEntities.append(selectedEntity)
                itemDetails += "• Jumlah: \(selectedEntity.jumlah)\n  Acara: \(selectedEntity.acara?.value ?? "Acara Tidak Diketahui")\n  Kategori: \(selectedEntity.kategori?.value ?? "Kategori Tidak Diketahui")\n  Keperluan: \(selectedEntity.keperluan?.value ?? "Keperluan Tidak Diketahui")\n\n"
            }
        }

        // Pastikan semua entity yang dipilih tetap diambil secara lengkap untuk proses hapus
        selectedEntities = selectedIndexPaths.compactMap { indexPath in
            if isGrouped {
                let jenisTransaksi = sortedSectionKeys[indexPath.section]
                return groupedData[jenisTransaksi]?[indexPath.item]
            } else {
                return indexPath.item < data.count ? data[indexPath.item] : nil
            }
        }

        // Key untuk menyimpan status suppress alert di UserDefaults
        let suppressionKey = "hapusAdministrasiAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)

        // Jika alert sudah disuppressed sebelumnya, langsung hapus tanpa konfirmasi
        guard !isSuppressed else {
            deleteSelectedItems(selectedIndexPaths, section: nil)
            return
        }

        // Buat alert konfirmasi penghapusan dengan detail item yang dipilih
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.messageText = "Anda yakin ingin menghapus item berikut?"
        alert.informativeText = "\(itemDetails)"
        alert.showsSuppressionButton = true
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")

        // Tampilkan alert sebagai sheet modal pada window saat ini
        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Jika user memilih suppress alert, simpan statusnya
                    if alert.suppressionButton?.state == .on {
                        UserDefaults.standard.set(true, forKey: suppressionKey)
                    }

                    // Panggil fungsi hapus data sesuai mode grouped atau tidak
                    if self.isGrouped {
                        self.deleteSelectedItems(selectedIndexPaths, section: nil)
                    } else {
                        self.deleteSelectedItems(selectedIndexes, section: nil)
                    }
                }
            }
        }
    }

    /// Menghapus item-item yang dipilih dari data dan collectionView,
    /// termasuk menghapus dari Core Data, memperbarui tampilan koleksi,
    /// dan mendaftarkan undo action untuk pengembalian penghapusan.
    ///
    /// Fungsi ini mendukung mode grouped maupun non-grouped.
    /// Item yang akan dihapus diurutkan dari indeks tertinggi ke terendah agar penghapusan aman.
    /// Jika ada section yang kosong setelah penghapusan, section tersebut akan dihapus.
    /// Setelah penghapusan, tampilan diperbarui dan notifikasi perubahan data diposting.
    ///
    /// - Parameters:
    ///   - selectedIndexes: Array IndexPath dari item yang dipilih untuk dihapus.
    ///   - section: Opsional, section tertentu jika ingin fokus penghapusan ke section tersebut.
    func deleteSelectedItems(_ selectedIndexes: [IndexPath], section _: Int? = nil) {
        var itemsToDelete: [Entity] = []
        var prevEntity: [EntitySnapshot] = []
        let sortedSectionKeys = groupedData.keys.sorted()

        // Urutkan indeks agar penghapusan dari indeks tertinggi ke terendah (section dan item)
        let sortedSelectedIndexes = selectedIndexes.sorted {
            if $0.section == $1.section {
                return $0.item > $1.item
            }
            return $0.section > $1.section
        }

        // Ambil semua entity yang akan dihapus dan buat snapshot-nya untuk undo
        for indexPath in sortedSelectedIndexes {
            if isGrouped {
                let jenisTransaksi = sortedSectionKeys[indexPath.section]
                guard let entitiesInSection = groupedData[jenisTransaksi], indexPath.item < entitiesInSection.count else {
                    return
                }
                let selectedEntity = entitiesInSection[indexPath.item]
                itemsToDelete.append(selectedEntity)
                prevEntity.append(createSnapshot(from: selectedEntity))
            } else {
                itemsToDelete.append(data[indexPath.item])
                prevEntity.append(createSnapshot(from: data[indexPath.item]))
            }
        }

        // Daftarkan undo action agar penghapusan dapat dibatalkan
        myUndoManager.registerUndo(withTarget: self, handler: { _ in
            self.undoHapus(prevEntity)
        })

        // Hapus entity dari data array / groupedData dictionary
        if isGrouped {
            for indexPath in sortedSelectedIndexes {
                let jenisTransaksi = sortedSectionKeys[indexPath.section]
                groupedData[jenisTransaksi]?.remove(at: indexPath.item)
            }
        } else {
            for item in itemsToDelete {
                if let index = data.firstIndex(where: { $0.id == item.id }) {
                    data.remove(at: index)
                }
            }
        }

        // Update UI collectionView dengan batch updates untuk menghapus item dan section jika perlu
        collectionView.performBatchUpdates({
            if isGrouped {
                collectionView.deleteItems(at: Set(sortedSelectedIndexes))
                for indexPath in sortedSelectedIndexes {
                    let jenisTransaksi = sortedSectionKeys[indexPath.section]
                    if groupedData[jenisTransaksi]?.isEmpty == false {
                        self.updateTotalAmountsForSection(at: indexPath)
                    }
                    if groupedData[jenisTransaksi]?.isEmpty == true {
                        groupedData.removeValue(forKey: jenisTransaksi)
                        sectionKeys.removeAll(where: { $0 == jenisTransaksi })
                        collectionView.deleteSections(IndexSet(integer: indexPath.section))
                    } else {
                        selectNextItem(afterDeletingFrom: sortedSelectedIndexes)
                    }
                }
            } else {
                let indexPathsToDelete = Set(selectedIndexes)
                collectionView.deleteItems(at: indexPathsToDelete)
                selectNextItem(afterDeletingFrom: sortedSelectedIndexes)
            }
            NotificationCenter.default.post(name: DataManager.dataDihapusNotif, object: nil, userInfo: ["deletedEntity": prevEntity])
        }, completionHandler: { [weak self] _ in
            guard let self, collectionView.numberOfSections > 0 else { return }
            for indexPath in 0 ..< collectionView.numberOfSections - 1 {
                updateTotalAmountsForSection(at: IndexPath(item: 0, section: indexPath))
            }
            flowLayout.invalidateLayout()
            view.window?.endSheet(view.window!, returnCode: .OK)
            createLineAtTopSection()
            NotificationCenter.default.post(name: .perubahanData, object: nil)
            // Hapus entity dari Core Data context
            for item in itemsToDelete {
                context.delete(item)
            }

            // Simpan perubahan ke Core Data
            do {
                try context.save()
            } catch {
                #if DEBUG
                    print(error.localizedDescription)
                #endif
            }
        })
    }

    /// Memilih item berikutnya di collectionView setelah proses penghapusan item tertentu,
    /// agar fokus atau seleksi berpindah ke item yang tepat.
    ///
    /// Jika mode grouped aktif, akan mencari item berikutnya di dalam section yang sama.
    /// Jika tidak grouped, akan memilih item berikutnya di section 0.
    /// Jika item terakhir dalam section/data, tidak melakukan seleksi.
    ///
    /// - Parameter selectedIndexes: Array IndexPath dari item yang baru saja dihapus.
    func selectNextItem(afterDeletingFrom selectedIndexes: [IndexPath]) {
        let sortedIndexes = selectedIndexes.sorted { $0.section < $1.section || ($0.section == $1.section && $0.item < $1.item) }
        // Tentukan indexPath terakhir yang dipilih
        guard let lastSelectedIndexPath = sortedIndexes.last else { return }

        if isGrouped {
            // Mode grouped
            let currentSectionIndex = lastSelectedIndexPath.section
            guard currentSectionIndex < sectionKeys.count else { return }
            let currentItemIndex = lastSelectedIndexPath.item

            let currentSectionKey = sectionKeys[currentSectionIndex]
            guard let currentSectionItems = groupedData[currentSectionKey], !currentSectionItems.isEmpty else {
                return
            }

            let nextItemIndex = currentItemIndex + 1
            if nextItemIndex <= currentSectionItems.count {
                let nextItemIndexPath = IndexPath(item: nextItemIndex, section: currentSectionIndex)
                guard nextItemIndexPath.item < collectionView.numberOfItems(inSection: currentSectionIndex) else {
                    return
                }
                collectionView.selectItems(at: Set([nextItemIndexPath]), scrollPosition: .centeredVertically)
            }
        } else {
            // Mode !isGrouped
            let currentItemIndex = lastSelectedIndexPath.item

            // Pastikan data tidak kosong
            guard !data.isEmpty else {
                return
            }

            // Cari indeks berikutnya dalam data
            let nextItemIndex = currentItemIndex + 1
            if nextItemIndex < data.count {
                let nextItemIndexPath = IndexPath(item: nextItemIndex, section: 0)
                guard nextItemIndexPath.item < collectionView.numberOfItems(inSection: 0) else {
                    return
                }
                collectionView.selectItems(at: Set([nextItemIndexPath]), scrollPosition: .centeredVertically)
            }
        }
    }

    /// `NSAlert` jika tidak ada item yang dipilih tetapi tombol Toolbar ``DataSDI/WindowController/hapusToolbar`` atau ``DataSDI/WindowController/editToolbar`` diklik.
    func showNoItemsSelectedAlert() {
        let alert = NSAlert()
        alert.messageText = "Tidak ada item yang dipilih."
        alert.informativeText = "Pilih item terlebih dahulu untuk melanjutkan."
        alert.icon = NSImage(named: "No Data Bordered")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let keyWindow = NSApplication.shared.keyWindow {
            alert.beginSheetModal(for: keyWindow) { _ in
            }
        }
    }

    /// Reload item yang diedit setelah menerima notifikasi dari ``DataSDI/EditTransaksi`` atau ``undoEdit(_:)``.
    @objc func reloadEditedItems(_ notification: Notification) {
        /// Hapus observer terlebih dahulu untuk mengurangi intensitas notifikasi
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDieditNotif, object: nil)

        /// Periksa apakah data dari notifikasi berupa tipe data yang diinginkan.
        guard let notif = notification.userInfo, let ids = notif["uuid"] as? Set<UUID>, let prevData = notif["entiti"] as? [EntitySnapshot] else { return }
        /// Hapus semua seleksi ``collectionView`` terlebih dahulu
        collectionView.deselectAll(nil)
        /// Array penyimpanan indexPath item yang diedit.
        var editedIndexPaths: Set<IndexPath> = []
        /// Jalankan logika pengeditan
        updateItem(ids: ids, prevData: prevData)
        /// Daftarkan ke ``myUndoManager``
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self else { return }
            undoEdit(prevData)
        })

        if isGrouped {
            // Jalankan blok kode ini secara asynchronous di background queue dengan prioritas userInteractive
            dataProcessingQueue.async { [weak self] in
                // Tangkap self secara weak untuk mencegah retain cycle dan cek agar self tidak nil
                guard let self else { return }

                // Ambil dan urutkan semua kunci section dari groupedData, simpan dalam array sectionKeys
                let sectionKeys = Array(groupedData.keys.sorted())

                // Loop melalui setiap section (index dan key)
                for (sectionIndex, sectionKey) in sectionKeys.enumerated() {
                    // Ambil semua item di section tersebut, jika ada
                    if let items = groupedData[sectionKey] {
                        // Loop setiap item dalam section beserta indexnya
                        for (itemIndex, entity) in items.enumerated() {
                            // Cek apakah entity memiliki id dan apakah id tersebut termasuk dalam set ids yang diberikan
                            if let entityId = entity.id, ids.contains(entityId) {
                                // Jika iya, buat IndexPath dari itemIndex dan sectionIndex
                                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                                // Tambahkan IndexPath tersebut ke set editedIndexPaths untuk nanti diseleksi
                                editedIndexPaths.insert(indexPath)
                            }
                        }
                    }
                }
                // Setelah seluruh pencarian selesai, jalankan di main thread untuk update UI
                DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                    // Pilih item di collectionView berdasarkan IndexPath yang sudah ditemukan
                    self?.collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
                }
            }
        }

        /// Tambahkan observer untuk kembali menjalankan func ini ketika mendapatkan notifikasi.
        NotificationCenter.default.addObserver(self, selector: #selector(reloadEditedItems(_:)), name: DataManager.dataDieditNotif, object: nil)
    }

    /// Memperbarui tampilan total pemasukan dan pengeluaran pada header section tertentu di collectionView.
    /// - Parameter indexPath: IndexPath yang menunjuk ke section header yang ingin diperbarui.
    func updateTotalAmountsForSection(at indexPath: IndexPath) {
        // Ambil header view untuk section tersebut, jika tidak ada langsung return
        guard let headerView = collectionView.supplementaryView(forElementKind: NSCollectionView.elementKindSectionHeader, at: indexPath) as? HeaderView else {
            return
        }

        // Ambil kunci section yang sudah diurutkan berdasarkan index section
        let sortedSectionKeys = groupedData.keys.sorted()
        let sectionKey = sortedSectionKeys[indexPath.section]

        // Siapkan formatter angka untuk menampilkan angka dengan format desimal tanpa digit desimal
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        // Inisialisasi variabel total pengeluaran dan pemasukan
        var totalPengeluaran: Double = 0
        var totalPemasukan: Double = 0

        // Ambil semua item dalam section tersebut
        if let itemsInSection = groupedData[sectionKey] {
            // Loop setiap entity dan jumlahkan total berdasarkan jenis transaksi
            for entity in itemsInSection {
                if entity.jenis == JenisTransaksi.pengeluaran.rawValue {
                    totalPengeluaran += entity.jumlah
                } else if entity.jenis == JenisTransaksi.pengeluaran.rawValue {
                    totalPemasukan += entity.jumlah
                }
            }
        }

        // Format total pengeluaran dan pemasukan ke string dengan awalan "Rp. "
        let totalPengeluaranFormatted = "Rp. " + (formatter.string(from: NSNumber(value: totalPengeluaran)) ?? "")
        let totalPemasukanFormatted = "Rp. " + (formatter.string(from: NSNumber(value: totalPemasukan)) ?? "")

        // Set nilai label kategori pada header dengan nama section
        headerView.kategori?.stringValue = sectionKey

        // Set nilai label jumlah pada header dengan informasi pemasukan dan pengeluaran yang sudah diformat
        headerView.jumlah?.stringValue = "Pemasukan: \(totalPemasukanFormatted) | Pengeluaran: \(totalPengeluaranFormatted)"
    }

    /// Edit data transaksi pada item yang dipilih.
    /// Action untuk ``DataSDI/WindowController/editToolbar``
    ///
    /// - Parameter sender: Objek pemicu. Bisa berupa apa saja.
    @IBAction func edit(_: Any) {
        // Dapatkan indeks item yang dipilih pertama kali
        guard collectionView.selectionIndexPaths.first != nil else {
            showNoItemsSelectedAlert()
            return
        }
        var selectedEntities: [Entity] = []
        // Dapatkan semua indeks item yang dipilih
        let selectedIndexPaths = collectionView.selectionIndexPaths

        // Membuat array untuk menyimpan data terkait dengan item yang dipilih
        let sortedSectionKeys = groupedData.keys.sorted()

        // Dapatkan data yang terkait dengan item yang dipilih
        for indexPath in selectedIndexPaths.reversed() {
            if isGrouped {
                let jenisTransaksi = sortedSectionKeys[indexPath.section]
                guard let entitiesInSection = groupedData[jenisTransaksi], indexPath.item < entitiesInSection.count else {
                    return
                }
                let selectedEntity = entitiesInSection[indexPath.item]
                selectedEntities.append(selectedEntity)
            } else {
                // Tidak menggunakan grouping
                guard indexPath.item < data.count else {
                    return
                }
                let selectedEntity = data[indexPath.item]
                selectedEntities.append(selectedEntity)
            }
        }

        // Membuat instance dari EditViewController
        let editViewController = EditTransaksi(nibName: "EditTransaksi", bundle: nil)
        editViewController.loadView()

        // Set nilai editedEntities
        editViewController.editedEntities = selectedEntities

        // Menampilkan view controller sebagai sheet
        presentAsSheet(editViewController)
        ReusableFunc.resetMenuItems()
    }

    /// Memfilter data berdasarkan jenis transaksi tertentu sesuai enum ``JenisTransaksi`` (misalnya "Pemasukan" atau "Pengeluaran").
    /// Fungsi ini juga memperbarui UI jika `grupTransaksi` diaktifkan dan memicu filter asinkron.
    /// - Parameter jenis: Jenis transaksi yang digunakan untuk memfilter data.
    func filterData(withType jenis: JenisTransaksi) {
        // Simpan jenis transaksi yang akan digunakan sebagai filter
        self.jenis = jenis.rawValue

        // Jika preferensi pengguna untuk tampilan grup transaksi aktif, nonaktifkan terlebih dahulu
        if UserDefaults.standard.bool(forKey: "grupTransaksi") {
            tampilanUnGrup() // Fungsi ini kemungkinan akan menonaktifkan mode grup
        }

        // Jalankan filter dan pembaruan UI secara asinkron di background thread
        dataProcessingQueue.async { [weak self] in
            guard let self else { return }

            // Terapkan filter utama, misalnya berdasarkan jenis, tanggal, kategori, dsb.
            applyFilters()

            // Setelah selesai, kembali ke main thread untuk memperbarui UI (jenisText)
            DispatchQueue.main.async { [weak self] in
                self?.jenisText.stringValue = jenis.title // Tampilkan jenis filter yang diterapkan
                self?.updateTitleWindow()
            }
        }
    }

    /// Mendapatkan data terbaru dari CoreData untuk data yang belum ditambahkan ke ``data``.
    /// Data terbaru akan ditampilkan sebagai item di ``collectionView``.
    @objc func dataDitambah(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uuid = userInfo["newItem"] as? UUID
        else { return }
        /// Hapus semua seleksi ``collectionView``
        collectionView.deselectAll(nil)

        /// Baca semua data di CoreData
        guard let newData = DataManager.shared.fetchData(by: uuid) else { return }

        /// Jika tidak ada filter jenis
        if !data.contains(newData) {
            insertSingleItem(newData)
        }
    }

    /// Memasukkan satu item `Entity` baru ke dalam `collectionView`,
    /// dengan mempertimbangkan apakah tampilan sedang dalam mode dikelompokkan (`isGrouped`) atau tidak.
    ///
    /// Proses penyisipan ini dilakukan secara animasi menggunakan `performBatchUpdates`
    /// untuk pengalaman pengguna yang mulus dan juga mendukung fungsionalitas undo.
    ///
    /// - Parameter newItem: Objek `Entity` baru yang akan dimasukkan ke dalam `collectionView`.
    func insertSingleItem(_ newItem: Entity) {
        var selectItem: IndexPath = [] // Akan menyimpan indexPath item yang baru dimasukkan untuk dipilih/di-scroll.

        // MARK: - Penanganan Mode Pengelompokan (`isGrouped`)

        if isGrouped {
            // Tentukan group key (kunci kelompok) berdasarkan kategori yang dipilih.
            guard let groupKey = getEntityGroupKey(for: newItem) else { return } // Jika kunci kelompok tidak bisa didapatkan, keluar.

            // Periksa apakah section untuk group key ini sudah ada di `groupedData`.
            let sectionExists = groupedData.keys.contains(groupKey)

            // Lakukan pembaruan batch pada `collectionView` untuk animasi yang halus.
            collectionView.performBatchUpdates {
                if sectionExists, var sectionData = groupedData[groupKey] {
                    // MARK: Section Sudah Ada

                    // Section untuk group key ini sudah ada. Tambahkan item baru ke section yang ada.
                    // Temukan indeks yang tepat untuk menyisipkan item baru agar tetap terurut.
                    // Diasumsikan `insertionIndex` yang dipanggil di sini adalah versi yang menerima
                    // `Entity`, indeks section (atau sectionData), dan `NSSortDescriptor`.
                    // Perlu sedikit penyesuaian jika `insertionIndex(for:in:using:)` yang digunakan.
                    // Jika `insertionIndex` yang Anda maksud adalah yang menerima `sectionData` langsung:
                    let itemIndex = insertionIndex(for: newItem, in: sectionData)

                    // Periksa apakah item dengan ID unik yang sama sudah ada di section ini.
                    // Ganti `$0.id` dengan properti identifier unik dari `Entity` Anda (misalnya `newItem.uuid`).
                    let itemExists = sectionData.contains { $0.id == newItem.id }

                    if !itemExists {
                        // Jika item belum ada (bukan duplikat), masukkan item ke dalam array data section.
                        sectionData.insert(newItem, at: itemIndex)
                        // Perbarui data di kamus `groupedData`.
                        groupedData[groupKey] = sectionData

                        // Dapatkan indeks section yang sebenarnya dalam `sectionKeys` yang sudah diurutkan.
                        if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                            let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                            // Beri tahu `collectionView` untuk menyisipkan item pada `indexPath` yang ditemukan.
                            collectionView.insertItems(at: [indexPath])
                            // Tambahkan indexPath ini ke `selectItem` agar bisa dipilih nanti.
                            selectItem.append(indexPath)

                            // Perbarui total jumlah untuk header section (jika ada).
                            let sectionIndices = IndexPath(item: 0, section: sectionIndex)
                            self.updateTotalAmountsForSection(at: sectionIndices)
                        } else {
                            // Handle kasus di mana sectionIndex tidak ditemukan (seharusnya tidak terjadi jika `sectionExists` benar)
                            // Anda mungkin ingin mencatat error di sini.
                        }
                    }
                } else {
                    // MARK: Section Belum Ada

                    // Section untuk group key ini belum ada. Buat section baru.
                    groupedData[groupKey] = [newItem] // Inisialisasi section baru dengan item ini.

                    // Jika kunci kelompok belum ada di `sectionKeys`, tambahkan.
                    if !sectionKeys.sorted().contains(groupKey) {
                        sectionKeys.append(groupKey)
                        // Anda mungkin perlu memanggil `sortSectionKeys()` di sini jika urutan section
                        // sangat penting dan tidak otomatis terurut oleh `sorted()` di atas.
                    } else {
                        // Jika sectionKeys sudah mengandung groupKey, dan sectionExists FALSE,
                        // ini adalah kondisi yang tidak biasa atau duplikat pada logika lain.
                        // Jika tujuannya untuk mencegah penambahan item pada section yang sudah terhapus
                        // atau kasus khusus, `return` di sini akan mencegah penambahan item.
                        return
                    }

                    // Dapatkan indeks section baru dalam `sectionKeys` yang sudah diurutkan.
                    if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                        // Beri tahu `collectionView` untuk menyisipkan section baru.
                        collectionView.insertSections([sectionIndex])

                        // Tambahkan item baru ke dalam section yang baru dibuat (selalu di indeks 0 karena ini item pertama).
                        let indexPath = IndexPath(item: 0, section: sectionIndex)
                        collectionView.insertItems(at: [indexPath])
                        selectItem.append(indexPath) // Tambahkan indexPath untuk dipilih nanti.
                    } else {
                        // Handle kasus di mana sectionIndex tidak ditemukan (setelah penambahan ke sectionKeys)
                        // Mungkin ada masalah dengan pengurutan atau pencarian.
                        return
                    }
                }
            } completionHandler: { [weak self] _ in
                guard let self else { return }

                // Setelah pembaruan batch selesai, lakukan post-processing.
                // Invalidasi layout untuk memastikan tampilan diperbarui dengan benar.
                flowLayout.invalidateLayout()
                // Tunda sebentar ke main thread untuk memastikan layout sudah diperbarui sebelum memilih/menggulir.
                DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                    guard let self else { return }
                    // Pilih item yang baru dimasukkan dan gulir ke sana.
                    collectionView.selectItems(at: [selectItem], scrollPosition: .centeredVertically)

                    // Logika tambahan untuk `createLineAtTopSection()`.
                    // Ini mungkin terkait dengan tampilan visual khusus untuk section teratas.
                    if selectItem.section == 0 {
                        createLineAtTopSection()
                    }
                    if let topSection = flowLayout.findTopSection() {
                        for i in 1 ..< sectionKeys.count {
                            guard i != topSection else { continue }
                            createLineAtTopSection() // Perlu dipertimbangkan apakah ini harus diulang untuk setiap section.
                        }
                    }
                }
            }
        } else {
            // MARK: - Penanganan Mode Tidak Dikompokkan (`else` block)

            // Ini adalah logika untuk mode di mana data tidak dikelompokkan (hanya ada satu section).
            // Temukan indeks penyisipan yang benar dalam array `data` utama.
            let index = insertionIndex(for: newItem)
            let indexPath = IndexPath(item: index, section: 0) // Selalu section 0 untuk mode tidak dikelompokkan.

            // Lakukan pembaruan batch pada `collectionView`.
            collectionView.performBatchUpdates {
                data.insert(newItem, at: index) // Sisipkan item baru ke array data utama.
                collectionView.insertItems(at: [indexPath]) // Beri tahu `collectionView` untuk menyisipkan item.
            } completionHandler: { _ in
                // Setelah pembaruan selesai, pilih item yang baru dan gulir ke sana.
                DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                    guard let self else { return }
                    collectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
                }
            }
        }

        // MARK: - Fungsionalitas Undo

        // Buat snapshot dari `newItem` untuk mendukung operasi undo.
        let snapshot = createSnapshot(from: newItem)
        // Daftarkan operasi undo: jika undo dipicu, `undoAddItem` akan dipanggil dengan snapshot ini.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self else { return }
            undoAddItem(snapshot)
        })
    }

//
//    /// function untuk mengurutkan sectionKeys
//    func sortSectionKeys() {
//        switch currentSortOption {
//        case "terlama", "terbaru":
//            sectionKeys.sort { key1, key2 in
//                guard let items1 = groupedData[key1]?.first?.tanggal,
//                      let items2 = groupedData[key2]?.first?.tanggal
//                else {
//                    return false
//                }
//                return currentSortOption == "terbaru" ? items1 > items2 : items1 < items2
//            }
//        case "kategori":
//            sectionKeys.sort()
//        case "acara":
//            sectionKeys.sort()
//        case "keperluan":
//            sectionKeys.sort()
//        default:
//            break
//        }
//    }
//
//    /// Mengurutkan kunci-kunci bagian (`sectionKeys`) yang digunakan untuk mengatur
//    /// tampilan data yang dikelompokkan dalam `collectionView`.
//    ///
//    /// Fungsi ini menyesuaikan urutan bagian-bagian berdasarkan kriteria pengurutan
//    /// yang ditentukan oleh parameter `key`. Ini memastikan bahwa bagian-bagian
//    /// ditampilkan dalam urutan yang logis sesuai dengan preferensi pengguna.
//    ///
//    /// - Parameter key: Sebuah `String` yang menentukan kriteria pengurutan
//    ///   (misalnya, "terlama", "terbaru", "kategori", "acara", "keperluan").
//    func sortSectionKeys(_ key: String) {
//        switch key {
//        case "terlama", "terbaru":
//            // Urutkan kunci bagian berdasarkan properti `tanggal` dari entitas pertama di setiap grup.
//            // Ini memungkinkan pengurutan section berdasarkan tanggal transaksi.
//            sectionKeys.sort { key1, key2 in
//                // Pastikan entitas pertama dan properti tanggal tersedia untuk kedua kunci.
//                guard let items1 = groupedData[key1]?.first?.tanggal,
//                      let items2 = groupedData[key2]?.first?.tanggal
//                else {
//                    return false // Jika tidak tersedia, urutan tidak diubah.
//                }
//                // Tentukan apakah urutan menaik atau menurun berdasarkan `currentSortOption`.
//                return currentSortOption == "terbaru" ? items1 > items2 : items1 < items2
//            }
//        case "kategori":
//            // Urutkan kunci bagian secara alfabetis menaik berdasarkan properti `kategori`
//            // dari entitas pertama di setiap grup. Ini mengatur section berdasarkan kategori.
//            sectionKeys.sort { key1, key2 in
//                // Pastikan entitas pertama dan properti kategori tersedia untuk kedua kunci.
//                guard let items1 = groupedData[key1]?.first?.kategori?.value,
//                      let items2 = groupedData[key2]?.first?.kategori?.value
//                else {
//                    return false // Jika tidak tersedia, urutan tidak diubah.
//                }
//                return items1 < items2 // Urutkan secara alfabetis menaik.
//            }
//        case "acara":
//            // Urutkan kunci bagian secara alfabetis menaik berdasarkan nilai string kunci itu sendiri.
//            // Ini efektif ketika kunci grup itu sendiri adalah nama acara.
//            sectionKeys.sort() // Memanggil metode `sort()` default untuk array String.
//        case "keperluan":
//            // Urutkan kunci bagian secara alfabetis menaik berdasarkan properti `keperluan`
//            // dari entitas pertama di setiap grup. Ini mengatur section berdasarkan keperluan.
//            sectionKeys.sort { key1, key2 in
//                // Pastikan entitas pertama dan properti keperluan tersedia untuk kedua kunci.
//                guard let items1 = groupedData[key1]?.first?.keperluan?.value,
//                      let items2 = groupedData[key2]?.first?.keperluan?.value
//                else {
//                    return false // Jika tidak tersedia, urutan tidak diubah.
//                }
//                return items1 < items2 // Urutkan secara alfabetis menaik.
//            }
//        default:
//            // Jika kunci pengurutan yang diberikan tidak dikenal atau tidak didukung,
//            // tidak ada tindakan pengurutan yang akan dilakukan pada `sectionKeys`.
//            break
//        }
//    }

    /// Button untuk memunculkan ``DataSDI/CatatTransaksi`` dalam jendelah sheet ketika Toolbar ``DataSDI/WindowController/addDataToolbar`` tidak ditampilkan dari Toolbar.
    var addButton: NSButton!

    /// Menampilkan ``DataSDI/CatatTransaksi`` sebagai `NSPopOver`.
    @objc func addTransaksi(_ sender: Any) {
        let addDataViewController = CatatTransaksi(nibName: "CatatTransaksi", bundle: nil)
        // Ganti "AddDataViewController" dengan ID view controller yang benar
        // Buat instance NSPopover
        let popover = NSPopover()
        popover.contentViewController = addDataViewController
        popover.behavior = .semitransient

        // Tentukan titik tampilan untuk menempatkan popover
        ReusableFunc.resetMenuItems()
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
            if let jenis {
                addDataViewController.pilihjTransaksi.selectItem(withTitle: JenisTransaksi(rawValue: jenis)?.title ?? "Pemasukan")
                addDataViewController.pilihjTransaksi.isEnabled = false
            }
        }
    }

    /// Merespons aksi dari tombol "Tambah Data" (Add Data).
    ///
    /// Fungsi ini mencoba untuk mensimulasikan klik pada tombol "Tambah Data" yang ada di toolbar.
    /// Jika tombol toolbar ditemukan dan berhasil diklik, maka fungsi ini akan memicu aksi tombol toolbar tersebut.
    /// Jika tombol toolbar tidak ditemukan atau tidak dapat diklik, fungsi ini akan menampilkan
    /// `CatatTransaksi` sebagai sheet (lembar modal) untuk memasukkan data transaksi baru.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya tombol atau item menu.
    @IBAction func tambahData(_ sender: Any) {
        // Coba temukan toolbar dari jendela saat ini dan kemudian temukan item dengan identifier "add".
        if let toolbar = view.window?.toolbar,
           let addItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" })
        {
            // Jika `addButton` belum diinisialisasi, coba ambil NSButton dari `addItem.view`.
            if addButton == nil {
                addButton = addItem.view as? NSButton
            }

            // Jika `addButton` berhasil ditemukan (baik dari inisialisasi awal atau sekarang),
            // lakukan simulasi klik pada tombol tersebut.
            // Ini memungkinkan satu aksi (`tambahData`) untuk memicu aksi lain (`addItem.action`).
            addButton.performClick(sender)
        } else {
            // Jika tombol "Tambah Data" di toolbar tidak ditemukan atau tidak dapat diakses,
            // maka tampilkan `CatatTransaksi` sebagai sheet modal.

            // Buat instance `CatatTransaksi` dari NIB/XIB-nya.
            let addDataViewController = CatatTransaksi(nibName: "CatatTransaksi", bundle: nil)
            // Setel properti `sheetWindow` menjadi `true` pada view controller baru.
            // Ini kemungkinan memberi tahu `CatatTransaksi` untuk mengkonfigurasi dirinya
            // agar berfungsi dengan benar sebagai sheet.
            addDataViewController.sheetWindow = true

            // Buat `NSWindow` baru yang akan menampung `addDataViewController`.
            let window = NSWindow(contentViewController: addDataViewController)

            // Tampilkan jendela baru sebagai sheet pada jendela utama aplikasi.
            if let mainWindow = view.window {
                mainWindow.beginSheet(window, completionHandler: nil)
            }
        }
    }

    /// Muat ulang dan terapkan filter yang sedang aktif.
    /// - Parameter sender: Objek pemicu. bisa melalui ⌘R atau Menu Item klik kanan.
    @IBAction func muatUlang(_: Any) {
        if isGrouped {
            tampilanGroup()
        } else {
            applyFilters()
        }
    }

    /// Memperbarui tampilan data dan status UI berdasarkan kondisi aplikasi saat ini.
    ///
    /// Fungsi ini mengatur ulang teks label jenis transaksi ke "Semua Transaksi",
    /// memicu pemuatan ulang data koleksi jika dalam mode grup dan data sudah dimuat,
    /// serta menerapkan filter data di latar belakang. Ini juga mengatur ulang status filter jenis transaksi.
    @objc func perbaruiData() {
        // Atur teks label jenis transaksi menjadi "Semua Transaksi".
        jenisText.stringValue = "Semua Transaksi"

        /// Jika ``jenis`` adalah `nil` (tidak ada filter jenis aktif), data sudah dimuat,
        /// dan tampilan sedang dalam mode grup (``isGrouped``).
        if jenis == nil, isDataLoaded, isGrouped {
            // Tunda eksekusi ke main thread setelah sedikit penundaan.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
                // Muat ulang semua data di `collectionView`.
                collectionView.reloadData()

                // Tunda eksekusi lebih lanjut ke main thread lagi untuk memastikan layout diperbarui.
                DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
                    let title = "Pilih beberapa item untuk kalkulasi"
                    // Hitung ukuran teks yang dibutuhkan untuk judul baru.
                    let textSize = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

                    // Perbarui nilai string dari `jumlahTextField`.
                    jumlahTextField.stringValue = title
                    // Jika ada kendala lebar untuk `jumlahTextField`, animasikan perubahannya.
                    if let widthConstraint = jumlahTextFieldWidthConstraint {
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.2 // Durasi animasi 0.2 detik.
                            context.timingFunction = CAMediaTimingFunction(name: .linear) // Timing function linear.
                            widthConstraint.constant = textSize.width // Ubah lebar kendala sesuai ukuran teks.
                            self.jumlahTextField.alphaValue = 0.6 // Atur transparansi `jumlahTextField`.
                        } completionHandler: {
                            self.jumlahTextField.isSelectable = false // Nonaktifkan seleksi teks setelah animasi.
                        }
                    }
                }
            }
        }

        updateTitleWindow()

        // Pastikan `jenis` tidak `nil` sebelum melanjutkan untuk menerapkan filter.
        guard jenis != nil else { return }

        // Jalankan `applyFilters()` di task terpisah dengan prioritas latar belakang.
        // Ini menjaga UI tetap responsif saat operasi filter data yang mungkin memakan waktu.
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            await applyFilters()
        }

        jenis = nil // Setel `jenis` kembali ke `nil` untuk menghapus filter yang sedang aktif.
    }

    func updateTitleWindow() {
        let judul = jenisText.stringValue == "Semua Transaksi"
            ? "Transaksi"
            : jenisText.stringValue

        if tahun > 1, let window = view.window {
            window.title = judul + " " + "(\(String(tahun)))"
        } else {
            view.window?.title = judul
        }
    }

    // MARK: - GROUP MODE MENU ITEM

    /// Pengelompokan data ``groupData`` sesuai key yang diberikan (acara, kategori, atau keperluan)
    /// dan mengurutkan kata kunci di kamus ``groupData`` [kata kunci: [data administrasi]].
    /// - Parameter key: Kata kunci pengelompokan.
    func groupDataByType(key _: String) {
        groupedData.removeAll()

        for entity in groupData {
            var groupKey: String?

            // Sesuaikan logika untuk menentukan kunci grup berdasarkan jenis yang diberikan
            switch selectedGroup {
            case "acara":
                groupKey = entity.acara?.value
            case "kategori":
                groupKey = entity.kategori?.value
            case "keperluan":
                groupKey = entity.keperluan?.value
            default:
                break
            }

            if let groupKey {
                if groupedData[groupKey] == nil {
                    groupedData[groupKey] = []
                }
                groupedData[groupKey]?.append(entity)
            }
        }

        // Perbarui sectionKeys
        sectionKeys = Array(groupedData.keys.sorted())
        // sortSectionKeys(selectedGroup!)
    }

    /// Menampilkan item dalam mode grup.
    /// Action dari sub menu item yang terdapat di ``kelompokkanMenurut``.
    /// - Parameter sender: Objek pemicu harus merupakan `NSMenuItem`.
    @IBAction func selectGroup(_ sender: NSMenuItem) {
        guard sender.state == .off else { return }
        flowLayout.refreshing = true
        selectedGroup = sender.title.lowercased()
        isGroupMenuItemOn.toggle()
        tampilanGroup()
    }

    /// Simpan sections yang dicollapse.
    fileprivate var expandedSections: Set<Int> = .init()

    /// Mengurutkan data yang dikelompokkan dalam `collectionView` berdasarkan kriteria yang dipilih.
    ///
    /// Fungsi ini dipicu ketika pengguna memilih opsi pengurutan dari menu atau kontrol lainnya.
    /// Ini melakukan pengurutan data di *background thread* untuk menjaga UI tetap responsif,
    /// lalu memperbarui tampilan `collectionView` di *main thread* dan menyimpan preferensi pengurutan pengguna.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini, biasanya sebuah `NSMenuItem`.
    @IBAction func sortGroupedData(_ sender: Any?) {
        // Periksa apakah opsi pengurutan yang baru saja diklik sama dengan opsi pengurutan yang sedang aktif.
        // Jika ya, langsung keluar dari fungsi untuk menghindari pengurutan ulang yang tidak perlu.
        if let menuItem = sender as? NSMenuItem,
           menuItem.title.lowercased() == currentSortOption.lowercased()
        {
            return
        }

        // Jalankan operasi pengurutan di *background thread* untuk menjaga UI tetap responsif.
        dataProcessingQueue.async { [weak self] in
            guard let self else { return } // Pastikan instance self masih ada.

            var key: String // Kunci pengurutan yang akan digunakan (misalnya "tanggal", "kategori").
            var urutkan = false // Bendera untuk menentukan apakah akan melakukan reloadData penuh atau reloadItems.

            // Ambil kunci pengurutan dan bendera `urutkan` dari `sender`.
            if let button = sender as? NSMenuItem, let sortir = button.representedObject as? Bool {
                key = button.title.lowercased() // Kunci diambil dari judul item menu.
                urutkan = sortir // Bendera `urutkan` diambil dari `representedObject`.
            } else {
                // Jika `sender` bukan `NSMenuItem` atau `representedObject` tidak ada,
                // gunakan `currentSortOption` yang sudah ada.
                key = currentSortOption
            }

            // Simpan kunci pengurutan yang baru sebagai `currentSortOption`.
            currentSortOption = key
            // Dapatkan kriteria pengurutan spesifik berdasarkan kunci yang dipilih.
            let criteria = getSortingCriteria(for: key)

            // Urutkan setiap array entitas dalam `groupedData` (setiap section)
            // menggunakan kriteria yang telah ditentukan.
            groupedData = groupedData.mapValues { entities in
                entities.sorted { e1, e2 in
                    // Gunakan fungsi pembantu `compareElements` untuk perbandingan detail.
                    self.compareElements(e1, e2, criteria: criteria)
                }
            }

            // Simpan preferensi urutan pengurutan ke `UserDefaults` agar persisten.
            UserDefaults.standard.setValue(currentSortOption, forKey: "urutanTransaksi")

            // Pindah eksekusi ke *MainActor* (main thread) untuk memperbarui UI.
            DispatchQueue.main.async {
                if !urutkan {
                    for i in 0 ..< self.groupedData.keys.count {
                        self.expandedSections.insert(i)
                        self.flowLayout.collapseSection(at: i)
                    }
                    // Jika `urutkan` adalah `false`, muat ulang seluruh `collectionView`.
                    self.collectionView.reloadData()
                } else {
                    // Jika `urutkan` adalah `true`, lakukan pembaruan batch untuk reload item.
                    // Ini mungkin untuk animasi yang lebih halus atau jika hanya item di dalam section
                    // yang perlu diurutkan ulang tanpa mengubah urutan section itu sendiri.
                    let sortedSectionKeys = self.groupedData.keys.sorted() // Dapatkan kunci section yang diurutkan.
                    self.collectionView.performBatchUpdates({
                        for (section, groupKey) in sortedSectionKeys.enumerated() {
                            guard let items = self.groupedData[groupKey] else { continue }
                            // Buat `IndexPath` untuk semua item dalam section dan muat ulang.
                            let indexPaths = (0 ..< items.count).map { IndexPath(item: $0, section: section) }
                            self.collectionView.reloadItems(at: Set(indexPaths))
                        }
                    }, completionHandler: nil) // `completionHandler` diatur ke `nil` karena post-processing di `Task` berikutnya.
                }

                // MARK: Post-Processing UI (dengan penundaan)

                // Gunakan `Task` terpisah dengan penundaan untuk operasi UI yang terjadi setelah reload.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.createLineAtTopSection() // Panggil fungsi untuk membuat/memperbarui garis di section teratas.

                    if !urutkan {
                        // Jika bukan mode `urutkan` (yaitu `reloadData` penuh),
                        // hapus garis dari header section selain yang paling atas.
                        let sectionCount = self.collectionView.numberOfSections
                        for section in 1 ..< sectionCount {
                            if let oldHeaderView = self.collectionView.supplementaryView(
                                forElementKind: NSCollectionView.elementKindSectionHeader,
                                at: IndexPath(item: 0, section: section)
                            ) as? HeaderView {
                                oldHeaderView.removeLine() // Hapus garis visual dari header.
                            }
                        }

                        // Gulir tampilan ke posisi awal (y: -38) dalam `scrollView`.
                        let clipView = self.scrollView.contentView
                        let newPoint = NSPoint(x: clipView.bounds.origin.x, y: -38)
                        clipView.scroll(to: newPoint)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.flowLayout.refreshing = false // Setel status `refreshing` pada `flowLayout` menjadi `false`.
                    }
                }
            }
        }
    }

    /// Memperbarui status dan visibilitas item-item dalam menu aplikasi,
    /// terutama yang berkaitan dengan opsi pengelompokan dan pengurutan data.
    ///
    /// Fungsi ini menyesuaikan tampilan menu berdasarkan status filter (`jenis`)
    /// dan mode pengelompokan data (`isGrouped`) saat ini.
    func updateMenu() {
        // MARK: - Mengatur Visibilitas Item Menu Berdasarkan Filter 'jenis'

        // Jika filter `jenis` sedang aktif (yaitu, `jenis` tidak `nil`),
        // sembunyikan opsi "Gunakan Grup" dan "Kelompokkan Menurut" dari `unGroupMenu`.
        if jenis != nil {
            if let useGroupItem = unGroupMenu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.isHidden = true
            }
            if let groupByCategoryItem = unGroupMenu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                groupByCategoryItem.isHidden = true
            }
        } else {
            // Jika tidak ada filter `jenis` yang aktif, tampilkan kembali opsi-opsi tersebut.
            if let useGroupItem = unGroupMenu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.isHidden = false
            }
            if let groupByCategoryItem = unGroupMenu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                groupByCategoryItem.isHidden = false
            }
        }

        // MARK: - Mengatur Status Centang Item Menu Berdasarkan Mode Pengelompokan

        // Jika data sedang dalam mode dikelompokkan (`isGrouped`).
        if isGrouped {
            // Untuk setiap item dalam menu `kelompokkanMenurut`, atur status centangnya.
            // Item akan dicentang jika judulnya cocok dengan `selectedGroup` saat ini (case-insensitive).
            for item in kelompokkanMenurut.items {
                item.state = (item.title.lowercased() == selectedGroup.lowercased()) ? .on : .off
            }

            // Untuk setiap item dalam `groupMenu`, matikan semua centangnya.
            // Ini mungkin dilakukan sebelum mengatur ulang status centang untuk item spesifik.
            for item in groupMenu.items {
                item.state = .off
            }

            // Cari item "Gunakan Grup" di `groupMenu` dan atur status centangnya
            // sesuai dengan nilai `isGrouped` (yang seharusnya `.on` dalam blok ini).
            if let useGroupItem = groupMenu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.state = isGrouped ? .on : .off
            }

            // Untuk setiap item dalam `urutkanMenu`, atur status centangnya.
            // Item akan dicentang jika judulnya cocok dengan `currentSortOption` saat ini (case-insensitive).
            for item in urutkanMenu.items {
                item.state = (item.title.lowercased() == currentSortOption.lowercased()) ? .on : .off
            }
        } else {
            // Jika data tidak dalam mode dikelompokkan (`isGrouped` adalah `false`).
            // Untuk setiap item dalam `unGroupMenu`, matikan semua centangnya.
            // Ini memastikan tidak ada opsi pengelompokan yang dicentang saat tidak dalam mode grup.
            for item in unGroupMenu.items {
                item.state = .off
            }
        }
    }

    /// Memperbarui status dan judul item-item dalam menu konteks (context menu) untuk item `collectionView`.
    ///
    /// Fungsi ini menyesuaikan teks pada opsi menu "Edit", "Hapus", "Salin", dan "Tandai"
    /// berdasarkan jumlah item yang saat ini dipilih di `collectionView` dan status `ditandai` (marked) mereka.
    func updateItemMenu() {
        let selectedIndexes = collectionView.selectionIndexPaths // Dapatkan semua indeks item yang saat ini dipilih.
        var isDitandai = false // Variabel untuk melacak apakah item yang dipilih ditandai.

        // MARK: - Menentukan Status 'Ditandai'

        // Jika hanya satu item yang dipilih.
        if selectedIndexes.count == 1 {
            // Periksa apakah data dikelompokkan (`grupTransaksi` dari UserDefaults).
            if UserDefaults.standard.bool(forKey: "grupTransaksi") {
                let sortedSectionKeys = groupedData.keys.sorted() // Dapatkan kunci section yang diurutkan.
                let sectionIndex = selectedIndexes.first!.section // Indeks section dari item yang dipilih.
                let itemIndex = selectedIndexes.first!.item // Indeks item dari item yang dipilih.
                let jenisTransaksi = sortedSectionKeys[sectionIndex] // Kunci grup/jenis transaksi untuk section ini.

                // Ambil entitas dari `groupedData` dan periksa status `ditandai`-nya.
                if let entities = groupedData[jenisTransaksi], itemIndex < entities.count {
                    let entity = entities[itemIndex]
                    isDitandai = entity.ditandai // Setel `isDitandai` sesuai dengan properti entitas.
                } else {
                    // Handle kasus di mana entitas tidak ditemukan (misalnya, index out of bounds).
                    // Dalam kasus ini, `isDitandai` akan tetap `false`.
                }
            } else {
                // Jika data tidak dikelompokkan.
                let itemIndex = selectedIndexes.first!.item // Indeks item dari item yang dipilih.
                let entity = data[itemIndex] // Ambil entitas langsung dari array `data`.
                isDitandai = entity.ditandai // Setel `isDitandai` sesuai dengan properti entitas.
            }
        } else if selectedIndexes.count > 1 {
            // Jika lebih dari satu item dipilih.
            // `isDitandai` akan `true` hanya jika SEMUA item yang dipilih memiliki properti `ditandai` = `true`.
            isDitandai = selectedIndexes.allSatisfy { indexPath in
                if UserDefaults.standard.bool(forKey: "grupTransaksi") {
                    // Logika serupa dengan di atas untuk mode dikelompokkan.
                    let sortedSectionKeys = groupedData.keys.sorted()
                    let sectionIndex = indexPath.section
                    let itemIndex = indexPath.item
                    let jenisTransaksi = sortedSectionKeys[sectionIndex]
                    if let entities = groupedData[jenisTransaksi] {
                        return entities[itemIndex].ditandai
                    } else {
                        return false // Jika entitas tidak ditemukan, anggap tidak ditandai.
                    }
                } else {
                    // Logika serupa dengan di atas untuk mode tidak dikelompokkan.
                    return data[indexPath.item].ditandai
                }
            }
        }

        // MARK: - Memperbarui Judul Item Menu

        // Temukan item menu "Edit", "Hapus", dan "Salin" berdasarkan identifier mereka.
        if let editItem = itemMenu.items.first(where: { $0.identifier?.rawValue == "editItem" }),
           let deleteItem = itemMenu.items.first(where: { $0.identifier?.rawValue == "hapusItem" }),
           let copyItem = itemMenu.items.first(where: { $0.identifier?.rawValue == "salin" })
        {
            let count = collectionView.selectionIndexPaths.count // Jumlah item yang dipilih.

            // Perbarui judul item menu untuk mencerminkan jumlah item yang dipilih.
            copyItem.title = "Salin \(count) data..."
            editItem.title = "Edit \(count) data..."
            deleteItem.title = "Hapus \(count) data..."
        }

        // MARK: - Memperbarui Judul Item Menu 'Tandai'

        // Tentukan judul untuk item menu "Tandai" (markItemMenu) berdasarkan status `isDitandai`.
        // Jika semua item yang dipilih `ditandai`, judulnya akan menjadi "Hapus Tanda".
        // Jika tidak, judulnya akan menjadi "Tandai data...".
        let tandaiTitle = isDitandai ? "Hapus \(collectionView.selectionIndexPaths.count) Tanda" : "Tandai \(collectionView.selectionIndexPaths.count) data..."
        markItemMenu.title = tandaiTitle // Atur judul `markItemMenu`.
    }

    /// Menandai atau menghapus tanda pada item transaksi yang dipilih di `collectionView`.
    ///
    /// Fungsi ini akan meninjau item-item yang dipilih. Jika semua item yang dipilih sudah ditandai,
    /// maka fungsi ini akan menghapus tanda dari semua item tersebut. Sebaliknya, jika ada setidaknya satu
    /// item yang belum ditandai, maka fungsi ini akan menandai semua item yang dipilih.
    /// Pembaruan tampilan dilakukan secara batch dengan animasi, dan operasi ini juga mendukung fitur *undo*.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini.
    @IBAction func tandaiTransaksi(_: Any) {
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDieditNotif, object: nil)
        var itemsToEdit: [Entity] = [] // Akan menyimpan referensi ke entitas yang akan diubah.
        var uuid: [UUID] = [] // Akan menyimpan UUID dari entitas yang diubah untuk operasi undo.
        var undoItem: [EntitySnapshot] = [] // Akan menyimpan snapshot entitas sebelum perubahan untuk operasi undo.

        // Dapatkan semua `IndexPath` dari item yang dipilih di `collectionView`.
        let selectedIndexes = collectionView.selectionIndexPaths

        // Urutkan `selectedIndexes` dalam urutan menurun (dari bawah ke atas, dari section terakhir ke awal).
        // Ini penting untuk operasi penghapusan atau modifikasi pada koleksi yang mendasari
        // agar indeks tidak bergeser saat iterasi.
        let sortedSelectedIndexes = selectedIndexes.sorted {
            if $0.section == $1.section {
                return $0.item > $1.item // Dalam section yang sama, urutkan item secara menurun.
            }
            return $0.section > $1.section // Urutkan section secara menurun.
        }

        // MARK: - Mengumpulkan Data Item yang Dipilih

        // Iterasi melalui indeks yang sudah diurutkan untuk mengumpulkan entitas yang akan diubah
        // dan membuat snapshot untuk operasi undo.
        for indexPath in sortedSelectedIndexes {
            if isGrouped {
                // Jika dalam mode dikelompokkan:
                let sortedSectionKeys = groupedData.keys.sorted() // Dapatkan kunci section yang diurutkan.
                let jenisTransaksi = sortedSectionKeys[indexPath.section] // Dapatkan kunci grup untuk section ini.

                // Pastikan ada entitas di section ini dan indeks item valid.
                guard let entitiesInSection = groupedData[jenisTransaksi], indexPath.item < entitiesInSection.count else {
                    continue // Lewati jika data tidak valid.
                }
                let selectedEntity = entitiesInSection[indexPath.item]
                itemsToEdit.append(selectedEntity) // Tambahkan entitas ke daftar untuk diubah.
                uuid.append(selectedEntity.id ?? UUID()) // Tambahkan UUID entitas.
                undoItem.append(createSnapshot(from: selectedEntity)) // Buat snapshot untuk undo.
            } else {
                // Jika tidak dalam mode dikelompokkan:
                itemsToEdit.append(data[indexPath.item]) // Tambahkan entitas dari array data utama.
                uuid.append(data[indexPath.item].id ?? UUID()) // Tambahkan UUID entitas.
                undoItem.append(createSnapshot(from: data[indexPath.item])) // Buat snapshot untuk undo.
            }
        }

        // MARK: - Mengubah Status 'Ditandai' dan Memperbarui Data

        // Tentukan status baru untuk properti `ditandai`.
        // Jika *semua* item yang dipilih sudah ditandai (`allMarked` = true), maka `newMarkState` akan `false` (hapus tanda).
        // Jika tidak semua item ditandai (ada yang belum ditandai atau tidak ada sama sekali), maka `newMarkState` akan `true` (tandai semua).
        let allMarked = itemsToEdit.allSatisfy(\.ditandai)
        let newMarkState = !allMarked

        // Iterasi melalui `itemsToEdit` dan perbarui status `ditandai` menggunakan `DataManager`.
        // Diasumsikan `tandaiDataTanpaNotif` memperbarui data di penyimpanan tanpa memicu notifikasi koleksi.
        for entity in itemsToEdit {
            DataManager.shared.tandaiDataTanpaNotif(entity, tertandai: newMarkState)
        }

        // MARK: - Memperbarui Tampilan UI dan Mengelola Undo

        // Lakukan pembaruan batch pada `collectionView` untuk animasi yang halus.
        collectionView.performBatchUpdates({
            // Muat ulang item-item yang telah diubah statusnya.
            collectionView.reloadItems(at: Set(sortedSelectedIndexes))
        }, completionHandler: { [weak self] _ in
            guard let self else { return }
            // Setelah pembaruan selesai, pastikan item yang diubah tetap terpilih.
            collectionView.selectItems(at: Set(sortedSelectedIndexes), scrollPosition: [])

            // Daftarkan operasi undo untuk tindakan ini.
            // Jika undo dipicu, `undoMark` akan dipanggil dengan UUID dan snapshot asli item-item.
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                guard let self else { return }
                undoMark(uuid, snapshot: undoItem)
            })
            NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: ["uuid": Set(uuid)])
        })
        NotificationCenter.default.addObserver(self, selector: #selector(reloadEditedItems(_:)), name: DataManager.dataDieditNotif, object: nil)
    }

    /// Mengembalikan status 'ditandai' (marked) pada item-item transaksi ke keadaan sebelumnya
    /// sebagai bagian dari operasi 'undo'.
    ///
    /// Fungsi ini mengambil snapshot data asli dari item-item yang terpengaruh dan
    /// mengaplikasikan kembali status 'ditandai' mereka. Setelah data diperbarui,
    /// tampilan `collectionView` akan dimuat ulang untuk item-item yang relevan,
    /// dan operasi 'redo' yang sesuai akan didaftarkan.
    ///
    /// - Parameters:
    ///   - id: Sebuah array `UUID` yang berisi ID unik dari entitas-entitas yang statusnya akan di-undo.
    ///   - snapshot: Sebuah array `EntitySnapshot` yang berisi status entitas sebelum perubahan.
    func undoMark(_ id: [UUID], snapshot: [EntitySnapshot]) {
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDieditNotif, object: nil)
        var editedIndexPaths: Set<IndexPath> = [] // Set untuk menyimpan indexPath dari item yang diperbarui.
        var redoSnapShot: [EntitySnapshot] = [] // Akan menyimpan snapshot untuk operasi 'redo'.

        // Urutkan kunci-kunci grup/section yang ada.
        let sortedSectionKeys = groupedData.keys.sorted()

        // MARK: - Mengembalikan Status 'Ditandai' pada Data

        // Iterasi melalui setiap snapshot yang diberikan.
        for singleSnapshot in snapshot {
            // Ambil entitas yang sesuai dari `DataManager` menggunakan ID dari snapshot.
            if let entity = DataManager.shared.fetchData(by: singleSnapshot.id ?? UUID()) {
                // Buat snapshot dari status entitas saat ini untuk operasi 'redo'.
                redoSnapShot.append(createSnapshot(from: entity))
                // Kembalikan status 'ditandai' entitas ke nilai yang ada di snapshot asli.
                DataManager.shared.tandaiDataTanpaNotif(entity, tertandai: singleSnapshot.ditandai ?? false)
            }
        }

        // MARK: - Memperbarui Tampilan CollectionView

        // Lakukan pembaruan batch pada `collectionView` untuk animasi yang halus.
        collectionView.performBatchUpdates({
            if isGrouped {
                // Jika dalam mode dikelompokkan:
                // Iterasi melalui setiap section yang diurutkan.
                for (section, jenisTransaksi) in sortedSectionKeys.enumerated() {
                    guard let items = groupedData[jenisTransaksi] else {
                        continue // Lewati jika tidak ada item di section ini.
                    }

                    // Iterasi mundur melalui item di section.
                    for (itemIndex, entity) in items.enumerated().reversed() {
                        // Jika ID entitas cocok dengan salah satu ID yang di-undo:
                        if let entityId = entity.id, id.contains(entityId) {
                            let indexPath = IndexPath(item: itemIndex, section: section)
                            // Muat ulang item tersebut di `collectionView`.
                            collectionView.reloadItems(at: Set([indexPath]))
                            // Tambahkan indexPath ke set item yang telah diubah.
                            editedIndexPaths.insert(indexPath)
                        }
                    }
                }
            } else {
                // Jika tidak dalam mode dikelompokkan:
                // Buat set `IndexPath` untuk semua item yang ID-nya cocok.
                editedIndexPaths = Set(data.enumerated().compactMap { index, entity in
                    if let entityId = entity.id, id.contains(entityId) {
                        return IndexPath(item: index, section: 0) // Selalu section 0.
                    }
                    return nil
                })
                // Muat ulang semua item yang relevan.
                self.collectionView.reloadItems(at: editedIndexPaths)
            }
        }, completionHandler: { [weak self] _ in
            guard let self else { return }
            // Setelah pembaruan selesai, pilih item-item yang baru saja diubah dan gulir ke sana.
            // `invalidateLayout()` dipanggil jika tidak dikelompokkan untuk memastikan tata letak diperbarui,
            // meskipun dalam banyak kasus `reloadItems` sudah cukup.
            if !isGrouped {
                flowLayout.invalidateLayout()
                collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
            } else {
                collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
            }
            NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: ["uuid": Set(id)])
            NotificationCenter.default.addObserver(self, selector: #selector(reloadEditedItems(_:)), name: DataManager.dataDieditNotif, object: nil)
        })

        // MARK: - Mendaftarkan Operasi 'Redo'

        // Daftarkan operasi 'redo' untuk tindakan ini.
        // Jika 'redo' dipicu, `undoMark` akan dipanggil lagi dengan ID yang sama
        // tetapi menggunakan `redoSnapShot` (status setelah undo, yaitu status asli).
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoMark(id, snapshot: redoSnapShot)
        })
    }

    /// Mengubah mode tampilan `collectionView` antara mode dikelompokkan dan tidak dikelompokkan.
    ///
    /// Fungsi ini bertindak sebagai *action* untuk item menu yang mengontrol pengelompokan data.
    /// Sebelum mengubah mode, fungsi ini memeriksa apakah ada filter "jenis" yang aktif.
    /// Jika ada, pengguna akan diberi peringatan karena pengelompokan tidak tersedia saat filter aktif.
    /// Jika tidak ada filter, fungsi akan memanggil ``toggleGroupedMode(_:)`` untuk melakukan perubahan.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini (misalnya, item menu "Gunakan Grup").
    @IBAction func groupMode(_ sender: NSMenuItem) {
        // Periksa apakah properti `jenis` (filter aktif) sedang tidak nil.
        // Jika ada filter aktif, tampilkan peringatan kepada pengguna.
        searchWorkItem?.cancel()
        guard jenis == nil else {
            ReusableFunc.showAlert(title: "Tampilan grup tidak tersedia di \(JenisTransaksi(rawValue: jenis!)?.title ?? "")",
                                   message: "Pilih \"Transaksi\" di Panel Sisi terlebih dahulu untuk mengelompokkan data sebagai tampilan grup.")
            return // Hentikan eksekusi karena pengelompokan tidak diizinkan saat filter aktif.
        }

        // Jika tidak ada filter aktif, panggil fungsi `toggleGroupedMode`
        // untuk benar-benar mengubah mode pengelompokan tampilan data.
        let workItem = DispatchWorkItem { [weak self] in
            self?.toggleGroupedMode(sender)
        }

        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: searchWorkItem!)
    }

    /// Mengubah mode tampilan `collectionView` antara mode dikelompokkan dan tidak dikelompokkan.
    ///
    /// Fungsi ini dipicu ketika pengguna memilih opsi untuk mengubah mode pengelompokan.
    /// Jika data saat ini sedang dikelompokkan, fungsi akan beralih ke mode tidak dikelompokkan.
    /// Sebaliknya, jika data tidak dikelompokkan, fungsi akan beralih ke mode dikelompokkan
    /// dengan default pengelompokan berdasarkan "keperluan".
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @IBAction func toggleGroupedMode(_ sender: NSMenuItem) {
        if isGrouped {
            // Jika saat ini dalam mode dikelompokkan:
            isGroupMenuItemOn = false // Setel status item menu grup menjadi nonaktif.
            tampilanUnGrup() // Panggil fungsi untuk beralih ke tampilan tidak dikelompokkan.
            updateMenu() // Perbarui status menu lainnya sesuai dengan perubahan mode.
            selectedGroup = "" // Hapus grup yang dipilih karena tidak lagi dalam mode grup.
        } else {
            // Jika saat ini dalam mode tidak dikelompokkan:
            selectedGroup = "keperluan" // Setel grup default menjadi "keperluan" saat beralih ke mode grup.
            sender.state = .on // Nyalakan status centang pada item menu yang diklik.
            tampilanGroup() // Panggil fungsi untuk beralih ke tampilan dikelompokkan.
        }
    }

    deinit {
        searchWorkItem?.cancel()
        searchWorkItem = nil
        keperluanSearchWorkItem?.cancel()
        keperluanSearchWorkItem = nil
        acaraSearchWorkItem?.cancel()
        kategoriSearchWorkItem = nil
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDieditNotif, object: nil)
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .windowControllerClose, object: nil)
    }
}

extension TransaksiView: NSCollectionViewDataSource {
    // MARK: - NSCollectionViewDataSource

    /// Memberi tahu `collectionView` berapa banyak section (bagian) yang harus ditampilkan.
    func numberOfSections(in _: NSCollectionView) -> Int {
        // Jika `isGrouped` adalah `true`, jumlah section adalah jumlah kunci unik di `groupedData`.
        // Jika `isGrouped` adalah `false`, hanya ada satu section (default).
        isGrouped ? groupedData.keys.count : 1
    }

    /// Memberi tahu `collectionView` berapa banyak item yang harus ditampilkan dalam section tertentu.
    func collectionView(_: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        // Dapatkan kunci-kunci section yang diurutkan dari data yang dikelompokkan.
        let sortedSectionKeys = groupedData.keys.sorted()

        // Jika `isGrouped` adalah `true`, data ditampilkan dalam mode pengelompokan.
        if isGrouped {
            // Ambil kunci transaksi (nama grup) untuk section saat ini.
            let jenisTransaksi = sortedSectionKeys[section]
            // Kembalikan jumlah item dalam grup tersebut. Jika grup tidak ditemukan, kembalikan 0.
            return groupedData[jenisTransaksi]?.count ?? 0
        } else {
            // Jika `isGrouped` adalah `false`, semua item berada dalam satu section.
            // Kembalikan total jumlah item dari array `data` utama.
            return data.count
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("CollectionViewItem"), for: indexPath)
        if isGrouped {
            let sortedSectionKeys = groupedData.keys.sorted()

            // Validasi tambahan untuk memastikan indexPath.section valid
            guard indexPath.section < sortedSectionKeys.count else {
                return NSCollectionViewItem()
            }

            let jenisTransaksi = sortedSectionKeys[indexPath.section]

            // Validasi tambahan untuk memastikan indexPath.item valid
            guard let entities = groupedData[jenisTransaksi], indexPath.item < entities.count else {
                return NSCollectionViewItem()
            }

            if let entities = groupedData[jenisTransaksi] {
                let entity = entities[indexPath.item]

                if let customItem = item as? CollectionViewItem {
                    customItem.mytextField?.stringValue = entity.jenisEnum?.title ?? ""
                    customItem.jumlah?.doubleValue = entity.jumlah
                    customItem.kategori?.stringValue = entity.kategori?.value ?? ""
                    customItem.acara?.stringValue = entity.acara?.value ?? ""
                    customItem.keperluan?.stringValue = entity.keperluan?.value ?? ""

                    if let tanggalDate = entity.tanggal {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd-MM-yyyy"
                        customItem.tanggal?.stringValue = dateFormatter.string(from: tanggalDate)
                    } else {
                        customItem.tanggal?.stringValue = ""
                    }

                    // Tooltip untuk item collectionView
                    customItem.view.toolTip = "Jenis: \(entity.jenisEnum?.title ?? "")\nJumlah: \(entity.jumlah)\nKategori: \(entity.kategori?.value ?? "")\nAcara: \(entity.acara?.value ?? "")\nKeperluan: \(entity.keperluan?.value ?? "")"

                    // Pemanggilan metode untuk mengatur warna teks
                    customItem.updateTextColorForEntity(entity)

                    // Pemanggilan metode untuk menambahkan atau menghapus garis
                    customItem.updateMark(for: entity)

                    // Pemanggilan metode untuk mengatur gambar sesuai jenis transaksi
                    if let enumJenis = entity.jenisEnum {
                        customItem.setImageViewForTransactionType(enumJenis)
                    }
                }
                return item
            }
        } else {
            // Pemeriksaan item index yang valid untuk data
            // Ketika index melebihi jumlah data yang valid, langsung kembali untuk menghindari error indexPath out of range.
            guard indexPath.item < data.count else {
                return item
            }
            let entity = data[indexPath.item]
            if let customItem = item as? CollectionViewItem {
                customItem.mytextField?.stringValue = entity.jenisEnum?.title ?? ""
                customItem.jumlah?.doubleValue = entity.jumlah
                customItem.kategori?.stringValue = entity.kategori?.value ?? ""
                customItem.acara?.stringValue = entity.acara?.value ?? ""
                customItem.keperluan?.stringValue = entity.keperluan?.value ?? ""

                if let tanggalDate = entity.tanggal {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd-MM-yyyy"
                    customItem.tanggal?.stringValue = dateFormatter.string(from: tanggalDate)
                } else {
                    customItem.tanggal?.stringValue = ""
                }
                customItem.view.toolTip = "Jenis: \(entity.jenisEnum?.title ?? "")\nJumlah: \(entity.jumlah)\nKategori: \(entity.kategori?.value ?? "")\nAcara: \(entity.acara?.value ?? "")\nKeperluan: \(entity.keperluan?.value ?? "")"

                // Pemanggilan metode untuk mengatur warna teks
                customItem.updateTextColorForEntity(entity)

                // Pemanggilan metode untuk menambahkan atau menghapus garis
                customItem.updateMark(for: entity)

                // Pemanggilan metode untuk mengatur gambar sesuai jenis transaksi
                if let enumJenis = entity.jenisEnum {
                    customItem.setImageViewForTransactionType(enumJenis)
                }
            }
            return item
        }
        return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("CollectionViewItem"), for: indexPath)
    }
}

extension TransaksiView: NSCollectionViewDelegate {
    func collectionView(_: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        // Menghitung jumlah pemasukan dan pengeluaran pada item yang dipilih.
        if !isGrouped {
            DispatchQueue.main.async { [unowned self] in
                hitungTotalTerpilih(collectionView.selectionIndexPaths)
            }
        }

        return indexPaths
    }

    func collectionView(_: NSCollectionView, didSelectItemsAt _: Set<IndexPath>) {
        // Update menu item ketika ada item yang dipilih.
        NSApp.sendAction(#selector(TransaksiView.updateMenuItem(_:)), to: nil, from: self)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt _: Set<IndexPath>) {
        NSApp.sendAction(#selector(TransaksiView.updateMenuItem(_:)), to: nil, from: self)
        if !isGrouped {
            DispatchQueue.main.async { [unowned self] in
                // reset kalkulasi item yang dipilih.
                if collectionView.selectionIndexes.count < 1 {
                    let title = "Pilih beberapa item untuk kalkulasi"
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        let textSize = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

                        // Update string value jumlah
                        jumlahTextField.stringValue = title

                        // Update constraint untuk lebar textField
                        if let widthConstraint = jumlahTextFieldWidthConstraint {
                            NSAnimationContext.runAnimationGroup { context in
                                context.duration = 0.2 // Durasi animasi dalam detik
                                context.timingFunction = CAMediaTimingFunction(name: .linear) // Mengatur timing function
                                widthConstraint.constant = textSize.width // Mengubah lebar constraint
                                self.jumlahTextField.alphaValue = 0.6
                            } completionHandler: {
                                self.jumlahTextField.isSelectable = false
                            }
                        }
                    }
                } else {
                    hitungTotalTerpilih(self.collectionView.selectionIndexPaths)
                }
            }
        }
    }
}

extension TransaksiView: NSCollectionViewDelegateFlowLayout {
    /// Menggambar garis di bawah header jika header berada di topView clipView.
    /// Memanfaatkan fungsi yang telah dibuat dari ``CustomFlowLayout/findTopSection()``
    func createLineAtTopSection() {
        if let topSection = flowLayout.findTopSection() {
            if let headerView = collectionView.supplementaryView(
                forElementKind: NSCollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: topSection)
            ) as? HeaderView {
                headerView.createLine()
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, referenceSizeForHeaderInSection _: Int) -> NSSize {
        if isGrouped {
            // tinggi header adalah 30
            NSSize(width: collectionView.bounds.width, height: 30.0)
        } else {
            // tidak ada section di mode non-grup. setel tinggi menjadi 0
            CGSize.zero
        }
    }

    func collectionView(_: NSCollectionView, layout _: NSCollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        // jarak antar item adalah 20
        20
    }

    func collectionView(_: NSCollectionView, layout _: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        // jarak antara section adalah 20
        20
    }

    func collectionView(_: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt _: IndexPath) -> NSSize {
        // ukuran item, dihitung dari `flowLayout`.
        flowLayout.itemSize
    }

    func collectionView(_: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, insetForSectionAt section: Int) -> NSEdgeInsets {
        if isGrouped {
            guard let layout = collectionViewLayout as? CustomFlowLayout else {
                return NSEdgeInsets(top: 15, left: 20, bottom: 30, right: 20) // Default jika bukan custom layout
            }
            return layout.insetForSection(at: section)
        } else {
            guard let layout = collectionViewLayout as? CustomFlowLayout else {
                // Ketika visualEffect ditampilkan
                if hideTools.state == .on {
                    return NSEdgeInsets(top: visualEffect.bounds.maxY + 35, left: 20, bottom: 30, right: 20)
                } else {
                    // Ketika visualEffect disembunyikan.
                    return NSEdgeInsets(top: 20, left: 20, bottom: 30, right: 20)
                }
            }
            // Ketika visualEffect ditampilkan.
            if hideTools.state == .on {
                return NSEdgeInsets(top: visualEffect.bounds.maxY + 35, left: layout.sectionInset.left, bottom: layout.sectionInset.bottom, right: layout.sectionInset.right)
            } else {
                // Ketika visualEffect disembunyikan.
                return NSEdgeInsets(top: 20, left: layout.sectionInset.left, bottom: layout.sectionInset.bottom, right: layout.sectionInset.right)
            }
        }
    }

    func collectionView(_: NSCollectionView, didEndDisplayingSupplementaryView view: NSView, forElementOfKind _: NSCollectionView.SupplementaryElementKind, at _: IndexPath) {
        if let stickyHeader = view as? HeaderView {
            stickyHeader.removeFromSuperview()
        }
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind _: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        // Logika untuk header pada koleksi yang digroup
        let headerView = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderView"), for: indexPath) as! HeaderView
        let sortedSectionKeys = groupedData.keys.sorted()
        let sectionKeys = Array(groupedData.keys)

        if indexPath.section < sectionKeys.count {
            let kategoriTransaksi = sortedSectionKeys[indexPath.section]

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0

            // Hitung total pemasukan dan pengeluaran untuk semua transaksi dalam kategori ini
            var totalPengeluaran: Double = 0
            var totalPemasukan: Double = 0
            if let itemsInSection = groupedData[kategoriTransaksi] {
                for entity in itemsInSection {
                    if entity.jenis == JenisTransaksi.pengeluaran.rawValue {
                        totalPengeluaran += entity.jumlah
                    } else if entity.jenis == JenisTransaksi.pemasukan.rawValue {
                        totalPemasukan += entity.jumlah
                    }
                }
            }

            let totalPengeluaranFormatted = "Rp. " + (formatter.string(from: NSNumber(value: totalPengeluaran)) ?? "")
            let totalPemasukanFormatted = "Rp. " + (formatter.string(from: NSNumber(value: totalPemasukan)) ?? "")

            if let kategoriLabel = headerView.kategori {
                kategoriLabel.stringValue = kategoriTransaksi
            }
            headerView.jumlah?.stringValue = "Pemasukan: \(totalPemasukanFormatted) | Pengeluaran: \(totalPengeluaranFormatted)"
        }
        let context = NSCollectionViewFlowLayoutInvalidationContext()
        context.invalidateSupplementaryElements(ofKind: NSCollectionView.elementKindSectionHeader, at: [indexPath])
        flowLayout.invalidateLayout(with: context)

        headerView.tmblRingkas?.tag = indexPath.section
        headerView.tmblRingkas?.action = #selector(ringkasSection(_:))
        if expandedSections.contains(indexPath.section) {
            flowLayout.collapseSection(at: indexPath.section)
            expandedSections.remove(indexPath.section)
        }

        let itemCount = groupedData[sortedSectionKeys[indexPath.section]]?.count ?? 0
        if flowLayout.section(atIndexIsCollapsed: indexPath.section) {
            headerView.tmblRingkas?.title = " Tampilkan (\(itemCount))"
        } else {
            headerView.tmblRingkas?.title = " Ringkas"
        }
        return headerView
    }

    /// Mengubah status ringkas (collapse) atau tampil (expand) pada section `collectionView`.
    ///
    /// Fungsi ini dipicu ketika tombol ringkas/tampilkan di header section diklik.
    /// Ini akan memperbarui teks tombol dan memanggil metode untuk mengubah status collapse section.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini, diharapkan adalah `NSButton` dari header section.
    @objc func ringkasSection(_ sender: Any) {
        if let button = sender as? NSButton {
            let section = button.tag // Dapatkan section index dari tag

            // Periksa apakah section saat ini dalam kondisi terlipat (collapsed).
            if flowLayout.section(atIndexIsCollapsed: section) {
                button.title = " Ringkas"
                // Refresh collectionView
                collectionView.toggleSectionCollapse(sender)
                expandedSections.remove(section)
            }

            // Jika section sedang terbuka (expanded), ubah teks tombol menjadi " Tampilkan (jumlah item)".
            else {
                button.title = " Tampilkan (\(itemCountForSection(section)))"
                // Refresh collectionView
                collectionView.toggleSectionCollapse(sender)
                expandedSections.insert(section)
            }
        }
    }

    /// Mengembalikan jumlah item dalam section (bagian) tertentu dari data yang dikelompokkan.
    ///
    /// Fungsi ini digunakan untuk mengetahui berapa banyak item yang ada di dalam sebuah section
    /// berdasarkan indeks section yang diberikan, dengan asumsi data sedang dalam mode pengelompokan.
    ///
    /// - Parameter section: Indeks integer dari section yang ingin diketahui jumlah itemnya.
    /// - Returns: Jumlah item dalam section yang ditentukan. Akan mengembalikan 0 jika section tidak ditemukan
    ///   atau tidak memiliki item.
    func itemCountForSection(_ section: Int) -> Int {
        let sortedSectionKeys = groupedData.keys.sorted()
        return groupedData[sortedSectionKeys[section]]?.count ?? 0
    }

    /// tampilanUnGrup() adalah fungsi yang mengubah tampilan collectionView dari mode dikelompokkan (grouped) menjadi tidak dikelompokkan (ungrouped). Ini mereset tampilan dan data yang terkait dengan pengelompokan serta memperbarui elemen UI lainnya agar sesuai dengan mode tampilan yang baru.
    func tampilanUnGrup() {
        // Hanya lakukan pembaruan jika `groupedData` tidak kosong (yaitu, saat ini dalam mode grup).
        if !groupedData.isEmpty {
            // Lakukan pembaruan batch pada `collectionView` untuk animasi yang halus.
            collectionView.performBatchUpdates({
                // Hapus semua data yang dikelompokkan dari model.
                groupedData.removeAll()
                // Hapus semua section yang ada di `collectionView`.
                for i in 0 ..< collectionView.numberOfSections {
                    collectionView.deleteSections(IndexSet([i]))
                }
            }, completionHandler: { [weak self] _ in
                guard let self else { return }
                // Setelah pembaruan batch selesai, lakukan operasi UI di MainActor.
                // Pastikan `collectionView` menjadi first responder.
                view.window?.makeFirstResponder(collectionView)
                // Atur `automaticallyAdjustsContentInsets` pada `scrollView` menjadi `true`.
                scrollView.automaticallyAdjustsContentInsets = true

                // Jika ada search field di toolbar, kosongkan string-nya.
                if let toolbar = view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                {
                    searchFieldToolbarItem.searchField.stringValue.removeAll()
                }

                // Jika tidak ada filter jenis yang aktif, terapkan filter (yang akan memuat ulang data tidak dikelompokkan).
                if jenis == nil { applyFilters() }

                // Pastikan section pertama (indeks 0) diperluas.
                flowLayout.expandSection(at: 0)
                // Setel status `isGrouped` menjadi `false`.
                isGrouped = false
                // Sembunyikan alat bantu yang mungkin hanya relevan di mode grup.
                hideTools(self)
                // Simpan preferensi pengguna bahwa mode grup dinonaktifkan.
                UserDefaults.standard.setValue(false, forKey: "grupTransaksi")

                // Perbarui `urutkanPopUp` untuk mencerminkan opsi pengurutan saat ini.
                urutkanPopUp.selectItem(withTitle: currentSortOption.capitalized.trimmingCharacters(in: .whitespacesAndNewlines))
                urutkanPopUp.selectedItem?.state = .on
                // Pastikan semua item menu di `urutkanPopUp` memiliki status centang yang benar.
                if let menuItems = urutkanPopUp.menu?.items {
                    for item in menuItems {
                        item.state = (item.title.lowercased() == currentSortOption) ? .on : .off
                    }
                }
                // Atur status item menu grup di `AppDelegate` menjadi nonaktif.
                AppDelegate.shared.groupMenuItem.state = .off
            })
        } else {
            // Jika `groupedData` sudah kosong (sudah dalam mode tidak dikelompokkan),
            // tetap lakukan operasi UI yang diperlukan untuk memastikan konsistensi.
            view.window?.makeFirstResponder(collectionView)
            scrollView.automaticallyAdjustsContentInsets = true
            if let toolbar = view.window?.toolbar,
               let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
            {
                searchFieldToolbarItem.searchField.stringValue.removeAll()
            }
            if jenis == nil { applyFilters() }
            flowLayout.expandSection(at: 0)
            isGrouped = false
            hideTools(self)
            UserDefaults.standard.setValue(false, forKey: "grupTransaksi")
            urutkanPopUp.selectItem(withTitle: currentSortOption.capitalized.trimmingCharacters(in: .whitespacesAndNewlines))
            urutkanPopUp.selectedItem?.state = .on
            if let menuItems = urutkanPopUp.menu?.items {
                for item in menuItems {
                    item.state = (item.title.lowercased() == currentSortOption) ? .on : .off
                }
            }
            // Sembunyikan garis horizontal di bagian atas jika ada.
            hlinetop.isHidden = true
            // Atur status item menu grup di `AppDelegate` menjadi nonaktif.
            AppDelegate.shared.groupMenuItem.state = .off
        }
    }

    /// Perbarui tampilan collectionView menjadi tampilan non-grup.
    func tampilanGroup() {
        // Bagian ini hanya dijalankan jika saat ini TIDAK dalam mode grup (`isGrouped` adalah `false`).
        // Ini adalah inisialisasi UI saat beralih ke mode grup.
        if !isGrouped {
            let title = "Pilih beberapa item untuk kalkulasi"
            // Hitung ukuran teks yang dibutuhkan untuk judul baru.
            let textSize = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: jumlahTextField.font!])

            // Perbarui nilai string dari `jumlahTextField`.
            jumlahTextField.stringValue = title

            // Jika ada kendala lebar untuk `jumlahTextField`, perbarui.
            if let widthConstraint = jumlahTextFieldWidthConstraint {
                widthConstraint.constant = textSize.width // Ubah lebar kendala sesuai ukuran teks.
            }
            jumlahTextField.isSelectable = false // Nonaktifkan seleksi teks.
            jumlahTextField.alphaValue = 0.6 // Atur transparansi.
            collectionView.deselectAll(nil) // Batalkan semua pilihan di `collectionView`.
            hlinetop.isHidden = true // Sembunyikan garis atas.
            hlinebottom.isHidden = true // Sembunyikan garis bawah.
            visualEffect.isHidden = true // Sembunyikan efek visual.
            hideTools.isHidden = true // Sembunyikan alat bantu.
        }

        // Lakukan pembaruan batch pada `collectionView` untuk animasi yang halus.
        collectionView.performBatchUpdates({
            // Jika sedang beralih dari mode *tidak dikelompokkan* ke mode dikelompokkan:
            if !isGrouped {
                data.removeAll() // Hapus semua data dari model data tidak dikelompokkan.
                // Hapus semua item dari section 0 di `collectionView`.
                for i in 0 ..< collectionView.numberOfItems(inSection: 0) {
                    let index = IndexPath(item: i, section: 0)
                    collectionView.deleteItems(at: Set([index]))
                }
            } else {
                // Jika saat ini sudah dalam mode dikelompokkan (ini mungkin terjadi jika fungsi dipanggil ulang
                // tanpa perubahan `isGrouped` sebelumnya, atau jika ada logika reset):
                groupedData.removeAll() // Hapus semua data dari model data dikelompokkan.
                // Hapus semua section dari `collectionView`.
                for i in 0 ..< collectionView.numberOfSections {
                    collectionView.deleteSections(IndexSet([i]))
                }
            }
        }, completionHandler: { [weak self] _ in
            // Setelah pembaruan batch selesai, lakukan operasi di background Task, lalu kembali ke MainActor.
            self?.dataProcessingQueue.async { [weak self] in
                guard let self else { return }
                jenis = nil // Setel filter jenis menjadi `nil`.
                // Ambil semua data dari `DataManager`. Ini akan menjadi data dasar untuk pengelompokan.
                let currentFilter = tahun >= 1000
                    ? Int16(tahun)
                    : nil
                groupData = DataManager.shared.fetchData(tahun: currentFilter)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    // Jika `groupData` kosong (tidak ada data untuk dikelompokkan), tampilkan peringatan.
                    guard !groupData.isEmpty else {
                        tahun = 0
                        tahunPopUp.selectItem(withTitle: "Tahun")
                        ReusableFunc.showAlert(title: "Data Kosong", message: "Tidak dapat mengelompokkan dokumen transaksi. Data tidak ditemukan. Filter direset.")
                        tampilanUnGrup()
                        return
                    }

                    // Lanjutkan jika ada data untuk dikelompokkan.
                    scrollView.scrollerInsets.top = 0 // Atur insets atas scroller.

                    // Kosongkan string pada search field di toolbar.
                    if let toolbar = view.window?.toolbar,
                       let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                    {
                        searchFieldToolbarItem.searchField.stringValue.removeAll()
                    }

                    scrollView.automaticallyAdjustsContentInsets = false // Nonaktifkan penyesuaian insets otomatis.
                    // Guard ini memastikan kode hanya berjalan jika `isGrouped` adalah `false` saat ini.
                    // Ini mencegah pengulangan operasi jika sudah dalam mode grup.
                    guard !isGrouped else { return }

                    // Simpan preferensi pengguna bahwa mode grup diaktifkan.
                    UserDefaults.standard.setValue(true, forKey: "grupTransaksi")
                    hlinetop.isHidden = true // Sembunyikan garis atas.
                    hlinebottom.isHidden = true // Sembunyikan garis bawah.
                    visualEffect.isHidden = true // Sembunyikan efek visual.
                    isGrouped = true // Setel status `isGrouped` menjadi `true`.
                    AppDelegate.shared.groupMenuItem.state = .on // Nyalakan status centang pada item menu grup di `AppDelegate`.
                }
            }
        })
    }

    /// Konfigurasi action dan target di toolbar jendela saat ini.
    func setupToolbar() {
        guard let toolbar = view.window?.toolbar else { return }
        if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem {
            let searchField = searchFieldToolbarItem.searchField
            searchField.isEnabled = true
            searchField.isEditable = true
            searchField.target = self
            searchField.action = #selector(procSearchFieldInput(sender:))
            searchField.delegate = self
            searchFieldToolbarItem.searchField.stringValue = "Cari \(JenisTransaksi(rawValue: jenis ?? -1)?.title ?? "adminstrasi")..."
        }

        if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
           let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
        {
            kalkulasiNilai.isEnabled = false
        }

        if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
           let tambah = tambahToolbarItem.view as? NSButton
        {
            tambah.isEnabled = false
        }

        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = true
            hapus.target = self
            hapus.action = #selector(hapus(_:))
        }

        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            edit.isEnabled = true
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
            add.toolTip = "Tambahkan Data Transaksi Baru"
            addToolbarItem.toolTip = "Tambahkan Data Transaksi Baru"
            add.isEnabled = true
            addButton = add
        }

        if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
           let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton
        {
            popUpButton.menu = toolbarMenu
        }
    }

    /// Fungsi untuk mereset target dan action menu item ke nilai aslinya.
    @objc func updateMenuItem(_: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
           let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
           let fileMenu = mainMenu.item(withTitle: "File"),
           let fileMenuItem = fileMenu.submenu,
           let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" })
        {
            let isItemSelected = collectionView.selectionIndexPaths.count > 0
            pasteMenuItem.target = self
            pasteMenuItem.action = #selector(paste(_:))

            deleteMenuItem.isEnabled = isItemSelected
            if isItemSelected {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(copyAction(_:))
                deleteMenuItem.target = self
                deleteMenuItem.action = #selector(hapus(_:))
            } else {
                deleteMenuItem.target = nil
                deleteMenuItem.action = nil
                copyMenuItem.target = nil
                copyMenuItem.action = nil
            }
            // Mendapatkan NSTableView aktif
            new.target = self
            new.action = #selector(tambahData(_:))
        }
    }
}

extension TransaksiView: NSSearchFieldDelegate, NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        if (obj.object as? NSSearchField) != nil {
            updateUndoRedo()
        }
    }

    func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if control is NSSearchField {
                true
            } else {
                false
            }
        } else {
            false
        }
    }
}

extension TransaksiView: NSGestureRecognizerDelegate {
    /// Menangani klik kanan pada `collectionView` untuk menampilkan menu konteks yang sesuai.
    ///
    /// Fungsi ini mendeteksi lokasi klik kanan dan menentukan apakah klik tersebut
    /// berada di atas sebuah item dalam `collectionView`. Berdasarkan mode tampilan (dikelompokkan atau tidak),
    /// ia akan menampilkan menu konteks yang relevan untuk item yang dipilih atau untuk seluruh tampilan.
    ///
    /// - Parameter sender: `NSClickGestureRecognizer` yang mendeteksi klik kanan.
    @objc func handleRightClick(_ sender: NSClickGestureRecognizer) {
        // Dapatkan lokasi klik dalam koordinat `collectionView`.
        let pointInCollectionView = sender.location(in: collectionView)

        // Coba dapatkan `indexPath` dari item di lokasi klik.
        if let indexPathAtPoint = collectionView.indexPathForItem(at: pointInCollectionView) {
            // Jika klik kanan berada di atas sebuah item:
            if isGrouped {
                // Jika data dikelompokkan, panggil penangan khusus untuk klik kanan pada item dalam grup.
                handleGroupedRightClick(at: indexPathAtPoint)
            } else {
                // Jika data tidak dikelompokkan, panggil penangan khusus untuk klik kanan pada item yang tidak dikelompokkan.
                handleUngroupedRightClick(at: indexPathAtPoint)
            }
            // Perbarui item-item di menu konteks (misalnya, judul "Edit X data...").
            updateItemMenu()
            // Tampilkan menu konteks item (`itemMenu`) pada lokasi klik.
            NSMenu.popUpContextMenu(itemMenu, with: NSApp.currentEvent!, for: collectionView)
        } else {
            // Jika klik kanan tidak berada di atas item apa pun (klik di area kosong `collectionView`):
            // Perbarui menu umum.
            updateMenu()
            if isGrouped {
                // Jika data dikelompokkan, tampilkan menu konteks khusus grup (`groupMenu`).
                NSMenu.popUpContextMenu(groupMenu, with: NSApp.currentEvent!, for: collectionView)
            } else {
                // Jika data tidak dikelompokkan, tampilkan menu konteks tidak dikelompokkan (`unGroupMenu`).
                NSMenu.popUpContextMenu(unGroupMenu, with: NSApp.currentEvent!, for: collectionView)
            }
        }
    }

    /// Fungsi ini menangani kejadian klik kanan pada item di dalam collectionView ketika data sedang dalam mode dikelompokkan. Tujuannya adalah untuk memastikan bahwa item yang diklik kanan tersebut menjadi satu-satunya item yang terpilih, jika sebelumnya belum terpilih.
    /// - Parameter indexPath: indexPath item di collectionView yang diklik.
    func handleGroupedRightClick(at indexPath: IndexPath) {
        /// indexPaths collectionView yang dipilih.
        let selectedIndexPaths = collectionView.selectionIndexPaths

        if !selectedIndexPaths.contains(indexPath) {
            // Item belum terpilih, deselect semua dan pilih item ini
            collectionView.deselectAll(nil)
            collectionView.selectItems(at: [indexPath], scrollPosition: [])
        }
    }

    /// Fungsi yang menangani klik kanan dalam mode non-grup.
    /// - Parameter indexPath: indexPath item di collectionView yang diklik.
    func handleUngroupedRightClick(at indexPath: IndexPath) {
        // Dapatkan set indeks dari semua item yang saat ini terpilih di `collectionView`.
        // Perhatikan bahwa dalam mode tidak dikelompokkan, `indexPath.item` sudah cukup
        // karena hanya ada satu section (section 0).
        let currentlySelectedIndexes = collectionView.selectionIndexes

        // Periksa apakah item yang diklik kanan (berdasarkan `indexPath.item`-nya)
        // belum termasuk dalam set item yang sedang terpilih.
        if !currentlySelectedIndexes.contains(indexPath.item) {
            // Jika item belum terpilih:
            // 1. Batalkan semua pilihan yang ada di `collectionView`.
            collectionView.deselectAll(nil)
            // 2. Pilih hanya item yang baru saja diklik kanan.
            collectionView.selectItems(at: [indexPath], scrollPosition: [])
        }
        // Jika item yang diklik kanan sudah terpilih (baik sebagai satu-satunya item atau bagian dari
        // multiple selection), fungsi ini tidak melakukan apa-apa, membiarkan pilihan yang ada tetap utuh.
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        // Dapatkan titik klik
        let pointInCollectionView = gestureRecognizer.location(in: collectionView)
        let sectionIndexPaths = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: NSCollectionView.elementKindSectionHeader)

        // Cek apakah titik klik berada di atas HeaderView dengan cara iterasi semua seleksi.
        for indexPath in sectionIndexPaths {
            if let headerView = collectionView.supplementaryView(forElementKind: NSCollectionView.elementKindSectionHeader, at: indexPath) as? HeaderView {
                headerView.tmblRingkas.tag = indexPath.section
                if headerView.frame.contains(pointInCollectionView) {
                    // Klik terjadi di atas HeaderView, jangan jalankan gesture recognizer
                    return false
                }
            }
        }
        let indexPathAtPoint = collectionView.indexPathForItem(at: pointInCollectionView)
        // Jika pengguna mengklik item, gesture recognizer tidak dijalankan
        return indexPathAtPoint == nil
    }

    /// Fungsi ini dipanggil saat klik terdeteksi di luar area item dalam collectionView. Tujuannya adalah untuk menghilangkan semua pilihan item jika tidak ada item yang diklik secara langsung.
    /// - Parameter sender: `NSClickGestureRecognizer` pendeteksi klik.
    @objc func handleTapOutside(_ sender: NSClickGestureRecognizer) {
        let pointInCollectionView = sender.location(in: collectionView)
        let indexPathAtPoint = collectionView.indexPathForItem(at: pointInCollectionView)
        if indexPathAtPoint == nil {
            // Tidak ada item yang diklik, kosongkan selectionIndexes dan jalankan animasi
            collectionView.deselectAll(nil)
        }
    }
}
