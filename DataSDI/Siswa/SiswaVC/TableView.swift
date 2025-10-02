//
//  TableView.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Foundation

// MARK: - NSTableViewDataSource

extension SiswaViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        // Jumlah total baris = jumlah siswa
        viewModel.numberOfRows
    }

    func tableView(_: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard viewModel.mode == .grouped else { return nil }
        let rowView = CustomRowView()
        let (isGroup, _, _) = viewModel.getRowInfoForRow(row)
        if isGroup {
            rowView.isGroupRowStyle = true
            return rowView
        } else {
            return NSTableRowView()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch viewModel.mode {
        case .plain:
            guard row < viewModel.numberOfRows,
                  let siswa = viewModel.dataSource.siswa(at: row),
                  let tableColumn, !tableColumn.isHidden
            else { return NSView() }

            let columnIdentifier = tableColumn.identifier.rawValue
            switch columnIdentifier {
            case "Nama":
                return configureSiswaCell(for: tableView, siswa: siswa, row: row)
            case "Tahun Daftar", "Tgl. Lulus":
                return configureDatePickerCell(for: tableView, tableColumn: tableColumn, siswa: siswa, dateKeyPath: columnIdentifier == "Tahun Daftar" ? \.tahundaftar : \.tanggalberhenti, tag: columnIdentifier == "Tahun Daftar" ? 1 : 2)
            default:
                return configureGeneralCell(for: tableView, columnIdentifier: columnIdentifier, siswa: siswa, row: row)
            }
        case .grouped:
            let (isGroupRow, sectionIndex, _) = viewModel.getRowInfoForRow(row)
            return configureGroupedCell(for: tableView, tableColumn: tableColumn, isGroupRow: isGroupRow, sectionIndex: sectionIndex, rowIndexInSection: row)
        }
    }

    /**
         Mengkonfigurasi tampilan cell untuk tabel siswa.

         - Parameter tableView: NSTableView yang akan dikonfigurasi cell-nya.
         - Parameter siswa: ModelSiswa yang datanya akan ditampilkan pada cell.
         - Parameter row: Indeks baris dari cell yang sedang dikonfigurasi.
         - Returns: NSView yang telah dikonfigurasi sebagai cell siswa, atau nil jika gagal.
     */
    func configureSiswaCell(for tableView: NSTableView, siswa: ModelSiswa, row _: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SiswaCell"), owner: self) as? NamaSiswaCellView else {
            return nil
        }

        // 2. Cukup panggil metode konfigurasi pada sel.
        // Sel akan menangani sisanya secara internal.
        cell.configure(with: siswa)
        return cell
    }

    /**
         Mengonfigurasi sel umum untuk NSTableView berdasarkan pengidentifikasi kolom yang diberikan.

         - Parameter tableView: NSTableView yang selnya akan dikonfigurasi.
         - Parameter columnIdentifier: String yang mengidentifikasi kolom yang akan dikonfigurasi.
         - Parameter siswa: ModelSiswa yang datanya akan ditampilkan dalam sel.
         - Parameter row: Indeks baris sel yang sedang dikonfigurasi.

         - Returns: NSView? yang merupakan sel yang telah dikonfigurasi, atau nil jika gagal membuat sel. Sel dikonfigurasi berdasarkan `columnIdentifier` yang sesuai dengan properti pada objek `siswa`.
     */
    func configureGeneralCell(for tableView: NSTableView, columnIdentifier: String, siswa: ModelSiswa, row _: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cellUmum"), owner: self) as? NSTableCellView else { return nil }

        switch columnIdentifier {
        case "Alamat": cell.textField?.stringValue = siswa.alamat
        case "T.T.L": cell.textField?.stringValue = siswa.ttl
        case "Nama Wali": cell.textField?.stringValue = siswa.namawali
        case "NIS": cell.textField?.stringValue = siswa.nis
        case "NISN": cell.textField?.stringValue = siswa.nisn
        case "Ayah": cell.textField?.stringValue = siswa.ayah
        case "Ibu": cell.textField?.stringValue = siswa.ibu
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin.description
        case "Status": cell.textField?.stringValue = siswa.status.description
        case "Nomor Telepon": cell.textField?.stringValue = siswa.tlv
        default: break
        }

        return cell
    }

    /**
         Mengonfigurasi tampilan sel untuk NSTableView, menangani tampilan header grup dan baris data.

         - Parameter tableView: NSTableView yang selnya sedang dikonfigurasi.
         - Parameter tableColumn: Kolom tabel yang selnya sedang dikonfigurasi. Bisa jadi nil jika ini adalah baris grup.
         - Parameter isGroupRow: Boolean yang menunjukkan apakah baris tersebut adalah baris grup (header).
         - Parameter sectionIndex: Indeks bagian tempat sel berada.
         - Parameter rowIndexInSection: Indeks baris dalam bagian tempat sel berada.

         - Returns: NSView yang dikonfigurasi untuk sel, bisa berupa tampilan header atau tampilan baris data. Mengembalikan nil jika konfigurasi gagal.
     */
    func configureGroupedCell(for tableView: NSTableView, tableColumn: NSTableColumn?, isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
        if isGroupRow {
            configureHeaderView(for: tableView, sectionIndex: sectionIndex)
        } else {
            configureGroupedRowView(for: tableView, tableColumn: tableColumn, row: rowIndexInSection)
        }
    }

    /**
         Mengonfigurasi tampilan header untuk bagian tertentu dalam tabel.

         - Parameter tableView: Tabel yang akan dikonfigurasi header-nya.
         - Parameter sectionIndex: Indeks bagian yang akan dikonfigurasi header-nya.
         - Returns: Tampilan header yang telah dikonfigurasi, atau `nil` jika header tidak ditampilkan atau terjadi kesalahan.

         Fungsi ini membuat atau menggunakan kembali tampilan header (`GroupTableCellView`) untuk bagian tertentu dalam tabel.
         Jika `sectionIndex` adalah 0, maka header tidak akan ditampilkan (mengembalikan `nil`).
         Jika tidak, fungsi ini akan mengatur properti `isGroupView`, `sectionTitle` (mengambil nama kelas dari array `kelasNames`),
         `sectionIndex`, dan `isBoldFont` pada tampilan header.
     */
    func configureHeaderView(for tableView: NSTableView, sectionIndex: Int) -> NSView? {
        guard let headerView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderView"), owner: nil) as? GroupTableCellView else { return nil }
        if sectionIndex == 0 {
            return nil // Tidak menampilkan header
        }

        headerView.isGroupView = true
        let kelasNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "Lulus", "Tanpa Kelas"]
        headerView.sectionTitle = kelasNames[sectionIndex]
        headerView.isBoldFont = isSortedByFirstColumn

        return headerView
    }

    /**
         Mengonfigurasi tampilan baris yang dikelompokkan untuk NSTableView.

         Fungsi ini membuat dan mengembalikan tampilan untuk baris tertentu dalam NSTableView yang dikelompokkan,
         berdasarkan indeks bagian dan baris dalam bagian tersebut. Tampilan dikonfigurasi berdasarkan
         identifier kolom tabel.

         - Parameter tableView: NSTableView yang meminta tampilan.
         - Parameter tableColumn: Kolom tabel yang tampilan ini untuknya.
         - Parameter sectionIndex: Indeks bagian dari baris yang diminta.
         - Parameter rowIndexInSection: Indeks baris dalam bagian yang diminta.

         - Returns: NSView yang dikonfigurasi untuk baris tersebut, atau nil jika terjadi kesalahan
                    (misalnya, indeks di luar batas, atau gagal membuat tampilan sel).
     */
    func configureGroupedRowView(for tableView: NSTableView, tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Guard untuk memastikan rowIndexInSection valid

        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cellUmum"), owner: self) as? NSTableCellView,
              let tableColumn, !tableColumn.isHidden else { return nil }

        guard let siswa = viewModel.dataSource.siswa(at: row) else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        switch tableColumn.identifier.rawValue {
        case "Nama":
            guard let namasiswa = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NamaSiswaGroup"), owner: self) as? NSTableCellView else { return nil }
            namasiswa.textField?.stringValue = siswa.nama
            return namasiswa
        case "Alamat": cell.textField?.stringValue = siswa.alamat
        case "T.T.L": cell.textField?.stringValue = siswa.ttl
        case "Nama Wali": cell.textField?.stringValue = siswa.namawali
        case "NIS": cell.textField?.stringValue = siswa.nis
        case "NISN": cell.textField?.stringValue = siswa.nisn
        case "Ayah": cell.textField?.stringValue = siswa.ayah
        case "Ibu": cell.textField?.stringValue = siswa.ibu
        case "Jenis Kelamin": cell.textField?.stringValue = siswa.jeniskelamin.description
        case "Status": cell.textField?.stringValue = siswa.status.description
        case "Tahun Daftar":
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tahundaftar
            ReusableFunc.updateDateFormat(for: cell, dateString: tanggalString, columnWidth: tableColumn.width)
        case "Tgl. Lulus":
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tanggalberhenti
            ReusableFunc.updateDateFormat(for: cell, dateString: tanggalString, columnWidth: tableColumn.width)
        case "Nomor Telepon":
            cell.textField?.stringValue = siswa.tlv
        default: break
        }
        return cell
    }
}

extension SiswaViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let columnIdentifier = tableView.tableColumns[columnIndex].identifier.rawValue
        if columnIdentifier == "Nama" {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }
        return true
    }

    func tableViewColumnDidMove(_: Notification) {
        updateHeaderMenuOrder()
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        saveSortDescriptor(sortDescriptor)
        // Lakukan pengurutan berdasarkan sort descriptor yang dipilih
        sortData(with: sortDescriptor, selectedIds: updateSelectedIDs())
        if viewModel.mode == .grouped {
            if let firstColumnSortDescriptor = tableView.tableColumns.first?.sortDescriptorPrototype {
                isSortedByFirstColumn = (firstColumnSortDescriptor.key == sortDescriptor.key)
            } else {
                isSortedByFirstColumn = false
            }
        }
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard viewModel.mode == .grouped else { return true }
        // Periksa apakah baris tersebut adalah bagian (section)
        if viewModel.isGroupRow(row) {
            return false // Menonaktifkan seleksi untuk bagian (section)
        } else {
            return true // Mengizinkan seleksi untuk baris biasa di dalam bagian
        }
    }

    func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
        // Periksa apakah mode adalah .grouped dan baris adalah header kelas
        if viewModel.mode == .grouped {
            viewModel.getRowInfoForRow(row).isGroupRow
        } else {
            false // Jika mode adalah .plain, maka tidak ada header kelas yang perlu ditampilkan
        }
    }

    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard tableView.numberOfRows != 0 else {
            return
        }

        let selectedRow = tableView.selectedRow
        if let wc = AppDelegate.shared.mainWindow.windowController as? WindowController {
            let shouldEnable = selectedRow != -1
            // Aktifkan isEditable pada baris yang sedang dipilih
            if let hapusToolbarItem = wc.hapusToolbar,
               let hapus = hapusToolbarItem.view as? NSButton
            {
                hapus.isEnabled = shouldEnable
                hapus.target = shouldEnable ? self : nil
                hapus.action = shouldEnable ? #selector(hapusMenu(_:)) : nil
            }
            if let editToolbarItem = wc.editToolbar,
               let edit = editToolbarItem.view as? NSButton
            {
                edit.isEnabled = shouldEnable
            }
        }

        NSApp.sendAction(#selector(SiswaViewController.updateMenuItem(_:)), to: nil, from: self)

        if SharedQuickLook.shared.isQuickLookVisible() {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if viewModel.mode == .grouped {
            let (isGroupRow, _, _) = viewModel.getRowInfoForRow(row)
            if isGroupRow, row == 0 { return 0.1 }
            else if isGroupRow { return 28.0 }
            else { return tableView.rowHeight }
        } else {
            return tableView.rowHeight
        }
    }

    /**
         Mengonfigurasi cell untuk DatePicker pada NSTableView.

         Fungsi ini membuat atau menggunakan kembali cell kustom yang berisi DatePicker dan TextField,
         kemudian mengonfigurasi DatePicker dengan target, action, dan tag yang sesuai.
         Tanggal yang ditampilkan pada TextField dan DatePicker diformat berdasarkan lebar kolom tabel.
         Data tanggal diambil dari objek `ModelSiswa` menggunakan KeyPath yang diberikan.

         - Parameter tableView: NSTableView yang akan menampilkan cell.
         - Parameter tableColumn: Kolom tabel yang terkait dengan cell.
         - Parameter siswa: Objek `ModelSiswa` yang berisi data tanggal.
         - Parameter dateKeyPath: KeyPath yang menentukan properti tanggal pada `ModelSiswa`.
         - Parameter tag: Tag yang akan diberikan ke DatePicker.

         - Returns: Cell kustom yang telah dikonfigurasi, atau nil jika pembuatan cell gagal.
     */
    func configureDatePickerCell(for tableView: NSTableView, tableColumn: NSTableColumn?, siswa: ModelSiswa, dateKeyPath: KeyPath<ModelSiswa, String>, tag _: Int) -> NSTableCellView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "expDP"), owner: self) as? NSTableCellView else { return nil }

        // Ambil textField dan DatePicker dari cell yang di-reuse
        let textField = cell.textField
        // Ambil tanggal dari siswa menggunakan KeyPath
        let tanggalString = siswa[keyPath: dateKeyPath]

        ReusableFunc.updateDateFormat(for: cell, dateString: tanggalString, columnWidth: tableColumn?.width ?? 0)

        // Convert string date to Date object dan set DatePicker value
        textField?.isEditable = false

        return cell
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        tableView.beginUpdates()
        updateCells(for: tableView, columnIdentifier: tahunDaftarColumn.identifier.rawValue, siswaData: viewModel.flattenedData())
        updateCells(for: tableView, columnIdentifier: tglLulusColumn.identifier.rawValue, siswaData: viewModel.flattenedData())
        tableView.endUpdates()
    }

    /**
     Memperbarui sel-sel pada NSTableView untuk kolom tertentu dengan data siswa.

     Fungsi ini digunakan untuk memperbarui tampilan sel dalam NSTableView berdasarkan data siswa yang diberikan.
     Fungsi ini akan mencari kolom berdasarkan identifier yang diberikan, dan kemudian memperbarui setiap sel
     dalam kolom tersebut dengan data yang sesuai dari array `siswaData`. Jika kolom yang sesuai ditemukan fungsi ini akan memanggil ``ReusableFunc/updateDateFormat(for:dateString:columnWidth:inputFormatter:)`` untuk
     memformat dan menampilkan tanggal yang sesuai.

     - Parameter tableView: NSTableView yang sel-selnya akan diperbarui.
     - Parameter columnIdentifier: Identifier kolom yang akan diperbarui.
     - Parameter siswaData: Array data siswa yang akan digunakan untuk memperbarui sel-sel.
     */
    // Fungsi untuk memperbarui sel pada mode plain
    func updateCells(for tableView: NSTableView, columnIdentifier: String, siswaData: [ModelSiswa]) {
        if let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: columnIdentifier)) {
            let columnIndex = tableView.column(withIdentifier: resizedColumn.identifier)
            for row in 0 ..< siswaData.count {
                let siswa = siswaData[row]
                if let cellView = tableView.view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let dateString = columnIdentifier == "Tahun Daftar" ? siswa.tahundaftar : siswa.tanggalberhenti
                    ReusableFunc.updateDateFormat(for: cellView, dateString: dateString, columnWidth: resizedColumn.width)
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        FilePromiseProvider.configureDraggingSession(
            tableView,
            session: session,
            willBeginAt: screenPoint,
            forRowIndexes: rowIndexes,
            columnIndex: columnIndexOfKelasAktif
        )
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return false
        }

        guard let (fileURLs, image) = FilePromiseProvider.validateImageForDrop(info) else {
            return false
        }

        // Drop di luar baris tableview
        if dropOperation == .above {
            guard let sortDescriptor = tableView.sortDescriptors.first,
                  let comparator = ModelSiswa.comparator(from: sortDescriptor)
            else { return false }
            DispatchQueue.global(qos: .background).async { [unowned self] in
                let newSiswas = viewModel.pasteSiswas(from: fileURLs)
                // Hapus semua informasi dari array redo
                insertMultipleSiswas(newSiswas, comparator: comparator)
                deleteAllRedoArray(self)
                pastedSiswasArray.append(newSiswas)

                // Daftarkan aksi undo untuk paste
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
                    targetSelf.undoPaste(self)
                }
            }
            return true
        }

        guard row != -1, row < viewModel.flattenedData().count else {
            return false
        }

        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            guard let id: Int64 = viewModel.getSiswaId(row: row) else { return }
            let imageData = getOrCreateImage(id, image: image)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.undoDragFoto(id, image: imageData)
            })

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            }
        }
        return true
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow _: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard FilePromiseProvider.validateImageForDrop(info) != nil else { return [] }

        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return [] // Return empty operation to disable drop
        }
        if dropOperation == .above {
            info.animatesToDestination = true
            tableView.setDropRow(-1, dropOperation: .above)
            return .copy
        } else {
            info.animatesToDestination = true
            return .copy
        }
    }

    /**
     Mengurungkan operasi drag foto siswa.

     Fungsi ini membatalkan perubahan foto siswa yang sebelumnya diseret dan dijatuhkan.
     Ini mendaftarkan operasi 'redo' dengan `UndoManager` untuk memungkinkan pengembalian perubahan.
     Fungsi ini juga memperbarui foto di database dan memilih baris yang sesuai di tabel.

     - Parameter:
        - id: ID siswa yang foto-nya akan dikembalikan.
        - image: `NSImage` yang akan dikembalikan.
     */
    func undoDragFoto(_ id: Int64, image: NSImage) {
        delegate?.didUpdateTable(.siswa)
        let oldImage = getOrCreateImage(id, image: image)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoDragFoto(id, image: oldImage)
        })
        guard let index = viewModel.getIndexForSiswa(id) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
        }
    }

    private func getOrCreateImage(_ id: Int64, image: NSImage) -> NSImage {
        let databaseImage = viewModel.updateFotoSiswa(id: id, newImage: image)
        return databaseImage == nil
            ? NSImage()
            : databaseImage!
    }
}
