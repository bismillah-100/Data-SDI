//
//  MyToolbar.swift
//  Data SDI
//
//  Created by Bismillah on 01/01/25.
//

import Cocoa

/// `MyToolbar` adalah subclass dari `NSToolbar` yang mengimplementasikan `NSToolbarDelegate` untuk mengelola item toolbar dalam aplikasi.
/// Kelas ini bertanggung jawab untuk menambahkan, mengonfigurasi, dan mengelola item toolbar yang ditampilkan di jendela utama aplikasi.
class MyToolbar: NSToolbar, NSToolbarDelegate {
    func toolbarWillAddItem(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newItem = userInfo["item"] as? NSToolbarItem else { return }
        guard let contentViewController = NSApp.mainWindow?.contentViewController,
              let splitViewController = contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            #if DEBUG
                print("ContentViewController tidak ditemukan")
            #endif
            return
        }

        let viewController = containerView.currentContentController
        switch newItem.itemIdentifier.rawValue {
        case "cari":
            if let searchField = newItem.view as? NSSearchField {
                searchField.isEnabled = true
                guard let textFieldInsideSearchField = searchField.cell as? NSSearchFieldCell else { return }
                textFieldInsideSearchField.placeholderAttributedString = nil
                textFieldInsideSearchField.placeholderString = ""
                searchField.placeholderString = ""
                let placeholderAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.labelColor,
                    .font: textFieldInsideSearchField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                ]
                let disabledPlaceholderAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: textFieldInsideSearchField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                ]

                if let siswa = viewController as? SiswaViewController {
                    searchField.action = #selector(siswa.procSearchFieldInput(sender:))
                    searchField.target = siswa
                    searchField.delegate = siswa
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Siswa", attributes: placeholderAttributes)
                    return
                } else if let view = viewController as? TransaksiView {
                    searchField.action = #selector(view.procSearchFieldInput(sender:))
                    searchField.target = view
                    searchField.delegate = view
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Transaksi", attributes: placeholderAttributes)
                    return
                } else if let view = viewController as? TugasMapelVC {
                    searchField.action = #selector(view.procSearchFieldInput(sender:))
                    searchField.target = view
                    searchField.delegate = view
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Tugas Guru", attributes: placeholderAttributes)
                    return
                } else if let view = viewController as? KelasVC {
                    searchField.action = #selector(view.procSearchFieldInput(sender:))
                    searchField.target = view
                    searchField.delegate = view
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        if let selectedTabViewItem = view.tabView.selectedTabViewItem {
                            let selectedTabIndex = view.tabView.indexOfTabViewItem(selectedTabViewItem)
                            view.updateSearchFieldPlaceholder(for: selectedTabIndex)
                        }
                    }
                    return
                } else if let view = viewController as? InventoryView {
                    searchField.action = #selector(view.procSearchFieldInput(sender:))
                    searchField.target = view
                    searchField.delegate = view
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Inventaris", attributes: placeholderAttributes)
                    return
                } else if (viewController as? JumlahSiswa) != nil {
                    searchField.action = nil
                    searchField.isEnabled = false
                    searchField.delegate = nil
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Jumlah Siswa", attributes: disabledPlaceholderAttributes)
                    return
                } else if (viewController as? JumlahTransaksi) != nil {
                    searchField.action = nil
                    searchField.isEnabled = false
                    searchField.delegate = nil
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Jumlah Saldo", attributes: disabledPlaceholderAttributes)
                    return
                } else if (viewController as? Stats) != nil {
                    searchField.action = nil
                    searchField.isEnabled = false
                    searchField.delegate = nil
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Statistik Nilai", attributes: disabledPlaceholderAttributes)
                    return
                } else if (viewController as? Struktur) != nil {
                    searchField.action = nil
                    searchField.isEnabled = false
                    searchField.delegate = nil
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Struktur", attributes: disabledPlaceholderAttributes)
                    return
                } else if let view = viewController as? GuruVC {
                    searchField.isEnabled = true
                    searchField.isEditable = true
                    searchField.action = #selector(view.procSearchFieldInput(_:))
                    searchField.target = view
                    searchField.delegate = view
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Guru", attributes: placeholderAttributes)
                    return
                } else if let view = viewController as? KelasHistoryVC {
                    searchField.isEnabled = true
                    searchField.isEditable = true
                    searchField.action = #selector(view.procSearchField(_:))
                    searchField.target = view
                    searchField.delegate = view
                    textFieldInsideSearchField.placeholderAttributedString = NSAttributedString(string: "Kelas Historis", attributes: placeholderAttributes)
                    return
                }
            }
        case "panelsisi":
            guard let sidebar = newItem.view as? NSButton else { return }
            if let splitView = contentViewController as? SplitVC {
                sidebar.target = splitView
                sidebar.action = #selector(splitView.toggleSidebar(_:))
                sidebar.isEnabled = true
            }
        case "simpan":
            guard let simpan = newItem.view as? NSButton,
                  let splitView = contentViewController as? SplitVC
            else { return }
            simpan.isEnabled = true
            simpan.target = self
            simpan.action = #selector(splitView.saveData(_:))
        case "Tabel":
            if let zoom = newItem.view as? NSSegmentedControl {
                zoom.isEnabled = true
                zoom.target = self
            }
            newItem.toolTip = "Perbesar / Perkecil tampilan item"
        case "Hapus":
            newItem.toolTip = "Hapus item yang dipilih"
        case "Edit":
            newItem.toolTip = "Edit item yang dipilih"
        case "tambah":
            guard let tambah = newItem.view as? NSButton else { return }
            if (viewController as? SiswaViewController) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? TransaksiView) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? TugasMapelVC) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? KelasVC) != nil {
                tambah.isEnabled = true
                if let image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: .none) {
                    let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)
                    newItem.image = largeImage
                }
                newItem.label = "Tambahkan Nilai Siswa"
                tambah.toolTip = "Tambahkan Nilai Siswa"
                return
            } else if (viewController as? InventoryView) != nil {
                tambah.isEnabled = true
                let image = NSImage(named: "add-pos")
                image?.isTemplate = true
                newItem.image = image
                newItem.label = "Tambahkan Kolom"
                tambah.toolTip = "Tambahkan Kolom Baru ke dalam Tabel"
                return
            } else if (viewController as? JumlahSiswa) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? JumlahTransaksi) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? Stats) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? Struktur) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? GuruVC) != nil {
                tambah.isEnabled = false
                return
            } else if (viewController as? KelasHistoryVC) != nil {
                tambah.isEnabled = false
                return
            }
        case "add":
            newItem.toolTip = "Catat data baru"
        case "popUpMenu":
            if let popUpButton = newItem.view as? NSPopUpButton {
                if let siswa = viewController as? SiswaViewController {
                    popUpButton.menu = siswa.itemSelectedMenu
                    return
                } else if let transaksi = viewController as? TransaksiView {
                    popUpButton.menu = transaksi.toolbarMenu
                    return
                } else if let tugasGuru = viewController as? TugasMapelVC {
                    popUpButton.menu = tugasGuru.toolbarMenu
                    tugasGuru.toolbarMenu.delegate = tugasGuru
                    return
                } else if let saldo = viewController as? JumlahTransaksi {
                    popUpButton.menu = saldo.toolbarMenu
                    saldo.toolbarMenu.delegate = saldo
                    return
                } else if let kelas = viewController as? KelasVC {
                    popUpButton.menu = kelas.toolbarMenu
                    kelas.toolbarMenu.delegate = kelas
                    return
                } else if let jumlahSiswa = viewController as? JumlahSiswa {
                    popUpButton.menu = jumlahSiswa.toolbarMenu
                    jumlahSiswa.toolbarMenu.delegate = jumlahSiswa
                    return
                } else if let struktur = viewController as? Struktur {
                    popUpButton.menu = struktur.toolbarMenu
                    struktur.toolbarMenu.delegate = struktur
                    return
                } else if let nilai = viewController as? Stats {
                    popUpButton.menu = nilai.pilihan.menu
                    nilai.pilihan.menu?.delegate = nilai
                    return
                } else if let inventory = viewController as? InventoryView {
                    popUpButton.menu = inventory.toolbarMenu
                    inventory.toolbarMenu.delegate = inventory
                    return
                } else if let guru = viewController as? GuruVC {
                    popUpButton.menu = guru.toolbarMenu
                    guru.toolbarMenu.delegate = guru
                    return
                } else if let histori = viewController as? KelasHistoryVC {
                    popUpButton.menu = histori.toolbarMenu
                    histori.toolbarMenu.delegate = histori
                    return
                }
            }
        default:
            break
        }
    }

    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        guard let windowController = NSApp.mainWindow?.windowController as? WindowController else { return nil }
        return toolbarItem(for: itemIdentifier, in: windowController)
    }

    /// Mengembalikan objek `NSToolbarItem` yang sesuai dengan `itemIdentifier` yang diberikan pada `windowController`.
    /// - Parameter itemIdentifier: Identifier unik untuk item toolbar yang ingin dibuat.
    /// - Parameter windowController: Objek `WindowController` tempat toolbar digunakan.
    /// - Returns: Objek `NSToolbarItem` jika ditemukan, atau `nil` jika tidak ada item yang cocok.
    /// - Note: Fungsi ini selalu membuat instans toolbar baru untuk memastikan toolbar item di jendela pallet tidak kosong.
    func toolbarItem(for itemIdentifier: NSToolbarItem.Identifier, in windowController: WindowController) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

        guard let splitViewController = windowController.contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            #if DEBUG
                print("ContentViewController tidak ditemukan")
            #endif
            return toolbarItem
        }

        let viewController = containerView.currentContentController

        switch itemIdentifier {
        case .tambah:
            if viewController is KelasVC,
               let modified = windowController.datakelas,
               let button = modified.view as? NSButton
            {
                // Konfigurasi tombol "Tambah" untuk KelasVC
                // Menggunakan ikon sistem untuk tombol
                // Jika ikon tidak ditemukan, gunakan ikon default
                // Jika ikon ditemukan, gunakan konfigurasi simbol besar
                // untuk tampilan yang lebih baik
                if let image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: nil) {
                    let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)
                    button.image = largeImage
                }
                // Mengatur label, palet label, dan tooltip untuk tombol
                return customToolbarItem(
                    itemForItemIdentifier: modified.itemIdentifier.rawValue,
                    label: "Nilai",
                    paletteLabel: "Catat Nilai",
                    toolTip: "Tambahkan Nilai Siswa",
                    itemContent: button
                ) ?? NSToolbarItem()
            } else if viewController is InventoryView,
                      let modified = windowController.datakelas,
                      let button = modified.view as? NSButton
            {
                // Konfigurasi tombol "Tambah" untuk InventoryView
                if let image = NSImage(named: "add-pos") {
                    /// Menggunakan ikon "add-pos" untuk tombol
                    /// Mengatur ikon sebagai template agar sesuai dengan tema gelap/terang
                    /// dan menghindari masalah dengan warna ikon.
                    /// Jika ikon tidak ditemukan, gunakan ikon default.
                    /// Jika ikon ditemukan, gunakan konfigurasi simbol besar
                    image.isTemplate = true
                    button.image = image
                }
                return customToolbarItem(
                    itemForItemIdentifier: modified.itemIdentifier.rawValue,
                    label: "Kolom",
                    paletteLabel: "Kolom Baru",
                    toolTip: "Tambahkan Kolom Baru ke dalam Tabel",
                    itemContent: button
                ) ?? NSToolbarItem()
            } else {
                return configureTambahDefault(windowController.datakelas) ?? NSToolbarItem()
            }

        case .simpan:
            return customToolbarItem(
                itemForItemIdentifier: windowController.simpanToolbar.itemIdentifier.rawValue,
                label: windowController.simpanToolbar.label,
                paletteLabel: windowController.simpanToolbar.paletteLabel,
                toolTip: windowController.simpanToolbar.toolTip ?? "",
                itemContent: windowController.simpanToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .cari:
            return customToolbarItem(
                itemForItemIdentifier: windowController.search.itemIdentifier.rawValue,
                label: windowController.search.label,
                paletteLabel: windowController.search.paletteLabel,
                toolTip: windowController.search.toolTip ?? "",
                itemContent: windowController.searchField
            ) ?? NSToolbarItem()

        case .tabel:
            return customToolbarItem(
                itemForItemIdentifier: windowController.segmentedControl.itemIdentifier.rawValue,
                label: windowController.segmentedControl.label,
                paletteLabel: windowController.segmentedControl.paletteLabel,
                toolTip: windowController.segmentedControl.toolTip ?? "",
                itemContent: windowController.segmentedControl.view ?? NSView()
            ) ?? NSToolbarItem()

        case .popupmenu:
            return customToolbarItem(
                itemForItemIdentifier: windowController.actionToolbar.itemIdentifier.rawValue,
                label: windowController.actionToolbar.label,
                paletteLabel: windowController.actionToolbar.paletteLabel,
                toolTip: windowController.actionToolbar.toolTip ?? "",
                itemContent: windowController.actionToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .hapus:
            return customToolbarItem(
                itemForItemIdentifier: windowController.hapusToolbar.itemIdentifier.rawValue,
                label: windowController.hapusToolbar.label,
                paletteLabel: windowController.hapusToolbar.paletteLabel,
                toolTip: windowController.hapusToolbar.toolTip ?? "",
                itemContent: windowController.hapusToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .edit:
            return customToolbarItem(
                itemForItemIdentifier: windowController.editToolbar.itemIdentifier.rawValue,
                label: windowController.editToolbar.label,
                paletteLabel: windowController.editToolbar.paletteLabel,
                toolTip: windowController.editToolbar.toolTip ?? "",
                itemContent: windowController.editToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .add:
            return customToolbarItem(
                itemForItemIdentifier: windowController.addDataToolbar.itemIdentifier.rawValue,
                label: windowController.addDataToolbar.label,
                paletteLabel: windowController.addDataToolbar.paletteLabel,
                toolTip: windowController.addDataToolbar.toolTip ?? "",
                itemContent: windowController.addDataToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .jumlah:
            return customToolbarItem(
                itemForItemIdentifier: windowController.jumlahToolbar.itemIdentifier.rawValue,
                label: windowController.jumlahToolbar.label,
                paletteLabel: windowController.jumlahToolbar.paletteLabel,
                toolTip: windowController.jumlahToolbar.toolTip ?? "",
                itemContent: windowController.jumlahToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .kalkulasi:
            return customToolbarItem(
                itemForItemIdentifier: windowController.kalkulasiToolbar.itemIdentifier.rawValue,
                label: windowController.kalkulasiToolbar.label,
                paletteLabel: windowController.kalkulasiToolbar.paletteLabel,
                toolTip: windowController.kalkulasiToolbar.toolTip ?? "",
                itemContent: windowController.kalkulasiToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .statistik:
            return customToolbarItem(
                itemForItemIdentifier: windowController.statistikToolbar.itemIdentifier.rawValue,
                label: windowController.statistikToolbar.label,
                paletteLabel: windowController.statistikToolbar.paletteLabel,
                toolTip: windowController.statistikToolbar.toolTip ?? "",
                itemContent: windowController.statistikToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .printmenu:
            return customToolbarItem(
                itemForItemIdentifier: windowController.printToolbar.itemIdentifier.rawValue,
                label: windowController.printToolbar.label,
                paletteLabel: windowController.printToolbar.paletteLabel,
                toolTip: windowController.printToolbar.toolTip ?? "",
                itemContent: windowController.printToolbar.view ?? NSView()
            ) ?? NSToolbarItem()

        case .sidebar:
            return customToolbarItem(
                itemForItemIdentifier: windowController.sidebarButton.itemIdentifier.rawValue,
                label: windowController.sidebarButton.label,
                paletteLabel: windowController.sidebarButton.paletteLabel,
                toolTip: windowController.sidebarButton.toolTip ?? "",
                itemContent: windowController.sidebarButton.view ?? NSView()
            ) ?? NSToolbarItem()

        case .sidebarTracking:
            return nil

        default:
            return toolbarItem
        }
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .sidebarTracking,
            .sidebar,
            .cari,
            .simpan,
            .tambah,
            .tabel,
            .popupmenu,
            .hapus,
            .edit,
            .add,
            .jumlah,
            .kalkulasi,
            .statistik,
            .printmenu,
        ]
    }

    /// - Tag: CustomToolbarItem
    func customToolbarItem(
        itemForItemIdentifier itemIdentifier: String,
        label: String,
        paletteLabel: String,
        toolTip: String,
        itemContent: AnyObject
    ) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: itemIdentifier))

        toolbarItem.label = label
        toolbarItem.paletteLabel = paletteLabel
        toolbarItem.toolTip = toolTip
        toolbarItem.target = self

        // Set the right attribute, depending on if we were given an image or a view.
        if itemIdentifier == "cari" {
            toolbarItem.view = NSSearchField()
        } else if itemContent is NSImage {
            if let image = itemContent as? NSImage {
                toolbarItem.image = image
            }
        } else if itemContent is NSView {
            if let view = itemContent as? NSView {
                toolbarItem.view = view
            }
        } else {
            assertionFailure("Invalid itemContent: object")
        }

        // We actually need an NSMenuItem here, so we construct one.
        let menuItem = NSMenuItem()
        menuItem.submenu = nil
        menuItem.title = label
        toolbarItem.menuFormRepresentation = menuItem

        return toolbarItem
    }

    /// Konfigurasi item toolbar untuk "Tambah" default.
    /// - Parameter item: NSToolbarItem yang akan dikonfigurasi.
    /// - Returns: NSToolbarItem yang telah dikonfigurasi.
    /// - Note: Mengubah tampilan item "Tambah" dengan ikon dan label yang sesuai.
    func configureTambahDefault(_ item: NSToolbarItem?) -> NSToolbarItem? {
        guard let modified = item,
              let button = modified.view as? NSButton else { return item }

        if let image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: .none) {
            let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)
            button.image = largeImage
        }

        modified.paletteLabel = "Catat Nilai Siswa"
        modified.label = "Catat Nilai"
        modified.toolTip = "Catat Nilai Siswa"
        return modified
    }
}

extension NSToolbarItem.Identifier {
    static let tambah = NSToolbarItem.Identifier("tambah")
    static let simpan = NSToolbarItem.Identifier("simpan")
    static let cari = NSToolbarItem.Identifier("cari")
    static let tabel = NSToolbarItem.Identifier("Tabel")
    static let popupmenu = NSToolbarItem.Identifier("popUpMenu")
    static let hapus = NSToolbarItem.Identifier("Hapus")
    static let edit = NSToolbarItem.Identifier("Edit")
    static let add = NSToolbarItem.Identifier("add")
    static let jumlah = NSToolbarItem.Identifier("jumlah")
    static let kalkulasi = NSToolbarItem.Identifier("Kalkulasi")
    static let statistik = NSToolbarItem.Identifier("statistik")
    static let printmenu = NSToolbarItem.Identifier("PrintMenu")
    static let sidebar = NSToolbarItem.Identifier("panelsisi")
    static let sidebarTracking = NSToolbarItem.Identifier("NSToolbarSidebarTrackingSeparatorItemIdentifier")
}
