//
//  PratinjauFoto.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/23.
//

import Cocoa

/// Class untuk menampilkan pratinjau foto siswa yang digunakan di ``DetailSiswaController``, ``EditData``, dan ``AddDataViewController``.
class PratinjauFoto: NSViewController {
    /// scrollView yang memuat imageView.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk NSImageView yang menampilkan foto siswa.
    @IBOutlet weak var imageView: XSDragImageView!
    /// Outlet visualEffect di bawah tombol.
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    /// Outlet visualEffect di bawah tombol berbagi.
    @IBOutlet weak var visualEffectShare: NSVisualEffectView!
    /// Outlet stackView yang memuat tombol.
    @IBOutlet weak var stackView: NSStackView!
    /// Menu item "Pilih File..."
    @IBOutlet weak var pilihFileMenuItem: NSMenuItem!
    /// Menu item "Simpan ke Database".
    @IBOutlet weak var simpanFotoMenuItem: NSMenuItem!
    /// Outlet tombol berbagi.
    @IBOutlet weak var shareMenu: NSButton!
    /// Data foto siswa yang akan ditampilkan.
    /// Digunakan untuk menyimpan data foto siswa yang diambil dari database.
    var fotoData: Data?
    /// Siswa yang dipilih untuk ditampilkan fotonya.
    /// Digunakan untuk menyimpan informasi siswa yang dipilih dari daftar siswa.
    var selectedSiswa: ModelSiswa?
    /// Kontroler database yang digunakan untuk mengakses data siswa dan foto siswa.
    let dbController = DatabaseController.shared
    /// Objek `FotoSiswa` yang berisi informasi foto siswa.
    var foto: Data!
    /// URL gambar yang dipilih oleh pengguna.
    var selectedImageURL: URL?

    /// Ukuran yang fit ke frame ``scrollView``.
    /// diset di ``fitInitialImage(_:)``
    var clampedMagnification: CGFloat! {
        didSet {
            imageView.clampedMagnification = clampedMagnification
        }
    }
    
    /// Properti untuk menyimpan panGesture recognizer
    private lazy var panGesture: NSPanGestureRecognizer = .init(target: self, action: #selector(handlePanGesture(_:)))

    override func loadView() {
        super.loadView()
        scrollView.documentView = imageView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        visualEffect.wantsLayer = true
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.cornerRadius = 14
        
        visualEffectShare.wantsLayer = true
        visualEffectShare.layer?.masksToBounds = true
        visualEffectShare.layer?.cornerRadius = 14
        let shareImage = NSImage(systemSymbolName: "square.and.arrow.up.fill", accessibilityDescription: nil)
        let customImageConf = NSImage.SymbolConfiguration(pointSize: 14.0, weight: .bold)
        let customShareImage = shareImage?.withSymbolConfiguration(customImageConf)
        shareMenu.image = customShareImage
        /// Ambil foto siswa dari database berdasarkan ID siswa yang dipilih.
        foto = dbController.bacaFotoSiswa(idValue: selectedSiswa?.id ?? 0)
        if let image = NSImage(data: foto) {
            setImageView(image)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidChangeBounds(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        simpanFotoMenuItem.isHidden = true
    }
    
    /// Merespons perubahan bounds pada `scrollView`.
    /// 
    /// Fungsi ini akan mengaktifkan atau menonaktifkan fitur drag pada `imageView`
    /// berdasarkan nilai `magnification` pada `scrollView`. Jika `magnification`
    /// sama dengan `clampedMagnification`, fitur drag diaktifkan dan gesture recognizer
    /// untuk pan dihapus dari `scrollView` jika sudah ada. Jika tidak sama, fitur drag
    /// dinonaktifkan dan gesture recognizer untuk pan ditambahkan ke `scrollView`
    /// jika belum ada.
    /// 
    /// - Parameter notification: Notifikasi yang diterima ketika bounds dari `scrollView` berubah.
    @objc
    func scrollViewDidChangeBounds(_ notification: Notification) {
        guard let clampedMagnification else { return }
        let tolerance: CGFloat = 0.0001
        if abs(scrollView.magnification - clampedMagnification) < tolerance {
            if !imageView.enableDrag {
                imageView.enableDrag = true
            }
            // Hapus recognizer hanya jika sudah ada
            if scrollView.gestureRecognizers.contains(panGesture) {
                scrollView.removeGestureRecognizer(panGesture)
            }
            imageView.superViewDragging = false
            visualEffect.isHidden = false
            visualEffectShare.isHidden = false
        } else {
            if imageView.enableDrag {
                imageView.enableDrag = false
            }
            // Tambahkan recognizer hanya jika belum ada
            if !scrollView.gestureRecognizers.contains(panGesture) {
                scrollView.addGestureRecognizer(panGesture)
            }
            visualEffect.isHidden = true
            visualEffectShare.isHidden = true
        }
    }
    
    private var originalScrollOrigin: NSPoint = .zero

    /// Menangani gesture pan (geser) pada `scrollView` untuk navigasi manual konten gambar.
    ///
    /// Metode ini adalah target untuk `NSPanGestureRecognizer` yang memungkinkan pengguna untuk
    /// menggeser konten di dalam `scrollView` secara manual. Ini terutama berguna ketika gambar
    /// di-zoom in (diperbesar) dan sebagian dari gambar berada di luar area pandang yang terlihat.
    ///
    /// Metode ini dinonaktifkan ketika gambar tidak dizoom.
    ///
    /// - Parameter gesture: Objek `NSPanGestureRecognizer` yang memicu metode ini.
    @objc func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let documentView = scrollView.documentView, !imageView.enableDrag else {
            return
        }
        let translation = gesture.translation(in: scrollView)
        
        switch gesture.state {
        case .began:
            // Simpan posisi scroll awal
            originalScrollOrigin = documentView.visibleRect.origin
            imageView.superViewDragging = true
        case .changed:
            // Hitung faktor pembesaran
            let zoomFactor = scrollView.magnification > 0 ? scrollView.magnification : 1.0
            
            let adjustedTranslation = NSPoint(
                x: translation.x / zoomFactor,
                y: translation.y / zoomFactor
            )
            
            let newOrigin = NSPoint(
                x: originalScrollOrigin.x - adjustedTranslation.x,
                y: originalScrollOrigin.y + adjustedTranslation.y
            )
            documentView.scroll(newOrigin)
        case .ended, .cancelled, .failed:
            imageView.superViewDragging = false
        default:
            break
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Pastikan hanya dijalankan sekali jika perlu, atau setiap kali layout berubah jika diinginkan.
        // Di sini kita asumsikan ingin set zoom awal setiap kali layout berubah (misal window di-resize).
        if let image = NSImage(data: foto) {
            fitInitialImage(image)
        }
    }

    /// Mengatur gambar yang akan ditampilkan di `imageView` dan mengonfigurasi `scrollView` untuk fitur zoom.
    ///
    /// Fungsi ini melakukan beberapa tugas utama:
    /// 1. Menetapkan objek `NSImage` yang diberikan ke `imageView`.
    /// 2. Menyesuaikan ukuran frame `imageView` agar sesuai dengan dimensi asli gambar. Ini penting
    ///    agar `imageView` tidak memotong atau meregangkan gambar secara tidak proporsional.
    /// 3. Mengaktifkan kemampuan pembesaran (magnification/zoom) pada `scrollView` yang menampung `imageView`.
    /// 4. Mengatur ulang tingkat pembesaran `scrollView` ke `1.0` (100% ukuran asli) sebagai titik awal.
    /// 5. Menetapkan batas minimum dan maksimum untuk pembesaran yang diizinkan pada `scrollView`.
    ///    Nilai `minMagnification` diatur ke `0.1` (10%), memungkinkan pengecilan gambar yang signifikan,
    ///    sementara `maxMagnification` diatur ke `1.0` (100%), membatasi zoom hingga ukuran asli gambar.
    ///
    /// - Parameter image: Objek `NSImage` yang akan ditampilkan di `imageView`.
    func setImageView(_ image: NSImage) {
        // 2. Atur gambar ke image view
        // Menetapkan gambar yang baru ke properti `image` dari `NSImageView`.
        imageView.image = image

        // Biarkan image view menyesuaikan ukurannya dengan ukuran asli gambar
        // Mengubah ukuran frame `imageView` agar sama persis dengan ukuran piksel asli dari `image`.
        imageView.frame.size = image.size

        // 3. Konfigurasi ScrollView untuk mengizinkan zoom
        // Mengaktifkan fitur pembesaran pada `NSScrollView`, memungkinkan pengguna untuk
        // memperbesar atau memperkecil konten di dalamnya.
        scrollView.allowsMagnification = true

        // Menetapkan batas pembesaran minimum yang diizinkan (0.1 = 10% dari ukuran asli).
        scrollView.minMagnification = 0.01 // Minimum zoom, bisa disesuaikan

        // Menetapkan batas pembesaran maksimum yang diizinkan (1.0 = 100% dari ukuran asli).
        // Ini mencegah pengguna untuk memperbesar gambar melebihi ukuran aslinya.
        scrollView.maxMagnification = 10.0
        
        // Atur batas zoom awal yang fleksibel
        // Mengatur tingkat pembesaran `scrollView` kembali ke 100% (ukuran asli gambar).
        // Ini memastikan bahwa setiap kali gambar baru diatur, zoom kembali ke default.
        scrollView.magnification = 1.0 // Kembalikan zoom ke 100%
    }

    /// Menyesuaikan tingkat pembesaran (magnification) awal `scrollView` agar gambar pas di dalam area pandang.
    ///
    /// Fungsi ini pertama-tama menghitung nilai pembesaran optimal menggunakan `calculateInitialMagnification`
    /// sehingga seluruh gambar dapat terlihat. Kemudian, ia menerapkan nilai pembesaran tersebut ke
    /// `scrollView`, memusatkannya di titik tengah area pandang. Selain itu, fungsi ini juga mengatur
    /// `minMagnification` dari `scrollView` agar sama dengan pembesaran awal yang dihitung,
    /// memastikan pengguna tidak bisa memperkecil gambar melebihi ukuran "fit-to-view" ini.
    ///
    /// - Parameter image: Objek `NSImage` yang akan disesuaikan pembesaran awalnya di `scrollView`.
    func fitInitialImage(_ image: NSImage) {
        // Fungsi ini mengembalikan nilai magnification yang dihitung berdasarkan ukuran gambar
        // dan ukuran scrollView, memastikan gambar pas di dalam view.
        clampedMagnification = calculateInitialMagnification(for: image, in: scrollView)

        // Dapatkan titik tengah dari area yang terlihat untuk zoom.
        // `scrollView.contentView.bounds` merepresentasikan area yang terlihat dari konten scrollView.
        let scrollViewBounds = scrollView.contentView.bounds
        let centerPoint = NSPoint(x: scrollViewBounds.midX, y: scrollViewBounds.midY)

        // Set magnification awal. Pemusatan akan ditangani oleh CenteringClipView secara otomatis.
        // Mengatur tingkat pembesaran `scrollView` ke nilai yang dihitung, dengan memusatkan tampilan
        // pada `centerPoint`. Ini membuat gambar yang di-zoom akan terlihat di tengah.
        scrollView.setMagnification(clampedMagnification, centeredAt: centerPoint)

        // Mengatur `minMagnification` dari `scrollView` agar sama dengan tingkat pembesaran awal.
        // Ini mencegah pengguna untuk memperkecil gambar lebih dari ukuran yang sudah "fit-to-view".
        scrollView.minMagnification = clampedMagnification
    }

    override func viewWillAppear() {
        imageView.isEditable = true
        imageView.refusesFirstResponder = false
        imageView.nama = selectedSiswa?.nama
    }

    /// Action tombol "Simpan" untuk menyimpan foto siswa ke database.
    @IBAction func simpanFoto(_ sender: Any) {
        // Menambahkan alert sebelum menulis ke SQLite
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menyimpan foto?"
        alert.informativeText = "Foto \(selectedSiswa?.nama ?? "Siswa") akan diperbarui, tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Simpan")

        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self else { return }
            if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Simpan"
                // Melanjutkan penyimpanan jika pengguna menekan tombol "Simpan"
                let selectedImage = self.imageView.selectedImage
                let compressedImageData = selectedImage?.compressImage(quality: 0.5) ?? Data()
                self.dbController.updateFotoInDatabase(with: compressedImageData, idx: self.selectedSiswa?.id ?? 0)
            }
        }
    }

    /// Action untuk memperbarui foto siswa.
    @IBAction func editFoto(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        let response = openPanel.runModal()
        
        if response == NSApplication.ModalResponse.OK, let imageURL = openPanel.urls.first {
            // Atur XSDragImageView
            imageView.imageNow = imageView.image
            
            // Menyimpan URL gambar yang dipilih
            self.selectedImageURL = imageURL
            var imageData: Data?
            do {
                imageData = try Data(contentsOf: imageURL)
            } catch {
                ReusableFunc.showAlert(title: "Gagal Membaca Gambar", message: error.localizedDescription, style: .critical)
            }
            
            if let imageData, let image = NSImage(data: imageData), let compressed = image.compressImage(quality: 0.5), let finalImage = NSImage(data: compressed) {
                // Atur properti NSImageView
                setImageView(finalImage)
                
                // Supaya gambar bisa difit ke scrollView setelah ukuran gambar yang berubah.
                scrollView.layoutSubtreeIfNeeded()
                
                fitInitialImage(finalImage)

                imageView.selectedImage = image
                imageView.enableDrag = true
                simpanFotoMenuItem.isHidden = false
            }
        }
    }
    
    /// URL file sementara yang berisi foto siswa.
    var tempDir: URL?

    /// Menampilkan menu berbagi (share menu) untuk gambar yang ditampilkan pada `imageView`.
    /// - Parameter sender: Tombol (`NSButton`) yang men-trigger aksi berbagi.
    /// - Proses:
    ///   1. Membuat direktori sementara unik menggunakan UUID.
    ///   2. Jika gambar tersedia di `imageView`, gambar dikonversi ke format JPEG dan disimpan ke direktori sementara.
    ///   3. Jika gambar tidak tersedia, membuat file error sebagai placeholder.
    ///   4. Menampilkan `NSSharingServicePicker` untuk membagikan file yang telah disiapkan.
    /// - Catatan: Nama file gambar diambil dari nama siswa yang dipilih, karakter '/' diganti dengan '-'.
    @IBAction func shareMenu(_ sender: NSButton) {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        // Pastikan temporaryFileURL valid sebelum mencoba berbagi
        let sessionID = UUID().uuidString
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(sessionID)
        
        guard let tempDir else { return }
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sharingPicker: NSSharingServicePicker
        let fileName: String
        let fileURL: URL
        
        if let image = imageView.image?.jpegRepresentation {
            fileName = "\(selectedSiswa?.nama.replacingOccurrences(of: "/", with: "-") ?? "").jpeg"
            fileURL = tempDir.appendingPathComponent(fileName)
            
            try? image.write(to: fileURL)
            
            sharingPicker = NSSharingServicePicker(items: [fileURL])
            
            // Menampilkan menu berbagi
            sharingPicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        } else {
            fileName = "Error saat membaca data foto"
            fileURL = tempDir.appendingPathComponent(fileName)
            sharingPicker = NSSharingServicePicker(items: [fileURL])
            
            // Menampilkan menu berbagi
            sharingPicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
    // MARK: - Helper Function untuk Zoom Awal

    /// Menghitung tingkat pembesaran (magnification) awal yang optimal untuk menampilkan seluruh gambar
    /// di dalam `scrollView` tanpa terpotong, dengan mempertimbangkan batas zoom yang diizinkan oleh `scrollView`.
    ///
    /// Fungsi ini menentukan skala terkecil yang diperlukan agar lebar atau tinggi gambar pas
    /// dengan area pandang (`contentView.bounds`) dari `scrollView`. Hasilnya kemudian
    /// dibatasi (clamped) agar tidak melebihi `maxMagnification` dan tidak kurang dari `minMagnification`
    /// yang telah diatur pada `scrollView`.
    ///
    /// - Parameters:
    ///   - image: Objek `NSImage` yang akan ditampilkan dan dihitung pembesarannya.
    ///   - scrollView: Objek `NSScrollView` tempat gambar akan ditampilkan. Batas dan ukuran
    ///     area pandang (`contentView.bounds`) dari `scrollView` digunakan dalam perhitungan.
    ///
    /// - Returns: Nilai `CGFloat` yang merepresentasikan tingkat pembesaran awal yang disarankan.
    ///     Nilai ini akan memastikan gambar pas di dalam `scrollView` dan berada dalam
    ///     rentang `minMagnification` hingga `maxMagnification` dari `scrollView`.
    ///     Mengembalikan `1.0` jika ukuran `scrollViewBounds` atau `imageSize` tidak valid (misalnya, nol atau negatif).
    func calculateInitialMagnification(for image: NSImage, in scrollView: NSScrollView) -> CGFloat {
        // Mendapatkan ukuran area pandang yang tersedia di dalam scrollView.
        // Ini adalah area di mana dokumen (gambar) akan terlihat.
        let scrollViewBounds = scrollView.contentView.bounds

        // Melakukan validasi dasar: Jika lebar atau tinggi scrollViewBounds nol atau negatif,
        // fungsi ini tidak dapat menghitung skala yang bermakna, jadi kembalikan nilai default 1.0.
        guard scrollViewBounds.width > 0, scrollViewBounds.height > 0 else { return 1.0 }

        // Mendapatkan ukuran asli dari gambar yang akan ditampilkan.
        let imageSize = image.size

        // Melakukan validasi dasar: Jika lebar atau tinggi gambar nol atau negatif,
        // fungsi ini tidak dapat menghitung skala yang bermakna, jadi kembalikan nilai default 1.0.
        guard imageSize.width > 0, imageSize.height > 0 else { return 1.0 }

        // Hitung skala yang diperlukan agar lebar gambar pas dengan lebar scrollView.
        let scaleToFitWidth = scrollViewBounds.width / imageSize.width

        // Hitung skala yang diperlukan agar tinggi gambar pas dengan tinggi scrollView.
        let scaleToFitHeight = scrollViewBounds.height / imageSize.height

        // Untuk memastikan seluruh gambar terlihat di dalam scrollView (fit-to-view),
        // kita harus menggunakan skala yang lebih kecil dari kedua skala (lebar atau tinggi).
        // Misalnya, jika gambar lebar tapi pendek, kita akan menggunakan skala yang membuat
        // tingginya pas, sehingga lebarnya mungkin tidak sepenuhnya mengisi tapi tidak terpotong.
        let initialMagnification = min(scaleToFitWidth, scaleToFitHeight)

        // Memastikan nilai magnification yang dihitung berada dalam rentang yang diizinkan
        // oleh scrollView (antara minMagnification dan maxMagnification).
        // `max` digunakan untuk memastikan tidak lebih kecil dari `minMagnification`.
        // `min` digunakan untuk memastikan tidak lebih besar dari `maxMagnification`.
        let clampedMagnification = max(scrollView.minMagnification, min(initialMagnification, scrollView.maxMagnification))

        // Mengembalikan nilai magnification akhir yang sudah disesuaikan.
        return clampedMagnification
    }

    /// Action untuk menghapus foto siswa.
    @IBAction func hpsFoto(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menghapus foto"
        alert.informativeText = "Foto \(selectedSiswa?.nama ?? "Siswa") akan dihapus. Tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Hapus")

        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self, response == .alertSecondButtonReturn else { return }
            // .alertSecondButtonReturn adalah tombol "Hapus"
            
            // Melanjutkan penghapusan jika pengguna menekan tombol "Hapus"
            self.dbController.updateFotoInDatabase(with: Data(), idx: selectedSiswa?.id ?? 0)
            
            // Reset imageView
            if let defaultImage = NSImage(named: "image") {
                self.setImageView(defaultImage)
                self.fitInitialImage(defaultImage)
                self.imageView.selectedImage = nil
                self.imageView.enableDrag = false
            }
            dbController.vacuumDatabase()
        }
    }

    /// Action untuk menutup pratinjau foto.
    @IBAction func tutupPratinjau(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                window.performClose(sender)
            }
        }
    }

    /// Action untuk menyimpan foto siswa ke folder yang dipilih oleh pengguna.
    @IBAction func simpankeFolder(_ sender: Any) {
        guard let image = imageView.image else {
            // Tambahkan penanganan jika tidak ada gambar yang ditampilkan

            return
        }

        // Mengonversi NSImage ke Data dan mengompresi gambar
        guard let compressedImageData = image.compressImage(quality: 0.5) else {
            // Tambahkan penanganan jika gagal mengonversi atau mengompresi ke Data
            return
        }

        // Membuat nama file berdasarkan nama siswa
        let fileName = "\(selectedSiswa?.nama.replacingOccurrences(of: "/", with: "-") ?? "unknown").png"

        // Menyimpan data gambar ke file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.image]
        savePanel.nameFieldStringValue = fileName // Menetapkan nama file default
        
        let result = savePanel.runModal()
        
        if result == .OK, let fileURL = savePanel.url {
            do {
                try compressedImageData.write(to: fileURL)

            } catch {
                ReusableFunc.showAlert(title: "Gagal Menyimpan Foto", message: error.localizedDescription, style: .critical)
            }
        }
    }

    // MARK: - Zoom Handling

    /// Memusatkan `imageView` di dalam `scrollView` dengan menghitung dan mengatur padding horizontal dan vertikal.
    /// Fungsi ini akan menambahkan `contentInsets` pada `scrollView` sehingga gambar berada di tengah area tampilan scroll.
    /// Jika tidak ada gambar pada `imageView`, fungsi akan langsung keluar.
    /// - Catatan: Padding hanya akan diterapkan jika ukuran gambar lebih kecil dari ukuran `scrollView`.
    func centerImageInScrollView() {
        guard imageView.image != nil else { return }

        let scrollViewBounds = scrollView.bounds
        let imageViewFrame = imageView.frame

        // Hitung padding yang diperlukan untuk memusatkan documentView
        let horizontalPadding = max((scrollViewBounds.width - imageViewFrame.width) / 2, 0)
        let verticalPadding = max((scrollViewBounds.height - imageViewFrame.height) / 2, 0)

        // Atur contentInsets untuk memusatkan imageView
        scrollView.contentInsets = NSEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: 0, right: 0)
    }

    /// Menganimasikan perubahan tingkat pembesaran (zoom) pada `scrollView`.
    ///
    /// - Parameter magnification: Nilai pembesaran (zoom) yang ingin diterapkan.
    /// - Catatan: Animasi berlangsung selama 0.2 detik dengan fungsi waktu `easeInEaseOut`.
    /// Setelah animasi selesai, gambar akan diposisikan ke tengah di dalam `scrollView`.
    private func animateZoom(to magnification: CGFloat) {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self?.scrollView.animator().magnification = magnification
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.centerImageInScrollView()
        }
    }

    /// Fungsi untuk memperbesar foto.
    @IBAction func increaseSize(_ sender: Any) {
        let zoomStep: CGFloat = 0.5 // Langkah zoom
        var newMagnification = scrollView.magnification * (1.0 + zoomStep)

        // Pastikan newMagnification tidak melebihi maxMagnification
        newMagnification = min(newMagnification, scrollView.maxMagnification)

        // Panggil animateZoom hanya jika magnification akan berubah
        if scrollView.magnification != newMagnification {
            animateZoom(to: newMagnification)
        }
    }

    /// Fungsi untuk memperkecil foto.
    @IBAction func decreaseSize(_ sender: Any) {
        let zoomStep: CGFloat = 0.5 // Langkah zoom
        var newMagnification = scrollView.magnification * (1.0 - zoomStep)

        // Pastikan newMagnification tidak kurang dari initialClampedMagnification (atau minMagnification yang Anda atur)
        newMagnification = max(newMagnification, clampedMagnification) // Menggunakan initialClampedMagnification sebagai batas zoom out
        // Atau Anda bisa menggunakan newMagnification = max(newMagnification, scrollView.minMagnification)

        // Panggil animateZoom hanya jika magnification akan berubah
        if scrollView.magnification != newMagnification {
            animateZoom(to: newMagnification)
        }
    }
    
    deinit {
        selectedSiswa = nil
        foto = nil
        fotoData = nil
        scrollView = nil
        imageView = nil
        stackView = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
#if DEBUG
        print("deinit PratinjauFoto")
#endif
    }
}
