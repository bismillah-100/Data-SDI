//
//  KelasTable Protocol.swift
//  Data SDI
//
//  Created by MacBook on 06/09/25.
//

import Cocoa

/**
 Protokol untuk menangani peristiwa pemilihan tabel
 */
@objc protocol TableSelectionDelegate: AnyObject {
    /// Dipanggil ketika baris dipilih
    /// - Parameters:
    ///   - tableView: `NSTableView` yang berinteraksi.
    ///   - index: index baris di tableView.
    func didSelectRow(_ tableView: NSTableView, at index: Int)

    /// Metode opsional yang dipanggil ketika tab dipilih
    /// - Parameters:
    ///   - tabViewItem: item dari `NSTabView`.
    ///   - index: index item di `NSTabView.
    @objc optional func didSelectTabView(_ tabViewItem: NSTabViewItem, at index: Int)

    /// Metode opsional yang dipanggil ketika pengeditan teks selesai
    /// - Parameters:
    ///   - textField: `NSTextField` yang berinteraksi.
    ///   - originalModel: Salinan data sebelum data diubah.`
    @objc optional func didEndEditing(_ textField: NSTextField, originalModel: OriginalData)

    /// Metode opsional yang dipanggil ketika selesai memperbarui data tabel
    @objc optional func didEndUpdate()
}
