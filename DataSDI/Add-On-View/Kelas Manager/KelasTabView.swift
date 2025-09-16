//
//  KelasTabView.swift
//  Data SDI
//
//  Created by MacBook on 06/09/25.
//

import Cocoa

extension KelasTableManager: NSTabViewDelegate {
    /// Mengembalikan indeks tab yang sedang dipilih
    func selectedTabViewItem() -> Int? {
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            return tabView.indexOfTabViewItem(selectedTabViewItem)
        }
        return nil
    }

    /// Memilih tab pada indeks yang ditentukan
    func selectTabViewItem(at index: Int) {
        guard let selectedItem = tabView.selectedTabViewItem,
              tabView.indexOfTabViewItem(selectedItem) != index
        else { return }
        tabView.selectTabViewItem(at: index)
    }

    /// Memilih tampilan tab secara terprogram
    func selectTabView() {
        if let selectedTabViewItem = tabView.selectedTabViewItem {
            tabView(tabView, didSelect: selectedTabViewItem)
        }
    }

    /**
     Menangani perubahan pemilihan tab

     - Parameter:
       - tabView: Tampilan tab
       - tabViewItem: Item tampilan tab yang baru dipilih
     */
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem,
              let scrollView = tabViewItem.view?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
              let table = scrollView.documentView as? NSTableView
        else { return }

        activeTableView = table
        if let tableType = tableType(table) {
            activeTableType = tableType
        }
        selectionDelegate?.didSelectTabView?(tabViewItem, at: tabView.indexOfTabViewItem(tabViewItem))
    }
}
