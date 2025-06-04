import Cocoa
import SQLite

class AddDetaildiKelas: NSViewController {
    @IBOutlet weak var mapelTextField: NSTextField!
    @IBOutlet weak var nilaiTextField: NSTextField!
    @IBOutlet weak var guruMapel: NSTextField!
    @IBOutlet weak var namaPopUpButton: NSPopUpButton!
    @IBOutlet weak var smstrPopUpButton: NSPopUpButton!
    @IBOutlet weak var kelasPopUpButton: NSPopUpButton!
    @IBOutlet weak var ok: NSButton!
    @IBOutlet weak var simpan: NSButton!
    @IBOutlet weak var pilihTgl: ExpandingDatePicker!
    var windowIdentifier: String?
    let dbController = DatabaseController.shared
    var dataArray: [(index: Int, data: KelasModels)] = []
    var tableDataArray: [(table: Table, id: Int64)] = []
    let kelas1 = Table("kelas1")
    let kelas2 = Table("kelas2")
    let kelas3 = Table("kelas3")
    let kelas4 = Table("kelas4")
    let kelas5 = Table("kelas5")
    let kelas6 = Table("kelas6")
    var appDelegate: Bool = false
    @IBOutlet var smstrBaruTextField: NSTextField!
    @IBOutlet weak var jumlahMapel: NSTextField!
    @IBOutlet weak var jumlahNilai: NSTextField!
    @IBOutlet weak var jumlahGuru: NSTextField!
    private lazy var badgeView = NSView()
    // AutoComplete Teks
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
    var semesterWindow: NSWindowController?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Menambahkan action untuk kelasPopUpButton
        kelasPopUpButton.target = self
        kelasPopUpButton.action = #selector(kelasPopUpButtonDidChange)
        kelasPopUpButton.selectItem(at: 0)
        fillNamaPopUpButton(withTable: "Kelas 1")
        view.window?.makeFirstResponder(mapelTextField)
        mapelTextField.delegate = self
        guruMapel.delegate = self
        nilaiTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        if !namaPopUpButton.itemTitles.isEmpty {
            updateSemesterPopUpButton(withTable: kelasPopUpButton.titleOfSelectedItem ?? "")
        } else {
            mapelTextField.isEnabled = false
            nilaiTextField.isEnabled = false
            smstrPopUpButton.isEnabled = false
            namaPopUpButton.isEnabled = false
            guruMapel.isEnabled = false
            ok.isEnabled = false
            simpan.isEnabled = false
            pilihTgl.isEnabled = false
            namaPopUpButton.addItem(withTitle: "Tidak ada data di \(kelasPopUpButton.titleOfSelectedItem ?? "")")
        }
        setupBackgroundViews()
        setupBadgeView()
    }
    private var insertedID: Set<Int64>?
    override func viewWillDisappear() {
        semesterWindow?.close()
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.post(.init(name: .popupDismissedKelas))
        semesterWindow = nil
    }
    func tabKelas(index: Int) {
        // Mengonversi indeks menjadi string nama kelas
        let namaKelas: String
        switch index {
        case 0:
            namaKelas = "Kelas 1"
        case 1:
            namaKelas = "Kelas 2"
        case 2:
            namaKelas = "Kelas 3"
        case 3:
            namaKelas = "Kelas 4"
        case 4:
            namaKelas = "Kelas 5"
        case 5:
            namaKelas = "Kelas 6"
        default:
            namaKelas = "kelas1" // Default jika indeks di luar jangkauan
        }
        
        // Memilih item pada kelasPopUpButton berdasarkan indeks
        kelasPopUpButton.selectItem(at: index)
        // Mengisi popup nama dengan string nama kelas
        fillNamaPopUpButton(withTable: namaKelas)
    }
    @objc func kelasPopUpButtonDidChange(_ sender: NSPopUpButton) {
        // Mendapatkan nama tabel yang dipilih dengan menghilangkan spasi
        guard let kelasTerpilih = sender.titleOfSelectedItem else {return}
        // Mengisi namaPopUpButton berdasarkan pilihan tabel
        fillNamaPopUpButton(withTable: kelasTerpilih)
        if !namaPopUpButton.itemTitles.isEmpty {
            updateSemesterPopUpButton(withTable: kelasPopUpButton.titleOfSelectedItem ?? "")
            mapelTextField.isEnabled = true
            nilaiTextField.isEnabled = true
            smstrPopUpButton.isEnabled = true
            guruMapel.isEnabled = true
            ok.isEnabled = true
            simpan.isEnabled = true
            pilihTgl.isEnabled = true
            namaPopUpButton.isEnabled = true
        } else {
            mapelTextField.isEnabled = false
            nilaiTextField.isEnabled = false
            smstrPopUpButton.isEnabled = false
            guruMapel.isEnabled = false
            ok.isEnabled = false
            simpan.isEnabled = false
            pilihTgl.isEnabled = false
            namaPopUpButton.isEnabled = false
            namaPopUpButton.addItem(withTitle: "Tidak ada data di \(kelasPopUpButton.titleOfSelectedItem ?? "")")
        }
    }
    
    func fillNamaPopUpButton(withTable table: String) {
        var siswaData: [String: Int64] = [:]
        siswaData = dbController.getNamaSiswa(withTable: table)
        
        // Bersihkan popup button sebelum mengisi data baru
        namaPopUpButton.removeAllItems()
        
        // Isi popup button dengan data nama siswa
        for (namaSiswa, siswaID) in siswaData.sorted(by: <) {
            namaPopUpButton.addItem(withTitle: namaSiswa)
            namaPopUpButton.item(withTitle: namaSiswa)?.tag = Int(siswaID)
        }
    }
    func updateSemesterPopUpButton(withTable tableName: String) {
        // Mengambil semester dari tabel yang telah diformat
        var semesters: [String] = []
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {return}
            // Menghapus spasi dari nama tabel
            let formattedTableName = tableName.replacingOccurrences(of: " ", with: "").lowercased()
            semesters = self.dbController.fetchSemesters(fromTable: formattedTableName)
            // Mengurutkan item sehingga "Semester 1" dan "Semester 2" selalu di atas
            let defaultSemesters = ["Semester 1", "Semester 2"]
            semesters = defaultSemesters + semesters.filter { !defaultSemesters.contains($0) }
            DispatchQueue.main.async {
                // Memperbarui NSPopUpButton
                self.smstrPopUpButton.removeAllItems()
                self.smstrPopUpButton.addItems(withTitles: semesters)
                self.smstrPopUpButton.addItem(withTitle: "Tambah...")
            }
        }
    }
    let badgeLabel = NSTextField()
    // Setup background view untuk setiap label
    let mapelBackgroundView = NSView()
    let nilaiBackgroundView = NSView()
    let guruBackgroundView = NSView()

    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." { // Pilihan "Tambah..."
            openTambahSemesterWindow()
        } else {

        }
    }
    
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        let selectedIndex = kelasPopUpButton.indexOfSelectedItem
        var kelasModel: KelasModels?
        var kelas: Table!
        switch selectedIndex {
        case 0: kelasModel = Kelas1Model();kelas = kelas1
        case 1: kelasModel = Kelas2Model();kelas = kelas2
        case 2: kelasModel = Kelas3Model();kelas = kelas3
        case 3: kelasModel = Kelas4Model();kelas = kelas4
        case 4: kelasModel = Kelas5Model();kelas = kelas5
        case 5: kelasModel = Kelas6Model();kelas = kelas6
        default: break
        }

        guard let validKelasModel = kelasModel else { return }

        validKelasModel.kelasID = kelasId
        validKelasModel.siswaID = siswaID
        validKelasModel.namasiswa = namasiswa
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal

        

        // Periksa duplikat sebelum menambahkan
        if !dataArray.contains(where: { $0.data.kelasID == kelasId }) {
            dataArray.append((index: selectedIndex, data: validKelasModel))
            tableDataArray.append((table: kelas, id: kelasId))
            NotificationCenter.default.post(name: .updateTableNotificationDetilSiswa, object: nil, userInfo: ["index": selectedIndex, "data": validKelasModel, "kelasAktif": false])
        } else {
            return
        }
    }
    
    @IBAction func okButtonClicked(_ sender: NSButton) {
        // Mendapatkan nama tabel yang dipilih dengan menghilangkan spasi
        guard let selectedTableTitle = kelasPopUpButton.titleOfSelectedItem?.replacingOccurrences(of: " ", with: "") else {return}
        var lastInsertedKelasIds: [Int] = []
        
        // Mendapatkan siswaID berdasarkan nama siswa yang dipilih
        guard let selectedSiswaName = namaPopUpButton.titleOfSelectedItem,
              let tag = namaPopUpButton.selectedItem?.tag,
              let siswaID = Int64(exactly: tag) else {
            return
        }
        let kelasTable = Table(selectedTableTitle)
        let semester = smstrPopUpButton.titleOfSelectedItem ?? "1"
        var formattedSemester = semester

        if semester.contains("Semester") {
            if let number = semester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        let mapelString = mapelTextField.stringValue.capitalizedAndTrimmed()
        // Memisahkan string mapel menjadi array berdasarkan koma
        let mapelArray = mapelString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let nilaiString = nilaiTextField.stringValue
        // Memisahkan string nilai menjadi array berdasarkan koma
        let nilaiArray = nilaiString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let guruString = guruMapel.stringValue.capitalizedAndTrimmed()
        let guruArray = guruString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // Pastikan jumlah mata pelajaran dan nilai sesuai
        guard mapelArray.count == nilaiArray.count && mapelArray.count == guruArray.count else {
            // Menampilkan alert jika jumlah mata pelajaran dan nilai tidak sesuai
            let alert = NSAlert()
            alert.messageText = "Jumlah Mata Pelajaran, Nilai dan Nama Guru Tidak Sama"
            alert.informativeText = "Pastikan Jumlah Mata Pelajaran, Nilai dan Nama Guru sesuai."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        guard !mapelArray.isEmpty else {
            // Menampilkan alert jika tidak ada mata pelajaran yang dimasukkan
            let alert = NSAlert()
            alert.messageText = "Mata Pelajaran Kosong"
            alert.informativeText = "Harap masukkan setidaknya satu mata pelajaran."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        guard !guruArray.isEmpty else {
            // Menampilkan alert jika tidak ada mata pelajaran yang dimasukkan
            let alert = NSAlert()
            alert.messageText = "Nama Guru Kosong"
            alert.informativeText = "Harap masukkan setidaknya satu nama guru."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        pilihTgl.datePickerElements = .yearMonthDay
        pilihTgl.datePickerMode = .single
        pilihTgl.datePickerStyle = .textField
        pilihTgl.sizeToFit()
        
        // Set tanggal yang dipilih ke ExpandingDatePicker
        // datePicker.dateValue = pilihTgl.dateValue
        // Memasukkan data ke dalam tabel untuk setiap mata pelajaran
        DispatchQueue.global(qos: .background).async { [unowned self] in
            for (index, mapel) in mapelArray.enumerated() {
                DispatchQueue.main.async { [unowned self] in
                    if let nilai = Int64(nilaiArray[index]) {
                        var guru = ""
                        if !guruArray[index].isEmpty {
                            guru = guruArray[index]
                        } else {
                            guru = ""
                        }
                        // Memasukkan data ke dalam tabel yang sesuai
                        if let kelasId = dbController.insertDataToKelas(table: kelasTable, siswaID: siswaID, namaSiswa: selectedSiswaName, mapel: mapel, namaguru: guru, nilai: nilai, semester: formattedSemester, tanggal: dateFormatter.string(from: pilihTgl.dateValue)) {
                            lastInsertedKelasIds.append(Int(kelasId))
                            updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: selectedSiswaName, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: guru, tanggal: dateFormatter.string(from: pilihTgl.dateValue))
                            insertedID?.insert(kelasId)
                        } else {
                            // Handle jika gagal menambahkan data ke database
                            // ... (existing code)
                        }
                    } else {
                        // Menampilkan alert jika salah satu nilai bukan nomor
                        let alert = NSAlert()
                        alert.messageText = "Input Harus Nomor"
                        alert.informativeText = "Harap masukkan nilai numerik."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        return
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.updateBadgeAppearance()
            }
        }
    }
    
    @IBAction func simpan(_ sender: Any) {
        if mapelTextField.stringValue.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Mata Pelajaran tidak boleh kosong."
            alert.informativeText = "Isi terlebih dahulu kolom mata pelajaran."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else if dataArray.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Tidak ada data yang akan disimpan."
            alert.informativeText = "Klik Catat terlebih dahulu untuk menyimpan data."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            if let window = view.window {
                if let sheetParent = window.sheetParent {
                    // Jika jendela adalah sheet, akhiri sheet
                    sheetParent.endSheet(window, returnCode: .cancel)
                } else {
                    // Jika jendela bukan sheet, lakukan aksi tutup
                    window.performClose(sender)
                }
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateTableNotification, object: nil, userInfo: ["data": self.dataArray, "tambahData": true, "windowIdentifier": self.windowIdentifier ?? "", "kelas": self.kelasPopUpButton.titleOfSelectedItem ?? "Kelas 1"])
            }
        }
    }
    
    @IBAction func kapitalkan(_ sender: Any) {
        [mapelTextField, guruMapel].kapitalkanSemua()
    }
    @IBAction func hurufBesar(_ sender: Any) {
        [mapelTextField, guruMapel].hurufBesarSemua()
    }
    
    @IBAction func tutup(_ sender: Any) {
        let dispatchGroup = DispatchGroup()
        DispatchQueue.global(qos: .background).async { [unowned self] in
            for (_, data) in tableDataArray.enumerated() {
                let id = data.id
                let table = data.table
                var tableType: TableType?
                
                dispatchGroup.enter()
                
                dbController.deleteDataFromKelas(table: table, kelasID: id)
                
                if let tableName = getTableName(from: table) {
                    switch tableName {
                    case "kelas1": tableType = .kelas1
                    case "kelas2": tableType = .kelas2
                    case "kelas3": tableType = .kelas3
                    case "kelas4": tableType = .kelas4
                    case "kelas5": tableType = .kelas5
                    case "kelas6": tableType = .kelas6
                    default:
                        continue
                    }
                }
                
                if let wrappedTableType = tableType {
                    NotificationCenter.default.post(name: .kelasDihapus, object: self, userInfo: ["tableType": wrappedTableType, "deletedKelasIDs": [id]])
                }
                
                dispatchGroup.leave()
            }
            dispatchGroup.notify(queue: .main) { [unowned self] in
                if let window = view.window {
                    if let sheetParent = window.sheetParent {
                        // Jika jendela adalah sheet, akhiri sheet
                        sheetParent.endSheet(window, returnCode: .cancel)
                    } else {
                        // Jika jendela bukan sheet, lakukan aksi tutup
                        window.performClose(sender)
                    }
                }
            }
        }
    }
    
    func getTableName(from table: Table) -> String? {
        let description = String(describing: table)
        
        // Cari pola (name: "kelas1", ...) dalam string deskripsi
        if let range = description.range(of: "name: \"(.*?)\"", options: .regularExpression) {
            let tableName = String(description[range])
                .replacingOccurrences(of: "name: \"", with: "")
                .replacingOccurrences(of: "\"", with: "")
            return tableName
        }
        
        return nil
    }

}
extension AddDetaildiKelas: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        activeText = obj.object as? NSTextField
        jumlahGuru.isHidden = false
        jumlahNilai.isHidden = false
        jumlahMapel.isHidden = false
        let suggestionsDict: [NSTextField: [String]] = [
            mapelTextField: Array(ReusableFunc.mapel),
            guruMapel: Array(ReusableFunc.namaguru)
        ]
        if let activeTextField = obj.object as? NSTextField {
            if activeTextField == mapelTextField {
                
                // Tindakan yang diambil saat mapelTextField diubah
            } else if activeTextField == nilaiTextField {
                
                // Tindakan yang diambil saat nilaiTextField diubah
            } else if activeTextField == guruMapel {
                
                // Tindakan yang diambil saat guruMapel diubah
            }

            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        
        // Ubah string menjadi bentuk yang sudah dipangkas dan menggunakan kapitalisasi yang tepat
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        
        // Jika karakter terakhir adalah koma, hapus koma tersebut
        if textField.stringValue.last == "," {
            textField.stringValue.removeLast()
        }
        
        // Ganti dua atau lebih koma berturut-turut dengan satu koma
        let cleanedString = textField.stringValue.replacingOccurrences(of: ",+", with: ",", options: .regularExpression)
        
        // Update nilai string pada textField
        textField.stringValue = cleanedString
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            var currentText = activeTextField.stringValue
            // Handling koma dan spasi
            if currentText.last == "," {
                if currentText.dropLast().last == " " {
                    let indexBeforeComma = currentText.index(before: currentText.index(before: currentText.endIndex))
                    currentText.remove(at: indexBeforeComma)
                }
                activeTextField.stringValue = currentText
            }
            
            // Update jumlah item untuk setiap TextField
            updateItemCount()
            
            // Suggestion handling
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])
                suggestionManager.typing = lastWord
            } else {
                suggestionManager.typing = activeText.stringValue
            }
            
            if activeText?.stringValue.isEmpty == true {
                suggestionManager.hideSuggestions()
            } else {
                suggestionManager.controlTextDidChange(obj)
            }
        }
    }
    private func setupBackgroundViews() {
        mapelBackgroundView.wantsLayer = true  // Mengaktifkan layer untuk background
        mapelBackgroundView.layer?.cornerRadius = 10  // Sesuaikan radius sudut sesuai kebutuhan
        nilaiBackgroundView.wantsLayer = true  // Mengaktifkan layer untuk background
        nilaiBackgroundView.layer?.cornerRadius = 10  // Sesuaikan radius sudut sesuai kebutuhan
        guruBackgroundView.wantsLayer = true  // Mengaktifkan layer untuk background
        guruBackgroundView.layer?.cornerRadius = 10  // Sesuaikan radius sudut sesuai kebutuhan

        // Tambahkan background views ke view hierarchy
        if let mapelSuperview = jumlahMapel.superview,
           let nilaiSuperview = jumlahNilai.superview,
           let guruSuperview = jumlahGuru.superview {
            
            mapelSuperview.addSubview(mapelBackgroundView, positioned: .below, relativeTo: jumlahMapel)
            nilaiSuperview.addSubview(nilaiBackgroundView, positioned: .below, relativeTo: jumlahNilai)
            guruSuperview.addSubview(guruBackgroundView, positioned: .below, relativeTo: jumlahGuru)
            
            // Setup constraints untuk background views
            mapelBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            nilaiBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            guruBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        }
        let circleSize: CGFloat = 18 // Sesuaikan ukuran ini
        
        NSLayoutConstraint.activate([
            // Constraints untuk mapel background
            mapelBackgroundView.centerXAnchor.constraint(equalTo: jumlahMapel.centerXAnchor),
            mapelBackgroundView.centerYAnchor.constraint(equalTo: jumlahMapel.centerYAnchor, constant: -1),
            mapelBackgroundView.widthAnchor.constraint(equalToConstant: circleSize),
            mapelBackgroundView.heightAnchor.constraint(equalToConstant: circleSize),
            
            // Constraints untuk nilai background
            nilaiBackgroundView.centerXAnchor.constraint(equalTo: jumlahNilai.centerXAnchor),
            nilaiBackgroundView.centerYAnchor.constraint(equalTo: jumlahNilai.centerYAnchor, constant: -1),
            nilaiBackgroundView.widthAnchor.constraint(equalToConstant: circleSize),
            nilaiBackgroundView.heightAnchor.constraint(equalToConstant: circleSize),
            
            // Constraints untuk guru background
            guruBackgroundView.centerXAnchor.constraint(equalTo: jumlahGuru.centerXAnchor),
            guruBackgroundView.centerYAnchor.constraint(equalTo: jumlahGuru.centerYAnchor, constant: -1),
            guruBackgroundView.widthAnchor.constraint(equalToConstant: circleSize),
            guruBackgroundView.heightAnchor.constraint(equalToConstant: circleSize)
        ])

    }
    private func setupBadgeView() {
        badgeView = NSView()
        badgeView.wantsLayer = true  // Mengaktifkan layer untuk background
        badgeView.layer?.cornerRadius = 10  // Sesuaikan radius sudut sesuai kebutuhan
        simpan.addSubview(badgeView)

        // Setup constraints untuk badgeView
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeView.trailingAnchor.constraint(equalTo: simpan.trailingAnchor, constant: 5), // Sesuaikan jarak dari tepi kanan
            badgeView.centerYAnchor.constraint(equalTo: simpan.centerYAnchor, constant: -5), // Sesuaikan posisi vertikal
            badgeView.widthAnchor.constraint(equalToConstant: 20),  // Ukuran badge
            badgeView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Tambahkan textField ke dalam badgeView
        badgeLabel.isEditable = false
        badgeLabel.isBordered = false
        badgeLabel.backgroundColor = .clear
        badgeLabel.alignment = .center
        badgeLabel.textColor = .white
        badgeLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        badgeView.addSubview(badgeLabel)
        
        // Setup constraints untuk badgeLabel di tengah badgeView
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor, constant: 3),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualTo: badgeView.widthAnchor),
            badgeLabel.heightAnchor.constraint(equalTo: badgeView.heightAnchor)
        ])
    }

    private func updateBadgeAppearance() {
        let itemCount = dataArray.count
        
        badgeView.layer?.backgroundColor = NSColor.systemRed.cgColor  // Jika tidak ada item
        // Update warna background badge
        if itemCount > 0 {
            badgeLabel.stringValue = "\(itemCount)"  // Update teks pada badge
        } else {
            badgeLabel.stringValue = "0"  // Kosongkan teks jika tidak ada item
        }
    }

    // Modifikasi fungsi update count
    private func updateItemCount() {
        func countItems(in text: String) -> Int {
            let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return items.filter { !$0.isEmpty }.count
        }

        // Hitung jumlah item di masing-masing textfield
        let mapelCount = countItems(in: mapelTextField.stringValue)
        let nilaiCount = countItems(in: nilaiTextField.stringValue)
        let guruCount = countItems(in: guruMapel.stringValue)

        // Tampilkan hasil perhitungan di jumlahLabel masing-masing
        jumlahMapel.stringValue = "\(mapelCount)"
        jumlahNilai.stringValue = "\(nilaiCount)"
        jumlahGuru.stringValue = "\(guruCount)"
        guard mapelCount > 0 else {
            // Update warna teks dan background
            let textColor: NSColor = .white
            let backgroundColor: NSColor = .systemRed
            
            jumlahGuru.textColor = textColor
            jumlahNilai.textColor = textColor
            jumlahMapel.textColor = textColor
            
            mapelBackgroundView.layer?.backgroundColor = backgroundColor.cgColor
            nilaiBackgroundView.layer?.backgroundColor = backgroundColor.cgColor
            guruBackgroundView.layer?.backgroundColor = backgroundColor.cgColor

            return
        }
        // Buat array untuk jumlah, textField, dan backgroundView
        let counts = [mapelCount, nilaiCount, guruCount]
        let jumlahLabels = [jumlahMapel, jumlahNilai, jumlahGuru]
        let backgroundViews = [mapelBackgroundView, nilaiBackgroundView, guruBackgroundView]

        // Ambil jumlah pertama sebagai referensi perbandingan
        let referenceCount = mapelCount

        // Loop untuk setiap jumlah, dan update warna sesuai kesamaan
        for (index, count) in counts.enumerated() {
            let textColor: NSColor = .white
            let backgroundColor: NSColor
            
            if count == referenceCount {
                backgroundColor = .systemGreen // Sama, warnai hijau
            } else {
                backgroundColor = .systemRed   // Tidak sama, warnai merah
            }
            
            // Update warna teks dan background
            jumlahLabels[index]?.textColor = textColor
            backgroundViews[index].layer?.backgroundColor = backgroundColor.cgColor
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
extension AddDetaildiKelas: KategoriBaruDelegate {
    func didAddNewSemester(_ semester: String) {
        let itemIndex = smstrPopUpButton.numberOfItems - 1 // Indeks untuk item "Tambah..."
        smstrPopUpButton.insertItem(withTitle: semester, at: itemIndex)
        smstrPopUpButton.selectItem(at: itemIndex)
    }
    func didCloseWindow() {
        semesterWindow = nil
    }
    func openTambahSemesterWindow() {
        let storyboard = NSStoryboard(name: "AddDetaildiKelas", bundle: nil)
        let mouseLocation = NSEvent.mouseLocation
        guard semesterWindow == nil else {
            semesterWindow?.window?.makeKeyAndOrderFront(self)
            return
        }
        if let window = storyboard.instantiateController(withIdentifier: "addDetailPanel") as? NSWindowController, let tambahSemesterViewController = storyboard.instantiateController(withIdentifier: "KategoriBaru") as? KategoriBaruViewController {
            window.contentViewController = tambahSemesterViewController
            if NSScreen.main != nil {
                let windowHeight = window.window?.frame.height ?? 0
                let windowWidth = window.window?.frame.width ?? 400
                
                // Atur frame window berdasarkan posisi mouse
                let mouseFrame = NSRect(
                    x: mouseLocation.x - 100,
                    y: mouseLocation.y - windowHeight + 25, // Kurangi tinggi window agar tidak keluar dari batas atas
                    width: windowWidth,
                    height: windowHeight
                )
                window.window?.setFrame(mouseFrame, display: true)
                semesterWindow = window
                tambahSemesterViewController.delegate = self
                if appDelegate {
                    tambahSemesterViewController.appDelegate = true
                    self.view.window?.beginSheet(window.window!, completionHandler: nil)
                } else {
                    tambahSemesterViewController.appDelegate = false
                    window.showWindow(nil)
                }
            }
        }
    }
}
