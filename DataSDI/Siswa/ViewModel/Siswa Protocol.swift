//
//  Siswa Protocol.swift
//  Data SDI
//
//  Created by MacBook on 20/09/25.
//

import Foundation

/// Protokol yang mendefinisikan antarmuka untuk mengelola, mengambil, dan memanipulasi data siswa.
///
/// Objek yang mengadopsi protokol `SiswaDataSource` bertanggung jawab sebagai sumber kebenaran tunggal
/// untuk data siswa. Ini mengabstraksi lapisan data (apakah itu berasal dari database lokal, jaringan, atau memori)
/// dari lapisan presentasi (UI), sehingga memungkinkan komponen UI seperti `NSTableView` atau `UICollectionView`
/// untuk berinteraksi dengan data secara konsisten.
protocol SiswaDataSource {
    // MARK: - Properti

    /// Jumlah total siswa yang saat ini ada di dalam data source.
    ///
    /// Properti ini harus selalu mencerminkan jumlah item terbaru dalam koleksi dan biasanya
    /// digunakan oleh `NSTableView` atau komponen serupa untuk menentukan jumlah baris yang akan ditampilkan.
    var numberOfRows: Int { get }

    // MARK: - Pengambilan Data

    /// Mengambil data siswa secara asinkron dari sumber data persisten (misalnya, database atau API).
    ///
    /// Fungsi ini harus dipanggil untuk memuat atau menyegarkan data awal ke dalam memori.
    func fetchSiswa() async

    /// Mengembalikan semua data siswa yang saat ini ada di memori dalam bentuk array datar.
    /// - Returns: Sebuah array `[ModelSiswa]` yang berisi semua siswa.
    func currentFlatData() -> [ModelSiswa]

    /// Mengambil data siswa pada indeks baris tertentu.
    /// - Parameter row: Indeks baris dari siswa yang ingin diambil.
    /// - Returns: Objek `ModelSiswa` pada indeks yang diberikan, atau `nil` jika indeks di luar batas.
    func siswa(at row: Int) -> ModelSiswa?

    /// Mencari dan mengembalikan siswa berdasarkan ID uniknya.
    /// - Parameter id: ID unik dari siswa yang dicari.
    /// - Returns: Objek `ModelSiswa` yang cocok, atau `nil` jika tidak ada siswa dengan ID tersebut.
    func siswa(for id: Int64) -> ModelSiswa?

    /// Mendapatkan informasi dasar (ID, nama, foto) dari siswa pada baris tertentu.
    ///
    /// Fungsi ini dioptimalkan untuk pengambilan data cepat yang sering digunakan di UI, tanpa perlu memuat seluruh objek model.
    /// - Parameter row: Indeks baris siswa.
    /// - Returns: Sebuah tuple berisi `id`, `nama`, dan `foto` siswa, atau `nil` jika indeks tidak valid.
    func getIdNamaFoto(row: Int) -> (id: Int64, nama: String, foto: Data)?

    // MARK: - Pencarian Indeks

    /// Mencari indeks baris dari seorang siswa berdasarkan ID uniknya.
    /// - Parameter id: ID unik dari siswa yang dicari.
    /// - Returns: Indeks baris berbasis nol dari siswa, atau `nil` jika tidak ditemukan.
    func indexSiswa(for id: Int64) -> Int?

    // MARK: - Manipulasi Data

    /// Memperbarui data seorang siswa yang ada di dalam data source.
    ///
    /// Fungsi ini akan mencari siswa dengan ID yang sama dengan model yang diberikan dan memperbarui datanya.
    /// - Parameter siswa: Objek `ModelSiswa` dengan data yang sudah diperbarui.
    /// - Returns: Indeks baris dari siswa yang diperbarui, atau `nil` jika siswa tidak ditemukan.
    func update(siswa: ModelSiswa) -> Int?

    /// Menghapus siswa dari data source pada indeks tertentu.
    /// - Parameter index: Indeks baris dari siswa yang akan dihapus.
    func remove(at index: Int)

    /// Menghapus seorang siswa dari data source berdasarkan objek modelnya.
    /// - Parameter siswa: Objek `ModelSiswa` yang akan dihapus.
    /// - Returns: Sebuah tuple yang berisi `index` dari siswa yang dihapus dan objek `UpdateData` untuk pembaruan UI, atau `nil` jika siswa tidak ditemukan.
    func removeSiswa(_ siswa: ModelSiswa) -> (index: Int, update: UpdateData)?

    /// Menyisipkan seorang siswa baru ke dalam data source sambil mempertahankan urutan yang benar.
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` baru yang akan disisipkan.
    ///   - comparator: Sebuah closure yang membandingkan dua objek `ModelSiswa` untuk menentukan urutan penyisipan yang benar.
    /// - Returns: Indeks baris tempat siswa baru disisipkan.
    func insert(_ siswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int

    /// Memperbarui nilai properti tertentu dari seorang siswa baik di model dalam memori maupun di database persisten.
    /// - Parameters:
    ///   - id: ID unik siswa yang akan diperbarui.
    ///   - columnIdentifier: Pengidentifikasi kolom (`SiswaColumn`) yang nilainya akan diubah.
    ///   - rowIndex: Indeks baris siswa saat ini (opsional, untuk optimasi).
    ///   - newValue: Nilai baru dalam bentuk `String` yang akan ditetapkan.
    func updateModelAndDatabase(id: Int64, columnIdentifier: SiswaColumn, rowIndex: Int?, newValue: String)

    // MARK: - Pengurutan dan Relokasi

    /// Mengatur ulang posisi seorang siswa dalam koleksi setelah datanya diubah, agar sesuai dengan urutan yang ditentukan.
    ///
    /// Fungsi ini lebih efisien daripada mengurutkan ulang seluruh koleksi data saat hanya satu item yang berubah.
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang posisinya perlu dievaluasi ulang.
    ///   - comparator: Closure pembanding untuk menentukan urutan yang benar.
    ///   - columnIndex: Indeks kolom yang memicu relokasi (opsional).
    /// - Returns: Objek `UpdateData` yang berisi informasi perpindahan (indeks lama dan baru) jika siswa berpindah posisi, atau `nil` jika posisinya tetap.
    func relocateSiswa(_ siswa: ModelSiswa,
                       comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
                       columnIndex: Int?) -> UpdateData?

    /// Mengurutkan seluruh koleksi siswa di dalam data source.
    /// - Parameter comparator: Sebuah closure yang mendefinisikan kriteria pengurutan antara dua objek `ModelSiswa`.
    func sort(by comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool)

    // MARK: - Undo & Redo

    /// Membatalkan aksi terakhir dan mengembalikan model ke keadaan semula.
    /// - Parameter originalModel: Objek `DataAsli` yang menyimpan keadaan siswa sebelum diubah.
    func undoAction(originalModel: DataAsli)

    /// Melakukan kembali aksi yang sebelumnya dibatalkan.
    /// - Parameter originalModel: Objek `DataAsli` yang menyimpan keadaan siswa sebelum diubah (yang akan diterapkan kembali).
    func redoAction(originalModel: DataAsli)

    // MARK: - Pencarian dan Penyaringan

    /// Melakukan pencarian siswa secara asinkron berdasarkan teks filter.
    ///
    /// Hasil pencarian akan memperbarui koleksi data yang dikelola oleh data source ini.
    /// - Parameter filter: Teks yang digunakan untuk mencari siswa (misalnya, nama).
    func cariSiswa(_ filter: String) async

    /// Memfilter daftar siswa untuk menampilkan atau menyembunyikan siswa yang sudah berhenti.
    /// - Parameters:
    ///   - isBerhentiHidden: `true` untuk menyembunyikan siswa yang berhenti, `false` untuk menampilkan semua.
    ///   - comparator: Closure pembanding untuk menjaga urutan data setelah pemfilteran.
    /// - Returns: Sebuah array berisi indeks baris dari siswa yang terpengaruh oleh operasi filter (misalnya, yang disembunyikan atau ditampilkan kembali).
    func filterSiswaBerhenti(_ isBerhentiHidden: Bool,
                             comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) async -> [Int]

    /// Memfilter daftar siswa untuk menampilkan atau menyembunyikan siswa yang sudah lulus.
    /// - Parameters:
    ///   - tampilkanLulus: `true` untuk menampilkan siswa yang sudah lulus, `false` untuk menyembunyikannya.
    ///   - comparator: Closure pembanding untuk menjaga urutan data setelah pemfilteran.
    /// - Returns: Sebuah array berisi indeks baris dari siswa yang terpengaruh oleh operasi filter.
    func filterSiswaLulus(_ tampilkanLulus: Bool,
                          comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) async -> [Int]
    
    /// Fungsi untuk membersihkan data.
    func clearData()
}

extension SiswaDataSource {
    /// Mengambil array siswa berdasarkan kumpulan indeks absolut.
    ///
    /// Menjalankan func ``siswa(at:)`` untuk mendapatkan
    /// ``ModelSiswa`` dari setiap indeks di dalam `indexes`.
    ///
    /// - Parameter indexes: `IndexSet` berisi indeks absolut siswa.
    /// - Returns: Array `ModelSiswa` sesuai urutan indeks.
    @inline(__always)
    func siswa(in indexes: IndexSet) -> [ModelSiswa] {
        indexes.compactMap { siswa(at: $0) }
    }

    /// Mengambil ID siswa berdasarkan kumpulan indeks absolut.
    ///
    /// Menjalankan func ``siswa(in:)`` untuk mendapatkan ``ModelSiswa``
    /// sesuai urutan parameter `indexes` dan mengambil properti ``ModelSiswa/id``.
    ///
    /// - Parameter indexes: `IndexSet` berisi indeks absolut siswa.
    /// - Returns: Set `Int64` berisi ID siswa.
    @inline(__always)
    func siswaIDs(in indexes: IndexSet) -> Set<Int64> {
        Set(siswa(in: indexes).map(\.id))
    }

    /// Mengambil `IndexSet` berdasarkan kumpulan ID siswa.
    ///
    /// Menjalankan func ``indexSiswa(for:)`` untuk mendapatkan
    /// indeks dari parameter `ids`.
    ///
    /// - Parameter ids: Set ID siswa.
    /// - Returns: `IndexSet` berisi indeks absolut siswa yang cocok.
    @inline(__always)
    func indexSet(for ids: Set<Int64>) -> IndexSet {
        IndexSet(ids.compactMap { indexSiswa(for: $0) })
    }
}
