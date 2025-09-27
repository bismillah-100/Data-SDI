//
//  PaginatedTable.swift
//  Data SDI
//
//  Created by MacBook on 26/09/25.
//

import Cocoa

/// Subclass kustom dari NSTableView yang menangani paginasi dengan benar saat mencetak
///
/// Kelas ini menimpa perilaku paginasi untuk memastikan baris tabel tidak terpotong
/// ketika dicetak ke beberapa halaman. Secara otomatis menambahkan garis batas pada baris
/// yang terbelah di antara halaman.
///
/// - Penting: Gunakan kelas ini sebagai pengganti NSTableView standar untuk operasi pencetakan
/// - Catatan: Kelas ini memerlukan konfigurasi yang tepat pada gridStyleMask dan intercellSpacing
class PaginatedTable: NSTableView {
    /// Array indeks baris yang membutuhkan garis batas atas karena paginasi
    private var topBorderRows: [Int] = []

    /// Array indeks baris yang membutuhkan garis batas bawah karena paginasi
    private var bottomBorderRows: [Int] = []

    /// Diambil dari sini: http://lists.apple.com/archives/cocoa-dev/2002/Nov/msg01710.html
    /// Memastikan baris dalam tabel tidak terpotong saat mencetak
    ///
    /// Metode ini dipanggil berulang kali selama proses paginasi untuk menentukan titik pemisah halaman yang optimal.
    /// Metode ini memastikan baris tidak pernah terpotong di antara halaman.
    ///
    /// - Parameter:
    ///   - newBottom: Pointer ke posisi bawah baru untuk halaman saat ini
    ///   - oldTop: Posisi atas halaman saat ini
    ///   - oldBottom: Posisi bawah halaman saat ini
    ///   - bottomLimit: Posisi bawah maksimum yang diizinkan
    override func adjustPageHeightNew(
        _ newBottom: UnsafeMutablePointer<CGFloat>,
        top _: CGFloat,
        bottom oldBottom: CGFloat,
        limit _: CGFloat
    ) {
        // Metode ini dipanggil berulang kali untuk setiap pemisah halaman.
        // Reset array di awal pekerjaan cetak
        // untuk menghindari garis batas yang salah pada cetakan berikutnya.
        if topBorderRows.isEmpty, bottomBorderRows.isEmpty {
            topBorderRows = []
            bottomBorderRows = []
        }

        let cutoffRow = row(at: NSPoint(x: 0, y: oldBottom))
        var rowBounds: NSRect

        newBottom.pointee = oldBottom
        if cutoffRow != -1 {
            rowBounds = rect(ofRow: cutoffRow)
            if oldBottom < NSMaxY(rowBounds) {
                newBottom.pointee = NSMinY(rowBounds)

                let previousRow = cutoffRow - 1

                // Mark which rows need which border, ignore ones we've already seen, and adjust ones that need different borders
                if topBorderRows.last != cutoffRow {
                    if bottomBorderRows.last == cutoffRow {
                        topBorderRows.removeLast()
                        bottomBorderRows.removeLast()
                    }

                    topBorderRows.append(cutoffRow)
                    bottomBorderRows.append(previousRow)
                }
            }
        }
    }

    /// Menggambar baris tabel dengan tambahan garis batas paginasi
    ///
    /// Metode ini menggambar baris tabel standar dan menambahkan garis batas kustom untuk baris
    /// yang terbelah di antara batas halaman.
    ///
    /// - Parameter:
    ///   - rowIndex: Indeks baris yang akan digambar
    ///   - clipRect: Area kliping untuk operasi gambar saat ini
    override func drawRow(_ rowIndex: Int, clipRect: NSRect) {
        super.drawRow(rowIndex, clipRect: clipRect)

        if topBorderRows.isEmpty {
            return
        }

        let rowRect = rect(ofRow: rowIndex)
        let gridPath = NSBezierPath()
        let color = NSColor.gridColor

        for i in 0 ..< topBorderRows.count {
            let rowNeedingTopBorder = topBorderRows[i]
            if rowNeedingTopBorder == rowIndex {
                gridPath.move(to: rowRect.origin)
                gridPath.line(to: NSPoint(x: rowRect.origin.x + rowRect.size.width, y: rowRect.origin.y))

                color.setStroke()
                gridPath.stroke()
            }

            let rowNeedingBottomBorder = bottomBorderRows[i]
            if rowNeedingBottomBorder == rowIndex {
                gridPath.move(to: NSPoint(x: rowRect.origin.x, y: rowRect.origin.y + rowRect.size.height))
                gridPath.line(to: NSPoint(x: rowRect.origin.x + rowRect.size.width, y: rowRect.origin.y + rowRect.size.height))

                color.setStroke()
                gridPath.stroke()
            }
        }
    }
}
