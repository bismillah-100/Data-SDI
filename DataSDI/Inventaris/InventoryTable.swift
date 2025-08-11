//
//  InventoryTable.swift
//  Data SDI
//
//  Created by MacBook on 09/08/25.
//

import Cocoa

extension InventoryView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView.rowHeight <= 18 {
            size = NSSize(width: 16, height: 16)
        } else if tableView.rowHeight >= 34 {
            size = NSSize(width: 36, height: 36)
        }
        DispatchQueue.global(qos: .background).async { [unowned self] in
            guard let id = self.data[row]["id"] as? Int64 else { return }
            let foto = manager.getImageSync(id)

            if let image = NSImage(data: foto) {
                let resizedImage = ReusableFunc.resizeImage(image: image, to: size)
                DispatchQueue.main.async {
                    let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                    if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                        cell.imageView?.image = resizedImage
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                    if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: row, makeIfNecessary: false) as? NSTableCellView {
                        cell.imageView?.image = NSImage(named: "pensil")
                    }
                }
            }
        }
        return tableView.rowHeight
    }

    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }

        let key = sortDescriptor.key ?? ""
        let ascending = sortDescriptor.ascending

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let sortedData = self.data.sorted { item1, item2 -> Bool in
                guard let column = SingletonData.columns.first(where: { $0.name == key }) else {
                    return false
                }
                let value1 = ["column": column, "value": item1[key], "item": item1]
                let value2 = ["column": column, "value": item2[key], "item": item2]

                let result = InventoryView.compareValues(value1 as [String: Any], value2 as [String: Any])
                if result != .orderedSame {
                    return ascending ? result == .orderedAscending : result == .orderedDescending
                }
                return false
            }

            // Set data ke hasil yang sudah diurutkan
            self.data = sortedData

            // Dapatkan indeks dari item yang dipilih
            var indexSet = IndexSet()
            for id in self.selectedIDs {
                if let index = self.data.firstIndex(where: { $0["id"] as? Int64 == id }) {
                    indexSet.insert(index)
                }
            }

            // Reload data di main thread
            await MainActor.run {
                tableView.reloadData()
                tableView.selectRowIndexes(indexSet, byExtendingSelection: false)

                if let maxIndex = indexSet.max() {
                    tableView.scrollRowToVisible(maxIndex)
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow _: Int, proposedDropOperation _: NSTableView.DropOperation) -> NSDragOperation {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return []
        }
        info.animatesToDestination = true
        // Izinkan kedua jenis operasi: .above untuk insert dan .on untuk replace
        return .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return false
        }

        let pasteboard = info.draggingPasteboard
        tableView.deselectAll(self)

        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !fileURLs.isEmpty
        else {
            return false
        }

        if dragSourceIsFromOurTable(draggingInfo: info) {
            return false
        }

        // Jika drop .above
        if dropOperation == .above {
            var success = false
            Task { [weak self] in
                guard let self else { return }

                await MainActor.run {
                    self.myUndoManager.beginUndoGrouping()
                    tableView.beginUpdates()
                }

                success = await self.handleInsertNewRows(at: row, fileURLs: fileURLs, tableView: tableView)

                await MainActor.run {
                    tableView.endUpdates()
                    self.myUndoManager.endUndoGrouping()
                }
            }
            return success
        } else {
            // Drop bukan di .above → proses file pertama saja
            guard let imageURL = fileURLs.first,
                  let image = NSImage(contentsOf: imageURL),
                  let imageData = image.tiffRepresentation
            else {
                return false
            }
            return handleReplaceExistingRow(at: row, withImageData: imageData, tableView: tableView)
        }
    }

    func tableViewColumnDidResize(_: Notification) {
        // Simpan lebar kolom ke UserDefaults
        for column in tableView.tableColumns {
            let identifier = column.identifier.rawValue
            var width = column.width
            if width <= 5 {
                width += 10
            }
            defaults.set(width, forKey: "Inventaris_tableColumnWidth_\(identifier)")
        }

        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat")) != nil {
            let resizedColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
            // Pastikan jumlah baris dalam tableView sesuai dengan jumlah data di model
            let rowCount = tableView.numberOfRows
            let inventoryList = data

            guard inventoryList.count == rowCount else {
                return
            }
            for row in 0 ..< rowCount {
                let inventory = inventoryList[row]
                if let cellView = tableView.view(atColumn: resizedColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let tanggalString = inventory["Tanggal Dibuat"] as? String
                {
                    let textField = cellView.textField

                    guard !tanggalString.isEmpty else { continue }
                    let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
                    // Tentukan format tanggal berdasarkan lebar kolom
                    if let textWidth = textField?.cell?.cellSize(forBounds: textField!.bounds).width, textWidth < textField!.bounds.width {
                        let availableWidth = textField?.bounds.width
                        if availableWidth! <= 80 {
                            // Teks dipotong, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d/M/yy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else if availableWidth! <= 120 {
                            // Lebar tersedia kurang dari atau sama dengan 80, gunakan format tanggal pendek
                            dateFormatter.dateFormat = "d-MMM-yyyy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        } else {
                            // Teks tidak dipotong dan lebar tersedia lebih dari 80, gunakan format tanggal panjang
                            dateFormatter.dateFormat = "dd-MMMM-yyyy"
                            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: columnIndex))
                        }
                    }
                    // Convert string date to Date object
                    if let date = dateFormatter.date(from: tanggalString) {
                        // Update text field dengan format tanggal yang baru
                        textField?.stringValue = dateFormatter.string(from: date)
                    } else {
                        print("error")
                    }
                }
            }
        }
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard tableView.numberOfRows != 0 else { return }
        selectedIDs.removeAll()
        let selectedRow = tableView.selectedRow
        if let toolbar = view.window?.toolbar {
            // Aktifkan isEditable pada baris yang sedang dipilih
            if selectedRow != -1 {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton
                {
                    hapus.isEnabled = true
                    hapus.target = self
                    hapus.action = #selector(delete(_:))
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton
                {
                    edit.isEnabled = true
                }
                let idColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "id"))
                let foto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                let tanggalDibuat = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Tanggal Dibuat"))
                if let cell = tableView.view(atColumn: foto, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
                if let cell = tableView.view(atColumn: idColumn, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
                if let cell = tableView.view(atColumn: tanggalDibuat, row: selectedRow, makeIfNecessary: false) as? NSTableCellView {
                    cell.textField?.isEditable = false
                }
            } else {
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
            }
        }
        NSApp.sendAction(#selector(InventoryView.updateMenuItem(_:)), to: nil, from: self)
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                data[index]["id"] as? Int64
            })
        }
        if SharedQuickLook.shared.isQuickLookVisible() {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    func tableViewColumnDidMove(_: Notification) {
        saveTableInfo()
        setupColumnMenu()
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let columnIdentifier = tableView.tableColumns[columnIndex].identifier.rawValue
        let columnIndexBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
        let columnIndexID = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "id"))
        if columnIdentifier == "Nama Barang" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if columnIdentifier == "id" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if newColumnIndex == columnIndexBarang || newColumnIndex == columnIndexID {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        return true
    }
}

extension InventoryView: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        data.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = "DataCell"
        let imageCellIdentifier = "imageCell"

        guard let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView,
              let cellImage = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(imageCellIdentifier), owner: self) as? NSTableCellView
        else {
            return nil
        }

        let rowData = data[row]
        let columnName = tableColumn?.identifier.rawValue

        if let columnName {
            if columnName == "id" {
                configureIdCell(cellView: cellView, rowData: rowData, tableView: tableView)
            } else if columnName == "Foto" {
                configureFotoCell(cellView: cellView, rowData: rowData)
            } else if columnName == "Nama Barang" {
                return configureNamaBarangCell(cellImage: cellImage, rowData: rowData, row: row)
            } else if columnName == "Tanggal Dibuat" {
                cellView.textField?.alphaValue = 0.6
                if let tgl = rowData["Tanggal Dibuat"] as? String {
                    dateFormatter.dateFormat = "dd-MMMM-yyyy"
                    let availableWidth = tableColumn?.width ?? 0
                    if availableWidth <= 80 {
                        dateFormatter.dateFormat = "d/M/yy"
                    } else if availableWidth <= 120 {
                        dateFormatter.dateFormat = "d-MMM-yyyy"
                    } else {
                        dateFormatter.dateFormat = "dd-MMMM-yyyy"
                    }
                    // Ambil tanggal dari siswa menggunakan KeyPath
                    if let date = dateFormatter.date(from: tgl) {
                        cellView.textField?.stringValue = dateFormatter.string(from: date)
                    } else {
                        cellView.textField?.stringValue = tgl // fallback jika parsing gagal
                    }
                    tableColumn?.minWidth = 70
                    tableColumn?.maxWidth = 140
                } else {
                    cellView.textField?.stringValue = ""
                }
            } else {
                configureDefaultCell(cellView: cellView, columnName: columnName, rowData: rowData, tableView: tableView, row: row)
            }
        }

        return cellView
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan ID entitas.
    /// Fungsi ini mengatur properti tampilan sel seperti opasitas teks, lebar kolom,
    /// dan menampilkan nilai ID dari data baris yang diberikan.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi.
    ///   - rowData: Data `[String: Any]` untuk baris saat ini, diharapkan berisi kunci "id".
    ///   - tableView: `NSTableView` tempat sel ini berada.
    func configureIdCell(cellView: NSTableCellView, rowData: [String: Any], tableView: NSTableView) {
        cellView.textField?.alphaValue = 0.6
        if let idColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("id")) {
            idColumn.maxWidth = 40
        }
        cellView.textField?.isEditable = false
        if let idValue = rowData["id"] as? Int64 {
            cellView.textField?.stringValue = "\(idValue)"
        } else {
            cellView.textField?.stringValue = ""
        }
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan ukuran foto
    /// di database dalam format KB/MB.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi.
    ///   - rowData: Data `[String: Any]` untuk baris saat ini, diharapkan berisi kunci "Foto".
    ///   - tableView: `NSTableView` tempat sel ini berada.
    func configureFotoCell(cellView: NSTableCellView, rowData: [String: Any]) {
        cellView.textField?.isEditable = false
        cellView.textField?.alphaValue = 0.6
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let id = rowData["id"] as? Int64 {
                let imageData = await manager.getImage(id)
                let byteCount = imageData.count
                let sizeInMB = Double(byteCount) / (1024.0 * 1024.0)

                if sizeInMB < 1.0 {
                    // Tampilkan dalam KB
                    let sizeInKB = Double(byteCount) / 1024.0
                    cellView.textField?.stringValue = String(format: "%.2f KB", sizeInKB)
                } else {
                    // Tampilkan dalam MB
                    cellView.textField?.stringValue = String(format: "%.2f MB", sizeInMB)
                }
            } else {
                cellView.textField?.stringValue = "-"
            }
        }
    }

    /// Mengkonfigurasi `NSTableCellView` untuk menampilkan nama barang beserta fotonya.
    /// Fungsi ini menangani pemuatan dan penyesuaian ukuran gambar secara asinkron
    /// untuk menjaga responsivitas UI, serta menampilkan nama barang.
    ///
    /// - Parameters:
    ///   - cellImage: `NSTableCellView` yang akan dikonfigurasi. Cell ini diharapkan memiliki `imageView` dan `textField`.
    ///   - rowData: `Dictionary` `[String: Any]` yang berisi data untuk baris saat ini.
    ///              Diharapkan memiliki kunci "Foto" (berisi `Data` gambar) dan "Nama Barang" (berisi `String`).
    ///   - row: Indeks baris saat ini dalam tabel. Parameter ini tidak digunakan secara langsung dalam implementasi ini,
    ///          tetapi umum disertakan dalam fungsi konfigurasi sel tabel.
    /// - Returns: `NSView` yang telah dikonfigurasi (dalam hal ini, `cellImage` itu sendiri).
    func configureNamaBarangCell(cellImage: NSTableCellView, rowData: [String: Any], row _: Int) -> NSView {
        cellImage.imageView?.isEditable = false
        cellImage.imageView?.image = NSImage(named: "pensil") // Placeholder image saat gambar belum dimuat
        let rowHeight = tableView.rowHeight
        Task(priority: .background) {
            if let id = rowData["id"] as? Int64 {
                let imageData = await manager.getImage(id)
                if let image = NSImage(data: imageData) {
                    let resizedImage = ReusableFunc.resizeImage(image: image, to: NSSize(width: rowHeight, height: rowHeight))
                    await MainActor.run {
                        cellImage.imageView?.image = resizedImage
                    }
                }
            } else {
                await MainActor.run {
                    cellImage.imageView?.image = NSImage(named: "pensil")
                }
            }
        }

        /// Mengkonfigurasi teks di baris ``tableView`` sesuai dengan teks yang ada di
        /// rowData["Nama Barang"].
        cellImage.textField?.stringValue = rowData["Nama Barang"] as? String ?? ""
        return cellImage
    }

    /// Mengkonfigurasi `NSTableCellView` umum untuk menampilkan data teks dari sebuah kolom tabel.
    /// Fungsi ini mengatur lebar minimum dan maksimum kolom yang terkait,
    /// serta menampilkan nilai string dari `rowData` ke dalam `textField` sel.
    ///
    /// - Parameters:
    ///   - cellView: `NSTableCellView` yang akan dikonfigurasi. Cell ini diharapkan memiliki `textField`.
    ///   - columnName: `String` yang merupakan nama kolom (identifier) yang sedang dikonfigurasi.
    ///                 Ini juga digunakan sebagai kunci untuk mengambil data dari `rowData`.
    ///   - rowData: `Dictionary` `[String: Any]` yang berisi data untuk baris saat ini.
    ///              Diharapkan memiliki kunci yang sesuai dengan `columnName`.
    ///   - tableView: `NSTableView` tempat sel ini berada. Digunakan untuk mengakses dan mengatur properti kolom.
    ///   - row: Indeks baris saat ini dalam tabel. Parameter ini tidak digunakan secara langsung dalam implementasi ini,
    ///          tetapi umum disertakan dalam fungsi konfigurasi sel tabel.
    func configureDefaultCell(cellView: NSTableCellView, columnName: String, rowData: [String: Any], tableView: NSTableView, row _: Int) {
        if let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnName)) {
            // Mengatur lebar maksimum kolom menjadi 400 poin.
            column.maxWidth = 400
            // Mengatur lebar minimum kolom menjadi 80 poin.
            column.minWidth = 80
        }
        cellView.textField?.stringValue = rowData[columnName] as? String ?? ""
    }

    func tableView(_: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let columnIdentifier = tableColumn?.identifier.rawValue,
              let newValue = object,
              let _ = data[row]["id"] as? Int64 else { return }

        _ = data[row][columnIdentifier]

        // Perbarui data
        data[row][columnIdentifier] = newValue
    }
}
