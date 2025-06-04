//
//  AddDetilSiswaUI.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 26/10/23.
//

import Cocoa
import SQLite

class AddDetilSiswaUI: NSViewController, KategoriBaruDelegate {
    func didAddNewSemester(_ semester: String) {
        let itemIndex = smstrPopUp.numberOfItems - 1
        smstrPopUp.insertItem(withTitle: semester, at: itemIndex)
        smstrPopUp.selectItem(at: itemIndex)
    }
    @IBAction func smpnKlsAktv(_ sender: NSButton) {
        simpanDiKelasAktif.toggle()
        saveKlsAktv.state = simpanDiKelasAktif ? .on : .off
    }
    func didCloseWindow() {
        semesterWindow = nil
    }
    var semesterWindow: NSWindowController?
    private var simpanDiKelasAktif: Bool = true
    @IBOutlet weak var saveKlsAktv: NSButton!
    @IBOutlet weak var nilaiTextField: NSTextField!
    @IBOutlet weak var mapelTextField: NSTextField!
    @IBOutlet weak var inputData: NSButton!
    @IBOutlet weak var pilihTgl: ExpandingDatePicker!
    // Deklarasikan selectedSiswa sebagai properti kelas
    var selectedSiswa: ModelSiswa?
    @IBOutlet weak var namaSiswa: NSTextField!
    // Deklarasikan siswaData sebagai properti kelas
    private var table: Table?
    var detailSiswa: DetailSiswaController!
    @IBOutlet weak var namaguruTextField: NSTextField!
    @IBOutlet var smstrPopUp: NSPopUpButton!
    @IBOutlet weak var pilihKelas: NSPopUpButton!
    @IBOutlet weak var idTextField: NSTextField!
    let dbController = DatabaseController.shared
    // AutoCompletion TextField
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateDetailView()
        
        tabDidChange(index: 1)
        mapelTextField.delegate = self
        namaguruTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.post(name: .addDetilSiswaUITertutup, object: nil)
        semesterWindow?.close()
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        updateSemesterPopUpButton(withTable: "kelas\(pilihKelas.indexOfSelectedItem + 1)")
        semesterWindow = nil
    }
    convenience init(siswa: ModelSiswa) {
        self.init()
        selectedSiswa = siswa
    }
    func tabDidChange(index: Int) {
        pilihKelas.selectItem(at: index)
    }
    @IBAction func kelasDidChange(_ sender: NSPopUpButton) {
        updateSemesterPopUpButton(withTable: "kelas\(pilihKelas.indexOfSelectedItem + 1)")
    }
    private func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String?, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        // Mendapatkan indeks yang dipilih dari kelasPopUpButton
        let selectedIndex = pilihKelas.indexOfSelectedItem
        // Menggunakan case statement untuk menentukan model data berdasarkan indeks
        var kelasModel: KelasModels?
        switch selectedIndex {
        case 0: kelasModel = Kelas1Model()
        case 1: kelasModel = Kelas2Model()
        case 2: kelasModel = Kelas3Model()
        case 3: kelasModel = Kelas4Model()
        case 4: kelasModel = Kelas5Model()
        case 5: kelasModel = Kelas6Model()
        default:
            break
        }
        
        // Pastikan kelasModel tidak nil sebelum mengakses propertinya
        guard let validKelasModel = kelasModel else {
            return
        }
        // Update the model data based on kelasId
        validKelasModel.kelasID = kelasId
        validKelasModel.siswaID = siswaID
        validKelasModel.namasiswa = namasiswa ?? ""
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal
        
        
        // Di tempat lain di kode Anda
        if saveKlsAktv.state == .off {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "UpdateTableNotificationDetilSiswa"),
                object: nil,
                userInfo: [
                    "index": selectedIndex,
                    "data": validKelasModel,
                    "kelasAktif": false
                ]
            )
        } else {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "UpdateTableNotificationDetilSiswa"),
                object: nil,
                userInfo: [
                    "index": selectedIndex,
                    "data": validKelasModel,
                    "kelasAktif": true
                ]
            )
        }
    }
    @IBAction func insertData(_ sender: Any) {
        // Periksa apakah siswa telah dipilih
        guard let siswaID = siswa?.id else {
            // Jika tidak, tampilkan pesan peringatan
            let alert = NSAlert()
            alert.messageText = "Siswa belum dipilih"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let kelas1 = Table("kelas1")
        let kelas2 = Table("kelas2")
        let kelas3 = Table("kelas3")
        let kelas4 = Table("kelas4")
        let kelas5 = Table("kelas5")
        let kelas6 = Table("kelas6")
        
        let selectedOption = pilihKelas.selectedItem?.title
        let mapel = mapelTextField.stringValue.capitalizedAndTrimmed()
        let namaguru = namaguruTextField.stringValue.capitalizedAndTrimmed()
        let semester = smstrPopUp.titleOfSelectedItem ?? "1"
        var formattedSemester = semester
        
        if semester.contains("Semester") {
            if let number = semester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        
        guard !mapel.isEmpty else {
            ReusableFunc.showAlert(title: "Nama Mata Pelajaran Tidak Boleh Kosong", message: "Mohon isi nama mata pelajaran sebelum menyimpan.")
            return
        }
        
        let nilaiString = nilaiTextField.stringValue
        guard let nilai = Int64(nilaiString) else {
            if nilaiString.isEmpty {
                ReusableFunc.showAlert(title: "Nilai Tidak Boleh Kosong", message: "Mohon isi nilai sebelum menyimpan.")
            } else {
                ReusableFunc.showAlert(title: "Nilai Harus Berupa Nomor", message: "Mohon isi nilai yang valid sebelum menyimpan.")
            }
            return
        }
        var namaSiswa: String? = nil
        if saveKlsAktv.state == .on {
            namaSiswa = siswa?.nama
        } else if saveKlsAktv.state == .off {
            namaSiswa = nil
        }
        var lastInsertedKelasIds: [Int] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        //let datePicker = ExpandingDatePicker(frame: .zero)
        pilihTgl.datePickerElements = .yearMonthDay
        pilihTgl.datePickerMode = .single
        pilihTgl.datePickerStyle = .textField
        pilihTgl.sizeToFit()
        
        // Set tanggal yang dipilih ke ExpandingDatePicker
        pilihTgl.dateValue = pilihTgl.dateValue
        let pilihanTgl = dateFormatter.string(from: pilihTgl.dateValue)
        
        // Memasukkan data ke dalam database sesuai siswa ID yang dipilih
        if selectedOption == "Kelas 1" {
            if let kelasId = dbController.insertDataToKelas(table: kelas1, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        } else if selectedOption == "Kelas 2" {
            if let kelasId = dbController.insertDataToKelas(table: kelas2, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        } else if selectedOption == "Kelas 3" {
            if let kelasId = dbController.insertDataToKelas(table: kelas3, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        } else if selectedOption == "Kelas 4" {
            if let kelasId = dbController.insertDataToKelas(table: kelas4, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        } else if selectedOption == "Kelas 5" {
            if let kelasId = dbController.insertDataToKelas(table: kelas5, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        } else if selectedOption == "Kelas 6" {
            if let kelasId = dbController.insertDataToKelas(table: kelas6, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
                lastInsertedKelasIds.append(Int(kelasId))
                updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
            } else {}
        }
    }
    private func updateSemesterPopUpButton(withTable tableName: String) {
        // Menghapus spasi dari nama tabel
        let formattedTableName = tableName.replacingOccurrences(of: " ", with: "").lowercased()
        
        // Mengambil semester dari tabel yang telah diformat
        var semesters = dbController.fetchSemesters(fromTable: formattedTableName)
        
        // Mengurutkan item sehingga "Semester 1" dan "Semester 2" selalu di atas
        let defaultSemesters = ["Semester 1", "Semester 2"]
        semesters = defaultSemesters + semesters.filter { !defaultSemesters.contains($0) }
        
        // Memperbarui NSPopUpButton
        smstrPopUp.removeAllItems()
        smstrPopUp.addItems(withTitles: semesters)
        smstrPopUp.addItem(withTitle: "Tambah...")
    }
    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." {
            openTambahSemesterWindow()
        }
    }
    private func openTambahSemesterWindow() {
        guard semesterWindow == nil else {
            semesterWindow?.window?.makeKeyAndOrderFront(self)
            return
        }
        let storyboard = NSStoryboard(name: "AddDetaildiKelas", bundle: nil)
        let mouseLocation = NSEvent.mouseLocation
        if  let window = storyboard.instantiateController(withIdentifier: "addDetailPanel") as? NSWindowController, let tambahSemesterViewController = storyboard.instantiateController(withIdentifier: "KategoriBaru") as? KategoriBaruViewController {
            semesterWindow = window
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
                tambahSemesterViewController.delegate = self
                window.showWindow(self)
            }
        }
    }
    private func updateDetailView() {
        if let siswa = siswa {
            namaSiswa.stringValue = siswa.nama
        }
    }
    
    @IBAction func kapitalkan(_ sender: Any) {
        [mapelTextField, namaguruTextField].kapitalkanSemua()
    }
    @IBAction func hurufBesar(_ sender: Any) {
        [mapelTextField, namaguruTextField].hurufBesarSemua()
    }
    
    var siswa: ModelSiswa? {
        didSet {
            if isViewLoaded {
                updateDetailView()
            }
        }
    }
}

extension AddDetilSiswaUI: NSTextFieldDelegate {
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
            mapelTextField: Array(ReusableFunc.mapel),
            namaguruTextField: Array(ReusableFunc.namaguru)
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
