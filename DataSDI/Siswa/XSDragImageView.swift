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
    var isHighLighted: Bool = false
    var selectedImage: NSImage?
    var enableDrag: Bool = true

    // MARK: - init and dealloc

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.png, NSPasteboard.PasteboardType.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.png, NSPasteboard.PasteboardType.fileURL])
    }

    // MARK: - Mouse Action

    override func mouseDown(with theEvent: NSEvent) {
        guard enableDrag else { return }
        let dragItem = NSDraggingItem(pasteboardWriter: image!)
        dragItem.draggingFrame = bounds
        dragItem.imageComponentsProvider = {
            let component = NSDraggingImageComponent(key: NSDraggingItem.ImageComponentKey.icon)
            component.contents = self.image
            component.frame = self.bounds
            return [component]
        }
        beginDraggingSession(with: [dragItem], event: theEvent, source: self)
    }

    // MARK: - Source Operation

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        guard enableDrag else { return NSDragOperation() }
        return NSDragOperation.copy
    }

    // MARK: - Destination Operation

    var draggedImage: NSImage?
    var imageNow: NSImage?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
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

        return NSDragOperation()
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        unhighlight()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Tambahkan opsi Hapus ke menu
        let deleteMenuItem = NSMenuItem(title: "Hapus", action: #selector(deleteImage(_:)), keyEquivalent: "")
        menu.addItem(deleteMenuItem)

        return menu
    }

    @objc func deleteImage(_ sender: Any?) {
        // Hapus gambar dan reset tampilan
        image = NSImage(named: "image")
        imageScaling = .scaleProportionallyDown
        selectedImage = nil
        needsDisplay = true
    }

    private func unhighlight() {
        if let previousImage = imageNow {
            image = previousImage
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {}

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let imageURL = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL else {
            // Tidak dapat membaca URL dari clipboard

            return false
        }

        do {
            let imageData = try Data(contentsOf: imageURL)

            if let image = NSImage(data: imageData) {
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
                selectedImage = image
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
        if let draggedImage {
            // Atur properti NSImageView
            imageScaling = .scaleProportionallyUpOrDown
            imageAlignment = .alignCenter

            // Hitung proporsi aspek gambar
            let aspectRatio = draggedImage.size.width / draggedImage.size.height

            // Hitung dimensi baru untuk gambar
            let newWidth = min(frame.width, frame.height * aspectRatio)
            let newHeight = newWidth / aspectRatio

            // Atur ukuran gambar sesuai proporsi aspek
            draggedImage.size = NSSize(width: newWidth, height: newHeight)

            // Setel gambar ke NSImageView
            image = draggedImage
        }
    }
}

extension NSImage {
    func compressImage(quality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation else {
            return nil
        }

        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapImageRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}

extension NSImage {
    func compressImage(quality: CGFloat, preserveTransparency: Bool = false) -> Data? {
        guard let tiffData = tiffRepresentation else {
            return nil
        }

        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        if preserveTransparency {
            // Gunakan PNG untuk mempertahankan transparansi
            return bitmapImageRep.representation(using: .png, properties: [
                .compressionFactor: quality,
                .interlaced: false,
            ])
        } else {
            // Gunakan JPEG untuk kompresi yang lebih baik (tanpa transparansi)
            return bitmapImageRep.representation(using: .jpeg, properties: [
                .compressionFactor: quality,
            ])
        }
    }
}
