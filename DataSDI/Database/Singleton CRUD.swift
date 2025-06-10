//
//  Singleton CRUD.swift
//  Data SDI
//
//  Created by Admin on 11/04/25.
//
import Foundation
import SQLite

/// `SingletonData` adalah kelas yang menyimpan data global yang digunakan di seluruh aplikasi.
/// Kelas ini berfungsi sebagai tempat penyimpanan data yang dapat diakses dari berbagai bagian aplikasi.
class SingletonData {
    /// Menyimpan kumpulan ID siswa yang dihapus sebelum disimpan.
    static var deletedStudentIDs = [Int64]()

    /// Menyimpan kumpulan ID siswa di ``KelasVC`` yang dihapus sebelum disimpan.
    static var deletedKelasAndSiswaIDs: [[(kelasID: Int64, siswaID: Int64)]] = []

    /// Menyimpan kumpulan data siswa di ``KelasVC`` yang dihapus untuk keperluan undo/redo.
    static var deletedDataArray: [(table: Table, data: [KelasModels])] = []

    /// Menyimpan kumpulan data siswa di ``KelasVC`` yang dihapus untuk keperluan undo/redo.
    static var deletedDataKelas: [(table: Table, data: [KelasModels])] = []

    /// Menyimpan kumpulan data table dan ID siswa di Database tabel Kelas1-6 untuk keperluan undo hapus di ``KelasVC``
    static var dataArray: [(index: Int, data: KelasModels)] = []

    /// Menyimpan kumpulan data table dan ID siswa di Database tabel Kelas1-6 untuk keperluan redo hapus di ``KelasVC``
    static var deletedKelasID: [(table: Table, kelasID: [Int64])] = []

    /// Menyimpan referensi data yang di `paste` di KelasVC untuk keperluan undo/redo.
    static var pastedData: [(table: Table, data: [KelasModels])] = []

    /// Menghandle penghapusan data ``KelasVC`` di ``SiswaViewController`` untuk keperluan undo/redo.
    static var undoStack: [String: [[KelasModels]]] = [:]

    /// Sudah diganti dengan  ``SingletonData/deletedSiswasArray``
    static var deletedSiswaArray: [ModelSiswa] = []

    /// Menyimpan data yang di `paste` atau ditambahkan di ``SiswaViewController`` yang kemudian diurungkan.
    static var redoPastedSiswaArray = [[ModelSiswa]]()

    /// Menyimpan data yang baru ditambahakn  di ``SiswaViewController`` yang kemudian untuk keperluan undo.
    static var undoAddSiswaArray = [[ModelSiswa]]()

    /// Menyimpan data siswa yang dihapus di ``SiswaViewController`` untuk keperluan undo/redo.
    static var deletedSiswasArray = [[ModelSiswa]]()

    /// Menyimpan ID Siswa yang kelas aktif nya berubah dari ``SiswaViewController`` untuk keperluan undo/redo.
    static var siswaNaikArray: [(siswaID: [Int64], kelasAwal: [String], kelasDikecualikan: [String])] = []

    /// Menyimpan ID Siswa yang kelas aktif nya berubah dari ``SiswaViewController`` untuk keperluan pengecekan konsistensi data di ``KelasVC``.
    static var siswaNaikId: [Int64] = []

    /// Membuat referensi jika menu item default di Menu Bar telah disimpan.
    static var savedMenuItemDefaults: Bool = false

    /// Menyimpan ID Guru yang dihapus sebelum disimpan.
    static var deletedGuru: Set<Int64> = []

    /// Menyimpan ID Guru yang baru ditambahkan untuk keperluan undo/redo.
    static var undoAddGuru: Set<Int64> = []

    /// Menyimpan status table kelas untuk mengetahui bahwa data tabel siap.
    ///
    /// Ini digunakan untuk menghandle jika data di table ``KelasVC`` belum dimuat saat menghapus data di ``SiswaViewController``.
    static var table1dimuat: Bool = false
    /// Lihat: ``SingletonData/table1dimuat``
    static var table2dimuat: Bool = false
    /// Lihat: ``SingletonData/table1dimuat``
    static var table3dimuat: Bool = false
    /// Lihat: ``SingletonData/table1dimuat``
    static var table4dimuat: Bool = false
    /// Lihat: ``SingletonData/table1dimuat``
    static var table5dimuat: Bool = false
    /// Lihat: ``SingletonData/table1dimuat``
    static var table6dimuat: Bool = false

    /// Menyimpan data ``JumlahSiswa`` di setiap bulan.
    static var monthliData: [MonthlyData] = []

    /// Target awal di Menu Bar yang disimpan sebelum dirubah untuk reset ulang.
    static var originalUndoTarget: AnyObject?
    /// Action awal di Menu Bar yang disimpan sebelum dirubah untuk reset ulang.
    static var originalUndoAction: Selector?
    /// Lihat: ``SingletonData/originalUndoTarget``
    static var originalRedoTarget: AnyObject?
    /// Lihat: ``SingletonData/originalUndoAction``
    static var originalRedoAction: Selector?
    /// Lihat: ``SingletonData/originalUndoTarget``
    static var originalCopyTarget: AnyObject?
    /// Lihat: ``SingletonData/originalUndoAction``
    static var originalCopyAction: Selector?
    /// Lihat: ``SingletonData/originalUndoTarget``
    static var originalPasteTarget: AnyObject?
    /// Lihat: ``SingletonData/originalUndoAction``
    static var originalPasteAction: Selector?
    /// Lihat: ``SingletonData/originalUndoTarget``
    static var originalDeleteTarget: AnyObject?
    /// Lihat: ``SingletonData/originalUndoAction``
    static var originalDeleteAction: Selector?
    /// Lihat: ``SingletonData/originalUndoTarget``
    static var originalNewTarget: AnyObject?
    /// Lihat: ``SingletonData/originalUndoAction``
    static var originalNewAction: Selector?

    // MARK: - INVENTORY

    /// Menyimpan kolom-koiom tabel ``InventoryView``.
    static var columns: [Column] = []
    /// Menyimpan ID Data yang dihapus di ``InventoryView`` untuk keperluan undo/redo.
    static var deletedInvID: Set<Int64> = []
    /// Menyimpan Kolom sekaligus datanya yang dihapus di ``InventoryView`` untuk keperluan undo/redo.
    static var deletedColumns: [(columnName: String, columnData: [(id: Int64, value: Any)])] = [] // Simpan
    /// Menyimpan Kolom yang baru ditambahkan  di ``InventoryView`` untuk keperluan undo/redo.
    static var undoAddColumns: [(columnName: String, columnData: [(id: Int64, value: Any)])] = [] //

    /// NSDateFormat. Digunakan di ``InventoryView``
    static let dateFormatter = DateFormatter()

    /// Mengembalikan objek `Table` yang merepresentasikan tabel database yang sesuai
    /// berdasarkan tipe kelas yang diberikan.
    ///
    /// Fungsi ini berfungsi sebagai pemetaan sederhana dari `TableType` ke nama tabel
    /// dalam database. Ini memastikan bahwa kode yang mengakses database selalu
    /// menggunakan nama tabel yang benar berdasarkan jenis kelas yang dituju.
    ///
    /// - Parameter tableType: Tipe kelas (`TableType`) yang ingin Anda dapatkan representasi tabel databasenya.
    /// - Returns: Sebuah instansi `Table` yang mewakili tabel database untuk `tableType` yang diberikan.
    ///            Mengembalikan `nil` jika `tableType` tidak sesuai dengan tabel yang dikenal (meskipun
    ///            dalam implementasi `switch` ini, semua kasus `TableType` ditangani, jadi `nil` tidak akan pernah dikembalikan).
    static func dbTable(forTableType tableType: TableType) -> Table? {
        switch tableType {
        case .kelas1:
            Table("kelas1") // Menginisialisasi objek Table dengan nama tabel "kelas1".
        case .kelas2:
            Table("kelas2") // Menginisialisasi objek Table dengan nama tabel "kelas2".
        case .kelas3:
            Table("kelas3") // Menginisialisasi objek Table dengan nama tabel "kelas3".
        case .kelas4:
            Table("kelas4") // Menginisialisasi objek Table dengan nama tabel "kelas4".
        case .kelas5:
            Table("kelas5") // Menginisialisasi objek Table dengan nama tabel "kelas5".
        case .kelas6:
            Table("kelas6") // Menginisialisasi objek Table dengan nama tabel "kelas6".
        }
    }
}
