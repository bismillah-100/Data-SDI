//
//  String.swift
//  Data SDI
//
//  Created by Bismillah on 16/10/24.
//

import Cocoa

// MARK: - Extension untuk String

// Menambahkan fungsi untuk membersihkan ANSI escape codes dari string
// dan mengkapitalisasi huruf pertama dari setiap kata dalam string.
extension String {
    // MARK: - Extension untuk Membersihkan ANSI Escape Codes

    /// Menghapus kode escape ANSI dari string.
    /// Kode escape ANSI biasanya digunakan untuk mengubah warna teks di terminal.
    /// Contoh: "\u001B[31mHalo\u001B[0m" akan menjadi "Halo".
    /// Digunakan untuk mengkonversi nilai ANSI saat menjalankan skrip Python ketika mengunduh data dari terminal.
    /// - Returns: String tanpa kode escape ANSI.
    func removingANSIEscapeCodes() -> String {
        // Pola: \u001B diikuti oleh '[' dan angka/delimiter, kemudian diakhiri huruf
        let pattern = "\u{001B}\\[[0-9;]*[A-Za-z]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: utf16.count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
        }
        return self
    }

    /// Mengubah huruf pertama dari setiap kata menjadi huruf besar dan menghapus spasi berlebih.
    /// Jika string sudah dalam huruf besar, tidak ada perubahan yang dilakukan.
    ///
    /// **Contoh transformasi teks:**
    /// - Input: `bANDung`
    ///   - Output: `Bandung`
    /// - Input: `TRY-out`
    ///   - Output: `Try-Out`
    /// - Input: `e-BooK,PDF`
    ///   - Output: `E-Book, PDF`
    /// - Input: `jakarta,bandUNG`
    ///   - Output: `Jakarta, Bandung`
    /// - Input: `ASSALAMUA'ALAIKUM`
    ///   - Output: `ASSALAMUA'ALAIKUM`
    /// - Note: Fungsi ini juga menghapus spasi di awal dan akhir string.
    /// - Note: Jika string hanya berisi huruf besar, string akan dikembalikan tanpa perubahan.
    /// - Returns: String dengan huruf pertama dari setiap kata dikapitalisasi dan spasi berlebih dihapus.
    func capitalizedAndTrimmed() -> String {
        guard let defaultKapital = UserDefaults.standard.object(forKey: "kapitalkanPengetikan") as? Bool,
              defaultKapital == true
        else {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var result = trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tambahkan spasi setelah koma jika belum ada
        let commaFixPattern = #",(?=\S)"# // cari koma yang langsung diikuti karakter bukan spasi
        let commaRegex = try! NSRegularExpression(pattern: commaFixPattern)
        result = commaRegex.stringByReplacingMatches(
            in: result,
            range: NSRange(location: 0, length: result.utf16.count),
            withTemplate: ", "
        )

        // 2. Kapitalisasi setiap kata tanpa mengubah tanda baca atau spasi
        let wordPattern = #"[A-Za-z0-9]+(?:['’`][A-Za-z0-9]+)*"#
        let wordRegex = try! NSRegularExpression(pattern: wordPattern)
        let matches = wordRegex.matches(in: result, range: NSRange(location: 0, length: result.utf16.count))

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let word = result[range]

            // Jika ALL CAPS atau bukan huruf, biarkan
            if word.allSatisfy({ $0.isUppercase || !$0.isLetter }) {
                continue
            }

            let capitalized = word.prefix(1).uppercased() + word.dropFirst().lowercased()
            result.replaceSubrange(range, with: capitalized)
        }

        return result
    }
}

extension Array where Element: NSTextField {
    /// Mengkapitalisasi huruf pertama dari setiap kata dalam stringValue dari setiap NSTextField dalam array.
    /// Contoh: ["assalamualaikum ikhwan", "selamat pagi"] menjadi ["Assalamualaikum Ikhwan", "Selamat Pagi"].
    /// - Note: Fungsi ini juga menghapus spasi di awal dan akhir stringValue.
    func kapitalkanSemua() {
        forEach { $0.stringValue = $0.stringValue.capitalized }
    }

    /// Mengubah semua huruf dalam stringValue dari setiap NSTextField dalam array menjadi huruf besar.
    /// Contoh: ["assalamualaikum ikhwan", "selamat pagi"] menjadi ["ASSALAMUALAIKUM IKHWAN", "SELAMAT PAGI"].
    /// - Note: Fungsi ini juga menghapus spasi di awal dan akhir stringValue.
    func hurufBesarSemua() {
        forEach { $0.stringValue = $0.stringValue.uppercased() }
    }
}
