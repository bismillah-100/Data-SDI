//
//  CollectionViewItem.swift
//  Administrasi
//
//  Created by Bismillah on 15/11/23.
//

import Cocoa

/// Logika tampilan dalam item `NSCollectionView` yang digunakan di ``DataSDI/TransaksiView/collectionView``.
class CollectionViewItem: NSCollectionViewItem {
    /// Foto untuk merepresentasikan jenis transaksi (Pemasukan, Pengeluaran, dan Lainnya).
    @IBOutlet weak var fotoJenis: NSImageView!
    /// Teks untuk jenis transaksi.
    @IBOutlet weak var mytextField: NSTextField!
    /// Jumlah transaksi.
    @IBOutlet weak var jumlah: NSTextField!
    /// Kategori transaksi.
    @IBOutlet weak var kategori: NSTextField!
    /// Kerperluan transaksi.
    @IBOutlet weak var keperluan: NSTextField!
    /// Tanggal transaksi.
    @IBOutlet weak var tanggal: NSTextField!
    /// Acara transaksi.
    @IBOutlet weak var acara: NSTextField!
    /// Label jumlah di samping kiri jumlah transaksi.
    @IBOutlet weak var jumlahHeading: NSTextField!
    /// Label keperluan.
    @IBOutlet weak var untukHeading: NSTextField!
    /// Label acara.
    @IBOutlet weak var acaraHeading: NSTextField!
    /// Label kategori.
    @IBOutlet weak var kategoriHeading: NSTextField!

    /// Referensi warna latar belakang untuk setiap jenis transaksi.
    private var backgroundColor: NSColor {
        guard let entity = representedObject as? Entity else {
            return .systemBlue
        }

        let red = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        let green = NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
        let orange = NSColor.systemOrange

        func blend(_ color: NSColor) -> NSColor {
            color.blended(withFraction: 0.2, of: .white) ?? .systemBlue
        }

        switch entity.jenisEnum {
        case .pengeluaran:
            return isSelected ? blend(red) : red
        case .pemasukan:
            return isSelected ? blend(green) : green
        // Warna latar belakang untuk Pemasukan
        case .lainnya:
            return isSelected ? blend(orange) : orange
        default:
            return NSColor(red: 0.25, green: 0.76, blue: 0.96, alpha: 1.0)
        }
    }

    private static let pengeluaranImage = NSImage(named: "uangkeluar colored")
    private static let pemasukanImage = NSImage(named: "uangmasuk colored")
    private static let lainnyaImage = NSImage(named: "lainnya colored")

    /// Kumpulan semua `NSTextField` yang menampilkan informasi transaksi.
    var transactionInfo: [NSTextField] {
        [jumlah, kategori,
         keperluan, jumlahHeading,
         untukHeading, jumlahHeading,
         kategoriHeading, acaraHeading, acara]
    }

    /// Warna header jenis transaksi.
    private var textColor: NSColor = .black

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    /// Format tanggal husus item di *NSCollectionView*.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    /// Dijalankan ketika objek telah ditampilkan.
    override var representedObject: Any? {
        didSet {
            guard let entity = representedObject as? Entity else { return }
            configureView(with: entity)
        }
    }

    /// Digunakan untuk mengatur item yang ditampilkan pada data Administrasi tertentu.
    private func configureView(with entity: Entity) {
        acaraHeading.stringValue = "Acara:"
        kategoriHeading.stringValue = "Kategori:"
        untukHeading.stringValue = "Kprluan.:"
        jumlahHeading.stringValue = "Jumlah:"
        mytextField.stringValue = entity.jenisEnum?.title ?? ""
        jumlah.doubleValue = entity.jumlah
        kategori.stringValue = entity.kategori?.value ?? ""
        acara.stringValue = entity.acara?.value ?? ""
        keperluan.stringValue = entity.keperluan?.value ?? ""
        tanggal.stringValue = entity.tanggal.map { Self.dateFormatter.string(from: $0) } ?? ""

        // Tooltip untuk item collectionView
        view.toolTip = "Jenis: \(entity.jenisEnum?.title ?? "")\nJumlah: \(entity.jumlah)\nKategori: \(entity.kategori?.value ?? "")\nAcara: \(entity.acara?.value ?? "")\nKeperluan: \(entity.keperluan?.value ?? "")"
    }

    /// Digunakan untuk mengatur gambar yang sesuai dengan tipe di ``JenisTransaksi``.
    func setImageViewForTransactionType(_ transactionType: JenisTransaksi) {
        switch transactionType {
        case .pengeluaran: fotoJenis?.image = Self.pengeluaranImage
        case .pemasukan: fotoJenis?.image = Self.pemasukanImage
        default: fotoJenis?.image = Self.lainnyaImage
        }
    }

    /// Ketika item dipilih.
    override var isSelected: Bool {
        didSet {
            updateHighlight()
        }
    }

    private var borderColor: NSColor {
        isSelected ? NSColor.systemBlue : NSColor.clear
    }

    private var borderWidth: CGFloat {
        isSelected ? 3.0 : 0
    }

    /// Layer untuk item yang diberi tanda.
    private var leftMarkerLayer: CAShapeLayer?

    /// Membuat warna lebih gelap melalui s.R.G.B.
    /// - Parameters:
    ///   - color: Warna dasar.
    ///   - amount: Jumlah penggelapan dalam `CGFloat`.
    /// - Returns: Warna yang lebih gelap yang dihasilkan.
    func darken(color: NSColor, amount: CGFloat) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        let red = max(c.redComponent - amount, 0)
        let green = max(c.greenComponent - amount, 0)
        let blue = max(c.blueComponent - amount, 0)
        return NSColor(red: red, green: green, blue: blue, alpha: c.alphaComponent)
    }

    /// Pembaruan setelah item diberi tanda/tidak.
    /// - Parameter entity: Data administrasi yang diubah.
    func updateMark(for entity: Entity) {
        if leftMarkerLayer == nil {
            leftMarkerLayer = CAShapeLayer()
            leftMarkerLayer!.frame = CGRect(x: 0, y: 0, width: 5, height: view.bounds.height)
            leftMarkerLayer!.autoresizingMask = [.layerHeightSizable]
            view.layer?.addSublayer(leftMarkerLayer!)
        }

        leftMarkerLayer!.isHidden = !entity.ditandai
        if entity.ditandai {
            leftMarkerLayer!.backgroundColor = darken(color: backgroundColor, amount: 0.3).cgColor
        }
    }

    /// Pembaruan *highlight* pada item yang dipilih.
    private func updateHighlight() {
        let borderColor: NSColor
        let borderWidth: CGFloat

        if isSelected {
            borderColor = NSColor.selectedContentBackgroundColor
            borderWidth = 3.0
        } else {
            borderColor = NSColor.clear
            borderWidth = 0
        }

        view.layer?.backgroundColor = backgroundColor.cgColor
        view.layer?.borderColor = borderColor.cgColor
        view.layer?.borderWidth = borderWidth
    }

    /// Warna `NSTextField` jenis transaksi: ``mytextField``
    /// - Parameter entity: Data administrasi.
    func updateTextColorForEntity(_ entity: Entity) {
        switch JenisTransaksi(rawValue: entity.jenis) {
        case .pengeluaran:
            textColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0) // Warna latar belakang untuk Pengeluaran
        case .pemasukan:
            textColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
        // Warna latar belakang untuk Pemasukan
        case .lainnya:
            textColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
        default:
            textColor = NSColor.black
        }

        mytextField.textColor = textColor
        // warna background
        view.layer?.backgroundColor = backgroundColor.cgColor
    }

    /// Pengaturan ampilan item. Dijalankan ketika XIB baru dimuat.
    private func setupAppearance() {
        view.wantsLayer = true
        view.layer?.borderColor = borderColor.cgColor
        view.layer?.borderWidth = borderWidth
        view.layer?.masksToBounds = true
        view.layer?.cornerRadius = 10.0
    }
}
