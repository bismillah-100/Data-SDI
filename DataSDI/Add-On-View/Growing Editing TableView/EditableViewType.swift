//
//  EditableViewType.swift
//  Data SDI
//
//  Created by MacBook on 12/06/25.
//

import AppKit

/// Protokol untuk menyesuaikan instans singleton ``AppDelegate/editorManager``
/// ke `NSTableView` yang sedang aktif menerima input.
protocol EditableViewType: AnyObject {
    /// Properti yang akan digunakan protokol
    var editAction: ((Int, Int) -> Void)? { get set }
}

extension EditableTableView: EditableViewType {}
extension EditableOutlineView: EditableViewType {}
