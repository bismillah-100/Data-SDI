//
//  CustomTableCellView.swift
//  Pods
//
//  Created by Bismillah on 26/12/23.
//

import Cocoa

class CustomTableHeaderView: NSTableHeaderView {
    var customHeaderCell: NSTableHeaderCell?
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
           let tableView = self.tableView,
           let _ = tableView.tableColumns.first {
            headerCell.isSorted = self.isSorted
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
class CustomTableCellView: NSTableCellView {
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
class GroupTableCellView: NSTableCellView {
    lazy var isGroupView: Bool = false
    var sectionTitle: String?
    var sectionIndex: Int!
    var isBoldFont: Bool = false
    override func draw(_ dirtyRect: NSRect) {
        if isGroupView {
            if let title = sectionTitle {
                self.textField?.stringValue = title
                if isBoldFont {
                    self.textField?.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                } else {
                    self.textField?.font = NSFont.systemFont(ofSize: 11)
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

class CustomRowView: NSTableRowView {
    var hasDrawn = false
    
    override func draw(_ dirtyRect: NSRect) {
        if isGroupRowStyle {
            if hasDrawn {return}
            hasDrawn = true
        } else {
            super.draw(dirtyRect)
        }
    }
}
