//
//  UserDefaults.swift
//  Data SDI
//
//  Created by MacBook on 14/10/25.
//

import Foundation

extension UserDefaults {
    // MARK: - Key Definitions
    fileprivate enum Key {
        // Integrasi
        static let integrasiUndoSiswaKelas = "IntegrasiUndoSiswaKelas"

        // Suggestions
        static let showSuggestions = "showSuggestions"
        static let showSuggestionsDiTabel = "showSuggestionsDiTabel"
        static let maksimalSaran = "maksimalSaran"

        // Transaksi
        static let grupTransaksi = "grupTransaksi"
        static let urutanTransaksi = "urutanTransaksi"

        // Tampilan Siswa
        static let tampilkanSiswaLulus = "tampilkanSiswaLulus"
        static let sembunyikanSiswaBerhenti = "sembunyikanSiswaBerhenti"

        // UI Settings
        static let autoCheckUpdates = "autoCheckUpdates"
        static let kapitalkanPengetikan = "kapitalkanPengetikan"

        // Sidebar Ringkasan
        static let sidebarRingkasanKelas = "sidebarRingkasanKelas"
        static let sidebarRingkasanGuru = "sidebarRingkasanGuru"
        static let sidebarRingkasanSiswa = "sidebarRingkasanSiswa"

        // Database Cleanup
        static let bersihkanTabelMapel = "bersihkanTabelMapel"
        static let bersihkanTabelTugas = "bersihkanTabelTugas"
        static let bersihkanTabelKelas = "bersihkanTabelKelas"
        static let bersihkanTabelSiswaKelas = "bersihkanTabelSiswaKelas"
        static let bersihkanTabelStruktur = "bersihkanTabelStruktur"

        // Struktur
        static let strukturTahunAjaran1 = "strukturTahunAjaran1"
        static let strukturTahunAjaran2 = "strukturTahunAjaran2"
        static let StrukturOutlineViewRowHeight = "StrukturOutlineViewRowHeight"
    }

    // MARK: - Integrasi

    /// Menentukan apakah fitur integrasi undo antara entitas `Siswa` dan `Kelas` diaktifkan.
    /// Nilai default: `true`
    var integrasiUndoSiswaKelas: Bool {
        get { bool(forKey: Key.integrasiUndoSiswaKelas) }
        set { set(newValue, forKey: Key.integrasiUndoSiswaKelas) }
    }

    // MARK: - Suggestions

    /// Menentukan apakah sistem menampilkan saran input otomatis.
    /// Nilai default: `true`
    var showSuggestions: Bool {
        get { bool(forKey: Key.showSuggestions) }
        set { set(newValue, forKey: Key.showSuggestions) }
    }

    /// Menentukan apakah saran ditampilkan langsung di tabel (misalnya di dalam cell editor).
    /// Nilai default: `true`
    var showSuggestionsDiTabel: Bool {
        get { bool(forKey: Key.showSuggestionsDiTabel) }
        set { set(newValue, forKey: Key.showSuggestionsDiTabel) }
    }

    /// Jumlah maksimum saran yang akan ditampilkan.
    /// Nilai default: `10`
    var maksimalSaran: Int {
        get { integer(forKey: Key.maksimalSaran) }
        set { set(newValue, forKey: Key.maksimalSaran) }
    }

    // MARK: - Transaksi

    /// Menentukan apakah transaksi dikelompokkan berdasarkan kategori tertentu.
    /// Nilai default: `false`
    var grupTransaksi: Bool {
        get { bool(forKey: Key.grupTransaksi) }
        set { set(newValue, forKey: Key.grupTransaksi) }
    }

    /// Menentukan urutan tampilan transaksi, misalnya `"terbaru"` atau `"terlama"`.
    /// Nilai default: `"terbaru"`
    var urutanTransaksi: String {
        get { string(forKey: Key.urutanTransaksi) ?? "terbaru" }
        set { set(newValue, forKey: Key.urutanTransaksi) }
    }

    // MARK: - Tampilan Siswa

    /// Menentukan apakah siswa yang sudah lulus tetap ditampilkan dalam daftar.
    /// Nilai default: `true`
    var tampilkanSiswaLulus: Bool {
        get { bool(forKey: Key.tampilkanSiswaLulus) }
        set { set(newValue, forKey: Key.tampilkanSiswaLulus) }
    }

    /// Menentukan apakah siswa yang sudah berhenti disembunyikan.
    /// Nilai default: `false`
    var sembunyikanSiswaBerhenti: Bool {
        get { bool(forKey: Key.sembunyikanSiswaBerhenti) }
        set { set(newValue, forKey: Key.sembunyikanSiswaBerhenti) }
    }

    // MARK: - UI Settings

    /// Menentukan apakah aplikasi akan memeriksa pembaruan secara otomatis saat diluncurkan.
    /// Nilai default: `true`
    var autoCheckUpdates: Bool {
        get { bool(forKey: Key.autoCheckUpdates) }
        set { set(newValue, forKey: Key.autoCheckUpdates) }
    }

    /// Menentukan apakah sistem secara otomatis mengkapitalkan
    /// huruf pertama sebelum spasi saat mengetik.
    /// Nilai default: `true`
    var kapitalkanPengetikan: Bool {
        get { bool(forKey: Key.kapitalkanPengetikan) }
        set { set(newValue, forKey: Key.kapitalkanPengetikan) }
    }

    // MARK: - Sidebar Ringkasan

    /// Label yang digunakan untuk menampilkan ringkasan bagian "Kelas" di sidebar.
    /// Nilai default: `"Ikhtisar"`
    var sidebarRingkasanKelas: String {
        get { string(forKey: Key.sidebarRingkasanKelas) ?? "Ikhtisar" }
        set { set(newValue, forKey: Key.sidebarRingkasanKelas) }
    }

    /// Label yang digunakan untuk menampilkan ringkasan bagian "Guru" di sidebar.
    /// Nilai default: `"Guru"`
    var sidebarRingkasanGuru: String {
        get { string(forKey: Key.sidebarRingkasanGuru) ?? "Struktur" }
        set { set(newValue, forKey: Key.sidebarRingkasanGuru) }
    }

    /// Label yang digunakan untuk menampilkan ringkasan bagian "Siswa" di sidebar.
    /// Nilai default: `"Sensus"`
    var sidebarRingkasanSiswa: String {
        get { string(forKey: Key.sidebarRingkasanSiswa) ?? "Sensus" }
        set { set(newValue, forKey: Key.sidebarRingkasanSiswa) }
    }

    // MARK: - Database Cleanup

    /// Menentukan apakah tabel ``MapelColumns`` akan dibersihkan saat inisialisasi ulang database.
    /// Nilai default: `false`
    var bersihkanTabelMapel: Bool {
        get { bool(forKey: Key.bersihkanTabelMapel) }
        set { set(newValue, forKey: Key.bersihkanTabelMapel) }
    }

    /// Menentukan apakah tabel ``PenugasanGuruMapelKelasColumns`` akan dibersihkan saat inisialisasi ulang database.
    /// Nilai default: `false`
    var bersihkanTabelTugas: Bool {
        get { bool(forKey: Key.bersihkanTabelTugas) }
        set { set(newValue, forKey: Key.bersihkanTabelTugas) }
    }

    /// Menentukan apakah tabel ``KelasColumns`` akan dibersihkan saat inisialisasi ulang database.
    /// Nilai default: `false`
    var bersihkanTabelKelas: Bool {
        get { bool(forKey: Key.bersihkanTabelKelas) }
        set { set(newValue, forKey: Key.bersihkanTabelKelas) }
    }

    /// Menentukan apakah tabel ``SiswaKelasColumns`` akan dibersihkan saat inisialisasi ulang database.
    /// Nilai default: `false`
    var bersihkanTabelSiswaKelas: Bool {
        get { bool(forKey: Key.bersihkanTabelSiswaKelas) }
        set { set(newValue, forKey: Key.bersihkanTabelSiswaKelas) }
    }

    /// Menentukan apakah tabel ``JabatanColumns`` akan dibersihkan saat inisialisasi ulang database.
    /// Nilai default: `false`
    var bersihkanTabelStruktur: Bool {
        get { bool(forKey: Key.bersihkanTabelStruktur) }
        set { set(newValue, forKey: Key.bersihkanTabelStruktur) }
    }

    // MARK: - STRUKTUR GURU
    /// Input Tahun Ajaran 1 Struktur Guru yang disimpan di UserDefaults untuk filter data.
    var strukturTahunAjaran1: String {
        get { string(forKey: Key.strukturTahunAjaran1) ?? "" }
        set { set(newValue, forKey: Key.strukturTahunAjaran1) }
    }

    /// Input Tahun Ajaran 2 Struktur Guru yang disimpan di UserDefaults untuk filter data.
    var strukturTahunAjaran2: String {
        get { string(forKey: Key.strukturTahunAjaran2) ?? "" }
        set { set(newValue, forKey: Key.strukturTahunAjaran2) }
    }
}

extension UserDefaults {
    /// Mendaftarkan nilai default untuk seluruh preferensi aplikasi agar tersedia saat pertama kali dijalankan.
    ///
    /// Panggil fungsi ini di awal siklus hidup aplikasi, misalnya di `applicationDidFinishLaunching`.
    static func registerAppDefaults() {
        standard.register(defaults: [
            Key.integrasiUndoSiswaKelas: true,
            Key.showSuggestions: true,
            Key.showSuggestionsDiTabel: true,
            Key.maksimalSaran: 10,
            Key.grupTransaksi: false,
            Key.urutanTransaksi: "terbaru",
            Key.tampilkanSiswaLulus: true,
            Key.sembunyikanSiswaBerhenti: false,
            Key.autoCheckUpdates: true,
            Key.kapitalkanPengetikan: true,
            "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints": false,
            Key.sidebarRingkasanKelas: "Ikhtisar",
            Key.sidebarRingkasanGuru: "Struktur",
            Key.sidebarRingkasanSiswa: "Sensus",
            Key.bersihkanTabelMapel: false,
            Key.bersihkanTabelTugas: false,
            Key.bersihkanTabelKelas: false,
            Key.bersihkanTabelSiswaKelas: false,
            Key.bersihkanTabelStruktur: false,
        ])
    }
}
