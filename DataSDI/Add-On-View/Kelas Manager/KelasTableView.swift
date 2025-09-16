//
//  KelasTableView.swift
//  Data SDI
//
//  Created by MacBook on 06/09/25.
//

import Cocoa

extension KelasTableManager: NSTableViewDataSource {
    /// Mengambil data model kelas berdasarkan `tableView` yang diberikan
    /// atau berdasarkan  tipe ``activeTableType`` jika dalam model arsip (KelasHistoris).
    ///
    /// Fungsi ini bertindak sebagai perantara untuk mengambil array dari `KelasModels`
    /// yang difilter berdasarkan tipe tabel, ID siswa, dan status arsip.
    /// Jika `tableType` tidak dapat ditentukan, fungsi akan mengembalikan array kosong.
    /// 
    /// - Returns: Sebuah array dari `KelasModels` yang berisi data yang relevan untuk tabel yang diberikan.
    /// - Parameter tableView: `NSTableView` untuk menentukan tipe data yang sesuai menggunakan func
    /// ``KelasViewModel/kelasModelForTable(_:siswaID:arsip:)``
    func getData(for tableView: NSTableView) -> [KelasModels] {
        if !arsip,
           let tableType = tableType(tableView) 
        {
            viewModel.kelasModelForTable(tableType, siswaID: siswaID)
        } else {
            viewModel.kelasModelForTable(activeTableType, siswaID: siswaID, arsip: arsip)
        }
    }

    /// Mengembalikan jumlah baris dalam tabel yang ditentukan
    func numberOfRows(in tableView: NSTableView) -> Int {
        getData(for: tableView).count
    }

    /// Menangani perubahan deskriptor pengurutan
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        let table = tableView
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }

        let data = getData(for: tableView)

        let sortedModel = viewModel.sortModel(data, by: sortDescriptor)
        viewModel.setModel(sortedModel, for: activeTableType, siswaID: siswaID, arsip: arsip)

        let indexset = IndexSet(selectedIDs.compactMap { id in
            sortedModel.firstIndex(where: { $0.nilaiID == id })
        })
        ReusableFunc.saveSortDescriptor(sortDescriptor, key: tableIdentifierStr)
        tableView.reloadData()
        table.selectRowIndexes(indexset, byExtendingSelection: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let max = indexset.max() {
                table.scrollRowToVisible(max)
            }
        }
    }
}

extension KelasTableManager: NSTableViewDelegate {
    /**
     Menyediakan tampilan untuk sel tabel tertentu

     - Parameter:
       - tableView: Tampilan tabel yang meminta sel
       - tableColumn: Kolom yang akan ditampilkan
       - row: Indeks baris

     - Returns: Tampilan sel tabel yang dikonfigurasi atau nil
     */
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let data = getData(for: tableView)
        let kelasModel = data[row]

        if row < data.count,
           let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView,
           let tableColumnIdentifier = tableColumn?.identifier.rawValue,
           let kelasColumns = KelasColumn(rawValue: tableColumnIdentifier),
           let textField = cell.textField
        {
            textField.lineBreakMode = .byTruncatingMiddle
            textField.usesSingleLineMode = true
            switch kelasColumns {
            case .nama:
                textField.stringValue = kelasModel.namasiswa
                textField.isEditable = false
                tableColumn?.minWidth = 80
                tableColumn?.maxWidth = 500
            case .mapel:
                textField.stringValue = kelasModel.mapel
                tableColumn?.minWidth = 80
                tableColumn?.maxWidth = 350
            case .nilai:
                let nilai = kelasModel.nilai
                textField.isEditable = arsip ? false : true
                textField.delegate = arsip ? nil : self
                textField.stringValue = nilai == 00 ? "" : String(nilai)
                textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.controlTextColor
                tableColumn?.minWidth = 40
                tableColumn?.maxWidth = 55
            case .semester:
                textField.stringValue = kelasModel.semester
                tableColumn?.minWidth = 30
                tableColumn?.maxWidth = 150
            case .guru:
                textField.stringValue = kelasModel.namaguru
                tableColumn?.minWidth = 80
                tableColumn?.maxWidth = 500
            case .tahun:
                textField.stringValue = kelasModel.tahunAjaran
                tableColumn?.minWidth = 80
                tableColumn?.maxWidth = 90
            case .status:
                textField.stringValue = kelasModel.status?.description ?? ""
                tableColumn?.minWidth = 40
                tableColumn?.maxWidth = 80
            case .tgl:
                textField.alphaValue = 0.6
                guard let dateFormatter = ReusableFunc.dateFormatter else { return cell }
                let availableWidth = tableColumn?.width ?? 0
                if availableWidth <= 80 {
                    dateFormatter.dateFormat = "d/M/yy"
                } else if availableWidth <= 120 {
                    dateFormatter.dateFormat = "d MMM yyyy"
                } else {
                    dateFormatter.dateFormat = "dd MMMM yyyy"
                }
                // Ambil tanggal dari siswa menggunakan KeyPath
                let tanggalString = kelasModel.tanggal
                if let date = dateFormatter.date(from: tanggalString) {
                    textField.stringValue = dateFormatter.string(from: date)
                } else {
                    textField.stringValue = tanggalString // fallback jika parsing gagal
                }
                tableColumn?.minWidth = 70
                tableColumn?.maxWidth = 140
            }
            return cell
        }
        return nil
    }

    /**
     Menentukan apakah kolom dapat diurutkan ulang

     - Parameter:
       - tableView: Tampilan tabel
       - columnIndex: Indeks kolom saat ini
       - newColumnIndex: Indeks kolom baru yang diusulkan

     - Returns: Boolean yang menunjukkan apakah pengurutan ulang diizinkan
     */
    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        if columnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }

        if newColumnIndex == 0 {
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }

        return true
    }

    /// Mencegah pemilihan kolom
    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    /// Menangani peristiwa perubahan ukuran kolom
    func tableViewColumnDidResize(_ notification: Notification) {
        // Periksa kolom yang diresize
        guard let tableView = notification.object as? NSTableView,
              let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")),
              !tableColumn.isHidden
        else { return }

        let column = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
        // Pastikan jumlah baris dalam tableView sesuai dengan jumlah data di model
        let rowCount = tableView.numberOfRows

        let data = getData(for: tableView)

        guard data.count == rowCount else { return }

        for row in 0 ..< rowCount {
            let siswa = data[row]
            if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
               let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            {
                ReusableFunc.updateDateFormat(for: cellView, dateString: siswa.tanggal, columnWidth: resizedColumn.width)
            }
        }
    }

    /// Menangani peristiwa perpindahan kolom
    func tableViewColumnDidMove(_ notification: Notification) {
        guard let activeTable = notification.object as? NSTableView else { return }

        let exceptions: Array = siswaID == nil
            ? [KelasColumn.nama.rawValue]
            : [KelasColumn.mapel.rawValue]

        ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: exceptions, target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    /// Mengembalikan tinggi baris untuk tabel
    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        tableView.rowHeight
    }

    /// Menangani perubahan pemilihan tabel
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let data = getData(for: tableView)
        selectedIDs.removeAll()
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                guard index >= 0, index < data.count else {
                    return nil // Mengabaikan indeks yang tidak valid
                }
                return data[index].nilaiID
            })
        }

        // Panggil metode delegate saat seleksi berubah
        selectionDelegate?.didSelectRow(tableView, at: tableView.selectedRow)
    }

    /// Fungsi ini mengembalikan tipe tabel berdasarkan `NSTableView` yang diberikan.
    /// - Parameter tableView: `NSTableView` yang ingin diperiksa.
    /// - Returns: `TableType?` yang sesuai dengan `NSTableView`, atau `nil` jika tidak ditemukan.
    func tableType(_ tableView: NSTableView) -> TableType? {
        tableInfo.first(where: { $0.table == tableView })?.type
    }

    /// Fungsi ini menangani aksi toggle visibilitas kolom pada tabel.
    /// - Parameter sender: Objek pemicu `NSMenuItem`.
    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else {
            return
        }

        // Toggle visibilitas kolom
        column.isHidden = !column.isHidden

        // Update state pada menu item
        sender.state = column.isHidden ? .off : .on
    }

    /**
     Mengambil tampilan tabel berdasarkan indeks

     - Parameter index: Indeks tabel
     - Returns: Tampilan tabel yang diminta atau nil
     */
    func getTableView(for index: Int) -> NSTableView? {
        // Cukup akses array menggunakan indeks
        guard index >= 0, index < tables.count else {
            return nil
        }
        return tables[index]
    }

    /**
         Mengembalikan string yang merepresentasikan nama tabel aktif.

         Fungsi ini memeriksa tabel mana yang sedang aktif dan mengembalikan string yang sesuai dengan nama tabel tersebut.
         Jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali, fungsi ini akan mengembalikan pesan yang menyatakan bahwa tabel aktif tidak memiliki nama.

         - Returns: String yang merepresentasikan nama tabel aktif, atau pesan kesalahan jika tabel aktif tidak dikenali atau tidak ada.
     */
    func createStringForActiveTable() -> String {
        // Cari indeks dari tabel aktif di dalam array tables
        if let activeTableView, let index = tables.firstIndex(of: activeTableView) {
            // Gunakan indeks untuk membuat string
            "table\(index + 1)"
        } else {
            // Fallback jika tabel aktif tidak ditemukan dalam array
            "Tabel Aktif?"
        }
    }

    /**
         Mengembalikan label yang sesuai dengan tabel yang sedang aktif.

         Fungsi ini memeriksa tabel mana yang sedang aktif (table1, table2, table3, table4, table5, atau table6) dan mengembalikan string yang sesuai dengan nama kelas. Jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali, fungsi ini mengembalikan pesan "Tabel Aktif Tidak Memiliki Nama".

         - Returns: String yang merepresentasikan nama kelas dari tabel yang aktif, atau "Tabel Aktif Tidak Memiliki Nama" jika tidak ada tabel yang aktif atau tabel aktif tidak dikenali.
     */
    func createLabelForActiveTable() -> String {
        // Cari indeks dari tabel aktif di dalam array tables
        if let activeTableView, let index = tables.firstIndex(of: activeTableView) {
            // Gunakan indeks untuk membuat string
            "Kelas \(index + 1)"
        } else {
            // Fallback jika tabel aktif tidak ditemukan dalam array
            "Kelas Aktif?"
        }
    }
}
