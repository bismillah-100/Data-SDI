//
//  DatabasePool.swift
//  Data SDI
//
//  Created by Ays on 23/05/25.
//
import SQLite

/// Sebuah *actor* yang mewakili koneksi SQLite yang digunakan oleh ``SQLiteConnectionPool``.
/// `ConnectionWorker` bertanggung jawab untuk menjalankan query pada koneksi SQLite
/// secara thread-safe. Actor ini memastikan bahwa hanya satu thread yang dapat menjalankan
/// query pada koneksi pada satu waktu, sehingga menghindari kondisi bal.
actor ConnectionWorker {
    /// Koneksi SQLite yang digunakan oleh worker ini.
    /// Koneksi ini digunakan untuk menjalankan query secara thread-safe.
    let conn: Connection

    /// Inisialisasi `ConnectionWorker` dengan koneksi SQLite.
    /// - Parameter conn: Koneksi SQLite yang akan digunakan oleh worker ini.
    init(conn: Connection) { self.conn = conn }

    ///  Fungsi untuk menjalankan query pada koneksi ini.
    /// - Parameter body: A closure yang menerima `Connection` dan mengembalikan nilai generik `T`.
    /// - Returns: Retrhows nilai generik `T` yang dihasilkan oleh closure.
    /// - Throws: Jika terjadi kesalahan saat menjalankan query.
    func run<T>(_ body: (Connection) throws -> T) rethrows -> T {
        try body(conn)
    }
}

/// Sebuah *actor* yang mengelola kumpulan koneksi *read-only* ke *database* SQLite.
///
/// `SQLiteConnectionPool` dirancang untuk menyediakan akses konkurensi-aman ke *database*
/// SQLite, khususnya untuk operasi baca. Dengan menggunakan pola *connection pool*,
/// ia menghindari pembukaan dan penutupan koneksi berulang kali, yang dapat meningkatkan
/// kinerja. Actor ini juga mengaktifkan mode *Write-Ahead Logging* (WAL) untuk *database*
/// untuk mendukung konkurensi baca yang lebih baik.
final actor SQLiteConnectionPool {
    /// Kumpulan koneksi yang tersedia untuk digunakan.
    private var idle: [ConnectionWorker] = []
    /// Daftar ``ConnectionWorker`` yang masuk dalam antrian ketika
    /// semua koneksi sedang digunakan.
    private var waiters: [CheckedContinuation<ConnectionWorker, Never>] = []

    /// Menginisialisasi kumpulan koneksi SQLite baru.
    ///
    /// - Parameters:
    ///   - path: Jalur ke file *database* SQLite.
    ///   - poolSize: Jumlah koneksi *read-only* yang akan dibuat dalam kumpulan.
    ///               Nilai default adalah 4.
    /// - Throws: `Error` jika terjadi masalah saat membuka koneksi atau mengaktifkan WAL.
    init(path: String, poolSize: Int = 4) throws {
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
        idle = try (0 ..< poolSize).map { _ in
            let conn = try Connection(path, readonly: true)
            // Mengatur batas waktu sibuk untuk koneksi *read-only*.
            conn.busyTimeout = 5000
            // Menambahkan *trace* untuk mencetak setiap perintah SQL yang dijalankan dalam mode DEBUG.
            conn.trace { sql in
                #if DEBUG
                    print("[SQL] \(sql)")
                #endif
            }
            return ConnectionWorker(conn: conn)
        }
    }

    /// Mengambil `ConnectionWorker` dari kumpulan koneksi.
    /// Jika tidak ada koneksi yang tersedia, tunggu hingga salah satu koneksi dilepaskan.
    /// - Returns: `ConnectionWorker` yang siap digunakan.
    /// - Note: Fungsi ini menggunakan `withCheckedContinuation` untuk menunggu koneksi
    ///         yang tersedia jika semua koneksi sedang digunakan.
    private func acquire() async -> ConnectionWorker {
        if let w = idle.popLast() { return w }
        return await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    /// Melepaskan `ConnectionWorker` kembali ke kumpulan koneksi.
    /// Jika ada yang menunggu, berikan koneksi tersebut kepada yang pertama dalam antrian.
    /// Jika tidak ada yang menunggu, tambahkan koneksi ke daftar `idle`.
    /// - Parameter w: `ConnectionWorker` yang akan dilepaskan.
    /// - Note: Fungsi ini memastikan bahwa koneksi yang dilepaskan dapat digunakan kembali
    ///         oleh thread lain yang membutuhkan koneksi.
    private func release(_ w: ConnectionWorker) {
        if !waiters.isEmpty {
            let cont = waiters.removeFirst()
            cont.resume(returning: w)
        } else {
            idle.append(w)
        }
    }

    // API utama: block dieksekusi di worker, bukan di pool.
    /// Fungsi untuk menjalankan operasi baca pada *database* SQLite.
    /// - Parameter body: Closure yang menerima `Connection` dan mengembalikan nilai generic `T`.
    /// - Returns: Nilai generik `T` yang dihasilkan oleh closure.
    /// - Throws: Jika terjadi kesalahan saat menjalankan query.
    /// - Note: Fungsi ini memastikan bahwa operasi baca dilakukan secara thread-safe
    ///         dengan menggunakan `ConnectionWorker` yang dikelola oleh actor ini.
    func read<T>(
        _ body: @escaping @Sendable (Connection) throws -> T
    ) async throws -> T {
        let worker = await acquire()
        defer { self.release(worker) }
        return try await worker.run(body)
    }

    /// Fungsi untuk menutup semua koneksi dalam kumpulan.
    /// Ini akan menghapus semua koneksi yang ada dalam daftar `idle`.
    /// - Note: Fungsi ini digunakan untuk membersihkan sumber daya ketika kumpulan koneksi
    ///         tidak lagi diperlukan, misalnya saat aplikasi ditutup atau saat *database* tidak
    ///         lagi digunakan.
    func closeAll() {
        idle.removeAll()
    }
}
