//
//  KelasHistory Table.swift
//  Data SDI
//
//  Created by MacBook on 30/07/25.
//

import Cocoa

extension KelasHistoryVC: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        guard let type = activeTableType else { return 0 }
        return viewModel.arsipKelasData[type]?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            await sortData()

            await MainActor.run {
                tableView.reloadData()
                guard let sortDescriptor = tableView.sortDescriptors.first else { return }
                ReusableFunc.saveSortDescriptor(sortDescriptor, key: "KelasHistoris-SortDescriptor")
            }
        }
    }
}

extension KelasHistoryVC: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let kelasModel = viewModel.arsipKelasData[activeTableType]?[row] else { return nil }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                textField.lineBreakMode = .byTruncatingMiddle
                textField.usesSingleLineMode = true
                textField.isEditable = false
                switch tableColumn?.identifier {
                case NSUserInterfaceItemIdentifier("namasiswa"):
                    textField.stringValue = kelasModel.namasiswa
                    tableColumn?.minWidth = 80
                    tableColumn?.maxWidth = 500
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

    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        tableView.rowHeight
    }

    func tableViewColumnDidMove(_: Notification) {
        ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["namasiswa"], target: self, selector: #selector(toggleColumnVisibility(_:)))
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

    func tableView(_: NSTableView, shouldSelect _: NSTableColumn?) -> Bool {
        false
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        // Periksa kolom yang diresize
        if tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl")) != nil,
           let siswaList = viewModel.arsipKelasData[activeTableType]
        {
            let column = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tgl"))
            let rowCount = tableView.numberOfRows

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

    func tableViewSelectionDidChange(_: Notification) {
        NSApp.sendAction(#selector(KelasHistoryVC.updateMenuItem), to: nil, from: self)
    }
}
