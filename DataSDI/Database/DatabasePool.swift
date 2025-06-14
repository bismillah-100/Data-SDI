//
//  DatabasePool.swift
//  Data SDI
//
//  Created by Ays on 23/05/25.
//
import SQLite

/// Sebuah *actor* yang mengelola kumpulan koneksi *read-only* ke *database* SQLite.
///
/// `SQLiteConnectionPool` dirancang untuk menyediakan akses konkurensi-aman ke *database*
/// SQLite, khususnya untuk operasi baca. Dengan menggunakan pola *connection pool*,
/// ia menghindari pembukaan dan penutupan koneksi berulang kali, yang dapat meningkatkan
/// kinerja. Actor ini juga mengaktifkan mode *Write-Ahead Logging* (WAL) untuk *database*
/// untuk mendukung konkurensi baca yang lebih baik.
public actor SQLiteConnectionPool {
    // MARK: - Properti Privat

    /// Kumpulan koneksi *read-only* yang tersedia.
    private var connections: [Connection]
    /// Indeks untuk melacak koneksi mana yang akan diberikan berikutnya dalam pola *round-robin*.
    private var index = 0

    // MARK: - Inisialisasi

    /// Menginisialisasi kumpulan koneksi SQLite baru.
    ///
    /// - Parameters:
    ///   - path: Jalur ke file *database* SQLite.
    ///   - poolSize: Jumlah koneksi *read-only* yang akan dibuat dalam kumpulan.
    ///               Nilai default adalah 4.
    /// - Throws: `Error` jika terjadi masalah saat membuka koneksi atau mengaktifkan WAL.
    public init(path: String, poolSize: Int = 4) throws {
        // 1. Koneksi sementara untuk mengaktifkan WAL
        // Koneksi ini digunakan hanya sekali untuk mengatur mode jurnal WAL,
        // yang memungkinkan beberapa pembacaan bersamaan sambil penulisan.
        let writeConn = try Connection(path)
        try writeConn.run("PRAGMA journal_mode=WAL;")
        // Mengatur batas waktu sibuk untuk koneksi tulis sementara.
        writeConn.busyTimeout = 5000
        #if DEBUG
            print("✅ WAL mode diaktifkan")
        #endif

        // 2. Buat koneksi *read-only*
        // Membuat sejumlah koneksi yang ditentukan oleh `poolSize`, semuanya dalam mode *read-only*.
        // Ini memastikan bahwa operasi baca tidak akan memblokir satu sama lain dan dapat berjalan secara paralel.
        connections = try (0 ..< poolSize).map { _ in
            let conn = try Connection(path, readonly: true)
            // Mengatur batas waktu sibuk untuk koneksi *read-only*.
            conn.busyTimeout = 5000
            // Menambahkan *trace* untuk mencetak setiap perintah SQL yang dijalankan dalam mode DEBUG.
            conn.trace { sql in
                #if DEBUG
                    print("[SQL] \(sql)")
                #endif
            }
            return conn
        }
    }

    // MARK: - Metode Privat

    /// Mengembalikan koneksi berikutnya dari kumpulan menggunakan algoritma *round-robin*.
    ///
    /// - Returns: Sebuah objek `Connection` dari kumpulan. Jika kumpulan kosong,
    ///            ia akan mengembalikan elemen pertama (ini harus ditangani dengan hati-hati
    ///            jika `connections` bisa kosong setelah inisialisasi).
    private func nextConnection() -> Connection {
        // Guard ini bisa disederhanakan jika asumsinya `connections` tidak akan pernah kosong
        // setelah inisialisasi berhasil.
        guard !connections.isEmpty else { return connections[0] }
        let conn = connections[index]
        // Memajukan indeks, melingkar kembali ke 0 jika mencapai akhir kumpulan.
        index = (index + 1) % connections.count
        return conn
    }

    // MARK: - Metode Publik

    /// Melakukan operasi baca pada salah satu koneksi dalam kumpulan.
    ///
    /// Metode ini mengambil koneksi berikutnya dari kumpulan dan mengeksekusi blok
    /// kode yang diberikan dengan koneksi tersebut. Karena ini adalah metode `actor`,
    /// akses ke kumpulan koneksi aman dari konkurensi.
    ///
    /// - Parameter block: Sebuah *closure* yang menerima `Connection` dan melempar `Error`.
    ///                    Logika operasi baca harus diimplementasikan di dalam *closure* ini.
    /// - Throws: Setiap kesalahan yang dilemparkan oleh *closure* `block`.
    /// - Returns: Hasil `T` yang dikembalikan oleh *closure* `block`.
    public func read<T>(_ block: (Connection) throws -> T) async throws -> T {
        let conn = nextConnection()
        return try block(conn)
    }

    /// Menutup semua koneksi dalam kumpulan.
    ///
    /// Metode ini menghapus semua koneksi dari array `connections`, yang menyebabkan
    /// koneksi-koneksi tersebut di-*deinitialize* dan secara otomatis menutup
    /// koneksi *database* yang mendasarinya. Indeks kumpulan juga disetel ulang.
    public func closeAll() {
        connections.removeAll() // Ini akan deinit dan otomatis menutup koneksi
        index = 0
    }
}
