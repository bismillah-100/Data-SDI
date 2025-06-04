//
//  GuruViewMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa
extension GuruViewController {
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu()
        
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        image.image = largeActionImage
        image.identifier = NSUserInterfaceItemIdentifier("foto")
        menu.addItem(image)

        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.identifier = NSUserInterfaceItemIdentifier("refresh")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(NSMenuItem.separator())
        
        let add = NSMenuItem(title: "Catat Guru baru", action: #selector(addSiswa(_:)), keyEquivalent: "")
        menu.addItem(add)
        add.target = self
        add.identifier = NSUserInterfaceItemIdentifier("add")
        menu.addItem(NSMenuItem.separator())
        
        let menuWarnaAlternatif = NSMenuItem(title: "Gunakan Warna Alternatif", action: #selector(beralihWarnaAlternatif), keyEquivalent: "")
        menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        menuWarnaAlternatif.identifier = NSUserInterfaceItemIdentifier("warnaAlt")
        menu.addItem(menuWarnaAlternatif)
        menu.addItem(NSMenuItem.separator())
        
        
        let editItem = NSMenuItem(title: "Edit", action: #selector(edit(_:)), keyEquivalent: "")
        editItem.identifier = NSUserInterfaceItemIdentifier("edit")
        menu.addItem(editItem)
        let deleteItem = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        deleteItem.identifier = NSUserInterfaceItemIdentifier("hapus")
        deleteItem.target = self
        menu.addItem(deleteItem)
        menu.addItem(NSMenuItem.separator())
        
        let salin = NSMenuItem(title: "Salin", action: #selector(salinData(_:)), keyEquivalent: "")
        salin.identifier = NSUserInterfaceItemIdentifier("salin")
        salin.representedObject = outlineView.selectedRowIndexes
        salin.target = self
        menu.addItem(salin)
        
        return menu
    }
    
    func updateTableMenu(_ menu: NSMenu) {
        let clickedRow = outlineView.clickedRow
        if let menuWarnaAlternatif = menu.items.first(where: {$0.identifier?.rawValue == "warnaAlt"}) {
            menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        }
        guard clickedRow >= 0 else {
            menu.items.forEach({ i in
                if i.identifier?.rawValue == "add" ||
                    i.identifier?.rawValue == "refresh" ||
                    i.identifier?.rawValue == "warnaAlt" {
                    i.isHidden = false
                } else if i.identifier?.rawValue == "foto" ||
                            i.identifier?.rawValue == "salin" ||
                            i.identifier?.rawValue == "edit" ||
                            i.identifier?.rawValue == "hapus" {
                    i.isHidden = true
                }
            })

            return
        }
        menu.items.forEach({ i in
            if i.identifier?.rawValue == "foto" ||
                i.identifier?.rawValue == "add" ||
                i.identifier?.rawValue == "refresh" ||
                i.identifier?.rawValue == "warnaAlt" {
                i.isHidden = true
            } else {
                i.isHidden = false
            }
        })
        var nama = String()
        var editString = String()
        var copyString = String()
        let selectedRows = outlineView.selectedRowIndexes
        
        func onlyClickedRow() {
            if let selectedItem = outlineView.item(atRow: clickedRow) {
                if let guru = selectedItem as? GuruModel {
                    // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                    editString = "\(guru.namaGuru)"
                    nama = "\(guru.namaGuru)"
                    copyString = "Data \"\(guru.namaGuru)\""
                } else if let mapel = selectedItem as? MapelModel {
                    // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                    editString = "guru \(mapel.namaMapel)"
                    nama = "guru \(mapel.namaMapel)"
                    copyString = "\"\(mapel.namaMapel)\""
                }
            }
        }
        
        if selectedRows.count > 1 {
            /* Clicked Row + Selected Row
             Memilih selectedRow
             */
            if selectedRows.contains(clickedRow) {
                // Inisialisasi penghitung
                var guruCount = 0
                var mapelCount = 0

                // Iterasi melalui setiap indeks pada selectedRows
                for row in selectedRows {
                    // Mendapatkan item pada row yang dipilih
                    if let selectedItem = outlineView.item(atRow: row) {
                        if selectedItem is GuruModel {
                            guruCount += 1
                        } else if selectedItem is MapelModel {
                            mapelCount += 1
                        }
                    }
                }
                
                // Gabungkan string untuk nama dengan kedua penghitung tanpa saling menimpa
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
                onlyClickedRow()
            }
        } else {
            onlyClickedRow()
        }

        if let editItem = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            editItem.action = #selector(edit(_:))
            editItem.target = self
            editItem.isEnabled = true
            editItem.title = "Edit \(editString)"
        }

        
        if let salin = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) {
            salin.representedObject = outlineView.selectedRowIndexes
            salin.title = "Salin \(copyString)"
            salin.target = self
        }
        
        if let deleteItem = menu.items.first(where: {$0.identifier?.rawValue == "hapus"}) {
            deleteItem.title = "Hapus \(nama)"
        deleteItem.target = self
        }
    }
    
    func updateToolbarMenu(_ menu: NSMenu) {
        let clickedRow = outlineView.selectedRow
        if let menuWarnaAlternatif = menu.items.first(where: {$0.identifier?.rawValue == "warnaAlt"}) {
            menuWarnaAlternatif.state = warnaAlternatif ? .on : .off
        }
        guard clickedRow >= 0 else {
            menu.items.forEach({ i in
                if i.identifier?.rawValue == "add" ||
                    i.identifier?.rawValue == "refresh" ||
                    i.identifier?.rawValue == "warnaAlt" {
                    i.isHidden = false
                } else if i.identifier?.rawValue == "foto" ||
                            i.identifier?.rawValue == "salin" ||
                            i.identifier?.rawValue == "edit" ||
                            i.identifier?.rawValue == "hapus" {
                    i.isHidden = true
                }
            })
            
            return
        }
        menu.items.forEach({ i in
            if i.identifier?.rawValue == "foto" {
                i.isHidden = true
            } else {
                i.isHidden = false
            }
        })
        var nama = String()
        var editString = String()
        var copyString = String()
        let selectedRows = outlineView.selectedRowIndexes

        if selectedRows.count > 1 {
            // Inisialisasi penghitung
            var guruCount = 0
            var mapelCount = 0

            // Iterasi melalui setiap indeks pada selectedRows
            for row in selectedRows {
                // Mendapatkan item pada row yang dipilih
                if let selectedItem = outlineView.item(atRow: row) {
                    if selectedItem is GuruModel {
                        guruCount += 1
                    } else if selectedItem is MapelModel {
                        mapelCount += 1
                    }
                }
            }
            
            // Gabungkan string untuk nama dengan kedua penghitung tanpa saling menimpa
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
            if let selectedItem = outlineView.item(atRow: clickedRow) {
                if let guru = selectedItem as? GuruModel {
                    // Jika item adalah GuruModel, tambahkan namaGuru dan idGuru ke set
                    editString = "\(guru.namaGuru)"
                    nama = "\(guru.namaGuru)"
                    copyString = "Data \"\(guru.namaGuru)\""
                } else if let mapel = selectedItem as? MapelModel {
                    // Jika item adalah MapelModel, tambahkan semua guru dalam mapel tersebut
                    editString = "guru \(mapel.namaMapel)"
                    nama = "guru \(mapel.namaMapel)"
                    copyString = "\"\(mapel.namaMapel)\""
                }
            }
        }
        if let editItem = menu.items.first(where: {$0.identifier?.rawValue == "edit"}) {
            editItem.action = #selector(edit(_:))
            editItem.target = self
            editItem.isEnabled = true
            editItem.title = "Edit \(editString)"
        }
        
        if let salin = menu.items.first(where: {$0.identifier?.rawValue == "salin"}) {
            salin.title = "Salin \(copyString)"
        }
        
        if let deleteItem = menu.items.first(where: {$0.identifier?.rawValue == "hapus"}) {
            deleteItem.title = "Hapus \(nama)"
        }
    }
}
