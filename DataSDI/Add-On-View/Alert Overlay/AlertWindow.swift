//
//  AlertWindow.swift
//  Data SDI
//
//  Created by Bismillah on 05/10/24.
//

import Cocoa

/// `AlertWindow` adalah `NSViewController` yang dirancang untuk menampilkan jendela overlay notifikasi kustom.
/// menyediakan tampilan visual yang menarik dengan efek blur latar belakang dan memungkinkan
/// penyesuaian pesan teks serta gambar.
class AlertWindow: NSViewController {
    /// Outlet untuk `NSImageView` yang menampilkan ikon atau gambar di atas teksfield.
    @IBOutlet weak var imageView: NSImageView!

    /// Outlet untuk `NSTextField` yang menampilkan pesan teks pesan.
    @IBOutlet weak var pesan: NSTextField!

    /// Outlet untuk `NSVisualEffectView` yang memberikan efek blur latar belakang,
    @IBOutlet weak var visualEffect: NSVisualEffectView!

    /// Dipanggil setelah view controller memuat view hierarkinya ke dalam memori.
    /// Metode ini memastikan layout awal view diatur, latar belakang view diatur ke transparan,
    /// dan mengonfigurasi tampilan dengan pesan dan gambar awal yang ada di outlet.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.needsLayout = true
        view.needsUpdateConstraints = true
        view.layoutSubtreeIfNeeded()
        view.layer?.backgroundColor = .clear // Mengatur latar belakang view menjadi transparan
        // Mengonfigurasi tampilan dengan nilai string awal dari 'pesan' dan gambar awal dari 'imageView'.
        // Catatan: Pastikan 'imageView.image!' tidak nil saat ini.
        configure(with: pesan.stringValue, image: imageView.image!)
    }

    /// Dipanggil setelah view controller dan view-nya telah sepenuhnya diinisialisasi dari file NIB/Storyboard.
    /// Metode ini melakukan konfigurasi visual awal untuk `visualEffect` view.
    override func awakeFromNib() {
        super.awakeFromNib()
        // Mengaktifkan layer untuk visualEffect untuk memungkinkan kustomisasi seperti cornerRadius.
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16.0 // Memberikan sudut membulat pada efek visual.
        visualEffect.blendingMode = .behindWindow // Mengatur mode blending untuk interaksi dengan jendela di belakangnya.

        // Menyesuaikan material efek visual berdasarkan tema tampilan sistem (Aqua untuk Light Mode, lainnya untuk Dark Mode).
        if NSAppearance.currentDrawing().name == .aqua {
            visualEffect.material = .popover // Material untuk Light Mode
        } else {
            visualEffect.material = .hudWindow // Material untuk Dark Mode
        }
    }

    /// Dipanggil tepat sebelum sistem me-layout subview dari view controller.
    /// Metode ini bertanggung jawab untuk mengatur gaya teks pada `pesan` NSTextField,
    /// termasuk font, kerning kustom, perataan tengah, dan memastikan teks dapat membungkus.
    override func viewWillLayout() {
        super.viewWillLayout()

        let text = pesan.stringValue
        let font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center // Teks diratakan di tengah

        // Mendefinisikan atribut untuk `NSAttributedString`
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: -0.8, // Mengatur kerning (jarak antar karakter) untuk efek visual yang spesifik
            .foregroundColor: NSColor.secondaryLabelColor, // Mengatur warna teks sekunder
            .paragraphStyle: paragraphStyle,
        ]
        // Membuat `NSAttributedString` dengan teks dan atribut yang ditentukan
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Mengatur `attributedStringValue` dari NSTextField untuk menerapkan gaya
        pesan.attributedStringValue = attributedString

        // Memastikan `NSTextFieldCell` tidak nil dan mengaktifkan pembungkus teks untuk teks multi-baris.
        if let cell = pesan.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = false // Memungkinkan teks menggunakan lebih dari satu baris
            cell.wraps = true // Memastikan teks akan membungkus ke baris berikutnya jika terlalu panjang
        }
    }

    /// Mengonfigurasi pesan teks dan gambar yang ditampilkan di jendela notifikasi.
    ///
    /// - Parameters:
    ///   - message: `String` yang akan ditampilkan sebagai pesan.
    ///   - image: `NSImage` yang akan ditampilkan sebagai ikon atau gambar.
    func configure(with message: String, image: NSImage) {
        pesan.stringValue = message // Mengatur teks pesan
        imageView.image = image // Mengatur gambar
    }
}
