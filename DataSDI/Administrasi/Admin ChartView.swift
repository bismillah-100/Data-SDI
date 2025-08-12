//
//  Monthly Chart UI.swift
//  Data SDI
//
//  Created by MacBook on 23/06/25.
//

import Charts
import SwiftUI

/// View untuk menampilkan ringkasan data administrasi per-bulan dan per-tahun dalam bentuk grafis garis (LineCharts).
struct AdminLineChartView: View {
    @ObservedObject var viewModel: AdminChartViewModel

    /// Data yang ditampilkan LineCharts.
    private var data: [ChartDataPoint] {
        switch period {
        case .yearly:
            viewModel.yearlyChartData
        case .monthly:
            viewModel.monthlyChartData
        }
    }

    /// Jenis transaksi yang diproses charts.
    private var filterJenis: String {
        viewModel.filterJenis
    }

    /// Untuk menentukan periode charts antara bulanan atau tahunan.
    private var period: ChartPeriod {
        viewModel.period
    }

    /// Properti untuk menentukan warna sesuai dengan ``filterJenis``.
    private var chartColor: Color {
        switch filterJenis {
        case "Pemasukan": .green
        case "Pengeluaran": .red
        case "Lainnya": .orange
        case "Jumlah Saldo": .blue
        default: .gray
        }
    }

    /// Properti computed yang mengembalikan `AnyShapeStyle` berupa gradasi warna sesuai dengan nilai `filterJenis`.
    /// - Jika `filterJenis` adalah "Pemasukan", akan mengembalikan gradasi hijau.
    /// - Jika `filterJenis` adalah "Pengeluaran", akan mengembalikan gradasi merah.
    /// - Jika `filterJenis` adalah "Lainnya", akan mengembalikan gradasi oranye.
    /// - Jika `filterJenis` adalah "Jumlah Saldo", akan mengembalikan gradasi biru.
    /// - Untuk nilai lainnya, akan mengembalikan gradasi abu-abu.
    /// Gradasi dihasilkan menggunakan fungsi `gradientStyle(for:)` dengan warna yang sesuai.
    private var chartGradient: AnyShapeStyle {
        switch filterJenis {
        case "Pemasukan":
            gradientStyle(for: .green)
        case "Pengeluaran":
            gradientStyle(for: .red)
        case "Lainnya":
            gradientStyle(for: .orange)
        case "Jumlah Saldo":
            gradientStyle(for: .blue)
        default:
            gradientStyle(for: .gray)
        }
    }

    // MARK: - State untuk interaktivitas

    /// State untuk menyimpan data pada titik yang diklik dan ditahan.
    @State private var touchedData: ChartDataPoint? = nil
    /// State untuk menyimpan tempat indikator pada titik yang diklik dan ditahan.
    @State private var indicatorPosition: CGPoint? = nil

    /// State untuk menyimpan ukuran tooltip
    @State private var tooltipSize: CGSize = .zero
    @State private var isHoveringTooltip: Bool = false

    /// Nilai terkecil yang ada di dalam ``data``.
    private var roundedMinValue: Double {
        data.map(\._minValue).first ?? 0.0
    }

    /// Nilai terbesar yang ada di dalam ``data``.
    private var roundedMaxValue: Double {
        data.map(\._maxValue).first ?? 0.0
    }

    /// Properti `body` yang menampilkan tampilan utama dari view ini.
    /// Di dalamnya, nilai minimum dan maksimum dari data akan dibulatkan menggunakan fungsi `ReusableFunc.makeRoundedNumber`.
    /// Kemudian, data akan divisualisasikan menggunakan komponen `Chart`.
    var body: some View {
        Chart(data) { point in
            // Menggunakan properti dari enum `period` untuk label
            let axisLabel = period.axisLabel

            // AreaMark, LineMark, dan PointMark tetap sama, hanya labelnya yang dinamis
            AreaMark(
                x: .value(axisLabel, point.date),
                yStart: .value("Min", roundedMinValue), // <- Mulai isi dari batas bawah chart
                yEnd: .value("Max", point.value) // <- Akhiri isi di nilai data
            )
            .foregroundStyle(chartGradient)
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value(axisLabel, point.date),
                y: .value("Total", point.value)
            )
            .foregroundStyle(chartColor)
            .symbol(Circle().strokeBorder(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value(axisLabel, point.date),
                y: .value("Total", point.value)
            )
            .foregroundStyle(chartColor)
            .annotation(position: .overlay) {
                Circle().stroke(Color.primary, lineWidth: 1).background(Circle().fill(chartColor)).frame(width: 10, height: 10)
            }
        }
        .onAppear {
            for i in 0 ..< data.count {
                withAnimation(.easeOut(duration: 0.6)) {
                    viewModel.updateAnimateFlag(at: i, period: period)
                }
            }
        }
        .onChange(of: data) { _ in
            for i in 0 ..< data.count {
                withAnimation(.easeOut(duration: 0.6)) {
                    viewModel.updateAnimateFlag(at: i, period: period)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                if let amount = value.as(Double.self) {
                    AxisValueLabel(ReusableFunc.rupiahCurrencyFormatter(amount))
                }
            }
        }
        .chartYScale(domain: roundedMinValue ... roundedMaxValue)
        .chartXScale(range: .plotDimension(padding: 0))
        // --- INI BAGIAN YANG BERBEDA ---
        // Sumbu X sekarang kondisional berdasarkan `period`
        .chartXAxis {
            switch period {
            case .yearly:
                AxisMarks(preset: .aligned, position: .bottom, values: .stride(by: .year)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.year(.defaultDigits))
                }
            case .monthly:
                AxisMarks(preset: .aligned, position: .bottom, values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated)) // Mis: Jan, Feb, Mar
                }
            }
        }
        .padding()
        .zoomableChart()
        // Overlay untuk interaktivitas (logikanya sama persis)
        .chartOverlay { proxy in
            GeometryReader { chartGeometry in
                ZStack {
                    // Area gesture tetap sama
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            if !isHovering || !isHoveringTooltip {
                                // Reset jika mouse keluar dari area
                                touchedData = nil
                                indicatorPosition = nil
                                return
                            }
                        }
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(locationInView):
                                let origin = chartGeometry[proxy.plotAreaFrame].origin
                                let location = CGPoint(x: locationInView.x - origin.x, y: locationInView.y - origin.y)

                                // Pengecekan apakah sentuhan masih di dalam area plot
                                guard chartGeometry[proxy.plotAreaFrame].contains(locationInView) else {
                                    touchedData = nil
                                    indicatorPosition = nil
                                    return
                                }

                                guard let dateAtLocation: Date = proxy.value(atX: location.x) else {
                                    return
                                }

                                if let closest = data.min(by: { abs($0.date.timeIntervalSince(dateAtLocation)) < abs($1.date.timeIntervalSince(dateAtLocation)) }) {
                                    touchedData = closest
                                    if let xPos = proxy.position(forX: closest.date), let yPos = proxy.position(forY: closest.value) {
                                        // Simpan posisi x dan y dari titik data
                                        indicatorPosition = CGPoint(x: xPos, y: yPos)
                                    }
                                }
                            default: break
                            }
                        }

                    // Tampilkan indikator dan tooltip jika ada data yang disentuh
                    if let touchedData, let anchor = indicatorPosition {
                        // Gambar garis-garis indikator
                        drawIndicatorLines(at: anchor, in: chartGeometry.size)

                        // Buat view tooltip
                        TooltipView(touchedData: touchedData, period: period)
                            .onHover { isHovering in
                                // Memperbarui status apakah tooltip sedang di-hover
                                isHoveringTooltip = isHovering
                            }

                            .background(
                                // Gunakan GeometryReader di background untuk mengukur ukuran tooltip
                                GeometryReader { tooltipGeometry in
                                    Color.clear.onAppear {
                                        tooltipSize = tooltipGeometry.size
                                    }
                                }
                            )
                            // Posisikan tooltip dengan offset yang sudah dihitung
                            .position(x: anchor.x, y: anchor.y)
                            .offset(calculateTooltipOffset(anchor: anchor, chartSize: chartGeometry.size, tooltipSize: tooltipSize))
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                    }
                }
            }
        }
    }

    /// Menggambar garis indikator vertikal dan horizontal serta lingkaran penanda pada posisi tertentu di dalam ukuran tampilan yang diberikan.
    ///
    /// - Parameters:
    ///   - position: Titik `CGPoint` tempat indikator akan digambar.
    ///   - size: Ukuran `CGSize` area tampilan tempat indikator digambar.
    /// - Returns: Sebuah `View` yang terdiri dari garis vertikal, garis horizontal, dan lingkaran penanda pada posisi yang ditentukan.
    @ViewBuilder
    func drawIndicatorLines(at position: CGPoint, in size: CGSize) -> some View {
        // Garis vertikal
        Rectangle()
            .fill(Color.gray)
            .frame(width: 1, height: size.height)
            .position(x: position.x, y: size.height / 2)

        // Garis horizontal
        Rectangle()
            .fill(Color.gray)
            .frame(width: size.width, height: 1)
            .position(x: size.width / 2, y: position.y)

        // Lingkaran penanda
        Circle()
            .fill(chartColor)
            .frame(width: 12, height: 12)
            .position(position)
    }

    /// Menghitung offset posisi tooltip agar tidak terpotong di dalam area chart.
    ///
    /// Fungsi ini menentukan posisi tooltip relatif terhadap titik anchor pada chart,
    /// dengan mempertimbangkan ukuran chart dan tooltip, serta memberikan padding agar tooltip
    /// tidak keluar dari batas chart baik secara vertikal maupun horizontal.
    ///
    /// - Parameters:
    ///   - anchor: Titik pusat (CGPoint) tempat tooltip akan ditampilkan.
    ///   - chartSize: Ukuran area chart (CGSize).
    ///   - tooltipSize: Ukuran tooltip (CGSize).
    /// - Returns: Offset (CGSize) yang perlu diterapkan agar tooltip tetap berada di dalam area chart.
    func calculateTooltipOffset(anchor: CGPoint, chartSize: CGSize, tooltipSize: CGSize) -> CGSize {
        // --- LOGIKA UTAMA ADA DI SINI ---

        let padding: CGFloat = 15 // Jarak antara titik dan tooltip

        var finalOffset = CGSize.zero

        // --- Aturan Sumbu Y (Vertikal) ---
        // Secara default, letakkan tooltip di atas titik
        let verticalOffset = -tooltipSize.height / 2 - padding

        // Cek apakah akan terpotong di atas
        if (anchor.y + verticalOffset) < 0 {
            // Jika ya, balikkan posisinya ke bawah titik
            finalOffset.height = tooltipSize.height / 2 + padding
        } else {
            // Jika tidak, gunakan posisi default (di atas)
            finalOffset.height = verticalOffset
        }

        // --- Aturan Sumbu X (Horizontal) ---
        let horizontalOffset: CGFloat = 0 // Defaultnya di tengah

        // Cek apakah akan terpotong di kanan
        let rightEdge = anchor.x + horizontalOffset + tooltipSize.width / 2
        if rightEdge > chartSize.width {
            // Jika ya, geser ke kiri agar pas di tepi kanan
            finalOffset.width = chartSize.width - rightEdge - 8 // 8 adalah padding dari tepi
        }

        // Cek apakah akan terpotong di kiri
        let leftEdge = anchor.x + horizontalOffset - tooltipSize.width / 2
        if leftEdge < 0 {
            // Jika ya, geser ke kanan agar pas di tepi kiri
            finalOffset.width = -leftEdge + 8 // 8 adalah padding dari tepi
        }

        return finalOffset
    }

    /// Menghasilkan gaya gradien vertikal berbasis warna yang diberikan.
    /// Gradien dimulai dari warna dengan opasitas 0.5 di bagian atas, menurun ke opasitas 0.2, lalu 0.05 di bagian bawah.
    /// - Parameter color: Warna dasar untuk gradien.
    /// - Returns: `AnyShapeStyle` yang berisi gradien linier dari atas ke bawah.
    private func gradientStyle(for color: Color) -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.5),
                    color.opacity(0.2),
                    color.opacity(0.05),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

/// View untuk menampilkan kotak info/tooltip pada titik yang diklik dan ditahan
/// di ``AdminLineChartView``.
struct TooltipView: View {
    /// Data yang ditampilkan.
    let touchedData: ChartDataPoint
    /// Periode data yang ditampilkan (bulanan atau tahunan).
    let period: ChartPeriod

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            // Format tanggalnya sesuai periode (tahunan/bulanan)
            Text(touchedData.date, format: period.tooltipDateFormat)
                .font(.headline)
            // Format mata uang
            Text(ReusableFunc.rupiahCurrencyFormatter(touchedData.value)).font(.subheadline)
        }
        .foregroundColor(.black)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
    }
}

extension View {
    /// Membuat chart dapat diperbesar/diperkecil dengan gestur
    /// - Returns: Konfigurasi chart yang telah diatur supaya dapat diperbesar/diperkecil.
    @ViewBuilder
    func zoomableChart() -> some View {
        if #available(macOS 14.0, *) {
            self.chartScrollableAxes(.horizontal)
        } else {
            self
        }
    }
}
