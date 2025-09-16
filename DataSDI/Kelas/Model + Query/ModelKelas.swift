//
//  ModelKelas.swift
//  Data SDI
//
//  Created by MacBook on 14/07/25.
//

import AppKit
import SQLite

/// Sebuah model yang merepresentasikan catatan kelas, termasuk informasi siswa, mata pelajaran, dan nilai.
/// Mengimplementasikan protokol `Comparable` untuk logika perbandingan.
/// Mengimplementasikan protokol `NSCopying` untuk memungkinkan pembuatan salinan objek.
/// Sortir data menggunakan protokol ``SortableKey``.
final class KelasModels: Comparable, NSCopying, SortableKey {
    // MARK: - Properti

    /// Kamus yang memetakan kunci pengurutan (`String`) ke `KeyPath` dari properti yang relevan.
    ///
    /// Properti ini berfungsi sebagai tabel pencarian untuk menentukan properti mana
    /// yang akan digunakan untuk pengurutan berdasarkan `sortDescriptor.key`.
    ///
    /// Setiap kunci dalam kamus ini harus sesuai dengan string yang digunakan
    /// di `NSSortDescriptor`. Nilainya adalah `KeyPath` ke properti yang ingin
    /// Anda urutkan di ``KelasModels``.
    static let keyPathMap: [String: PartialKeyPath<KelasModels>] = [
        KelasColumn.nama.rawValue: \.namasiswa,
        KelasColumn.mapel.rawValue: \.mapel,
        KelasColumn.semester.rawValue: \.semester,
        KelasColumn.nilai.rawValue: \.nilai,
        KelasColumn.guru.rawValue: \.namaguru,
        KelasColumn.tgl.rawValue: \.tglDate,
        KelasColumn.tahun.rawValue: \.tahunAjaran,
        KelasColumn.status.rawValue: \.status,
    ]

    /// Sekumpulan `PartialKeyPath` sekunder untuk `KelasModels`.
    ///
    /// Digunakan sebagai **fallback comparator** atau urutan pembanding tambahan
    /// ketika proses pengurutan (sorting) data kelas tidak cukup hanya
    /// mengandalkan key path utama.
    ///
    /// Urutan elemen di array ini menentukan **prioritas pembanding sekunder**.
    /// Misalnya:
    /// 1. Jika dua entri kelas memiliki nilai sama pada key path utama,
    /// 2. Maka pembanding akan berlanjut ke `namasiswa`,
    /// 3. Lalu `mapel`, `nilai`, `semester`, `tahunAjaran`,
    /// 4. Dan terakhir `nilaiID` sebagai **tie‑breaker** final untuk memastikan
    ///    hasil urutan deterministik.
    ///
    /// - Note: `PartialKeyPath` memungkinkan akses properti tanpa
    ///   mengikat tipe nilai (`Value`) secara langsung, sehingga fleksibel
    ///   untuk berbagai tipe properti dalam `KelasModels`.
    static let secondaryKeyPaths: [PartialKeyPath<KelasModels>] = [
        \.namasiswa,
        \.mapel,
        \.nilai,
        \.semester,
        \.tahunAjaran,
        \.nilaiID, // Menggunakan ID sebagai tie-breaker terakhir
    ]

    /// Pengidentifikasi unik untuk catatan kelas.
    var nilaiID: Int64 = 0

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

    /// ID Penugasan Guru.
    var tugasID: Int64 = 0

    /// Nama guru.
    var namaguru: String = ""

    /// Semester akademik (contoh: "Ganjil", "Genap").
    var semester: String = ""

    /// Tanggal yang terkait dengan catatan, biasanya dalam format string (contoh: "YYYY-MM-DD").
    var tanggal: String = ""

    fileprivate var tglDate: Date? {
        ReusableFunc.dateFormatter?.date(from: tanggal)
    }

    /// Tahun Ajaran pada nilai.
    var tahunAjaran: String = ""

    /// Status aktif siswa di kelas tertentu, jika bernilai `false` maka siswa tidak sedang aktif di kelas
    /// (naik kelas atau sudah ditandai sebagai siswa yang lulus)
    var aktif: Bool = true

    /// Status siswa di dalam kelas.
    var status: StatusSiswa?

    // MARK: - Inisialisasi

    /// Menginisialisasi instance `KelasModels` baru yang kosong.
    /// Ini adalah inisialisasi yang diperlukan untuk memenuhi protokol `NSCopying`.
    required init() {}

    /// Menginisialisasi instance `KelasModels` dengan detail yang diberikan.
    ///
    /// - Parameters:
    ///   - nilaiID: ID unik untuk catatan kelas.
    ///   - siswaID: ID unik untuk siswa.
    ///   - namasiswa: Nama siswa.
    ///   - mapel: Nama mata pelajaran.
    ///   - nilai: Nilai atau skor. Jika `nil`, maka nilai default-nya adalah `0`.
    ///   - namaguru: Nama guru.
    ///   - semester: Semester akademik.
    ///   - tanggal: Tanggal catatan.
    required init(nilaiID: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64?, guruID: Int64, tugasID: Int64, namaguru: String, semester: String, tanggal: String, aktif: Bool, statusSiswa: StatusSiswa? = nil, tahunAjaran: String) {
        self.nilaiID = nilaiID
        self.siswaID = siswaID
        self.mapel = StringInterner.shared.intern(mapel)
        self.nilai = nilai ?? 0 // Menggunakan nil coalescing untuk default ke 0 jika nilai adalah nil
        self.namasiswa = StringInterner.shared.intern(namasiswa)
        self.guruID = guruID
        self.tugasID = tugasID
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
        nilaiID = row[NilaiSiswaMapelColumns.id]
        siswaID = row[SiswaColumns.id]
        namasiswa = StringInterner.shared.intern(row[SiswaColumns.nama])
        mapel = StringInterner.shared.intern(row[MapelColumns.nama])
        nilai = Int64(row[NilaiSiswaMapelColumns.nilai] ?? 0)
        guruID = Int64(row[GuruColumns.id])
        tugasID = Int64(row[TabelTugas.id])
        namaguru = StringInterner.shared.intern(row[GuruColumns.nama])
        semester = StringInterner.shared.intern(row[KelasColumns.semester])
        tanggal = row[NilaiSiswaMapelColumns.tanggalNilai]
        aktif = row[SiswaKelasColumns.statusEnrollment] == StatusSiswa.aktif.rawValue
        status = StatusSiswa(rawValue: row[SiswaKelasColumns.statusEnrollment]) ?? nil
        tahunAjaran = StringInterner.shared.intern(row[KelasColumns.tahunAjaran])
    }

    // MARK: - Implementasi Protokol Comparable

    /// Mendefinisikan operator "kurang dari" (`<`) untuk instance `KelasModels`.
    /// Implementasi ini membandingkan setiap properti untuk menentukan urutan.
    ///
    /// **Catatan Penting**: Implementasi asli dari operator `<` ini sebenarnya
    /// mendefinisikan kesamaan (`==`) bukan urutan "kurang dari". Ini berarti
    /// dua objek dianggap "kurang dari" satu sama lain jika semua properti yang
    /// dibandingkan sama. Untuk pengurutan yang benar, logika ini mungkin perlu
    /// disesuaikan agar sesuai dengan kriteria pengurutan yang spesifik (misalnya,
    /// mengurutkan berdasarkan `tanggal`, kemudian `nilaiID`, dll.).
    static func < (lhs: KelasModels, rhs: KelasModels) -> Bool {
        // Implementasi ini sebenarnya mendefinisikan kesamaan, bukan urutan "kurang dari".
        // Untuk pengurutan, logika perlu disesuaikan.
        if lhs.namasiswa != rhs.namasiswa { return lhs.namasiswa < rhs.namasiswa }
        if lhs.mapel != rhs.mapel { return lhs.mapel < rhs.mapel }
        if lhs.semester != rhs.semester { return lhs.semester < rhs.semester }
        if lhs.nilai != rhs.nilai { return lhs.nilai < rhs.nilai }
        if lhs.namaguru != rhs.namaguru { return lhs.namaguru < rhs.namaguru }
        if lhs.tahunAjaran != rhs.tahunAjaran { return lhs.tahunAjaran < rhs.tahunAjaran }
        return lhs.nilaiID < rhs.nilaiID
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instance ``KelasModels``.
    /// Dua instance ``KelasModels`` dianggap sama jika properti ``nilaiID`` sama.
    static func == (lhs: KelasModels, rhs: KelasModels) -> Bool {
        lhs.nilaiID == rhs.nilaiID
    }

    // MARK: - Implementasi Protokol NSCopying

    /// Membuat salinan (copy) dari instance `KelasModels` saat ini.
    ///
    /// - Parameter zone: Tidak digunakan dalam implementasi ini, dapat diabaikan.
    /// - Returns: Sebuah objek `Any` yang merupakan salinan dari instance `KelasModels` ini.
    ///            Perlu dilakukan *downcast* ke `KelasModels` saat digunakan.
    func copy(with _: NSZone? = nil) -> Any {
        KelasModels(
            nilaiID: nilaiID,
            siswaID: siswaID,
            namasiswa: namasiswa,
            mapel: mapel,
            nilai: nilai,
            guruID: guruID,
            tugasID: tugasID,
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

    /// Menginisialisasi instance `KelasPrint` baru yang kosong.
    /// Semua properti akan diatur ke nilai *default* (string kosong).
    init() {}

    /// Menginisialisasi instance `KelasPrint` dengan detail yang diberikan.
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
    /// menjadi satu atau lebih instance `TableType` yang sesuai.
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
    /// Merepresentasikan kolom untuk tahun ajaran.
    case tahun = "thnAjrn"
    /// Merepresentasikan kolom untuk status.
    case status
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
class OriginalData: NSObject { // `NSObject` diperlukan jika digunakan dengan API Objective-C atau KVO.

    // MARK: - Properti

    /// ID kelas atau catatan terkait dengan perubahan.
    var nilaiId: Int64 = 0

    /// Tipe tabel di mana perubahan terjadi (misalnya, siswa, nilai, dll.).
    /// `TableType` diasumsikan sebagai enum atau struct yang sudah didefinisikan di tempat lain.
    var tableType: TableType!

    /// Pengidentifikasi kolom tempat perubahan terjadi.
    var columnIdentifier: KelasColumn = .nama

    /// Nilai lama dari sel sebelum perubahan.
    var oldValue: String = ""

    /// Nilai baru dari sel setelah perubahan.
    var newValue: String = ""

    /// Referensi ke objek `NSTableView` tempat perubahan visual terjadi.
    var tableView: NSTableView!

    // MARK: - Inisialisasi

    /// Menginisialisasi instance `OriginalData` dengan detail lengkap tentang perubahan data.
    ///
    /// - Parameters:
    ///   - nilaiId: ID kelas atau catatan.
    ///   - tableType: Tipe tabel.
    ///   - rowIndex: Indeks baris.
    ///   - columnIdentifier: Pengidentifikasi kolom.
    ///   - oldValue: Nilai lama sel.
    ///   - newValue: Nilai baru sel.
    ///   - table: Objek `Table` terkait.
    ///   - tableView: Objek `NSTableView` terkait.
    required init(nilaiId: Int64, tableType: TableType, columnIdentifier: KelasColumn, oldValue: String, newValue: String, tableView: NSTableView) {
        self.nilaiId = nilaiId
        self.tableType = tableType
        self.columnIdentifier = columnIdentifier
        self.oldValue = oldValue
        self.newValue = newValue
        self.tableView = tableView
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instance `OriginalData`.
    /// Dua instance `OriginalData` dianggap sama jika semua properti pentingnya (kecuali referensi objek) sama.
    /// Perbandingan `tableView` dilakukan berdasarkan referensi objek (`===`).
    static func == (lhs: OriginalData, rhs: OriginalData) -> Bool {
        lhs.nilaiId == rhs.nilaiId &&
            lhs.tableType == rhs.tableType &&
            lhs.columnIdentifier == rhs.columnIdentifier &&
            lhs.oldValue == rhs.oldValue &&
            lhs.newValue == rhs.newValue &&
            // Membandingkan referensi objek `tableView` karena ini mungkin merujuk pada instance UI yang sama.
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

/// Struktur hasil operasi penghapusan nilai.
/// Digunakan di ``KelasViewModel/removeData(withIDs:forTableType:siswaID:arsip:)``
///
/// `DeleteNilaiResult` digunakan untuk mengembalikan kumpulan data yang
/// dihasilkan setelah proses penghapusan nilai, termasuk daftar pembaruan,
/// ID yang terpengaruh, model kelas terkait, dan relasi nilai–siswa.
///
/// Struktur ini memudahkan pemanggil untuk memproses efek samping dari
/// penghapusan nilai dalam satu paket data.
struct DeleteNilaiResult {
    /// Daftar data yang perlu diperbarui setelah penghapusan nilai.
    var updates: [UpdateData] = []

    /// Kumpulan bilangan bulat umum yang relevan dengan operasi ini.
    /// Misalnya, bisa berisi indeks atau ID sederhana.
    var intArray: [Int] = []

    /// Model kelas yang terpengaruh oleh penghapusan nilai.
    var kelasModels: [KelasModels] = []

    /// Relasi antara `nilaiID` dan `siswaID` yang dihapus.
    /// Berguna untuk melacak nilai mana milik siswa mana yang terhapus.
    var relationArray: [(nilaiID: Int64, siswaID: Int64)] = []
}
