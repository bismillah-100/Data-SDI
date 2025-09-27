//
//  DragImageUtility.swift
//  Data SDI
//
//  Created by MacBook on 27/09/25.
//

import Foundation

/// Struktur ini menyimpan semua informasi yang diperlukan untuk membuat komponen drag-and-drop,
/// termasuk gambar, frame posisi, dan kunci identifikasi komponen.
struct DragComponentConfig {
    /// Gambar yang akan ditampilkan dalam komponen drag.
    let image: NSImage
    /// Frame posisi dan ukuran komponen dalam koordinat drag view.
    let frame: NSRect
    /// Kunci identifikasi jenis komponen drag (misalnya `.icon` atau `.label`).
    let key: NSDraggingItem.ImageComponentKey
}

/// Kelas utilitas untuk menangani perhitungan frame gambar dan komponen drag-and-drop.
///
/// `DragImageUtility` menyediakan fungsi-fungsi statis untuk membantu dalam:
/// - Perhitungan frame gambar yang tepat berdasarkan constraint
/// - Konfigurasi komponen drag-and-drop untuk table view
/// - Pembuatan gambar teks untuk tampilan drag
///
/// ## Penggunaan Utama
///
/// Kelas ini digunakan untuk mengatur tampilan drag-and-drop dalam aplikasi macOS,
/// khususnya untuk table view yang menampilkan data dengan gambar dan teks.
///
/// ```swift
/// // Menghitung frame gambar
/// let frame = DragImageUtility.calculateImageFrameInView(image: myImage, imageView: myImageView)
///
/// // Membuat gambar teks
/// let textImage = DragImageUtility.createTextImage(for: "Nama Item")
/// ```
class DragImageUtility {
    // MARK: - Constants

    /// Jarak default antar komponen dalam layout drag-and-drop.
    ///
    /// Digunakan untuk memberikan spacing yang konsisten antara gambar dan teks
    /// dalam komponen drag. Nilai ini optimal untuk memberikan visual yang tidak terlalu rapat.
    ///
    /// ```swift
    /// let spacing = DragImageUtility.defaultGap // 4.0
    /// ```
    static let defaultGap: CGFloat = 4.0

    /// Padding default horizontal untuk teks dalam background.
    ///
    /// Memberikan ruang kosong di kiri dan kanan teks dalam background rounded rectangle.
    /// Memastikan teks tidak menempel langsung dengan tepi background.
    ///
    /// ```swift
    /// let textPadding = DragImageUtility.defaultPadding // 3.0
    /// ```
    static let defaultPadding: CGFloat = 3.0

    /// Tinggi default untuk background teks dalam komponen drag.
    ///
    /// Memberikan tinggi yang konsisten untuk semua komponen teks drag,
    /// menciptakan tampilan yang seragam dan profesional.
    ///
    /// ```swift
    /// let backgroundHeight = DragImageUtility.defaultBackgroundHeight // 20.0
    /// ```
    static let defaultBackgroundHeight: CGFloat = 20.0

    /// Ukuran font default untuk teks dalam komponen drag.
    ///
    /// Dipilih untuk memberikan keterbacaan yang optimal pada ukuran komponen drag
    /// yang relatif kecil, sesuai dengan standar macOS.
    ///
    /// ```swift
    /// let fontSize = DragImageUtility.defaultTextFontSize // 13.0
    /// ```
    static let defaultTextFontSize: CGFloat = 13.0

    /// Lebar maksimum default untuk gambar dalam komponen drag.
    ///
    /// Membatasi ukuran gambar agar tidak terlalu dominan dalam layout drag.
    /// Dapat di-override melalui parameter fungsi jika diperlukan ukuran yang berbeda.
    ///
    /// ```swift
    /// let maxWidth = DragImageUtility.defaultMaxWidth // 20.0
    /// ```
    static let defaultMaxWidth: CGFloat = 20.0

    // MARK: - Frame Calculations

    /// Menghitung frame gambar yang tepat berdasarkan constraint dari NSImageView.
    ///
    /// Fungsi ini akan menghitung ukuran dan posisi gambar yang sesuai dengan aspect ratio asli
    /// gambar sambil memastikan gambar pas di dalam bounds dari NSImageView dengan positioning yang tepat.
    ///
    /// - Parameters:
    ///   - image: Gambar NSImage yang akan dihitung frame-nya. Digunakan untuk mendapatkan ukuran asli dan aspect ratio. Harus valid dengan width dan height > 0.
    ///   - imageView: NSImageView yang menjadi container. Frame dan ukurannya digunakan sebagai constraint untuk perhitungan positioning.
    ///
    /// - Returns: NSRect yang merepresentasikan frame gambar yang sudah disesuaikan dengan aspect ratio dan di-center dalam imageView.
    ///
    /// ## Cara Kerja
    ///
    /// 1. **Validasi Input**: Memeriksa apakah gambar memiliki dimensi yang valid
    /// 2. **Perhitungan Aspect Ratio**: Membandingkan ratio gambar dengan container
    /// 3. **Scaling**: Menentukan faktor scaling berdasarkan constraint terkecil
    /// 4. **Positioning**: Menempatkan gambar di center dari imageView
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let myImage = NSImage(named: "icon")!
    /// let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
    ///
    /// let calculatedFrame = DragImageUtility.calculateImageFrameInView(
    ///     image: myImage,
    ///     imageView: imageView
    /// )
    ///
    /// print("Image will be displayed at: \(calculatedFrame)")
    /// // Output: Image akan ditempatkan di center dengan ukuran yang proportional
    /// ```
    ///
    /// - Note: Jika gambar tidak valid (width atau height = 0), fungsi akan mengembalikan frame imageView secara utuh.
    /// - Important: Pastikan image yang dipass memiliki dimensi yang valid untuk hasil yang akurat.
    static func calculateImageFrameInView(image: NSImage, imageView: NSImageView) -> NSRect {
        let imageViewFrame = imageView.frame
        let imageSize = image.size

        guard imageSize.width > 0, imageSize.height > 0 else {
            return imageViewFrame
        }

        let scaledSize = calculateScaledSize(
            imageSize: imageSize,
            containerSize: imageViewFrame.size
        )

        return centerRect(
            size: scaledSize,
            in: imageViewFrame
        )
    }

    /// Menghitung ukuran scaled dengan mempertahankan aspect ratio.
    ///
    /// Fungsi internal untuk menentukan ukuran akhir gambar yang akan ditampilkan
    /// dengan memastikan aspect ratio tetap terjaga dan gambar fit dalam container.
    ///
    /// - Parameters:
    ///   - imageSize: NSSize ukuran asli gambar yang akan di-scale. Digunakan untuk menghitung aspect ratio.
    ///   - containerSize: NSSize ukuran container yang menjadi batasan. Menentukan batas maksimum scaling.
    ///
    /// - Returns: NSSize ukuran gambar setelah di-scale dengan aspect ratio yang terjaga.
    ///
    /// ## Algoritma Scaling
    ///
    /// - **Landscape Image** (ratio > container): Scale berdasarkan width container
    /// - **Portrait Image** (ratio < container): Scale berdasarkan height container
    /// - **Same Ratio**: Gambar akan fit perfectly
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let originalSize = NSSize(width: 400, height: 300) // 4:3 ratio
    /// let containerSize = NSSize(width: 100, height: 100) // Square container
    ///
    /// let scaledSize = DragImageUtility.calculateScaledSize(
    ///     imageSize: originalSize,
    ///     containerSize: containerSize
    /// )
    ///
    /// print(scaledSize) // NSSize(width: 100, height: 75) - fit by width
    /// ```
    static func calculateScaledSize(imageSize: NSSize, containerSize: NSSize) -> NSSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            // Image lebih landscape - fit berdasarkan width
            return NSSize(
                width: containerSize.width,
                height: containerSize.width / imageAspectRatio
            )
        } else {
            // Image lebih portrait - fit berdasarkan height
            return NSSize(
                width: containerSize.height * imageAspectRatio,
                height: containerSize.height
            )
        }
    }

    /// Menempatkan rect di center dari container rect.
    ///
    /// Utility function untuk positioning yang menghitung posisi x,y agar
    /// rect dengan ukuran tertentu berada tepat di tengah container.
    ///
    /// - Parameters:
    ///   - size: NSSize ukuran rect yang akan di-center. Menentukan dimensi object yang akan diposisikan.
    ///   - containerRect: NSRect container tempat object akan ditempatkan. Origin dan size-nya digunakan untuk perhitungan center.
    ///
    /// - Returns: NSRect dengan posisi yang sudah di-center dalam container.
    ///
    /// ## Formula Centering
    ///
    /// ```
    /// centerX = containerX + (containerWidth - objectWidth) / 2
    /// centerY = containerY + (containerHeight - objectHeight) / 2
    /// ```
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let objectSize = NSSize(width: 50, height: 30)
    /// let container = NSRect(x: 10, y: 10, width: 100, height: 80)
    ///
    /// let centeredRect = DragImageUtility.centerRect(size: objectSize, in: container)
    /// print(centeredRect) // NSRect(x: 35, y: 35, width: 50, height: 30)
    /// ```
    static func centerRect(size: NSSize, in containerRect: NSRect) -> NSRect {
        let x = containerRect.origin.x + (containerRect.width - size.width) / 2
        let y = containerRect.origin.y + (containerRect.height - size.height) / 2
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Drag Configuration

    /// Mengkonfigurasi komponen drag berdasarkan konten yang tersedia dalam cell.
    ///
    /// Fungsi ini adalah dispatcher utama yang akan memilih metode konfigurasi yang tepat
    /// berdasarkan komponen yang tersedia dalam cell (gambar dari imageView, pasteboard, atau hanya teks).
    ///
    /// - Parameters:
    ///   - dragItem: NSDraggingItem yang akan dikonfigurasi. Target utama untuk pengaturan komponen drag.
    ///   - cell: NSTableCellView yang berisi komponen UI. Sumber data untuk imageView dan textField.
    ///   - textImage: NSImage yang berisi rendering teks. Gambar teks yang sudah di-render sebelumnya.
    ///   - pasteboardItem: NSPasteboardItem yang mungkin berisi data gambar. Sumber alternatif untuk gambar jika imageView kosong.
    ///   - rowHeight: CGFloat tinggi baris table. Digunakan untuk perhitungan layout vertikal semua komponen.
    ///
    /// ## Logika Pemilihan Konfigurasi
    ///
    /// Fungsi ini menggunakan prioritas bertingkat untuk menentukan konfigurasi drag yang optimal:
    ///
    /// 1. **Prioritas 1**: Jika cell memiliki imageView → Gunakan gambar dari cell
    /// 2. **Prioritas 2**: Jika ada data gambar di pasteboard → Gunakan gambar dari pasteboard dengan resize
    /// 3. **Selalu**: Tambahkan komponen teks untuk setiap drag operation
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// // Dalam table view delegate
    /// func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
    ///     let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
    ///     let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    ///     let textImage = DragImageUtility.createTextImage(for: "Item Name")
    ///
    ///     DragImageUtility.configureDragComponents(
    ///         for: dragItem,
    ///         cell: cell,
    ///         textImage: textImage,
    ///         pasteboardItem: pasteboardItem,
    ///         rowHeight: tableView.rowHeight
    ///     )
    ///
    ///     return dragItem
    /// }
    /// ```
    ///
    /// - Returns: Void. Fungsi ini mengmodifikasi dragItem secara langsung melalui imageComponentsProvider.
    /// - Note: Fungsi ini akan selalu menambahkan komponen teks, namun komponen gambar bersifat opsional.
    /// - Important: Pastikan textField tersedia di dalam cell sebelum memanggil fungsi ini.
    static func configureDragComponents(
        for dragItem: NSDraggingItem,
        cell: NSTableCellView,
        textImage: NSImage,
        pasteboardItem: NSPasteboardItem,
        rowHeight: CGFloat
    ) {
        guard let textField = cell.textField else { return }

        var components: [DragComponentConfig] = []

        // Tambahkan komponen gambar jika tersedia
        if let imageComponent = createImageComponent(
            from: cell,
            pasteboardItem: pasteboardItem,
            textField: textField,
            rowHeight: rowHeight
        ) {
            components.append(imageComponent)
        }

        // Tambahkan komponen teks
        let textComponent = createTextComponent(
            textImage: textImage,
            textField: textField,
            rowHeight: rowHeight
        )
        components.append(textComponent)

        // Konfigurasikan drag item
        configureDragItem(dragItem, with: components)
    }

    /// Membuat komponen gambar dari cell atau pasteboard dengan prioritas bertingkat.
    ///
    /// Fungsi ini akan mencoba membuat komponen gambar dengan urutan prioritas:
    /// cell imageView terlebih dahulu, kemudian pasteboard sebagai fallback.
    ///
    /// - Parameters:
    ///   - cell: NSTableCellView yang mungkin memiliki imageView. Sumber prioritas utama untuk gambar.
    ///   - pasteboardItem: NSPasteboardItem yang mungkin berisi data TIFF. Sumber fallback untuk gambar.
    ///   - textField: NSTextField untuk referensi positioning. Digunakan untuk menghitung posisi gambar relatif terhadap teks.
    ///   - rowHeight: CGFloat tinggi baris untuk constraint vertikal. Memastikan gambar tidak melebihi tinggi row.
    ///
    /// - Returns: DragComponentConfig optional yang berisi konfigurasi gambar, atau nil jika tidak ada gambar yang tersedia.
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
    /// let pasteboardItem = NSPasteboardItem()
    ///
    /// if let imageComponent = DragImageUtility.createImageComponent(
    ///     from: cell,
    ///     pasteboardItem: pasteboardItem,
    ///     textField: cell.textField!,
    ///     rowHeight: 25.0
    /// ) {
    ///     print("Image component created: \(imageComponent.frame)")
    /// }
    /// ```
    ///
    /// - Note: Fungsi akan return nil jika tidak ada sumber gambar yang valid.
    /// - Important: textField harus valid untuk perhitungan positioning yang akurat.
    static func createImageComponent(
        from cell: NSTableCellView,
        pasteboardItem: NSPasteboardItem,
        textField: NSTextField,
        rowHeight: CGFloat
    ) -> DragComponentConfig? {
        // Prioritas 1: Gambar dari imageView cell
        if let imageView = cell.imageView,
           let cellImage = imageView.image
        {
            let frame = imageView.calculateImageFrame(for: cellImage)
            return DragComponentConfig(
                image: cellImage,
                frame: frame,
                key: .icon
            )
        }

        // Prioritas 2: Gambar dari pasteboard
        if let imageData = pasteboardItem.data(forType: .tiff),
           let pasteboardImage = NSImage(data: imageData)
        {
            return createPasteboardImageComponent(
                image: pasteboardImage,
                textField: textField,
                rowHeight: rowHeight
            )
        }

        return nil
    }

    /// Membuat komponen gambar dari pasteboard dengan resize otomatis.
    ///
    /// Fungsi khusus untuk memproses gambar dari pasteboard yang biasanya memiliki
    /// ukuran yang tidak sesuai untuk komponen drag. Akan melakukan resize dan positioning.
    ///
    /// - Parameters:
    ///   - image: NSImage dari pasteboard yang akan diproses. Gambar asli yang mungkin berukuran besar.
    ///   - textField: NSTextField untuk referensi positioning horizontal. Gambar akan ditempatkan di sebelah kiri textField.
    ///   - rowHeight: CGFloat tinggi baris sebagai constraint maksimum. Gambar tidak akan melebihi tinggi ini.
    ///
    /// - Returns: DragComponentConfig optional dengan gambar yang sudah di-resize dan diposisikan, atau nil jika resize gagal.
    ///
    /// ## Proses Resize
    ///
    /// 1. **Calculate Constraint**: Tentukan ukuran maksimum berdasarkan rowHeight
    /// 2. **Maintain Aspect Ratio**: Resize dengan mempertahankan proportions
    /// 3. **Position Calculation**: Tempatkan di sebelah kiri textField dengan gap
    /// 4. **Vertical Centering**: Center secara vertikal dalam row
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let largeImage = NSImage(data: pasteboardData)! // 1000x800 pixels
    /// let textField = NSTextField(frame: NSRect(x: 50, y: 0, width: 100, height: 20))
    ///
    /// if let component = DragImageUtility.createPasteboardImageComponent(
    ///     image: largeImage,
    ///     textField: textField,
    ///     rowHeight: 25.0
    /// ) {
    ///     print("Resized image: \(component.image.size)") // Much smaller, proportional
    ///     print("Positioned at: \(component.frame)")      // Left of textField
    /// }
    /// ```
    ///
    /// - Note: Menggunakan ReusableFunc.resizeImage untuk actual resizing operation.
    /// - Important: Jika resize gagal, function akan return nil.
    static func createPasteboardImageComponent(
        image: NSImage,
        textField: NSTextField,
        rowHeight: CGFloat
    ) -> DragComponentConfig? {
        let constrainedSize = calculateAspectRatioSize(
            originalSize: image.size,
            maxHeight: rowHeight
        )

        guard let resizedImage = ReusableFunc.resizeImage(
            image: image,
            to: constrainedSize
        ) else {
            return nil
        }

        let frame = NSRect(
            x: textField.frame.origin.x - constrainedSize.width - defaultGap,
            y: (rowHeight - constrainedSize.height) / 2,
            width: constrainedSize.width,
            height: constrainedSize.height
        )

        return DragComponentConfig(
            image: resizedImage,
            frame: frame,
            key: .icon
        )
    }

    /// Membuat komponen teks untuk drag operation.
    ///
    /// Fungsi yang mengonfigurasi komponen teks yang akan ditampilkan dalam drag operation.
    /// Komponen ini selalu dibuat untuk setiap drag operation sebagai label identifier.
    ///
    /// - Parameters:
    ///   - textImage: NSImage yang berisi rendered text dengan background. Gambar teks yang sudah di-style.
    ///   - textField: NSTextField sebagai referensi positioning. Komponen teks akan diposisikan berdasarkan lokasi textField.
    ///   - rowHeight: CGFloat tinggi baris untuk centering vertikal. Memastikan teks berada di center row.
    ///
    /// - Returns: DragComponentConfig yang berisi konfigurasi lengkap untuk komponen teks.
    ///
    /// ## Positioning Logic
    ///
    /// - **Horizontal**: Sedikit offset dari textField (x - 1) untuk alignment yang presisi
    /// - **Vertical**: Di-center dalam rowHeight untuk konsistensi visual
    /// - **Size**: Menggunakan ukuran natural dari textImage
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let textImage = DragImageUtility.createTextImage(for: "Document Name")!
    /// let textField = NSTextField(frame: NSRect(x: 50, y: 5, width: 200, height: 15))
    ///
    /// let textComponent = DragImageUtility.createTextComponent(
    ///     textImage: textImage,
    ///     textField: textField,
    ///     rowHeight: 25.0
    /// )
    ///
    /// print("Text component frame: \(textComponent.frame)")
    /// print("Text component key: \(textComponent.key)") // .label
    /// ```
    ///
    /// - Note: Komponen teks menggunakan key .label untuk identifikasi dalam drag system.
    /// - Important: textImage harus sudah di-render sebelumnya dengan style yang diinginkan.
    static func createTextComponent(
        textImage: NSImage,
        textField: NSTextField,
        rowHeight: CGFloat
    ) -> DragComponentConfig {
        let textY = (rowHeight - textImage.size.height) / 2
        let frame = NSRect(
            x: textField.frame.origin.x - 1,
            y: textY,
            width: textImage.size.width,
            height: textImage.size.height
        )

        return DragComponentConfig(
            image: textImage,
            frame: frame,
            key: .label
        )
    }

    /// Mengkonfigurasi drag item dengan komponen yang diberikan.
    ///
    /// Fungsi akhir dalam pipeline konfigurasi drag yang mengapply semua komponen
    /// ke NSDraggingItem melalui imageComponentsProvider.
    ///
    /// - Parameters:
    ///   - dragItem: NSDraggingItem yang akan dikonfigurasi. Target object yang akan menerima komponen visual.
    ///   - configs: Array DragComponentConfig berisi konfigurasi semua komponen. Daftar komponen yang akan ditampilkan saat drag.
    ///
    /// ## Cara Kerja
    ///
    /// 1. **Set Provider**: Mengatur imageComponentsProvider pada dragItem
    /// 2. **Convert Configs**: Mengubah DragComponentConfig menjadi NSDraggingImageComponent
    /// 3. **Apply Properties**: Mengatur contents, frame, dan key untuk setiap komponen
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    /// let configs = [imageConfig, textConfig] // Array of DragComponentConfig
    ///
    /// DragImageUtility.configureDragItem(dragItem, with: configs)
    ///
    /// // dragItem sekarang memiliki visual components untuk drag operation
    /// ```
    ///
    /// - Note: Function ini menggunakan closure-based provider untuk lazy evaluation.
    /// - Important: Setiap config dalam array harus memiliki image, frame, dan key yang valid.
    static func configureDragItem(
        _ dragItem: NSDraggingItem,
        with configs: [DragComponentConfig]
    ) {
        dragItem.imageComponentsProvider = {
            configs.map { config in
                let component = NSDraggingImageComponent(key: config.key)
                component.contents = config.image
                component.frame = config.frame
                return component
            }
        }
    }

    // MARK: - Image Creation

    /// Membuat gambar teks dengan background rounded untuk tampilan drag.
    ///
    /// Fungsi ini akan membuat NSImage yang berisi teks dengan background berwarna dan berbentuk pill
    /// (rounded rectangle). Gambar ini biasanya digunakan sebagai komponen teks dalam drag operation.
    ///
    /// - Parameter text: String yang akan dirender menjadi gambar teks. Nama atau label yang ingin ditampilkan dalam drag component.
    ///
    /// - Returns: NSImage optional yang berisi teks dengan background styled, atau nil jika terjadi kesalahan dalam pembuatan gambar.
    ///
    /// ## Karakteristik Gambar yang Dihasilkan
    ///
    /// - **Font**: System font ukuran 13pt untuk keterbacaan optimal
    /// - **Background**: selectedContentBackgroundColor dengan bentuk pill untuk tampilan modern
    /// - **Height**: Fixed 20pt untuk konsistensi visual
    /// - **Padding**: 3pt horizontal padding di kiri dan kanan teks
    /// - **Text Color**: Putih untuk kontras maksimal dengan background
    /// - **Shape**: Rounded rectangle dengan corner radius setengah dari height
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// // Membuat gambar teks untuk nama file
    /// if let textImage = DragImageUtility.createTextImage(for: "My Document.pdf") {
    ///     print("Text image size: \(textImage.size)")
    ///     // Gambar siap digunakan dalam drag component
    /// }
    ///
    /// // Untuk teks yang panjang
    /// let longTextImage = DragImageUtility.createTextImage(for: "Very Long Document Name.docx")
    /// // Background akan menyesuaikan lebar teks secara otomatis
    ///
    /// // Untuk teks kosong atau nil handling
    /// let emptyImage = DragImageUtility.createTextImage(for: "")
    /// // Tetap akan membuat gambar dengan background minimal
    /// ```
    ///
    /// ## Proses Rendering
    ///
    /// 1. **Text Measurement**: Mengukur dimensi teks dengan font yang dipilih
    /// 2. **Size Calculation**: Menghitung ukuran total gambar termasuk padding
    /// 3. **Background Drawing**: Menggambar rounded rectangle sebagai background
    /// 4. **Text Drawing**: Menempatkan teks di center background dengan warna kontras
    ///
    /// - Note: Gambar dihasilkan dengan flipped: false untuk koordinat macOS yang benar.
    /// - Important: Return nil hanya jika terjadi error dalam pembuatan NSImage, bukan karena input kosong.
    static func createTextImage(for text: String) -> NSImage? {
        let font = NSFont.systemFont(ofSize: defaultTextFontSize)
        let textSize = calculateTextSize(for: text, font: font)
        let imageSize = calculateTextImageSize(textSize: textSize)
        let backgroundSize = NSSize(width: imageSize.width + 4, height: defaultBackgroundHeight)
        let image = NSImage(size: backgroundSize, flipped: false) { _ in
            drawTextImageContent(
                text: text,
                font: font,
                textSize: textSize,
                imageSize: imageSize,
                backgroundSize: backgroundSize
            )

            return true
        }
        return image
    }

    /// Menghitung ukuran teks dengan font yang ditentukan.
    ///
    /// Utility function untuk mengukur dimensi teks sebelum rendering,
    /// memungkinkan perhitungan ukuran gambar yang presisi.
    ///
    /// - Parameters:
    ///   - text: String yang akan diukur dimensinya. Teks yang akan di-render dalam gambar.
    ///   - font: NSFont yang akan digunakan untuk rendering. Menentukan style dan ukuran font.
    ///
    /// - Returns: NSSize yang merepresentasikan lebar dan tinggi teks dalam pixel.
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let font = NSFont.systemFont(ofSize: 13)
    /// let textSize = DragImageUtility.calculateTextSize(for: "Hello World", font: font)
    /// print("Text dimensions: \(textSize.width) x \(textSize.height)")
    /// ```
    ///
    /// - Note: Menggunakan NSAttributedString size calculation untuk akurasi maksimal.
    static func calculateTextSize(for text: String, font: NSFont) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return text.size(withAttributes: attributes)
    }

    /// Menghitung ukuran total gambar teks termasuk padding.
    ///
    /// Mengkonversi ukuran teks mentah menjadi ukuran gambar final yang sudah
    /// termasuk padding dan menyesuaikan dengan tinggi background yang konsisten.
    ///
    /// - Parameter textSize: NSSize ukuran teks mentah dari perhitungan sebelumnya. Dimensi teks tanpa padding.
    ///
    /// - Returns: NSSize ukuran total gambar yang akan dibuat, sudah termasuk semua padding.
    ///
    /// ## Contoh Penggunaan
    ///
    /// ```swift
    /// let textSize = NSSize(width: 80, height: 15)
    /// let imageSize = DragImageUtility.calculateTextImageSize(textSize: textSize)
    /// print("Final image size: \(imageSize)") // Width: 86 (80 + 6), Height: 20
    /// ```
    ///
    /// - Note: Height selalu menggunakan defaultBackgroundHeight untuk konsistensi.
    static func calculateTextImageSize(textSize: NSSize) -> NSSize {
        NSSize(
            width: textSize.width + 2 * defaultPadding,
            height: defaultBackgroundHeight
        )
    }

    /// Menggambar konten gambar teks (background + text)
    static func drawTextImageContent(
        text: String,
        font: NSFont,
        textSize: NSSize,
        imageSize: NSSize,
        backgroundSize: NSSize
    ) {
        // Draw background
        let bounds = NSRect(origin: .zero, size: backgroundSize)
        let cornerRadius = defaultBackgroundHeight / 2
        drawBackground(bounds: bounds, cornerRadius: cornerRadius)

        // Draw text
        drawCenteredText(
            text,
            font: font,
            textSize: textSize,
            imageSize: imageSize,
            backgroundHeight: defaultBackgroundHeight
        )
    }

    /**
     Menggambar background dengan bentuk rounded rectangle

     Fungsi ini akan menggambar background dengan warna `selectedContentBackgroundColor`
     dan sudut yang membulat sesuai dengan corner radius yang ditentukan.

     - Parameters:
        - bounds: Area persegi panjang tempat background akan digambar
        - cornerRadius: Radius sudut untuk membuat sudut yang membulat (dalam points)

     - Note:
        - Menggunakan `NSColor.selectedContentBackgroundColor` sebagai warna fill
        - Background akan mengisi seluruh area bounds yang diberikan

     - Example:
     ```swift
     let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
     DrawingUtilities.drawBackground(bounds: rect, cornerRadius: 10.0)
     ```
     */
    static func drawBackground(bounds: NSRect, cornerRadius: CGFloat) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.selectedContentBackgroundColor.setFill()
        path.fill()
    }

    // MARK: - Text Drawing

    /**
     Menggambar teks yang diposisikan di tengah-tengah area yang ditentukan

     Fungsi ini akan menghitung posisi yang tepat untuk menempatkan teks di tengah
     area gambar, dengan mempertimbangkan ukuran teks dan tinggi background.

     - Parameters:
        - text: String teks yang akan digambar
        - font: Font yang akan digunakan untuk menggambar teks
        - textSize: Ukuran actual dari teks (width dan height dalam NSSize)
        - imageSize: Ukuran total area gambar (width dan height dalam NSSize)
        - backgroundHeight: Tinggi area background tempat teks akan diposisikan

     - Note:
        - Teks akan digambar dengan warna putih (`NSColor.white`)
        - Posisi dihitung agar teks berada di center horizontal dan vertical
        - Menggunakan `withAttributes` untuk styling font dan warna

     - Example:
     ```swift
     let text = "Bismillah"
     let font = NSFont.systemFont(ofSize: 16)
     let textSize = text.size(withAttributes: [.font: font])
     let imageSize = NSSize(width: 300, height: 200)
     let backgroundHeight: CGFloat = 50

     DrawingUtilities.drawCenteredText(
         text,
         font: font,
         textSize: textSize,
         imageSize: imageSize,
         backgroundHeight: backgroundHeight
     )
     ```
     */
    static func drawCenteredText(
        _ text: String,
        font: NSFont,
        textSize: NSSize,
        imageSize: NSSize,
        backgroundHeight: CGFloat
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let position = NSPoint(
            x: (imageSize.width - textSize.width) / 2,
            y: (backgroundHeight - textSize.height) / 2
        )
        text.draw(at: position, withAttributes: attributes)
    }

    // MARK: - Size Calculation

    /**
     Menghitung ukuran baru dengan mempertahankan aspect ratio dalam batasan maksimum

     Fungsi ini sangat berguna untuk resize gambar atau elemen UI agar tetap proporsional
     sambil memastikan tidak melebihi batasan ukuran yang ditentukan. Prioritas utama
     adalah mempertahankan aspect ratio original.

     - Parameters:
        - originalSize: Ukuran asli yang ingin diresize (width dan height)
        - maxHeight: Tinggi maksimum yang diizinkan (constraint utama)
        - maxWidth: Lebar maksimum yang diizinkan (default: `defaultMaxWidth`)

     - Returns: NSSize baru yang sudah disesuaikan dengan constraint dan aspect ratio

     - Algorithm Flow:
        1. Hitung aspect ratio dari ukuran original
        2. Resize berdasarkan maxHeight constraint
        3. Cek apakah width hasil melebihi maxWidth, jika ya maka resize berdasarkan maxWidth
        4. Validasi ulang apakah height masih dalam batas
        5. Double check untuk memastikan semua constraint terpenuhi

     - Note:
        - Aspect ratio selalu dipertahankan
        - Hasil akhir akan selalu dalam batas maxWidth dan maxHeight
        - Jika original size sudah lebih kecil dari constraint, tetap akan dihitung ulang

     - Example:
     ```swift
     // Resize gambar landscape
     let originalSize = NSSize(width: 800, height: 600)
     let newSize = DrawingUtilities.calculateAspectRatioSize(
         originalSize: originalSize,
         maxHeight: 200,
         maxWidth: 300
     )
     // Result: NSSize(width: 266.67, height: 200)

     // Resize gambar portrait
     let portraitSize = NSSize(width: 400, height: 800)
     let newPortraitSize = DrawingUtilities.calculateAspectRatioSize(
         originalSize: portraitSize,
         maxHeight: 300,
         maxWidth: 200
     )
     // Result: NSSize(width: 150, height: 300)

     // Resize gambar sangat wide
     let wideSize = NSSize(width: 1600, height: 400)
     let newWideSize = DrawingUtilities.calculateAspectRatioSize(
         originalSize: wideSize,
         maxHeight: 200,
         maxWidth: 300
     )
     // Result: NSSize(width: 300, height: 75)
     ```
     */
    static func calculateAspectRatioSize(
        originalSize: NSSize,
        maxHeight: CGFloat,
        maxWidth: CGFloat = defaultMaxWidth
    ) -> NSSize {
        let aspectRatio = originalSize.width / originalSize.height

        // Hitung berdasarkan height constraint
        var newSize = NSSize(
            width: maxHeight * aspectRatio,
            height: maxHeight
        )

        // Adjust jika width melebihi constraint
        if newSize.width > maxWidth {
            newSize = NSSize(
                width: maxWidth,
                height: maxWidth / aspectRatio
            )
        }

        // Final validation untuk height
        if newSize.height > maxHeight {
            newSize = NSSize(
                width: maxHeight * aspectRatio,
                height: maxHeight
            )
            // Double check width lagi
            if newSize.width > maxWidth {
                newSize = NSSize(
                    width: maxWidth,
                    height: maxWidth / aspectRatio
                )
            }
        }

        return newSize
    }
}

// MARK: - NSImageView Extension

extension NSImageView {
    /// Menghitung frame gambar yang tepat berdasarkan scaling mode imageView.
    ///
    /// Method convenience yang memanggil `DragImageUtility.calculateImageFrameInView`
    /// dengan menggunakan self sebagai imageView parameter.
    ///
    /// - Parameter image: NSImage yang akan dihitung frame-nya dalam konteks imageView ini.
    /// - Returns: NSRect frame gambar yang sudah disesuaikan dengan imageView.
    ///
    /// ## Contoh Penggunaan
    /// ```swift
    /// let frame = myImageView.calculateImageFrame(for: myImage)
    /// print("Image frame: \(frame)")
    /// ```
    func calculateImageFrame(for image: NSImage) -> NSRect {
        DragImageUtility.calculateImageFrameInView(image: image, imageView: self)
    }
}
