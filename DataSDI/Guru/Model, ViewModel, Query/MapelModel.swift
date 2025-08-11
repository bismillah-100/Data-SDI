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
/// Kesetaraan dan nilai *hash* didasarkan pada properti `id` yang unik.
class MapelModel: Equatable, Hashable {
    // MARK: - Properti

    /// Pengidentifikasi unik untuk mata pelajaran.
    /// Ini digunakan untuk menentukan kesetaraan dan untuk menghasilkan nilai *hash*.
    var id: UUID

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
    init(id: UUID, namaMapel: String, guruList: [GuruModel]) {
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

extension [MapelModel] {
    /// Menemukan indeks penyisipan yang tepat untuk sebuah elemen `MapelModel` baru
    /// dalam array, mempertahankan urutan yang ditentukan oleh `NSSortDescriptor`.
    ///
    /// Fungsi ini dirancang khusus untuk array yang berisi objek `MapelModel`.
    /// Ia mengiterasi elemen-elemen yang ada dan membandingkan properti
    /// `namaMapel` dari `element` yang akan disisipkan dengan `namaMapel`
    /// dari setiap `item` yang sudah ada. Perbandingan ini disesuaikan dengan
    /// arah pengurutan (`ascending` atau `descending`) yang ditentukan oleh `sortDescriptor`.
    ///
    /// - Parameter element: **Elemen `MapelModel`** baru yang akan disisipkan ke dalam array.
    /// - Parameter sortDescriptor: **`NSSortDescriptor`** yang mendefinisikan kunci (`key`)
    ///   untuk perbandingan utama dan arah pengurutan (`ascending`). Saat ini, hanya kunci "Mapel"
    ///   yang didukung untuk pengurutan.
    ///
    /// - Returns: **Indeks (`Index`)** di mana `element` harus disisipkan untuk menjaga
    ///   urutan array yang benar. Jika `element` lebih besar dari semua elemen yang ada
    ///   (sesuai dengan kriteria pengurutan), maka akan mengembalikan `self.endIndex`.
    ///
    /// - Catatan:
    ///   - Saat ini, logika pengurutan hanya diterapkan untuk `sortDescriptor.key` yang bernilai `"Mapel"`.
    ///     Jika kunci lain digunakan, perilaku default (`return true`) akan menyebabkan `firstIndex`
    ///     selalu mengembalikan `0`, yang mungkin bukan perilaku yang diinginkan dan dapat
    ///     menimbulkan masalah dalam pengurutan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        firstIndex { item in
            switch sortDescriptor.key {
            case "Mapel":
                // Membandingkan nama mata pelajaran (`namaMapel`) dari kedua MapelModel.
                // Jika `ascending` true, cari indeks di mana `namaMapel` item saat ini
                // lebih besar atau sama dengan `namaMapel` elemen baru.
                // Jika `ascending` false, cari indeks di mana `namaMapel` item saat ini
                // lebih kecil atau sama dengan `namaMapel` elemen baru.
                sortDescriptor.ascending ? item.namaMapel >= element.namaMapel : item.namaMapel <= element.namaMapel
            default:
                // Jika `sortDescriptor.key` bukan "Mapel", `true` dikembalikan, yang akan
                // menyebabkan `firstIndex` segera mengembalikan indeks 0.
                // Ini berarti elemen akan disisipkan di awal array jika kunci tidak cocok.
                // Pertimbangkan untuk menambahkan penanganan kasus lain atau mengembalikan `false`
                // jika perilaku ini tidak diinginkan.
                true
            }
        } ?? endIndex // Jika tidak ada item yang memenuhi kondisi `firstIndex`, elemen akan disisipkan di akhir array.
    }
}
