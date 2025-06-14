//
//  CustomTableCellView.swift
//  Pods
//
//  Created by Bismillah on 26/12/23.
//

import Cocoa

/// Class untuk menampilkan header tabel yang disesuaikan dengan efek visual dan status pengurutan.
class CustomTableHeaderView: NSTableHeaderView {
    /// Kelas khusus untuk layout dan tampilan teks header.
    var customHeaderCell: NSTableHeaderCell?
    /// Property untuk menentukan apakah header sedang dalam keadaan terurut.
    var isSorted: Bool = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        customHeaderCell = MyHeaderCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Gambar custom header cell jika ada
        if let headerCell = customHeaderCell as? MyHeaderCell,
           let tableView,
           let _ = tableView.tableColumns.first
        {
            headerCell.isSorted = isSorted
            let headerRect = self.headerRect(ofColumn: 0)
            let modFrame = NSRect(
                x: headerRect.origin.x + 6,
                y: headerRect.origin.y,
                width: headerRect.width - 6,
                height: headerRect.height
            )
            headerCell.draw(withFrame: modFrame, in: self)
        }
    }
}

/// Class untuk menampilkan cell kustom pada baris tabel dengan tambahan ``ExpandingDatePicker``.
/// Digunakan untuk menampilkan tanggal dengan opsi ekspansi pada tabel.
class CustomTableCellView: NSTableCellView {
    /// Inisialisasi dari ExpandingDatePicker yang digunakan untuk memilih tanggal.
    lazy var datePicker: ExpandingDatePicker = {
        let picker = ExpandingDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerElements = .yearMonthDay
        picker.datePickerMode = .single
        picker.drawsBackground = false
        picker.isBordered = false
        picker.sizeToFit()
        picker.textColor = .clear
        addSubview(picker)
        // Set target dan action untuk DatePicker
        picker.target = self
        return picker
    }()

    override func prepareForReuse() {
        super.prepareForReuse()
        datePicker.dateValue = Date()
        textField?.stringValue = ""
    }

    deinit {
        datePicker.removeFromSuperview()
    }
}

/// Class untuk menampilkan cell grup pada tabel dengan judul dan opsi font tebal.
class GroupTableCellView: NSTableCellView {
    /// Property untuk menentukan apakah cell ini adalah tampilan grup.
    lazy var isGroupView: Bool = false
    /// Property untuk menyimpan judul dari grup.
    var sectionTitle: String?
    /// Property untuk menyimpan indeks dari grup.
    var sectionIndex: Int!
    /// Property untuk menentukan apakah font pada judul grup harus tebal.
    var isBoldFont: Bool = false
    override func draw(_ dirtyRect: NSRect) {
        if isGroupView {
            if let title = sectionTitle {
                textField?.stringValue = title
                if isBoldFont {
                    textField?.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                } else {
                    textField?.font = NSFont.systemFont(ofSize: 11)
                }
                textField?.textColor = NSColor.controlTextColor
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textField?.stringValue = ""
    }
}

/// Class kustom untuk menampilkan baris tabel dengan gaya grup.
/// Digunakan untuk menampilkan baris grup dengan efek visual khusus.
class CustomRowView: NSTableRowView {
    var hasDrawn = false

    override func draw(_ dirtyRect: NSRect) {
        if isGroupRowStyle {
            if hasDrawn { return }
            hasDrawn = true
        } else {
            super.draw(dirtyRect)
        }
    }
}
