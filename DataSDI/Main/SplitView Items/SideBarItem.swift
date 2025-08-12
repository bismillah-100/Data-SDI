//
//  SideBarItem.swift
//  Data Manager
//
//  Created by Bismillah on 14/11/23.
//

import Cocoa
import Foundation

/// Class SidebarItem yang merepresentasikan item di sidebar
/// Class ini memiliki nama, identifier, dan gambar (image) yang ditampilkan di sidebar.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar.
/// dapat digunakan untuk membuat item sidebar yang dapat berupa item biasa atau grup,
/// memiliki properti `type` yang mengindikasikan apakah item tersebut adalah item biasa atau grup,
/// memiliki inisialisasi yang menerima nama, identifier, dan gambar,
/// dapat digunakan untuk membuat item sidebar yang dapat berupa item biasa atau grup,
/// juga memiliki properti `type` yang mengindikasikan apakah item tersebut adalah item biasa atau grup.
class SidebarItem {
    var name: String
    let identifier: String
    let image: NSImage?
    let index: SidebarIndex

    init(name: String, identifier: String, image: NSImage?, index: SidebarIndex) {
        self.name = name
        self.image = image
        self.identifier = identifier
        self.index = index
    }
}

/// Protokol SidebarGroup yang mendefinisikan struktur grup sidebar
/// Protokol ini memiliki properti `name`, `children`, dan `type`.
/// `name` adalah nama grup, `children` adalah daftar item sidebar yang termasuk dalam grup,
/// dan `type` adalah tipe item sidebar yang selalu berupa grup.
/// Protokol ini digunakan untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
protocol SidebarGroup {
    var identifier: String { get }
    var name: String { get }
    var children: [SidebarItem] { get }
}

/// Class yang mengimplementasikan SidebarGroup untuk grup "Administrasi"
/// Class ini memiliki nama grup dan daftar item sidebar yang termasuk dalam grup.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait administrasi, seperti pengaturan, laporan, dan lainnya.
class AdministrasiParentItem: SidebarGroup {
    var identifier = "Administrasi"
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

/// Class yang mengimplementasikan SidebarGroup untuk grup "Daftar"
/// Class ini memiliki nama grup dan daftar item sidebar yang termasuk dalam grup.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait daftar, seperti daftar siswa, daftar guru, daftar kelas, dan lainnya.
class DaftarParentItem: SidebarGroup {
    let identifier: String
    let name: String
    var children: [SidebarItem]

    init(identifier: String, name: String, children: [SidebarItem]) {
        self.identifier = identifier
        self.name = name
        self.children = children
    }
}
