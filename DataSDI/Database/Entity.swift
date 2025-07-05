//
//  Entity+CoreDataClass.swift
//  
//
//  Created by Bismillah on 06/11/24.
//
//

import Foundation
import CoreData

@objc(Entity)
public class Entity: NSManagedObject, Identifiable {
    
    @NSManaged public var acara: UniqueString?
    @NSManaged public var bulan: Int16
    @NSManaged public var dari: String?
    @NSManaged public var ditandai: Bool
    @NSManaged public var id: UUID?
    @NSManaged public var jenis: Int16
    @NSManaged public var jumlah: Double
    @NSManaged public var kategori: UniqueString?
    @NSManaged public var keperluan: UniqueString?
    @NSManaged public var tahun: Int16
    @NSManaged public var tanggal: Date?
    
    public override func awakeFromInsert() {
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
    var jenisEnum: JenisTransaksi? {
        get { JenisTransaksi(rawValue: jenis) }
        set { jenis = newValue?.rawValue ?? 0 }
    }
}
