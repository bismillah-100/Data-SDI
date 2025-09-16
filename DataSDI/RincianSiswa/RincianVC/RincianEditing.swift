//
//  RincianEditing.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

extension DetailSiswaController {
    func didEndEditing(_: NSTextField, originalModel: OriginalData) {
        // Daftarkan aksi undo ke NSUndoManager
        myUndoManager?.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoAction(originalModel: originalModel)
        }
        deleteRedoArray(self)
        updateSemesterTeks()
    }
}
