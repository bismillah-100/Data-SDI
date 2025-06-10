//
//  StatistikMurid.swift
//  Data Manager
//
//  Created by Bismillah on 09/11/23.
//

import Cocoa
import DGCharts
import SQLite

/// Statistik siswa dalam tampilan Grafik
class StatistikMurid: NSViewController, ChartViewDelegate {
    private var chartDescriptionText: String = ""
    var siswaID: Int64 = 0
    @IBOutlet weak var namaMurid: NSTextField!
    @IBOutlet var chartView: CombinedChartView!
    private let dbController = DatabaseController.shared
    private var kelasModel: [KelasModel] = []
    private var kelas1Model: [Kelas1Model] = []
    private var kelas2Model: [Kelas2Model] = []
    private var kelas3Model: [Kelas3Model] = []
    private var kelas4Model: [Kelas4Model] = []
    private var kelas5Model: [Kelas5Model] = []
    private var kelas6Model: [Kelas6Model] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { [weak self] in
            guard let self else { return }
            await self.getallKelas()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.createCombinedChart()
                self.chartView.delegate = self
                self.chartView.doubleTapToZoomEnabled = false
            }
        }
    }

    override func viewWillDisappear() {
        kelas1Model.removeAll()
        kelas2Model.removeAll()
        kelas3Model.removeAll()
        kelas4Model.removeAll()
        kelas5Model.removeAll()
        kelas6Model.removeAll()
        chartView.removeFromSuperviewWithoutNeedingDisplay()
    }

    /// Fungsi untuk mendapatkan nilai siswa di semua kelas
    func getallKelas() async {
        kelas1Model = dbController.getKelas1(siswaID: siswaID)
        kelas2Model = dbController.getKelas2(siswaID: siswaID)
        kelas3Model = dbController.getKelas3(siswaID: siswaID)
        kelas4Model = dbController.getKelas4(siswaID: siswaID)
        kelas5Model = dbController.getKelas5(siswaID: siswaID)
        kelas6Model = dbController.getKelas6(siswaID: siswaID)
    }

    /// Mengkalkulasi nilai semua semester di setiap kelas dan mengembalikan nilai Nama Kelas dan Nilai Kelas
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai semua kelas dan jumlah nilai dari semua semester  yang telah dikalkulasi ke dalam format Array String: Double
    private func calculateAverageAllSemesters(forSiswaID siswaID: Int64) -> [String: Double] {
        var averageByClass: [String: Double] = [:]

        let allClasses: [[KelasModels]] = [kelas1Model, kelas2Model, kelas3Model, kelas4Model, kelas5Model, kelas6Model]

        for (index, kelasModel) in allClasses.enumerated() {
            let siswaData = kelasModel.filter { $0.siswaID == siswaID }
            let totalNilai = siswaData.reduce(0) { $0 + $1.nilai }
            let average = Double(totalNilai) / Double(siswaData.count)

            averageByClass["Kelas \(index + 1)"] = average // Nama Kelas dan Jumlah Nilai Kelas
        }

        return averageByClass
    }

    /// Mengkalkulasi nilai semester 1 dan 2 di setiap kelas dan mengembalikan nilai dari setiap semester 1 dan 2.
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai dalam Array dengan format [Kelas: [Semester 1: Nilai], [Semester 2: Nilai]]
    private func calculateAverageSemester1And2(forSiswaID siswaID: Int64) -> [String: [String: Double]] {
        var averageByClassAndSemester: [String: [String: Double]] = [:]
        let allClasses: [[KelasModels]] = [kelas1Model, kelas2Model, kelas3Model, kelas4Model, kelas5Model, kelas6Model]

        for (index, kelasModel) in allClasses.enumerated() {
            let siswaData = kelasModel.filter { $0.siswaID == siswaID }
            let semester1Data = siswaData.filter { $0.semester == "1" }
            let semester2Data = siswaData.filter { $0.semester == "2" }

            let averageSemester1 = Double(semester1Data.reduce(0.0) { $0 + Double($1.nilai) }) / Double(semester1Data.count)
            let averageSemester2 = Double(semester2Data.reduce(0.0) { $0 + Double($1.nilai) }) / Double(semester2Data.count)

            averageByClassAndSemester["Kelas \(index + 1)"] = [
                "Semester 1": averageSemester1.isNaN ? 0 : averageSemester1,
                "Semester 2": averageSemester2.isNaN ? 0 : averageSemester2,
            ]
        }

        return averageByClassAndSemester
    }

    /// Metode delegasi dari ChartViewDelegate ketika gambar chart diklik.
    /// - Parameters:
    ///   - chartView: Chart yang digunakan dan ditampilkan.
    ///   - entry: Entry yang diklik.
    ///   - highlight: Pilihan Highlight pada data yang diklik
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Format nilai yang dipilih
        let formattedValue = String(format: "%.2f", entry.y)
        let className = String(format: "Kelas %.0f", entry.x + 1) // Tambahkan 1 jika kelas dimulai dari 1

        // Pastikan dataset ada
        guard let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else {
            return
        }

        // Mendapatkan warna dari dataset
        let colorIndex = Int(entry.x) % dataSet.colors.count
        let selectedColor = dataSet.colors[colorIndex]

        // Menampilkan popover dengan informasi tambahan
        showPopoverFor(kelas: className, nilai: formattedValue, warna: selectedColor)
    }

    /// Tampilan popover ketika chart diklik dari metode delegasi ChartViewDelegate.
    /// - Parameters:
    ///   - kelas: Nama Kelas yang ditampilkan.
    ///   - nilai: Nilai yang ditampilkan.
    ///   - warna: Warna yang ditampilkan sesuai semester.
    private func showPopoverFor(kelas: String, nilai: String, warna: NSUIColor) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("TeksCuplikan"), bundle: nil)

        // Ganti "TeksCuplikan" dengan storyboard identifier yang benar
        if let popoverViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("TeksCuplikan")) as? TeksCuplikan {
            // Buat dan konfigurasi popover sesuai kebutuhan
            let popover = NSPopover()
            popover.contentViewController = popoverViewController
            popover.behavior = .transient

            // Set data yang diperlukan di popoverViewController
            popoverViewController.loadView()
            popoverViewController.kelas.stringValue = kelas
            popoverViewController.kelas.textColor = warna
            popoverViewController.nilai.stringValue = nilai

            // Hitung ulang origin agar popover muncul di tempat yang diklik
            let mouseLocation = NSEvent.mouseLocation
            guard let window = view.window else { return }
            let windowLocation = window.convertPoint(fromScreen: mouseLocation) // Koordinat lokal jendela
            let viewLocation = view.convert(windowLocation, from: nil) // Koordinat lokal view

            // Tentukan rect untuk lokasi popover
            let rect = NSRect(x: viewLocation.x - 1, y: viewLocation.y + 5.2, width: 1, height: 1)

            // Tampilkan popover di lokasi mouse
            popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        }
    }

    /// Membuat kombinasi grafis chart line dan batang.
    private func createCombinedChart() {
        let barChartData = BarChartData()
        let lineChartData = LineChartData()
        chartView.delegate = self

        // Siapkan data rata-rata per kelas untuk semua semester
        let averageDataAllSemesters = calculateAverageAllSemesters(forSiswaID: siswaID)

        // Siapkan data rata-rata per kelas untuk Semester 1 dan Semester 2
        let averageDataSemester1And2 = calculateAverageSemester1And2(forSiswaID: siswaID)

        var barEntries: [BarChartDataEntry] = []
        var lineEntriesSemester1: [ChartDataEntry] = []
        var lineEntriesSemester2: [ChartDataEntry] = []
        var xAxisLabels: [String] = []

        // Urutkan kelas berdasarkan indeks
        let sortedClasses = averageDataAllSemesters.keys.sorted { kelas1, kelas2 -> Bool in
            let index1 = Int(kelas1.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            let index2 = Int(kelas2.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            return index1 < index2
        }

        for kelas in sortedClasses {
            let average = averageDataAllSemesters[kelas] ?? 0.0
            let barEntry = BarChartDataEntry(x: Double(xAxisLabels.count), y: average)
            barEntries.append(barEntry)

            if let semesterAverages = averageDataSemester1And2[kelas] {
                lineEntriesSemester1.append(ChartDataEntry(x: Double(xAxisLabels.count), y: semesterAverages["Semester 1"] ?? 0))
                lineEntriesSemester2.append(ChartDataEntry(x: Double(xAxisLabels.count), y: semesterAverages["Semester 2"] ?? 0))
            }

            xAxisLabels.append(kelas)
        }
        let classColors: [NSColor] = [
            NSColor(red: 0.6, green: 0.8, blue: 0.6, alpha: 1.0), // Warna hijau yang lebih gelap
            NSColor(red: 0.8, green: 0.75, blue: 0.6, alpha: 1.0), // Warna kuning yang lebih gelap
            NSColor(red: 0.55, green: 0.65, blue: 0.8, alpha: 1.0), // Warna biru yang lebih gelap
            NSColor(red: 0.7, green: 0.55, blue: 0.7, alpha: 1.0), // Warna ungu yang lebih gelap
            NSColor(red: 0.8, green: 0.6, blue: 0.6, alpha: 1.0), // Warna merah muda yang lebih gelap
            NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0), // Warna abu-abu yang lebih gelap
        ]
        let barDataSet = BarChartDataSet(entries: barEntries, label: "Rata-rata Semua Semester per Kelas")
        barDataSet.colors = classColors
        barDataSet.valueFont = NSFont.systemFont(ofSize: 14, weight: .bold)
        barDataSet.drawValuesEnabled = true
        barChartData.groupBars(fromX: 0.0, groupSpace: 0.2, barSpace: 0.1) // Sesuaikan ruang antar grup dan bar

        let lineDataSetSemester1 = LineChartDataSet(entries: lineEntriesSemester1, label: "Rata-rata Semester 1")
        lineDataSetSemester1.colors = [NSUIColor.magenta]
        lineDataSetSemester1.circleColors = [NSColor.magenta]
        lineDataSetSemester1.valueFont = NSFont.systemFont(ofSize: 10)
        lineDataSetSemester1.drawValuesEnabled = false
        lineDataSetSemester1.mode = .cubicBezier // Untuk kurva melengkung
        lineDataSetSemester1.cubicIntensity = 0.2 // Atur intensitas kelengkungan (0.0 - 1.0)

        let lineDataSetSemester2 = LineChartDataSet(entries: lineEntriesSemester2, label: "Rata-rata Semester 2")
        lineDataSetSemester2.colors = [NSUIColor.green]
        lineDataSetSemester2.valueFont = NSFont.systemFont(ofSize: 10)
        lineDataSetSemester2.drawValuesEnabled = false
        lineDataSetSemester2.circleColors = [NSColor.green]
        lineDataSetSemester2.mode = .cubicBezier // Untuk kurva melengkung
        lineDataSetSemester2.cubicIntensity = 0.2 // Atur intensitas kelengkungan (0.0 - 1.0)

        barChartData.append(barDataSet)
        lineChartData.append(lineDataSetSemester1)
        lineChartData.append(lineDataSetSemester2)

        let chartXAxis = chartView.xAxis
        chartXAxis.valueFormatter = DefaultAxisValueFormatter(formatter: NumberFormatter()) // Gunakan formatter default dengan angka
        chartXAxis.labelCount = xAxisLabels.count
        chartXAxis.drawLabelsEnabled = false // Menonaktifkan penampilan label pada sumbu x

        // Set nama murid pada chartDescription
        setNamaMurid(forClassIndex: 0) // Mengambil nama murid dari kelas pertama sebagai contoh

        // Gabungkan data barchart dan linechart dalam satu grafik
        let combinedData = CombinedChartData()
        combinedData.barData = barChartData
        combinedData.lineData = lineChartData
        chartView.data = combinedData
        chartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0, easingOption: .easeInOutCubic)
    }

    /// Mencari data siswa yang ada di Kelas Models
    /// - Parameter siswaID: ID Siswa yang dicari
    /// - Returns: Pengembalian dalam format model KelasModels
    private func findMuridModel(forSiswaID siswaID: Int64) -> KelasModels? {
        // Cari model dengan siswaID yang sesuai
        for kelasModel in [
            kelas1Model as [KelasModels],
            kelas2Model as [KelasModels],
            kelas3Model as [KelasModels],
            kelas4Model as [KelasModels],
            kelas5Model as [KelasModels],
            kelas6Model as [KelasModels],
        ] {
            if let muridModel = kelasModel.first(where: { $0.siswaID == siswaID }) {
                return muridModel
            }
        }
        return nil
    }

    /// Menuliskan nama siswa ke jendela window
    /// - Parameter classIndex: Kelas yang dipilih.
    func setNamaMurid(forClassIndex classIndex: Int) {
        // Set nama murid pada NSTextField
        if let muridModel = findMuridModel(forSiswaID: siswaID) {
            chartDescriptionText = "Informasi - \(muridModel.namasiswa)"
            title = chartDescriptionText
        } else {
            chartDescriptionText = "Grafik Gabungan - Murid tidak ditemukan"
            title = "Murid tidak ditemukan"
        }
    }
}
