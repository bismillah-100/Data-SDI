//
//  StatistikViewController.swift
//  Data Manager
//
//  Created by Bismillah on 07/11/23.
//

import Cocoa

/// Untuk memuat view StatistikKelas dan yang ditampilkan di popover
class StatistikViewController: NSViewController {
    /// Tahun ajaran. default: nil.
    var tahunAjaran: String?

    override func viewDidAppear() {
        super.viewDidAppear()

        guard let statistikView = view as? StatistikKelas else { return }
        statistikView.arsipKelas = true
        statistikView.tahunAjaran = tahunAjaran

        Task(priority: .userInitiated) { [weak self, weak statistikView] in
            guard let self, let statistikView else { return }
            await statistikView.prepareChartData()

            DispatchQueue.main.asyncAfter(deadline: .now()) {
                if let tahunAjaran = self.tahunAjaran {
                    statistikView.title.stringValue = statistikView.title.stringValue + "・" + tahunAjaran
                }
            }
        }
    }

    deinit {
        for view in view.subviews {
            view.removeFromSuperview()
        }

        view.removeFromSuperview()

        #if DEBUG
            print("deinit statistikViewController")
        #endif
    }
}
