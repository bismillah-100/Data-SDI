//
//  ModelData.swift
//  ReadDB
//
//  Created by Bismillah on 16/10/23.
//

import Foundation
import SQLite

/// Struktur yang merepresentasikan ringkasan data seorang siswa.
///
/// Struktur ini menyimpan nama siswa, nilai rata-rata, dan total nilai yang diperoleh.
struct StudentSummary {
    var name: String
    var averageScore: Double
    var totalScore: Int
}

/// Subclass dari ``KelasModels``
class Kelas1Model: KelasModels {}
/// Subclass dari ``KelasModels``
class Kelas2Model: KelasModels {}
/// Subclass dari ``KelasModels``
class Kelas3Model: KelasModels {}
/// Subclass dari ``KelasModels``
class Kelas4Model: KelasModels {}
/// Subclass dari ``KelasModels``
class Kelas5Model: KelasModels {}
/// Subclass dari ``KelasModels``
class Kelas6Model: KelasModels {}

/// Sebuah model yang merepresentasikan catatan kelas, termasuk informasi siswa, mata pelajaran, dan nilai.
/// Mengimplementasikan protokol `Comparable` untuk logika perbandingan khusus, dan secara implisit juga `Equatable`.
/// Mengimplementasikan protokol `NSCopying` untuk memungkinkan pembuatan salinan objek.
public class KelasModels: Comparable, NSCopying {
    // MARK: - Properti

    /// Pengidentifikasi unik untuk catatan kelas.
    public var kelasID: Int64 = 0

    /// Nama mata pelajaran.
    public var mapel: String = ""

    /// Nilai atau skor untuk mata pelajaran. Nilai default adalah 0 jika tidak diberikan.
    public var nilai: Int64 = 0

    /// Pengidentifikasi unik untuk siswa.
    public var siswaID: Int64 = 0

    /// Nama siswa.
    public var namasiswa: String = ""

    /// Nama guru.
    public var namaguru: String = ""

    /// Semester akademik (contoh: "Ganjil", "Genap").
    public var semester: String = ""

    /// Tanggal yang terkait dengan catatan, biasanya dalam format string (contoh: "YYYY-MM-DD").
    public var tanggal: String = ""

    /// Sebuah *flag* yang menunjukkan apakah menu pembaruan harus ditampilkan untuk catatan ini.
    public var updateMenu: Bool = false

    // MARK: - Properti Statis

    /// Sebuah `NSSortDescriptor` statis untuk menyimpan preferensi pengurutan saat ini untuk instansi `KelasModels`.
    /// Ini memungkinkan mekanisme pengurutan eksternal untuk mereferensikan deskriptor pengurutan bersama.
    public static var currentSortDescriptor: NSSortDescriptor?

    /// Sebuah `NSSortDescriptor` statis khusus untuk mengurutkan instansi `KelasModels` berdasarkan siswa.
    public static var siswaSortDescriptor: NSSortDescriptor?

    // MARK: - Inisialisasi

    /// Menginisialisasi instansi `KelasModels` baru yang kosong.
    /// Ini adalah inisialisasi yang diperlukan untuk memenuhi protokol `NSCopying`.
    public required init() {}

    /// Menginisialisasi instansi `KelasModels` dengan detail yang diberikan.
    ///
    /// - Parameters:
    ///   - kelasID: ID unik untuk catatan kelas.
    ///   - siswaID: ID unik untuk siswa.
    ///   - namasiswa: Nama siswa.
    ///   - mapel: Nama mata pelajaran.
    ///   - nilai: Nilai atau skor. Jika `nil`, maka nilai default-nya adalah `0`.
    ///   - namaguru: Nama guru.
    ///   - semester: Semester akademik.
    ///   - tanggal: Tanggal catatan.
    public required init(kelasID: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64?, namaguru: String, semester: String, tanggal: String) {
        self.kelasID = kelasID
        self.siswaID = siswaID
        self.mapel = mapel
        self.nilai = nilai ?? 0 // Menggunakan nil coalescing untuk default ke 0 jika nilai adalah nil
        self.namasiswa = namasiswa
        self.namaguru = namaguru
        self.semester = semester
        self.tanggal = tanggal
    }

    // MARK: - Implementasi Protokol Comparable

    /// Mendefinisikan operator "kurang dari" (`<`) untuk instansi `KelasModels`.
    /// Implementasi ini membandingkan setiap properti untuk menentukan urutan.
    ///
    /// **Catatan Penting**: Implementasi asli dari operator `<` ini sebenarnya
    /// mendefinisikan kesamaan (`==`) bukan urutan "kurang dari". Ini berarti
    /// dua objek dianggap "kurang dari" satu sama lain jika semua properti yang
    /// dibandingkan sama. Untuk pengurutan yang benar, logika ini mungkin perlu
    /// disesuaikan agar sesuai dengan kriteria pengurutan yang spesifik (misalnya,
    /// mengurutkan berdasarkan `tanggal`, kemudian `kelasID`, dll.).
    public static func < (lhs: KelasModels, rhs: KelasModels) -> Bool {
        // Implementasi ini sebenarnya mendefinisikan kesamaan, bukan urutan "kurang dari".
        // Untuk pengurutan, logika perlu disesuaikan.
        lhs.kelasID == rhs.kelasID &&
            lhs.mapel == rhs.mapel &&
            lhs.nilai == rhs.nilai &&
            lhs.siswaID == rhs.siswaID &&
            lhs.namasiswa == rhs.namasiswa &&
            lhs.namaguru == rhs.namaguru &&
            lhs.semester == rhs.semester
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instansi `KelasModels`.
    /// Dua instansi `KelasModels` dianggap sama jika semua properti pentingnya sama.
    public static func == (lhs: KelasModels, rhs: KelasModels) -> Bool {
        lhs.kelasID == rhs.kelasID &&
            lhs.mapel == rhs.mapel &&
            lhs.nilai == rhs.nilai &&
            lhs.siswaID == rhs.siswaID &&
            lhs.namasiswa == rhs.namasiswa &&
            lhs.namaguru == rhs.namaguru &&
            lhs.semester == rhs.semester
        // `tanggal` tidak termasuk dalam perbandingan kesamaan, pertimbangkan untuk menambahkannya jika relevan.
        // `updateMenu` juga tidak termasuk karena biasanya ini adalah properti UI atau status sementara.
    }

    // MARK: - Implementasi Protokol NSCopying

    /// Membuat salinan (copy) dari instansi `KelasModels` saat ini.
    ///
    /// - Parameter zone: Tidak digunakan dalam implementasi ini, dapat diabaikan.
    /// - Returns: Sebuah objek `Any` yang merupakan salinan dari instansi `KelasModels` ini.
    ///            Perlu dilakukan *downcast* ke `KelasModels` saat digunakan.
    public func copy(with zone: NSZone? = nil) -> Any {
        KelasModels(kelasID: kelasID,
                    siswaID: siswaID,
                    namasiswa: namasiswa,
                    mapel: mapel,
                    nilai: nilai,
                    namaguru: namaguru,
                    semester: semester,
                    tanggal: tanggal)
    }
}

/// Lihat: ``KelasModels``
class KelasModel {
    public var kelasID: Int64 = 0
    public var mapel: String
    public var nilai: Int64
    public var siswaID: Int64
    public var namasiswa: String
    public var namaguru: String
    public var semester: String
    public var tanggal: String

    init(siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, namaguru: String, tanggal: String, semester: String) {
        self.siswaID = siswaID
        self.namasiswa = namasiswa
        self.mapel = mapel
        self.nilai = nilai
        self.namaguru = namaguru
        self.tanggal = tanggal
        self.semester = semester
    }
}

/// Subclass dari ``KelasPrint``
class Kelas1Print: KelasPrint {}
/// Subclass dari ``KelasPrint``
class Kelas2Print: KelasPrint {}
/// Subclass dari ``KelasPrint``
class Kelas3Print: KelasPrint {}
/// Subclass dari ``KelasPrint``
class Kelas4Print: KelasPrint {}
/// Subclass dari ``KelasPrint``
class Kelas5Print: KelasPrint {}
/// Subclass dari ``KelasPrint``
class Kelas6Print: KelasPrint {}
/// Sebuah model yang dirancang untuk menampung data yang akan dicetak atau ditampilkan
/// dalam format laporan, khususnya untuk nilai kelas.
class KelasPrint {
    // MARK: - Properti

    /// Nama siswa yang terkait dengan laporan.
    var namasiswa: String = ""

    /// Nama mata pelajaran.
    var mapel: String = ""

    /// Nilai atau skor mata pelajaran, disimpan sebagai `String` untuk fleksibilitas format cetak.
    var nilai: String = ""

    /// Nama guru yang mengajar mata pelajaran tersebut.
    var namaguru: String = ""

    /// Semester akademik (contoh: "Ganjil", "Genap") yang terkait dengan laporan ini.
    var semester: String = ""

    // MARK: - Inisialisasi

    /// Menginisialisasi instansi `KelasPrint` baru yang kosong.
    /// Semua properti akan diatur ke nilai *default* (string kosong).
    init() {}

    /// Menginisialisasi instansi `KelasPrint` dengan detail yang diberikan.
    ///
    /// - Parameters:
    ///   - namasiswa: Nama siswa.
    ///   - mapel: Nama mata pelajaran.
    ///   - nilai: Nilai atau skor dalam format `String`.
    ///   - namaguru: Nama guru.
    ///   - semester: Semester akademik.
    init(namasiswa: String, mapel: String, nilai: String, namaguru: String, semester: String) {
        self.namasiswa = namasiswa
        self.mapel = mapel
        self.nilai = nilai
        self.namaguru = namaguru
        self.semester = semester
    }

    // MARK: - Metode

    /// Mengatur data header untuk laporan cetak.
    /// Metode ini memungkinkan pembaruan semua properti utama dari objek `KelasPrint` secara bersamaan.
    ///
    /// - Parameters:
    ///   - namasiswa: Nama siswa.
    ///   - mapel: Nama mata pelajaran.
    ///   - nilai: Nilai atau skor dalam format `String`.
    ///   - semester: Semester akademik.
    ///   - namaguru: Nama guru.
    func setHeaderData(namasiswa: String, mapel: String, nilai: String, semester: String, namaguru: String) {
        self.namasiswa = namasiswa
        self.mapel = mapel
        self.nilai = nilai
        self.semester = semester
        self.namaguru = namaguru
    }
}

/// `ColumnInfo` adalah struktur data yang ringkas untuk menyimpan informasi dasar tentang sebuah kolom.
/// Ini utamanya digunakan untuk mengidentifikasi kolom secara unik dan menyediakan judul yang
/// mudah dibaca untuk tampilan di antarmuka pengguna, seperti dalam tabel.
public struct ColumnInfo {
    /// Pengidentifikasi unik untuk kolom. Ini biasanya digunakan secara internal untuk
    /// merujuk pada kolom tertentu dalam kode atau skema database.
    public var identifier: String

    /// Judul kustom untuk kolom yang akan ditampilkan kepada pengguna.
    /// Ini bisa berbeda dari `identifier` untuk memberikan nama yang lebih deskriptif atau ramah pengguna.
    public var customTitle: String
}

/// `StatusSiswa` merepresentasikan kemungkinan status seorang siswa di sekolah.
/// Ini menggunakan nilai `String` mentah (`rawValue`) yang akan ditampilkan kepada pengguna.
enum StatusSiswa: String {
    /// Siswa sedang aktif belajar di sekolah.
    case aktif = "Aktif"
    /// Siswa telah berhenti dari sekolah.
    case berhenti = "Berhenti"
    /// Siswa telah lulus dari sekolah.
    case lulus = "Lulus"
}

/// `KelasAktif` merepresentasikan tingkatan kelas yang berbeda dalam sebuah sekolah.
/// Ini menggunakan nilai `String` mentah (`rawValue`) yang akan ditampilkan sebagai nama kelas.
enum KelasAktif: String {
    /// Kelas 1.
    case kelas1 = "Kelas 1"
    /// Kelas 2.
    case kelas2 = "Kelas 2"
    /// Kelas 3.
    case kelas3 = "Kelas 3"
    /// Kelas 4.
    case kelas4 = "Kelas 4"
    /// Kelas 5.
    case kelas5 = "Kelas 5"
    /// Kelas 6.
    case kelas6 = "Kelas 6"
}

/// `DataAsli` adalah struktur untuk menyimpan data perubahan tunggal pada sebuah sel.
/// Ini merekam ID baris, indeks baris, pengidentifikasi kolom, serta nilai lama dan baru dari sel tersebut.
/// Mengimplementasikan `Equatable` untuk perbandingan kesamaan antar instansi.
public struct DataAsli: Equatable {
    // MARK: - Properti

    /// ID unik dari data yang diubah (misalnya, ID catatan di database).
    public var ID: Int64

    /// Indeks baris (`rowIndex`) tempat perubahan terjadi dalam tabel.
    public var rowIndex: Int

    /// Pengidentifikasi unik untuk kolom (`columnIdentifier`) tempat perubahan terjadi.
    public var columnIdentifier: String

    /// Nilai asli (`oldValue`) dari sel sebelum perubahan.
    public var oldValue: String

    /// Nilai baru (`newValue`) dari sel setelah perubahan.
    public var newValue: String

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instansi `DataAsli`.
    /// Dua instansi `DataAsli` dianggap sama jika semua propertinya (ID, rowIndex, columnIdentifier, oldValue, newValue) sama.
    public static func == (lhs: DataAsli, rhs: DataAsli) -> Bool {
        lhs.ID == rhs.ID &&
            lhs.rowIndex == rhs.rowIndex &&
            lhs.columnIdentifier == rhs.columnIdentifier &&
            lhs.oldValue == rhs.oldValue &&
            lhs.newValue == rhs.newValue
    }
}

class OriginalData: NSObject { // `NSObject` diperlukan jika digunakan dengan API Objective-C atau KVO.
    // MARK: - Properti

    /// ID kelas atau catatan terkait dengan perubahan.
    var kelasId: Int64 = 0

    /// Tipe tabel di mana perubahan terjadi (misalnya, siswa, nilai, dll.).
    /// `TableType` diasumsikan sebagai enum atau struct yang sudah didefinisikan di tempat lain.
    var tableType: TableType!

    /// Indeks baris tempat perubahan terjadi.
    var rowIndex: Int = 0

    /// Pengidentifikasi kolom tempat perubahan terjadi.
    var columnIdentifier: String = ""

    /// Nilai lama dari sel sebelum perubahan.
    var oldValue: String = ""

    /// Nilai baru dari sel setelah perubahan.
    var newValue: String = ""

    /// Referensi ke objek `Table` yang menyimpan data yang diubah.
    /// `Table` diasumsikan sebagai kelas atau struct yang sudah didefinisikan di tempat lain.
    var table: Table!

    /// Referensi ke objek `NSTableView` tempat perubahan visual terjadi.
    var tableView: NSTableView!

    // MARK: - Inisialisasi

    /// Menginisialisasi instansi `OriginalData` dengan detail lengkap tentang perubahan data.
    ///
    /// - Parameters:
    ///   - kelasId: ID kelas atau catatan.
    ///   - tableType: Tipe tabel.
    ///   - rowIndex: Indeks baris.
    ///   - columnIdentifier: Pengidentifikasi kolom.
    ///   - oldValue: Nilai lama sel.
    ///   - newValue: Nilai baru sel.
    ///   - table: Objek `Table` terkait.
    ///   - tableView: Objek `NSTableView` terkait.
    required init(kelasId: Int64, tableType: TableType, rowIndex: Int, columnIdentifier: String, oldValue: String, newValue: String, table: Table, tableView: NSTableView) {
        self.kelasId = kelasId
        self.tableType = tableType
        self.rowIndex = rowIndex
        self.columnIdentifier = columnIdentifier
        self.oldValue = oldValue
        self.newValue = newValue
        self.table = table
        self.tableView = tableView
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instansi `OriginalData`.
    /// Dua instansi `OriginalData` dianggap sama jika semua properti pentingnya (kecuali referensi objek) sama.
    /// Perbandingan `tableView` dilakukan berdasarkan referensi objek (`===`).
    static func == (lhs: OriginalData, rhs: OriginalData) -> Bool {
        lhs.kelasId == rhs.kelasId &&
            lhs.tableType == rhs.tableType &&
            lhs.rowIndex == rhs.rowIndex &&
            lhs.columnIdentifier == rhs.columnIdentifier &&
            lhs.oldValue == rhs.oldValue &&
            lhs.newValue == rhs.newValue &&
            // Membandingkan referensi objek `tableView` karena ini mungkin merujuk pada instansi UI yang sama.
            lhs.tableView === rhs.tableView
    }
}

/// `AutoCompletion` adalah struktur yang digunakan untuk menampung berbagai data
/// yang mungkin diperlukan untuk fitur pelengkapan otomatis (autocompletion) di antarmuka pengguna.
/// Ini mengelompokkan string yang terkait dengan siswa, guru, mata pelajaran, dan detail lainnya.
public struct AutoCompletion {
    // MARK: - Properti

    /// Nama siswa untuk pelengkapan otomatis.
    public var namasiswa = ""

    /// Nama guru untuk pelengkapan otomatis.
    public var namaguru = ""

    /// Nama mata pelajaran untuk pelengkapan otomatis.
    public var mapel = ""

    /// Semester untuk pelengkapan otomatis.
    public var semester = ""

    /// Alamat untuk pelengkapan otomatis.
    public var alamat = ""

    /// Nama ayah untuk pelengkapan otomatis.
    public var ayah = ""

    /// Nama ibu untuk pelengkapan otomatis.
    public var ibu = ""

    /// Nama wali untuk pelengkapan otomatis.
    public var wali = ""

    /// Nomor telepon atau seluler untuk pelengkapan otomatis.
    public var tlv = ""

    /// Nomor Induk Siswa (NIS) untuk pelengkapan otomatis.
    public var nis = ""

    /// Nomor Induk Siswa Nasional (NISN) untuk pelengkapan otomatis.
    public var nisn = ""

    /// Tanggal lahir untuk pelengkapan otomatis.
    public var tanggallahir = ""

    /// Kategori (misalnya, acara, siswa, dll.) untuk pelengkapan otomatis.
    public var kategori = ""

    /// Acara untuk pelengkapan otomatis.
    public var acara = ""

    /// Keperluan (misalnya, kunjungan, pengajuan) untuk pelengkapan otomatis.
    public var keperluan = ""

    /// Jabatan (misalnya, guru, staf) untuk pelengkapan otomatis.
    public var jabatan = ""
}

/// `Column` adalah struktur yang merepresentasikan definisi sebuah kolom dalam tabel.
/// Ini menyimpan nama kolom dan tipe data yang diharapkan untuk nilai-nilai dalam kolom tersebut.
/// Mengimplementasikan `Sendable` yang menunjukkan bahwa instansi dapat dikirimkan melintasi batas-batas konkuren.
struct Column: Sendable {
    // MARK: - Properti

    /// Nama kolom. Properti ini dapat diubah melalui metode `rename`.
    private(set) var name: String

    /// Tipe data yang diharapkan untuk nilai-nilai dalam kolom ini (misalnya, `String.self`, `Int.self`).
    let type: Any.Type

    // MARK: - Inisialisasi

    /// Menginisialisasi instansi `Column` baru dengan nama dan tipe data yang ditentukan.
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

/// `TableChange` adalah struktur sederhana untuk merekam perubahan data tunggal
/// yang terjadi dalam sebuah tabel, mencakup ID catatan, nama kolom, serta nilai lama dan baru.
struct TableChange {
    // MARK: - Properti

    /// ID unik dari catatan yang mengalami perubahan.
    let id: Int64

    /// Nama kolom di mana perubahan terjadi.
    let columnName: String

    /// Nilai lama dari sel sebelum perubahan. Tipe `Any` memungkinkan untuk berbagai jenis data.
    let oldValue: Any

    /// Nilai baru dari sel setelah perubahan. Tipe `Any` memungkinkan untuk berbagai jenis data.
    let newValue: Any
}

extension [ModelSiswa] {
    /// Sebuah ekstensi untuk `Array` di mana elemen-elemennya adalah `ModelSiswa`.
    /// Ekstensi ini menyediakan fungsionalitas untuk menemukan indeks penyisipan yang benar
    /// untuk sebuah elemen baru agar mempertahankan urutan array yang sudah diurutkan.
    ///
    /// **Catatan Penting**: Ekstensi ini memastikan bahwa `ModelSiswa` memiliki properti
    /// seperti `nama`, `alamat`, `ttl`, `tahundaftar`, `namawali`, `nis`, `nisn`, `ayah`,
    /// `ibu`, `tlv`, `jeniskelamin`, `status`, dan `tanggalberhenti` yang semuanya
    /// bertipe `String`.
    ///
    /// Menentukan indeks di mana sebuah elemen `ModelSiswa` baru harus disisipkan
    /// ke dalam array yang sudah diurutkan untuk mempertahankan urutan berdasarkan
    /// `NSSortDescriptor` yang diberikan.
    ///
    /// Metode ini menangani berbagai kunci pengurutan (`sortDescriptor.key`) dan
    /// menyediakan logika pengurutan sekunder (biasanya berdasarkan `nama` siswa)
    /// jika nilai pada kunci utama sama.
    ///
    /// - Parameters:
    ///   - element: Elemen `ModelSiswa` yang ingin Anda temukan indeks penyisipannya.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan
    ///                     (kunci dan urutan naik/turun).
    /// - Returns: Indeks (`Index`) di mana elemen harus disisipkan. Jika elemen harus
    ///            disisipkan di akhir array, `endIndex` akan dikembalikan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "nama":
                if item.nama == item.nama {
                    // Jika alamat sama, bandingkan nama siswa sebagai kriteria kedua
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.alamat >= element.alamat)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.alamat <= element.alamat)
                    }
                } else {
                    return sortDescriptor.ascending ? item.nama >= element.nama : item.nama <= element.nama
                }
            case "alamat":
                if item.alamat == element.alamat {
                    // Jika alamat sama, bandingkan nama siswa sebagai kriteria kedua
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.alamat >= element.alamat : item.alamat <= element.alamat
                }
            case "ttl":
                if item.ttl == element.ttl {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.ttl >= element.ttl : item.ttl <= element.ttl
                }
            case "tahundaftar":
                let date1 = dateFormatter.date(from: item.tahundaftar) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tahundaftar) ?? Date.distantPast
                if item.tahundaftar == element.tahundaftar {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            case "namawali":
                if item.namawali == element.namawali {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.namawali >= element.namawali : item.namawali <= element.namawali
                }
            case "nis":
                if item.nis == element.nis {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.nis >= element.nis : item.nis <= element.nis
                }
            case "nisn":
                if item.nisn == element.nisn {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.nisn >= element.nisn : item.nisn <= element.nisn
                }
            case "ayahkandung":
                if item.ayah == element.ayah {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.ayah >= element.ayah : item.ayah <= element.ayah
                }
            case "ibukandung":
                if item.ibu == element.ibu {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.ibu >= element.ibu : item.ibu <= element.ibu
                }
            case "telepon":
                if item.tlv == element.tlv {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.tlv >= element.tlv : item.tlv <= element.tlv
                }
            case "jeniskelamin":
                if item.jeniskelamin == element.jeniskelamin {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.jeniskelamin >= element.jeniskelamin : item.jeniskelamin <= element.jeniskelamin
                }
            case "status":
                if item.status == element.status {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? item.status >= element.status : item.status <= element.status
                }
            case "tanggalberhenti":
                let date1 = dateFormatter.date(from: item.tanggalberhenti) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggalberhenti) ?? Date.distantPast
                if item.tanggalberhenti == element.tanggalberhenti {
                    let compareResult = item.nama.compare(element.nama)
                    if sortDescriptor.ascending {
                        return compareResult == .orderedDescending || (compareResult == .orderedSame && item.nama >= element.nama)
                    } else {
                        return compareResult == .orderedAscending || (compareResult == .orderedSame && item.nama <= element.nama)
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas1Model] {
    /// Sebuah ekstensi untuk `Array` di mana elemen-elemennya adalah subclass dari `KelasModels`.
    /// Ekstensi ini menyediakan fungsionalitas untuk menemukan indeks penyisipan yang benar
    /// untuk sebuah elemen baru agar mempertahankan urutan array yang sudah diurutkan.
    ///
    /// `namasiswa`, `mapel`, `nilai`, `semester`, `namaguru`, dan `tanggal`
    /// semuanya adalah bertipe `String` dan  dapat dibandingkan secara langsung.
    ///
    /// Menentukan indeks di mana sebuah elemen dari suatu subclass `KelasModels` baru harus disisipkan
    /// ke dalam array yang sudah diurutkan untuk mempertahankan urutan berdasarkan
    /// `NSSortDescriptor` yang diberikan.
    ///
    /// Metode ini menangani berbagai kunci pengurutan (`sortDescriptor.key`) dan
    /// menyediakan logika pengurutan sekunder (biasanya berdasarkan `namasiswa`, `mapel`,
    /// dan `semester`) jika nilai pada kunci utama sama.
    ///
    /// - Parameters:
    ///   - element: Elemen `KelasModels` yang ingin Anda temukan indeks penyisipannya.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan
    ///                     (kunci dan urutan naik/turun).
    /// - Returns: Indeks (`Index`) di mana elemen harus disisipkan. Jika elemen harus
    ///            disisipkan di akhir array, `endIndex` akan dikembalikan.

    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas2Model] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas3Model] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas4Model] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas5Model] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [Kelas6Model] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

extension [KelasModels] {
    /// Lihat: ``Swift/Array/insertionIndex(for:using:)-1aqar``
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        return firstIndex { item in
            switch sortDescriptor.key {
            case "namasiswa":
                if item.namasiswa == element.namasiswa {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.mapel.compare(element.mapel)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.namasiswa >= element.namasiswa : item.namasiswa <= element.namasiswa
                }
            case "mapel":
                if item.mapel == element.mapel {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.semester.compare(element.semester)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.mapel >= element.mapel : item.mapel <= element.mapel
                }
            case "nilai":
                if item.nilai == element.nilai {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.nilai >= element.nilai : item.nilai <= element.nilai
                }
            case "semester":
                if item.semester == element.semester {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    } else {
                        // Jika namasiswa tidak sama, bandingkan berdasarkan namasiswa
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    // Jika semester tidak sama, bandingkan berdasarkan semester
                    return sortDescriptor.ascending ? item.semester >= element.semester : item.semester <= element.semester
                }
            case "namaguru":
                return sortDescriptor.ascending ? item.namaguru >= element.namaguru : item.namaguru <= element.namaguru
            case "tgl":
                let date1 = dateFormatter.date(from: item.tanggal) ?? Date.distantPast
                let date2 = dateFormatter.date(from: element.tanggal) ?? Date.distantPast
                if item.tanggal == element.tanggal {
                    // Jika semester sama, bandingkan nama siswa terlebih dahulu
                    let compareResultNamaSiswa = item.namasiswa.compare(element.namasiswa)
                    if compareResultNamaSiswa == .orderedSame {
                        // Jika namasiswa sama, bandingkan berdasarkan mapel
                        let compareResultMapel = item.mapel.compare(element.mapel)
                        if compareResultMapel == .orderedSame {
                            // Jika mapel sama, bandingkan berdasarkan semester
                            return sortDescriptor.ascending ? item.semester > element.semester : item.semester < element.semester
                        } else {
                            // Jika mapel berbeda, urutkan berdasarkan mapel
                            return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                        }
                    } else {
                        let compareResultMapel = item.namasiswa.compare(element.namasiswa)
                        return sortDescriptor.ascending ? compareResultMapel == .orderedDescending : compareResultMapel == .orderedAscending
                    }
                } else {
                    return sortDescriptor.ascending ? date1 >= date2 : date1 <= date2
                }
            default:
                return true
            }
        } ?? endIndex
    }
}

/// `TableType` merepresentasikan berbagai jenis tabel kelas, dari Kelas 1 hingga Kelas 6.
/// `rawValue` dari enum ini disesuaikan dengan indeks basis-0 untuk penggunaan internal
/// (misalnya, `kelas1` memiliki `rawValue` 0, `kelas2` memiliki `rawValue` 1, dan seterusnya).
enum TableType: Int {
    /// Merepresentasikan Kelas 1. Raw value: 0.
    case kelas1 = 0
    /// Merepresentasikan Kelas 2. Raw value: 1.
    case kelas2
    /// Merepresentasikan Kelas 3. Raw value: 2.
    case kelas3
    /// Merepresentasikan Kelas 4. Raw value: 3.
    case kelas4
    /// Merepresentasikan Kelas 5. Raw value: 4.
    case kelas5
    /// Merepresentasikan Kelas 6. Raw value: 5.
    case kelas6

    // MARK: - Properti Terkomputasi

    /// Mengembalikan representasi string dari `TableType` yang cocok untuk tampilan pengguna.
    /// Contoh: `.kelas1` akan mengembalikan "Kelas 1".
    var stringValue: String {
        switch self {
        case .kelas1:
            "Kelas 1"
        case .kelas2:
            "Kelas 2"
        case .kelas3:
            "Kelas 3"
        case .kelas4:
            "Kelas 4"
        case .kelas5:
            "Kelas 5"
        case .kelas6:
            "Kelas 6"
        }
    }

    // MARK: - Metode Statis

    /// Metode statis untuk mengonversi `String` yang berisi nama kelas (atau rentang kelas)
    /// menjadi satu atau lebih instansi `TableType` yang sesuai.
    ///
    /// Metode ini dirancang untuk memparsing input seperti "Kelas 1", "Kelas 2-4",
    /// "Kelas 1, Kelas 3", atau "1-3, 5".
    /// Setiap `TableType` yang berhasil diurai akan diteruskan ke *closure* `completion`.
    ///
    /// - Parameters:
    ///   - value: `String` input yang berisi nama kelas atau rentang kelas.
    ///            Contoh: "Kelas 1", "Kelas 2-4", "1,3,5".
    ///   - completion: Sebuah *closure* yang akan dipanggil untuk setiap `TableType`
    ///                 yang berhasil diurai dari string input.
    static func fromString(_ value: String, completion: (TableType) -> Void) {
        // Hapus prefiks "Kelas " dan spasi, lalu pisahkan string berdasarkan koma
        // untuk mendapatkan bagian-bagian individual (misalnya, "1", "2-4").
        let parts = value
            .replacingOccurrences(of: "Kelas ", with: "")
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: ",")

        // Iterasi melalui setiap bagian yang terurai.
        for part in parts {
            // Periksa apakah bagian tersebut merupakan sebuah rentang (mengandung "-").
            if part.contains("-") {
                // Pisahkan rentang (contoh: "2-4") menjadi angka awal dan akhir.
                let rangeParts = part.split(separator: "-").compactMap { Int($0) }

                // Jika berhasil mendapatkan angka awal dan akhir dari rentang.
                if let start = rangeParts.first, let end = rangeParts.last {
                    // Iterasi dari angka awal hingga akhir rentang.
                    for i in start ... end {
                        // Konversi angka (basis-1) menjadi `rawValue` (basis-0) untuk `TableType`.
                        // Contoh: "Kelas 1" (i=1) akan menjadi `rawValue` 0.
                        if let tableType = TableType(rawValue: i - 1) {
                            completion(tableType) // Panggil completion handler dengan `TableType` yang ditemukan.
                        }
                    }
                }
            } else if let number = Int(part) {
                // Jika bagian tersebut adalah angka tunggal (bukan rentang).
                // Konversi angka (basis-1) menjadi `rawValue` (basis-0) untuk `TableType`.
                if let tableType = TableType(rawValue: number - 1) {
                    completion(tableType) // Panggil completion handler dengan `TableType` yang ditemukan.
                }
            }
        }
    }
}

extension KelasModels {
    /// Membuat sebuah instansi baru dari `KelasModels` dan menyalin semua properti
    /// dari instansi `KelasModels` yang lain (`other`).
    ///
    /// Metode ini berguna untuk membuat salinan data dari sebuah objek `KelasModels`
    /// tanpa memengaruhi objek aslinya, atau untuk mengonversi data dari format lain
    /// yang memiliki properti serupa.
    ///
    /// - Parameter other: Instansi `KelasModels` yang akan menjadi sumber data untuk
    ///                    pembuatan instansi baru.
    /// - Returns: Sebuah instansi baru dari `KelasModels` dengan properti yang telah
    ///            disalin dari `other`.
    static func create(from other: KelasModels) -> Self {
        /// Membuat instansi baru dari tipe saat ini (`Self`).
        /// Mengasumsikan ada inisialisasi default atau `required init()` yang tersedia.
        let newInstance = Self()

        /// Menyalin setiap properti dari objek 'other' ke 'newInstance'.
        newInstance.kelasID = other.kelasID
        newInstance.siswaID = other.siswaID
        newInstance.namasiswa = other.namasiswa
        newInstance.mapel = other.mapel
        newInstance.nilai = other.nilai
        newInstance.namaguru = other.namaguru
        newInstance.semester = other.semester
        newInstance.tanggal = other.tanggal
        newInstance.updateMenu = other.updateMenu
        return newInstance
    }
}

/// `KelasModelsColumnIdentifier` mendefinisikan pengidentifikasi kolom string
/// yang digunakan untuk berbagai properti dalam model data kelas.
/// Ini memungkinkan identifikasi kolom yang konsisten di seluruh aplikasi.
enum KelasModelsColumnIdentifier: String, CaseIterable {
    /// Merepresentasikan kolom untuk nama siswa.
    case nama = "namasiswa"
    /// Merepresentasikan kolom untuk mata pelajaran.
    case mapel
    /// Merepresentasikan kolom untuk nilai.
    case nilai
    /// Merepresentasikan kolom untuk semester.
    case semester
    /// Merepresentasikan kolom untuk nama guru.
    case namaguru
    /// Merepresentasikan kolom untuk tanggal.
    case tgl
}

/// `ModelSiswaKey` mendefinisikan kunci string untuk berbagai properti dalam model data siswa.
/// Ini berguna untuk mengidentifikasi properti model saat berinteraksi dengan UI atau penyimpanan data.
enum ModelSiswaKey: String, CaseIterable {
    /// Merepresentasikan kunci untuk ID unik siswa.
    case id = "ID"
    /// Merepresentasikan kunci untuk nama siswa.
    case nama = "Nama"
    /// Merepresentasikan kunci untuk alamat siswa.
    case alamat = "Alamat"
    /// Merepresentasikan kunci untuk tempat dan tanggal lahir siswa.
    case ttl = "T.T.L"
    /// Merepresentasikan kunci untuk tahun pendaftaran siswa.
    case tahundaftar = "Tahun Daftar"
    /// Merepresentasikan kunci untuk nama wali siswa.
    case namawali = "Nama Wali"
    /// Merepresentasikan kunci untuk Nomor Induk Siswa (NIS).
    case nis = "NIS"
    /// Merepresentasikan kunci untuk Nomor Induk Siswa Nasional (NISN).
    case nisn = "NISN"
    /// Merepresentasikan kunci untuk nama ayah kandung.
    case ayah = "Ayah"
    /// Merepresentasikan kunci untuk nama ibu kandung.
    case ibu = "Ibu"
    /// Merepresentasikan kunci untuk jenis kelamin siswa.
    case jeniskelamin = "Jenis Kelamin"
    /// Merepresentasikan kunci untuk status siswa (misal: Aktif, Berhenti, Lulus).
    case status = "Status"
    /// Merepresentasikan kunci untuk kelas siswa saat ini.
    case kelasSekarang = "Kelas Sekarang"
    /// Merepresentasikan kunci untuk tanggal lulus siswa.
    case tanggalberhenti = "Tgl. Lulus"
    /// Merepresentasikan kunci untuk nomor telepon siswa atau wali.
    case tlv = "Nomor Telepon"
}

/// Sebuah struktur yang merepresentasikan ringkasan data untuk sebuah mata pelajaran.
///
/// Digunakan untuk mengkompilasi dan menyimpan metrik kunci seperti total nilai, rata-rata nilai,
/// jumlah siswa yang terkait, dan nama guru pengampu untuk mata pelajaran tertentu.
struct MapelSummary {
    /// Nama mata pelajaran.
    let name: String

    /// Total akumulasi nilai dari semua siswa untuk mata pelajaran ini.
    let totalScore: Double

    /// Rata-rata nilai semua siswa dalam mata pelajaran ini.
    let averageScore: Double

    /// Jumlah total siswa yang terdaftar dalam mata pelajaran ini.
    let totalStudents: Int

    /// Nama guru yang mengampu mata pelajaran ini.
    let namaGuru: String
}
