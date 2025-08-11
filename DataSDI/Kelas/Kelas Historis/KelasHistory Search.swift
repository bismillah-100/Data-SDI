//
//  KelasHistory Search.swift
//  Data SDI
//
//  Created by MacBook on 31/07/25.
//

import Cocoa

extension KelasHistoryVC: NSSearchFieldDelegate {
    /// Memproses input pencarian dari NSSearchField dan melakukan pencarian data kelas historis
    /// dengan penundaan waktu (debouncing) untuk mengoptimalkan performa.
    ///
    /// Fungsi ini akan:
    /// - Membatalkan pencarian sebelumnya yang masih pending
    /// - Memeriksa apakah query pencarian telah berubah
    /// - Membuat tugas pencarian baru dengan delay 0.5 detik
    /// - Memuat data kelas berdasarkan tahun ajaran dan query yang diberikan
    /// - Mengurutkan data dan memperbarui tampilan tabel
    ///
    /// - Parameter sender: NSSearchField yang memicu pencarian
    @objc
    func procSearchField(_ sender: NSSearchField) {
        let query = sender.stringValue

        workItem?.cancel()

        guard searchText != query else { return }

        workItem = DispatchWorkItem {
            Task(priority: .userInitiated) { [weak self, query] in
                guard let self else { return }
                let a = tahunAjaranTextField1.stringValue
                let b = tahunAjaranTextField2.stringValue
                let c = a + "/" + b
                await viewModel.loadArsipKelas(activeTableType, tahunAjaran: c, query: query)
                await sortData()
                await MainActor.run {
                    self.tableView.reloadData()
                    self.searchText = query
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5, execute: workItem!)
    }
}
