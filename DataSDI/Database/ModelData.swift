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
