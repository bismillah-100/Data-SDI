//
//  AdminChart.swift
//  bismillah
//
//  Created by Bismillah on 28/11/24.
//

import Cocoa
import DGCharts

extension Date {
    /// Mendapatkan tahun sekarang.
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}

/// AdminChart adalah sebuah class yang mengelola data Administrasi untuk direpresentasikan dalam grafis line yang disediakan oleh DGCharts.
class AdminChart: NSViewController, ChartViewDelegate {
    /// LineChartView IBOutlet
    @IBOutlet weak var barChart: LineChartView!

    /// Indicator yang berputar saat data dimuat lebih lama.
    @IBOutlet weak var indicator: NSProgressIndicator!

    /// Horizontal StackView untuk filtering data.
    @IBOutlet weak var hStackFilter: NSStackView!

    /// Horizontal StackView untuk tombol.
    @IBOutlet weak var hStackAction: NSStackView!
    /// Garis horizontal antara bar chart dan topView yang memuat tombol.
    @IBOutlet weak var hLine: NSBox!

    /// Background context coredata **Thread yang dikelola CoreData™️**
    let context = DataManager.shared.managedObjectContext

    /// Menyimpan referensi tahun yang tersedia di data administrasi untuk ditampilkan di ``DataSDI/AdminChart/tahunPopUp``
    var tahunList: [String] = []

    /// Referensi jenis transaksi yang dipilih dari ``DataSDI/AdminChart/jenisPopUp`` untuk digunakan filtering data.
    var filterJenis = "Pemasukan" {
        didSet {
            if dataPerTahun.state == .on {
                displayYearlyLineChart()
            } else {
                displayLineChart()
            }
        }
    }

    /// Garis vertikal di bagian kiri tombol muat ulang.
    @IBOutlet weak var verticalLine: NSBox!

    /// VisualEffect.
    @IBOutlet var ve: NSVisualEffectView!

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
            displayLineChart()
        }
    }

    /// Constraint StackView yang diubah ketika view ``DataSDI/AdminChart`` ditampilkan di jendela baru.
    @IBOutlet weak var topConstraint: NSLayoutConstraint!

    /// Menyimpan referensi tahun yang tersedia di data Administrasi.
    var years: [Int] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        ve.material = .popover // Material yang paling transparan
        barChart.delegate = self // Delegate untuk chart
        indicator.isDisplayedWhenStopped = false
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: .perubahanData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: DataManager.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: DataManager.dataDieditNotif, object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    /// Notifikasi yang diterima ketika ada perubahan data Administrasi.
    ///
    /// Membersihkan *cache* data administrasi tahun per tahun yang sebelumnya dibuat untuk meningkatkan waktu pemuatan.
    @objc func deleteCache(_ notification: Notification) {
        guard !yearlyTotalSurplusCache.isEmpty else { return }
        deleteCache()
    }

    /// Fungsi untuk menghapus cache data administrasi tahun per tahun yang sebelumnya dibuat untuk meningkatkan waktu pemuatan.
    func deleteCache() {
        yearlyTotalSurplusCache.removeAll()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        displayLineChart()
        loadTahunList()
        jenisPopUp.selectItem(at: 1)
        jenisPopUp.selectedItem?.state = .on
    }

    /// `@IBAction` untu tombol muat ulang yang ada di XIB.
    /// - Parameter sender: Event yang memicu.
    @IBAction func muatUlang(_ sender: Any) {
        indicator.startAnimation(sender)
        loadTahunList()
        if dataPerTahun.state == .on {
            displayYearlyLineChart()
        } else {
            displayLineChart()
        }
    }

    /// Buka PopOver grafis AdminChart di jendela baru.
    /// - Parameter sender: event yang memicu aksi.
    @IBAction func newWindow(_ sender: Any) {
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
        window.title = "Grafis Saldo"
        window.setFrameAutosaveName("AdminChartGrafisSaldoWindow")
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.isRestorable = false
        window.styleMask.insert(.fullSizeContentView)
        window.makeKeyAndOrderFront(sender)
        view.window?.close()
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
                displayYearlyLineChart()
            } else {
                tahunPopUp.isHidden = false // Tampilkan popup
                displayLineChart()
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

    /// Fungsi yang digunakan untuk mendapatkan data administrasi tahun per tahun.
    private func displayYearlyLineChart() {
        DispatchQueue.global(qos: .background).async { [unowned self] in
            years.removeAll()
            // 1. Menyiapkan data untuk chart berdasarkan filterJenis
            var yearlyData: [Double] = []

            // Menyiapkan permintaan fetch untuk semua jenis data
            let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
            fetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)

            // Ekspresi untuk menghitung total per tahun
            let sumExpression = NSExpression(format: "sum:(jumlah)")
            let sumExpressionDesc = NSExpressionDescription()
            sumExpressionDesc.name = "yearTotal"
            sumExpressionDesc.expression = sumExpression
            sumExpressionDesc.expressionResultType = .doubleAttributeType

            // Filter berdasarkan jenis yang dipilih
            let jenisPredicate = NSPredicate(format: "jenis == %@", filterJenis)
            fetchRequest.predicate = jenisPredicate
            fetchRequest.propertiesToGroupBy = ["tanggal"] // Kelompokkan berdasarkan tahun
            fetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
            fetchRequest.resultType = .dictionaryResultType

            do {
                let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []

                // Proses hasil fetch
                for result in results {
                    guard let tanggal = result["tanggal"] as? Date,
                          let total = result["yearTotal"] as? Double
                    else {
                        continue
                    }

                    let year = Calendar.current.component(.year, from: tanggal)

                    // Gabungkan data per tahun yang sama
                    if let index = years.firstIndex(of: year) {
                        yearlyData[index] += total
                    } else {
                        years.append(year)
                        yearlyData.append(total)
                    }
                }

                // **Tambahkan Proses untuk "Jumlah Saldo"**
                if filterJenis == "Jumlah Saldo" {
                    // Pisahkan data untuk Pemasukan dan Pengeluaran
                    var totalPemasukan: [Double] = []
                    var totalPengeluaran: [Double] = []

                    // Ambil data pemasukan per tahun
                    let pemasukanPredicate = NSPredicate(format: "jenis == %@", "Pemasukan")
                    let pemasukanFetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
                    pemasukanFetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)
                    pemasukanFetchRequest.predicate = pemasukanPredicate
                    pemasukanFetchRequest.propertiesToGroupBy = ["tanggal"]
                    pemasukanFetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
                    pemasukanFetchRequest.resultType = .dictionaryResultType

                    let pemasukanResults = try context.fetch(pemasukanFetchRequest) as? [[String: Any]] ?? []
                    for result in pemasukanResults {
                        guard let tanggal = result["tanggal"] as? Date,
                              let total = result["yearTotal"] as? Double
                        else {
                            continue
                        }
                        let year = Calendar.current.component(.year, from: tanggal)
                        if let index = years.firstIndex(of: year) {
                            totalPemasukan[index] += total
                        } else {
                            years.append(year)
                            totalPemasukan.append(total)
                            totalPengeluaran.append(0) // Pastikan pengeluaran ada
                        }
                    }

                    // Ambil data pengeluaran per tahun
                    let pengeluaranPredicate = NSPredicate(format: "jenis == %@", "Pengeluaran")
                    let pengeluaranFetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
                    pengeluaranFetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)
                    pengeluaranFetchRequest.predicate = pengeluaranPredicate
                    pengeluaranFetchRequest.propertiesToGroupBy = ["tanggal"]
                    pengeluaranFetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
                    pengeluaranFetchRequest.resultType = .dictionaryResultType

                    let pengeluaranResults = try context.fetch(pengeluaranFetchRequest) as? [[String: Any]] ?? []
                    for result in pengeluaranResults {
                        guard let tanggal = result["tanggal"] as? Date,
                              let total = result["yearTotal"] as? Double
                        else {
                            continue
                        }
                        let year = Calendar.current.component(.year, from: tanggal)
                        if let index = years.firstIndex(of: year) {
                            totalPengeluaran[index] += total
                        } else {
                            years.append(year)
                            totalPengeluaran.append(total)
                            totalPemasukan.append(0) // Pastikan pemasukan ada
                        }
                    }

                    // Hitung surplus saldo (Pemasukan - Pengeluaran) per tahun
                    var surplusData: [Double] = []
                    for i in 0 ..< years.count {
                        let surplus = totalPemasukan[i] - totalPengeluaran[i]
                        surplusData.append(surplus)
                    }

                    // **Agregasi surplusData untuk mendapatkan saldo kumulatif** (jumlah saldo)
                    var cumulativeSaldo: [Double] = []
                    var currentSaldo: Double = 0
                    for surplus in surplusData {
                        currentSaldo += surplus
                        cumulativeSaldo.append(currentSaldo)
                    }

                    // Urutkan berdasarkan tahun (Ascending)
                    let sortedData = zip(years, cumulativeSaldo)
                        .sorted { $0.0 < $1.0 }

                    years = sortedData.map(\.0)
                    cumulativeSaldo = sortedData.map(\.1)

                    // Gunakan cumulativeSaldo untuk chart jika filterJenis adalah "Jumlah Saldo"
                    yearlyData = cumulativeSaldo
                }

                // 2. Persiapkan data untuk chart
                var dataEntries: [ChartDataEntry] = []
                for (index, totalAmount) in yearlyData.enumerated() {
                    let entry = ChartDataEntry(x: Double(index), y: totalAmount)
                    dataEntries.append(entry)
                }

                // 3. Buat dataset untuk chart
                let dataSet = LineChartDataSet(entries: dataEntries, label: "\(filterJenis) per Tahun")

                // Konfigurasi warna berdasarkan jenis
                switch filterJenis {
                case "Pemasukan":
                    dataSet.colors = [NSColor.systemGreen]
                    dataSet.fillColor = NSColor.systemGreen
                    dataSet.circleHoleColor = .systemGreen
                case "Pengeluaran":
                    dataSet.colors = [NSColor.systemRed]
                    dataSet.fillColor = NSColor.systemRed
                    dataSet.circleHoleColor = .systemRed
                case "Lainnya":
                    dataSet.colors = [NSColor.systemOrange]
                    dataSet.fillColor = NSColor.systemOrange
                    dataSet.circleHoleColor = .systemOrange
                case "Jumlah Saldo":
                    dataSet.colors = [NSColor.systemBlue]
                    dataSet.fillColor = NSColor.systemBlue
                    dataSet.circleHoleColor = .systemBlue
                default:
                    dataSet.colors = [NSColor.systemBlue]
                }

                // Konfigurasi lebih lanjut untuk dataset
                dataSet.circleColors = [NSUIColor.controlTextColor]
                dataSet.circleRadius = 6
                dataSet.lineWidth = 2.0
//                dataSet.valueColors = [.labelColor]
                dataSet.drawValuesEnabled = false

                // Menambahkan pengisian area pada chart
                dataSet.drawFilledEnabled = true
                dataSet.fillAlpha = 0.5
                dataSet.mode = .cubicBezier
                dataSet.cubicIntensity = 0.2

                DispatchQueue.main.async { [unowned self] in
                    // Atur data untuk Line Chart
                    let lineChartData = LineChartData(dataSet: dataSet)
                    self.barChart.data = lineChartData

                    // Pengaturan sumbu X dan Y
                    self.barChart.xAxis.labelCount = years.count
                    self.barChart.xAxis.granularity = 1.0
                    self.barChart.xAxis.drawGridLinesEnabled = false
                    self.barChart.xAxis.axisMinimum = 0
                    self.barChart.xAxis.axisMaximum = Double(years.count - 1)
                    self.barChart.xAxis.labelPosition = .bottom
                    self.barChart.xAxis.valueFormatter = IndexAxisValueFormatter(values: years.map { String($0) })
                    self.barChart.xAxis.labelRotationAngle = -45.0

                    self.barChart.leftAxis.granularity = 1.0
                    self.barChart.leftAxis.granularityEnabled = true
                    self.barChart.leftAxis.axisMinimum = 0
                    self.barChart.leftAxis.valueFormatter = CustomYAxisValueFormatter()

                    self.barChart.rightAxis.enabled = true
                    self.barChart.rightAxis.granularity = 1.0
                    self.barChart.rightAxis.granularityEnabled = true
                    self.barChart.rightAxis.axisMinimum = 0
                    self.barChart.rightAxis.valueFormatter = CustomYAxisValueFormatter()

                    self.barChart.legend.enabled = true
                    self.barChart.legend.font = NSUIFont.systemFont(ofSize: 12)
                    self.barChart.animate(yAxisDuration: 1.0, easingOption: .easeInOutCubic)
                    self.indicator.stopAnimation(self)
                }
            } catch {}
        }
    }

    /// Menemukan indeks bulan terakhir yang memiliki nilai data lebih besar dari nol.
    ///
    /// Fungsi ini mengiterasi array `data` dari belakang ke depan, mencari indeks pertama
    /// (bulan terakhir) yang memiliki nilai positif. Ini berguna untuk menentukan
    /// sampai bulan mana data valid atau signifikan tersedia.
    ///
    /// - Parameter data: Sebuah array `[Double]` yang merepresentasikan nilai data bulanan.
    ///                   (Indeks 0 = Januari, ..., Indeks 11 = Desember).
    ///
    /// - Returns: Indeks (`Int`) bulan terakhir yang memiliki nilai positif.
    ///            Mengembalikan `0` jika tidak ada bulan dengan nilai positif ditemukan
    ///            atau array `data` kosong.
    private func findLastMonthWithData(_ data: [Double]) -> Int {
        // Cari indeks terakhir yang memiliki nilai lebih dari 0
        for i in stride(from: data.count - 1, through: 0, by: -1) {
            if data[i] > 0 {
                return i
            }
        }
        return 0 // Jika tidak ada data, kembalikan 0
    }

    /// Logika untuk memfilter data administrasi sesuai dengan filter yang dipilih dan membungkusnya dalam grafis line
    private func displayLineChart() {
        Task(priority: .background) { [unowned self] in
            // 1. Fetch data dari Core Data (atau sumber lain)
            var data: [Double] = []
            if filterJenis != "Jumlah Saldo" {
                data = fetchMonthlyData(filterJenis, tahun: tahun)
            } else {
                data = calculateMonthlyCumulativeSurplus(tahun: tahun)
            }

            // Temukan indeks bulan terakhir yang memiliki data
            let lastMonthWithData = findLastMonthWithData(data)

            // Potong data hanya sampai bulan terakhir yang memiliki data
            let truncatedData = Array(data.prefix(lastMonthWithData + 1))

            var dataEntries: [ChartDataEntry] = []
            for (month, totalAmount) in truncatedData.enumerated() {
                let entry = ChartDataEntry(x: Double(month), y: totalAmount)
                dataEntries.append(entry)
            }

            // 3. Buat dataset
            let dataSet = LineChartDataSet(entries: dataEntries, label: "\(filterJenis) per Bulan \(tahun ?? 2024)")
            switch filterJenis {
            case "Pemasukan":
                dataSet.colors = [NSColor.systemGreen] // Warna garis
                dataSet.fillColor = NSColor.systemGreen
                dataSet.circleHoleColor = .systemGreen
            case "Pengeluaran":
                dataSet.colors = [NSColor.systemRed] // Warna garis
                dataSet.fillColor = NSColor.systemRed
                dataSet.circleHoleColor = .systemRed
            case "Lainnya":
                dataSet.colors = [NSColor.systemOrange] // Warna garis
                dataSet.fillColor = NSColor.systemOrange
                dataSet.circleHoleColor = .systemOrange
            default:
                dataSet.colors = [NSColor.systemGreen]
                dataSet.circleHoleColor = .systemGreen
                dataSet.fillColor = NSColor.systemGreen
            }
            dataSet.circleColors = [NSUIColor.controlTextColor]
            dataSet.circleRadius = 6 // set ke 0 untuk tidak menampilkan titik
            dataSet.lineWidth = 2.0 // Ketebalan garis
//            dataSet.valueColors = [.labelColor] // Warna teks nilai
            dataSet.drawValuesEnabled = false

            // 3. Atur formatter
//            dataSet.valueFormatter = CustomValueFormatter()
//            dataSet.valueFont = NSUIFont.systemFont(ofSize: 11) // Ubah ukuran font sesuai kebutuhan

            // 4. Tambahkan pengisian area
            dataSet.drawFilledEnabled = true
            dataSet.fillAlpha = 0.5 // Transparansi area
            dataSet.mode = .cubicBezier // Untuk kurva melengkung
            dataSet.cubicIntensity = 0.2 // Atur intensitas kelengkungan (0.0 - 1.0)

            Task { @MainActor [self] in
                // 5. Atur data untuk Line Chart
                let lineChartData = LineChartData(dataSet: dataSet)
                barChart.data = lineChartData

                // 6. Konfigurasi chart
//                barChart.xAxis.labelCount = 12 // Pastikan menampilkan 12 label
                barChart.xAxis.labelCount = truncatedData.count
                barChart.xAxis.axisMaximum = Double(truncatedData.count - 1)
                barChart.xAxis.granularity = 1.0
                barChart.xAxis.drawGridLinesEnabled = false // Opsional, untuk menghilangkan grid
                barChart.xAxis.axisMinimum = 0 // Mulai dari 0
//                barChart.xAxis.axisMaximum = 11 // Berakhir di 12
                barChart.xAxis.labelPosition = .bottom // Label di bawah sumbu X
                let monthLabels = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
                let truncatedMonthLabels = Array(monthLabels.prefix(truncatedData.count))
                barChart.xAxis.valueFormatter = IndexAxisValueFormatter(values: truncatedMonthLabels)

                barChart.xAxis.labelRotationAngle = -45.0 // Memutar label agar lebih terlihat

                // Atur granularitas
                barChart.leftAxis.granularity = 1.0 // Sesuaikan sesuai kebutuhan
                barChart.leftAxis.granularityEnabled = true

                // Atur sumbu Y
                barChart.leftAxis.axisMinimum = 0 // Pastikan sumbu Y dimulai dari 0
                // 5. Konfigurasi Y-Axis dengan Prefix "Rp."
                barChart.leftAxis.valueFormatter = CustomYAxisValueFormatter()

                barChart.rightAxis.enabled = true // tampilkan suhu kanan
                barChart.rightAxis.granularity = 1.0 // Sesuaikan sesuai kebutuhan
                barChart.rightAxis.granularityEnabled = true

                // Atur sumbu Y
                barChart.rightAxis.axisMinimum = 0 // Pastikan sumbu Y dimulai dari 0
                // 5. Konfigurasi Y-Axis dengan Prefix "Rp."
                barChart.rightAxis.valueFormatter = CustomYAxisValueFormatter()
                // Animasi
                //        barChart.animate(xAxisDuration: 1.0, easingOption: .easeInOutQuad)
                barChart.animate(yAxisDuration: 1.0, easingOption: .easeInOutCubic)
                indicator.stopAnimation(self)
            }
        }
    }

    /// Memuat data bulanan administrasi untuk jenis transaksi dan tahun tertentu.
    /// - Parameters:
    ///   - jenis: Jenis administrasi. Bisa berupa (Pengeluaran, Pemasukan, atau Lainnya)
    ///   - tahun: Tahun yang dipilih yang digunakan untuk memfitlter data bulan pada tahun apa yang akan digunakan. Tahun bisa diabaikan untuk menampilkan data di setiap tahun yang ada.
    /// - Returns: Nilai yang didapatkan dari Database.
    private func fetchMonthlyData(_ jenis: String, tahun: Int?) -> [Double] {
        // Array untuk menyimpan total pemasukan per bulan (1-12)
        var monthlyTotals = Array(repeating: 0.0, count: 12)

        // Ambil data dari Core Data
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()

        // Buat predikat dasar untuk memfilter jenis
        var predicates: [NSPredicate] = [NSPredicate(format: "jenis == %@", jenis)]

        // Jika tahun bukan nil, tambahkan filter tahun
        if let tahun {
            let calendar = Calendar.current
            let startDate = calendar.date(from: DateComponents(year: tahun, month: 1, day: 1))!
            let endDate = calendar.date(from: DateComponents(year: tahun + 1, month: 1, day: 1))!
            let yearPredicate = NSPredicate(format: "tanggal >= %@ AND tanggal < %@", startDate as NSDate, endDate as NSDate)
            predicates.append(yearPredicate)
        }

        // Gabungkan predikat
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let results = try context.fetch(fetchRequest)

            // Filter data dan kelompokkan berdasarkan bulan
            for result in results {
                let bulan = result.bulan
                if bulan >= 1, bulan <= 12 {
                    monthlyTotals[Int(bulan) - 1] += result.jumlah // Tambahkan jumlah pemasukan
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return monthlyTotals
    }

    /// Cari tahun dengan nilai terbesar di data administrasi.
    /// - Returns: Nilai tahun terbesar yang didapatkan.
    private func fetchLatestYear() -> Int {
        // Buat fetch request untuk mendapatkan data dengan tanggal terbaru
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tanggal", ascending: false)]

        do {
            let results = try context.fetch(fetchRequest)
            if let latestEntity = results.first {
                let calendar = Calendar.current
                return calendar.component(.year, from: latestEntity.tanggal ?? Date())
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return Calendar.current.component(.year, from: Date()) // Default ke tahun saat ini jika tidak ada data
    }

    /// Menghitung surplus kumulatif bulanan untuk tahun tertentu atau tahun terbaru yang tersedia.
    ///
    /// Fungsi ini menghitung surplus (pemasukan dikurangi pengeluaran) untuk setiap bulan,
    /// kemudian menghitung saldo kumulatif bulanan dengan mempertimbangkan saldo akhir dari semua
    /// tahun sebelumnya sebagai saldo awal.
    ///
    /// - Parameter tahun: Tahun untuk menghitung surplus kumulatif.
    ///   Jika `nil`, fungsi akan menggunakan tahun terbaru yang tersedia di data.
    ///
    /// - Returns: Sebuah array `[Double]` yang merepresentasikan surplus kumulatif untuk setiap bulan
    ///   (indeks 0 untuk Januari, indeks 11 untuk Desember).
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchLatestYear()` untuk mendapatkan tahun terbaru.
    ///   - Fungsi ini bergantung pada `calculateTotalSurplusUntil(year:)` untuk mendapatkan saldo
    ///     akhir dari tahun-tahun sebelumnya.
    ///   - Fungsi ini bergantung pada `fetchMonthlyData(_:tahun:)` untuk mendapatkan data pemasukan
    ///     dan pengeluaran bulanan.
    private func calculateMonthlyCumulativeSurplus(tahun: Int?) -> [Double] {
        if tahun == nil {
            // Ambil tahun terakhir yang tersedia di data
            let latestYear = fetchLatestYear()
            let saldoAkhirTahunSebelumnya = calculateTotalSurplusUntil(year: latestYear)

            // Ambil data pemasukan dan pengeluaran untuk tahun ini
            let pemasukan = fetchMonthlyData("Pemasukan", tahun: latestYear)
            let pengeluaran = fetchMonthlyData("Pengeluaran", tahun: latestYear)

            // Hitung surplus: pemasukan - pengeluaran
            var surplus: [Double] = []
            for i in 0 ..< 12 {
                surplus.append(pemasukan[i] - pengeluaran[i])
            }

            // Hitung saldo kumulatif dengan saldo awal dari semua tahun sebelumnya
            var cumulativeSurplus: [Double] = []
            var currentBalance = saldoAkhirTahunSebelumnya
            for value in surplus {
                currentBalance += value
                cumulativeSurplus.append(currentBalance)
            }
            return cumulativeSurplus
        }

        // Ambil saldo kumulatif dari semua tahun sebelumnya
        let saldoAkhirTahunSebelumnya = calculateTotalSurplusUntil(year: tahun!)

        // Ambil data pemasukan dan pengeluaran untuk tahun ini
        let pemasukan = fetchMonthlyData("Pemasukan", tahun: tahun)
        let pengeluaran = fetchMonthlyData("Pengeluaran", tahun: tahun)

        // Hitung surplus: pemasukan - pengeluaran
        var surplus: [Double] = []
        for i in 0 ..< 12 {
            surplus.append(pemasukan[i] - pengeluaran[i])
        }

        // Hitung saldo kumulatif dengan saldo awal dari semua tahun sebelumnya
        var cumulativeSurplus: [Double] = []
        var currentBalance = saldoAkhirTahunSebelumnya
        for value in surplus {
            currentBalance += value
            cumulativeSurplus.append(currentBalance)
        }
        return cumulativeSurplus
    }

    /// Caching hasil perhitungan tahun sebelumnya
    private var yearlyTotalSurplusCache: [Int: Double] = [:]

    /// Menghitung total surplus kumulatif dari tahun pertama yang tersedia hingga tahun yang ditentukan (eksklusif).
    ///
    /// Fungsi ini mengiterasi dari tahun pertama yang tercatat hingga tahun yang diberikan (`year` - 1),
    /// mengakumulasi surplus tahunan untuk setiap tahun. Untuk mengoptimalkan kinerja, fungsi ini
    /// menggunakan `yearlyTotalSurplusCache` untuk menyimpan dan mengambil surplus tahunan yang telah dihitung sebelumnya.
    /// Jika surplus untuk suatu tahun belum ada di *cache*, fungsi akan menghitungnya menggunakan
    /// `calculateYearlySurplus(forYear:)` dan menyimpannya ke *cache*.
    ///
    /// - Parameter year: Tahun batas atas (eksklusif) hingga surplus akan dihitung.
    ///                   Hanya surplus dari tahun-tahun *sebelum* tahun ini yang akan dimasukkan.
    ///
    /// - Returns: Total surplus kumulatif (`Double`) dari tahun pertama yang tersedia hingga
    ///            tahun yang ditentukan (tidak termasuk tahun yang ditentukan). Mengembalikan `0.0`
    ///            jika tahun yang ditentukan adalah tahun pertama atau sebelumnya.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchYearRange()` untuk mendapatkan tahun pertama yang tercatat.
    ///   - Fungsi ini bergantung pada `calculateYearlySurplus(forYear:)` untuk menghitung surplus tahunan
    ///     jika tidak ditemukan di *cache*.
    ///   - `yearlyTotalSurplusCache` diasumsikan sebagai kamus `[Int: Double]` yang digunakan untuk *caching*.
    private func calculateTotalSurplusUntil(year: Int) -> Double {
        let (firstYear, _) = fetchYearRange() // Cari tahun pertama
        guard year > firstYear else { return 0.0 } // Tidak ada surplus jika sebelum tahun pertama

        var totalSurplus = 0.0
        for currentYear in firstYear ..< year {
            if let cachedSurplus = yearlyTotalSurplusCache[currentYear] {
                // Ambil surplus dari cache jika sudah dihitung sebelumnya
                totalSurplus += cachedSurplus
            } else {
                // Hitung surplus tahunan jika belum ada di cache
                let yearlySurplus = calculateYearlySurplus(forYear: currentYear)
                yearlyTotalSurplusCache[currentYear] = yearlySurplus // Simpan ke cache
                totalSurplus += yearlySurplus
            }
        }
        return totalSurplus
    }

    /// Mengambil rentang tahun (tahun pertama dan tahun terakhir) dari entitas yang tersimpan.
    ///
    /// Fungsi ini melakukan *fetch* semua entitas dari Core Data, mengurutkannya berdasarkan
    /// properti `tanggal` secara menaik untuk mengidentifikasi tanggal paling awal dan paling akhir.
    /// Kemudian, ia mengekstrak komponen tahun dari tanggal-tanggal ini.
    ///
    /// - Returns: Sebuah *tuple* `(Int, Int)` yang berisi tahun pertama dan tahun terakhir
    ///            dari data yang tersedia. Jika tidak ada data yang ditemukan atau terjadi kesalahan,
    ///            fungsi akan mengembalikan tahun saat ini sebagai tahun pertama dan terakhir.
    ///
    /// - Catatan:
    ///   - Fungsi ini mengasumsikan adanya konteks Core Data (`context`) dan entitas bernama `Entity`
    ///     dengan properti `tanggal` yang bertipe `Date`.
    ///   - Dalam mode `DEBUG`, kesalahan *fetch* akan dicetak ke konsol.
    private func fetchYearRange() -> (Int, Int) {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tanggal", ascending: true)] // Urutkan ASC untuk tahun pertama

        do {
            let results = try context.fetch(fetchRequest)
            if let firstEntity = results.first,
               let lastEntity = results.last,
               let firstDate = firstEntity.tanggal,
               let lastDate = lastEntity.tanggal
            {
                let calendar = Calendar.current
                let firstYear = calendar.component(.year, from: firstDate)
                let lastYear = calendar.component(.year, from: lastDate)
                return (firstYear, lastYear)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear, currentYear) // Default jika tidak ada data
    }

    /// Menghitung total surplus (pemasukan dikurangi pengeluaran) untuk tahun yang ditentukan.
    ///
    /// Fungsi ini mengambil data pemasukan dan pengeluaran bulanan untuk tahun yang diberikan,
    /// kemudian menjumlahkan selisih antara pemasukan dan pengeluaran untuk setiap bulan
    /// untuk mendapatkan total surplus tahunan.
    ///
    /// - Parameter year: Tahun (`Int`) di mana surplus akan dihitung.
    ///
    /// - Returns: Total surplus tahunan (`Double`) untuk tahun yang ditentukan.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchMonthlyData(_:tahun:)` untuk mengambil data keuangan bulanan.
    private func calculateYearlySurplus(forYear year: Int) -> Double {
        // Ambil data pemasukan dan pengeluaran untuk tahun tertentu
        let pemasukan = fetchMonthlyData("Pemasukan", tahun: year)
        let pengeluaran = fetchMonthlyData("Pengeluaran", tahun: year)

        // Hitung total surplus untuk tahun tersebut
        var totalSurplus = 0.0
        for i in 0 ..< 12 {
            totalSurplus += (pemasukan[i] - pengeluaran[i])
        }
        return totalSurplus
    }

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Mendapatkan index bulan dari entry.x dan menggunakan array monthLabels
        var className = "" // Mendapatkan nama bulan
        if dataPerTahun.state == .off {
            className = getMonthLabel(for: Int(entry.x))
        } else {
            let yearIndex = Int(entry.x) // entry.x mewakili index di chart yang sama dengan array years
            if yearIndex >= 0, yearIndex < years.count {
                className = "\(years[yearIndex])" // Ambil tahun yang sesuai
            }
        }
        // Menggunakan NumberFormatter untuk menambahkan Rp dan format ribuan/jutaan
        let formattedValue = formatCurrency(entry.y)

        // Menampilkan nilai dengan label

        // Panggil fungsi untuk menampilkan popover atau UI lainnya
        showPopoverFor(className: className, nilai: formattedValue)
    }

    /// Fungsi untuk mendapatkan nama bulan berdasarkan index
    func getMonthLabel(for index: Int) -> String {
        let monthLabels = ["Januari", "Februari", "Maret", "April", "Mei", "Junu", "Juli", "Agustus", "September", "Oktober", "November", "Desember"]
        // Pastikan index berada dalam jangkauan array monthLabels
        return monthLabels.indices.contains(index) ? monthLabels[index] : "Unknown"
    }

    /// Fungsi untuk memformat nilai menjadi format mata uang dengan Rp.
    func formatCurrency(_ value: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = "."
        numberFormatter.decimalSeparator = ","
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 0

        let formattedValue = numberFormatter.string(from: NSNumber(value: value)) ?? "0"

        // Menambahkan prefix Rp.
        return "Rp. \(formattedValue)"
    }

    var currentPopover: NSPopover?

    /// Dijalankan ketika ada poin di dalam line Chart yang diklik.
    private func showPopoverFor(className: String, nilai: String) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("TeksCuplikan"), bundle: nil)
        // Ganti "TeksCuplikan" dengan storyboard identifier yang benar
        if let popoverViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("TeksCuplikan")) as? TeksCuplikan {
            currentPopover?.close()
            // Buat dan konfigurasi popover sesuai kebutuhan
            let popover = NSPopover()
            popover.contentViewController = popoverViewController

            // Set data yang diperlukan di popoverViewController
            popoverViewController.loadView()
            popoverViewController.kelas.stringValue = className
            popoverViewController.nilai.stringValue = nilai
            // Menghitung ukuran popover berdasarkan panjang teks
            let textWidth = max(popoverViewController.kelas.intrinsicContentSize.width, popoverViewController.nilai.intrinsicContentSize.width)
            let textHeight = popoverViewController.kelas.intrinsicContentSize.height + popoverViewController.nilai.intrinsicContentSize.height

            // Menyesuaikan ukuran popover dengan panjang teks
            popover.contentSize = NSSize(width: textWidth + 40, height: textHeight + 20) // Memberikan sedikit padding

            // Hitung ulang origin agar popover muncul di tempat yang diklik
            let mouseLocation = NSEvent.mouseLocation
            guard let window = view.window else { return }
            let windowLocation = window.convertPoint(fromScreen: mouseLocation) // Koordinat lokal jendela
            let viewLocation = view.convert(windowLocation, from: nil) // Koordinat lokal view

            // Tentukan rect untuk lokasi popover
            let rect = NSRect(x: viewLocation.x - 1, y: viewLocation.y + 5.2, width: 1, height: 1)

            // Tampilkan popover di lokasi mouse
            popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)

            popover.behavior = .semitransient
            currentPopover = popover
            view.window?.makeFirstResponder(currentPopover?.contentViewController?.view.window)
        }
    }

    /// Perkecil grafis line chart.
    @IBAction func zoomOut(_ sender: Any) {
        barChart.zoomOut()
    }

    /// Perbesar grafis line chart.
    @IBAction func zoomIn(_ sender: Any) {
        barChart.zoomIn()
    }

    deinit {
        #if DEBUG
            print("admin chart deinit")
        #endif
        deleteCache()
        tahunList.removeAll()
        years.removeAll()
        filterJenis.removeAll()
        tahun = nil
        NotificationCenter.default.removeObserver(self)
        for subViews in view.subviews {
            subViews.removeFromSuperviewWithoutNeedingDisplay()
        }
        self.view.removeFromSuperviewWithoutNeedingDisplay()
    }
}

/// Class untuk membuat format string husus.
/// Digunakan untuk membuat format dalam angka rupiah.
class CustomYAxisValueFormatter: AxisValueFormatter {
    /// Konversi angka Rupiah.
    ///
    /// 100.000 menjadi 100 Rb.
    /// 1.000.000 menjadi 1 Jt.
    /// /// 1.000.000.000 menjadi 1 M.
    /// - Parameters:
    ///   - value: Nilai yang akan dikonversi
    ///   - axis: **Deprecated**
    /// - Returns: Nilai konversi yang dihasilkan.
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value >= 1_000_000_000 {
            "\(String(format: "%.1f M", value / 1_000_000_000))"
        } else if value >= 1_000_000 {
            "\(String(format: "%.1f Jt", value / 1_000_000))"
        } else if value >= 1000 {
            "\(String(format: "%.1f Rb", value / 1000))"
        } else {
            "\(Int(value))"
        }
    }
}
