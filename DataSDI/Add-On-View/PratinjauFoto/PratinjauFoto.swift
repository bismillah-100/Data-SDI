//
//  ImagePreviewViewController.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/23.
//

import Cocoa

class PratinjauFoto: NSViewController {
    @IBOutlet weak var imageView: XSDragImageView!
    var fotoData: Data?
    var selectedSiswa: ModelSiswa?
    let dbController = DatabaseController.shared
    var siswa: ModelSiswa?
    var foto: FotoSiswa!
    var selectedImageURL: URL?
    @IBOutlet weak var hapus: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        siswa = dbController.getSiswa(idValue: selectedSiswa?.id ?? 0)
        foto = dbController.bacaFotoSiswa(idValue: selectedSiswa?.id ?? 0)
        let data = foto.foto
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
    
    @IBAction func simpanFoto(_ sender: Any) {
        // Menambahkan alert sebelum menulis ke SQLite
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menyimpan foto?"
        alert.informativeText = "Foto \(selectedSiswa?.nama ?? "Siswa") akan diperbarui, tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Lanjutkan")
        
        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [self] (response) in
            if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Simpan"
                // Melanjutkan penyimpanan jika pengguna menekan tombol "Simpan"
                let selectedImage = imageView.selectedImage
                let compressedImageData = selectedImage?.compressImage(quality: 0.5) ?? Data()
                dbController.updateFotoInDatabase(with: compressedImageData, idx: self.selectedSiswa?.id ?? 0)
            }
        }
    }
    @IBAction func editFoto(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        
        // Menggunakan sheets
        openPanel.beginSheetModal(for: self.view.window!) { [self] (response) in
            if response == NSApplication.ModalResponse.OK {
                if let imageURL = openPanel.urls.first {
                    // Menyimpan URL gambar yang dipilih
                    self.selectedImageURL = imageURL
                    
                    do {
                        let imageData = try Data(contentsOf: imageURL)
                        
                        if let image = NSImage(data: imageData) {
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
                            imageView.selectedImage = image
                        }
                    } catch {
                        
                    }
                }
            }
        }
    }
    @IBAction func hpsFoto(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menghapus foto"
        alert.informativeText = "Foto \(selectedSiswa?.nama ?? "Siswa") akan dihapus. Tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Hapus")
        
        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [self] (response) in
        if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Hapus"
            // Melanjutkan penghapusan jika pengguna menekan tombol "Hapus"
            dbController.hapusFoto(idx: selectedSiswa?.id ?? 0)
            self.imageView.image = NSImage(named: "image")
            imageView.selectedImage = nil
        }
            dbController.vacuumDatabase()
        }
    }
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
        savePanel.nameFieldStringValue = fileName  // Menetapkan nama file default

        // Menampilkan save panel
        savePanel.beginSheetModal(for: self.view.window!) { (result) in
            if result == .OK, let fileURL = savePanel.url {
                do {
                    try compressedImageData.write(to: fileURL)
                    
                } catch {
                    
                }
            }
        }
    }
    deinit {
        foto = nil
        fotoData = nil
    }
}
