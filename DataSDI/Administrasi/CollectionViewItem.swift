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
    /// Referensi warna latar belakang untuk setiap jenis transaksi.
    private var backgroundColor: NSColor = .clear
    /// Label jumlah di samping kiri jumlah transaksi.
    @IBOutlet weak var jumlahHeading: NSTextField!
    /// Label keperluan.
    @IBOutlet weak var untukHeading: NSTextField!
    /// Label acara.
    @IBOutlet weak var acaraHeading: NSTextField!
    /// Label kategori.
    @IBOutlet weak var kategoriHeading: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    /// Format tanggal husus item di *NSCollectionView*.
    private lazy var dateFormatter: DateFormatter = {
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
        kategoriHeading.stringValue = "Katgri.:"
        untukHeading.stringValue = "Kperln."
        jumlahHeading.stringValue = "Jumlah:"
        mytextField.stringValue = entity.jenisEnum?.title ?? ""
        jumlah.doubleValue = entity.jumlah
        kategori.stringValue = entity.kategori?.value ?? ""
        acara.stringValue = entity.acara?.value ?? ""
        keperluan.stringValue = entity.keperluan?.value ?? ""
        tanggal.stringValue = entity.tanggal.map { dateFormatter.string(from: $0) } ?? ""
    }

    /// Digunakan untuk mengatur gambar yang sesuai dengan tipe di ``JenisTransaksi``.
    public func setImageViewForTransactionType(_ transactionType: JenisTransaksi) {
        switch transactionType {
        case .pengeluaran:
            if let image = NSImage(named: "uangkeluar colored") {
                fotoJenis?.image = image
            }
        case .pemasukan:
            if let image = NSImage(named: "uangmasuk colored") {
                fotoJenis?.image = image
            }
        default:
            if let image = NSImage(named: "lainnya colored") {
                fotoJenis?.image = image
            }
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

    /// Membuat warna lebih gelap melalu R.G.B.
    /// - Parameters:
    ///   - color: Warna dasar.
    ///   - amount: Jumlah penggelapan dalam `CGFloat`.
    /// - Returns: Warna yang lebih gelap yang dihasilkan.
    func darken(color: NSColor, amount: CGFloat) -> NSColor {
        // Fungsi untuk menggelapkan warna dengan mengurangi komponen RGB
        var red = color.redComponent
        var green = color.greenComponent
        var blue = color.blueComponent

        red = max(red - amount, 0.0) // Pastikan tidak kurang dari 0
        green = max(green - amount, 0.0)
        blue = max(blue - amount, 0.0)

        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// Pembaruan setelah item diberi tanda/tidak.
    /// - Parameter entity: Data administrasi yang diubah.
    func updateMark(for entity: Entity) {
        // Hapus marker layer lama jika ada
        if let leftMarkerLayer {
            leftMarkerLayer.removeFromSuperlayer()
            self.leftMarkerLayer = nil
        }

        // Tambahkan marker hanya jika `entity.ditandai` bernilai true
        guard entity.ditandai else { return }

        // Tentukan warna dasar marker berdasarkan jenis entity
        let baseColor = switch JenisTransaksi(rawValue: entity.jenis) {
        case .pengeluaran:
            NSColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0) // Warna merah terang
        case .pemasukan:
            NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) // Warna hijau terang
        case .lainnya:
            NSColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1.0)
        default:
            NSColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0) // Warna biru terang
        }

        // Gelapkan warna dasar untuk marker
        let markerColor = darken(color: baseColor, amount: 0.3) // Gelapkan sebesar 30%

        // Buat marker layer baru
        let markerLayer = CAShapeLayer()
        markerLayer.backgroundColor = markerColor.cgColor
        markerLayer.frame = CGRect(x: 0, y: 0, width: 5, height: view.bounds.height) // Garis di sisi kiri, lebar 5
        markerLayer.autoresizingMask = [.layerHeightSizable] // Agar tinggi menyesuaikan ukuran view

        // Tambahkan ke view
        view.layer?.addSublayer(markerLayer)

        leftMarkerLayer = markerLayer
    }

    /// Pembaruan *highlight* pada item yang dipilih.
    private func updateHighlight() {
        view.layer?.borderColor = borderColor.cgColor
        view.layer?.borderWidth = borderWidth
    }

    /// Warna `NSTextField` jenis transaksi: ``mytextField``
    /// - Parameter entity: Data administrasi.
    public func updateTextColorForEntity(_ entity: Entity) {
        let textColor: NSColor

        switch JenisTransaksi(rawValue: entity.jenis) {
        case .pengeluaran:
            backgroundColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            textColor = NSColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0) // Warna latar belakang untuk Pengeluaran
        case .pemasukan:
            backgroundColor = NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
            textColor = NSColor(red: 0.09, green: 0.1, blue: 0.04, alpha: 1.0)
        // Warna latar belakang untuk Pemasukan
        case .lainnya:
            textColor = NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
            backgroundColor = NSColor.systemOrange // Warna latar belakang untuk Lainnya
        default:
            backgroundColor = NSColor(red: 0.25, green: 0.76, blue: 0.96, alpha: 1.0)
            textColor = NSColor.black
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            // Tambahkan atribut lain jika diperlukan
        ]

        let attributedString = NSAttributedString(string: entity.jenisEnum?.title ?? "", attributes: attributes)
        mytextField.attributedStringValue = attributedString
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
