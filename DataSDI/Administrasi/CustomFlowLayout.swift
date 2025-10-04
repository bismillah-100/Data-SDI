//
//  CustomFlowLayout.swift
//  Data SDI
//
//  Created by Bismillah on 13/11/24.
//

import Cocoa

/// Layout flowLayout untuk ``DataSDI/TransaksiView/collectionView``.
///
/// Mengatur tata letak:
/// - Jarak antara item.
/// - Tampilan section header.
/// - Atribut layout section header.
class CustomFlowLayout: NSCollectionViewFlowLayout {
    /// Item dan spacing yang digunakan dalam perhitungan.
    private var itemWidth: CGFloat = 214.0
    /// Jarak antar item dalam mode group.
    private let interitemSpacing: CGFloat = 20.0
    /// Jarak samping kanan dan kiri dalam mode group.
    private let sideInset: CGFloat = 20.0

    /// Inset top untuk section.
    var topInset: CGFloat = 20

    /// Referensi yang menyimpan section yang sedang berada di topView dan dipin di atas.
    ///
    /// Digunakan untuk menambahkan line di bawah section.
    var currentPinnedSection: Int = -1
    /// Digunakan untuk mendapatkan nilai false/true apakah *NSCollectionView* sedang dimuat ulang.
    ///
    /// Diperlukan ketika *NSCollectionView* hanya memuat ulang tampilan seperti, sortir data dan memuat ulang seluruh tampilan.
    var refreshing: Bool = false

    /// Tinggi item *NSCollectionViewItem*
    private let itemHeight: CGFloat = 187.0

    /// Nilai paling atas di clipView.
    ///
    /// Sebelumnya digunakan ketika tab bar ditampilkan. Deprecated.
    var clipViewTop: CGFloat = 0

    var isGrouped: Bool = false

    private var cachedTopSection: Int?
    private var cachedBoundsOrigin: CGPoint = .zero
    private let cacheThresholdY: CGFloat = 1 // Toleransi perubahan scroll

    override func prepare() {
        super.prepare()
        itemSize = NSSize(width: itemWidth, height: itemHeight)
        guard let collectionView else { return }
        insetForExpandedSection(collectionView)
        if isGrouped {
            cachedTopSection = nil
            currentPinnedSection = -1
        }
    }

    // MARK: - Invalidation

    override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)

        guard isGrouped else {
            return context
        }

        // Gunakan cached value (sudah dihitung di shouldInvalidateLayout)
        let currentPinned = getCachedTopSection(for: newBounds)

        if currentPinned != currentPinnedSection {
            var indexPaths: [IndexPath] = []

            // Invalidate header section lama
            if currentPinnedSection >= 0 {
                indexPaths.append(IndexPath(item: 0, section: currentPinnedSection))
            }

            // Invalidate header section baru
            if currentPinned >= 0 {
                indexPaths.append(IndexPath(item: 0, section: currentPinned))
            }

            context.invalidateSupplementaryElements(
                ofKind: NSCollectionView.elementKindSectionHeader,
                at: Set(indexPaths)
            )

            currentPinnedSection = currentPinned
        }

        return context
    }

    /// Membuat custom layout attributes yang disediakan oleh AppKit untuk mendesain tampilan header.
    override class var layoutAttributesClass: AnyClass {
        CustomHeaderLayoutAttributes.self
    }

    /// Lihat: ``CustomFlowLayout/layoutAttributesClass``.
    /// Menambahkan garis di bawah header ketika header berada di topView seperti di Aplikasi Finder.
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath) as? CustomHeaderLayoutAttributes else { return nil }
        guard isGrouped, currentPinnedSection != -1 else { return super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath) }
        // Misal: hanya header pada section top (misalnya currentPinnedSection) yang menampilkan garis.
        attributes.shouldShowLine = (indexPath.section == currentPinnedSection && currentPinnedSection != -1)
        return attributes
    }

    /// Mendapatkan lokasi element CollectionView di layar.
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        var attributesArray = super.layoutAttributesForElements(in: rect)
        // Filter hanya elemen yang benar-benar berada dalam visibleRect
        attributesArray = attributesArray.filter { rect.intersects($0.frame) }

        return attributesArray
    }

    /// Mendapatkan top section dengan caching untuk menghindari perhitungan berulang
    private func getCachedTopSection(for bounds: NSRect) -> Int {
        let boundsOrigin = bounds.origin

        // Cek apakah cache masih valid (bounds tidak berubah signifikan)
        let deltaY = abs(boundsOrigin.y - cachedBoundsOrigin.y)

        if let cached = cachedTopSection,
           deltaY < cacheThresholdY
        {
            // Cache masih valid, gunakan nilai cache
            return cached
        }

        // Cache tidak valid, hitung ulang
        let topSection = findTopSection() ?? -1

        // Simpan ke cache
        cachedTopSection = topSection
        cachedBoundsOrigin = boundsOrigin

        return topSection
    }

    // MARK: - Find Top Section (Hanya dipanggil saat cache invalid)

    /// Ini merupakan logika yang kompleks untuk menentukan frame section header yang berada di topView saat scrolling dan juga saat collectionview baru ditampilkan.
    ///
    /// - Menghitung tinggi dan topView di clipView.
    /// - Mendapatkan index section yang berada di topView.
    /// - Menambahkan tinggi jendela toolbar.
    func findTopSection() -> Int? {
        guard let collectionView else { return nil }
        // Mengakses clipView dari scrollView
        guard let scrollView = collectionView.enclosingScrollView else { return nil }
        let clipView = scrollView.contentView
        // Mendapatkan posisi Y dari clipView
        var currentY = clipView.bounds.origin.y
        currentY += clipViewTop

        if currentY == -38.0 /* tinggi frame toolbar */, currentPinnedSection != 0 {
            if let oldHeaderView = collectionView.supplementaryView(
                forElementKind: NSCollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: 0)
            ) as? HeaderView {
                oldHeaderView.createLine()
                return 0
            }
        }
        // Cek apakah sedang bounce
        if currentY < -38.0 /* tinggi frame toolbar */, currentY != 38.0 {
            guard currentY != 38.0, !refreshing else {
                return -1
            }

            // Jika posisi lebih kecil dari 0, berarti masih dalam bouncing
            let visibleVisual: Set = [0, currentPinnedSection]

            for i in visibleVisual {
                if let oldHeaderView = collectionView.supplementaryView(
                    forElementKind: NSCollectionView.elementKindSectionHeader,
                    at: IndexPath(item: 0, section: i)
                ) as? HeaderView {
                    oldHeaderView.removeLine()
                }
            }

            return -1
        } else if currentY != 38.0 {
            guard !refreshing else {
                return -1
            }

            // Dapatkan visible rect
            var visibleRect = collectionView.visibleRect
            visibleRect.origin.y += clipViewTop

            // Jika sedang bounce, langsung return section 0
            if collectionView.visibleRect.origin.y <= 0 {
                return 0
            } else {
                visibleRect.origin.y += 38 // Toolbar offset
            }
            // Jika tidak bounce, lakukan perhitungan normal
            let headers = layoutAttributesForElements(in: visibleRect)
                .filter { $0.representedElementKind == NSCollectionView.elementKindSectionHeader }
            let topHeader = headers.min { $0.frame.origin.y + clipViewTop < $1.frame.origin.y + clipViewTop }

            return topHeader?.indexPath?.section
        } else {
            return 0
        }
    }

    /// Menghitung jarak antar item di collectionView.
    /// - Parameter section: Index section
    /// - Returns: Nilai jarak yang dihitung.
    func insetForSection(at section: Int) -> NSEdgeInsets {
        if self.section(atIndexIsCollapsed: section) {
            let numberOfItems = CGFloat(collectionView?.numberOfItems(inSection: section) ?? 0)
            let totalItemsWidth = (itemWidth + sideInset) * numberOfItems
            let collectionViewWidth = collectionView?.bounds.width ?? 0
            // Hitung total width yang dibutuhkan
            let requiredRightInset = max(
                -(totalItemsWidth - collectionViewWidth),
                -(totalItemsWidth - collectionViewWidth)
            )

            // Cek apakah total lebar melebihi lebar collectionView
            return NSEdgeInsets(
                top: topInset,
                left: sideInset,
                bottom: 30.0,
                right: requiredRightInset
            )
        } else {
            // Default inset untuk section yang tidak collapse
            return sectionInset
        }
    }

    /// Jarak antar item ketika section diluaskan dalam mode group.
    /// - Parameter collectionView: CollectionView yang menampilkan item.
    func insetForExpandedSection(_ collectionView: NSCollectionView) {
        // Set minimal line spacing
        minimumLineSpacing = interitemSpacing
        minimumInteritemSpacing = interitemSpacing

        // Hitung jumlah item yang bisa ditampilkan
        let availableWidth = collectionView.bounds.width - sideInset
        let itemWithSpacing = itemWidth + interitemSpacing
        let numberOfItemsPossible = floor(availableWidth / itemWithSpacing)

        // Hitung total width yang dibutuhkan
        let totalWidth = (numberOfItemsPossible * itemWidth) + ((numberOfItemsPossible - 1) * interitemSpacing)

        // Hitung right inset
        let rightInset = collectionView.bounds.width - totalWidth - sideInset

        sectionInset = NSEdgeInsets(
            top: topInset,
            left: sideInset,
            bottom: 30,
            right: max(0, rightInset)
        )
        itemSize = NSSize(width: itemWidth, height: itemHeight) // sesuaikan height dengan kebutuhan
    }

    /// Memperbarui lebar item ketika diperbesar dan diperkecil.
    /// - Parameter scaleFactor: Nilai pelebaran yang diinginkan.
    func updateSize(scaleFactor: CGFloat) {
        // Mengubah lebar dan tinggi layout flow
        let currentWidth = itemWidth
        let newWidth = currentWidth * scaleFactor
        let minItemWidth: CGFloat = 214.0
        itemWidth = max(newWidth, minItemWidth)
        // Mengatur itemSize baru untuk layout flow
        itemSize = NSSize(width: max(newWidth, minItemWidth), height: itemHeight)
        invalidateLayout()
    }
}
