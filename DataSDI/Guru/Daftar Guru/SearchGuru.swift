//
//  SearchGuru.swift
//  Data SDI
//
//  Created by MacBook on 16/07/25.
//

import Cocoa

extension GuruVC: NSSearchFieldDelegate {
    /// Fungsi ini dipanggil ketika pengguna memasukkan input pada `NSSearchField`.
    /// Fungsi ini akan membatalkan pekerjaan sebelumnya jika ada, dan memulai pencarian
    /// baru dengan query yang diberikan.
    /// - Parameter sender: `NSSearchField` yang memicu event ini.
    /// - Note: Fungsi ini menggunakan `DispatchWorkItem` untuk menunda eksekusi pencarian
    /// selama 0.5 detik untuk menghindari terlalu banyak permintaan pencarian yang berlebihan
    /// saat pengguna mengetik. Jika pengguna mengetik lagi sebelum 0.5 detik berakhir,
    /// pekerjaan sebelumnya akan dibatalkan.
    @objc
    func procSearchFieldInput(_ sender: NSSearchField) {
        workItem?.cancel()
        let query = sender.stringValue
        let search = DispatchWorkItem {
            Task { [weak self] in
                guard let self else { return }
                await self.viewModel.queryDataGuru(query: query, forceLoad: true)
                await MainActor.run {
                    self.tableView.reloadData()
                }
            }
        }
        workItem = search
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem!)
    }
}
