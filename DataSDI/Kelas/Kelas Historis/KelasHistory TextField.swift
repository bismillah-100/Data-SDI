//
//  KelasHistory TextField.swift
//  Data SDI
//
//  Created by MacBook on 30/07/25.
//

import Cocoa

extension KelasHistoryVC: NSTextFieldDelegate {
    /// Fungsi callback yang dipanggil ketika pengeditan teks pada text field selesai.
    ///
    /// Fungsi ini memverifikasi dan memproses perubahan input tahun ajaran pada kedua text field.
    /// Hanya akan memproses input jika:
    /// - Input hanya berisi angka
    /// - Kedua text field tidak kosong
    ///
    /// - Parameter obj: Notification yang berisi informasi tentang text field yang selesai diedit
    ///
    /// Alur kerja:
    /// 1. Mengambil nilai terkini dari kedua text field tahun ajaran
    /// 2. Memverifikasi bahwa input valid dan tidak kosong
    /// 3. Memeriksa perubahan pada masing-masing text field:
    ///    - Jika tidak ada perubahan, fungsi akan return
    ///    - Jika ada perubahan, nilai sebelumnya akan diperbarui
    /// 4. Memanggil fungsi muatUlang() jika terjadi perubahan
    func controlTextDidEndEditing(_ obj: Notification) {
        let currentTahunAjaran1 = tahunAjaranTextField1.stringValue
        let currentTahunAjaran2 = tahunAjaranTextField2.stringValue

        guard let textField = obj.object as? NSTextField,
              textField.stringValue.allSatisfy({ $0.isNumber }),
              !currentTahunAjaran1.isEmpty,
              !currentTahunAjaran2.isEmpty
        else { return }

        // Periksa apakah teks berubah untuk textField1
        if textField === tahunAjaranTextField1 {
            if currentTahunAjaran1 == previousTahunAjaran1 {
                // Tidak ada perubahan, keluar dari fungsi
                #if DEBUG
                    print("Tahun ajaran 1 tidak berubah.")
                #endif
                return
            } else {
                // Ada perubahan, perbarui nilai sebelumnya
                previousTahunAjaran1 = currentTahunAjaran1
            }
        }

        // Periksa apakah teks berubah untuk textField2
        if textField === tahunAjaranTextField2 {
            if currentTahunAjaran2 == previousTahunAjaran2 {
                // Tidak ada perubahan, keluar dari fungsi
                #if DEBUG
                    print("Tahun ajaran 2 tidak berubah.")
                #endif
                return
            } else {
                // Ada perubahan, perbarui nilai sebelumnya
                previousTahunAjaran2 = currentTahunAjaran2
            }
        }

        muatUlang(obj)
    }
}
