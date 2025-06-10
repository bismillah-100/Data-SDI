//
//  GuruViewMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa

extension GuruViewController {
    /// Membuat dan mengonfigurasi sebuah `NSMenu` yang akan digunakan sebagai menu konteks
    /// atau menu toolbar. Menu ini berisi berbagai item untuk interaksi pengguna, seperti
    /// memuat ulang data, menambahkan guru baru, mengubah preferensi tampilan, mengedit,
    /// menghapus, dan menyalin data.
    ///
    /// - Returns: Sebuah instance `NSMenu` yang telah dikonfigurasi dengan item-item menu.
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu() // Inisialisasi objek NSMenu baru.

        // MARK: - Item Menu 'Foto'

        // Membuat NSMenuItem untuk representasi visual terkait foto.
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        // Membuat NSImage dari simbol sistem "ellipsis.circle".
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        // Mengatur konfigurasi simbol menjadi skala besar.
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        // Menerapkan konfigurasi skala besar ke gambar.
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        image.image = largeActionImage // Menetapkan gambar ke item menu.
        image.identifier = NSUserInterfaceItemIdentifier("foto") // Memberikan identifier unik.
        menu.addItem(image) // Menambahkan item menu ke menu.

        // MARK: - Item Menu 'Muat Ulang'

        // Membuat NSMenuItem untuk memuat ulang data.
        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.identifier = NSUserInterfaceItemIdentifier("refresh") // Memberikan identifier unik.
        refresh.target = self // Menetapkan target aksi ke instance ini.
        menu.addItem(refresh) // Menambahkan item menu ke menu.
        menu.addItem(NSMenuItem.separator()) // Menambahkan pemisah visual.

        // MARK: - Item Menu 'Catat Guru baru'

        // Membuat NSMenuItem untuk menambahkan guru baru.
        let add = NSMenuItem(title: "Catat Guru baru", action: #selector(addGuru(_:)), keyEquivalent: "")
        menu.addItem(add) // Menambahkan item menu ke menu.
        add.target = self // Menetapkan target aksi ke instance ini.
        add.identifier = NSUserInterfaceItemIdentifier("add") // Memberikan identifier unik.
        menu.addItem(NSMenuItem.separator()) // Menambahkan pemisah visual.

        // MARK: - Item Menu 'Gunakan Warna Alternatif'

        // Membuat NSMenuItem untuk beralih mode warna alternatif tabel.
        let menuWarnaAlternatif = NSMenuItem(title: "Gunakan Warna Alternatif", action: #selector(beralihWarnaAlternatif), keyEquivalent: "")
        // Mengatur status item menu (centang atau tidak) berdasarkan nilai properti `warnaAlternatif`.
        menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        menuWarnaAlternatif.identifier = NSUserInterfaceItemIdentifier("warnaAlt") // Memberikan identifier unik.
        menu.addItem(menuWarnaAlternatif) // Menambahkan item menu ke menu.
        menu.addItem(NSMenuItem.separator()) // Menambahkan pemisah visual.

        // MARK: - Item Menu 'Edit'

        // Membuat NSMenuItem untuk mengedit item yang dipilih.
        let editItem = NSMenuItem(title: "Edit", action: #selector(edit(_:)), keyEquivalent: "")
        editItem.identifier = NSUserInterfaceItemIdentifier("edit") // Memberikan identifier unik.
        menu.addItem(editItem) // Menambahkan item menu ke menu.

        // MARK: - Item Menu 'Hapus'

        // Membuat NSMenuItem untuk menghapus item yang dipilih.
        let deleteItem = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        deleteItem.identifier = NSUserInterfaceItemIdentifier("hapus") // Memberikan identifier unik.
        deleteItem.target = self // Menetapkan target aksi ke instance ini.
        menu.addItem(deleteItem) // Menambahkan item menu ke menu.
        menu.addItem(NSMenuItem.separator()) // Menambahkan pemisah visual.

        // MARK: - Item Menu 'Salin'

        // Membuat NSMenuItem untuk menyalin data dari item yang dipilih.
        let salin = NSMenuItem(title: "Salin", action: #selector(salinData(_:)), keyEquivalent: "")
        salin.identifier = NSUserInterfaceItemIdentifier("salin") // Memberikan identifier unik.
        // Menyimpan indeks baris yang dipilih saat ini sebagai `representedObject`.
        // Ini memungkinkan penerima aksi `salinData` untuk mengetahui baris mana yang relevan.
        salin.representedObject = outlineView.selectedRowIndexes
        salin.target = self // Menetapkan target aksi ke instance ini.
        menu.addItem(salin) // Menambahkan item menu ke menu.

        return menu // Mengembalikan menu yang telah selesai dikonfigurasi.
    }

    /// Memperbarui status dan judul item-item dalam menu konteks tabel (`NSMenu`)
    /// berdasarkan baris yang diklik dan baris yang dipilih di `NSOutlineView`.
    /// Fungsi ini menyesuaikan visibilitas dan teks menu item agar relevan dengan konteks
    /// interaksi pengguna (misalnya, baris dipilih, tidak ada baris yang dipilih, atau multi-seleksi).
    ///
    /// - Parameter menu: `NSMenu` yang akan diperbarui.
    func updateTableMenu(_ menu: NSMenu) {
        // Mendapatkan indeks baris yang terakhir diklik di `outlineView`.
        let clickedRow = outlineView.clickedRow

        // Temukan item menu "Gunakan Warna Alternatif" berdasarkan identifier-nya.
        if let menuWarnaAlternatif = menu.items.first(where: { $0.identifier?.rawValue == "warnaAlt" }) {
            // Perbarui status centang item menu ini berdasarkan properti `warnaAlternatif`.
            menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        }

        // --- Logika untuk Ketika Tidak Ada Baris yang Diklik ---
        // Jika tidak ada baris yang diklik (clickedRow kurang dari 0),
        // atur visibilitas item menu untuk skenario "tidak ada seleksi".
        guard clickedRow >= 0 else {
            for i in menu.items {
                // Item menu "add", "refresh", dan "warnaAlt" harus terlihat.
                if i.identifier?.rawValue == "add" ||
                    i.identifier?.rawValue == "refresh" ||
                    i.identifier?.rawValue == "warnaAlt"
                {
                    i.isHidden = false
                }
                // Item menu "foto", "salin", "edit", dan "hapus" harus disembunyikan.
                else if i.identifier?.rawValue == "foto" ||
                    i.identifier?.rawValue == "salin" ||
                    i.identifier?.rawValue == "edit" ||
                    i.identifier?.rawValue == "hapus"
                {
                    i.isHidden = true
                }
            }
            return // Hentikan eksekusi fungsi.
        }

        // --- Logika untuk Ketika Ada Baris yang Diklik ---
        // Jika ada baris yang diklik, atur visibilitas item menu untuk skenario "ada seleksi".
        for i in menu.items {
            // Item menu "foto", "add", "refresh", dan "warnaAlt" harus disembunyikan.
            if i.identifier?.rawValue == "foto" ||
                i.identifier?.rawValue == "add" ||
                i.identifier?.rawValue == "refresh" ||
                i.identifier?.rawValue == "warnaAlt"
            {
                i.isHidden = true
            }
            // Semua item menu lainnya harus terlihat.
            else {
                i.isHidden = false
            }
        }

        // Variabel untuk menyimpan bagian teks dinamis untuk judul menu.
        var nama = String() // Digunakan untuk judul item 'Hapus'.
        var editString = String() // Digunakan untuk judul item 'Edit'.
        var copyString = String() // Digunakan untuk judul item 'Salin'.

        // Mendapatkan semua indeks baris yang saat ini dipilih di `outlineView`.
        let selectedRows = outlineView.selectedRowIndexes

        /// Fungsi pembantu lokal untuk mengisi `nama`, `editString`, dan `copyString`
        /// berdasarkan baris yang diklik.
        func onlyClickedRow() {
            if let selectedItem = outlineView.item(atRow: clickedRow) {
                // Jika item yang diklik adalah `GuruModel`.
                if let guru = selectedItem as? GuruModel {
                    editString = "\(guru.namaGuru)"
                    nama = "\(guru.namaGuru)"
                    copyString = "Data \"\(guru.namaGuru)\""
                }
                // Jika item yang diklik adalah `MapelModel`.
                else if let mapel = selectedItem as? MapelModel {
                    editString = "guru \(mapel.namaMapel)"
                    nama = "guru \(mapel.namaMapel)"
                    copyString = "\"\(mapel.namaMapel)\""
                }
            }
        }

        // --- Logika Penentuan Judul Menu Berdasarkan Seleksi ---
        // Jika ada lebih dari satu baris yang dipilih.
        if selectedRows.count > 1 {
            // Jika baris yang diklik termasuk dalam kumpulan baris yang dipilih,
            // ini menandakan multi-seleksi aktif.
            if selectedRows.contains(clickedRow) {
                // Inisialisasi penghitung untuk guru dan mapel yang dipilih.
                var guruCount = 0
                var mapelCount = 0

                // Iterasi melalui setiap baris yang dipilih untuk menghitung jenis item.
                for row in selectedRows {
                    if let selectedItem = outlineView.item(atRow: row) {
                        if selectedItem is GuruModel {
                            guruCount += 1
                        } else if selectedItem is MapelModel {
                            mapelCount += 1
                        }
                    }
                }

                // Gabungkan string untuk `nama`, `editString`, dan `copyString`
                // berdasarkan jumlah guru dan mapel yang dipilih.
                var namaParts: [String] = []
                if guruCount > 0 {
                    namaParts.append("\(guruCount) guru")
                }
                if mapelCount > 0 {
                    namaParts.append("\(mapelCount) mapel")
                }
                nama = "(\(namaParts.joined(separator: " dan ")))"
                editString = nama
                copyString = nama
            } else {
                // Jika baris yang diklik bukan bagian dari seleksi multi-baris,
                // hanya fokus pada baris yang diklik saja.
                onlyClickedRow()
            }
        } else {
            // Jika hanya satu baris atau tidak ada baris yang dipilih (tapi `clickedRow` valid),
            // fokus pada baris yang diklik.
            onlyClickedRow()
        }

        // --- Memperbarui Judul dan Target Item Menu Individual ---
        // Temukan item menu "Edit" dan perbarui propertinya.
        if let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            editItem.action = #selector(edit(_:)) // Menetapkan aksi.
            editItem.target = self // Menetapkan target.
            editItem.isEnabled = true // Memastikan item aktif.
            editItem.title = "Edit \(editString)" // Memperbarui judul dengan teks dinamis.
        }

        // Temukan item menu "Salin" dan perbarui propertinya.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            // Menyimpan indeks baris yang dipilih saat ini sebagai `representedObject`
            // untuk digunakan oleh aksi penyalinan.
            salin.representedObject = outlineView.selectedRowIndexes
            salin.title = "Salin \(copyString)" // Memperbarui judul.
            salin.target = self // Menetapkan target.
        }

        // Temukan item menu "Hapus" dan perbarui propertinya.
        if let deleteItem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            deleteItem.title = "Hapus \(nama)" // Memperbarui judul.
            deleteItem.target = self // Menetapkan target.
        }
    }

    /// Memperbarui status dan judul item-item dalam menu toolbar (`NSMenu`)
    /// berdasarkan baris yang dipilih di `NSOutlineView`. Fungsi ini menyesuaikan
    /// visibilitas dan teks item menu agar relevan dengan konteks seleksi pengguna
    /// (misalnya, tidak ada seleksi, seleksi tunggal, atau multi-seleksi).
    ///
    /// - Parameter menu: `NSMenu` yang akan diperbarui.
    func updateToolbarMenu(_ menu: NSMenu) {
        // Mendapatkan indeks baris yang saat ini dipilih di `outlineView`.
        // Perhatikan bahwa di sini digunakan `selectedRow` (seleksi tunggal)
        // bukan `clickedRow` seperti di `updateTableMenu`.
        let clickedRow = outlineView.selectedRow

        // Temukan item menu "Gunakan Warna Alternatif" berdasarkan identifier-nya.
        if let menuWarnaAlternatif = menu.items.first(where: { $0.identifier?.rawValue == "warnaAlt" }) {
            // Perbarui status centang item menu ini berdasarkan properti `warnaAlternatif`.
            menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        }

        // --- Logika untuk Ketika Tidak Ada Baris yang Dipilih ---
        // Jika tidak ada baris yang dipilih (`clickedRow` kurang dari 0),
        // atur visibilitas item menu untuk skenario "tidak ada seleksi".
        guard clickedRow >= 0 else {
            for i in menu.items {
                // Item menu "add", "refresh", dan "warnaAlt" harus terlihat.
                if i.identifier?.rawValue == "add" ||
                    i.identifier?.rawValue == "refresh" ||
                    i.identifier?.rawValue == "warnaAlt"
                {
                    i.isHidden = false
                }
                // Item menu "foto", "salin", "edit", dan "hapus" harus disembunyikan.
                else if i.identifier?.rawValue == "foto" ||
                    i.identifier?.rawValue == "salin" ||
                    i.identifier?.rawValue == "edit" ||
                    i.identifier?.rawValue == "hapus"
                {
                    i.isHidden = true
                }
            }
            return // Hentikan eksekusi fungsi.
        }

        // --- Logika untuk Ketika Ada Baris yang Dipilih (clickedRow >= 0) ---
        // Jika ada baris yang dipilih, atur visibilitas item menu.
        for i in menu.items {
            // Item menu "foto" harus disembunyikan.
            if i.identifier?.rawValue == "foto" {
                i.isHidden = true
            }
            // Semua item menu lainnya harus terlihat.
            else {
                i.isHidden = false
            }
        }

        // Variabel untuk menyimpan bagian teks dinamis untuk judul menu.
        var nama = String() // Digunakan untuk judul item 'Hapus'.
        var editString = String() // Digunakan untuk judul item 'Edit'.
        var copyString = String() // Digunakan untuk judul item 'Salin'.

        // Mendapatkan semua indeks baris yang saat ini dipilih di `outlineView`.
        let selectedRows = outlineView.selectedRowIndexes

        // --- Logika Penentuan Judul Menu Berdasarkan Seleksi ---
        // Jika ada lebih dari satu baris yang dipilih.
        if selectedRows.count > 1 {
            // Inisialisasi penghitung untuk guru dan mapel yang dipilih.
            var guruCount = 0
            var mapelCount = 0

            // Iterasi melalui setiap baris yang dipilih untuk menghitung jenis item.
            for row in selectedRows {
                // Mendapatkan item (data model) yang terkait dengan baris saat ini.
                if let selectedItem = outlineView.item(atRow: row) {
                    if selectedItem is GuruModel {
                        guruCount += 1
                    } else if selectedItem is MapelModel {
                        mapelCount += 1
                    }
                }
            }

            // Gabungkan string untuk `nama`, `editString`, dan `copyString`
            // berdasarkan jumlah guru dan mapel yang dipilih.
            var namaParts: [String] = []
            if guruCount > 0 {
                namaParts.append("\(guruCount) guru")
            }
            if mapelCount > 0 {
                namaParts.append("\(mapelCount) mapel")
            }
            nama = "(\(namaParts.joined(separator: " dan ")))"
            editString = nama
            copyString = nama
        } else {
            // Jika hanya satu baris yang dipilih (atau `clickedRow` valid tapi `selectedRows.count` tidak lebih dari 1).
            if let selectedItem = outlineView.item(atRow: clickedRow) {
                // Jika item yang dipilih adalah `GuruModel`.
                if let guru = selectedItem as? GuruModel {
                    editString = "\(guru.namaGuru)"
                    nama = "\(guru.namaGuru)"
                    copyString = "Data \"\(guru.namaGuru)\""
                }
                // Jika item yang dipilih adalah `MapelModel`.
                else if let mapel = selectedItem as? MapelModel {
                    editString = "guru \(mapel.namaMapel)"
                    nama = "guru \(mapel.namaMapel)"
                    copyString = "\"\(mapel.namaMapel)\""
                }
            }
        }

        // --- Memperbarui Judul dan Target Item Menu Individual ---
        // Temukan item menu "Edit" dan perbarui propertinya.
        if let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            editItem.action = #selector(edit(_:)) // Menetapkan aksi.
            editItem.target = self // Menetapkan target.
            editItem.isEnabled = true // Memastikan item aktif.
            editItem.title = "Edit \(editString)" // Memperbarui judul dengan teks dinamis.
        }

        // Temukan item menu "Salin" dan perbarui propertinya.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = "Salin \(copyString)" // Memperbarui judul.
        }

        // Temukan item menu "Hapus" dan perbarui propertinya.
        if let deleteItem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            deleteItem.title = "Hapus \(nama)" // Memperbarui judul.
        }
    }
}
