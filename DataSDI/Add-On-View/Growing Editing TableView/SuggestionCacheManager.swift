//
//  SuggestionCacheManager.swift
//  Data SDI
//
//  Created by Ays on 18/05/25.
//

import Foundation

/// Manajer cache untuk menyimpan dan mengambil prediksi ketik (suggestions) secara efisien.
actor SuggestionCacheManager {
    /// Singleton instance untuk mengakses cache secara global.
    /// Menggunakan actor untuk memastikan akses yang aman dan konkuren.
    /// Actor ini akan mengelola cache secara aman dalam konteks akses konkuren,
    /// sehingga kita tidak perlu khawatir tentang kondisi bal.
    static let shared = SuggestionCacheManager()
    
    /// Inisialisasi privat untuk memastikan hanya ada satu instance (singleton).
    private init() {} // Membuatnya singleton

    /// Struktur two-level cache:
    /// Key utama: nama kolom (String)
    /// Key kedua: filter/prefix dalam lowercase (String)
    /// Nilainya: array tuple (full dan display)
    private var suggestionsCache: [String: [String: [String]]] = [:]

    /// Mengambil cache untuk suatu kolom dan filter tertentu secara asinkron dan konkuren.
    /// - Parameter column: Nama kolom yang ingin diakses.
    /// - Parameter filter: Filter yang digunakan untuk mencari saran.
    /// - Returns: Array dari saran yang sesuai dengan filter, atau nil jika tidak ada.
    /// - Note: Menggunakan TaskGroup untuk memproses pencarian secara konkuren.
    ///         Hasilnya akan `didedup` dan diurutkan sebelum dikembalikan.
    ///         Cache akan diakses secara aman untuk menghindari kondisi bal.
    ///         Pencarian dilakukan dengan memecah cache menjadi chunk yang lebih kecil untuk efisiensi.
    func getCache(for column: String, filter: String) async -> [String]? {
        let lowerFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // --- Langkah 1: Akses cache secara aman (blocking sebentar) ---
        // Kunci untuk membaca cacheForColumn agar aman dari modifikasi konkuren
        guard let cacheForColumn = suggestionsCache[column] else {
            return nil
        }

        // --- Langkah 2: Proses pencarian secara konkuren menggunakan TaskGroup ---
        var mergedResult: [String] = []

        // Kita akan membagi `cacheForColumn` (dictionary) menjadi array dari tuple
        // agar mudah dipecah ke dalam chunk untuk TaskGroup.
        let cacheEntries = Array(cacheForColumn)
        let numEntries = cacheEntries.count

        // Tentukan jumlah task yang wajar berdasarkan jumlah inti prosesor
        // atau jumlah item yang akan diproses
        let numberOfTasks = min(numEntries, ProcessInfo.processInfo.activeProcessorCount * 2)
        // Pastikan setidaknya ada 1 task jika numEntries > 0
        guard numberOfTasks > 0 else { return nil }

        let chunkSize = max(1, numEntries / numberOfTasks) // Pastikan chunkSize minimal 1

        await withTaskGroup(of: [String].self) { group in
            for i in 0 ..< numberOfTasks {
                let startIndex = i * chunkSize
                let endIndex = (i == numberOfTasks - 1) ? numEntries : min(startIndex + chunkSize, numEntries)

                guard startIndex < endIndex else { continue }

                let chunk = Array(cacheEntries[startIndex ..< endIndex])

                // Menambahkan task untuk memproses setiap chunk
                group.addTask {
                    var localChunkSuggestions: [String] = []
                    for (cacheKey, suggestions) in chunk {
                        if cacheKey.contains(lowerFilter) {
                            localChunkSuggestions.append(contentsOf: suggestions)
                        }
                    }
                    return localChunkSuggestions
                }
            }

            // Kumpulkan hasil dari semua task
            for await chunkResult in group {
                mergedResult.append(contentsOf: chunkResult)
            }
        }

        // --- Langkah 3: Deduplikasi akhir dan pengurutan (jika diperlukan) ---
        let uniqueResult = Array(Set(mergedResult)).sorted() // Menggunakan Set untuk deduplikasi yang efisien

        return uniqueResult.isEmpty ? nil : uniqueResult
    }

    /// Menambahkan saran baru ke cache untuk kolom dan filter tertentu.
    /// - Parameter column: Nama kolom yang ingin diupdate.
    /// - Parameter filter: Filter yang digunakan untuk mencari saran.
    /// - Parameter newSuggestions: Array dari saran baru yang akan ditambahkan.
    /// - Note: Fungsi ini akan memecah filter menjadi token, dan menambahkan saran baru ke cache
    ///         dengan mempertimbangkan token sebelumnya. Jika cache untuk key ini kosong atau nil, akan diabaikan.
    ///         Fungsi ini juga akan menghapus bagian awal dari saran baru sesuai dengan panjang token sebelumnya.
    ///         Pastikan untuk memanggil fungsi ini hanya jika ada saran baru atau filter yang tidak kosong.
    ///         Fungsi ini akan mengupdate cache dengan saran baru yang unik.
    ///         Jika cache untuk kolom dan filter ini belum ada, akan dibuat baru.
    ///         Fungsi ini akan mengupdate cache dengan saran baru yang unik.
    func appendToCache(
        for column: String,
        filter: String,
        newSuggestions: [String]
    ) {
        guard !filter.isEmpty || !newSuggestions.isEmpty, (suggestionsCache[column]?.isEmpty) == nil else { return }
        // Trim dan lowercased filter input
        let lowerFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if suggestionsCache[column] == nil {
            suggestionsCache[column] = [:]
        }

        // Pecah filter menggunakan spasi dan "|" sehingga misalnya "testing tes teks|simple"
        // menghasilkan ["testing", "tes", "teks", "simple"]
        let tokens = lowerFilter.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "|")))
            .filter { !$0.isEmpty }

        // Untuk setiap token, buat cache key dengan format:
        // - Indeks 0: key = "|<token0>"
        // - Indeks >0: key = "<gabungan token sebelumnya>|<token saat ini>"
        for i in 0 ..< tokens.count {
            let leftPart = i > 0 ? tokens[..<i].joined(separator: " ") : ""
            let currentToken = tokens[i]
            let key = leftPart.isEmpty ? "|\(currentToken)" : "\(leftPart)|\(currentToken)"

            // Jika cache untuk key ini kosong atau nil, langsung skip (continue)
            guard var existing = suggestionsCache[column]?[key], !existing.isEmpty else {
                continue
            }

            // Jika ada leftPart, kita perlu memotong suggestion sesuai dengan panjang leftPart + spasi.
            let dropCount = leftPart.isEmpty ? 0 : (leftPart.count + 1)
            let trimmedSuggestions: [String] = newSuggestions.map { (suggestion: String) -> String in
                if dropCount > 0, suggestion.count > dropCount {
                    return String(suggestion.dropFirst(dropCount))
                } else {
                    return suggestion
                }
            }

            // Perbarui cache: masukkan suggestion yang unik
            let uniqueNew = trimmedSuggestions.filter { !existing.contains($0) }
            existing.append(contentsOf: uniqueNew)
            suggestionsCache[column]?[key] = existing
        }
    }

    /// Menyimpan cache untuk kolom dan filter tertentu.
    /// - Parameter column: Nama kolom yang ingin disimpan.
    /// - Parameter filter: Filter yang digunakan untuk mencari saran.
    /// - Parameter suggestions: Array dari saran yang akan disimpan.
    /// - Note: Fungsi ini akan menyimpan saran baru ke cache untuk kolom dan filter tertentu.
    ///         Jika cache untuk kolom dan filter ini belum ada, akan dibuat baru.
    ///         Fungsi ini akan mengupdate cache dengan saran baru yang unik.
    func storeCache(
        for column: String,
        filter: String,
        suggestions: [String]
    ) {
        if suggestionsCache[column] == nil {
            suggestionsCache[column] = [:]
        }

        suggestionsCache[column]?[filter.lowercased()] = suggestions
    }

    /// Membersihkan cache seluruhnya (misalnya, saat ada perubahan data besar)
    func clearCache() {
        suggestionsCache.removeAll()
    }
}
