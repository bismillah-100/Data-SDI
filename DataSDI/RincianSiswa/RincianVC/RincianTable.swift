//
//  RincianTable.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//
extension DetailSiswaController: TableSelectionDelegate {
    /// Dipanggil ketika pengguna memilih sebuah baris setelah
    /// menerima delegate dari ``TableSelectionDelegate/didSelectRow(_:at:)``.
    ///
    /// Metode ini mengirim aksi untuk memperbarui item menu yang relevan
    /// berdasarkan baris yang dipilih.
    ///
    /// - Parameters:
    ///   - tableView: Tampilan tabel yang barisnya telah dipilih.
    ///   - row: Indeks baris yang dipilih.
    func didSelectRow(_: NSTableView, at _: Int) {
        NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)
    }

    /// Dipanggil ketika pengguna memilih sebuah tab baru di `NSTabView`.
    /// Dikirim dari ``TableSelectionDelegate/didSelectTabView(_:at:)``
    ///
    /// Metode ini memperbarui `tableView` yang aktif, mengaktifkan tabel yang
    /// dipilih, dan kemudian memperbarui data yang ditampilkan serta item menu.
    ///
    /// - Parameters:
    ///   - tabViewItem: Item tab yang baru saja dipilih.
    ///   - index: Indeks dari item tab yang dipilih.
    func didSelectTabView(_ tabViewItem: NSTabViewItem, at index: Int) {
        // Ambil `NSTableView` yang berada di dalam `tabViewItem` yang dipilih.
        guard let scrollView = tabViewItem.view?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
              let table = scrollView.documentView as? NSTableView
        else { return }

        // Atur `NSTableView` yang baru dipilih sebagai tabel yang aktif.
        tableViewManager.activeTableView = table
        activateSelectedTable()

        // Lakukan pembaruan UI di thread utama secara asinkron.
        DispatchQueue.main.async { [unowned self] in
            populateSemesterPopUpButton()
            NSApp.sendAction(#selector(DetailSiswaController.updateMenuItem(_:)), to: nil, from: self)

            // Dapatkan semester yang dipilih dan perbarui nilai untuk tab yang dipilih.
            let selectedSemester = smstr.titleOfSelectedItem ?? ""
            updateValuesForSelectedTab(tabIndex: index, semesterName: selectedSemester)
        }
    }

    /// Dipanggil setelah pembaruan data selesai.
    /// Dikirim dari ``TableSelectionDelegate/didEndUpdate()``
    ///
    /// Metode ini digunakan untuk memicu pembaruan teks semester setelah
    /// pembaruan data internal selesai.
    func didEndUpdate() {
        updateSemesterTeks()
    }
}
