//
//  RincianTable.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

extension DetailSiswaController: NSTableViewDataSource, NSTableViewDelegate {
    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil {
            let column = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            let rowCount = tableView.numberOfRows
            let siswaList = viewModel.kelasModelForTable(tableTypeForTable(tableView), siswaID: siswaID)

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
        guard let table = activeTable() else { return }
        let tableColumns = table.tableColumns
        ReusableFunc.updateColumnMenu(table, tableColumns: tableColumns, exceptions: ["mapel"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }

    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        tableView.rowHeight
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        let tableType = tableTypeForTable(tableView)
        return viewModel.numberOfRows(forTableType: tableType, siswaID: siswaID)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableType = tableTypeForTable(tableView)
        guard let kelasModel = viewModel.modelForRow(at: row, tableType: tableType, siswaID: siswaID) else { return NSView() }
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                switch tableColumn?.identifier {
                case NSUserInterfaceItemIdentifier("mapel"):
                    textField.stringValue = kelasModel.mapel
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 350
                case NSUserInterfaceItemIdentifier("nilai"):
                    let nilai = kelasModel.nilai
                    textField.stringValue = nilai == 00 ? "" : String(nilai)
                    textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.controlTextColor
                    tableColumn?.minWidth = 30
                    tableColumn?.maxWidth = 40
                    textField.isEditable = true
                    textField.delegate = self
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

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIDs.removeAll()
        guard let tableView = notification.object as? NSTableView,
              tableView.numberOfRows != 0
        else { return }
        let table = activeTable()!
        let model = viewModel.kelasModelForTable(tableTypeForTable(table), siswaID: siswaID)
        if tableView.selectedRowIndexes.count > 0 {
            selectedIDs = Set(tableView.selectedRowIndexes.compactMap { index in
                guard index >= 0, index < model.count else {
                    return nil // Mengabaikan indeks yang tidak valid
                }
                return model[index].kelasID
            })
        }
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
    }

    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

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

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        KelasModels.siswaSortDescriptor = sortDescriptor
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let tableType = tableTypeForTable(tableView)
            let model = viewModel.kelasModelForTable(tableType, siswaID: siswaID)
            let sortedModel = viewModel.sortModel(model, by: sortDescriptor)
            var indexset = IndexSet()
            for id in selectedIDs {
                if let index = sortedModel.firstIndex(where: { $0.kelasID == id }) {
                    indexset.insert(index)
                }
            }

            viewModel.setModel(sortedModel, for: tableType, siswaID: siswaID)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tableView.reloadData()
                tableView.selectRowIndexes(indexset, byExtendingSelection: false)
                if let max = indexset.max() {
                    tableView.scrollRowToVisible(max)
                }
                ReusableFunc.saveSortDescriptor(sortDescriptor, key: "SortDescriptorSiswa_\(self.createStringForActiveTable())")
            }
        }
    }
}
