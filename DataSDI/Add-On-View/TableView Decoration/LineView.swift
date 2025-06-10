//
//  LineView.swift
//  Data SDI
//
//  Created by Bismillah on 04/10/24.
//

import Cocoa

/// Class untuk menggambar garis horizontal pada tampilan yang digunakan sebagai dekorasi.
class LineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let linePath = NSBezierPath()
        linePath.lineWidth = 0.5

        if NSAppearance.currentDrawing().name == .darkAqua {
            NSColor.lightGray.setStroke()
        } else {
            NSColor.darkGray.setStroke()
        }

        linePath.move(to: NSPoint(x: dirtyRect.minX, y: dirtyRect.minY))
        linePath.line(to: NSPoint(x: dirtyRect.maxX, y: dirtyRect.minY))

        linePath.stroke()
    }
}
