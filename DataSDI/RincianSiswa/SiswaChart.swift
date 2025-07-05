//
//  StatistikMurid.swift
//  Data Manager
//
//  Created by Bismillah on 09/11/23.
//

import Cocoa
import SwiftUI

/// Statistik siswa dalam tampilan Grafik
class SiswaChart: NSViewController {
    /// ID unik siswa yang ditampilkan
    var siswaID: Int64?
    
    /// TextField nama siswa.
    var namaSiswa: NSTextField!

    /// View-Model yang mengatur data sebelum ditampilkan
    private let viewModel = ChartKelasViewModel.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 388, height: 339))
        namaSiswa = NSTextField()
        namaSiswa.drawsBackground = false
        namaSiswa.isBordered = false
        namaSiswa.isEditable = false
        namaSiswa.usesSingleLineMode = true
        namaSiswa.lineBreakMode = .byClipping
        namaSiswa.font = NSFont.systemFont(ofSize: 22)
    }
    
    init(siswaID: Int64? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.siswaID = siswaID
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Task(priority: .userInitiated) { [weak self] in
            guard let self, let siswaID,
                  let data = KelasViewModel.shared.siswaKelasData[siswaID]
            else { return }
            // 1. Process the raw data into our clean data model
            await viewModel.processChartData(data)
            await MainActor.run { [weak self] in
                guard let self else { return }
                // 2. Setup the SwiftUI chart view and host it
                setupChartView()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        namaSiswa = nil
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
        // Create an instance of our SwiftUI Chart View, passing in the data
        let swiftUIChartView = StudentCombinedChartView(data: viewModel.studentData, displayPoint: false)

        // Create the hosting view that will contain our SwiftUI view
        let hostingView = NSHostingView(rootView: swiftUIChartView)

        // Important: Disable autoresizing mask translation for programmatic constraints
        namaSiswa.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // Add the hosting view as a subview to our container
        view.addSubview(namaSiswa)
        view.addSubview(hostingView)

        // Create and activate constraints to make the hosting view fill the container
        NSLayoutConstraint.activate([
            namaSiswa.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            namaSiswa.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            namaSiswa.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            namaSiswa.widthAnchor.constraint(lessThanOrEqualToConstant: 388),
            namaSiswa.heightAnchor.constraint(equalToConstant: 24),
            hostingView.topAnchor.constraint(equalTo: namaSiswa.bottomAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    deinit {
#if DEBUG
        print("deinit SiswaChart")
#endif
        view.subviews.removeAll()
    }
}
