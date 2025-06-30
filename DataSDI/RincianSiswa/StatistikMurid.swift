//
//  StatistikMurid.swift
//  Data Manager
//
//  Created by Bismillah on 09/11/23.
//

import Cocoa
import SwiftUI

/// Statistik siswa dalam tampilan Grafik
class StatistikMurid: NSViewController {
    /// ID unik siswa yang ditampilkan
    var siswaID: Int64?
    /// TextField nama siswa.
    @IBOutlet weak var namaMurid: NSTextField!
    /// View yang digunakan untuk memuat tampilan SwiftUI.
    @IBOutlet var chartView: NSView!

    /// View-Model yang mengatur data sebelum ditampilkan
    private let viewModel = ChartKelasViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { [weak self] in
            guard let self, let siswaID else { return }
            await viewModel.loadSiswaData(siswaID: siswaID)
            // 1. Process the raw data into our clean data model
            await viewModel.processChartData(siswaID)
            await MainActor.run { [weak self] in
                guard let self else { return }
                // 2. Setup the SwiftUI chart view and host it
                setupChartView()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        namaMurid = nil
        chartView = nil
        siswaID = nil
    }
    
    /// Mengatur tampilan grafik pada `chartView`.
    /// 
    /// Fungsi ini membuat dan menambahkan dua subview ke dalam container `chartView`, yaitu:
    /// - `namaMurid`: Label nama murid yang diletakkan di bagian atas container.
    /// - `hostingView`: View yang menampilkan grafik berbasis SwiftUI (`StudentCombinedChartView`) dengan data dari `viewModel.studentData`.
    /// 
    /// Fungsi ini juga mengatur constraint secara programatik agar kedua subview tersebut tersusun secara vertikal dan memenuhi lebar container.
    /// Jika ``chartView`` tidak tersedia, fungsi akan langsung keluar.
    private func setupChartView() {
        guard let container = chartView else { return }
        // Create an instance of our SwiftUI Chart View, passing in the data
        let swiftUIChartView = StudentCombinedChartView(data: viewModel.studentData, displayPoint: false)

        // Create the hosting view that will contain our SwiftUI view
        let hostingView = NSHostingView(rootView: swiftUIChartView)

        // Important: Disable autoresizing mask translation for programmatic constraints
        namaMurid.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // Add the hosting view as a subview to our container
        container.addSubview(namaMurid)
        container.addSubview(hostingView)

        // Create and activate constraints to make the hosting view fill the container
        NSLayoutConstraint.activate([
            namaMurid.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            namaMurid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            namaMurid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            namaMurid.widthAnchor.constraint(lessThanOrEqualToConstant: 388),
            namaMurid.heightAnchor.constraint(equalToConstant: 24),
            hostingView.topAnchor.constraint(equalTo: namaMurid.bottomAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}
