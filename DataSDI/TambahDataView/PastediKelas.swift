//
//  PastediKelas.swift
//  Data Manager
//
//  Created by Bismillah on 21/11/23.
//

import Cocoa
import SQLite
class PastediKelas: NSViewController {
    let dbController = DatabaseController.shared
    @IBOutlet weak var kelasPopUpButton: NSPopUpButton!
    @IBOutlet weak var smstrPopUpButton: NSPopUpButton!
    @IBOutlet weak var namaPopUpButton: NSPopUpButton!
    @IBOutlet weak var smpnButton: NSButton!
    let kelas1 = Table("kelas1")
    let kelas2 = Table("kelas2")
    let kelas3 = Table("kelas3")
    let kelas4 = Table("kelas4")
    let kelas5 = Table("kelas5")
    let kelas6 = Table("kelas6")
    var dataArray: [(index: Int, data: KelasModels)] = []
    var windowIdentifier: String?
    var semesterWindow: NSWindowController?
    override func viewDidLoad() {
        super.viewDidLoad()
        kelasPopUpButton.target = self
        kelasPopUpButton.action = #selector(kelasPopUpButtonDidChange)
        namaPopUpButton.removeAllItems()
        // Do view setup here.
        loadNamaSiswaForSelectedKelas()
        if let v = view as? NSVisualEffectView {
            v.blendingMode = .behindWindow
            v.material = .windowBackground
            v.state = .followsWindowActiveState
        }
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        dataArray.removeAll()
        updateSemesterPopUpButton(withTable: kelasPopUpButton.titleOfSelectedItem ?? "")
    }
    override func viewWillDisappear() {
        semesterWindow?.close()
        semesterWindow = nil
    }
    @IBAction func kelasPopUpButtonDidChange(_ sender: NSPopUpButton) {
        loadNamaSiswaForSelectedKelas()
    }
    func kelasTerpilih(index: Int) {
        kelasPopUpButton.selectItem(at: index)
        loadNamaSiswaForSelectedKelas()
    }
    func loadNamaSiswaForSelectedKelas() {
        // Mendapatkan nama tabel yang dipilih dengan menghilangkan spasi
        guard let selectedTableTitle = kelasPopUpButton.titleOfSelectedItem else {
            return
        }
        // Mendapatkan kelasTable berdasarkan tabel yang dipilih
        var siswaData: [String: Int64] = [:]
        siswaData = dbController.getNamaSiswa(withTable: selectedTableTitle)
        
        // Bersihkan popup button sebelum mengisi data baru
        namaPopUpButton.removeAllItems()
        
        // Isi popup button dengan data nama siswa
        for (namaSiswa, siswaID) in siswaData.sorted(by: <) {
            namaPopUpButton.addItem(withTitle: namaSiswa)
            namaPopUpButton.item(withTitle: namaSiswa)?.tag = Int(siswaID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
            if namaPopUpButton.numberOfItems < 1 {
                smpnButton.isEnabled = false
                smstrPopUpButton.isEnabled = false
            } else {
                smpnButton.isEnabled = true
                smstrPopUpButton.isEnabled = true
            }
        }
    }
    
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            window.sheetParent?.endSheet(window, returnCode: .cancel)
        }
    }
    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." { // Pilihan "Tambah..."
            openTambahSemesterWindow()
        } else {

        }
    }
}
extension PastediKelas {
    @IBAction func pasteItemClicked(_ sender: Any) {
        // Mendapatkan kelasTable berdasarkan tabel yang dipilih
        guard let selectedTableTitle = kelasPopUpButton.titleOfSelectedItem?.replacingOccurrences(of: " ", with: "") else {
            return
        }
        let kelasTable = Table(selectedTableTitle)

        // Mendapatkan nama siswa dan siswaID berdasarkan nama siswa yang dipilih
        guard let selectedSiswaName = namaPopUpButton.titleOfSelectedItem,
              let siswaID = dbController.getSiswaIDForNamaSiswa(selectedSiswaName) else {
            return
        }
        var lastInsertedKelasIds: [Int] = []

        // Mendapatkan semester dari NSPopUpButton
        var semester = ""
        if let smstrTitle = smstrPopUpButton.titleOfSelectedItem {
            semester = smstrTitle.replacingOccurrences(of: "Semester ", with: "")
        }
        var formattedSemester = semester.capitalizedAndTrimmed()
        if semester.contains("Semester") {
            if let number = semester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalSekarang = dateFormatter.string(from: Date())
        var errorMessages: [String] = []
        // Handling "paste" logic for multiple rows with tab-separated format
        if let pasteboardString = NSPasteboard.general.string(forType: .string) {
            let rows = pasteboardString.components(separatedBy: .newlines)

            for row in rows {
                var rowComponents: [String]

                if row.contains("\t") {
                    rowComponents = row.components(separatedBy: "\t")
                } else if row.contains(",") {
                    rowComponents = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                } else {
                    errorMessages.append("Format tidak valid untuk baris: \(row)")
                    continue
                }
                if rowComponents.count == 1 {
                    let mapel = rowComponents[0]
                        // Memasukkan data ke dalam tabel yang sesuai
                        dbController.tambahDataKelas(table: kelasTable, siswaID: siswaID, namaSiswa: selectedSiswaName, mapel: mapel.capitalizedAndTrimmed(), namaguru: "", semester: formattedSemester, tanggal: tanggalSekarang)
                        NotificationCenter.default.post(name: DatabaseController.dataDidChangeNotification, object: nil)
                    
                } else if rowComponents.count == 2 {
                    let mapel = rowComponents[0]
                    let nilaiString = rowComponents[1]
                    if let nilai = Int64(nilaiString) {
                        // Memasukkan data ke dalam tabel yang sesuai
                        if let kelasId = dbController.insertDataToKelas(table: kelasTable, siswaID: siswaID, namaSiswa: selectedSiswaName, mapel: mapel.capitalizedAndTrimmed(), namaguru: "", nilai: nilai, semester: formattedSemester, tanggal: tanggalSekarang) {
                            lastInsertedKelasIds.append(Int(kelasId))
                            updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: selectedSiswaName, mapel: mapel.capitalizedAndTrimmed(), nilai: nilai, semester: formattedSemester, namaguru: "", tanggal: tanggalSekarang)
                        } else {}
                    } else {
                        errorMessages.append("Format nilai harus Nomor utk. '\(mapel)'.")
                    }
                } else if rowComponents.count == 3 {
                    let mapel = rowComponents[0]
                    let nilaiString = rowComponents[1]
                    let namaguru = rowComponents[2]
                    if let nilai = Int64(nilaiString) {
                        // Memasukkan data ke dalam tabel yang sesuai
                        if let kelasId = dbController.insertDataToKelas(table: kelasTable, siswaID: siswaID, namaSiswa: selectedSiswaName, mapel: mapel.capitalizedAndTrimmed(), namaguru: namaguru.capitalizedAndTrimmed(), nilai: nilai, semester: formattedSemester, tanggal: tanggalSekarang) {
                            lastInsertedKelasIds.append(Int(kelasId))
                            updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: selectedSiswaName, mapel: mapel.capitalizedAndTrimmed(), nilai: nilai, semester: formattedSemester, namaguru: namaguru.capitalizedAndTrimmed(), tanggal: tanggalSekarang)
                        } else {}
                    } else {
                        // Menampilkan alert jika input bukan nomor
                        errorMessages.append("Format nilai harus Nomor utk. '\(mapel)'.")
                    }
                }
            }
            if !errorMessages.isEmpty {
                let alert = NSAlert()
                alert.messageText = "Kesalahan dalam Input"
                alert.informativeText = errorMessages.joined(separator: "\n")
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        tutup(sender)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "UpdateTableNotification"), object: nil, userInfo: ["data": self.dataArray,"tambahData": true, "windowIdentifier": self.windowIdentifier ?? ""])
        }
    }
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        // Mendapatkan indeks yang dipilih dari kelasPopUpButton
        let selectedIndex = kelasPopUpButton.indexOfSelectedItem
        // Menggunakan case statement untuk menentukan model data berdasarkan indeks
        var kelasModel: KelasModels?
        switch selectedIndex {
        case 0:
            kelasModel = Kelas1Model()
        case 1:
            kelasModel = Kelas2Model()
        case 2:
            kelasModel = Kelas3Model()
        case 3:
            kelasModel = Kelas4Model()
        case 4:
            kelasModel = Kelas5Model()
        case 5:
            kelasModel = Kelas6Model()
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
        validKelasModel.namasiswa = namasiswa
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal

        
        // Di tempat lain di kode Anda
        
        // NotificationCenter.default.post(name: NSNotification.Name(rawValue: "UpdateTableNotification"), object: nil, userInfo: ["index": selectedIndex, "data": validKelasModel])
        dataArray.append((index: selectedIndex, data: validKelasModel))
    }
}
extension PastediKelas: KategoriBaruDelegate {
    func didCloseWindow() {
        semesterWindow = nil
    }
    func didAddNewSemester(_ semester: String) {
        let itemIndex = smstrPopUpButton.numberOfItems - 1 // Indeks untuk item "Tambah..."
        smstrPopUpButton.insertItem(withTitle: semester, at: itemIndex)
        smstrPopUpButton.selectItem(at: itemIndex)
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
    func openTambahSemesterWindow() {
        guard semesterWindow == nil else {
            semesterWindow?.window?.makeKeyAndOrderFront(self)
            return
        }
        let mouseLocation = NSEvent.mouseLocation
        let storyboard = NSStoryboard(name: "AddDetaildiKelas", bundle: nil)
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
                tambahSemesterViewController.appDelegate = false
                window.showWindow(nil)
            }
        }
    }
}
