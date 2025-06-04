//
//  Stats.swift
//  Data Manager
//
//  Created by Bismillah on 08/11/23.
//

import Cocoa
import SQLite
import DGCharts

class Stats: NSViewController, ChartViewDelegate {
    @IBOutlet weak var stats: PieChartView!
    @IBOutlet weak var tutup: NSButton!
    @IBOutlet weak var stats2: PieChartView!
    @IBOutlet weak var barstats: BarChartView!
    @IBOutlet weak var pilihan: NSPopUpButton!
    @IBOutlet weak var verline: NSBox!
    @IBOutlet weak var kategoriTextField: NSTextField!
    // @IBOutlet weak var semuaNilaiWidth: NSLayoutConstraint!
    @IBOutlet weak var pieChartTop: NSLayoutConstraint! // default 35
    @IBOutlet weak var tutupTpConstraint: NSLayoutConstraint! // default 12
    var sheetWindow: Bool = false
    private var currentPopover: NSPopover?
    var dataEntries: [BarChartDataEntry] = []
    var dataEntries1: [ChartDataEntry] = []
    var dataEntries2: [ChartDataEntry] = []
    private let dbController = DatabaseController.shared
    private var kelas1data: [Kelas1Model] = []
    private var kelas2data: [Kelas2Model] = []
    private var kelas3data: [Kelas3Model] = []
    private var kelas4data: [Kelas4Model] = []
    private var kelas5data: [Kelas5Model] = []
    private var kelas6data: [Kelas6Model] = []
    @IBOutlet weak var pilihanCell: NSPopUpButtonCell!
    @IBOutlet weak var pilihanSmstr1: NSPopUpButton!
    @IBOutlet weak var pilihanSmstr2: NSPopUpButton!
    @IBOutlet weak var semuaNilai: NSPopUpButton!
    @IBOutlet weak var moreItem: NSMenuItem!
    var viewDitampilkan: Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        if let ve = view as? NSVisualEffectView {
            ve.blendingMode = .behindWindow
            ve.material = .windowBackground
            ve.state = .followsWindowActiveState
        }
        if sheetWindow {
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
        // Do view setup here.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            self.view.window?.makeFirstResponder(self)
        }
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: .windowControllerClose, object: nil)
        if !sheetWindow { setupToolbar() }
        if !viewDitampilkan { viewDitampilkan = true }
    }
    
//    @objc func tabBarDidHide(_ notification: Notification) {
//        guard let window = self.view.window,
//           let tabGroup = window.tabGroup,
//           !tabGroup.isTabBarVisible else {
//            return
//        }
//        if pieChartTop.constant != 35 {
//            DispatchQueue.main.async { [unowned self] in
//                pieChartTop.constant = 35
//                verLineTop.constant = 18
//                tutupTpConstraint.constant = 12
//            }
//        }
//    }
    
    // MARK: - Chart Methods
    @IBAction func muatUlang(_ sender: Any) {
        Task(priority: .background) { [weak self] in
            guard let self = self else {return}
            await self.updateData()
            await MainActor.run { [unowned self] in
                self.updateUI()
            }
        }
    }
    
    func updateData() async {
        // Reset bar chart data
        self.barstats.data = nil
        self.stats.data = nil
        self.stats2.data = nil
        
        // Jika Anda ingin mereset data entries secara keseluruhan
        self.dataEntries.removeAll()
        self.dataEntries1.removeAll()
        self.dataEntries2.removeAll()
        self.kelas1data = await self.dbController.getallKelas1()
        self.kelas2data = await self.dbController.getallKelas2()
        self.kelas3data = await self.dbController.getallKelas3()
        self.kelas4data = await self.dbController.getallKelas4()
        self.kelas5data = await self.dbController.getallKelas5()
        self.kelas6data = await self.dbController.getallKelas6()
    }
    
    func updateUI() {
        self.pilihanSmstr1.selectItem(withTitle: "Semester 1")
        self.pilihanSmstr2.selectItem(withTitle: "Semester 2")
        self.createPieChart()
        self.createPieChartSemester2()
        self.barstats.delegate = self
        self.populateSemesterPopUpButton()
        self.barstats.doubleTapToZoomEnabled = false
        self.pilihanSmstr1.selectItem(withTitle: "Semester 1")
        self.pilihanSmstr2.selectItem(withTitle: "Semester 2")
        self.selectedSemester1 = "Semester 1"
        self.selectedSemester2 = "Semester 2"
    }
    
    var selectedSemester1: String? = nil
    var selectedSemester2: String? = nil

    @IBAction func pilihanSemester1(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester1 else { return }
        selectedSemester1 = selectedTitle // Update setelah validasi
        
        stats.data = nil
        dataEntries1.removeAll() // Reset data
        stats.notifyDataSetChanged()
        createPieChart() // Update Pie Chart
    }

    @IBAction func pilihanSemester2(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester2 else { return }
        selectedSemester2 = selectedTitle // Update setelah validasi
        
        stats2.data = nil
        dataEntries2.removeAll() // Reset data
        stats2.notifyDataSetChanged()
        createPieChartSemester2() // Update Pie Chart
    }

    private func populateSemesterPopUpButton() {
        let kelasDataArrays: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]
        
        // Filter dan gabungkan semester yang tidak kosong
        let allSemesters: Set<String> = Set(kelasDataArrays.flatMap { $0.map { $0.semester }.filter { !$0.isEmpty } })
        
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
            updateDataEntries(selectedItems: selectedItems) {
                self.displayBarChart()
            }
            kategoriTextField.stringValue = "Nilai rata-rata Semester 1 & 2"
        }
    }
    private func displayBarChart() {
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            // Create a dataset for the bar chart with the class labels
            let classLabels = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6"]

            // Create an array to store the data sets for each class

            // Create a set to track the colors that have been used
            var usedColors: Set<NSColor> = []
            let classColors: [NSColor] = [
                NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0),  // Warna hijau yang lebih terang
                NSColor(calibratedRed: 246.0/255.0, green: 161.0/255.0, blue: 81.0/255.0, alpha: 1.0),  // Warna kuning yang lebih pekat
                NSColor(red: 66.0/255.0, green: 133.0/255.0, blue: 244.0/255.0, alpha: 1.0),  // Warna biru yang lebih terang
                NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),  // Warna ungu yang lebih terang
                NSColor(red: 0.8, green: 0.5, blue: 0.6, alpha: 1.0),  // Warna merah muda yang lebih terang
                NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)   // Warna abu-abu yang lebih terang
            ]
            var dataSets: [BarChartDataSet] = []
            // Create a data set for each class and assign unique colors
            for (i, className) in classLabels.enumerated() {
                let color: NSColor
                if i < classLabels.count {
                    color = classColors[i]
                } else {
                    color = NSColor.systemPink
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
            for entry in dataEntries {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [unowned self] in
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
//                self.barstats.animate(xAxisDuration: 1.5, yAxisDuration: 1.5)
            }
        }
    }
    private func createPieChart() {
        let selectedSemester = pilihanSmstr1.titleOfSelectedItem ?? "Semester 1"
        var formattedSemester = selectedSemester
        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        let classColors: [NSColor] = [
            NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0),
            NSColor(calibratedRed: 246.0/255.0, green: 161.0/255.0, blue: 81.0/255.0, alpha: 1.0),  // Warna kuning yang lebih pekat
            NSColor(red: 66.0/255.0, green: 133.0/255.0, blue: 244.0/255.0, alpha: 1.0),
            NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.8, green: 0.5, blue: 0.6, alpha: 1.0),
            NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        ]
        DispatchQueue.global(qos: .background).async { [unowned self] in
            let kelasDataArray: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]
            for (index, kelas) in kelasDataArray.enumerated() {
                let siswaSemester: [KelasModels] = kelas.filter { $0.semester == formattedSemester }
                let totalRataRataKelas = calculateTotalRataRata(siswaSemester)
                var entryLabel: String
                if index == 5 {  // Index 5 adalah kelas 6
                    entryLabel = "Kls. 6"
                } else {
                    entryLabel = "Kls. \(index + 1)"
                }

                // Tambahkan entry dengan nilai 0 jika tidak ada data
                let entryValue = totalRataRataKelas > 0 ? totalRataRataKelas : 0
                let entry = PieChartDataEntry(value: entryValue, label: entryLabel)
                dataEntries1.append(entry)
            }
            DispatchQueue.main.async { [unowned self] in
                let dataSet = PieChartDataSet(entries: dataEntries1, label: "")
                dataSet.colors = classColors
                
                let data = PieChartData(dataSet: dataSet)
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = .center
                let centerText: NSMutableAttributedString = NSMutableAttributedString(string: "\(selectedSemester)\nRerata Nilai")
                centerText.setAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 15.0)!, NSAttributedString.Key.paragraphStyle: paragraphStyle], range: NSMakeRange(0, centerText.length))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-Light", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor.gray], range: NSMakeRange(10, centerText.length - 10))
                centerText.addAttributes([NSAttributedString.Key.font: NSFont(name: "HelveticaNeue-LightItalic", size: 13.0)!, NSAttributedString.Key.foregroundColor: NSColor(red: 51 / 255.0, green: 181 / 255.0, blue: 229 / 255.0, alpha: 1.0)], range: NSMakeRange(centerText.length - 0, 0))
                self.stats.centerAttributedText = centerText
                
                self.stats.data = data
                
                // dataSet.valueTextColor = NSColor.controlTextColor // Mengatur warna teks nilai
                dataSet.valueFormatter = DefaultValueFormatter(formatter: NumberFormatter())
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 2 // Menentukan jumlah minimum desimal
                formatter.maximumFractionDigits = 2 // Menentukan jumlah maksimum desimal
                dataSet.valueFormatter = DefaultValueFormatter(formatter: formatter)
                // dataSet.drawValuesEnabled = true
                
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
    private func createPieChartSemester2() {
        let selectedSemester = pilihanSmstr2.titleOfSelectedItem ?? "Semester 2"
        var formattedSemester = selectedSemester

        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        let classColors: [NSColor] = [
            NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0),
            NSColor(calibratedRed: 246.0/255.0, green: 161.0/255.0, blue: 81.0/255.0, alpha: 1.0),  // Warna kuning yang lebih pekat
            NSColor(red: 66.0/255.0, green: 133.0/255.0, blue: 244.0/255.0, alpha: 1.0),
            NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.8, green: 0.5, blue: 0.6, alpha: 1.0),
            NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        ]
        DispatchQueue.global(qos: .background).async { [unowned self] in
            let kelasDataArray: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]
            for (index, kelas) in kelasDataArray.enumerated() {
                let siswaSemester: [KelasModels] = kelas.filter { $0.semester == formattedSemester }
                let totalRataRataKelas = calculateTotalRataRata(siswaSemester)
                var entryLabel: String
                if index == 5 {  // Index 5 adalah kelas 6
                    entryLabel = "Kls. 6"
                } else {
                    entryLabel = "Kls. \(index + 1)"
                }

                // Tambahkan entry dengan nilai 0 jika tidak ada data
                let entryValue = totalRataRataKelas > 0 ? totalRataRataKelas : 0
                let entry = PieChartDataEntry(value: entryValue, label: entryLabel)
                dataEntries2.append(entry)
            }
            DispatchQueue.main.async { [unowned self] in
                let dataSet = PieChartDataSet(entries: dataEntries2, label: "")
                dataSet.colors = classColors
                
                let data = PieChartData(dataSet: dataSet)
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = .center
                let centerText: NSMutableAttributedString = NSMutableAttributedString(string: "\(selectedSemester)\nRerata Nilai")
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

    @IBAction func tutupchart(_ sender: Any) {
        if let sheetWindow = NSApplication.shared.mainWindow?.attachedSheet {
            NSApplication.shared.mainWindow?.endSheet(sheetWindow)
            sheetWindow.orderOut(nil)
        }
    }
    @IBAction func simpanchart(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 3)?.title ?? "")"
        panel.beginSheetModal(for: self.view.window!) { (result) -> Void in
            if result == NSApplication.ModalResponse.OK
            {
                if let path = panel.url?.path
                {
                    let _ = self.barstats.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }
    @IBAction func smstr1(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 1)?.title ?? "")"
        panel.beginSheetModal(for: self.view.window!) { (result) -> Void in
            if result == NSApplication.ModalResponse.OK
            {
                if let path = panel.url?.path
                {
                    let _ = self.stats.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }
    @IBAction func smstr2(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 2)?.title ?? "")"
        panel.beginSheetModal(for: self.view.window!) { (result) -> Void in
            if result == NSApplication.ModalResponse.OK
            {
                if let path = panel.url?.path
                {
                    let _ = self.stats2.save(to: path, format: .png, compressionQuality: 1.0)
                }
            }
        }
    }
    @IBAction func pilihanSemuaNilai(_ sender: NSPopUpButton) {
        if currentPopover != nil {
            currentPopover?.close()
            self.view.window?.becomeFirstResponder()
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
        } else if selectedItem == "Semua Kategori & Semester" && items.first(where: { $0.state == .on && $0.title != "Semua Kategori & Semester" }) != nil {
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
            .map { $0.element.title }

        
        updateDataEntries(selectedItems: items.filter { $0.state == .on }.map { $0.title }) { [unowned self] in
            barstats.notifyDataSetChanged()
            displayBarChart()
            updateKategoriTextField(with: selectedItems)
            
        }
    }

    private func updateDataEntries(selectedItems: [String], completion: @escaping() -> Void) {
        Task(priority: .background) { [unowned self] in
            // Reset dataEntries
            dataEntries.removeAll()
            
            // Jika "Semua Kategori & Semester" ada dalam pilihan
            if selectedItems.contains("Semua Kategori & Semester") {
                // Tambahkan data untuk semua kelas
                dataEntries.append(calculateTotalNilaiForClass(kelas1data, className: "Kelas 1"))
                dataEntries.append(calculateTotalNilaiForClass(kelas2data, className: "Kelas 2"))
                dataEntries.append(calculateTotalNilaiForClass(kelas3data, className: "Kelas 3"))
                dataEntries.append(calculateTotalNilaiForClass(kelas4data, className: "Kelas 4"))
                dataEntries.append(calculateTotalNilaiForClass(kelas5data, className: "Kelas 5"))
                dataEntries.append(calculateTotalNilaiForClass(kelas6data, className: "Kelas 6"))
            } else {
                let kelasDataArray: [([KelasModels], String)] = [
                    (kelas1data, "Kelas 1"),
                    (kelas2data, "Kelas 2"),
                    (kelas3data, "Kelas 3"),
                    (kelas4data, "Kelas 4"),
                    (kelas5data, "Kelas 5"),
                    (kelas6data, "Kelas 6")
                ]
                
                // Proses data berdasarkan kategori yang dipilih
                for (kelas, className) in kelasDataArray {
                    var totalNilai: Double = 0
                    var totalSiswa: Int = 0
                    
                    for selectedItem in selectedItems {
                        let formattedSemester = selectedItem.split(separator: " ").last ?? "1"
                        let siswaSemester = kelas.filter { $0.semester == formattedSemester }
                        totalNilai += siswaSemester.reduce(0) { $0 + Double($1.nilai) }
                        totalSiswa += siswaSemester.count
                    }
                    
                    let rataRataNilai = totalSiswa > 0 ? totalNilai / Double(totalSiswa) : 0.0
                    let index = kelasDataArray.firstIndex { $0.1 == className } ?? 0
                    let entry = BarChartDataEntry(x: Double(index), y: rataRataNilai, data: className)
                    dataEntries.append(entry)
                    
                    // Tambahkan entri kosong untuk kelas yang tidak memiliki data
                }
            }
            
            await MainActor.run {
                completion()
            }
        }
    }

    private func calculateTotalRataRata(_ siswaSemester: [KelasModels]) -> Double {
        var totalRataRata: Double = 0
        for siswa in siswaSemester {
            totalRataRata += Double(siswa.nilai)
        }
        return totalRataRata / Double(siswaSemester.count)
    }

    private func calculateTotalNilai(forKelas kelas: [KelasModels]) -> Int {
        var jumlah = 0
        for siswa in kelas {
            jumlah += Int(siswa.nilai)
        }
        return jumlah
    }

    private func calculateTotalNilaiForClass(_ kelas: [KelasModels], className: String) -> BarChartDataEntry {
        // Calculate the total nilai for the class
        let totalNilai = calculateTotalNilai(forKelas: kelas)
        
        // Calculate the rata-rata nilai per siswa dalam kelas
        let rataRataNilai = kelas.isEmpty ? 0.0 : Double(totalNilai) / Double(kelas.count)
        
        // Create a data entry for the class using the rata-rata nilai and class name
        let classEntry = BarChartDataEntry(x: Double(dataEntries.count), y: rataRataNilai, data: className)
        
        return classEntry
    }
    
    private func semesterOrder(_ semester1: String, _ semester2: String) -> Bool {
        if semester1 == "1" { return true }
        if semester2 == "1" { return false }
        if semester1 == "2" { return true }
        if semester2 == "2" { return false }
        return semester1 < semester2
    }

    // Function to format semester names
    private func formatSemesterName(_ semester: String) -> String {
        switch semester {
        case "1":
            return "Semester 1"
        case "2":
            return "Semester 2"
        default:
            return "\(semester)"
        }
    }
    internal func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        guard let _ = chartView.data?.dataSets[highlight.dataSetIndex] as? BarChartDataSet,
              let className = entry.data as? String else {
            return
        }

        // Mengubah entry.y menjadi string dengan format 2 desimal
        let formattedValue = String(format: "%.2f", entry.y)
        
        

        showPopoverFor(className: className, nilai: formattedValue)
    }
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

            // Hitung ulang origin agar popover muncul di tempat yang diklik
            let mouseLocation = NSEvent.mouseLocation
            guard let window = self.view.window else { return }
            let windowLocation = window.convertPoint(fromScreen: mouseLocation) // Koordinat lokal jendela
            let viewLocation = self.view.convert(windowLocation, from: nil)     // Koordinat lokal view

            // Tentukan rect untuk lokasi popover
            let rect = NSRect(x: viewLocation.x - 1, y: viewLocation.y + 5.2, width: 1, height: 1)

            // Tampilkan popover di lokasi mouse
            popover.show(relativeTo: rect, of: self.view, preferredEdge: .maxY)

            popover.behavior = .semitransient
            currentPopover = popover
            self.view.window?.makeFirstResponder(currentPopover?.contentViewController?.view.window)
        }
    }
    
    private func updateKategoriTextField(with selectedItems: [String]) {
        var text = String()
        Task(priority: .background) { [unowned self] in
            // Gabungkan item yang dipilih, format sesuai kebutuhan
            text = await self.groupItemsByBaseName(Array(Set(selectedItems))).joined(separator: " & ")
            await MainActor.run { [unowned self] in
                self.kategoriTextField.stringValue = text
            }
        }
    }

    private func groupItemsByBaseName(_ items: [String]) async -> [String] {
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

    func setupToolbar() {
        if let toolbar = self.view.window?.toolbar {
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
               let popUpButtom = popUpMenuToolbarItem.view as? NSPopUpButton {
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
            save.title = "\(pilihanSmstr1.titleOfSelectedItem ?? "Tdk. ada item terpilih")"
        }
        
        if let save1 = menu.item(at: 3) {
            save1.title = "\(pilihanSmstr2.titleOfSelectedItem ?? "Tdk. ada item terpilih")"
        }
        if let saveOpt = menu.item(at: 4) {
            saveOpt.title = "\(kategoriTextField.stringValue)"
        }
    }
}
