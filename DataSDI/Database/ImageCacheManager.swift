//
//  ImageCacheManager.swift
//  Data SDI
//
//  Created by MacBook on 29/06/25.
//

import Foundation

/// Class yang bertugas mengelola cache foto siswa dan inventaris berdasarkan data yang telah dimuat dari database.
///
/// Class ini dibuat singleton dengan `private init()` dan menggunakan `NSCache` yang dibatasi penggunaannya ke 50MB.
/// * Fungsi di dalam ``DatabaseController`` dan ``DynamicTable`` secara langsung berinteraksi dengan class ini untuk
/// memperbarui dan menghapus cache setelah ada pembaruan di database.
/// * Semua cache yang disimpan akan dihapus setelah
/// menyimpan perubahan data secara global melalui ⌘S.
final class ImageCacheManager {
    
    /// Singleton ImageCacheManager
    static let shared = ImageCacheManager()
    
    /// NSCache untuk data foto siswa dan inventaris.
    /// Objek dibatasi hingga 50MB.
    let cache = NSCache<NSString, NSData>()

    /// private init ImageCacheManager
    private init() {
        // 50 MB limit untuk total cost cache
        cache.totalCostLimit = 50 * 1024 * 1024 // bytes
    }
    
    // MARK: - SISWA
    
    /// Menyimpan data gambar siswa ke dalam cache dengan key unik.
    /// - Parameters:
    ///   - data: Data gambar.
    ///   - id: ID siswa.
    func cacheSiswaImage(_ data: Data, for id: Int64) {
        let key = NSString(string: "s_\(id)")
        cache.setObject(NSData(data: data), forKey: key, cost: data.count)
    }

    /// Mengambil data gambar siswa dari cache jika ada.
    /// - Parameter id: ID siswa.
    /// - Returns: Data gambar atau nil jika tidak ada.
    func getCachedSiswa(for id: Int64) -> Data? {
        let key = NSString(string: "s_\(id)")
        if let nsData = cache.object(forKey: key) {
            return Data(referencing: nsData)
        }
        return nil
    }

    /// Menghapus cache gambar siswa tertentu.
    /// - Parameter id: ID siswa.
    func clearSiswaCache(for id: Int64) {
        let key = NSString(string: "s_\(id)")
        cache.removeObject(forKey: key)
    }

    // MARK: - INVENTARIS

    /// Menyimpan data gambar inventaris ke dalam cache dengan key unik.
    /// - Parameters:
    ///   - data: Data gambar.
    ///   - id: ID inventaris.
    func cacheInvImage(_ data: Data, for id: Int64) {
        let key = NSString(string: "i_\(id)")
        let nsData = NSData(data: data)
        let cost = data.count
        cache.setObject(nsData, forKey: key, cost: cost)
    }

    /// Mengambil data gambar inventaris dari cache jika ada.
    /// - Parameter id: ID inventaris.
    /// - Returns: Data gambar atau nil jika tidak ada.
    func getInvCachedImage(for id: Int64) -> Data? {
        let key = NSString(string: "i_\(id)")
        if let nsData = cache.object(forKey: key) {
            return Data(referencing: nsData)
        }
        return nil
    }

    /// Menghapus cache gambar inventaris tertentu.
    /// - Parameter id: ID inventaris.
    func clearInvCache(for id: Int64) {
        let key = NSString(string: "i_\(id)")
        cache.removeObject(forKey: key)
    }

    /// Menghapus semua cache gambar.
    func clear() {
        cache.removeAllObjects()
    }
}
