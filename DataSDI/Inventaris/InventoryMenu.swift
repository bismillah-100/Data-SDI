//
//  InventoryMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa

extension InventoryView {
    /// Membuat dan mengonfigurasi `NSMenu` yang digunakan sebagai menu konteks atau menu aksi di aplikasi.
    /// Menu ini mencakup berbagai opsi untuk berinteraksi dengan data dan tampilan tabel,
    /// seperti muat ulang, tambah/hapus kolom/baris, edit, salin, serta opsi terkait foto (buka, lihat, simpan, hapus).
    ///
    /// - Returns: Sebuah instance `NSMenu` yang telah dikonfigurasi dengan `NSMenuItem` yang relevan.
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu() // Membuat instance baru dari NSMenu.

        // --- Bagian "foto" ---
        // Membuat NSMenuItem untuk kategori "foto" tanpa aksi langsung, hanya sebagai label atau sub-menu.
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        // Mendapatkan gambar sistem SFSymbol "ellipsis.circle".
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        // Mengonfigurasi simbol gambar agar berukuran besar.
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        // Menerapkan konfigurasi ukuran besar pada gambar.
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        // Menetapkan gambar ke `NSMenuItem`.
        image.image = largeActionImage
        // Menetapkan identifier untuk `NSMenuItem` ini.
        image.identifier = NSUserInterfaceItemIdentifier("foto")
        menu.addItem(image) // Menambahkan item ke menu.

        // --- Bagian Aksi Utama ---
        // Item "Muat Ulang" untuk me-reload data.
        let muatUlang = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        muatUlang.identifier = NSUserInterfaceItemIdentifier("muatUlang")
        menu.addItem(muatUlang)
        menu.addItem(NSMenuItem.separator()) // Pemisah visual.

        // Item "Tambah Kolom" untuk menambah kolom baru.
        let tambahHeader = NSMenuItem(title: "Tambah Kolom", action: #selector(addColumnButtonClicked(_:)), keyEquivalent: "")
        tambahHeader.identifier = NSUserInterfaceItemIdentifier("tambahHeader")
        menu.addItem(tambahHeader)

        // Item "Masukkan Data" untuk menambah baris data baru.
        let tambahRow = NSMenuItem(title: "Masukkan Data", action: #selector(addRowButtonClicked(_:)), keyEquivalent: "")
        tambahRow.identifier = NSUserInterfaceItemIdentifier("tambahRow")
        menu.addItem(tambahRow)
        menu.addItem(NSMenuItem.separator()) // Pemisah visual.

        // Item "Edit" untuk mengedit data.
        let edit = NSMenuItem(title: "Edit", action: #selector(edit(_:)), keyEquivalent: "")
        edit.identifier = NSUserInterfaceItemIdentifier("edit")
        menu.addItem(edit)

        // Item "Hapus" untuk menghapus data.
        let hapus = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        hapus.identifier = NSUserInterfaceItemIdentifier("hapus")
        menu.addItem(hapus)

        // Item "Hapus Foto" untuk menghapus foto yang terkait dengan data.
        let hapusFoto = NSMenuItem(title: "Hapus Foto", action: #selector(hapusFotoMenu(_:)), keyEquivalent: "")
        hapusFoto.identifier = NSUserInterfaceItemIdentifier("hapusFoto")
        menu.addItem(hapusFoto)
        menu.addItem(NSMenuItem.separator()) // Pemisah visual.

        // Item "Salin" untuk menyalin data ke clipboard.
        let salin = NSMenuItem(title: "Salin", action: #selector(salinData(_:)), keyEquivalent: "")
        salin.identifier = NSUserInterfaceItemIdentifier("salin")
        menu.addItem(salin)
        menu.addItem(NSMenuItem.separator()) // Pemisah visual.

        // --- Bagian Aksi Foto Spesifik ---
        // Item "Buka Foto" untuk membuka foto di aplikasi default (misalnya Preview.app).
        let foto = NSMenuItem(title: "Buka Foto", action: #selector(tampilkanFoto(_:)), keyEquivalent: "")
        foto.identifier = NSUserInterfaceItemIdentifier("tampilkanFoto")
        menu.addItem(foto)

        // Item "Lihat Foto" untuk menampilkan foto menggunakan Quick Look.
        let lihatFoto = NSMenuItem(title: "Lihat Foto", action: #selector(tampilkanFotos(_:)), keyEquivalent: "")
        lihatFoto.identifier = NSUserInterfaceItemIdentifier("lihatFoto")
        menu.addItem(lihatFoto)

        // Item "Simpan Foto" untuk menyimpan foto ke sistem berkas.
        let simpanFoto = NSMenuItem(title: "Simpan Foto", action: #selector(simpanFoto(_:)), keyEquivalent: "")
        simpanFoto.identifier = NSUserInterfaceItemIdentifier("simpanFoto")
        menu.addItem(simpanFoto)

        return menu // Mengembalikan menu yang telah lengkap.
    }

    /// Memperbarui visibilitas dan judul item-item dalam menu konteks tabel
    /// berdasarkan konteks interaksi pengguna (baris yang diklik atau dipilih).
    /// Fungsi ini menyesuaikan menu agar hanya menampilkan opsi yang relevan
    /// dengan kondisi pemilihan baris saat ini, serta memperbarui teks item menu
    /// untuk mencerminkan jumlah atau nama item yang terpengaruh.
    ///
    /// - Parameter menu: `NSMenu` yang akan diperbarui (biasanya menu konteks tabel).
    func updateTableMenu(_ menu: NSMenu) {
        let klikRow = tableView.clickedRow // Indeks baris yang terakhir diklik.
        let rows = tableView.selectedRowIndexes // `IndexSet` dari baris-baris yang dipilih.

        // --- Skenario 1: Tidak ada baris yang dipilih DAN tidak ada baris yang diklik. ---
        // (Misalnya, pengguna mengklik area kosong di tabel atau memicu menu tanpa seleksi/klik).
        if !rows.contains(klikRow) && klikRow == -1 {
            for i in menu.items { // Iterasi melalui semua item dalam menu.
                // Tampilkan item-item yang relevan saat tidak ada seleksi/klik.
                if i.identifier?.rawValue == "tambahHeader" ||
                    i.identifier?.rawValue == "tambahRow" ||
                    i.identifier?.rawValue == "muatUlang"
                {
                    i.isHidden = false // Jadikan terlihat.
                }
                // Sembunyikan item-item yang memerlukan baris yang dipilih/diklik.
                else if i.identifier?.rawValue == "edit" ||
                    i.identifier?.rawValue == "foto" || // Item "foto" sebagai kategori/label.
                    i.identifier?.rawValue == "hapus" ||
                    i.identifier?.rawValue == "hapusFoto" ||
                    i.identifier?.rawValue == "salin" ||
                    i.identifier?.rawValue == "tampilkanFoto" ||
                    i.identifier?.rawValue == "simpanFoto" ||
                    i.identifier?.rawValue == "lihatFoto"
                {
                    i.isHidden = true // Jadikan tersembunyi.
                }
            }
            return // Hentikan fungsi karena menu telah diperbarui untuk skenario ini.
        }

        // --- Skenario 2: Ada baris yang dipilih atau diklik. ---
        // Logika ini akan dieksekusi jika kondisi `if` di atas tidak terpenuhi.
        for i in menu.items { // Iterasi lagi melalui semua item menu.
            // Sembunyikan item-item yang tidak relevan saat ada seleksi/klik.
            if i.identifier?.rawValue == "foto" || // Sembunyikan kategori "foto".
                i.identifier?.rawValue == "tambahHeader" ||
                i.identifier?.rawValue == "tambahRow" ||
                i.identifier?.rawValue == "muatUlang"
            {
                i.isHidden = true
            }
            // Tampilkan item-item yang memerlukan baris yang dipilih/diklik.
            else if i.identifier?.rawValue == "edit" ||
                i.identifier?.rawValue == "hapus" ||
                i.identifier?.rawValue == "hapusFoto" ||
                i.identifier?.rawValue == "salin" ||
                i.identifier?.rawValue == "tampilkanFoto" ||
                i.identifier?.rawValue == "simpanFoto" ||
                i.identifier?.rawValue == "lihatFoto"
            {
                i.isHidden = false
            }
        }

        var nama = "" // Variabel untuk menyimpan nama item/jumlah item yang ditampilkan di menu.
        var editString = "" // Variabel khusus untuk teks item "Edit".

        // Mengambil "Nama Barang" dari baris yang diklik. Ini akan digunakan sebagai nama default.
        let namaBarang = data[klikRow]["Nama Barang"] as? String
        // Mengatur `editString` default untuk kasus edit satu baris.
        editString = "\"\(namaBarang ?? "namaBarang")\""

        // Mendapatkan referensi ke item menu "Lihat Foto" untuk diperbarui nanti.
        let lihatFoto = menu.items.first(where: { $0.identifier?.rawValue == "lihatFoto" })

        // --- Logika Penyesuaian Judul Item Menu ---
        // Jika baris yang diklik TIDAK termasuk dalam seleksi dan `klikRow` valid (ini adalah klik tunggal non-seleksi).
        if !rows.contains(klikRow) && klikRow != -1 {
            // Atur `nama` menjadi nama barang dari baris yang diklik.
            nama = "\"\(namaBarang ?? "namaBarang")\""
            // Perbarui judul item "Lihat Foto" untuk mencerminkan nama barang tunggal.
            lihatFoto?.title = "Lihat Cepat \"\(namaBarang ?? "")\""
        }
        // Jika baris yang diklik termasuk dalam seleksi, atau jika ada seleksi tanpa klik spesifik.
        else {
            // Pastikan ada baris yang diklik. Kondisi ini mungkin sedikit berlebihan
            // mengingat struktur `if/else` sebelumnya.
            guard tableView.clickedRow != -1 else { return }

            // Atur `nama` menjadi "X item..." untuk menunjukkan multiple selection.
            nama = "\(rows.count) item..."
            // Jika ada lebih dari satu baris yang dipilih, perbarui `editString` menjadi "X item...".
            if tableView.selectedRowIndexes.count > 1 {
                editString = "\(rows.count) item..."
            }
            // Perbarui judul item "Lihat Foto" untuk mencerminkan jumlah item yang dipilih.
            lihatFoto?.title = "Lihat Cepat \(rows.count) item..."
        }

        // Pastikan ada baris yang dipilih ATAU baris yang diklik valid sebelum memperbarui judul item.
        // Jika tidak ada, kembalikan menu tanpa perubahan lebih lanjut dan atur ulang menu tableView.
        guard rows.count > 0 || klikRow != -1 else {
            tableView.menu = menu // Atur ulang menu tableView ke menu yang diperbarui.
            return
        }

        // Perbarui judul item "Hapus" berdasarkan `nama` yang telah ditentukan.
        if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            hapus.title = "Hapus \(nama)"
        }
        // Perbarui judul item "Hapus Foto" berdasarkan `nama`.
        if let hapusFoto = menu.items.first(where: { $0.identifier?.rawValue == "hapusFoto" }) {
            hapusFoto.title = "Hapus Foto \(nama)"
        }
        // Perbarui judul item "Edit" berdasarkan `editString`.
        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = "Edit \(editString)"
        }

        // Perbarui judul item "Salin" berdasarkan `nama`.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = "Salin \(nama)"
        }
    }

    /// Memperbarui visibilitas dan judul item-item dalam menu toolbar
    /// berdasarkan status seleksi baris di `NSTableView`.
    /// Fungsi ini menyesuaikan menu agar hanya menampilkan opsi yang relevan
    /// dengan konteks seleksi saat ini (tidak ada seleksi, satu seleksi, atau multi-seleksi),
    /// serta memperbarui teks item menu untuk mencerminkan jumlah atau nama item yang terpengaruh.
    ///
    /// - Parameter menu: `NSMenu` yang ada di dalam toolbar (``DataSDI/WindowController/actionToolbar``) yang akan diperbarui.
    func updateToolbarMenu(_ menu: NSMenu) {
        let klikRow = tableView.selectedRow // Indeks baris yang saat ini dipilih (jika hanya satu).
        let rows = tableView.selectedRowIndexes // `IndexSet` dari semua baris yang dipilih.

        // --- Skenario 1: Tidak ada baris yang dipilih (jumlah baris yang dipilih kurang dari 1). ---
        guard tableView.numberOfSelectedRows >= 1 else {
            // Iterasi melalui semua item dalam menu toolbar.
            for i in menu.items {
                // Tampilkan item-item yang relevan saat tidak ada seleksi.
                if i.identifier?.rawValue == "tambahHeader" ||
                    i.identifier?.rawValue == "tambahRow" ||
                    i.identifier?.rawValue == "muatUlang"
                {
                    i.isHidden = false // Jadikan terlihat.
                }
                // Sembunyikan item-item yang memerlukan setidaknya satu baris yang dipilih.
                else if i.identifier?.rawValue == "foto" || // Item "foto" sebagai kategori/label.
                    i.identifier?.rawValue == "edit" ||
                    i.identifier?.rawValue == "hapus" ||
                    i.identifier?.rawValue == "hapusFoto" ||
                    i.identifier?.rawValue == "salin" ||
                    i.identifier?.rawValue == "tampilkanFoto" ||
                    i.identifier?.rawValue == "simpanFoto" ||
                    i.identifier?.rawValue == "lihatFoto"
                {
                    i.isHidden = true // Jadikan tersembunyi.
                }
            }
            return // Hentikan fungsi karena menu telah diperbarui untuk skenario ini.
        }

        // --- Skenario 2: Ada setidaknya satu baris yang dipilih. ---
        // Logika ini akan dieksekusi jika `guard` di atas tidak terpenuhi.
        for i in menu.items {
            // Sembunyikan item kategori "foto" karena akan diganti dengan aksi spesifik foto.
            if i.identifier?.rawValue == "foto" {
                i.isHidden = true
            }
            // Tampilkan item-item dasar yang selalu relevan atau relevan dengan seleksi.
            else if i.identifier?.rawValue == "tambahHeader" ||
                i.identifier?.rawValue == "tambahRow" ||
                i.identifier?.rawValue == "muatUlang"
            {
                i.isHidden = false
            }
            // Tampilkan item-item yang memerlukan baris yang dipilih.
            else if i.identifier?.rawValue == "edit" ||
                i.identifier?.rawValue == "hapus" ||
                i.identifier?.rawValue == "hapusFoto" ||
                i.identifier?.rawValue == "salin" ||
                i.identifier?.rawValue == "tampilkanFoto" ||
                i.identifier?.rawValue == "simpanFoto" ||
                i.identifier?.rawValue == "lihatFoto"
            {
                i.isHidden = false
            }
        }

        var nama = "" // Variabel untuk menyimpan nama item/jumlah item yang ditampilkan di menu.
        var editString = "" // Variabel khusus untuk teks item "Edit".
        var lihatFotoTitle = "" // Variabel khusus untuk judul item "Lihat Foto".

        // Pastikan `rows.count` tidak negatif. Ini adalah guard yang aman.
        guard rows.count >= 0 else { return }

        // Mendapatkan referensi ke item menu "Lihat Foto".
        let lihatFoto = menu.items.first(where: { $0.identifier?.rawValue == "lihatFoto" })

        // Mengambil "Nama Barang" dari baris yang diklik/dipilih (jika ada).
        // Perhatikan bahwa `klikRow` di sini adalah `tableView.selectedRow`, yang hanya satu baris.
        let namaBarang = data[klikRow]["Nama Barang"] as? String
        // Atur `editString` default untuk kasus edit satu baris.
        editString = "\"\(namaBarang ?? "")\""

        // --- Logika Penyesuaian Judul Item Menu berdasarkan jumlah seleksi ---
        if rows.count >= 2 {
            // Jika dua atau lebih baris dipilih:
            lihatFotoTitle = "Lihat Cepat \(rows.count) item..."
            nama = "\(rows.count) item..."
            editString = "\(rows.count) item..." // Untuk "Edit X item..."
        } else {
            // Jika hanya satu baris dipilih (atau nol, tapi itu sudah ditangani oleh guard awal):
            lihatFotoTitle = "Lihat Cepat \"\(namaBarang ?? "")\""
            nama = "\"\(namaBarang ?? "")\""
            // `editString` sudah diatur di atas untuk kasus ini.
        }

        // Pastikan ada baris yang dipilih ATAU baris yang diklik valid sebelum memperbarui judul item.
        // Ini mungkin redundan mengingat struktur `guard` di awal, tetapi bertindak sebagai pemeriksaan keamanan.
        guard rows.count > 0 || klikRow != -1 else {
            // Jika tidak ada seleksi atau klik valid, atur ulang menu tableView.
            tableView.menu = menu
            return
        }

        // Perbarui judul item "Hapus" berdasarkan `nama`.
        if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            hapus.title = "Hapus \(nama)"
        }

        // Perbarui judul item "Lihat Foto" dengan `lihatFotoTitle` yang telah ditentukan.
        lihatFoto?.title = lihatFotoTitle

        // Perbarui judul item "Hapus Foto" berdasarkan `nama`.
        if let hapusFoto = menu.items.first(where: { $0.identifier?.rawValue == "hapusFoto" }) {
            hapusFoto.title = "Hapus Foto \(nama)"
        }

        // Perbarui judul item "Edit" berdasarkan `editString`.
        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = "Edit \(editString)"
        }

        // Perbarui judul item "Salin" berdasarkan `nama`.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = "Salin \(nama)"
        }
    }

    /// Menangani aksi penghapusan foto yang dipicu dari item menu.
    /// Fungsi ini menentukan baris mana yang harus dihapus fotonya, baik itu baris yang diklik
    /// secara individual atau beberapa baris yang telah dipilih, lalu memanggil fungsi `hapusFoto`
    /// untuk melakukan operasi penghapusan sebenarnya.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @objc func hapusFotoMenu(_ sender: NSMenuItem) {
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let clickedRow = tableView.clickedRow
        // Mendapatkan semua indeks baris yang saat ini dipilih di `tableView`.
        let selectedRows = tableView.selectedRowIndexes

        // Memeriksa apakah ada baris yang diklik (indeks valid).
        if clickedRow >= 0 {
            // Jika baris yang diklik termasuk dalam kumpulan baris yang dipilih,
            // ini menandakan pengguna mungkin ingin menghapus foto dari semua baris yang dipilih.
            if selectedRows.contains(clickedRow) {
                // Panggil `hapusFoto` untuk semua baris yang dipilih.
                hapusFoto(selectedRows)
            }
            // Jika baris yang diklik tidak termasuk dalam kumpulan baris yang dipilih,
            // ini menandakan pengguna hanya ingin menghapus foto dari baris yang diklik saja.
            else {
                // Panggil `hapusFoto` hanya untuk baris yang diklik.
                hapusFoto(IndexSet([clickedRow]))
            }
        }
        // Jika tidak ada baris yang diklik (`clickedRow` kurang dari 0),
        // asumsikan operasi ini berlaku untuk semua baris yang dipilih.
        else {
            // Panggil `hapusFoto` untuk semua baris yang dipilih.
            hapusFoto(selectedRows)
        }
    }
}
