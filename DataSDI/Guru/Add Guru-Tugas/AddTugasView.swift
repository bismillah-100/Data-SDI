//
//  AddTugasView.swift
//  Data SDI
//
//  Created by MacBook on 22/07/25.
//

import Cocoa

extension AddTugasGuruVC {
    /// Membuat dan mengatur tampilan input dinamis untuk menambah atau mengedit data guru maupun tugas guru.
    ///
    /// - Parameter opsi: ``AddGuruOrTugas`` yang menentukan mode tampilan
    /// - Parameter guru: Array dari ``GuruModel`` yang berisi data guru yang akan ditampilkan atau diedit.
    ///
    /// Fungsi ini membangun tampilan form secara dinamis menggunakan berbagai komponen NSView dan NSStackView,
    /// menyesuaikan label, input, dan kontrol berdasarkan opsi yang dipilih.
    /// Komponen yang dibuat meliputi:
    /// - Label judul yang berubah sesuai mode (tambah/edit guru/tugas)
    /// - Tombol kontrol untuk mengubah format teks
    /// - Input field (NSTextField) atau popup (NSPopUpButton) untuk data guru/tugas
    /// - Radio button untuk status tugas (aktif/nonaktif)
    /// - Date picker untuk tanggal mulai dan selesai tugas
    /// - StackView untuk tata letak vertikal dan horizontal
    /// - Tombol aksi "Simpan" dan "Tutup"
    ///
    /// Fungsi ini juga mengatur placeholder, nilai awal, dan status enable/disable komponen sesuai konteks.
    /// Data yang sudah ada akan dimuat ke field jika mode edit, dan field dikosongkan jika mode tambah.
    ///
    func createView(_ opsi: AddGuruOrTugas, guru: [GuruModel]) {
        // Root visual effect
        let rootView = NSVisualEffectView()
        // Penting: Anda perlu mengatur translatesAutoresizingMaskIntoConstraints menjadi false
        // untuk rootView karena Anda akan menggunakan Auto Layout untuk itu.
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.blendingMode = .behindWindow
        rootView.material = .windowBackground
        rootView.state = .followsWindowActiveState
        view = rootView

        let enableControl = opsi == .tambahTugas ? true : false
        // Label Title
        var labelString = ""
        if opsi == .tambahGuru {
            labelString = "Masukkan Informasi Guru"
        } else if opsi == .editGuru {
            labelString = "Perbarui Data Guru"
        } else if opsi == .tambahTugas {
            labelString = "Masukkan Informasi Tugas"
        } else if opsi == .editTugas {
            labelString = "Perbarui Informasi Tugas"
        }

        let hStackTop = NSStackView()
        applyStackViewStyle(hStackTop, orientation: .horizontal, alignment: .bottom)

        let hStackTitle = NSStackView()
        applyStackViewStyle(hStackTitle, orientation: .horizontal, alignment: .bottom)

        let hStackButton = NSStackView()
        applyStackViewStyle(hStackButton, orientation: .horizontal, alignment: .bottom, spacing: 0)

        let titleLabel = NSTextField(labelWithString: labelString)
        titleLabel.font = NSFont.preferredFont(forTextStyle: .title1)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        hStackTitle.addArrangedSubview(titleLabel)

        let uppercaseButton = NSButton(image: NSImage(systemSymbolName: "character", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(hurufBesar(_:)))
        uppercaseButton.contentTintColor = .controlAccentColor
        uppercaseButton.isBordered = false
        uppercaseButton.bezelStyle = .smallSquare
        uppercaseButton.translatesAutoresizingMaskIntoConstraints = false
        hStackButton.addArrangedSubview(uppercaseButton)

        // Tombol kontrol (hanya dibuat sekali)
        let kapitalButton = NSButton(image: NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)!.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!, target: self, action: #selector(kapitalkan(_:)))
        kapitalButton.contentTintColor = .controlAccentColor
        kapitalButton.isBordered = false
        kapitalButton.bezelStyle = .smallSquare
        kapitalButton.translatesAutoresizingMaskIntoConstraints = false
        hStackButton.addArrangedSubview(kapitalButton)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        // StackView root vertical
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        applyStackViewStyle(stackView, orientation: .vertical, alignment: .leading, distribution: .fillEqually, spacing: 16)

        // Tambahkan title label dan button ke stackView
        hStackTop.addArrangedSubview(hStackTitle)

        hStackTop.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        hStackTop.addArrangedSubview(hStackButton)
        stackView.addArrangedSubview(hStackTop)

        let sep = NSBox()
        sep.boxType = .separator
        stackView.addArrangedSubview(sep)

        let labelInputVStack = NSStackView()
        labelInputVStack.translatesAutoresizingMaskIntoConstraints = false
        applyStackViewStyle(labelInputVStack, orientation: .vertical, alignment: .leading, distribution: .fillEqually, spacing: 8)

        // Loop fieldNames
        for (i, labelText) in fieldNames.enumerated() {
            let hStack = NSStackView()
            applyStackViewStyle(hStack, orientation: .horizontal, alignment: .centerY, distribution: .fill, spacing: 8)

            let label = NSTextField(labelWithString: labelText == "NamaPopup" ? "Nama Guru" : labelText)
            label.alignment = .left
            label.widthAnchor.constraint(equalToConstant: 100).isActive = true

            hStack.addArrangedSubview(label)

            if labelText != "NamaPopup", labelText != "Sebagai:" {
                let textField = NSTextField()
                applyTextFieldStyle(textField, placeHolder: labelText, identifier: labelText)
                textField.delegate = self

                textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
                textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                // Kalau mau biar pasti fill HStack
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

                // Simpan referensi textField pada property kelas
                if options == .tambahGuru || options == .editGuru {
                    switch i {
                    case 0: nameTextField = textField
                    case 1: addressTextField = textField
                    default: break
                    }
                } else {
                    mapelTextField = textField
                }

                hStack.addArrangedSubview(textField)
                // Assign kalau mau simpan ke property
            } else {
                let popupButton = NSPopUpButton()
                let newOpt = NSMenuItem(title: "Tambah...", action: #selector(buatMenuPopUp(_:)), keyEquivalent: "")
                var dataa: [(Int64, String)] = []
                Task(priority: .background) { [weak self] in
                    guard let self else { return }
                    if labelText == "NamaPopup" {
                        namaPopUpButton = popupButton
                        newOpt.representedObject = CategoryType.guru
                        namaPopUpButton.isEnabled = enableControl
                        if dataToEdit.count > 1 {
                            let title = "memuat \(dataToEdit.count) data..."
                            namaPopUpButton.addItem(withTitle: title)
                            namaPopUpButton.selectItem(withTitle: title)
                        } else {
                            dataa = await dbController.fetchGuruDanID()
                        }
                    } else if labelText == "Sebagai:" {
                        jabatanPopUpButton = popupButton
                        newOpt.representedObject = CategoryType.jabatan
                        if dataToEdit.count > 1 {
                            let title = "memuat \(dataToEdit.count) data..."
                            jabatanPopUpButton.addItem(withTitle: title)
                            jabatanPopUpButton.selectItem(withTitle: title)
                            jabatanPopUpButton.isEnabled = false
                        } else {
                            let cache = await IdsCacheManager.shared.jabatanCache
                            dataa = cache.map { namaJabatan, jabatanID in
                                (jabatanID, namaJabatan)
                            }
                        }
                    }
                    guard dataToEdit.count <= 1 else { return }
                    for data in dataa.sorted(by: { $0.1 < $1.1 }) {
                        popupButton.addItem(withTitle: data.1)
                        popupButton.lastItem?.tag = Int(data.0)
                        if dataToEdit.count == 1,
                           dataToEdit.first!.struktural == data.1 ||
                           dataToEdit.first!.namaGuru == data.1
                        {
                            popupButton.selectItem(withTitle: data.1)
                        }
                    }

                    popupButton.menu?.addItem(.separator())
                    newOpt.target = self
                    newOpt.tag = 0
                    popupButton.menu?.addItem(newOpt)
                }
                hStack.addArrangedSubview(popupButton)
                popupButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
                popupButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                // Kalau mau biar pasti fill HStack
                popupButton.translatesAutoresizingMaskIntoConstraints = false
                popupButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
            }

            labelInputVStack.addArrangedSubview(hStack)
            NSLayoutConstraint.activate([
                hStack.leadingAnchor.constraint(equalTo: labelInputVStack.leadingAnchor, constant: 0),
                hStack.trailingAnchor.constraint(equalTo: labelInputVStack.trailingAnchor, constant: 0),
            ])
        }

        stackView.addArrangedSubview(labelInputVStack)

        // Tombol simpan dan batal
        let buttonStack = NSStackView()
        applyStackViewStyle(buttonStack, orientation: .horizontal, alignment: .centerY, distribution: .fill, spacing: 10)

        let simpanButton = NSButton(title: "Simpan", target: self, action: #selector(simpanGuru(_:)))
        simpanButton.keyEquivalent = "\r" // enter key
        simpanButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let batalButton = NSButton(title: "Tutup", target: self, action: #selector(tutupSheet(_:)))
        batalButton.keyEquivalent = "\u{1b}" // escape key
        batalButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        buttonStack.addArrangedSubview(batalButton)
        buttonStack.addArrangedSubview(simpanButton)

        let (topStts, hStackStatus, separatorTglMulai, hStackTgl) = createStackViewStatus()

        if let topStts,
           let hStackStatus,
           let separatorTglMulai,
           let hStackTgl
        {
            stackView.addArrangedSubview(topStts)

            stackView.addArrangedSubview(hStackStatus)

            stackView.addArrangedSubview(separatorTglMulai)

            stackView.addArrangedSubview(hStackTgl)
        }

        let (hStackKelas, hStackKelasInput, sepr) = createHStackKelas()
        let vStackKelas = createVStackKelas()
        if let sepr, let vStackKelas, let hStackKelas, let hStackKelasInput {
            stackView.addArrangedSubview(sepr)

            vStackKelas.insertArrangedSubview(hStackKelasInput, at: 0)
            hStackKelas.addArrangedSubview(vStackKelas)
            stackView.addArrangedSubview(hStackKelas)
        }

        let separator = NSBox()
        separator.boxType = .separator
        stackView.addArrangedSubview(separator)

        stackView.addArrangedSubview(buttonStack)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -20),

            hStackTop.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 0),
            hStackTop.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 0),
            hStackTop.heightAnchor.constraint(equalToConstant: 28),

            kapitalButton.widthAnchor.constraint(equalToConstant: 24),
            kapitalButton.heightAnchor.constraint(equalToConstant: 11),
            kapitalButton.bottomAnchor.constraint(equalTo: hStackButton.bottomAnchor, constant: -6),
            kapitalButton.trailingAnchor.constraint(equalTo: hStackButton.trailingAnchor, constant: 0),

            uppercaseButton.trailingAnchor.constraint(equalTo: uppercaseButton.leadingAnchor, constant: 0),
            uppercaseButton.bottomAnchor.constraint(equalTo: hStackButton.bottomAnchor, constant: -5),
            uppercaseButton.widthAnchor.constraint(equalToConstant: 18),
            uppercaseButton.heightAnchor.constraint(equalToConstant: 12),

            labelInputVStack.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 0),
            labelInputVStack.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0),

            buttonStack.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0),
        ])

        if let hStackKelas {
            NSLayoutConstraint.activate([
                hStackKelas.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 0),
                hStackKelas.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0),
            ])
        }

        // Ketika pilihan adalah edit.
        if opsi == .editGuru {
            if guru.count > 1 {
                nameTextField.placeholderString = "memuat \(guru.count) data"
                addressTextField.placeholderString = "memuat \(guru.count) data"
            } else if let guruData = guru.first {
                nameTextField.stringValue = guruData.namaGuru
                addressTextField.stringValue = guruData.alamatGuru ?? ""
            }
        } else if opsi == .tambahGuru {
            // Ketika pilihan adalah tambah data.
            nameTextField.stringValue = ""
            addressTextField.stringValue = ""
            nameTextField.placeholderString = "ketik nama guru"
            addressTextField.placeholderString = "ketik alamat guru"
        } else if opsi == .editTugas {
            if guru.count > 1 {
                mapelTextField.placeholderString = "memuat \(guru.count) data"
            } else if let guruData = guru.first {
                mapelTextField.stringValue = guruData.mapel ?? ""
                mapelTextField.placeholderString = "ketik mata pelajaran"
            }
        } else if opsi == .tambahTugas {
            mapelTextField.placeholderString = "ketik mata pelajaran"
        }
    }

    /// Menerapkan gaya khusus pada `NSTextField`.
    ///
    /// - Parameter textField: Objek `NSTextField` yang akan diberikan gaya.
    /// - Parameter placeHolder: Teks placeholder yang akan ditampilkan pada text field.
    /// - Parameter identifier: Identifier unik untuk text field.
    /// - Parameter alignment: (Opsional) Pengaturan perataan teks dalam text field. Default adalah `.left`.
    func applyTextFieldStyle(_ textField: NSTextField, placeHolder: String, identifier: String, alignment: NSTextAlignment? = .left) {
        textField.placeholderString = placeHolder
        textField.bezelStyle = .roundedBezel
        textField.lineBreakMode = .byTruncatingTail
        textField.isEditable = true
        textField.usesSingleLineMode = true
        textField.identifier = .init(identifier)
        if let alignment {
            textField.alignment = alignment
        }
    }

    /// Menerapkan gaya pada `NSStackView` dengan mengatur orientasi, alignment, distribusi, dan jarak antar elemen stack.
    /// - Parameters:
    ///   - stackView: Objek `NSStackView` yang akan diberikan gaya.
    ///   - orientation: Orientasi stack view (horizontal atau vertikal).
    ///   - alignment: Alignment elemen-elemen di dalam stack view.
    ///   - distribution: (Opsional) Distribusi elemen di dalam stack view.
    ///   - spacing: (Opsional) Jarak antar elemen di dalam stack view.
    func applyStackViewStyle(_ stackView: NSStackView, orientation: NSUserInterfaceLayoutOrientation, alignment: NSLayoutConstraint.Attribute, distribution: NSStackView.Distribution? = nil, spacing: CGFloat? = nil) {
        stackView.orientation = orientation
        stackView.alignment = alignment
        if let distribution {
            stackView.distribution = distribution
        }
        if let spacing {
            stackView.spacing = spacing
        }
    }

    /// Membuat dan mengatur tampilan stack view yang menampilkan status penugasan guru serta pilihan tanggal mulai dan selesai.
    /// Fungsi ini digunakan saat mode .tambahTugas atau .editTugas.
    /// - Returns: Tuple yang berisi empat komponen view. **`NSBox?`** Separator atas untuk memperjelas batas visual bagian.
    /// **`NSStackView?`** Stack view horizontal berisi label "Status Tugas" dan dua pilihan status (`Aktif` / `Nonaktif`).
    /// **`NSBox?`** Separator vertikal antara komponen tanggal.
    /// **`NSStackView?`** Stack view horizontal berisi label dan date picker untuk "Tgl. Mulai" dan "Tgl. Selesai".
    func createStackViewStatus() -> (NSBox?, NSStackView?, NSBox?, NSStackView?) {
        guard options == .tambahTugas || options == .editTugas else {
            return (nil, nil, nil, nil)
        }
        let hStackStatus = NSStackView()
        applyStackViewStyle(hStackStatus, orientation: .horizontal, alignment: .top, spacing: 8)
        let titleStatus = NSTextField(labelWithString: "Status Tugas:")
        titleStatus.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        hStackStatus.addArrangedSubview(titleStatus)

        let vStackStatus = NSStackView()
        applyStackViewStyle(vStackStatus, orientation: .vertical, alignment: .leading, spacing: 6)
        aktifSttsButton = NSButton(radioButtonWithTitle: "Aktif", target: self, action: #selector(ubahStatus(_:)))
        nonAktifSttsButton = NSButton(radioButtonWithTitle: "Selesai", target: self, action: #selector(ubahStatus(_:)))
        vStackStatus.addArrangedSubview(aktifSttsButton)
        vStackStatus.addArrangedSubview(nonAktifSttsButton)

        hStackStatus.addArrangedSubview(vStackStatus)

        let separatorTglMulai = NSBox()
        separatorTglMulai.boxType = .separator

        let hStackTgl = NSStackView()
        applyStackViewStyle(hStackTgl, orientation: .horizontal, alignment: .centerY, spacing: 1)

        let titleTglMulai = NSButton()
        let attrTitle = NSMutableAttributedString(string: "Tgl. Mulai:")
        attrTitle.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: attrTitle.length))
        titleTglMulai.attributedTitle = attrTitle
        titleTglMulai.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        titleTglMulai.isBordered = false
        if dataToEdit.count >= 1 {
            titleTglMulai.setButtonType(.switch)
            titleTglMulai.action = #selector(enableTanggalMulai(_:))
            titleTglMulai.target = self
            if dataToEdit.count == 1 {
                titleTglMulai.state = .on
            } else {
                titleTglMulai.state = .off
            }
        }
        hStackTgl.addArrangedSubview(titleTglMulai)

        func setDateValue(_ tgl: String) -> Date {
            if dataToEdit.count == 1,
               let date = ReusableFunc.dateFormatter?.date(from: tgl)
            {
                date
            } else {
                Date()
            }
        }

        tanggalMulai = ExpandingDatePicker(frame: .zero)
        // Required settings...
        tanggalMulai.datePickerElements = .yearMonthDay
        tanggalMulai.datePickerMode = .single
        tanggalMulai.datePickerStyle = .textField
        tanggalMulai.drawsBackground = false
        tanggalMulai.isBezeled = false
        tanggalMulai.dateValue = setDateValue(dataToEdit.first?.tglMulai ?? "")
        tanggalMulai.sizeToFit()
        tanggalMulai.isEnabled = dataToEdit.count == 1
        hStackTgl.addArrangedSubview(tanggalMulai)
        tanggalMulai.topAnchor.constraint(equalTo: titleTglMulai.topAnchor, constant: 3).isActive = true
        hStackTgl.setCustomSpacing(10, after: tanggalMulai)

        let verticalBoxTgl = NSBox()
        verticalBoxTgl.boxType = .separator
        verticalBoxTgl.widthAnchor.constraint(equalToConstant: 1).isActive = true
        verticalBoxTgl.heightAnchor.constraint(equalToConstant: 16).isActive = true
        hStackTgl.addArrangedSubview(verticalBoxTgl)
        hStackTgl.setCustomSpacing(10, after: verticalBoxTgl)

        let titleTglSelesai = NSButton()
        let attrTitle1 = NSMutableAttributedString(string: "Tgl. Selesai:")
        attrTitle1.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: attrTitle.length))
        titleTglSelesai.attributedTitle = attrTitle1
        titleTglSelesai.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        titleTglSelesai.isBordered = false

        hStackTgl.addArrangedSubview(titleTglSelesai)

        tanggalSelesai = ExpandingDatePicker(frame: .zero)
        // Required settings...
        tanggalSelesai.datePickerElements = .yearMonthDay
        tanggalSelesai.datePickerMode = .single
        tanggalSelesai.datePickerStyle = .textField
        tanggalSelesai.drawsBackground = false
        tanggalSelesai.isBezeled = false
        tanggalSelesai.isEnabled = statusTugas ? true : false
        tanggalSelesai.dateValue = setDateValue(dataToEdit.first?.tglSelesai ?? "")
        tanggalSelesai.sizeToFit()
        hStackTgl.addArrangedSubview(tanggalSelesai)
        tanggalSelesai.topAnchor.constraint(equalTo: titleTglSelesai.topAnchor, constant: 3).isActive = true

        let topSepr = NSBox()
        topSepr.boxType = .separator
        return (topSepr, hStackStatus, separatorTglMulai, hStackTgl)
    }

    /// Membuat dan mengembalikan `NSStackView` vertikal yang berisi `NSPopUpButton` untuk memilih semester.
    ///
    /// Fungsi ini hanya dijalankan jika `options` bernilai .tambahTugas.
    /// - Stack view akan diatur dengan orientasi vertikal, alignment leading, distribusi fill, dan spacing 8.
    /// - `NSPopUpButton` akan diisi dengan daftar semester yang diambil dari database tabel "kelas".
    /// - Jika sedang mengedit data (`dataToEdit.count == 1`), maka semester yang sesuai akan otomatis dipilih.
    /// - Menambahkan opsi "Tambah..." di akhir menu popup untuk menambah semester baru, beserta separator.
    /// - Mengatur constraint trailing popup ke trailing stack view.
    /// - Mengembalikan stack view yang sudah terisi, atau `nil` jika syarat tidak terpenuhi.
    /// - Nilai popup button juga disimpan ke properti `semesterPopUpButton`.
    ///
    /// - Returns: `NSStackView` berisi popup semester, atau `nil` jika `options` tidak sesuai.
    func createVStackKelas() -> NSStackView? {
        guard options == .tambahTugas else {
            return nil
        }
        let vStackKelas = NSStackView()
        applyStackViewStyle(vStackKelas, orientation: .vertical, alignment: .leading, distribution: .fill, spacing: 8)

        let popupSemester = NSPopUpButton()
        let newSemOpt = NSMenuItem(title: "Tambah...", action: #selector(buatMenuPopUp(_:)), keyEquivalent: "")
        newSemOpt.target = self
        newSemOpt.representedObject = CategoryType.semester
        let options = dbController.fetchSemesters()
        for sem in options {
            popupSemester.addItem(withTitle: sem)
            if dataToEdit.count == 1 {
                let full = dataToEdit.first!.kelas ?? ""
                // Coba en‐dash dulu, baru hyphen
                let semesterPart = ReusableFunc.selectComponentString(full, separator: "-", selectPart: 1)
                if sem == semesterPart {
                    popupSemester.selectItem(withTitle: sem)
                }
            }
        }

        // separator dan newSemOpt tetap ditambahkan terpisah jika perlu
        popupSemester.menu?.addItem(NSMenuItem.separator())
        popupSemester.menu?.addItem(newSemOpt)
        semesterPopUpButton = popupSemester

        vStackKelas.addArrangedSubview(popupSemester)
        popupSemester.trailingAnchor.constraint(equalTo: vStackKelas.trailingAnchor, constant: 0).isActive = true
        return vStackKelas
    }

    /// Membuat dan mengembalikan tiga komponen tampilan untuk input data kelas, tahun ajaran, dan semester pada tampilan tambah tugas guru.
    ///
    /// - Returns: Tuple berisi tiga elemen:
    ///   - `NSStackView?`: Stack horizontal utama yang berisi label judul.
    ///   - `NSStackView?`: Stack horizontal untuk input kelas, bagian kelas, tahun ajaran, dan semester.
    ///   - `NSBox?`: Separator vertikal sebagai pemisah antar komponen.
    ///
    /// Fungsi ini hanya dijalankan jika `options` bernilai .tambahTugas. Komponen yang dibuat meliputi:
    /// - Label judul "Kelas, Tahun Ajaran, dan Semester:"
    /// - Popup kelas yang diisi secara asinkron dari database
    /// - Popup bagian kelas (A, B, C)
    /// - Text field tahun ajaran (dua buah, misal: 2024/2025)
    /// - Separator vertikal dan horizontal
    /// - Pengisian otomatis nilai jika sedang dalam mode edit data
    func createHStackKelas() -> (NSStackView?, NSStackView?, NSBox?) {
        guard options == .tambahTugas else {
            return (nil, nil, nil)
        }
        let hStackKelas = NSStackView()
        applyStackViewStyle(hStackKelas, orientation: .horizontal, alignment: .top, distribution: .fill, spacing: 8)

        let hStackKelasInput = NSStackView()
        applyStackViewStyle(hStackKelasInput, orientation: .horizontal, alignment: .centerY, distribution: .fill, spacing: 8)

        let titleKelas = NSTextField(wrappingLabelWithString: "Kelas, Tahun Ajaran, dan Semester:")
        titleKelas.isEditable = false
        titleKelas.widthAnchor.constraint(equalToConstant: 100).isActive = true
        hStackKelas.addArrangedSubview(titleKelas)

        let popupKelas = NSPopUpButton()
        popupKelas.alignment = .left
        Task(priority: .background) {
            let dataKelas = await dbController.fetchKelas()
            for data in dataKelas.sorted(by: { $0.1 < $1.1 }) {
                popupKelas.addItem(withTitle: data.1)
                if dataToEdit.count == 1,
                   let kelas = dataToEdit.first?.kelas,
                   kelas.first.map(String.init) == data.1
                {
                    popupKelas.selectItem(withTitle: data.1)
                }
            }
        }
        kelasPopUpButton = popupKelas
        popupKelas.widthAnchor.constraint(equalToConstant: 38).isActive = true
        hStackKelasInput.addArrangedSubview(popupKelas)

        let popupBagKls = NSPopUpButton()
        popupBagKls.bezelStyle = .smallSquare
        popupBagKls.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let items = ["A", "B", "C"]
        for i in 0 ..< items.count {
            popupBagKls.addItem(withTitle: items[i])
            if dataToEdit.count == 1 {
                let selectedBag = dataToEdit.first.flatMap { full -> String? in
                    return ReusableFunc.selectComponentString(full.kelas ?? "", separator: "–", selectPart: 0, wordIndex: 1)
                }
                if let sel = selectedBag, sel == items[i] {
                    popupBagKls.selectItem(withTitle: sel)
                }
            }
        }
        bagianKelasPopUpButton = popupBagKls
        popupBagKls.widthAnchor.constraint(equalToConstant: 28).isActive = true
        hStackKelasInput.addArrangedSubview(popupBagKls)

        let verticalBox = NSBox()
        verticalBox.boxType = .separator
        verticalBox.widthAnchor.constraint(equalToConstant: 1).isActive = true
        verticalBox.heightAnchor.constraint(equalToConstant: 16).isActive = true
        hStackKelasInput.addArrangedSubview(verticalBox)

        tahunAjaran1TextField = NSTextField()
        tahunAjaran1TextField.delegate = self
        applyTextFieldStyle(tahunAjaran1TextField, placeHolder: "2024", identifier: "thnAjrn1", alignment: .center)
        tahunAjaran1TextField.widthAnchor.constraint(equalToConstant: 58).isActive = true
        tahunAjaran1TextField.alignment = .center
        if dataToEdit.count == 1 {
            tahunAjaran1TextField.stringValue = ReusableFunc.selectComponentString(dataToEdit.first!.tahunaktif ?? "", separator: "/", selectPart: 0)
        }
        hStackKelasInput.addArrangedSubview(tahunAjaran1TextField)

        let slash = NSTextField(labelWithString: "/")
        slash.isEditable = false
        slash.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        slash.widthAnchor.constraint(equalToConstant: 4).isActive = true
        hStackKelasInput.addArrangedSubview(slash)

        tahunAjaran2TextField = NSTextField()
        applyTextFieldStyle(tahunAjaran2TextField, placeHolder: "2025", identifier: "thnAjrn2", alignment: .center)
        tahunAjaran2TextField.widthAnchor.constraint(equalToConstant: 58).isActive = true
        tahunAjaran2TextField.alignment = .center
        if dataToEdit.count == 1 {
            tahunAjaran2TextField.stringValue = ReusableFunc.selectComponentString(dataToEdit.first!.tahunaktif ?? "", separator: "/", selectPart: 1)
        }
        hStackKelasInput.addArrangedSubview(tahunAjaran2TextField)

        hStackKelasInput.setCustomSpacing(3, after: tahunAjaran1TextField)
        hStackKelasInput.setCustomSpacing(3, after: slash)

        let sepr = NSBox()
        sepr.boxType = .separator

        return (hStackKelas, hStackKelasInput, sepr)
    }
}
