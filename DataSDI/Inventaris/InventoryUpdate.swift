//
//  InventoryUpdate.swift
//  Data SDI
//
//  Created by MacBook on 09/08/25.
//

import Cocoa

// MARK: - CRUD

extension InventoryView {
    /// Fungsi untuk menambah kolom baru
    /// - Parameters:
    ///   - name: Nama kolom yang akan ditambahkan.
    ///   - type: Tipe kolom di database. Untuk saat ini hanya mendukung tipe string saja.
    func addColumn(name: String, type _: Any.Type) async {
        // Menambah kolom baru ke database
        await manager.addColumn(name: name, type: String.self)
        addTableColumn(name: name) // Menambah kolom baru ke NSTableView
        data = await manager.loadData() // Mendapatkan data yang baru di database
        await MainActor.run {
            tableView(self.tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
            // muat ulang seluruh baris di tableView
        }
    }

    /// Fungsi untuk menambah kolom ke NSTableView
    /// - Parameter name: Nama kolom yang akan ditambahkan
    func addTableColumn(name: String) {
        /// Membuat Instance `NSTableColumn` dengan identifier yang sesuai nama.
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
        tableColumn.title = name
        tableView.addTableColumn(tableColumn)
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu()
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAddColumn(name)
        })
        setupDescriptor()
        updateUndoRedo()
    }

    /// Fungsi untuk membatalkan penambahan kolom yang dicatat di ``myUndoManager``
    ///
    /// Kolom tidak langsung dihapus di database. Akan tetapi disimpan
    /// di dalam Array ``DataSDI/SingletonData/undoAddColumns``
    /// semua kolom yang ada di array ini akan dihapus ketika:
    /// - Aplikasi akan ditutup.
    /// - Pengguna mengklik toolbar item ``DataSDI/WindowController/simpanToolbar``
    /// - Pengguna menyimpan melalui ⌘S.
    /// - Parameter name: Nama kolom yang akan dicari.
    func undoAddColumn(_ name: String) {
        guard let index = SingletonData.columns.firstIndex(where: { $0.name == name }) else { return }

        // Pastikan index valid
        guard index < SingletonData.columns.count else { return }

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[name] ?? "")) // Simpan ID dan nilai kolom
            }
        }
        SingletonData.undoAddColumns.append((columnName: name, columnData: columnData))

        guard let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == name }) else { return }
        tableView.removeTableColumn(column)

        // Reload data pada table view
        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
                removeMenuItem(for: name)
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoAddColumn(columnName: name)
        })
        updateUndoRedo()
        setupDescriptor()
    }

    /// Fungsi untuk mengulangi penambahan kolom yang dicatat di ``myUndoManager``
    /// - Parameter columnName: Nama kolom yang akan dicari.
    func redoAddColumn(columnName _: String) {
        guard !SingletonData.undoAddColumns.isEmpty else { return }
        let lastDeleted = SingletonData.undoAddColumns.removeLast()
        let columnName = lastDeleted.columnName
        let columnData = lastDeleted.columnData

        // Tambahkan kolom kembali ke database dan table view

        let newColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
        newColumn.title = columnName
        tableView.addTableColumn(newColumn)

        // Kembalikan data kolom ke baris dengan ID yang sesuai
        for (index, row) in data.enumerated() {
            if let id = row["id"] as? Int64 {
                // Cari nilai yang sesuai dengan ID
                if let matchedData = columnData.first(where: { $0.id == id }) {
                    data[index][columnName] = matchedData.value // Mengembalikan data berdasarkan ID yang cocok
                }
            }
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAddColumn(columnName)
        })
        // Reload table view dengan data yang diperbarui
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu()
        updateUndoRedo()
        setupDescriptor()
    }

    /// Fungsi untuk menghapus kolom dari database dan NSTableView
    /// - Parameter name: Nama kolom yang akan dihapus.
    func deleteColumn(at name: String) {
        guard let index = SingletonData.columns.firstIndex(where: { $0.name == name }) else { return }

        // Pastikan index valid
        guard index < SingletonData.columns.count else { return }

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[name] ?? "")) // Simpan ID dan nilai kolom
            }
        }
        SingletonData.deletedColumns.append((columnName: name, columnData: columnData))

        // Hapus kolom dari database dan tabel
        // manager.deleteColumn(table: "main_table", nama: columnToDelete)

        guard let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == name }) else { return }
        tableView.removeTableColumn(column)

        // Reload data pada table view
        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)

                removeMenuItem(for: name)
                myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                    self?.undoDeleteColumn()
                })
                updateUndoRedo()
                setupDescriptor()
            }
        }
    }

    /// Fungsi untuk untuk menghapus menu item di header menu ``tableView``
    /// yang berkaitan dengan nama kolom yang diberikan.
    ///
    /// Dijalankan ketika menghapus kolom dari ``tableView``.
    /// - Parameter columnName: Nama menu item yang akan dihapus.
    func removeMenuItem(for columnName: String) {
        if let headerMenu = tableView.headerView?.menu {
            // Mencari item menu yang ingin dihapus
            if let itemToRemove = headerMenu.item(withTitle: "Hapus \(columnName)") {
                headerMenu.removeItem(itemToRemove)
            }
            if let hideToRemove = headerMenu.item(withTitle: "\(columnName)") {
                headerMenu.removeItem(hideToRemove)
            }
            if let editToRemove = headerMenu.item(withTitle: "Edit \(columnName)") {
                headerMenu.removeItem(editToRemove)
            }
        }
    }

    /// Fungsi untuk menangani tombol tambah kolom.
    ///
    /// Memeriksa beberapa kondisi sebelum menambahkan kolom baru:
    /// 1. Nama kolom tidak kosong.
    /// 2. Kolom tidak sama dengan nama kolom yang sudah ada (case-insensitive dan setelah normalisasi).
    ///    Normalisasi meliputi:
    ///    - Mengganti `;` dengan `:` (ini mungkin digunakan untuk membersihkan input).
    ///    - Mengubah ke huruf kecil untuk perbandingan yang tidak peka huruf besar/kecil.
    ///    - Menghapus spasi dan baris baru di awal/akhir string.
    @IBAction func addColumnButtonClicked(_: Any) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "add-pos")
        alert.messageText = "Tambah Kolom Baru"
        alert.informativeText = "Masukkan nama kolom baru:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 285, height: 24))
        inputTextField.placeholderString = "Nama kolom baru"
        inputTextField.bezelStyle = .roundedBezel
        alert.accessoryView = inputTextField

        alert.window.initialFirstResponder = inputTextField
        alert.beginSheetModal(for: view.window!) { [self] response in
            if response == .alertFirstButtonReturn {
                // Mendapatkan nilai nama kolom dari input pengguna.
                let columnName = inputTextField.stringValue

                if !columnName.isEmpty, !SingletonData.columns.contains(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == columnName.replacingOccurrences(of: ";", with: ":").lowercased() }) {
                    // Jika semua kondisi terpenuhi, inisiasi Task asinkron.
                    // Task ini akan memanggil fungsi `addColumn` untuk menambahkan kolom baru.
                    // Nama kolom akan dinormalisasi (mengganti `;` dengan `:`, kapitalisasi, dan trim spasi)
                    // dan tipenya akan diatur sebagai `String.self`.
                    Task {
                        await addColumn(name: columnName.replacingOccurrences(of: ";", with: ":").capitalizedAndTrimmed(), type: String.self)
                    }
                } else {
                    let aler = NSAlert()
                    aler.messageText = "Format Kolom Tidak Didukung"
                    aler.informativeText = "Nama kolom tidak boleh sama dan tidak boleh kosong."
                    aler.runModal()
                }
            }
        }
    }

    /// Fungsi untuk menangani tombol edit kolom.
    /// Menggunakan implementasi ``editNamaKolom(_:kolomBaru:)``.
    @IBAction func editNamaKolom(_ sender: NSMenuItem) {
        guard let columnIdentifier = sender.representedObject as? NSUserInterfaceItemIdentifier else { return }
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.messageText = "Edit Nama Kolom"
        alert.informativeText = "Masukkan nama kolom baru:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 285, height: 24))
        inputTextField.placeholderString = "Nama kolom baru"
        inputTextField.bezelStyle = .roundedBezel
        alert.accessoryView = inputTextField

        alert.window.initialFirstResponder = inputTextField

        alert.beginSheetModal(for: view.window!) { [self] response in
            if response == .alertFirstButtonReturn {
                editNamaKolom(columnIdentifier.rawValue, kolomBaru: inputTextField.stringValue)
            }
        }
    }

    /// Mengubah nama sebuah kolom yang ada, baik pada struktur database maupun pada tampilan UI tabel.
    /// Fungsi ini dirancang untuk beroperasi secara asinkron untuk menjaga responsivitas aplikasi.
    /// Ia juga secara cerdas mencatat perubahan ini untuk memungkinkan fungsionalitas undo/redo.
    ///
    /// - Parameters:
    ///   - kolomLama: `String` yang menunjukkan nama kolom saat ini yang akan diubah.
    ///   - kolomBaru: `String` yang menunjukkan nama baru yang diinginkan untuk kolom tersebut.
    func editNamaKolom(_ kolomLama: String, kolomBaru: String) {
        // Sebuah dictionary untuk menyimpan nilai-nilai lama dari kolom yang diubah,
        // diindeks berdasarkan ID (Int64) dari setiap entitas. Ini penting untuk operasi undo.
        var previousValues: [Int64: Any] = [:]

        // Memulai tugas asinkron dengan prioritas latar belakang (`.background`).
        // Ini memastikan bahwa operasi yang memakan waktu (seperti interaksi database)
        // tidak memblokir antrean utama (UI) aplikasi.
        Task(priority: .background) { [weak self] in
            // Verifikasi dua hal penting:
            // 1. Pastikan operasi penggantian nama kolom di database berhasil.
            //    `DynamicTable.shared.renameColumn` sebagai fungsi yang menangani hal ini.
            // 2. Pastikan `self` (Instance kelas saat ini) masih ada dan belum dilepaskan dari memori.
            guard await ((try? DynamicTable.shared.renameColumn("main_table", kolomLama: kolomLama, kolomBaru: kolomBaru)) != nil),
                  let self
            else {
                // Jika salah satu kondisi gagal, hentikan eksekusi Task ini.
                return
            }

            // Iterasi melalui setiap baris data dalam model lokal (`self.data`).
            for i in 0 ..< data.count {
                // Dapatkan ID dari baris saat ini. Jika tidak ada ID, lewati baris ini.
                guard let id = data[i]["id"] as? Int64 else { continue }
                // Coba hapus nilai lama dari kolom `kolomLama` dan simpan nilai tersebut.
                if let oldValue = data[i].removeValue(forKey: kolomLama) {
                    // Simpan nilai lama ke dalam `previousValues` menggunakan ID sebagai kunci.
                    previousValues[id] = oldValue
                    // Tetapkan nilai lama tersebut ke kolom dengan nama `kolomBaru` di model data.
                    data[i][kolomBaru] = oldValue
                }
            }

            // Kembali ke antrean utama (`MainActor`) untuk melakukan pembaruan UI.
            // Semua manipulasi UI harus dilakukan di sini untuk memastikan thread-safety.
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Perbarui objek `NSTableColumn` yang sesuai di `tableView`.
                if let column = tableView.tableColumn(withIdentifier: .init(kolomLama)) {
                    column.title = kolomBaru // Ganti judul kolom di UI.
                    column.identifier = .init(kolomBaru) // Ganti identifier kolom.
                    // Perbarui prototipe sort descriptor untuk kolom, agar pengurutan tetap berfungsi.
                    column.sortDescriptorPrototype = NSSortDescriptor(key: kolomBaru, ascending: true)
                }

                // Perbarui deskriptor pengurutan yang aktif di tabel.
                // Jika ada sort descriptor yang menggunakan `kolomLama` sebagai kunci,
                // ubah kuncinya menjadi `kolomBaru` sambil mempertahankan arah pengurutan.
                tableView.sortDescriptors = tableView.sortDescriptors.map {
                    $0.key == kolomLama ? NSSortDescriptor(key: kolomBaru, ascending: $0.ascending) : $0
                }

                // Memanggil `setupColumnMenu` untuk meregenerasi menu kolom,
                // memastikan nama kolom yang baru ditampilkan dengan benar.
                setupColumnMenu()
                // Muat ulang data tabel untuk merefleksikan perubahan nama kolom di sel-selnya.
                tableView.reloadData()
            }
        }
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoEditNamaKolom(kolomLama: kolomLama, kolomBaru: kolomBaru, previousValues: previousValues)
        }

        updateUndoRedo()
    }

    /// Membatalkan perubahan nama kolom yang sebelumnya telah dilakukan.
    /// Fungsi ini mengembalikan nama kolom baik di database maupun di UI tabel
    /// ke kondisi semula, dan mengembalikan nilai-nilai data ke kolom yang benar.
    /// Ini adalah bagian penting dari fungsionalitas undo, yang juga menyiapkan operasi redo.
    ///
    /// - Parameters:
    ///   - kolomLama: `String` yang merupakan nama kolom asli (sebelum diubah).
    ///   - kolomBaru: `String` yang merupakan nama kolom setelah diubah (saat ini).
    ///   - previousValues: `[Int64: Any]` sebuah dictionary yang berisi nilai-nilai data lama,
    ///                     diindeks berdasarkan ID entitas, yang disimpan saat operasi `editNamaKolom` terjadi.
    func undoEditNamaKolom(kolomLama: String, kolomBaru: String, previousValues: [Int64: Any]) {
        Task(priority: .background) { [weak self] in
            guard await ((try? DynamicTable.shared.renameColumn("main_table", kolomLama: kolomBaru, kolomBaru: kolomLama)) != nil), let self else { return }
            for i in 0 ..< data.count {
                guard let id = data[i]["id"] as? Int64 else { continue }
                // Periksa apakah ada nilai lama yang disimpan untuk ID ini.
                if let oldValue = previousValues[id] {
                    // Hapus nilai dari kolom dengan `kolomBaru` (nama saat ini).
                    data[i].removeValue(forKey: kolomBaru)
                    // Tetapkan `oldValue` (nilai asli) ke kolom dengan `kolomLama` (nama asli).
                    data[i][kolomLama] = oldValue
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                // Perbarui objek `NSTableColumn` yang sesuai di `tableView`.
                // Kita mencari kolom dengan `identifier` `kolomBaru` (nama yang diubah).
                if let column = tableView.tableColumn(withIdentifier: .init(kolomBaru)) {
                    column.title = kolomLama
                    column.identifier = .init(kolomLama)
                    // Perbarui prototipe sort descriptor untuk kolom, agar pengurutan tetap berfungsi.
                    column.sortDescriptorPrototype = NSSortDescriptor(key: kolomLama, ascending: true)
                }

                // Perbarui deskriptor pengurutan yang aktif di tabel.
                // Jika ada sort descriptor yang menggunakan `kolomBaru` sebagai kunci,
                // ubah kuncinya kembali menjadi `kolomLama` sambil mempertahankan arah pengurutan.
                tableView.sortDescriptors = tableView.sortDescriptors.map {
                    $0.key == kolomBaru ? NSSortDescriptor(key: kolomLama, ascending: $0.ascending) : $0
                }
                setupColumnMenu()
                tableView.reloadData()
            }
        }
        // Redo
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.editNamaKolom(kolomLama, kolomBaru: kolomBaru)
        }
        updateUndoRedo()
    }

    /// Fungsi yang menangani tombol hapus.
    ///
    /// Bisa juga melalui Menu Bar atau pintasan ⌘⌫.
    /// - Catatan:
    ///     - Data tidak langsung dihapus dari database
    /// melainkan disimpan di ``DataSDI/SingletonData/deletedInvID``
    /// dan dihapus ketika pengguna menyiimpan perubahan
    /// atau ketika pengguna mengkonfirmasi alert ketika aplikasi akan ditutup.
    @IBAction func delete(_: Any) {
        let rows = tableView.selectedRowIndexes

        // Dapatkan ID untuk setiap baris yang dipilih
        for row in rows {
            if let idValue = data[row]["id"] as? Int64 {
                SingletonData.deletedInvID.insert(idValue)
            }
        }

        // Memulai pembaruan batch untuk `tableView`.
        // Ini mengoptimalkan kinerja dengan menunda pembaruan visual hingga `endUpdates()` dipanggil.
        tableView.beginUpdates()
        // Memulai kelompok undo. Semua operasi undo yang didaftarkan antara `beginUndoGrouping()`
        // dan `endUndoGrouping()` akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()
        // Mengiterasi baris yang dipilih dalam urutan terbalik.
        // Mengiterasi secara terbalik penting saat menghapus item dari array
        // agar indeks baris yang tersisa tidak bergeser secara tidak terduga.
        for row in rows.reversed() {
            // Menghapus data dari array model lokal (`self.data`) pada indeks baris saat ini.
            let deletedData = data.remove(at: row)
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.undoHapus(deletedData)
            })
            // Memberi tahu `tableView` untuk menghapus baris secara visual dengan animasi `slideDown`.
            tableView.removeRows(at: IndexSet([row]), withAnimation: .slideDown)
            // Logika untuk memilih baris setelah penghapusan.
            // Jika baris yang dihapus adalah baris terakhir, pilih baris sebelumnya.
            if row == tableView.numberOfRows { // Perhatikan: `numberOfRows` sudah diperbarui setelah `removeRows`
                tableView.selectRowIndexes(IndexSet([row - 1]), byExtendingSelection: false)
            } else {
                // Jika tidak, pilih baris yang sekarang berada di posisi baris yang dihapus.
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            }
        }
        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()
        tableView.endUpdates()
        updateUndoRedo()
    }

    /// Memanggil ``deleteColumn(at:)`` ketika menghapus kolom.
    @IBAction func deleteColumnButtonClicked(_ sender: NSMenuItem) {
        guard let columnIdentifier = sender.representedObject as? NSUserInterfaceItemIdentifier else { return }

        // Mencari index kolom yang sesuai dengan identifier
        if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier == columnIdentifier }) {
            let alert = NSAlert()
            alert.messageText = "Hapus Kolom"
            alert.informativeText = "Apakah Anda yakin ingin menghapus kolom \(tableView.tableColumns[columnIndex].title)?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Hapus")
            alert.addButton(withTitle: "Batalkan")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                deleteColumn(at: columnIdentifier.rawValue)
            }
        }
        updateUndoRedo()
    }

    /// Fungsi yang menangani tombol tambah data.
    @IBAction func addRowButtonClicked(_: Any) {
        // Membuat dictionary baru berdasarkan kolom yang ada

        Task { [weak self] in
            guard let self else { return }
            var newData: [String: Any] = [:]
            let currentDate = SingletonData.dateFormatter.string(from: Date())

            for column in SingletonData.columns {
                if column.type == String.self {
                    if column.name == "Nama Barang" {
                        newData[column.name] = "Nama Barang"
                    } else if column.name == "Tanggal Dibuat" {
                        newData[column.name] = currentDate
                    } else {
                        newData[column.name] = "" // Nilai default untuk kolom String lainnya
                    }
                } else if column.type == Int64.self {
                    newData[column.name] = 0 // Nilai default untuk kolom Integer
                }
            }

            // Menambahkan data baru ke array data di baris pertama
            data.insert(newData, at: 0)

            // Simpan data baru ke database dan dapatkan ID yang baru
            guard let newId = await manager.insertData(newData) else { return }

            // Update newData dengan ID yang baru
            data[0]["id"] = newId // Menyimpan ID baru ke dictionary data
            data[0]["Tanggal Dibuat"] = currentDate // Hari ini
            data[0]["Nama Barang"] = "Nama Barang" // default: Nama barang
            self.newData.insert(newId) // insert ke data

            await MainActor.run { [weak self] in
                guard let self else { return }
                // Tambahkan baris ke table view setelah menambahkan data
                tableView.insertRows(at: IndexSet([0]), withAnimation: .slideUp)
                tableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang")) //
                AppDelegate.shared.editorManager.startEditing(row: 0, column: columnIndexNamaBarang)
                myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                    self?.undoAddRows([newId])
                })
            }
        }
    }

    /// Fungsi untuk menambahkan foto baru ke database.
    ///
    /// Foto dapat ditambahkan melalui drop ke row atau ke tableView.
    /// - Parameters:
    ///   - row: Baris di ``tableView`` dan ``data``
    ///   - imageData: `Data` foto yang ditambahkan.
    func saveImageToDatabase(atRow row: Int, imageData: Data) async {
        let rowData = data[row]
        guard let id = rowData["id"] as? Int64,
              let imageView = NSImage(data: imageData) else { return }
        // Cek apakah gambar memiliki alpha channel
        let hasAlpha = imageView.representations.contains { rep in
            guard let bitmapRep = rep as? NSBitmapImageRep else { return false }
            return bitmapRep.hasAlpha
        }

        // Kompres gambar dengan mempertahankan transparansi jika diperlukan
        let compressedImageData = imageView.compressImage(
            quality: 0.5,
            preserveTransparency: hasAlpha
        ) ?? Data()

        await manager.saveImageToDatabase(id, foto: compressedImageData)

        await MainActor.run { [weak self] in
            guard let self else { return }
            let columnIndexOfNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
            if let cell = tableView.view(atColumn: columnIndexOfNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                let resizedImage = ReusableFunc.resizeImage(image: imageView, to: size)
                cell.imageView?.image = resizedImage
            }

            let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndexOfFoto))
        }
    }
}
