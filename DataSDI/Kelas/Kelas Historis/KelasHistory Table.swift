//
//  KelasHistory Table.swift
//  Data SDI
//
//  Created by MacBook on 30/07/25.
//

import Cocoa

extension KelasHistoryVC: TableSelectionDelegate {
    func didSelectRow(_: NSTableView, at _: Int) {
        NSApp.sendAction(#selector(KelasHistoryVC.updateMenuItem), to: nil, from: self)
    }
}
