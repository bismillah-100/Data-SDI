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
        image.image = ReusableFunc.largeActionImage
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
        editString = "〝\(namaBarang ?? "namaBarang")〞"

        // Mendapatkan referensi ke item menu "Lihat Foto" untuk diperbarui nanti.
        let lihatFoto = menu.items.first(where: { $0.identifier?.rawValue == "lihatFoto" })

        // --- Logika Penyesuaian Judul Item Menu ---
        // Jika baris yang diklik TIDAK termasuk dalam seleksi dan `klikRow` valid (ini adalah klik tunggal non-seleksi).
        if !rows.contains(klikRow) && klikRow != -1 {
            // Atur `nama` menjadi nama barang dari baris yang diklik.
            nama = "〝\(namaBarang ?? "namaBarang")〞"
            // Perbarui judul item "Lihat Foto" untuk mencerminkan nama barang tunggal.
            lihatFoto?.title = "Lihat Foto〝\(namaBarang ?? "")〞"
        }
        // Jika baris yang diklik termasuk dalam seleksi, atau jika ada seleksi tanpa klik spesifik.
        else {
            // Pastikan ada baris yang diklik. Kondisi ini mungkin sedikit berlebihan
            // mengingat struktur `if/else` sebelumnya.
            guard tableView.clickedRow != -1 else { return }

            // Atur `nama` menjadi "X item..." untuk menunjukkan multiple selection.
            nama = " \(rows.count) item..."
            // Jika ada lebih dari satu baris yang dipilih, perbarui `editString` menjadi "X item...".
            if tableView.selectedRowIndexes.count > 1 {
                editString = " \(rows.count) item..."
            }
            // Perbarui judul item "Lihat Foto" untuk mencerminkan jumlah item yang dipilih.
            lihatFoto?.title = "Lihat Foto \(rows.count) item..."
        }

        // Pastikan ada baris yang dipilih ATAU baris yang diklik valid sebelum memperbarui judul item.
        // Jika tidak ada, kembalikan menu tanpa perubahan lebih lanjut dan atur ulang menu tableView.
        guard rows.count > 0 || klikRow != -1 else {
            tableView.menu = menu // Atur ulang menu tableView ke menu yang diperbarui.
            return
        }

        // Perbarui judul item "Hapus" berdasarkan `nama` yang telah ditentukan.
        if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            hapus.title = "Hapus\(nama)"
        }
        // Perbarui judul item "Hapus Foto" berdasarkan `nama`.
        if let hapusFoto = menu.items.first(where: { $0.identifier?.rawValue == "hapusFoto" }) {
            hapusFoto.title = "Hapus Foto\(nama)"
        }
        // Perbarui judul item "Edit" berdasarkan `editString`.
        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = "Edit\(editString)"
        }

        // Perbarui judul item "Salin" berdasarkan `nama`.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = "Salin\(nama)"
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
        editString = "〝\(namaBarang ?? "")〞"

        // --- Logika Penyesuaian Judul Item Menu berdasarkan jumlah seleksi ---
        if rows.count >= 2 {
            // Jika dua atau lebih baris dipilih:
            lihatFotoTitle = "Lihat Foto \(rows.count) item..."
            nama = " \(rows.count) item..."
            editString = " \(rows.count) item..." // Untuk "Edit X item..."
        } else {
            // Jika hanya satu baris dipilih (atau nol, tapi itu sudah ditangani oleh guard awal):
            lihatFotoTitle = "Lihat Foto〝\(namaBarang ?? "")〞"
            nama = "〝\(namaBarang ?? "")〞"
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
            hapus.title = "Hapus\(nama)"
        }

        // Perbarui judul item "Lihat Foto" dengan `lihatFotoTitle` yang telah ditentukan.
        lihatFoto?.title = lihatFotoTitle

        // Perbarui judul item "Hapus Foto" berdasarkan `nama`.
        if let hapusFoto = menu.items.first(where: { $0.identifier?.rawValue == "hapusFoto" }) {
            hapusFoto.title = "Hapus Foto\(nama)"
        }

        // Perbarui judul item "Edit" berdasarkan `editString`.
        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = "Edit\(editString)"
        }

        // Perbarui judul item "Salin" berdasarkan `nama`.
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = "Salin\(nama)"
        }
    }

    /// Menangani aksi penghapusan foto yang dipicu dari item menu.
    /// Fungsi ini menentukan baris mana yang harus dihapus fotonya, baik itu baris yang diklik
    /// secara individual atau beberapa baris yang telah dipilih, lalu memanggil fungsi `hapusFoto`
    /// untuk melakukan operasi penghapusan sebenarnya.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @objc func hapusFotoMenu(_: NSMenuItem) {
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let clickedRow = tableView.clickedRow
        // Mendapatkan semua indeks baris yang saat ini dipilih di `tableView`.
        let selectedRows = tableView.selectedRowIndexes
        Task {
            // Memeriksa apakah ada baris yang diklik (indeks valid).
            if clickedRow >= 0 {
                // Jika baris yang diklik termasuk dalam kumpulan baris yang dipilih,
                // ini menandakan pengguna mungkin ingin menghapus foto dari semua baris yang dipilih.
                if selectedRows.contains(clickedRow) {
                    // Panggil `hapusFoto` untuk semua baris yang dipilih.
                    await hapusFoto(selectedRows)
                }
                // Jika baris yang diklik tidak termasuk dalam kumpulan baris yang dipilih,
                // ini menandakan pengguna hanya ingin menghapus foto dari baris yang diklik saja.
                else {
                    // Panggil `hapusFoto` hanya untuk baris yang diklik.
                    await hapusFoto(IndexSet([clickedRow]))
                }
            }
            // Jika tidak ada baris yang diklik (`clickedRow` kurang dari 0),
            // asumsikan operasi ini berlaku untuk semua baris yang dipilih.
            else {
                // Panggil `hapusFoto` untuk semua baris yang dipilih.
                await hapusFoto(selectedRows)
            }
        }
    }
}

// MARK: - TABLEVIEW MENU

extension InventoryView: NSMenuDelegate {
    /// Fungsi yang dijalankan ketika menerima notifikasi dari `.saveData`.
    ///
    /// Menjalankan logika untuk menyiapkan ulang database, memperbarui `data` dari database,
    /// dan memuat ulang seluruh baris di ``tableView``.
    /// - Parameter sender: Objek apapun.
    @objc func saveData(_: Any) {
        guard isDataLoaded else { return }

        Task(priority: .background) { [weak self] in
            guard let self else { return }
            newData.removeAll()

            await manager.setupDatabase()
            await data = manager.loadData()

            await MainActor.run { [weak self] in
                guard let self else { return }
                myUndoManager.removeAllActions()
                updateUndoRedo()
                tableView(tableView, sortDescriptorsDidChange: tableView.sortDescriptors)
            }
        }
    }

    /// Fungsi yang dijalankan ketika menu item `hapus` diklik.
    @objc func hapusMenu(_ sender: NSMenuItem) {
        let klikRow = tableView.clickedRow
        let rows = tableView.selectedRowIndexes
        // jika row yang diklik kanan termasuk dari row yang dipilih(baris yang disorot dengan warna aksen sistem)
        if rows.contains(klikRow) {
            delete(sender)
        }
        // jika row yang diklik kanan tidak termasuk dari row yang dipilih.
        else {
            tableView.selectRowIndexes(IndexSet([klikRow]), byExtendingSelection: false)
            delete(sender)
        }
    }

    /// Membuka antarmuka pengguna untuk mengedit data baris yang dipilih.
    /// Fungsi ini menginisialisasi jendela edit (`CariDanGanti`) dengan data dari baris-baris
    /// yang dipilih di tabel dan daftar kolom yang dapat diedit.
    /// Setelah perubahan data dilakukan di jendela edit, fungsi ini menangani pembaruan
    /// pada model data lokal dan database secara asinkron, sambil memastikan
    /// fungsionalitas undo/redo yang mulus.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol Edit).
    @objc func edit(_: Any) {
        // Membuat instance dari ViewController `CariDanGanti`
        // yang menangani logika pencarian dan penggantian/pengeditan.
        let editVC = CariDanGanti.instantiate()

        // Mengisi `objectData` di `editVC` dengan data dari baris-baris yang dipilih di `tableView`.
        // Iterasi terbalik memastikan urutan data tetap konsisten jika ada perubahan.
        for row in tableView.selectedRowIndexes.reversed() {
            editVC.objectData.append(data[row])
        }

        // Mengisi `columns` di `editVC` dengan nama-nama kolom yang dapat diedit.
        // Kolom "id", "Tanggal Dibuat", dan "Foto" secara eksplisit dikecualikan
        // karena biasanya tidak diedit secara langsung oleh pengguna.
        for column in tableView.tableColumns {
            guard column.identifier.rawValue != "id",
                  column.identifier.rawValue != "Tanggal Dibuat",
                  column.identifier.rawValue != "Foto"
            else { continue } // Lewati kolom-kolom yang tidak boleh diedit.
            editVC.columns.append(column.identifier.rawValue) // Tambahkan nama kolom yang dapat diedit.
        }

        // Menetapkan closure `onUpdate` yang akan dipanggil oleh `editVC` ketika data berhasil diperbarui.
        editVC.onUpdate = { [weak self] updatedRows, selectedColumn in
            // Memastikan `self` (Instance kelas saat ini) masih ada.
            guard let self else { return }

            /*
             `updatedRows` adalah array dari dictionary `[String: Any]`,
             yang berisi data yang telah dimodifikasi dari jendela edit.
             Contoh strukturnya:
             [
             ["id": 123, "Nama Barang": "Buku Tulis (edited)", ...],
             ["id": 456, "Nama Barang": "Pensil (edited)", ...]
             ]
             */

            // Memulai Task asinkron untuk menangani pembaruan database dan model data.
            // Ini menjaga UI tetap responsif selama operasi yang berpotensi memakan waktu.
            Task {
                var undoChanges = [TableChange]() // Array untuk menyimpan perubahan demi fungsionalitas undo.

                // Iterasi melalui setiap baris data yang telah diperbarui dari `editVC`.
                for updatedData in updatedRows {
                    // Memastikan `id` dan `newValue` (nilai baru dari kolom yang diedit) valid.
                    guard let idValue = updatedData["id"] as? Int64,
                          let newValue = updatedData[selectedColumn] as? String
                    else {
                        continue // Lewati jika data tidak valid.
                    }

                    // Perbarui database dengan nilai baru untuk ID dan kolom yang sesuai.
                    await self.manager.updateDatabase(ID: idValue, column: selectedColumn, value: newValue)

                    // Cari indeks baris yang relevan dalam model data lokal (`self.data`).
                    if let rowIndex = self.data.firstIndex(where: { ($0["id"] as? Int64) == idValue }) {
                        // Ambil nilai lama dari kolom sebelum diperbarui, untuk keperluan undo.
                        let oldValue = self.data[rowIndex][selectedColumn]
                        // Tambahkan perubahan ke `undoChanges`.
                        undoChanges.append(TableChange(id: idValue, columnName: selectedColumn, oldValue: oldValue as Any, newValue: newValue as Any))

                        // Perbarui seluruh baris dalam model data lokal dengan `updatedData` yang baru.
                        self.data[rowIndex] = updatedData

                        // Kembali ke `MainActor` untuk memperbarui UI tabel secara spesifik.
                        await MainActor.run {
                            // Muat ulang sel tertentu di `tableView` untuk merefleksikan perubahan.
                            // Ini lebih efisien daripada memuat ulang seluruh tabel.
                            self.tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                        }
                    }
                }

                // Daftarkan operasi undo untuk semua perubahan yang baru saja dilakukan.
                // Saat di-undo, fungsi `urung` akan dipanggil dengan kumpulan `undoChanges`.
                self.myUndoManager.registerUndo(withTarget: self, handler: { inventory in
                    inventory.urung(undoChanges)
                })

                // Kembali ke `MainActor` untuk menampilkan pesan keberhasilan dan memperbarui status undo/redo.
                await MainActor.run {
                    // Tampilkan jendela progres atau notifikasi keberhasilan.
                    ReusableFunc.showProgressWindow(3, pesan: "Pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) ?? ReusableFunc.menuOnStateImage)
                }
            }
        }

        // Menetapkan closure `onClose` yang akan dipanggil saat jendela edit ditutup.
        editVC.onClose = {
            self.updateUndoRedo() // Perbarui status undo/redo setelah jendela ditutup.
        }

        // Menampilkan `editVC` sebagai sheet yang menempel pada jendela utama.
        presentAsSheet(editVC)
        // Mengatur ulang item menu di Menu Bar.
        ReusableFunc.resetMenuItems()
    }

    /// Fungsi yang dijalankan ketika menu item **Buka Foto** diklik.
    ///
    /// Menu item dibuat dari func ``buatMenuItem()``.
    @objc func tampilkanFoto(_: NSMenuItem) {
        let klikRow = tableView.clickedRow
        let rows = tableView.selectedRowIndexes

        // Memeriksa apakah baris yang diklik (`klikRow`) termasuk dalam kumpulan baris yang saat ini dipilih (`rows`),
        // dan memastikan `klikRow` adalah indeks baris yang valid (bukan -1).
        Task {
            if rows.contains(klikRow), klikRow != -1 {
                // Menangani kasus di mana **beberapa baris dipilih dan baris yang diklik adalah salah satunya**.
                // Iterasi melalui setiap baris yang dipilih.
                for row in rows {
                    // Memulai Task asinkron untuk membuka gambar dari setiap baris yang dipilih di jendela pratinjau.
                    // Ini memastikan UI tetap responsif.
                    await openImageInPreview(forRow: row)
                }
            } else if !rows.contains(klikRow), klikRow != -1 {
                // Menangani kasus di mana **baris yang diklik tidak termasuk dalam pilihan yang ada,
                // tetapi merupakan baris yang valid (pemilihan tunggal baru)**.
                // Ini mungkin terjadi ketika pengguna mengklik baris yang tidak dipilih tanpa menekan tombol modifikasi.
                // Membuka gambar hanya untuk baris yang baru saja diklik di jendela pratinjau.
                await openImageInPreview(forRow: klikRow)
            } else {
                // Menangani kasus lain, termasuk skenario di mana `klikRow` adalah -1 (tidak ada baris yang diklik,
                // atau konteks lainnya), atau di mana `rows` tidak berisi `klikRow` tetapi `klikRow` juga -1
                // (kondisi yang mungkin redundan atau perlu klarifikasi lebih lanjut).
                // Dalam kasus ini, semua baris yang saat ini dipilih akan diproses.
                for row in rows {
                    // Memulai Task asinkron untuk membuka gambar dari setiap baris yang dipilih di jendela pratinjau.
                    await openImageInPreview(forRow: row)
                }
            }
        }
    }

    /// Membuka gambar yang terkait dengan baris tertentu di aplikasi Pratinjau macOS.
    /// Fungsi ini mengambil data gambar dari database secara asinkron, menyimpannya ke file sementara,
    /// dan kemudian meluncurkan aplikasi Pratinjau untuk menampilkan gambar tersebut.
    /// Penanganan kesalahan disertakan untuk kasus di mana gambar tidak dapat dimuat atau dibuka.
    ///
    /// - Parameter row: `Int` yang menunjukkan indeks baris di `NSTableView` yang gambarnya ingin dibuka.
    func openImageInPreview(forRow row: Int) async {
        // Memastikan baris yang diberikan valid dan memiliki "id" yang dapat diakses sebagai Int64.
        guard let id = data[row]["id"] as? Int64 else { return }

        // Membuat direktori sementara untuk menyimpan file gambar.
        // Ini memastikan gambar disimpan di lokasi yang aman dan dapat diakses sementara.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TempImages", isDirectory: true)

        do {
            // Coba buat direktori sementara jika belum ada.
            // `withIntermediateDirectories: true` akan membuat direktori induk yang diperlukan.
            try FileManager.default.createDirectory(at: tempDir,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)

            // Membuat nama file unik untuk gambar.
            // Nama file menggunakan "Nama Barang" (jika ada) dan UUID untuk menghindari konflik.
            let filename = "\(data[row]["Nama Barang"] ?? "Foto")-\(UUID().uuidString).png"
            let trimmedNama = filename.replacingOccurrences(of: "/", with: "-")
            // Menggabungkan direktori sementara dengan nama file untuk mendapatkan URL file lengkap.
            let fileURL = tempDir.appendingPathComponent(trimmedNama)

            // Mengambil data gambar (Data) dari database menggunakan `manager.getImage(id)`.
            let imageData = await manager.getImage(id)

            // Menulis data gambar ke file sementara.
            try imageData.write(to: fileURL)

            // Mendapatkan URL untuk aplikasi Pratinjau (Preview.app) menggunakan bundle identifier.
            if let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
                // Membuat objek konfigurasi opsional untuk membuka aplikasi.
                let configuration = NSWorkspace.OpenConfiguration()

                // Membuka file gambar dengan aplikasi Pratinjau.
                // Closure completion akan dipanggil setelah operasi selesai.
                NSWorkspace.shared.open([fileURL], withApplicationAt: previewAppURL, configuration: configuration) { app, error in
                    // Jika aplikasi berhasil dibuka, cetak pesan debug (hanya di mode DEBUG).
                    if let app {
                        #if DEBUG
                            print("File opened successfully in \(app.localizedName ?? "Preview").")
                        #endif
                    } else if let error {
                        // Jika terjadi kesalahan saat membuka file, tampilkan peringatan di antrean utama.
                        DispatchQueue.main.async {
                            ReusableFunc.showAlert(title: "Error", message: error.localizedDescription)
                        }
                    }
                }
            }
        } catch {
            // Menangani kesalahan yang terjadi selama proses (misalnya, gagal membuat direktori, gagal menulis file).
            // Tampilkan `NSAlert` untuk memberi tahu pengguna tentang masalah tersebut.
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            // Tampilkan alert sebagai sheet modal yang melekat pada jendela utama.
            alert.beginSheetModal(for: view.window ?? NSWindow()) { _ in }
        }
    }

    /// Menangani aksi untuk menyimpan foto, baik untuk baris tunggal yang diklik maupun beberapa baris yang dipilih.
    /// Fungsi ini memeriksa konteks pemilihan baris di `NSTableView` untuk menentukan
    /// apakah akan memicu penyimpanan foto untuk satu baris (berdasarkan klik) atau beberapa baris (berdasarkan seleksi).
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu atau tombol).
    @objc func simpanFoto(_: Any) {
        Task {
            // Memeriksa apakah ada baris yang diklik (`tableView.clickedRow != -1`).
            if tableView.clickedRow != -1 {
                // Kondisi pertama: Jika baris yang diklik termasuk dalam baris yang dipilih,
                // dan ada setidaknya satu baris yang dipilih yang valid dalam batas data.
                if tableView.selectedRowIndexes.contains(tableView.clickedRow), let selectedRow = tableView.selectedRowIndexes.first,
                   selectedRow < data.count
                {
                    // Memanggil fungsi untuk menangani penyimpanan foto untuk beberapa baris yang dipilih.
                    await simpanMultipleFoto(tableView.selectedRowIndexes)
                }
                // Kondisi kedua: Jika baris yang diklik TIDAK termasuk dalam baris yang dipilih.
                else if !tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                    // Memulai `Task` asinkron untuk menangani penyimpanan foto untuk baris tunggal yang diklik.
                    // Ini menjaga UI tetap responsif.
                    await simpanMultipleFoto(IndexSet(integer: tableView.clickedRow))
                }
            }
            // Kondisi ketiga: Jika tidak ada baris yang diklik (`tableView.clickedRow == -1`),
            // tetapi ada setidaknya satu baris yang dipilih (`tableView.numberOfSelectedRows >= 1`).
            else if tableView.numberOfSelectedRows >= 1 {
                // Memanggil fungsi untuk menangani penyimpanan foto untuk beberapa baris yang dipilih.
                await simpanMultipleFoto(tableView.selectedRowIndexes)
            }
            // Kondisi default: Jika tidak ada baris yang diklik maupun dipilih, tidak ada aksi yang dilakukan.
            else {
                return
            }
        }
    }

    /// Menyimpan beberapa foto dari baris yang dipilih di tabel ke folder yang ditentukan oleh pengguna.
    /// Fungsi ini pertama-tama meminta pengguna untuk memilih direktori penyimpanan.
    /// Setelah folder dipilih, ia secara asinkron mengambil data foto untuk setiap baris yang dipilih dari database,
    /// dan menyimpannya sebagai file terpisah di folder yang dipilih.
    ///
    /// - Parameter rows: Baris di tableView yang akan digunakan untuk menyalin foto jika ada.
    @objc func simpanMultipleFoto(_ rows: IndexSet) async {
        guard rows.count > 0 else {
            // Tampilkan pesan jika tidak ada baris yang dipilih
            ReusableFunc.showAlert(title: "Perhatian", message: "Pilih setidaknya satu baris untuk menyimpan foto.")
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Pilih Folder Penyimpanan Foto"
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Simpan"
        let result = await openPanel.beginSheetModal(for: view.window!)
        guard result == .OK, let selectedFolderURL = openPanel.url else {
            return
        }

        // Jalankan seluruh proses penyimpanan dalam Task utama agar kita bisa menggunakan await
        // dan menunggu semua sub-task selesai.
        var successfulSaves = 0
        var failedSaves = 0
        var errorMessages: [String] = []

        await withTaskGroup(of: Void.self) { [weak self] group in // Gunakan TaskGroup untuk mengelola banyak Task
            guard let self else { return }
            for selectedRow in rows {
                // Pastikan indeks baris valid
                guard selectedRow < data.count else {
                    failedSaves += 1
                    continue
                }

                let id = data[selectedRow]["id"] as? Int64 ?? -1
                let namaBarang = data[selectedRow]["Nama Barang"] as? String ?? ""

                // Pastikan ID valid
                guard id != -1 else {
                    failedSaves += 1
                    errorMessages.append("Gagal mendapatkan ID untuk baris ke-\(selectedRow + 1).")
                    continue
                }

                // Tambahkan setiap operasi penyimpanan ke dalam TaskGroup
                group.addTask {
                    let fotoData = await self.manager.getImage(id)

                    guard fotoData.count > 0,
                          let pngFoto = NSImage(data: fotoData)?.pngRepresentation
                    else {
                        await MainActor.run {
                            failedSaves += 1
                            errorMessages.append("Gagal mengambil atau mengonversi foto untuk \(namaBarang) (ID: \(id)).")
                        }
                        return
                    }

                    let trimmedNama = namaBarang.replacingOccurrences(of: "/", with: "-")
                    let saveURL = selectedFolderURL.appendingPathComponent("\(id)_\(trimmedNama).png")

                    do {
                        try pngFoto.write(to: saveURL)

                        await MainActor.run {
                            successfulSaves += 1
                        }
                    } catch {
                        await MainActor.run {
                            failedSaves += 1
                            errorMessages.append("Gagal menyimpan foto '\(namaBarang)' (ID: \(id)): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        // Setelah semua Task dalam group selesai, tampilkan rangkuman
        await MainActor.run {
            let totalSelected = rows.count
            var message = ""
            var informativeText = ""
            var alertStyle = NSAlert.Style.informational

            if successfulSaves == totalSelected {
                message = "Penyimpanan Foto Selesai"
                informativeText = "\(successfulSaves) foto berhasil disimpan."
            } else if successfulSaves > 0, failedSaves > 0 {
                message = "Penyimpanan Foto Selesai dengan Beberapa Masalah"
                informativeText = "Berhasil menyimpan \(successfulSaves) dari \(totalSelected) foto. \(failedSaves) foto gagal disimpan."
                alertStyle = .warning
                if !errorMessages.isEmpty {
                    informativeText += "\nDetail kesalahan:\n" + errorMessages.joined(separator: "\n")
                }
            } else {
                message = "Penyimpanan Foto Gagal"
                informativeText = "Tidak ada foto yang berhasil disimpan. \(failedSaves) foto gagal."
                alertStyle = .critical
                if !errorMessages.isEmpty {
                    informativeText += "\nDetail kesalahan:\n" + errorMessages.joined(separator: "\n")
                }
            }

            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informativeText
            alert.alertStyle = alertStyle
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
    }

    /// Menyalin data dari baris yang dipilih atau yang diklik di tabel ke papan klip sistem.
    /// Fungsi ini menentukan apakah operasi penyalinan harus berdasarkan multi-seleksi
    /// atau hanya pada baris yang terakhir diklik jika tidak termasuk dalam seleksi aktif.
    ///
    /// - Parameter sender: Objek yang memicu aksi ini (misalnya, item menu konteks atau tombol).
    @objc func salinData(_: Any) {
        // Mendapatkan indeks baris yang saat ini dipilih di `tableView`.
        let rows = tableView.selectedRowIndexes
        // Mendapatkan indeks baris yang terakhir diklik di `tableView`.
        let klikRow = tableView.clickedRow

        // Memeriksa apakah baris yang diklik termasuk dalam baris yang saat ini dipilih.
        if rows.contains(klikRow) {
            // Jika baris yang diklik sudah termasuk dalam seleksi, lanjutkan dengan menyalin
            // semua baris yang dipilih. Memastikan ada baris yang dipilih.
            guard rows.count > 0 else { return }
            ReusableFunc.salinBaris(rows, from: tableView)
        }
        // Jika tidak ada baris yang diklik (klikRow adalah -1), tetapi ada baris yang dipilih.
        else if klikRow == -1 {
            // Lanjutkan dengan menyalin semua baris yang dipilih. Memastikan ada baris yang dipilih.
            guard rows.count > 0 else { return }
            ReusableFunc.salinBaris(rows, from: tableView)
        }
        // Jika baris yang diklik tidak termasuk dalam baris yang dipilih,
        // dan `klikRow` adalah baris yang valid (bukan -1).
        else {
            // Salin hanya data dari baris yang diklik. Memastikan `klikRow` valid.
            guard klikRow != -1 else { return }
            ReusableFunc.salinBaris(IndexSet([klikRow]), from: tableView) // Mengubah `[klikRow]` menjadi `IndexSet([klikRow])` agar sesuai dengan parameter.
        }
    }

    /// Menghapus data foto yang terkait dengan baris-baris yang dipilih di tabel.
    /// Fungsi ini memperbarui model data lokal dan database secara asinkron untuk menghapus foto,
    /// lalu memperbarui UI tabel untuk merefleksikan perubahan. Ini juga mendukung fungsionalitas undo/redo.
    ///
    /// - Parameter row: `IndexSet` yang berisi indeks baris-baris yang fotonya akan dihapus.
    @objc func hapusFoto(_ row: IndexSet) async {
        // Memulai pembaruan batch untuk `tableView` untuk kinerja yang lebih baik.
        tableView.beginUpdates()
        // Memulai kelompok undo. Semua operasi undo yang didaftarkan di dalam blok ini
        // akan dianggap sebagai satu tindakan undo.
        myUndoManager.beginUndoGrouping()

        // Iterasi melalui setiap indeks baris yang dipilih dalam `IndexSet` yang diberikan.
        for selectedRow in row {
            // Memastikan `selectedRow` berada dalam batas array `data` (model lokal).
            guard selectedRow < data.count else { return }
            // Mendapatkan ID dari baris yang dipilih. Jika tidak ada ID, lewati baris ini.
            guard let id = data[selectedRow]["id"] as? Int64 else { return }

            // Mencari indeks baris (lagi) berdasarkan ID. Ini mungkin redundan jika `selectedRow`
            // sudah valid, tetapi memastikan data yang benar jika ada pengurutan atau perubahan lain.
            if let actualRowIndex = findRowIndex(forId: id) {
                // Menyimpan `newImage` (sebenarnya `oldImage` atau `currentImage`) sebelum menghapus.
                // Ini penting untuk operasi undo. Jika tidak ada gambar, gunakan `Data()` kosong.
                let newImage = await manager.getImage(id)

                // Memanggil `manager.hapusImage(id)` untuk menghapus gambar dari database.
                await manager.hapusImage(id)

                // Kembali ke `MainActor` untuk melakukan pembaruan UI.
                await MainActor.run { [weak self] in
                    guard let self else { return } // Memastikan `self` masih ada.

                    // Mendapatkan indeks kolom "Nama Barang" di tabel.
                    let columnIndexNamaBarang = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Nama Barang"))
                    // Jika sel untuk "Nama Barang" ditemukan, perbarui gambar sel menjadi "pensil" (placeholder).
                    if let cell = tableView.view(atColumn: columnIndexNamaBarang, row: actualRowIndex, makeIfNecessary: false) as? NSTableCellView {
                        cell.imageView?.image = NSImage(named: "pensil")
                    }

                    // Mendapatkan indeks kolom "Foto" di tabel.
                    let columnIndexOfFoto = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Foto"))
                    // Jika sel untuk "Foto" ditemukan, perbarui teksnya menjadi "0.00 MB" (menunjukkan tidak ada foto).
                    if let cell = tableView.view(atColumn: columnIndexOfFoto, row: actualRowIndex, makeIfNecessary: false) as? NSTableCellView {
                        cell.textField?.stringValue = "0.00 MB"
                    }

                    // Mendaftarkan operasi undo untuk penghapusan foto ini.
                    // Saat di-undo, `redoReplaceImage` akan dipanggil dengan ID dan data gambar yang lama
                    // untuk mengembalikan foto tersebut.
                    myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
                        self?.redoReplaceImage(id, imageData: newImage)
                    })
                }
            }
        }
        // Mengakhiri kelompok undo.
        myUndoManager.endUndoGrouping()
        // Mengakhiri pembaruan batch untuk `tableView`, memicu pembaruan visual.
        tableView.endUpdates()
        // Memperbarui status tombol undo/redo di UI.
        updateUndoRedo()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menu)
        }
        view.window?.makeFirstResponder(tableView)
    }
}
