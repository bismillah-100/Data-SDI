//
//  InventoryDrop.swift
//  Data SDI
//
//  Created by MacBook on 09/08/25.
//

import Cocoa
import UniformTypeIdentifiers

// MARK: - Handle drop row table

extension InventoryView {
    /// Menangani penyisipan beberapa baris baru ke dalam tabel berdasarkan daftar URL file gambar yang diberikan. Fungsi ini akan memproses setiap URL, mengubah gambar menjadi data, dan kemudian memanggil handleInsertNewRow untuk menyisipkan setiap baris secara individual. Ini dirancang sebagai operasi asinkron untuk menghindari pemblokiran UI saat memproses beberapa file.
    ///
    /// - Parameters:
    ///    - startRow: Int yang menunjukkan indeks baris awal di mana penyisipan akan dimulai di NSTableView.
    ///    - fileURLs: Array URL yang berisi lokasi file gambar yang akan disisipkan sebagai baris baru.
    ///    - tableView: NSTableView tempat baris-baris baru akan disisipkan.
    /// - Returns: Bool true jika setidaknya satu baris berhasil disisipkan, false jika tidak ada baris yang berhasil disisipkan.
    func handleInsertNewRows(at startRow: Int, fileURLs: [URL], tableView: NSTableView) async -> Bool {
        var currentRow = startRow // Menginisialisasi indeks baris saat ini untuk penyisipan.
        var success = false // Menandai apakah ada setidaknya satu penyisipan yang berhasil.
        var ids: [Int64] = [] // Menyimpan ID dari data yang berhasil disisipkan untuk operasi undo.

        // Loop melalui setiap URL file yang diberikan.
        for fileURL in fileURLs {
            // Guard statement untuk memastikan URL menunjuk ke gambar yang valid dan dapat diubah menjadi Data.
            guard let image = NSImage(contentsOf: fileURL), // Coba muat gambar dari URL.
                  let imageData = image.tiffRepresentation
            else { // Dapatkan representasi TIFF dari gambar.
                // Jika gagal memuat gambar atau mendapatkan data gambar, lewati ke URL berikutnya.
                continue
            }

            // Dapatkan nama file (tanpa ekstensi) dari URL, yang akan digunakan sebagai nama barang.
            let fileName = fileURL.deletingPathExtension().lastPathComponent

            // Memanggil `handleInsertNewRow` secara asinkron untuk menyisipkan satu baris baru.
            // `handleInsertNewRow` diasumsikan melakukan penyisipan data ke model dan memperbarui tabel.
            let (inserted, id) = await handleInsertNewRow(at: currentRow, withImageData: imageData, tableView: tableView, fileName: fileName)

            // Periksa apakah penyisipan berhasil dan ID data tersedia.
            if inserted, let dataID = id {
                currentRow += 1 // Tingkatkan indeks baris untuk penyisipan berikutnya.
                ids.append(dataID) // Tambahkan ID ke daftar untuk operasi undo.
                success = true // Setel `success` menjadi true karena setidaknya satu baris berhasil disisipkan.
            }
        }

        // Daftarkan operasi undo untuk semua ID yang baru saja disisipkan.
        // Ini memungkinkan pengguna untuk membatalkan penyisipan baris-baris ini.
        registerUndoForInsert(ids)

        // Kembalikan status keberhasilan keseluruhan operasi.
        return success
    }

    /// Menangani penyisipan satu baris data baru ke dalam tabel dan Core Data secara asinkron.
    /// Fungsi ini menginisialisasi data untuk baris baru berdasarkan skema kolom yang ditentukan
    /// di `SingletonData.columns`, menetapkan gambar, dan kemudian menyisipkan data tersebut
    /// ke dalam model data aplikasi dan Core Data. Setelah penyisipan berhasil, ia memperbarui
    /// tampilan tabel dan menyimpan gambar ke database.
    ///
    /// - Parameters:
    ///   - row: `Int` yang menunjukkan indeks baris di mana data baru akan disisipkan dalam tabel.
    ///   - withImageData: `Data` dari gambar yang akan dikaitkan dengan baris baru ini.
    ///   - tableView: `NSTableView` tempat baris baru akan disisipkan.
    ///   - fileName: `String` yang akan digunakan sebagai nilai awal untuk kolom "Nama Barang".
    ///
    /// - Returns: Tuple `(Bool, Int64?)`
    ///   - `Bool`: `true` jika penyisipan dan penyimpanan ke Core Data berhasil, `false` jika gagal.
    ///   - `Int64?`: ID unik dari data yang baru disisipkan, atau `nil` jika penyisipan gagal.
    func handleInsertNewRow(at row: Int, withImageData imageData: Data, tableView: NSTableView, fileName: String) async -> (Bool, Int64?) {
        var newData: [String: Any] = [:] // Inisialisasi dictionary untuk menyimpan data baris baru.
        dateFormatter.dateFormat = "dd-MMMM-yyyy" // Mengatur format tanggal.
        let currentDate = dateFormatter.string(from: Date()) // Mendapatkan tanggal saat ini dalam format string.

        // Mengisi `newData` berdasarkan definisi kolom di `SingletonData.columns`.
        for column in SingletonData.columns {
            if column.type == String.self {
                // Jika tipe kolom adalah String.
                if column.name == "Tanggal Dibuat" {
                    newData[column.name] = currentDate // Set nilai "Tanggal Dibuat" dengan tanggal saat ini.
                } else if column.name == "Nama Barang" {
                    newData[column.name] = fileName // Set nilai "Nama Barang" dengan `fileName` yang diberikan.
                } else {
                    newData[column.name] = "" // Untuk kolom String lainnya, set nilai default string kosong.
                }
            } else if column.type == Int64.self {
                // Jika tipe kolom adalah Int64, set nilai default 0.
                newData[column.name] = 0
            }
        }

        // Memproses data gambar yang diberikan.
        if let image = NSImage(data: imageData) {
            // Mengubah ukuran gambar ke dimensi yang telah ditentukan (`size`).
            let resizedImage = ReusableFunc.resizeImage(image: image, to: size)
            newData["Foto"] = resizedImage // Menyimpan gambar yang telah diubah ukurannya ke `newData`.
        }

        // Memperbarui model data utama (`self.data`) di MainActor karena ini adalah perubahan UI-related.
        await MainActor.run {
            self.data.insert(newData, at: row) // Sisipkan baris baru ke dalam array data.
        }

        // Menyimpan data baru ke Core Data menggunakan `manager.insertData`.
        // `guard let` digunakan untuk memastikan operasi penyimpanan berhasil dan mengembalikan ID.
        guard let newId = await manager.insertData(newData) else {
            // Jika penyimpanan gagal, kembalikan `false` dan `nil` ID.
            return (false, nil)
        }

        // Setelah berhasil menyimpan ke Core Data, perbarui `newData` di model dengan ID yang dihasilkan.
        data[row]["id"] = newId
        // Memastikan "Tanggal Dibuat" di data model juga sudah sesuai dengan yang ditetapkan.
        data[row]["Tanggal Dibuat"] = currentDate
        // Menambahkan ID baru ke set `newData` (mungkin untuk pelacakan perubahan atau undo).
        self.newData.insert(newId)

        // Melakukan pembaruan UI di MainActor.
        await MainActor.run {
            // Memberi tahu `tableView` untuk menyisipkan baris baru dengan animasi.
            tableView.insertRows(at: IndexSet([row]), withAnimation: .effectGap)
            // Memfokuskan pada kolom "Nama Barang" dari baris yang baru disisipkan.
            focusOnNamaBarang(row: row)
        }

        // Menyimpan gambar ke database (kemungkinan ke lokasi spesifik setelah ID diketahui).
        await saveImageToDatabase(atRow: row, imageData: imageData)

        // Kembalikan `true` untuk menandakan keberhasilan dan ID dari data yang baru disisipkan.
        return (true, newId)
    }

    /// Menggantikan data gambar pada baris yang sudah ada di tabel dan database.
    /// Fungsi ini dirancang untuk memperbarui hanya kolom "Foto" dari sebuah entitas
    /// yang sudah ada tanpa mengubah data lainnya. Ia juga mendukung fungsionalitas undo
    /// dengan menyimpan data gambar lama sebelum penggantian.
    ///
    /// - Parameters:
    ///   - row: `Int` yang menunjukkan indeks baris di `NSTableView` yang akan diperbarui.
    ///   - withImageData: `Data` dari gambar baru yang akan digunakan untuk menggantikan gambar lama.
    ///   - tableView: `NSTableView` tempat operasi penggantian baris dilakukan.
    ///
    /// - Returns: `Bool` yang selalu `true` setelah operasi dimulai.
    ///   Perhatikan bahwa operasi asinkron di dalam `Task` tidak memengaruhi nilai kembalian ini secara langsung,
    ///   dan keberhasilan pembaruan database ditangani di dalam `Task` itu sendiri.
    func handleReplaceExistingRow(at row: Int, withImageData imageData: Data, tableView: NSTableView) -> Bool {
        guard row < data.count,
              let id = data[row]["id"] as? Int64
        else { return false }
        Task {
            let oldImageData = await self.manager.getImage(id)

            // Update di database
            guard let id = data[row]["id"] as? Int64 else { return false }

            // Register undo untuk replace
            registerUndoForReplace(id: id, oldImageData: oldImageData)

            await saveImageToDatabase(atRow: row, imageData: imageData)

            await MainActor.run {
                tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            }
            return true
        }
        return true
    }

    /// Seleksi baris yang baru saja diupdate melalui drop foto.
    func focusOnNamaBarang(row: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: true)
        }
    }

    /// Pendaftaran ke ``myUndoManager`` untuk keperluan undo
    /// setelah baru menambahkan data melalui drop foto ke ``tableView``.
    func registerUndoForInsert(_ newId: [Int64]) {
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.undoAddRows(newId)
        })
    }

    /// Pendaftaran ke ``myUndoManager`` untuk keperluan undo
    /// setelah memperbarui foto di suat baris melalui drop foto
    /// ke baris yang sudah ada di ``tableView``.
    func registerUndoForReplace(id: Int64, oldImageData: Data?) {
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undoReplaceImage(id, imageData: oldImageData ?? Data())
        }
    }

    /// Berguna untuk mencari row di ``data``
    /// yang sesuai dengan `id` yang diterima.
    /// baris ini juga sama urutannya dengan yang ada di ``tableView``.
    /// - Parameter id: `id` pada baris yang akan dicari.
    /// - Returns: Properti baris yang ditemukan.
    /// Properti ini akan`nil` jika `id` tidak ditemukan.
    func findRowIndex(forId id: Int64) -> Int? {
        data.firstIndex { ($0["id"] as? Int64) == id }
    }
}

// MARK: - DRAG ROW KE APLIKASI LAIN

extension InventoryView: NSFilePromiseProviderDelegate {
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let mouseLocation = tableView.window?.mouseLocationOutsideOfEventStream ?? .zero
        let locationInView = tableView.convert(mouseLocation, from: nil)

        // Dapatkan kolom di posisi mouse
        let column = tableView.column(at: locationInView)

        guard column == 1 else { return nil }

        // Dapatkan cell view
        guard let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cellView.textField else { return nil }
        // Buat semaphore untuk menunggu operasi selesai
        let customQueue = DispatchQueue(label: "sdi.Data-SDI.pasteboardWriterQueue", qos: .userInteractive)

        if tableView.selectedRowIndexes.contains(row) {
            // Buat file promise provider dengan userInfo yang lengkap
            let provider = FilePromiseProvider(
                fileType: UTType.data.identifier,
                delegate: self
            )
            // Siapkan data foto untuk setiap item yang didrag.
            customQueue.async { [weak self] in
                guard let self, let id = data[row]["id"] as? Int64 else { return }
                let nama = data[row]["Nama Barang"] as? String ?? "Nama Barang"
                let foto = manager.getImageSync(id)

                // Send over the row number and photo's url dictionary.
                provider.userInfo = [FilePromiseProvider.UserInfoKeys.namaKey: nama,
                                     FilePromiseProvider.UserInfoKeys.imageKey: foto as Any]
            }
            return provider
        }

        // Konversi posisi mouse ke koordinat cell
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

        // Siapkan data foto untuk setiap item yang didrag.
        customQueue.async { [weak self] in
            guard let self, let id = data[row]["id"] as? Int64 else { return }
            let nama = data[row]["Nama Barang"] as? String ?? "Nama Barang"
            let foto = manager.getImageSync(id)

            // Send over the row number and photo's url dictionary.
            provider.userInfo = [FilePromiseProvider.UserInfoKeys.namaKey: nama,
                                 FilePromiseProvider.UserInfoKeys.imageKey: foto as Any]
        }
        return provider
    }

    /// Mengatur fungsionalitas _drag and drop_ untuk `NSTableView`.
    /// Fungsi ini mengonfigurasi tabel agar dapat menerima data yang diseret dari aplikasi lain,
    /// khususnya file gambar dan teks. Ini juga mengaktifkan _multiple selection_
    /// dan mengatur _feedback style_ visual saat _dragging_ ke tabel.
    func setupTableDragAndDrop() {
        // Mengatur jenis operasi _dragging source_ yang didukung oleh tabel ketika bertindak
        // sebagai sumber seretan. `.copy` berarti tabel memungkinkan data-nya disalin (bukan dipindahkan)
        // ke aplikasi lain, dan `forLocal: false` menunjukkan bahwa ini berlaku untuk target non-lokal.
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        // Mendaftarkan tabel untuk tipe data yang dapat diterima saat menjadi _dragging destination_.
        // Ini berarti tabel dapat menerima data gambar TIFF, PNG, URL file, dan string.
        tableView.registerForDraggedTypes([.tiff, .png, .fileURL, .string])

        // Mengaktifkan _multiple selection_ pada tabel, memungkinkan pengguna memilih
        // lebih dari satu baris secara bersamaan.
        tableView.allowsMultipleSelection = true

        // Mengatur _feedback style_ visual yang ditampilkan saat item diseret di atas tabel.
        // `.regular` biasanya menampilkan indikator penyisipan di antara baris.
        tableView.draggingDestinationFeedbackStyle = .regular
    }

    /// Memeriksa apakah sumber operasi _drag_ berasal dari `NSTableView` ini sendiri.
    /// Fungsi ini membantu membedakan antara operasi _drag and drop_ internal (di dalam aplikasi ini)
    /// dan eksternal (dari aplikasi lain).
    ///
    /// - Parameter draggingInfo: Objek `NSDraggingInfo` yang berisi informasi tentang operasi _drag_ yang sedang berlangsung.
    /// - Returns: `Bool` yang bernilai `true` jika sumber _drag_ adalah `tableView` ini,
    ///            dan `false` jika bukan.
    func dragSourceIsFromOurTable(draggingInfo: NSDraggingInfo) -> Bool {
        // Memeriksa apakah `draggingSource` dari `draggingInfo` adalah instance dari `NSTableView`,
        // dan jika `NSTableView` tersebut sama dengan `tableView` ini (`self.tableView`).
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableView {
            true // Jika ya, sumber drag berasal dari tabel kita.
        } else {
            false // Jika tidak, sumber drag bukan dari tabel kita.
        }
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType _: String) -> String {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let nama = userInfoDict[FilePromiseProvider.UserInfoKeys.namaKey] as? String else { return "unknown.dat" }

        return nama.replacingOccurrences(of: "/", with: "-") + ".png"
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let userInfoDict = filePromiseProvider.userInfo as? [String: Any],
              let fotoData = userInfoDict[FilePromiseProvider.UserInfoKeys.imageKey] as? Data
        else {
            completionHandler(NSError(domain: "", code: -1))
            return
        }
        DispatchQueue.global(qos: .background).async {
            guard let fotoJPEG = NSImage(data: fotoData)?.pngRepresentation else { return }
            do {
                try fotoJPEG.write(to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
