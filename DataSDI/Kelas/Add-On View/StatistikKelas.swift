//
//  StatistikKelas.swift
//  Chart
//
//  Created by Bismillah on 06/11/23.
//

import Cocoa

/// Tampilan jumlah nilai kelas dan semester 1 dan 2 dalam grafis.
class StatistikKelas: NSView {
    /// Outlet title deskripsi.
    @IBOutlet weak var title: NSTextField!

    /// Array tuple untuk menyimpan data dari database.
    var kelasChartData: [(kelas: String, semester: String, value: Double)] = []

    /// Properti ini diset ke true saat ``ContainerSplitView/currentContentController``
    /// adalah ``KelasHistoryVC``. Default: false.
    var arsipKelas: Bool = false

    /// Properti ini diset dari ``StatistikViewController``
    /// saat ``ContainerSplitView/currentContentController``
    /// adalah ``KelasHistoryVC``. Default: nil.
    var tahunAjaran: String?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !kelasChartData.isEmpty else { return }

        // Hitung lebar maksimum untuk grafik yang lebih kecil
        let maxBarHeight: CGFloat = 320.0
        drawChart(in: dirtyRect, maxBarHeight: maxBarHeight)
        drawLegend(in: dirtyRect)
    }

    /// Menggambar grafik batang berdasarkan data `kelasChartData`.
    ///
    /// Fungsi ini menghitung tinggi dan posisi setiap batang berdasarkan nilai data
    /// relatif terhadap nilai tertinggi keseluruhan. Warna batang ditentukan berdasarkan
    /// semester atau kelas. Label nilai ditampilkan secara vertikal di atas setiap batang.
    ///
    /// - Parameters:
    ///   - rect: `NSRect` yang menunjukkan area menggambar yang tersedia.
    ///   - maxBarHeight: Tinggi maksimum yang diizinkan untuk batang grafik.
    private func drawChart(in rect: NSRect, maxBarHeight _: CGFloat) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        guard !kelasChartData.isEmpty else { return }

        let groupedData = Dictionary(grouping: kelasChartData, by: { $0.kelas })

        // menyiapkan variabel untuk menyimpan nilai tertinggi masing-masing kelas
        var maxValuesByKelas: [String: Double] = [:]

        // Iterasi melalui data yang dikelompokkan
        for (kelas, data) in groupedData {
            // Cari nilai tertinggi dalam data kelas saat ini
            let maxNilaiKelas = data.map(\.value).max() ?? 0.0
            maxValuesByKelas[kelas] = maxNilaiKelas
        }
        let maxTotalValue = maxValuesByKelas.values.max() ?? 0.0
        let maxHeightLimit: CGFloat = 220.0 // Ubah tinggi maksimum ke 200
        let maxBarWidth: CGFloat = 27.0

        // Hitung lebar setiap batang
        let barWidth = min(maxBarWidth, (rect.size.width - 20.0) / CGFloat(kelasChartData.count / 3))

        // let classNames = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6"]
        // let classNameFont = NSFont.systemFont(ofSize: 12.0)
        let hijauMuda = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)
        let kuningMuda = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
        // Biru Pekat
        _ = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
        let coklat = NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        let unguTerang = NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0)
        let abuAbu = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

        let semesterColors: [String: NSColor] = ["Semester 1": .systemTeal, "Semester 2": .systemOrange]
        let kelasColors: [String: NSColor] = [
            "Kelas 1": hijauMuda,
            "Kelas 2": kuningMuda,
            "Kelas 3": .systemBlue,
            "Kelas 4": unguTerang,
            "Kelas 5": coklat,
            "Kelas 6": abuAbu,
        ]
        // Loop melalui data dan gambar setiap chart
        for (index, (kelas, semester, value)) in kelasChartData.enumerated() {
            let x = 20.0 + CGFloat(index) * barWidth
            var barHeight: CGFloat

            let maxValue = Double(maxTotalValue)

            // Hitung tinggi batang sebagai persentase dari total nilai tertinggi
            if value > maxValue {
                barHeight = maxHeightLimit
            } else {
                barHeight = (CGFloat(value) / CGFloat(maxTotalValue)) * maxHeightLimit
            }

            let barRect = NSRect(x: x, y: 20.0, width: barWidth, height: barHeight)

            // MARK: - WARNA CHART

            if let color = semesterColors[semester] {
                color.setFill()
            } else {
                // Ganti NSColor.systemPurple dengan warna yang sesuai dengan kelas
                if let kelasColor = kelasColors[kelas] {
                    kelasColor.setFill()
                } else {
                    NSColor.systemPurple.setFill() // Jika kelas tidak memiliki warna yang ditentukan
                }
            }

            NSBezierPath(rect: barRect).fill()
            let text = NSString(string: "\(formatter.string(from: NSNumber(value: value)) ?? "")")
            var textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
            ]

            // Tambahkan warna teks sesuai dengan mode
            let textColor = NSColor.labelColor
            textAttributes[.foregroundColor] = textColor

            // let textSize = text.size(withAttributes: textAttributes)

            // Hitung posisi tengah bar
            let barCenterX = x + (barWidth / 2)

            // Atur transformasi untuk teks vertikal dan tengah
            let transform = NSAffineTransform()

            transform.translateX(by: barCenterX + 6, yBy: barRect.maxY + 6.0)
            // Putar teks
            transform.rotate(byDegrees: 90.0)

            // Gambar teks vertikal
            let currentContext = NSGraphicsContext.current?.cgContext
            currentContext?.saveGState()
            transform.concat()

            text.draw(at: NSPoint(x: 0, y: 0), withAttributes: textAttributes)

            currentContext?.restoreGState()
        }
    }

    /// Mempersiapkan data yang akan ditampilkan dalam grafik secara asinkron.
    ///
    /// Fungsi ini mengambil data nilai dari setiap kelas ``KelasModels`` menggunakan ``DatabaseController``
    /// secara paralel. Kemudian, ia menghitung total nilai per semester dan nilai keseluruhan
    /// untuk setiap kelas. Hasilnya dikompilasi ke dalam format ``kelasChartData``
    /// dan diperbarui di antrean utama, yang memicu penggambaran ulang grafik.
    func prepareChartData() async {
        let viewModel = KelasViewModel.shared
        let kelasData: [TableType: [KelasModels]]

        if arsipKelas, let tahunAjaran, !tahunAjaran.isEmpty {
            await viewModel.loadAllArsipKelas(tahunAjaran)
            kelasData = viewModel.arsipKelasData
        } else {
            await viewModel.loadAllKelasData()
            kelasData = viewModel.kelasData
        }

        guard !kelasData.isEmpty else { return }

        let chartData = await buildChartData(from: kelasData)

        await MainActor.run { [unowned self] in
            kelasChartData = chartData
            needsDisplay = true
        }
    }

    @Sendable
    private func calculateValues(from data: [KelasModels]) async -> (Double, Double, Double) {
        let total = data.reduce(0.0) { $0 + Double($1.nilai) }
        let s1 = data.filter { $0.semester == "1" }.compactMap { Double($0.nilai) }.reduce(0.0, +)
        let s2 = data.filter { $0.semester == "2" }.compactMap { Double($0.nilai) }.reduce(0.0, +)
        return (total, s1, s2)
    }

    @Sendable
    private func buildChartData(from kelasData: [TableType: [KelasModels]]) async -> [(String, String, Double)] {
        let labels = ["Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6"]
        let types: [TableType] = [.kelas1, .kelas2, .kelas3, .kelas4, .kelas5, .kelas6]
        let resultData: [[KelasModels]] = types.map { kelasData[$0] ?? [] }

        var tempChartData: [(String, String, Double)] = []

        await withTaskGroup(of: (Int, [(String, String, Double)]).self) { [weak self] group in
            guard let self else { return }
            for (index, data) in resultData.enumerated() {
                group.addTask {
                    let (total, s1, s2) = await self.calculateValues(from: data)
                    let kelas = labels[index]
                    return (index, [
                        (kelas, "Total Nilai", total),
                        (kelas, "Semester 1", s1),
                        (kelas, "Semester 2", s2),
                    ])
                }
            }

            var temp: [(Int, [(String, String, Double)])] = []

            for await result in group {
                temp.append(result)
            }

            temp.sort { $0.0 < $1.0 }
            for (_, entries) in temp {
                tempChartData.append(contentsOf: entries)
            }
        }

        return tempChartData
    }

    /// Menggambar legenda grafik di bagian bawah view.
    ///
    /// Legenda ini menampilkan kotak warna kecil dan label teks yang sesuai
    /// untuk setiap kelas dan setiap semester, membantu pengguna memahami
    /// representasi warna dalam grafik.
    ///
    /// - Parameter rect: `NSRect` yang menunjukkan area menggambar yang tersedia.
    private func drawLegend(in _: NSRect) {
        // Smaller dimensions for more compact legend
        let legendRectSize = NSSize(width: 8.0, height: 8.0)
        let legendFont = NSFont.systemFont(ofSize: 10.0)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: legendFont,
            .foregroundColor: NSColor.labelColor,
        ]

        // Colors definition
        let hijauMuda = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)
        let kuningMuda = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
        let unguTerang = NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0)
        let coklat = NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        let abuAbu = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

        // Legend items in two groups
        let semesterItems: [(color: NSColor, text: String)] = [
            (NSColor.systemTeal, "Semester 1"),
            (NSColor.systemOrange, "Semester 2"),
        ]

        let kelasItems: [(color: NSColor, text: String)] = [
            (hijauMuda, "Kelas 1"),
            (kuningMuda, "Kelas 2"),
            (NSColor.systemBlue, "Kelas 3"),
            (unguTerang, "Kelas 4"),
            (coklat, "Kelas 5"),
            (abuAbu, "Kelas 6"),
        ]

        // Calculate starting positions
        let startX: CGFloat = 20.0
        let startY: CGFloat = 5.0
        let semesterSpacing: CGFloat = 75.0
        let kelasSpacing: CGFloat = 52.0

        // Draw semester legend items
        for (index, item) in kelasItems.enumerated() { // Ini seharusnya kelasItems, bukan semesterItems
            let x = startX + CGFloat(index) * kelasSpacing
            let y = startY

            // Draw color rectangle
            let rectFrame = NSRect(x: x, y: y, width: legendRectSize.width, height: legendRectSize.height)
            item.color.setFill()
            NSBezierPath(rect: rectFrame).fill()

            // Draw text
            let text = NSString(string: item.text)
            let textPoint = NSPoint(x: x + legendRectSize.width + 3.0, y: y - 2.5)
            text.draw(at: textPoint, withAttributes: textAttributes)
        }

        // Draw kelas legend items starting after Semester 2
        let kelasStartX = startX + semesterSpacing * 2 + 175 // Add some padding after Semester 2

        for (index, item) in semesterItems.enumerated() { // Ini seharusnya semesterItems, bukan kelasItems
            let x = kelasStartX + CGFloat(index) * semesterSpacing
            let y = startY

            // Draw color rectangle
            let rectFrame = NSRect(x: x, y: y, width: legendRectSize.width, height: legendRectSize.height)
            item.color.setFill()
            NSBezierPath(rect: rectFrame).fill()

            // Draw text
            let text = NSString(string: item.text)
            let textPoint = NSPoint(x: x + legendRectSize.width + 3.0, y: y - 2.5)
            text.draw(at: textPoint, withAttributes: textAttributes)
        }
    }

    deinit {
        kelasChartData.removeAll()
        removeFromSuperviewWithoutNeedingDisplay()
        #if DEBUG
            print("deinit StatistikKelas")
        #endif
    }
}
