//
//  InventoryMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa
extension InventoryView {
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu()
        
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        image.image = largeActionImage
        image.identifier = NSUserInterfaceItemIdentifier("foto")
        menu.addItem(image)
        let muatUlang = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        muatUlang.identifier = NSUserInterfaceItemIdentifier("muatUlang")
        menu.addItem(muatUlang)
        menu.addItem(NSMenuItem.separator())
        let tambahHeader = NSMenuItem(title: "Tambah Kolom", action: #selector(addColumnButtonClicked(_:)), keyEquivalent: "")
        tambahHeader.identifier = NSUserInterfaceItemIdentifier("tambahHeader")
        menu.addItem(tambahHeader)
        let tambahRow = NSMenuItem(title: "Masukkan Data", action: #selector(addRowButtonClicked(_:)), keyEquivalent: "")
        tambahRow.identifier = NSUserInterfaceItemIdentifier("tambahRow")
        menu.addItem(tambahRow)
        menu.addItem(NSMenuItem.separator())
        let edit = NSMenuItem(title: "Edit", action: #selector(edit(_:)), keyEquivalent: "")
        edit.identifier = NSUserInterfaceItemIdentifier("edit")
        menu.addItem(edit)
        let hapus = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        hapus.identifier = NSUserInterfaceItemIdentifier("hapus")
        menu.addItem(hapus)
        let hapusFoto = NSMenuItem(title: "Hapus Foto", action: #selector(hapusFotoMenu(_:)), keyEquivalent: "")
        hapusFoto.identifier = NSUserInterfaceItemIdentifier("hapusFoto")
        menu.addItem(hapusFoto)
        menu.addItem(NSMenuItem.separator())
        let salin = NSMenuItem(title: "Salin", action: #selector(salinData(_:)), keyEquivalent: "")
        salin.identifier = NSUserInterfaceItemIdentifier("salin")
        menu.addItem(salin)
        menu.addItem(NSMenuItem.separator())
        let foto = NSMenuItem(title: "Buka Foto", action: #selector(tampilkanFoto(_:)), keyEquivalent: "")
        foto.identifier = NSUserInterfaceItemIdentifier("tampilkanFoto")
        menu.addItem(foto)
        let lihatFoto = NSMenuItem(title: "Lihat Foto", action: #selector(tampilkanFotos(_:)), keyEquivalent: "")
        lihatFoto.identifier = NSUserInterfaceItemIdentifier("lihatFoto")
        menu.addItem(lihatFoto)
        let simpanFoto = NSMenuItem(title: "Simpan Foto", action: #selector(simpanFoto(_:)), keyEquivalent: "")
        simpanFoto.identifier = NSUserInterfaceItemIdentifier("simpanFoto")
        menu.addItem(simpanFoto)
        return menu
    }
    func updateTableMenu(_ menu: NSMenu) {
        let klikRow = tableView.clickedRow
        let rows = tableView.selectedRowIndexes
        if !rows.contains(klikRow) && klikRow == -1 {
            menu.items.forEach({ i in
                if i.identifier?.rawValue == "tambahHeader" ||
                    i.identifier?.rawValue == "tambahRow" ||
                    i.identifier?.rawValue == "muatUlang" {
                    i.isHidden = false
                } else if i.identifier?.rawValue == "edit" ||
                            i.identifier?.rawValue == "foto" ||
                            i.identifier?.rawValue == "hapus" ||
                            i.identifier?.rawValue == "hapusFoto" ||
                            i.identifier?.rawValue == "salin" ||
                            i.identifier?.rawValue == "tampilkanFoto" ||
                            i.identifier?.rawValue == "simpanFoto" ||
                            i.identifier?.rawValue == "lihatFoto" {
                    i.isHidden = true
                }
            })
            
            return
        }
        
        menu.items.forEach({ i in
            if i.identifier?.rawValue == "foto" ||
                i.identifier?.rawValue == "tambahHeader" ||
                i.identifier?.rawValue == "tambahRow" ||
                i.identifier?.rawValue == "muatUlang" {
                i.isHidden = true
            } else if i.identifier?.rawValue == "edit" ||
                        i.identifier?.rawValue == "hapus" ||
                        i.identifier?.rawValue == "hapusFoto" ||
                        i.identifier?.rawValue == "salin" ||
                        i.identifier?.rawValue == "tampilkanFoto" ||
                        i.identifier?.rawValue == "simpanFoto" ||
                        i.identifier?.rawValue == "lihatFoto" {
                i.isHidden = false
            }
        })
        var nama = ""
        var editString = ""
        let namaBarang = data[klikRow]["Nama Barang"] as? String
        editString = "\"\(namaBarang ?? "namaBarang")\""
        let lihatFoto = menu.items.first(where: {$0.identifier?.rawValue == "lihatFoto"})
        if !rows.contains(klikRow) && klikRow != -1 {
            nama = "\"\(namaBarang ?? "namaBarang")\""
            lihatFoto?.title = "Lihat Cepat \"\(namaBarang ?? "")\""
        } else {
            guard tableView.clickedRow != -1 else {return}
            nama = "\(rows.count) item..."
            if tableView.selectedRowIndexes.count > 1 {
                editString = "\(rows.count) item..."
            }
            lihatFoto?.title = "Lihat Cepat \(rows.count) item..."
        }
        guard rows.count > 0 || klikRow != -1 else {tableView.menu = menu;return}
        if let hapus = menu.items.first(where: {$0.identifier?.rawValue == "hapus"}) {
            hapus.title = "Hapus \(nama)"
        }
        if let hapusFoto = menu.items.first(where: {$0.identifier?.rawValue == "hapusFoto"}) {
            hapusFoto.title = "Hapus Foto \(nama)"
        }
        if let edit = menu.items.first(where: {$0.identifier?.rawValue == "edit"}) {
            edit.title = "Edit \(editString)"
        }
        
        if let salin = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) {
            salin.title = "Salin \(nama)"
        }
    }
    func updateToolbarMenu(_ menu: NSMenu) {
        let klikRow = tableView.selectedRow
        let rows = tableView.selectedRowIndexes
        guard tableView.numberOfSelectedRows >= 1  else {
            menu.items.forEach({ i in
                if i.identifier?.rawValue == "tambahHeader" ||
                    i.identifier?.rawValue == "tambahRow" ||
                    i.identifier?.rawValue == "muatUlang" {
                    i.isHidden = false
                } else if i.identifier?.rawValue == "foto" ||
                            i.identifier?.rawValue == "edit" ||
                            i.identifier?.rawValue == "hapus" ||
                            i.identifier?.rawValue == "hapusFoto" ||
                            i.identifier?.rawValue == "salin" ||
                            i.identifier?.rawValue == "tampilkanFoto" ||
                            i.identifier?.rawValue == "simpanFoto" ||
                            i.identifier?.rawValue == "lihatFoto" {
                    i.isHidden = true
                }
            })
            
            return
        }
        
        menu.items.forEach({ i in
            if i.identifier?.rawValue == "foto" {
                i.isHidden = true
            } else if i.identifier?.rawValue == "tambahHeader" ||
                        i.identifier?.rawValue == "tambahRow" ||
                        i.identifier?.rawValue == "muatUlang" {
                i.isHidden = false
            } else if i.identifier?.rawValue == "edit" ||
                        i.identifier?.rawValue == "hapus" ||
                        i.identifier?.rawValue == "hapusFoto" ||
                        i.identifier?.rawValue == "salin" ||
                        i.identifier?.rawValue == "tampilkanFoto" ||
                        i.identifier?.rawValue == "simpanFoto" ||
                        i.identifier?.rawValue == "lihatFoto" {
                i.isHidden = false
            }
        })
        
        
        var nama = ""
        var editString = ""
        var lihatFotoTitle = ""
        guard rows.count >= 0 else {return}
        let lihatFoto = menu.items.first(where: {$0.identifier?.rawValue == "lihatFoto"})
        let namaBarang = data[klikRow]["Nama Barang"] as? String
        editString = "\"\(namaBarang ?? "")\""
        if rows.count >= 2 {
            lihatFotoTitle = "Lihat Cepat \(rows.count) item..."
            nama = "\(rows.count) item..."
            editString = "\(rows.count) item..."
        } else {
            lihatFotoTitle = "Lihat Cepat \"\(namaBarang ?? "")\""
            nama = "\"\(namaBarang ?? "")\""
        }
        guard rows.count > 0 || klikRow != -1 else {tableView.menu = menu;return}
        if let hapus = menu.items.first(where: {$0.identifier?.rawValue == "hapus"}) {
            hapus.title = "Hapus \(nama)"
        }
        lihatFoto?.title = lihatFotoTitle
        
        if let hapusFoto = menu.items.first(where: {$0.identifier?.rawValue == "hapusFoto"}) {
            hapusFoto.title = "Hapus Foto \(nama)"
        }
        if let edit = menu.items.first(where: {$0.identifier?.rawValue == "edit"}) {
            edit.title = "Edit \(editString)"
        }
        
        if let salin = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) {
            salin.title = "Salin \(nama)"
        }
    }
    
    @objc func hapusFotoMenu(_ sender: NSMenuItem) {
        let clickedRow = tableView.clickedRow
        let selectedRows = tableView.selectedRowIndexes
        if clickedRow >= 0 {
            if selectedRows.contains(clickedRow) {
                hapusFoto(selectedRows)
            } else {
                hapusFoto(IndexSet([clickedRow]))
            }
        } else {
            hapusFoto(selectedRows)
        }
    }
}
