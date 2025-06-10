//
//  GuruModel.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 19/10/23.
//

import Foundation

/// `MapelModel` adalah sebuah struktur data yang merepresentasikan mata pelajaran.
///
/// Struktur ini dirancang untuk dapat dibandingkan (`Equatable`) dan dapat di-*hash* (`Hashable`),
/// yang membuatnya cocok untuk digunakan dalam koleksi seperti `Set` atau sebagai kunci dalam `Dictionary`.
/// Kesetaraan dan nilai *hash* didasarkan pada properti `id` yang unik.
public class MapelModel: Equatable, Hashable {
    // MARK: - Properti

    /// Pengidentifikasi unik untuk mata pelajaran.
    /// Ini digunakan untuk menentukan kesetaraan dan untuk menghasilkan nilai *hash*.
    public var id: UUID

    /// Nama mata pelajaran (misalnya, "Matematika", "Fisika", "Bahasa Indonesia").
    public var namaMapel: String

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
        self.namaMapel = namaMapel
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
    public static func == (lhs: MapelModel, rhs: MapelModel) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Implementasi Protokol Hashable

    /// Mengimplementasikan metode `hash(into:)` untuk mendukung protokol `Hashable`.
    ///
    /// Nilai *hash* untuk `MapelModel` dihasilkan hanya dari properti `id` untuk memastikan
    /// konsistensi dengan implementasi `Equatable`.
    ///
    /// - Parameter hasher: `Hasher` yang digunakan untuk menggabungkan nilai *hash*.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// `GuruModel` adalah kelas yang merepresentasikan data seorang guru.
///
/// Kelas ini mengimplementasikan protokol `Comparable` dan `Equatable`, memungkinkan
/// instance `GuruModel` untuk dibandingkan dan dicek kesetaraannya.
///
/// - Properti:
///   - `idGuru`: `Int64` yang unik untuk setiap guru. Digunakan dalam perbandingan dan kesetaraan.
///   - `namaGuru`: Nama lengkap guru.
///   - `alamatGuru`: Alamat tempat tinggal guru.
///   - `tahunaktif`: Tahun di mana guru aktif mengajar.
///   - `mapel`: Mata pelajaran yang diajar oleh guru.
///   - `struktural`: Posisi struktural atau jabatan guru (misalnya, "Kepala Sekolah", "Guru Kelas").
///   - `menuNeedsUpdate`: Sebuah flag `Bool` yang bisa digunakan untuk menandakan apakah UI terkait guru perlu diperbarui.
///
/// - Catatan:
///   Implementasi `Comparable` dan `Equatable` mempertimbangkan *semua* properti yang didefinisikan.
///   Metode `copy()` menyediakan cara untuk membuat salinan *deep copy* dari instance `GuruModel`.
class GuruModel: Comparable {
    // MARK: - Properti

    var idGuru: Int64 = 0
    var namaGuru: String = ""
    var alamatGuru: String = ""
    var tahunaktif: String = ""
    var mapel: String = ""
    var struktural: String = ""
    var menuNeedsUpdate: Bool = false

    // MARK: - Inisialisasi

    /// Menginisialisasi instance `GuruModel` kosong dengan nilai default.
    public init() {}

    /// Menginisialisasi instance `GuruModel` dengan detail yang diberikan.
    ///
    /// - Parameters:
    ///   - idGuru: ID unik guru.
    ///   - nama: Nama lengkap guru.
    ///   - alamat: Alamat guru.
    ///   - tahunaktif: Tahun aktif guru.
    ///   - mapel: Mata pelajaran yang diajar.
    ///   - struktural: Posisi struktural guru.
    public init(idGuru: Int64, nama: String, alamat: String, tahunaktif: String, mapel: String, struktural: String) {
        self.idGuru = idGuru
        namaGuru = nama
        alamatGuru = alamat
        self.tahunaktif = tahunaktif
        self.mapel = mapel
        self.struktural = struktural
    }

    // MARK: - Implementasi Protokol Comparable

    /// Mengimplementasikan operator "kurang dari" (`<`) untuk `GuruModel`.
    ///
    /// Dua `GuruModel` dianggap "kurang dari" jika semua properti (`idGuru`, `namaGuru`,
    /// `alamatGuru`, `mapel`, `tahunaktif`, `struktural`) dari `lhs` secara leksikografis
    /// atau numerik kurang dari `rhs`.
    ///
    /// - Parameters:
    ///   - lhs: `GuruModel` di sisi kiri operator.
    ///   - rhs: `GuruModel` di sisi kanan operator.
    /// - Returns: `true` jika `lhs` dianggap "kurang dari" `rhs` berdasarkan perbandingan semua properti.
    static func < (lhs: GuruModel, rhs: GuruModel) -> Bool {
        lhs.idGuru < rhs.idGuru &&
            lhs.namaGuru < rhs.namaGuru &&
            lhs.alamatGuru < rhs.alamatGuru &&
            lhs.mapel < rhs.mapel &&
            lhs.tahunaktif < rhs.tahunaktif &&
            lhs.struktural < rhs.struktural
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mengimplementasikan operator kesetaraan (`==`) untuk `GuruModel`.
    ///
    /// Dua `GuruModel` dianggap sama jika *semua* properti (`idGuru`, `namaGuru`,
    /// `alamatGuru`, `mapel`, `tahunaktif`, `struktural`) mereka sama.
    ///
    /// - Parameters:
    ///   - lhs: `GuruModel` di sisi kiri operator.
    ///   - rhs: `GuruModel` di sisi kanan operator.
    /// - Returns: `true` jika kedua guru memiliki nilai properti yang sama, `false` jika sebaliknya.
    static func == (lhs: GuruModel, rhs: GuruModel) -> Bool {
        lhs.idGuru == rhs.idGuru &&
            lhs.namaGuru == rhs.namaGuru &&
            lhs.alamatGuru == rhs.alamatGuru &&
            lhs.mapel == rhs.mapel &&
            lhs.tahunaktif == rhs.tahunaktif &&
            lhs.struktural == rhs.struktural
    }

    // MARK: - Metode Lainnya

    /// Membuat salinan (deep copy) baru dari instance `GuruModel` saat ini.
    ///
    /// Ini sangat berguna ketika Anda perlu memodifikasi objek `GuruModel` tanpa
    /// memengaruhi instance aslinya, karena `GuruModel` adalah *reference type* (kelas).
    ///
    /// - Returns: Instance `GuruModel` baru dengan nilai properti yang sama dengan instance saat ini.
    func copy() -> GuruModel {
        let newCopy = GuruModel()
        newCopy.idGuru = idGuru
        newCopy.namaGuru = namaGuru
        newCopy.alamatGuru = alamatGuru
        newCopy.tahunaktif = tahunaktif
        newCopy.mapel = mapel
        newCopy.struktural = struktural
        return newCopy
    }
}

extension [GuruModel] {
    /// Menemukan indeks penyisipan yang tepat untuk sebuah elemen baru dalam array,
    /// mempertahankan urutan yang ditentukan oleh `NSSortDescriptor`.
    ///
    /// Fungsi ini mengiterasi elemen-elemen yang ada dan membandingkan properti kunci
    /// dari elemen yang akan disisipkan (`element`) dengan properti yang sama dari
    /// setiap item yang sudah ada (`item`). Perbandingan ini disesuaikan dengan
    /// arah pengurutan (`ascending` atau `descending`) yang ditentukan oleh `sortDescriptor`.
    /// Untuk kasus di mana properti kunci utama sama, fungsi ini menggunakan `namaGuru`
    /// sebagai kriteria pengurutan sekunder untuk memastikan pengurutan yang stabil.
    ///
    /// - Parameter element: **Elemen** baru yang akan disisipkan ke dalam array.
    /// - Parameter sortDescriptor: **`NSSortDescriptor`** yang mendefinisikan kunci (`key`)
    ///   untuk perbandingan utama dan arah pengurutan (`ascending`).
    ///
    /// - Returns: **Indeks (`Index`)** di mana `element` harus disisipkan untuk menjaga
    ///   urutan array yang benar. Jika `element` lebih besar dari semua elemen yang ada
    ///   (sesuai dengan kriteria pengurutan), maka akan mengembalikan `self.endIndex`.
    ///
    /// - Catatan:
    ///   - Fungsi ini mengasumsikan bahwa `Element` adalah tipe yang memiliki properti
    ///     `namaGuru`, `alamatGuru`, `tahunaktif`, `mapel`, dan `struktural`
    ///     yang semuanya berjenis `String`.
    ///   - Kriteria pengurutan sekunder selalu `namaGuru` ketika kunci utama sama,
    ///     kecuali ketika kunci utama adalah `namaGuru` itu sendiri, di mana `alamatGuru`
    ///     digunakan sebagai kriteria sekunder. Ini perlu dikonfirmasi apakah perilaku
    ///     ini yang diinginkan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        firstIndex { item in
            switch sortDescriptor.key {
            case "NamaGuru":
                if item.namaGuru == item.namaGuru {
                    // Jika alamat sama, bandingkan nama siswa sebagai kriteria kedua
                    let compareResult = item.namaGuru.compare(element.namaGuru)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.alamatGuru >= element.alamatGuru)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.alamatGuru <= element.alamatGuru)
                    }
                } else {
                    return sortDescriptor.ascending ? item.namaGuru >= element.namaGuru : item.namaGuru <= element.namaGuru
                }
            case "AlamatGuru":
                if item.alamatGuru == element.alamatGuru {
                    // Jika alamat sama, bandingkan nama siswa sebagai kriteria kedua
                    let compareResult = item.namaGuru.compare(element.namaGuru)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.namaGuru >= element.namaGuru)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.namaGuru <= element.namaGuru)
                    }
                } else {
                    return sortDescriptor.ascending ? item.alamatGuru >= element.alamatGuru : item.alamatGuru <= element.alamatGuru
                }
            case "TahunAkfif":
                if item.tahunaktif == element.tahunaktif {
                    let compareResult = item.namaGuru.compare(element.namaGuru)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.namaGuru >= element.namaGuru)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.namaGuru <= element.namaGuru)
                    }
                } else {
                    return sortDescriptor.ascending ? item.tahunaktif >= element.tahunaktif : item.tahunaktif <= element.tahunaktif
                }
            case "Mapel":
                if item.mapel == element.mapel {
                    let compareResult = item.tahunaktif.compare(element.tahunaktif)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.tahunaktif >= element.tahunaktif)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.tahunaktif <= element.tahunaktif)
                    }
                } else {
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "Struktural":
                if item.struktural == element.struktural {
                    let compareResult = item.struktural.compare(element.struktural)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.namaGuru >= element.namaGuru)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.namaGuru <= element.namaGuru)
                    }
                } else {
                    return sortDescriptor.ascending ? item.struktural >= element.struktural : item.struktural <= element.struktural
                }
            default:
                return true
            }
        } ?? endIndex
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
