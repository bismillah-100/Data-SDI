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
    /// Instance KelasViewModel.
    let viewModel: KelasViewModel = .shared

    /// Outlet untuk tabel kelas 1 hingga kelas 6
    @IBOutlet weak var table1: PaginatedTable!

    /// Outlet untuk scroll view yang membungkus ``resultTextView``
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk text view yang menampilkan hasil perhitungan
    @IBOutlet weak var resultTextView: NSTextView!

    /// Deprecated: Outlet untuk stack view untuk kolom.
    @IBOutlet weak var kolom: NSStackView!

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

    func numberOfRows(in _: NSTableView) -> Int {
        kelasPrint.count
    }

    func tableView(_: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if let identifier = tableColumn?.identifier {
            switch identifier {
            case NSUserInterfaceItemIdentifier("namasiswa"):
                tableColumn?.width = 330
                return kelasPrint[row].namasiswa
            case NSUserInterfaceItemIdentifier("mapel"):
                tableColumn?.width = 140
                return kelasPrint[row].mapel
            case NSUserInterfaceItemIdentifier("nilai"):
                let nilai = kelasPrint[row].nilai
                tableColumn?.width = 55
                return String(nilai)
            case NSUserInterfaceItemIdentifier("semester"):
                tableColumn?.width = 70
                return kelasPrint[row].semester
            case NSUserInterfaceItemIdentifier("namaguru"):
                tableColumn?.width = 245
                return kelasPrint[row].namaguru
            default:
                break
            }
        }
        return nil
    }

    func tableView(_: NSTableView,
                   willDisplayCell cell: Any,
                   for tableColumn: NSTableColumn?,
                   row: Int)
    {
        guard let identifier = tableColumn?.identifier,
              let textCell = cell as? NSTextFieldCell else { return }

        if identifier == .init("nilai"),
           let nilai = Int(kelasPrint[row].nilai)
        {
            textCell.textColor = (nilai < 60) ? .red : .labelColor
        } else {
            textCell.textColor = .labelColor
        }
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
        // Set the desired width for the stackView
        let stackViewWidth: CGFloat = 972
        // Set the frame size for the NSStackView
        let initialFrameForPrinting = NSRect(origin: .zero, size: NSSize(width: stackViewWidth, height: tableView.intrinsicContentSize.height))
        let stackView = NSStackView(frame: initialFrameForPrinting)
        // Calculate the adjusted width for the tableView
        let adjustedTableWidth = stackViewWidth - stackView.spacing * CGFloat(stackView.views.count - 1)

        let labelTextField = NSTextField(wrappingLabelWithString: label)
        labelTextField.font = NSFont.systemFont(ofSize: 16, weight: .black)
        stackView.addArrangedSubview(labelTextField)

        tableView.autoresizingMask = [.width]
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.frame.size.width = adjustedTableWidth
        stackView.addArrangedSubview(tableView)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(spacer)

        let ringkasanTextField = NSTextField(wrappingLabelWithString: "Ringkasan")
        ringkasanTextField.font = NSFont.systemFont(ofSize: 16, weight: .black)
        stackView.addArrangedSubview(ringkasanTextField)

        // Gunakan NSTextView untuk keterangan (non-scrollable)
        let keterangan = NSTextView()
        keterangan.isEditable = false
        keterangan.isSelectable = false
        keterangan.isVerticallyResizable = true
        keterangan.isHorizontallyResizable = false
        keterangan.drawsBackground = false
        keterangan.textContainerInset = NSSize(width: 0, height: 0)

        // Atur lebar dan tinggi
        keterangan.minSize = NSSize(width: adjustedTableWidth, height: 0)
        keterangan.maxSize = NSSize(width: adjustedTableWidth, height: .greatestFiniteMagnitude)
        keterangan.textContainer?.widthTracksTextView = true
        keterangan.textContainer?.heightTracksTextView = false

        // Ambil konten dari resultTextView
        if let attributedString = resultTextView.textStorage?.copy() as? NSAttributedString {
            keterangan.textStorage?.setAttributedString(attributedString)
        }

        // Hitung tinggi yang dibutuhkan
        keterangan.layoutManager?.ensureLayout(for: keterangan.textContainer!)
        let usedRect = keterangan.layoutManager?.usedRect(for: keterangan.textContainer!)
        let textHeight = usedRect?.height ?? 0

        // Tambahkan constraint tinggi
        keterangan.heightAnchor.constraint(equalToConstant: textHeight).isActive = true
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
        printOperation.jobTitle = label
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
            await s.viewModel.loadKelasData(forTableType: kelas)

            if let dataList = s.viewModel.kelasData[kelas] {
                for data in dataList.sorted() {
                    let kelasDataPrint = KelasPrint(
                        namasiswa: data.namasiswa,
                        mapel: data.mapel,
                        nilai: String(data.nilai),
                        namaguru: data.namaguru,
                        semester: data.semester
                    )
                    s.kelasPrint.append(kelasDataPrint)
                }
            }

            s.viewModel.updateTextViewWithCalculations(for: kelas, in: s.resultTextView)
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

    override func viewWillDisappear() {
        kelasPrint.removeAll()
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
