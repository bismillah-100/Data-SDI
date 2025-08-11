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
    @Published
    var ketikKapital: Bool {
        didSet {
            if oldValue == ketikKapital { return }
            UserDefaults.standard.set(ketikKapital, forKey: "kapitalkanPengetikan")
            UserDefaults.standard.synchronize()
            let image = ketikKapital ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = ketikKapital ? "Kalimat akan dikapitalkan secara otomatis setelah mengetik" : "Kalimat tidak akan dikapitalkan secara otomatis"
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

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

            let image = saranSiswaDanKelasAktif ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = saranSiswaDanKelasAktif ? "Prediksi ketik di tabel aktif" : "Prediksi ketik di tabel non-aktif"
            ReusableFunc.showProgressWindow(3, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan integrasi `UndoManager` antar ``DataSDI/SiswaViewController`` dan ``DataSDI/KelasVC``.
    @Published var integrateUndoSiswaKelas: Bool {
        didSet {
            if oldValue == integrateUndoSiswaKelas { return }
            UserDefaults.standard.setValue(integrateUndoSiswaKelas, forKey: "IntegrasiUndoSiswaKelas")
            let image = integrateUndoSiswaKelas ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = integrateUndoSiswaKelas ? "Undo Manajer Kelas Aktif dan Siswa terintegrasi" : "Undo Manajer Kelas Aktif dan Siswa independen"
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
        }
    }

    /// `@Published` untuk pengaturan pembersihan tabel kelas tanpa relasi.
    @Published var bersihkanTabelKelas: Bool {
        didSet {
            if oldValue == bersihkanTabelKelas { return }
            UserDefaults.standard.setValue(bersihkanTabelKelas, forKey: "bersihkanTabelKelas")

            let image = bersihkanTabelKelas ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = bersihkanTabelKelas ? "Kelas tanpa relasi akan dibersihkan" : "Kelas yang tidak digunakan tidak akan dibersihkan"
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan pembersihan tabel siswa kelas tanpa relas.
    @Published var bersihkanTabelSiswaKelas: Bool {
        didSet {
            if oldValue == bersihkanTabelSiswaKelas { return }
            UserDefaults.standard.setValue(bersihkanTabelSiswaKelas, forKey: "bersihkanTabelSiswaKelas")

            let image = bersihkanTabelSiswaKelas ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = bersihkanTabelSiswaKelas ? "Data nilai tanpa relasi akan dibersihkan" : "Data nilai tidak akan dibersihkan meskipun siswa dihapus."
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan pembersihan tabel mapel tanpa relas.
    @Published var bersihkanTabelMapel: Bool {
        didSet {
            if oldValue == bersihkanTabelMapel { return }
            UserDefaults.standard.setValue(bersihkanTabelMapel, forKey: "bersihkanTabelMapel")

            let image = bersihkanTabelMapel ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = bersihkanTabelMapel ? "Mata pelajaran tanpa relasi akan dibersihkan" : "Mata pelajaran tanpa relasi tidak akan dibersihkan."
            ReusableFunc.showProgressWindow(5, pesan: pesan, image: image!)
        }
    }

    /// `@Published` untuk pengaturan pembersihan tabel penugasan guru tanpa relas.
    @Published var bersihkanTabelTugas: Bool {
        didSet {
            if oldValue == bersihkanTabelTugas { return }
            UserDefaults.standard.setValue(bersihkanTabelTugas, forKey: "bersihkanTabelTugas")

            let image = bersihkanTabelTugas ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = bersihkanTabelTugas ? "Tugas guru tanpa relasi data kelas akan dibersihkan" : "Tugas guru tanpa relasi tidak akan dibersihkan"
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

            let image = autoUpdateCheck ? ReusableFunc.menuOnStateImage : ReusableFunc.stopProgressImage
            let pesan = autoUpdateCheck ? "Aplikasi akan memeriksa pembaruan setelah dibuka" : "Aplikasi tidak akan memeriksa pembaruan secara otomatis"
            ReusableFunc.showProgressWindow(3, pesan: pesan, image: image!)
        }
    }

    init() {
        // Inisialisasi nilai awal dari UserDefaults
        // Penting: Inisialisasi ini harus dilakukan sebelum didSet dapat membandingkan oldValue
        _ketikKapital = Published(initialValue: UserDefaults.standard.object(forKey: "kapitalkanPengetikan") as? Bool ?? true)
        _saranMengetik = Published(initialValue: UserDefaults.standard.object(forKey: "showSuggestions") as? Bool ?? true)
        _saranSiswaDanKelasAktif = Published(initialValue: UserDefaults.standard.object(forKey: "showSuggestionsDiTabel") as? Bool ?? true)
        _maksimalSaran = Published(initialValue: UserDefaults.standard.object(forKey: "maksimalSaran") as? Int ?? 10)
        _integrateUndoSiswaKelas = Published(initialValue: UserDefaults.standard.object(forKey: "IntegrasiUndoSiswaKelas") as? Bool ?? true)
        _bersihkanTabelKelas = Published(initialValue: UserDefaults.standard.object(forKey: "bersihkanTabelKelas") as? Bool ?? true)
        _bersihkanTabelSiswaKelas = Published(initialValue: UserDefaults.standard.object(forKey: "bersihkanTabelSiswaKelas") as? Bool ?? true)
        _bersihkanTabelMapel = Published(initialValue: UserDefaults.standard.object(forKey: "bersihkanTabelMapel") as? Bool ?? true)
        _bersihkanTabelTugas = Published(initialValue: UserDefaults.standard.object(forKey: "bersihkanTabelTugas") as? Bool ?? true)
        _autoUpdateCheck = Published(initialValue: UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true)
    }
}
