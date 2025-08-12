//
//  Kelas Chart Model.swift
//  Data SDI
//
//  Created by MacBook on 22/06/25.
//

import Foundation

/// Model data untuk chart kelas, digunakan untuk merepresentasikan data rata-rata nilai kelas dalam sebuah grafik.
///
/// - Note:
///   Properti dengan awalan underscore (_) digunakan sebagai penyimpanan nilai asli untuk kebutuhan animasi.
///   Properti `animate` dapat diubah untuk memicu perubahan tampilan nilai pada chart.
struct KelasChartModel: Identifiable {
    /// Indeks urutan model pada daftar
    let index: Int
    /// UUID unik untuk identifikasi model
    let id: UUID = .init()
    /// Nama kelas
    let className: String

    // --- PERUBAHAN DI SINI ---
    // 'let' karena nilai ini tidak pernah diubah setelah init.

    /// Nilai rata-rata keseluruhan (internal, digunakan untuk animasi).
    let _overallAverage: Double
    /// Nilai rata-rata semester 1 (internal, digunakan untuk animasi).
    let _semester1Average: Double
    /// Nilai rata-rata semester 2 (internal, digunakan untuk animasi).
    let _semester2Average: Double
    /// Nilai awal rata-rata keseluruhan untuk animasi.
    let _overallAverageYStart: Double

    /// Status animasi, jika true maka nilai rata-rata akan ditampilkan sesuai data asli, jika false menggunakan nilai awal animasi.
    var animate: Bool = false

    /// Nilai rata-rata keseluruhan yang ditampilkan, tergantung status animasi.
    var overallAverage: Double {
        animate ? _overallAverage : _overallAverageYStart
    }

    /// Nilai rata-rata semester 1 yang ditampilkan, tergantung status animasi.
    var semester1Average: Double {
        animate ? _semester1Average : _overallAverageYStart
    }

    /// Nilai rata-rata semester 2 yang ditampilkan, tergantung status animasi.
    var semester2Average: Double {
        animate ? _semester2Average : _overallAverageYStart
    }

    init(index: Int, className: String? = nil, overallAverage: Double? = nil, semester1Average: Double? = nil, semester2Average: Double? = nil, overallAverageYStart: Double) {
        self.index = index
        self.className = className ?? ""
        _overallAverage = overallAverage ?? 0
        _semester1Average = semester1Average ?? 0
        _semester2Average = semester2Average ?? 0
        _overallAverageYStart = overallAverageYStart
    }
}
