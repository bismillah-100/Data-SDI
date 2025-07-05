//
//  SiswaViewMenu.swift
//  Data SDI
//
//  Created by Bismillah on 11/12/24.
//

import Cocoa

extension SiswaViewController {
    func menuDidClose(_ menu: NSMenu) {
        for item in menu.items {
            guard item.title != "Image" else {
                continue
            }
            item.isHidden = false
        }
        if customViewMenu != nil {
            for subview in customViewMenu.subviews {
                if let tagControl = subview as? TagControl {
                    // Check if the tag corresponds to the current active class
                    tagControl.isSelected = false
                    tagControl.unselected = false
                    tagControl.multipleItem = false
                }
            }
        }
        if customViewMenu != nil {
            for subview in customViewMenu2.subviews {
                if let tagControl = subview as? TagControl {
                    // Check if the tag corresponds to the current active class
                    tagControl.isSelected = false
                    tagControl.unselected = false
                    tagControl.multipleItem = false
                }
            }
        }
        if let activeWindow = NSApp.keyWindow {
            if let splitViewController = activeWindow.contentViewController as? SplitVC {
                AppDelegate.shared.updateUndoRedoMenu(for: splitViewController)
            } else if (activeWindow.windowController as? DetilWindow) != nil {
                let viewController = activeWindow.contentViewController as? DetailSiswaController
                AppDelegate.shared.updateUndoRedoMenu(for: viewController ?? DetailSiswaController())
            } else {
                ReusableFunc.resetMenuItems()
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == itemSelectedMenu {
            updateMenu(itemSelectedMenu)
        } else {
            updateTableMenu(menu)
        }
        view.window?.makeFirstResponder(tableView)
    }

    /**
         Memperbarui tampilan menu berdasarkan status dan mode tampilan tabel saat ini.

         Fungsi ini mengonfigurasi visibilitas dan status item menu berdasarkan apakah baris tabel telah diklik atau dipilih,
         mode tampilan tabel (dikelompokkan atau biasa), dan status siswa (misalnya, berhenti atau lulus).
         Ini juga menyesuaikan judul item menu berdasarkan jumlah baris yang dipilih.

         - Parameter:
             - menu: NSMenu yang akan diperbarui.
     */
    func updateTableMenu(_ menu: NSMenu) {
        var siswa: ModelSiswa!
        let nonItemMenu: IndexSet = [1, 3, 4, 6, 7, 9, 10, 24, 25]
        let groupTableItem = menu.items.first(where: { $0.identifier?.rawValue == "kelasMode" })
        groupTableItem?.tag = currentTableViewMode == .grouped ? 0 : 1
        groupTableItem?.state = currentTableViewMode == .grouped ? .on : .off

        let siswaBerhenti = menu.items.first(where: { $0.title.lowercased() == "sertakan siswa berhenti" })
        siswaBerhenti?.state = isBerhentiHidden ? .off : .on

        let siswaLulus = menu.items.first(where: { $0.title.lowercased() == "sertakan siswa lulus" })
        siswaLulus?.state = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") ? .on : .off
        siswaLulus?.isHidden = currentTableViewMode == .grouped

        let ubahData = menu.items.first(where: { $0.identifier?.rawValue == "ubahData" })

        let detailItem = menu.items.first(where: { $0.identifier?.rawValue == "detail" })
        let altColor = menu.items.first(where: { $0.title.lowercased() == "gunakan warna alternatif" })
        altColor?.state = useAlternateColor ? .on : .off
        let lihatFoto = menu.items.first(where: { $0.identifier?.rawValue == "lihatFoto" })
        if tableView.clickedRow == -1 {
            for item in nonItemMenu {
                menu.item(at: item)?.isHidden = false
            }
            detailItem?.isHidden = true

            let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
            hapusitem?.isHidden = true

            let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
            editItem?.isHidden = true

            ubahData?.isHidden = true

            lihatFoto?.isHidden = true

            let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
            salinItem?.isHidden = true

            let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
            excelItem?.isHidden = false

            let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
            tempelItem?.isHidden = false

            let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
            pdfItem?.isHidden = false

            let statusMenu = menu.items.first(where: { $0.title == "Status Siswa" })

            if let statusMenuItem = menu.items.first(where: { $0.submenu == statusMenu }) {
                statusMenuItem.isHidden = true // Menyembunyikan menu utama beserta submenu-nya
            }
            statusMenu?.isHidden = true
            if menu.items.contains(tagMenuItem) {
                menu.removeItem(tagMenuItem)
            }
        } else {
            let clickedRow = tableView.clickedRow
            if currentTableViewMode == .plain {
                siswa = viewModel.filteredSiswaData[clickedRow]
            } else if currentTableViewMode == .grouped {
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                if selectedRowInfo.isGroupRow {
                    for item in menu.items {
                        item.isHidden = true
                    }
                    // Check if the tagMenuItem exists in the menu before removing it
                    if let itemToRemove = menu.items.first(where: { $0.identifier?.rawValue == "kelasAktif" }) {
                        menu.removeItem(itemToRemove)
                    }
                    return
                }
                if groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count {
                    siswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                }
            }
            for item in nonItemMenu {
                menu.item(at: item)?.isHidden = true
            }
            // For cells that need context menu, add necessary menu items
            let selectedRowsCount = tableView.selectedRowIndexes.count
            // Periksa mode tabel saat ini
            if currentTableViewMode == .plain {
                let selectedRow = tableView.clickedRow
                if tableView.clickedRow >= 0, !tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                    siswa = viewModel.filteredSiswaData[tableView.clickedRow]
                    for subview in customViewMenu.subviews {
                        if let tagControl = subview as? TagControl {
                            // Check if the tag corresponds to the current active class
                            if tagControl.kelasValue == siswa.kelasSekarang.rawValue {
                                tagControl.isSelected = true
                            } else {
                                tagControl.isSelected = false
                            }
                        }
                    }
                } else {
                    for row in tableView.selectedRowIndexes {
                        siswa = viewModel.filteredSiswaData[row]
                        for subview in customViewMenu.subviews {
                            if let tagControl = subview as? TagControl {
                                // Check if the tag corresponds to the current active class
                                if tagControl.kelasValue == siswa.kelasSekarang.rawValue {
                                    tagControl.isSelected = true
                                    if selectedRowsCount > 1 {
                                        tagControl.multipleItem = true
                                    } else {
                                        tagControl.multipleItem = false
                                    }
                                }
                            }
                        }
                    }
                }
                var copyItemTitle = "Salin Data \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
                var hapusTitle = "Hapus \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
                var editTitle = "Edit Data"
                var ubahTitle = "Ubah Data"
                var rincianTitle = "Rincian Siswa"
                var lihatFotoTitle = "Lihat Foto \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
                if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
                    if selectedRowsCount > 1, tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                        // Handle clicked row that is not in selected indexes
                        copyItemTitle = "Salin \(selectedRowsCount) data..."
                        hapusTitle = "Hapus \(selectedRowsCount) data..."
                        editTitle = "Edit \(selectedRowsCount) data..."
                        ubahTitle = "Ubah \(selectedRowsCount) data..."
                        rincianTitle = "Rincian \(selectedRowsCount) siswa..."
                        lihatFotoTitle = "Lihat Foto \(selectedRowsCount) siswa..."
                    }
                }
                detailItem?.isHidden = false
                detailItem?.title = rincianTitle

                let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
                hapusitem?.title = hapusTitle
                hapusitem?.isHidden = false

                let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
                editItem?.title = editTitle
                editItem?.isHidden = false

                ubahData?.title = ubahTitle
                ubahData?.isHidden = false

                lihatFoto?.isHidden = false
                lihatFoto?.title = lihatFotoTitle

                let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
                salinItem?.title = copyItemTitle
                salinItem?.isHidden = false

                let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
                tempelItem?.isHidden = true

                let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
                excelItem?.isHidden = true

                let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
                pdfItem?.isHidden = true

                if let statusMenuItem = menu.items.first(where: { $0.title == "Status Siswa" }) {
                    statusMenuItem.isHidden = false
                    if let submenu = statusMenuItem.submenu {
                        for menuItem in submenu.items {
                            if let representedStatus = menuItem.representedObject as? String {
                                menuItem.state = (representedStatus == siswa.status.rawValue) ? .on : .off
                            } else {
                                menuItem.state = .off
                            }
                        }
                    }
                }
                if menu.items.first(where: { $0.identifier?.rawValue == "kelasAktif" }) == nil {
                    menu.insertItem(tagMenuItem, at: 21)
                }
            } else {
                // Dapatkan informasi baris yang diklik
                let selectedRowInfo = getRowInfoForRow(tableView.clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                // Pastikan indeks valid sebelum mengakses data siswa
                guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                    return
                }

                // Ambil objek siswa dari viewModel.groupedSiswa
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                // Atur judul item menu "Salin" dan "Hapus"
                var copyItemTitle = "Salin Data \"\(selectedSiswa.nama)\""
                var hapusTitle = "Hapus \"\(selectedSiswa.nama)\""
                var editTitle = "Edit Data"
                var ubahTitle = "Ubah Data"
                var rincianTitle = "Rincian Siswa"
                var lihatFotoTitle = "Lihat Foto \"\(selectedSiswa.nama)\""
                if selectedRowsCount > 1, tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                    copyItemTitle = "Salin \(selectedRowsCount) data..."
                    hapusTitle = "Hapus \(selectedRowsCount) data..."
                    editTitle = "Edit \(selectedRowsCount) data..."
                    ubahTitle = "Ubah \(selectedRowsCount) data..."
                    rincianTitle = "Rincian \(selectedRowsCount) siswa..."
                    lihatFotoTitle = "Lihat Foto \(selectedRowsCount) siswa..."
                }
                detailItem?.isHidden = false
                detailItem?.title = rincianTitle

                let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
                hapusitem?.title = hapusTitle
                hapusitem?.isHidden = false

                let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
                editItem?.title = editTitle
                editItem?.isHidden = false

                ubahData?.title = ubahTitle
                ubahData?.isHidden = false

                lihatFoto?.title = lihatFotoTitle
                lihatFoto?.isHidden = false

                let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
                salinItem?.title = copyItemTitle
                salinItem?.isHidden = false

                let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
                excelItem?.isHidden = true

                let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
                pdfItem?.isHidden = true

                let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
                tempelItem?.isHidden = true

                let statusMenu = menu.items.first(where: { $0.title == "Status Siswa" })
                statusMenu?.isHidden = true

                menu.removeItem(tagMenuItem)
            }
        }
    }

    /// Fungsi updateMenu bertanggung jawab untuk memperbarui tampilan dan status item-item dalam NSMenu (menu konteks) di toolbar berdasarkan kondisi aplikasi saat ini, seperti mode tampilan tabel (currentTableViewMode), status filter, dan jumlah baris yang dipilih di NSTableView.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateMenu(_ menu: NSMenu) {
        let groupTableItem = menu.items.first(where: { $0.identifier?.rawValue == "kelasMode" })

        let siswaBerhenti = menu.items.first(where: { $0.title.lowercased() == "sertakan siswa berhenti" })
        siswaBerhenti?.state = isBerhentiHidden ? .off : .on

        let siswaLulus = menu.items.first(where: { $0.title.lowercased() == "sertakan siswa lulus" })
        siswaLulus?.state = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") ? .on : .off
        siswaLulus?.isHidden = currentTableViewMode == .grouped

        let ubahData = menu.items.first(where: { $0.identifier?.rawValue == "ubahData" })
        groupTableItem?.tag = currentTableViewMode == .grouped ? 0 : 1
        groupTableItem?.state = currentTableViewMode == .grouped ? .on : .off
        let altColor = menu.items.first(where: { $0.title.lowercased() == "gunakan warna alternatif" })
        altColor?.state = useAlternateColor ? .on : .off
        let detailItem = menu.items.first(where: { $0.identifier?.rawValue == "detail" })
        let lihatFoto = menu.items.first(where: { $0.identifier?.rawValue == "lihatFoto" })
        guard tableView.numberOfSelectedRows >= 1 else {
            detailItem?.isHidden = true

            let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
            hapusitem?.isHidden = true

            let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
            editItem?.isHidden = true

            ubahData?.isHidden = true

            lihatFoto?.isHidden = true

            let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
            salinItem?.isHidden = true

            let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
            excelItem?.isHidden = false

            let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
            tempelItem?.isHidden = false

            let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
            pdfItem?.isHidden = false

            let statusMenu = menu.items.first(where: { $0.title == "Status Siswa" })
            if let statusMenuItem = menu.items.first(where: { $0.submenu == statusMenu }) {
                statusMenuItem.isHidden = true // Menyembunyikan menu utama beserta submenu-nya
            }
            statusMenu?.isHidden = true
            if menu.items.contains(tagMenuItem2) {
                menu.removeItem(tagMenuItem2)
            }

            if currentTableViewMode == .grouped {
                let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
                tempelItem?.isHidden = false
            }
            return
        }
        var siswa: ModelSiswa!
        let clickedRow = tableView.selectedRow
        if currentTableViewMode == .plain {
            siswa = viewModel.filteredSiswaData[clickedRow]
        } else if currentTableViewMode == .grouped {
            let selectedRowInfo = getRowInfoForRow(clickedRow)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            if selectedRowInfo.isGroupRow {
                for item in menu.items {
                    item.isHidden = true
                }
                return
            }
            if groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count {
                siswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
            }
        }

        detailItem?.isHidden = false
        // For cells that need context menu, add necessary menu items
        let selectedRowsCount = tableView.selectedRowIndexes.count
        // Periksa mode tabel saat ini
        if currentTableViewMode == .plain {
            for row in tableView.selectedRowIndexes {
                siswa = viewModel.filteredSiswaData[row]
                for subview in customViewMenu2.subviews {
                    if let tagControl = subview as? TagControl {
                        // Check if the tag corresponds to the current active class
                        if tagControl.kelasValue == siswa.kelasSekarang.rawValue {
                            tagControl.isSelected = true
                            if selectedRowsCount > 1 {
                                tagControl.multipleItem = true
                            } else {
                                tagControl.multipleItem = false
                            }
                        }
                    }
                }
            }

            let selectedRow = tableView.selectedRow
            var detailTitle = "Rincian Siswa"
            var copyItemTitle = "Salin Data \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
            var hapusTitle = "Hapus \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
            var editTitle = "Edit Data"
            var ubahTitle = "Ubah Data"
            var lihatFotoTitle = "Lihat Foto \"\(viewModel.filteredSiswaData[selectedRow].nama)\""
            if selectedRowsCount > 1, selectedRowsCount <= viewModel.filteredSiswaData.count {
                // Handle clicked row that is not in selected indexes
                copyItemTitle = "Salin \(selectedRowsCount) data..."
                hapusTitle = "Hapus \(selectedRowsCount) data..."
                editTitle = "Edit \(selectedRowsCount) data..."
                ubahTitle = "Ubah \(selectedRowsCount) data..."
                detailTitle = "Rincian \(selectedRowsCount) siswa..."
                lihatFotoTitle = "Lihat Foto \(selectedRowsCount) siswa..."
            }
            detailItem?.title = detailTitle
            let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
            hapusitem?.title = hapusTitle
            hapusitem?.isHidden = false

            let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
            editItem?.title = editTitle
            editItem?.isHidden = false

            ubahData?.title = ubahTitle
            ubahData?.isHidden = false

            if menu.items.first(where: { $0.identifier?.rawValue == "kelasAktif" }) == nil {
                menu.insertItem(tagMenuItem2, at: 21)
            }

            lihatFoto?.isHidden = false
            lihatFoto?.title = lihatFotoTitle

            let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
            salinItem?.title = copyItemTitle
            salinItem?.isHidden = false

            let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
            tempelItem?.isHidden = false

            let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
            excelItem?.isHidden = false

            let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
            pdfItem?.isHidden = false

            if let statusMenuItem = menu.items.first(where: { $0.title == "Status Siswa" }) {
                statusMenuItem.isHidden = false
                if let submenu = statusMenuItem.submenu {
                    for menuItem in submenu.items {
                        if let representedStatus = menuItem.representedObject as? String {
                            menuItem.state = (representedStatus == siswa.status.rawValue) ? .on : .off
                        } else {
                            menuItem.state = .off
                        }
                    }
                }
            }
        } else {
            // Dapatkan informasi baris yang diklik
            let selectedRowInfo = getRowInfoForRow(tableView.selectedRow)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            // Pastikan indeks valid sebelum mengakses data siswa
            guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                return
            }

            // Ambil objek siswa dari viewModel.groupedSiswa
            let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

            // Atur judul item menu "Salin" dan "Hapus"
            var copyItemTitle = "Salin Data \"\(selectedSiswa.nama)\""
            var hapusTitle = "Hapus \"\(selectedSiswa.nama)\""
            var editTitle = "Edit Data"
            var ubahTitle = "Ubah Data"
            var detailTitle = "Rincian Siswa"
            var lihatFotoTitle = "Lihat Foto \"\(selectedSiswa.nama)\""

            if selectedRowsCount > 1 {
                copyItemTitle = "Salin \(selectedRowsCount) data..."
                hapusTitle = "Hapus \(selectedRowsCount) data..."
                editTitle = "Edit \(selectedRowsCount) data..."
                ubahTitle = "Ubah \(selectedRowsCount) data..."
                detailTitle = "Rincian \(selectedRowsCount) siswa..."
                lihatFotoTitle = "Lihat Foto \(selectedRowsCount) siswa..."
            }
            detailItem?.title = detailTitle
            let hapusitem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
            hapusitem?.title = hapusTitle
            hapusitem?.isHidden = false

            let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
            editItem?.title = editTitle
            editItem?.isHidden = false

            ubahData?.title = ubahTitle
            ubahData?.isHidden = false

            lihatFoto?.isHidden = false
            lihatFoto?.title = lihatFotoTitle

            let salinItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
            salinItem?.title = copyItemTitle
            salinItem?.isHidden = false

            let excelItem = menu.items.first(where: { $0.identifier?.rawValue == "xcl" })
            excelItem?.isHidden = false

            let pdfItem = menu.items.first(where: { $0.identifier?.rawValue == "pdf" })
            pdfItem?.isHidden = false

            let tempelItem = menu.items.first(where: { $0.identifier?.rawValue == "tempel" })
            tempelItem?.isHidden = false

            let statusMenu = menu.items.first(where: { $0.title == "Status Siswa" })
            statusMenu?.isHidden = true

            menu.removeItem(tagMenuItem2)
        }
    }

    /**
     Menangani aksi ketika sebuah tag (kelas) diklik. Fungsi ini menampilkan dialog konfirmasi untuk mengubah atau menghapus kelas aktif siswa,
     baik untuk siswa yang dipilih maupun siswa yang barisnya diklik.

     - Parameter sender: Objek yang mengirimkan aksi, diharapkan berupa `TagControl`.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Memastikan bahwa `sender` adalah `TagControl` dan mendapatkan `tableView` serta nilai kelas dari tag. Jika tidak, fungsi akan berhenti.
     2. Menentukan baris mana yang diklik pada `tableView`.
     3. Membuat dan mengkonfigurasi sebuah `NSAlert` untuk menampilkan pesan konfirmasi. Pesan yang ditampilkan bergantung pada:
        - Apakah ada baris yang diklik.
        - Apakah baris yang diklik termasuk dalam baris yang dipilih.
        - Apakah nilai kelas yang dipilih kosong (menandakan penghapusan kelas).
     4. Menambahkan ikon dan tombol ("OK" dan "Batalkan") ke dalam alert.
     5. Menjalankan alert secara asinkron di `DispatchQueue.main`.
     6. Jika tombol "OK" diklik:
        - Memanggil fungsi `updateKelasDipilih` jika baris yang diklik termasuk dalam baris yang dipilih, atau jika tidak ada baris yang diklik.
        - Memanggil fungsi `updateKelasKlik` jika ada baris yang diklik dan tidak termasuk dalam baris yang dipilih.
     7. Jika tombol "Batalkan" diklik, tidak ada perubahan yang dilakukan.
     8. Memastikan bahwa `itemSelectedMenu` dan `tableView.menu` membatalkan pelacakan.
     9. Memastikan bahwa `tag.isSelected` diubah dan `tag.mouseInside` diatur ke `false` setelah alert ditutup.
     */
    @objc func tagClick(_ sender: AnyObject?) {
        guard let tag = sender as? TagControl, let tableView, let kelas = tag.kelasValue else { return }
        let klikRow = tableView.clickedRow
        let alert = NSAlert()
        alert.messageText = "Konfirmasi Pengubahan Kelas"
        if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                if !kelas.isEmpty {
                    alert.informativeText = "Apakah Anda yakin mengubah kelas aktif dari \(tableView.selectedRowIndexes.count) siswa menjadi \"\(kelas)\"?"
                } else {
                    alert.informativeText = "Apakah Anda yakin menghapus kelas aktif dari \(tableView.selectedRowIndexes.count) siswa?"
                }
            } else {
                let siswa = viewModel.filteredSiswaData[tableView.clickedRow]
                guard kelas != siswa.kelasSekarang.rawValue else { return }
                if !kelas.isEmpty {
                    alert.informativeText = "Apakah Anda yakin mengubah kelas aktif \(siswa.nama) menjadi \"\(kelas)\"?"
                } else {
                    alert.informativeText = "Apakah Anda yakin menghapus kelas aktif \(siswa.nama)?"
                }
            }
        } else {
            if !kelas.isEmpty {
                alert.informativeText = "Apakah Anda yakin mengubah kelas aktif dari \(tableView.selectedRowIndexes.count) siswa menjadi \"\(kelas)\"?"
            } else {
                alert.informativeText = "Apakah Anda yakin menghapus kelas aktif dari \(tableView.selectedRowIndexes.count) siswa?"
            }
        }
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")
        DispatchQueue.main.async {
            self.itemSelectedMenu.cancelTracking()
            tableView.menu?.cancelTracking()
            DispatchQueue.main.async { [unowned self] in
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    tag.isSelected.toggle()
                    tag.mouseInside = false
                    // Jika ada baris yang diklik
                    if klikRow >= 0, klikRow < viewModel.filteredSiswaData.count {
                        if tableView.selectedRowIndexes.contains(klikRow) {
                            updateKelasDipilih(kelas)
                        } else {
                            updateKelasKlik(kelas, clickedRow: klikRow)
                        }
                    } else {
                        updateKelasDipilih(kelas)
                    }
                } else {
                    tag.mouseInside = false
                }
            }
        }
    }

    /**
         Membuat menu kustom yang menampilkan indikator kelas aktif dengan warna yang berbeda.

         Menu ini terdiri dari sebuah label teks "Kelas Aktif" dan serangkaian kontrol tag berwarna
         yang mewakili setiap kelas.  Pengguna dapat berinteraksi dengan kontrol tag untuk
         melakukan tindakan tertentu (misalnya, memfilter data berdasarkan kelas yang dipilih).

         - Note: Fungsi ini menginisialisasi dan menambahkan subview ke `customViewMenu`.
     */
    func createCustomMenu() {
        let textField = NSTextField(frame: NSRect(x: 11, y: 0, width: 150, height: 20))
        textField.stringValue = "Kelas Aktif"
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.isBordered = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.textColor = .systemGray

        let colors: [(NSColor, NSRect, String)] = [
            (.systemRed, NSRect(x: 11, y: 24, width: 20, height: 20), ""),
            (NSColor(named: "kelas1") ?? NSColor.clear, NSRect(x: 41, y: 24, width: 20, height: 20), "Kelas 1"),
            (NSColor(named: "kelas2") ?? NSColor.clear, NSRect(x: 67, y: 24, width: 20, height: 20), "Kelas 2"),
            (NSColor(named: "kelas3") ?? NSColor.clear, NSRect(x: 93, y: 24, width: 20, height: 20), "Kelas 3"),
            (NSColor(named: "kelas4") ?? NSColor.clear, NSRect(x: 119, y: 24, width: 20, height: 20), "Kelas 4"),
            (NSColor(named: "kelas5") ?? NSColor.clear, NSRect(x: 145, y: 24, width: 20, height: 20), "Kelas 5"),
            (NSColor(named: "kelas6") ?? NSColor.clear, NSRect(x: 171, y: 24, width: 20, height: 20), "Kelas 6"),
        ]

        for (index, (color, frame, kelas)) in colors.enumerated() {
            let tagControl = TagControl(color, frame: frame)
            tagControl.tag = index
            tagControl.textField = textField
            tagControl.target = self
            tagControl.action = #selector(tagClick(_:))
            tagControl.kelasValue = kelas
            customViewMenu.addSubview(tagControl)
        }

        customViewMenu.addSubview(textField)
    }

    /// Seperti ``createCustomMenu()`` dengan penyesuaian untuk menu item di toolbar.
    func createCustomMenu2() {
        let textField = NSTextField(frame: NSRect(x: 22, y: 0, width: 150, height: 20))
        textField.stringValue = "Kelas Aktif"
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.isBordered = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.textColor = .systemGray

        let colors: [(NSColor, NSRect, String)] = [
            (.systemRed, NSRect(x: 22, y: 24, width: 20, height: 20), ""),
            (NSColor(named: "kelas1") ?? NSColor.clear, NSRect(x: 52, y: 24, width: 20, height: 20), "Kelas 1"),
            (NSColor(named: "kelas2") ?? NSColor.clear, NSRect(x: 78, y: 24, width: 20, height: 20), "Kelas 2"),
            (NSColor(named: "kelas3") ?? NSColor.clear, NSRect(x: 104, y: 24, width: 20, height: 20), "Kelas 3"),
            (NSColor(named: "kelas4") ?? NSColor.clear, NSRect(x: 130, y: 24, width: 20, height: 20), "Kelas 4"),
            (NSColor(named: "kelas5") ?? NSColor.clear, NSRect(x: 156, y: 24, width: 20, height: 20), "Kelas 5"),
            (NSColor(named: "kelas6") ?? NSColor.clear, NSRect(x: 182, y: 24, width: 20, height: 20), "Kelas 6"),
        ]

        for (index, (color, frame, kelas)) in colors.enumerated() {
            let tagControl = TagControl(color, frame: frame)
            tagControl.tag = index
            tagControl.textField = textField
            tagControl.target = self
            tagControl.action = #selector(tagClick(_:))
            tagControl.kelasValue = kelas
            customViewMenu2.addSubview(tagControl)
        }
        customViewMenu2.addSubview(textField)
    }

    /// Fungsi untuk membangun ulang menu header sesuai urutan kolom tableView.
    /// Lihat: ``ReusableFunc/updateColumnMenu(_:tableColumns:exceptions:target:selector:)``.
    func updateHeaderMenuOrder() {
        ReusableFunc.updateColumnMenu(tableView, tableColumns: tableView.tableColumns, exceptions: ["Nama"], target: self, selector: #selector(toggleColumnVisibility(_:)))
    }
}
