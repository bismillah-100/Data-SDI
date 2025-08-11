//
//  TableViewGuru.swift
//  Data SDI
//
//  Created by MacBook on 15/07/25.
//

extension GuruVC: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return viewModel.guru.count
    }

    func tableView(_: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let guru = viewModel.guru
        let text: String

        if tableColumn.identifier.rawValue == "NamaGuru" {
            text = guru[row].namaGuru
        } else if tableColumn.identifier.rawValue == "AlamatGuru" {
            text = guru[row].alamatGuru ?? ""
        } else {
            text = ""
        }

        // Buat cell baru
        let cell = NSTableCellView()
        cell.identifier = tableColumn.identifier

        let textField = NSTextField(labelWithString: text)
        textField.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(textField)
        cell.textField = textField
        cell.textField?.usesSingleLineMode = true
        cell.textField?.isEditable = false
        cell.textField?.lineBreakMode = .byTruncatingMiddle

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            textField.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
        ])

        return cell
    }
}

extension GuruVC: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow _: Int) -> CGFloat {
        return tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        print("Changed to:", tableView.sortDescriptors.first?.key ?? "none")
        if let newDescriptor = tableView.sortDescriptors.first {
            sortDescriptor = newDescriptor
            viewModel.urutkanGuru(newDescriptor)
            viewModel.guruSortDescriptor = sortDescriptor
            tableView.reloadData()

            print("saveSortDescriptor:", newDescriptor.key ?? "")
            saveSortDescriptor(newDescriptor)
        }
    }

    func tableViewSelectionDidChange(_: Notification) {
        NSApp.sendAction(#selector(GuruVC.updateMenuItem), to: nil, from: self)

        guard let toolbar = view.window?.toolbar /* Dapatkan toolbar item yang ingin Anda atur */ else { return }

        let isItemSelected = tableView.selectedRow != -1
        if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
           let hapus = hapusToolbarItem.view as? NSButton
        {
            if isItemSelected {
                hapus.isEnabled = true
                hapus.target = self
                hapus.action = #selector(hapusGuru(_:))
            } else {
                hapus.isEnabled = false
            }
        }
        if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
           let edit = editToolbarItem.view as? NSButton
        {
            if isItemSelected {
                edit.isEnabled = true
            } else {
                // Jika tidak ada item yang dipilih, nonaktifkan tombol edit
                edit.isEnabled = false
            }
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
        return true
    }
}
