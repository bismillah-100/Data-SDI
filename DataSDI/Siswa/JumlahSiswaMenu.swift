//
//  JumlahSiswaMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa
extension JumlahSiswa {
    func buatItemMenu() -> NSMenu {
        let menu = NSMenu()
        
        let foto = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        foto.image = largeActionImage
        menu.addItem(foto)
        
        let reloadData = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        reloadData.target = self
        menu.addItem(reloadData)
        menu.addItem(NSMenuItem.separator())
        
        
        let copyItem = NSMenuItem(title: "Salin", action: #selector(copyMenuItem(_:)), keyEquivalent: "")
        copyItem.identifier = NSUserInterfaceItemIdentifier("salin")
        copyItem.target = self
        menu.addItem(copyItem)

        let copyAllItem = NSMenuItem(title: "Salin Semua Jumlah Siswa", action: #selector(copyAllsRows(_:)), keyEquivalent: "")
        copyAllItem.identifier = NSUserInterfaceItemIdentifier("salinSemua")
        copyAllItem.target = self
        menu.addItem(copyAllItem)
        
        return menu
    }
    func updateTableMenu(_ menu: NSMenu) {
        let foto = menu.item(at: 0)
        foto?.isHidden = true
        guard tableView.numberOfRows > 0 else {
            menu.items.forEach({ i in
                if i.title.lowercased() != "muat ulang" {
                    i.isHidden = true
                } else {
                    i.isHidden = true
                }
            })
            return
        }
        let muatUlang = menu.item(withTitle: "Muat Ulang")
        muatUlang?.isHidden = false
        guard tableView.clickedRow >= 0 else {
            let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
            salinSemua?.isHidden = false
            let salin = menu.item(withTitle: "Salin")
            salin?.isHidden = true
            return
        }
        
        muatUlang?.isHidden = true
        
        let salin = menu.item(withTitle: "Salin")
        salin?.isHidden = false
        
        let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
        salinSemua?.isHidden = true
    }
    func updateToolbarMenu(_ menu: NSMenu) {
        guard tableView.numberOfRows > 0 else {
            menu.items.forEach({ i in
                if i.title.lowercased() != "muat ulang" {
                    i.isHidden = true
                } else if i.title.lowercased() != "foto" {
                    i.isHidden = true
                } else {
                    i.isHidden = true
                }
            })
            return
        }
        let foto = menu.item(at: 0)
        foto?.isHidden = true
        guard tableView.numberOfSelectedRows >= 1 else {
            let salinSemua = menu.item(withTitle: "Salin Semua Jumlah Siswa")
            salinSemua?.isHidden = false
            let salin = menu.item(withTitle: "Salin")
            salin?.isHidden = true
            return
        }
        let salinSemua = menu.item(withTitle: "Salin")
        salinSemua?.isHidden = false
        
        let salin = menu.item(withTitle: "Salin")
        salin?.isHidden = false
    }
}

