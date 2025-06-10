//
//  Database Manager.swift
//  DataSDI
//
//  Created by Ays on 02/06/25.
//

import Foundation

/// `DatabaseManager` adalah kelas final singleton yang mengelola satu instance
/// `SQLiteConnectionPool` untuk interaksi *database* di seluruh aplikasi.
///
/// Kelas ini menyediakan titik akses terpusat untuk *database* SQLite,
/// memastikan bahwa semua bagian aplikasi menggunakan kumpulan koneksi yang sama.
/// Database secara default terletak di subdirektori "Data SDI" di dalam direktori Dokumen pengguna.
///
/// - Properti:
///   - `static let shared`: Instance singleton dari `DatabaseManager`.
///   - `let pool`: Instance dari `SQLiteConnectionPool` yang digunakan untuk mengelola
///     koneksi ke *database* SQLite. Kumpulan koneksi diinisialisasi dengan ukuran 4.
///
/// - Penggunaan:
///   Akses *pool* koneksi melalui instance `shared` untuk melakukan operasi *database*
///   (misalnya, `DatabaseManager.shared.pool.read { ... }`).
///
/// - Catatan:
///   - Inisialisasi *pool* menggunakan `try!`, yang berarti aplikasi akan mengalami
///     *crash* jika ada kesalahan saat membuat koneksi *database* di awal.
///     Pastikan jalur *database* dan izin sudah benar.
final class DatabaseManager {
    static let shared = DatabaseManager()
    let pool: SQLiteConnectionPool

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
        let db = dataSiswaFolderURL.appendingPathComponent("data.sqlite3").path
        pool = try! SQLiteConnectionPool(path: db, poolSize: 4)
    }
}
