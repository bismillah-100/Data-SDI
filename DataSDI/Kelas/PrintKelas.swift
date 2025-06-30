//
//  PrintKelas.swift
//  Data Manager
//
//  Created by Bismillah on 05/11/23.
//
import Cocoa
import SQLite

/// Cetak data kelas ke printer.
class PrintKelas: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    /// Outlet untuk tabel kelas 1 hingga kelas 6
    @IBOutlet weak var table1: NSTableView!
    
    /// Outlet untuk scroll view yang membungkus ``resultTextView``
    @IBOutlet var scrollView: NSScrollView!
    /// Outlet untuk text view yang menampilkan hasil perhitungan
    @IBOutlet var resultTextView: NSTextView!

    /// Deprecated: Outlet untuk stack view untuk kolom.
    @IBOutlet weak var kolom: NSStackView!
    /// Data siswa yang akan ditampilkan
    var siswaData: [ModelSiswa] = []
    /// Database controller untuk mengelola koneksi database
    /// dan operasi terkait database.
    let dbController = DatabaseController.shared

    private(set) var kelasData: [KelasModels] = []
    
    /// Model kelas yang digunakan untuk menampung data kelas yang akan dicetak.
    var kelasPrint: [KelasPrint] = []

    /// Array untuk menyimpan informasi tentang tabel yang ada di tampilan.
    /// Setiap elemen berisi tuple yang terdiri dari tabel dan tipe tabel.
    /// Tipe tabel adalah enum yang mendefinisikan jenis kelas (kelas 1 hingga kelas 6).
    var tableInfo: [(table: NSTableView, type: TableType)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: STRUCTURE

    func numberOfRows(in tableView: NSTableView) -> Int {
        return kelasData.count + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("KelasCell"), owner: nil) as? NSTableCellView {
            if let textField = cell.textField {
                if let identifier = tableColumn?.identifier {
                    switch identifier {
                    case NSUserInterfaceItemIdentifier("namasiswa"):
                        textField.stringValue = kelasPrint[row].namasiswa
                        tableColumn?.width = 330
                    case NSUserInterfaceItemIdentifier("mapel"):
                        textField.stringValue = kelasPrint[row].mapel
                        tableColumn?.width = 140
                    case NSUserInterfaceItemIdentifier("nilai"):
                        let nilai = kelasPrint[row].nilai
                        textField.stringValue = String(nilai)
                        if let nilai = Int(nilai) {
                            textField.textColor = (nilai <= 59) ? NSColor.red : NSColor.black
                        }
                        tableColumn?.width = 55
                    case NSUserInterfaceItemIdentifier("semester"):
                        textField.stringValue = kelasPrint[row].semester
                        tableColumn?.width = 70
                    case NSUserInterfaceItemIdentifier("namaguru"):
                        textField.stringValue = kelasPrint[row].namaguru
                        cell.toolTip = "\(kelasPrint[row].namaguru)"
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

    // MARK: - OPERATION

    /// Fungsi untuk mencetak tabel yang diberikan dengan label tertentu.
    /// - Parameters:
    ///   - tableView: NSTableView yang akan dicetak.
    ///   - label: Label yang akan ditampilkan di atas tabel saat mencetak.
    /// - Note: Fungsi ini mengatur delegate dan dataSource untuk tabel, mengatur ukuran stackView, menambahkan label, dan mengonfigurasi opsi pencetakan.
    /// - Note: Fungsi ini juga mengatur margin, orientasi, dan faktor skala untuk pencetakan.
    /// - Note: Setelah selesai, fungsi ini menjalankan operasi pencetakan dan membersihkan operasi tersebut.
    /// - Note: Pastikan untuk memanggil fungsi ini pada thread utama (MainActor) untuk menghindari masalah UI.
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
        printInfo.paperSize = NSSize(width: stackViewWidth - printInfo.leftMargin - printInfo.rightMargin, height: printInfo.paperSize.height)

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
        dismiss(true)
    }

    /// Print Kelas 1
    func print(_ kelas: TableType) {
        Task { [weak self] in
            guard let s = self else { return }
            s.kelasData = await s.dbController.getAllKelas(ofType: kelas)
            s.kelasPrint = s.dbController.getKelasPrint(table: kelas.table) // dapatkan nilai-nilai kelas1print
            s.updateTextViewWithCalculations(forIndex: 0) // update kalkulasi nilai
            await MainActor.run { [weak self] in
                guard let s = self else { return }
                s.table1.delegate = self
                s.table1.dataSource = self
                let headerData1 = KelasPrint()
                headerData1.setHeaderData(namasiswa: "Nama Siswa", mapel: "Mata Pelajaran", nilai: "Nilai", semester: "Semester", namaguru: "Nama Guru")
                s.kelasPrint.insert(headerData1, at: 0)
                s.table1.reloadData()
                s.printTableView(s.table1, label: "Data Kelas \(kelas.rawValue + 1)")
            }
        }
    }
    
    /// Menulis nilai dari setiap siswa ke NSTextView (resultTextView)
    /// - Parameter index: Tentukan kelas sesuai index: Kelas 1 (0) - Kelas 6 (5)
    @objc func updateTextViewWithCalculations(forIndex index: Int) {
        let kelasModel = kelasData

        // Get all unique semesters
        let uniqueSemesters = Set(kelasModel.map(\.semester)).sorted { ReusableFunc.semesterOrder($0, $1) }

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
    func calculateRataRataNilaiPerMapel(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Membuat set unik dari semua mata pelajaran yang ada di semester tersebut.
        let uniqueMapels = Set(siswaSemester.map(\.mapel))

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
        kelasData.removeAll()
        for (table, _) in tableInfo {
            table.target = nil
            table.delegate = nil
            table.menu = nil // Hapus menu yang ditambahkan sebelumnya
            table.menu?.removeAllItems()
            table.dataSource = nil
            table.removeFromSuperviewWithoutNeedingDisplay()
        }
        table1.delegate = nil
        table1.dataSource = nil
        table1.removeFromSuperviewWithoutNeedingDisplay()
        resultTextView.delegate = nil
        resultTextView.removeFromSuperviewWithoutNeedingDisplay()
    }
}
