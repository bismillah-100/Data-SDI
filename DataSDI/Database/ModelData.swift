//
//  ModelData.swift
//  ReadDB
//
//  Created by Bismillah on 16/10/23.
//

import SQLite

/// `ColumnInfo` adalah struktur data yang ringkas untuk menyimpan informasi dasar tentang sebuah kolom.
/// Ini utamanya digunakan untuk mengidentifikasi kolom secara unik dan menyediakan judul yang
/// mudah dibaca untuk tampilan di antarmuka pengguna, seperti dalam tabel.
struct ColumnInfo {
    /// Pengidentifikasi unik untuk kolom. Ini biasanya digunakan secara internal untuk
    /// merujuk pada kolom tertentu dalam kode atau skema database.
    var identifier: String

    /// Judul kustom untuk kolom yang akan ditampilkan kepada pengguna.
    /// Ini bisa berbeda dari `identifier` untuk memberikan nama yang lebih deskriptif atau ramah pengguna.
    var customTitle: String
}

/// `AutoCompletion` adalah struktur yang digunakan untuk menyimpan berbagai data
/// yang mungkin diperlukan untuk fitur pelengkapan otomatis (autocompletion) di antarmuka pengguna.
/// Ini mengelompokkan string yang terkait dengan siswa, guru, mata pelajaran, dan detail lainnya.
struct AutoCompletion {
    // MARK: - Properti

    /// Nama siswa untuk pelengkapan otomatis.
    var namasiswa = ""

    /// Nama guru untuk pelengkapan otomatis.
    var namaguru = ""

    /// Nama mata pelajaran untuk pelengkapan otomatis.
    var mapel = ""

    /// Semester untuk pelengkapan otomatis.
    var semester = ""

    /// Alamat untuk pelengkapan otomatis.
    var alamat = ""

    /// Nama ayah untuk pelengkapan otomatis.
    var ayah = ""

    /// Nama ibu untuk pelengkapan otomatis.
    var ibu = ""

    /// Nama wali untuk pelengkapan otomatis.
    var wali = ""

    /// Nomor telepon atau seluler untuk pelengkapan otomatis.
    var tlv = ""

    /// Nomor Induk Siswa (NIS) untuk pelengkapan otomatis.
    var nis = ""

    /// Nomor Induk Siswa Nasional (NISN) untuk pelengkapan otomatis.
    var nisn = ""

    /// Tanggal lahir untuk pelengkapan otomatis.
    var tanggallahir = ""

    /// Kategori (misalnya, acara, siswa, dll.) untuk pelengkapan otomatis.
    var kategori = ""

    /// Acara untuk pelengkapan otomatis.
    var acara = ""

    /// Keperluan (misalnya, kunjungan, pengajuan) untuk pelengkapan otomatis.
    var keperluan = ""

    /// Jabatan (misalnya, guru, staf) untuk pelengkapan otomatis.
    var jabatan = ""
}

/// `Column` adalah struktur yang merepresentasikan definisi sebuah kolom dalam tabel.
/// Ini menyimpan nama kolom dan tipe data yang diharapkan untuk nilai-nilai dalam kolom tersebut.
/// Mengimplementasikan `Sendable` yang menunjukkan bahwa instance dapat dikirimkan melintasi batas-batas konkuren.
struct Column: Sendable {
    // MARK: - Properti

    /// Nama kolom. Properti ini dapat diubah melalui metode `rename`.
    private(set) var name: String

    /// Tipe data yang diharapkan untuk nilai-nilai dalam kolom ini (misalnya, `String.self`, `Int.self`).
    let type: Any.Type

    // MARK: - Inisialisasi

    /// Menginisialisasi instance `Column` baru dengan nama dan tipe data yang ditentukan.
    ///
    /// - Parameters:
    ///   - name: Nama awal kolom.
    ///   - type: Tipe data untuk nilai kolom.
    init(name: String, type: Any.Type) {
        self.name = name
        self.type = type
    }

    // MARK: - Metode Mutating

    /// Mengubah nama kolom menjadi nama baru yang ditentukan.
    ///
    /// - Parameter newName: Nama baru untuk kolom.
    mutating func rename(_ newName: String) {
        name = newName
    }
}

/// Sebuah protokol untuk tipe-tipe yang dapat diurutkan secara dinamis menggunakan `NSSortDescriptor`
/// melalui `KeyPath` yang aman-tipe (type-safe).
///
/// Tipe yang mengadopsi protokol ini, yang harus berupa kelas (`AnyObject`), mendefinisikan sebuah pemetaan
/// dari kunci berbasis `String` ke `KeyPath` Swift. Ini memungkinkan pembuatan comparator
/// pengurutan yang efisien dan stabil, menjembatani API Objective-C lama (seperti `NSSortDescriptor`)
/// dengan fitur modern Swift.
///
/// Protokol ini juga mendukung pengurutan sekunder sebagai tie-breaker untuk memastikan
/// urutan yang konsisten dan dapat diprediksi.
///
/// ### Persyaratan
/// 1. `keyPathMap`: Kamus yang memetakan nama kunci (`String`) ke `PartialKeyPath<Self>`.
///    Ini adalah pemetaan utama untuk `NSSortDescriptor`.
/// 2. `secondaryKeyPaths`: Array `PartialKeyPath<Self>` yang digunakan untuk pengurutan
///    tambahan jika perbandingan primer menghasilkan kesamaan.
///
/// ### Contoh Penggunaan
///
/// ```swift
/// class Buku: NSObject, SortableKey {
///     @objc let judul: String
///     @objc let tahunTerbit: Int64
///     @objc let penulis: String?
///
///     init(judul: String, tahunTerbit: Int64, penulis: String?) {
///         self.judul = judul
///         self.tahunTerbit = tahunTerbit
///         self.penulis = penulis
///     }
///
///     static var keyPathMap: [String : PartialKeyPath<Buku>] = [
///         "judul": \Buku.judul,
///         "tahunTerbit": \Buku.tahunTerbit
///     ]
///
///     // Jika tahun terbit sama, urutkan berdasarkan judul
///     static var secondaryKeyPaths: [PartialKeyPath<Buku>] = [\Buku.judul]
/// }
///
/// let daftarBuku = [
///     Buku(judul: "Laskar Pelangi", tahunTerbit: 2005, penulis: "Andrea Hirata"),
///     Buku(judul: "Bumi Manusia", tahunTerbit: 1980, penulis: "Pramoedya Ananta Toer"),
///     Buku(judul: "Negeri 5 Menara", tahunTerbit: 2009, penulis: "Ahmad Fuadi"),
///     Buku(judul: "Cantik Itu Luka", tahunTerbit: 2002, penulis: "Eka Kurniawan")
/// ]
///
/// // Buat sort descriptor untuk mengurutkan berdasarkan 'tahunTerbit' secara menurun
/// let sortDescriptor = NSSortDescriptor(key: "tahunTerbit", ascending: false)
///
/// // Buat comparator menggunakan protokol
/// if let comparator = Buku.comparator(from: sortDescriptor) {
///     let bukuTerurut = daftarBuku.sorted(by: comparator)
///     bukuTerurut.forEach { print("\($0.judul) (\($0.tahunTerbit))") }
/// }
/// // Hasil:
/// // Negeri 5 Menara (2009)
/// // Laskar Pelangi (2005)
/// // Cantik Itu Luka (2002)
/// // Bumi Manusia (1980)
/// ```
protocol SortableKey: AnyObject {
    /// Dictionary yang memetakan nama kunci (`String`) ke `KeyPath` yang
    /// sesuai.
    ///
    /// Properti ini berfungsi sebagai "peta" yang memungkinkan kita untuk mengidentifikasi
    /// `KeyPath` yang akan digunakan untuk pengurutan primer, berdasarkan
    /// nama string yang diberikan.
    static var keyPathMap: [String: PartialKeyPath<Self>] { get }

    /// Sebuah array dari `KeyPath` yang digunakan untuk pengurutan sekunder
    /// (tie-breaker).
    ///
    /// Properti ini digunakan jika dua objek memiliki nilai yang sama pada
    /// `KeyPath` pengurutan primer. `KeyPath` dalam array ini akan digunakan
    /// secara berurutan untuk membandingkan objek hingga ditemukan perbedaan,
    /// memastikan pengurutan yang stabil.
    static var secondaryKeyPaths: [PartialKeyPath<Self>] { get }
}

extension SortableKey {
    /// Membuat sebuah closure perbandingan (`ComparisonResult`) dari `PartialKeyPath`.
    ///
    /// Fungsi ini secara dinamis menghasilkan logika perbandingan berdasarkan tipe data
    /// dari `KeyPath` yang diberikan. Mendukung tipe `String`, `Int64`, `Date`,
    /// dan versi opsionalnya.
    ///
    /// - Parameters:
    ///   - keyPath: `PartialKeyPath` yang akan digunakan untuk perbandingan.
    ///   - ascending: `true` untuk urutan menaik (ascending), `false` untuk menurun (descending).
    /// - Returns: Sebuah closure `((Self, Self) -> ComparisonResult)?` yang membandingkan
    ///   dua objek dari tipe `Self`. Mengembalikan `nil` jika tipe data `KeyPath` tidak didukung.
    static func createComparator(for keyPath: PartialKeyPath<Self>, ascending: Bool) -> ((Self, Self) -> ComparisonResult)? {
        // Helper untuk membandingkan nilai non-opsional
        func compare<U: Comparable>(_ lhs: U, _ rhs: U, ascending: Bool) -> ComparisonResult {
            if lhs < rhs {
                ascending ? .orderedAscending : .orderedDescending
            } else if lhs > rhs {
                ascending ? .orderedDescending : .orderedAscending
            } else {
                .orderedSame
            }
        }

        // Helper untuk membandingkan nilai opsional, dengan nilai default jika nil
        func compareOptional<U: Comparable>(_ lhs: U?, _ rhs: U?, defaultValue: U, ascending: Bool) -> ComparisonResult {
            let v1 = lhs ?? defaultValue
            let v2 = rhs ?? defaultValue
            return compare(v1, v2, ascending: ascending)
        }

        switch keyPath {
        case let path as KeyPath<Self, String>:
            return { compare($0[keyPath: path], $1[keyPath: path], ascending: ascending) }

        case let path as KeyPath<Self, String?>:
            return { compareOptional($0[keyPath: path], $1[keyPath: path], defaultValue: "", ascending: ascending) }

        case let path as KeyPath<Self, Int64>:
            return { compare($0[keyPath: path], $1[keyPath: path], ascending: ascending) }

        case let path as KeyPath<Self, Int64?>:
            return { compareOptional($0[keyPath: path], $1[keyPath: path], defaultValue: Int64.min, ascending: ascending) }

        case let path as KeyPath<Self, Date>:
            return { compare($0[keyPath: path], $1[keyPath: path], ascending: ascending) }

        case let path as KeyPath<Self, Date?>:
            return { compareOptional($0[keyPath: path], $1[keyPath: path], defaultValue: .distantPast, ascending: ascending) }

        default:
            #if DEBUG
                print("Tipe data untuk KeyPath tidak didukung: \(keyPath)")
            #endif
            return nil
        }
    }

    /// Membuat sebuah closure pengurutan (`(Self, Self) -> Bool`) dari `NSSortDescriptor`.
    ///
    /// Fungsi ini adalah titik masuk utama untuk membuat logika pengurutan. Ia melakukan hal berikut:
    /// 1. Mencari `KeyPath` primer dari `keyPathMap` berdasarkan `key` dari `sortDescriptor`.
    /// 2. Membuat comparator primer.
    /// 3. Membuat comparator sekunder dari `secondaryKeyPaths`.
    /// 4. Menggabungkan semua comparator, dengan `ObjectIdentifier` sebagai tie-breaker
    ///    terakhir untuk memastikan pengurutan yang stabil.
    ///
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan.
    /// - Returns: Sebuah closure `((Self, Self) -> Bool)?` yang cocok untuk digunakan
    ///   dengan metode `sort(by:)` dari Swift. Mengembalikan `nil` jika `key` dari
    ///   `sortDescriptor` tidak ditemukan di `keyPathMap`.
    static func comparator(from sortDescriptor: NSSortDescriptor) -> ((Self, Self) -> Bool)? {
        guard let key = sortDescriptor.key,
              let path = keyPathMap[key]
        else {
            return nil
        }

        let primaryComparator = createComparator(for: path, ascending: sortDescriptor.ascending)
        let secondaryComparators = secondaryKeyPaths.compactMap { createComparator(for: $0, ascending: true) }

        return { obj1, obj2 -> Bool in
            // 1. Perbandingan Primer
            if let primaryResult = primaryComparator?(obj1, obj2), primaryResult != .orderedSame {
                return primaryResult == .orderedAscending
            }

            // 2. Perbandingan Sekunder
            for secondaryCmp in secondaryComparators {
                let secondaryResult = secondaryCmp(obj1, obj2)
                if secondaryResult != .orderedSame {
                    return secondaryResult == .orderedAscending
                }
            }

            // 3. Tie-breaker terakhir menggunakan ObjectIdentifier untuk stabilitas
            return ObjectIdentifier(obj1) < ObjectIdentifier(obj2)
        }
    }
}

extension RandomAccessCollection {
    /// Menentukan indeks di mana sebuah elemen harus disisipkan ke dalam koleksi
    /// yang sudah diurutkan agar urutan tetap terjaga.
    ///
    /// Metode ini menggunakan algoritma **pencarian biner** (binary search)
    /// untuk menemukan posisi penyisipan secara efisien. Kinerja pencarian
    /// ini adalah **O(log n)**, di mana `n` adalah jumlah elemen dalam koleksi.
    ///
    /// - Parameters:
    ///   - element: Elemen yang akan disisipkan.
    ///   - areInIncreasingOrder: Sebuah closure yang mengembalikan `true` jika elemen
    ///     pertama harus diurutkan sebelum elemen kedua. Logika closure ini
    ///     harus konsisten dengan urutan koleksi saat ini.
    ///
    /// - Returns: Indeks terendah di mana `element` dapat disisipkan sambil
    ///   menjaga urutan koleksi.
    ///
    /// ### Contoh Penggunaan
    ///
    /// ```swift
    /// // Misalkan Anda memiliki array yang sudah diurutkan
    /// let sortedNumbers = [10, 20, 30, 40, 50]
    ///
    /// // Temukan indeks untuk menyisipkan 35
    /// // Closure `<` digunakan karena array diurutkan secara menaik (ascending)
    /// let insertionIndex = sortedNumbers.insertionIndex(for: 35, using: <)
    /// print("Indeks penyisipan untuk 35 adalah \(insertionIndex)")
    /// // Hasil: Indeks penyisipan untuk 35 adalah 3
    ///
    /// // Temukan indeks untuk menyisipkan 5
    /// let newIndex = sortedNumbers.insertionIndex(for: 5, using: <)
    /// print("Indeks penyisipan untuk 5 adalah \(newIndex)")
    /// // Hasil: Indeks penyisipan untuk 5 adalah 0
    ///
    /// // Temukan indeks untuk 30 (elemen yang sudah ada)
    /// // Hasilnya adalah indeks pertama di mana 30 bisa disisipkan
    /// let existingElementIndex = sortedNumbers.insertionIndex(for: 30, using: <)
    /// print("Indeks penyisipan untuk 30 adalah \(existingElementIndex)")
    /// // Hasil: Indeks penyisipan untuk 30 adalah 2
    /// ```
    ///
    /// - Penting: Metode ini mengasumsikan bahwa koleksi sudah **diurutkan**
    ///   sesuai dengan kriteria `areInIncreasingOrder`. Jika tidak, hasil yang
    ///   dikembalikan tidak akan benar.
    func insertionIndex<T>(
        for element: T,
        using areInIncreasingOrder: (Element, T) -> Bool
    ) -> Index {
        var low = startIndex
        var high = endIndex

        while low < high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
            if areInIncreasingOrder(self[mid], element) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}
