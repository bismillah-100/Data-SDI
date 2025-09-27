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
        let customQueue = DispatchQueue(label: "sdi.Data-SDI.pasteboardWriterQueue", qos: .userInteractive, attributes: .concurrent)

        // Buat semaphore untuk menunggu operasi selesai
        let group = DispatchGroup()

        // Konversi posisi mouse ke koordinat cell
        if tableView.selectedRowIndexes.contains(row) {
            // Buat file promise provider dengan userInfo yang lengkap
            let provider = FilePromiseProvider(
                fileType: UTType.data.identifier,
                delegate: self
            )

            customQueue.async { [weak self] in
                guard let self else { return }
                group.enter()
                guard let (_, nama, foto) = viewModel.getIdNamaFoto(row: row) else { return }
                // Set data pada userInfo
                provider.userInfo = [
                    FilePromiseProvider.UserInfoKeys.imageKey: foto as Any,
                    FilePromiseProvider.UserInfoKeys.namaKey: nama as Any,
                ]
                group.leave()
            }
            return provider
        }

        let locationInCell = cellView.convert(locationInView, from: tableView)

        // Hitung lebar teks sebenarnya
        let text = textField.stringValue
        let font = textField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)

        // Pastikan mouse berada dalam area teks, bukan di area kosong textfield
        guard locationInCell.x <= textSize.width + 8 else { return nil }

        // Buat file promise provider dengan userInfo yang lengkap
        let provider = FilePromiseProvider(
            fileType: UTType.data.identifier,
            delegate: self
        )

        // Siapkan data foto untuk setiap item yang didrag.
        customQueue.async { [weak self] in
            guard let self else { return }
            group.enter()
            // Ambil info siswa (pindah ke ViewModel)
            guard let (_, nama, foto) = viewModel.getIdNamaFoto(row: row) else { return }
            // Send over the row number and photo's url dictionary.
            provider.userInfo = [FilePromiseProvider.UserInfoKeys.imageKey: foto,
                                 FilePromiseProvider.UserInfoKeys.namaKey: nama as Any]
            group.leave()
        }

        return provider
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType _: String) -> String {
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
}
