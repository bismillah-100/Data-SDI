//
//  Entity+CoreDataClass.swift
//  
//
//  Created by Bismillah on 06/11/24.
//
//

import Foundation
import CoreData

/// This file was generated and should not be edited.
@objc(Entity)
public class Entity: NSManagedObject, Identifiable {
    /// The `UniqueString` type is assumed to be a custom type that conforms to `NSManagedObject` and is used for storing unique string values.
    /// If `UniqueString` is not defined, you should define it or replace it with `String` or another appropriate type.
    @NSManaged public var acara: UniqueString?
    @NSManaged public var bulan: Int16
    @NSManaged public var dari: String?
    @NSManaged public var ditandai: Bool
    @NSManaged public var id: UUID?
    @NSManaged public var jenis: Int16
    @NSManaged public var jumlah: Double
    /// The `UniqueString` type is assumed to be a custom type that conforms to `NSManagedObject` and is used for storing unique string values.
    /// If `UniqueString` is not defined, you should define it or replace it with `String` or another appropriate type.
    @NSManaged public var kategori: UniqueString?
    /// The `UniqueString` type is assumed to be a custom type that conforms to `NSManagedObject` and is used for storing unique string values.
    /// If `UniqueString` is not defined, you should define it or replace it with `String` or another appropriate type.
    @NSManaged public var keperluan: UniqueString?
    @NSManaged public var tahun: Int16
    @NSManaged public var tanggal: Date?

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        // Pastikan UUID di-set jika belum ada (untuk entitas yang baru)
        if id == nil {
            id = UUID() // UUID baru akan dihasilkan
        }
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }
}

extension Entity {
    /// Enum representing the type of transaction.
    var jenisEnum: JenisTransaksi? {
        get { JenisTransaksi(rawValue: jenis) }
        set { jenis = newValue?.rawValue ?? 0 }
    }
}
