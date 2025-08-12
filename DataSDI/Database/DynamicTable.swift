//
//  DynamicTable.swift
//  Data SDI
//
//  Created by Bismillah on 21/10/24.
//

import Foundation
import SQLite

/// `DynamicTable` adalah kelas *singleton* yang bertanggung jawab untuk mengelola skema
/// tabel `main_table` di *database* SQLite secara dinamis.
///
/// Kelas ini bertugas untuk membaca struktur kolom dari `main_table` saat inisialisasi
/// dan menyimpannya ke dalam `SingletonData.columns`, memungkinkan penanganan data
/// yang fleksibel dan adaptif berdasarkan skema *database* aktual.
final class DynamicTable {
    // MARK: - Properti

    /// Instans koneksi *database* SQLite yang dibagikan dari `DB_Controller`.
    let db = DatabaseController.shared.db

    /// Instans *singleton* dari `DynamicTable`, memastikan hanya ada satu titik akses.
    static let shared: DynamicTable = .init()

    /// Representasi objek tabel `main_table` dari *database*.
    let mainTable: Table = .init("main_table")

    // MARK: - Inisialisasi

    /// Inisialisasi privat untuk `DynamicTable` yang mengaktifkan pola *singleton*.
    ///
    /// Saat diinisialisasi, ini memanggil `setupDatabase()` secara asinkron untuk
    /// menyiapkan struktur kolom dari *database*.
    private init() {
        Task {
            await setupDatabase()
        }
    }

    // MARK: - Metode Database

    /// Menyiapkan skema *database* dengan mengambil detail kolom dari `main_table`.
    ///
    /// Fungsi ini terhubung ke *database*, mengambil semua kolom dari tabel `main_table`,
    /// dan kemudian mengisi `SingletonData.columns` dengan objek `Column` yang sesuai
    /// berdasarkan tipe data kolom (*TEXT*, *INTEGER*, *BLOB*).
    /// Kesalahan apa pun selama proses *fetch* kolom akan dicetak di konsol dalam mode `DEBUG`.
    func setupDatabase() async {
        do {
            // Memastikan koneksi database tersedia.
            guard let db else {
                #if DEBUG
                    print("Koneksi database error")
                #endif
                return
            }

            // Mengambil detail semua kolom dari `main_table` di database.
            let dbColumns = try db.getColumnDetails(in: "main_table")

            // Mengiterasi melalui setiap kolom yang diambil dan menambahkannya ke `SingletonData.columns`
            // dengan tipe Swift yang sesuai.
            for column in dbColumns {
                switch column.type {
                case .TEXT:
                    SingletonData.columns.append(Column(name: column.name, type: String.self))
                case .INTEGER:
                    SingletonData.columns.append(Column(name: column.name, type: Int64.self))
                case .BLOB:
                    SingletonData.columns.append(Column(name: column.name, type: Data.self)) // Mendukung kolom bertipe Data
                default:
                    // Mengabaikan tipe kolom yang tidak didukung atau tidak relevan.
                    break
                }
            }

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    // MARK: - Fungsi untuk menambah kolom baru secara dinamis

    /// Menambahkan kolom baru ke `main_table` di *database* dan memperbarui struktur kolom internal.
    ///
    /// Fungsi ini mendukung penambahan kolom bertipe `String` atau `Int64`.
    /// Setelah kolom ditambahkan ke *database*, ia juga ditambahkan ke `SingletonData.columns`
    /// untuk menjaga konsistensi representasi skema dalam aplikasi.
    ///
    /// - Parameters:
    ///   - name: Nama kolom baru yang akan ditambahkan.
    ///   - type: Tipe data kolom baru (`String.self` atau `Int64.self`).
    func addColumn(name: String, type: Any.Type) async {
        do {
            // Menambah kolom baru ke database
            if type == String.self {
                try db?.run(mainTable.addColumn(Expression<String?>(name)))
            } else if type == Int64.self {
                try db?.run(mainTable.addColumn(Expression<Int64?>(name)))
            }

            // Menyimpan kolom baru ke array columns dan UserDefaults
            SingletonData.columns.append(Column(name: name, type: type))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Mengganti nama kolom yang ada dalam tabel *database* dan memperbarui struktur kolom internal.
    ///
    /// Fungsi ini menggunakan `SchemaChanger` dari library SQLite.swift untuk melakukan
    /// operasi ganti nama kolom pada tabel yang ditentukan. Setelah berhasil diganti nama
    /// di *database*, ia juga memperbarui nama kolom di `SingletonData.columns`.
    ///
    /// - Parameters:
    ///   - namaTabel: Nama tabel di mana kolom akan diganti namanya.
    ///   - kolomLama: Nama kolom yang saat ini ada.
    ///   - kolomBaru: Nama baru untuk kolom.
    /// - Throws: `Error` jika terjadi masalah saat mengakses *database* atau saat mengganti nama kolom.
    func renameColumn(_ namaTabel: String, kolomLama: String, kolomBaru: String) async throws {
        guard let db, let index = SingletonData.columns.firstIndex(where: { $0.name == kolomLama }) else {
            return
        }
        let schemaChanger = SchemaChanger(connection: db)
        do {
            try schemaChanger.alter(table: namaTabel) { table in
                table.rename(column: kolomLama, to: kolomBaru)
            }
            // Memperbarui nama kolom di array internal `SingletonData.columns`.
            SingletonData.columns[index].rename(kolomBaru)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus kolom dari tabel *database* dan memperbarui struktur kolom internal.
    ///
    /// Fungsi ini menggunakan `SchemaChanger` dari library SQLite.swift untuk melakukan
    /// operasi penghapusan kolom pada tabel yang ditentukan. Setelah kolom berhasil dihapus
    /// dari *database*, ia juga dihapus dari `SingletonData.columns`.
    ///
    /// - Parameters:
    ///   - tableName: Nama tabel tempat kolom akan dihapus.
    ///   - columnName: Nama kolom yang akan dihapus.
    func deleteColumn(tableName: String, columnName: String) async {
        guard let db else {
            #if DEBUG
                print("Koneksi database error")
            #endif
            return
        }

        do {
            // Menggunakan `SchemaChanger` untuk menghapus kolom.
            let schemaChanger = SchemaChanger(connection: db)
            try schemaChanger.alter(table: tableName) { table in
                table.drop(column: columnName)
            }
            #if DEBUG
                print("Kolom '\(columnName)' berhasil dihapus dari tabel '\(tableName)'.")
            #endif
            // Menghapus kolom dari array `SingletonData.columns` internal.
            SingletonData.columns.removeAll(where: { $0.name == columnName })
        } catch {
            #if DEBUG
            // Menangani kesalahan dengan mencetaknya ke konsol.
                print(error.localizedDescription)
            #endif
        }
    }

    // MARK: - CRUD Kolom MainTable

    /// Memasukkan data baru ke dalam `main_table` secara dinamis.
    ///
    /// Fungsi ini menerima kamus `newData` di mana kunci adalah nama kolom (`String`)
    /// dan nilai adalah data yang akan dimasukkan (`Any`). Ini secara otomatis
    /// menentukan tipe data (String, Int64, atau Data) dan membangun pernyataan
    /// `INSERT` yang sesuai untuk *database*.
    ///
    /// - Parameter newData: Kamus `[String: Any]` yang berisi nama kolom sebagai kunci
    ///                      dan nilai yang akan dimasukkan sebagai nilai.
    ///
    /// - Returns: `Int64` opsional yang merepresentasikan ID baris yang baru dimasukkan
    ///            (`lastInsertRowid`), atau `nil` jika operasi gagal.
    func insertData(_ newData: [String: Any]) async -> Int64? {
        do {
            // Membuat statement insert dinamis
            let insert = mainTable.insert(
                newData.map { key, value in
                    switch value {
                    case let stringValue as String:
                        Expression<String>(key) <- stringValue
                    case let intValue as Int64:
                        Expression<Int64>(key) <- intValue
                    case let dataValue as Data:
                        Expression<Data>(key) <- dataValue
                    default:
                        nil // Atau Anda bisa menambahkan penanganan kesalahan di sini
                    }
                }.compactMap { $0 } // Menghilangkan nil dari hasil
            )

            // Jalankan perintah insert
            try db?.run(insert)

            // Mengembalikan id dari baris yang baru ditambahkan
            return db?.lastInsertRowid
        } catch {
            return nil
        }
    }

    /// Memuat semua data dari `main_table` secara asinkron dan mengembalikannya sebagai array kamus.
    ///
    /// Fungsi ini dirancang untuk mengambil semua baris dari `main_table`, mengabaikan baris yang
    /// ID-nya ada di `SingletonData.deletedInvID`. Untuk setiap baris yang diambil, ia membuat
    /// kamus `[String: Any]` yang berisi data kolom, dengan cerdas mengekstrak nilai berdasarkan
    /// tipe kolom yang disimpan di `SingletonData.columns`. Proses pembentukan kamus ini
    /// dilakukan secara konkurensi menggunakan `TaskGroup` untuk kinerja yang lebih baik.
    ///
    /// - Returns: Sebuah array `[[String: Any]]` di mana setiap kamus merepresentasikan satu baris
    ///            data dari `main_table`, tidak termasuk baris atau kolom yang ditandai untuk dihapus.
    ///            Mengembalikan array kosong jika terjadi kesalahan koneksi *database* atau *fetch*.
    ///
    /// - Catatan:
    ///   - Bergantung pada `db` yang merupakan koneksi *database* yang valid (dari `DB_Controller.shared.db`).
    ///   - Menggunakan `SingletonData.deletedInvID` untuk menyaring baris yang dihapus secara logis.
    ///   - Menggunakan `SingletonData.columns` untuk mengetahui nama dan tipe kolom yang diharapkan.
    ///   - Menggunakan `SingletonData.deletedColumns` untuk menyaring kolom yang dihapus secara logis.
    ///   - Menangani tipe data `String`, `Int64`, dan `Data` secara dinamis.
    ///   - Kesalahan saat *fetch* akan dicetak ke konsol dalam mode `DEBUG`.
    func loadData() async -> [[String: Any]] {
        var resultData: [[String: Any]] = []

        guard let db else {
            #if DEBUG
                print("Koneksi database error")
            #endif
            return resultData
        }

        do {
            let rows = try db.prepare(mainTable)

            await withTaskGroup(of: [String: Any]?.self) { group in
                for row in rows {
                    let rowID = row[Expression<Int64>("id")]
                    if SingletonData.deletedInvID.contains(rowID) {
                        continue
                    }

                    group.addTask {
                        var rowData: [String: Any] = [:]
                        for column in SingletonData.columns {
                            if SingletonData.deletedColumns.contains(where: { $0.columnName.lowercased() == column.name.lowercased() }) {
                                continue
                            }

                            // Ambil value sesuai tipe
                            switch column.type {
                            case is String.Type:
                                rowData[column.name] = row[Expression<String?>(column.name)]
                            case is Int64.Type:
                                rowData[column.name] = row[Expression<Int64?>(column.name)]
                            case is Data.Type:
                                continue
                            /*
                             rowData[column.name] = row[Expression<Data?>(column.name)]
                             mendukung kolom bertipe Data namun tidak digunakan untuk menghemat RAM ketika database menyimpan banyak foto.
                             */
                            default:
                                break // Jika tipe tidak dikenali
                            }
                        }
                        return rowData
                    }
                }

                for await rowDict in group {
                    if let dict = rowDict {
                        resultData.append(dict)
                    }
                }
            }

        } catch {
            #if DEBUG
                print("❌ \(error.localizedDescription)")
            #endif
        }

        return resultData
    }

    /// Memperbarui nilai kolom tertentu untuk baris yang cocok dengan ID yang diberikan di `main_table`.
    ///
    /// Fungsi ini membuat kueri pembaruan (UPDATE) untuk satu baris berdasarkan `ID` yang disediakan
    /// dan mengatur nilai kolom yang ditentukan (`column`) ke `value` baru.
    ///
    /// - Parameters:
    ///   - ID: `Int64` yang mewakili ID baris yang akan diperbarui.
    ///   - column: `String` yang mewakili nama kolom yang akan diperbarui.
    ///   - value: `String` nilai baru yang akan ditetapkan ke kolom.
    func updateDatabase(ID: Int64, column: String, value: String) async {
        do {
            let record = mainTable.filter(Expression<Int64>("id") == ID)
            try db?.run(record.update(Expression<String>(column) <- value))
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus baris dari `main_table` berdasarkan ID yang diberikan.
    ///
    /// Fungsi ini membuat kueri penghapusan (DELETE) untuk satu baris berdasarkan `id` yang disediakan.
    ///
    /// - Parameter id: `Int64` yang mewakili ID baris yang akan dihapus.
    func deleteData(withID id: Int64) async {
        do {
            let delete = mainTable.filter(Expression<Int64>("id") == id)
            try db?.run(delete.delete())

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menyimpan atau memperbarui gambar (dalam format `Data`) untuk baris tertentu di `main_table`.
    ///
    /// Fungsi ini memperbarui kolom "Foto" untuk baris yang cocok dengan `id` yang diberikan
    /// dengan `Data` gambar yang disediakan.
    /// * Gambar yang ditambahkan disimpan sebagai cache di ``ImageCacheManager``.
    ///
    /// - Parameters:
    ///   - id: `Int64` yang mewakili ID baris yang gambar akan disimpan.
    ///   - foto: Objek `Data` yang mewakili gambar yang akan disimpan.
    func saveImageToDatabase(_ id: Int64, foto: Data) async {
        do {
            // Update foto dalam database
            let updateQuery = mainTable.filter(Expression<Int64>("id") == id)
            try db?.run(updateQuery.update(Expression<Data>("Foto") <- foto))
            ImageCacheManager.shared.cacheInvImage(foto, for: id)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menghapus gambar yang terkait dengan baris tertentu di `main_table` dengan mengatur kolom "Foto" menjadi kosong.
    ///
    /// Fungsi ini memperbarui kolom "Foto" untuk baris yang cocok dengan `id` yang diberikan
    /// dengan objek `Data()` kosong, secara efektif menghapus gambar.
    /// * Gambar yang telah disimpan sebagai cache di ``ImageCacheManager`` juga akan dihapus.
    ///
    /// - Parameter id: `Int64` yang mewakili ID baris yang gambarnya akan dihapus.
    func hapusImage(_ id: Int64) async {
        do {
            // Update foto dalam database
            let updateQuery = mainTable.filter(Expression<Int64>("id") == id)
            try db?.run(updateQuery.update(Expression<Data>("Foto") <- Data()))
            ImageCacheManager.shared.clearInvCache(for: id)
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Mengambil data gambar (dalam format `Data`) dari kolom "Foto" untuk baris tertentu di `main_table`
    /// secara asinkron.
    ///
    /// Fungsi ini membuat kueri untuk baris yang cocok dengan `id` yang diberikan,
    /// mengambil nilai dari kolom "Foto", dan mengonversinya dari `Blob` ke `Data`.
    /// * Gambar yang telah dikueri disimpan sebagai cache di ``ImageCacheManager``.
    /// * Note: Fungsi ini mengembalikan gambar dari ``ImageCacheManager`` jika sebelumnya gambar telah dicache.
    ///
    /// - Parameter id: `Int64` yang mewakili ID baris yang gambarnya akan diambil.
    /// - Returns: Objek `Data` yang berisi data gambar, atau `Data()` kosong jika gambar tidak ditemukan
    ///            atau terjadi kesalahan.
    func getImage(_ id: Int64) async -> Data {
        // 🔑 Cek di cache dulu
        if let cachedData = ImageCacheManager.shared.getInvCachedImage(for: id) {
            return cachedData
        }

        do {
            return try await DatabaseManager.shared.pool.read { conn in
                let query = mainTable.filter(Expression<Int64>("id") == id)
                if let rowValue = try conn.pluck(query) {
                    let fotoBlob: Blob = try rowValue.get(Expression<Blob>("Foto"))
                    let data = Data(fotoBlob.bytes)
                    if !data.isEmpty {
                        ImageCacheManager.shared.cacheInvImage(data, for: id)
                    }
                    return data
                }
                return Data()
            }
        } catch {
            #if DEBUG
                print("❌ getImage error: \(error)")
            #endif
            return Data()
        }
    }

    /// Versi sinkron dari ``getImage(_:)``.
    func getImageSync(_ id: Int64) -> Data {
        // 🔑 Cek di cache dulu
        if let cachedData = ImageCacheManager.shared.getInvCachedImage(for: id) {
            return cachedData
        }

        var fotoSiswa = Data()

        do {
            // Memfilter data dengan id yang sesuai
            let query = mainTable.filter(Expression<Int64>("id") == id)

            // Ambil satu row dari hasil query
            if let rowValue = try db?.pluck(query) {
                // Ambil foto dari kolom yang sesuai
                let fotoBlob: Blob = try rowValue.get(Expression<Blob>("Foto"))
                // Konversi Blob ke Data
                let data = Data(fotoBlob.bytes)

                fotoSiswa = data
                if !data.isEmpty {
                    ImageCacheManager.shared.cacheInvImage(data, for: id)
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        return fotoSiswa
    }
}
