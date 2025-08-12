//
//  InventoryModel.swift
//  Data SDI
//
//  Created by MacBook on 09/08/25.
//

import Cocoa

extension InventoryView {
    /// Membandingkan dua set nilai berdasarkan tipe data kolom dan kriteria pengurutan sekunder.
    ///
    /// Fungsi ini digunakan untuk tujuan pengurutan, misalnya dalam `NSTableView` atau daftar lainnya.
    /// Perbandingan utama dilakukan berdasarkan `column` dan `value` yang disediakan.
    /// Jika nilai utama sama, perbandingan sekunder akan dilakukan berdasarkan kolom "Nama Barang" dan "Lokasi"
    /// untuk memastikan urutan yang konsisten.
    ///
    /// - Parameters:
    ///   - value1: Kamus `[String: Any]` yang berisi data untuk item pertama yang akan dibandingkan. Diharapkan berisi kunci "column" (tipe `Column`) dan "value" (nilai utama).
    ///   - value2: Kamus `[String: Any]` yang berisi data untuk item kedua yang akan dibandingkan. Diharapkan berisi kunci "column" (tipe `Column`) dan "value" (nilai utama).
    /// - Returns: `ComparisonResult` yang menunjukkan hubungan urutan antara `value1` dan `value2`.
    ///            Mengembalikan `.orderedSame` jika input tidak valid (misalnya, kunci yang diperlukan tidak ada).
    @objc static func compareValues(_ value1: [String: Any], _ value2: [String: Any]) -> ComparisonResult {
        guard let column = value1["column"] as? Column,
              let primaryValue1 = value1["value"],
              let primaryValue2 = value2["value"]
        else {
            return .orderedSame
        }

        // Fungsi helper untuk mendapatkan hasil perbandingan sekunder
        func getSecondaryComparison(_ item1: [String: Any], _ item2: [String: Any]) -> ComparisonResult {
            let secondaryColumns = ["Nama Barang", "Lokasi"]

            for secondaryColumn in secondaryColumns {
                if let col = SingletonData.columns.first(where: { $0.name == secondaryColumn }),
                   let val1 = item1[secondaryColumn],
                   let val2 = item2[secondaryColumn]
                {
                    let secondaryResult = compareValuesByType(col.type, val1, val2)
                    if secondaryResult != .orderedSame {
                        return secondaryResult
                    }
                }
            }
            return .orderedSame
        }

        // Fungsi helper untuk membandingkan nilai berdasarkan tipe
        func compareValuesByType(_ type: Any.Type, _ val1: Any, _ val2: Any) -> ComparisonResult {
            switch type {
            case is String.Type:
                return (val1 as? String ?? "").compare(val2 as? String ?? "")

            case is Int64.Type:
                let num1 = (val1 as? Int64) ?? 0
                let num2 = (val2 as? Int64) ?? 0
                return num1 < num2 ? .orderedAscending :
                    num1 > num2 ? .orderedDescending : .orderedSame

            case is Data.Type:
                let data1Size = (val1 as? Data)?.count ?? 0
                let data2Size = (val2 as? Data)?.count ?? 0
                let size1MB = Double(data1Size) / (1024 * 1024)
                let size2MB = Double(data2Size) / (1024 * 1024)

                return size1MB < size2MB ? .orderedAscending :
                    size1MB > size2MB ? .orderedDescending : .orderedSame

            default:
                return String(describing: val1).compare(String(describing: val2))
            }
        }

        // Bandingkan nilai utama
        let primaryResult = compareValuesByType(column.type, primaryValue1, primaryValue2)

        // Jika nilai utama sama, gunakan secondary sorting
        if primaryResult == .orderedSame,
           let item1 = value1["item"] as? [String: Any],
           let item2 = value2["item"] as? [String: Any]
        {
            return getSecondaryComparison(item1, item2)
        }

        return primaryResult
    }
}

// MARK: - EKSTENSI PENGURUTAN INDEKS

extension [[String: Any]] {
    /// Menentukan indeks yang tepat untuk menyisipkan sebuah elemen baru ke dalam koleksi yang sudah terurut.
    /// Fungsi ini mencari posisi di mana `element` harus disisipkan agar koleksi tetap terurut
    /// sesuai dengan `sortDescriptor` yang diberikan.
    ///
    /// - Parameters:
    ///   - element: Elemen (data) yang akan disisipkan. `Element` diasumsikan sebagai alias untuk `[String: Any]`.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan (kunci dan arah).
    ///
    /// - Returns: `Index` (Int) di mana `element` harus disisipkan. Jika `element` harus ditempatkan
    ///            di akhir koleksi, `endIndex` akan dikembalikan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        // Menggunakan `firstIndex` untuk mencari elemen pertama yang memenuhi kondisi.
        // Jika tidak ada elemen yang memenuhi, `nil` akan dikembalikan, dan operator `??` akan
        // mengembalikan `endIndex`, artinya elemen baru harus ditambahkan di akhir.
        firstIndex { item in
            // Memastikan `sortDescriptor` memiliki kunci (nama kolom) yang valid.
            guard let key = sortDescriptor.key else { return false }

            // Membungkus nilai dari `item` (elemen yang ada di koleksi) dan `element` (elemen baru)
            // dalam dictionary yang diformat khusus. Ini diperlukan karena `ReusableFunc.compareValues`
            // mengharapkan format input tertentu yang mencakup kolom, nilai, dan seluruh item.
            let value1 = [
                "column": SingletonData.columns.first(where: { $0.name == key })!, // Informasi kolom.
                "value": item[key], // Nilai dari `item` pada kunci kolom.
                "item": item, // Seluruh data `item`.
            ]
            let value2 = [
                "column": SingletonData.columns.first(where: { $0.name == key })!, // Informasi kolom.
                "value": element[key], // Nilai dari `element` pada kunci kolom.
                "item": element, // Seluruh data `element`.
            ]

            // Membandingkan `value1` (item yang ada) dengan `value2` (elemen yang akan disisipkan)
            // menggunakan fungsi `ReusableFunc.compareValues`. Fungsi ini akan mengembalikan
            // `ComparisonResult` (.orderedAscending, .orderedSame, atau .orderedDescending).
            let result = InventoryView.compareValues(value1 as [String: Any], value2 as [String: Any])

            // Logika untuk menentukan apakah `element` harus disisipkan *sebelum* `item` saat ini.
            // Jika pengurutan `ascending` (naik):
            //   - Kita mencari item pertama yang `result`nya `.orderedDescending` (artinya `element` lebih kecil dari `item`).
            // Jika pengurutan `descending` (turun):
            //   - Kita mencari item pertama yang `result`nya `.orderedAscending` (artinya `element` lebih besar dari `item`).
            return sortDescriptor.ascending ?
                result == .orderedDescending : // Untuk ascending, cari yang lebih besar dari element
                result == .orderedAscending // Untuk descending, cari yang lebih kecil dari element
        } ?? endIndex // Jika tidak ada item yang memenuhi kondisi, sisipkan di akhir.
    }
}
