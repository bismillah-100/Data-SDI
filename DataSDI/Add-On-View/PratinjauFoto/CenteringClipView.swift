//
//  CenteringClipView.swift
//  Data SDI
//
//  Created by MacBook on 20/06/25.
//

import Cocoa

/// Sebuah subclass dari `NSClipView` yang secara otomatis memusatkan tampilan dokumen jika ukuran dokumen lebih kecil dari area tampilan.
///
/// - Properti:
///   - isDragging: Menandakan apakah sedang dalam mode dragging. Jika `true`, centering tidak dilakukan.
///
/// - Fungsi:
///   - constrainBoundsRect(_:) : Menyesuaikan posisi bounds agar dokumen tetap terpusat secara horizontal dan/atau vertikal ketika ukuran dokumen lebih kecil dari area tampilan. Jika sedang dragging, bounds tidak diubah.
///
class CenteringClipView: NSClipView {
    /// Menandakan apakah sedang dalam mode dragging. Jika `true`, centering tidak dilakukan.
    var isDragging = false

    /// Menyesuaikan posisi bounds dari clip view agar tetap terpusat ketika ukuran dokumen lebih kecil dari area tampilan.
    /// Jika sedang dalam mode dragging (`isDragging`), fungsi akan mengembalikan bounds yang diusulkan tanpa perubahan.
    /// Jika tidak, fungsi akan memusatkan dokumen secara horizontal dan/atau vertikal jika ukuran dokumen lebih kecil dari bounds yang diusulkan.
    /// - Parameter proposedBounds: Bounds yang diusulkan untuk clip view.
    /// - Returns: Bounds yang telah disesuaikan agar dokumen tetap terpusat jika diperlukan.
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        // Jika dalam mode dragging, jangan lakukan centering (gunakan nilai yang diusulkan)
        if isDragging {
            return proposedBounds
        }

        var newBounds = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return newBounds }
        let documentFrame = documentView.frame

        if documentFrame.width < proposedBounds.width {
            newBounds.origin.x = (documentFrame.width - proposedBounds.width) / 2.0
        }
        if documentFrame.height < proposedBounds.height {
            newBounds.origin.y = (documentFrame.height - proposedBounds.height) / 2.0
        }
        return newBounds
    }
}
