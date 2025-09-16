//
//  NamaSiswaCell.swift
//  Data SDI
//
//  Created by MacBook on 14/09/25.
//

import Cocoa

/// Subkelas `NSTableCellView` untuk menampilkan informasi siswa.
///
/// Kelas ini menggabungkan field teks untuk nama siswa dan lingkaran
/// yang diberi kode warna untuk merepresentasikan tingkat kelas aktif mereka.
/// Atau imageView untuk representasi siswa lulus/tanpa kelas.
///
/// - Penting: `NSTableCellView` harus dikonfigurasi dengan benar di Interface Builder
///              untuk menggunakan kelas kustom ini.
class NamaSiswaCellView: NSTableCellView {
    /// Cache path lingkaran berdasarkan kombinasi key unik.
    private static var pathCache: [String: NSBezierPath] = [:]

    /// Objek model siswa yang akan ditampilkan di dalam sel.
    private var siswa: ModelSiswa?

    /// Warna lingkaran yang digambar untuk merepresentasikan kelas siswa.
    /// Properti ini diperbarui oleh metode `configure(with:)`.
    private var circleColor: NSColor = .gray

    func configure(with siswa: ModelSiswa) {
        self.siswa = siswa
        textField?.stringValue = siswa.nama
        circleColor = colorForKelas(siswa.tingkatKelasAktif)
        needsDisplay = true
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { needsDisplay = true }
    }

    fileprivate func setImageView(_ image: NSImage) {
        imageView?.image = image
        imageView?.isHidden = false
    }

    /// Menggambar `NSBezierPath` untuk tingkat kelas dan atau `NSImageView`
    /// jika siswa lulus/tanpa kelas.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let siswa else { return }
        let isSelected = (backgroundStyle == .emphasized)

        if siswa.status == .lulus {
            let img = isSelected
                ? NSImage(named: "lulus Bordered")!
                : NSImage(named: "lulus")!
            setImageView(img)
            return
        }

        if circleColor == .clear {
            let img = isSelected
                ? NSImage(named: "No Data Bordered")!
                : NSImage(named: "No Data")!
            setImageView(img)
            return
        }

        imageView?.isHidden = true

        let circleDiameter: CGFloat = 10
        let margin: CGFloat = 6
        let circleSize = NSSize(width: circleDiameter, height: circleDiameter)
        let circleX = dirtyRect.maxX - circleDiameter - margin
        let circleY = dirtyRect.midY - circleDiameter / 2
        let iconRect = NSRect(origin: NSPoint(x: circleX, y: circleY), size: circleSize)

        // Gambar lingkaran + border seperti biasa
        circleColor.setFill()
        getCachedPath(for: iconRect, borderWidth: 0, selected: false).fill()

        if isSelected {
            let borderWidth: CGFloat = 1.0
            let path = getCachedPath(for: iconRect, borderWidth: borderWidth, selected: true)
            NSColor.white.setStroke()
            path.lineWidth = borderWidth
            path.stroke()
        } else {
            let borderWidth: CGFloat = 0.4
            let innerStrokeColor = circleColor.shadow(withLevel: 0.5) ?? NSColor(white: 0.3, alpha: 1.0)
            innerStrokeColor.setStroke()
            let path = getCachedPath(for: iconRect, borderWidth: borderWidth, selected: false)
            path.lineWidth = borderWidth
            path.stroke()
        }
    }

    /// Ambil path dari cache atau buat baru jika belum ada.
    fileprivate func getCachedPath(for rect: NSRect, borderWidth: CGFloat, selected: Bool) -> NSBezierPath {
        // Key unik: ukuran + borderWidth + state
        let key = "\(rect.origin.x),\(rect.origin.y),\(rect.size.width),\(rect.size.height)-\(borderWidth)-\(selected)"

        if let cached = Self.pathCache[key] {
            return cached
        }

        let insetRect = rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = NSBezierPath(ovalIn: insetRect)
        Self.pathCache[key] = path
        return path
    }

    /// Menentukan warna untuk tingkat kelas tertentu.
    /// - Parameter tingkatKelas: Tingkat kelas ("1", "2" dst.).
    /// - Returns: Sebuah `NSColor` yang terkait dengan tingkat kelas.
    fileprivate func colorForKelas(_ kelas: KelasAktif) -> NSColor {
        switch kelas {
        case .kelas1: NSColor(named: "kelas1")!
        case .kelas2: NSColor(named: "kelas2")!
        case .kelas3: NSColor(named: "kelas3")!
        case .kelas4: NSColor(named: "kelas4")!
        case .kelas5: NSColor(named: "kelas5")!
        case .kelas6: NSColor(named: "kelas6")!
        default: .clear
        }
    }
}
