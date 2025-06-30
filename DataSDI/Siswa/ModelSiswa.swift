//
//  ModelSiswa.swift
//  DataSDI
//
//  Created by Ays on 02/06/25.
//

import Foundation
import SQLite

/// Class `ModelSiswa` merepresentasikan model data untuk seorang siswa dalam aplikasi.
/// Class ini mengelola berbagai properti siswa, seperti informasi pribadi, detail pendaftaran,
/// dan data terkait lainnya. `ModelSiswa` juga mematuhi protokol `Comparable`,
/// yang memungkinkan objek `ModelSiswa` untuk dibandingkan.
public class ModelSiswa: Comparable, RowInitializable {
    required convenience init(row: SQLite.Row) {
        self.init()
        id = row[Expression<Int64>("id")]
        /// Kolom 'Nama' pada tabel `siswa`.
        nama = row[Expression<String>("Nama")]
        /// Kolom 'Alamat' pada tabel `siswa`.
        alamat = row[Expression<String>("Alamat")]
        /// Kolom 'T.T.L.' (Tanggal, Tempat Lahir) pada tabel `siswa`.
        ttl = row[Expression<String>("T.T.L.")]
        /// Kolom 'Tahun Daftar' pada tabel `siswa`.
        tahundaftar = row[Expression<String>("Tahun Daftar")]
        /// Kolom 'Nama Wali' pada tabel `siswa`.
        namawali = row[Expression<String>("Nama Wali")]
        /// Kolom 'NIS' (Nomor Induk Siswa) pada tabel `siswa`.
        nis = row[Expression<String>("NIS")]
        /// Kolom 'Status' pada tabel `siswa`.
        status = row[Expression<String>("Status")]
        /// Kolom 'Tgl. Lulus' pada tabel `siswa`, merepresentasikan tanggal berhenti/lulus.
        tanggalberhenti = row[Expression<String>("Tgl. Lulus")]
        /// Kolom 'Jenis Kelamin' pada tabel `siswa`.
        jeniskelamin = row[Expression<String>("Jenis Kelamin")]
        /// Kolom 'NISN' (Nomor Induk Siswa Nasional) pada tabel `siswa`.
        nisn = row[Expression<String>("NISN")]
        /// Kolom 'Kelas Aktif' pada tabel `siswa`.
        kelasSekarang = row[Expression<String>("Kelas Aktif")]
        /// Kolom 'Ayah' pada tabel `siswa`.
        ayah = row[Expression<String>("Ayah")]
        /// Kolom 'Ibu' pada tabel `siswa`.
        ibu = row[Expression<String>("Ibu")]
        /// Kolom 'Nomor Telepon' pada tabel `siswa`.
        tlv = row[Expression<String>("Nomor Telepon")]
    }
    
    // --- Properti Statis ---
    /// `currentSortDescriptor` menyimpan sort descriptor yang saat ini digunakan untuk
    /// mengurutkan daftar siswa. Ini memungkinkan aplikasi untuk mempertahankan urutan
    /// pengurutan yang konsisten di seluruh sesi atau tampilan.
    static var currentSortDescriptor: NSSortDescriptor?

    // --- Properti Instan ---
    /// `id` adalah pengidentifikasi unik untuk siswa, biasanya digunakan sebagai primary key
    /// di penyimpanan data. Nilai default adalah `0`.
    public var id: Int64 = 0

    /// `nama` adalah nama lengkap siswa. Nilai default adalah `""`.
    public var nama: String = ""

    /// `alamat` adalah alamat tempat tinggal siswa. Nilai default adalah `""`.
    public var alamat: String = ""

    /// `ttl` adalah tempat tanggal lahir siswa. Nilai default `""`.
    public var ttl: String = ""

    /// `tahundaftar` adalah tahun ketika siswa pertama kali mendaftar. Nilai default adalah `""`.
    public var namawali: String = ""

    /// `nis` adalah Nomor Induk Siswa (NIS) siswa. Nilai default adalah `""`.
    public var nis: String = ""

    /// `nisn` adalah Nomor Induk Siswa Nasional (NISN) siswa. Nilai default adalah `""`.
    public var nisn: String = ""

    /// `ayah` adalah nama ayah siswa. Nilai default adalah `""`.
    public var ayah: String = ""

    /// `ibu` adalah nama ibu siswa. Nilai default adalah `""`.
    public var ibu: String = ""

    /// `jenisKelamin` adalah jenis kelamin siswa. Nilai default adalah `""`
    public var jeniskelamin: String = ""

    /// `status` adalah status siswa (misalnya, "Aktif", "Lulus", "Berhenti"). Nilai default adalah `""`.
    public var status: String = ""

    /// `kelasSekarang` adalah kelas aktif siswa. Nilai default adalah `""`
    public var kelasSekarang: String = ""

    /// `tahundaftar` adalah tanggal pendaftaran siswa. Nilai default adalah `""`
    public var tahundaftar: String = ""

    /// `tanggalberhenti` adalah tanggal ketika siswa berhenti atau lulus dari sekolah.
    /// Nilai default adalah `""`.
    public var tanggalberhenti: String = ""

    /// `tlv` adalah nomor telepon siswa atau wali. Nilai default adalah `""`.
    public var tlv: String = ""

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
        jeniskelamin = ""
        status = ""
        kelasSekarang = ""
        tanggalberhenti = ""
        tlv = ""
    }

    // --- Metode Protokol Hashable (Implisit dari Equatable) ---
    /// Metode ini menyediakan cara untuk membuat nilai hash dari objek `ModelSiswa`
    /// berdasarkan `id`, `index`, `originalIndex`, dan `nama`. Ini penting saat
    /// menggunakan `ModelSiswa` dalam koleksi seperti `Set` atau sebagai kunci dalam `Dictionary`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(nama)
    }

    // --- Metode Protokol Comparable ---
    /// Implementasi operator "kurang dari" (`<`) untuk protokol `Comparable`.
    /// Dua objek `ModelSiswa` dianggap "kurang dari" satu sama lain jika mereka memiliki
    /// nilai yang sama untuk `id`, `nama`, `alamat`,
    /// `kelasSekarang`, `ayah`, dan `ibu`.
    ///
    /// **Catatan Penting:** Implementasi ini mendefinisikan kesamaan dan bukan urutan.
    /// Untuk pengurutan yang benar, Anda mungkin perlu membandingkan properti
    /// seperti `nama` atau `id` secara berurutan.
    public static func < (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        lhs.id == rhs.id && lhs.nama == rhs.nama && lhs.alamat == rhs.alamat && lhs.kelasSekarang == rhs.kelasSekarang && lhs.ayah == rhs.ayah && lhs.ibu == rhs.ibu
    }

    /// Implementasi operator "sama dengan" (`==`) untuk protokol `Equatable` (yang merupakan turunan dari `Comparable`).
    /// Dua objek `ModelSiswa` dianggap sama jika semua properti berikut sama:
    /// `id`, `index`, `originalIndex`, `nama`, `alamat`, `kelasSekarang`, `ayah`, dan `ibu`.
    public static func == (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        lhs.id == rhs.id && lhs.nama == rhs.nama && lhs.alamat == rhs.alamat && lhs.kelasSekarang == rhs.kelasSekarang && lhs.ayah == rhs.ayah && lhs.ibu == rhs.ibu
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
            "Status": status,
            "Kelas Sekarang": kelasSekarang,
            "Tgl. Lulus": tanggalberhenti,
            "Nomor Telepon": tlv
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
        siswa.jeniskelamin = dictionary["Jenis Kelamin"] as? String ?? ""
        siswa.status = dictionary["Status"] as? String ?? ""
        siswa.kelasSekarang = dictionary["Kelas Sekarang"] as? String ?? ""
        siswa.tanggalberhenti = dictionary["Tgl. Lulus"] as? String ?? ""
        siswa.tlv = dictionary["Nomor Telepon"] as? String ?? ""
        return siswa
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
    let jeniskelamin: String

    /// Status siswa (misalnya, "Aktif", "Lulus", "Pindah").
    let status: String

    /// Tanggal siswa pertama kali mendaftar.
    let tanggalDaftar: String

    /// Tanggal siswa berhenti atau lulus dari sekolah.
    let tanggalBerhenti: String

    /// Kelas siswa saat ini.
    let kelas: String

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
    /// Membuat salinan (copy) dari instansi `ModelSiswa` saat ini.
    ///
    /// - Parameter zone: Tidak digunakan dalam implementasi ini, dapat diabaikan.
    /// - Returns: Sebuah objek `Any` yang merupakan salinan dari instansi `KelasModels` ini.
    ///            Perlu dilakukan *downcast* ke `KelasModels` saat digunakan.
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = ModelSiswa()
        copy.id = self.id
        copy.nama = self.nama
        copy.alamat = self.alamat
        copy.ttl = self.ttl
        copy.namawali = self.namawali
        copy.nis = self.nis
        copy.nisn = self.nisn
        copy.ayah = self.ayah
        copy.ibu = self.ibu
        copy.jeniskelamin = self.jeniskelamin
        copy.status = self.status
        copy.kelasSekarang = self.kelasSekarang
        copy.tahundaftar = self.tahundaftar
        copy.tanggalberhenti = self.tanggalberhenti
        copy.tlv = self.tlv
        return copy
    }
}
