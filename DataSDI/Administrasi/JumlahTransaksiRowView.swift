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
    var isMarked: Bool = false

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
            super.drawBackground(in: dirtyRect)

            let desiredHeight: CGFloat = dirtyRect.height - 4 // Your intended height reduction
            let desiredWidth: CGFloat = 5

            // 1. Calculate the vertical offset (y-origin)
            // This is (Full Height - Desired Height) / 2
            let yOffset = (dirtyRect.height - desiredHeight) / 2

            // 2. Define the new centered rect
            let rectKiri = NSRect(
                x: dirtyRect.origin.x, // Stays on the far left (based on your original intent)
                y: dirtyRect.origin.y + yOffset, // Moves down by the calculated offset
                width: desiredWidth, // Stays at the desired width (5)
                height: desiredHeight // Stays at the desired height
            )

            // 1. Create a Bezier Path for the rounded rectangle
            let cornerRadius: CGFloat = 3.0 // Adjust this value for desired roundness
            let roundedPath = NSBezierPath(roundedRect: rectKiri, xRadius: cornerRadius, yRadius: cornerRadius)

            // 2. Set the fill color
            customTextColor.setFill()

            // 3. Fill the rounded path
            roundedPath.fill()
        } else {
            super.drawBackground(in: dirtyRect)
        }
        resetJumlah(with: customTextColor)
    }

    /// Menangani penggambaran latar seleksi baris.
    /// - Parameter dirtyRect: Frame baris.
    override func drawSelection(in dirtyRect: NSRect) {
        guard let tableView = superview as? NSTableView else {
            super.drawSelection(in: dirtyRect)
            return
        }

        let myRow = tableView.row(for: self)
        if myRow == -1 {
            super.drawSelection(in: dirtyRect)
            return
        }

        // CHANGED: The variable's type is now our custom RectCorner
        var corners: RectCorner = []

        if !isPreviousRowSelected {
            corners.insert(.bottomLeft)
            corners.insert(.bottomRight)
        }
        // Round bottom corners if no selected row below (e.g., end of a block)
        if !isNextRowSelected {
            corners.insert(.topLeft)
            corners.insert(.topRight)
        }

        let adjustedRect = NSRect(
            x: dirtyRect.origin.x + 10,
            y: dirtyRect.origin.y,
            width: dirtyRect.width - 20,
            height: dirtyRect.height - 0.2
        )

        let selectionColor = isEmphasized
            ? customTextColor.blended(withFraction: 0.5, of: .black)
            : customTextColor.blended(withFraction: 0.4, of: .white)

        let cornerRadius: CGFloat = 6.0

        // This call now works correctly with our custom RectCorner type
        let path = NSBezierPath(roundedRect: adjustedRect, byRoundingCorners: corners, cornerRadius: cornerRadius)

        selectionColor?.setFill()
        path.fill()
        resetJumlah(with: .controlTextColor)
    }

    private func resetJumlah(with color: NSColor) {
        if let tableView = superview as? NSTableView {
            let indexJumlahColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "jumlah"))
            if let c = view(atColumn: indexJumlahColumn) as? NSTableCellView {
                c.textField?.textColor = color
            }
        }
    }
}

extension NSBezierPath {
    /// Inisialisasi Bezier Path dengan persegi panjang yang memiliki sudut membulat pada sudut-sudut tertentu.
    /// - Parameters:
    ///   - rect: Persegi panjang yang akan digambar.
    ///   - corners: Sudut-sudut yang akan dibulatkan.
    ///   - cornerRadius: Radius pembulatan sudut.
    convenience init(roundedRect rect: NSRect, byRoundingCorners corners: RectCorner, cornerRadius: CGFloat) {
        self.init()

        let topLeft = NSPoint(x: rect.minX, y: rect.maxY)
        let topRight = NSPoint(x: rect.maxX, y: rect.maxY)
        let bottomRight = NSPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = NSPoint(x: rect.minX, y: rect.minY)

        move(to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        if corners.contains(.topRight) {
            line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            appendArc(from: topRight, to: NSPoint(x: rect.maxX, y: rect.maxY - cornerRadius), radius: cornerRadius)
        } else {
            line(to: topRight)
        }

        if corners.contains(.bottomRight) {
            line(to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            appendArc(from: bottomRight, to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY), radius: cornerRadius)
        } else {
            line(to: bottomRight)
        }

        if corners.contains(.bottomLeft) {
            line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            appendArc(from: bottomLeft, to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius), radius: cornerRadius)
        } else {
            line(to: bottomLeft)
        }

        if corners.contains(.topLeft) {
            line(to: NSPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            appendArc(from: topLeft, to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY), radius: cornerRadius)
        } else {
            line(to: topLeft)
        }

        close()
    }
}

/// Struct untuk menentukan sudut mana yang akan dibulatkan pada sebuah persegi panjang.
struct RectCorner: OptionSet {
    /// Nilai mentah yang mewakili sudut-sudut yang dipilih.
    let rawValue: Int

    // Sudut-sudut yang dapat dipilih.
    /// Sudut kiri-bawah.
    static let bottomLeft: RectCorner = .init(rawValue: 1 << 0)
    /// Sudut kanan-bawah.
    static let bottomRight: RectCorner = .init(rawValue: 1 << 1)
    /// Sudut kiri-atas.
    static let topLeft: RectCorner = .init(rawValue: 1 << 2)
    /// Sudut kanan-atas.
    static let topRight: RectCorner = .init(rawValue: 1 << 3)

    /// Semua sudut yang dapat dikonfigurasi.
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
