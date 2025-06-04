//
//  AddDataViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa
import SQLite

class AddDataViewController: NSViewController {
    @IBOutlet weak var imageView: XSDragImageView!
    @IBOutlet weak var namaSiswa: NSTextField!
    @IBOutlet weak var alamatTextField: NSTextField!
    @IBOutlet weak var ttlTextField: NSTextField!
    @IBOutlet weak var NIS: NSTextField!
    @IBOutlet weak var namawaliTextField: NSTextField!
    @IBOutlet weak var NISN: NSTextField!
    @IBOutlet weak var ayah: NSTextField!
    @IBOutlet weak var ibu: NSTextField!
    @IBOutlet weak var tlv: NSTextField!
    // @IBOutlet weak var addData: NSButton!
    @IBOutlet weak var tutup: NSButton!
    @IBOutlet weak var showImageView: NSButton!
    @IBOutlet weak var pilihTanggal: ExpandingDatePicker!
    @IBOutlet weak var jenisPopUp: NSPopUpButton!
    @IBOutlet weak var popUpButton: NSPopUpButton!
    @IBOutlet weak var pilihFoto: NSButton!
    @IBOutlet weak var hLineTextField: NSBox!
    @IBOutlet weak var stackView: NSStackView!
    private let dbController = DatabaseController.shared
    private var kelasTable: Table?
    public var sourceViewController: SourceViewController?
    // AutoComplete Teks
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
    var enableDrag: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        namaSiswa.delegate = self
        ttlTextField.delegate = self
        alamatTextField.delegate = self
        namawaliTextField.delegate = self
        ayah.delegate = self
        ibu.delegate = self
        NIS.delegate = self
        NISN.delegate = self
        tlv.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let sourceViewController = sourceViewController {
            switch sourceViewController {
            case .kelasViewController:
                NotificationCenter.default.post(name: .popupDismissedKelas, object: nil)
            case .siswaViewController:
                NotificationCenter.default.post(name: .popupDismissed, object: nil)
            }
        }
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        imageView.isHidden = true
        hLineTextField.isHidden = true
        self.showImageView.state = .off
        stackView.layoutSubtreeIfNeeded()
        view.window?.setFrame(stackView.frame, display: true, animate: true)
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        if !enableDrag {
            imageView.enableDrag = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ReusableFunc.resetMenuItems()
        }
    }
    public func kelasTerpilih(index: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            popUpButton.selectItem(at: index)
        }
    }
    @IBAction func addButtonClicked(_ sender: Any) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let selectedOption = popUpButton.selectedItem?.title
        let nama = namaSiswa.stringValue.capitalizedAndTrimmed()
        guard !nama.isEmpty else {
            ReusableFunc.showAlert(title: "Nama Siswa Tidak Boleh Kosong", message: "Mohon isi nama siswa sebelum menyimpan.")
            return
        }
        let alamat = alamatTextField.stringValue.capitalizedAndTrimmed()
        let ttl = ttlTextField.stringValue.capitalizedAndTrimmed()
        let nis = NIS.stringValue
        let namawali = namawaliTextField.stringValue.capitalizedAndTrimmed()
        let jenisKelamin = jenisPopUp.selectedItem?.title ?? ""  // Mengambil nilai jenis kelamin dari popup
        let selectedImage = imageView.selectedImage
        let ayahNya = ayah.stringValue.capitalizedAndTrimmed()
        let ibuNya = ibu.stringValue.capitalizedAndTrimmed()
        let tlvValue = tlv.stringValue
        let compressedImageData = selectedImage?.compressImage(quality: 0.5) ?? Data()
        
        pilihTanggal.datePickerElements = .yearMonthDay
        pilihTanggal.datePickerMode = .single
        pilihTanggal.datePickerStyle = .textField
        pilihTanggal.sizeToFit()
        
            // Panggil addUser untuk menambahkan siswa dengan data gambar yang terkompresi
        dbController.catatSiswa(namaValue: nama, alamatValue: alamat, ttlValue: ttl, tahundaftarValue: dateFormatter.string(from: pilihTanggal.dateValue), namawaliValue: namawali, nisValue: nis, nisnValue: NISN.stringValue, namaAyah: ayahNya, namaIbu: ibuNya, jeniskelaminValue: jenisKelamin, statusValue: "Aktif", tanggalberhentiValue: "", kelasAktif: selectedOption ?? "", noTlv: tlvValue, fotoPath: compressedImageData)
        // Dapatkan nama tabel kelas yang dipilih dari NSPopUpButton
        let selectedKelas = selectedOption
        // Gunakan switch case untuk memanggil insertDataToKelas sesuai dengan pilihan kelas
        switch selectedKelas {
        case "Kelas 1":
            kelasTable = Table("kelas1")
        case "Kelas 2":
            kelasTable = Table("kelas2")
        case "Kelas 3":
            kelasTable = Table("kelas3")
        case "Kelas 4":
            kelasTable = Table("kelas4")
        case "Kelas 5":
            kelasTable = Table("kelas5")
        case "Kelas 6":
            kelasTable = Table("kelas6")
        default:
            break
        }
        // Memasukkan data ke tabel kelas sesuai dengan fungsi insertDataToKelas
        NotificationCenter.default.post(name: DatabaseController.siswaBaru, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ReusableFunc.resetMenuItems()
        }
    }
    @IBAction func showImageView(_ sender: Any) {
        if imageView.isHidden {
            imageView.isHidden = false
            hLineTextField.isHidden = false
            self.showImageView.state = .on
        }
        else {
            imageView.isHidden = true
            hLineTextField.isHidden = true
            self.showImageView.state = .off
        }
        self.stackView.layoutSubtreeIfNeeded()
        let newSize = self.stackView.fittingSize
        self.preferredContentSize = NSSize(width: self.view.bounds.width, height: newSize.height)
    }
    @IBAction func pilihFoto(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.tiff, .jpeg, .png]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        
        openPanel.beginSheetModal(for: self.view.window!) { [weak self] (response) in
            guard let self = self else { return }
            if response == NSApplication.ModalResponse.OK {
                if let imageURL = openPanel.urls.first {
                    self.imageView.setFrameSize(NSSize(width: self.imageView.frame.width, height: 171))
                    self.imageView.isHidden = true
                    self.hLineTextField.isHidden = true
                    do {
                        let imageData = try Data(contentsOf: imageURL)
                        
                        if let image = NSImage(data: imageData) {
                            // Atur properti NSImageView
                            self.imageView.imageScaling = .scaleProportionallyUpOrDown
                            self.imageView.imageAlignment = .alignCenter
                            
                            // Hitung proporsi aspek gambar
                            let aspectRatio = image.size.width / image.size.height
                            
                            // Hitung dimensi baru untuk gambar
                            let newWidth = min(self.imageView.frame.width, self.imageView.frame.height * aspectRatio)
                            let newHeight = newWidth / aspectRatio
                            
                            // Atur ukuran gambar sesuai proporsi aspek
                            image.size = NSSize(width: newWidth, height: newHeight)
                            // Setel gambar ke NSImageView
                            self.imageView.image = image
                            self.imageView.selectedImage = image
                            self.imageView.isHidden = false
                            self.hLineTextField.isHidden = false
                            self.showImageView.state = .on
                            self.stackView.layoutSubtreeIfNeeded()
                            let newSize = self.stackView.fittingSize
                            self.preferredContentSize = NSSize(width: self.view.bounds.width, height: newSize.height)
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    @IBAction func kapitalkan(_ sender: Any) {
        [namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv].kapitalkanSemua()
    }

    @IBAction func hurufBesar(_ sender: Any) {
        [namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv].hurufBesarSemua()
    }

    @IBAction func tutup(_ sender: Any) {
        if let window = self.view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                self.view.window?.performClose(sender)
            }
        }
    }
    enum SourceViewController {
        case kelasViewController
        case siswaViewController
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        imageView = nil
    }
}
extension AddDataViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        activeText = obj.object as? NSTextField
        let suggestionsDict: [NSTextField: [String]] = [
            namaSiswa: Array(ReusableFunc.namasiswa),
            alamatTextField: Array(ReusableFunc.alamat),
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return false}
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
