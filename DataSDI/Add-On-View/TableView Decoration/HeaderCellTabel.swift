//
//  HeaderCellTabel.swift
//  Data SDI
//
//  Created by Bismillah on 22/12/23.
//

import Cocoa

/// Class untuk konfigurasi layout dan tampilan teks dan indikator pengurutan di header tabel
/// yang disesuaikan dengan efek visual dan status pengurutan.
class MyHeaderCell: NSTableHeaderCell {
    /// Inisialisasi dengan teks dan atribut yang sesuai.
    var customTitle: String = ""
    /// Properti untuk menentukan apakah header sedang dalam keadaan terurut.
    var isSorted: Bool = false {
        didSet {
            if let view = controlView {
                view.setNeedsDisplay(view.bounds)
            }
        }
    }

    // Customize text style/positioning for header cell
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var adjustedFrame = NSRect()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingMiddle // Atur line break mode sesuai kebutuhan
        if isSorted {
            attributedStringValue = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11.0, weight: .semibold),
                    NSAttributedString.Key.foregroundColor: NSColor.headerTextColor,
                    NSAttributedString.Key.paragraphStyle: paragraphStyle, // Tambahkan paragraph style
                ]
            )
            adjustedFrame = NSRect(x: cellFrame.origin.x + 1, y: cellFrame.origin.y, width: cellFrame.size.width - 4.9, height: cellFrame.size.height)
        } else {
            attributedStringValue = NSAttributedString(
                string: title,
                attributes: [
                    NSAttributedString.Key.foregroundColor: NSColor.headerTextColor,
                    NSAttributedString.Key.paragraphStyle: paragraphStyle, // Tambahkan paragraph style
                ]
            )
            adjustedFrame = NSRect(x: cellFrame.origin.x + 1, y: cellFrame.origin.y + 1, width: cellFrame.size.width - 4.9, height: cellFrame.size.height)
        }

        super.drawInterior(withFrame: adjustedFrame, in: controlView)
    }

    override func drawSortIndicator(withFrame cellFrame: NSRect, in _: NSView, ascending: Bool, priority _: Int) {
        let indicator = sortIndicatorRect(forBounds: cellFrame)

        // Pilih karakter panah sesuai dengan arah pengurutan
        let arrowCharacter = ascending ? "↑" : "↓"

        // Hitung posisi untuk menempatkan karakter panah di tengah indikator
        let textAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11.0, weight: NSFont.Weight.light), // Ganti dengan ukuran yang diinginkan
            NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Ganti dengan warna yang diinginkan
        ]

        let textSize = arrowCharacter.size(withAttributes: textAttributes)
        var textRect = CGRect(x: indicator.midX - textSize.width / 2,
                              y: indicator.minY - textSize.height,
                              width: textSize.width,
                              height: textSize.height)

        let y: CGFloat = 11.0 // Sesuaikan dengan nilai yang diinginkan
        textRect.origin.y += y
        // Gambar karakter panah ke dalam cellFrame
        arrowCharacter.draw(in: textRect, withAttributes: textAttributes)
    }
}

/// Class ini digunakan untuk headerCell di ``SiswaViewController`` karena
/// penggunaan `NSTableHeaderView` custom yang dapat menghilangkan kemampuan
/// `NSVisualEffect`. class ini dibuat untuk membuat `NSTableHeaderCell` transparan.
final class GroupHeaderCell: MyHeaderCell {
    /// Override metode draw yang spesifik untuk membuat warna `cell` transparan
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        NSColor.clear.setFill()
        __NSRectFill(cellFrame)
        super.draw(withFrame: cellFrame, in: controlView)
    }
}

/// Subclass `NSTableHeaderView` dengan `NSVisualEffect`.
class BlurBgHeaderView: NSTableHeaderView {
    private var visualEffectView: NSVisualEffectView?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    /// Memperbarui frame `y`.
    /// - Parameter y: Nilai yang akan digunakan untuk `frame.origin.y`.
    func setOriginY(_ y: CGFloat) {
        frame.origin.y = y
        visualEffectView?.frame.origin.y = y
    }

    override func layout() {
        super.layout()
        if visualEffectView != nil {
            visualEffectView?.frame = bounds
        } else {
            guard visualEffectView == nil else {return}
            guard let superView = superview as? NSClipView else {
                return
            }
            let effectView = NSVisualEffectView(frame: bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.blendingMode = .withinWindow
            effectView.state = .followsWindowActiveState
            effectView.material = .headerView // Ubah sesuai kebutuhan
            superView.addSubview(effectView, positioned: .below, relativeTo: nil)
            visualEffectView = effectView
        }
    }
}
