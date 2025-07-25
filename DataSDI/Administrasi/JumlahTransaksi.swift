//
//  JumlahTransaksi.swift
//  Data Manager
//
//  Created by Bismillah on 16/11/23.
//

import Cocoa
import CoreData

/// `JumlahTransaksi` adalah class yang mengelola tampilan dan interaksi dengan data transaksi administrasi.
/// Class ini bertanggung jawab untuk menampilkan jumlah transaksi, baik pemasukan maupun pengeluaran,
class JumlahTransaksi: NSViewController {
    @IBOutlet weak var saldoSekarang: NSTextField!
    /// Jumlah pemasukan. diset di ``muatSaldoData(_:)``
    @IBOutlet weak var masuk: NSTextField!
    /// Jumlah pengeluaran. diset di ``muatSaldoData(_:)``
    @IBOutlet weak var keluar: NSTextField!
    /// Jumlah surplus saldo. diset di ``muatSaldoData(_:)``
    @IBOutlet weak var jumlah: NSTextField!
    /// Outlet Tabel dari XIB.
    @IBOutlet weak var tableView: NSTableView!
    /// Outlet ScrollView yang menampung Tabel dari XIB.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Lihat: ``DataSDI/DataManager/managedObjectContext``
    let privateContext = DataManager.shared.managedObjectContext

    /// Menyimpan grup yang sedang digunakan untuk memfilter data. Default: Keperluan.
    ///
    /// Digunakan untuk menghandle perubahan filter grup seperti memperbarui nama kolom pertama dan kedua.
    var selectedGroupCategory: String = "keperluan"

    /// Data yang ditampilkan di dalam tabel.
    ///
    /// `title:` adalah kolom grup yang sedang digunakan untuk pengelompokan
    /// `entities:` adalah Array dari data-data administrasi di dalam title.
    var dataSections: [(title: String, entities: [Entity])] = []

    /// Menyimpan beberapa Menu Item klik kanan.
    var categoryMenuItems: [NSMenuItem] = []

    /// Referensi untuk format nomor untuk menghandle angka supaya tidak diinisialisasi terus menerus.
    ///
    /// Seperti:
    /// - Menambahkan titik setelah 3 angka.
    /// - Menambahkan ,- setelah angka terakhir.
    let formatter = NumberFormatter()

    /// Kolom pertama sebelumnya yang dipin di topView clipView.
    ///
    /// Berguna untuk mengetahui apakah nama kolom pertama sama ketika scrolling.
    /// - Ketika nama kolom pertama berbeda dengan kolom selanjutnya ketika scrolling, ``scrollViewDidScroll(_:)`` akan memperbarui nama kolom pertama dengan nama kolom pertama berikutnya yang sedang discroll.
    var previousColumnTitle: String?

    /// Membuat salinan NSTableHeaderView saat scrolling dan topView akan berpindah section.
    var nextSectionHeaderView: NSTableHeaderView?

    /// Format tanggal untuk tanggal pembuatan data administrasi.
    var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    /// Thread dispatch khsusus untuk fetch data administrasi di CoreData.
    let dataProcessingQueue = DispatchQueue(label: "com.sdi.DataProcessing", attributes: .concurrent)

    /// Referensi proses pemuatan data tabel.
    ///
    /// Diset ke true ketika data sudah dimuat.
    var isDataLoaded: Bool = false

    /// IndexSet untuk menyimpan baris-baris yang dipilih jika baris tersebut merupakan data yang diberi tanda.
    lazy var tertanda: IndexSet = []

    /// Deprecated. Sebelumnya digunakan jika tab bar ditampilkan untuk handle proses scrolling.
    var tabBarFrame: CGFloat = 0

    /// Menu di toolbar yang digunakan untuk handle tampilan class.
    var toolbarMenu = NSMenu()

    /// SortDescriptor yang digunakan untuk mengurutkan data tabel sesuai kolom.
    var currentSortDescriptor: NSSortDescriptor?

    /// Constraint top ``labelStack``.
    @IBOutlet weak var stackViewTopConstraint: NSLayoutConstraint!

    /// Diperlukan oleh ``DataSDI/MyHeaderCell`` dan diset dari ``tableView(_:sortDescriptorsDidChange:)``
    ///
    /// Memeriksa apakah tabel sedang diurutkan pada kolom pertama.
    /// Jika tabel diurutkan pada kolom pertama. Semua teks di section group akan menggunakan teks tebal.
    var isSortedByFirstColumn: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        jumlah.alphaValue = 0
        masuk.alphaValue = 0
        keluar.alphaValue = 0
        saldoSekarang.alphaValue = 0.6
        let menu = buatItemMenu()
        toolbarMenu = buatItemMenu()
        toolbarMenu.delegate = self
        menu.delegate = self
        tableView.menu = menu
        setupDescriptor()
        if let firstColumn = tableView.tableColumns.first(where: { $0.identifier.rawValue == "Column1" }),
           let sortDescriptor = firstColumn.sortDescriptorPrototype {
            tableView.sortDescriptors = [sortDescriptor]
        }
    }

    /// Notifikasi ketika data diedit dari ``DataSDI/TransaksiView``
    ///
    /// Memperbarui data dan tabel.
    @objc func dataDieditNotif(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uuids = userInfo["uuid"] as? Set<UUID>
        else { return }
        let group = DispatchGroup()
        group.enter()
        for uuid in uuids {
            reloadRow(forUUID: uuid, in: tableView)
        }
        group.leave()

        group.notify(queue: .global(qos: .unspecified)) { [weak self] in
            self?.privateContext.perform { [weak self] in
                self?.updateSaldo()
            }
        }
    }

    /// Notifikasi ketika ada data baru yang ditambahkan dari ``DataSDI/TransaksiView``
    ///
    /// Memperbarui data dan tabel.
    @objc func dataDitambahNotif(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newData = userInfo["data"] as? Entity,
              let sortDescriptor = tableView.sortDescriptors.first
        else { return }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        // Tentukan section berdasarkan `selectedGroupCategory`
        let sectionKey = switch selectedGroupCategory {
        case "keperluan":
            "  \(newData.keperluan?.value ?? "Lainnya")"
        case "acara":
            "  \(newData.acara?.value ?? "Lainnya")"
        case "kategori":
            "  \(newData.kategori?.value ?? "Lainnya")"
        default:
            "Lainnya"
        }

        // Cek apakah data sudah ada di `dataSections`
        if let sectionIndex = dataSections.firstIndex(where: { $0.title == sectionKey }),
           dataSections[sectionIndex].entities.contains(where: { $0.id == newData.id })
        {
            dispatchGroup.leave()
            // Data sudah ada, tidak perlu ditambahkan
            return
        }

        // Tambahkan data ke `dataSections`
        if let sectionIndex = dataSections.firstIndex(where: { $0.title == sectionKey }), let insertIndex = insertionIndex(for: newData, in: sectionIndex, using: sortDescriptor) {
            // Tambahkan ke section yang sudah ada
            dataSections[sectionIndex].entities.insert(newData, at: insertIndex)
            let absoluteRowIndex = calculateAbsoluteRowIndex(for: sectionIndex, rowIndex: insertIndex)
            dispatchGroup.leave()

            dispatchGroup.notify(queue: .main) { [weak self] in
                // Insert row ke NSTableView
                self?.tableView.insertRows(at: IndexSet(integer: absoluteRowIndex), withAnimation: [])
            }
        } else {
            // Tambahkan section baru
            let hiddenRows = tableView.hiddenRowIndexes
            let newSection = (title: sectionKey, entities: [newData])
            dataSections.append(newSection)
            dataSections.sort { $0.title < $1.title } // Pastikan terurut
            if let section = dataSections.firstIndex(where: { $0.title == sectionKey }), let sectionIndex = findRowForSection(section) {
                let rowToInsert = [sectionIndex, sectionIndex + 1]
                dispatchGroup.leave()

                dispatchGroup.enter()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { dispatchGroup.leave(); return }
                    self.tableView.beginUpdates()
                    if sectionIndex == 0 {
                        self.tableView.unhideRows(at: hiddenRows, withAnimation: [])
                        self.tableView.reloadData(forRowIndexes: hiddenRows, columnIndexes: IndexSet(integersIn: 0 ..< self.tableView.numberOfColumns))
                    }
                    self.tableView.insertRows(at: IndexSet(rowToInsert), withAnimation: [])
                    if sectionIndex == 0 {
                        self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
                        if let headerView = self.tableView.headerView {
                            self.updateHeaderTitle(for: 0, in: headerView)
                            self.tableView.scrollRowToVisible(1)
                        }
                    }
                    dispatchGroup.leave()
                    self.tableView.endUpdates()
                }
            }
        }

        dispatchGroup.notify(queue: .global(qos: .unspecified)) { [weak self] in
            self?.privateContext.perform { [weak self] in
                self?.updateSaldo()
            }
        }
    }

    /// Notifikasi ketika ada data yang dihapus dari ``DataSDI/TransaksiView``
    ///
    /// Memperbarui data dan tabel.
    @objc func handleEntitiesDeleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let deletedEntities = userInfo["deletedEntity"] as? [Entity] else { return }
        let group = DispatchGroup()
        var rowsToRemove: [Int] = []
        group.enter()
        // Loop melalui entitas yang dihapus
        for deletedEntity in deletedEntities {
            let sectionKey = switch selectedGroupCategory {
            case "keperluan":
                "  \(deletedEntity.keperluan?.value ?? "Lainnya")"
            case "acara":
                "  \(deletedEntity.acara?.value ?? "Lainnya")"
            case "kategori":
                "  \(deletedEntity.kategori?.value ?? "Lainnya")"
            default:
                "Lainnya"
            }
            if let sectionIndex = dataSections.firstIndex(where: { $0.title == sectionKey }),
               let rowIndex = dataSections[sectionIndex].entities.firstIndex(where: { $0.id == deletedEntity.id })
            {
                // Hapus dari dataSections
                dataSections[sectionIndex].entities.remove(at: rowIndex)
                if dataSections[sectionIndex].entities.isEmpty {
                    if let firstRow = findRowForSection(sectionIndex) {
                        if firstRow >= 0, firstRow < tableView.numberOfRows {
                            rowsToRemove.append(firstRow)
                        }
                        dataSections.remove(at: sectionIndex)
                    }
                }

                // Hitung indeks absolut untuk NSTableView
                let absoluteRowIndex = calculateAbsoluteRowIndex(for: sectionIndex, rowIndex: rowIndex)
                if absoluteRowIndex >= 0, absoluteRowIndex < tableView.numberOfRows {
                    rowsToRemove.append(absoluteRowIndex)
                }
            }
        }
        // Hapus baris dari NSTableView dalam urutan terbalik
        rowsToRemove.sort(by: >) // Urutkan secara descending
        group.leave()

        group.enter()
        DispatchQueue.main.async { [weak self] in
            self?.tableView.beginUpdates()
            self?.tableView.removeRows(at: IndexSet(rowsToRemove), withAnimation: [])
            self?.tableView.endUpdates()
            group.leave()
        }

        group.notify(queue: .global(qos: .unspecified)) { [weak self] in
            self?.privateContext.perform { [weak self] in
                self?.updateSaldo()
            }
            DispatchQueue.main.async {
                guard let self, self.tableView.numberOfRows > 0 else { return }
                self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
            }
        }
    }

    /// Memuat ulang baris yang diperbarui dari ``DataSDI/TransaksiView``.
    /// - Parameters:
    ///   - uuid: UUID unik data administrasi.
    ///   - tableView: Tabel yang menampilkan data administrasi.
    func reloadRow(forUUID uuid: UUID, in tableView: NSTableView) {
        var rowIndex: Int? = nil
        var currentRow = 0
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        // Cari rowIndex berdasarkan UUID
        for section in dataSections {
            // Header row
            currentRow += 1

            // Iterasi entities dalam section
            for entity in section.entities {
                if entity.id == uuid {
                    rowIndex = currentRow
                    break
                }
                currentRow += 1
            }

            if rowIndex != nil {
                break
            }
        }

        // Jika ditemukan, reload row di tableView
        if let rowIndex {
            let rowIndexes = IndexSet(integer: rowIndex)
            let columnIndexes = IndexSet(integersIn: 0 ..< tableView.tableColumns.count)
            dispatchGroup.leave()
            dispatchGroup.notify(queue: .main) {
                tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
            }
        } else {
            #if DEBUG
                print("Row with UUID \(uuid) not found in tableView.")
            #endif
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isDataLoaded {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.indicator.isHidden = false
                self.indicator.startAnimation(self)
                self.setupTable()
                self.dataProcessingQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self else { return }
                    self.muatSaldoData(self)
                }
            }
        }

        visualEffect.material = .headerView
        masuk.textColor = NSColor.systemGreen
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        for columnInfo in tableView.tableColumns {
            guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier.rawValue)) else {
                continue
            }
            let customHeaderCell = MyHeaderCell()
            customHeaderCell.title = columnInfo.title
            column.headerCell = customHeaderCell
        }

        stackBox.boxType = .custom
        stackBox.contentViewMargins = .zero
        stackBox.fillColor = .gridColor
        stackBox.borderColor = .gridColor
        if let sorting = tableView.sortDescriptors.first {
            currentSortDescriptor = sorting
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.view.window?.makeFirstResponder(self.tableView)
            self.updateMenuItem(self)
            self.updateColumnMenu()
        }
        toolbarItem()

        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDitambahNotif(_:)), name: DataManager.dataDitambahNotif, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleEntitiesDeleted(_:)), name: DataManager.dataDihapusNotif, object: nil)
    }

    /// Konfigurasi action dan target Toolbar Item.
    func toolbarItem() {
        if let toolbar = view.window?.toolbar {
            // Search Field Toolbar Item
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
            {
                let searchField = searchFieldToolbarItem.searchField
                searchField.placeholderAttributedString = nil
                searchField.delegate = nil
                searchField.placeholderString = "Jumlah Saldo"
                searchField.isEditable = false
            }

            // Zoom Toolbar Item
            if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
               let zoom = zoomToolbarItem.view as? NSSegmentedControl
            {
                zoom.isEnabled = true
                zoom.target = self
                zoom.action = #selector(segmentedControlValueChanged(_:))
            }

            // Kalkulasi Toolbar Item
            if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
               let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton
            {
                kalkulasiNilai.isEnabled = false
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
                edit.isEnabled = false
            }

            // Tambah Toolbar Item
            if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
               let tambah = tambahToolbarItem.view as? NSButton
            {
                tambah.isEnabled = false
            }

            // Add Toolbar Item
            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
               let add = addToolbarItem.view as? NSButton
            {
                add.isEnabled = false
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

    /// Outlet dari XIB untuk NSVisualEffect
    @IBOutlet weak var visualEffect: NSVisualEffectView!

    override func viewWillDisappear() {
        super.viewWillDisappear()
        ReusableFunc.resetMenuItems()
        indicator.stopAnimation(self)
        indicator.isHidden = true
    }

    /// Metode delegate dari NSTableViewDelegate ketika seleksi berubah.
    func tableViewSelectionDidChange(_ notification: Notification) {
        NSApp.sendAction(#selector(JumlahTransaksi.updateMenuItem(_:)), to: nil, from: self)
    }

    /// Indikator yang berputar ketika data table sedang diproses dari Database.
    @IBOutlet weak var indicator: NSProgressIndicator!

    /// Ketika Menu Item **Muat Ulang** di toolbar atau klik kanan diklik.
    @IBAction func muatUlang(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.jumlah.alphaValue = 0
            self.masuk.alphaValue = 0
            self.keluar.alphaValue = 0
            self.indicator.isHidden = false
            self.indicator.startAnimation(sender)
            if self.tableView.numberOfRows > 0 {
                self.tableView.removeRows(at: IndexSet(integersIn: 0 ..< self.tableView.numberOfRows), withAnimation: [])
            }
            self.dataProcessingQueue.async(flags: .barrier) { [weak self] in
                guard let self else { return }
                self.muatSaldoData(sender)
            }
        }
    }

    /// Logika untuk memuat saldo dan menampilkannya di tabel sekaligus memperbarui teks ``jumlah``, ``keluar`` dan ``masuk``.
    func muatSaldoData(_ sender: Any) {
        let dispatchGroup = DispatchGroup()
        // Mulai fetchData
        dispatchGroup.enter()
        dataProcessingQueue.async(flags: .barrier) { [weak self] in
            guard let self else {
                dispatchGroup.leave()
                return
            }
            self.privateContext.performAndWait { [weak self] in
                self!.fetchData(in: self!.privateContext)
                dispatchGroup.leave()
            }

            // Mulai updateSaldo
            dispatchGroup.enter()
            self.privateContext.performAndWait { [weak self] in
                self!.updateSaldo()
                dispatchGroup.leave()
            }

            // Tunggu semua selesai, lalu pindah ke thread utama
            dispatchGroup.notify(queue: .main) { [weak self] in
                guard let self else { return }
                if self.tableView.numberOfRows > 0 {
                    self.tableView.removeRows(at: IndexSet(integersIn: 0 ..< self.tableView.numberOfRows), withAnimation: [])
                }

                self.tableView.beginUpdates()
                self.insertSectionsAndRows(from: self.dataSections)
                if self.tableView.numberOfRows > 0 {
                    self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
                }
                self.tableView.endUpdates()

                self.updateColumnHeaders()
                // Animasikan indicator isHidden
                NSAnimationContext.runAnimationGroup { [weak self] context in
                    context.duration = 0.3 // Durasi animasi
                    context.allowsImplicitAnimation = true
                    self?.indicator.stopAnimation(sender)
                    self?.indicator.isHidden = true
                    self?.labelStack.layoutSubtreeIfNeeded()
                } completionHandler: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self else { return }
                        if !self.isDataLoaded {
                            self.tableView.reloadData()
                            if self.tableView.numberOfRows > 0 {
                                self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
                            }
                            self.isDataLoaded = true
                        }
                    }
                }
            }
        }
    }

    /// Box untuk menampilkan garis di bawah ``labelStack`` stackView.
    @IBOutlet weak var stackBox: NSBox!

    /// Outle NSStackView yang menampung:
    /// - ``jumlah``
    /// - ``masuk``
    /// - ``keluar``
    @IBOutlet weak var labelStack: NSStackView!

    /// Memasukkan section baru dan baris-baris terkaitnya ke dalam tampilan tabel dengan animasi fade.
    ///
    /// Fungsi ini dirancang untuk menambahkan data baru secara efisien ke `self.tableView`.
    /// Fungsi ini mengiterasi setiap `section` yang diberikan, memasukkan setiap `section` dan
    /// baris-baris terkaitnya. Proses penyisipan dianimasikan menggunakan efek fade,
    /// memberikan pengalaman pengguna yang mulus.
    ///
    /// - Penting: Implementasi ini menggunakan `insertRows(at:withAnimation:)` untuk `section` dan juga baris.
    ///   Meskipun `insertRows` biasanya untuk baris, dalam konteks tampilan tabel tertentu
    ///   (misalnya, `NSTableView` khusus yang mengelola data hierarkis),
    ///   ini dapat diadaptasi untuk memasukkan item tingkat atas (`section`).
    ///
    /// - Parameter sections: Sebuah array dari tuple, di mana setiap tuple mewakili sebuah `section`
    ///   yang akan dimasukkan. Setiap `section` terdiri dari:
    ///     - `title`: Sebuah `String` yang mewakili judul `section`. Meskipun termasuk dalam tuple,
    ///       fungsi ini tidak secara langsung menggunakan judul untuk penyisipan.
    ///     - `entities`: Sebuah array objek `Entity`, di mana setiap `Entity` mewakili sebuah baris
    ///       yang termasuk dalam `section` ini.
    func insertSectionsAndRows(from sections: [(title: String, entities: [Entity])]) {
        // Jika tidak ada section yang akan dimasukkan, keluar lebih awal.
        guard !sections.isEmpty else { return }

        // Iterasi setiap section untuk memasukkan section dan baris-barisnya.
        // Loop berjalan sesuai urutan section yang diberikan.
        for sectionIndex in 0 ..< sections.count {
            let section = sections[sectionIndex]

            // Jika sebuah section tidak memiliki entitas (baris), lewati saja karena tidak ada yang ditampilkan.
            guard !section.entities.isEmpty else { continue }

            // Masukkan section ke dalam tampilan tabel terlebih dahulu.
            // Ini dilakukan menggunakan `insertRows` pada indeks section.
            tableView.insertRows(at: IndexSet(integer: sectionIndex), withAnimation: [.effectFade])

            // Iterasi setiap entitas (baris) dalam section saat ini dan masukkan.
            // Baris dimasukkan relatif terhadap section-nya.
            for rowIndex in 0 ..< section.entities.count {
                let index = IndexSet(integer: rowIndex)
                tableView.insertRows(at: index, withAnimation: [.effectFade])
            }
        }
    }

    /// Menemukan indeks baris di `tableView` untuk sebuah `section` tertentu.
    ///
    /// Fungsi ini menghitung posisi baris awal (indeks baris pertama) dari sebuah `section` yang
    /// diberikan di dalam tampilan tabel. Ini sangat berguna ketika Anda perlu menavigasi, memilih,
    /// atau melakukan operasi lain yang membutuhkan indeks baris global untuk sebuah `section`.
    /// Perhitungan ini mengasumsikan bahwa setiap `section` memiliki satu baris "header" implisit
    /// (atau representasi `section` itu sendiri) ditambah jumlah entitas (baris) yang dimilikinya.
    ///
    /// - Parameter sectionIndex: Indeks berbasis nol dari `section` yang ingin dicari barisnya.
    ///   Misalnya, `0` untuk `section` pertama, `1` untuk `section` kedua, dan seterusnya.
    ///
    /// - Returns: Indeks baris (`Int`) dari baris pertama `section` yang dimaksud jika `sectionIndex`
    ///   valid. Mengembalikan `nil` jika `sectionIndex` berada di luar batas `dataSections`,
    ///   dan akan mencetak pesan kesalahan ke konsol.
    func findRowForSection(_ sectionIndex: Int) -> Int? {
        // Memastikan sectionIndex yang diberikan berada dalam batas array dataSections.
        // Jika tidak valid, cetak pesan kesalahan dan kembalikan nil.
        guard sectionIndex >= 0, sectionIndex < dataSections.count else {
            print("Section index \(sectionIndex) out of bounds.")
            return nil
        }

        var currentRow = 0
        // Iterasi melalui section-section sebelum section yang diminta
        // untuk menghitung total jumlah baris yang dilewati.
        for index in 0 ..< sectionIndex {
            // Hitung jumlah total baris untuk section sebelumnya (termasuk header).
            // Diasumsikan setiap section berkontribusi 1 baris untuk dirinya sendiri (seperti header)
            // ditambah jumlah entitas (baris) di dalamnya.
            currentRow += dataSections[index].entities.count + 1
        }
        // Baris pertama dari section yang dimaksud adalah `currentRow` yang telah diakumulasikan.
        return currentRow
    }

    /// Menghitung indeks baris absolut dalam tampilan tabel untuk sebuah baris tertentu di dalam section.
    ///
    /// Fungsi ini sangat berguna ketika Anda perlu mengubah kombinasi `sectionIndex` dan `rowIndex`
    /// menjadi indeks baris tunggal dan unik yang digunakan oleh `UITableView` atau `NSTableView`.
    /// Perhitungan ini mengasumsikan bahwa setiap `section` memiliki satu baris "header" implisit
    /// (atau representasi `section` itu sendiri) yang berkontribusi pada total indeks baris.
    ///
    /// - Parameters:
    ///   - sectionIndex: Indeks berbasis nol dari `section` di mana baris berada.
    ///     Misalnya, `0` untuk `section` pertama, `1` untuk `section` kedua, dan seterusnya.
    ///   - rowIndex: Indeks berbasis nol dari baris di dalam `section` yang diberikan.
    ///     Misalnya, `0` untuk baris pertama dalam `section`, `1` untuk baris kedua, dan seterusnya.
    ///
    /// - Returns: Indeks baris absolut (`Int`) dari baris yang ditentukan dalam tampilan tabel.
    ///   Ini adalah indeks baris global yang mencakup semua section dan baris, termasuk header section.
    func calculateAbsoluteRowIndex(for sectionIndex: Int, rowIndex: Int) -> Int {
        var absoluteRowIndex = 0

        // Akumulasi jumlah baris dari semua section sebelumnya.
        // Untuk setiap section sebelumnya, tambahkan jumlah entitas (baris) ditambah 1
        // untuk memperhitungkan baris header section tersebut.
        for index in 0 ..< sectionIndex {
            absoluteRowIndex += dataSections[index].entities.count + 1 // Tambahkan 1 untuk header section sebelumnya
        }

        // Tambahkan 1 untuk baris header dari section saat ini.
        absoluteRowIndex += 1 // Header row untuk section saat ini

        // Tambahkan indeks baris relatif dalam section saat ini.
        absoluteRowIndex += rowIndex // Row dalam section saat ini

        return absoluteRowIndex
    }

    /// Memperbarui tampilan saldo total, pemasukan, dan pengeluaran pada antarmuka pengguna.
    ///
    /// Fungsi ini mengambil data finansial terbaru, memformatnya ke dalam format mata uang Rupiah,
    /// dan kemudian memperbarui label tampilan dengan animasi yang halus.
    ///
    /// - Terkait dengan:
    ///   - `DataManager.shared`: Diharapkan memiliki metode `calculateSaldo()` untuk menyediakan data finansial.
    ///   - `formatter`: Sebuah instance `NumberFormatter` yang harus diinisialisasi dan tersedia
    ///     dalam cakupan kelas atau objek yang memanggil fungsi ini.
    ///   - Properti UI (`jumlah`, `masuk`, `keluar`): Ini adalah `NSTextField` atau komponen UI serupa
    ///     yang memiliki properti `stringValue` dan `alphaValue` (umumnya untuk macOS dengan `AppKit`).
    ///
    /// - Cara Penggunaan:
    ///   Panggil fungsi ini setiap kali data finansial (pemasukan atau pengeluaran) berubah
    ///   dan Anda ingin memperbarui tampilan saldo di UI. Ini memastikan pengguna selalu melihat
    ///   informasi keuangan yang terkini dengan transisi visual yang menarik.
    func updateSaldo() {
        // Mengambil nilai total pemasukan, total pengeluaran, dan saldo bersih dari DataManager.
        let (totalMasuk, totalKeluar, saldo) = DataManager.shared.calculateSaldo()

        // Mengkonfigurasi formatter untuk menampilkan angka sebagai desimal tanpa digit pecahan.
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        // Memformat nilai saldo, pemasukan, dan pengeluaran ke dalam format mata uang Rupiah.
        let saldoFormatted = "Rp. " + (formatter.string(from: NSNumber(value: saldo)) ?? "")
        let totalMasukFormatted = "Pemasukan:   Rp. " + (formatter.string(from: NSNumber(value: totalMasuk)) ?? "")
        let totalKeluarFormatted = "Pengeluaran:   Rp. " + (formatter.string(from: NSNumber(value: totalKeluar)) ?? "")

        // Memperbarui UI di dispatch queue utama untuk memastikan keamanan thread dan kelancaran UI.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return } // Mencegah retain cycle.

            // Menjalankan grup animasi untuk pembaruan UI.
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true // Mengizinkan animasi implisit.
                context.duration = 0.3 // Mengatur durasi animasi menjadi 0.3 detik.

                // Memperbarui nilai string dari label UI.
                self.jumlah.stringValue = saldoFormatted
                self.masuk.stringValue = totalMasukFormatted
                self.keluar.stringValue = totalKeluarFormatted

                // Menganimasikan nilai alpha (opasitas) dari label untuk efek fade.
                self.jumlah.animator().alphaValue = 0.6 // Membuat saldo sedikit transparan.
                self.masuk.animator().alphaValue = 1 // Membuat pemasukan sepenuhnya terlihat.
                self.keluar.animator().alphaValue = 1 // Membuat pengeluaran sepenuhnya terlihat.
            }, completionHandler: nil) // Tidak ada blok penanganan setelah animasi selesai.
        }
    }

    /// Mengambil data `Entity` dari Core Data dan mengelompokkannya ke dalam `dataSections`.
    ///
    /// Fungsi ini melakukan operasi *fetch* asinkron dari Core Data untuk mengambil semua objek `Entity`.
    /// Setelah diambil, entitas-entitas ini dikelompokkan berdasarkan kategori yang dipilih
    /// (`selectedGroupCategory`), seperti "keperluan", "acara", atau "kategori".
    /// Data yang dikelompokkan kemudian diubah menjadi format `dataSections` yang merupakan
    /// array tuple `(title: String, entities: [Entity])`, diurutkan berdasarkan judul section,
    /// dan kemudian diurutkan lagi berdasarkan `currentSortDescriptor`.
    ///
    /// - Parameter context: `NSManagedObjectContext` tempat operasi *fetch* akan dilakukan.
    ///   Penting untuk melakukan operasi Core Data pada *context* yang benar untuk menghindari masalah
    ///   *thread safety*.
    ///
    /// - Catatan:
    ///   - `dataSections` diharapkan adalah properti dari kelas yang menyimpan data yang dikelompokkan
    ///     untuk tampilan tabel atau koleksi.
    ///   - `selectedGroupCategory` adalah properti yang menentukan kriteria pengelompokan.
    ///   - `currentSortDescriptor` adalah properti yang menentukan bagaimana entitas diurutkan dalam
    ///     setiap section setelah pengelompokan.
    ///   - Pesan kesalahan hanya dicetak dalam mode `DEBUG`.
    func fetchData(in context: NSManagedObjectContext) {
        // Bersihkan dataSections yang ada sebelum mengambil data baru.
        dataSections = []

        // Jalankan operasi Core Data secara sinkron pada context yang diberikan
        // untuk memastikan thread safety.
        context.performAndWait {
            // Buat fetch request untuk mengambil semua objek "Entity".
            let fetchRequest = NSFetchRequest<Entity>(entityName: "Entity")

            do {
                // Lakukan fetch request dan dapatkan array entitas.
                let entities = DataManager.shared.internFetchedData(try context.fetch(fetchRequest))
                // Inisialisasi dictionary untuk mengelompokkan entitas berdasarkan kunci section.
                var groupedData: [String: [Entity]] = [:]

                // Iterasi setiap entitas untuk mengelompokkannya.
                for entity in entities {
                    let sectionKey
                    
                    // Tentukan kunci section berdasarkan `selectedGroupCategory`.
                    = switch selectedGroupCategory
                    {
                    case "keperluan":
                        // Gunakan nilai `keperluan` entitas sebagai kunci section.
                        // Tambahkan spasi di awal untuk potensi tujuan pemformatan/pengurutan.
                        "  " + (entity.keperluan?.value ?? "Lainnya")
                    case "acara":
                        // Gunakan nilai `acara` entitas sebagai kunci section.
                        "  " + (entity.acara?.value ?? "Lainnya")
                    case "kategori":
                        // Gunakan nilai `kategori` entitas sebagai kunci section.
                        "  " + (entity.kategori?.value ?? "Lainnya")
                    default:
                        // Jika `selectedGroupCategory` tidak cocok, gunakan "Lainnya" sebagai kunci.
                        "Lainnya"
                    }
                    
                    // Inisialisasi array untuk kunci section jika belum ada.
                    if groupedData[sectionKey] == nil {
                        groupedData[sectionKey] = []
                    }
                    // Tambahkan entitas ke array yang sesuai dengan kunci section-nya.
                    groupedData[sectionKey]?.append(entity)
                }

                // Ubah dictionary data yang dikelompokkan menjadi array `dataSections`.
                // Setiap elemen adalah tuple (title: String, entities: [Entity]).
                // Urutkan section berdasarkan judulnya (kunci).
                dataSections = groupedData.map { key, value in
                    (title: key, entities: value)
                }.sorted { $0.title < $1.title }
                self.sortData(with: currentSortDescriptor ?? NSSortDescriptor(key: "Column1", ascending: true))
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
        }
    }

    /// Menangani aksi penyalinan data ke clipboard berdasarkan interaksi pengguna dengan tabel.
    ///
    /// Fungsi ini adalah metode target `@objc` yang dipanggil ketika item menu "Salin" (Copy)
    /// diklik. Ini memeriksa apakah baris yang diklik valid dan merupakan bagian dari baris yang
    /// saat ini dipilih. Berdasarkan kondisi ini, fungsi ini akan mendelegasikan operasi penyalinan
    /// ke `copySelectedRows` jika beberapa baris dipilih (termasuk baris yang diklik),
    /// atau ke `copyClickedRow` jika hanya baris yang diklik yang relevan untuk disalin.
    /// Jika tidak ada baris yang diklik valid, atau jika tidak ada baris yang diklik,
    /// ini akan secara default memanggil `copySelectedRows`.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini. Parameter ini tidak digunakan
    ///   secara langsung dalam logika fungsi ini, tetapi merupakan bagian dari tanda tangan metode target.
    ///
    /// - Catatan:
    ///   - `tableView.clickedRow` adalah properti dari `NSTableView` yang menunjukkan indeks baris
    ///     yang terakhir kali diklik oleh pengguna (misalnya, untuk memicu menu konteks).
    ///   - `tableView.selectedRowIndexes` adalah `IndexSet` yang berisi indeks semua baris yang saat ini dipilih.
    ///   - `dataSections` diharapkan adalah properti yang berisi data yang ditampilkan di tabel,
    ///     yang merupakan array dari section yang masing-masing berisi entitas (baris).
    ///   - `copySelectedRows` dan `copyClickedRow` adalah metode lain dalam kelas yang bertanggung jawab
    ///     untuk melakukan operasi penyalinan sebenarnya.
    @objc func copyDataToClipboard(_ sender: NSMenuItem) {
        // Memeriksa apakah baris yang diklik (jika ada) valid dan berada dalam batas data yang tersedia.
        // `flatMap` digunakan untuk mendapatkan jumlah total baris dari semua section.
        if tableView.clickedRow >= 0, tableView.clickedRow < dataSections.flatMap(\.entities).count {
            // Jika baris yang diklik adalah bagian dari baris yang sudah dipilih,
            // ini menunjukkan bahwa pengguna mungkin ingin menyalin seluruh pilihan.
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                // Panggil fungsi untuk menyalin semua baris yang dipilih.
                copySelectedRows(sender)
            } else {
                // Jika baris yang diklik bukan bagian dari pilihan yang ada,
                // asumsikan pengguna hanya ingin menyalin baris yang baru saja diklik.
                copyClickedRow(sender)
            }
        } else {
            // Jika tidak ada baris yang diklik yang valid (misalnya, area kosong diklik)
            // atau `clickedRow` di luar batas, secara default salin semua baris yang saat ini dipilih.
            copySelectedRows(sender)
        }
    }

    /// Memperbarui action dan target menu item di Menu Bar ketika class ini baru ditampilkan
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" })
        {
            let isRowSelected = tableView.selectedRowIndexes.count > 0
            copyMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                copyMenuItem.target = self
                copyMenuItem.action = #selector(copySelectedRows(_:))
            } else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
            }
        }
    }

    /// Menyalin data dari baris-baris yang dipilih di `tableView` ke clipboard.
    ///
    /// Fungsi ini mengiterasi melalui semua indeks baris yang saat ini dipilih di tabel.
    /// Untuk setiap baris yang dipilih, ia menemukan `Entity` yang sesuai dalam struktur `dataSections`
    /// dan membangun string yang berisi data baris tersebut, diformat sebagai teks yang dipisahkan oleh tab.
    /// Data disalin berdasarkan urutan kolom yang terlihat di tabel, dan juga menyertakan
    /// `entity.jenis` sebagai kolom pertama.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, `NSMenuItem`). Parameter ini
    ///   tidak digunakan secara langsung dalam logika fungsi ini, tetapi diperlukan oleh tanda tangan `@objc`.
    ///
    /// - Catatan Penting:
    ///   - Fungsi ini mengasumsikan bahwa `tableView` menggunakan model data di mana baris header section
    ///     mengambil satu indeks baris, dan kemudian diikuti oleh baris-baris entitas dalam section tersebut.
    ///   - `dataSections` adalah properti yang berisi data tabel yang dikelompokkan
    ///     (array dari tuple `(title: String, entities: [Entity])`).
    ///   - `selectedGroupCategory` digunakan untuk menentukan data mana yang akan ditampilkan di "Column1"
    ///     dan "Column2" berdasarkan kategori pengelompokan yang dipilih.
    ///   - `formatter` adalah `NumberFormatter` yang digunakan untuk memformat nilai mata uang.
    ///   - `dateFormatter` adalah `DateFormatter` yang digunakan untuk memformat tanggal.
    ///   - `NSPasteboard.general` digunakan untuk mengakses clipboard sistem.
    @objc func copySelectedRows(_ sender: Any) {
        var dataToCopy = "" // String untuk mengakumulasi semua data yang akan disalin.

        // Iterasi melalui setiap indeks baris yang dipilih di tabel.
        for selectedRow in tableView.selectedRowIndexes {
            var currentRow = selectedRow // Salinan indeks baris yang dipilih untuk perhitungan relatif.

            // Iterasi melalui setiap section untuk menemukan entitas yang sesuai dengan `selectedRow`.
            for section in dataSections {
                // Jika `currentRow` adalah 0, itu berarti kita berada di indeks header section.
                // Baris header tidak disalin, jadi kita keluar dari loop section ini.
                if currentRow == 0 {
                    break // Keluar dari loop untuk section ini.
                }
                // Jika `currentRow` kurang dari atau sama dengan jumlah entitas di section saat ini,
                // berarti baris yang dipilih ada di section ini.
                else if currentRow <= section.entities.count {
                    // Dapatkan entitas yang sesuai. `currentRow - 1` karena `currentRow` adalah indeks relatif
                    // setelah baris header (yaitu, baris pertama entitas adalah indeks 1, bukan 0).
                    let entity = section.entities[currentRow - 1]

                    // Tambahkan properti `jenis` entitas sebagai kolom pertama, diikuti dengan tab.
                    dataToCopy += (entity.jenisEnum?.title ?? "") + "\t"

                    // Iterasi melalui setiap kolom di tabel untuk mengambil data sesuai urutan kolom.
                    for column in tableView.tableColumns {
                        switch column.identifier.rawValue {
                        case "Column1":
                            // Data untuk "Column1" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                            switch selectedGroupCategory {
                            case "keperluan":
                                // Jika dikelompokkan berdasarkan keperluan, kolom ini menampilkan acara.
                                dataToCopy += (entity.acara?.value ?? "") + "\t"
                            case "acara":
                                // Jika dikelompokkan berdasarkan acara, kolom ini menampilkan keperluan.
                                dataToCopy += (entity.keperluan?.value ?? "") + "\t"
                            case "kategori":
                                // Jika dikelompokkan berdasarkan kategori, kolom ini menampilkan keperluan.
                                dataToCopy += (entity.keperluan?.value ?? "") + "\t"
                            default:
                                // Default: gunakan kategori entitas.
                                dataToCopy += (entity.kategori?.value ?? "") + "\t"
                            }
                        case "Column2":
                            // Data untuk "Column2" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                            switch selectedGroupCategory {
                            case "keperluan", "acara":
                                // Jika dikelompokkan berdasarkan keperluan atau acara, kolom ini menampilkan kategori.
                                dataToCopy += (entity.kategori?.value ?? "") + "\t"
                            default:
                                // Default: gunakan acara entitas.
                                dataToCopy += (entity.acara?.value ?? "") + "\t"
                            }
                        case "jumlah":
                            // Format dan tambahkan jumlah dengan awalan "Rp. ".
                            dataToCopy += "Rp. " + (formatter.string(from: NSNumber(value: entity.jumlah)) ?? "") + "\t"
                        case "tgl":
                            // Format dan tambahkan tanggal entitas. Gunakan nilai default jika tanggal nil.
                            if let date = entity.tanggal {
                                dataToCopy += dateFormatter.string(from: date) + "\t"
                            } else {
                                dataToCopy += "10-10-2023\t" // Nilai default jika tanggal tidak ada.
                            }
                        default:
                            // Abaikan kolom lain yang tidak relevan untuk disalin.
                            break
                        }
                    }
                    // Hapus karakter tab terakhir yang ditambahkan setelah semua kolom.
                    dataToCopy = String(dataToCopy.dropLast())
                    // Tambahkan karakter newline untuk memisahkan setiap baris data.
                    dataToCopy += "\n"
                    break // Keluar dari loop section setelah baris yang dipilih ditemukan dan diproses.
                }
                // Jika baris yang dipilih tidak ada di section saat ini, kurangi `currentRow`
                // dengan jumlah total baris di section ini (termasuk header) dan lanjutkan ke section berikutnya.
                else {
                    currentRow -= (section.entities.count + 1)
                }
            }
        }

        // Bersihkan isi clipboard yang ada.
        NSPasteboard.general.clearContents()
        // Atur string `dataToCopy` ke clipboard sebagai tipe string.
        NSPasteboard.general.setString(dataToCopy, forType: .string)
    }

    /// Menyalin semua data baris dari `tableView` ke clipboard, termasuk ringkasan saldo.
    ///
    /// Fungsi ini mengiterasi melalui semua baris yang terlihat di tabel, menemukan entitas yang
    /// sesuai, dan membangun string yang berisi data baris tersebut, diformat sebagai teks yang
    /// dipisahkan oleh tab. Data disalin berdasarkan urutan kolom yang terlihat di tabel,
    /// dan juga menyertakan `entity.jenis` sebagai kolom pertama. Sebelum data baris,
    /// fungsi ini menambahkan baris ringkasan yang mencakup saldo saat ini, total pemasukan,
    /// dan total pengeluaran.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, `NSMenuItem`). Parameter ini
    ///   tidak digunakan secara langsung dalam logika fungsi ini, tetapi diperlukan oleh tanda tangan `@objc`.
    ///
    /// - Catatan Penting:
    ///   - Fungsi ini mengasumsikan bahwa `tableView` menggunakan model data di mana baris header section
    ///     mengambil satu indeks baris, dan kemudian diikuti oleh baris-baris entitas dalam section tersebut.
    ///   - `dataSections` adalah properti yang berisi data tabel yang dikelompokkan
    ///     (array dari tuple `(title: String, entities: [Entity])`).
    ///   - `selectedGroupCategory` digunakan untuk menentukan data mana yang akan ditampilkan di "Column1"
    ///     dan "Column2" berdasarkan kategori pengelompokan yang dipilih.
    ///   - `formatter` adalah `NumberFormatter` yang digunakan untuk memformat nilai mata uang.
    ///   - `dateFormatter` adalah `DateFormatter` yang digunakan untuk memformat tanggal.
    ///   - `jumlah`, `masuk`, dan `keluar` adalah properti `NSTextField` (atau sejenisnya) yang
    ///     menyimpan string saldo, pemasukan, dan pengeluaran yang diformat.
    ///   - `NSPasteboard.general` digunakan untuk mengakses clipboard sistem.
    @objc func copyAllRows(_ sender: Any) {
        // Pastikan tableView memiliki setidaknya satu baris sebelum mencoba menyalin.
        guard tableView.numberOfRows >= 1 else { return }

        var dataToCopy = "" // String untuk mengakumulasi semua data yang akan disalin.

        // Ambil string nilai saldo, pemasukan, dan pengeluaran saat ini dari label UI.
        let jumlahSaldo = jumlah.stringValue
        let pemasukan = masuk.stringValue
        let pengeluaran = keluar.stringValue

        // Iterasi melalui setiap baris di tabel (dari 0 hingga jumlah total baris).
        for selectedRow in 0 ..< tableView.numberOfRows {
            var currentRow = selectedRow // Salinan indeks baris untuk perhitungan relatif.

            // Iterasi melalui setiap section untuk menemukan entitas yang sesuai dengan `selectedRow`.
            for section in dataSections {
                // Jika `currentRow` adalah 0, ini berarti kita berada di indeks header section.
                // Baris header tidak disalin dalam detail data, jadi kita keluar dari loop section ini.
                if currentRow == 0 {
                    break // Keluar dari loop untuk section ini.
                }
                // Jika `currentRow` kurang dari atau sama dengan jumlah entitas di section saat ini,
                // berarti baris yang sedang diproses ada di section ini.
                else if currentRow <= section.entities.count {
                    // Dapatkan entitas yang sesuai. `currentRow - 1` karena `currentRow` adalah indeks relatif
                    // setelah baris header (yaitu, baris pertama entitas adalah indeks 1, bukan 0).
                    let entity = section.entities[currentRow - 1]

                    // Tambahkan properti `jenis` entitas sebagai kolom pertama, diikuti dengan tab.
                    dataToCopy += (entity.jenisEnum?.title ?? "") + "\t"

                    // Iterasi melalui setiap kolom di tabel untuk mengambil data sesuai urutan kolom.
                    for column in tableView.tableColumns {
                        switch column.identifier.rawValue {
                        case "Column1":
                            // Data untuk "Column1" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                            switch selectedGroupCategory {
                            case "keperluan":
                                // Jika dikelompokkan berdasarkan keperluan, kolom ini menampilkan keperluan dan acara.
                                dataToCopy += (entity.keperluan?.value ?? "") + "\t"
                                dataToCopy += (entity.acara?.value ?? "") + "\t" // Terdapat duplikasi/tambahan kolom di sini
                            case "acara":
                                // Jika dikelompokkan berdasarkan acara, kolom ini menampilkan acara dan keperluan.
                                dataToCopy += (entity.acara?.value ?? "") + "\t"
                                dataToCopy += (entity.keperluan?.value ?? "") + "\t" // Terdapat duplikasi/tambahan kolom di sini
                            case "kategori":
                                // Jika dikelompokkan berdasarkan kategori, kolom ini menampilkan kategori dan keperluan.
                                dataToCopy += (entity.kategori?.value ?? "") + "\t"
                                dataToCopy += (entity.keperluan?.value ?? "") + "\t" // Terdapat duplikasi/tambahan kolom di sini
                            default:
                                // Default: gunakan kategori entitas.
                                dataToCopy += (entity.kategori?.value ?? "") + "\t"
                            }
                        case "Column2":
                            // Data untuk "Column2" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                            switch selectedGroupCategory {
                            case "keperluan", "acara":
                                // Jika dikelompokkan berdasarkan keperluan atau acara, kolom ini menampilkan kategori.
                                dataToCopy += (entity.kategori?.value ?? "") + "\t"
                            default:
                                // Default: gunakan acara entitas.
                                dataToCopy += (entity.acara?.value ?? "") + "\t"
                            }
                        case "jumlah":
                            // Format dan tambahkan jumlah dengan awalan "Rp. ".
                            dataToCopy += "Rp. " + (formatter.string(from: NSNumber(value: entity.jumlah)) ?? "") + "\t"
                        case "tgl":
                            // Format dan tambahkan tanggal entitas. Gunakan nilai default jika tanggal nil.
                            if let date = entity.tanggal {
                                dataToCopy += dateFormatter.string(from: date) + "\t"
                            } else {
                                dataToCopy += "10-10-2023\t" // Nilai default jika tanggal tidak ada.
                            }
                        default:
                            // Abaikan kolom lain yang tidak relevan untuk disalin.
                            break
                        }
                    }
                    // Hapus karakter tab terakhir yang ditambahkan setelah semua kolom.
                    dataToCopy = String(dataToCopy.dropLast())
                    // Tambahkan karakter newline untuk memisahkan setiap baris data.
                    dataToCopy += "\n"
                    break // Keluar dari loop section setelah baris yang diproses ditemukan.
                }
                // Jika baris yang sedang diproses tidak ada di section saat ini, kurangi `currentRow`
                // dengan jumlah total baris di section ini (termasuk header) dan lanjutkan ke section berikutnya.
                else {
                    currentRow -= (section.entities.count + 1)
                }
            }
        }

        // Hapus spasi berlebihan dari string pemasukan dan pengeluaran untuk ringkasan.
        let trimmedPemasukan = pemasukan.replacingOccurrences(of: ":   ", with: ": ")
        let trimmedPengeluaran = pengeluaran.replacingOccurrences(of: ":   ", with: ": ")

        // Sisipkan baris ringkasan (saldo, pemasukan, pengeluaran) di awal string `dataToCopy`.
        dataToCopy.insert(contentsOf: "Saldo saat ini: \(jumlahSaldo), \(trimmedPemasukan), \(trimmedPengeluaran)\n\n", at: dataToCopy.startIndex)

        // Bersihkan isi clipboard yang ada.
        NSPasteboard.general.clearContents()
        // Atur string `dataToCopy` ke clipboard sebagai tipe string.
        NSPasteboard.general.setString(dataToCopy, forType: .string)
    }

    /// Menyalin data dari baris yang diklik di `tableView` ke clipboard.
    ///
    /// Fungsi ini dirancang untuk menyalin data dari satu baris spesifik yang baru saja diklik
    /// oleh pengguna (misalnya, melalui klik kanan untuk menu konteks). Fungsi ini menemukan `Entity`
    /// yang sesuai dengan `tableView.clickedRow` dan membangun string yang berisi data baris tersebut,
    /// diformat sebagai teks yang dipisahkan oleh tab. Data disalin berdasarkan urutan kolom yang
    /// terlihat di tabel dan juga menyertakan `entity.jenis` sebagai kolom pertama.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini. Parameter ini tidak digunakan
    ///   secara langsung dalam logika fungsi ini, tetapi merupakan bagian dari tanda tangan metode target.
    ///
    /// - Catatan Penting:
    ///   - Fungsi ini mengasumsikan bahwa `tableView` menggunakan model data di mana baris header section
    ///     mengambil satu indeks baris, dan kemudian diikuti oleh baris-baris entitas dalam section tersebut.
    ///   - `tableView.clickedRow` adalah properti dari `NSTableView` yang menunjukkan indeks baris
    ///     yang terakhir kali diklik oleh pengguna.
    ///   - `dataSections` adalah properti yang berisi data tabel yang dikelompokkan
    ///     (array dari tuple `(title: String, entities: [Entity])`).
    ///   - `selectedGroupCategory` digunakan untuk menentukan data mana yang akan ditampilkan di "Column1"
    ///     dan "Column2" berdasarkan kategori pengelompokan yang dipilih.
    ///   - `formatter` adalah `NumberFormatter` yang digunakan untuk memformat nilai mata uang.
    ///   - `dateFormatter` adalah `DateFormatter` yang digunakan untuk memformat tanggal.
    ///   - `NSPasteboard.general` digunakan untuk mengakses clipboard sistem.
    @objc func copyClickedRow(_ sender: NSMenuItem) {
        let clickedRow = tableView.clickedRow // Dapatkan indeks baris yang diklik.

        // Pastikan baris yang diklik adalah baris yang valid (indeks tidak negatif).
        guard clickedRow >= 0 else { return }

        var currentRow = clickedRow // Salinan indeks baris yang diklik untuk perhitungan relatif.
        var dataToCopy = "" // String untuk mengakumulasi data yang akan disalin.

        // Iterasi melalui setiap section untuk menemukan entitas yang sesuai dengan `clickedRow`.
        for section in dataSections {
            // Jika `currentRow` adalah 0, ini berarti kita berada di indeks header section.
            // Baris header tidak disalin, jadi kita keluar dari fungsi.
            if currentRow == 0 {
                return
            }
            // Jika `currentRow` kurang dari atau sama dengan jumlah entitas di section saat ini,
            // berarti baris yang diklik ada di section ini.
            else if currentRow <= section.entities.count {
                // Dapatkan entitas yang sesuai. `currentRow - 1` karena `currentRow` adalah indeks relatif
                // setelah baris header (yaitu, baris pertama entitas adalah indeks 1, bukan 0).
                let entity = section.entities[currentRow - 1]

                // Tambahkan properti `jenis` entitas sebagai kolom pertama, diikuti dengan tab.
                dataToCopy += (entity.jenisEnum?.title ?? "") + "\t"

                // Iterasi melalui setiap kolom di tabel untuk mengambil data sesuai urutan kolom.
                for column in tableView.tableColumns {
                    switch column.identifier.rawValue {
                    case "Column1":
                        // Data untuk "Column1" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                        switch selectedGroupCategory {
                        case "keperluan":
                            dataToCopy += (entity.acara?.value ?? "")
                        case "acara":
                            dataToCopy += (entity.keperluan?.value ?? "")
                        case "kategori":
                            dataToCopy += (entity.keperluan?.value ?? "")
                        default:
                            dataToCopy += (entity.kategori?.value ?? "")
                        }
                    case "Column2":
                        // Data untuk "Column2" bervariasi tergantung pada kategori pengelompokan yang dipilih.
                        switch selectedGroupCategory {
                        case "keperluan":
                            dataToCopy += (entity.kategori?.value ?? "")
                        case "acara":
                            dataToCopy += (entity.kategori?.value ?? "")
                        case "kategori":
                            dataToCopy += (entity.acara?.value ?? "")
                        default:
                            dataToCopy += (entity.acara?.value ?? "")
                        }
                    case "jumlah":
                        // Format dan tambahkan jumlah dengan awalan "Rp. ".
                        dataToCopy += "\("Rp. " + (formatter.string(from: NSNumber(value: entity.jumlah)) ?? ""))"
                    case "tgl":
                        // Format dan tambahkan tanggal entitas. Gunakan nilai default jika tanggal nil.
                        if let date = entity.tanggal {
                            dataToCopy += dateFormatter.string(from: date)
                        } else {
                            dataToCopy += "10-10-2023" // Nilai default jika tanggal tidak ada.
                        }
                    default:
                        // Abaikan kolom lain yang tidak relevan untuk disalin.
                        break
                    }
                    dataToCopy += "\t" // Tambahkan tab setelah setiap nilai kolom.
                }
                // Hapus karakter tab terakhir yang ditambahkan setelah semua kolom.
                dataToCopy = String(dataToCopy.dropLast())
                break // Keluar dari loop section setelah baris yang diklik ditemukan dan diproses.
            }
            // Jika baris yang diklik tidak ada di section saat ini, kurangi `currentRow`
            // dengan jumlah total baris di section ini (termasuk header) dan lanjutkan ke section berikutnya.
            else {
                currentRow -= (section.entities.count + 1)
            }
        }

        // Bersihkan isi clipboard yang ada.
        NSPasteboard.general.clearContents()
        // Atur string `dataToCopy` ke clipboard sebagai tipe string.
        NSPasteboard.general.setString(dataToCopy, forType: .string)
    }

    /// Menangani event scroll pada `tableView` untuk menciptakan efek header "sticky"
    /// dan transisi antar judul section.
    ///
    /// Fungsi ini dipanggil setiap kali `scrollView` mendeteksi adanya pergerakan scroll.
    /// Tujuannya adalah untuk menjaga judul `section` tetap terlihat di bagian atas tampilan
    /// tabel saat pengguna menggulir, dan juga untuk mengelola transisi visual (fade-in/fade-out)
    /// antara judul `section` saat mereka masuk atau keluar dari area yang terlihat.
    ///
    /// - Parameter notification: Notifikasi `Notification` yang dikirim oleh `NSScrollView`
    ///   ketika ada event scroll. Objek notifikasi diharapkan adalah `NSClipView`.
    ///
    /// - Keterkaitan dengan properti dan func:
    ///   - `tableView`: `NSTableView` yang sedang di-scroll.
    ///   - `dataSections`: Array data yang mengelola struktur section dan entitas tabel.
    ///   - `headerView`: `NSTableHeaderView` bawaan dari `tableView`.
    ///   - `nextSectionHeaderView`: `NSView?` opsional yang digunakan untuk menampilkan
    ///     judul section berikutnya selama transisi.
    ///   - `tabBarFrame`: `CGFloat` yang merepresentasikan tinggi elemen UI di atas tabel,
    ///     digunakan untuk menyesuaikan offset scroll.
    ///   - `getRowInfoForRow(_:)`: Metode pembantu untuk mendapatkan indeks section dan baris
    ///     relatif dari indeks baris absolut.
    ///   - `findFirstRowInSection(_:)`: Metode pembantu untuk menemukan indeks baris absolut
    ///     dari baris pertama section tertentu.
    ///   - `createHeaderViewCopy(title:)`: Metode pembantu untuk membuat salinan `headerView`
    ///     dengan judul yang diberikan.
    ///   - `updateHeaderTitle(for:in:)`: Metode pembantu untuk memperbarui teks pada `headerView`.
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              let headerView = tableView.headerView
        else {
            return
        }

        var offsetY = clipView.documentVisibleRect.origin.y
        let stackViewAndToolbarFrame = CGFloat(60) /// frame stackView + Toolbar
        offsetY += (stackViewAndToolbarFrame + tabBarFrame)
        let topRow = tableView.row(at: CGPoint(x: 0, y: offsetY))

        // Handle top position
        if (clipView.bounds.origin.y + tabBarFrame) <= -103 {
            DispatchQueue.main.async { [unowned self] in
                self.updateHeaderTitle(for: 0, in: headerView)
                if headerView.frame.origin.y != 0 {
                    headerView.frame.origin.y = 0
                }
                if nextSectionHeaderView != nil {
                    nextSectionHeaderView?.removeFromSuperview()
                    nextSectionHeaderView = nil
                }
            }
            return
        }

        guard topRow != -1 else { return }

        let (_, currentSectionIndex, _) = getRowInfoForRow(topRow)
        let nextSectionIndex = currentSectionIndex + 1

        guard nextSectionIndex < dataSections.count else {
            nextSectionHeaderView?.removeFromSuperview()
            nextSectionHeaderView = nil
            return
        }

        let nextSectionFirstRow = findFirstRowInSection(nextSectionIndex)
        let nextSectionY = tableView.rect(ofRow: nextSectionFirstRow).minY

        let defaultSectionSpacing: CGFloat = 20 // jarak antar row paling bawah dengan row section group.
        let transitionDistance: CGFloat = 26 // Jarak scroll di mana transisi terjadi.
        // Titik awal offset Y di mana transisi header berikutnya dimulai.
        let transitionStart = nextSectionY - defaultSectionSpacing - transitionDistance

        if offsetY > transitionStart {
            // Create next section header if it doesn't exist
            if nextSectionHeaderView == nil {
                nextSectionHeaderView = createHeaderViewCopy(title: formatTitleForSection(dataSections[nextSectionIndex].title))
                if let nextHeader = nextSectionHeaderView {
                    clipView.addSubview(nextHeader)
                }
            }

            // Hitung progres transisi (0.0 hingga 1.0).
            let progress = min(max((offsetY - transitionStart) / transitionDistance, 0.0), 1.0)
            // Hitung pergeseran Y untuk header utama.
            let headerY = progress * transitionDistance
            // Hitung alpha (opasitas) untuk header berikutnya (fade-in).
            let nextAlpha = progress

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Update current header
                headerView.frame.origin.y = -headerY
                // headerView.alphaValue = currentAlpha
                self.updateHeaderTitle(for: currentSectionIndex, in: headerView)

                // Update next section header
                self.nextSectionHeaderView?.frame.origin.y = nextSectionY - 1
                self.nextSectionHeaderView?.alphaValue = nextAlpha

                if nextAlpha >= 1.0 {
                    self.updateHeaderTitle(for: nextSectionIndex, in: headerView)
                    if headerView.frame.origin.y != 0 {
                        headerView.frame.origin.y = 0
                        // headerView.alphaValue = 1.0
                    }
                    if self.nextSectionHeaderView != nil {
                        self.nextSectionHeaderView?.removeFromSuperview()
                        self.nextSectionHeaderView = nil
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateHeaderTitle(for: currentSectionIndex, in: headerView)
                headerView.frame.origin.y = 0
                self?.nextSectionHeaderView?.removeFromSuperview()
                self?.nextSectionHeaderView = nil
            }
        }
    }

    /// Memformat judul section berdasarkan kategori pengelompokan yang dipilih.
    ///
    /// Fungsi ini menyesuaikan tampilan judul `section` di UI. Ketika data dikelompokkan
    /// berdasarkan kriteria tertentu (`selectedGroupCategory`), fungsi ini menambahkan
    /// teks deskriptif ke judul asli untuk memberikan konteks yang lebih jelas kepada pengguna.
    /// Misalnya, jika data dikelompokkan berdasarkan "keperluan", judul section akan
    /// ditambahkan dengan "utk. Acara".
    ///
    /// - Parameter title: `String` judul asli dari section. Ini biasanya adalah nilai dari
    ///   properti `Entity` yang digunakan untuk pengelompokan (misalnya, nama keperluan, nama acara, atau nama kategori).
    ///
    /// - Returns: `String` judul section yang telah diformat. Jika `selectedGroupCategory`
    ///   tidak cocok dengan kasus yang ditentukan, judul asli akan dikembalikan tanpa modifikasi.
    ///
    /// - Terkait dengan:
    ///   - `selectedGroupCategory`: Properti `String` yang menunjukkan kriteria pengelompokan
    ///     data yang sedang aktif ("keperluan", "acara", "kategori", atau nilai default lainnya).
    func formatTitleForSection(_ title: String) -> String {
        switch selectedGroupCategory {
        case "keperluan":
            // Jika dikelompokkan berdasarkan keperluan, judul section akan menampilkan keperluan
            // dan mengindikasikan bahwa baris di dalamnya terkait dengan "Acara".
            "\(title) utk. Acara"
        case "acara":
            // Jika dikelompokkan berdasarkan acara, judul section akan menampilkan acara
            // dan mengindikasikan bahwa baris di dalamnya terkait dengan "Keperluan".
            "\(title) utk. Keperluan"
        case "kategori":
            // Jika dikelompokkan berdasarkan kategori, judul section akan menampilkan kategori
            // dan mengindikasikan bahwa baris di dalamnya terkait dengan "Keperluan".
            "\(title) utk. Keperluan"
        default:
            // Untuk kategori pengelompokan lainnya atau jika tidak ada kategori yang cocok,
            // kembalikan judul asli tanpa modifikasi.
            title
        }
    }

    /// Memperbarui judul kolom header utama `tableView` (`Column1`) berdasarkan indeks `section` yang diberikan.
    ///
    /// Fungsi ini bertujuan untuk mengubah teks pada `headerCell` dari `Column1` untuk mencerminkan
    /// judul `section` yang saat ini "lengket" atau terlihat di bagian atas `scrollView`. Ini menggunakan
    /// `formatTitleForSection` untuk mendapatkan judul yang sesuai dan kemudian mengatur `headerCell`
    /// kolom tersebut. Fungsi ini juga mencakup mekanisme untuk mencegah pembaruan yang tidak perlu
    /// jika judul sudah sama.
    ///
    /// - Parameters:
    ///   - sectionIndex: `Int` indeks `section` yang judulnya akan digunakan untuk memperbarui `header`.
    ///   - headerView: `NSTableHeaderView` dari `tableView`. Parameter ini disertakan dalam tanda tangan
    ///     metode, tetapi tidak secara langsung digunakan dalam logika ini untuk memanipulasi `headerView` itu sendiri,
    ///     melainkan untuk mengakses `NSTableColumn` melalui `tableView`.
    ///
    /// - Catatan Penting:
    ///   - Fungsi ini mengasumsikan bahwa `tableView` memiliki kolom dengan `identifier` "Column1".
    ///   - Diharapkan ada kelas `MyHeaderCell` yang merupakan `NSHeaderCell` kustom dengan properti
    ///     `customTitle` atau kemampuan untuk mengatur judul melalui properti `title`.
    ///   - `dataSections` adalah properti yang menyimpan data terkelompok dari tabel.
    ///   - `previousColumnTitle` adalah properti yang digunakan untuk menyimpan judul kolom sebelumnya
    ///     guna mencegah pembaruan yang berlebihan.
    ///   - Terdapat potensi logika yang tidak tepat pada baris `customHeaderCell.stringValue != previousColumnTitle`
    ///     karena `customHeaderCell` baru dibuat di setiap pemanggilan, dan `stringValue` awalnya akan kosong
    ///     atau berisi nilai default `MyHeaderCell`, bukan `previousColumnTitle`. Ini dapat menyebabkan `customHeaderCell.title`
    ///     tidak selalu diperbarui dan `previousColumnTitle` tidak selalu disetel dengan benar.
    ///   - Baris `self.jumlah.stringValue = "MyHeaderCell Error"` kemungkinan adalah *debug placeholder*.
    func updateHeaderTitle(for sectionIndex: Int, in headerView: NSTableHeaderView) {
        // Dapatkan NSTableColumn dengan identifier "Column1".
        if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("Column1")),
           let customHeaderCell = column.headerCell as? MyHeaderCell
        {
            // Pastikan sectionIndex yang diberikan valid dan berada dalam batas `dataSections`.
            guard sectionIndex >= 0, sectionIndex < dataSections.count else {
                return // Keluar jika sectionIndex tidak valid.
            }

            // Dapatkan judul yang diformat untuk section yang diberikan.
            let nextTitle = formatTitleForSection(dataSections[sectionIndex].title)

            // Perhatian: Logika perbandingan di bawah ini mungkin tidak bekerja seperti yang diharapkan.
            // `customHeaderCell.stringValue` pada titik ini akan menjadi nilai default `MyHeaderCell` yang baru dibuat,
            // bukan judul header yang sedang ditampilkan di UI. Ini berarti `customHeaderCell.stringValue != previousColumnTitle`
            // kemungkinan besar akan selalu true kecuali `previousColumnTitle` kebetulan sama dengan string default.
            if customHeaderCell.stringValue != previousColumnTitle {
                // Atur judul custom dari MyHeaderCell.
                customHeaderCell.title = nextTitle
                // Tetapkan customHeaderCell sebagai headerCell dari kolom.
                column.headerCell = customHeaderCell
                // Simpan judul yang baru disetel sebagai `previousColumnTitle` untuk perbandingan di masa mendatang.
                previousColumnTitle = customHeaderCell.customTitle // Asumsi MyHeaderCell memiliki properti customTitle
            } else {
                // Jika judul tidak berubah (berdasarkan logika perbandingan yang mungkin bermasalah),
                // atur stringValue dari `jumlah` ke pesan error. Ini kemungkinan adalah pesan debug.
                jumlah.stringValue = "MyHeaderCell Error"
            }
        }
    }

    /// Membuat salinan dari `NSTableHeaderView` yang ada untuk digunakan sebagai header sementara.
    ///
    /// Fungsi ini menghasilkan sebuah `NSTableHeaderView` baru yang merupakan duplikat fungsional
    /// dari `headerView` asli `tableView`. Header baru ini disesuaikan dengan judul yang diberikan
    /// dan properti-properti lain yang relevan disetel untuk meniru perilaku header asli,
    /// khususnya untuk tujuan animasi atau tampilan header "sticky".
    ///
    /// - Parameter title: `String` judul yang akan ditampilkan di header baru ini.
    ///
    /// - Returns: `NSTableHeaderView?` Sebuah instance `NSTableHeaderView` baru yang telah
    ///   dikonfigurasi, atau `nil` jika `tableView.headerView` asli tidak tersedia.
    ///
    /// - Terkait dengan:
    ///   - `tableView`: `NSTableView` tempat header asli berada.
    ///   - `CustomTableHeaderView`: Sebuah subclass `NSTableHeaderView` kustom yang diharapkan
    ///     memiliki properti `tableView` dan `isSorted`, serta `customHeaderCell`.
    ///   - `MyHeaderCell`: Sebuah subclass `NSTableHeaderCell` kustom yang digunakan untuk
    ///     mengatur judul header.
    ///   - `isSortedByFirstColumn`: Properti boolean yang menunjukkan apakah tabel diurutkan
    ///     berdasarkan kolom pertama.
    func createHeaderViewCopy(title: String) -> NSTableHeaderView? {
        // Pastikan headerView asli dari tableView tersedia. Jika tidak, kembalikan nil.
        guard let originalHeader = tableView.headerView else { return nil }

        // Buat frame baru yang sama dengan frame header asli.
        // Ini memastikan header baru memiliki ukuran dan posisi awal yang sama.
        let modFrame = NSRect(
            x: originalHeader.frame.origin.x,
            y: originalHeader.frame.origin.y,
            width: originalHeader.frame.width,
            height: originalHeader.frame.height
        )

        // Buat instance baru dari CustomTableHeaderView dengan frame yang dimodifikasi.
        let newHeader = CustomTableHeaderView(frame: modFrame)
        // Kaitkan tableView ke header baru (jika CustomTableHeaderView membutuhkannya).
        newHeader.tableView = tableView
        // Set properti isSorted berdasarkan status pengurutan kolom pertama.
        newHeader.isSorted = isSortedByFirstColumn

        // Buat instance MyHeaderCell baru untuk mengatur judul.
        let emptyHeaderCell = MyHeaderCell()
        // Set judul cell ke judul yang diberikan.
        emptyHeaderCell.title = title

        // Tetapkan MyHeaderCell yang baru dibuat sebagai customHeaderCell dari header baru.
        newHeader.customHeaderCell = emptyHeaderCell

        // Kembalikan header baru yang telah dikonfigurasi.
        return newHeader
    }

    /// Menemukan indeks baris absolut pertama dalam `tableView` untuk sebuah section tertentu.
    ///
    /// Fungsi ini mencari indeks baris global dari baris pertama (yang diasumsikan sebagai header section)
    /// untuk `sectionIndex` yang diberikan. Ini mengiterasi semua baris di tabel,
    /// menggunakan `getRowInfoForRow` untuk menentukan section mana setiap baris berada,
    /// dan mengembalikan indeks baris begitu section yang cocok ditemukan.
    ///
    /// - Parameter sectionIndex: Indeks berbasis nol dari section yang ingin dicari baris pertamanya.
    ///
    /// - Returns: `Int` yang merupakan indeks baris absolut dari baris pertama section tersebut.
    ///   Mengembalikan `-1` jika section tidak ditemukan (meskipun dalam implementasi normal,
    ///   semua section harus memiliki setidaknya satu baris header).
    func findFirstRowInSection(_ sectionIndex: Int) -> Int {
        // Mulai dari baris 1 karena baris 0 mungkin memiliki penanganan khusus atau tidak relevan.
        for row in 1 ..< tableView.numberOfRows {
            // Dapatkan informasi section dan baris dari indeks baris absolut saat ini.
            let (_, section, _) = getRowInfoForRow(row)
            // Jika section dari baris saat ini cocok dengan sectionIndex yang dicari,
            // maka ini adalah baris pertama dari section tersebut.
            if section == sectionIndex {
                return row
            }
        }
        // Jika section tidak ditemukan setelah mengiterasi semua baris, kembalikan -1.
        return -1
    }

    /// Mendapatkan informasi detail (tipe baris, indeks section, indeks baris dalam section)
    /// untuk sebuah indeks baris absolut tertentu dalam `tableView`.
    ///
    /// Fungsi ini membantu menerjemahkan indeks baris global (`tableView.row`) menjadi
    /// konteks data yang lebih spesifik, yaitu apakah itu baris grup (header section)
    /// atau baris entitas biasa, dan di section mana baris tersebut berada.
    /// Ini mengasumsikan bahwa setiap section memiliki satu baris "header" diikuti oleh baris entitasnya.
    ///
    /// - Parameter row: `Int` indeks baris absolut dalam `tableView` yang ingin dicari informasinya.
    ///
    /// - Returns: Sebuah tuple `(isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int)`:
    ///   - `isGroupRow`: `true` jika baris adalah baris header section, `false` jika baris entitas.
    ///   - `sectionIndex`: Indeks berbasis nol dari section tempat baris berada.
    ///   - `rowIndexInSection`: Indeks berbasis nol dari baris dalam section-nya. Akan menjadi `-1`
    ///     jika baris adalah header section.
    ///
    /// - Catatan:
    ///   - `dataSections` adalah properti yang berisi data terkelompok yang ditampilkan di tabel,
    ///     diasumsikan sebagai `[(title: String, entities: [Entity])]`.
    func getRowInfoForRow(_ row: Int) -> (isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) {
        var currentRow = 0 // Pelacak indeks baris absolut saat ini.

        // Iterasi melalui setiap section dalam `dataSections` dengan indeksnya.
        for (index, section) in dataSections.enumerated() {
            // Hitung total baris untuk section saat ini (jumlah entitas + 1 untuk header).
            let sectionRowCount = section.entities.count + 1

            // Periksa apakah baris yang dicari (`row`) berada dalam rentang section saat ini.
            if row >= currentRow, row < currentRow + sectionRowCount {
                // Jika `row` sama dengan `currentRow`, itu berarti ini adalah baris header section.
                if row == currentRow {
                    return (true, index, -1) // `isGroupRow` true, `rowIndexInSection` -1 (tidak berlaku).
                } else {
                    // Jika tidak, itu adalah baris entitas dalam section ini.
                    // Indeks baris dalam section dihitung dengan mengurangi `currentRow` (posisi awal section)
                    // dan 1 (untuk baris header).
                    return (false, index, row - currentRow - 1)
                }
            }
            // Pindahkan `currentRow` ke awal section berikutnya.
            currentRow += sectionRowCount
        }

        // Jika baris tidak ditemukan dalam section manapun (misalnya, indeks di luar batas yang diharapkan),
        // kembalikan nilai default. Ini bisa mengindikasikan masalah data atau logika.
        return (false, 0, 0)
    }

    /// Menangani pemilihan item menu kategori pengelompokan.
    ///
    /// Fungsi ini dipanggil ketika pengguna memilih salah satu item dari menu ``categoryMenuItems``
    /// (misalnya, "keperluan", "acara", "kategori"). Ini memperbarui status centang (`.on` atau `.off`)
    /// dari item menu yang relevan, mengatur kategori pengelompokan yang dipilih, memuat ulang data,
    /// memperbarui header kolom tabel, dan me-reload tabel.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini. `sender.tag` digunakan untuk
    ///   mengidentifikasi kategori yang dipilih dari array `categories`.
    ///
    /// - Pra-kondisi:
    ///   - `sender.state` harus `.off` (tidak dicentang) untuk memproses pemilihan baru.
    ///   - `categoryMenuItems` adalah array `NSMenuItem` yang sesuai dengan kategori-kategori.
    ///   - `selectedGroupCategory` adalah properti yang akan menyimpan kategori yang dipilih.
    ///   - `privateContext` adalah `NSManagedObjectContext` untuk operasi data.
    ///   - `fetchData(in:)`, `updateColumnHeaders()`, dan `tableView.reloadData()` adalah metode
    ///     yang diharapkan ada untuk memperbarui data dan tampilan UI.
    @objc func menuItemSelected(_ sender: NSMenuItem) {
        // Hanya proses jika item menu yang diklik saat ini tidak dicentang.
        // Ini mencegah pemrosesan ulang jika pengguna mengklik item yang sudah aktif.
        guard sender.state == .off else { return }

        // Mendefinisikan kategori yang tersedia, diindeks sesuai dengan `sender.tag` item menu.
        let categories = ["keperluan", "acara", "kategori"]
        // Mendapatkan kategori yang dipilih berdasarkan `tag` dari item menu yang diklik.
        let selectedCategory = categories[sender.tag]

        // Perbarui status centang semua item menu kategori:
        // Setel `.on` untuk item yang baru dipilih (`sender.tag`), dan `.off` untuk yang lainnya.
        for menuItem in categoryMenuItems {
            menuItem.state = (menuItem.tag == sender.tag) ? .on : .off
        }

        // Setel properti `selectedGroupCategory` kelas ke kategori yang baru dipilih.
        selectedGroupCategory = selectedCategory

        // Ambil ulang data dari Core Data berdasarkan kategori pengelompokan yang baru.
        fetchData(in: privateContext)
        // Perbarui judul dan konfigurasi header kolom tabel agar sesuai dengan pengelompokan baru.
        updateColumnHeaders()
        // Muat ulang seluruh data tabel untuk merefleksikan perubahan pengelompokan.
        tableView.reloadData()

        // Jika tabel memiliki baris (setelah dimuat ulang), sembunyikan baris pertama (yang seringkali
        // merupakan header section) tanpa animasi. Ini sering digunakan untuk efek header sticky.
        if tableView.numberOfRows > 0 {
            tableView.hideRows(at: IndexSet([0]), withAnimation: [])
        }
    }

    /// Memperbarui judul kolom header `tableView` berdasarkan kategori pengelompokan yang dipilih.
    ///
    /// Fungsi ini menyesuaikan teks yang ditampilkan di `header` untuk "Column1" dan "Column2"
    /// dari `tableView` Anda. Ini memastikan bahwa judul kolom mencerminkan kriteria pengelompokan
    /// data yang sedang aktif (`selectedGroupCategory`), memberikan konteks yang jelas kepada pengguna
    /// tentang informasi yang disajikan di setiap kolom.
    ///
    /// - Pra-kondisi:
    ///   - `tableView` memiliki kolom dengan identifier "Column1" dan "Column2".
    ///   - `dataSections` tidak kosong dan memiliki setidaknya satu judul section pertama.
    ///   - `selectedGroupCategory` adalah properti yang menunjukkan kriteria pengelompokan
    ///     data yang sedang aktif ("keperluan", "acara", "kategori", atau nilai default lainnya).
    func updateColumnHeaders() {
        // Pastikan "Column1", "Column2" ada, dan ada setidaknya satu judul section.
        guard let column1 = tableView.tableColumns.first(where: { $0.identifier.rawValue == "Column1" }),
              let column2 = tableView.tableColumns.first(where: { $0.identifier.rawValue == "Column2" }),
              let firstSectionTitle = dataSections.first?.title
        else {
            return // Keluar jika ada yang tidak ditemukan.
        }

        // Sesuaikan judul kolom berdasarkan kategori pengelompokan yang dipilih.
        switch selectedGroupCategory {
        case "keperluan":
            // Jika dikelompokkan berdasarkan keperluan, "Column1" menampilkan keperluan (dari judul section)
            // dan mengindikasikan terkait "Acara". "Column2" menjadi "Kategori".
            column1.title = "\(firstSectionTitle) utk. Acara"
            column2.title = "Kategori"
        case "acara":
            // Jika dikelompokkan berdasarkan acara, "Column1" menampilkan acara (dari judul section)
            // dan mengindikasikan terkait "Keperluan". "Column2" menjadi "Kategori".
            column1.title = "\(firstSectionTitle) utk. Keperluan"
            column2.title = "Kategori"
        case "kategori":
            // Jika dikelompokkan berdasarkan kategori, "Column1" menampilkan kategori (dari judul section)
            // dan mengindikasikan terkait "Keperluan". "Column2" menjadi "Acara".
            column1.title = "\(firstSectionTitle) utk. Keperluan"
            column2.title = "Acara"
        default:
            // Untuk kategori pengelompokan lainnya atau jika tidak ada kategori yang cocok,
            // judul kolom tidak berubah.
            break
        }

        /*
         // Blok kode yang dikomentari di bawah ini adalah contoh bagaimana Anda dapat
         // mengatur atribut teks pada header, seperti warna.
         // Ini mungkin berguna jika Anda ingin menerapkan gaya kustom pada teks header.
         for column in tableView.tableColumns {
             column.headerCell.attributedStringValue = NSAttributedString(
                 string: column.title,
                 attributes: [
                     NSAttributedString.Key.foregroundColor: AppDelegate.shared.headerColor
                 ]
             )
         }
         */
    }

    /// Mengatur prototipe deskriptor pengurutan (sort descriptor prototype) untuk setiap kolom di `tableView`.
    ///
    /// Fungsi ini menginisialisasi `NSSortDescriptor` untuk setiap kolom yang dapat diurutkan
    /// di tabel Anda. `sortDescriptorPrototype` memungkinkan `NSTableView` untuk secara otomatis
    /// menangani indikator pengurutan di `header` kolom (panah naik/turun) ketika pengguna
    /// mengklik `header` kolom untuk mengurutkan data.
    ///
    /// - Catatan:
    ///   - Ini mengasumsikan bahwa Anda memiliki kolom tabel dengan identifier `Column1`, `Column2`,
    ///     `jumlah`, dan `tgl`. Jika identifier ini tidak cocok dengan kolom aktual di `tableView` Anda,
    ///     descriptor tidak akan diterapkan.
    ///   - Setiap deskriptor pengurutan diatur ke `ascending: true` secara default, yang berarti
    ///     pengurutan awal akan menaik.
    func setupDescriptor() {
        // Buat NSSortDescriptor untuk setiap kolom dengan pengurutan menaik (ascending) secara default.
        let column1 = NSSortDescriptor(key: "Column1", ascending: true)
        let column2 = NSSortDescriptor(key: "Column2", ascending: true)
        let jumlah = NSSortDescriptor(key: "jumlah", ascending: true) // Asumsi "jumlah" adalah nama kunci pengurutan yang benar.
        let tgl = NSSortDescriptor(key: "tgl", ascending: true) // Asumsi "tgl" adalah nama kunci pengurutan yang benar.

        // Buat dictionary yang memetakan NSUserInterfaceItemIdentifier kolom ke NSSortDescriptor-nya.
        let columnDescriptor: [NSUserInterfaceItemIdentifier: NSSortDescriptor] = [
            NSUserInterfaceItemIdentifier("Column1"): column1,
            NSUserInterfaceItemIdentifier("Column2"): column2,
            NSUserInterfaceItemIdentifier("jumlah"): jumlah,
            NSUserInterfaceItemIdentifier("tgl"): tgl,
        ]

        // Iterasi melalui semua kolom di `tableView`.
        for column in tableView.tableColumns {
            let identifier = column.identifier // Dapatkan identifier kolom.
            // Cari sort descriptor yang sesuai di `columnDescriptor` dictionary.
            let sortDesc = columnDescriptor[identifier]
            // Tetapkan sort descriptor sebagai prototipe untuk kolom ini.
            // Ini memungkinkan tabel untuk secara otomatis mengelola pengurutan ketika header kolom diklik.
            column.sortDescriptorPrototype = sortDesc
        }
    }

    /// Mengurutkan data dalam setiap section berdasarkan `NSSortDescriptor` yang diberikan.
    ///
    /// Fungsi ini melakukan pengurutan data di *background thread* untuk menjaga responsivitas UI.
    /// Setiap `section` dalam `dataSections` akan diurutkan berdasarkan `key` dan `ascending`
    /// dari `sortDescriptor`. Logika pengurutan disesuaikan untuk `Column1` dan `Column2`
    /// berdasarkan `selectedGroupCategory`, serta kolom `jumlah` dan `tgl` dengan penanganan
    /// nilai `nil` dan pengurutan sekunder jika nilai utama sama.
    ///
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang mendefinisikan kunci (kolom)
    ///   dan arah pengurutan (menaik atau menurun).
    ///
    /// - Terkait dengan:
    ///   - `dataSections`: Properti yang menyimpan data tabel yang terkelompok (array of sections).
    ///   - `Entity`: Tipe model data yang memiliki properti seperti `acara`, `keperluan`,
    ///     `kategori`, `jumlah`, `tanggal`, dan `jenis`.
    ///   - `selectedGroupCategory`: Properti yang menunjukkan kategori pengelompokan yang aktif,
    ///     yang mempengaruhi data mana yang digunakan untuk pengurutan `Column1` dan `Column2`.
    func sortData(with sortDescriptor: NSSortDescriptor) {
        // Jalankan operasi pengurutan di background thread untuk mencegah pemblokiran UI.
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Pastikan self masih ada (tidak di-deallocate) untuk mencegah crash.
            guard let self else { return }

            // Map setiap section ke section baru dengan entitas yang sudah diurutkan.
            let sortedSections: [(title: String, entities: [Entity])] = self.dataSections.map { section in
                let sortedEntities = section.entities.sorted { entity1, entity2 -> Bool in
                    // MARK: - Helper Methods for Comparison

                    /// Membandingkan dua string berdasarkan arah pengurutan.
                    /// - Parameters:
                    ///   - string1: String pertama untuk dibandingkan.
                    ///   - string2: String kedua untuk dibandingkan.
                    ///   - ascending: `true` untuk pengurutan menaik (A-Z), `false` untuk menurun (Z-A).
                    /// - Returns: `true` jika `string1` harus datang sebelum `string2`.
                    func compareStrings(_ string1: String, _ string2: String, ascending: Bool) -> Bool {
                        ascending ? string1 < string2 : string1 > string2
                    }

                    /// Membandingkan dua tanggal berdasarkan arah pengurutan.
                    /// - Parameters:
                    ///   - date1: Tanggal pertama untuk dibandingkan.
                    ///   - date2: Tanggal kedua untuk dibandingkan.
                    ///   - ascending: `true` untuk pengurutan menaik (tanggal lama ke baru), `false` untuk menurun (tanggal baru ke lama).
                    /// - Returns: `true` jika `date1` harus datang sebelum `date2`.
                    func compareDates(_ date1: Date, _ date2: Date, ascending: Bool) -> Bool {
                        ascending ? date1 < date2 : date1 > date2
                    }

                    // MARK: - Sorting Logic based on Sort Descriptor Key

                    // Gunakan `sortDescriptor.key` untuk menentukan properti entitas mana yang akan diurutkan.
                    switch sortDescriptor.key {
                    case "Column1":
                        // Pengurutan untuk "Column1" tergantung pada kategori pengelompokan yang aktif.
                        switch self.selectedGroupCategory {
                        case "keperluan":
                            return compareStrings(entity1.acara?.value ?? "", entity2.acara?.value ?? "", ascending: sortDescriptor.ascending)
                        case "acara":
                            return compareStrings(entity1.keperluan?.value ?? "", entity2.keperluan?.value ?? "", ascending: sortDescriptor.ascending)
                        case "kategori":
                            return compareStrings(entity1.keperluan?.value ?? "", entity2.keperluan?.value ?? "", ascending: sortDescriptor.ascending)
                        default:
                            // Default fallback jika selectedGroupCategory tidak cocok.
                            return compareStrings(entity1.kategori?.value ?? "", entity2.kategori?.value ?? "", ascending: sortDescriptor.ascending)
                        }
                    case "Column2":
                        // Pengurutan untuk "Column2" juga tergantung pada kategori pengelompokan.
                        switch self.selectedGroupCategory {
                        case "keperluan":
                            return compareStrings(entity1.kategori?.value ?? "", entity2.kategori?.value ?? "", ascending: sortDescriptor.ascending)
                        case "acara":
                            return compareStrings(entity1.kategori?.value ?? "", entity2.kategori?.value ?? "", ascending: sortDescriptor.ascending)
                        case "kategori":
                            return compareStrings(entity1.acara?.value ?? "", entity2.acara?.value ?? "", ascending: sortDescriptor.ascending)
                        default:
                            // Default fallback.
                            return compareStrings(entity1.acara?.value ?? "", entity2.acara?.value ?? "", ascending: sortDescriptor.ascending)
                        }
                    case "jumlah":
                        // Jika jumlah sama, lakukan pengurutan sekunder berdasarkan `jenis`.
                        if entity1.jumlah == entity2.jumlah {
                            return compareStrings(entity1.jenisEnum?.title ?? "", entity2.jenisEnum?.title ?? "", ascending: sortDescriptor.ascending)
                        } else {
                            // Urutkan berdasarkan jumlah.
                            return sortDescriptor.ascending ? entity1.jumlah < entity2.jumlah : entity1.jumlah > entity2.jumlah
                        }
                    case "tgl":
                        // Pastikan kedua tanggal ada sebelum membandingkan.
                        if let date1 = entity1.tanggal, let date2 = entity2.tanggal {
                            // Jika tanggal sama, lakukan pengurutan sekunder berdasarkan `jenis`.
                            if date1 == date2 {
                                return compareStrings(entity1.jenisEnum?.title ?? "", entity2.jenisEnum?.title ?? "", ascending: sortDescriptor.ascending)
                            } else {
                                // Urutkan berdasarkan tanggal.
                                return compareDates(date1, date2, ascending: sortDescriptor.ascending)
                            }
                        } else {
                            // Penanganan kasus di mana salah satu atau kedua tanggal adalah `nil`.
                            // Di sini, `false` berarti tidak ada perubahan urutan relatif.
                            // Anda mungkin ingin menyesuaikan logika ini berdasarkan kebutuhan aplikasi Anda
                            // (misalnya, menempatkan nilai nil di awal atau akhir).
                            return false
                        }
                    default:
                        // Default fallback jika `sortDescriptor.key` tidak cocok dengan kasus di atas.
                        // Mengembalikan `true` akan menjaga urutan asli relatif.
                        return true
                    }
                }
                // Kembalikan section dengan entitas yang sudah diurutkan.
                return (title: section.title, entities: sortedEntities)
            }

            // Setelah pengurutan selesai, perbarui `dataSections` di main thread.
            // `tableView.reloadData()` dan pembaruan UI lainnya harus dilakukan di main thread.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.dataSections = sortedSections
                // Anda mungkin perlu memanggil `self.tableView.reloadData()` di sini
                // agar perubahan urutan data tercermin di UI.
                // self.tableView.reloadData()
                // self.tableView.sortDescriptors = [sortDescriptor] // Perbarui indikator pengurutan di header.
            }
        }
    }

    /// Menangani perubahan nilai pada `NSSegmentedControl`, yang digunakan untuk menyesuaikan ukuran baris tabel.
    ///
    /// Fungsi ini bertindak sebagai action method untuk `NSSegmentedControl`. Berdasarkan segmen yang dipilih
    /// (indeks 0 atau 1), fungsi ini akan memicu peningkatan atau pengurangan tinggi baris `tableView`.
    ///
    /// - Parameter sender: `NSSegmentedControl` yang mengirim aksi. `sender.selectedSegment`
    ///   digunakan untuk menentukan segmen mana yang dipilih (0 untuk segmen pertama, 1 untuk segmen kedua).
    @IBAction func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: // Biasanya segmen untuk mengurangi ukuran
            decreaseSize(sender)
        case 1: // Biasanya segmen untuk meningkatkan ukuran
            increaseSize(sender)
        default:
            // Tidak ada tindakan untuk segmen lain jika ada.
            break
        }
    }

    /// Meningkatkan tinggi baris `tableView` dengan animasi dan menyimpan perubahan.
    ///
    /// Fungsi ini memperbesar tinggi baris tabel sebesar 5 poin. Perubahan ini dianimasikan
    /// dengan durasi 0.2 detik untuk memberikan pengalaman pengguna yang halus. Setelah perubahan,
    /// tabel diberitahu tentang tinggi baris yang baru, dan tinggi baris yang diperbarui
    /// disimpan secara persisten ke `UserDefaults`.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini. Parameter ini opsional (`Any?`) dan tidak
    ///   digunakan secara langsung dalam logika fungsi.
    @IBAction func increaseSize(_ sender: Any?) {
        // Jalankan grup animasi untuk perubahan tinggi baris.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi dalam detik.
            tableView.rowHeight += 5 // Tingkatkan tinggi baris.
            // Beri tahu tabel bahwa tinggi baris telah berubah untuk semua baris kecuali baris header (indeks 0).
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 1 ..< tableView.numberOfRows))
        }, completionHandler: { [unowned self] in
            // Setelah animasi selesai, muat ulang baris-baris yang "tertanda" (kemungkinan baris-baris yang dipilih atau terlihat)
            // di semua kolom untuk memastikan konten ditampilkan dengan benar.
            tableView.reloadData(forRowIndexes: tertanda, columnIndexes: IndexSet(0 ..< tableView.numberOfColumns))
        })
        // Simpan tinggi baris yang baru ke UserDefaults.
        saveRowHeight()
    }

    /// Mengurangi tinggi baris `tableView` dengan animasi dan menyimpan perubahan.
    ///
    /// Fungsi ini mengurangi tinggi baris tabel sebesar 3 poin, memastikan tinggi minimum 16 poin.
    /// Perubahan ini dianimasikan dengan durasi 0.2 detik. Setelah perubahan, tabel diberitahu
    /// tentang tinggi baris yang baru, dan tinggi baris yang diperbarui disimpan secara persisten
    /// ke `UserDefaults`.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini. Parameter ini opsional (`Any?`) dan tidak
    ///   digunakan secara langsung dalam logika fungsi.
    @IBAction func decreaseSize(_ sender: Any?) {
        // Jalankan grup animasi untuk perubahan tinggi baris.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Durasi animasi dalam detik.
            // Kurangi tinggi baris, pastikan tidak kurang dari 16.
            tableView.rowHeight = max(tableView.rowHeight - 3, 16)
            // Beri tahu tabel bahwa tinggi baris telah berubah untuk semua baris kecuali baris header (indeks 0).
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 1 ..< tableView.numberOfRows))
        }, completionHandler: { [unowned self] in
            // Setelah animasi selesai, muat ulang baris-baris yang "tertanda" (kemungkinan baris-baris yang dipilih atau terlihat)
            // di semua kolom untuk memastikan konten ditampilkan dengan benar.
            tableView.reloadData(forRowIndexes: tertanda, columnIndexes: IndexSet(0 ..< tableView.numberOfColumns))
        })
        // Simpan tinggi baris yang baru ke UserDefaults.
        saveRowHeight()
    }

    /// Mengatur konfigurasi awal `tableView`, khususnya memuat tinggi baris yang tersimpan.
    ///
    /// Fungsi ini dipanggil saat inisialisasi atau pemuatan tampilan untuk mengembalikan
    /// `tableView.rowHeight` ke nilai yang terakhir disimpan oleh pengguna di `UserDefaults`.
    /// Ini memastikan konsistensi preferensi pengguna antar sesi aplikasi.
    func setupTable() {
        // Coba memuat tinggi baris yang tersimpan dari UserDefaults.
        if let savedRowHeight = UserDefaults.standard.value(forKey: "SaldoTableViewRowHeight") as? CGFloat {
            // Jika ditemukan, terapkan tinggi baris yang tersimpan ke tabel.
            tableView.rowHeight = savedRowHeight
        }
    }

    /// Menyimpan tinggi baris `tableView` saat ini ke `UserDefaults`.
    ///
    /// Fungsi ini digunakan untuk menyimpan preferensi tinggi baris pengguna secara persisten.
    /// Tinggi baris `tableView` saat ini akan disimpan di bawah kunci "SaldoTableViewRowHeight"
    /// di `UserDefaults`, memungkinkan aplikasi untuk memuatnya kembali di lain waktu.
    func saveRowHeight() {
        // Simpan nilai tableView.rowHeight saat ini ke UserDefaults.
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "SaldoTableViewRowHeight")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }
}

extension JumlahTransaksi: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        // 1. Jumlah entitas (`$1.entities.count`) di setiap section.
        // 2. Ditambah 1 untuk baris header setiap section.
        // Inisialisasi total dengan 0.
        dataSections.reduce(0) { $0 + $1.entities.count + 1 }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var currentRow = row // Salin indeks baris untuk iterasi lokal.

        // Iterasi melalui setiap section untuk menentukan baris mana yang sedang diminta.
        for section in dataSections {
            // === Penanganan Baris Header Section ===
            if currentRow == 0 {
                let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "HeaderCellIdentifier")
                // Coba untuk mendapatkan atau membuat ulang `GroupTableCellView` dengan identifier yang diberikan.
                if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? GroupTableCellView {
                    cell.isGroupView = true // Tandai sebagai tampilan grup (header).
                    // Set judul section, diformat sesuai dengan kategori pengelompokan.
                    cell.sectionTitle = formatTitleForSection(section.title)
                    // Atur font tebal jika tabel diurutkan berdasarkan kolom pertama.
                    cell.isBoldFont = isSortedByFirstColumn
                    return cell
                }
            }
            // === Penanganan Baris Data Entitas ===
            else if currentRow <= section.entities.count {
                // Dapatkan entitas yang sesuai dari section saat ini.
                // `currentRow - 1` karena baris 0 adalah header section.
                let entity = section.entities[currentRow - 1]

                // Periksa identifier kolom untuk menentukan data mana yang akan ditampilkan.
                switch tableColumn?.identifier.rawValue {
                case "Column1":
                    // Dapatkan atau buat ulang `NSTableCellView` untuk kolom "Column1".
                    guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "column1"), owner: self) as? NSTableCellView else {
                        return NSTableCellView() // Fallback jika gagal.
                    }

                    // Set nilai textField berdasarkan `selectedGroupCategory`.
                    switch selectedGroupCategory {
                    case "keperluan":
                        cell.textField?.stringValue = entity.acara?.value ?? ""
                    case "acara":
                        cell.textField?.stringValue = entity.keperluan?.value ?? ""
                    case "kategori":
                        cell.textField?.stringValue = entity.keperluan?.value ?? ""
                    default:
                        cell.textField?.stringValue = entity.kategori?.value ?? ""
                    }

                    // === Konfigurasi Warna untuk Baris yang Ditandai (Marker) ===
                    // Coba dapatkan `JumlahTransaksiRowView` untuk baris ini.
                    if let rowView = tableView.rowView(atRow: row, makeIfNecessary: true) as? JumlahTransaksiRowView {
                        if entity.ditandai {
                            // Atur warna dasar marker dan warna teks berdasarkan `jenis` transaksi.
                            let baseColor: NSColor
                            switch entity.jenisEnum {
                            case .pengeluaran:
                                baseColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0) // Merah muda
                                cell.textField?.textColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)
                                rowView.customTextColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)
                            case .pemasukan:
                                baseColor = NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) // Hijau terang
                                cell.textField?.textColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
                                rowView.customTextColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
                            case .lainnya:
                                baseColor = NSColor.systemOrange
                                cell.textField?.textColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
                                rowView.customTextColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
                            default:
                                baseColor = NSColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0) // Biru langit
                            }
                            rowView.isMarked = true // Aktifkan penandaan.
                            rowView.markerColor = baseColor // Set warna marker.
                        } else {
                            // Jika tidak ditandai, nonaktifkan penandaan dan set warna teks default.
                            rowView.isMarked = false
                            cell.textField?.textColor = NSColor.controlTextColor
                        }
                    }

                    cell.textField?.alphaValue = 1 // Pastikan opasitas penuh.
                    return cell

                case "Column2":
                    // Dapatkan atau buat ulang `NSTableCellView` untuk kolom "umum" (Column2).
                    guard let cellUmum = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "umum"), owner: self) as? NSTableCellView else {
                        return NSTableCellView() // Fallback jika gagal.
                    }

                    // Set nilai textField berdasarkan `selectedGroupCategory`.
                    switch selectedGroupCategory {
                    case "keperluan":
                        cellUmum.textField?.stringValue = entity.kategori?.value ?? ""
                    case "acara":
                        cellUmum.textField?.stringValue = entity.kategori?.value ?? ""
                    case "kategori":
                        cellUmum.textField?.stringValue = entity.acara?.value ?? ""
                    default:
                        cellUmum.textField?.stringValue = entity.acara?.value ?? ""
                    }

                    // Sesuaikan warna teks berdasarkan status `ditandai` dan `jenis` transaksi.
                    if !entity.ditandai {
                        cellUmum.textField?.textColor = NSColor.controlTextColor
                    } else {
                        switch entity.jenisEnum {
                        case .pengeluaran:
                            cellUmum.textField?.textColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)
                        case .pemasukan:
                            cellUmum.textField?.textColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
                        case .lainnya:
                            cellUmum.textField?.textColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
                        default:
                            cellUmum.textField?.textColor = NSColor.controlTextColor
                        }
                    }
                    cellUmum.textField?.alphaValue = 1
                    return cellUmum

                case "jumlah":
                    // Dapatkan atau buat ulang `NSTableCellView` untuk kolom "jumlah".
                    guard let cellUmum = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "umum"), owner: self) as? NSTableCellView else {
                        return NSTableCellView()
                    }

                    // Konfigurasi `NumberFormatter` untuk nilai mata uang.
                    formatter.numberStyle = .decimal
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 0
                    // Set nilai textField dengan format mata uang Rupiah.
                    cellUmum.textField?.stringValue = "Rp. " + (formatter.string(from: NSNumber(value: entity.jumlah)) ?? "")

                    // Sesuaikan warna teks berdasarkan jenis transaksi jika tidak ditandai.
                    if let jenisTransaksi = JenisTransaksi(rawValue: entity.jenis),
                       !entity.ditandai,
                       let rowView = tableView.rowView(atRow: row, makeIfNecessary: true) as? JumlahTransaksiRowView
                    {
                        switch jenisTransaksi {
                        case .pengeluaran:
                            cellUmum.textField?.textColor = NSColor.systemRed
                            rowView.customTextColor = NSColor.systemRed
                        case .pemasukan:
                            cellUmum.textField?.textColor = NSColor.systemGreen
                            rowView.customTextColor = NSColor.systemGreen
                        case .lainnya:
                            cellUmum.textField?.textColor = NSColor.systemOrange
                            rowView.customTextColor = NSColor.systemOrange
                        }
                    }
                    // Sesuaikan warna teks untuk baris yang ditandai (override jika perlu).
                    else if let rowView = tableView.rowView(atRow: row, makeIfNecessary: true) as? JumlahTransaksiRowView {
                        switch entity.jenisEnum {
                        case .pengeluaran:
                            cellUmum.textField?.textColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)
                            rowView.customTextColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)
                        case .pemasukan:
                            cellUmum.textField?.textColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
                            rowView.customTextColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
                        case .lainnya:
                            cellUmum.textField?.textColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
                            rowView.customTextColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
                        default:
                            cellUmum.textField?.textColor = NSColor.controlTextColor
                        }
                    }
                    cellUmum.textField?.alphaValue = 1
                    return cellUmum

                case "tgl":
                    // Dapatkan atau buat ulang `NSTableCellView` untuk kolom "tgl".
                    guard let cellUmum = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "umum"), owner: self) as? NSTableCellView else {
                        return NSTableCellView()
                    }

                    // Inisialisasi DateFormatter di sini untuk memastikan konfigurasi yang benar
                    // karena mungkin diakses setelah pembuatan cell.
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd MMMM yyyy" // Format default

                    // Sesuaikan format tanggal berdasarkan lebar kolom yang tersedia.
                    let availableWidth = tableColumn?.width ?? 0
                    if availableWidth <= 80 {
                        dateFormatter.dateFormat = "d/M/yy"
                    } else if availableWidth <= 120 {
                        dateFormatter.dateFormat = "d MMM yyyy"
                    } else {
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                    }

                    // Set nilai textField dengan tanggal yang diformat.
                    if let date = entity.tanggal {
                        cellUmum.textField?.stringValue = dateFormatter.string(from: date)
                    } else {
                        cellUmum.textField?.stringValue = "10-10-2023" // Nilai default jika tanggal nil.
                    }

                    cellUmum.textField?.alphaValue = 0.6 // Opasitas sedikit lebih rendah.
                    cellUmum.textField?.textColor = NSColor.controlTextColor // Warna teks default.
                    return cellUmum

                default:
                    break // Tidak melakukan apa-apa untuk kolom lain.
                }
            }
            // Jika baris saat ini bukan header atau entitas di section ini,
            // kurangi `currentRow` dengan jumlah baris di section ini (header + entitas)
            // dan lanjutkan ke section berikutnya.
            currentRow -= (section.entities.count + 1)
        }
        return nil // Kembalikan nil jika baris tidak ditemukan di section manapun.
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        currentSortDescriptor = sortDescriptor
        sortData(with: sortDescriptor)
        if let firstColumnSortDescriptor = tableView.tableColumns.first?.sortDescriptorPrototype {
            isSortedByFirstColumn = (firstColumnSortDescriptor.key == sortDescriptor.key)
        } else {
            isSortedByFirstColumn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.tableView.reloadData()
            if self.tableView.numberOfRows > 0 {
                self.tableView.hideRows(at: IndexSet([0]), withAnimation: [])
            }
        }
    }

    /// Menangani notifikasi ketika kolom `tableView` diubah ukurannya.
    ///
    /// Fungsi ini dipanggil secara otomatis ketika pengguna mengubah ukuran kolom tabel.
    /// Tujuan utamanya adalah untuk menyesuaikan format tampilan tanggal di kolom "tgl"
    /// berdasarkan lebar kolom yang baru. Jika kolom "tgl" diubah ukurannya, fungsi ini
    /// akan mengulang setiap baris yang terlihat, mengidentifikasi data tanggalnya,
    /// dan memformat ulang tampilan tanggal agar sesuai dengan lebar kolom yang tersedia.
    ///
    /// - Parameter notification: Notifikasi `Notification` yang dikirim oleh `NSTableView`
    ///   ketika salah satu kolomnya diubah ukurannya. `notification.object` adalah `NSTableView` itu sendiri.
    ///
    /// - Diperlukan:
    ///   - `dataSections`: Array data yang mengelola struktur section dan entitas tabel,
    ///     digunakan untuk menemukan entitas (data `siswa` dalam konteks ini) yang sesuai dengan setiap baris.
    ///   - `Entity`: Model data yang memiliki properti `tanggal` (tipe `Date?`).
    ///   - `NSTableCellView`: Tipe view sel yang digunakan untuk menampilkan data di kolom.
    ///   - `DateFormatter`: Digunakan untuk mengkonversi objek `Date` ke `String` dengan format yang berbeda.
    func tableViewColumnDidResize(_ notification: Notification) {
        // Pastikan notifikasi berasal dari NSTableView.
        guard let tableView = notification.object as? NSTableView else { return }

        // Periksa apakah kolom yang di-resize adalah kolom "tgl".
        // Jika kolom "tgl" ditemukan, kita ingin memproses penyesuaian format tanggal.
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            // Dapatkan indeks kolom "tgl".
            let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))

            // Loop melalui setiap baris di tabel untuk memperbarui tampilan tanggal.
            for row in 0 ..< tableView.numberOfRows {
                var currentRow = row // Variabel bantu untuk melacak posisi baris dalam struktur section.
                var foundEntity: Entity? // Variabel untuk menyimpan entitas yang ditemukan.

                // Temukan entitas yang sesuai dengan baris saat ini dalam `dataSections`.
                // Logika ini sama dengan yang digunakan di `tableView(_:viewFor:row:)`.
                for section in dataSections {
                    if currentRow == 0 {
                        // Ini adalah baris untuk header section, jadi lewati entitas.
                        break
                    } else if currentRow <= section.entities.count {
                        // Entitas ditemukan, set `foundEntity` dan keluar dari loop section.
                        foundEntity = section.entities[currentRow - 1]
                        break
                    } else {
                        // Baris saat ini berada di luar section ini, lanjutkan ke section berikutnya.
                        currentRow -= (section.entities.count + 1)
                    }
                }

                // Pastikan entitas (`siswa` dalam konteks ini) ditemukan untuk baris ini.
                guard let siswa = foundEntity else { continue }

                // Dapatkan `NSTableCellView` untuk sel di kolom "tgl" dan baris saat ini.
                // `makeIfNecessary: false` karena kita hanya ingin memperbarui view yang sudah ada.
                if let cellView = tableView.view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let textField = cellView.textField // Dapatkan text field di dalam sel.
                    var tanggalString = "" // String untuk menyimpan tanggal yang diformat.

                    // Inisialisasi `DateFormatter`.
                    let dateFormatter = DateFormatter()

                    // Dapatkan tanggal dari entitas.
                    if let tanggal = siswa.tanggal {
                        // Tentukan lebar kolom yang tersedia untuk menyesuaikan format tanggal.
                        // Gunakan `tableColumn?.width` dari kolom yang di-resize, bukan `textField!.bounds.width`
                        // karena `bounds.width` textField mungkin tidak mencerminkan lebar kolom penuh
                        // setelah resize (terutama jika ada padding/margin).
                        let availableWidth = tableView.tableColumns[columnIndex].width

                        if availableWidth <= 80 {
                            dateFormatter.dateFormat = "d/M/yy" // Format pendek (e.g., 1/1/25)
                        } else if availableWidth <= 120 {
                            dateFormatter.dateFormat = "d MMM yyyy" // Format sedang (e.g., 1 Jan 2025)
                        } else {
                            dateFormatter.dateFormat = "dd MMMM yyyy" // Format panjang (e.g., 01 Januari 2025)
                        }

                        // Format tanggal dan setel ke textField.
                        tanggalString = dateFormatter.string(from: tanggal)
                        textField?.stringValue = tanggalString
                        // Muat ulang hanya sel yang terpengaruh untuk memperbarui tampilannya.
                        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                    } else {
                        // Jika tanggal nil, set string kosong atau default.
                        textField?.stringValue = "10-10-2023" // Nilai default jika tanggal nil.
                        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                    }
                }
            }
        } else {
            // Jika kolom yang di-resize bukan "tgl", tidak ada tindakan spesifik yang diperlukan di sini.
            // Anda bisa menambahkan logika lain di sini jika ada kolom lain yang memerlukan penyesuaian khusus
            // saat diubah ukurannya.
        }
    }

    func tableViewColumnDidMove(_ notification: Notification) {
        updateColumnMenu()
    }
}

extension JumlahTransaksi: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false // Menonaktifkan seleksi kolom
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let (isGroupRow, _, _) = getRowInfoForRow(row)
        if isGroupRow {
            return false // Menonaktifkan seleksi untuk bagian (section)
        } else {
            return true // Mengizinkan seleksi untuk baris biasa di dalam bagian
        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        var currentRow = row
        for section in dataSections {
            if currentRow == 0 {
                return true // Ini adalah header section
            } else if currentRow <= section.entities.count {
                return false // Ini adalah data row
            }
            currentRow -= (section.entities.count + 1)
        }
        return false
    }

    /// Mengembalikan `NSTableRowView` kustom untuk baris tertentu di `NSTableView`.
    ///
    /// Fungsi ini adalah bagian dari protokol `NSTableViewDelegate` yang memungkinkan
    /// Anda menyediakan tampilan baris kustom untuk setiap baris di tabel.
    /// Ini memeriksa apakah baris yang diminta adalah baris header grup (section)
    /// atau baris data reguler, dan mengembalikan instance `NSTableRowView` yang sesuai
    /// (`CustomRowView` untuk header grup, `JumlahTransaksiRowView` untuk baris data).
    ///
    /// - Parameters:
    ///   - tableView: Instance `NSTableView` yang meminta tampilan baris.
    ///   - row: Indeks baris absolut (global) yang sedang diminta.
    ///
    /// - Returns: Sebuah instance `NSTableRowView` yang telah dikonfigurasi.
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        // Dapatkan informasi tentang baris: apakah ini baris grup (header section) atau bukan.
        let (isGroup, _, _) = getRowInfoForRow(row)

        if isGroup {
            // Jika ini adalah baris grup, gunakan ``DataSDI/CustomRowView`` dan setel gayanya.
            let rowView = CustomRowView()
            rowView.isGroupRowStyle = true
            return rowView
        } else {
            // Jika ini bukan baris grup, gunakan ``DataSDI/JumlahTransaksiRowView`` untuk baris data.
            return JumlahTransaksiRowView()
        }
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let columnIdentifier = tableView.tableColumns[columnIndex].identifier.rawValue
        if columnIdentifier == "Column1" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false // tidak memperbolehkan memindahkan kolom pertama.
        }
        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false // tidak memperbolehkan memindahkan ke tempat kolom pertama.
        }
        return true
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let (isGroup, _, _) = getRowInfoForRow(row)
        if isGroup {
            return 28.0
        } else {
            return tableView.rowHeight
        }
    }
}

extension JumlahTransaksi: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Jika menu yang akan ditampilkan adalah menu di toolbar.
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        }
        // Jika bukan menu di toolbar.
        else {
            updateTableMenu(menu)
        }
    }

    /// Memperbarui status dan visibilitas item-item dalam `NSMenu` yang diberikan,
    /// biasanya terkait dengan toolbar.
    ///
    /// Fungsi ini secara dinamis menyesuaikan item menu berdasarkan status `tableView` saat ini,
    /// seperti jumlah baris yang dipilih dan kategori pengelompokan yang aktif.
    /// Ini memastikan bahwa menu toolbar selalu mencerminkan kondisi aplikasi yang relevan.
    ///
    /// - Parameter menu: `NSMenu` yang akan diperbarui.
    ///
    /// - Terkait dengan:
    ///   - `tableView`: Sebuah instance `NSTableView` yang menyediakan informasi tentang
    ///     jumlah baris dan baris yang dipilih.
    ///   - `selectedGroupCategory`: Properti (diasumsikan `String`) yang menyimpan
    ///     kategori pengelompokan yang saat ini aktif.
    func updateToolbarMenu(_ menu: NSMenu) {
        // Pastikan `tableView` memiliki setidaknya satu baris. Jika tidak, keluar lebih awal.
        guard tableView.numberOfRows >= 1 else { return }

        // Coba temukan item menu spesifik berdasarkan judul atau identifier-nya.
        // Jika ada item penting yang tidak ditemukan, keluar untuk mencegah crash.
        guard let groupMenu = menu.item(withTitle: "Kelompokkan Menurut"),
              let refreshItem = menu.item(withTitle: "Muat Ulang"),
              let copyItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }),
              let salinSemua = menu.item(withTitle: "Salin Semua Transaksi")
        else { return }

        // Atur visibilitas item menu penting menjadi terlihat (tidak tersembunyi).
        groupMenu.isHidden = false
        refreshItem.isHidden = false
        salinSemua.isHidden = false

        // Perbarui judul item "Salin" dan visibilitasnya secara dinamis.
        var copyItemTitle = "Salin 1 catatan transaksi..." // Judul default untuk satu catatan.

        let selectedRowsCount = tableView.selectedRowIndexes.count // Dapatkan jumlah baris yang dipilih.
        if selectedRowsCount >= 1 {
            // Jika ada baris yang dipilih, perbarui judul untuk mencerminkan jumlahnya.
            copyItemTitle = "Salin \(selectedRowsCount) catatan transaksi..."
            copyItem.title = copyItemTitle
            copyItem.isHidden = false // Pastikan item "Salin" terlihat.
        } else {
            // Jika tidak ada baris yang dipilih, sembunyikan item "Salin".
            copyItem.isHidden = true
        }

        // Perbarui status centang submenu "Kelompokkan Menurut".
        if let submenu = groupMenu.submenu {
            for item in submenu.items {
                // Periksa identifier setiap item submenu (dikonversi ke huruf kecil).
                if let category = item.identifier?.rawValue.lowercased() {
                    // Setel status centang item: `.on` jika cocok dengan kategori pengelompokan yang dipilih,
                    // `.off` jika tidak.
                    item.state = (category == selectedGroupCategory) ? .on : .off
                }
            }
        }
    }

    /// Memperbarui status dan visibilitas item-item dalam `NSMenu` yang diberikan,
    /// menu konteks untuk `NSTableView`.
    ///
    /// Fungsi ini menyesuaikan item menu berdasarkan baris yang diklik atau dipilih di tabel.
    /// Ini mengontrol visibilitas item-item seperti "Kelompokkan Menurut", "Muat Ulang",
    /// "Salin", dan "Salin Semua Transaksi", serta memperbarui judul item "Salin"
    /// dan status centang submenu pengelompokan.
    ///
    /// - Parameter menu: `NSMenu` yang akan diperbarui (menu konteks tabel).
    ///
    /// - Terkait dengan:
    ///   - `tableView`: Sebuah instance `NSTableView` yang menyediakan informasi tentang
    ///     baris yang diklik (`clickedRow`), baris yang dipilih (`selectedRowIndexes`),
    ///     dan jumlah baris.
    ///   - `JumlahTransaksiRowView`: Subclass `NSTableRowView` kustom yang digunakan untuk
    ///     baris data, dengan properti `isGroupRowStyle`.
    ///   - `selectedGroupCategory`: Properti (diasumsikan `String`) yang menyimpan
    ///     kategori pengelompokan yang saat ini aktif.
    func updateTableMenu(_ menu: NSMenu) {
        // Coba temukan item menu spesifik berdasarkan judul atau identifier-nya.
        // Jika ada item penting yang tidak ditemukan, keluar untuk mencegah crash.
        guard let groupMenu = menu.item(withTitle: "Kelompokkan Menurut"),
              let copyItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" }),
              let refreshItem = menu.item(withTitle: "Muat Ulang"),
              let salinSemua = menu.item(withTitle: "Salin Semua Transaksi")
        else { return }

        // Dapatkan `rowView` untuk baris yang diklik.
        // Jika baris yang diklik adalah baris grup (header section) atau tidak ada rowView,
        // maka sembunyikan beberapa item menu yang tidak relevan untuk header.
        guard let rowView = tableView.rowView(atRow: tableView.clickedRow, makeIfNecessary: false) as? JumlahTransaksiRowView,
              !rowView.isGroupRowStyle
        else {
            groupMenu.isHidden = true // Sembunyikan menu pengelompokan.
            copyItem.isHidden = true // Sembunyikan opsi salin.
            refreshItem.isHidden = true // Sembunyikan opsi muat ulang.
            salinSemua.isHidden = true // Sembunyikan opsi salin semua.
            return // Keluar karena menu konteks diklik pada header atau tidak ada baris valid.
        }

        // Jika baris yang diklik adalah baris data (bukan header), tampilkan item menu yang relevan.
        groupMenu.isHidden = false
        copyItem.isHidden = false
        refreshItem.isHidden = false
        salinSemua.isHidden = false

        // Perbarui status centang submenu "Kelompokkan Menurut".
        if let submenu = groupMenu.submenu {
            for item in submenu.items {
                // Periksa identifier setiap item submenu (dikonversi ke huruf kecil).
                if let category = item.identifier?.rawValue.lowercased() {
                    // Setel status centang item: `.on` jika cocok dengan kategori pengelompokan yang dipilih,
                    // `.off` jika tidak.
                    item.state = (category == selectedGroupCategory) ? .on : .off
                }
            }
        }

        // Penanganan khusus jika tidak ada baris yang diklik valid (misalnya, klik di area kosong tabel).
        // Dalam kasus ini, opsi salin satu baris akan disembunyikan.
        guard tableView.clickedRow >= 0 else {
            groupMenu.isHidden = false // Menu pengelompokan tetap terlihat.
            refreshItem.isHidden = false // Opsi muat ulang tetap terlihat.
            copyItem.isHidden = true // Sembunyikan opsi salin satu baris.
            salinSemua.isHidden = false // Opsi salin semua tetap terlihat.
            return
        }

        // Perbarui judul item "Salin" secara dinamis.
        var copyItemTitle = "Salin 1 catatan transaksi..." // Judul default untuk satu catatan.
        let selectedRowsCount = tableView.selectedRowIndexes.count // Dapatkan jumlah baris yang dipilih.

        // Jika lebih dari satu baris dipilih DAN baris yang diklik termasuk dalam pilihan,
        // perbarui judul untuk mencerminkan jumlah baris yang dipilih.
        if selectedRowsCount > 1, tableView.selectedRowIndexes.contains(tableView.clickedRow) {
            copyItemTitle = "Salin \(selectedRowsCount) catatan transaksi..."
        }
        copyItem.title = copyItemTitle // Terapkan judul yang diperbarui.

        // Setelah semua penyesuaian, sembunyikan menu pengelompokan, muat ulang, dan salin semua
        // karena menu konteks ini kemungkinan besar hanya untuk operasi baris tunggal atau pilihan.
        // Ini mungkin menimpa visibilitas yang disetel di atas, tergantung pada alur yang diinginkan.
        groupMenu.isHidden = true
        refreshItem.isHidden = true
        salinSemua.isHidden = true
    }

    /// Membuat dan mengkonfigurasi instance `NSMenu`, yang berfungsi sebagai
    /// menu konteks atau menu umum untuk `NSTableView`.
    ///
    /// Fungsi ini menyiapkan berbagai item menu, termasuk opsi untuk memuat ulang data,
    /// mengelompokkan data, dan menyalin data. Item-item menu ini dikonfigurasi dengan
    /// judul, aksi, identifier, dan status awal yang sesuai.
    ///
    /// - Returns: Sebuah objek `NSMenu` yang telah sepenuhnya dikonfigurasi dengan
    ///   item-item menu dan submenu-nya.
    ///
    /// - Terkait dengan:
    ///   - ``selectedGroupCategory``: Properti `String` yang menentukan opsi pengelompokan
    ///     mana yang saat ini aktif dan harus dicentang di submenu.
    ///   - ``categoryMenuItems``: Sebuah array `[NSMenuItem]` yang digunakan untuk
    ///     menyimpan referensi ke item menu pengelompokan yang dibuat secara dinamis.
    ///   - ``muatUlang(_:)``: Metode aksi yang akan dipanggil ketika item menu
    ///     "Muat Ulang" dipilih.
    ///   - ``menuItemSelected(_:)``: Metode aksi yang akan dipanggil ketika salah satu
    ///     item menu kategori pengelompokan dipilih.
    ///   - ``copyAllRows(_:)``: Metode aksi yang akan dipanggil ketika item menu
    ///     "Salin Semua Transaksi" dipilih.
    ///   - ``copyDataToClipboard(_:)``: Metode aksi yang akan dipanggil ketika item menu
    ///     "Salin" dipilih.
    func buatItemMenu() -> NSMenu {
        // Inisialisasi instance NSMenu baru.
        let menu = NSMenu()

        // MARK: - Item Menu "foto" (Placeholder/Visual)

        // Buat item menu dengan judul "foto". Aksi diatur ke `nil` karena ini mungkin hanya visual.
        let foto = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        // Dapatkan gambar simbol sistem "ellipsis.circle".
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        // Buat konfigurasi simbol untuk skala besar.
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        // Terapkan konfigurasi skala besar ke gambar.
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        // Tetapkan gambar ke item menu.
        foto.image = largeActionImage
        // Sembunyikan item ini secara default; mungkin akan ditampilkan secara kondisional nanti.
        foto.isHidden = true
        // Tambahkan item menu "foto" ke menu utama.
        menu.addItem(foto)

        // MARK: - Item Menu "Muat Ulang"

        // Buat item menu "Muat Ulang" dan kaitkan dengan metode aksi `muatUlang`.
        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        // Tambahkan item menu "Muat Ulang" ke menu utama.
        menu.addItem(refresh)

        // MARK: - Submenu "Kelompokkan Menurut"

        // Buat item menu utama untuk submenu pengelompokan. Aksi diatur ke `nil` karena ini akan memiliki submenu.
        let groupMenu = NSMenuItem(title: "Kelompokkan Menurut", action: nil, keyEquivalent: "")
        // Buat instance NSMenu baru untuk submenu.
        let submenu = NSMenu()
        // Definisikan kategori pengelompokan yang tersedia.
        let categories = ["keperluan", "acara", "kategori"]

        // Iterasi melalui kategori untuk membuat item submenu secara dinamis.
        for (index, category) in categories.enumerated() {
            // Buat item menu untuk setiap kategori, dengan judul dikapitalisasi.
            let menuItem = NSMenuItem(title: category.capitalized, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            // Tetapkan tag item menu dengan indeksnya (berguna untuk identifikasi di `menuItemSelected`).
            menuItem.tag = index
            // Tetapkan identifier item menu (berguna untuk akses programatik).
            menuItem.identifier = NSUserInterfaceItemIdentifier(category.capitalized)
            // Setel status centang item menu: `.on` jika kategori cocok dengan `selectedGroupCategory`,
            // `.off` jika tidak.
            menuItem.state = (category == selectedGroupCategory) ? .on : .off
            // Tambahkan item menu ke array `categoryMenuItems` untuk referensi eksternal.
            categoryMenuItems.append(menuItem)
            // Tambahkan item menu ke submenu.
            submenu.addItem(menuItem)
        }
        // Tetapkan submenu yang telah dibuat ke item menu "Kelompokkan Menurut".
        groupMenu.submenu = submenu
        // Tetapkan identifier untuk item menu "Kelompokkan Menurut".
        groupMenu.identifier = NSUserInterfaceItemIdentifier("GroupMenu")
        // Tambahkan item menu "Kelompokkan Menurut" ke menu utama.
        menu.addItem(groupMenu)

        // MARK: - Separator dan Item Menu Salin

        // Tambahkan item pemisah untuk memisahkan secara visual bagian-bagian menu.
        menu.addItem(NSMenuItem.separator())

        // Buat item menu "Salin Semua Transaksi" dan kaitkan dengan metode aksi `copyAllRows`.
        let salinSemua = NSMenuItem(title: "Salin Semua Transaksi", action: #selector(copyAllRows(_:)), keyEquivalent: "")
        // Tambahkan item menu "Salin Semua Transaksi" ke menu utama.
        menu.addItem(salinSemua)

        // Buat item menu "Salin" dan kaitkan dengan metode aksi `copyDataToClipboard`.
        let copyDataItem = NSMenuItem(title: "Salin", action: #selector(copyDataToClipboard(_:)), keyEquivalent: "")
        // Tetapkan identifier untuk item menu "Salin".
        copyDataItem.identifier = NSUserInterfaceItemIdentifier("salin")
        // Tambahkan item menu "Salin" ke menu utama.
        menu.addItem(copyDataItem)

        // Kembalikan menu yang telah sepenuhnya dikonfigurasi.
        return menu
    }

    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn, column.identifier.rawValue == "tgl" else {
            return
        }

        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }

    /// Menentukan indeks penyisipan yang benar untuk `newEntity` dalam sebuah `section` tertentu,
    /// memastikan bahwa entitas-entitas dalam section tersebut tetap terurut sesuai dengan
    /// `NSSortDescriptor` yang diberikan.
    ///
    /// Fungsi ini sangat penting untuk menjaga data tetap terurut saat menambahkan item baru
    /// secara inkremental tanpa perlu mengurutkan ulang seluruh section setiap kali.
    ///
    /// - Parameters:
    ///   - newEntity: Objek `Entity` yang perlu dimasukkan.
    ///   - section: Indeks berbasis nol dari section target dalam `dataSections` di mana
    ///     entitas baru akan dimasukkan.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan
    ///     (kunci dan arah menaik/menurun).
    ///
    /// - Returns: `Int?` yang merepresentasikan indeks berbasis nol di mana `newEntity`
    ///   harus dimasukkan. Mengembalikan `nil` jika indeks `section` berada di luar batas.
    ///
    /// - Terkait dengan:
    ///   - `dataSections`: Properti yang berisi data terkelompok (array of sections).
    ///   - `Entity`: Tipe model data yang memiliki properti seperti `acara`, `keperluan`,
    ///     `kategori`, `jumlah`, `tanggal`, dan `jenis`.
    ///   - `selectedGroupCategory`: Properti `String` yang menunjukkan kategori pengelompokan
    ///     yang aktif, memengaruhi properti `Entity` mana yang digunakan untuk perbandingan
    ///     dalam kasus "Column1" dan "Column2".
    func insertionIndex(for newEntity: Entity, in section: Int, using sortDescriptor: NSSortDescriptor) -> Int? {
        // Pastikan indeks section valid. Jika tidak, kembalikan nil.
        guard section < dataSections.count else { return nil }
        // Dapatkan array entitas dari section yang dituju.
        let entities = dataSections[section].entities

        // MARK: - Fungsi Bantu untuk Membandingkan Entitas

        /// Fungsi bantu internal untuk membandingkan dua entitas berdasarkan `sortDescriptor`.
        /// Ini adalah logika pengurutan inti yang sama dengan yang digunakan dalam `sortData`.
        ///
        /// - Parameters:
        ///   - entity1: Entitas pertama untuk dibandingkan.
        ///   - entity2: Entitas kedua untuk dibandingkan.
        /// - Returns: `true` jika `entity1` harus datang sebelum `entity2` dalam urutan yang diurutkan.
        func compare(_ entity1: Entity, _ entity2: Entity) -> Bool {
            switch sortDescriptor.key {
            case "Column1":
                // Logika perbandingan untuk "Column1" tergantung pada kategori pengelompokan yang dipilih.
                switch selectedGroupCategory {
                case "keperluan":
                    // Jika dikelompokkan berdasarkan keperluan, urutkan berdasarkan `acara`.
                    return sortDescriptor.ascending
                        ? (entity1.acara?.value ?? "") < (entity2.acara?.value ?? "")
                        : (entity1.acara?.value ?? "") > (entity2.acara?.value ?? "")
                case "acara", "kategori":
                    // Jika dikelompokkan berdasarkan acara atau kategori, urutkan berdasarkan `keperluan`.
                    return sortDescriptor.ascending
                        ? (entity1.keperluan?.value ?? "") < (entity2.keperluan?.value ?? "")
                        : (entity1.keperluan?.value ?? "") > (entity2.keperluan?.value ?? "")
                default:
                    // Default: urutkan berdasarkan `kategori`.
                    return sortDescriptor.ascending
                        ? (entity1.kategori?.value ?? "") < (entity2.kategori?.value ?? "")
                        : (entity1.kategori?.value ?? "") > (entity2.kategori?.value ?? "")
                }
            case "Column2":
                // Logika perbandingan untuk "Column2" tergantung pada kategori pengelompokan yang dipilih.
                switch selectedGroupCategory {
                case "keperluan", "acara":
                    // Jika dikelompokkan berdasarkan keperluan atau acara, urutkan berdasarkan `kategori`.
                    return sortDescriptor.ascending
                        ? (entity1.kategori?.value ?? "") < (entity2.kategori?.value ?? "")
                        : (entity1.kategori?.value ?? "") > (entity2.kategori?.value ?? "")
                case "kategori":
                    // Jika dikelompokkan berdasarkan kategori, urutkan berdasarkan `acara`.
                    return sortDescriptor.ascending
                        ? (entity1.acara?.value ?? "") < (entity2.acara?.value ?? "")
                        : (entity1.acara?.value ?? "") > (entity2.acara?.value ?? "")
                default:
                    // Default: urutkan berdasarkan `acara`.
                    return sortDescriptor.ascending
                        ? (entity1.acara?.value ?? "") < (entity2.acara?.value ?? "")
                        : (entity1.acara?.value ?? "") > (entity2.acara?.value ?? "")
                }
            case "jumlah":
                // Urutkan berdasarkan `jumlah`. Jika `jumlah` sama, gunakan `jenis` sebagai kunci sekunder.
                return entity1.jumlah == entity2.jumlah
                    ? sortDescriptor.ascending
                    ? (entity1.jenisEnum?.title ?? "") < (entity2.jenisEnum?.title ?? "")
                    : (entity1.jenisEnum?.title ?? "") > (entity2.jenisEnum?.title ?? "")
                    : sortDescriptor.ascending
                    ? entity1.jumlah < entity2.jumlah
                    : entity1.jumlah > entity2.jumlah
            case "tgl":
                // Urutkan berdasarkan `tanggal`.
                if let date1 = entity1.tanggal, let date2 = entity2.tanggal {
                    // Jika tanggal sama, gunakan `jenis` sebagai kunci sekunder.
                    return date1 == date2
                        ? sortDescriptor.ascending
                        ? (entity1.jenisEnum?.title ?? "") < (entity2.jenisEnum?.title ?? "")
                        : (entity1.jenisEnum?.title ?? "") > (entity2.jenisEnum?.title ?? "")
                        : sortDescriptor.ascending
                        ? date1 < date2
                        : date1 > date2
                }
                // Jika salah satu atau kedua tanggal adalah nil, anggap tidak ada urutan yang ditentukan
                // (atau sesuaikan dengan kebutuhan aplikasi Anda, misal: nil selalu di akhir).
                return false
            default:
                // Untuk kunci pengurutan yang tidak dikenal, anggap tidak ada urutan yang ditentukan.
                return false
            }
        }

        // MARK: - Menemukan Indeks Penyisipan

        // Gunakan `firstIndex(where:)` untuk menemukan indeks pertama di mana `newEntity`
        // harus mendahului entitas yang ada di array. Ini secara efektif melakukan pencarian biner
        // atau linear scan untuk menemukan titik penyisipan yang benar.
        let index = entities.firstIndex { compare(newEntity, $0) }

        // Jika `firstIndex` mengembalikan nil, berarti `newEntity` harus ditempatkan di akhir array.
        // Dalam kasus ini, kembalikan `entities.count` sebagai indeks penyisipan.
        return index ?? entities.count
    }

    /// Memperbarui menu kustomisasi kolom untuk `tableView`.
    ///
    /// Fungsi ini bertanggung jawab untuk mengatur visibilitas dan status item-item
    /// dalam menu yang memungkinkan pengguna untuk menampilkan atau menyembunyikan kolom tabel.
    /// Ini secara khusus mengecualikan kolom "tgl" (tanggal) dari kontrol pengguna melalui menu ini,
    /// memastikan kolom tersebut selalu memiliki perilaku visibilitas yang konsisten.
    ///
    /// - Terkait dengan:
    ///   - `tableView`: Instance `NSTableView` yang kolom-kolomnya akan dikelola.
    ///   - `ReusableFunc.updateColumnMenu`: Sebuah metode statis/kelas yang diharapkan ada
    ///     di `ReusableFunc` untuk menangani logika pembaruan menu kolom yang sebenarnya.
    ///   - `@objc toggleColumnVisibility(_:)`: Metode aksi yang akan dipanggil ketika
    ///     item menu visibilitas kolom dipilih oleh pengguna.
    func updateColumnMenu() {
        var includeIdentifier: [String] = [] // Array untuk menyimpan identifier kolom yang akan dimasukkan dalam menu.

        // Iterasi melalui semua kolom tabel.
        for column in tableView.tableColumns {
            // Jika identifier kolom BUKAN "tgl", tambahkan ke daftar `includeIdentifier`.
            // Ini berarti kolom "tgl" akan dikecualikan dari menu kontrol visibilitas.
            if column.identifier.rawValue != "tgl" {
                includeIdentifier.append(column.identifier.rawValue)
            }
        }

        // Delegasikan logika pembaruan menu yang sebenarnya ke fungsi pembantu `ReusableFunc.updateColumnMenu`.
        // Parameter `exceptions` di sini kemungkinan berarti kolom-kolom yang *harus* disertakan dalam menu,
        // sehingga kolom "tgl" menjadi pengecualian dari daftar ini.
        ReusableFunc.updateColumnMenu(
            tableView,
            tableColumns: tableView.tableColumns,
            exceptions: includeIdentifier, // Daftar identifier kolom yang dapat dikontrol oleh pengguna.
            target: self, // Target untuk aksi menu item (objek saat ini).
            selector: #selector(toggleColumnVisibility(_:)) // Aksi yang dipanggil saat item menu kolom dipilih.
        )
    }
}
