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
public class Entity: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        // Pastikan UUID di-set jika belum ada (untuk entitas yang baru)
        if id == nil {
            id = UUID() // UUID baru akan dihasilkan
        }
    }
}
