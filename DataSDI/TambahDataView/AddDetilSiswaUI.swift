//
//  AddDetilSiswaUI.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 26/10/23.
//

import Cocoa
import SQLite

/// Class yang menangani logika penambahan data nilai di suatu kelas dan siswa tertentu
/// ketika menambahkan data di ``DetailSiswaController``.
class AddDetilSiswaUI: NSViewController {
    /// Outlet label yang menampilkan nama siswa.
    @IBOutlet weak var namaSiswa: NSTextField!
    /// Outlet untuk pengetikan nilai.
    @IBOutlet weak var nilaiTextField: NSTextField!
    /// Outlet untuk pengetikan mata pelajaran
    @IBOutlet weak var mapelTextField: NSTextField!
    /// Outlet untuk pengetikan nama guru.
    @IBOutlet weak var namaguruTextField: NSTextField!
    /// Outlet untuk pemilihan tanggal.
    @IBOutlet weak var pilihTgl: ExpandingDatePicker!

    /// Outlet menu popup pilihan semester.
    @IBOutlet weak var smstrPopUp: NSPopUpButton!
    /// Outlet menu popup pilihan kelas.
    @IBOutlet weak var pilihKelas: NSPopUpButton!
    /// Outlet label untuk id siswa. Disembunyikan.
    @IBOutlet weak var idTextField: NSTextField!
    /// Outlet tombol on/off untuk menyimpan data yang baru ke kelas aktif.
    @IBOutlet weak var saveKlsAktv: NSButton!

    /// Properti selectedSiswa yang akan ditambahkan nilai.
    var selectedSiswa: ModelSiswa?

    /// Properti untuk referensi tabel di database.
    var table: Table?

    /// Instans ``DatabaseController``.
    let dbController = DatabaseController.shared

    // AutoCompletion TextField
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    /// Properti untuk referensi penyimpanan nilai baru ke kelas aktif.
    var simpanDiKelasAktif: Bool = true

    /// Properti untuk referensi jendela yang ditampilkan ketika akan membuat kategori (semester) baru.
    var semesterWindow: NSWindowController?

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

    /// Fungsi untuk memilih item menu di popup ``pilihKelas`` tertentu.
    /// - Parameter index: Index menu di popup  ``pilihKelas`` yang akan dipilih.
    func tabDidChange(index: Int) {
        pilihKelas.selectItem(at: index)
    }

    /// Fungsi yang dijalankan ketika pilihan di popup ``pilihKelas`` berubah.
    /// Fungsi ini akan menjalankan func ``updateSemesterPopUpButton(withTable:)`` untuk memperbarui
    /// data semester di ``smstrPopUp`` dari database.
    /// - Parameter sender: Objek pemicu.
    @IBAction func kelasDidChange(_ sender: NSPopUpButton) {
        updateSemesterPopUpButton(withTable: "kelas\(pilihKelas.indexOfSelectedItem + 1)")
    }

    /**
     Memperbarui data model dengan informasi detail siswa.

     Fungsi ini mengambil informasi detail siswa seperti ID kelas, ID siswa, nama siswa, mata pelajaran, nilai, semester, nama guru, dan tanggal,
     kemudian memperbarui model data yang sesuai berdasarkan kelas yang dipilih. Setelah data model diperbarui, fungsi ini mengirimkan notifikasi
     untuk memberitahu tabel detail siswa agar diperbarui dengan data yang baru.

     - Parameter kelasId: ID kelas siswa (Int64).
     - Parameter siswaID: ID siswa (Int64).
     - Parameter namasiswa: Nama siswa (String, opsional). Jika nil, akan diisi dengan string kosong.
     - Parameter mapel: Mata pelajaran (String).
     - Parameter nilai: Nilai siswa (Int64).
     - Parameter semester: Semester (String).
     - Parameter namaguru: Nama guru (String).
     - Parameter tanggal: Tanggal (String).

     - Precondition: `pilihKelas` harus sudah diinisialisasi dan memiliki item yang sesuai dengan kelas yang tersedia.
     - Postcondition: Data model yang sesuai akan diperbarui dengan informasi yang diberikan, dan notifikasi akan dikirimkan untuk memperbarui tabel detail siswa.
     */
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String?, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
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
                    "kelasAktif": false,
                ]
            )
        } else {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "UpdateTableNotificationDetilSiswa"),
                object: nil,
                userInfo: [
                    "index": selectedIndex,
                    "data": validKelasModel,
                    "kelasAktif": true,
                ]
            )
        }
    }

    /**
         * Fungsi ini digunakan untuk memasukkan data ke dalam database berdasarkan input dari pengguna.
         *
         * Fungsi ini mengambil data dari berbagai elemen UI seperti `siswa`, `pilihKelas`, `mapelTextField`,
         * `namaguruTextField`, `smstrPopUp`, `nilaiTextField`, `saveKlsAktv`, dan `pilihTgl` untuk kemudian
         * menyimpannya ke dalam tabel kelas yang sesuai di database.
         *
         * - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol "Simpan").
         *
         * Proses:
         * 1. Memeriksa apakah siswa telah dipilih. Jika belum, menampilkan pesan peringatan.
         * 2. Mendapatkan referensi ke tabel-tabel kelas (kelas1 hingga kelas6).
         * 3. Mengambil data dari elemen UI:
         *   - Kelas yang dipilih dari `pilihKelas`.
         *   - Nama mata pelajaran dari `mapelTextField`.
         *   - Nama guru dari `namaguruTextField`.
         *   - Semester dari `smstrPopUp`.
         *   - Nilai dari `nilaiTextField`.
         * 4. Validasi input:
         *   - Memastikan nama mata pelajaran tidak kosong.
         *   - Memastikan nilai tidak kosong dan berupa angka yang valid.
         * 5. Menentukan apakah nama siswa akan disimpan berdasarkan status `saveKlsAktv`.
         * 6. Memformat tanggal dari `pilihTgl`.
         * 7. Menentukan tabel kelas yang sesuai berdasarkan opsi yang dipilih dari `pilihKelas`.
         * 8. Memanggil `dbController.insertDataToKelas` untuk menyimpan data ke database.
         * 9. Memanggil `updateModelData` untuk memperbarui model data dengan data yang baru disimpan.
     */
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        // let datePicker = ExpandingDatePicker(frame: .zero)
        pilihTgl.datePickerElements = .yearMonthDay
        pilihTgl.datePickerMode = .single
        pilihTgl.datePickerStyle = .textField
        pilihTgl.sizeToFit()

        // Set tanggal yang dipilih ke ExpandingDatePicker
        pilihTgl.dateValue = pilihTgl.dateValue
        let pilihanTgl = dateFormatter.string(from: pilihTgl.dateValue)

        var table: Table!
        switch selectedOption {
        case "Kelas 1": table = kelas1
        case "Kelas 2": table = kelas2
        case "Kelas 3": table = kelas3
        case "Kelas 4": table = kelas4
        case "Kelas 5": table = kelas5
        case "Kelas 6": table = kelas6
        default: break
        }
        if let kelasId = dbController.insertDataToKelas(table: table, siswaID: siswaID, namaSiswa: namaSiswa, mapel: mapel, namaguru: namaguru, nilai: nilai, semester: formattedSemester, tanggal: pilihanTgl) {
            updateModelData(withKelasId: Int64(kelasId), siswaID: siswaID, namasiswa: namaSiswa, mapel: mapel, nilai: nilai, semester: formattedSemester, namaguru: namaguru, tanggal: pilihanTgl)
        }
    }

    /// Fungsi untuk membaca semua data semester yang ada di table database sesuai dengan
    /// nama table yang diberikan dan mengisi ``smstrPopUp`` dengan data yang didapatkan.
    /// - Parameter tableName: Nama table yang akan difetch data semesternya.
    func updateSemesterPopUpButton(withTable tableName: String) {
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

    /**
         Menangani perubahan yang terjadi pada `NSPopUpButton` semester.

         Jika item yang dipilih adalah "Tambah...", maka fungsi ini akan membuka jendela untuk menambahkan semester baru.

         - Parameter sender: `NSPopUpButton` yang mengirimkan aksi.
     */
    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." {
            openTambahSemesterWindow()
        }
    }

    /// Action dari ``saveKlsAktv``. Memperbarui status ``simpanDiKelasAktif`` sesuai dengan
    /// `state` on/off ``saveKlsAktv`.
    /// - Parameter sender: Objek pemicu.
    @IBAction func smpnKlsAktv(_ sender: NSButton) {
        simpanDiKelasAktif.toggle()
        saveKlsAktv.state = simpanDiKelasAktif ? .on : .off
    }

    /// Update UI nama siswa.
    func updateDetailView() {
        if let siswa {
            namaSiswa.stringValue = siswa.nama
        }
    }

    /**
         Fungsi ini dipanggil ketika tombol "Aa" ditekan.

         Fungsi ini mengkapitalkan teks pada text field ``mapelTextField`` dan `namaguruTextField`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_ sender: Any) {
        [mapelTextField, namaguruTextField].kapitalkanSemua()
    }

    /**
         Fungsi ini dipanggil ketika tombol "AA" ditekan.

         Fungsi ini membuat teks di ``mapelTextField`` dan `namaguruTextField` menjadi HURUF BESAR.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func hurufBesar(_ sender: Any) {
        [mapelTextField, namaguruTextField].hurufBesarSemua()
    }

    /// Properti untuk data siswa yang akan ditambahkan nilai.
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
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        activeText = obj.object as? NSTextField
        let suggestionsDict: [NSTextField: [String]] = [
            mapelTextField: Array(ReusableFunc.mapel),
            namaguruTextField: Array(ReusableFunc.namaguru),
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

extension AddDetilSiswaUI: KategoriBaruDelegate {
    /**
         Menambahkan semester baru ke daftar semester pada pop-up button dan memilih semester yang baru ditambahkan.

         - Parameter semester: String yang merepresentasikan semester yang akan ditambahkan.
     */
    func didAddNewSemester(_ semester: String) {
        let itemIndex = smstrPopUp.numberOfItems - 1
        smstrPopUp.insertItem(withTitle: semester, at: itemIndex)
        smstrPopUp.selectItem(at: itemIndex)
    }

    /**
         Menangani aksi ketika jendela semester ditutup.

         Setelah jendela semester ditutup, fungsi ini akan dipanggil untuk mengatur `semesterWindow` menjadi `nil`.
         Hal ini dilakukan untuk membersihkan referensi ke jendela yang telah ditutup dan mencegah potensi masalah memori atau perilaku yang tidak terduga.
     */
    func didCloseWindow() {
        semesterWindow = nil
    }

    /**
     * Membuka jendela "Tambah Semester".
     *
     * Fungsi ini menampilkan jendela untuk menambahkan detail semester baru. Jika jendela sudah terbuka,
     * jendela tersebut akan dibawa ke depan. Jika belum, jendela baru akan dibuat dan ditampilkan
     * di dekat posisi mouse.
     *
     * - Note: Jendela akan ditampilkan sebagai sheet jika `appDelegate` bernilai true, jika tidak,
     *         jendela akan ditampilkan sebagai jendela terpisah.
     *
     * - Precondition: Storyboard dengan nama "AddDetaildiKelas" dan identifier "addDetailPanel" dan "KategoriBaru" harus ada.
     *
     * - Postcondition: Jendela "Tambah Semester" akan ditampilkan.
     */
    func openTambahSemesterWindow() {
        guard semesterWindow == nil else {
            semesterWindow?.window?.makeKeyAndOrderFront(self)
            return
        }
        let storyboard = NSStoryboard(name: "AddDetaildiKelas", bundle: nil)
        let mouseLocation = NSEvent.mouseLocation
        if let window = storyboard.instantiateController(withIdentifier: "addDetailPanel") as? NSWindowController, let tambahSemesterViewController = storyboard.instantiateController(withIdentifier: "KategoriBaru") as? KategoriBaruViewController {
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
}
