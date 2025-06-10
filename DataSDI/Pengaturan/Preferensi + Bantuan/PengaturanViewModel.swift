//
//  PengaturanViewModel.swift
//  Data SDI
//
//  Created by Ays on 28/05/25.
//

import Foundation
import SwiftUI

/// `PengaturanViewModel` adalah kelas yang mengelola pengaturan aplikasi.
/// Kelas ini menggunakan `ObservableObject` untuk memungkinkan tampilan SwiftUI memperbarui diri secara otomatis ketika ada perubahan pada pengaturan.
/// Kelas ini menyimpan berbagai pengaturan seperti saran mengetik, maksimal saran, dan lainnya.
/// Setiap pengaturan disimpan dalam `UserDefaults` untuk memastikan persistensi data antar sesi aplikasi.
/// Kelas ini juga menyediakan mekanisme untuk menampilkan pesan kepada pengguna ketika pengaturan diubah, menggunakan ``ReusableFunc/showProgressWindow(_:pesan:image:)-3momw``.
class PengaturanViewModel: ObservableObject {
    /// `@Published` untuk pengaturan prediksi ketik digunakan untuk memberi tahu tampilan SwiftUI bahwa nilai telah berubah,
    /// sehingga tampilan akan diperbarui secara otomatis.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    @Published var saranMengetik: Bool {
        didSet {
            if oldValue == saranMengetik { return } // Hindari pekerjaan ganda jika nilai tidak berubah
            UserDefaults.standard.set(saranMengetik, forKey: "showSuggestions")
            UserDefaults.standard.synchronize()
            let image = saranMengetik ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = saranMengetik ? "Prediksi ketik aktif" : "Prediksi ketik non-aktif"
            ReusableFunc.showProgressWindow(Int(1.5), pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan prediksi ketik di tabel digunakan untuk memberi tahu tampilan SwiftUI bahwa nilai telah berubah,
    /// sehingga tampilan akan diperbarui secara otomatis.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    @Published var saranSiswaDanKelasAktif: Bool {
        didSet {
            if oldValue == saranSiswaDanKelasAktif { return }
            UserDefaults.standard.set(saranSiswaDanKelasAktif, forKey: "showSuggestionsDiTabel")
            UserDefaults.standard.synchronize()
            let image = saranSiswaDanKelasAktif ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = saranSiswaDanKelasAktif ? "Prediksi ketik di tabel aktif" : "Prediksi ketik di tabel non-aktif"
            ReusableFunc.showProgressWindow(3, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan maksimal saran digunakan untuk memberi tahu tampilan SwiftUI bahwa nilai telah berubah,
    /// sehingga tampilan akan diperbarui secara otomatis.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    @Published var maksimalSaran: Int {
        didSet {
            if oldValue == maksimalSaran { return }
            UserDefaults.standard.set(maksimalSaran, forKey: "maksimalSaran")
            UserDefaults.standard.synchronize()
        }
    }

    /// `@Published` untuk pengaturan apakah nama guru baru akan dicatat ke Daftar Guru ketika ada guru baru yang baru ditambahkan
    //  dari ``KelasVC``.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    @Published var catatKeDaftarGuru: Bool {
        didSet {
            if oldValue == catatKeDaftarGuru { return }
            UserDefaults.standard.set(catatKeDaftarGuru, forKey: "tambahkanDaftarGuruBaru")
            UserDefaults.standard.synchronize()
            let image = catatKeDaftarGuru ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = catatKeDaftarGuru ? "Nama guru baru akan disimpan ke Daftar Guru (jika belum ada)" : "Nama guru baru tidak akan disimpan ke Daftar Guru"
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan apakah perubahan nama guru akan diterapkan ke semua mata pelajaran yang sama.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    /// Perhatikan bahwa ini akan memicu perubahan pada `timpaNamaGuru` jika diubah ke `false`.
    /// Ini memastikan bahwa jika `updateNamaGuru` diubah, maka `timpaNamaGuru` akan diatur ke `false`, yang akan memicu perubahan pada `timpaNamaGuru`.
    /// Ini memungkinkan pengguna untuk memilih apakah perubahan nama guru akan diterapkan ke semua mata pelajaran yang sama atau hanya pada baris data yang diubah.
    /// Jika `updateNamaGuru` diatur ke `true`, maka perubahan nama guru akan diterapkan ke semua mata pelajaran yang sama.
    /// Jika `updateNamaGuru` diatur ke `false`, maka perubahan nama guru hanya akan diterapkan pada baris data yang diubah.
    @Published var updateNamaGuru: Bool {
        didSet {
            // Perhatikan: oldValue di sini adalah nilai SEBELUM didSet ini dipanggil.
            // Jika Toggle di-flip, oldValue akan berbeda dari updateNamaGuru (nilai baru).
            // Tidak perlu if oldValue == updateNamaGuru di sini karena Toggle memastikan perubahan.

            UserDefaults.standard.set(updateNamaGuru, forKey: "updateNamaGuruDiMapelDanKelasSama")
            UserDefaults.standard.synchronize()

            if updateNamaGuru {
                ReusableFunc.showProgressWindow(5, pesan: "Perubahan nama guru selanjutnya berlaku ke semua mata pelajaran yang sama", image: ReusableFunc.menuOnStateImage!)
            } else {
                // Sebelum mengubah self.timpaNamaGuru, pastikan ini tidak menyebabkan loop jika ada dependensi balik.
                // Dalam kasus ini, timpaNamaGuru tidak mengubah updateNamaGuru, jadi aman.
                timpaNamaGuru = false // Ini akan memicu didSet dari timpaNamaGuru

                // Progress window untuk aksi updateNamaGuru itu sendiri
                ReusableFunc.showProgressWindow(5, pesan: "Perubahan nama guru selanjutnya hanya berlaku di baris data yang diubah", image: ReusableFunc.stopProgressImage!)
            }
        }
    }

    /// `@Published` untuk pengaturan apakah perubahan nama guru akan menggantikan semua nama guru pada mata pelajaran yang sama.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    /// Ini memungkinkan pengguna untuk memilih apakah perubahan nama guru akan menggantikan semua nama guru pada mata pelajaran yang sama atau hanya pada baris data yang diubah.
    /// Jika `timpaNamaGuru` diatur ke `true`, maka perubahan nama guru akan menggantikan semua nama guru pada mata pelajaran yang sama.
    /// Jika `timpaNamaGuru` diatur ke `false`, maka perubahan nama guru hanya akan diterapkan pada baris data yang diubah.
    @Published var timpaNamaGuru: Bool {
        didSet {
            if oldValue == timpaNamaGuru { return }
            UserDefaults.standard.set(timpaNamaGuru, forKey: "timpaNamaGuruSebelumnya")
            UserDefaults.standard.synchronize()

            let image = timpaNamaGuru ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = timpaNamaGuru ? "Perubahan nama guru selanjutnya akan mengganti semua nama guru pada mapel yang sama" : "Perubahan nama guru selanjutnya hanya berlaku untuk nama guru mapel yang sama"
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan apakah aplikasi akan memeriksa pembaruan secara otomatis saat dibuka.
    /// Nilai ini juga disimpan dalam `UserDefaults` untuk persistensi data.
    /// Jika `autoUpdateCheck` diatur ke `true`, maka aplikasi akan memeriksa pembaruan secara otomatis saat dibuka.
    @Published var autoUpdateCheck: Bool {
        didSet {
            if oldValue == autoUpdateCheck { return }
            UserDefaults.standard.set(autoUpdateCheck, forKey: "autoCheckUpdates")
            UserDefaults.standard.synchronize()
            let image = autoUpdateCheck ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = autoUpdateCheck ? "Aplikasi akan memeriksa pembaruan setelah dibuka." : "Aplikasi tidak akan memeriksa pembaruan secara otomatis."
            ReusableFunc.showProgressWindow(3, pesan: pesan, image: image!)
        }
    }

    init() {
        // Inisialisasi nilai awal dari UserDefaults
        // Penting: Inisialisasi ini harus dilakukan sebelum didSet dapat membandingkan oldValue
        _saranMengetik = Published(initialValue: UserDefaults.standard.object(forKey: "showSuggestions") as? Bool ?? true)
        _saranSiswaDanKelasAktif = Published(initialValue: UserDefaults.standard.object(forKey: "showSuggestionsDiTabel") as? Bool ?? true)
        _maksimalSaran = Published(initialValue: UserDefaults.standard.object(forKey: "maksimalSaran") as? Int ?? 10)
        _catatKeDaftarGuru = Published(initialValue: UserDefaults.standard.object(forKey: "tambahkanDaftarGuruBaru") as? Bool ?? true)
        _updateNamaGuru = Published(initialValue: UserDefaults.standard.object(forKey: "updateNamaGuruDiMapelDanKelasSama") as? Bool ?? true)
        _timpaNamaGuru = Published(initialValue: UserDefaults.standard.object(forKey: "timpaNamaGuruSebelumnya") as? Bool ?? true)
        _autoUpdateCheck = Published(initialValue: UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true)
    }
}
