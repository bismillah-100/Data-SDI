//
//  KelasTextField.swift
//  Data SDI
//
//  Created by MacBook on 06/09/25.
//

import Cocoa

extension KelasTableManager: NSTextFieldDelegate {
    /**
     Menangani penyelesaian pengeditan teks dalam sel tabel

     - Parameter obj: Notifikasi yang berisi informasi pengeditan
     */
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        guard let editedCell = textField.superview as? NSTableCellView,
              let activeTable = activeTableView,
              let tableType = tableType(activeTable)
        else { return }

        let row = activeTable.row(for: editedCell)
        let column = activeTable.column(for: editedCell)

        guard row >= 0,
              let columnIdentifier = KelasColumn(rawValue: activeTable.tableColumns[column].identifier.rawValue)
        else { return }

        let newValue = textField.stringValue
        let oldValue = viewModel.getOldValueForColumn(tableType: tableType, rowIndex: row, columnIdentifier: columnIdentifier, modelArray: viewModel.kelasModelForTable(tableType, siswaID: siswaID))

        guard newValue != oldValue else { return }

        // Dapatkan nilaiID dari model data
        let nilaiId = viewModel.kelasModelForTable(tableType, siswaID: siswaID)[row].nilaiID
        // Simpan originalModel untuk undo dengan nilaiId
        let originalModel = OriginalData(
            nilaiId: nilaiId, tableType: tableType,
            columnIdentifier: columnIdentifier,
            oldValue: oldValue,
            newValue: newValue,
            tableView: activeTable
        )

        let numericValue = Int(newValue) ?? 0
        textField.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor

        let model = viewModel.kelasModelForTable(tableType, siswaID: siswaID)
        let siswaID = model[row].siswaID

        viewModel.updateModelAndDatabase(tableType: tableType, columnIdentifier: columnIdentifier, rowIndex: row, newValue: newValue, modelArray: model, nilaiId: nilaiId, siswaID: siswaID)

        NilaiKelasNotif.sendNotif(tableType: tableType, columnIdentifier: columnIdentifier, idNilai: nilaiId, dataBaru: newValue, idSiswa: siswaID)

        selectionDelegate?.didEndEditing?(textField, originalModel: originalModel)
    }

    /// Fungsi ini menangani pembaruan kolom nilai pada tabel kelas
    /// dan juga memperbarui data di model dan database.
    /// - Parameter originalModel: Model data asli yang berisi informasi tentang perubahan yang dilakukan.
    /// - Parameter newValue: Nilai baru yang akan digunakan
    func updateNilai(_ originalModel: OriginalData, newValue: String) {
        // Cari indeks kelasModels yang memiliki id yang cocok dengan originalModel
        guard let tableType = tableType(originalModel.tableView),
              let rowIndexToUpdate = viewModel.kelasModelForTable(tableType).firstIndex(where: { $0.nilaiID == originalModel.nilaiId }),
              let columnIndex = originalModel.tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == originalModel.columnIdentifier.rawValue }),
              columnIndex >= 0, columnIndex < originalModel.tableView.tableColumns.count else { return }

        let siswaID = viewModel.kelasModelForTable(originalModel.tableType)[rowIndexToUpdate].siswaID

        // Lakukan pembaruan model dan database dengan nilai lama
        viewModel.updateModelAndDatabase(tableType: originalModel.tableType, columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, modelArray: viewModel.kelasModelForTable(tableType), nilaiId: originalModel.nilaiId, siswaID: siswaID)

        originalModel.tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
        originalModel.tableView.scrollRowToVisible(rowIndexToUpdate)
        selectionDelegate?.didEndUpdate?()
    }
}
