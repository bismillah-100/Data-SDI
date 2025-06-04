//
//  PengaturanViewModel.swift
//  Data SDI
//
//  Created by Ays on 28/05/25.
//

import SwiftUI
import Foundation

class PengaturanViewModel: ObservableObject {
    
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
    
    @Published var maksimalSaran: Int {
        didSet {
            if oldValue == maksimalSaran { return }
            UserDefaults.standard.set(maksimalSaran, forKey: "maksimalSaran")
            UserDefaults.standard.synchronize()
        }
    }
    
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
                self.timpaNamaGuru = false // Ini akan memicu didSet dari timpaNamaGuru
                
                // Progress window untuk aksi updateNamaGuru itu sendiri
                ReusableFunc.showProgressWindow(5, pesan: "Perubahan nama guru selanjutnya hanya berlaku di baris data yang diubah", image: ReusableFunc.stopProgressImage!)
            }
        }
    }
    
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

