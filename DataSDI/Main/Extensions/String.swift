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

    /// Menghapus karakter khusus dari string.
    /// Karakter khusus yang dihapus termasuk: tanda baca, simbol, dan karakter non-alfanumerik.
    /// - Returns: String tanpa karakter khusus.
    func capitalizeFirstLetterOfWords() -> String {
        let words = components(separatedBy: " ")
        let capitalizedWords = words.map { $0.prefix(1).capitalized + $0.dropFirst() }
        return capitalizedWords.joined(separator: " ")
    }

    /// Mengubah huruf pertama dari setiap kata menjadi huruf besar dan menghapus spasi berlebih.
    /// Jika string sudah dalam huruf besar, tidak ada perubahan yang dilakukan.
    /// Contoh: "assalamualaikum ikhwan" menjadi "Assalamualaikum Ikhwan", "ASSALAMUALAIKUM IKHWAN" tetap "ASSALAMUALAIKUM IKHWAN".
    /// - Note: Fungsi ini juga menghapus spasi di awal dan akhir string.
    /// - Note: Jika string hanya berisi huruf besar, string akan dikembalikan tanpa perubahan.
    /// - Returns: String dengan huruf pertama dari setiap kata dikapitalisasi dan spasi berlebih dihapus.
    func capitalizedAndTrimmed() -> String {
        // self.capitalized.trimmingCharacters(in: .whitespaces)

        // Periksa apakah semua huruf dalam string adalah huruf besar
        if allSatisfy(\.isUppercase) {
            return self // Kembalikan string tanpa modifikasi
        }

        // Jika tidak, ubah huruf pertama dari setiap kata menjadi huruf besar
        let words = components(separatedBy: " ")
        let capitalizedWords = words.map {
            $0.prefix(1).capitalized + $0.dropFirst()
        }
        return capitalizedWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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
