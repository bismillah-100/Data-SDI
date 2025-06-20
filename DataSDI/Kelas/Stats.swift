//
//  Stats.swift
//  Data Manager
//
//  Created by Bismillah on 08/11/23.
//

import Cocoa
import DGCharts
import SQLite

/// ViewController untuk menampilkan statistik nilai siswa per kelas
/// dan semester dalam bentuk grafik pie dan bar chart.
/// Juga menyediakan opsi untuk menyimpan grafik sebagai gambar.
/// Dapat digunakan sebagai sheet window atau view biasa.
class Stats: NSViewController, ChartViewDelegate {
    // MARK: - Properties

    /// Outlet untuk elemen UI Pie Chart.
    @IBOutlet weak var stats: PieChartView!
    /// OUtlet untuk tombol tutup.
    @IBOutlet weak var tutup: NSButton!
    /// Outlet untuk elemen UI Pie Chart untuk semester 2.
    @IBOutlet weak var stats2: PieChartView!
    /// Outlet untuk elemen UI Bar Chart.
    @IBOutlet weak var barstats: BarChartView!
    /// Outlet untuk pilihan menu popup.
    @IBOutlet weak var pilihan: NSPopUpButton!
    /// Outlet untuk garis vertikal.
    @IBOutlet weak var verline: NSBox!
    /// Outlet untuk nama kategori yang dipilih dari popup ``pilihan``.
    @IBOutlet weak var kategoriTextField: NSTextField!
    /// @IBOutlet weak var semuaNilaiWidth: NSLayoutConstraint!
    @IBOutlet weak var pieChartTop: NSLayoutConstraint! // default 35
    /// Outlet constraint bagian atas untuk tombol ``tutup``.
    @IBOutlet weak var tutupTpConstraint: NSLayoutConstraint! // default 12

    /// Outlet cell menu popup ``pilihan``.
    @IBOutlet weak var pilihanCell: NSPopUpButtonCell!
    /// Outlet menu popup di bawah ``stats``.
    @IBOutlet weak var pilihanSmstr1: NSPopUpButton!
    /// Outlet menu popup di bawah ``stats2``.
    @IBOutlet weak var pilihanSmstr2: NSPopUpButton!
    /// Outlet untuk menu popup yang menampilkan semua nilai kelas.
    @IBOutlet weak var semuaNilai: NSPopUpButton!
    /// Outlet untuk menu item "..." pada menu popup.
    @IBOutlet weak var moreItem: NSMenuItem!

    /// Menandakan apakah ``Stats`` ditampilkan sebagai sheet window.
    var sheetWindow: Bool = false
    /// Menandakan apakah ``Stats`` ditampilkan sebagai popover.
    var currentPopover: NSPopover?

    /// Array untuk menyimpan data entri bar chart.
    var dataEntries: [BarChartDataEntry] = []
    /// Array untuk menyimpan data entri pie chart semester 1.
    var dataEntries1: [ChartDataEntry] = []
    /// Array untuk menyimpan data entri pie chart semester 2.
    var dataEntries2: [ChartDataEntry] = []

    /// Controller untuk mengakses database.
    let dbController = DatabaseController.shared

    /// Array untuk menyimpan data kelas 1 hingga kelas 6.
    var kelas1data: [Kelas1Model] = []
    /// Lihat: ``kelas1data``.
    var kelas2data: [Kelas2Model] = []
    /// Lihat: ``kelas1data``.
    var kelas3data: [Kelas3Model] = []
    /// Lihat: ``kelas1data``.
    var kelas4data: [Kelas4Model] = []
    /// Lihat: ``kelas1data``.
    var kelas5data: [Kelas5Model] = []
    /// Lihat: ``kelas1data``.
    var kelas6data: [Kelas6Model] = []

    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 1.
    var selectedSemester1: String? = nil
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 2.
    var selectedSemester2: String? = nil
    
    /// Properti warna yang digunakan di setiap chart. Berisi enam warna berbeda sesuai kelas.
    let classColors: [NSColor] = [
        NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0), // Warna hijau yang lebih terang
        NSColor(calibratedRed: 246.0 / 255.0, green: 161.0 / 255.0, blue: 81.0 / 255.0, alpha: 1.0), // Warna kuning yang lebih pekat
        NSColor(red: 66.0 / 255.0, green: 133.0 / 255.0, blue: 244.0 / 255.0, alpha: 1.0), // Warna biru yang lebih terang
        NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0), // Warna ungu yang lebih terang
        NSColor(red: 0.8, green: 0.5, blue: 0.6, alpha: 1.0), // Warna merah muda yang lebih terang
        NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0), // Warna abu-abu yang lebih terang
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        if let ve = view as? NSVisualEffectView {
            ve.blendingMode = .behindWindow
            ve.material = .windowBackground
            ve.state = .followsWindowActiveState
        }
        if sheetWindow {
            // Jika Stats ditampilkan sebagai sheet window
            tutup.isHidden = false
            pilihan.isHidden = false
            let ellipsis = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: .none)
            let conf = NSImage.SymbolConfiguration(scale: .medium)
            let largeEllipsis = ellipsis?.withSymbolConfiguration(conf)
            moreItem.image = largeEllipsis
            pilihanCell.arrowPosition = .noArrow
            pilihan.menu?.delegate = self
        } else {
            tutup.isHidden = true
            pilihan.isHidden = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        muatUlang(self)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        // Reset bar chart data
        barstats.data = nil
        stats.data = nil
        stats2.data = nil

        // Jika Anda ingin mereset data entries secara keseluruhan
        dataEntries.removeAll()
        dataEntries1.removeAll()
        dataEntries2.removeAll()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .windowControllerClose, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: .windowControllerClose, object: nil)
        
        if !sheetWindow { setupToolbar() }
    }

    // MARK: - Chart Methods

    /// Memuat ulang data dan memperbarui grafik.
    /// - Parameter sender: `Any` yang memicu aksi ini, tombol "Muat Ulang".
    @IBAction func muatUlang(_ sender: Any) {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            await self.updateData()
            await MainActor.run { [weak self] in
                self?.updateUI()
            }
        }
    }

    /// Memperbarui data untuk grafik dan mengatur ulang data entri.
    func updateData() async {
        // Reset bar chart data
        barstats.data = nil
        stats.data = nil
        stats2.data = nil

        // Jika Anda ingin mereset data entries secara keseluruhan
        dataEntries.removeAll()
        dataEntries1.removeAll()
        dataEntries2.removeAll()
        kelas1data = await dbController.getallKelas1()
        kelas2data = await dbController.getallKelas2()
        kelas3data = await dbController.getallKelas3()
        kelas4data = await dbController.getallKelas4()
        kelas5data = await dbController.getallKelas5()
        kelas6data = await dbController.getallKelas6()
    }

    /// Memperbarui antarmuka pengguna dengan memilih semester default,
    /// membuat grafik pie untuk semester 1 dan 2, serta mengonfigurasi bar chart.
    func updateUI() {
        pilihanSmstr1.selectItem(withTitle: "Semester 1")
        pilihanSmstr2.selectItem(withTitle: "Semester 2")
        createPieChart()
        createPieChartSemester2()
        barstats.delegate = self
        populateSemesterPopUpButton()
        barstats.doubleTapToZoomEnabled = false
        pilihanSmstr1.selectItem(withTitle: "Semester 1")
        pilihanSmstr2.selectItem(withTitle: "Semester 2")
        selectedSemester1 = "Semester 1"
        selectedSemester2 = "Semester 2"
    }

    // MARK: - Actions

    /// Fungsi yang dipanggil ketika menu popup untuk semester 1 dipilih.
    /// Mengupdate data dan grafik sesuai dengan semester yang dipilih.
    ///
    /// - Parameter sender: `NSPopUpButton` yang memicu aksi ini.
    @IBAction func pilihanSemester1(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester1 else { return }
        selectedSemester1 = selectedTitle // Update setelah validasi

        stats.data = nil
        dataEntries1.removeAll() // Reset data
        stats.notifyDataSetChanged()
        createPieChart() // Update Pie Chart
    }

    /// Fungsi yang dipanggil ketika menu popup untuk semester 2 dipilih.
    /// Mengupdate data dan grafik sesuai dengan semester yang dipilih.
    ///
    /// - Parameter sender: `NSPopUpButton` yang memicu aksi ini
    @IBAction func pilihanSemester2(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester2 else { return }
        selectedSemester2 = selectedTitle // Update setelah validasi

        stats2.data = nil
        dataEntries2.removeAll() // Reset data
        stats2.notifyDataSetChanged()
        createPieChartSemester2() // Update Pie Chart
    }

    /// Fungsi untuk mengisi popup menu ``pilihanSmstr1`` dan ``pilihanSmstr2`` dengan semester yang tersedia.
    func populateSemesterPopUpButton() {
        let kelasDataArrays: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]

        // Filter dan gabungkan semester yang tidak kosong
        let allSemesters: Set<String> = Set(kelasDataArrays.flatMap { $0.map(\.semester).filter { !$0.isEmpty } })

        let sortedSemesters = allSemesters.sorted { semesterOrder($0, $1) }
        let formattedSemesters = sortedSemesters.map { formatSemesterName($0) }

        if formattedSemesters.isEmpty {
            // Tambahkan pesan placeholder jika tidak ada data
            semuaNilai.addItem(withTitle: "Semua Kategori & Semester")
            let semuaSemester = semuaNilai.item(withTitle: "Semua Kategori & Semester")
            semuaSemester?.state = .on
            pilihanSmstr1.removeAllItems()
            pilihanSmstr1.addItem(withTitle: "Tdk. ada data")
            pilihanSmstr1.isEnabled = false
            pilihanSmstr2.removeAllItems()
            pilihanSmstr2.addItem(withTitle: "Tdk. ada data")
            pilihanSmstr2.isEnabled = false
        } else {
            // Update pilihanSmstr1
            semuaNilai.addItem(withTitle: "Semua Kategori & Semester")
            semuaNilai.addItems(withTitles: formattedSemesters)
            semuaNilai.selectItem(withTitle: "Semua Kategori & Semester")
            semuaNilai.selectItem(withTitle: "Semester 1")
            semuaNilai.selectItem(withTitle: "Semester 2")
            let semester1 = semuaNilai.item(withTitle: "Semester 1")
            let semester2 = semuaNilai.item(withTitle: "Semester 2")
            semester1?.state = .on
            semester2?.state = .on
            pilihanSmstr1.removeAllItems()
            pilihanSmstr1.addItems(withTitles: formattedSemesters)
            pilihanSmstr1.isEnabled = true
            // Update pilihanSmstr2
            pilihanSmstr2.removeAllItems()
            pilihanSmstr2.addItems(withTitles: formattedSemesters)
            pilihanSmstr2.isEnabled = true
            let selectedItems = ["Semester 1", "Semester 2"]
            Task { [weak self] in
                await self?.updateDataEntries(selectedItems: selectedItems)
                await MainActor.run {
                    self?.displayBarChart()
                }
            }
            kategoriTextField.stringValue = "Nilai rata-rata Semester 1 & 2"
        }
    }

    /// Fungsi untuk menampilkan bar chart dengan data yang telah diisi.
    /// Menggunakan thread background untuk membuat dataset dan menambahkan entri ke bar chart.
    /// - Note: Pastikan untuk memanggil fungsi ini setelah dataEntries diisi.
    func displayBarChart() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            // Create a dataset for the bar chart with the class labels
            let classLabels = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6"]

            // Create an array to store the data sets for each class

            // Create a set to track the colors that have been used
            var usedColors: Set<NSColor> = []
            var dataSets: [BarChartDataSet] = []
            // Create a data set for each class and assign unique colors
            for (i, className) in classLabels.enumerated() {
                let color: NSColor = if i < classLabels.count {
                    self.classColors[i]
                } else {
                    NSColor.systemPink
                }

                // Check if the color has been used for another class
                if !usedColors.contains(color) {
                    usedColors.insert(color)

                    let label = "\(className)"
                    let dataSet = BarChartDataSet(entries: [], label: label)
                    dataSet.colors = [color]
                    dataSet.highlightAlpha = 0
                    dataSets.append(dataSet)
                }
            }
            // Add entries to the respective data sets
            for entry in self.dataEntries {
                if let className = entry.data as? String {
                    if classLabels.firstIndex(of: className) != nil {
                        let label = "\(className)"
                        if let dataSet = dataSets.first(where: { $0.label == label }) {
                            entry.data = label
                            dataSet.append(entry)
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                // Create a chart data object
                let data = BarChartData(dataSets: dataSets)
                data.barWidth = 0.7
                self.barstats.data = data

                // Add the chart view to your NSView
                // Loop through the dataSets and add value labels to each bar
                for dataSet in dataSets {
                    dataSet.valueFont = NSFont.systemFont(ofSize: 12) // Mengatur ukuran font menjadi 16 (atau sesuai kebutuhan)
                    dataSet.valueTextColor = NSColor.controlTextColor // Mengatur warna teks nilai
                    dataSet.valueFormatter = DefaultValueFormatter(formatter: NumberFormatter())
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.minimumFractionDigits = 2 // Menentukan jumlah minimum desimal
                    formatter.maximumFractionDigits = 2 // Menentukan jumlah maksimum desimal
                    dataSet.valueFormatter = DefaultValueFormatter(formatter: formatter)
                    dataSet.drawValuesEnabled = true
                }
                self.barstats.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: .easeOutCirc)
            }
        }
    }

    /// Fungsi untuk menampilkan pie chart pertama.
    /// Mengambil semester yang dipilih dari menu popup ``pilihanSmstr1`` dan membuat pie chart berdasarkan data kelas.
    func createPieChart() {
        let selectedSemester = pilihanSmstr1.titleOfSelectedItem ?? "Semester 1"
        var formattedSemester = selectedSemester
        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let kelasDataArray: [[KelasModels]] = [self.kelas1data, self.kelas2data, self.kelas3data, self.kelas4data, self.kelas5data, self.kelas6data]
            for (index, kelas) in kelasDataArray.enumerated() {
                let siswaSemester: [KelasModels] = kelas.filter { $0.semester == formattedSemester }
                let totalRataRataKelas = calculateTotalRataRata(siswaSemester)
                let entryLabel = if index == 5 { // Index 5 adalah kelas 6
                    "Kls. 6"
                } else {
                    "Kls. \(index + 1)"
                }

                // Tambahkan entry dengan nilai 0 jika tidak ada data
                let entryValue = totalRataRataKelas > 0 ? totalRataRataKelas : 0
                let entry = PieChartDataEntry(value: entryValue, label: entryLabel)
                self.dataEntries1.append(entry)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let dataSet = PieChartDataSet(entries: self.dataEntries1, label: "")
                dataSet.colors = self.classColors

                let data = PieChartData(dataSet: dataSet)
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = .center
                let centerText = NSMutableAttributedString(string: "\(selectedSemester)\nRerata Nilai")
                centerText.setAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 15.0)!, NSAttributedString.Key.paragraphStyle: paragraphStyle], range: NSMakeRange(0, centerText.length))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor.gray], range: NSMakeRange(10, centerText.length - 10))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-LightItalic", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor(red: 51 / 255.0, green: 181 / 255.0, blue: 229 / 255.0, alpha: 1.0)], range: NSMakeRange(centerText.length - 0, 0))
                self.stats.centerAttributedText = centerText

                self.stats.data = data

                dataSet.valueFormatter = DefaultValueFormatter(formatter: NumberFormatter())
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 2 // Menentukan jumlah minimum desimal
                formatter.maximumFractionDigits = 2 // Menentukan jumlah maksimum desimal
                dataSet.valueFormatter = DefaultValueFormatter(formatter: formatter)

                self.stats.usePercentValuesEnabled = false
                self.stats.holeRadiusPercent = 0.5
                self.stats.transparentCircleRadiusPercent = 0.55
                self.stats.drawEntryLabelsEnabled = false
                self.stats.entryLabelFont = NSFont.boldSystemFont(ofSize: 13)
                self.stats.entryLabelColor = .white
                self.stats.animate(xAxisDuration: 0.8, yAxisDuration: 0.8, easingOption: .easeOutCirc)
            }
        }
    }

    /// Fungsi untuk menampilkan pie chart kedua.
    /// Mengambil semester yang dipilih dari menu popup ``pilihanSmstr2`` dan membuat pie chart berdasarkan data kelas.
    func createPieChartSemester2() {
        let selectedSemester = pilihanSmstr2.titleOfSelectedItem ?? "Semester 2"
        var formattedSemester = selectedSemester

        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let kelasDataArray: [[KelasModels]] = [self.kelas1data, self.kelas2data, self.kelas3data, self.kelas4data, self.kelas5data, self.kelas6data]
            for (index, kelas) in kelasDataArray.enumerated() {
                let siswaSemester: [KelasModels] = kelas.filter { $0.semester == formattedSemester }
                let totalRataRataKelas = calculateTotalRataRata(siswaSemester)
                let entryLabel = if index == 5 { // Index 5 adalah kelas 6
                    "Kls. 6"
                } else {
                    "Kls. \(index + 1)"
                }

                // Tambahkan entry dengan nilai 0 jika tidak ada data
                let entryValue = totalRataRataKelas > 0 ? totalRataRataKelas : 0
                let entry = PieChartDataEntry(value: entryValue, label: entryLabel)
                self.dataEntries2.append(entry)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let dataSet = PieChartDataSet(entries: self.dataEntries2, label: "")
                dataSet.colors = self.classColors

                let data = PieChartData(dataSet: dataSet)
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = .center
                let centerText = NSMutableAttributedString(string: "\(selectedSemester)\nRerata Nilai")
                centerText.setAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 15.0)!, NSAttributedString.Key.paragraphStyle: paragraphStyle], range: NSMakeRange(0, centerText.length))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor.gray], range: NSMakeRange(10, centerText.length - 10))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-LightItalic", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor(red: 51 / 255.0, green: 181 / 255.0, blue: 229 / 255.0, alpha: 1.0)], range: NSMakeRange(centerText.length - 0, 0))
                self.stats2.centerAttributedText = centerText

                self.stats2.data = data

                dataSet.valueFormatter = DefaultValueFormatter(formatter: NumberFormatter())
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 2 // Menentukan jumlah minimum desimal
                formatter.maximumFractionDigits = 2 // Menentukan jumlah maksimum desimal
                dataSet.valueFormatter = DefaultValueFormatter(formatter: formatter)

                self.stats2.usePercentValuesEnabled = false
                self.stats2.holeRadiusPercent = 0.5
                self.stats2.transparentCircleRadiusPercent = 0.55
                self.stats2.drawEntryLabelsEnabled = false
                self.stats2.entryLabelFont = NSFont.boldSystemFont(ofSize: 13)
                self.stats2.entryLabelColor = .white
                self.stats2.animate(xAxisDuration: 0.8, yAxisDuration: 0.8, easingOption: .easeOutCirc)
            }
        }
    }

    /// Action tombol untuk menutup view ``Stats`` ketika ditampilkan dalam jendela sheet.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func tutupchart(_ sender: Any) {
        if let sheetWindow = NSApplication.shared.mainWindow?.attachedSheet {
            NSApplication.shared.mainWindow?.endSheet(sheetWindow)
            sheetWindow.orderOut(nil)
        }
    }

    /// Action tombol untuk menyimpan ``barstats``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func simpanchart(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 3)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if let self, result == NSApplication.ModalResponse.OK {
                if let path = panel.url?.path {
                    let _ = self.barstats.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }

    /// Tombol untuk menyimpan ``stats``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func smstr1(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 1)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if let self, result == NSApplication.ModalResponse.OK {
                if let path = panel.url?.path {
                    let _ = self.stats.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }

    /// Tombol untuk menyimpan ``stats2``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func smstr2(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 2)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if let self, result == NSApplication.ModalResponse.OK {
                if let path = panel.url?.path {
                    let _ = self.stats2.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }

    /// Action untuk NSPopUpButton ``semuaNilai``.
    /// - Parameter sender: Objek pemicu berupa NSPopUpButton.
    @IBAction func pilihanSemuaNilai(_ sender: NSPopUpButton) {
        if currentPopover != nil {
            currentPopover?.close()
            view.window?.becomeFirstResponder()
        }
        // Dapatkan menu dari NSPopUpButton
        let menu = sender.menu
        guard let items = menu?.items else { return }

        // Mendapatkan item yang dipilih
        guard let selectedItem = sender.titleOfSelectedItem else { return }

        // Filter item yang statenya adalah .on
//        let selectedItems = items.filter { $0.state == .on }

        // Ubah state item yang dipilih
        if let selectedMenuItem = items.first(where: { $0.title == selectedItem }) {
            // Toggle state item yang dipilih
            selectedMenuItem.state = (selectedMenuItem.state == .on) ? .off : .on
        }
        if selectedItem == "Semua Kategori & Semester" {
            for menuItem in items {
                menuItem.state = (menuItem.title == selectedItem) ? .on : .off
            }
        } else if selectedItem == "Semua Kategori & Semester", items.first(where: { $0.state == .on && $0.title != "Semua Kategori & Semester" }) != nil {
            // Matikan state "Semua Kategori & Semester"
            if let allSemesterItem = items.first(where: { $0.title == "Semua Kategori & Semester" }) {
                allSemesterItem.state = .off
            }
        } else {
            // Matikan state "Semua Kategori & Semester" jika kategori lain dipilih
            if selectedItem != "Semua Kategori & Semester" {
                if let allSemesterItem = items.first(where: { $0.title == "Semua Kategori & Semester" }) {
                    allSemesterItem.state = .off
                }
            }
        }
        // Ambil item yang sedang dalam keadaan aktif
        let selectedItems = items.enumerated()
            .filter { $0.offset != 0 && $0.element.state == .on } // Mengecualikan indeks 0
            .map(\.element.title)

        Task { [weak self] in
            guard let self else { return }
            await self.updateDataEntries(selectedItems: items.filter { $0.state == .on }.map(\.title))
            
            await MainActor.run {
                self.barstats.notifyDataSetChanged()
                self.displayBarChart()
                self.updateKategoriTextField(with: selectedItems)
            }
            
        }
    }

    /// Memperbarui entri data yang digunakan untuk visualisasi (misalnya, grafik batang) berdasarkan item yang dipilih pengguna.
    /// Fungsi ini menghitung rata-rata nilai untuk setiap kelas atau agregat semua kelas, tergantung pada pilihan yang diberikan.
    /// Operasi pembaruan dilakukan di latar belakang untuk menjaga responsivitas UI, dan penyelesaiannya dipanggil di 'MainActor'.
    ///
    /// - Parameters:
    ///   - selectedItems: Sebuah array string yang berisi kriteria filter yang dipilih pengguna.
    ///                    Ini dapat mencakup "Semua Kategori & Semester" untuk menampilkan data agregat dari semua kelas,
    ///                    atau semester tertentu (misalnya, "Semester 1", "Semester 2") untuk memfilter data per semester.
    ///   - completion: Sebuah closure yang akan dipanggil tanpa argumen setelah pembaruan data selesai
    ///                 dan 'dataEntries' telah diperbarui. Closure ini dijamin akan dijalankan pada 'MainActor'.
    func updateDataEntries(selectedItems: [String]) async {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            // Reset dataEntries
            self.dataEntries.removeAll()

            // Jika "Semua Kategori & Semester" ada dalam pilihan
            if selectedItems.contains("Semua Kategori & Semester") {
                // Tambahkan data untuk semua kelas
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas1data, className: "Kelas 1"))
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas2data, className: "Kelas 2"))
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas3data, className: "Kelas 3"))
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas4data, className: "Kelas 4"))
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas5data, className: "Kelas 5"))
                self.dataEntries.append(self.calculateTotalNilaiForClass(self.kelas6data, className: "Kelas 6"))
            } else {
                let kelasDataArray: [([KelasModels], String)] = [
                    (self.kelas1data, "Kelas 1"),
                    (self.kelas2data, "Kelas 2"),
                    (self.kelas3data, "Kelas 3"),
                    (self.kelas4data, "Kelas 4"),
                    (self.kelas5data, "Kelas 5"),
                    (self.kelas6data, "Kelas 6"),
                ]

                // Proses data berdasarkan kategori yang dipilih
                for (kelas, className) in kelasDataArray {
                    var totalNilai: Double = 0
                    var totalSiswa = 0

                    for selectedItem in selectedItems {
                        let formattedSemester = selectedItem.split(separator: " ").last ?? "1"
                        let siswaSemester = kelas.filter { $0.semester == formattedSemester }
                        totalNilai += siswaSemester.reduce(0) { $0 + Double($1.nilai) }
                        totalSiswa += siswaSemester.count
                    }

                    let rataRataNilai = totalSiswa > 0 ? totalNilai / Double(totalSiswa) : 0.0
                    let index = kelasDataArray.firstIndex { $0.1 == className } ?? 0
                    let entry = BarChartDataEntry(x: Double(index), y: rataRataNilai, data: className)
                    self.dataEntries.append(entry)
                }
            }
        }
    }

    /// Menghitung rata-rata total dari nilai-nilai siswa yang diberikan dalam array `KelasModels`.
    /// Fungsi ini menjumlahkan semua nilai siswa dan kemudian membagi dengan jumlah siswa untuk mendapatkan rata-rata.
    /// Jika array `siswaSemester` kosong, fungsi akan mengembalikan 0.0 untuk menghindari pembagian dengan nol.
    ///
    /// - Parameter siswaSemester: Sebuah array `KelasModels` yang berisi data siswa,
    ///                           termasuk properti `nilai` (nilai siswa).
    /// - Returns: Sebuah nilai `Double` yang merepresentasikan rata-rata total nilai dari siswa yang diberikan.
    ///            Mengembalikan 0.0 jika tidak ada siswa dalam array `siswaSemester`.
    func calculateTotalRataRata(_ siswaSemester: [KelasModels]) -> Double {
        var totalRataRata: Double = 0
        for siswa in siswaSemester {
            totalRataRata += Double(siswa.nilai)
        }
        return totalRataRata / Double(siswaSemester.count)
    }

    /// Menghitung total nilai dari semua siswa yang diberikan dalam array `KelasModels`.
    /// Fungsi ini menjumlahkan properti `nilai` dari setiap objek `KelasModels` dalam array.
    ///
    /// - Parameter kelas: Sebuah array `KelasModels` yang berisi data siswa,
    ///                   termasuk properti `nilai` (nilai siswa).
    /// - Returns: Sebuah nilai `Int` yang merepresentasikan jumlah total nilai dari semua siswa yang diberikan.
    func calculateTotalNilai(forKelas kelas: [KelasModels]) -> Int {
        var jumlah = 0
        for siswa in kelas {
            jumlah += Int(siswa.nilai)
        }
        return jumlah
    }

    /// Menghitung total nilai dan rata-rata nilai untuk kelas tertentu, lalu mengembalikan entri data yang diformat untuk grafik batang.
    /// Fungsi ini memanfaatkan `calculateTotalNilai` untuk mendapatkan jumlah total nilai dari semua siswa di kelas,
    /// kemudian menghitung rata-rata nilai per siswa. Hasilnya digunakan untuk membuat `BarChartDataEntry`
    /// yang merepresentasikan rata-rata nilai kelas dengan nama kelas yang diberikan.
    ///
    /// - Parameters:
    ///   - kelas: Sebuah array `KelasModels` yang berisi data siswa untuk kelas yang sedang diproses.
    ///            Setiap objek `KelasModels` diharapkan memiliki properti `nilai`.
    ///   - className: Sebuah `String` yang merepresentasikan nama kelas (misalnya, "Kelas 1", "Kelas 2")
    ///                yang akan digunakan sebagai label data dalam entri grafik.
    /// - Returns: Sebuah objek `BarChartDataEntry` yang berisi rata-rata nilai kelas sebagai nilai Y,
    ///            indeks entri sebagai nilai X (berdasarkan jumlah entri yang sudah ada), dan nama kelas sebagai data.
    ///            Jika array `kelas` kosong, rata-rata nilai akan menjadi 0.0.
    func calculateTotalNilaiForClass(_ kelas: [KelasModels], className: String) -> BarChartDataEntry {
        // Calculate the total nilai for the class
        let totalNilai = calculateTotalNilai(forKelas: kelas)

        // Calculate the rata-rata nilai per siswa dalam kelas
        let rataRataNilai = kelas.isEmpty ? 0.0 : Double(totalNilai) / Double(kelas.count)

        // Create a data entry for the class using the rata-rata nilai and class name
        let classEntry = BarChartDataEntry(x: Double(dataEntries.count), y: rataRataNilai, data: className)

        return classEntry
    }

    /// Menentukan urutan dua semester.
    /// Fungsi ini mengurutkan semester 1 terlebih dahulu, diikuti semester 2, lalu urutan leksikografis untuk semester lainnya.
    ///
    /// - Parameters:
    ///   - semester1: Sebuah `String` yang merepresentasikan semester pertama untuk dibandingkan.
    ///   - semester2: Sebuah `String` yang merepresentasikan semester kedua untuk dibandingkan.
    /// - Returns: `true` jika `semester1` harus datang sebelum `semester2` dalam urutan,
    ///            `false` jika `semester2` harus datang sebelum atau sama dengan `semester1`.
    func semesterOrder(_ semester1: String, _ semester2: String) -> Bool {
        if semester1 == "1" { return true }
        if semester2 == "1" { return false }
        if semester1 == "2" { return true }
        if semester2 == "2" { return false }
        return semester1 < semester2
    }

    /// Memformat angka semester menjadi nama semester yang lebih mudah dibaca.
    /// Fungsi ini mengonversi angka semester (misalnya, "1", "2") menjadi format string yang lebih deskriptif
    /// (misalnya, "Semester 1", "Semester 2"). Jika semester tidak dikenal, ia akan mengembalikan input asli.
    ///
    /// - Parameter semester: Sebuah `String` yang merepresentasikan angka semester (misalnya, "1", "2", dll.).
    /// - Returns: Sebuah `String` yang diformat dari nama semester.
    func formatSemesterName(_ semester: String) -> String {
        switch semester {
        case "1":
            "Semester 1"
        case "2":
            "Semester 2"
        default:
            "\(semester)"
        }
    }

    /// Dipanggil ketika sebuah nilai diklik dalam tampilan grafik.
    /// Fungsi ini mengambil data dari entri yang dipilih, mengekstrak nama kelas dan nilai yang diformat,
    /// kemudian memanggil fungsi `showPopoverFor` untuk menampilkan popover dengan informasi tersebut.
    ///
    /// - Parameters:
    ///   - chartView: Objek `ChartViewBase` di mana nilai dipilih.
    ///   - entry: Objek `ChartDataEntry` yang merepresentasikan entri data yang dipilih.
    ///   - highlight: Objek `Highlight` yang berisi informasi tentang penyorotan yang terjadi.
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        guard let _ = chartView.data?.dataSets[highlight.dataSetIndex] as? BarChartDataSet,
              let className = entry.data as? String
        else {
            return
        }

        // Mengubah entry.y menjadi string dengan format 2 desimal
        let formattedValue = String(format: "%.2f", entry.y)

        showPopoverFor(className: className, nilai: formattedValue)
    }

    /// Dipanggil ketika sebuah nilai dipilih dalam tampilan grafik.
    /// Fungsi ini mengambil data dari entri yang dipilih, mengekstrak nama kelas dan nilai yang diformat,
    /// kemudian memanggil fungsi `showPopoverFor` untuk menampilkan popover dengan informasi tersebut.
    ///
    /// - Parameters:
    ///   - chartView: Objek `ChartViewBase` di mana nilai dipilih.
    ///   - entry: Objek `ChartDataEntry` yang merepresentasikan entri data yang dipilih.
    ///   - highlight: Objek `Highlight` yang berisi informasi tentang penyorotan yang terjadi.
    func showPopoverFor(className: String, nilai: String) {
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

    /// Memperbarui tampilan bidang teks kategori dengan item yang dipilih.
    /// Fungsi ini menggabungkan item yang dipilih menjadi sebuah string yang diformat,
    /// kemudian menetapkan string tersebut ke `kategoriTextField` setelah pengelompokan item selesai di latar belakang.
    /// Pemrosesan dilakukan secara asinkron untuk menghindari pemblokiran thread utama.
    ///
    /// - Parameter selectedItems: Sebuah array string yang berisi item-item yang dipilih oleh pengguna.
    ///                            Item-item ini akan diproses untuk membentuk string tampilan kategori.
    func updateKategoriTextField(with selectedItems: [String]) {
        var text = String()
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            // Gabungkan item yang dipilih, format sesuai kebutuhan
            text = await self.groupItemsByBaseName(Array(Set(selectedItems))).joined(separator: " & ")
            await MainActor.run { [weak self] in
                self?.kategoriTextField.stringValue = text
            }
        }
    }

    /// Mengelompokkan item-item string berdasarkan nama dasarnya dan menggabungkan angka-angka terkait.
    /// Misalnya, jika input adalah ["Kategori 1", "Kategori 2", "Kategori 3"],
    /// output akan menjadi ["Kategori 1 & 2 & 3"]. Ini berguna untuk menampilkan pilihan yang ringkas.
    ///
    /// - Parameter items: Sebuah array string, di mana setiap string diharapkan memiliki format
    ///                    "Nama Angka" (misalnya, "Semester 1", "Kelas 3").
    /// - Returns: Sebuah array string yang telah dikelompokkan, di mana nama dasar yang sama digabungkan
    ///            dengan angka-angka yang sesuai.
    func groupItemsByBaseName(_ items: [String]) async -> [String] {
        var grouped: [String: [String]] = [:]

        for item in items {
            // Pisahkan nama dan angka
            let components = item.split(separator: " ")
            guard let baseName = components.first else { continue }

            // Kelompokkan berdasarkan nama
            if grouped[String(baseName)] != nil {
                grouped[String(baseName)]?.append(item)
            } else {
                grouped[String(baseName)] = [item]
            }
        }

        // Gabungkan nama dengan angka
        var result: [String] = []
        for (baseName, items) in grouped {
            if items.count > 1 {
                let numbers: [String] = items.compactMap { item in
                    let components = item.split(separator: " ")
                    return components.count > 1 ? String(components.last!) : nil
                }
                let numberRange = numbers.sorted().joined(separator: " & ")
                result.append("\(baseName) \(numberRange)")
            } else {
                result.append(items.first ?? "")
            }
        }

        return result
    }

    /// Konfigurasi action dan target toolbar.
    func setupToolbar() {
        if let toolbar = view.window?.toolbar {
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) {
                if let searchField = searchFieldToolbarItem.view as? NSSearchField {
                    searchField.placeholderAttributedString = nil
                    searchField.placeholderString = "Nilai Kelas"
                    searchField.isEnabled = false
                }
            }

            if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }) {
                if let zoom = zoomToolbarItem.view as? NSSegmentedControl {
                    zoom.isEnabled = false
                }
            }

            if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }) {
                if let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton {
                    kalkulasiNilai.isEnabled = false
                }
            }

            if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }) {
                if let hapus = hapusToolbarItem.view as? NSButton {
                    hapus.isEnabled = false
                }
            }

            if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }) {
                if let edit = editToolbarItem.view as? NSButton {
                    edit.isEnabled = false
                }
            }

            if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }) {
                if let tambah = tambahToolbarItem.view as? NSButton {
                    tambah.isEnabled = false
                }
            }

            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }) {
                if let add = addToolbarItem.view as? NSButton {
                    add.isEnabled = false
                }
            }

            pilihan.isEnabled = true

            if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
               let popUpButtom = popUpMenuToolbarItem.view as? NSPopUpButton
            {
                popUpButtom.menu = pilihan.menu
                pilihan.menu?.delegate = self
            }
        }
    }

    deinit {
        dataEntries.removeAll()
        kelas1data.removeAll()
        kelas2data.removeAll()
        kelas3data.removeAll()
        kelas4data.removeAll()
        kelas5data.removeAll()
        kelas6data.removeAll()
        barstats.removeFromSuperview()
        stats.removeFromSuperview()
        stats2.removeFromSuperview()
        barstats.delegate = nil
        NotificationCenter.default.removeObserver(self, name: .windowControllerClose, object: nil)
    }
}

extension Stats {
    /// Notifikasi ketika ada window ditutup. Berguna ketika sheet ``Stats`` dihentikan.
    @objc func windowWillClose(_ notification: Notification) {
        dataEntries.removeAll()
    }
}

extension Stats: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let saves = menu.item(at: 1) {
            saves.isEnabled = false
            saves.isHidden = false
        }
        if let save = menu.item(at: 2) {
            if let title = pilihanSmstr1.titleOfSelectedItem {
                save.title = title
                save.isHidden = false
            } else {
                save.isHidden = true
            }
        }

        if let save1 = menu.item(at: 3) {
            if let title = pilihanSmstr2.titleOfSelectedItem {
                save1.title = title
                save1.isHidden = false
            } else {
                save1.isHidden = true
            }
        }
        if let saveOpt = menu.item(at: 4) {
            saveOpt.title = "\(kategoriTextField.stringValue)"
        }
    }
}
