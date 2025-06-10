//
//  JumlahTransaksiRowView.swift
//  Data SDI
//
//  Created by Bismillah on 04/01/25.
//

import Cocoa

/// RowView Kustom untuk NSTableView yang digunakan di ``DataSDI/JumlahTransaksi/tableView(_:rowViewForRow:)``
///
/// Class ini digunakan untuk menggambar row yang sedang dipilih.
/// Jika item yang dipilih adalah item yang ditandai maka row tersebut akan menggunakan warna kustom sesuai jenis transaksi.
/// Jika item yang dipilih adalah item yang tidak ditandai, maka row tersebut akan menggambar line di tepi kiri dengan warna yang sesuai jenis transaksi.
class JumlahTransaksiRowView: NSTableRowView {
    /// Referensi yang menunjukkan jika item di suatu baris ditandai atau tidak.
    var isMarked: Bool = false {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    /// Penentuan warna row.
    ///
    /// Warna ini ditentukan dari ``DataSDI/JumlahTransaksi/tableView(_:viewFor:row:)``
    var markerColor: NSColor = .clear {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    /// Warna teks di suatu row ketika row dipilih.
    ///
    /// Warna ini digunakan di kolom jumlah ketika row tidak sedang dipilih.
    var customTextColor: NSColor = .white

    /// Tentukan radius sudut yang membulat
    let cornerRadius: CGFloat = 5

    /// Menangani penggambaran latar belakang baris.
    /// - Parameter dirtyRect: Frame baris.
    override func drawBackground(in dirtyRect: NSRect) {
        if isMarked {
            // Area utama tanpa 1 px di bawah
            let mainRect = NSRect(
                x: dirtyRect.origin.x + 10,
                y: dirtyRect.origin.y,
                width: dirtyRect.width - 20,
                height: dirtyRect.height - 1 // Kurangi 1 px dari bawah
            )

            let path = NSBezierPath(roundedRect: mainRect, xRadius: cornerRadius, yRadius: cornerRadius)

            markerColor.setFill()
            path.fill()

            for i in 0 ..< numberOfColumns {
                if let c = view(atColumn: i) as? NSTableCellView {
                    c.textField?.textColor = customTextColor
                }
            }
        } else {
            super.drawBackground(in: dirtyRect)
            if let tableView = superview as? NSTableView {
                let indexJumlahColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "jumlah"))
                if let c = view(atColumn: indexJumlahColumn) as? NSTableCellView {
                    c.textField?.textColor = customTextColor
                }
            }
        }
    }

    /// Menangani penggambaran latar seleksi baris.
    /// - Parameter dirtyRect: Frame baris.
    override func drawSelection(in dirtyRect: NSRect) {
        if isMarked, isSelected {
            // Kurangi 1 px pada tinggi rect untuk memberikan jarak intercell
            let adjustedRect = NSRect(
                x: dirtyRect.origin.x + 10,
                y: dirtyRect.origin.y,
                width: dirtyRect.width - 20,
                height: dirtyRect.height - 1 // Kurangi 1 px dari bawah
            )
            let brighterColor = markerColor.blended(withFraction: 0.5, of: .black) ?? markerColor
            let path = NSBezierPath(roundedRect: adjustedRect, xRadius: cornerRadius, yRadius: cornerRadius)

            brighterColor.setFill()
            path.fill()
            for i in 0 ..< numberOfColumns {
                if let c = view(atColumn: i) as? NSTableCellView {
                    c.textField?.textColor = .white
                }
            }
        } else if isSelected {
            // Gunakan warna seleksi default
            super.drawSelection(in: dirtyRect)
            let rectKiri = NSRect(x: dirtyRect.origin.x, y: dirtyRect.origin.y, width: 5, height: dirtyRect.height - 1)
            customTextColor.setFill()
            rectKiri.fill()
            if let tableView = superview as? NSTableView {
                let indexJumlahColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "jumlah"))
                if let c = view(atColumn: indexJumlahColumn) as? NSTableCellView {
                    c.textField?.textColor = .white
                }
            }
        } else {
            super.drawSelection(in: dirtyRect)
        }
    }
}
