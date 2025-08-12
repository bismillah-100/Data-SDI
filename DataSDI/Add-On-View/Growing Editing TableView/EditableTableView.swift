//
//  EditableTableView.swift
//  tableViewCellOverlay
//
//  Created by Ays on 15/05/25.
//

import Cocoa

/// `EditableTableView` adalah subclass dari `NSTableView` yang memungkinkan sel untuk diedit dengan cara yang lebih interaktif.
/// Class ini menangani event mouse dan keyboard untuk memulai proses pengeditan sel ketika kondisi tertentu terpenuhi.
class EditableTableView: NSTableView {
    // Callback ke AppDelegate atau controller yang menangani logika edit
    var editAction: ((_ row: Int, _ column: Int) -> Void)?
    var defaultEditColumn: Int?

    // weak var editableDelegate: EditableTableViewDelegate? // Alternatif jika menggunakan delegate

    override func mouseDown(with event: NSEvent) {
        if event.clickCount > 1 {
            super.mouseDown(with: event)
            return
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: localPoint)
        let clickedColumn = column(at: localPoint)

        // Pastikan klik ada di dalam area sel yang valid
        guard clickedRow >= 0, clickedColumn >= 0, selectedRowIndexes.count == 1 else {
            super.mouseDown(with: event) // Klik di luar sel (misalnya, header atau area kosong)
            return
        }

        // Kondisi 1: Apakah baris yang diklik sudah terpilih?
        let isRowCurrentlySelected = selectedRowIndexes.contains(clickedRow)

        if isRowCurrentlySelected {
            // Kondisi 2 & 3: Apakah klik mengenai NSTextField di dalam sel dan ada teksnya?
            if let cellView = view(atColumn: clickedColumn, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
               let textField = cellView.textField
            {
                // Konversi titik klik ke sistem koordinat NSTextField
                let pointInTextField = cellView.convert(localPoint, from: self)
                let text = textField.stringValue
                let font = textField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = text.size(withAttributes: attributes)

                func startEditing() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, let window, window.isKeyWindow else { return }
                        let mouseLocation = window.mouseLocationOutsideOfEventStream
                        let locationInView = convert(mouseLocation, from: nil)
                        let tolerance: CGFloat = 1.0
                        if abs(localPoint.x - locationInView.x) < tolerance,
                           abs(localPoint.y - locationInView.y) < tolerance
                        {
                            editAction?(clickedRow, clickedColumn)
                            return
                        }
                    }
                }
                guard pointInTextField.x <= textSize.width, pointInTextField.y <= textSize.height else {
                    // oleh NSTableView (misalnya, untuk memulai drag atau mengubah seleksi jika tidak perlu).
                    if textField.stringValue.isEmpty {
                        startEditing()
                    } else if textSize.width <= 6,
                              pointInTextField.x <= textSize.width + 6,
                              pointInTextField.y <= textSize.height
                    {
                        // Kondisi ketika lebar textSize terlalu kecil.
                        startEditing()
                    }
                    return
                }
                // Periksa apakah titik klik ada di dalam batas NSTextField
                if textField.bounds.contains(pointInTextField) {
                    // Semua kondisi terpenuhi, panggil aksi edit
                    // Kita tidak memanggil super.mouseDown agar event ini tidak diproses lebih lanjut
                    // oleh NSTableView (misalnya, untuk memulai drag atau mengubah seleksi jika tidak perlu).
                    startEditing()
                    // editableDelegate?.tableView(self, shouldEditRow: clickedRow, column: clickedColumn)
                    // Event sudah ditangani
                }
            }
        }

        // Jika salah satu kondisi tidak terpenuhi (baris tidak terpilih, atau klik di area kosong sel),
        // biarkan NSTableView menangani event secara normal (misalnya, untuk memilih baris).
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Keycode untuk Enter dan Return
        let enterKeyCode: UInt16 = 36 // Return
        let keypadEnterKeyCode: UInt16 = 76 // Numpad Enter

        // Cari window bertipe NSPanel yang floating, aktif, dan memiliki EditingViewController

        if event.keyCode == enterKeyCode || event.keyCode == keypadEnterKeyCode,
           selectedRow >= 0
        {
            // Trigger edit callback
            editAction?(selectedRow, defaultEditColumn ?? 0)
            return // Jangan teruskan event ke super
        } else if event.keyCode == 31 || event.keyCode == 48 {
            editAction?(selectedRow, defaultEditColumn ?? 0)
            return
        }
        // Biarkan key lain diproses seperti biasa
        super.keyDown(with: event)
    }
}

/// `EditableOutlineView` adalah subclass dari `NSOutlineView` yang memungkinkan sel untuk diedit dengan cara yang lebih interaktif.
/// Class ini menangani event mouse dan keyboard untuk memulai proses pengeditan sel ketika kondisi tertentu terpenuhi.
class EditableOutlineView: NSOutlineView {
    // Callback ke AppDelegate atau controller yang menangani logika edit
    var editAction: ((_ row: Int, _ column: Int) -> Void)?
    var defaultEditColumn: Int?

    // weak var editableDelegate: EditableTableViewDelegate? // Alternatif jika menggunakan delegate

    override func mouseDown(with event: NSEvent) {
        if event.clickCount > 1 {
            super.mouseDown(with: event)
            return
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: localPoint)
        let clickedColumn = column(at: localPoint)

        // Pastikan klik ada di dalam area sel yang valid
        guard clickedRow >= 0, clickedColumn >= 0, selectedRowIndexes.count == 1 else {
            super.mouseDown(with: event) // Klik di luar sel (misalnya, header atau area kosong)
            return
        }

        // Kondisi 1: Apakah baris yang diklik sudah terpilih?
        let isRowCurrentlySelected = selectedRowIndexes.contains(clickedRow)

        if isRowCurrentlySelected {
            // Kondisi 2 & 3: Apakah klik mengenai NSTextField di dalam sel dan ada teksnya?
            if let cellView = view(atColumn: clickedColumn, row: clickedRow, makeIfNecessary: false) as? NSTableCellView,
               let textField = cellView.textField
            {
                // Konversi titik klik ke sistem koordinat NSTextField
                let pointInTextField = cellView.convert(localPoint, from: self)
                let text = textField.stringValue
                let font = textField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = text.size(withAttributes: attributes)
                func startEditing() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, let window, window.isKeyWindow else { return }
                        let mouseLocation = window.mouseLocationOutsideOfEventStream
                        let locationInView = convert(mouseLocation, from: nil)
                        let tolerance: CGFloat = 1.0
                        if abs(localPoint.x - locationInView.x) < tolerance,
                           abs(localPoint.y - locationInView.y) < tolerance
                        {
                            editAction?(clickedRow, clickedColumn)
                            return
                        }
                    }
                }
                guard pointInTextField.x <= textSize.width, pointInTextField.y <= textSize.height else {
                    // oleh NSTableView (misalnya, untuk memulai drag atau mengubah seleksi jika tidak perlu).
                    if textField.stringValue.isEmpty {
                        startEditing()
                    }
                    return
                }
                // Periksa apakah titik klik ada di dalam batas NSTextField
                if textField.bounds.contains(pointInTextField) {
                    // Semua kondisi terpenuhi, panggil aksi edit
                    // Kita tidak memanggil super.mouseDown agar event ini tidak diproses lebih lanjut
                    // oleh NSTableView (misalnya, untuk memulai drag atau mengubah seleksi jika tidak perlu).
                    startEditing()
                    // editableDelegate?.tableView(self, shouldEditRow: clickedRow, column: clickedColumn)
                    // Event sudah ditangani
                }
            }
        }

        // Jika salah satu kondisi tidak terpenuhi (baris tidak terpilih, atau klik di area kosong sel),
        // biarkan NSTableView menangani event secara normal (misalnya, untuk memilih baris).
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Keycode untuk Enter dan Return
        let enterKeyCode: UInt16 = 36 // Return
        let keypadEnterKeyCode: UInt16 = 76 // Numpad Enter

        // Cari window bertipe NSPanel yang floating, aktif, dan memiliki EditingViewController
//        if let mainWindow = self.window?.windowController?.window ?? self.window,
//           let panel = mainWindow.childWindows?.first(where: { $0 is NSPanel && $0.isVisible }),
//           let editingVC = panel.contentViewController as? EditingViewController {
//            editingVC.textField.currentEditor()!.keyDown(with: event)
//            return
//        }

        if event.keyCode == enterKeyCode || event.keyCode == keypadEnterKeyCode,
           selectedRow >= 0
        {
            // Trigger edit callback
            editAction?(selectedRow, defaultEditColumn ?? 0)
            return // Jangan teruskan event ke super
        } else if event.keyCode == 31 || event.keyCode == 48 {
            editAction?(selectedRow, defaultEditColumn ?? 0)
            return
        }
        // Biarkan key lain diproses seperti biasa
        super.keyDown(with: event)
    }
}
