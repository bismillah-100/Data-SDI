//
//  UpdateModel.swift
//  Data SDI
//
//  Created by MacBook on 09/09/25.
//

import Foundation

/// Enum yang mendefinisikan jenis-jenis pembaruan yang dapat diterapkan ke `NSTableView` di macOS.
/// Enum ini berfungsi sebagai model data ringan dan terstruktur untuk mengomunikasikan perubahan UI dari ``SiswaViewModel`` ke ``SiswaViewController``. Pendekatan ini memastikan pembaruan UI dilakukan secara terorganisir dan efisien.
enum UpdateData {
    /// Merepresentasikan **penyisipan baris baru**.
    /// - Parameters:
    ///   - index: Indeks baris baru yang akan dimasukkan.
    ///   - selectRow: Menentukan apakah baris baru harus dipilih.
    ///   - extendSelection: Menentukan apakah pilihan yang sudah ada harus diperluas.
    case insert(index: Int, selectRow: Bool = false, extendSelection: Bool = false)

    /// Merepresentasikan **pemindahan baris** dari satu lokasi ke lokasi lain.
    /// - Parameters:
    ///   - from: Indeks awal baris yang akan dipindahkan.
    ///   - to: Indeks tujuan baris setelah dipindahkan.
    case move(from: Int, to: Int)

    /// Merepresentasikan **pemuatan ulang (reload) data** untuk satu baris yang sudah ada. Ini berguna saat konten suatu baris berubah, tetapi posisinya tidak.
    /// - Parameters:
    ///   - index: Indeks baris yang akan dimuat ulang.
    ///   - selectRow: Menentukan apakah baris ini harus dipilih setelah dimuat ulang.
    ///   - extendSelection: Menentukan apakah pilihan yang sudah ada harus diperluas.
    case reload(index: Int, selectRow: Bool = false, extendSelection: Bool = false)

    /// Merepresentasikan **penghapusan baris**.
    /// - Parameter index: Indeks baris yang akan dihapus.
    case remove(index: Int)

    /// Merepresentasikan **pemindahan dan pemuatan ulang data** untuk baris dan kolom tertentu. Kasus ini digunakan untuk skenario spesifik di mana hanya data di kolom tertentu yang perlu diperbarui setelah baris dipindahkan.
    /// - Parameters:
    ///   - from: Indeks awal baris.
    ///   - to: Indeks tujuan baris.
    ///   - columnIndex: Indeks kolom yang akan dimuat ulang.
    case moveRowAndReloadColumn(from: Int, to: Int, columnIndex: Int)

    /// Menerapkan pembaruan UI ke table view secara efisien.
    ///
    /// Fungsi ini mengambil array `UpdateData` dan mengiterasi melaluinya untuk
    /// menerapkan pembaruan ke `tableView`. Pembaruan ini, seperti penyisipan,
    /// pemindahan, atau pemuatan ulang, dibungkus dalam `beginUpdates()` dan
    /// `endUpdates()` untuk memastikan animasi berjalan lancar dan performa
    /// tetap optimal. Fungsi ini juga menangani pemilihan baris dan menggulir
    /// baris ke tampilan.
    ///
    /// - Parameters:
    ///   - updates: Array dari ``UpdateData`` yang berisi instruksi untuk memperbarui UI.
    ///   - tableView: `NSTableView` yang diperbarui.
    ///   - deselectAll: Opsi untuk menghapus seleksi baris sebelum pembaruan. Default = true.
    @MainActor
    static func applyUpdates(_ updates: [UpdateData], tableView: NSTableView, deselectAll: Bool = true) {
        guard !updates.isEmpty else { return }

        let columnIndexes = IndexSet(integersIn: 0 ..< tableView.numberOfColumns)
        var scrollRow: Int?

        tableView.beginUpdates()
        if deselectAll { tableView.deselectAll(nil) }
        for update in updates {
            switch update {
            case let .insert(index, selectRow, extendSelection):
                tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
                if selectRow {
                    tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: extendSelection)
                    scrollRow = index
                }
            case let .move(from, to):
                tableView.moveRow(at: from, to: to)
                tableView.reloadData(forRowIndexes: IndexSet(integer: to), columnIndexes: columnIndexes)
                tableView.selectRowIndexes(IndexSet(integer: to), byExtendingSelection: true)
                scrollRow = to
            case let .reload(index, selectRow, extendSelection):
                tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: columnIndexes)
                if selectRow {
                    tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: extendSelection)
                    scrollRow = index
                }
            case let .remove(index):
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: [.slideUp, .effectFade])
            case let .moveRowAndReloadColumn(from, to, columnIndex):
                tableView.moveRow(at: from, to: to)
                tableView.reloadData(forRowIndexes: IndexSet(integer: to), columnIndexes: IndexSet(integer: columnIndex))
                tableView.selectRowIndexes(IndexSet(integer: to), byExtendingSelection: false)
                scrollRow = to
            }
        }
        tableView.endUpdates()
        if let scrollRow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                tableView.scrollRowToVisible(scrollRow)
            }
        }
    }
}
