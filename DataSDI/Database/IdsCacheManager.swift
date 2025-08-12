//
//  IdsCacheManager.swift
//  Data SDI
//
//  Created by MacBook on 19/07/25.
//

import Foundation

/// CacheManager yang mengelola ID Mapel dan Jabatan
/// untuk menghindari query berulang ke database.
actor IdsCacheManager {
    // MARK: – Shared instance

    static let shared: IdsCacheManager = .init()

    // MARK: – Caches

    /// [namaMapel: mapelID]
    private(set) var mapelCache: [String: Int64] = [:]
    /// [namaJabatan: jabatanID]
    private(set) var jabatanCache: [String: Int64] = [:]

    private let dbController: DatabaseController = .shared

    private init() {}

    // MARK: – Load awal (dipanggil di AppDelegate / SceneDelegate)

    /// Load semua cache dari database saat aplikasi dimulai.
    /// Ini akan mengisi `mapelCache` dan `jabatanCache` dengan data
    /// yang ada di database.
    func loadAllCaches() async {
        // 1. Fetch semua mapel dari DB
        let allMapel: [(String, Int64)] = await dbController.fetchAllMapel()
        mapelCache = Dictionary(uniqueKeysWithValues: allMapel)

        // 2. Fetch semua jabatan dari DB
        let allJabatan: [(String, Int64)] = await dbController.fetchAllJabatan()
        jabatanCache = Dictionary(uniqueKeysWithValues: allJabatan)
    }

    // MARK: – Helpers untuk men‐get/insert

    /// Mengambil ID Mapel berdasarkan nama Mapel.
    /// Jika ID tidak ditemukan, akan mencoba untuk memasukkan
    /// nama Mapel ke database dan mengembalikan ID yang baru.
    /// - Parameter namaMapel: Nama Mapel yang ingin dicari.
    /// - Returns: ID Mapel jika ditemukan atau berhasil dimasukkan, `nil`
    /// jika gagal.
    func mapelID(for namaMapel: String) async -> Int64? {
        if let id = mapelCache[namaMapel] {
            return id
        }
        // kalau belum ada, insert ke DB & cache
        if let newID = await dbController.insertOrGetMapelID(namaMapel: namaMapel) {
            mapelCache[namaMapel] = newID
            return newID
        }
        return nil
    }

    /*
     /// Mengambil nama Mapel berdasarkan ID Mapel.
     /// - Parameter id: ID Mapel yang ingin dicari.
     /// - Returns: Nama Mapel jika ditemukan, `nil` jika tidak ditemukan.
     // func namaMapel(for id: Int64) async -> String? {
     //     if let foundEntry = mapelCache.first(where: {$0.value == id}) {
     //         return foundEntry.key // Ambil nama mapel (key dari dictionary)
     //     }
     //     return nil // Kembalikan nil jika tidak ditemukan
     // }
     */

    /// Mengambil ID Jabatan berdasarkan nama Jabatan.
    /// Jika ID tidak ditemukan, akan mencoba untuk memasukkan
    /// nama Jabatan ke database dan mengembalikan ID yang baru.
    /// - Parameter namaJabatan: Nama Jabatan yang ingin dicari.
    /// - Returns: ID Jabatan jika ditemukan atau berhasil dimasukkan, `nil`
    /// jika gagal.
    func jabatanID(for namaJabatan: String) async -> Int64? {
        if let id = jabatanCache[namaJabatan] {
            return id
        }
        if let newID = await dbController.insertOrGetJabatanID(namaJabatan) {
            jabatanCache[namaJabatan] = newID
            return newID
        }
        return nil
    }

    /// Mengambil nama Jabatan berdasarkan ID Jabatan.
    /// Jika ID tidak ditemukan, akan mengembalikan `nil`.
    /// - Parameter id: Int64 ID Jabatan yang ingin dicari.
    /// - Returns: Nama Jabatan jika ditemukan, `nil` jika tidak ditemukan.
    /// - Note: Fungsi ini mencari di `jabatanCache` yang merupakan
    /// dictionary dengan key sebagai nama Jabatan dan value sebagai ID Jabatan.
    func namaJabatan(for id: Int64) async -> String? {
        if let foundEntry = jabatanCache.first(where: { $0.value == id }) {
            return foundEntry.key // Ambil nama jabatan (key dari dictionary)
        }
        return nil // Kembalikan nil jika tidak ditemukan
    }

    /// Fungsi untuk membersihkan ``mapelCache`` dan ``jabatanCache``.
    func clearUpCache() {
        mapelCache.removeAll()
        jabatanCache.removeAll()
    }
}
