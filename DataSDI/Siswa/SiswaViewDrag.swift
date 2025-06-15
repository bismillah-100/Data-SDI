//
//  SiswaViewDrag.swift
//  Data SDI
//
//  Created by Bismillah on 27/10/24.
//

import Cocoa
import UniformTypeIdentifiers

extension SiswaViewController: NSFilePromiseProviderDelegate {

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let mouseLocation = tableView.window?.mouseLocationOutsideOfEventStream ?? .zero
        let locationInView = tableView.convert(mouseLocation, from: nil)

        // Dapatkan kolom di posisi mouse
        let column = tableView.column(at: locationInView)

        guard column == 0 else { return nil }

        // Dapatkan cell view
        guard let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cellView.textField else { return nil }
        // Buat DispatchQueue dengan label khusus
        let customQueue = DispatchQueue(label: "sdi.Data-SDI.pasteboardWriterQueue", qos: .userInteractive)

        // Buat semaphore untuk menunggu operasi selesai
        let semaphore = DispatchSemaphore(value: 0)

        // Konversi posisi mouse ke koordinat cell
        if tableView.selectedRowIndexes.contains(row) {
            // Buat file promise provider dengan userInfo yang lengkap
            let provider = FilePromiseProvider(
                fileType: UTType.data.identifier,
                delegate: self
            )

            customQueue.async { [weak self] in
                guard let self else { return }
                let id: Int64
                let nama: String

                if self.currentTableViewMode == .plain {
                    id = self.viewModel.filteredSiswaData[row].id
                    nama = self.viewModel.filteredSiswaData[row].nama
                } else {
                    id = self.viewModel.getSiswaIdInGroupedMode(row: row)
                    nama = self.dbController.getSiswa(idValue: id).nama
                }

                let foto = self.dbController.bacaFotoSiswa(idValue: id).foto

                // Set data pada userInfo
                provider.userInfo = [
                    FilePromiseProvider.UserInfoKeys.imageKey: foto as Any,
                    FilePromiseProvider.UserInfoKeys.namaKey: nama as Any,
                ]
                semaphore.signal()
            }
            semaphore.wait()
            return provider
        }

        let locationInCell = cellView.convert(locationInView, from: tableView)

        // Hitung lebar teks sebenarnya
        let text = textField.stringValue
        let font = textField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)

        // Pastikan mouse berada dalam area teks, bukan di area kosong textfield
        guard locationInCell.x <= textSize.width else { return nil }

        // Buat file promise provider dengan userInfo yang lengkap
        let provider = FilePromiseProvider(
            fileType: UTType.data.identifier,
            delegate: self
        )

        // Buat semaphore untuk menunggu operasi selesai
        // Siapkan data foto untuk setiap item yang didrag.
        customQueue.async { [weak self] in
            guard let self else { return }
            let id: Int64
            let nama: String
            if self.currentTableViewMode == .plain {
                id = self.viewModel.filteredSiswaData[row].id
                nama = self.viewModel.filteredSiswaData[row].nama
            } else {
                id = self.viewModel.getSiswaIdInGroupedMode(row: row)
                nama = self.dbController.getNamaSiswa(idValue: id)
            }

            let foto = self.dbController.bacaFotoSiswa(idValue: id).foto

            // Send over the row number and photo's url dictionary.
            provider.userInfo = [FilePromiseProvider.UserInfoKeys.imageKey: foto,
                                 FilePromiseProvider.UserInfoKeys.namaKey: nama as Any]
            semaphore.signal()
        }
        semaphore.wait()
        return provider
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let nama = userInfoDict[FilePromiseProvider.UserInfoKeys.namaKey] as? String else { return "unknown.dat" }
        return nama.replacingOccurrences(of: "/", with: "-") + ".jpeg"
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let image = userInfoDict[FilePromiseProvider.UserInfoKeys.imageKey] as? Data
        else {
            completionHandler(NSError(domain: "", code: -1))
            return
        }
        // Ambil data gambar
        DispatchQueue.global(qos: .background).async {
            guard let fotoJpeg = NSImage(data: image)?.jpegRepresentation else {
                completionHandler(NSError(domain: "", code: -1))
                return
            }
            // Simpan ke file sementara
            do {
                try fotoJpeg.write(to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    /// Ini untuk membersihkan ketika drag dibatalkan
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                             didFailToWritePromiseTo url: URL,
                             error: Error) {}
    
}

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
        /// Kunci untuk menyimpan nomor baris atau indeks terkait data yang dijanjikan.
        static let rowNumberKey = "rowNumber"
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
}
