//
//  EditData.swift
//  Data SDI
//
//  Created by Bismillah on 27/12/23.
//

import Cocoa
import SQLite

class EditData: NSViewController {
    @IBOutlet weak var horizontalLine: NSBox!
    @IBOutlet weak var imageView: XSDragImageView!
    @IBOutlet weak var pilihFoto: NSButton!
    @IBOutlet weak var hapusFoto: NSButton!
    @IBOutlet weak var eksporFoto: NSButton!
    @IBOutlet weak var tglDaftar: ExpandingDatePicker!
    @IBOutlet weak var tglBerhenti: ExpandingDatePicker!
    @IBOutlet weak var status: NSPopUpButton!
    @IBOutlet weak var jnsKelamin: NSPopUpButton!
    @IBOutlet weak var pilihKelas: NSPopUpButton!
    @IBOutlet weak var kelaminSwitch: NSButton!
    @IBOutlet weak var kelasSwitch: NSButton!
    @IBOutlet weak var statusSwitch: NSButton!
    @IBOutlet weak var tglPendaftaranSwitch: NSButton!
    @IBOutlet weak var batalkantmbl: NSButton!
    @IBOutlet weak var tmblsimpan: NSButton!
    @IBOutlet weak var pratinjau: NSButton!
    
    //TextField
    @IBOutlet weak var namaSiswa: NSTextField!
    @IBOutlet weak var alamatSiswa: NSTextField!
    @IBOutlet weak var ttlTextField: NSTextField!
    @IBOutlet weak var NIS: NSTextField!
    @IBOutlet weak var namawaliTextField: NSTextField!
    @IBOutlet weak var ibu: NSTextField!
    @IBOutlet weak var tlv: NSTextField!
    @IBOutlet weak var ayah: NSTextField!
    @IBOutlet weak var NISN: NSTextField!
    
    // Label
    @IBOutlet weak var namaLabel: NSTextField!
    @IBOutlet weak var alamatLabel: NSTextField!
    @IBOutlet weak var ttlteks: NSTextField!
    @IBOutlet weak var nisteks: NSTextField!
    @IBOutlet weak var namaortuteks: NSTextField!
    @IBOutlet weak var tglBerhentiTeks: NSTextField!
    
    // Data
    var selectedSiswaList: [ModelSiswa] = []
    let dbController = DatabaseController.shared
    var siswaID: Int64?
    var siswaData: ModelSiswa?
    var selectedImageURL: URL?
    
    // Pilihan
    private var aktifkanTglDaftar: Bool = false
    private var aktifkanTglBerhenti: Bool = false
    private var pilihJnsKelamin: Bool = false
    private var pilihKelasSwitch: Bool = false
    private var pilihStatusSwitch: Bool = false
    private var nonaktifkanImageView: Bool = true
    
    // AutoComplete Teks
    private var suggestionManager: SuggestionManager!
    private var activeText: NSTextField!
    
    @IBOutlet weak var vertical1: NSBox!
    override func viewDidLoad() {
        super.viewDidLoad()
        if let v = view as? NSVisualEffectView {
            v.blendingMode = .behindWindow
            v.material = .windowBackground
            v.state = .followsWindowActiveState
        }
        if selectedSiswaList.count > 1 {
//            self.view.frame = CGRect(x: 422, y: self.view.frame.minY, width: 422, height: self.view.frame.height)
//            let newX: CGFloat = -218 // Geser poin dari sisi kanan
//            tmblsimpan.frame.origin.x += newX
//            batalkantmbl.frame.origin.x += newX
//            // Atur frame masing-masing elemen dengan nilai x yang baru
//            nama.frame.origin.x += newX
//            alamat.frame.origin.x += newX
//            ttl.frame.origin.x += newX
//            nis.frame.origin.x += newX
//            namawali.frame.origin.x += newX
//            tglDaftar.frame.origin.x += newX
//            tglBerhenti.frame.origin.x += newX
//            tglBerhentiTeks.frame.origin.x += newX
//            status.frame.origin.x += newX
//            jnsKelamin.frame.origin.x += newX
//            pilihKelas.frame.origin.x += newX
//            kelaminSwitch.frame.origin.x += newX
//            kelasSwitch.frame.origin.x += newX
//            statusSwitch.frame.origin.x += newX
//            tglPendaftaranSwitch.frame.origin.x += newX
//            namaTeks.frame.origin.x += newX
//            alamatteks.frame.origin.x += newX
//            ttlteks.frame.origin.x += newX
//            nisteks.frame.origin.x += newX
//            namaortuteks.frame.origin.x += newX
//            horizontalLine.removeFromSuperviewWithoutNeedingDisplay()
//            vertical1.removeFromSuperviewWithoutNeedingDisplay()
        }
        namaSiswa.delegate = self
        ttlTextField.delegate = self
        alamatSiswa.delegate = self
        namawaliTextField.delegate = self
        ayah.delegate = self
        ibu.delegate = self
        NIS.delegate = self
        NISN.delegate = self
        tlv.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if selectedSiswaList.count == 1 {
            siswaData = dbController.getSiswa(idValue: siswaID!)
            // StringValue
            namaSiswa.stringValue = siswaData?.nama ?? ""
            alamatSiswa.stringValue = siswaData?.alamat ?? ""
            ttlTextField.stringValue = siswaData?.ttl ?? ""
            NIS.stringValue = siswaData?.nis ?? ""
            NISN.stringValue = siswaData?.nisn ?? ""
            ayah.stringValue = siswaData?.ayah ?? ""
            ibu.stringValue = siswaData?.ibu ?? ""
            namawaliTextField.stringValue = siswaData?.namawali ?? ""
            tlv.stringValue = siswaData?.tlv ?? ""
            
            pilihKelas.selectItem(withTitle: siswaData?.kelasSekarang ?? "")
            pilihKelas.selectedItem?.state = .on
            jnsKelamin.selectItem(withTitle: siswaData?.jeniskelamin ?? "")
            jnsKelamin.selectedItem?.state = .on
            status.selectItem(withTitle: siswaData?.status ?? "")
            status.selectedItem?.state = .on
            pilihJnsKelamin = true
            aktifkanTglDaftar = true
            pilihKelasSwitch = true
            pilihStatusSwitch = true
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMMM yyyy"
            if let tglPndftrn = dateFormatter.date(from: siswaData?.tahundaftar ?? "") { tglDaftar.dateValue = tglPndftrn }
            if let tglBrhnt = dateFormatter.date(from: siswaData?.tanggalberhenti ?? "") { tglBerhenti.dateValue = tglBrhnt }
            if (2...3).contains(status.indexOfSelectedItem) {
                tglBerhenti.isEnabled = true
                aktifkanTglBerhenti = true
                pilihKelas.isEnabled = false
                kelasSwitch.isEnabled = false
            } else {
                tglBerhenti.isEnabled = false
                aktifkanTglBerhenti = false
                pilihKelas.isEnabled = true
                kelasSwitch.isEnabled = true
            }
            nonaktifkanImageView = false
        } else if selectedSiswaList.count > 1 {
            siswaData = dbController.getSiswa(idValue: selectedSiswaList[0].id)
//            let pengeditanMultipelString = NSAttributedString(string: "Berisi Informasi Beberapa Siswa", attributes: [
//                NSAttributedString.Key.foregroundColor: NSColor.tertiaryLabelColor,
//                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13) // Sesuaikan font dan ukuran sesuai keinginan Anda
//            ])
            namaSiswa.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            alamatSiswa.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ttlTextField.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            NIS.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            namawaliTextField.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            NISN.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ayah.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ibu.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            tlv.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            jnsKelamin.isEnabled = false
            pilihJnsKelamin = false
            kelaminSwitch.state = .off
            pilihKelas.isEnabled = false
            pilihKelasSwitch = false
            kelasSwitch.state = .off
            aktifkanTglDaftar = false
            status.isEnabled = false
            pilihStatusSwitch = false
            statusSwitch.state = .off
            pilihFoto.isEnabled = false
            imageView.removeFromSuperviewWithoutNeedingDisplay()
            nonaktifkanImageView = true
            hapusFoto.isEnabled = false
            eksporFoto.isEnabled = false
            tglDaftar.isEnabled = false
            tglBerhenti.isEnabled = false
            pratinjau.isEnabled = false
            tglPendaftaranSwitch.state = .off
            imageView.frame = CGRect.zero
            pilihFoto.frame = CGRect.zero
            hapusFoto.frame = CGRect.zero
            eksporFoto.frame = CGRect.zero
        }
    }
    override func viewDidAppear() {
        DispatchQueue.main.async {
            ReusableFunc.resetMenuItems()
        }
    }
    override func viewWillDisappear() {
        NotificationCenter.default.post(name: .popupDismissed, object: nil)
        if tglDaftarBerhenti {
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        }
    }
    func resetKapital() {
        let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
        fields.forEach { field in
            field?.placeholderString = (field?.placeholderString?.lowercased() ?? "")
        }
    }
    @IBAction func ubahTglDftr(_ sender: Any) {
        aktifkanTglDaftar.toggle()
        if aktifkanTglDaftar {
            tglDaftar.isEnabled = true
        } else {
            tglDaftar.isEnabled = false
        }
    }
    @IBAction func pratinjauFoto(_ sender: NSButton) {
        if let siswa = siswaData {
            let selectedSiswa = selectedSiswaList.first { $0.id == siswa.id }
            if let viewController = NSStoryboard(name: NSStoryboard.Name("PratinjauFoto"), bundle: nil)
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ImagePreviewViewController")) as? PratinjauFoto {
                viewController.selectedSiswa = selectedSiswa
                viewController.loadView()
                // Menampilkan popover atau sheet, sesuai kebutuhan Anda
                let popover = NSPopover()
                popover.contentViewController = viewController
                popover.behavior = .semitransient

                // Tampilkan popover di dekat tombol yang memicunya
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            }
        }
        
    }
    @IBAction func aksiJenisKelamin(_ sender: NSPopUpButton) {
        let kelamin = sender.titleOfSelectedItem ?? ""
        guard let submenu = sender.menu else { return }
        // Iterate through the items in the submenu
        for bela in submenu.items {
            bela.state = .off
        }
        jnsKelamin.selectItem(withTitle: kelamin)
        jnsKelamin.selectedItem?.state = .on
    }
    @IBAction func kelaminSwitch(_ sender: NSButton) {
        pilihJnsKelamin.toggle()
        if pilihJnsKelamin {
            jnsKelamin.isEnabled = true
            sender.state = .on
        } else {
            jnsKelamin.isEnabled = false
            sender.state = .off
        }
    }
    @IBAction func aksiTglBerhenti(_ sender: ExpandingDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let selectedDate = sender.dateValue
        let formattedDate = dateFormatter.string(from: selectedDate)
        tglBerhenti.dateValue = dateFormatter.date(from: formattedDate)!
    }
    @IBAction func aksiKelas(_ sender: NSPopUpButton) {
        guard let submenu = sender.menu else { return }
        for bela in submenu.items {
            bela.state = .off
        }
        pilihKelas.selectedItem?.state = .on
        tglBerhenti.isEnabled = false
        statusSwitch.isEnabled = true
        statusSwitch.state = .on
        status.isEnabled = true
        status.selectItem(at: 1)
        status.selectedItem?.state = .on
    }
    @IBAction func kelasSwitch(_ sender: NSButton) {
        pilihKelasSwitch.toggle()
        if pilihKelasSwitch {
            pilihKelas.isEnabled = true
            sender.state = .on
            if selectedSiswaList.count > 1 {
                pilihStatusSwitch = true
                pilihKelas.selectItem(at: 1)
                pilihKelas.selectedItem?.state = .on
                status.isEnabled = true
                status.selectItem(at: 1)
                status.selectedItem?.state = .on
                statusSwitch.animator().state = .on
            }
        } else {
            if selectedSiswaList.count > 1 {
                pilihStatusSwitch = false
                pilihKelas.select(nil)
                status.isEnabled = false
                status.select(nil)
                statusSwitch.animator().state = .off
            }
            pilihKelas.isEnabled = false
            sender.state = .off
        }
    }
    @IBAction func aksiStatus(_ sender: NSPopUpButton) {
        guard let submenu = sender.menu else { return }
        for bela in submenu.items {
            bela.state = .off
        }
        let statuss = sender.titleOfSelectedItem ?? ""
        status.selectItem(withTitle: statuss)
        status.selectedItem?.state = .on
        if sender.indexOfSelectedItem == 2 {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        } else if sender.indexOfSelectedItem == 3 {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        } else {
            tglBerhenti.isEnabled = false
            pilihKelas.isEnabled = true
            kelasSwitch.isEnabled = true
            pilihKelasSwitch = true
            kelasSwitch.state = .on
        }
    }
    @IBAction func statusSwitch(_ sender: NSButton) {
        pilihStatusSwitch.toggle()
        if pilihStatusSwitch {
            sender.state = .on
            status.isEnabled = true
            kelasSwitch.isEnabled = true
            if selectedSiswaList.count > 1 {
                pilihKelasSwitch.toggle()
                status.selectItem(at: 1)
                status.selectedItem?.state = .on
                pilihKelas.selectItem(at: 1)
                pilihKelas.selectedItem?.state = .on
            }
            kelasSwitch.animator().state = .on
        } else {
            status.isEnabled = false
            if selectedSiswaList.count > 1 {
                pilihKelasSwitch.toggle()
                status.select(nil)
            }
            pilihKelas.isEnabled = false
            kelasSwitch.animator().state = .off
            sender.state = .off
        }
        if status.titleOfSelectedItem == "Aktif" {
            tglBerhenti.isEnabled = false
            pilihKelas.isEnabled = true
            kelasSwitch.isEnabled = true
            kelasSwitch.animator().state = .on
            pilihKelasSwitch = true
        } else {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        }
    }
    var tglDaftarBerhenti = false
    
    func updateSiswa(_ siswa: ModelSiswa, with input: SiswaInput, option: UpdateOption) {
        let id = siswa.id

        dbController.updateSiswa(
            idValue: id,
            namaValue: input.nama.isEmpty ? siswa.nama : input.nama,
            alamatValue: input.alamat.isEmpty ? siswa.alamat : input.alamat,
            ttlValue: input.ttl.isEmpty ? siswa.ttl : input.ttl,
            tahundaftarValue: option.aktifkanTglDaftar ? input.tanggalDaftar : siswa.tahundaftar,
            namawaliValue: input.namawali.isEmpty ? siswa.namawali : input.namawali,
            nisValue: input.nis.isEmpty ? siswa.nis : input.nis,
            jeniskelaminValue: option.pilihJnsKelamin ? input.jeniskelamin : siswa.jeniskelamin,
            statusValue: option.statusEnabled ? input.status : siswa.status,
            tanggalberhentiValue: option.tglBerhentiEnabled ? input.tanggalBerhenti : siswa.tanggalberhenti,
            nisnValue: input.nisn.isEmpty ? siswa.nisn : input.nisn,
            updatedAyah: input.ayah.isEmpty ? siswa.ayah : input.ayah,
            updatedIbu: input.ibu.isEmpty ? siswa.ibu : input.ibu,
            updatedTlv: input.tlv.isEmpty ? siswa.tlv : input.tlv
        )
        
        let data: [ModelSiswaKey: String] = [
            .nama: input.nama,
            .alamat: input.alamat,
            .ttl: input.ttl,
            .namawali: input.namawali,
            .nis: input.nis,
            .nisn: input.nisn,
            .ayah: input.ayah,
            .ibu: input.ibu,
            .tlv: input.tlv
        ]
        
        DatabaseController.shared.catatSuggestions(data: data)

        if let imageData = input.selectedImageData {
            dbController.updateFotoInDatabase(with: imageData, idx: id)
        }

        // Notifikasi nama berubah
        if input.nama != siswa.nama && option.kelasPilihan == siswa.kelasSekarang {
            NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: [
                "updateStudentIDs": id,
                "kelasSekarang": siswa.kelasSekarang,
                "namaSiswa": input.nama
            ])
        }

        // Kelas berubah
        if option.kelasIsEnabled && option.kelasPilihan != siswa.kelasSekarang {
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
                "deletedStudentIDs": [id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true
            ])
            dbController.updateKelasAktif(idSiswa: id, newKelasAktif: option.pilihKelasSwitch ? option.kelasPilihan : siswa.kelasSekarang)
            dbController.updateTabelKelasAktif(
                idSiswa: id,
                kelasAwal: siswa.kelasSekarang,
                kelasYangDikecualikan: option.kelasPilihan.replacingOccurrences(of: " ", with: "").lowercased()
            )
        }

        // Status lulus
        if option.statusEnabled && input.status == "Lulus" {
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
                "deletedStudentIDs": [id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true
            ])
            dbController.editSiswaLulus(namaSiswa: siswa.nama, siswaID: id, kelasBerikutnya: "Lulus")
        }
    }

    
    
    @IBAction func update(_ sender: Any) {
        var ids = [Int64]()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"

        let tglPndftrn = formatter.string(from: tglDaftar.dateValue)
        let tglBrhnti = formatter.string(from: tglBerhenti.dateValue)
        let selectedImageData = nonaktifkanImageView ? nil : imageView.selectedImage?.compressImage(quality: 0.5)

        let option = UpdateOption(
            aktifkanTglDaftar: aktifkanTglDaftar,
            tglBerhentiEnabled: tglBerhenti.isEnabled,
            statusEnabled: status.isEnabled,
            pilihKelasSwitch: pilihKelasSwitch,
            kelasIsEnabled: pilihKelas.isEnabled,
            pilihJnsKelamin: pilihJnsKelamin,
            kelasPilihan: pilihKelas.titleOfSelectedItem ?? ""
        )

        for siswa in selectedSiswaList {
            let input = SiswaInput(
                nama: ReusableFunc.teksFormat(namaSiswa.stringValue, oldValue: siswa.nama, hurufBesar: hurufBesar, kapital: kapitalkan),
                alamat: ReusableFunc.teksFormat(alamatSiswa.stringValue, oldValue: siswa.alamat, hurufBesar: hurufBesar, kapital: kapitalkan),
                ttl: ReusableFunc.teksFormat(ttlTextField.stringValue, oldValue: siswa.ttl, hurufBesar: hurufBesar, kapital: kapitalkan),
                nis: NIS.stringValue,
                nisn: NISN.stringValue,
                ayah: ReusableFunc.teksFormat(ayah.stringValue, oldValue: siswa.ayah, hurufBesar: hurufBesar, kapital: kapitalkan),
                ibu: ReusableFunc.teksFormat(ibu.stringValue, oldValue: siswa.ibu, hurufBesar: hurufBesar, kapital: kapitalkan),
                tlv: tlv.stringValue,
                namawali: ReusableFunc.teksFormat(namawaliTextField.stringValue, oldValue: siswa.namawali, hurufBesar: hurufBesar, kapital: kapitalkan),
                jeniskelamin: jnsKelamin.titleOfSelectedItem ?? "",
                status: status.titleOfSelectedItem ?? "",
                tanggalDaftar: tglPndftrn,
                tanggalBerhenti: tglBrhnti,
                kelas: pilihKelas.titleOfSelectedItem ?? "",
                selectedImageData: selectedImageData
            )
            updateSiswa(siswa, with: input, option: option)
            ids.append(siswa.id)
        }

        self.dismiss(nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dataSiswaDiEdit, object: nil, userInfo: ["ids": ids])
        }
    }

    
    @IBAction func insertFoto(_ sender: Any) {
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
    @IBAction func eksporFoto(_ sender: Any) {
        let imageData = dbController.bacaFotoSiswa(idValue: siswaID!)
        guard let image = NSImage(data: imageData.foto), let compressedImageData = image.compressImage(quality: 0.5) else {
            // Tambahkan penanganan jika gagal mengonversi atau mengompresi ke Data
            return
        }

        // Membuat nama file berdasarkanƒ nama siswa
        let fileName = "\(siswaData?.nama ?? "unknown").png"

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
    @IBAction func hapusFoto(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menghapus foto"
        alert.informativeText = "Foto \(siswaData?.nama ?? "Siswa") akan dihapus. Tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Hapus")
        
        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [self] (response) in
        if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Hapus"
            // Melanjutkan penghapusan jika pengguna menekan tombol "Hapus"
            dbController.hapusFoto(idx: siswaData?.id ?? 0)
            self.imageView.image = NSImage(named: "image")
            imageView.selectedImage = nil
        }
            dbController.vacuumDatabase()
        }
    }
    
    var kapitalkan: Bool = true
    var hurufBesar: Bool = false
    @IBAction func kapitalkan(_ sender: Any) {
        [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah].kapitalkanSemua()
        if selectedSiswaList.count > 1 {
            let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
            fields.forEach { field in
                field?.placeholderString = (field?.placeholderString?.capitalized ?? "")
            }
        }
        kapitalkan = true
        hurufBesar = false
    }
    @IBAction func hurufBesar(_ sender: Any) {
        [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah].hurufBesarSemua()
        if selectedSiswaList.count > 1 {
            let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
            fields.forEach { field in
                field?.placeholderString = (field?.placeholderString?.uppercased() ?? "")
            }
        }

        kapitalkan = false
        hurufBesar = true
    }
    
    @IBAction func tutup(_ sender: Any) {
        dismiss(nil)
    }
    @IBAction func aksiTglPendaftaran(_ sender: ExpandingDatePicker) {}
}
extension EditData: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {return}
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
    func controlTextDidBeginEditing(_ obj: Notification) {
        activeText = obj.object as? NSTextField
        let suggestionsDict: [NSTextField: [String]] = [
            namaSiswa: Array(ReusableFunc.namasiswa),
            alamatSiswa: Array(ReusableFunc.alamat),
            ayah: Array(ReusableFunc.namaAyah),
            ibu: Array(ReusableFunc.namaIbu),
            namawaliTextField: Array(ReusableFunc.namawali),
            ttlTextField: Array(ReusableFunc.ttl),
            NIS: Array(ReusableFunc.nis),
            NISN: Array(ReusableFunc.nisn),
            tlv: Array(ReusableFunc.tlvString)
        ]
        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            let currentText = activeTextField.stringValue
            
            // Find the last word (after the last space)
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])
                
                // Update the text field with only the last word
                suggestionManager.typing = lastWord
                
            } else {
                suggestionManager.typing = activeText.stringValue
            }
        }
        if activeText?.stringValue.isEmpty == true {
            suggestionManager.hideSuggestions()
        } else {
            suggestionManager.controlTextDidChange(obj)
        }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if !suggestionManager.suggestionWindow.isVisible {
            return false
        }
        
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            suggestionManager.moveUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            suggestionManager.moveDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            suggestionManager.enterSuggestions()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            suggestionManager.hideSuggestions()
            return true
        case #selector(NSResponder.insertTab(_:)):
            suggestionManager.hideSuggestions()
            return false
        default:
            return false
        }
    }
}
