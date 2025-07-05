//
//  AddDataViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa
import SQLite

/// Class yang menangani logika penambahan data siswa.
class AddDataViewController: NSViewController {
    /// Outlet untuk menampilkan foto.
    /// Mendukung *drag and drop*.
    @IBOutlet weak var imageView: XSDragImageView!

    // MARK: - TEXTFIELD

    /// Outlet untuk pengetikan nama siswa.
    @IBOutlet weak var namaSiswa: NSTextField!
    /// Outlet untuk pengetikan alamat.
    @IBOutlet weak var alamatTextField: NSTextField!
    /// Outlet untuk pengetikan tempat tanggal lahir.
    @IBOutlet weak var ttlTextField: NSTextField!
    /// Outlet untuk pengetikan NIS.
    @IBOutlet weak var NIS: NSTextField!
    /// Outlet untuk pengetikan nama wali.
    @IBOutlet weak var namawaliTextField: NSTextField!
    /// Outlet untuk pengetikan NISN.
    @IBOutlet weak var NISN: NSTextField!
    /// Outlet untuk pengetikan ayah.
    @IBOutlet weak var ayah: NSTextField!
    /// Outlet untuk pengetikan ibu.
    @IBOutlet weak var ibu: NSTextField!
    /// Outlet untuk pengetikan nomor telepon.
    @IBOutlet weak var tlv: NSTextField!

    // MARK: - TOMBOL

    /// Outlet tombol "batalkan".
    @IBOutlet weak var tutup: NSButton!
    /// Outlet tombol ">" untuk menampilkan/menyembunyikan foto.
    @IBOutlet weak var showImageView: NSButton!
    /// Outlet tombol pemilihan tanggal pendaftaran.
    @IBOutlet weak var pilihTanggal: ExpandingDatePicker!
    /// Outlet menu popup pilihan jenis kelamin.
    @IBOutlet weak var jenisPopUp: NSPopUpButton!
    /// Outlet menu popup pilihan kelas aktif.
    @IBOutlet weak var popUpButton: NSPopUpButton!
    /// Outlet tombol "foto".
    @IBOutlet weak var pilihFoto: NSButton!
    /// Outlet garis horizontal di atas nama siswa.
    @IBOutlet weak var hLineTextField: NSBox!
    /// Outlet stackView yang memuat seluruh elemen view.
    @IBOutlet weak var stackView: NSStackView!

    /// Instans ``DatabaseController``.
    private let dbController = DatabaseController.shared

    /// Properti untuk referensi tabel di database.
    private var kelasTable: Table?

    /// Properti referensi untuk class yang menampilkan ``AddDataViewController``.
    public var sourceViewController: SourceViewController?

    // AutoComplete Teks
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

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
        if let sourceViewController {
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
        showImageView.state = .off
        stackView.layoutSubtreeIfNeeded()
        view.window?.setFrame(stackView.frame, display: true, animate: true)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        imageView.enableDrag = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ReusableFunc.resetMenuItems()
        }
    }

    /**
         Memilih kelas pada pop-up button setelah penundaan singkat.

         Fungsi ini memilih item pada pop-up button pada indeks yang diberikan setelah penundaan 0.3 detik.
         Penundaan ini dilakukan secara asinkron pada main thread.

         - Parameter:
            - index: Indeks item yang akan dipilih pada pop-up button.
     */
    public func kelasTerpilih(index: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
            popUpButton.selectItem(at: index)
        }
    }

    /**
     Menangani aksi ketika tombol "Tambah" diklik. Fungsi ini mengumpulkan data dari input pengguna,
     memvalidasi nama siswa, mengompresi gambar yang dipilih, dan menyimpan data siswa ke database.
     Selain itu, data juga dimasukkan ke tabel kelas yang sesuai berdasarkan pilihan pengguna.

     - Parameter sender: Objek yang mengirimkan aksi (tombol "Tambah").
     */
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
        let jenisKelamin = jenisPopUp.selectedItem?.title ?? ""
        let jenisKelaminEnum = JenisKelamin(rawValue: jenisKelamin) ?? .lakiLaki
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
        dbController.catatSiswa(namaValue: nama, alamatValue: alamat, ttlValue: ttl, tahundaftarValue: dateFormatter.string(from: pilihTanggal.dateValue), namawaliValue: namawali, nisValue: nis, nisnValue: NISN.stringValue, namaAyah: ayahNya, namaIbu: ibuNya, jeniskelaminValue: jenisKelaminEnum.rawValue, statusValue: StatusSiswa.aktif.rawValue, tanggalberhentiValue: "", kelasAktif: selectedOption ?? "", noTlv: tlvValue, fotoPath: compressedImageData)
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

    /**
     Menampilkan atau menyembunyikan tampilan gambar dan garis horizontal di bawahnya.

     Saat tampilan gambar tersembunyi, fungsi ini akan menampilkannya beserta garis horizontal.
     Sebaliknya, jika tampilan gambar terlihat, fungsi ini akan menyembunyikannya beserta garis horizontal.
     Fungsi ini juga memperbarui status tombol `showImageView` dan menyesuaikan ukuran preferred content size dari stack view.

     - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol atau gesture recognizer).
     */
    @IBAction func showImageView(_ sender: Any) {
        if imageView.isHidden {
            imageView.isHidden = false
            hLineTextField.isHidden = false
            showImageView.state = .on
        } else {
            imageView.isHidden = true
            hLineTextField.isHidden = true
            showImageView.state = .off
        }
        stackView.layoutSubtreeIfNeeded()
        let newSize = stackView.fittingSize
        preferredContentSize = NSSize(width: view.bounds.width, height: newSize.height)
    }

    /**
         Menampilkan panel buka file untuk memilih foto dari file di disk.

         Pengguna dapat memilih file dengan tipe konten yang diizinkan, seperti TIFF, JPEG, atau PNG.
         Setelah foto dipilih, foto akan ditampilkan di `imageView`, dan properti `imageView` akan diatur
         untuk menampilkan gambar secara proporsional di dalam batas `imageView`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func pilihFoto(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self else { return }
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
                            updateStackViewSize()
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// Fungsi untuk memperbarui stackView ketika gambar dtambahkan.
    func updateStackViewSize() {
        self.imageView.isHidden = false
        self.hLineTextField.isHidden = false
        self.showImageView.state = .on
        self.stackView.layoutSubtreeIfNeeded()
        let newSize = self.stackView.fittingSize
        self.preferredContentSize = NSSize(width: self.view.bounds.width, height: newSize.height)
    }

    /// Fungsi ini dipanggil ketika tombol untuk mengkapitalkan semua teks ditekan.
    /// Fungsi ini akan mengkapitalkan semua teks yang ada di dalam text field yang telah ditentukan.
    ///
    /// - Parameter sender: Objek yang mengirimkan aksi (tombol).
    @IBAction func kapitalkan(_ sender: Any) {
        [namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv].kapitalkanSemua()
    }

    /**
        Fungsi ini dipanggil ketika tombol untuk mengubah semua teks menjadi huruf besar ditekan.
        Fungsi ini akan mengubah teks pada semua text field yang terdaftar (namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv) menjadi huruf besar.

        - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func hurufBesar(_ sender: Any) {
        [namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv].hurufBesarSemua()
    }

    /// Action untuk menutup tampilan ``AddDataViewController``.
    /// - Parameter sender: Objek apapun dapat memicu.
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                view.window?.performClose(sender)
            }
        }
    }

    /**
         Enum yang merepresentasikan sumber View Controller.

         Digunakan untuk mengidentifikasi dari mana data berasal, apakah dari Kelas View Controller atau Siswa View Controller.
     */
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
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        if textField == namaSiswa, !textField.stringValue.isEmpty {
            imageView.nama = textField.stringValue
        } else {
            imageView.nama = nil
        }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
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
            tlv: Array(ReusableFunc.tlvString),
        ]
        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return false }
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
