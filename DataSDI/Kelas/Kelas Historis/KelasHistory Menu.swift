//
//  KelasHistory MENU.swift
//  Data SDI
//
//  Created by MacBook on 30/07/25.
//

import Cocoa

extension KelasHistoryVC: NSMenuDelegate {
    /// Membuat menu konteks untuk tabel kelas historis.
    ///
    /// Fungsi ini membuat sebuah `NSMenu` dengan tiga item menu:
    /// - Item gambar (tersembunyi) untuk menampilkan foto
    /// - Tombol muat ulang untuk merefresh data
    /// - Tombol salin data untuk menyalin data yang dipilih
    ///
    /// - Returns: `NSMenu` yang telah dikonfigurasi dengan item-item menu yang diperlukan
    func buatMenu() -> NSMenu {
        let menu: NSMenu = .init()
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        image.image = ReusableFunc.largeActionImage
        image.isHidden = true
        menu.addItem(image)

        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        let salin = NSMenuItem(title: "Salin Data", action: #selector(salin(_:)), keyEquivalent: "")
        salin.representedObject = tableView.selectedRowIndexes
        salin.target = self
        salin.identifier = NSUserInterfaceItemIdentifier("salin")
        menu.addItem(salin)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu === tableMenu
            ? updateTableMenu(tableMenu)
            : updateTableMenu(toolbarMenu, toolbar: true)
    }

    /// Memperbarui menu konteks tabel berdasarkan status pemilihan baris.
    ///
    /// Fungsi ini mengatur tampilan dan judul menu salin berdasarkan baris yang dipilih pada tableView.
    ///
    /// - Parameters:
    ///   - menu: Menu NSMenu yang akan diperbarui
    ///   - toolbar: Boolean yang menentukan apakah menu ini untuk toolbar. Nilai default adalah false
    ///
    /// Menu salin akan:
    /// - Disembunyikan jika tidak ada baris yang dipilih (untuk toolbar) atau tidak ada baris yang diklik
    /// - Menampilkan nama siswa jika hanya 1 baris yang dipilih
    /// - Menampilkan jumlah data yang dipilih jika lebih dari 1 baris dipilih
    /// - Menampilkan nama siswa dari baris yang diklik jika baris tersebut tidak termasuk dalam baris yang dipilih
    private func updateTableMenu(_ menu: NSMenu, toolbar: Bool = false) {
        let salinMenu = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
        salinMenu?.representedObject = tableView.selectedRowIndexes

        let numberOfSelectedRows = tableView.numberOfSelectedRows
        let selectedRow = tableView.selectedRow
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow

        salinMenu?.isHidden = toolbar
            ? tableView.numberOfSelectedRows < 1
            : tableView.clickedRow == -1

        guard let kelasData = viewModel.arsipKelasData[activeTableType] else { return }

        var salinTitle = ""

        if clickedRow != -1, !selectedRows.contains(clickedRow) {
            salinTitle = "Salin〝\(kelasData[clickedRow].namasiswa)〞"
        } else if numberOfSelectedRows > 0 {
            if numberOfSelectedRows == 1 {
                salinTitle = "Salin〝\(kelasData[selectedRow].namasiswa)〞"
            } else {
                salinTitle = "Salin〝\(numberOfSelectedRows) Data〞"
            }
        }
        salinMenu?.title = salinTitle
    }

    /// Menangani aksi penyalinan data dari TableView ke clipboard.
    ///
    /// Fungsi ini dipanggil ketika pengguna memilih opsi "Salin" dari menu konteks.
    /// Fungsi akan menyalin konten dari baris-baris yang dipilih di TableView ke clipboard sistem.
    ///
    /// - Parameter sender: Item menu yang memicu aksi penyalinan
    ///
    /// Alur kerja:
    /// 1. Mendapatkan indeks baris yang saat ini dipilih di TableView
    /// 2. Memeriksa apakah sender memiliki representedObject berupa IndexSet
    /// 3. Jika tidak ada representedObject, menyalin semua baris yang dipilih
    /// 4. Jika ada representedObject, menentukan baris yang relevan berdasarkan konteks klik dan seleksi
    /// 5. Melakukan operasi penyalinan untuk baris-baris yang ditentukan
    @objc
    func salin(_ sender: NSMenuItem) {
        // Mendapatkan semua indeks baris yang saat ini dipilih di `outlineView`.
        let selectedRows = tableView.selectedRowIndexes

        // Mencoba mendapatkan `IndexSet` dari `sender.representedObject`.
        // Ini biasanya digunakan ketika item menu secara eksplisit membawa informasi tentang baris yang relevan.
        guard let representedRows = sender.representedObject as? IndexSet else {
            // Jika `representedObject` bukan `IndexSet` (atau `nil`),
            // asumsikan bahwa operasi penyalinan berlaku untuk semua baris yang dipilih.
            ReusableFunc.salinBaris(selectedRows, from: tableView)
            return // Hentikan eksekusi fungsi di sini.
        }

        // Mendapatkan indeks baris yang terakhir diklik di `outlineView`.
        let clickedRow = tableView.clickedRow

        let rowsToProcess = ReusableFunc.determineRelevantRows(
            clickedRow: clickedRow,
            selectedRows: selectedRows,
            representedRows: representedRows
        )
        ReusableFunc.salinBaris(rowsToProcess, from: tableView)
    }
}
