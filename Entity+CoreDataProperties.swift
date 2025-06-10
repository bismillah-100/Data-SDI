//
//  Entity+CoreDataProperties.swift
//  
//
//  Created by Bismillah on 06/11/24.
//
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }

    @NSManaged public var acara: String?
    @NSManaged public var bulan: Int64
    @NSManaged public var dari: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isEdited: Bool
    @NSManaged public var jenis: String?
    @NSManaged public var jumlah: Double
    @NSManaged public var kategori: String?
    @NSManaged public var keperluan: String?
    @NSManaged public var tahun: Int64
    @NSManaged public var tanggal: Date?
    @NSManaged public var ditandai: Bool = false
}
