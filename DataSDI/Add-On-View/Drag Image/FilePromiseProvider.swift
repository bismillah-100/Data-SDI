//
//  FilePromiseProvider.swift
//  Data SDI
//
//  Created by MacBook on 27/09/25.
//

import Foundation

/// `FilePromiseProvider` adalah subclass dari `NSFilePromiseProvider` yang mengelola penyediaan data
/// untuk operasi *drag-and-drop* atau *copy-paste*, khususnya untuk file gambar.
///
/// Kelas ini memungkinkan aplikasi untuk "menjanjikan" file, yang berarti data file tidak
/// langsung tersedia di *pasteboard* tetapi akan disediakan saat aplikasi penerima memintanya.
/// Ini sangat berguna untuk data berukuran besar seperti gambar, menghindari penyalinan data
/// yang tidak perlu sampai benar-benar dibutuhkan.
///
/// `FilePromiseProvider` ini dikonfigurasi untuk mendukung beberapa tipe data:
/// - `.tiff`: Untuk kompatibilitas dengan aplikasi seperti Notes atau pengolah gambar lainnya.
/// - `.fileURL`: Untuk menyediakan URL file yang dapat diunduh oleh aplikasi lain.
/// - `.png`: Untuk format gambar PNG.
/// - `.string`: Untuk menyediakan data tekstual, dalam kasus ini, nama siswa.
class FilePromiseProvider: NSFilePromiseProvider {
    /// Struktur `UserInfoKeys` mendefinisikan kunci-kunci untuk menyimpan informasi kustom
    /// dalam kamus `userInfo` dari `NSFilePromiseProvider`.
    enum UserInfoKeys {
        // Kunci untuk menyimpan nomor baris atau indeks terkait data yang dijanjikan.
        // static let rowNumberKey = "rowNumber"
        /// Kunci untuk menyimpan `URL` dari file yang dijanjikan.
        static let urlKey = "url"
        /// Kunci untuk menyimpan data gambar (`Data`) yang dijanjikan.
        static let imageKey = "image"
        /// Kunci untuk menyimpan nama siswa yang terkait dengan data.
        static let namaKey = "namaSiswa"
    }

    /// Mengembalikan daftar tipe *pasteboard* yang dapat ditulis oleh penyedia ini.
    ///
    /// Metode ini menambahkan tipe-tipe spesifik seperti `.tiff`, `.fileURL`, `.png`, dan `.string`
    /// ke dalam daftar tipe bawaan yang didukung oleh `NSFilePromiseProvider` standar.
    /// Ini memungkinkan aplikasi penerima untuk mengetahui format data apa saja yang bisa diharapkan.
    ///
    /// - Parameter pasteboard: `NSPasteboard` yang sedang digunakan.
    /// - Returns: Array `[NSPasteboard.PasteboardType]` yang berisi semua tipe yang didukung.
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = super.writableTypes(for: pasteboard)
        types.append(.tiff) // Untuk support drag ke aplikasi seperti Notes
        types.append(.fileURL) // Untuk promise files ke aplikasi lain
        types.append(.png)
        types.append(.string)
        return types
    }

    /// Mengembalikan representasi data yang dijanjikan untuk tipe *pasteboard* yang diminta.
    ///
    /// Metode ini mengambil informasi dari kamus `userInfo` dan mengonversinya ke format yang sesuai
    /// berdasarkan `NSPasteboard.PasteboardType` yang diminta.
    ///
    /// - Parameter type: Tipe *pasteboard* yang diminta oleh aplikasi penerima.
    /// - Returns: Representasi data yang dijanjikan sebagai `Any?`, atau `nil` jika data tidak tersedia
    ///            untuk tipe yang diminta.
    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard let userInfoDict = userInfo as? [String: Any] else { return nil }

        switch type {
        case .fileURL:
            // Mengembalikan URL file jika tipe yang diminta adalah `.fileURL`.
            if let url = userInfoDict[UserInfoKeys.urlKey] as? NSURL {
                return url.pasteboardPropertyList(forType: type)
            }
        case .tiff:
            // Mengembalikan data gambar sebagai TIFF jika tipe yang diminta adalah `.tiff`.
            if let imageData = userInfoDict[UserInfoKeys.imageKey] as? Data {
                return imageData
            }
        case .string:
            // Mengembalikan nama siswa sebagai string jika tipe yang diminta adalah `.string`.
            if let namaSiswa = userInfoDict[UserInfoKeys.namaKey] as? String {
                return namaSiswa
            }
        default:
            break
        }

        // Memanggil implementasi superclass untuk tipe-tipe lain yang tidak ditangani secara kustom.
        return super.pasteboardPropertyList(forType: type)
    }

    /// Mengembalikan opsi penulisan untuk tipe *pasteboard* yang ditentukan.
    ///
    /// Metode ini dapat digunakan untuk mengonfigurasi opsi tambahan saat data ditulis ke *pasteboard*,
    /// meskipun dalam implementasi saat ini, ia hanya memanggil implementasi superclass.
    ///
    /// - Parameters:
    ///   - type: Tipe *pasteboard* yang akan ditulis.
    ///   - pasteboard: `NSPasteboard` yang sedang digunakan.
    /// - Returns: `NSPasteboard.WritingOptions` untuk tipe yang ditentukan.
    override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard)
        -> NSPasteboard.WritingOptions
    {
        super.writingOptions(forType: type, pasteboard: pasteboard)
    }

    // MARK: - Validate image from url

    /// Fungsi untuk melakukan validasi terhadap item yang di drag.
    ///
    /// Fungsi ini memeriksa `url` item yang didrag dan memastikan `url`
    /// tidak kosong dan setidaknya ada satu item yang memuat gambar.
    /// Jika kondisi ini tidak memenuhi, fungsi ini akan langsung return `nil`.
    ///
    /// - Parameter info: NSDragging info ketika draggingSession.
    /// - Returns: Tuple yang berisi array `url` item yang didrag dan satu gambar dari item pertama
    /// yang didrag setelah dikonversi ke `NSImage`.
    static func validateImageForDrop(_ info: NSDraggingInfo) -> (fileURLs: [URL], image: NSImage)? {
        let pasteboard = info.draggingPasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !fileURLs.isEmpty
        else {
            return nil
        }

        // Drop bukan di .above → proses file pertama saja
        guard let imageURL = fileURLs.first,
              let image = NSImage(contentsOf: imageURL)
        else {
            return nil
        }

        return (fileURLs, image)
    }

    // MARK: - Reusable Dragging Session Configuration

    /// Mengkonfigurasi dragging session untuk table view dengan pengaturan komponen visual drag.
    ///
    /// Fungsi ini bertanggung jawab untuk mengatur tampilan visual dari drag operation yang dimulai
    /// dari table view. Akan mengiterasi setiap item yang di-drag dan mengkonfigurasi komponen
    /// visualnya (gambar dan teks) berdasarkan data yang tersedia.
    ///
    /// - Parameters:
    ///   - tableView: NSTableView yang menjadi sumber drag operation. Digunakan untuk mengambil cell view dan properti layout.
    ///   - session: NSDraggingSession yang sedang aktif. Session ini berisi drag items yang akan dikonfigurasi.
    ///   - point: NSPoint lokasi awal drag dalam koordinat table view. Parameter ini diterima untuk kompatibilitas API tetapi tidak digunakan.
    ///   - rowIndexes: IndexSet yang berisi indeks baris yang sedang di-drag. Digunakan untuk mapping antara drag item dan baris aktual.
    ///   - columnIndex: Int indeks kolom tempat drag dimulai. Digunakan untuk mengambil cell view yang tepat.
    ///
    /// ## Proses Konfigurasi
    ///
    /// 1. **Mapping Index**: Mengkonversi IndexSet ke Array untuk akses yang mudah
    /// 2. **Iterasi Drag Items**: Menggunakan `enumerateDraggingItems` untuk setiap item
    /// 3. **Validasi Data**: Memastikan pasteboard item dan data nama tersedia
    /// 4. **Text Image Creation**: Membuat gambar teks dengan background rounded
    /// 5. **Cell Retrieval**: Mengambil cell view untuk informasi layout
    /// 6. **Component Configuration**: Mengatur komponen visual berdasarkan konten cell
    ///
    /// ## Error Handling
    ///
    /// Fungsi ini memiliki multiple guard statements untuk menangani berbagai kemungkinan error:
    /// - Index out of bounds pada rowIndexes
    /// - Pasteboard item tidak valid
    /// - Data nama tidak tersedia di pasteboard
    /// - Gagal membuat text image
    /// - Cell view tidak dapat diakses
    ///
    /// ## Debug Information
    ///
    /// Dalam mode DEBUG, fungsi akan mencetak pesan error yang informatif untuk membantu debugging
    /// masalah konfigurasi drag session.
    ///
    /// - Important: Fungsi menggunakan `actualRowIndex` dari `rowIndexArray[idx]` bukan `idx` langsung
    ///   dari `enumerateDraggingItems` untuk memastikan mapping yang benar antara drag item dan baris table.
    static func configureDraggingSession(
        _ tableView: NSTableView,
        session: NSDraggingSession,
        willBeginAt _: NSPoint,
        forRowIndexes rowIndexes: IndexSet,
        columnIndex: Int
    ) {
        let rowIndexArray = Array(rowIndexes)

        session.enumerateDraggingItems(options: [],
                                       for: tableView,
                                       classes: [NSPasteboardItem.self],
                                       searchOptions: [:])
        { dragItem, idx, _ in
            // Gunakan rowIndexes yang diteruskan, bukan idx dari enumerateDraggingItems
            guard idx < rowIndexArray.count else {
                return
            }

            let actualRowIndex = rowIndexArray[idx]

            guard let pasteboardItem = dragItem.item as? NSPasteboardItem else {
                #if DEBUG
                    print("Error: Tidak dapat mengakses pasteboard item")
                #endif
                return
            }

            // Ambil nama dari pasteboard
            guard let nama = pasteboardItem.string(forType: NSPasteboard.PasteboardType.string) else {
                #if DEBUG
                    print("Error: Tidak ada nama di pasteboardItem")
                #endif
                return
            }

            // Buat text image dengan rounded background
            guard let textImage = DragImageUtility.createTextImage(for: nama) else {
                #if DEBUG
                    print("Error: Gagal membuat textImage")
                #endif
                return
            }

            // Ambil cell untuk mendapatkan informasi layout
            guard let cell = tableView.view(
                atColumn: columnIndex,
                row: actualRowIndex,
                makeIfNecessary: true
            ) as? NSTableCellView
            else { return }

            // Konfigurasi drag components berdasarkan cell content
            DragImageUtility.configureDragComponents(
                for: dragItem,
                cell: cell,
                textImage: textImage,
                pasteboardItem: pasteboardItem,
                rowHeight: tableView.rowHeight
            )
        }
    }
}
