//
//  OverlayEditor Protocol + Delegate.swift
//  tableViewCellOverlay
//
//  Created by Ays on 15/05/25.
//
import Cocoa

/// Enum untuk arah pertumbuhan, bisa diletakkan di sini atau di dalam OverlayEditorManager
enum GrowthDirection { case upwards, downwards }

/// Protokol untuk mengelola editor overlay pada NSTableView.
@objc protocol OverlayEditorManagerDataSource: AnyObject {
    /// Memberikan teks awal untuk editor
    func overlayEditorManager(_ manager: OverlayEditorManager, textForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> String
    /// Memberikan lebar kolom asli (untuk perhitungan lebar editor)
    func overlayEditorManager(_ manager: OverlayEditorManager, originalColumnWidthForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> CGFloat
    /// Meneruskan suggestions untuk editor teks (NSTextView)
    @objc optional func overlayEditorManager(_ manager: OverlayEditorManager, suggestionsForCellAtColumn column: Int, in tableView: NSTableView) -> [String]

    // Opsional: Memberikan NSTableCellView jika manager perlu mengaksesnya secara langsung untuk alasan tertentu
    // func overlayEditorManager(_ manager: OverlayEditorManager, cellViewForCellAtRow row: Int, column: Int, in tableView: NSTableView) -> NSTableCellView?
}

/// Protokol untuk menangani event dan aksi yang terkait dengan editor overlay.
/// Protokol ini akan digunakan oleh delegate untuk menangani event seperti commit atau cancel editing.
@objc protocol OverlayEditorManagerDelegate: AnyObject {
    /// Dipanggil setelah teks berhasil diedit dan di-commit
    func overlayEditorManager(_ manager: OverlayEditorManager, didUpdateText newText: String, forCellAtRow row: Int, column: Int, in tableView: NSTableView)
    /// Dipanggil jika pengeditan dibatalkan
    @objc optional func overlayEditorManagerDidCancelEditing(_ manager: OverlayEditorManager, forCellAtRow row: Int, column: Int, in tableView: NSTableView)
    /// Opsi untuk menonaktifkan pengeditan kolom dan baris tertentu jika diset ke false
    func overlayEditorManager(_ manager: OverlayEditorManager, perbolehkanEdit column: Int, row: Int) -> Bool
    // Opsional: Dipanggil tepat sebelum editor ditampilkan, jika ada setup tambahan yang perlu dilakukan oleh delegate
    // func overlayEditorManager(_ manager: OverlayEditorManager, willShowEditorForCellAtRow row: Int, column: Int, cellView: NSTableCellView, in tableView: NSTableView)
}
