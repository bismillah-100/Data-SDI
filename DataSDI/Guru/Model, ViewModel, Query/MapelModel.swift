//
//  MapelModel.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

import Foundation

/// `MapelModel` adalah sebuah struktur data yang merepresentasikan mata pelajaran.
///
/// Struktur ini dirancang untuk dapat dibandingkan (`Equatable`) dan dapat di-*hash* (`Hashable`),
/// yang membuatnya cocok untuk digunakan dalam koleksi seperti `Set` atau sebagai kunci dalam `Dictionary`.
/// Kesetaraan dan nilai *hash* didasarkan pada properti `id` yang unik. Sortir data menggunakan
/// protokol ``SortableKey``.
final class MapelModel: Equatable, Hashable, Comparable, SortableKey {
    static func < (lhs: MapelModel, rhs: MapelModel) -> Bool {
        lhs.namaMapel != rhs.namaMapel
    }

    /// Pemetaan nama kolom (`String`) ke `PartialKeyPath` milik `MapelModel`.
    ///
    /// Digunakan untuk:
    /// - Mencocokkan nama kolom tabel atau header UI dengan properti model.
    /// - Mendukung fitur seperti **dynamic sorting**, **filtering**, atau **binding UI**
    ///   berdasarkan nama kolom yang dipilih pengguna.
    ///
    /// Kunci dictionary (`String`) biasanya sesuai dengan label kolom di UI,
    /// sedangkan nilainya adalah `PartialKeyPath` ke properti terkait di `MapelModel`.
    ///
    /// ### Contoh Penggunaan
    /// ```swift
    /// if let keyPath = MapelModel.keyPathMap["NamaGuru"] {
    ///     let namaMapel = mapelInstance[keyPath: keyPath]
    ///     print(namaMapel)
    /// }
    /// ```
    ///
    /// - Important: Pastikan string key konsisten dengan label yang digunakan di UI
    ///   agar pemetaan berfungsi dengan benar.
    static var keyPathMap: [String: PartialKeyPath<MapelModel>] = [
        "NamaGuru": \.namaMapel,
    ]

    /// Sekumpulan `PartialKeyPath` sekunder untuk `MapelModel`.
    ///
    /// Digunakan sebagai **fallback comparator** atau urutan pembanding tambahan
    /// ketika proses pengurutan (sorting) data mapel tidak cukup hanya
    /// mengandalkan key path utama.
    ///
    /// Dalam kasus ini, hanya ada satu key path sekunder, yaitu `namaMapel`,
    /// yang akan digunakan sebagai pembanding tambahan atau tie‑breaker.
    ///
    /// - Note: `PartialKeyPath` memungkinkan akses properti tanpa
    ///   mengikat tipe nilai (`Value`) secara langsung, sehingga fleksibel
    ///   untuk berbagai tipe properti dalam `MapelModel`.
    static var secondaryKeyPaths: [PartialKeyPath<MapelModel>] = [
        \.namaMapel,
    ]

    // MARK: - Properti

    /// Pengidentifikasi unik untuk mata pelajaran.
    /// Ini digunakan untuk menentukan kesetaraan dan untuk menghasilkan nilai *hash*.
    var id: Int64

    /// Nama mata pelajaran (misalnya, "Matematika", "Fisika", "Bahasa Indonesia").
    var namaMapel: String

    /// Daftar guru yang mengajar mata pelajaran ini.
    /// Diasumsikan `GuruModel` adalah struktur atau kelas yang relevan.
    var guruList: [GuruModel]

    // MARK: - Inisialisasi

    /// Menginisialisasi instance baru dari `MapelModel`.
    ///
    /// - Parameters:
    ///   - id: ID unik untuk mata pelajaran.
    ///   - namaMapel: Nama mata pelajaran.
    ///   - guruList: Array `GuruModel` yang terkait dengan mata pelajaran ini.
    init(id: Int64, namaMapel: String, guruList: [GuruModel]) {
        self.id = id
        self.namaMapel = StringInterner.shared.intern(namaMapel)
        self.guruList = guruList
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mengimplementasikan operator kesetaraan (`==`) untuk `MapelModel`.
    ///
    /// Dua `MapelModel` dianggap sama jika `id` mereka sama.
    ///
    /// - Parameters:
    ///   - lhs: `MapelModel` di sisi kiri operator.
    ///   - rhs: `MapelModel` di sisi kanan operator.
    /// - Returns: `true` jika kedua mata pelajaran memiliki `id` yang sama, `false` jika sebaliknya.
    static func == (lhs: MapelModel, rhs: MapelModel) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Implementasi Protokol Hashable

    /// Mengimplementasikan metode `hash(into:)` untuk mendukung protokol `Hashable`.
    ///
    /// Nilai *hash* untuk `MapelModel` dihasilkan hanya dari properti `id` untuk memastikan
    /// konsistensi dengan implementasi `Equatable`.
    ///
    /// - Parameter hasher: `Hasher` yang digunakan untuk menggabungkan nilai *hash*.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
