//
//  SiswaViewMenu.swift
//  Data SDI
//
//  Created by Bismillah on 11/12/24.
//

import Cocoa

extension SiswaViewController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        let tagItem = menu === itemSelectedMenu
            ? tagMenuItem2
            : tagMenuItem

        if !menu.items.contains(tagItem) {
            menu.insertItem(tagItem, at: 21)
        }

        for item in menu.items {
            guard item.title != "Image" else {
                continue
            }
            item.isHidden = false
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
        let nonItemMenu: IndexSet = [1, 3, 4, 6, 7, 9, 10, 24, 25]
        let clickedRow = tableView.clickedRow
        let selectedRows = tableView.selectedRowIndexes
        let rowsToProcess = ReusableFunc.resolveRowsToProcess(selectedRows: selectedRows, clickedRow: clickedRow)
        let processCount = rowsToProcess.count

        guard clickedRow >= 0 else {
            setupMenuForNoSelection(in: menu, nonItemMenu: nonItemMenu)
            // Setup common menu items
            setupCommonMenuItems(in: menu)
            if menu.items.contains(tagMenuItem) {
                menu.removeItem(tagMenuItem)
            }
            return
        }

        // Handle row selection
        guard let siswa = getSiswaForRow(clickedRow) else {
            for menu in menu.items {
                menu.isHidden = true
            }
            if menu.items.contains(tagMenuItem) {
                menu.removeItem(tagMenuItem)
            }
            return
        }

        if processCount > 1 {
            setupMenuForMultipleSelection(in: customViewMenu, indexes: rowsToProcess)
        } else {
            setupMenuForSingleSelection(in: customViewMenu, siswa: siswa)
        }

        // Update menu items visibility
        updateMenuItemsVisibility(in: menu, nonItemMenu: nonItemMenu, shouldHide: true)
        setupDetailMenuItems(in: menu, siswa: siswa, processCount: processCount)
        hideExportItem(menu)
    }

    // Helper functions
    private func setupCommonMenuItems(in menu: NSMenu) {
        let groupTableItem = menu.items.first(where: { $0.identifier?.rawValue == "kelasMode" })
        groupTableItem?.tag = viewModel.mode == .grouped ? 0 : 1
        groupTableItem?.state = viewModel.mode == .grouped ? .on : .off

        menu.items.first(where: { $0.title.lowercased() == "sertakan siswa berhenti" })?.state = isBerhentiHidden ? .off : .on
        menu.items.first(where: { $0.title.lowercased() == "sertakan siswa lulus" })?.state = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") ? .on : .off
        menu.items.first(where: { $0.title.lowercased() == "gunakan warna alternatif" })?.state = useAlternateColor ? .on : .off
    }

    private func getSiswaForRow(_ row: Int) -> ModelSiswa? {
        switch viewModel.mode {
        case .plain:
            return viewModel.siswa(at: row)
        case .grouped:
            let rowInfo = viewModel.getRowInfoForRow(row)
            return rowInfo.isGroupRow ? nil : viewModel.siswa(at: row)
        }
    }

    private func setupMenuForNoSelection(in menu: NSMenu, nonItemMenu: IndexSet) {
        nonItemMenu.forEach { menu.item(at: $0)?.isHidden = false }

        let itemsToHide = ["detail", "hapus", "edit", "ubahData", "lihatFoto", "salin"]
        itemsToHide.compactMap { id in menu.items.first(where: { $0.identifier?.rawValue == id }) }.forEach { $0.isHidden = true }

        ["xcl", "tempel", "pdf"].compactMap { id in menu.items.first(where: { $0.identifier?.rawValue == id }) }.forEach { $0.isHidden = false }

        menu.items.first(where: { $0.title == "Status Siswa" })?.isHidden = true
    }

    private func setupMenuForSingleSelection(in customViewMenu: NSView, siswa: ModelSiswa) {
        for subview in customViewMenu.subviews {
            if let tagControl = subview as? TagControl {
                // Check if the tag corresponds to the current active class
                if tagControl.kelasValue == siswa.tingkatKelasAktif.rawValue {
                    tagControl.isSelected = true
                } else {
                    tagControl.isSelected = false
                }
                tagControl.multipleItem = false
            }
        }
    }

    private func setupMenuForMultipleSelection(in customViewMenu: NSView, indexes: IndexSet) {
        for row in indexes {
            for subview in customViewMenu.subviews {
                guard let siswa = viewModel.siswa(at: row),
                      let tagControl = subview as? TagControl
                else { continue }
                tagControl.resetState()
                if tagControl.kelasValue == siswa.tingkatKelasAktif.rawValue {
                    tagControl.isSelected = true
                    tagControl.multipleItem = true
                }
            }
        }
    }

    private func updateMenuItemsVisibility(in menu: NSMenu, nonItemMenu: IndexSet, shouldHide: Bool) {
        nonItemMenu.forEach { menu.item(at: $0)?.isHidden = shouldHide }
    }

    private func setupDetailMenuItems(in menu: NSMenu, siswa: ModelSiswa, processCount: Int) {
        let nama = "〝\(siswa.nama)〞"
        let defaultMultiple = "\(processCount) data..."
        let defaultMultipleSiswa = "\(processCount) siswa..."

        let rincian = processCount > 1 ? "Rincian \(defaultMultipleSiswa)" : "Rincian Siswa"
        let hapus = processCount > 1 ? "Hapus \(defaultMultipleSiswa)" : "Hapus\(nama)"
        let edit = processCount > 1 ? "Edit \(defaultMultiple)" : "Edit\(nama)"
        let ubah = processCount > 1 ? "Ubah \(defaultMultiple)" : "Ubah\(nama)"
        let lihat = processCount > 1 ? "Lihat Foto \(defaultMultipleSiswa)" : "Lihat Foto\(nama)"
        let salin = processCount > 1 ? "Salin \(defaultMultiple)" : "Salin\(nama)"

        let menuItems = [
            ("detail", rincian),
            ("hapus", hapus),
            ("edit", edit),
            ("ubahData", ubah),
            ("lihatFoto", lihat),
            ("salin", salin),
        ]

        for (id, title) in menuItems {
            menu.items.first(where: { $0.identifier?.rawValue == id })?.title = title
        }
        updateStatusItem(menu, siswa: siswa, processCount: processCount)
    }

    func updateStatusItem(_ menu: NSMenu, siswa: ModelSiswa, processCount: Int) {
        if let statusMenuItem = menu.items.first(where: { $0.title == "Status Siswa" }) {
            statusMenuItem.isHidden = false
            if let submenu = statusMenuItem.submenu {
                for menuItem in submenu.items {
                    if let representedStatus = menuItem.representedObject as? String,
                       processCount == 1
                    {
                        menuItem.state = (representedStatus == siswa.status.description) ? .on : .off
                    } else {
                        menuItem.state = .off
                    }
                }
            }
        }
    }

    func hideExportItem(_ menu: NSMenu) {
        ["tempel", "xcl", "pdf"].compactMap { id in menu.items.first(where: { $0.identifier?.rawValue == id }) }.forEach { $0.isHidden = true }
    }

    /// Fungsi updateMenu bertanggung jawab untuk memperbarui tampilan dan status item-item dalam NSMenu (menu konteks) di toolbar berdasarkan kondisi aplikasi saat ini, seperti mode tampilan tabel (viewModel.mode), status filter, dan jumlah baris yang dipilih di NSTableView.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateMenu(_ menu: NSMenu) {
        let nonItemMenu: IndexSet = [1, 3, 4, 6, 7, 9, 10, 24, 25]
        let rowsToProcess = tableView.selectedRowIndexes
        let processCount = rowsToProcess.count

        // Setup common menu items
        setupCommonMenuItems(in: menu)

        guard tableView.selectedRow != -1 else {
            setupMenuForNoSelection(in: menu, nonItemMenu: nonItemMenu)
            if menu.items.contains(tagMenuItem2) {
                menu.removeItem(tagMenuItem2)
            }
            return
        }

        // Handle row selection
        guard let siswa = getSiswaForRow(rowsToProcess.first!) else { return }

        if processCount > 1 {
            setupMenuForMultipleSelection(in: customViewMenu2, indexes: rowsToProcess)
        } else {
            setupMenuForSingleSelection(in: customViewMenu2, siswa: siswa)
        }

        // Update menu items visibility
        updateMenuItemsVisibility(in: menu, nonItemMenu: nonItemMenu, shouldHide: false)
        setupDetailMenuItems(in: menu, siswa: siswa, processCount: processCount)
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
        itemSelectedMenu.cancelTracking()
        tableView.menu?.cancelTracking()
        DispatchQueue.main.async { [unowned self] in
            tag.isSelected.toggle()
            tag.mouseInside = false
            let indexes = ReusableFunc.resolveRowsToProcess(selectedRows: tableView.selectedRowIndexes, clickedRow: klikRow)
            updateKelasDipilih(kelas, selectedRowIndexes: indexes)
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
            (NSColor(named: "kelas1") ?? NSColor.clear, NSRect(x: 11, y: 24, width: 20, height: 20), "Kelas 1"),
            (NSColor(named: "kelas2") ?? NSColor.clear, NSRect(x: 37, y: 24, width: 20, height: 20), "Kelas 2"),
            (NSColor(named: "kelas3") ?? NSColor.clear, NSRect(x: 63, y: 24, width: 20, height: 20), "Kelas 3"),
            (NSColor(named: "kelas4") ?? NSColor.clear, NSRect(x: 89, y: 24, width: 20, height: 20), "Kelas 4"),
            (NSColor(named: "kelas5") ?? NSColor.clear, NSRect(x: 115, y: 24, width: 20, height: 20), "Kelas 5"),
            (NSColor(named: "kelas6") ?? NSColor.clear, NSRect(x: 141, y: 24, width: 20, height: 20), "Kelas 6"),
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
            (NSColor(named: "kelas1") ?? NSColor.clear, NSRect(x: 22, y: 24, width: 20, height: 20), "Kelas 1"),
            (NSColor(named: "kelas2") ?? NSColor.clear, NSRect(x: 48, y: 24, width: 20, height: 20), "Kelas 2"),
            (NSColor(named: "kelas3") ?? NSColor.clear, NSRect(x: 74, y: 24, width: 20, height: 20), "Kelas 3"),
            (NSColor(named: "kelas4") ?? NSColor.clear, NSRect(x: 100, y: 24, width: 20, height: 20), "Kelas 4"),
            (NSColor(named: "kelas5") ?? NSColor.clear, NSRect(x: 126, y: 24, width: 20, height: 20), "Kelas 5"),
            (NSColor(named: "kelas6") ?? NSColor.clear, NSRect(x: 152, y: 24, width: 20, height: 20), "Kelas 6"),
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
