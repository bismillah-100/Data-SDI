//
//  Flat Siswa.swift
//  Data SDI
//
//  Created by MacBook on 19/09/25.
//

import Foundation

/// `PlainSiswaData`
///
/// Mengimplementasikan protokol `SiswaDataSource` untuk menyimpan dan mengelola data siswa
/// dalam bentuk **array datar (flat)**.
///
/// Digunakan untuk tampilan daftar sederhana di mana semua siswa berada dalam satu list.
/// Menyediakan fungsi untuk:
/// - Mengambil data siswa dalam bentuk array datar.
/// - Mencari, memfilter, menambah, menghapus, dan memindahkan siswa.
/// - Mengelola pembaruan data di memori dan sinkronisasi dengan database.
/// - Mendukung operasi undo/redo.
/// - Mengurutkan data berdasarkan comparator yang diberikan.
class PlainSiswaData: SiswaDataSource {
    /// Array ``ModelSiswa`` yang didapatkan dari database.
    var data: [ModelSiswa] = []

    /// Mengembalikan jumlah total baris (siswa) di dalam ``data``.
    var numberOfRows: Int { data.count }

    /// Mengambil seluruh data siswa dalam bentuk array datar.
    ///
    /// - Returns: Array ``ModelSiswa`` yang merepresentasikan seluruh data saat ini.
    func currentFlatData() -> [ModelSiswa] {
        data
    }

    /// Mencari siswa berdasarkan kata kunci tertentu.
    ///
    /// - Parameter filter: String kata kunci pencarian.
    /// - Note: Proses pencarian dilakukan secara asinkron melalui ``DatabaseController/searchSiswa(query:)``.
    func cariSiswa(_ filter: String) async {
        data = await DatabaseController.shared.searchSiswa(query: filter)
    }

    /// Memfilter siswa yang berstatus berhenti.
    ///
    /// - Parameters:
    ///   - isBerhentiHidden: Jika `true`, hanya mengembalikan indeks siswa yang berstatus berhenti dari data saat ini.
    ///     Jika `false`, data akan diambil ulang dari database, diurutkan, lalu mengembalikan indeks siswa yang berstatus berhenti.
    ///   - comparator: Closure pembanding untuk mengurutkan data.
    /// - Returns: Array `Int` berisi indeks siswa yang berstatus berhenti.
    func filterSiswaBerhenti(
        _ isBerhentiHidden: Bool,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    ) async -> [Int] {
        if isBerhentiHidden {
            return data.enumerated().compactMap { index, siswa in
                siswa.status == .berhenti ? index : nil
            }
        } else {
            await fetchSiswa()
            sort(by: comparator)
            return data.enumerated().compactMap { index, siswa in
                siswa.status == .berhenti ? index : nil
            }
        }
    }

    /// Memfilter siswa yang berstatus lulus.
    ///
    /// - Parameters:
    ///   - tampilkanLulus: Jika `false`, hanya mengembalikan indeks siswa yang berstatus lulus dari data saat ini.
    ///     Jika `true`, data akan diambil ulang dari database, diurutkan, lalu mengembalikan indeks siswa yang berstatus lulus.
    ///   - comparator: Closure pembanding untuk mengurutkan data.
    /// - Returns: Array `Int` berisi indeks siswa yang berstatus lulus.
    func filterSiswaLulus(
        _ tampilkanLulus: Bool,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    ) async -> [Int] {
        if !tampilkanLulus {
            return data.enumerated().compactMap { index, siswa in
                siswa.status == .lulus ? index : nil
            }
        } else {
            await fetchSiswa()
            sort(by: comparator)
            let indices = data.enumerated().compactMap { index, siswa in
                siswa.status == .lulus ? index : nil
            }

            // Print semua indeks sebelum mengembalikan
            return indices
        }
    }

    /// Mengembalikan data siswa ke nilai sebelumnya (undo).
    ///
    /// - Note: Fungsi ini menjalankan pembaruan model dan database melalui
    /// ``updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``.
    ///
    /// - Parameter originalModel: ``DataAsli`` sebelum perubahan, digunakan untuk mengembalikan nilai.
    func undoAction(originalModel: DataAsli) {
        let (id, column, oldValue, _) = DataAsli.extract(originalModel: originalModel)

        guard let rowIndexToUpdate = indexSiswa(for: id) else {
            updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: nil, newValue: oldValue)
            UndoActionNotification.sendNotif(id, columnIdentifier: column)
            return
        }
        updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndexToUpdate, newValue: oldValue)
    }

    /// Mengulangi kembali perubahan data siswa (redo).
    ///
    /// - Note: Fungsi ini menjalankan pembaruan model dan database melalui
    /// ``updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``.
    ///
    /// - Parameter originalModel: Data asli setelah perubahan, digunakan untuk mengulang nilai yang telah diubah.
    func redoAction(originalModel: DataAsli) {
        let (id, column, _, newValue) = DataAsli.extract(originalModel: originalModel)
        // Cari indeks di model berdasarkan ID
        guard let rowIndexToUpdate = indexSiswa(for: id) else {
            updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: nil, newValue: newValue)
            UndoActionNotification.sendNotif(id, columnIdentifier: column)
            return
        }
        updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndexToUpdate, newValue: newValue)
    }

    /// Mengambil ulang seluruh data siswa dari database.
    ///
    /// - Note: Proses dilakukan secara asinkron ``DatabaseController/getSiswa(_:)`` dengan parameter
    /// group `false`.
    @inline(__always)
    func fetchSiswa() async {
        data = await DatabaseController.shared.getSiswa(false)
    }

    /// Mengambil objek siswa berdasarkan indeks baris.
    ///
    /// - Parameter row: Indeks baris siswa.
    /// - Returns: Objek `ModelSiswa` jika ditemukan, atau `nil` jika indeks tidak valid.
    @inline(__always)
    func siswa(at row: Int) -> ModelSiswa? {
        data.indices.contains(row) ? data[row] : nil
    }

    /// Mengambil objek siswa berdasarkan ID unik.
    ///
    /// - Parameter id: ID siswa.
    /// - Returns: Objek `ModelSiswa` jika ditemukan, atau `nil` jika tidak ada yang cocok.
    @inline(__always)
    func siswa(for id: Int64) -> ModelSiswa? {
        data.first { $0.id == id }
    }

    /// Mengambil indeks siswa berdasarkan ID unik.
    ///
    /// - Parameter id: ID siswa.
    /// - Returns: Indeks siswa jika ditemukan, atau `nil` jika tidak ada yang cocok.
    @inline(__always)
    func indexSiswa(for id: Int64) -> Int? {
        data.firstIndex { $0.id == id }
    }

    /// Memperbarui data siswa yang sudah ada.
    ///
    /// - Parameter siswa: Objek `ModelSiswa` yang akan diperbarui.
    /// - Returns: Indeks siswa yang diperbarui, atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func update(siswa: ModelSiswa) -> Int? {
        guard let index = indexSiswa(for: siswa.id),
              data.indices.contains(index)
        else { return nil }

        data[index] = siswa

        return index
    }

    /// Menghapus siswa berdasarkan indeks baris.
    ///
    /// - Parameter index: Indeks baris siswa yang akan dihapus.
    @inline(__always)
    func remove(at index: Int) {
        guard data.indices.contains(index) else { return }
        data.remove(at: index)
    }

    /// Menghapus siswa berdasarkan objek siswa.
    ///
    /// - Parameter siswa: Objek `ModelSiswa` yang akan dihapus.
    /// - Returns: Tuple berisi indeks siswa yang dihapus dan `UpdateData` untuk pembaruan UI, atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func removeSiswa(_ siswa: ModelSiswa) -> (index: Int, update: UpdateData)? {
        guard let index = indexSiswa(for: siswa.id) else { print("siswaNotFound"); return nil }
        remove(at: index)
        return (index, .remove(index: index))
    }

    /// Menyisipkan siswa baru ke dalam data dengan posisi terurut.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan dimasukkan.
    ///   - comparator: Closure pembanding untuk menentukan posisi penyisipan.
    /// - Returns: Indeks posisi siswa yang baru dimasukkan.
    @discardableResult @inline(__always)
    func insert(_ siswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int {
        // Cari posisi insert berdasarkan comparator (untuk sorted insert)
        let insertIndex = data.insertionIndex(for: siswa, using: comparator)
        data.insert(siswa, at: insertIndex)
        return insertIndex
    }

    /// Memindahkan siswa ke posisi yang benar berdasarkan comparator.
    ///
    /// - Parameters:
    ///   - siswa: Objek `ModelSiswa` yang akan dipindahkan.
    ///   - comparator: Closure pembanding untuk menentukan posisi.
    ///   - columnIndex: Indeks kolom opsional untuk pembaruan UI.
    /// - Returns: `UpdateData` untuk pembaruan UI, atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func relocateSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        columnIndex: Int?
    ) -> UpdateData? {
        // Remove dulu, lalu insert ulang berdasarkan comparator
        if let oldIndex = indexSiswa(for: siswa.id) {
            remove(at: oldIndex)
            let newIndex = insert(siswa, comparator: comparator)
            if oldIndex == newIndex {
                return columnIndex != nil ?
                    .moveRowAndReloadColumn(from: oldIndex, to: newIndex, columnIndex: columnIndex!) :
                    .reload(index: newIndex, selectRow: true, extendSelection: true)
            } else {
                return columnIndex != nil ?
                    .moveRowAndReloadColumn(from: oldIndex, to: newIndex, columnIndex: columnIndex!) :
                    .move(from: oldIndex, to: newIndex)
            }
        } else {
            let newIndex = insert(siswa, comparator: comparator)
            return .insert(index: newIndex, selectRow: true, extendSelection: true)
        }
    }

    /// Memperbarui model siswa di memori dan di database.
    ///
    /// - Parameters:
    ///   - id: ID siswa.
    ///   - columnIdentifier: Kolom yang akan diperbarui.
    ///   - rowIndex: Indeks baris siswa (opsional).
    ///   - newValue: Nilai baru yang akan disimpan.
    ///
    /// - Note: Fungsi ini mengirim notifikasi ``undoAction(originalModel:)`` dengan parameter
    /// `id`, `columnIndentifier`, dan objek ``ModelSiswa``. Menjalankan ``siswa(for:)`` untuk
    /// mendapatkan objek ``ModelSiswa`` sesuai `id` nya.
    func updateModelAndDatabase(id: Int64, columnIdentifier: SiswaColumn, rowIndex: Int?, newValue: String) {
        if let kolomDB = columnIdentifier.kolomDB {
            DatabaseController.shared.updateKolomSiswa(id, kolom: kolomDB, data: newValue)
        }

        guard let siswa = siswa(for: id) else {
            if let persistentSiswa = DatabaseController.shared.getKelasSiswa(id) {
                NotifSiswaDiedit.sendNotif(persistentSiswa)
            }
            return
        }

        siswa.setValue(for: columnIdentifier, newValue: newValue)

        UndoActionNotification.sendNotif(
            id, columnIdentifier: columnIdentifier, rowIndex: rowIndex,
            newValue: newValue, isGrouped: true,
            updatedSiswa: siswa
        )

        NotifSiswaDiedit.sendNotif(siswa)
    }

    /// Mengambil ID, nama, dan foto siswa berdasarkan indeks baris.
    ///
    /// - Parameter row: Indeks baris siswa.
    /// - Returns: Tuple `(id, nama, foto)` atau `nil` jika siswa tidak ditemukan.
    @inline(__always)
    func getIdNamaFoto(row: Int) -> (id: Int64, nama: String, foto: Data)? {
        guard let siswa = siswa(at: row) else { return nil }
        let foto = DatabaseController.shared.bacaFotoSiswa(idValue: siswa.id)
        return (siswa.id, siswa.nama, foto)
    }

    /// Mengurutkan data siswa berdasarkan comparator.
    ///
    /// - Parameter comparator: Closure pembanding untuk pengurutan.
    @inline(__always)
    func sort(by comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) {
        data.sort(by: comparator)
    }
    
    /// Fungsi ini membersihkan ``data``.
    func clearData() {
        data.removeAll()
    }
}
