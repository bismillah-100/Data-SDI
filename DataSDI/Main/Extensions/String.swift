//
//  Extensions.swift
//  Data SDI
//
//  Created by Bismillah on 16/10/24.
//

import Cocoa

extension String {
    // MARK: - Extension untuk Membersihkan ANSI Escape Codes
    func removingANSIEscapeCodes() -> String {
        // Pola: \u001B diikuti oleh '[' dan angka/delimiter, kemudian diakhiri huruf
        let pattern = "\u{001B}\\[[0-9;]*[A-Za-z]"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: self.utf16.count)
                return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
            }
        return self
    }
    
    func capitalizeFirstLetterOfWords() -> String {
        let words = components(separatedBy: " ")
        let capitalizedWords = words.map { $0.prefix(1).capitalized + $0.dropFirst() }
        return capitalizedWords.joined(separator: " ")
    }
    func capitalizedAndTrimmed() -> String {
        // self.capitalized.trimmingCharacters(in: .whitespaces)
        
        // Periksa apakah semua huruf dalam string adalah huruf besar
        if self.allSatisfy({ $0.isUppercase }) {
            return self // Kembalikan string tanpa modifikasi
        }
        
        // Jika tidak, ubah huruf pertama dari setiap kata menjadi huruf besar
        let words = components(separatedBy: " ")
        let capitalizedWords = words.map {
            $0.prefix(1).capitalized + $0.dropFirst()
        }
        return capitalizedWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    //func cleanForSuggestion() -> String {
        // Hapus karakter khusus dan whitespace berlebih
        //return self.trimmingCharacters(in: .whitespacesAndNewlines)
            //.components(separatedBy: .whitespacesAndNewlines)
            //.filter { !$0.isEmpty }
            //.joined(separator: " ")
    //}
}

extension Array where Element: NSTextField {
    func kapitalkanSemua() {
        self.forEach { $0.stringValue = $0.stringValue.capitalized }
    }

    func hurufBesarSemua() {
        self.forEach { $0.stringValue = $0.stringValue.uppercased() }
    }
}
