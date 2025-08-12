//
//  MenuGuru.swift
//  Data SDI
//
//  Created by MacBook on 15/07/25.
//

import AppKit

extension GuruVC: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(menu)
            return
        }
        updateTableMenu(menu)
    }

    /// Fungsi ini membuat menu untuk tabel guru.
    /// Menu ini berisi item untuk mengelola guru, seperti
    /// "Edit", "Hapus", "Muat Ulang", dan "Cata Guru Baru".
    /// - Returns: NSMenu yang berisi item-item untuk mengelola guru.
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu()

        // Membuat NSMenuItem untuk representasi visual terkait foto.
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        image.image = ReusableFunc.largeActionImage
        image.isHidden = true
        image.identifier = NSUserInterfaceItemIdentifier("foto") // Memberikan identifier unik.
        menu.addItem(image) // Menambahkan item menu ke menu.

        let muatUlang = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        muatUlang.identifier = NSUserInterfaceItemIdentifier("reload")
        muatUlang.target = self
        menu.addItem(muatUlang)
        menu.addItem(NSMenuItem.separator())

        let catatGuru = NSMenuItem(title: "Cata Guru Baru", action: #selector(tambahGuru(_:)), keyEquivalent: "")
        catatGuru.identifier = NSUserInterfaceItemIdentifier("new")
        catatGuru.target = self
        menu.addItem(catatGuru)
        menu.addItem(NSMenuItem.separator())

        let edit = NSMenuItem(title: "Edit", action: #selector(editGuru(_:)), keyEquivalent: "")
        edit.target = self
        edit.identifier = NSUserInterfaceItemIdentifier("edit")
        menu.addItem(edit)

        let hapus = NSMenuItem(title: "Hapus", action: #selector(hapusGuru(_:)), keyEquivalent: "")
        hapus.target = self
        hapus.identifier = NSUserInterfaceItemIdentifier("hapus")
        menu.addItem(hapus)
        menu.addItem(NSMenuItem.separator())

        let salin = NSMenuItem(title: "Salin", action: #selector(salin(_:)), keyEquivalent: "")
        salin.identifier = NSUserInterfaceItemIdentifier("salin")
        salin.representedObject = tableView.selectedRowIndexes
        salin.target = self
        menu.addItem(salin)

        return menu
    }

    ///  Fungsi ini mengatur item menu baris untuk tabel guru.
    /// Fungsi ini akan mengupdate item menu berdasarkan baris yang diklik atau dipilih
    /// pada tabel. Jika baris yang diklik tidak ada dalam indeks yang dipilih,
    /// maka item menu akan menampilkan nama guru pada baris yang diklik.
    /// Jika ada baris yang dipilih, maka item menu akan menampilkan nama guru pada
    /// baris yang dipilih. Jika tidak ada baris yang dipilih, maka item menu akan disembunyikan.
    /// Fungsi ini juga mengatur item menu untuk aksi seperti
    /// "Hapus", "Edit", dan "Salin" berdasarkan baris yang dik
    /// - Parameters:
    ///   - menu: NSMenu yang akan diupdate.
    ///   - clickedRow: Baris yang diklik pada tabel. Jika nil, maka tidak ada baris yang diklik.
    ///   - selectedRows: Baris yang dipilih pada tabel. Jika kosong, maka tidak ada baris yang dipilih.
    ///   - hide: Opsi untuk menyembunyikan item menu. Jika true, item menu akan disembunyikan.
    private func configureRowMenuItem(_ menu: NSMenu, clickedRow: Int?, selectedRows: IndexSet, hide: Bool = false) {
        let nama: String = if let clickedRow {
            if selectedRows.contains(clickedRow), selectedRows.count > 1 {
                "\(selectedRows.count) guru..."
            } else {
                viewModel.guru[clickedRow].namaGuru
            }
        } else {
            if selectedRows.count > 1 {
                "\(selectedRows.count) guru..."
            } else if let selectedRow = selectedRows.first {
                viewModel.guru[selectedRow].namaGuru
            } else {
                ""
            }
        }

        hideRowMenuItem(menu, hide: hide, nama: nama)
    }

    ///  Fungsi ini mengupdate menu tabel berdasarkan baris yang diklik atau dipilih.
    /// Fungsi ini akan menyembunyikan item menu aksi jika tidak ada baris yang diklik atau dipilih.
    /// Jika ada baris yang diklik, maka item menu aksi akan disembunyikan,
    /// dan item menu baris akan diupdate berdasarkan baris yang diklik atau dipilih.
    /// Jika tidak ada baris yang diklik, maka item menu aksi akan ditampilkan,
    /// dan item menu baris akan disembunyikan.
    /// - Parameter menu: NSMenu yang akan diupdate.
    func updateTableMenu(_ menu: NSMenu) {
        let clickedRow = tableView.clickedRow
        let selectedRows = tableView.selectedRowIndexes

        if clickedRow != -1 {
            hideActionMenuItem(menu, hide: true)
            configureRowMenuItem(menu, clickedRow: clickedRow, selectedRows: selectedRows)
        } else {
            hideActionMenuItem(menu, hide: false)
            hideRowMenuItem(menu, hide: true)
        }
    }

    ///  Fungsi ini mengupdate menu toolbar berdasarkan baris yang dipilih pada tabel.
    /// - Parameter menu: NSMenu yang akan diperbarui.
    func updateToolbarMenu(_ menu: NSMenu) {
        let selectedRows = tableView.selectedRowIndexes
        hideActionMenuItem(menu, hide: false)
        if selectedRows.isEmpty {
            configureRowMenuItem(menu, clickedRow: nil, selectedRows: selectedRows, hide: true)
        } else {
            configureRowMenuItem(menu, clickedRow: nil, selectedRows: selectedRows)
        }
    }

    ///  Fungsi ini menyembunyikan item menu baris berdasarkan kondisi tertentu.
    /// Fungsi ini akan menyembunyikan item menu "Hapus", "Edit",
    /// dan "Salin" jika `hide` bernilai true.
    /// Jika `hide` bernilai false, maka item menu akan ditampilkan.
    /// Jika `nama` tidak nil, maka item menu "Hapus", "Edit",
    /// dan "Salin" akan diupdate dengan nama yang diberikan.
    /// - Parameters:
    ///   - menu: NSMenu yang akan diupdate.
    ///   - hide: Opsi untuk menyembunyikan item menu. Jika true, item menu akan disembunyikan.
    ///   - nama: Opsi untuk memberikan nama pada item menu. Jika nil, nama tidak akan diupdate.
    func hideRowMenuItem(_ menu: NSMenu, hide: Bool, nama: String? = nil) {
        let deleteMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "hapus" })
        let editMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" })
        let copyMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "salin" })
        deleteMenuItem?.isHidden = hide == true
        editMenuItem?.isHidden = hide == true
        copyMenuItem?.isHidden = hide == true
        guard let nama, !hide else { return }
        deleteMenuItem?.title = "Hapus " + nama
        editMenuItem?.title = "Edit " + nama
        copyMenuItem?.title = "Salin " + nama
        copyMenuItem?.representedObject = tableView.selectedRowIndexes
    }

    ///  Fungsi ini menyembunyikan item menu aksi berdasarkan kondisi tertentu.
    /// Fungsi ini akan menyembunyikan item menu "Muat Ulang" dan "Cata Guru Baru" jika `hide` bernilai true.
    /// Jika `hide` bernilai false, maka item menu akan ditampilkan.
    /// - Parameters:
    ///   - menu: NSMenu yang akan diupdate.
    ///   - hide: Opsi untuk menyembunyikan item menu. Jika true,
    func hideActionMenuItem(_ menu: NSMenu, hide: Bool) {
        let reloadMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "reload" })
        let newMenuItem = menu.items.first(where: { $0.identifier?.rawValue == "new" })
        reloadMenuItem?.isHidden = hide == true
        newMenuItem?.isHidden = hide == true
    }
}
