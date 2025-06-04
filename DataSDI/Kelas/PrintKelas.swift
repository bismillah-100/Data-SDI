//
//  PrintKelas.swift
//  Data Manager
//
//  Created by Bismillah on 05/11/23.
//
import Cocoa
import SQLite
/// @Group Kelas / Tampilan Pendukung
/// Cetak data kelas ke printer
class PrintKelas: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var table1: NSTableView!
    @IBOutlet weak var table2: NSTableView!
    @IBOutlet weak var table3: NSTableView!
    @IBOutlet weak var table4: NSTableView!
    @IBOutlet weak var table5: NSTableView!
    @IBOutlet weak var table6: NSTableView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var resultTextView: NSTextView!
    @IBOutlet weak var kolom: NSStackView!
    var siswaData: [ModelSiswa] = []
    let dbController = DatabaseController.shared
    var clickedRow: Int?
    var db: Connection!
    var kelasModel: [KelasModel] = []
    var kelas1data: [Kelas1Model] = []
    var kelas2data: [Kelas2Model] = []
    var kelas3data: [Kelas3Model] = []
    var kelas4data: [Kelas4Model] = []
    var kelas5data: [Kelas5Model] = []
    var kelas6data: [Kelas6Model] = []
    var kelas1print: [Kelas1Print] = []
    var kelas2print: [Kelas2Print] = []
    var kelas3print: [Kelas3Print] = []
    var kelas4print: [Kelas4Print] = []
    var kelas5print: [Kelas5Print] = []
    var kelas6print: [Kelas6Print] = []
    var selectedTable: NSTableView?
    var tableInfo: [(table: NSTableView, type: TableType)] = []
    var data: KelasModels!
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK STRUCTURE
    func tableType(forTableView tableView: NSTableView) -> TableType? {
        switch tableView {
        case table1:
            return .kelas1
        case table2:
            return .kelas2
        case table3:
            return .kelas3
        case table4:
            return .kelas4
        case table5:
            return .kelas5
        case table6:
            return .kelas6
        default:
            return nil
        }
    }
    enum TableType {
        case kelas1
        case kelas2
        case kelas3
        case kelas4
        case kelas5
        case kelas6
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == table1 {
            return kelas1data.count + 1
        } else if tableView == table2 {
            return kelas2data.count + 1
        } else if tableView == table3 {
            return kelas3data.count + 1
        } else if tableView == table4 {
            return kelas4data.count + 1
        } else if tableView == table5 {
            return kelas5data.count + 1
        } else if tableView == table6 {
            return kelas6data.count + 1
        }
        return 0
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                if let identifier = tableColumn?.identifier {
                    switch identifier {
                    case NSUserInterfaceItemIdentifier("namasiswa"):
                        textField.stringValue = kelasModelForTableView(tableView)[row].namasiswa
                        tableColumn?.width = 330
                    case NSUserInterfaceItemIdentifier("mapel"):
                        textField.stringValue = kelasModelForTableView(tableView)[row].mapel
                        tableColumn?.width = 140
                    case NSUserInterfaceItemIdentifier("nilai"):
                        let nilai = kelasModelForTableView(tableView)[row].nilai
                        textField.stringValue = String(nilai)
                        if let nilai = Int(nilai) {
                            textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.black
                        }
                        tableColumn?.width = 55
                    case NSUserInterfaceItemIdentifier("semester"):
                        textField.stringValue = kelasModelForTableView(tableView)[row].semester
                        tableColumn?.width = 70
                    case NSUserInterfaceItemIdentifier("namaguru"):
                        textField.stringValue = kelasModelForTableView(tableView)[row].namaguru
                        cell.toolTip = "\(kelasModelForTableView(tableView)[row].namaguru)"
                        tableColumn?.width = 245
                    default:
                        break
                    }
                }
            }
            return cell
        }

        return nil
    }

    func kelasModelForTableView(_ tableView: NSTableView) -> [KelasPrint] {
        switch tableView {
        case table1:
            return kelas1print
        case table2:
            return kelas2print
        case table3:
            return kelas3print
        case table4:
            return kelas4print
        case table5:
            return kelas5print
        case table6:
            return kelas6print
        default:
            return []
        }
    }
    // MARK: - OPERATION
    func printTableView(_ tableView: NSTableView, label: String) {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
        // Set the desired width for the stackView
        let stackViewWidth: CGFloat = 972
        // Set the frame size for the NSStackView
        let initialFrameForPrinting = NSRect(origin: .zero, size: NSSize(width: stackViewWidth, height: tableView.intrinsicContentSize.height))
        let stackView = NSStackView(frame: initialFrameForPrinting)
        // Calculate the adjusted width for the tableView
        let adjustedTableWidth = stackViewWidth - stackView.spacing * CGFloat(stackView.views.count - 1)
        
        
        let labelTextField = NSTextField(wrappingLabelWithString: label)
        stackView.addArrangedSubview(labelTextField)
        labelTextField.font = NSFont.systemFont(ofSize: 16, weight: .black)
        
        tableView.autoresizingMask = [.width]
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.frame.size.width = adjustedTableWidth
        stackView.addArrangedSubview(tableView)
        
        let box = NSBox(frame: NSRect(x: stackView.frame.origin.x, y: stackView.frame.origin.y, width: stackView.frame.width, height: 0.6))
        box.boxType = .custom
        box.borderColor = .black
        box.fillColor = .black
        stackView.addArrangedSubview(box)
        
        let keterangan = NSTextField(wrappingLabelWithString: resultTextView.string)
        stackView.addArrangedSubview(keterangan)
        
        stackView.appearance = NSAppearance(named: .aqua)
        stackView.orientation = .vertical
        stackView.alignment = .left
        stackView.distribution = .fill
        stackView.autoresizesSubviews = true
        stackView.autoresizingMask = [.height, .width]
        stackView.spacing = 8
        
        stackView.layoutSubtreeIfNeeded()
        
        let printOpts: [NSPrintInfo.AttributeKey: Any] = [.headerAndFooter: false, .orientation: 0]
        let printInfo = NSPrintInfo(dictionary: printOpts)
        
        // Set the desired width for the paper
        printInfo.paperSize = NSSize(width: stackViewWidth - printInfo.leftMargin - printInfo.rightMargin,  height: printInfo.paperSize.height)
        
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.horizontalPagination = .clip
        printInfo.verticalPagination = .automatic
        printInfo.scalingFactor = 0.9
        printInfo.orientation = .landscape
        
        let printOperation = NSPrintOperation(view: stackView, printInfo: printInfo)
        let printPanel = printOperation.printPanel
        printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
        if let mainWindow = NSApplication.shared.mainWindow {
            printOperation.runModal(for: mainWindow, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            // Handle the case when the main window is nil
            
        }
        printOperation.cleanUp()
        self.dismiss(true)
    }
    
    /// Print Kelas 1
    func prnt1() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas1data = await s.dbController.getallKelas1() // dapatkan nilai-nilai siswa
            s.kelas1print = s.dbController.getKelas1Print() // dapatkan nilai-nilai kelas1print
            s.updateTextViewWithCalculations(forIndex: 0) // update kalkulasi nilai
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table1.delegate = self
                s.table1.dataSource = self
                let headerData1 = Kelas1Print()
                headerData1.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas1print.insert(headerData1, at: 0)
                s.table1.reloadData()
                s.printTableView(s.table1, label: "Data Kelas 1")
            }
        }
    }
    /// Print Kelas 2
    func printkls2() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas2data = await s.dbController.getallKelas2()
            s.kelas2print = s.dbController.getKelas2Print()
            s.updateTextViewWithCalculations(forIndex: 1)
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table2.delegate = self
                s.table2.dataSource = self
                s.table2.reloadData()
                let headerData2 = Kelas2Print()
                headerData2.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas2print.insert(headerData2, at: 0)
                s.printTableView(s.table2, label: "Data Kelas 2")

            }
        }
    }
    func printkls3() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas3data = await s.dbController.getallKelas3()
            s.kelas3print = s.dbController.getKelas3Print()
            s.updateTextViewWithCalculations(forIndex: 2)
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table3.delegate = self
                s.table3.dataSource = self
                s.table3.reloadData()
                let headerData3 = Kelas3Print()
                headerData3.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas3print.insert(headerData3, at: 0)
                s.printTableView(s.table3, label: "Data Kelas 3")
            }
        }
    }
    func printkls4() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas4data = await s.dbController.getallKelas4()
            s.kelas4print = s.dbController.getKelas4Print()
            s.updateTextViewWithCalculations(forIndex: 3)
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table4.delegate = self
                s.table4.dataSource = self
                s.table4.reloadData()
                let headerData4 = Kelas4Print()
                headerData4.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas4print.insert(headerData4, at: 0)
                s.printTableView(s.table4, label: "Data Kelas 4")
            }
        }
    }
    func printkls5() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas5data = await s.dbController.getallKelas5()
            s.kelas5print = s.dbController.getKelas5Print()
            s.updateTextViewWithCalculations(forIndex: 4)
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table5.delegate = self
                s.table5.dataSource = self
                s.table5.reloadData()
                let headerData5 = Kelas5Print()
                headerData5.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas5print.insert(headerData5, at: 0)
                s.printTableView(s.table5, label: "Data Kelas 5")
            }
        }
    }
    func printkls6() {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelas6data = await s.dbController.getallKelas6()
            s.kelas6print = s.dbController.getKelas6Print()
            s.updateTextViewWithCalculations(forIndex: 5)
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table6.delegate = self
                s.table6.dataSource = self
                s.table6.reloadData()
                let headerData6 = Kelas6Print()
                headerData6.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelas6print.insert(headerData6, at: 0)
                s.printTableView(s.table6, label: "Data Kelas 6")
            }
        }
    }
    
    
    /// Menulis nilai dari setiap siswa ke NSTextView (resultTextView)
    /// - Parameter index: Tentukan kelas sesuai index: Kelas 1 (0) - Kelas 6 (5)
    @objc func updateTextViewWithCalculations(forIndex index: Int) {
        var kelasModel = [KelasModels]()
        switch index {
        case 0:
            kelasModel = kelas1data
        case 1:
            kelasModel = kelas2data
        case 2:
            kelasModel = kelas3data
        case 3:
            kelasModel = kelas4data
        case 4:
            kelasModel = kelas5data
        case 5:
            kelasModel = kelas6data
        default:
            break
        }

        // Get all unique semesters
        let uniqueSemesters = Set(kelasModel.map { $0.semester }).sorted { ReusableFunc.semesterOrder($0, $1) }

        // Initialize the text view string
        var resultText = "Jumlah Nilai Semua Semester: \(calculateTotalNilai(forKelas: kelasModel))\n\n"

        // Process each semester
        for semester in uniqueSemesters {
            let formattedSemester = ReusableFunc.formatSemesterName(semester)
            let (totalNilai, topSiswa) = calculateTotalAndTopSiswa(forKelas: kelasModel, semester: semester)
            if let rataRataNilaiUmum = calculateRataRataNilaiUmumKelas(forKelas: kelasModel, semester: semester) {
                resultText += """
                Jumlah Nilai \(formattedSemester): \(totalNilai)\n
                Rata-rata Nilai Umum \(formattedSemester): \(rataRataNilaiUmum)
                \(topSiswa.joined(separator: "\n"))\n
                Rata-rata Nilai Per Mapel \(formattedSemester):
                \(calculateRataRataNilaiPerMapel(forKelas: kelasModel, semester: semester) ?? "")\n\n
                
                """
            }
        }
        // Update the resultTextView with the combined results
        resultTextView.string = resultText
    }
    
    
    /// Jumlah Nilai keseluruhan kelas di semua semester
    /// - Parameter kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    /// - Returns: Mengembalikan nilai dalam format nilai Int
    func calculateTotalNilai(forKelas kelas: [KelasModels]) -> Int {
        var total = 0
        for siswa in kelas {
            total += Int(siswa.nilai)
        }
        return total
    }
    
    
    /// Jumlah nilai siswa di kelas tertentu untuk semester tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai yang dikalkukasi dalam format Array [Int64, [String]]
    func calculateTotalAndTopSiswa(forKelas kelas: [KelasModels], semester: String) -> (totalNilai: Int64, topSiswa: [String]) {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }
        
        // Calculate total nilai for the selected semester
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }
        
        // Calculate top siswa for the selected semester
        let topSiswa = calculateTopSiswa(forKelas: siswaSemester, semester: semester)
        
        return (totalNilai, topSiswa)
    }
    
    
    /// Mengkalkulasi nilai semester tertentu setiap siswa di data kelas tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai yang dikalkulasi dalam format Array String (namaSiswa, jumlahNilai, Rata-rata)
    func calculateTopSiswa(forKelas kelas: [KelasModels], semester: String) -> [String] {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }
        
        // Hitung jumlah nilai dan rata-rata untuk setiap siswa.
        var nilaiSiswaDictionary: [String: (totalNilai: Int64, jumlahSiswa: Int64)] = [:]
        for siswa in siswaSemester {
            if var siswaData = nilaiSiswaDictionary[siswa.namasiswa] {
                siswaData.totalNilai += siswa.nilai
                siswaData.jumlahSiswa += 1
                nilaiSiswaDictionary[siswa.namasiswa] = siswaData
            } else {
                nilaiSiswaDictionary[siswa.namasiswa] = (totalNilai: siswa.nilai, jumlahSiswa: 1)
            }
        }
        // Urutkan siswa berdasarkan total nilai dari yang tertinggi ke terendah.
        let sortedSiswa = nilaiSiswaDictionary.sorted { $0.value.totalNilai > $1.value.totalNilai }
        
        // Kembalikan hasil dalam format yang sesuai.
        var result: [String] = []
        for (namaSiswa, dataSiswa) in sortedSiswa {
            let totalNilai = dataSiswa.totalNilai
            let jumlahSiswa = dataSiswa.jumlahSiswa
            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)
            result.append("・ \(namaSiswa) (Jumlah Nilai: \(totalNilai), Rata-rata Nilai: \(formattedRataRataNilai))")
        }
        return result
    }
    
    
    /// Rata-rata nilai umum untuk kelas dan semester tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai rata-rata yang telah dikalkulasi dalam format string. nilai ini opsional dan bisa mengembalikan nil.
    func calculateRataRataNilaiUmumKelas(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }
        
        // Jumlah total nilai untuk semua siswa pada semester tersebut.
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }
        
        // Jumlah siswa pada semester tersebut.
        let jumlahSiswa = siswaSemester.count
        
        // Hitung rata-rata nilai umum kelas untuk semester tersebut.
        guard jumlahSiswa > 0 else {
            return nil // Menghindari pembagian oleh nol.
        }
        
        let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)
        
        // Mengubah nilai rata-rata menjadi format dua desimal
        let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)
        
        return formattedRataRataNilai
    }
    
    
    /// Kalkulasi nilai rata-rata mata pelajaran untuk kelas dengan model data yang dikirim
    /// - Parameters:
    ///   - kelas: Ini adalah model data KelasModels yang menampung semua data siswa. data ini digunakan untuk kalkulasi.
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai rata-rata mata pelajaran yang telah dikalkulasi dalam format string. nilai ini opsional dan bisa mengembalikan nil.
    private func calculateRataRataNilaiPerMapel(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Membuat set unik dari semua mata pelajaran yang ada di semester tersebut.
        let uniqueMapels = Set(siswaSemester.map { $0.mapel })

        // Dictionary untuk menyimpan hasil per-mapel.
        var totalNilaiPerMapel: [String: Int] = [:]
        var jumlahSiswaPerMapel: [String: Int] = [:]

        // Menghitung total nilai per-mapel dan jumlah siswa per-mapel.
        for mapel in uniqueMapels {
            // Filter siswa berdasarkan mata pelajaran.
            let siswaMapel = siswaSemester.filter { $0.mapel == mapel }

            // Jumlah total nilai untuk semua siswa pada mata pelajaran tersebut.
            let totalNilai = siswaMapel.reduce(0) { $0 + $1.nilai }

            // Jumlah siswa pada mata pelajaran tersebut.
            let jumlahSiswa = siswaMapel.count

            // Menyimpan hasil total nilai dan jumlah siswa per-mapel.
            totalNilaiPerMapel[mapel] = totalNilaiPerMapel[mapel, default: 0] + Int(totalNilai)
            jumlahSiswaPerMapel[mapel] = jumlahSiswaPerMapel[mapel, default: 0] + jumlahSiswa
        }

        // Menghitung rata-rata nilai per-mapel.
        var rataRataPerMapel: [String: String] = [:]
        for mapel in uniqueMapels {
            guard let totalNilai = totalNilaiPerMapel[mapel], let jumlahSiswa = jumlahSiswaPerMapel[mapel], jumlahSiswa > 0 else {
                rataRataPerMapel[mapel] = "Data tidak tersedia"
                continue
            }

            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)

            // Mengubah nilai rata-rata menjadi format dua desimal.
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)

            // Menyimpan hasil rata-rata per-mapel dengan paragraf baru.
            rataRataPerMapel[mapel] = formattedRataRataNilai
        }

        // Menggabungkan hasil rata-rata per-mapel dengan paragraf baru.
        let resultString = rataRataPerMapel.map { "・ \($0.key): \($0.value)" }.joined(separator: "\n")

        return resultString
    }

    override func viewWillDisappear() {
        kelas1data.removeAll()
        kelas2data.removeAll()
        kelas3data.removeAll()
        kelas4data.removeAll()
        kelas5data.removeAll()
        kelas6data.removeAll()
        for (table, _) in tableInfo {
            table.target = nil
            table.delegate = nil
            table.menu = nil // Hapus menu yang ditambahkan sebelumnya
            table.menu?.removeAllItems()
            table.dataSource = nil
            table.removeFromSuperviewWithoutNeedingDisplay()
        }
        table1.delegate = nil
        table2.delegate = nil
        table3.delegate = nil
        table4.delegate = nil
        table5.delegate = nil
        table6.delegate = nil
        table1.dataSource = nil
        table2.dataSource = nil
        table3.dataSource = nil
        table4.dataSource = nil
        table5.dataSource = nil
        table6.dataSource = nil
        table1.removeFromSuperviewWithoutNeedingDisplay()
        table2.removeFromSuperviewWithoutNeedingDisplay()
        table3.removeFromSuperviewWithoutNeedingDisplay()
        table4.removeFromSuperviewWithoutNeedingDisplay()
        table5.removeFromSuperviewWithoutNeedingDisplay()
        table6.removeFromSuperviewWithoutNeedingDisplay()
        resultTextView.delegate = nil
        resultTextView.removeFromSuperviewWithoutNeedingDisplay()
    }
}
