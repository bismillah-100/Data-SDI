//
//  CustomMenuItem.swift
//  Data SDI
//
//  Created by Bismillah on 23/12/24.
//

import Cocoa

/**
 `TagControl` adalah class kustom `NSControl` yang digunakan untuk menampilkan `NSMenuItem` kustom
 yang menampilkan pilihan untuk mengubah kelas aktif di ``SiswaViewController``.

 Kelas ini dapat dikonfigurasi untuk memungkinkan pengguna berinteraksi dengan tag, seperti menambah, menghapus, atau mengeditnya.

 - Note: Kelas ini adalah subclass dari `NSControl`, yang menyediakan dasar untuk kontrol kustom dalam aplikasi macOS.
 */
class TagControl: NSControl {
    /// Properti untuk referensi ketika mouse sedang berada di dalam tag.
    var isSelected: Bool = false
    /// Instans `NSColor`.
    let color: NSColor

    /**
      Nilai boolean yang menunjukkan apakah pointer mouse saat ini berada di dalam batas item menu kustom.

      Ketika nilai ini berubah, flag `needsDisplay` diatur ke `true`, memicu penggambaran ulang item menu.
     */
    var mouseInside: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    /**
     Inisialisasi sebuah `CustomMenuItem` dengan warna dan bingkai yang diberikan.

     - Parameter color: Warna latar belakang item menu.
     - Parameter frame: Bingkai (frame) item menu.

     Inisialisasi ini juga mengatur area pelacakan (tracking area) untuk mendeteksi peristiwa mouse seperti mouse masuk dan keluar.
     Area pelacakan hanya ditambahkan jika belum ada area pelacakan yang ada.
     */
    init(_ color: NSColor, frame: NSRect) {
        self.color = color
        super.init(frame: frame)

        if trackingAreas.isEmpty {
            let trackingArea = NSTrackingArea(
                rect: frame,
                options: [
                    .activeInKeyWindow,
                    .mouseEnteredAndExited,
                    .inVisibleRect,
                ],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseEntered(with _: NSEvent) {
        /// Ketika mouse berada di dalam tag.
        mouseInside = true
    }

    override func mouseExited(with _: NSEvent) {
        /// Ketika mouse berada di luar tag.
        mouseInside = false
    }

    override func mouseDown(with _: NSEvent) {
        /// Ketika mouse diklik kiri.
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        /// Terapkan properti ``color`` yang sudah diset ketika inisialisasi sebagai warna untuk `fill`.
        color.set()

        let circleRect: NSRect

            /// Menentukan persegi panjang untuk menggambar lingkaran berdasarkan apakah mouse berada di dalam area item atau tidak.
            /// Jika mouse berada di dalam, persegi panjang lingkaran sama dengan persegi panjang kotor.
            /// Jika tidak, persegi panjang lingkaran adalah persegi panjang kotor yang diperbesar sebesar 3 poin di setiap sisi.
            = if mouseInside
        {
            dirtyRect
        } else {
            NSInsetRect(dirtyRect, 3, 3)
        }

        let circle = NSBezierPath(ovalIn: circleRect)
        /// Cat lingkaran yang sudah dibuat dengan warna ``color``.
        circle.fill()

        /// Warna tepi.
        let strokeColor = color.shadow(withLevel: 0.2)
        /// Bagian dalam untuk membuat lingkaran.
        let insetRect = NSInsetRect(circleRect, 1.0, 1.0)
        /// Bagian dalam dan membuat lingkaran.
        let insetCircle = NSBezierPath(ovalIn: insetRect)

        /// Gunakan warna ``strokeColor``.
        strokeColor?.set()

        /// Cat bagian dalam lingkaran yang telah dibuat dengan ``strokeColor``.
        insetCircle.fill()

        // Draw remove icon and return early
        if mouseInside, isSelected {
            let iconRect = NSInsetRect(dirtyRect, 6, 6)
            let iconPath = removePath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
            return
        }

        // Else draw the add icon
        if mouseInside {
            let iconRect = NSInsetRect(dirtyRect, 6, 6)
            let iconPath = addPath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
        }

        // Draw the tick icon
        if isSelected {
            let iconRect = NSInsetRect(dirtyRect, 6, 6)
            let iconPath = tickPath(iconRect)
            NSColor.white.setFill()
            iconPath.fill()
        }
    }

    /**
     Menambahkan path berbentuk silang ke `NSBezierPath` di dalam persegi panjang yang diberikan.

     Fungsi ini membuat bentuk (+) menggunakan serangkaian garis di dalam `NSRect` yang ditentukan.
     Tambah didefinisikan oleh urutan panggilan `line(to:)`, dimulai dari sudut kiri bawah
     dan menggambar setiap segmen tambah (+). Path kemudian ditutup untuk menyelesaikan bentuk.

     - Parameter rect: `NSRect` di mana bentuk tambah akan digambar. Posisi dan
              ukuran persegi panjang menentukan asal untuk koordinat tambah (+).

     - Returns: Objek `NSBezierPath` yang mewakili bentuk +.
     */
    func addPath(_ rect: NSRect) -> NSBezierPath {
        // Mendapatkan koordinat X minimum (paling kiri) dan Y minimum (paling bawah) dari NSRect yang diberikan.
        let minX = NSMinX(rect)
        let minY = NSMinY(rect)

        // Membuat instance NSBezierPath baru. Objek ini akan digunakan untuk menggambar bentuk.
        let path = NSBezierPath()

        // Memindahkan titik awal path ke koordinat yang ditentukan relatif terhadap minX dan minY.
        // Ini adalah awal dari salah satu lengan salib.
        path.move(to: NSPoint(x: minX + 0.5, y: minY + 3.25))

        // Menggambar serangkaian segmen garis untuk membentuk bentuk salib.
        // Setiap `line(to:)` melanjutkan gambar dari titik sebelumnya ke titik yang baru.
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 3.25)) // Sudut pertama
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 0.5)) // Menurun
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 0.5)) // Melintang
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 3.25)) // Ke atas
        path.line(to: NSPoint(x: minX + 7.5, y: minY + 3.25)) // Lengan horizontal kanan
        path.line(to: NSPoint(x: minX + 7.5, y: minY + 4.75)) // Menurun sedikit
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 4.75)) // Melintang ke kiri
        path.line(to: NSPoint(x: minX + 4.75, y: minY + 7.5)) // Lengan vertikal atas
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 7.5)) // Melintang ke kiri
        path.line(to: NSPoint(x: minX + 3.25, y: minY + 4.75)) // Menurun
        path.line(to: NSPoint(x: minX + 0.5, y: minY + 4.75)) // Melintang ke kiri (menyelesaikan bentuk)

        // Menutup path, yang berarti menggambar garis dari titik terakhir kembali ke titik awal.
        // Ini akan membentuk bentuk tertutup.
        path.close()

        // Mengembalikan objek NSBezierPath yang telah dibuat.
        return path
    }

    /// Fungsi removePath membuat dan mengembalikan objek NSBezierPath yang menggambarkan bentuk 'X' (silang) atau tanda hapus, relatif terhadap NSRect yang diberikan. Bentuk ini dibuat dengan serangkaian segmen garis yang membentuk dua garis diagonal yang saling berpotongan.
    /// - Parameter rect: `NSRect` di mana bentuk tambah akan digambar. Posisi dan
    ///          ukuran persegi panjang menentukan asal untuk koordinat tambah (+).
    /// - Returns: Objek `NSBezierPath` yang mewakili bentuk (x).
    func removePath(_ rect: NSRect) -> NSBezierPath {
        // Mendapatkan koordinat X minimum (paling kiri) dan Y minimum (paling bawah) dari NSRect yang diberikan.
        let minX = NSMinX(rect)
        let minY = NSMinY(rect)

        // Membuat instance NSBezierPath baru untuk menggambar bentuk.
        let path = NSBezierPath()

        // Memindahkan titik awal path ke koordinat pertama dari bentuk 'X'.
        path.move(to: NSPoint(x: minX, y: minY + 1))

        // Menggambar serangkaian segmen garis untuk membentuk tanda 'X'.
        // Titik-titik ini secara berurutan membentuk garis diagonal pertama,
        // kemudian melompat ke garis diagonal kedua, dan seterusnya hingga bentuk tertutup.
        path.line(to: NSPoint(x: minX + 1, y: minY)) // Segmen pertama
        path.line(to: NSPoint(x: minX + 4, y: minY + 3)) // Lanjutkan ke tengah
        path.line(to: NSPoint(x: minX + 7, y: minY)) // Lanjutkan ke sudut kanan atas
        path.line(to: NSPoint(x: minX + 8, y: minY + 1)) // Belok
        path.line(to: NSPoint(x: minX + 5, y: minY + 4)) // Menuju tengah
        path.line(to: NSPoint(x: minX + 8, y: minY + 7)) // Sudut kanan bawah
        path.line(to: NSPoint(x: minX + 7, y: minY + 8)) // Belok
        path.line(to: NSPoint(x: minX + 4, y: minY + 5)) // Menuju tengah
        path.line(to: NSPoint(x: minX + 1, y: minY + 8)) // Sudut kiri bawah
        path.line(to: NSPoint(x: minX, y: minY + 7)) // Belok
        path.line(to: NSPoint(x: minX + 3, y: minY + 4)) // Kembali ke titik awal diagonal (dekat pusat)

        // Menutup path, yang berarti menggambar garis dari titik terakhir kembali ke titik awal.
        // Ini akan membentuk bentuk 'X' tertutup.
        path.close()

        // Mengembalikan objek NSBezierPath yang telah dibuat.
        return path
    }

    /// Fungsi tickPath membuat dan mengembalikan objek NSBezierPath yang menggambarkan bentuk tanda centang (✓) yang terpusat relatif terhadap NSRect yang diberikan. Bentuk ini digambar menggunakan serangkaian garis lurus yang saling terhubung.
    /// - Parameter rect: `NSRect` di mana bentuk tambah akan digambar. Posisi dan
    ///          ukuran persegi panjang menentukan asal untuk koordinat centang (✓).
    /// - Returns: Objek `NSBezierPath` yang mewakili bentuk (✓).
    func tickPath(_ rect: NSRect) -> NSBezierPath {
        // Mendapatkan koordinat X minimum (paling kiri) dan Y minimum (paling bawah) dari NSRect yang diberikan.
        let minX = NSMinX(rect)
        let minY = NSMinY(rect)

        // Membuat instance NSBezierPath baru. Objek ini akan digunakan untuk menggambar bentuk.
        let path = NSBezierPath()

        // Memindahkan titik awal path ke koordinat yang ditentukan relatif terhadap minX dan minY.
        // Ini adalah awal dari bagian bawah tanda centang.
        path.move(to: NSPoint(x: minX + 2, y: minY))

        // Menggambar serangkaian segmen garis untuk membentuk tanda centang.
        // Setiap `line(to:)` melanjutkan gambar dari titik sebelumnya ke titik yang baru.
        path.line(to: NSPoint(x: minX + 8, y: minY + 7)) // Garis naik ke kanan atas
        path.line(to: NSPoint(x: minX + 7, y: minY + 8)) // Puncak tanda centang
        path.line(to: NSPoint(x: minX + 2.5, y: minY + 2.5)) // Garis turun ke kiri bawah
        path.line(to: NSPoint(x: minX + 1.5, y: minY + 4.5)) // Sudut kecil
        path.line(to: NSPoint(x: minX, y: minY + 4)) // Kembali ke sisi kiri

        // Menutup path, yang berarti menggambar garis dari titik terakhir kembali ke titik awal.
        // Ini akan membentuk bentuk tertutup dari tanda centang.
        path.close()

        // Mengembalikan objek NSBezierPath yang telah dibuat.
        return path
    }
}

/// Class untuk membuat ``TagControl`` dengan warna-warna berbeda
/// mulai kelas 1 - kelas 6 dan membuat `tagControl` berwarna merah
/// yang digunakan untuk menghapus kelas aktif.
class TagViewController: NSViewController {
    override func loadView() {
        view = NSView()
    }

    /// Action ketika tag diklik.
    /// - Parameter sender: Objek yang memicu, yaitu event `mouseDown`.
    @objc func tagClicked(_ sender: AnyObject?) {
        guard let tag = sender as? TagControl else { return }

        tag.isSelected.toggle()
    }

    override func viewDidLoad() {
        /// warna merah
        let redTag = TagControl(.red, frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        /// warna biru
        let blueTag = TagControl(.blue, frame: NSRect(x: 24, y: 0, width: 20, height: 20))
        /// warna hijau
        let greenTag = TagControl(.green, frame: NSRect(x: 48, y: 0, width: 20, height: 20))
        /// warna kuning
        let yellowTag = TagControl(.yellow, frame: NSRect(x: 72, y: 0, width: 20, height: 20))
        /// warna oranye
        let orangeTag = TagControl(.orange, frame: NSRect(x: 96, y: 0, width: 20, height: 20))
        /// warna abu-abu
        let grayTag = TagControl(.gray, frame: NSRect(x: 120, y: 0, width: 20, height: 20))

        redTag.tag = 0
        redTag.target = self
        redTag.action = #selector(tagClicked(_:))

        blueTag.tag = 1
        blueTag.target = self
        blueTag.action = #selector(tagClicked(_:))

        greenTag.tag = 2
        greenTag.target = self
        greenTag.action = #selector(tagClicked(_:))

        yellowTag.tag = 3
        yellowTag.target = self
        yellowTag.action = #selector(tagClicked(_:))

        orangeTag.tag = 4
        orangeTag.target = self
        orangeTag.action = #selector(tagClicked(_:))

        grayTag.tag = 5
        grayTag.target = self
        grayTag.action = #selector(tagClicked(_:))

        view.addSubview(redTag)
        view.addSubview(blueTag)
        view.addSubview(greenTag)
        view.addSubview(yellowTag)
        view.addSubview(orangeTag)
        view.addSubview(grayTag)
    }
}
