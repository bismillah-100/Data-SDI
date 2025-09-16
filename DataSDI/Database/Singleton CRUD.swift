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
    static var deletedStudentIDs: [Int64] = .init()

    /// Menyimpan kumpulan ID siswa di ``KelasVC`` yang dihapus sebelum disimpan.
    static var deletedKelasAndSiswaIDs: [[(nilaiID: Int64, siswaID: Int64)]] = []

    /// Menyimpan kumpulan data siswa di ``KelasVC`` yang dihapus untuk keperluan undo/redo.
    static var deletedDataArray: [[KelasModels]] = []

    /// Menyimpan kumpulan data table dan ID siswa di Database tabel Kelas1-6 untuk keperluan undo hapus di ``KelasVC``
    static var dataArray: [(index: Int, data: KelasModels)] = []

    /// Menyimpan kumpulan data table dan ID siswa di Database tabel Kelas1-6 untuk keperluan redo hapus di ``KelasVC``
    static var deletedNilaiID: [[Int64]] = []

    /// Menyimpan referensi data yang di `paste` di KelasVC untuk keperluan undo/redo.
    static var pastedData: [[KelasModels]] = []

    /// Menghandle penghapusan data ``KelasVC`` di ``SiswaViewController`` untuk keperluan undo/redo.
    static var undoStack: [String: [[KelasModels]]] = [:]

    /// Sudah diganti dengan  ``SingletonData/deletedSiswasArray``
    static var deletedSiswaArray: [ModelSiswa] = []

    /// Menyimpan data yang di `paste` atau ditambahkan di ``SiswaViewController`` yang kemudian diurungkan.
    static var redoPastedSiswaArray: [[ModelSiswa]] = .init()

    /// Menyimpan data yang baru ditambahakn  di ``SiswaViewController`` yang kemudian untuk keperluan undo.
    static var undoAddSiswaArray: [[ModelSiswa]] = .init()

    /// Menyimpan data siswa yang dihapus di ``SiswaViewController`` untuk keperluan undo/redo.
    static var deletedSiswasArray: [[ModelSiswa]] = .init()

    /// Membuat referensi jika menu item default di Menu Bar telah disimpan.
    static var savedMenuItemDefaults: Bool = false

    // MARK: - KELAS

    /// Properti yang menyimpan referensi nilaiID unik ketika menambahkan data.
    /// Digunakan untuk membatalkan penambahan data ketika view ``DataSDI/AddDetaildiKelas`` dibatalkan.
    static var insertedID: Set<Int64> = []

    // MARK: - GURU

    /// Menyimpan ID Guru yang dihapus sebelum disimpan.
    static var deletedGuru: Set<Int64> = []

    /// Menyimpan ID Guru yang baru ditambahkan untuk keperluan undo/redo.
    static var undoAddGuru: Set<Int64> = []

    // MARK: - TUGAS GURU

    static var deletedTugasGuru: Set<Int64> = []

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
    static let dateFormatter: DateFormatter = .init()
}
