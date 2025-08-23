//
//  ModelKelas.swift
//  Data SDI
//
//  Created by MacBook on 14/07/25.
//

import AppKit
import SQLite

/// Sebuah model yang merepresentasikan catatan kelas, termasuk informasi siswa, mata pelajaran, dan nilai.
/// Mengimplementasikan protokol `Comparable` untuk logika perbandingan khusus, dan secara implisit juga `Equatable`.
/// Mengimplementasikan protokol `NSCopying` untuk memungkinkan pembuatan salinan objek.
class KelasModels: Comparable, NSCopying {
    // MARK: - Properti

    /// Pengidentifikasi unik untuk catatan kelas.
    var kelasID: Int64 = 0

    /// Nama mata pelajaran.
    var mapel: String = ""

    /// Nilai atau skor untuk mata pelajaran. Nilai default adalah 0 jika tidak diberikan.
    var nilai: Int64 = 0

    /// Pengidentifikasi unik untuk siswa.
    var siswaID: Int64 = 0

    /// Nama siswa.
    var namasiswa: String = ""

    /// ID Guru.
    var guruID: Int64 = 0

    /// Nama guru.
    var namaguru: String = ""

    /// Semester akademik (contoh: "Ganjil", "Genap").
    var semester: String = ""

    /// Tanggal yang terkait dengan catatan, biasanya dalam format string (contoh: "YYYY-MM-DD").
    var tanggal: String = ""

    /// Tahun Ajaran pada nilai.
    var tahunAjaran: String = ""

    /// Status aktif siswa di kelas tertentu, jika bernilai `false` maka siswa tidak sedang aktif di kelas
    /// (naik kelas atau sudah ditandai sebagai siswa yang lulus)
    var aktif: Bool = true

    var status: StatusSiswa?

    // MARK: - Properti Statis

    /// Sebuah `NSSortDescriptor` statis untuk menyimpan preferensi pengurutan saat ini untuk instansi `KelasModels`.
    /// Ini memungkinkan mekanisme pengurutan eksternal untuk mereferensikan deskriptor pengurutan bersama.
    static var currentSortDescriptor: NSSortDescriptor?

    /// Sebuah `NSSortDescriptor` statis khusus untuk mengurutkan instansi `KelasModels` berdasarkan siswa.
    static var siswaSortDescriptor: NSSortDescriptor?

    // MARK: - Inisialisasi

    /// Menginisialisasi instansi `KelasModels` baru yang kosong.
    /// Ini adalah inisialisasi yang diperlukan untuk memenuhi protokol `NSCopying`.
    required init() {}

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
    required init(kelasID: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64?, guruID: Int64, namaguru: String, semester: String, tanggal: String, aktif: Bool, statusSiswa: StatusSiswa? = nil, tahunAjaran: String) {
        self.kelasID = kelasID
        self.siswaID = siswaID
        self.mapel = StringInterner.shared.intern(mapel)
        self.nilai = nilai ?? 0 // Menggunakan nil coalescing untuk default ke 0 jika nilai adalah nil
        self.namasiswa = StringInterner.shared.intern(namasiswa)
        self.guruID = guruID
        self.namaguru = StringInterner.shared.intern(namaguru)
        self.semester = StringInterner.shared.intern(semester)
        self.tanggal = tanggal
        self.aktif = aktif
        self.tahunAjaran = StringInterner.shared.intern(tahunAjaran)
        status = statusSiswa
    }

    /// Inisialisasi objek dari baris hasil query SQLite.
    ///
    /// Digunakan untuk membuat instance dari model berdasarkan hasil pembacaan data dari database menggunakan SQLite.swift.
    ///
    /// - Parameter row: Baris (`Row`) hasil dari query yang berisi data yang akan digunakan untuk mengisi properti objek.
    /// - Note: Nilai opsional akan diberikan nilai default jika `nil`.
    ///
    /// Contoh penggunaan:
    /// ```swift
    /// let siswa = KelasModels(row: resultRow)
    /// ```
    convenience init(row: Row) {
        self.init()
        kelasID = row[NilaiSiswaMapelColumns.id]
        siswaID = row[SiswaColumns.id]
        namasiswa = StringInterner.shared.intern(row[SiswaColumns.nama])
        mapel = StringInterner.shared.intern(row[MapelColumns.nama])
        nilai = Int64(row[NilaiSiswaMapelColumns.nilai] ?? 0)
        guruID = Int64(row[GuruColumns.id])
        namaguru = StringInterner.shared.intern(row[GuruColumns.nama])
        semester = StringInterner.shared.intern(row[KelasColumns.semester])
        tanggal = row[NilaiSiswaMapelColumns.tanggalNilai]
        aktif = row[SiswaKelasColumns.statusEnrollment] == StatusSiswa.aktif.rawValue
        status = StatusSiswa(rawValue: row[SiswaKelasColumns.statusEnrollment]) ?? nil
        tahunAjaran = StringInterner.shared.intern(row[KelasColumns.tahunAjaran])
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
    static func < (lhs: KelasModels, rhs: KelasModels) -> Bool {
        // Implementasi ini sebenarnya mendefinisikan kesamaan, bukan urutan "kurang dari".
        // Untuk pengurutan, logika perlu disesuaikan.
        if lhs.kelasID != rhs.kelasID { return lhs.kelasID < rhs.kelasID }
        if lhs.mapel != rhs.mapel { return lhs.mapel < rhs.mapel }
        if lhs.nilai != rhs.nilai { return lhs.nilai < rhs.nilai }
        if lhs.siswaID != rhs.siswaID { return lhs.siswaID < rhs.siswaID }
        if lhs.namasiswa != rhs.namasiswa { return lhs.namasiswa < rhs.namasiswa }
        if lhs.namaguru != rhs.namaguru { return lhs.namaguru < rhs.namaguru }
        if lhs.semester != rhs.semester { return lhs.semester < rhs.semester }
        return false
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instansi ``KelasModels``.
    /// Dua instansi ``KelasModels`` dianggap sama jika properti ``kelasID`` sama.
    static func == (lhs: KelasModels, rhs: KelasModels) -> Bool {
        lhs.kelasID == rhs.kelasID
    }

    // MARK: - Implementasi Protokol NSCopying

    /// Membuat salinan (copy) dari instansi `KelasModels` saat ini.
    ///
    /// - Parameter zone: Tidak digunakan dalam implementasi ini, dapat diabaikan.
    /// - Returns: Sebuah objek `Any` yang merupakan salinan dari instansi `KelasModels` ini.
    ///            Perlu dilakukan *downcast* ke `KelasModels` saat digunakan.
    func copy(with _: NSZone? = nil) -> Any {
        KelasModels(
            kelasID: kelasID,
            siswaID: siswaID,
            namasiswa: namasiswa,
            mapel: mapel,
            nilai: nilai,
            guruID: guruID,
            namaguru: namaguru,
            semester: semester,
            tanggal: tanggal,
            aktif: aktif,
            statusSiswa: status ?? nil,
            tahunAjaran: tahunAjaran
        )
    }
}

/// Sebuah model yang dirancang untuk memuat data yang akan dicetak atau ditampilkan
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

/// `KelasAktif` merepresentasikan tingkatan kelas yang berbeda dalam sebuah sekolah.
/// Ini menggunakan nilai `String` mentah (`rawValue`) yang akan ditampilkan sebagai nama kelas.
enum KelasAktif: String, Comparable, CaseIterable {
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
    /// Lulus.
    case lulus = "Lulus"
    /// Tidak berada di kelas manapun: .default
    case belumDitentukan = ""

    /// Mengembalikan urutan angka (`Int`) yang digunakan untuk sorting `KelasAktif`.
    ///
    /// Setiap case memiliki nilai `Int` tetap untuk menentukan prioritas urutan:
    /// - kelas1 → 1
    /// - kelas2 → 2
    /// - kelas3 → 3
    /// - kelas4 → 4
    /// - kelas5 → 5
    /// - kelas6 → 6
    /// - lulus → 99
    /// - belumDitentukan → 100
    ///
    /// Nilai ini sering digunakan saat menampilkan data `KelasAktif`
    /// secara berurutan di UI.
    ///
    /// Contoh penggunaan:
    /// ```swift
    /// let kelas: KelasAktif = .kelas3
    /// print(kelas.sortOrder) // Output: 3
    /// ```
    ///
    /// - Returns: Angka urutan (`Int`) untuk case terkait.
    var integer: Int {
        switch self {
        case .kelas1: 1
        case .kelas2: 2
        case .kelas3: 3
        case .kelas4: 4
        case .kelas5: 5
        case .kelas6: 6
        case .lulus: 99
        case .belumDitentukan: 100
        }
    }

    static func < (lhs: KelasAktif, rhs: KelasAktif) -> Bool {
        lhs.integer < rhs.integer
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

extension [KelasModels] {
    /// Sebuah ekstensi untuk `Array`  dari `KelasModels`.
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
        firstIndex { item in
            item.compare(to: element, using: sortDescriptor) == .orderedDescending
        } ?? endIndex
    }
}

extension KelasModels {
    /// Membandingkan objek `KelasModels` ini dengan objek lain menggunakan kunci dan urutan dari `NSSortDescriptor`.
    ///
    /// - Parameter other: Objek `KelasModels` lain yang akan dibandingkan.
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang menentukan kunci pengurutan dan arah ascending/descending.
    /// - Returns: Nilai `ComparisonResult`:
    ///   - `.orderedAscending` jika objek ini harus berada sebelum objek lain.
    ///   - `.orderedDescending` jika objek ini harus berada setelah objek lain.
    ///   - `.orderedSame` jika keduanya setara dalam urutan.
    func compare(to other: KelasModels, using sortDescriptor: NSSortDescriptor) -> ComparisonResult {
        let asc = sortDescriptor.ascending
        let key = sortDescriptor.key ?? ""

        func parsedDate(_ s: String) -> Date {
            ReusableFunc.dateFormatter?.date(from: s) ?? .distantPast
        }

        switch key {
        case "namasiswa":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(namasiswa, other.namasiswa, asc: asc),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )

        case "mapel":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(mapel, other.mapel, asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )

        case "nilai":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(nilai, other.nilai, asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(semester, other.semester)
            )

        case "semester":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(semester, other.semester, asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai)
            )

        case "namaguru":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(namaguru, other.namaguru, asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )
        case "status":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(status?.description ?? "", other.status?.description ?? "", asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )

        case "thnAjrn":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(tahunAjaran, other.tahunAjaran, asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )

        case "tgl":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(parsedDate(tanggal), parsedDate(other.tanggal), asc: asc),
                ReusableFunc.cmp(namasiswa, other.namasiswa),
                ReusableFunc.cmp(mapel, other.mapel),
                ReusableFunc.cmp(nilai, other.nilai),
                ReusableFunc.cmp(semester, other.semester)
            )

        default:
            return .orderedSame
        }
    }
}

/// `TableType` merepresentasikan berbagai jenis tabel kelas, dari Kelas 1 hingga Kelas 6.
/// `rawValue` dari enum ini disesuaikan dengan indeks basis-0 untuk penggunaan internal
/// (misalnya, `kelas1` memiliki `rawValue` 0, `kelas2` memiliki `rawValue` 1, dan seterusnya).
enum TableType: Int, CaseIterable {
    /// Merepresentasikan Kelas 1. Raw value: 0. Kelas 2. Raw value: 1. dst.
    case kelas1 = 0, kelas2, kelas3, kelas4, kelas5, kelas6

    // MARK: - Properti Terkomputasi

    /// Properti helper untuk mendapatkan tingkat kelas (string),
    /// kelas1 (0) -> "1", kelas2 (1) -> "2", dst.
    var tingkatKelasString: String {
        "\(rawValue + 1)"
    }

    /// Mengembalikan representasi string dari `TableType` yang cocok untuk tampilan pengguna.
    /// Contoh: `.kelas1` akan mengembalikan "Kelas 1".
    var stringValue: String {
        "Kelas \(rawValue + 1)"
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

/// `KelasColumn` mendefinisikan pengidentifikasi kolom string
/// yang digunakan untuk berbagai properti dalam model data kelas.
/// Ini memungkinkan identifikasi kolom yang konsisten di seluruh aplikasi.
enum KelasColumn: String, CaseIterable {
    /// Merepresentasikan kolom untuk nama siswa.
    case nama = "namasiswa"
    /// Merepresentasikan kolom untuk mata pelajaran.
    case mapel
    /// Merepresentasikan kolom untuk nilai.
    case nilai
    /// Merepresentasikan kolom untuk semester.
    case semester
    /// Merepresentasikan kolom untuk nama guru.
    case guru = "namaguru"
    /// Merepresentasikan kolom untuk tanggal.
    case tgl
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

// MARK: - Tabel Kelas

/// Struktur `KelasColumns` digunakan untuk mendefinisikan representasi kolom-kolom pada tabel `kelas` di database.
/// Setiap properti statis merepresentasikan nama kolom dan tipe data yang sesuai pada tabel `kelas`.
/// - `tabel`: Representasi objek tabel `kelas`.
/// - `id`: Kolom `id_kelas`, bertipe `Int64`, sebagai primary key.
/// - `nama`: Kolom `nama_kelas`, bertipe `String`, contoh: "1A".
/// - `tingkat`: Kolom `tingkat_kelas`, bertipe `String`, contoh: "1".
/// - `tahunAjaran`: Kolom `tahun_ajaran`, bertipe `String`, contoh: "2024/2025".
/// - `semester`: Kolom `semester`, bertipe `String`, contoh: "Ganjil".
enum KelasColumns {
    /// Representasi objek tabel `kelas` di *database*.
    static let tabel: Table = .init("kelas")
    /// Kolom `id_kelas` pada tabel `kelas`.
    static let id: Expression<Int64> = .init("idKelas")
    /// Kolom `nama_kelas` pada tabel `kelas`, contoh: "1A".
    static let nama: Expression<String> = .init("nama_kelas")
    /// Kolom `tingkat_kelas` pada tabel `kelas`, contoh: "1".
    static let tingkat: Expression<String> = .init("tingkat_kelas")
    /// Kolom '`ahun_ajaran` pada tabel `kelas`, contoh: "2024/2025".
    static let tahunAjaran: Expression<String> = .init("tahun_ajaran")
    /// Kolom 'semester' pada tabel `kelas`, contoh: "Ganjil".
    static let semester: Expression<String> = .init("semester")
}

// MARK: - Tabel Siswa_Kelas

/// Struktur `SiswaKelasColumns` berfungsi sebagai representasi kolom-kolom pada tabel `siswa_kelas` di database.
///
/// - Properti:
///   - `tabel`: Objek tabel `siswa_kelas`.
///   - `id`: Kolom `id_siswa_kelas`, sebagai primary key.
///   - `idSiswa`: Kolom `id_siswa`, sebagai foreign key ke tabel `siswa`.
///   - `idKelas`: Kolom `id_kelas`, sebagai foreign key ke tabel `kelas`.
///   - `statusEnrollment`: Kolom `status_enrollment`, status keaktifan siswa di kelas (misal: "Aktif").
///   - `tanggalMasuk`: Kolom `tanggal_masuk`, tanggal siswa masuk kelas (nullable).
///   - `tanggalKeluar`: Kolom `tanggal_keluar`, tanggal siswa keluar kelas (nullable).
enum SiswaKelasColumns {
    /// Representasi objek tabel `siswa_kelas` di *database*.
    static let tabel: Table = .init("siswa_kelas")
    /// Kolom 'id_siswa_kelas' pada tabel `siswa_kelas`.
    static let id: Expression<Int64> = .init("id_siswa_kelas")
    /// Kolom 'id_siswa' pada tabel `siswa_kelas`, merujuk ke `siswa.id`.
    static let idSiswa: Expression<Int64> = .init("id_siswa")
    /// Kolom 'id_kelas' pada tabel `siswa_kelas`, merujuk ke `kelas.id`.
    static let idKelas: Expression<Int64> = .init("id_kelas")
    /// Kolom 'status_enrollment' pada tabel `siswa_kelas`, contoh: "Aktif".
    static let statusEnrollment: Expression<Int> = .init("status_enrollment")
    /// Kolom 'tanggal_masuk' pada tabel `siswa_kelas`, bisa bernilai null.
    static let tanggalMasuk: Expression<String?> = .init("tanggal_masuk")
    /// Kolom 'tanggal_keluar' pada tabel `siswa_kelas`, bisa bernilai null.
    static let tanggalKeluar: Expression<String?> = .init("tanggal_keluar")
}

// MARK: - Tabel Nilai_Siswa_Mapel

/// Struktur `NilaiSiswaMapelColumns` berfungsi sebagai representasi kolom-kolom pada tabel `nilai_siswa_mapel` di database.
///
/// Kolom-kolom yang tersedia:
/// - `tabel`: Objek tabel `nilai_siswa_mapel`.
/// - `id`: Kolom 'id_nilai', sebagai primary key.
/// - `idSiswaKelas`: Kolom 'id_siswa_kelas', merujuk ke `siswa_kelas.id`.
/// - `idMapel`: Kolom 'id_mapel', merujuk ke `mapel.id`.
/// - `nilai`: Kolom 'nilai', menyimpan nilai numerik siswa.
/// - `idPenugasanGuruMapelKelas`: Kolom 'id_penugasan_guru_mapel_kelas', merujuk ke `guru.id`.
/// - `tanggalNilai`: Kolom 'tanggal_nilai', menyimpan tanggal penilaian.
///
/// Struktur ini memudahkan akses dan manipulasi data pada tabel `nilai_siswa_mapel`.
enum NilaiSiswaMapelColumns {
    /// Representasi objek tabel `nilai_siswa_mapel` di *database*.
    static let tabel: Table = .init("nilai_siswa_mapel")
    /// Kolom 'id_nilai' pada tabel `nilai_siswa_mapel`.
    static let id: Expression<Int64> = .init("id_nilai")
    /// Kolom 'id_siswa_kelas' pada tabel `nilai_siswa_mapel`, merujuk ke `siswa_kelas.id`.
    static let idSiswaKelas: Expression<Int64> = .init("id_siswa_kelas")
    /// Kolom 'id_mapel' pada tabel `nilai_siswa_mapel`, merujuk ke `mapel.id`.
    static let idMapel: Expression<Int64> = .init("id_mapel")
    /// Kolom 'nilai' pada tabel `nilai_siswa_mapel`, menyimpan nilai numerik.
    static let nilai: Expression<Int?> = .init("nilai")
    /// Kolom 'id_guru_pemberi_nilai' pada tabel `nilai_siswa_mapel`, merujuk ke `guru.id`.
    static let idPenugasanGuruMapelKelas: Expression<Int64> = .init("id_penugasan_guru_mapel_kelas")
    /// Kolom 'tanggal_nilai' pada tabel `nilai_siswa_mapel`, menyimpan tanggal penilaian.
    static let tanggalNilai: Expression<String> = .init("tanggal_nilai")
}

/// Class untuk menyimpan data sebelum diperbarui di ``KelasVC`` dan ``DetailSiswaController``.
/// Data ini diperlukan untuk mengembalikan nilai lama saat undo/redo.
class OriginalData: Equatable { // `NSObject` diperlukan jika digunakan dengan API Objective-C atau KVO.

    // MARK: - Properti

    /// ID kelas atau catatan terkait dengan perubahan.
    var kelasId: Int64 = 0

    /// Tipe tabel di mana perubahan terjadi (misalnya, siswa, nilai, dll.).
    /// `TableType` diasumsikan sebagai enum atau struct yang sudah didefinisikan di tempat lain.
    var tableType: TableType!

    /// Pengidentifikasi kolom tempat perubahan terjadi.
    var columnIdentifier: KelasColumn = .nama

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
    required init(kelasId: Int64, tableType: TableType, columnIdentifier: KelasColumn, oldValue: String, newValue: String, table: Table, tableView: NSTableView) {
        self.kelasId = kelasId
        self.tableType = tableType
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
            lhs.columnIdentifier == rhs.columnIdentifier &&
            lhs.oldValue == rhs.oldValue &&
            lhs.newValue == rhs.newValue &&
            // Membandingkan referensi objek `tableView` karena ini mungkin merujuk pada instansi UI yang sama.
            lhs.tableView === rhs.tableView
    }
}

/// Struktur yang merepresentasikan ringkasan data seorang siswa.
///
/// Struktur ini menyimpan nama siswa, nilai rata-rata, dan total nilai yang diperoleh.
struct StudentSummary {
    /// Nama siswa
    var name: String
    /// Rata-rata nilai
    var averageScore: Double
    /// Jumlah nilai
    var totalScore: Int
}
