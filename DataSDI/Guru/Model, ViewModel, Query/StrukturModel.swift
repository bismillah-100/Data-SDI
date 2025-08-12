//
//  StrukturModel.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

import Foundation

/// Kamus untuk menampilkan struktur guru dalam
/// mode hierarki.
class StrukturGuruDictionary {
    /// Kamus induk yang berfungsi sebagai key untuk struktur.
    let struktural: String
    /// Menyimpan daftar guru yang terkait dengan struktur ini.
    var guruList: [GuruModel]

    init(struktural: String, guruList: [GuruModel] = []) {
        self.struktural = struktural
        self.guruList = guruList
    }
}

/// Event yang terjadi pada struktur guru.
/// Digunakan untuk mengelola perubahan pada struktur guru,
/// seperti penambahan, penghapusan, pemindahan, atau pembaruan guru.
/// Event ini digunakan untuk combine dan mengelola perubahan pada struktur guru secara reaktif.
enum StrukturEvent {
    /// Event yang terjadi ketika struktur guru diperbarui.
    /// - Parameter guru: Daftar guru yang diperbarui.
    case updated([GuruModel])
    /// Event yang terjadi ketika guru dihapus dari struktur.
    /// - Parameter guru: Daftar guru yang dihapus.
    case deleted([GuruModel])
    /// Event yang terjadi ketika guru dipindahkan dalam struktur.
    /// - Parameter oldGuru: Guru yang dipindahkan dari posisi lama.
    /// - Parameter updatedGuru: Guru yang diperbarui posisinya.
    case moved(oldGuru: GuruModel, updatedGuru: GuruModel)
    /// Event yang terjadi ketika guru baru ditambahkan ke struktur.
    /// - Parameter guru: Guru yang baru ditambahkan.
    case inserted(GuruModel)
}
