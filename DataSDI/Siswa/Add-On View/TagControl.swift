//
//  TagControl.swift
//  Data SDI
//
//  Created by Bismillah on 24/12/24.
//

import Cocoa

/// Tag control untuk pemilihan kelas di dalam `Daftar Siswa`.
class TagControl: NSControl {
    /// Referensi lemah ke `NSTextField` yang akan diperbarui teksnya saat mouse masuk/keluar.
    weak var textField: NSTextField?

    /// Menandakan apakah tag sedang dipilih. Mengatur ulang akan memicu *redraw*.
    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    func resetState() {
        multipleItem = false
        isSelected = false
        unselected = false
    }

    /// Digunakan untuk membandingkan tag kelas dengan kelas siswa untuk rendering
    ///  ``addPath(_:)``, ``tickPath(_:)`` atau ``removePath(_:)``.
    var kelasValue: String?

    /// Status sementara untuk menandai tag lain saat tag ini di-*hover*.
    var unselected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    /// Menentukan apakah ikon yang ditampilkan saat hover adalah tanda tambah (`+`) atau centang (`✓`).
    var multipleItem: Bool = false

    /// Warna utama lingkaran tag.
    let color: NSColor
    /// Work item untuk debouce pembaruan ``textField`` ketika ``mouseInside``.
    var updateTextWork: DispatchWorkItem?
    /// Status apakah kursor berada di dalam area pelacakan. Mengubah nilai ini akan memperbarui tampilan dan teks ``textField``.
    var mouseInside: Bool = false {
        didSet {
            needsDisplay = true
            updateTextWork?.cancel()
            if mouseInside {
                updateTextWork = DispatchWorkItem { [unowned self] in
                    textField?.stringValue = "\(colorName(for: color))"
                    textField?.textColor = NSColor.systemGray
                }
                if let updateText = updateTextWork {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: updateText)
                }
            } else {
                updateTextWork = DispatchWorkItem { [unowned self] in
                    textField?.stringValue = "Kelas Aktif"
                    textField?.textColor = NSColor.systemGray
                }
                if let updateText = updateTextWork {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: updateText)
                }
            }
        }
    }

    /// Menginisialisasi sebuah ``TagControl`` dengan warna dan bingkai yang ditentukan.
    ///
    /// Kontrol ini dapat digunakan sebagai penanda visual untuk mengategorikan item berdasarkan warna,
    /// misalnya untuk mewakili status atau tingkat kelas.
    ///
    /// - Parameters:
    ///   - color: `NSColor` yang digunakan untuk mewarnai tag.
    ///   - frame: `NSRect` yang menentukan posisi dan ukuran kontrol.
    init(_ color: NSColor, frame: NSRect) {
        self.color = color
        super.init(frame: frame)
        setupTrackingArea()
    }

    /// Menginisialisasi ``TagControl`` dari sebuah coder.
    ///
    /// Ini adalah inisialisasi yang diperlukan untuk mendukung Storyboard atau xib. Warna default-nya adalah clear.
    ///
    /// - Parameter coder: `NSCoder` yang berisi data arsip untuk objek.
    required init?(coder: NSCoder) {
        color = .clear
        super.init(coder: coder)
    }

    /// Mengatur area pelacakan (tracking area).
    ///
    /// Fungsi ini membuat sebuah `NSTrackingArea` yang sedikit lebih besar dari *frame* tampilan itu sendiri
    /// dengan menambahkan margin di sekelilingnya (kecuali bagian atas). Ini memungkinkan tampilan
    /// untuk merespons peristiwa *mouse* seperti masuk (`mouseEntered`) dan keluar (`mouseExited`)
    /// dari area yang ditentukan, bahkan ketika kursor *mouse* tidak ditekan, dan juga saat
    /// kursor sudah berada di dalam area pelacakan saat area pelacakan ditambahkan.
    ///
    /// Area pelacakan diperluas sebesar `margin` (3 poin) di sisi kiri, bawah, dan kanan
    /// dari *frame* tampilan saat ini, memastikan *event* terpicu bahkan sebelum kursor
    /// secara visual benar-benar berada di atas batas tampilan.
    ///
    /// - Note:
    ///   Fungsi ini sebaiknya dipanggil sekali, biasanya saat inisialisasi tampilan (misalnya,
    ///   di `init(frame:)` atau `awakeFromNib`) untuk memastikan pelacakan *mouse* aktif
    ///   sejak awal. Lebih baik jika dipanggil ketika ``updateTrackingAreas()``.
    func setupTrackingArea() {
        /// Margin (ruang tambahan) yang akan ditambahkan ke *frame* untuk area pelacakan.
        /// Margin sebesar 3 poin digunakan untuk memperluas area pelacakan di sekitar tampilan.
        let margin: CGFloat = 3

        /// Membuat *rect* baru (`NSRect`) untuk area pelacakan berdasarkan `bounds` view.
        /// Menggunakan `bounds` memastikan koordinat area pelacakan selalu relatif ke
        /// sistem koordinat internal view, sehingga tetap konsisten walau posisi view
        /// di superview berubah.
        ///
        /// * `dx: -margin` dan `dy: -margin`: Memperluas area pelacakan ke kiri, kanan,
        ///   atas, dan bawah sebesar `margin`.
        /// * Nilai negatif pada `insetBy` berarti area diperluas, bukan diperkecil.
        ///
        /// Contoh: margin 3 poin akan membuat area pelacakan 3 poin lebih besar di
        /// setiap sisi dibandingkan ukuran asli `bounds`.
        let trackingFrame = bounds.insetBy(dx: -margin, dy: -margin)

        /// Menginisialisasi `NSTrackingArea` dengan *frame* yang telah ditentukan dan opsi pelacakan.
        let trackingArea = NSTrackingArea(
            rect: trackingFrame,
            options: [
                /// Area pelacakan akan selalu aktif.
                .activeAlways,
                /// Memberi tahu pemilik (owner) ketika kursor *mouse* masuk atau keluar dari area pelacakan.
                .mouseEnteredAndExited,
            ],
            owner: self, // Objek yang akan menerima peristiwa mouse (dalam hal ini, tampilan itu sendiri).
            userInfo: nil // Informasi khusus aplikasi tambahan yang terkait dengan area pelacakan (tidak digunakan di sini).
        )

        /// Menambahkan `NSTrackingArea` yang baru dibuat ke tampilan,
        /// mengaktifkan pelacakan *mouse* untuk area yang ditentukan.
        addTrackingArea(trackingArea)
    }

    /// Menandai `mouseInside = true` dan memperbarui status tag lain.
    override func mouseEntered(with _: NSEvent) {
        mouseInside = true
        updateOtherTags()
    }

    /// Menandai `mouseInside = false` dan memperbarui status tag lain.
    override func mouseExited(with _: NSEvent) {
        mouseInside = false
        updateOtherTags()
    }

    private func updateOtherTags() {
        guard let parentView = superview else { return }
        for subview in parentView.subviews {
            if let tag = subview as? TagControl, tag.isSelected, tag != self {
                tag.unselected = mouseInside
            }
        }
    }

    /// Mengirim aksi (`action`) ke target yang ditentukan.
    override func mouseDown(with _: NSEvent) {
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    /// Menggambar lingkaran berwarna, *stroke*, dan ikon sesuai status (`isSelected`, `unselected`, `mouseInside`, `multipleItem`).
    /// - Parameter dirtyRect: `NSRect` lingkaran.
    override func draw(_ dirtyRect: NSRect) {
        color.set()

        let circleRect: NSRect = mouseInside ? dirtyRect : NSInsetRect(dirtyRect, 3, 3)
        let circle = NSBezierPath(ovalIn: circleRect)
        circle.fill()

        let strokeColor = color.shadow(withLevel: 0.2)
        let insetRect = NSInsetRect(circleRect, 1.0, 1.0)
        let insetCircle = NSBezierPath(ovalIn: insetRect)
        strokeColor?.set()
        insetCircle.fill()

        // Tampilkan ikon berdasarkan status
        let iconRect = NSInsetRect(dirtyRect, 6, 6)

        if mouseInside, isSelected {
            if !multipleItem {
                let iconPath = tickPath(iconRect)
                NSColor.white.setFill()
                iconPath.fill()
            } else {
                let iconPath = addPath(iconRect)
                NSColor.white.setFill()
                iconPath.fill()
            }
            return
        }

        if unselected {
            let iconPath = removePath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
            return
        }

        if mouseInside {
            let iconPath = addPath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
        }

        // Tampilkan ikon tick jika item `selected`
        if isSelected {
            let iconPath = tickPath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
        }
    }

    /// Membuat string deskriptif untuk warna tertentu, digunakan untuk memperbarui teks ``textField``.
    ///
    /// Fungsi ini memetakan objek `NSColor` ke string teks yang deskriptif.
    /// Digunakan untuk menampilkan label yang berhubungan dengan warna di antarmuka pengguna,
    /// seperti menu atau tooltip.
    ///
    /// - Parameter color: Warna `NSColor` yang akan dikonversi.
    ///
    /// - Returns: Sebuah `String` yang berisi nama kelas yang sesuai atau "Kelas Aktif"
    /// jika warnanya tidak cocok.
    func colorName(for color: NSColor) -> String {
        switch color {
        case NSColor(named: "kelas1") ?? NSColor.clear: "Ubah ke: \"Kelas 1\""
        case NSColor(named: "kelas2") ?? NSColor.clear: "Ubah ke: \"Kelas 2\""
        case NSColor(named: "kelas3") ?? NSColor.clear: "Ubah ke: \"Kelas 3\""
        case NSColor(named: "kelas4") ?? NSColor.clear: "Ubah ke: \"Kelas 4\""
        case NSColor(named: "kelas5") ?? NSColor.clear: "Ubah ke: \"Kelas 5\""
        case NSColor(named: "kelas6") ?? NSColor.clear: "Ubah ke: \"Kelas 6\""
        default: "Kelas Aktif"
        }
    }

    /// Membuat dan mengembalikan `NSBezierPath` yang menggambarkan simbol "tambah" (`+`).
    ///
    /// Jalur ini digambar relatif terhadap titik asal (*origin*) dari `rect` yang diberikan,
    /// dengan menggunakan koordinat `minX` dan `minY` dari *rect* sebagai acuan.
    /// Bentuk yang dihasilkan adalah tanda plus (+) dengan ketebalan garis implisit yang ditentukan
    /// oleh serangkaian segmen garis.
    ///
    /// - Parameter rect: `NSRect` yang digunakan untuk menentukan titik acuan `minX` dan `minY`
    ///                   untuk menggambar jalur. Lebar dan tinggi `rect` tidak secara langsung
    ///                   memengaruhi ukuran jalur, tetapi lebih pada posisi relatifnya.
    /// - Returns: Sebuah `NSBezierPath` yang merepresentasikan simbol "tambah".
    func addPath(_ rect: NSRect) -> NSBezierPath {
        let minX = NSMinX(rect) // Koordinat x minimum dari rect.
        let minY = NSMinY(rect) // Koordinat y minimum dari rect.

        let path = NSBezierPath() // Membuat objek NSBezierPath baru.

        // Membangun jalur berbentuk tanda "plus" dengan serangkaian segmen garis.
        // Koordinat yang digunakan adalah relatif terhadap minX dan minY dari rect.
        path.move(to: NSPoint(x: minX + 0.5, y: minY + 3.25))
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 3.25))
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 0.5))
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 0.5))
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 3.25))
        path.line(to: NSPoint(x: minX + 7.5, y: minY + 3.25))
        path.line(to: NSPoint(x: minX + 7.5, y: minY + 4.75))
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 4.75))
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 7.5))
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 7.5))
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 4.75))
        path.line(to: NSPoint(x: minX + 0.5, y: minY + 4.75))
        path.close() // Menutup jalur, menghubungkan titik terakhir ke titik awal.

        return path // Mengembalikan NSBezierPath yang telah dibuat.
    }

    /// Membuat dan mengembalikan `NSBezierPath` yang menggambarkan simbol "silang" (`x`) atau "hapus".
    ///
    /// Jalur ini digambar relatif terhadap titik asal (*origin*) dari `rect` yang diberikan,
    /// menggunakan koordinat `minX` dan `minY` dari *rect* sebagai acuan.
    /// Bentuk yang dihasilkan adalah tanda silang (X) yang simetris, sering digunakan untuk menunjukkan
    /// tindakan "hapus" atau "tutup".
    ///
    /// - Parameter rect: `NSRect` yang digunakan untuk menentukan titik acuan `minX` dan `minY`
    ///                   untuk menggambar jalur. Lebar dan tinggi `rect` tidak secara langsung
    ///                   memengaruhi ukuran jalur, tetapi lebih pada posisi relatifnya.
    /// - Returns: Sebuah `NSBezierPath` yang merepresentasikan simbol "silang".
    func removePath(_ rect: NSRect) -> NSBezierPath {
        let minX = NSMinX(rect) // Koordinat x minimum dari rect.
        let minY = NSMinY(rect) // Koordinat y minimum dari rect.

        let path = NSBezierPath() // Membuat objek NSBezierPath baru.

        // Membangun jalur berbentuk tanda "silang" dengan serangkaian segmen garis.
        // Koordinat yang digunakan adalah relatif terhadap minX dan minY dari rect.
        path.move(to: NSPoint(x: minX, y: minY + 1))
        path.line(to: NSPoint(x: minX + 1, y: minY))
        path.line(to: NSPoint(x: minX + 4, y: minY + 3))
        path.line(to: NSPoint(x: minX + 7, y: minY))
        path.line(to: NSPoint(x: minX + 8, y: minY + 1))
        path.line(to: NSPoint(x: minX + 5, y: minY + 4))
        path.line(to: NSPoint(x: minX + 8, y: minY + 7))
        path.line(to: NSPoint(x: minX + 7, y: minY + 8))
        path.line(to: NSPoint(x: minX + 4, y: minY + 5))
        path.line(to: NSPoint(x: minX + 1, y: minY + 8))
        path.line(to: NSPoint(x: minX, y: minY + 7))
        path.line(to: NSPoint(x: minX + 3, y: minY + 4))
        path.close() // Menutup jalur, menghubungkan titik terakhir ke titik awal.

        return path // Mengembalikan NSBezierPath yang telah dibuat.
    }

    /// Membuat dan mengembalikan `NSBezierPath` yang menggambarkan simbol "centang" (tick/check mark).
    ///
    /// Jalur ini digambar relatif terhadap titik asal (*origin*) dari `rect` yang diberikan,
    /// menggunakan koordinat `minX` dan `minY` dari *rect* sebagai acuan.
    /// Bentuk yang dihasilkan adalah tanda centang, sering digunakan untuk menunjukkan konfirmasi
    /// atau penyelesaian.
    ///
    /// - Parameter rect: `NSRect` yang digunakan untuk menentukan titik acuan `minX` dan `minY`
    ///                   untuk menggambar jalur. Lebar dan tinggi `rect` tidak secara langsung
    ///                   memengaruhi ukuran jalur, tetapi lebih pada posisi relatifnya.
    /// - Returns: Sebuah `NSBezierPath` yang merepresentasikan simbol "centang".
    func tickPath(_ rect: NSRect) -> NSBezierPath {
        let minX = NSMinX(rect) // Koordinat x minimum dari rect.
        let minY = NSMinY(rect) // Koordinat y minimum dari rect.

        let path = NSBezierPath() // Membuat objek NSBezierPath baru.

        // Membangun jalur berbentuk tanda "centang" dengan serangkaian segmen garis.
        // Koordinat yang digunakan adalah relatif terhadap minX dan minY dari rect.
        path.move(to: NSPoint(x: minX + 2, y: minY))
        path.line(to: NSPoint(x: minX + 8, y: minY + 7))
        path.line(to: NSPoint(x: minX + 7, y: minY + 8))
        path.line(to: NSPoint(x: minX + 2.5, y: minY + 2.5))
        path.line(to: NSPoint(x: minX + 1.5, y: minY + 4.5))
        path.line(to: NSPoint(x: minX, y: minY + 4))
        path.close() // Menutup jalur, menghubungkan titik terakhir ke titik awal.

        return path // Mengembalikan NSBezierPath yang telah dibuat.
    }
}
