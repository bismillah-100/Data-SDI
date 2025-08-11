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
        if currentTableViewMode == .plain {
            viewModel.filteredSiswaData.count
        } else {
            viewModel.groupedSiswa.reduce(0) { $0 + $1.count + 1 }
        }
    }

    func tableView(_: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard currentTableViewMode == .grouped else { return nil }
        let rowView = CustomRowView()
        let (isGroup, _, _) = getRowInfoForRow(row)
        if isGroup {
            rowView.isGroupRowStyle = true
            return rowView
        } else {
            return NSTableRowView()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let (isGroupRow, sectionIndex, rowIndexInSection) = getRowInfoForRow(row)

        if currentTableViewMode == .plain {
            guard row < viewModel.filteredSiswaData.count else { return NSView() }
            let siswa = viewModel.filteredSiswaData[row]

            if let columnIdentifier = tableColumn?.identifier.rawValue {
                switch columnIdentifier {
                case "Nama":
                    return configureSiswaCell(for: tableView, siswa: siswa, row: row)
                case "Tahun Daftar", "Tgl. Lulus":
                    return configureDatePickerCell(for: tableView, tableColumn: tableColumn, siswa: siswa, dateKeyPath: columnIdentifier == "Tahun Daftar" ? \.tahundaftar : \.tanggalberhenti, tag: columnIdentifier == "Tahun Daftar" ? 1 : 2)
                default:
                    return configureGeneralCell(for: tableView, columnIdentifier: columnIdentifier, siswa: siswa, row: row)
                }
            }
        } else if currentTableViewMode == .grouped {
            return configureGroupedCell(for: tableView, tableColumn: tableColumn, isGroupRow: isGroupRow, sectionIndex: sectionIndex, rowIndexInSection: rowIndexInSection)
        }

        return NSView()
    }

    /**
         Mengkonfigurasi tampilan cell untuk tabel siswa.

         - Parameter tableView: NSTableView yang akan dikonfigurasi cell-nya.
         - Parameter siswa: ModelSiswa yang datanya akan ditampilkan pada cell.
         - Parameter row: Indeks baris dari cell yang sedang dikonfigurasi.
         - Returns: NSView yang telah dikonfigurasi sebagai cell siswa, atau nil jika gagal.
     */
    func configureSiswaCell(for tableView: NSTableView, siswa: ModelSiswa, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SiswaCell"), owner: self) as? NSTableCellView,
              let imageView = cell.imageView
        else { return nil }

        cell.textField?.stringValue = siswa.nama
        let selected = tableView.selectedRowIndexes.contains(row)
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            var image = ""
            if siswa.status == .lulus {
                let lulus = StatusSiswa.lulus.description
                image = selected ? lulus + " Bordered" : lulus
            } else {
                image = self.viewModel.determineImageName(for: siswa.tingkatKelasAktif.rawValue, bordered: selected)
            }
            DispatchQueue.main.async { [weak imageView] in
                imageView?.image = NSImage(named: image)
            }
        }

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
            configureGroupedRowView(for: tableView, tableColumn: tableColumn, sectionIndex: sectionIndex, rowIndexInSection: rowIndexInSection)
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
    func configureGroupedRowView(for tableView: NSTableView, tableColumn: NSTableColumn?, sectionIndex: Int, rowIndexInSection: Int) -> NSView? {
        guard sectionIndex >= 0,
              sectionIndex < viewModel.groupedSiswa.count else { return nil }

        // Guard untuk memastikan rowIndexInSection valid
        guard rowIndexInSection >= 0,
              rowIndexInSection < viewModel.groupedSiswa[sectionIndex].count else { return nil }

        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CellForRowInGroup"), owner: self) as? NSTableCellView,
              let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }

        let siswa = viewModel.groupedSiswa[sectionIndex][rowIndexInSection]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        switch columnIdentifier {
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
            let availableWidth = tableColumn?.width ?? 0
            if availableWidth <= 80 {
                dateFormatter.dateFormat = "d/M/yy"
            } else if availableWidth <= 120 {
                dateFormatter.dateFormat = "d MMM yyyy"
            } else {
                dateFormatter.dateFormat = "dd MMMM yyyy"
            }
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tahundaftar

            if let date = dateFormatter.date(from: tanggalString) {
                cell.textField?.stringValue = dateFormatter.string(from: date)
            } else {
                cell.textField?.stringValue = tanggalString // fallback jika parsing gagal
            }
        case "Tgl. Lulus":
            let availableWidth = tableColumn?.width ?? 0
            if availableWidth <= 80 {
                dateFormatter.dateFormat = "d/M/yy"
            } else if availableWidth <= 120 {
                dateFormatter.dateFormat = "d MMM yyyy"
            } else {
                dateFormatter.dateFormat = "dd MMMM yyyy"
            }
            // Ambil tanggal dari siswa menggunakan KeyPath
            let tanggalString = siswa.tanggalberhenti

            if let date = dateFormatter.date(from: tanggalString) {
                cell.textField?.stringValue = dateFormatter.string(from: date)
            } else {
                cell.textField?.stringValue = tanggalString // fallback jika parsing gagal
            }
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
        let sortDescriptorDidChange = sortDescriptor != ModelSiswa.currentSortDescriptor
        ModelSiswa.currentSortDescriptor = sortDescriptor
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        saveSortDescriptor(sortDescriptor)
        // Lakukan pengurutan berdasarkan sort descriptor yang dipilih
        if sortDescriptorDidChange || currentTableViewMode == .grouped {
            sortData(with: sortDescriptor)
            if let firstColumnSortDescriptor = tableView.tableColumns.first?.sortDescriptorPrototype {
                isSortedByFirstColumn = (firstColumnSortDescriptor.key == sortDescriptor.key)
            } else {
                isSortedByFirstColumn = false
            }
        }
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard currentTableViewMode == .grouped else { return true }
        // Periksa apakah baris tersebut adalah bagian (section)
        let (isGroupRow, _, _) = getRowInfoForRow(row)
        if isGroupRow {
            return false // Menonaktifkan seleksi untuk bagian (section)
        } else {
            return true // Mengizinkan seleksi untuk baris biasa di dalam bagian
        }
    }

    func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
        // Periksa apakah mode adalah .grouped dan baris adalah header kelas
        if currentTableViewMode == .grouped {
            getRowInfoForRow(row).isGroupRow
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
        selectedIds.removeAll()

        let selectedRow = tableView.selectedRow
        if let toolbar = view.window?.toolbar {
            // Aktifkan isEditable pada baris yang sedang dipilih
            if selectedRow != -1 {
                if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
                   let hapus = hapusToolbarItem.view as? NSButton
                {
                    hapus.isEnabled = true
                    hapus.target = self
                    hapus.action = #selector(deleteSelectedRowsAction(_:))
                }
                if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
                   let edit = editToolbarItem.view as? NSButton
                {
                    edit.isEnabled = true
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
        // Nonaktifkan isEditable pada baris yang sedang diedit sebelumnya
        if currentTableViewMode == .grouped {
        } else if currentTableViewMode == .plain {
            let selectedRowIndexes = tableView.selectedRowIndexes
            let maxRow = viewModel.filteredSiswaData.count - 1

            // Hapus border dari baris yang tidak lagi dipilih
            if let full = previouslySelectedRows.max() {
                guard full < tableView.numberOfRows else {
                    previouslySelectedRows.remove(full)
                    return
                }
                for row in previouslySelectedRows {
                    guard row <= maxRow else { continue }
                    if !selectedRowIndexes.contains(row),
                       let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
                    {
                        let previousSiswa = viewModel.filteredSiswaData[row]
                        var image = ""
                        if previousSiswa.status == .lulus {
                            image = StatusSiswa.lulus.description
                        } else {
                            image = viewModel.determineImageName(for: previousSiswa.tingkatKelasAktif.rawValue, bordered: false)
                        }
                        DispatchQueue.main.async {
                            previousCellView.imageView?.image = NSImage(named: image)
                        }
                    }
                }
            }

            // Tambahkan border ke semua baris yang dipilih
            for row in selectedRowIndexes {
                guard row <= maxRow else { continue }
                if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let siswa = viewModel.filteredSiswaData[row]
                    var image = ""
                    if siswa.status == .lulus {
                        image = StatusSiswa.lulus.description + " Bordered"
                    } else {
                        image = viewModel.determineImageName(for: siswa.tingkatKelasAktif.rawValue, bordered: true)
                    }
                    DispatchQueue.main.async {
                        selectedCellView.imageView?.image = NSImage(named: image)
                    }
                }
            }

            // Simpan baris yang saat ini dipilih
            previouslySelectedRows = selectedRowIndexes
        }

        NSApp.sendAction(#selector(SiswaViewController.updateMenuItem(_:)), to: nil, from: self)
        if tableView.selectedRowIndexes.count > 0 {
            if currentTableViewMode == .plain {
                selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                    if index < viewModel.filteredSiswaData.count {
                        return viewModel.filteredSiswaData[index].id
                    }
                    return nil
                })
            } else {
                selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                    for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                        let startRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: 0)
                        let endRowIndex = startRowIndex + siswaGroup.count
                        if index >= startRowIndex, index < endRowIndex {
                            let siswaIndex = index - startRowIndex
                            return siswaGroup[siswaIndex].id
                        }
                    }
                    return nil
                })
            }
        }

        if SharedQuickLook.shared.isQuickLookVisible() {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    func tableViewSelectionIsChanging(_: Notification) {
        guard currentTableViewMode == .plain,
              tableView.numberOfRows > 0
        else { return }

        let selectedRowIndexes = tableView.selectedRowIndexes

        // Hapus border dari baris yang tidak lagi dipilih
        if let full = previouslySelectedRows.max() {
            guard full < tableView.numberOfRows else {
                previouslySelectedRows.remove(full)
                return
            }

            NSApp.sendAction(#selector(SiswaViewController.updateMenuItem(_:)), to: nil, from: self)
            if tableView.selectedRowIndexes.count > 0 {
                if currentTableViewMode == .plain {
                    selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                        viewModel.filteredSiswaData[index].id
                    })
                } else {
                    selectedIds = Set(tableView.selectedRowIndexes.compactMap { index in
                        for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                            let startRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: 0)
                            let endRowIndex = startRowIndex + siswaGroup.count
                            if index >= startRowIndex, index < endRowIndex {
                                let siswaIndex = index - startRowIndex
                                return siswaGroup[siswaIndex].id
                            }
                        }
                        return nil
                    })
                }
            }
            for row in previouslySelectedRows {
                if !selectedRowIndexes.contains(row), let previousCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                    let previousSiswa = viewModel.filteredSiswaData[row]
                    var image = ""
                    if previousSiswa.status == .lulus {
                        image = StatusSiswa.lulus.description
                    } else {
                        image = viewModel.determineImageName(for: previousSiswa.tingkatKelasAktif.rawValue, bordered: false)
                    }
                    DispatchQueue.main.async {
                        previousCellView.imageView?.image = NSImage(named: image)
                    }
                }
            }
        }

        // Tambahkan border ke semua baris yang dipilih
        for row in selectedRowIndexes {
            if let selectedCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView {
                let siswa = viewModel.filteredSiswaData[row]
                var image = ""
                if siswa.status == .lulus {
                    image = StatusSiswa.lulus.description + " Bordered"
                } else {
                    image = viewModel.determineImageName(for: siswa.tingkatKelasAktif.rawValue, bordered: true)
                }
                DispatchQueue.main.async {
                    selectedCellView.imageView?.image = NSImage(named: image)
                }
            }
        }

        // Simpan baris yang saat ini dipilih
        previouslySelectedRows = selectedRowIndexes
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if currentTableViewMode == .grouped {
            let (isGroupRow, _, _) = getRowInfoForRow(row)
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
    func configureDatePickerCell(for tableView: NSTableView, tableColumn: NSTableColumn?, siswa: ModelSiswa, dateKeyPath: KeyPath<ModelSiswa, String>, tag: Int) -> CustomTableCellView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "expDP"), owner: self) as? CustomTableCellView else { return nil }

        // Ambil textField dan DatePicker dari cell yang di-reuse
        let textField = cell.textField
        let pilihTanggal = cell.datePicker
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // Set target dan action untuk DatePicker
        pilihTanggal.target = self
        pilihTanggal.action = #selector(datePickerValueChanged(_:))
        pilihTanggal.tag = tag

        let availableWidth = tableColumn?.width ?? 0

        if availableWidth <= 80 {
            dateFormatter.dateFormat = "d/M/yy"
        } else if availableWidth <= 120 {
            dateFormatter.dateFormat = "d MMM yyyy"
        } else {
            dateFormatter.dateFormat = "dd MMMM yyyy"
        }

        // Ambil tanggal dari siswa menggunakan KeyPath
        let tanggalString = siswa[keyPath: dateKeyPath]

        // Convert string date to Date object
        if let date = dateFormatter.date(from: tanggalString) {
            pilihTanggal.dateValue = date
            textField?.stringValue = dateFormatter.string(from: date)
        } else {
            textField?.stringValue = tanggalString // fallback jika parsing gagal
        }

        // Convert string date to Date object dan set DatePicker value
        textField?.isEditable = false

        return cell
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }

        if currentTableViewMode == .plain {
            // Kode untuk mode plain
            tableView.beginUpdates()
            updateCells(for: tableView, columnIdentifier: tahunDaftarColumn.identifier.rawValue, siswaData: viewModel.filteredSiswaData)
            updateCells(for: tableView, columnIdentifier: tglLulusColumn.identifier.rawValue, siswaData: viewModel.filteredSiswaData)
            tableView.endUpdates()
        } else {
            // Kode untuk mode grup
            tableView.beginUpdates()
            for row in 0 ..< tableView.numberOfRows {
                let rowInfo = getRowInfoForRow(row)
                // Pastikan bahwa kita tidak memperbarui header grup
                if !rowInfo.isGroupRow {
                    let groupIndex = rowInfo.sectionIndex
                    let rowIndexInSection = rowInfo.rowIndexInSection

                    // Mengakses siswa dari groupedSiswa
                    let siswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                    // Update untuk kolom "Tahun Daftar"
                    let tahunDaftarColumnIndex = ReusableFunc.columnIndex(of: tahunDaftarColumn, in: tableView)
                    if siswa.tahundaftar.isEmpty {
                        if let cellView = tableView.view(atColumn: tahunDaftarColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView {
                            ReusableFunc.updateDateFormat(for: cellView, dateString: siswa.tahundaftar, columnWidth: tahunDaftarColumn.width)
                        }
                    }

                    // Update untuk kolom "Tgl. Lulus"
                    let tglLulusColumnIndex = ReusableFunc.columnIndex(of: tglLulusColumn, in: tableView)
                    if siswa.tanggalberhenti.isEmpty {
                        if let cellView = tableView.view(atColumn: tglLulusColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView {
                            ReusableFunc.updateDateFormat(for: cellView, dateString: siswa.tanggalberhenti, columnWidth: tglLulusColumn.width)
                        }
                    }
                }
            }
            tableView.endUpdates()
        }
    }

    /**
     Memperbarui sel-sel pada NSTableView untuk kolom tertentu dengan data siswa.

     Fungsi ini digunakan untuk memperbarui tampilan sel dalam NSTableView berdasarkan data siswa yang diberikan.
     Fungsi ini akan mencari kolom berdasarkan identifier yang diberikan, dan kemudian memperbarui setiap sel
     dalam kolom tersebut dengan data yang sesuai dari array `siswaData`. Jika kolom yang sesuai ditemukan dan
     sel adalah instance dari `CustomTableCellView`, fungsi ini akan memanggil `updateDateFormat` untuk
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
                if let cellView = tableView.view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? CustomTableCellView {
                    let dateString = columnIdentifier == "Tahun Daftar" ? siswa.tahundaftar : siswa.tanggalberhenti
                    ReusableFunc.updateDateFormat(for: cellView, dateString: dateString, columnWidth: resizedColumn.width)
                }
            }
        }
    }

    /**
         Membuat gambar teks untuk nama yang diberikan.

         - Parameter name: Nama untuk membuat gambar teks.
         - Returns: NSImage yang berisi teks nama, atau nil jika terjadi kesalahan.
     */
    func createTextImage(for name: String) -> NSImage? {
        let font = NSFont.systemFont(ofSize: 13)
        let textSize = name.size(withAttributes: [.font: font])
        let imageSize = NSSize(width: textSize.width, height: tableView.rowHeight)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.controlTextColor]
        name.draw(at: NSPoint(x: 0, y: 0), withAttributes: attributes)
        image.unlockFocus()

        return image
    }

    /**
         Memeriksa apakah sumber seret berasal dari tabel kita.

         - Parameter draggingInfo: Informasi seret.
         - Returns: `true` jika sumber seret adalah tabel kita, jika tidak, `false`.
     */
    func dragSourceIsFromOurTable(draggingInfo: NSDraggingInfo) -> Bool {
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableView {
            true
        } else {
            false
        }
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt _: NSPoint, forRowIndexes _: IndexSet) {
        session.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            guard let pasteboardItem = dragItem.item as? NSPasteboardItem else {
                print("Error: Tidak dapat mengakses pasteboard item")
                return
            }

            // Ambil data dari pasteboardItem
            if let fotoData = pasteboardItem.data(forType: NSPasteboard.PasteboardType.tiff),
               let image = NSImage(data: fotoData), let nama = pasteboardItem.string(forType: NSPasteboard.PasteboardType.string)
            {
                // Gunakan foto dari database sebagai drag image
                let dragSize = NSSize(width: tableView.rowHeight, height: tableView.rowHeight)
                let resizedImage = ReusableFunc.resizeImage(image: image, to: dragSize)

                // Menghitung lebar teks dengan atribut font
                let font = NSFont.systemFont(ofSize: 13) // Anda bisa menggunakan font yang sesuai
                let textSize = nama.size(withAttributes: [.font: font])

                // Mengatur ukuran drag item
                let textWidth = textSize.width
                let textVerticalPosition = (dragSize.height - 17) / 2 // Posisi tengah vertikal

                // Atur imageComponentsProvider untuk setiap dragItem
                dragItem.imageComponentsProvider = {
                    var components = [NSDraggingImageComponent(key: .icon)]

                    // Komponen untuk foto
                    let fotoComponent = NSDraggingImageComponent(key: .icon)
                    fotoComponent.contents = resizedImage
                    fotoComponent.frame = NSRect(origin: .zero, size: dragSize)
                    components.append(fotoComponent)

                    // Komponen untuk nama
                    let textComponent = NSDraggingImageComponent(key: .label)
                    textComponent.contents = self.createTextImage(for: nama)
                    textComponent.frame = NSRect(x: dragSize.width, y: textVerticalPosition, width: textWidth, height: dragSize.height)
                    components.append(textComponent)
                    return components
                }
                // session.draggingFormation = .list

                // Lakukan sesuatu dengan gambar
                #if DEBUG
                    print("Foto berhasil didapatkan")
                #endif
            } else {
                #if DEBUG
                    print("Error: Tidak ada foto di pasteboardItem")
                #endif
            }
        }
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let sourceView = info.draggingSource as? NSTableView,
           sourceView === tableView
        {
            return false
        }

        let pasteboard = info.draggingPasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }

        // Drop di luar baris tableview
        if dropOperation == .above {
            var insertedSiswaIDs: [Int64] = []
            var tempInsertedIndexes = [Int]()
            var tempDeletedSiswaArray = [ModelSiswa]()
            tableView.deselectAll(nil)
            let group = DispatchGroup()
            group.enter()
            guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return false }
            DispatchQueue.global(qos: .background).async { [unowned self] in
                for fileURL in fileURLs {
                    if let image = NSImage(contentsOf: fileURL) {
                        let compressedImageData = image.compressImage(quality: 0.5) ?? Data()
                        let fileName = fileURL.deletingPathExtension().lastPathComponent
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd MMMM yyyy"
                        let currentDate = dateFormatter.string(from: Date())

                        let dataSiswaUntukDicatat: SiswaDefaultData = (
                            nama: fileName,
                            alamat: "",
                            ttl: "",
                            tahundaftar: currentDate,
                            namawali: "",
                            nis: "",
                            nisn: "",
                            ayah: "",
                            ibu: "",
                            jeniskelamin: JenisKelamin.lakiLaki,
                            status: .aktif,
                            tanggalberhenti: "",
                            tlv: "siswa",
                            foto: compressedImageData
                        )
                        // Dapatkan ID siswa yang baru ditambahkan
                        if let insertedSiswaID = dbController.catatSiswa(dataSiswaUntukDicatat) {
                            // Simpan insertedSiswaID ke array
                            insertedSiswaIDs.append(insertedSiswaID)
                        }
                    }
                }
                // Hapus semua informasi dari array redo
                deleteAllRedoArray(self)
                // Daftarkan aksi undo untuk paste
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
                    targetSelf.undoPaste(self)
                }
                group.leave()
            }

            group.notify(queue: .main) { [unowned self] in
                tableView.beginUpdates()
                for insertedSiswaID in insertedSiswaIDs {
                    // Dapatkan data siswa yang baru ditambahkan dari database
                    let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)

                    if currentTableViewMode == .plain {
                        // Pastikan siswa yang baru ditambahkan belum ada di tabel
                        guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else {
                            continue
                        }
                        // Tentukan indeks untuk menyisipkan siswa baru ke dalam array viewModel.filteredSiswaData sesuai dengan urutan kolom
                        let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Masukkan siswa baru ke dalam array viewModel.filteredSiswaData
                        viewModel.insertSiswa(insertedSiswa, at: insertIndex)

                        // Tambahkan baris baru ke tabel dengan animasi
                        tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .effectGap)
                        // Pilih baris yang baru ditambahkan
                        tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                        tempInsertedIndexes.append(insertIndex)
                    } else {
                        // Pastikan siswa yang baru ditambahkan belum ada di groupedSiswa
                        let siswaAlreadyExists = viewModel.groupedSiswa.flatMap { $0 }.contains(where: { $0.id == insertedSiswaID })

                        if siswaAlreadyExists {
                            continue // Jika siswa sudah ada, lanjutkan ke siswa berikutnya
                        }
                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                        viewModel.insertGroupSiswa(insertedSiswa, groupIndex: 7, index: insertIndex)

                        // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                        tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .effectGap)
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                        tempInsertedIndexes.append(absoluteRowIndex + 1)
                    }
                    tempDeletedSiswaArray.append(insertedSiswa)
                }
                tableView.endUpdates()
                if let maxIndex = tempInsertedIndexes.max() {
                    if maxIndex >= tableView.numberOfRows - 1 {
                        tableView.scrollToEndOfDocument(self)
                    } else {
                        tableView.scrollRowToVisible(maxIndex + 1)
                    }
                }
                pastedSiswasArray.append(tempDeletedSiswaArray)

                updateUndoRedo(self)
            }
            return true
        }

        // Untuk operasi non-.above, hanya proses file pertama
        guard let imageURL = fileURLs.first,
              let image = NSImage(contentsOf: imageURL)
        else {
            return false
        }

        guard row != -1, row < viewModel.filteredSiswaData.count else {
            return false
        }
        if dragSourceIsFromOurTable(draggingInfo: info) {
            // Drag source came from our own table view.
            return false
        }

        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            var id: Int64!
            if currentTableViewMode == .plain {
                id = viewModel.filteredSiswaData[row].id
            } else {
                var cumulativeRow = row
                for (_, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                    let groupCount = siswaGroup.count + 1 // +1 untuk header
                    if cumulativeRow < groupCount {
                        let siswaIndex = cumulativeRow - 1 // -1 untuk mengabaikan header
                        if siswaIndex >= 0, siswaIndex < siswaGroup.count {
                            id = siswaGroup[siswaIndex].id
                        }
                        break
                    }
                    cumulativeRow -= groupCount
                }
            }
            let imageData = dbController.bacaFotoSiswa(idValue: id)
            let compressedImageData = image.compressImage(quality: 0.5) ?? Data()
            dbController.updateFotoInDatabase(with: compressedImageData, idx: id)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                self?.undoDragFoto(id, image: imageData)
            })

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                self.updateUndoRedo(self)
            }
        }
        return true
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow _: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
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
        - image: Data gambar asli yang akan dikembalikan.
     */
    func undoDragFoto(_ id: Int64, image: Data) {
        delegate?.didUpdateTable(.siswa)
        tableView.deselectAll(self)

        let data = dbController.bacaFotoSiswa(idValue: id)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.redoDragFoto(id, image: data)
        })
        dbController.updateFotoInDatabase(with: image, idx: id)
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) else { return }
            index = rowIndex
        } else {
            for (groupIndex, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                // Jika dalam mode `grouped`, cari di setiap grup
                if let siswaIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                    // Dapatkan `rowIndex` absolut menggunakan `getAbsoluteRowIndex`
                    index = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                    break
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
            updateUndoRedo(self)
        }
    }

    /**
     Melakukan perubahan foto siswa dan mendaftarkan operasi undo.

     Fungsi ini memperbarui foto siswa dengan ID tertentu dalam database, mendaftarkan operasi undo untuk mengembalikan ke foto sebelumnya,
     dan memilih baris yang sesuai di `tableView`.

     - Parameter id: ID siswa yang fotonya akan diubah.
     - Parameter image: Data gambar baru yang akan disimpan.
     */
    func redoDragFoto(_ id: Int64, image: Data) {
        delegate?.didUpdateTable(.siswa)
        tableView.deselectAll(self)

        let data = dbController.bacaFotoSiswa(idValue: id)
        dbController.updateFotoInDatabase(with: image, idx: id)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoDragFoto(id, image: data)
        })
        var index = Int()
        if currentTableViewMode == .plain {
            guard let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) else { return }
            index = rowIndex
        } else {
            for (groupIndex, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                // Jika dalam mode `grouped`, cari di setiap grup
                if let siswaIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                    // Dapatkan `rowIndex` absolut menggunakan `getAbsoluteRowIndex`
                    index = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                    break
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
            updateUndoRedo(self)
        }
    }
}
