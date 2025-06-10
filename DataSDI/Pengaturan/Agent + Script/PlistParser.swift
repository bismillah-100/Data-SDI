//
//  PlistParser.swift
//  Data SDI
//
//  Created by Ays on 04/05/25.
//

import Foundation

/// `SharedPlist` adalah sebuah kelas singleton yang dirancang untuk mengelola pembacaan, penulisan, dan penghapusan data ke/dari file Property List (plist) kustom.
///
/// Kelas ini menyediakan antarmuka yang sederhana untuk menyimpan dan mengambil berbagai tipe data (Boolean, Integer, String, dll.) dalam format plist yang persisten.
/// File plist akan disimpan di dalam direktori `Application Support` aplikasi, dengan nama `sdi-update.plist` di dalam sub-direktori "Data SDI".
/// Ini memastikan bahwa data aplikasi tersimpan dengan aman dan dapat diakses setiap kali aplikasi berjalan.
class SharedPlist {
    static let shared = SharedPlist()

    /// Nama file plist yang akan digunakan untuk menyimpan pengaturan.
    let fileName = "sdi-update.plist"
    /// URL lengkap ke file plist yang digunakan untuk menyimpan pengaturan.
    let fileURL: URL

    /// Dictionary yang menyimpan pengaturan yang dimuat dari file plist.
    var settings: [String: Any] = [:]

    /// Description
    /// Setup awal untuk Class ini
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dirURL = appSupport.appendingPathComponent("Data SDI", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        fileURL = dirURL.appendingPathComponent(fileName)
        load()
    }

    /// Muat file plist dan pengaturan di dalamnya
    func load() {
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            settings = dict
        }
    }

    /// Simpan ke penyimpanan permanen
    func save() {
        let dict = NSDictionary(dictionary: settings)
        dict.write(to: fileURL, atomically: true)
    }

    // MARK: - Public Access

    /// Fungsi untuk menulis/memperbarui key di file plist yang sudah diatur di private init
    /// - Parameters:
    ///   - value: Nilai yang akan disimpan untuk kunci yang diberikan. Ini bisa berupa tipe data apa pun yang didukung (misalnya, String, Int, Bool, Array, Dictionary).
    ///   - key: Kunci (string) yang terkait dengan nilai yang akan disimpan. Kunci ini akan digunakan untuk mengakses nilai nanti.
    func set(_ value: Any?, forKey key: String) {
        settings[key] = value
        save()
    }

    /// Fungsi untuk membaca nilai Boolean (YES/NO/TRUE/FALSE) dari file plist.
    /// - Parameters:
    ///   - key: Kunci (String) dari nilai Boolean yang ingin dibaca dari file plist.
    ///   - reload: Jika `true`, data dari file plist akan dimuat ulang sebelum mencoba membaca nilai. Nilai default-nya adalah `false`.
    /// - Returns: Nilai Boolean (`true` atau `false`) jika kunci ditemukan dan nilainya adalah Boolean. Mengembalikan `nil` jika kunci tidak ditemukan atau nilainya bukan tipe Boolean.
    func bool(forKey key: String, reload: Bool = false) -> Bool? {
        if reload { load() }
        return settings[key] as? Bool
    }

    /// Fungsi untuk membaca nilai Integer dari file plist.
    /// - Parameter key: Kunci (String) dari nilai Integer yang ingin dibaca dari file plist.
    /// - Returns: Nilai Integer jika kunci ditemukan dan nilainya adalah Integer. Mengembalikan `nil` jika kunci tidak ditemukan atau nilainya bukan tipe Integer.
    func integer(forKey key: String) -> Int? {
        settings[key] as? Int
    }

    /// Fungsi untuk menghapus nilai yang terkait dengan kunci tertentu dari file plist.
    /// Setelah nilai dihapus, perubahan akan disimpan ke file plist.
    /// - Parameter key: Kunci (String) dari nilai yang ingin dihapus.
    func remove(key: String) {
        settings.removeValue(forKey: key)
        save()
    }
}
