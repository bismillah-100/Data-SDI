//
//  InventoryUndoRedo.swift
//  Data SDI
//
//  Created by MacBook on 09/08/25.
//

import Cocoa

// MARK: - UNDO REDO

extension InventoryView {
    /// Berguna untuk memperbarui action/target menu item undo/redo di Menu Bar.
    func updateUndoRedo() {
        ReusableFunc.workItemUpdateUndoRedo?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let undoMenuItem = ReusableFunc.undoMenuItem,
                  let redoMenuItem = ReusableFunc.redoMenuItem
            else {
                return
            }

            let canUndo = myUndoManager.canUndo
            let canRedo = myUndoManager.canRedo

            if !canUndo {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            } else {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(performUndo(_:))
                undoMenuItem.isEnabled = canUndo
            }

            if !canRedo {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            } else {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(performRedo(_:))
                redoMenuItem.isEnabled = canRedo
            }

            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    /// Fungsi untuk menjalankan undo.
    @objc func performUndo(_: Any) {
        myUndoManager.undo()
        updateUndoRedo()
    }

    /// Fungsi untuk menjalankan redo.
    @objc func performRedo(_: Any) {
        myUndoManager.redo()
        updateUndoRedo()
    }

    /// Fungsi untuk mengurungkan penggantian gambar setelah *drop* gambar
    /// ke salah satu row di ``tableView``
    /// - Parameters:
    ///   - id: `id` unik data yang akan diperbarui.
    ///   - imageData: `Data` gambar yang digunakan untuk memperbarui.
    func undoReplaceImage(_ id: Int64, imageData: Data) {
        guard let row = findRowIndex(forId: id) else { return }

        let newImage = manager.getImageSync(id)
        let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))

        Task {
            await self.manager.saveImageToDatabase(id, foto: imageData)
            await MainActor.run {
                if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                    if !imageData.isEmpty {
                        cell.imageView?.image = NSImage(data: imageData)
                    } else {
                        cell.imageView?.image = NSImage(named: "pensil")
                    }
                }
                let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndexOfFoto))
            }
        }
        tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoReplaceImage(id, imageData: newImage)
        })
    }

    /// Fungsi untuk mengulangi penggantian gambar setelah *drop* gambar
    /// ke salah satu row di ``tableView``
    /// - Parameters:
    ///   - id: `id` unik data yang akan diperbarui.
    ///   - imageData: `Data` gambar yang digunakan untuk memperbarui.
    func redoReplaceImage(_ id: Int64, imageData: Data) {
        guard let row = findRowIndex(forId: id) else {
            return
        }

        let oldImage = manager.getImageSync(id)
        let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))

        Task {
            await self.manager.saveImageToDatabase(id, foto: imageData)
            await MainActor.run {
                if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                    if !imageData.isEmpty {
                        cell.imageView?.image = NSImage(data: imageData)
                    } else {
                        cell.imageView?.image = NSImage(named: "pensil")
                    }
                }
                let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))

                tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndexOfFoto))
            }
        }

        tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoReplaceImage(id, imageData: oldImage)
        })
    }

    /// Fungsi untuk mengulangi hapus kolom.
    /// - Parameter columnName: Nama kolom yang akan dihapus
    func redoDeleteColumn(columnName: String) {
        let columnToDelete = columnName

        // Simpan data kolom yang akan dihapus bersama dengan ID
        var columnData: [(id: Int64, value: Any)] = []
        for row in data {
            if let id = row["id"] as? Int64 {
                columnData.append((id: id, value: row[columnToDelete] ?? "")) // Simpan ID dan nilai kolom
            }
        }

        /* Data tidak langsung dihapus di database. tetapi disimpan terlebih dahulu dalam array untuk dihapus nanti ketika pengguna memilih untuk menyimpan perubahan data. */
        SingletonData.deletedColumns.append((columnName: columnToDelete, columnData: columnData))

        guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnName)) else { return }
        tableView.removeTableColumn(column)

        Task {
            data = await manager.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
                myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                    self?.undoDeleteColumn()
                })
                removeMenuItem(for: columnName)
                updateUndoRedo()
                setupDescriptor()
            }
        }
    }

    /// Membatalkan operasi penghapusan kolom sebelumnya.
    /// Fungsi ini mengembalikan kolom yang dihapus ke tampilan tabel dan juga mengembalikan
    /// data yang terkait dengan kolom tersebut ke posisi aslinya di setiap baris.
    func undoDeleteColumn() {
        // Pastikan ada kolom yang dihapus sebelumnya untuk dibatalkan.
        guard !SingletonData.deletedColumns.isEmpty else { return }

        // Ambil detail kolom yang terakhir dihapus dari daftar `deletedColumns`.
        let lastDeleted = SingletonData.deletedColumns.removeLast()
        let columnName = lastDeleted.columnName // Nama kolom yang akan dikembalikan.
        let columnData = lastDeleted.columnData // Data yang terkait dengan kolom ini.

        // Tambahkan kolom kembali ke `NSTableView`.
        // Baris yang dikomentari `manager.addColumn` menunjukkan bahwa penambahan kolom ke database
        // kemungkinan ditangani secara otomatis atau di tempat lain yang relevan.
        let newColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
        newColumn.title = columnName // Atur judul kolom sesuai nama aslinya.
        tableView.addTableColumn(newColumn) // Tambahkan kolom baru ke tabel.

        // Kembalikan data kolom ke baris yang sesuai berdasarkan ID.
        // Iterasi melalui setiap baris dalam model data lokal (`self.data`).
        for (index, row) in data.enumerated() {
            // Pastikan setiap baris memiliki ID.
            if let id = row["id"] as? Int64 {
                // Cari data yang cocok di `columnData` berdasarkan ID.
                if let matchedData = columnData.first(where: { $0.id == id }) {
                    // Jika data ditemukan, kembalikan nilai ke kolom yang sesuai (`columnName`)
                    // di baris `data` pada indeks saat ini.
                    data[index][columnName] = matchedData.value
                }
            }
        }

        // Daftarkan operasi redo untuk operasi undo ini.
        // Jika pengguna memilih "redo", fungsi `redoDeleteColumn` akan dipanggil
        // untuk menghapus kembali kolom tersebut.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoDeleteColumn(columnName: columnName)
        })

        // Memuat ulang dan memperbarui tampilan tabel setelah perubahan.
        // Ini mensimulasikan pembaruan tabel seolah-olah sort descriptors baru saja diubah,
        // memastikan tampilan yang benar.
        tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
        setupColumnMenu() // Perbarui menu kolom agar kolom yang dikembalikan terlihat.
        updateUndoRedo() // Perbarui status tombol undo/redo.
        setupDescriptor() // Setel ulang deskriptor (mungkin untuk menyelaraskan dengan kolom yang dikembalikan).
    }

    /// Membatalkan (undo) serangkaian perubahan pada tabel dan database.
    /// Fungsi ini mengembalikan nilai-nilai data ke kondisi sebelumnya berdasarkan model perubahan yang disediakan.
    /// Pembaruan dilakukan baik pada model data lokal maupun database, dengan pembaruan UI yang sesuai.
    /// Ini juga mendaftarkan operasi "ulang" (redo) untuk membatalkan undo ini.
    ///
    /// - Parameter model: Sebuah array `[TableChange]` yang berisi detail perubahan yang akan dibatalkan.
    ///                    Setiap `TableChange` diharapkan berisi `id` entitas, `columnName` yang diubah,
    ///                    dan `oldValue` yang akan dikembalikan.
    func urung(_ model: [TableChange]) {
        tableView.deselectAll(nil)

        // Variabel untuk melacak indeks baris tertinggi yang dimodifikasi,
        // yang nantinya akan digunakan untuk menggulir tabel.
        var maxRow: Int?
        // Iterasi melalui setiap perubahan yang perlu dibatalkan.
        for change in model { // Mengganti nama parameter `model` menjadi `change` agar lebih jelas
            // Cari indeks baris dalam model data lokal (`self.data`) yang cocok dengan ID dari perubahan.
            if let rowIndex = data.firstIndex(where: { $0["id"] as? Int64 == change.id }) {
                // Perbarui data di model lokal dengan `oldValue` yang ingin dikembalikan.
                data[rowIndex][change.columnName] = change.oldValue

                // Gulir tabel agar baris yang dimodifikasi terlihat.
                tableView.scrollRowToVisible(rowIndex)

                // Dapatkan indeks kolom di `tableView` yang sesuai dengan `columnName` dari perubahan.
                if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == change.columnName }) {
                    // Pastikan indeks kolom valid untuk menghindari crash.
                    guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return }

                    // Dapatkan tampilan sel (`NSTableCellView`) untuk baris dan kolom yang relevan.
                    // `makeIfNecessary: false` berarti kita hanya ingin mengambil sel jika sudah ada.
                    if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        // Jika `oldValue` adalah String, perbarui secara asinkron.
                        if let newString = change.oldValue as? String {
                            Task { [weak self] in
                                guard let self else { return }
                                // Perbarui database dengan nilai lama.
                                await manager.updateDatabase(ID: change.id, column: change.columnName, value: newString)

                                // Kembali ke MainActor untuk pembaruan UI.
                                await MainActor.run { [weak self] in
                                    guard let self else { return }
                                    // Pembaruan UI spesifik untuk kolom "Nama Barang" (langsung set stringValue).
                                    if change.columnName == "Nama Barang" {
                                        cellView.textField?.stringValue = newString
                                    } else {
                                        // Untuk kolom lain, muat ulang sel spesifik di tabel.
                                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndex]))
                                    }
                                }
                            }
                        } else {
                            // Jika `oldValue` bukan String (misalnya `nil` atau tipe lain), set ke string kosong.
                            Task { [weak self] in
                                // Perbarui database dengan string kosong.
                                await self?.manager.updateDatabase(ID: change.id, column: change.columnName, value: "")
                                // Kembali ke MainActor untuk pembaruan UI.
                                await MainActor.run {
                                    cellView.textField?.stringValue = "" // Perbarui UI sel.
                                }
                            }
                        }
                        // Pilih baris yang telah dimodifikasi di tabel.
                        tableView.selectRowIndexes(IndexSet([rowIndex]), byExtendingSelection: true)
                    }

                    // Perbarui `maxRow` jika `rowIndex` saat ini lebih besar.
                    if rowIndex > maxRow ?? 0 {
                        maxRow = rowIndex
                    }
                }
            }
        }

        if let maxRow {
            tableView.scrollRowToVisible(maxRow)
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.ulang(model)
        })
        updateUndoRedo()
    }

    /// Membatalkan (ulang) serangkaian perubahan pada tabel dan database.
    /// Fungsi ini mengembalikan nilai-nilai data ke kondisi sebelumnya (setelah undo) berdasarkan model perubahan yang disediakan.
    /// Pembaruan dilakukan baik pada model data lokal maupun database, dengan pembaruan UI yang sesuai.
    /// Ini juga mendaftarkan operasi "urung" (undo) untuk membatalkan redo ini.
    ///
    /// - Parameter model: Sebuah array `[TableChange]` yang berisi detail perubahan yang telah diterapkan.
    ///                    Setiap `TableChange` diharapkan berisi `id` entitas, `columnName` yang diubah,
    ///                    dan `oldValue` yang akan dikembalikan.
    func ulang(_ model: [TableChange]) {
        tableView.deselectAll(nil)
        var maxRow: Int?
        for model in model {
            if let rowIndex = data.firstIndex(where: { $0["id"] as? Int64 == model.id }) {
                data[rowIndex][model.columnName] = model.newValue
                tableView.scrollRowToVisible(rowIndex)
                if let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == model.columnName }) {
                    // Pastikan bahwa kolom yang diinginkan tidak melebihi batas indeks kolom
                    guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return }
                    if let cellView = tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                        if let newString = model.newValue as? String {
                            Task { [weak self] in
                                guard let self else { return }
                                await manager.updateDatabase(ID: model.id, column: model.columnName, value: newString)
                                await MainActor.run { [weak self] in
                                    guard let self else { return }
                                    if model.columnName == "Nama Barang" {
                                        cellView.textField?.stringValue = newString
                                    } else {
                                        tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet([columnIndex]))
                                    }
                                }
                            }
                        } else {
                            Task { [weak self] in
                                await self?.manager.updateDatabase(ID: model.id, column: model.columnName, value: "")
                                await MainActor.run {
                                    cellView.textField?.stringValue = ""
                                }
                            }
                        }
                    }
                    tableView.selectRowIndexes(IndexSet([rowIndex]), byExtendingSelection: true)
                    if rowIndex > maxRow ?? 0 {
                        maxRow = rowIndex
                    }
                }
            }
        }
        if let maxRow {
            tableView.scrollRowToVisible(maxRow)
        }
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.urung(model)
        })
        updateUndoRedo()
    }

    /// Membatalkan operasi penghapusan baris data sebelumnya.
    /// Fungsi ini mengembalikan baris yang dihapus ke dalam model data aplikasi dan `NSTableView`
    /// pada posisi yang benar berdasarkan kriteria pengurutan yang aktif.
    ///
    /// - Parameter model: Sebuah `Dictionary` `[String: Any]` yang berisi data dari baris yang dihapus
    ///                    yang perlu dikembalikan.
    func undoHapus(_ model: [String: Any]) {
        // Memulai kelompok undo. Operasi yang terjadi di antara `beginUndoGrouping()`
        // dan `endUndoGrouping()` akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()

        // Menghapus semua pilihan baris di tabel.
        tableView.deselectAll(self)

        // Memastikan ada deskriptor pengurutan yang aktif di tabel.
        // Jika tidak ada, fungsi akan berhenti karena tidak dapat menentukan posisi penyisipan.
        guard let sort = tableView.sortDescriptors.first else { return }

        // Menentukan indeks yang benar untuk menyisipkan kembali `model`
        // agar tabel tetap terurut sesuai dengan deskriptor pengurutan yang aktif.
        let rowInsertion = data.insertionIndex(for: model, using: sort)

        // Menyisipkan kembali data `model` ke dalam array data lokal (`self.data`)
        // pada indeks yang telah ditentukan.
        data.insert(model, at: rowInsertion)

        // Mendaftarkan operasi redo untuk operasi undo ini.
        // Jika pengguna melakukan redo, fungsi `redoHapus` akan dipanggil dengan `model` asli
        // untuk menghapus kembali item tersebut.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoHapus(model)
        })

        // Jika `model` memiliki ID, hapus ID tersebut dari set `SingletonData.deletedInvID`.
        // Ini membalikkan tindakan yang dilakukan saat baris dihapus.
        if let id = model["id"] as? Int64 {
            SingletonData.deletedInvID.remove(id)
        }

        // Memberi tahu `tableView` untuk menyisipkan baris secara visual
        // pada `rowInsertion` dengan animasi `.effectGap`.
        tableView.insertRows(at: IndexSet([rowInsertion]), withAnimation: .effectGap)

        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()

        // Menunda eksekusi blok kode ini ke antrean utama setelah 0.2 detik.
        // Ini memberikan waktu bagi animasi penyisipan untuk selesai sebelum memilih dan menggulir.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            // Setelah baris disisipkan, cari indeksnya lagi (untuk memastikan lokasi yang akurat).
            if let index = data.firstIndex(where: { $0["id"] as? Int64 == model["id"] as? Int64 }) {
                // Pilih baris yang baru disisipkan.
                tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: true)
                // Gulir tabel agar baris yang dipilih terlihat.
                tableView.scrollRowToVisible(index)
            } else {
                // Jika baris tidak ditemukan (mungkin terjadi kesalahan atau kondisi yang tidak terduga).
                // Anda bisa menambahkan penanganan kesalahan atau logging di sini.
            }
        }

        // Memperbarui status tombol undo/redo di UI.
        updateUndoRedo()
    }

    /// Mengulangi operasi penghapusan baris data yang sebelumnya diurungkan.
    /// Fungsi ini menghapus baris yang sebelumnya telah dihapus dan urungkan
    /// ke dalam model data aplikasi dan `NSTableView`
    /// pada posisi yang benar berdasarkan kriteria pengurutan yang aktif.
    ///
    /// - Parameter model: Sebuah `Dictionary` `[String: Any]` yang berisi data dari baris yang dihapus
    ///                    yang perlu dikembalikan
    func redoHapus(_ model: [String: Any]) {
        myUndoManager.beginUndoGrouping()
        tableView.beginUpdates()
        if let id = model["id"] as? Int64 {
            SingletonData.deletedInvID.insert(id)
        }
        if let index = data.firstIndex(where: { $0["id"] as? Int64 == model["id"] as? Int64 }) {
            data.remove(at: index)
            myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.undoHapus(model)
            })
            tableView.removeRows(at: IndexSet([index]), withAnimation: .slideDown)
            if index == tableView.numberOfRows {
                //
                tableView.selectRowIndexes(IndexSet([index - 1]), byExtendingSelection: false)
            } else {
                tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
                //
            }
        } else {}
        tableView.endUpdates()
        myUndoManager.endUndoGrouping()
        updateUndoRedo()
    }

    /// Membatalkan operasi penambahan baris sebelumnya.
    /// Fungsi ini menghapus baris-baris yang baru ditambahkan dari model data aplikasi dan `NSTableView`
    /// berdasarkan daftar ID yang diberikan. Ia juga menangani pembaruan UI dan mendaftarkan operasi redo.
    ///
    /// - Parameter ids: Sebuah array `[Int64]` yang berisi ID unik dari baris-baris yang sebelumnya ditambahkan
    ///                  dan sekarang akan dihapus (dibatalkan penambahannya).
    func undoAddRows(_ ids: [Int64]) {
        var oldDatas = [[String: Any]]() // Menyimpan data dari baris yang dihapus untuk kemungkinan redo.
        var rowsToSelect = IndexSet() // Indeks baris yang akan dipilih setelah operasi selesai.

        tableView.beginUpdates()
        // Iterasi melalui setiap ID yang disediakan (yang mewakili baris yang baru ditambahkan).
        for id in ids {
            // Cari indeks baris dalam model data lokal (`self.data`) yang cocok dengan ID saat ini.
            guard let index = data.firstIndex(where: { $0["id"] as? Int64 == id }) else { continue }

            // Hapus data dari array model lokal dan simpan sebagai `oldData` untuk operasi redo.
            let oldData = data.remove(at: index)
            oldDatas.append(oldData)

            // Hapus ID dari set `newData` (asumsi ini melacak data yang baru dibuat/belum disimpan).
            newData.remove(id)

            // Tambahkan ID ke `SingletonData.deletedInvID`. Ini mungkin digunakan
            // untuk menandai item ini sebagai "dihapus" di database, bahkan jika itu adalah undo dari "tambah".
            SingletonData.deletedInvID.insert(id)

            // Catat indeks baris yang dihapus untuk kemungkinan seleksi di kemudian hari.
            rowsToSelect.insert(index)

            // Memberi tahu `tableView` untuk menghapus baris secara visual
            // pada indeks yang ditentukan dengan animasi `slideDown`.
            tableView.removeRows(at: IndexSet([index]), withAnimation: .slideDown)

            // Pilih baris yang sekarang berada di posisi baris yang baru saja dihapus.
            // Ini memberikan umpan balik visual kepada pengguna.
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
        }
        tableView.endUpdates()

        if let endOfRow = rowsToSelect.max(), endOfRow < tableView.numberOfRows {
            tableView.scrollRowToVisible(endOfRow)
        } else {
            if tableView.numberOfRows > 0 {
                tableView.scrollRowToVisible(rowsToSelect.min() ?? 0)
            }
        }

        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoAddRows(oldDatas)
        })
        updateUndoRedo()
    }

    /// Mengulangi operasi penambahan baris sebelumnya.
    /// Fungsi ini menambahkan kembali baris-baris yang baru ditambahkan yang kemudian diurungkan
    /// ke model data aplikasi dan `NSTableView`
    /// berdasarkan daftar ID yang diberikan. Ia juga menangani pembaruan UI dan mendaftarkan operasi redo.
    ///
    /// - Parameter ids: Sebuah array `[Int64]` yang berisi ID unik dari baris-baris yang sebelumnya ditambahkan
    ///                  dan sekarang akan dihapus (dibatalkan penambahannya).
    func redoAddRows(_ newDatas: [[String: Any]]) {
        // Menambahkan data baru ke array data di baris pertama
        var ids = [Int64]()
        tableView.deselectAll(nil)
        tableView.beginUpdates()
        for newData in newDatas {
            guard let sort = tableView.sortDescriptors.first else { return }
            let rowInsertion = data.insertionIndex(for: newData, using: sort)
            data.insert(newData, at: rowInsertion)
            guard let id = newData["id"] as? Int64 else { return }
            data[rowInsertion]["id"] = id // Menyimpan ID baru ke dictionary data
            self.newData.insert(id)
            ids.append(id)
            SingletonData.deletedInvID.remove(id)
            // Reload table view setelah menambahkan data
            tableView.insertRows(at: IndexSet([rowInsertion]), withAnimation: .effectGap)
            tableView.selectRowIndexes(IndexSet([rowInsertion]), byExtendingSelection: true)
        }
        tableView.endUpdates()

        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAddRows(ids)
        })
        updateUndoRedo()
    }
}
