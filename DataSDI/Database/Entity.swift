//
//  Entity.swift
//
//
//  Created by Bismillah on 06/11/24.
//
//

import CoreData
import Foundation

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
        NSFetchRequest<Entity>(entityName: "Entity")
    }
}

extension Entity {
    /// Enum representing the type of transaction.
    var jenisEnum: JenisTransaksi? {
        get { JenisTransaksi(rawValue: jenis) }
        set { jenis = newValue?.rawValue ?? 0 }
    }
}

/// Kriteria pengurutan untuk `Entity`.
///
/// `SortCriterion` menentukan urutan elemen berdasarkan atribut tertentu.
/// Setiap case memiliki *comparator* yang mengembalikan closure pembanding
/// `(Entity, Entity) -> ComparisonResult` untuk digunakan pada operasi sort.
///
/// Contoh penggunaan:
///
/// ```swift
/// let sorted = entities.sorted {
///     SortCriterion.jumlah.comparator($0, $1) == .orderedAscending
/// }
/// ```
enum SortCriterion: String {
    /// Urutkan berdasarkan tanggal terbaru ke terlama.
    case terbaru
    /// Urutkan berdasarkan tanggal terlama ke terbaru.
    case terlama
    /// Urutkan berdasarkan nama kategori (`kategori.value`) secara lokal.
    case kategori
    /// Urutkan berdasarkan nama acara (`acara.value`) secara lokal.
    case acara
    /// Urutkan berdasarkan nama keperluan (`keperluan.value`) secara lokal.
    case keperluan
    /// Urutkan berdasarkan nilai jumlah (`Double`).
    case jumlah
    /// Urutkan berdasarkan jenis transaksi (`pemasukan`, `pengeluaran`, `lainnya`).
    case transaksi
    /// Urutkan berdasarkan status tanda (`ditandai`), `true` lebih dulu.
    case bertanda

    /// Closure pembanding untuk kriteria ini.
    ///
    /// Mengembalikan closure `(Entity, Entity) -> ComparisonResult` yang
    /// membandingkan dua `Entity` sesuai kriteria yang dipilih.
    ///
    /// - Note: Semua logika pembanding terpusat di properti ini.
    var comparator: (Entity, Entity) -> ComparisonResult {
        switch self {
        case .terbaru:
            /// Urutkan dari tanggal terbaru (besar) ke terlama (kecil).
            { $1.tanggal?.compare($0.tanggal ?? .distantPast) ?? .orderedSame }
        case .terlama:
            /// Urutkan dari tanggal terlama (kecil) ke terbaru (besar).
            { $0.tanggal?.compare($1.tanggal ?? .distantPast) ?? .orderedSame }
        case .kategori:
            /// Urutkan berdasarkan kategori secara lokal.
            { ($0.kategori?.value ?? "").localizedStandardCompare($1.kategori?.value ?? "") }
        case .acara:
            /// Urutkan berdasarkan acara secara lokal.
            { ($0.acara?.value ?? "").localizedStandardCompare($1.acara?.value ?? "") }
        case .keperluan:
            /// Urutkan berdasarkan keperluan secara lokal.
            { ($0.keperluan?.value ?? "").localizedStandardCompare($1.keperluan?.value ?? "") }
        case .jumlah:
            /// Urutkan berdasarkan jumlah (`Double`).
            { compareValues($0.jumlah, $1.jumlah) }
        case .transaksi:
            /// Urutkan berdasarkan jenis transaksi sesuai urutan:
            /// `pemasukan` → `pengeluaran` → `lainnya`.
            {
                let order: [JenisTransaksi: Int] = [
                    .pemasukan: 0,
                    .pengeluaran: 1,
                    .lainnya: 2,
                ]
                let order1 = order[$0.jenisEnum ?? .lainnya] ?? 3
                let order2 = order[$1.jenisEnum ?? .lainnya] ?? 3
                return compareValues(order1, order2)
            }
        case .bertanda:
            /// Urutkan `true` (ditandai) sebelum `false` (tidak ditandai).
            {
                let ditandai2 = $0.ditandai ? 1 : 0
                let ditandai1 = $1.ditandai ? 1 : 0
                if ditandai2 > ditandai1 {
                    return .orderedAscending
                } else if ditandai2 < ditandai1 {
                    return .orderedDescending
                } else {
                    return .orderedSame
                }
            }
        }
    }
}

// Fungsi bantuan kecil untuk perbandingan numerik/boolean
private func compareValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
    if lhs < rhs { return .orderedAscending }
    if lhs > rhs { return .orderedDescending }
    return .orderedSame
}
