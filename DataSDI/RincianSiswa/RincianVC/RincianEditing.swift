//
//  RincianEditing.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

extension DetailSiswaController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let editedCell = textField.superview as? NSTableCellView,
              let activeTable = activeTable() else { return }

        let row = activeTable.row(for: editedCell)
        let column = activeTable.column(for: editedCell)

        guard row >= 0,
              let columnIdentifier = KelasColumn(rawValue: activeTable.tableColumns[column].identifier.rawValue),
              let table = SingletonData.dbTable(forTableType: tableTypeForTable(activeTable))
        else { return }

        let tableType = tableTypeForTable(activeTable)

        let newValue = textField.stringValue
        let oldValue = viewModel.getOldValueForColumn(tableType: tableType, rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableType, siswaID: siswaID), table: table)

        guard newValue != oldValue,
              let selectedTabView = tabView.selectedTabViewItem
        else { return }

        // Dapatkan kelasId dari model data
        let kelasId = viewModel.kelasModelForTable(tableType, siswaID: siswaID)[row].kelasID
        // Simpan originalModel untuk undo dengan kelasId
        let originalModel = OriginalData(
            kelasId: kelasId, tableType: tableType,
            columnIdentifier: columnIdentifier,
            oldValue: oldValue,
            newValue: newValue,
            table: table,
            tableView: activeTable
        )

        viewModel.updateModelAndDatabase(columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, oldValue: oldValue, modelArray: viewModel.kelasModelForTable(tableType, siswaID: siswaID), table: table, tableView: createStringForActiveTable(), kelasId: kelasId, undo: false)

        NotificationCenter.default.post(name: .editDataSiswa, object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": createStringForActiveTable(), "newValue": newValue, "kelasId": originalModel.kelasId])
        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager?.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        }
        deleteRedoArray(self)
        updateValuesForSelectedTab(tabIndex: tabView.indexOfTabViewItem(selectedTabView), semesterName: smstr.titleOfSelectedItem ?? "")
        updateUndoRedo(nil)
    }
}
