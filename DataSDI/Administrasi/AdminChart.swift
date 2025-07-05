//
//  AdminChart.swift
//  bismillah
//
//  Created by Bismillah on 28/11/24.
//

import Cocoa
import SwiftUI

/// AdminChart adalah sebuah class yang mengelola data Administrasi untuk direpresentasikan dalam grafis line yang disediakan oleh DGCharts.
class AdminChart: NSViewController {
    /// LineChartView IBOutlet
    @IBOutlet weak var barChart: NSView!

    /// Indicator yang berputar saat data dimuat lebih lama.
    @IBOutlet weak var indicator: NSProgressIndicator!

    /// Horizontal StackView untuk filtering data.
    @IBOutlet weak var hStackFilter: NSStackView!

    /// Horizontal StackView untuk tombol.
    @IBOutlet weak var hStackAction: NSStackView!
    /// Garis horizontal antara bar chart dan topView yang memuat tombol.
    @IBOutlet weak var hLine: NSBox!

    /// Menyimpan referensi tahun yang tersedia di data administrasi untuk ditampilkan di ``DataSDI/AdminChart/tahunPopUp``
    var tahunList: [String] = []
    
    /// ViewModel yang mengelola data untuk ditampilkan
    let viewModel = AdminChartViewModel.shared

    /// Referensi jenis transaksi yang dipilih dari ``DataSDI/AdminChart/jenisPopUp`` untuk digunakan filtering data.
    var filterJenis = "Pemasukan" {
        didSet {
            viewModel.filterJenis = filterJenis
            if dataPerTahun.state == .on {
                viewModel.prepareYearlyData(filterJenis)
            } else {
                viewModel.prepareMonthlyData(filterJenis, tahun: tahun)
            }
        }
    }

    /// Garis vertikal di bagian kiri tombol muat ulang.
    @IBOutlet weak var verticalLine: NSBox!

    /// VisualEffect.
    @IBOutlet weak var ve: NSVisualEffectView!

    /// PopUp jenis.
    @IBOutlet weak var jenisPopUp: NSPopUpButton!
    /// PopUp tahun.
    @IBOutlet weak var tahunPopUp: NSPopUpButton!
    /// Tombol buka di jendela baru.
    @IBOutlet weak var bukaJendela: NSButton!

    /// Menyimpan tahun yang dipilih ke UserDefatults untuk menentukan pilihan saat dibuka kembali.
    var tahun: Int? = UserDefaults.standard.object(forKey: "adminChartFilterTahun") as? Int {
        didSet {
            if let pilihanTahun = tahun {
                UserDefaults.standard.setValue(pilihanTahun, forKey: "adminChartFilterTahun")
            } else {
                UserDefaults.standard.removeObject(forKey: "adminChartFilterTahun")
            }
            viewModel.prepareMonthlyData(filterJenis, tahun: tahun)
        }
    }

    /// Constraint StackView yang diubah ketika view ``DataSDI/AdminChart`` ditampilkan di jendela baru.
    @IBOutlet weak var topConstraint: NSLayoutConstraint!

    /// Menyimpan referensi tahun yang tersedia di data Administrasi.
    var years: [Int] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        ve.material = .popover // Material yang paling transparan
        indicator.isDisplayedWhenStopped = false
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        indicator.startAnimation(nil)
        displayLineChart()
        loadTahunList()
        jenisPopUp.selectItem(at: 1)
        jenisPopUp.selectedItem?.state = .on
        if bukaJendela.isHidden {
            NotificationCenter.default.addObserver(self, selector: #selector(clearWindowReference(_:)), name: NSWindow.willCloseNotification, object: view.window)
        }
    }
    
    /// Membersihkan referensi ke window `AdminChart` yang telah ditutup.
    ///
    /// Fungsi ini dipanggil ketika window `AdminChart` mengirim notifikasi `NSWindow.willCloseNotification`.
    /// Tujuannya adalah untuk menghapus referensi dari properti `openedAdminChart` di `AppDelegate`,
    /// agar window dapat dibuang dari memori dengan benar dan menghindari kebocoran memori (memory leak).
    ///
    /// - Parameter notification: Notifikasi yang dikirim saat window akan ditutup.
    @objc
    func clearWindowReference(_ notification: Notification) {
        AppDelegate.shared.openedAdminChart = nil
    }


    /// `@IBAction` untu tombol muat ulang yang ada di XIB.
    /// - Parameter sender: Event yang memicu.
    @IBAction func muatUlang(_ sender: Any) {
        indicator.startAnimation(sender)
        loadTahunList()
        if dataPerTahun.state == .on {
            viewModel.prepareYearlyData(filterJenis)
        } else {
            viewModel.prepareMonthlyData(filterJenis, tahun: tahun)
        }
    }

    /// Buka PopOver grafis AdminChart di jendela baru.
    /// - Parameter sender: event yang memicu aksi.
    @IBAction func newWindow(_ sender: Any) {
        dismiss(sender)
        view.window?.performClose(sender)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Memuat storyboard AdminChart
            let storyboard = NSStoryboard(name: "AdminChart", bundle: nil)

            // Mengambil view controller dengan ID AdminChart
            guard let chartData = storyboard.instantiateController(withIdentifier: "AdminChart") as? AdminChart else { return }

            chartData.loadView()
            chartData.bukaJendela.isHidden = true
            chartData.topConstraint.constant += 15
            chartData.verticalLine.isHidden = true
            // Membuat window baru untuk AdminChart
            let window = NSWindow(contentViewController: chartData)
            window.styleMask.insert([.fullSizeContentView, .closable, .resizable, .miniaturizable])
            window.title = "Grafis Saldo"
            window.setFrameAutosaveName("AdminChartGrafisSaldoWindow")
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.makeKeyAndOrderFront(sender)
            AppDelegate.shared.openedAdminChart = window
        }
    }

    /// Memuat dan memperbarui daftar tahun unik yang tersedia dari data yang diambil.
    ///
    /// Fungsi ini mengambil semua data dari `DataManager.shared`, kemudian mengekstrak tahun unik
    /// dari entitas yang memiliki properti `tanggal` yang valid (sebagai `Date`) dan `bulan` bukan 0.
    ///
    /// Jika daftar tahun yang diekstrak berbeda dengan `tahunList` yang sudah ada, fungsi ini akan:
    /// 1. Memperbarui `tahunList` dengan tahun-tahun unik yang diurutkan secara menurun.
    /// 2. Menghapus semua item yang ada dari `tahunPopUp`.
    /// 3. Memasukkan item "Tahun" di indeks 0 dan "Semua Thn." di indeks 1 ke dalam `tahunList`.
    /// 4. Menambahkan semua item dari `tahunList` ke `tahunPopUp`.
    /// 5. Memilih tahun yang sesuai di `tahunPopUp` berdasarkan nilai `tahun` yang ada.
    ///    Jika `tahun` valid dan tidak 0, tahun tersebut akan dipilih. Jika tidak, "Semua Thn." akan dipilih.
    /// 6. Mengatur status item yang dipilih menjadi `.on`.
    ///
    /// - Catatan:
    ///   Fungsi ini mengandalkan `DataManager.shared` untuk menyediakan data.
    ///   `tahunPopUp` sebagai outlet `NSPopUpButton` yang terhubung.
    ///   `tahunList` sebagai properti yang menyimpan daftar tahun dalam bentuk `[String]`.
    ///   `tahun` sebagai properti yang menyimpan tahun yang sedang aktif atau dipilih.
    private func loadTahunList() {
        let data = DataManager.shared.fetchData()
        let uniqueYears: Set<String> = Set(data.compactMap { entity in
            if let tanggalDate = entity.tanggal as Date?, entity.bulan != 0 {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.month, .year], from: tanggalDate)
                if let year = components.year {
                    return String(year)
                }
            }
            return nil
        })

        if tahunList != Array(uniqueYears) {
            tahunList = Array(uniqueYears.sorted(by: >))
            tahunPopUp.removeAllItems()
            tahunList.insert("Tahun", at: 0)
            tahunList.insert("Semua Thn.", at: 1)
            tahunPopUp.addItems(withTitles: tahunList)
            if let tahunSekarang = tahun, tahunSekarang != 0 {
                tahunPopUp.selectItem(withTitle: "\(tahunSekarang)")
            } else {
                tahunPopUp.selectItem(at: 1)
            }
            tahunPopUp.selectedItem?.state = .on
        }
    }

    /// Tombol checkmark untuk menampilkan data tahun per tahun.
    @IBOutlet weak var dataPerTahun: NSButton!

    /// Action dari tombol ``DataSDI/AdminChart/dataPerTahun``
    @IBAction func yearByYear(_ sender: NSButton) {
        tahunPopUp.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true

            if sender.state == .on {
                tahunPopUp.isHidden = true // Sembunyikan popup
                viewModel.prepareYearlyData(filterJenis)
            } else {
                tahunPopUp.isHidden = false // Tampilkan popup
                viewModel.prepareMonthlyData(filterJenis, tahun: tahun)
            }

            // Perbarui layout stack view untuk menganimasikan perubahan
            hStackFilter.layoutSubtreeIfNeeded()
        }, completionHandler: {
            self.tahunPopUp.alphaValue = 1
        })
    }

    /// Action dari tombol ``DataSDI/AdminChart/jenisPopUp``
    @IBAction func filterJenis(_ sender: NSPopUpButton) {
        DispatchQueue.main.async { [weak self] in
            self?.indicator.startAnimation(nil)
        }
        filterJenis = sender.titleOfSelectedItem ?? "Pemasukan"
        if let items = jenisPopUp.menu?.items {
            for item in items {
                item.state = .off
            }
        }
        jenisPopUp.selectedItem?.state = .on
    }

    /// Action dari tombol ``DataSDI/AdminChart/tahunPopUp`
    @IBAction func filterTahun(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem else { return }
        DispatchQueue.main.async { [weak self] in
            self?.indicator.startAnimation(nil)
        }
        if let items = tahunPopUp.menu?.items {
            for item in items {
                item.state = .off
            }
        }
        tahunPopUp.selectedItem?.state = .on
        if title == "Semua Thn." {
            tahun = nil
            return
        }
        tahun = Int(title) ?? nil
    }

    /// Logika untuk memfilter data administrasi sesuai dengan filter yang dipilih dan membungkusnya dalam grafis line.
    private func displayLineChart() {
        guard let container = barChart else { return }
        
        container.subviews.removeAll()
        
        viewModel.prepareMonthlyData(filterJenis, tahun: tahun)
        
        // Create an instance of our SwiftUI Chart View, passing in the data
        let swiftUIChartView = AdminLineChartView(viewModel: viewModel)

        // Create the hosting view that will contain our SwiftUI view
        let hostingView = NSHostingView(rootView: swiftUIChartView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // Add the hosting view as a subview to our container
        container.addSubview(hostingView)

        // Create and activate constraints to make the hosting view fill the container
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        indicator.stopAnimation(self)
        indicator.isHidden = true
    }
    
    /// URL file sementara yang berisi gambar grafis garis.
    var tempDir: URL?
    
    /// Bagikan grafis line chart sebagai gambar.
    @IBAction func shareMenu(_ sender: NSButton) {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let sharingPicker: NSSharingServicePicker
        let fileName: String
        let fileURL: URL
        
        let sessionID = UUID().uuidString
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(sessionID)

        let thn = (tahun != nil) ? " -\(tahun!)" : ""
        fileName = "Administrasi \(filterJenis)\(thn).png"
        
        guard let imageData = ReusableFunc.createImageFromNSView(barChart, scaleFactor: 2.0) else { return }
        guard let tempDir else { print("tempDir error"); return }
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            fileURL = tempDir.appendingPathComponent(fileName)
            
            try imageData.write(to: fileURL)
            
            sharingPicker = NSSharingServicePicker(items: [fileURL])
        } catch {
            ReusableFunc.showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        // Menampilkan menu berbagi
        sharingPicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    deinit {
        #if DEBUG
            print("admin chart deinit")
        #endif
        tahunList.removeAll()
        years.removeAll()
        filterJenis.removeAll()
        tahun = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.removeObserver(self)
        for subViews in view.subviews {
            subViews.removeFromSuperviewWithoutNeedingDisplay()
        }
        view.removeFromSuperviewWithoutNeedingDisplay()
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }
}
