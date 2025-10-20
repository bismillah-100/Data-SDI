//
//  GuruCellView.swift
//  Data SDI
//
//  Created by MacBook on 20/10/25.
//

import Cocoa

/// NSTableCellView yang digunakan untuk child item di NSOutlineView
/// untuk cellView UI ``TugasMapelVC`` dan ``Struktur``.
class GuruCellView: NSTableCellView {

    /// Mengatur constraint.
    /// Leading: 0. Trailing: -5. CenterY: CenterY ke superView.
    override func awakeFromNib() {
        super.awakeFromNib()
        textField?.font = NSFont.systemFont(ofSize: 13)
        textField?.translatesAutoresizingMaskIntoConstraints = false

        if let tf = textField {
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
                tf.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
                tf.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }
}

/// NSTableCellView yang digunakan untuk parent item di NSOutlineView
/// untuk cellView UI ``TugasMapelVC`` dan ``Struktur``.
class MapelCellView: NSTableCellView {

    /// Mengatur constraint.
    /// Leading: 5. Trailing: -20. CenterY: CenterY ke superView.
    override func awakeFromNib() {
        super.awakeFromNib()
        textField?.font = NSFont.boldSystemFont(ofSize: 13)
        textField?.translatesAutoresizingMaskIntoConstraints = false

        if let tf = textField {
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
                tf.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                tf.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }
}
