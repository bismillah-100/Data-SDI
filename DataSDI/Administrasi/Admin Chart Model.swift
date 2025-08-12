//
//  Admin Chart Model.swift
//  Data SDI
//
//  Created by MacBook on 23/06/25.
//

import Foundation

/// Model data untuk chart administrasi.
///
/// - Properties:
///   - id: UUID unik untuk setiap data chart.
///   - date: Tanggal data chart.
///   - _value: Nilai asli data chart.
///   - month: Label bulan dalam format singkat (misal: "Jan") dari tanggal.
///   - year: Tahun dari tanggal.
///   - animate: Status animasi chart, jika true maka value akan muncul.
///   - value: Nilai yang ditampilkan pada chart, 0 jika animasi belum aktif.
///
/// - Initializer:
///   - init(date:value:): Inisialisasi model dengan tanggal dan nilai chart.
struct ChartDataPoint: Identifiable, Equatable {
    /// UUID unik untuk setiap data chart
    var id: UUID = .init()
    /// Tanggal data chart
    let date: Date
    /// Nilai asli data chart.
    let _value: Double

//    /// Properti tambahan untuk label dalam format singkat (misal: "Jan") dari tanggal.
//    var month: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MMM" // "Jan", "Feb", etc.
//        return formatter.string(from: date)
//    }

    let _minValue: Double

    let _maxValue: Double

//    /// Tahun dari tanggal
//    var year: Int { Calendar.current.component(.year, from: date) }
    /// Status animasi chart, jika true maka value akan muncul.
    var animate: Bool = false
    /// Nilai yang ditampilkan pada chart, 0 jika animasi belum aktif.
    var value: Double { animate ? _value : _minValue }

    /// Inisialisasi model dengan tanggal dan nilai chart.
    init(date: Date, value: Double, minValue: Double, maxValue: Double) {
        self.date = date
        _value = value
        _minValue = minValue
        _maxValue = maxValue
    }
}

/// Enum untuk menentukan jenis periode chart
/// Enum yang merepresentasikan periode chart, yaitu tahunan (`yearly`) dan bulanan (`monthly`).
///
/// - yearly: Periode tahunan.
/// - monthly: Periode bulanan.
///
/// Properti:
/// - `axisLabel`: Label yang digunakan untuk sumbu X pada chart, menyesuaikan dengan periode.
/// - `tooltipDateFormat`: Format tanggal yang digunakan pada tooltip chart, menyesuaikan dengan periode.
enum ChartPeriod {
    /// Periode tahunan.
    case yearly
    /// Periode bulanan.
    case monthly

    /// Properti untuk mendapatkan label sumbu X
    var axisLabel: String {
        switch self {
        case .yearly:
            "Tahun"
        case .monthly:
            "Bulan"
        }
    }

    /// Properti untuk mendapatkan format tanggal di tooltip
    var tooltipDateFormat: Date.FormatStyle {
        switch self {
        case .yearly:
            .dateTime.year()
        case .monthly:
            .dateTime.month(.wide) // Menggunakan .wide agar lebih jelas, mis: "Juni"
        }
    }
}
