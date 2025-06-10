//
//  CustomSearchField.swift
//  Data SDI
//
//  Created by Bismillah on 18/12/24.
//

import Cocoa

/// Class NSSearchField kustom dengan tujuan mereset menu item di Menu Bar ketika menjadi `firstResponder` (View pertama yang menerima input keyboard)
/// dan menjalankan func ``AppDelegate/updateUndoRedoMenu(for:)-9l87t`` ketika kehilangan fokus.
class CustomSearchField: NSSearchField {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func becomeFirstResponder() -> Bool {
        ReusableFunc.resetMenuItems()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if let splitVC = window?.contentViewController as? SplitVC {
            AppDelegate.shared.updateUndoRedoMenu(for: splitVC)
        }
        return super.resignFirstResponder()
    }
}
