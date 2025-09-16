//
//  JumlahSiswaMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa

extension JumlahSiswa {
    /**
     Membuat dan mengembalikan sebuah menu NSMenu yang berisi item-item seperti "foto", "Muat Ulang", "Salin", dan "Salin Semua Jumlah Siswa".

     - Returns: Sebuah objek NSMenu yang telah dikonfigurasi.
     */
    func buatItemMenu() -> NSMenu {
        let menu = NSMenu()

        let foto = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        foto.image = ReusableFunc.largeActionImage
        menu.addItem(foto)

        let reloadData = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        reloadData.target = self
        menu.addItem(reloadData)
        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Salin", action: #selector(copyMenuItem(_:)), keyEquivalent: "")
        copyItem.identifier = NSUserInterfaceItemIdentifier("salin")
        copyItem.target = self
        menu.addItem(copyItem)

        let copyAllItem = NSMenuItem(title: "Salin Semua Jumlah Siswa", action: #selector(copyMenuItem(_:)), keyEquivalent: "")
        copyAllItem.identifier = NSUserInterfaceItemIdentifier("salinSemua")
        copyAllItem.target = self
        copyAllItem.representedObject = true
        menu.addItem(copyAllItem)

        return menu
    }

    /**
         Memperbarui tampilan menu berdasarkan status tabel.

         Fungsi ini mengatur visibilitas item menu berdasarkan kondisi berikut:
         - Jika tidak ada baris di tabel, semua item menu (kecuali "Muat Ulang") disembunyikan.
         - Jika ada baris yang dipilih di tabel dan tidak ada baris yang diklik, hanya item "Salin Semua Jumlah Siswa" yang ditampilkan.
         - Jika ada baris yang diklik, hanya item "Salin" yang ditampilkan.
         - Item "Foto" selalu disembunyikan.
         - Item "Muat Ulang" ditampilkan hanya jika ada baris di tabel dan tidak ada baris yang dipilih.

         - Parameter:
             - menu: Menu NS yang akan diperbarui.
     */
    func updateTableMenu(_ menu: NSMenu) {
        let foto = menu.item(at: 0)
        foto?.isHidden = true
        guard tableView.numberOfRows > 0 else {
            for i in menu.items {
                if i.title.lowercased() != "muat ulang" {
                    i.isHidden = true
                } else {
                    i.isHidden = true
                }
            }
            return
        }
        let muatUlang = menu.item(withTitle: "Muat Ulang")
        muatUlang?.isHidden = false
        guard tableView.clickedRow >= 0 else {
            let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
            salinSemua?.isHidden = false
            let salin = menu.item(withTitle: "Salin")
            salin?.isHidden = true
            return
        }

        muatUlang?.isHidden = true

        let salin = menu.item(withTitle: "Salin")
        salin?.isHidden = false

        let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
        salinSemua?.isHidden = true
    }

    /**
         Memperbarui menu toolbar berdasarkan status tabel tampilan.

         Fungsi ini menyesuaikan visibilitas item menu toolbar berdasarkan apakah tabel tampilan memiliki baris,
         dan apakah ada baris yang dipilih.

         - Parameter menu: Menu `NSMenu` yang akan diperbarui.

         **Logika:**

         1.  **Jika tabel tampilan kosong (tidak ada baris):**
             *   Menyembunyikan semua item menu kecuali "Muat Ulang" dan "Foto".
         2.  **Jika tabel tampilan tidak kosong:**
             *   Menyembunyikan item menu "Foto".
             *   **Jika tidak ada baris yang dipilih:**
                 *   Menampilkan item menu "Salin Semua Jumlah Siswa".
                 *   Menyembunyikan item menu "Salin".
             *   **Jika ada setidaknya satu baris yang dipilih:**
                 *   Menampilkan item menu "Salin".

         **Catatan:** Fungsi ini mengasumsikan bahwa menu memiliki item dengan judul yang sesuai
         ("Muat Ulang", "Foto", "Salin Semua Jumlah Siswa", "Salin").
     */
    func updateToolbarMenu(_ menu: NSMenu) {
        guard tableView.numberOfRows > 0 else {
            for i in menu.items {
                if i.title.lowercased() != "muat ulang" {
                    i.isHidden = true
                } else if i.title.lowercased() != "foto" {
                    i.isHidden = true
                } else {
                    i.isHidden = true
                }
            }
            return
        }
        let foto = menu.item(at: 0)
        foto?.isHidden = true
        guard tableView.numberOfSelectedRows >= 1 else {
            let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
            salinSemua?.isHidden = false
            let salin = menu.item(withTitle: "Salin")
            salin?.isHidden = true
            return
        }
        let salinSemua = menu.item(withTitle: "Salin")
        salinSemua?.isHidden = false

        let salin = menu.item(withTitle: "Salin")
        salin?.isHidden = false
    }
}
