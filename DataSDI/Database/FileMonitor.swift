//
//  FileMonitor.swift
//  Data SDI
//
//  Created by Bismillah on 04/11/24.
//

import Foundation

/// `FileMonitor` adalah kelas yang dirancang untuk memantau perubahan pada sebuah file
/// dalam sistem berkas, khususnya event penghapusan dan penggantian nama. Anda bisa meminilih file mana yang akan diawasi dan penanganan ketika file berubah dari ``init(filePath:onChange:)``
///
///
/// Kelas ini menggunakan `DispatchSourceFileSystemObject` untuk mendengarkan perubahan
/// pada *file descriptor* yang terkait dengan jalur file yang diberikan.
/// Ketika event yang relevan terdeteksi, *closure* `onChange` akan dipicu.
///
/// - Catatan Penting:
///   - Pemantauan hanya mendeteksi event `.delete` (penghapusan) dan `.rename` (penggantian nama).
///   - *Closure* `onChange` dipanggil secara asinkron di *main queue* untuk memastikan
///     pembaruan UI atau operasi terkait UI lainnya dilakukan di *thread* yang benar.
///   - `fileDescriptor` akan secara otomatis ditutup saat `DispatchSource` dibatalkan
///     atau saat instance `FileMonitor` di-deinit.
final class FileMonitor {
    // MARK: - Properti Privat

    /// *File descriptor* sistem operasi untuk file yang sedang dipantau.
    /// Nilai `-1` menunjukkan bahwa *file descriptor* tidak valid atau belum dibuka.
    private var fileDescriptor: CInt = -1

    /// `DispatchSourceFileSystemObject` yang digunakan untuk memantau event pada file.
    private var source: DispatchSourceFileSystemObject?

    private let onChange: @Sendable () async -> Void

    // MARK: - Inisialisasi

    /// Menginisialisasi `FileMonitor` baru dan segera memulai pemantauan file yang ditentukan.
    ///
    /// - Parameters:
    ///   - filePath: Jalur lengkap ke file yang akan dipantau.
    ///   - onChange: Sebuah *closure* yang akan dipanggil setiap kali event perubahan
    ///               (penghapusan atau penggantian nama) terdeteksi pada file.
    init(filePath: String, onChange: @escaping @Sendable () async -> Void) {
        self.onChange = onChange
        startMonitoring(filePath: filePath)
    }

    // MARK: - Metode Privat

    /// Memulai proses pemantauan file.
    ///
    /// Metode ini membuka *file descriptor* untuk file, membuat `DispatchSource`,
    /// menetapkan penangan event untuk `.delete` dan `.rename`, serta penangan pembatalan.
    /// Pemantauan dimulai setelah `resume()` dipanggil.
    ///
    /// - Parameters:
    ///   - filePath: Jalur lengkap ke file yang akan dipantau.
    ///   - onChange: Sebuah *closure* yang akan dipanggil saat perubahan file terdeteksi.
    private func startMonitoring(filePath: String) {
        // Membuka file descriptor untuk file
        // `O_EVTONLY` memastikan file dibuka hanya untuk keperluan pemantauan event,
        // tanpa kemampuan membaca atau menulis.
        fileDescriptor = open(filePath, O_EVTONLY)

        guard fileDescriptor != -1 else {
            // Menangani kasus di mana file tidak dapat dibuka (misalnya, tidak ada, izin kurang).
            return
        }

        // Membuat DispatchSource untuk memantau perubahan pada file
        // Event mask diatur untuk mendengarkan penghapusan (`.delete`) dan penggantian nama (`.rename`).
        // Event diproses pada *global queue* untuk menghindari pemblokiran *main thread*.
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.delete, .rename],
            queue: DispatchQueue.global()
        )

        // Menetapkan tindakan yang akan dilakukan saat file berubah
        // Penangan event memanggil `onChange` di *main queue* untuk keamanan *thread*.
        source?.setEventHandler {
            // bridge sync → async
            Task {
                await self.onChange()
            }
        }

        // Menetapkan tindakan ketika source dibatalkan
        // Ketika `source` dibatalkan (baik secara eksplisit atau saat deinit),
        // *file descriptor* akan ditutup dan properti `source` diatur ulang menjadi `nil`.
        source?.setCancelHandler(handler: { [weak self] in
            guard let self else { return }
            close(fileDescriptor)
            fileDescriptor = -1
            source = nil
        })

        // Memulai pemantauan event
        source?.resume()
    }

    // MARK: - Deinisialisasi

    /// Memastikan bahwa `DispatchSource` dibatalkan ketika instance `FileMonitor` tidak lagi digunakan.
    ///
    /// Pembatalan ini akan memicu `cancelHandler` yang telah diatur, yang akan menutup
    /// *file descriptor* terkait dan membersihkan sumber daya.
    deinit {
        source?.cancel()
    }
}

extension FileManager {
    /// Optional: ekstensi FileManager untuk permbersihan file-file sampah yang digunakan untuk mengoptimalkan aplikasi..
    func cleanupTempImages() {
        let tempDir = temporaryDirectory
            .appendingPathComponent("TempImages", isDirectory: true)

        do {
            let contents = try contentsOfDirectory(at: tempDir,
                                                   includingPropertiesForKeys: nil,
                                                   options: [])

            for url in contents {
                try? removeItem(at: url)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }
}

extension AppDelegate {
    /**
        Menangani perubahan pada file database. Fungsi ini dipanggil ketika terdeteksi adanya perubahan pada file database,
        seperti perubahan yang disebabkan oleh sinkronisasi iCloud atau modifikasi file.

        Fungsi ini menampilkan sebuah alert kepada pengguna yang memberitahukan bahwa perubahan telah terdeteksi pada file.
        Pengguna diberikan dua pilihan:

        1.  **OK:** Memuat ulang database dari file yang ada dan menyimpan data saat ini.
            Jika file database tidak ada, aplikasi akan membuat file baru dan mereset data.
            FileMonitor akan diinisialisasi ulang untuk file yang baru.
            Cache saran akan dibersihkan.

        2.  **Tutup Aplikasi:** Menutup aplikasi setelah memastikan tabel database telah disiapkan.

        Fungsi ini menggunakan DispatchGroup untuk memastikan bahwa operasi asinkron selesai sebelum melanjutkan.
     */
    @MainActor
    func handleFileChange() async {
        // UI: reset & alert
        fileMonitor = nil

        // Tutup semua koneksi database
        DatabaseController.shared.closeConnection()

        // Clear sinkron
        StringInterner.shared.clear()
        ImageCacheManager.shared.clear()

        // Clear async paralel dan tutup koneksi pool, dan tunggu semuanya.
        async let idsClear: Void = IdsCacheManager.shared.clearUpCache()
        async let suggestionClear: Void = SuggestionCacheManager.shared.clearCache()
        async let closePoolConn: Void = DatabaseManager.shared.pool.closeAll()
        _ = await (idsClear, suggestionClear, closePoolConn)

        alert = nil
        alert = NSAlert()
        alert?.messageText = "Perubahan Terdeteksi pada File"
        alert?.informativeText = """
        File mungkin belum sepenuhnya diunduh dari iCloud Drive atau sedang dalam proses modifikasi. \
        Selesaikan proses unduhan atau modifikasi file terlebih dahulu. Jika tidak ada file baru, \
        aplikasi akan membuat file baru dan mereset data.
        """
        alert?.alertStyle = .critical
        alert?.addButton(withTitle: "OK")
        alert?.addButton(withTitle: "Tutup Aplikasi")

        let response = alert?.runModal()

        if response == .alertFirstButtonReturn {
            // OK → reload DB, broadcast save, reinit monitor
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
            let dbFilePath = dataSiswaFolderURL.appendingPathComponent("data.sdi").path

            DatabaseController.shared.hapusWalShm(dbPath: dbFilePath)

            // Kerja berat dulu di background, barulah terminate
            await Task.detached(priority: .userInitiated) {
                DatabaseController.shared.reloadDatabase(withNewPath: dbFilePath)
                DatabaseManager.shared.reloadConnections(newPath: dbFilePath)
                await IdsCacheManager.shared.loadAllCaches()
            }.value

            // Jika benar perlu jeda kecil
            try? await Task.sleep(nanoseconds: 500_000_000)

            NotificationCenter.default.post(name: .saveData, object: nil)

            if FileManager.default.fileExists(atPath: dbFilePath) {
                if fileMonitor != nil {
                    fileMonitor = nil
                }
                createFileMonitor()
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    /**
        Membuat dan menginisialisasi pemantau berkas (file monitor) untuk memantau perubahan pada berkas database.

        Fungsi ini melakukan langkah-langkah berikut:
        1. Mendapatkan URL direktori dokumen pengguna.
        2. Membuat URL folder "Data SDI" di dalam direktori dokumen.
        3. Membuat path lengkap ke berkas database "data.sdi" di dalam folder "Data SDI".
        4. Menginisialisasi objek `FileMonitor` dengan path berkas database dan closure handler yang akan dipanggil ketika perubahan terdeteksi.
        5. Menyimpan instance `FileMonitor` yang dibuat ke properti `fileMonitor` kelas ini.

        Closure handler `handleFileChange()` dipanggil ketika perubahan terdeteksi pada berkas database.
     */
    func createFileMonitor() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
        let dbFilePath = dataSiswaFolderURL.appendingPathComponent("data.sdi").path

        fileMonitor = FileMonitor(filePath: dbFilePath) { [weak self] in
            await self?.handleFileChange()
        }
    }
}
