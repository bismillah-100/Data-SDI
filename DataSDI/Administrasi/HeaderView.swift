//
//  HeaderView.swift
//  Data SDI
//
//  Created by Bismillah on 23/12/23.
//
import Cocoa

/// Layout section header yang digunakan ``DataSDI/TransaksiView/collectionView``.
class HeaderView: NSView, NSCollectionViewSectionHeaderView {
    /// Teks yang menampilkan kategori transaksi yang sedang dikelompokkan sesuai grup.
    @IBOutlet weak var kategori: NSTextField!
    /// Teks yang menampilkan jumlah total transaksi dalam satu grup.
    @IBOutlet weak var jumlah: NSTextField!

    /// Tombol yang berguna untuk meluaskan semua item grup atau meringkasnya.
    @IBOutlet weak var tmblRingkas: NSButton!

    /// Garis horizontal di atas header.
    @IBOutlet weak var line: NSBox!

    /// Garis horizontal di bawah header ketika header berada di topView.
    var box: NSBox?

    /// Implementasi default dari NSColectionViewSectionHeaderView
    ///
    /// Sudah dimodifikasi di action dan targetnya.
    var sectionCollapseButton: NSButton?

    private lazy var visualEffect: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.wantsLayer = true
        v.blendingMode = .withinWindow
        v.material = .headerView
        v.state = .followsWindowActiveState
        return v
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        sectionCollapseButton = tmblRingkas
        sectionCollapseButton?.isEnabled = true
    }

    /// Menggunakan custom layout attribute untuk menggambar garis di bawah header ketika header berada di topView.
    /// - Parameter layoutAttributes: Attribute yang telah disesuaikan dari ``DataSDI/CustomFlowLayout/layoutAttributesClass``.
    func apply(_ layoutAttributes: NSCollectionViewLayoutAttributes) {
        guard let customAttributes = layoutAttributes as? CustomHeaderLayoutAttributes else { return }
        if customAttributes.shouldShowLine {
            // Tampilkan garis secara konsisten, misalnya hanya sekali.
            if box == nil {
                createLine()
            }
        } else {
            removeLine()
        }
    }

    /// Membuat garis ketika header berada di topView.
    func createLine() {
        if box == nil {
            box = NSBox()
            line.isHidden = true
        }
        guard let box, line.isHidden else { return }
        addSubview(visualEffect, positioned: .below, relativeTo: nil)
        let frame = NSRect(x: bounds.origin.x, y: bounds.origin.y + 1, width: bounds.width, height: bounds.height - 1)
        visualEffect.frame = frame

        // Membuat NSBox sebagai garis horizontal
        let lightMode = NSApp.effectiveAppearance.name == .aqua || NSApp.effectiveAppearance.name == .vibrantLight
        box.boxType = .custom
        box.borderColor = lightMode ? .gridColor : .darkGray
        box.fillColor = .clear
        box.borderWidth = 1
        box.translatesAutoresizingMaskIntoConstraints = false

        // Menambahkan box ke dalam visualEffectView
        addSubview(box)

        // Menambahkan constraint untuk posisi dan ukuran box (garis horizontal)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
            box.bottomAnchor.constraint(equalTo: bottomAnchor), // Mengatur posisi di bawah
            box.heightAnchor.constraint(equalToConstant: 1), // Menentukan ketebalan garis
        ])
        setNeedsDisplay(bounds)
    }

    /// Menghapus garis ketika header sudah tidak berada di topView.
    func removeLine() {
        guard let box else { return }
        box.removeFromSuperview()
        self.box = nil
        line.isHidden = false
        visualEffect.removeFromSuperview()
        setNeedsDisplay(bounds)
    }
}

/// Atribut layout untuk section header ``DataSDI/TransaksiView/collectionView``.
class CustomHeaderLayoutAttributes: NSCollectionViewLayoutAttributes {
    /// Referensi yang menyatakan apakah harus menggambar garis di bawah header.
    ///
    /// True/false di atur di ``DataSDI/CustomFlowLayout/layoutAttributesForSupplementaryView(ofKind:at:)``
    var shouldShowLine: Bool = false

    /// Menyalin semua layout attributes
    /// - Parameter zone: NSZone yang akan digunakan untuk menyalin layout attributes.
    /// - Returns: Mengembalikan nilai Boolean ``CustomHeaderLayoutAttributes/shouldShowLine``
    override func copy(with zone: NSZone? = nil) -> Any {
        guard let copy = super.copy(with: zone) as? CustomHeaderLayoutAttributes else {
            return super.copy(with: zone)
        }
        copy.shouldShowLine = shouldShowLine
        return copy
    }
}
