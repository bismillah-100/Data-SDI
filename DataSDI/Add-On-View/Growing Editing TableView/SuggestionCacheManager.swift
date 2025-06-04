//
//  SuggestionCacheManager.swift
//  Data SDI
//
//  Created by Ays on 18/05/25.
//

import Foundation

actor SuggestionCacheManager {
    
    static let shared = SuggestionCacheManager()
    private init() {} // Membuatnya singleton

    // Struktur two-level cache:
    // Key utama: nama kolom (String)
    // Key kedua: filter/prefix dalam lowercase (String)
    // Nilainya: array tuple (full dan display)
    private var suggestionsCache: [String: [String: [String]]] = [:]
        
    /// Mengambil cache untuk suatu kolom dan filter tertentu secara asinkron dan konkuren.
    func getCache(for column: String, filter: String) async -> [String]? {
        let lowerFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // --- Langkah 1: Akses cache secara aman (blocking sebentar) ---
        // Kunci untuk membaca cacheForColumn agar aman dari modifikasi konkuren
        guard let cacheForColumn = self.suggestionsCache[column] else {
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
            for i in 0..<numberOfTasks {
                let startIndex = i * chunkSize
                let endIndex = (i == numberOfTasks - 1) ? numEntries : min(startIndex + chunkSize, numEntries)

                guard startIndex < endIndex else { continue }

                let chunk = Array(cacheEntries[startIndex..<endIndex])

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

    func appendToCache(
        for column: String,
        filter: String,
        newSuggestions: [String]
    ) {
        guard !filter.isEmpty || !newSuggestions.isEmpty, ((self.suggestionsCache[column]?.isEmpty) == nil) else {return}
        // Trim dan lowercased filter input
        let lowerFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if self.suggestionsCache[column] == nil {
            self.suggestionsCache[column] = [:]
        }
        
        // Pecah filter menggunakan spasi dan "|" sehingga misalnya "testing tes teks|simple"
        // menghasilkan ["testing", "tes", "teks", "simple"]
        let tokens = lowerFilter.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "|")))
            .filter { !$0.isEmpty }
        
        // Untuk setiap token, buat cache key dengan format:
        // - Indeks 0: key = "|<token0>"
        // - Indeks >0: key = "<gabungan token sebelumnya>|<token saat ini>"
        for i in 0..<tokens.count {
            let leftPart = i > 0 ? tokens[..<i].joined(separator: " ") : ""
            let currentToken = tokens[i]
            let key = leftPart.isEmpty ? "|\(currentToken)" : "\(leftPart)|\(currentToken)"
            
            // Jika cache untuk key ini kosong atau nil, langsung skip (continue)
            guard var existing = self.suggestionsCache[column]?[key], !existing.isEmpty else {
                continue
            }
            
            // Jika ada leftPart, kita perlu memotong suggestion sesuai dengan panjang leftPart + spasi.
            let dropCount = leftPart.isEmpty ? 0 : (leftPart.count + 1)
            let trimmedSuggestions: [String] = newSuggestions.map { (suggestion: String) -> String in
                if dropCount > 0 && suggestion.count > dropCount {
                    return String(suggestion.dropFirst(dropCount))
                } else {
                    return suggestion
                }
            }
            
            // Perbarui cache: masukkan suggestion yang unik
            let uniqueNew = trimmedSuggestions.filter { !existing.contains($0) }
            existing.append(contentsOf: uniqueNew)
            self.suggestionsCache[column]?[key] = existing
        }
    }


    /// Menyimpan cache untuk kolom dan filter tertentu
    func storeCache(
        for column: String,
        filter: String,
        suggestions: [String]
    ) {
        if self.suggestionsCache[column] == nil {
            self.suggestionsCache[column] = [:]
        }
        
        self.suggestionsCache[column]?[filter.lowercased()] = suggestions
    }

    /// Membersihkan cache seluruhnya (misalnya, saat ada perubahan data besar)
    func clearCache() {
        self.suggestionsCache.removeAll()
    }
}
