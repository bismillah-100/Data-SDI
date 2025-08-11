//
//  KelasTable.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Cocoa

extension KelasVC: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let tableType = tableType(forTableView: tableView) else { return 0 }
        return viewModel.numberOfRows(forTableType: tableType)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableType = tableType(forTableView: tableView),
              let kelasModel = viewModel.modelForRow(at: row, tableType: tableType)
        else {
            return NSView()
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                textField.lineBreakMode = .byTruncatingMiddle
                textField.usesSingleLineMode = true
                switch tableColumn?.identifier {
                case NSUserInterfaceItemIdentifier("namasiswa"):
                    textField.stringValue = kelasModel.namasiswa
                    textField.isEditable = false
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
                case NSUserInterfaceItemIdentifier("mapel"):
                    textField.stringValue = kelasModel.mapel
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 350
                case NSUserInterfaceItemIdentifier("nilai"):
                    let nilai = kelasModel.nilai
                    textField.isEditable = true
                    textField.delegate = self
                    textField.stringValue = nilai == 00 ? "" : String(nilai)
                    textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.controlTextColor
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 40
                case NSUserInterfaceItemIdentifier("semester"):
                    textField.stringValue = kelasModel.semester
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 150
                case NSUserInterfaceItemIdentifier("namaguru"):
                    textField.stringValue = kelasModel.namaguru
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
                case NSUserInterfaceItemIdentifier("thnAjrn"):
                    textField.stringValue = kelasModel.tahunAjaran
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 90
                case NSUserInterfaceItemIdentifier("tgl"):
                    textField.alphaValue = 0.6
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd MMMM yyyy"
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
                default:
                    break
                }
            }
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard let tableView = activeTable() else { return }
        guard tableView.numberOfRows != 0 else {
            return
        }

        selectedIDs.removeAll()

        NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
        let table = activeTable()!
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                guard index >= 0, index < model.count else {
                    return nil // Mengabaikan indeks yang tidak valid
                }
                return model[index].kelasID
            })
        }
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        let column = tableView.tableColumns[columnIndex].identifier.rawValue

        if column == "namasiswa" || newColumnIndex == 0 {
            // Menghapus highlight secara eksplisit
            tableView.setNeedsDisplay(tableView.rect(ofColumn: columnIndex))
            return false
        }

        return true
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        let table = activeTable()!
        KelasModels.currentSortDescriptor = tableView.sortDescriptors.first
        guard let sortDescriptor = tableView.sortDescriptors.first, let tableType = tableType(forTableView: tableView) else {
            return
        }
        viewModel.sort(tableType: tableType, sortDescriptor: sortDescriptor)
        let model = viewModel.kelasModelForTable(tableTypeForTable(table))
        var indexset = IndexSet()
        for id in selectedIDs {
            if let index = model.firstIndex(where: { $0.kelasID == id }) {
                indexset.insert(index)
            }
        }
        saveSortDescriptor(sortDescriptor, forTableIdentifier: createStringForActiveTable())
        tableView.reloadData()
        table.selectRowIndexes(indexset, byExtendingSelection: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let max = indexset.max() {
                table.scrollRowToVisible(max)
            }
        }
    }

    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            let column = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            // Pastikan jumlah baris dalam tableView sesuai dengan jumlah data di model
            let rowCount = tableView.numberOfRows
            let siswaList = viewModel.kelasModelForTable(tableTypeForTable(tableView))

            guard siswaList.count == rowCount else {
                return
            }
            for row in 0 ..< rowCount {
                let siswa = siswaList[row]
                if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let resizedColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
                {
                    ReusableFunc.updateDateFormat(for: cellView, dateString: siswa.tanggal, columnWidth: resizedColumn.width)
                }
            }
        }
    }

    func tableViewColumnDidMove(_: Notification) {
        guard let activeTable = activeTable() else {
            return
        }
        ReusableFunc.updateColumnMenu(activeTable, tableColumns: activeTable.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow _: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        let table = activeTable()!
        if edge == .trailing, let tabtype = tableType(forTableView: table) {
            var actions: [NSTableViewRowAction] = []
            let hapus = NSTableViewRowAction(style: .destructive, title: "Hapus") { [weak self] _, rowIndex in
                self?.hapusPilih(tableType: tabtype, table: table, selectedIndexes: IndexSet(integer: rowIndex))
            }
            hapus.backgroundColor = NSColor.systemRed
            actions.append(hapus)
            return actions
        } else if edge == .leading {
            let naikKelas = NSTableViewRowAction(style: .regular, title: "Salin Data") { [weak self] _, _ in
                self?.copy(tableView)
            }
            return [naikKelas]
        }

        return []
    }
}
