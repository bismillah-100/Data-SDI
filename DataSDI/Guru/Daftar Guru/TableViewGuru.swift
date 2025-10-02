//
//  TableViewGuru.swift
//  Data SDI
//
//  Created by MacBook on 15/07/25.
//

extension GuruVC: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        viewModel.guru.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }

        let guru = viewModel.guru
        let text: String = if tableColumn.identifier.rawValue == "NamaGuru" {
            guru[row].namaGuru
        } else if tableColumn.identifier.rawValue == "AlamatGuru" {
            guru[row].alamatGuru ?? ""
        } else {
            ""
        }

        // Gunakan identifier yang SAMA untuk semua kolom text biasa
        let cellIdentifier = NSUserInterfaceItemIdentifier("TextCell")
        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }

        // Buat cell baru HANYA kalau belum ada di reuse queue
        let textField = NSTextField()
        textField.usesSingleLineMode = true
        textField.isEditable = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.isBordered = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)

        let cell = NSTableCellView()
        cell.identifier = cellIdentifier // Identifier TETAP untuk reuse
        cell.addSubview(textField)
        cell.textField = textField
        cell.textField?.stringValue = text

        // Setup constraints HANYA SEKALI saat create
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}

extension GuruVC: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let newDescriptor = tableView.sortDescriptors.first else { return }
        let selectedRows = tableView.selectedRowIndexes
        DispatchQueue.global(qos: .utility).async { [weak self, selectedRows] in
            guard let self else { return }
            viewModel.simpanIdGuruDariSeleksi(&selectedIDs, selectedRows: selectedRows)
            sortDescriptor = newDescriptor
            viewModel.urutkanGuru(newDescriptor)
            viewModel.guruSortDescriptor = sortDescriptor
            saveSortDescriptor(newDescriptor)
            let indexesToSelect = viewModel.indeksDataBerdasarId(selectedIDs)
            DispatchQueue.main.async { [indexesToSelect] in
                tableView.reloadData()
                tableView.selectRowIndexes(indexesToSelect, byExtendingSelection: false)
                if let maxIndexes = indexesToSelect.max() {
                    tableView.scrollRowToVisible(maxIndexes)
                }
            }
        }
    }

    func tableViewSelectionDidChange(_: Notification) {
        NSApp.sendAction(#selector(GuruVC.updateMenuItem), to: nil, from: self)

        guard let wc = AppDelegate.shared.mainWindow.windowController as? WindowController else { return }

        let isItemSelected = tableView.selectedRow != -1
        if let hapusToolbarItem = wc.hapusToolbar,
           let hapus = hapusToolbarItem.view as? NSButton
        {
            hapus.isEnabled = isItemSelected
            hapus.target = isItemSelected ? self : nil
            hapus.action = isItemSelected ? #selector(hapusGuru(_:)) : nil
        }
        if let editToolbarItem = wc.editToolbar,
           let edit = editToolbarItem.view as? NSButton
        {
            edit.isEnabled = isItemSelected
        }
    }
}

extension GuruVC: OverlayEditorManagerDataSource {
    func overlayEditorManager(_: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String {
        guard let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cell.textField
        else {
            return ""
        }
        return textField.stringValue
    }

    func overlayEditorManager(_: OverlayEditorManager, originalColumnWidthForCellAtRow _: Int, column: Int, in tableView: NSTableView) -> CGFloat {
        tableView.tableColumns[column].width
    }

    func overlayEditorManager(_: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String] {
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        switch columnIdentifier {
        case "NamaGuru": // Nama Guru
            return Array(ReusableFunc.namaguru)
        case "AlamatGuru": // Alamat Guru
            return Array(ReusableFunc.alamat)
        default:
            return []
        }
    }
}

extension GuruVC: OverlayEditorManagerDelegate {
    func overlayEditorManager(_: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView) {
        guard let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cell.textField
        else {
            return
        }
        let columnIdentifier = tableView.tableColumns[column].identifier.rawValue
        let oldGuru = viewModel.guru[row]
        let idGuru = oldGuru.idGuru
        let idTugas = oldGuru.idTugas
        let updatedGuru = GuruModel(idGuru: idGuru, idTugas: idTugas)
        let oldValue: String
        let capitalizedText = newText.capitalizedAndTrimmed()

        switch columnIdentifier {
        case "NamaGuru": // Nama Guru
            oldValue = oldGuru.namaGuru
            updatedGuru.namaGuru = capitalizedText
            updatedGuru.alamatGuru = oldGuru.alamatGuru ?? ""
        case "AlamatGuru": // Alamat Guru
            oldValue = oldGuru.alamatGuru ?? ""
            updatedGuru.namaGuru = oldGuru.namaGuru
            updatedGuru.alamatGuru = capitalizedText
        default: oldValue = ""
        }
        guard capitalizedText != oldValue else { return }
        viewModel.updateGuruu([updatedGuru])
        textField.stringValue = capitalizedText
    }

    func overlayEditorManager(_: OverlayEditorManager, perbolehkanEdit _: Int, row _: Int) -> Bool {
        true
    }
}
