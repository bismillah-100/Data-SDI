//
//  ModelSiswa.swift
//  DataSDI
//
//  Created by Ays on 02/06/25.
//

import SQLite

/// Class `ModelSiswa` merepresentasikan model data untuk seorang siswa dalam aplikasi.
/// Class ini mengelola berbagai properti siswa, seperti informasi pribadi, detail pendaftaran,
/// dan data terkait lainnya. `ModelSiswa` juga mematuhi protokol `Comparable`,
/// yang memungkinkan objek `ModelSiswa` untuk dibandingkan.
/// Sortir data menggunakan protokol ``SortableKey``.
final class ModelSiswa: Comparable, SortableKey {
    /// Inisialisasi objek `ModelSiswa` dari sebuah array yang berisi data siswa.
    /// Array ini harus memiliki setidaknya 15 elemen, sesuai dengan jumlah properti
    /// yang didefinisikan dalam class ini. Jika jumlah elemen kurang dari 15,
    /// inisialisasi akan gagal dan mengembalikan `nil`.
    /// - Parameter row: Array yang berisi data siswa, diharapkan memiliki setidaknya 15 elemen.
    /// - Returns: Objek `ModelSiswa` yang diinisialisasi dengan data dari array, atau `nil` jika jumlah elemen kurang dari 15.
    /// - Note: Properti yang diinisialisasi meliputi `id`, `nama`, `alamat`,
    /// `ttl`, `tahundaftar`, `namawali`, `nis`, `status`, `tanggalberhenti`,
    /// `jeniskelamin`, `nisn`, `tingkatKelasAktif`, `ayah`, `ibu`, dan `tlv`.
    /// - Note: Properti `tingkatKelasAktif` diinisialisasi berdasarkan nilai string
    /// yang diberikan dalam array. Jika string tersebut adalah "Lulus", maka
    /// `tingkatKelasAktif` akan diatur ke `.lulus`. Jika tidak, maka akan diinisialisasi
    /// sebagai `KelasAktif` dengan nilai yang sesuai.
    /// - Note: Properti `status` diinisialisasi dari nilai `Int64` yang ada di array.
    convenience init?(from row: [Any?]) {
        guard row.count >= 15 else { return nil }

        self.init()
        id = row[0] as? Int64 ?? 0
        nama = StringInterner.shared.intern(row[1] as? String ?? "")
        alamat = row[2] as? String ?? ""
        ttl = row[3] as? String ?? ""
        tahundaftar = row[4] as? String ?? ""
        namawali = row[5] as? String ?? ""
        nis = row[6] as? String ?? ""

        if let statusInt = row[7] as? Int64 {
            status = StatusSiswa(rawValue: Int(statusInt)) ?? .aktif
        } else if let statusInt = row[7] as? Int {
            status = StatusSiswa(rawValue: statusInt) ?? .aktif
        } else {
            status = .aktif
        }

        tanggalberhenti = row[8] as? String ?? ""

        if let jkInt64 = row[9] as? Int64 {
            jeniskelamin = JenisKelamin(rawValue: Int(jkInt64)) ?? .lakiLaki
        } else if let jkInt = row[9] as? Int {
            jeniskelamin = JenisKelamin(rawValue: jkInt) ?? .lakiLaki
        } else {
            jeniskelamin = .lakiLaki
        }

        nisn = row[10] as? String ?? ""

        let tingkatString = row[11] as? String
        if let tingkatString {
            tingkatKelasAktif = KelasAktif(rawValue: "Kelas " + tingkatString) ?? .belumDitentukan
        } else {
            tingkatKelasAktif = .belumDitentukan
        }
        #if DEBUG
            print("SiswaTingkatKelas", tingkatKelasAktif)
        #endif

        ayah = row[12] as? String ?? ""
        ibu = row[13] as? String ?? ""
        tlv = row[14] as? String ?? ""
    }

    /// Inisialisasi objek ``ModelSiswa`` dari sebuah ``SiswaDefaultData`` dan ID.
    /// - Parameters:
    ///   - data: SiswaDefaultData yang berisi informasi siswa.
    ///   - id: ID unik untuk siswa ini, digunakan sebagai primary key.
    convenience init(from data: SiswaDefaultData, id: Int64) {
        self.init()
        self.id = id
        nama = data.nama
        alamat = data.alamat
        ttl = data.ttl
        tahundaftar = data.tahundaftar
        namawali = data.namawali
        nis = data.nis
        nisn = data.nisn
        ayah = data.ayah
        ibu = data.ibu
        jeniskelamin = data.jeniskelamin
        status = data.status
        tanggalberhenti = data.tanggalberhenti
        tlv = data.tlv
    }

    // --- Properti Statis ---

    /// Kumpulan `PartialKeyPath` sekunder untuk `ModelSiswa`.
    ///
    /// Digunakan sebagai **fallback comparator** atau urutan pembanding tambahan
    /// ketika proses pengurutan (sorting) data siswa tidak cukup hanya
    /// mengandalkan key path utama.
    ///
    /// Urutan elemen di array ini menentukan **prioritas pembanding sekunder**.
    /// Misalnya:
    /// 1. Jika dua siswa memiliki nilai sama pada key path utama,
    /// 2. Maka pembanding akan berlanjut ke `nama`,
    /// 3. Lalu `alamat`, `ayah`, `ibu`, `nis`, `nisn`,
    /// 4. Dan terakhir `id` sebagai **tie‑breaker** final untuk memastikan
    ///    hasil urutan deterministik.
    ///
    /// - Note: `PartialKeyPath` memungkinkan akses properti tanpa
    ///   mengikat tipe nilai (`Value`) secara langsung, sehingga fleksibel
    ///   untuk berbagai tipe properti dalam `ModelSiswa`.
    static let secondaryKeyPaths: [PartialKeyPath<ModelSiswa>] = [
        \.nama,
        \.alamat,
        \.ayah,
        \.ibu,
        \.nis,
        \.nisn,
        \.id,
    ]

    /// Pemetaan nama kolom (`String`) ke `PartialKeyPath` milik `ModelSiswa`.
    ///
    /// Digunakan untuk:
    /// - Mencocokkan nama kolom tabel atau header UI dengan properti model.
    /// - Mendukung fitur seperti **dynamic sorting**, **filtering**, atau **binding UI**
    ///   berdasarkan nama kolom yang dipilih pengguna.
    ///
    /// Kunci dictionary (`String`) biasanya diambil dari `SiswaColumn.rawValue`
    /// agar konsisten dengan definisi kolom di UI, sedangkan nilainya adalah
    /// `PartialKeyPath` ke properti terkait di `ModelSiswa`.
    ///
    /// ### Contoh Penggunaan
    /// ```swift
    /// if let keyPath = ModelSiswa.keyPathMap[SiswaColumn.nama.rawValue] {
    ///     let nama = siswaInstance[keyPath: keyPath]
    ///     print(nama)
    /// }
    /// ```
    ///
    /// - Important: Pastikan string key konsisten dengan label atau enum `SiswaColumn`
    ///   yang digunakan di UI agar pemetaan berfungsi dengan benar.
    static let keyPathMap: [String: PartialKeyPath<ModelSiswa>] = [
        SiswaColumn.nama.rawValue: \.nama,
        SiswaColumn.alamat.rawValue: \.alamat,
        SiswaColumn.ayah.rawValue: \.ayah,
        SiswaColumn.ibu.rawValue: \.ibu,
        SiswaColumn.jeniskelamin.rawValue: \.jeniskelamin.description,
        SiswaColumn.status.rawValue: \.status.description,
        SiswaColumn.tlv.rawValue: \.tlv,
        SiswaColumn.nis.rawValue: \.nis,
        SiswaColumn.nisn.rawValue: \.nisn,
        SiswaColumn.namawali.rawValue: \.namawali,
        SiswaColumn.ttl.rawValue: \.ttl,
        SiswaColumn.tahundaftar.rawValue: \.tahunDaftarDate,
        SiswaColumn.tanggalberhenti.rawValue: \.tglBerhentiDate,
    ]

    // --- Properti Instan ---
    /// `id` adalah pengidentifikasi unik untuk siswa, biasanya digunakan sebagai primary key
    /// di penyimpanan data. Nilai default adalah `0`.
    var id: Int64 = 0

    /// `nama` adalah nama lengkap siswa. Nilai default adalah `""`.
    var nama: String = ""

    /// `alamat` adalah alamat tempat tinggal siswa. Nilai default adalah `""`.
    var alamat: String = ""

    /// `ttl` adalah tempat tanggal lahir siswa. Nilai default `""`.
    var ttl: String = ""

    /// `tahundaftar` adalah tahun ketika siswa pertama kali mendaftar. Nilai default adalah `""`.
    var namawali: String = ""

    /// `nis` adalah Nomor Induk Siswa (NIS) siswa. Nilai default adalah `""`.
    var nis: String = ""

    /// `nisn` adalah Nomor Induk Siswa Nasional (NISN) siswa. Nilai default adalah `""`.
    var nisn: String = ""

    /// `ayah` adalah nama ayah siswa. Nilai default adalah `""`.
    var ayah: String = ""

    /// `ibu` adalah nama ibu siswa. Nilai default adalah `""`.
    var ibu: String = ""

    /// `jenisKelamin` adalah jenis kelamin siswa. Nilai default adalah `""`
    var jeniskelamin: JenisKelamin

    /// `status` adalah status siswa (misalnya, "Aktif", "Lulus", "Berhenti"). Nilai default adalah `""`.
    var status: StatusSiswa

    /// `kelasSekarang` adalah kelas aktif siswa. Nilai default adalah `""`
    var tingkatKelasAktif: KelasAktif

    /// `tahundaftar` adalah tanggal pendaftaran siswa. Nilai default adalah `""`
    var tahundaftar: String = ""

    fileprivate var tahunDaftarDate: Date? {
        ReusableFunc.dateFormatter?.date(from: tahundaftar)
    }

    /// `tanggalberhenti` adalah tanggal ketika siswa berhenti atau lulus dari sekolah.
    /// Nilai default adalah `""`.
    var tanggalberhenti: String = ""

    fileprivate var tglBerhentiDate: Date? {
        ReusableFunc.dateFormatter?.date(from: tanggalberhenti)
    }

    /// `tlv` adalah nomor telepon siswa atau wali. Nilai default adalah `""`.
    var tlv: String = ""

    // --- Inisialisasi ---
    /// Inisialisasi default untuk objek `ModelSiswa`. Semua properti diatur ke nilai default
    /// yang kosong atau nol.
    init() {
        id = 0
        nama = ""
        alamat = ""
        ttl = ""
        tahundaftar = ""
        namawali = ""
        nis = ""
        nisn = ""
        ayah = ""
        ibu = ""
        jeniskelamin = .lakiLaki
        status = .aktif
        tingkatKelasAktif = .belumDitentukan
        tanggalberhenti = ""
        tlv = ""
    }

    // --- Metode Protokol Comparable ---
    /// Implementasi operator "kurang dari" (`<`) untuk protokol `Comparable`.
    /// Dua objek ``ModelSiswa`` dianggap "kurang dari" satu sama lain jika mereka memiliki
    /// nilai yang sama untuk ``id``, ``nama``, ``alamat``,
    /// ``tingkatKelasAktif``, ``ayah``, dan ``ibu``.
    ///
    /// **Catatan Penting:** Implementasi ini mendefinisikan kesamaan dan bukan urutan.
    /// Untuk pengurutan yang benar, Anda mungkin perlu membandingkan properti
    /// seperti `nama` atau `id` secara berurutan.
    static func < (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        // Urutan prioritas: nama → tingkat kelas → alamat → ayah → ibu → ID
        if lhs.nama != rhs.nama { return lhs.nama < rhs.nama }
        if lhs.tingkatKelasAktif != rhs.tingkatKelasAktif { return lhs.tingkatKelasAktif < rhs.tingkatKelasAktif }
        if lhs.alamat != rhs.alamat { return lhs.alamat < rhs.alamat }
        if lhs.ayah != rhs.ayah { return lhs.ayah < rhs.ayah }
        if lhs.ibu != rhs.ibu { return lhs.ibu < rhs.ibu }
        return lhs.id < rhs.id
    }

    /// Implementasi operator "sama dengan" (`==`) untuk protokol `Equatable` (yang merupakan turunan dari `Comparable`).
    /// Dua objek `ModelSiswa` dianggap sama jika semua properti berikut sama:
    /// `id`, `index`, `originalIndex`, `nama`, `alamat`, `kelasSekarang`, `ayah`, dan `ibu`.
    static func == (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        lhs.id == rhs.id && lhs.nama == rhs.nama
    }

    // --- Metode Konversi Data ---
    /// Mengubah objek `ModelSiswa` saat ini menjadi `Dictionary` (`[String: Any]`).
    /// Ini berguna untuk serialisasi data, seperti menyimpan objek ke `UserDefaults`,
    /// berkas JSON, atau basis data. Kunci kamus sesuai dengan nama properti atau
    /// representasi yang berpusat pada tampilan.
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "Nama": nama,
            "Alamat": alamat,
            "T.T.L": ttl,
            "Tahun Daftar": tahundaftar,
            "Nama Wali": namawali,
            "NIS": nis,
            "NISN": nisn,
            "Ayah": ayah,
            "Ibu": ibu,
            "Jenis Kelamin": jeniskelamin,
            "Status": status.description,
            "Kelas Sekarang": tingkatKelasAktif,
            "Tgl. Lulus": tanggalberhenti,
            "Nomor Telepon": tlv,
        ]
    }

    /// Membuat dan mengembalikan objek `ModelSiswa` baru dari `Dictionary` (`[String: Any]`)
    /// yang diberikan. Ini adalah metode deserialization yang berguna untuk merekonstruksi
    /// objek `ModelSiswa` dari data yang disimpan. Fungsi ini menangani nilai `nil`
    /// dengan menyediakan nilai default yang sesuai.
    ///
    /// - Parameter dictionary: Kamus yang berisi pasangan kunci-nilai yang merepresentasikan data siswa.
    /// - Returns: Objek `ModelSiswa` yang diinisialisasi dengan data dari kamus.
    static func fromDictionary(_ dictionary: [String: Any]) -> ModelSiswa {
        let siswa = ModelSiswa()

        siswa.id = dictionary["id"] as? Int64 ?? 0
        siswa.nama = dictionary["Nama"] as? String ?? ""
        siswa.alamat = dictionary["Alamat"] as? String ?? ""
        siswa.ttl = dictionary["T.T.L"] as? String ?? ""
        siswa.tahundaftar = dictionary["Tahun Daftar"] as? String ?? ""
        siswa.namawali = dictionary["Nama Wali"] as? String ?? ""
        siswa.nis = dictionary["NIS"] as? String ?? ""
        siswa.nisn = dictionary["NISN"] as? String ?? ""
        siswa.ayah = dictionary["Ayah"] as? String ?? ""
        siswa.ibu = dictionary["Ibu"] as? String ?? ""
        siswa.jeniskelamin = dictionary["Jenis Kelamin"] as? JenisKelamin ?? .lakiLaki
        siswa.status = dictionary["Status"] as? StatusSiswa ?? .aktif
        siswa.tingkatKelasAktif = dictionary["Kelas Sekarang"] as? KelasAktif ?? .belumDitentukan
        siswa.tanggalberhenti = dictionary["Tgl. Lulus"] as? String ?? ""
        siswa.tlv = dictionary["Nomor Telepon"] as? String ?? ""
        return siswa
    }

    /// Mengatur nilai properti pada instance ``ModelSiswa`` berdasarkan kolom yang ditentukan.
    ///
    /// Fungsi ini menerima sebuah ``SiswaColumn`` dan nilai baru dalam bentuk `String`,
    /// lalu memperbarui properti yang sesuai pada objek siswa.
    /// Beberapa kolom memerlukan konversi nilai string ke tipe enum terkait:
    /// - ``SiswaColumn/jeniskelamin`` akan dikonversi ke ``JenisKelamin``
    ///   menggunakan `JenisKelamin.from(description:)`, default ke `.lakiLaki` jika konversi gagal.
    /// - ``SiswaColumn/status`` akan dikonversi ke ``StatusSiswa``
    ///   menggunakan `StatusSiswa.from(description:)`, default ke `.aktif` jika konversi gagal.
    ///
    /// ### Parameter
    /// - `column`: Kolom siswa yang ingin diperbarui.
    /// - `newValue`: Nilai baru dalam bentuk `String` yang akan diatur ke properti terkait.
    ///
    /// ### Contoh
    /// ```swift
    /// var siswa = ModelSiswa()
    /// siswa.setValue(for: .nama, newValue: "Ahmad Fauzi")
    /// siswa.setValue(for: .jeniskelamin, newValue: "Laki-laki")
    /// ```
    /// Pada contoh di atas:
    /// - Properti `nama` akan diperbarui menjadi `"Ahmad Fauzi"`.
    /// - Properti `jeniskelamin` akan diubah menjadi `.lakilaki`
    ///   jika deskripsi `"Laki-laki"` dikenali oleh konversi.
    func setValue(for column: SiswaColumn, newValue: String) {
        switch column {
        case .nama: nama = StringInterner.shared.intern(newValue)
        case .alamat: alamat = newValue
        case .ttl: ttl = newValue
        case .tahundaftar: tahundaftar = newValue
        case .namawali: namawali = newValue
        case .nis: nis = newValue
        case .nisn: nisn = newValue
        case .ayah: ayah = newValue
        case .ibu: ibu = newValue
        case .jeniskelamin:
            jeniskelamin = JenisKelamin.from(description: newValue) ?? .lakiLaki
        case .status:
            status = StatusSiswa.from(description: newValue) ?? .aktif
        case .tanggalberhenti: tanggalberhenti = newValue
        case .tlv: tlv = newValue
        default: break
        }
    }
}

/// Struct untuk memeriksa tipe input siswa ketika mengedit atau menambahkan siswa.
struct SiswaInput {
    /// Nama lengkap siswa.
    let nama: String

    /// Alamat tempat tinggal siswa.
    let alamat: String

    /// Tempat dan tanggal lahir siswa (misalnya, "Jakarta, 17 Agustus 2000").
    let ttl: String

    /// Nomor Induk Siswa (NIS) siswa.
    let nis: String

    /// Nomor Induk Siswa Nasional (NISN) siswa.
    let nisn: String

    /// Nama ayah siswa.
    let ayah: String

    /// Nama ibu siswa.
    let ibu: String

    /// Nomor telepon siswa atau wali.
    let tlv: String

    /// Nama wali siswa.
    let namawali: String

    /// Jenis kelamin siswa (misalnya, "Laki-laki", "Perempuan").
    let jeniskelamin: JenisKelamin

    /// Status siswa (misalnya, "Aktif", "Lulus", "Pindah").
    let status: StatusSiswa

    /// Tanggal siswa pertama kali mendaftar.
    let tanggalDaftar: String

    /// Tanggal siswa berhenti atau lulus dari sekolah.
    let tanggalBerhenti: String

    /// Data biner dari gambar atau foto siswa yang dipilih. Bersifat opsional (`Data?`)
    /// karena siswa mungkin tidak selalu memiliki foto yang dipilih saat input.
    let selectedImageData: Data?
}

/// Struct yang digunakan untuk mengelola status dan opsi yang dapat diperbarui dalam sebuah antarmuka pengguna
/// yang terkait dengan formulir atau tampilan detail siswa.
/// Struct ini berisi flag boolean dan satu properti string yang membaca interaktivitas dan visibilitas elemen UI tertentu
/// untuk operasional saat mengedit data siswa.
struct UpdateOption {
    var aktifkanTglDaftar: Bool
    var tglBerhentiEnabled: Bool
    var statusEnabled: Bool
    var pilihKelasSwitch: Bool
    var kelasIsEnabled: Bool
    var pilihJnsKelamin: Bool
    var kelasPilihan: String
}

extension ModelSiswa: NSCopying {
    /// Membuat salinan (copy) dari instance `ModelSiswa` saat ini.
    ///
    /// - Parameter zone: Tidak digunakan dalam implementasi ini, dapat diabaikan.
    /// - Returns: Sebuah objek `Any` yang merupakan salinan dari instance `KelasModels` ini.
    ///            Perlu dilakukan *downcast* ke `KelasModels` saat digunakan.
    func copy(with _: NSZone? = nil) -> Any {
        let copy = ModelSiswa()
        copy.id = id
        copy.nama = nama
        copy.alamat = alamat
        copy.ttl = ttl
        copy.namawali = namawali
        copy.nis = nis
        copy.nisn = nisn
        copy.ayah = ayah
        copy.ibu = ibu
        copy.jeniskelamin = jeniskelamin
        copy.status = status
        copy.tingkatKelasAktif = tingkatKelasAktif
        copy.tahundaftar = tahundaftar
        copy.tanggalberhenti = tanggalberhenti
        copy.tlv = tlv
        return copy
    }
}

/// StatusSiswa merepresentasikan kemungkinan status data.
/// Ini menggunakan nilai `Int` mentah (`rawValue`).
/// Data yang ditampilkan adalah `description`.
enum StatusSiswa: Int, Comparable, CaseIterable {
    /// Status default.
    case unknown = 0
    /// Aktif.
    case aktif = 1
    /// Berhenti.
    case berhenti = 2
    /// Lulus.
    case lulus = 3
    /// Untuk status penugasan guru.
    case selesai = 4
    /// Untuk status naik di tabel siswa_kelas.
    case naik = 5

    /// Deskripsi teks untuk setiap nilai enum.
    ///
    /// Properti ini memberikan representasi `String` yang ramah pengguna dari nilai enum, yang dapat digunakan untuk ditampilkan di UI.
    ///
    /// - Returns: String deskriptif sesuai dengan kasus enum.
    var description: String {
        switch self {
        case .unknown:
            "" // Tidak ditampilkan atau tidak dikenali
        case .aktif:
            "Aktif"
        case .lulus:
            "Lulus"
        case .berhenti:
            "Berhenti"
        case .selesai:
            "Selesai"
        case .naik:
            "Naik"
        }
    }

    /// Mengembalikan semua nilai enum sebagai array.
    static func < (lhs: StatusSiswa, rhs: StatusSiswa) -> Bool {
        lhs.description < rhs.description
    }

    /// Konversi dari string deskripsi ke enum StatusSiswa
    static func from(description: String) -> StatusSiswa? {
        allCases.first(where: { $0.description == description })
    }
}

/// JenisKelamin adalah enum bertipe String yang merepresentasikan jenis kelamin dengan dua opsi,
/// yaitu laki-laki dan perempuan.
/// Enum ini juga mengimplementasikan protokol Comparable sehingga data dapat
/// diurutkan berdasarkan nilai rawValue-nya.
enum JenisKelamin: Int, Comparable, CaseIterable {
    /// Enum Laki-Laki
    case lakiLaki = 1
    /// Enum Perempuan
    case perempuan = 2

    /// Deskripsi teks untuk setiap nilai enum.
    ///
    /// Properti ini memberikan representasi `String` yang ramah pengguna dari nilai enum, yang dapat digunakan untuk ditampilkan di UI.
    ///
    /// - Returns: String deskriptif sesuai dengan kasus enum.
    var description: String {
        switch self {
        case .lakiLaki:
            "Laki-laki"
        case .perempuan:
            "Perempuan"
        }
    }

    /// Deskripsi teks untuk setiap nilai enum.
    static func < (lhs: JenisKelamin, rhs: JenisKelamin) -> Bool {
        lhs.description < rhs.description
    }

    /// Objek enum ``JenisKelamin`` dari string.
    /// - Parameter description: Deskripsi dari enum. harus sesuai dengan ``description``.
    /// - Returns: Objek enum yang dibuat dari `description`.
    static func from(description: String) -> JenisKelamin? {
        allCases.first(where: { $0.description == description })
    }
}

// MARK: - Tabel Siswa

/// `SiswaColumns` adalah struktur yang mendefinisikan kolom-kolom dalam tabel `siswa` di basis data.
/// Struktur ini menyediakan representasi yang jelas dan terstruktur dari kolom-kolom yang ada
/// dalam tabel `siswa`, sehingga memudahkan interaksi dengan basis data menggunakan SQLite.
enum SiswaColumns {
    /// Representasi objek tabel `siswa` di *database*.
    static let tabel: Table = .init("siswa")
    /// Kolom 'id' pada tabel `siswa`.
    static let id: Expression<Int64> = .init("id")
    /// Kolom 'Nama' pada tabel `siswa`.
    static let nama: Expression<String> = .init("Nama")
    /// Kolom 'Alamat' pada tabel `siswa`.
    static let alamat: Expression<String> = .init("Alamat")
    /// Kolom 'T.T.L.' (Tanggal, Tempat Lahir) pada tabel `siswa`.
    static let ttl: Expression<String> = .init("T.T.L.")
    /// Kolom 'Tahun Daftar' pada tabel `siswa`.
    static let tahundaftar: Expression<String> = .init("Tahun Daftar")
    /// Kolom 'Nama Wali' pada tabel `siswa`.
    static let namawali: Expression<String> = .init("Nama Wali")
    /// Kolom 'NIS' (Nomor Induk Siswa) pada tabel `siswa`.
    static let nis: Expression<String> = .init("NIS")
    /// Kolom 'Status' pada tabel `siswa`.
    static let status: Expression<Int> = .init("Status")
    /// Kolom 'Tgl. Lulus' pada tabel `siswa`, merepresentasikan tanggal berhenti/lulus.
    static let tanggalberhenti: Expression<String> = .init("Tgl. Lulus")
    /// Kolom 'Jenis Kelamin' pada tabel `siswa`.
    static let jeniskelamin: Expression<Int> = .init("Jenis Kelamin")
    /// Untuk mendapatkan nama kolom jenis kelamin dari database.
    static let jeniskelaminColumn: Expression<String> = .init("Jenis Kelamin")
    /// Kolom 'NISN' (Nomor Induk Siswa Nasional) pada tabel `siswa`.
    static let nisn: Expression<String> = .init("NISN")
    /// Kolom 'Ayah' pada tabel `siswa`.
    static let ayah: Expression<String> = .init("Ayah")
    /// Kolom 'Ibu' pada tabel `siswa`.
    static let ibu: Expression<String> = .init("Ibu")
    /// Kolom 'Nomor Telepon' pada tabel `siswa`.
    static let tlv: Expression<String> = .init("Nomor Telepon")
    /// Kolom 'foto' pada tabel `siswa`, menyimpan data gambar.
    static let foto: Expression<Data?> = .init("foto")
}

/// `SiswaColumn` mendefinisikan kunci string untuk berbagai properti dalam model data siswa.
/// Ini berguna untuk mengidentifikasi properti model saat berinteraksi dengan UI atau penyimpanan data.
enum SiswaColumn: String, CaseIterable {
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

    /// Mengembalikan referensi kolom database (`Expression<String>`) yang sesuai
    /// dengan nilai enum ``SiswaColumn``.
    ///
    /// Properti ini memetakan setiap case tertentu ke kolom yang relevan di tabel
    /// siswa pada database. Jika case tidak memiliki kolom database yang terkait
    /// (misalnya `.id`, `.status`, atau `.kelasSekarang`), maka akan mengembalikan `nil`.
    ///
    /// ### Return Value
    /// - `Expression<String>` untuk kolom yang memiliki representasi di database.
    /// - `nil` jika case tidak memiliki kolom database terkait.
    ///
    /// ### Contoh
    /// ```swift
    /// if let kolom = SiswaColumn.nama.kolomDB {
    ///     // Gunakan kolom ini untuk query database
    ///     query.order(kolom.asc)
    /// }
    /// ```
    /// Pada contoh di atas, `kolom` akan berisi referensi ke kolom `nama`
    /// di tabel siswa, yang dapat digunakan untuk operasi query.
    var kolomDB: Expression<String>? {
        switch self {
        case .nama: SiswaColumns.nama
        case .alamat: SiswaColumns.alamat
        case .ttl: SiswaColumns.ttl
        case .tahundaftar: SiswaColumns.tahundaftar
        case .namawali: SiswaColumns.namawali
        case .nis: SiswaColumns.nis
        case .nisn: SiswaColumns.nisn
        case .ayah: SiswaColumns.ayah
        case .ibu: SiswaColumns.ibu
        case .jeniskelamin: SiswaColumns.jeniskelaminColumn
        case .tanggalberhenti: SiswaColumns.tanggalberhenti
        case .tlv: SiswaColumns.tlv
        default: nil
        }
    }
}

/// `DataAsli` adalah struktur untuk menyimpan data perubahan tunggal pada sebuah sel.
/// Ini merekam ID baris, indeks baris, pengidentifikasi kolom, serta nilai lama dan baru dari sel tersebut.
/// Mengimplementasikan `Equatable` untuk perbandingan kesamaan antar instance.
struct DataAsli: Equatable {
    // MARK: - Properti

    /// ID unik dari data yang diubah (misalnya, ID catatan di database).
    let ID: Int64

    /// Pengidentifikasi unik untuk kolom (`columnIdentifier`) tempat perubahan terjadi.
    let columnIdentifier: SiswaColumn

    /// Nilai asli (`oldValue`) dari sel sebelum perubahan.
    let oldValue: String

    /// Nilai baru (`newValue`) dari sel setelah perubahan.
    let newValue: String

    // MARK: - Implementasi Protokol Equatable

    /// Mendefinisikan operator kesamaan (`==`) untuk instance `DataAsli`.
    /// Dua instance `DataAsli` dianggap sama jika semua propertinya (ID, rowIndex, columnIdentifier, oldValue, newValue) sama.
    static func == (lhs: DataAsli, rhs: DataAsli) -> Bool {
        lhs.ID == rhs.ID &&
            lhs.columnIdentifier == rhs.columnIdentifier &&
            lhs.oldValue == rhs.oldValue &&
            lhs.newValue == rhs.newValue
    }

    /// Fungsi untuk mengekstrak ``DataAsli``.
    ///
    /// **Contoh Penggunaan:**
    /// ```swift
    /// let (id, column, oldValue, newValue) = DataAsli.extract(originalModel: originalModel)
    ///
    /// guard let rowIndexToUpdate = indexSiswa(for: id) else {
    ///     updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: nil, newValue: oldValue)
    ///     UndoActionNotification.sendNotif(id, columnIdentifier: column)
    ///     return
    /// }
    ///
    /// updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndexToUpdate, newValue: oldValue)
    /// ```
    ///
    /// - Parameter originalModel: ``DataAsli`` yang akan di ekstrak.
    /// - Returns: Tuple properti ``DataAsli`` berisi
    /// `(id: Int64, column: SiswaColumn, oldValue: String, newValue: String)`.
    static func extract(originalModel: DataAsli) -> (id: Int64, column: SiswaColumn, oldValue: String, newValue: String) {
        let id = originalModel.ID
        let column = originalModel.columnIdentifier
        let oldValue = originalModel.oldValue
        let newValue = originalModel.newValue
        return (id, column, oldValue, newValue)
    }
}

/// Enum untuk menentukan tableView dalam mode group atau non-grup.
enum TableViewMode: Int {
    /// Mode basic.
    case plain //  0
    /// Mode grup
    case grouped // 1
}

/// Menggambarkan semua perubahan yang terjadi saat naik kelas
struct UndoNaikKelasContext {
    let siswaId: Int64
    /// Semua entri siswa_kelas yang tadinya aktif dan kemudian dinonaktifkan
    let deactivatedEntries: [(rowID: Int64, oldStatus: Int, oldTanggalKeluar: String?)]
    /// ID entry baru yang dibuat untuk kelas baru
    let newEntryID: Int64
    // --- Data Tambahan untuk REDO ---
    /// ID dari kelas tujuan (misal, ID untuk 'Kelas 2A'). Ini adalah informasi kunci.
    let newEntryKelasID: Int64
    /// Tanggal saat kenaikan kelas dilakukan, untuk digunakan kembali saat redo.
    let newEntryTanggal: String
    /// TahunAjaran
    let tahunAjaran: String
    /// Semester
    let semester: String
}
