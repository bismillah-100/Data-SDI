//
//  Statistik Siswa.swift
//  Data SDI
//
//  Created by MacBook on 21/06/25.
//

import Charts
import SwiftUI

/// View untuk menampilkan SwiftCharts yang memuat ringkasan data siswa dan kelas.
struct StudentCombinedChartView: View {
    /// Data yang ditampilkan di dalam Charts.
    @State var data: [KelasChartModel] // @State agar bisa dimodifikasi untuk animasi

    /// Opsi untuk menonaktifkan LineChart pertama.
    @State var displayLine1: Bool = true
    /// Opsi untuk menonaktifkan LineChart kedua.
    @State var displayLine2: Bool = true
    /// Opsi untuk menonaktifkan BarChart.
    @State var displayBar: Bool = true
    /// Opsi untuk menonaktifkan PointChart.
    @State var displayPoint: Bool = true

    /// Warna yang digunakan untuk setiap kelas.
    private let barColors: [Color] =
        ReusableFunc.classColors.map { nsColor in
            Color(nsColor: nsColor)
        }

    // MARK: - Properti untuk Mengelola Posisi Klik

    /// Variabel untuk menyimpan data yang sedang disentuh/diklik (untuk tooltip atau info)
    @State private var touchedGradeData: KelasChartModel? = nil

    /// Mendapatkan nilai rata-rata dalam kondisi tertentu sesuai pilihan ``displayLine1``, ``displayLine12``
    /// dan ``displayBar``. Digunakan untuk mendapatkan nilai terendah yang dibutuhkan untuk memproses animasi.
    private var allAverages: [Double] {
        if !displayLine1, !displayLine2 {
            return data.flatMap { [$0._overallAverage] }
        } else if !displayLine1 || !displayLine2 {
            return data.flatMap { [$0._semester1Average] }
        } else {
            return data.flatMap { [$0._overallAverage, $0._semester1Average, $0._semester2Average] }
        }
    }

    /// Warna latar untuk Chart Legend rata-rata nilai semester 1 dan 2.
    private var foregroundStyles: KeyValuePairs<String, AnyShapeStyle> {
        if displayLine1, displayLine2 {
            return [
                "Rata-rata Semester 1": AnyShapeStyle(Color(nsColor: NSColor.magenta)),
                "Rata-rata Semester 2": AnyShapeStyle(Color(nsColor: NSColor.green))
            ]
        } else {
            return [:]
        }
    }
    
    /// Nilai minimum charts untuk label x axis dan nilai awal sebelum animasi.
    private var finalMinDomain: Double {
        if displayLine1, displayLine2, displayBar {
            return 0
        } else {
            let actualMinGrade = ReusableFunc.decreaseAndRoundDownToMultiple(allAverages.min() ?? 0.0, percent: 0.95)
            return actualMinGrade
        }
    }

    /// Menampilkan tampilan grafik statistik siswa.
    ///
    /// - Menghitung nilai rata-rata minimum dari `allAverages`.
    /// - Membulatkan nilai minimum ke bawah ke puluhan terdekat.
    /// - Memastikan nilai domain minimum tidak kurang dari 0.
    /// - Menggunakan data yang diberikan untuk menampilkan grafik menggunakan `Chart`.
    var body: some View {

        Chart {
            // MARK: BarMark duluan

            if displayBar {
                ForEach(data) { gradeData in
                    BarMark(
                        x: .value("Kelas", gradeData.className),
                        yStart: .value("Nilai Dasar", finalMinDomain),
                        yEnd: .value("Total", gradeData.overallAverage)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(barColors[gradeData.index])
                }
            }

            // MARK: Line & Point Mark Semester 1

            if displayLine1 {
                ForEach(data) { gradeData in
                    LineMark(
                        x: .value("Kelas", gradeData.className),
                        y: .value("Semester 1", gradeData.semester1Average)
                    )
                    .foregroundStyle(by: .value("Semester", "Rata-rata Semester 1"))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(data) { gradeData in
                    if !displayPoint {
                        /// ** Statistik siswa **
                        
                        // Stroke luar (besar)
                        PointMark(
                          x: .value("Kelas", gradeData.className),
                          y: .value("Semester 2", gradeData.semester1Average)
                        )
                        .symbolSize(90)
                        .foregroundStyle(Color(red: 0.7, green: 0.0, blue: 0.7))
                        
                        // Fill
                        PointMark(
                            x: .value("Kelas", gradeData.className),
                            y: .value("Semester 1", gradeData.semester1Average)
                        )
                        .symbolSize(70)
                        .foregroundStyle(by: .value("Semester", "Rata-rata Semester 1"))
                    } else {
                        /// ** Stats(Semua Kelas dan Siswa) **
                        
                        // Fill
                        PointMark(
                            x: .value("Kelas", gradeData.className),
                            y: .value("Semester 1", gradeData.semester1Average)
                        )
                        .symbolSize(100)
                        .foregroundStyle(barColors[gradeData.index])

                        LineMark(
                            x: .value("Kelas", gradeData.className),
                            y: .value("Semester 1", gradeData.semester1Average)
                        )
                        .foregroundStyle(
                            AnyShapeStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: barColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
            }

            // MARK: Line & Point Mark Semester 2

            if displayLine2 {
                /// ** Statistik siswa **
                ForEach(data) { gradeData in
                    LineMark(
                        x: .value("Kelas", gradeData.className),
                        y: .value("Semester 2", gradeData.semester2Average)
                    )
                    .foregroundStyle(by: .value("Semester", "Rata-rata Semester 2"))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(data) { gradeData in
                    // Stroke luar (besar)
                    PointMark(
                      x: .value("Kelas", gradeData.className),
                      y: .value("Semester 2", gradeData.semester2Average)
                    )
                    .symbolSize(90)
                    .foregroundStyle(Color(red: 0.0, green: 0.6, blue: 0.0))

                    
                    // Fill
                    PointMark(
                        x: .value("Kelas", gradeData.className),
                        y: .value("Semester 2", gradeData.semester2Average)
                    )
                    .symbolSize(70)
                    .foregroundStyle(by: .value("Semester", "Rata-rata Semester 2"))
                }
            }
            
            if let touchedGradeData,
               let kelasInt = Int(touchedGradeData.className.replacingOccurrences(of: "Kelas ", with: "")) {
                RectangleMark(
                    x: .value("Kelas", touchedGradeData.className),
                    y: .value("Total",
                              displayLine1 && !displayBar ? touchedGradeData.semester1Average : touchedGradeData.overallAverage)
                )
                    .foregroundStyle(barColors[kelasInt - 1].opacity(0.5))
                    .annotation(
                        position: kelasInt < 4 ? .trailing : .leading,
                        alignment: .center,
                        spacing: 0
                    ) {
                        createGradeAnnotation(touchedGradeData: touchedGradeData, displayBar: displayBar, displayLine1: displayLine1, displayLine2: displayLine2)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartYScale(domain: finalMinDomain ... 100)
        .frame(maxHeight: .infinity)
        .chartForegroundStyleScale(foregroundStyles)
        .padding()
        .onAppear {
            // Pastikan ini hanya berjalan saat chartIsVisible menjadi true (pertama kali muncul)
            // Iterasi setiap item data dan animasikan properti 'animate'
            for i in 0 ..< data.count {
                withAnimation(.easeOut(duration: 0.6).delay(Double(i) * 0.1)) { // Sesuaikan delay antar bar
                    data[i].animate = true
                }
            }
        }
        .chartOverlay { proxy in
            Color.clear
                .onHover { isHovering in
                    if !isHovering {
                        touchedGradeData = nil
                        return
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let locationInView):
                        if let className: String = proxy.value(atX: locationInView.x) {
                            // Cari data yang paling cocok dengan kelas ini
                            if let closestGradeData = data.first(where: { $0.className == className }) {
                                touchedGradeData = closestGradeData
                            }
                        }
                    case .ended:
                        touchedGradeData = nil
                    }
                }
        }
    }

    /// Membuat anotasi visual untuk grafik nilai berdasarkan data kelas yang disentuh.
    ///
    /// Fungsi ini menghasilkan tampilan SwiftUI yang menyajikan informasi nilai secara kondisional,
    /// tergantung pada parameter `displayBar`, `displayLine1`, dan `displayLine2`.
    /// Anotasi ini cocok digunakan dalam grafik (misalnya dalam `Chart`) untuk menampilkan detail nilai
    /// seperti nilai keseluruhan dan nilai tiap semester.
    ///
    /// - Parameters:
    ///   - touchedGradeData: Objek `KelasChartModel` yang merepresentasikan data nilai dari kelas yang sedang disentuh.
    ///   - displayBar: Boolean yang menentukan apakah nilai keseluruhan (`overallAverage`) ditampilkan.
    ///   - displayLine1: Boolean yang menentukan apakah nilai Semester 1 ditampilkan.
    ///   - displayLine2: Boolean yang menentukan apakah nilai Semester 2 ditampilkan.
    ///
    /// - Returns: Tampilan anotasi sebagai `some View`, yang terdiri dari teks informatif dalam sebuah `VStack`
    ///   dengan gaya tampilan berupa latar belakang putih semi-transparan, teks hitam, dan sudut membulat.
    @ViewBuilder
    func createGradeAnnotation(
        touchedGradeData: KelasChartModel,
        displayBar: Bool,
        displayLine1: Bool,
        displayLine2: Bool
    ) -> some View {
        // Menggunakan RectangleMark untuk menempatkan annotation pada sumbu X

        VStack(alignment: .leading, spacing: 4) {
            Text("\(touchedGradeData.className)")
            if displayBar, displayLine1, displayLine2 {
                Text("Overall: \(String(format: "%.2f", touchedGradeData.overallAverage))")
                    .font(.subheadline)
                Text("Sem 1: \(String(format: "%.2f", touchedGradeData.semester1Average))")
                    .font(.subheadline)
                Text("Sem 2: \(String(format: "%.2f", touchedGradeData.semester2Average))")
                    .font(.subheadline)
            }
            else if displayBar {
                Text("\(String(format: "%.2f", touchedGradeData.overallAverage))")
                    .font(.subheadline)
            }
            else if displayLine1 {
                Text("\(String(format: "%.2f", touchedGradeData.semester1Average))")
                    .font(.subheadline)
            }
            else if displayLine2 {
                Text("\(String(format: "%.2f", touchedGradeData.semester2Average))")
                    font(.subheadline)
            }
        }
        .foregroundStyle(Color.black)
        .font(.headline)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
    }

    /// Menentukan nilai Y target berdasarkan prioritas tampilan chart.
    /// - Parameter data: Model data `KelasChartModel` yang berisi nilai-nilai rata-rata.
    /// - Returns: Nilai Y yang akan digunakan pada chart, berdasarkan prioritas berikut:
    ///   - Jika ``displayBar`` aktif, mengembalikan `overallAverage`.
    ///   - Jika tidak, namun ``displayLine1`` aktif, mengembalikan `semester1Average`.
    ///   - Jika tidak, namun ``displayLine2`` aktif, mengembalikan `semester2Average`.
    ///   - Jika semua tidak aktif, mengembalikan 0 (fallback).
    private func getTargetYValue(for data: KelasChartModel) -> Double {
        // Tentukan prioritas. Misal: jika Bar tampil, selalu targetkan nilai Bar.
        if displayBar {
            return data.overallAverage
        }
        // Jika tidak, tapi Line 1 tampil, targetkan nilai Line 1.
        if displayLine1 {
            return data.semester1Average
        }
        // Jika tidak, tapi Line 2 tampil, targetkan nilai Line 2.
        if displayLine2 {
            return data.semester2Average
        }

        // Fallback jika semua disembunyikan (seharusnya tidak terjadi)
        return 0
    }
}
