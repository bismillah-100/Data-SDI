//
//  KelasTable.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Cocoa

extension KelasVC: TableSelectionDelegate {
    func didSelectRow(_: NSTableView, at _: Int) {
        NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
    }

    func didSelectTabView(_: NSTabViewItem, at _: Int) {
        guard let table = tableViewManager.activeTableView,
              let tableType = tableType(table) else { return }
        activeTableType = tableType
        if isDataLoaded[table] == nil || !(isDataLoaded[table] ?? false) {
            // Load data for the table view
            loadTableData(tableView: table, forceLoad: true)
            isDataLoaded[table] = true
            table.reloadData()
        }

        if let window = view.window {
            window.title = tableType.stringValue
        }

        updateSearchFieldPlaceholder()

        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self else { return }
            NSApp.sendAction(#selector(KelasVC.updateMenuItem(_:)), to: nil, from: self)
            switchTextView()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let window = view.window else { return }
            window.makeFirstResponder(table)

            if let keyPath = tableSearchMapping[table] {
                let searchText = self[keyPath: keyPath]
                ReusableFunc.updateSearchFieldToolbar(window, text: searchText)
            }

            tableViewManager.performPendingReloads()
        }
    }
}
