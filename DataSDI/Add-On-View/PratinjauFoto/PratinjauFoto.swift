//
//  PratinjauFoto.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/23.
//

import Cocoa

/// Class untuk menampilkan pratinjau foto siswa yang digunakan di ``DetailSiswaController``, ``EditData``, dan ``AddDataViewController``.
class PratinjauFoto: NSViewController {
    /// Outlet untuk NSImageView yang menampilkan foto siswa.
    @IBOutlet weak var imageView: XSDragImageView!
    /// Data foto siswa yang akan ditampilkan.
    /// Digunakan untuk menyimpan data foto siswa yang diambil dari database.
    var fotoData: Data?
    /// Siswa yang dipilih untuk ditampilkan fotonya.
    /// Digunakan untuk menyimpan informasi siswa yang dipilih dari daftar siswa.
    var selectedSiswa: ModelSiswa?
    /// Kontroler database yang digunakan untuk mengakses data siswa dan foto siswa.
    let dbController = DatabaseController.shared
    /// Objek `FotoSiswa` yang berisi informasi foto siswa.
    var foto: FotoSiswa!
    /// URL gambar yang dipilih oleh pengguna.
    var selectedImageURL: URL?
    /// Tombol untuk menghapus foto siswa.
    @IBOutlet weak var hapus: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        /// Ambil foto siswa dari database berdasarkan ID siswa yang dipilih.
        foto = dbController.bacaFotoSiswa(idValue: selectedSiswa?.id ?? 0)
        let data = foto.foto
        // Periksa apakah data foto tidak kosong
        if let image = NSImage(data: data) {
            // Atur properti NSImageView
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.imageAlignment = .alignCenter

            // Hitung proporsi aspek gambar
            let aspectRatio = image.size.width / image.size.height

            // Hitung dimensi baru untuk gambar
            let newWidth = min(imageView.frame.width, imageView.frame.height * aspectRatio)
            let newHeight = newWidth / aspectRatio

            // Atur ukuran gambar sesuai proporsi aspek
            image.size = NSSize(width: newWidth, height: newHeight)
            // Setel gambar ke NSImageView
            imageView.image = image
        }
    }

    override func viewWillAppear() {
        imageView.isEditable = true
        imageView.refusesFirstResponder = true
    }

    /// Action tombol "Simpan" untuk menyimpan foto siswa ke database.
    @IBAction func simpanFoto(_ sender: Any) {
        // Menambahkan alert sebelum menulis ke SQLite
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menyimpan foto?"
        alert.informativeText = "Foto \(selectedSiswa?.nama ?? "Siswa") akan diperbarui, tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Lanjutkan")

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
    @IBAction func editFoto(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        // Menggunakan sheets
        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self else { return }
            // Menangani respons dari open panel
            if response == NSApplication.ModalResponse.OK {
                if let imageURL = openPanel.urls.first {
                    // Menyimpan URL gambar yang dipilih
                    self.selectedImageURL = imageURL

                    do {
                        let imageData = try Data(contentsOf: imageURL)

                        if let image = NSImage(data: imageData) {
                            // Atur properti NSImageView
                            self.imageView.imageScaling = .scaleProportionallyUpOrDown
                            self.imageView.imageAlignment = .alignCenter

                            // Hitung proporsi aspek gambar
                            let aspectRatio = image.size.width / image.size.height

                            // Hitung dimensi baru untuk gambar
                            let newWidth = min(imageView.frame.width, imageView.frame.height * aspectRatio)
                            let newHeight = newWidth / aspectRatio

                            // Atur ukuran gambar sesuai proporsi aspek
                            image.size = NSSize(width: newWidth, height: newHeight)
                            // Setel gambar ke NSImageView
                            self.imageView.image = image
                            self.imageView.selectedImage = image
                        }
                    } catch {
                        ReusableFunc.showAlert(title: "Gagal Membaca Gambar", message: error.localizedDescription, style: .critical)
                    }
                }
            }
        }
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
            guard let self else { return }
            if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Hapus"
                // Melanjutkan penghapusan jika pengguna menekan tombol "Hapus"
                dbController.hapusFoto(idx: selectedSiswa?.id ?? 0)
                self.imageView.image = NSImage(named: "image")
                imageView.selectedImage = nil
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
        let fileName = "\(selectedSiswa?.nama ?? "unknown").png"

        // Menyimpan data gambar ke file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = fileName // Menetapkan nama file default

        // Menampilkan save panel
        savePanel.beginSheetModal(for: view.window!) { result in
            if result == .OK, let fileURL = savePanel.url {
                do {
                    try compressedImageData.write(to: fileURL)

                } catch {
                    ReusableFunc.showAlert(title: "Gagal Menyimpan Foto", message: error.localizedDescription, style: .critical)
                }
            }
        }
    }

    deinit {
        foto = nil
        fotoData = nil
    }
}
