//
//  SharedQuickLook.swift
//  Data SDI
//
//  Created by MacBook on 14/06/25.
//

import Cocoa
import Quartz

/// ViewModel yang digunakan untuk menyimpan referensi `URL` item
/// di dalam penyimpanan permanen (Disk) yang dibuat oleh `ViewController`
/// yang berinteraksi untuk menampilkan foto di dalam `QLPreviewPanel`.
///
/// Class ini mematuhi protokol `QLPreviewPanelDataSource` dan `QLPreviewPanelDelegate`
/// dan bertanggung jawab pada pengelolaan animasi, menyimpan referensi data `URL`,
/// dan interaksi pengguna serta status `QLPreviewPanel`.
class SharedQuickLook: NSObject {
    /// Instans singleton ``SharedQuickLook``.
    static let shared: SharedQuickLook = .init()

    /// Panel QuickLook
    var panel: QLPreviewPanel!

    /// `NSTableView` yang berinteraksi untuk
    /// menampilkan konten di ``SharedQuickLook``.
    var sourceTableView: NSTableView?

    /// Propert direktori sementara ketika menampilkan pratinjau foto siswa dari
    /// ``DataSDI/SiswaViewController/showQuickLook(_:)`` ataupun dari ``DataSDI/InventoryView/showQuickLook(_:)``.
    private(set) var tempDir: URL?

    /// Properti yang menyimpan kumpulan `URL` ke file .png yang dibuat
    /// ketika ``showQuickLook()`` untuk menampilkan foto.
    private(set) var previewItems: [URL] = []

    /// Kolom yang digunakan untuk menentukan lokasi animasi zoom in/out ketika
    /// menampilkan/menutup quick look.
    var columnIndex: Int = 0

    /// Private init untuk mencegah class ``SharedQuickLook`` menggunakan inisialisasi baru.
    override private init() {
        super.init()
        panel = QLPreviewPanel.shared()
        panel.delegate = self
        panel.dataSource = self
    }

    /// Fungsi untuk membersihkan ``tempDir`` yang digunakan
    /// untuk item yang sedang ditampilkan di QuickLook.
    func cleanTempDir() {
        tempDir = nil
    }

    /// Fungsi yang mengatur URL file yang dibuat setelah mendapatkan
    /// data foto dari database atau data model dan disalin ke penyimpanan
    /// permanen (Disk).
    /// - Parameter URL:URL yang akan digunakan ``panel`` QuickLook.
    func setTempDir(_ URL: URL) {
        tempDir = URL
    }

    /// Fungsi untuk mendapatkan URL dari ``tempDir``.
    /// - Returns: URL yang disimpan di ``tempDir``.
    func getTempDir() -> URL? {
        tempDir
    }

    /// Fungsi untuk memeriksa visibilitas ``panel``.
    /// - Returns: True berarti panel sedang ditampilkan.
    ///            False berarti panel tidak ditampilkan.
    func isQuickLookVisible() -> Bool {
        panel.isVisible
    }

    /// Fungsi untuk menghapus semua referensi `URL` yang ada di ``previewItems``.
    func cleanPreviewItems() {
        previewItems.removeAll()
    }

    /// Fungsi untuk menambahkan `URL` untuk ditambahkan
    /// ke koleksi `URL`  ke ``previewItems``.
    /// - Parameter url: Nilai `URL` yang akan ditambahkan ke koleksi.
    func setPreviewItems(_ url: URL) {
        previewItems.append(url)
    }

    /// Fungsi untuk menampilkan QuickLook atau memuat ulang ``panel``
    /// jika `panel` telah ditampilkan.
    /// Dengan cara memperbarui `controller panel` dan
    /// memeriksa visibilitas  `panel`.
    func showQuickLook() {
        panel.updateController()
        // Jika panel sudah visible, reload data
        if panel.isVisible {
            panel.reloadData()
        } else {
            beginPreviewPanelControl(panel)
            panel.isFloatingPanel = true
        }
    }

    /// Fungsi yang digunakan untuk menutup ``panel`` QuickLook
    /// dan menjalankan beberapa fungsi pembersihan item yang digunakan QuickLook.
    ///
    /// Berikut fungsi yang dijalankan setelah ``panel``QuickLook  ditutup:
    /// - ``cleanTempDir()``
    /// - ``cleanQuickLook()``
    func closeQuickLook() {
        panel.close()
        cleanTempDir()
        cleanQuickLook()
    }

    /// Fungsi untuk membersihkan item QuickLook yang terdapat di dalam
    /// penyimpanan permanen (Disk).
    ///
    /// Fungsi ini dijalankan di latar belakang menggunakan GCD dengan prioritas `utility`.
    func cleanQuickLook() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            do {
                // Cleanup temporary files
                if let tempDir {
                    try FileManager.default.removeItem(at: tempDir)
                    self.tempDir = nil
                }

                for url in previewItems {
                    try FileManager.default.removeItem(at: url)
                }
                cleanPreviewItems()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

extension SharedQuickLook: QLPreviewPanelDataSource {
    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItems[index] as QLPreviewItem
    }
}

extension SharedQuickLook: QLPreviewPanelDelegate {
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.makeKeyAndOrderFront(nil)
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.orderOut(nil)
        cleanQuickLook()
    }

    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        true
    }

    func previewPanel(_: QLPreviewPanel!, sourceFrameOnScreenFor _: QLPreviewItem!) -> NSRect {
        guard let tableView = sourceTableView, let index = tableView.selectedRowIndexes.last else { return NSZeroRect }
        var returnIconRect = NSZeroRect
        if index != NSNotFound {
            var iconRect = tableView.frameOfCell(atColumn: columnIndex, row: index)

            // fix icon width
            iconRect.size.width = iconRect.size.height
            let visibleRect = tableView.visibleRect

            if NSIntersectsRect(visibleRect, iconRect) {
                var convertedRect = tableView.convert(iconRect, to: nil)
                convertedRect.origin = (tableView.window?.convertPoint(toScreen: convertedRect.origin))!
                returnIconRect = convertedRect
            }
        }
        return returnIconRect
    }

    func previewPanel(_: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect _: UnsafeMutablePointer<NSRect>!) -> Any! {
        if let url = item.previewItemURL {
            // Coba memuat NSImage dari URL tersebut
            if let image = NSImage(contentsOf: url) {
                // Sesuaikan contentRect jika diperlukan
                return image
            }
        }
        return nil
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let tableView = sourceTableView else { return false }
        // Handle key events
        if event.type == .keyDown {
            switch event.keyCode {
            case 125: // Down arrow
                let nextIndex = tableView.selectedRowIndexes.first.map { $0 + 1 }
                if let next = nextIndex, next < tableView.numberOfRows {
                    tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
                    tableView.scrollRowToVisible(next)
                    showQuickLook()
                }
                return true
            case 126: // Up arrow
                let prevIndex = tableView.selectedRowIndexes.first.map { $0 - 1 }
                if let prev = prevIndex, prev >= 0 {
                    tableView.selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
                    tableView.scrollRowToVisible(prev)
                    showQuickLook()
                }
                return true
            case 49: // Space
                endPreviewPanelControl(panel)
                return true
            default:
                return false
            }
        }
        return false
    }
}
