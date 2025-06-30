//
//  XSDragImageView.swift
//  Data SDI
//
//  Created by Bismillah on 14/12/23.
//

import Cocoa

/// Sebuah class dari proyek Objective-C dengan nama XSDragImageView yang tersedia di GitHub dan telah dikonversi ke Swift.
///
/// Ada beberapa tambahan dan modifikasi.
class XSDragImageView: NSImageView, NSDraggingSource {
    
    /// Properti untuk menyimpan referensi jika gambar sedang disorot.
    var isHighLighted: Bool = false
    
    /// Gambar yang ditampilkan.
    var selectedImage: NSImage?
    
    /// Nama siswa
    var nama: String?
    
    /// Direktori sementara untuk menyimpan foto yang di drag.
    var tempFileURL: URL?
    
    /// Properti referensi untuk menonaktifkan/mengaktifkan drag foto.
    /// Ketika foto masih kosong atau dihapus, drag foto dinonaktifkan.
    var enableDrag: Bool = false

    /// Properti yang digunakan untuk mengatur foto yang di-drag menggunakan
    /// `NSDraggingItem(pasteboardWriter:)`.
    var draggingItem: NSDraggingItem?
    
    /// Nilai minimum zoom di superView.
    var clampedMagnification: CGFloat?
    
    /// Properti yang menunjukkan jika superView sedang menjalankan aksi
    /// drag untuk scrolling foto. Ketika nilai ini `false`, kursor mouse
    /// akan diubah ke openHand(tangan terbuka) jika foto melebihi ukuran
    /// superView (sedang diperbesar).
    var superViewDragging: Bool = false {
        didSet {
            if !superViewDragging {
                addCursorRect(bounds, cursor: NSCursor.openHand)
            }
        }
    }

    // MARK: - init and dealloc

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.tiff, .png, .fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.tiff, .png, .fileURL])
    }

    // MARK: - Mouse Action
    
    override func resetCursorRects() {
        super.resetCursorRects()
        guard let scrollView = superview?.superview as? NSScrollView,
              let clampedMagnification, !enableDrag
        else {
            print("scrollView tidak ditemukan")
            return
        }
        
        if scrollView.magnification > clampedMagnification {
            // Saat di-zoom, area imageView pakai kursor openHand
            if superViewDragging {
                addCursorRect(bounds, cursor: NSCursor.closedHand)
            } else {
                addCursorRect(bounds, cursor: NSCursor.openHand)
            }
        } else {
            // Saat fit-to-view, pakai arrow
            addCursorRect(bounds, cursor: NSCursor.arrow)
        }
        
    }
    
    override func mouseDown(with event: NSEvent) {
        guard enableDrag, let image, let nama else { return }
        let scaledSize = scaledDragSize(for: image.size, maxDimension: 256)

        let mouseLocationInWindow = event.locationInWindow

        // Biasanya drag preview di-offset supaya mouse berada di tengah preview:
        let dragOriginInWindow = NSPoint(
            x: mouseLocationInWindow.x - scaledSize.width / 2.0,
            y: mouseLocationInWindow.y - scaledSize.height / 2.0
        )
        
        // 1. Simpan image ke file sementara
        tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(nama.replacingOccurrences(of: "/", with: "-")).jpeg")

        guard let tempFileURL else { return }
        
        try? FileManager.default.removeItem(at: tempFileURL)
        
        if let pngData = image.jpegRepresentation {
            try? pngData.write(to: tempFileURL)
        } else {
            return
        }

        // 2. Buat dragging item sebagai file URL
        draggingItem = NSDraggingItem(pasteboardWriter: tempFileURL as NSURL)
        
        let dragFrameInWindow = NSRect(origin: dragOriginInWindow, size: scaledSize)
        draggingItem?.draggingFrame = dragFrameInWindow

        draggingItem?.imageComponentsProvider = {
            let component = NSDraggingImageComponent(key: .label)
            component.contents = image
            component.frame = NSRect(origin: .zero, size: scaledSize)
            return [component]
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        // 3. Mulai drag session
        guard let draggingItem else { return }
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }



    // MARK: - Source Operation

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        guard enableDrag else { return [] }
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        draggingItem = nil
    }
    // MARK: - Destination Operation

    /// Properti untuk menyimpan gambar yang saat ini di drag.
    var draggedImage: NSImage?
    
    /// Properti untuk menyimpan gambar sebelum drag & drop.
    /// Digunakan untuk mengembalikan gambar jika drag di batalkan
    /// atau gambar yang di drop dihapus.
    var imageNow: NSImage?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let sourceView = sender.draggingSource as? NSImageView,
           sourceView === self
        {
            return []
        }
        
        let pboard = sender.draggingPasteboard

        // Mengecek apakah ada data gambar di dalam pasteboard
        if pboard.availableType(from: registeredDraggedTypes) != nil {
            if let image = NSImage(pasteboard: pboard) {
                draggedImage = image
                imageNow = self.image?.copy() as? NSImage

            } else {}

            isHighLighted = true
            updateHighlight()
            needsDisplay = true
            return NSDragOperation.copy
        }

        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if let sourceView = sender?.draggingSource as? NSImageView,
           sourceView === self
        {
            return
        }
        unhighlight()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Tambahkan opsi Hapus ke menu
        let deleteMenuItem = NSMenuItem(title: "Hapus", action: #selector(deleteImage(_:)), keyEquivalent: "")
        menu.addItem(deleteMenuItem)

        return menu
    }

    
    @objc
    /// Fungsi untuk menghapus gambar yang ditampilkan.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    func deleteImage(_ sender: Any?) {
        if let pratinjauFoto = superview,
           let targetViewController = ReusableFunc.findViewController(from: pratinjauFoto.nextResponder, ofType: PratinjauFoto.self)
        {
            // NSViewController dari superview ditemukan dan sudah bertipe AddDataViewController.
            if let previousImage = imageNow {
                // Hapus gambar dan reset tampilan
                image = previousImage
                imageNow = nil
                targetViewController.simpanFotoMenuItem.isHidden = true
                targetViewController.setImageView(previousImage)
                targetViewController.scrollView.layoutSubtreeIfNeeded()
                targetViewController.fitInitialImage(previousImage)
            } else {
                image = NSImage(named: "image")
                targetViewController.simpanFotoMenuItem.isHidden = false
            }
            #if DEBUG
            print("AddDataViewController ditemukan dan updateStackViewSize() dipanggil.")
            #endif
        } else {
            #if DEBUG
            print("Superview tidak ditemukan.")
            #endif
        }
        
        selectedImage = nil
        needsDisplay = true
        enableDrag = false
    }

    private func unhighlight() {
        if let previousImage = imageNow {
            image = previousImage
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        draggedImage = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let sourceView = sender.draggingSource as? NSImageView,
           sourceView === self
        {
            return false
        }
        
        guard let imageURL = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL else {
            // Tidak dapat membaca URL dari clipboard
            return false
        }

        do {
            let imageData = try Data(contentsOf: imageURL)

            if let image = NSImage(data: imageData), let compressed = image.compressImage(quality: 0.5), let finalImage = NSImage(data: compressed) {
                if let pratinjauFoto = superview { // Pastikan superview ada
                    if let targetViewController = ReusableFunc.findViewController(from: pratinjauFoto.nextResponder, ofType: PratinjauFoto.self) {
                        // NSViewController dari superview ditemukan dan sudah bertipe AddDataViewController.
                        targetViewController.setImageView(finalImage)
                        targetViewController.scrollView.layoutSubtreeIfNeeded()
                        targetViewController.simpanFotoMenuItem.isHidden = false
                        targetViewController.fitInitialImage(finalImage)
                        #if DEBUG
                        print("AddDataViewController ditemukan dan updateStackViewSize() dipanggil.")
                        #endif
                    } else {
                        #if DEBUG
                        print("AddDataViewController tidak ditemukan di rantai responder.")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("Superview tidak ditemukan.")
                    #endif
                }
                selectedImage = image
                enableDrag = true
            }
        } catch {
            return false
        }

        needsDisplay = true
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        needsDisplay = true
    }

    private func updateHighlight() {
        if let image = draggedImage {
            // Atur properti NSImageView
            imageScaling = .scaleProportionallyUpOrDown
            imageAlignment = .alignCenter

            // Hitung proporsi aspek gambar
            let aspectRatio = image.size.width / image.size.height

            // Hitung dimensi baru untuk gambar
            let newWidth = min(frame.width, frame.height * aspectRatio)
            let newHeight = newWidth / aspectRatio

            // Atur ukuran gambar sesuai proporsi aspek
            image.size = NSSize(width: newWidth, height: newHeight)

            // Setel gambar ke NSImageView
            self.image = image
            
            // Misalkan ini adalah kode di dalam NSView Anda atau di mana pun Anda memiliki akses ke `self` (NSView)
            if let addData = superview { // Pastikan superview ada
                if let targetViewController = ReusableFunc.findViewController(from: addData.nextResponder, ofType: AddDataViewController.self) {
                    // NSViewController dari superview ditemukan dan sudah bertipe AddDataViewController.
                    targetViewController.updateStackViewSize()
                    #if DEBUG
                    print("AddDataViewController ditemukan dan updateStackViewSize() dipanggil.")
                    #endif
                } else {
                    #if DEBUG
                    print("AddDataViewController tidak ditemukan di rantai responder.")
                    #endif
                }
            } else {
                #if DEBUG
                print("Superview tidak ditemukan.")
                #endif
            }
        }
    }
    
    /// Menghitung ukuran gambar yang telah diskalakan agar tidak melebihi dimensi maksimum tertentu,
    /// sambil mempertahankan rasio aspek asli gambar.
    ///
    /// Fungsi ini berguna untuk membatasi ukuran pratinjau gambar saat proses drag-and-drop,
    /// sehingga pratinjau tidak terlalu besar dan tetap proporsional.
    ///
    /// - Parameters:
    ///   - imageSize: Ukuran asli gambar yang akan diskalakan.
    ///   - maxDimension: Batas panjang maksimum sisi terpanjang gambar (dalam satuan poin).
    ///
    /// - Returns: Ukuran gambar yang telah diskalakan dengan rasio aspek tetap.
    func scaledDragSize(for imageSize: NSSize, maxDimension: CGFloat) -> NSSize {
        let aspectRatio = imageSize.width / imageSize.height
        var width = imageSize.width
        var height = imageSize.height
        
        if width > height {
            if width > maxDimension {
                width = maxDimension
                height = width / aspectRatio
            }
        } else {
            if height > maxDimension {
                height = maxDimension
                width = height * aspectRatio
            }
        }
        return NSSize(width: width, height: height)
    }

    
    deinit {
        #if DEBUG
            print("deinit XSDragImageView")
        #endif
        
        if let tempFileURL {
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }
    }
}

extension NSImage {
    /// Mengompresi NSImage menjadi format JPEG dengan tingkat kualitas tertentu.
    ///
    /// - Parameter quality: Nilai antara 0.0 hingga 1.0.
    ///   Semakin rendah nilainya, semakin tinggi kompresi (dan semakin rendah kualitas gambar).
    ///
    /// - Returns: Objek `Data` berisi representasi JPEG dari gambar, atau `nil` jika konversi gagal.
    func compressImage(quality: CGFloat) -> Data? {
        // Ambil representasi TIFF dari NSImage
        guard let tiffData = tiffRepresentation else {
            return nil  // Gagal mendapatkan data gambar
        }

        // Buat NSBitmapImageRep dari data TIFF
        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            return nil  // Gagal membuat representasi bitmap
        }

        // Kembalikan data gambar dalam format JPEG dengan tingkat kompresi tertentu
        return bitmapImageRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }
}

extension NSImage {
    /// Mengompres `NSImage` menjadi data gambar (JPEG atau PNG) dengan tingkat kualitas tertentu,
    /// dengan opsi untuk mempertahankan transparansi gambar.
    ///
    /// - Parameters:
    ///   - quality: Nilai dari 0.0 hingga 1.0. Semakin rendah nilainya, semakin tinggi kompresi
    ///              (dan semakin rendah kualitas gambar).
    ///   - preserveTransparency: Bool opsional (default: `false`). Jika `true`, transparansi akan
    ///              dipertahankan menggunakan format PNG. Jika `false`, gambar dikonversi ke JPEG
    ///              (yang tidak mendukung transparansi).
    ///
    /// - Returns: Objek `Data` yang berisi hasil kompresi gambar (dalam format JPEG atau PNG),
    ///            atau `nil` jika proses konversi gagal.
    func compressImage(quality: CGFloat, preserveTransparency: Bool = false) -> Data? {
        // Ambil representasi TIFF dari NSImage
        guard let tiffData = tiffRepresentation else {
            return nil  // Gagal mendapatkan representasi gambar
        }

        // Buat representasi bitmap dari data TIFF
        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            return nil  // Gagal membuat representasi bitmap
        }

        if preserveTransparency {
            // Kompres sebagai PNG untuk mempertahankan transparansi (alpha channel)
            return bitmapImageRep.representation(using: .png, properties: [
                .compressionFactor: quality, // PNG compression (lossless, tetapi faktor ini bisa memengaruhi ukuran)
                .interlaced: false           // Non-interlaced untuk hasil lebih sederhana
            ])
        } else {
            // Kompres sebagai JPEG untuk ukuran file lebih kecil (tidak mendukung transparansi)
            return bitmapImageRep.representation(using: .jpeg, properties: [
                .compressionFactor: quality
            ])
        }
    }

}

// MARK: - NSImage Extension for PNG and JPEG Representation
extension NSImage {
    /// Menghasilkan representasi data PNG dari objek `NSImage`.
    ///
    /// Properti ini digunakan untuk mengonversi gambar yang saat ini dimuat dalam `NSImage`
    /// ke format PNG dalam bentuk `Data`. Konversi dilakukan melalui representasi TIFF internal.
    ///
    /// - Returns: Data dalam format PNG (`Data?`), atau `nil` jika proses konversi gagal.
    var pngRepresentation: Data? {
        // Ambil data TIFF dari NSImage (representasi internal berbasis bitmap)
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil  // Gagal mendapatkan data TIFF atau membuat bitmap
        }

        // Kembalikan data dalam format PNG (tanpa properti tambahan)
        return bitmapImage.representation(using: .png, properties: [:])
    }

    /// Menghasilkan representasi data JPEG dari objek `NSImage` dengan tingkat kompresi default.
    ///
    /// Properti ini mengonversi gambar saat ini dalam `NSImage` ke format JPEG dengan
    /// tingkat kompresi sedang (compressionFactor = 0.7). JPEG cocok untuk foto atau
    /// gambar yang tidak memerlukan transparansi.
    ///
    /// - Returns: Data dalam format JPEG (`Data?`), atau `nil` jika proses konversi gagal.
    var jpegRepresentation: Data? {
        // Ambil representasi TIFF dari NSImage (dibutuhkan untuk konversi ke bitmap)
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil  // Gagal membuat bitmap dari TIFF
        }

        // Kembalikan data gambar dalam format JPEG dengan tingkat kompresi 0.7
        return bitmapImage.representation(using: .jpeg, properties: [
            .compressionFactor: 0.7  // Nilai antara 0.0 (kompresi tinggi) dan 1.0 (kualitas tinggi)
        ])
    }
}
