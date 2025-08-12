//
//  AddDataViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa

/// Class yang menangani logika penambahan data siswa.
class AddDataViewController: NSViewController {
    /// Outlet untuk menampilkan foto.
    /// Mendukung *drag and drop*.
    @IBOutlet weak var imageView: XSDragImageView!

    /// Outlet scrollView yang memuat field input dan tombol.
    @IBOutlet weak var scrollView: NSScrollView!

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
    private let dbController: DatabaseController = .shared

    /// Properti referensi untuk class yang menampilkan ``AddDataViewController``.
    var sourceViewController: SourceViewController?

    // AutoComplete Teks
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    private let placeholderImage = NSImage(named: "image")

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
        let shouldHide = (imageView.image === placeholderImage)
        imageView.isHidden = shouldHide
        imageView.enableDrag = !shouldHide
        hLineTextField.isHidden = shouldHide
        showImageView.state = shouldHide ? .off : .on
        updateStackViewSize(false)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.becomeFirstResponder()
        view.window?.becomeKey()
        view.window?.makeFirstResponder(namaSiswa)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        view.window?.resignFirstResponder()
        view.window?.resignKey()
    }

    /**
         Memilih kelas pada pop-up button setelah penundaan singkat.

         Fungsi ini memilih item pada pop-up button pada indeks yang diberikan setelah penundaan 0.3 detik.
         Penundaan ini dilakukan secara asinkron pada main thread.

         - Parameter:
            - index: Indeks item yang akan dipilih pada pop-up button.
     */
    func kelasTerpilih(index: Int) {
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
    @IBAction func addButtonClicked(_: Any) {
        Task {
            await insertSiswaKeDatabase()
        }
    }

    private func insertSiswaKeDatabase() async {
        guard let selectedOption = popUpButton.selectedItem?.title else { return }
        let nama = namaSiswa.stringValue.capitalizedAndTrimmed()
        guard !nama.isEmpty else {
            ReusableFunc.showAlert(title: "Nama Siswa Tidak Boleh Kosong", message: "Mohon isi nama siswa sebelum menyimpan.")
            return
        }
        let alamat = alamatTextField.stringValue.capitalizedAndTrimmed()
        let ttl = ttlTextField.stringValue.capitalizedAndTrimmed()
        let nis = NIS.stringValue
        let namawali = namawaliTextField.stringValue.capitalizedAndTrimmed()
        let jenisKelamin = jenisPopUp.selectedItem?.tag ?? 1
        let jenisKelaminEnum = JenisKelamin(rawValue: jenisKelamin) ?? .lakiLaki
        let selectedImage = imageView.selectedImage
        let ayahNya = ayah.stringValue.capitalizedAndTrimmed()
        let ibuNya = ibu.stringValue.capitalizedAndTrimmed()
        let tlvValue = tlv.stringValue
        let compressedImageData = selectedImage?.compressImage(quality: 0.5) ?? Data()
        let tahunDaftar = ReusableFunc.buatFormatTanggal(pilihTanggal.dateValue) ?? "10 April 2024"

        let dataSiswaUntukDicatat: SiswaDefaultData = (
            nama: nama,
            alamat: alamat,
            ttl: ttl,
            tahundaftar: tahunDaftar,
            namawali: namawali,
            nis: nis,
            nisn: NISN.stringValue,
            ayah: ayahNya,
            ibu: ibuNya,
            jeniskelamin: jenisKelaminEnum,
            status: .aktif,
            tanggalberhenti: "",
            tlv: tlvValue,
            foto: compressedImageData
        )

        guard let idSiswaBaru = dbController.catatSiswa(dataSiswaUntukDicatat) else {
            return
        }

        let siswaBaru = ModelSiswa(from: dataSiswaUntukDicatat, id: idSiswaBaru)
        siswaBaru.tingkatKelasAktif = KelasAktif(rawValue: selectedOption) ?? .kelas1

        let tingkatKelas = selectedOption.replacingOccurrences(of: "Kelas ", with: "")

        let tanggal = pilihTanggal.dateValue
        let calendar = Calendar.current
        let tahun = calendar.component(.year, from: tanggal)

        let tahunAjaran = "\(tahun)/\(tahun + 1)"

        await dbController.naikkanSiswa(idSiswaBaru, namaKelasBaru: "A", tingkatBaru: tingkatKelas, tahunAjaran: tahunAjaran, semester: "1", tanggalNaik: tahunDaftar)

        let userInfo: [String: Any] = [
            "siswaBaru": siswaBaru,
            "idSiswaBaru": idSiswaBaru,
        ]
        NotificationCenter.default.post(name: DatabaseController.siswaBaru, object: nil, userInfo: userInfo)

        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 Detik
        await MainActor.run {
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
    @IBAction func showImageView(_: Any) {
        if imageView.isHidden {
            imageView.isHidden = false
            hLineTextField.isHidden = false
            showImageView.state = .on
        } else {
            imageView.isHidden = true
            hLineTextField.isHidden = true
            showImageView.state = .off
        }
        updateStackViewSize()
    }

    /**
         Menampilkan panel buka file untuk memilih foto dari file di disk.

         Pengguna dapat memilih file dengan tipe konten yang diizinkan, seperti TIFF, JPEG, atau PNG.
         Setelah foto dipilih, foto akan ditampilkan di `imageView`, dan properti `imageView` akan diatur
         untuk menampilkan gambar secara proporsional di dalam batas `imageView`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func pilihFoto(_: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self else { return }
            if response == NSApplication.ModalResponse.OK {
                if let imageURL = openPanel.urls.first {
                    imageView.setFrameSize(NSSize(width: imageView.frame.width, height: 171))
                    imageView.isHidden = true
                    hLineTextField.isHidden = true
                    do {
                        let imageData = try Data(contentsOf: imageURL)

                        if let image = NSImage(data: imageData) {
                            imageView.imageNow = imageView.image

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
                            imageView.isHidden = false
                            hLineTextField.isHidden = false
                            showImageView.state = .on
                            DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                                self?.updateStackViewSize()
                            }
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }

    func updateStackViewSize(_ visualize: Bool = true, anchorRect: NSRect? = nil) {
        guard let window = view.window,
              let stack = stackView
        else { return }

        let topViewHeight: CGFloat = 60
        let bottomPadding: CGFloat = 20

        func calculateTargetFrame() -> NSRect {
            // 1) Toggle imageView visibility & opacity
            let willHideImage = imageView.isHidden
            imageView.animator().alphaValue = willHideImage ? 0 : 1

            // 2) Layout ulang stack
            stack.layoutSubtreeIfNeeded()

            // 3) Hitung total ukuran konten
            let fitting = stack.fittingSize
            let totalH = fitting.height + topViewHeight + bottomPadding
            let totalW = scrollView.contentSize.width

            // 4) Resize scrollView dulu (scrollable area)
            scrollView.setFrameSize(NSSize(
                width: window.frame.width - ((window.contentView?.frame.width ?? 0) - scrollView.frame.width),
                height: totalH - topViewHeight - bottomPadding
            ))

            // 5) Hitung frame baru untuk window
            let contentRect = NSRect(origin: .zero,
                                     size: NSSize(width: totalW, height: totalH))
            var newFrame = window.frameRect(forContentRect: contentRect)

            // 6) Tentukan origin.y berdasarkan anchor (menu‑bar button) atau default
            let screenVisible = window.screen?.visibleFrame
                ?? NSScreen.main!.visibleFrame
            let anchorY: CGFloat
            if let anchor = anchorRect {
                // pasang popover tepat di bawah anchor
                anchorY = anchor.minY - newFrame.height
            } else {
                // fallback: geser dari atas window sekarang
                let delta = window.frame.height - newFrame.height
                anchorY = window.frame.origin.y + delta
            }
            // pastikan tidak melewati batas atas/bawah layar
            let minY = screenVisible.minY
            let maxY = screenVisible.maxY - newFrame.height
            newFrame.origin.y = min(max(anchorY, minY), maxY)

            // tetap pakai x yang sama
            newFrame.origin.x = window.frame.origin.x

            // 7) Atur scrollers
            scrollView.hasVerticalScroller = (stack.fittingSize.height > scrollView.contentSize.height)
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = false
            scrollView.verticalScrollElasticity = .none

            return newFrame
        }

        let target = calculateTargetFrame()
        guard window.frame != target else { return }

        if visualize {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                window.setFrame(target, display: true, animate: true)
            }
        } else {
            window.setFrame(target, display: true, animate: false)
        }
    }

    /// Fungsi ini dipanggil ketika tombol untuk mengkapitalkan semua teks ditekan.
    /// Fungsi ini akan mengkapitalkan semua teks yang ada di dalam text field yang telah ditentukan.
    ///
    /// - Parameter sender: Objek yang mengirimkan aksi (tombol).
    @IBAction func kapitalkan(_: Any) {
        [namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv].kapitalkanSemua()
    }

    /**
        Fungsi ini dipanggil ketika tombol untuk mengubah semua teks menjadi huruf besar ditekan.
        Fungsi ini akan mengubah teks pada semua text field yang terdaftar (namaSiswa, alamatTextField, ttlTextField, NIS, namawaliTextField, NISN, ayah, ibu, tlv) menjadi huruf besar.

        - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func hurufBesar(_: Any) {
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
            AppDelegate.shared.updateUndoRedoMenu(for: AppDelegate.shared.mainWindow.contentViewController as! SplitVC)
        }
        resetForm(sender)
    }

    /**
         Enum yang merepresentasikan sumber View Controller.

         Digunakan untuk mengidentifikasi dari mana data berasal, apakah dari Kelas View Controller atau Siswa View Controller.
     */
    enum SourceViewController {
        case kelasViewController
        case siswaViewController
    }

    @IBAction private func resetForm(_: Any) {
        namaSiswa.stringValue = ""
        alamatTextField.stringValue = ""
        ttlTextField.stringValue = ""
        NIS.stringValue = ""
        namawaliTextField.stringValue = ""
        NISN.stringValue = ""
        ayah.stringValue = ""
        ibu.stringValue = ""
        tlv.stringValue = ""
        popUpButton.selectItem(at: 0)
        jenisPopUp.selectItem(at: 0)
        imageView.image = NSImage(named: "image")
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
            // Find the last word (after the last space)
            if let lastSpaceIndex = ReusableFunc.getLastLetterBeforeSpace(activeTextField.stringValue) {
                // Update the text field with only the last word
                suggestionManager.typing = lastSpaceIndex
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
        suggestionManager.controlTextField(control, textView: textView, doCommandBy: commandSelector)
    }
}
