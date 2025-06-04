//
//  SideBarItem.swift
//  Data Manager
//
//  Created by Bismillah on 14/11/23.
//

import Foundation
import Cocoa
enum NodeType: Int, Codable {
    case container
    case document
    case separator
    case unknown
    case daftar // Tambahkan tipe untuk grup "Daftar"
}

class Node: NSObject, Codable {
    var type: NodeType = .unknown
    var title: String = ""
    var identifier: String = ""
    var url: URL?
    @objc dynamic var children = [Node]()
    var isExpandable: Bool {
        return !children.isEmpty
    }
}
extension Array where Self.Element == Node {
    // Search for a node (recursively) until a matching element is found
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

class SidebarItem {
    let name: String
    let identifier: String
    let image: NSImage?

    // ...

    init(name: String, identifier: String, image: NSImage?) {
        self.name = name
        self.image = image
        self.identifier = identifier
    }
}
enum SidebarItemType {
    case item
    case group
}
protocol SidebarGroup {
    var name: String { get }
    var children: [SidebarItem] { get }
    var type: SidebarItemType {get}
    
}
extension SidebarGroup {
    var type: SidebarItemType{ return .group }
    
}
class AdministrasiParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

class DaftarParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

class StatistikParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}

class KelasParentItem: SidebarGroup {
    let name: String
    var children: [SidebarItem]

    init(name: String, children: [SidebarItem]) {
        self.name = name
        self.children = children
    }
}
