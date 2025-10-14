//
//  TransaksiMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa

extension TransaksiView: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarGroupMenu {
            updateToolbarGroupMenu(toolbarGroupMenu)
            return
        }

        if menu == toolbarMenu {
            if let filterItem = toolbarMenu.items
                .first(where: { $0.identifier?.rawValue == "filterTahunItem" })
            {
                filterItem.isHidden = !isGrouped
            }
        }

        if !data.isEmpty,
           let tahunMenu = tahunPopUp.menu,
           menu == tahunMenu
        {
            Task(priority: .background) { [weak self] in
                await self?.loadTahunList()
            }
            return
        }
    }

    /// Fungsi ini bertanggung jawab untuk memperbarui tampilan dan status item-item dalam NSMenu yang digunakan sebagai menu toolbar atau konteks, khususnya yang berkaitan dengan opsi pengelompokan dan pengurutan data transaksi. Ini menyesuaikan visibilitas dan status centang (on/off) item menu berdasarkan mode tampilan saat ini (isGrouped), filter yang aktif (jenis), dan item-item yang terpilih di collectionView.
    func updateToolbarGroupMenu(_ menu: NSMenu) {
        // Dapatkan indeks item yang saat ini terpilih di collectionView.
        let selectedIndexPaths = collectionView.selectionIndexPaths

        // Temukan item menu "Catat Transaksi" dan pastikan itu terlihat.
        let catat = menu.item(withTitle: "Catat Transaksi")
        catat?.isHidden = false

        // Pastikan item menu "Urutkan Menurut" dan "Kelompokkan Menurut" ada. Jika tidak, keluar dari fungsi.
        guard let urutkan = menu.items.first(where: { $0.title == "Urutkan Menurut" }),
              let kolompok = menu.items.first(where: { $0.title == "Kelompokkan Menurut" }) else { return }

        // MARK: - Logika untuk Mode Pengelompokan (isGrouped)

        if isGrouped {
            // Jika data dikelompokkan, tampilkan item menu "Urutkan Menurut".
            urutkan.isHidden = false

            // Atur status centang untuk submenu "Kelompokkan Menurut"
            // Item yang judulnya cocok dengan `selectedGroup` akan dicentang.
            for itemInSubmenu in kolompok.submenu!.items {
                itemInSubmenu.state = (itemInSubmenu.title.lowercased() == selectedGroup) ? .on : .off
            }

            // Batalkan semua status centang untuk item menu utama di `menu` ini terlebih dahulu.
            for item in menu.items {
                item.state = .off
            }

            // Atur status centang untuk item "Gunakan Grup" di menu ini berdasarkan `isGrouped`.
            if let useGroupItem = menu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.state = isGrouped ? .on : .off
            }

            // Atur status centang untuk submenu "Urutkan Menurut"
            // Item yang judulnya cocok dengan `currentSortOption` akan dicentang.
            for itemInSubmenu in urutkan.submenu!.items {
                itemInSubmenu.state = (itemInSubmenu.title.lowercased() == currentSortOption) ? .on : .off
            }

        } else {
            // Jika data tidak dikelompokkan, sembunyikan item menu "Urutkan Menurut".
            urutkan.isHidden = true
            // Batalkan semua status centang untuk item menu utama.
            for item in menu.items {
                item.state = .off
            }
            // Batalkan semua status centang untuk submenu "Kelompokkan Menurut".
            for itemInSubmenu in kolompok.submenu!.items {
                itemInSubmenu.state = .off
            }
        }

        // MARK: - Logika untuk Item Menu Aksi (Edit, Hapus, Salin, Tandai)

        // Jika tidak ada item yang terpilih di `collectionView`:
        guard selectedIndexPaths.count >= 1 else {
            // Sembunyikan item menu "Edit", "Hapus", "Salin", dan "Tandai".
            let edit = menu.items.first(where: { $0.identifier?.rawValue == "editItem" })
            edit?.isHidden = true
            let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapusItem" })
            hapus?.isHidden = true
            let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
            salin?.isHidden = true
            let tandai = menu.items.first(where: { $0.identifier?.rawValue == "tandaiItem" })
            tandai?.isHidden = true

            // Jika ada filter jenis yang aktif, sembunyikan juga opsi grup.
            if jenis != nil {
                if let useGroupItem = menu.items.first(where: { $0.title == "Gunakan Grup" }) {
                    useGroupItem.isHidden = true
                }
                if let groupByCategoryItem = menu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                    groupByCategoryItem.isHidden = true
                }
            } else {
                // Jika tidak ada filter jenis aktif, tampilkan kembali opsi grup.
                if let useGroupItem = menu.items.first(where: { $0.title == "Gunakan Grup" }) {
                    useGroupItem.isHidden = false
                }
                if let groupByCategoryItem = menu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                    groupByCategoryItem.isHidden = false
                }
            }
            return // Keluar dari fungsi karena tidak ada item yang terpilih.
        }

        // Jika ada item yang terpilih:
        let tandai = menu.items.first(where: { $0.identifier?.rawValue == "tandaiItem" })
        tandai?.isHidden = false // Pastikan item "Tandai" terlihat.

        // Duplikasi logika visibilitas grup berdasarkan filter jenis.
        // Ini memastikan bahwa visibilitas opsi grup diperbarui dengan benar
        // bahkan ketika ada item yang terpilih.
        if jenis != nil {
            if let useGroupItem = menu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.isHidden = true
            }
            if let groupByCategoryItem = menu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                groupByCategoryItem.isHidden = true
            }
        } else {
            if let useGroupItem = menu.items.first(where: { $0.title == "Gunakan Grup" }) {
                useGroupItem.isHidden = false
            }
            if let groupByCategoryItem = menu.items.first(where: { $0.title == "Kelompokkan Menurut" }) {
                groupByCategoryItem.isHidden = false
            }
        }

        // MARK: - Menentukan Status 'Ditandai' untuk Item yang Dipilih

        var isDitandai = false
        if selectedIndexPaths.count == 1 {
            // Logika yang sama seperti di `updateItemMenu()` untuk menentukan status 'ditandai'
            // untuk satu item yang terpilih.
            if UserDefaults.standard.grupTransaksi {
                let sortedSectionKeys = groupedData.keys.sorted()
                let sectionIndex = selectedIndexPaths.first!.section
                let itemIndex = selectedIndexPaths.first!.item
                let jenisTransaksi = sortedSectionKeys[sectionIndex]
                if let entities = groupedData[jenisTransaksi], itemIndex < entities.count {
                    let entity = entities[itemIndex]
                    isDitandai = entity.ditandai
                }
            } else {
                let itemIndex = selectedIndexPaths.first!.item
                let entity = data[itemIndex]
                isDitandai = entity.ditandai
            }
        } else if selectedIndexPaths.count > 1 {
            // Logika yang sama seperti di `updateItemMenu()` untuk menentukan status 'ditandai'
            // untuk banyak item yang terpilih (semua harus ditandai agar `isDitandai` menjadi `true`).
            isDitandai = selectedIndexPaths.allSatisfy { indexPath in
                if UserDefaults.standard.grupTransaksi {
                    let sortedSectionKeys = groupedData.keys.sorted()
                    let sectionIndex = indexPath.section
                    let itemIndex = indexPath.item
                    let jenisTransaksi = sortedSectionKeys[sectionIndex]
                    if let entities = groupedData[jenisTransaksi] {
                        return entities[itemIndex].ditandai
                    }
                    return false
                } else {
                    return data[indexPath.item].ditandai
                }
            }
        }

        // MARK: - Memperbarui Judul Item Menu Aksi

        // Temukan item menu "Edit", "Hapus", dan "Salin" dan perbarui judul serta visibilitasnya
        // berdasarkan jumlah item yang terpilih.
        if let editItem = menu.items.first(where: { $0.identifier?.rawValue == "editItem" }),
           let deleteItem = menu.items.first(where: { $0.identifier?.rawValue == "hapusItem" }),
           let copyItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
        {
            editItem.title = "Edit \(collectionView.selectionIndexPaths.count) data..."
            editItem.isHidden = false
            deleteItem.title = "Hapus \(collectionView.selectionIndexPaths.count) data..."
            deleteItem.isHidden = false
            copyItem.title = "Salin \(collectionView.selectionIndexPaths.count) data..."
            copyItem.isHidden = false
        }

        // Perbarui judul item menu "Tandai" berdasarkan status `isDitandai`.
        let tandaiTitle = isDitandai ? "Hapus \(collectionView.selectionIndexPaths.count) Tanda" : "Tandai \(collectionView.selectionIndexPaths.count) data..."
        tandai?.title = tandaiTitle
    }

    /// Fungsi buatGroupMenu() ini bertanggung jawab untuk membuat dan mengonfigurasi sebuah NSMenu yang dirancang khusus untuk digunakan sebagai menu konteks atau menu toolbar yang berkaitan dengan tampilan data yang dikelompokkan. Menu ini menggabungkan elemen-elemen dari menu yang sudah ada, yaitu itemMenu dan groupMenu, untuk menyediakan serangkaian opsi yang komprehensif saat beroperasi dalam tampilan grup.
    func buatGroupMenu() -> NSMenu {
        let menu = NSMenu() // Buat instance NSMenu baru yang kosong.

        // MARK: - Menambahkan Item "foto" (Tersembunyi Secara Default)

        // Buat item menu dengan judul "foto".
        let photoMenuItem = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        photoMenuItem.image = ReusableFunc.largeActionImage
        photoMenuItem.isHidden = true // Sembunyikan item ini secara default.
        menu.addItem(photoMenuItem) // Tambahkan item "foto" ke menu baru.

        // MARK: - Menduplikasi Menu yang Ada

        // Buat salinan (deep copy) dari `itemMenu`. Ini memastikan bahwa perubahan pada `selectedMenu`
        // tidak memengaruhi `itemMenu` yang asli. `itemMenu` kemungkinan berisi aksi-aksi untuk item yang terpilih
        // seperti Edit, Hapus, Salin.
        let selectedMenu = itemMenu.copy() as! NSMenu
        // Buat salinan (deep copy) dari `self.groupMenu`. Ini memastikan bahwa perubahan pada `groupMenu`
        // tidak memengaruhi `self.groupMenu` yang asli. `groupMenu` kemungkinan berisi opsi-opsi terkait pengelompokan.
        filterTahun.identifier = NSUserInterfaceItemIdentifier("filterTahunItem")
        if !groupMenu.items.contains(filterTahun) {
            groupMenu.insertItem(filterTahun, at: groupMenu.items.count - 3)
        }
        let groupMenu = groupMenu.copy() as! NSMenu

        // MARK: - Mengisi Menu Baru

        // Tambahkan semua item dari `groupMenu` yang telah disalin ke `menu` baru.
        // Setiap item disalin lagi untuk memastikan kemandirian penuh.
        groupMenu.items.forEach { menu.addItem($0.copy() as! NSMenuItem) }

        // Tambahkan pemisah untuk membagi bagian menu secara visual.
        menu.addItem(NSMenuItem.separator())

        // Tambahkan semua item dari `selectedMenu` yang telah disalin ke `menu` baru.
        // Setiap item disalin lagi.
        selectedMenu.items.forEach { menu.addItem($0.copy() as! NSMenuItem) }

        return menu // Kembalikan menu yang baru saja dibangun.
    }
}
