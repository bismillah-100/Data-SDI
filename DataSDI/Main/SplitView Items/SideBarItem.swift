//
//  SideBarItem.swift
//  Data Manager
//
//  Created by Bismillah on 14/11/23.
//

import Cocoa
import Foundation

/// Enum untuk menentukan tipe node yang ada di sidebar
/// Tipe ini digunakan untuk mengelompokkan node berdasarkan fungsinya, seperti container, document, separator, dan lainnya.
enum NodeType: Int, Codable {
    case container
    case document
    case separator
    case unknown
    case daftar // Tambahkan tipe untuk grup "Daftar"
}

/// Class Node yang merepresentasikan item di sidebar
/// Class ini mengimplementasikan protokol Codable untuk serialisasi dan deserialisasi.
/// Node memiliki tipe, judul, identifier, URL, dan daftar anak (children).
class Node: NSObject, Codable {
    var type: NodeType = .unknown
    var title: String = ""
    var identifier: String = ""
    var url: URL?
    @objc dynamic var children = [Node]()
    var isExpandable: Bool {
        !children.isEmpty
    }
}

extension [Node] {
    /// Fungsi untuk mencari node pertama yang memenuhi kondisi tertentu
    ///
    /// - Parameter predicate: A closure yang menerima elemen dari array dan mengembalikan nilai boolean.
    ///   Jika closure mengembalikan true, node tersebut akan dianggap sebagai hasil yang cocok.
    /// - Returns: Node pertama yang memenuhi kondisi, atau nil jika tidak ada yang cocok.
    func firstNode(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        for element in self {
            if try predicate(element) {
                return element
            }
            if let matched = try element.children.firstNode(where: predicate) {
                return matched
            }
        }
        return nil
    }
}

/// Class SidebarItem yang merepresentasikan item di sidebar
/// Class ini memiliki nama, identifier, dan gambar (image) yang ditampilkan di sidebar.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar.
/// dapat digunakan untuk membuat item sidebar yang dapat berupa item biasa atau grup,
/// memiliki properti `type` yang mengindikasikan apakah item tersebut adalah item biasa atau grup,
/// memiliki inisialisasi yang menerima nama, identifier, dan gambar,
/// dapat digunakan untuk membuat item sidebar yang dapat berupa item biasa atau grup,
/// juga memiliki properti `type` yang mengindikasikan apakah item tersebut adalah item biasa atau grup.
class SidebarItem {
    let name: String
    let identifier: String
    let image: NSImage?

    init(name: String, identifier: String, image: NSImage?) {
        self.name = name
        self.image = image
        self.identifier = identifier
    }
}

/// Enum untuk menentukan tipe item sidebar
/// Tipe ini digunakan untuk mengelompokkan item sidebar menjadi item biasa atau grup.
enum SidebarItemType {
    case item
    case group
}

/// Protokol SidebarGroup yang mendefinisikan struktur grup sidebar
/// Protokol ini memiliki properti `name`, `children`, dan `type`.
/// `name` adalah nama grup, `children` adalah daftar item sidebar yang termasuk dalam grup,
/// dan `type` adalah tipe item sidebar yang selalu berupa grup.
/// Protokol ini digunakan untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
protocol SidebarGroup {
    var name: String { get }
    var children: [SidebarItem] { get }
    var type: SidebarItemType { get }
}

extension SidebarGroup {
    /// Properti `type` yang mengembalikan tipe item sidebar sebagai grup
    /// Ini digunakan untuk mengindikasikan bahwa item ini adalah grup yang dapat memiliki sub-item.
    /// - Returns: Tipe item sidebar yang selalu berupa grup.
    /// - Note: Implementasi ini mengembalikan nilai `.group` untuk menandakan bahwa item ini adalah grup.
    var type: SidebarItemType { .group }
}

/// Class yang mengimplementasikan SidebarGroup untuk grup "Administrasi"
/// Class ini memiliki nama grup dan daftar item sidebar yang termasuk dalam grup.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait administrasi, seperti pengaturan, laporan, dan lainnya.
class AdministrasiParentItem: SidebarGroup {
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
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait daftar, seperti daftar siswa, daftar kelas, dan lainnya.
class DaftarParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

/// Class yang mengimplementasikan SidebarGroup untuk grup "Statistik"
/// Class ini memiliki nama grup dan daftar item sidebar yang termasuk dalam grup.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait statistik, seperti grafik, laporan statistik, dan lainnya.
class StatistikParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

/// Class yang mengimplementasikan SidebarGroup untuk grup "Kelas"
/// Class ini memiliki nama grup dan daftar item sidebar yang termasuk dalam grup.
/// Class ini juga mengimplementasikan protokol SidebarGroup untuk mengelompokkan item sidebar menjadi grup yang memiliki sub-item.
/// Class ini digunakan untuk membuat grup sidebar yang berisi item-item terkait kelas.
class KelasParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}
