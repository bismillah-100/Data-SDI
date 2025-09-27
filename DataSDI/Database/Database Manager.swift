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
    /// Membuat singleton dengan *private initializer*.
    static let shared: DatabaseManager = .init()

    /// `SQLiteConnectionPool` untuk mengelola koneksi
    /// yang dibuat untuk mendukung fitur konkurensi `SQLite`
    /// dan `Switf Concurrency`.
    var pool: SQLiteConnectionPool

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
        let db = dataSiswaFolderURL.appendingPathComponent("data.sdi").path
        pool = try! SQLiteConnectionPool(path: db, poolSize: 4)
    }

    /// Fungsi untuk memuat ulang koneksi.
    ///
    /// Digunakan ketika file database dihapus dari penyimpanan
    /// persisten saat aplikasi sedang berjalan. Monitoring file
    /// diimplementasikan di ``FileMonitor``.
    /// - Parameter newPath: `path` jalur file baru.
    func reloadConnections(newPath: String) {
        do {
            pool = try SQLiteConnectionPool(path: newPath, poolSize: 4)
        } catch {
            fatalError("Tidak dapat membuat connectionpool")
        }
    }
}
