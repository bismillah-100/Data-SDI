import Cocoa
import SQLite

/// Class yang menangani logika penambahan data nilai di suatu kelas dan siswa tertentu
/// ketika menambahkan data di ``KelasVC``.
class AddDetaildiKelas: NSViewController {
    /// Outlet untuk pengetikan mata pelajaran.
    @IBOutlet weak var mapelTextField: NSTextField!
    /// Outlet untuk pengetikan nilai.
    @IBOutlet weak var nilaiTextField: NSTextField!
    /// Outlet untuk pengetikan nama guru.
    @IBOutlet weak var guruMapel: NSTextField!

    /// Outlet menu popup pilihan nama.
    @IBOutlet weak var namaPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan semester.
    @IBOutlet weak var smstrPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan kelas.
    @IBOutlet weak var kelasPopUpButton: NSPopUpButton!

    /// Outlet untuk tombol "catat".
    /// Tombol ini berguna untuk mencatat semua pengetikan ke memori database dan semua ID data yang ditambah ke memori sementara.
    /// Ketika tombol "Batalkan" diklik, semua data di database yang sesuai dengan ID baru yang disimpan sebelumnya akan dihapus.
    @IBOutlet weak var ok: NSButton!

    /// Outlet untuk tombol "simpan".
    /// Tombol ini akan melanjutkan data yang telah disimpan sebelumnya untuk diteruskan ke pembaruan di UI.
    @IBOutlet weak var simpan: NSButton!

    /// Outlet untuk memilih tanggal.
    @IBOutlet weak var pilihTgl: ExpandingDatePicker!
    /// Outlet untuk menghitung jumlah mata pelajaran yang ditambahkan.
    @IBOutlet weak var jumlahMapel: NSTextField!
    /// Outlet untuk menghitung nilai yang ditambahkan.
    @IBOutlet weak var jumlahNilai: NSTextField!
    /// Outlet untuk menghitung jumlah nama guru yang ditambahkan.
    @IBOutlet weak var jumlahGuru: NSTextField!

    /// Deprecated. Bisa dihapus.
    /// Sebelumnya digunakan untuk menentukan window yang memicu view ini ditampilkan.
    var windowIdentifier: String?

    /// Instans ``DatabaseController``.
    let dbController = DatabaseController.shared

    /**
         Array untuk menyimpan data kelas beserta indeksnya.

         Setiap elemen dalam array ini adalah tuple yang berisi:
         - `index`: Integer yang merepresentasikan indeks dari data kelas.
         - `data`: Objek `KelasModels` yang menyimpan informasi detail tentang kelas.
     */
    var dataArray: [(index: Int, data: KelasModels)] = []

    /// Array yang menyimpan data tabel beserta ID-nya. Setiap elemen dalam array adalah tuple yang berisi objek `Table` dan `Int64` yang merepresentasikan ID.
    ///
    /// - Note: Digunakan untuk menyimpan dan mengelola data tabel yang akan ditampilkan atau diproses lebih lanjut.
    var tableDataArray: [(table: Table, id: Int64)] = []

    /// Referensi tabel database kelas 1.
    let kelas1 = Table("kelas1")
    /// Referensi tabel database kelas 2.
    let kelas2 = Table("kelas2")
    /// Referensi tabel database kelas 3.
    let kelas3 = Table("kelas3")
    /// Referensi tabel database kelas 4.
    let kelas4 = Table("kelas4")
    /// Referensi tabel database kelas 5.
    let kelas5 = Table("kelas5")
    /// Referensi tabel database kelas 6.
    let kelas6 = Table("kelas6")

    /// Properti yang digunakan untuk referensi jika view ini dipicu dari Menu Bar (AppDelegate)
    /// atau dari ``KelasVC``.
    var appDelegate: Bool = false

    /// Badge View untuk menampilkan jumlah data yang akan ditambahakan.
    lazy var badgeView = NSView()
    // AutoComplete Teks
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!
    /// Properti untuk referensi jendela yang ditampilkan ketika akan membuat kategori (semester) baru.
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

    /// Properti yang menyimpan referensi KelasID unik ketika menambahkan data.
    /// Digunakan untuk membatalkan penambahan data ketika view ini ditutup.
    private var insertedID: Set<Int64>?

    override func viewWillDisappear() {
        semesterWindow?.close()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.post(.init(name: .popupDismissedKelas))
        semesterWindow = nil
    }

    /**
     Menangani pemilihan tab kelas berdasarkan indeks yang diberikan.

     Fungsi ini melakukan beberapa hal:
     1. Mengonversi indeks tab yang diberikan menjadi nama kelas yang sesuai (misalnya, 0 menjadi "Kelas 1").
     2. Memilih item yang sesuai pada `kelasPopUpButton` berdasarkan indeks yang diberikan.
     3. Mengisi `namaPopUpButton` dengan data yang sesuai dengan nama kelas yang dipilih.

     - Parameter:
        - index: Indeks tab kelas yang dipilih (0 untuk Kelas 1, 1 untuk Kelas 2, dst.).
     */
    func tabKelas(index: Int) {
        // Mengonversi indeks menjadi string nama kelas
        let namaKelas = switch index {
        case 0:
            "Kelas 1"
        case 1:
            "Kelas 2"
        case 2:
            "Kelas 3"
        case 3:
            "Kelas 4"
        case 4:
            "Kelas 5"
        case 5:
            "Kelas 6"
        default:
            "kelas1" // Default jika indeks di luar jangkauan
        }

        // Memilih item pada kelasPopUpButton berdasarkan indeks
        kelasPopUpButton.selectItem(at: index)
        // Mengisi popup nama dengan string nama kelas
        fillNamaPopUpButton(withTable: namaKelas)
    }

    /**
     Menangani perubahan yang terjadi pada `kelasPopUpButton`.

     Fungsi ini dipanggil setiap kali item yang dipilih pada `kelasPopUpButton` berubah.
     Fungsi ini akan mendapatkan nama tabel (kelas) yang dipilih, mengisi `namaPopUpButton`
     berdasarkan kelas yang dipilih, dan memperbarui `smstrPopUpButton`.
     Selain itu, fungsi ini juga mengaktifkan atau menonaktifkan beberapa elemen UI
     seperti `mapelTextField`, `nilaiTextField`, `smstrPopUpButton`, `guruMapel`, `ok`,
     `simpan`, `pilihTgl`, dan `namaPopUpButton` berdasarkan apakah `namaPopUpButton` memiliki item atau tidak.
     Jika `namaPopUpButton` kosong, fungsi ini akan menambahkan item "Tidak ada data di [nama kelas]"
     ke `namaPopUpButton`.

     - Parameter:
        - sender: `NSPopUpButton` yang mengirimkan aksi perubahan.
     */
    @objc func kelasPopUpButtonDidChange(_ sender: NSPopUpButton) {
        // Mendapatkan nama tabel yang dipilih dengan menghilangkan spasi
        guard let kelasTerpilih = sender.titleOfSelectedItem else { return }
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

    /**
         Mengisi popup button nama dengan data dari tabel yang ditentukan.

         Fungsi ini mengambil data nama siswa dan ID siswa dari database berdasarkan tabel yang diberikan,
         kemudian mengisi popup button `namaPopUpButton` dengan nama-nama siswa tersebut.
         Setiap item di popup button akan memiliki tag yang sesuai dengan ID siswa.

         - Parameter table: Nama tabel yang akan digunakan untuk mengambil data siswa.
     */
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

    /**
     Memperbarui `NSPopUpButton` semester dengan data dari tabel yang ditentukan.

     Fungsi ini mengambil daftar semester dari tabel database yang telah diformat,
     mengurutkannya sehingga "Semester 1" dan "Semester 2" selalu berada di atas,
     dan kemudian memperbarui `NSPopUpButton` dengan daftar semester yang telah diurutkan.
     Selain itu, fungsi ini menambahkan opsi "Tambah..." ke `NSPopUpButton`.

     - Parameter:
        - tableName: Nama tabel database tempat semester akan diambil. Nama tabel akan diformat
                     dengan menghapus spasi dan mengubahnya menjadi huruf kecil.
     */
    func updateSemesterPopUpButton(withTable tableName: String) {
        // Mengambil semester dari tabel yang telah diformat
        var semesters: [String] = []

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
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

    /// Label yang ditampilkan di dalam badge jumlah.
    let badgeLabel = NSTextField()

    // Setup background view untuk setiap label
    /// Warna latar belakang badge mata pelajaran.
    let mapelBackgroundView = NSView()
    /// Warna latar belakang badge nilai.
    let nilaiBackgroundView = NSView()
    /// Warna latar belakang badge guru.
    let guruBackgroundView = NSView()

    /**
         Menangani perubahan yang terjadi pada `NSPopUpButton` semester.

         Jika item yang dipilih adalah "Tambah...", maka fungsi ini akan membuka jendela untuk menambahkan semester baru.

         - Parameter sender: `NSPopUpButton` yang mengirimkan aksi.
     */
    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." { // Pilihan "Tambah..."
            openTambahSemesterWindow()
        }
    }

    /**
     Memperbarui data model dengan informasi detail siswa dan mengirimkan notifikasi.

     Fungsi ini mengambil data siswa seperti ID kelas, ID siswa, nama siswa, mata pelajaran, nilai, semester, nama guru, dan tanggal, lalu memperbarui model data yang sesuai berdasarkan kelas yang dipilih. Data kemudian ditambahkan ke array `dataArray` dan `tableDataArray` jika belum ada duplikat berdasarkan `kelasId`. Terakhir, fungsi ini mengirimkan notifikasi untuk memperbarui tampilan tabel detail siswa.

     - Parameter kelasId: ID kelas (Int64).
     - Parameter siswaID: ID siswa (Int64).
     - Parameter namasiswa: Nama siswa (String).
     - Parameter mapel: Mata pelajaran (String).
     - Parameter nilai: Nilai siswa (Int64).
     - Parameter semester: Semester (String).
     - Parameter namaguru: Nama guru (String).
     - Parameter tanggal: Tanggal (String).

     - Catatan: Fungsi ini menggunakan `kelasPopUpButton` untuk menentukan kelas yang dipilih dan memperbarui model data yang sesuai (Kelas1Model, Kelas2Model, dst.). Fungsi ini juga memeriksa duplikat data berdasarkan `kelasId` sebelum menambahkan data baru ke array.
     */
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String) {
        let selectedIndex = kelasPopUpButton.indexOfSelectedItem
        var kelasModel: KelasModels?
        var kelas: Table!
        switch selectedIndex {
        case 0: kelasModel = Kelas1Model(); kelas = kelas1
        case 1: kelasModel = Kelas2Model(); kelas = kelas2
        case 2: kelasModel = Kelas3Model(); kelas = kelas3
        case 3: kelasModel = Kelas4Model(); kelas = kelas4
        case 4: kelasModel = Kelas5Model(); kelas = kelas5
        case 5: kelasModel = Kelas6Model(); kelas = kelas6
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

    /**
         Menangani aksi yang terjadi ketika tombol "OK" diklik. Fungsi ini bertanggung jawab untuk mengambil data dari input pengguna,
         memvalidasi data, dan memasukkan data ke dalam tabel database yang sesuai.

         - Parameter sender: Objek `NSButton` yang memicu aksi ini.

         Langkah-langkah yang dilakukan dalam fungsi ini:
         1.  Mendapatkan nama tabel yang dipilih dari `kelasPopUpButton` dan menghapus spasi.
         2.  Mendapatkan `siswaID` dari `namaPopUpButton` berdasarkan nama siswa yang dipilih.
         3.  Mendapatkan semester yang dipilih dari `smstrPopUpButton` dan memformatnya jika perlu.
         4.  Mendapatkan mata pelajaran dari `mapelTextField`, memformatnya, dan memisahkannya menjadi array.
         5.  Mendapatkan nilai dari `nilaiTextField` dan memisahkannya menjadi array.
         6.  Mendapatkan nama guru dari `guruMapel` dan memisahkannya menjadi array.
         7.  Memvalidasi bahwa jumlah mata pelajaran, nilai, dan nama guru sesuai. Jika tidak, menampilkan alert.
         8.  Memvalidasi bahwa mata pelajaran dan nama guru tidak kosong. Jika kosong, menampilkan alert.
         9.  Memformat tanggal dari `pilihTgl`.
         10. Memasukkan data ke dalam tabel untuk setiap mata pelajaran secara asynchronous:
             *   Memvalidasi bahwa nilai adalah angka. Jika tidak, menampilkan alert.
             *   Memasukkan data ke dalam tabel menggunakan `dbController.insertDataToKelas`.
             *   Memperbarui model data dengan `updateModelData`.
             *   Menyimpan `kelasId` yang baru dimasukkan.
         11. Memperbarui tampilan badge setelah semua data dimasukkan.
     */
    @IBAction func okButtonClicked(_ sender: NSButton) {
        // Mendapatkan nama tabel yang dipilih dengan menghilangkan spasi
        guard let selectedTableTitle = kelasPopUpButton.titleOfSelectedItem?.replacingOccurrences(of: " ", with: "") else { return }
        var lastInsertedKelasIds: [Int] = []

        // Mendapatkan siswaID berdasarkan nama siswa yang dipilih
        guard let selectedSiswaName = namaPopUpButton.titleOfSelectedItem,
              let tag = namaPopUpButton.selectedItem?.tag,
              let siswaID = Int64(exactly: tag)
        else {
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
        guard mapelArray.count == nilaiArray.count, mapelArray.count == guruArray.count else {
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
        
        // Nonaktifkan pemilihan kelas setelah ada data yang disimpan
        kelasPopUpButton.isEnabled = false
    }

    /**
         Menangani aksi ketika tombol "Simpan" ditekan.

         Fungsi ini melakukan validasi untuk memastikan bahwa kolom mata pelajaran tidak kosong dan ada data yang akan disimpan.
         Jika validasi gagal, sebuah alert akan ditampilkan kepada pengguna. Jika validasi berhasil, fungsi ini akan menutup jendela
         (baik sebagai sheet atau jendela utama) dan mengirimkan notifikasi untuk memperbarui tabel data.

         - Parameter:
            - sender: Objek yang memicu aksi (biasanya tombol "Simpan").

         Tindakan yang dilakukan:
         1. Memeriksa apakah kolom `mapelTextField` kosong. Jika kosong, menampilkan alert yang meminta pengguna untuk mengisi kolom tersebut.
         2. Memeriksa apakah `dataArray` kosong. Jika kosong, menampilkan alert yang memberitahu pengguna untuk mencatat data terlebih dahulu.
         3. Jika kedua validasi berhasil:
             - Menutup jendela saat ini. Jika jendela adalah sheet, sheet akan diakhiri. Jika tidak, jendela akan ditutup.
             - Mengirimkan notifikasi `updateTableNotification` melalui `NotificationCenter` untuk memperbarui tabel data. Notifikasi ini membawa informasi berikut:
                 - `data`: Array data yang akan disimpan (`dataArray`).
                 - `tambahData`: Nilai boolean yang menunjukkan bahwa data baru ditambahkan (true).
                 - `windowIdentifier`: Identifier jendela (jika ada).
                 - `kelas`: Kelas yang dipilih dari `kelasPopUpButton`.

         - Catatan:
             - Fungsi ini menggunakan `DispatchQueue.main.async` untuk memastikan bahwa notifikasi dikirimkan pada main thread.
             - Notifikasi `updateTableNotification` diharapkan untuk ditangani oleh objek lain yang bertanggung jawab untuk memperbarui tampilan tabel.
     */
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
                /// Memastikan jendela tersedia sebelum mengirim notifikasi.
                if !AppDelegate.shared.mainWindow.isVisible {
                    AppDelegate.shared.mainWindow.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                NotificationCenter.default.post(name: .updateTableNotification, object: nil, userInfo: ["data": self.dataArray, "tambahData": true, "windowIdentifier": self.windowIdentifier ?? "", "kelas": self.kelasPopUpButton.titleOfSelectedItem ?? "Kelas 1"])
            }
        }
    }

    /**
         Fungsi ini dipanggil ketika tombol "Aa" ditekan.

         Fungsi ini mengkapitalkan teks pada text field ``mapelTextField`` dan `guruMapel`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_ sender: Any) {
        [mapelTextField, guruMapel].kapitalkanSemua()
    }

    /**
         Fungsi ini dipanggil ketika tombol "AA" ditekan.

         Fungsi ini membuat teks pada text field ``mapelTextField`` dan `guruMapel` menjadi huruf besar semua.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func hurufBesar(_ sender: Any) {
        [mapelTextField, guruMapel].hurufBesarSemua()
    }

    /**
         Menutup tampilan dan menghapus data kelas terkait dari database.

         Fungsi ini melakukan iterasi melalui `tableDataArray`, menghapus data dari tabel yang sesuai di database,
         dan mengirimkan notifikasi bahwa kelas telah dihapus. Setelah semua operasi penghapusan selesai,
         tampilan akan ditutup.

         - Parameter sender: Objek yang memicu aksi ini.
     */
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

    /**
     Mengekstrak nama tabel dari deskripsi objek `Table`.

     Fungsi ini mengambil objek `Table` sebagai input, mengonversi objek tersebut menjadi string deskripsi,
     dan kemudian menggunakan regular expression untuk mengekstrak nilai dari field "name".

     - Parameter table: Objek `Table` yang akan diekstrak namanya.
     - Returns: Nama tabel sebagai string opsional. Mengembalikan `nil` jika nama tabel tidak dapat diekstrak.

     Contoh:
     ```
     let table = Table(name: "kelas1")
     let tableName = getTableName(from: table) // tableName akan menjadi "kelas1"
     ```
     */
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        activeText = obj.object as? NSTextField
        jumlahGuru.isHidden = false
        jumlahNilai.isHidden = false
        jumlahMapel.isHidden = false
        let suggestionsDict: [NSTextField: [String]] = [
            mapelTextField: Array(ReusableFunc.mapel),
            guruMapel: Array(ReusableFunc.namaguru),
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

extension AddDetaildiKelas {
    /**
         Mengatur tampilan latar belakang untuk `jumlahMapel`, `jumlahNilai`, dan `jumlahGuru`.
         Fungsi ini membuat tampilan latar belakang dengan sudut membulat dan menambahkannya
         di bawah tampilan yang sesuai dalam hierarki tampilan. Fungsi ini juga mengatur constraint
         untuk memastikan tampilan latar belakang diposisikan dengan benar di tengah tampilan terkait.
     */
    private func setupBackgroundViews() {
        mapelBackgroundView.wantsLayer = true // Mengaktifkan layer untuk background
        mapelBackgroundView.layer?.cornerRadius = 10 // Sesuaikan radius sudut sesuai kebutuhan
        nilaiBackgroundView.wantsLayer = true // Mengaktifkan layer untuk background
        nilaiBackgroundView.layer?.cornerRadius = 10 // Sesuaikan radius sudut sesuai kebutuhan
        guruBackgroundView.wantsLayer = true // Mengaktifkan layer untuk background
        guruBackgroundView.layer?.cornerRadius = 10 // Sesuaikan radius sudut sesuai kebutuhan

        // Tambahkan background views ke view hierarchy
        if let mapelSuperview = jumlahMapel.superview,
           let nilaiSuperview = jumlahNilai.superview,
           let guruSuperview = jumlahGuru.superview
        {
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
            guruBackgroundView.heightAnchor.constraint(equalToConstant: circleSize),
        ])
    }

    /**
     * Mengatur tampilan badge yang akan ditampilkan di atas tombol "Simpan".
     *
     * Fungsi ini membuat dan mengkonfigurasi sebuah `NSView` sebagai badge, menambahkan sudut membulat,
     * dan menempatkannya di sudut kanan atas tombol "Simpan". Di dalam badge, terdapat sebuah `NSTextField`
     * yang menampilkan teks (biasanya angka) sebagai indikator atau notifikasi.
     *
     * - Note: Fungsi ini mengatur properti visual badge dan label, serta menambahkan constraint layout
     *   untuk memastikan posisi dan ukuran yang tepat relatif terhadap tombol "Simpan".
     */
    private func setupBadgeView() {
        badgeView = NSView()
        badgeView.wantsLayer = true // Mengaktifkan layer untuk background
        badgeView.layer?.cornerRadius = 10 // Sesuaikan radius sudut sesuai kebutuhan
        simpan.addSubview(badgeView)

        // Setup constraints untuk badgeView
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeView.trailingAnchor.constraint(equalTo: simpan.trailingAnchor, constant: 5), // Sesuaikan jarak dari tepi kanan
            badgeView.centerYAnchor.constraint(equalTo: simpan.centerYAnchor, constant: -5), // Sesuaikan posisi vertikal
            badgeView.widthAnchor.constraint(equalToConstant: 20), // Ukuran badge
            badgeView.heightAnchor.constraint(equalToConstant: 20),
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
            badgeLabel.heightAnchor.constraint(equalTo: badgeView.heightAnchor),
        ])
    }

    /**
         Memperbarui tampilan badge berdasarkan jumlah data yang ada di dalam `dataArray`.

         Fungsi ini mengatur warna latar belakang dan teks pada badge untuk memberikan indikasi visual
         mengenai jumlah item yang ada. Jika `dataArray` memiliki item, badge akan menampilkan jumlah item tersebut.
         Jika `dataArray` kosong, badge akan menampilkan "0".
     */
    private func updateBadgeAppearance() {
        let itemCount = dataArray.count

        badgeView.layer?.backgroundColor = NSColor.systemRed.cgColor // Jika tidak ada item
        // Update warna background badge
        if itemCount > 0 {
            badgeLabel.stringValue = "\(itemCount)" // Update teks pada badge
        } else {
            badgeLabel.stringValue = "0" // Kosongkan teks jika tidak ada item
        }
    }

    // Modifikasi fungsi update count
    /**
         Memperbarui tampilan jumlah item pada label dan background view berdasarkan input dari text field.

         Fungsi ini menghitung jumlah item (dipisahkan oleh koma) pada masing-masing text field (mata pelajaran, nilai, dan guru),
         kemudian memperbarui label jumlah yang sesuai dengan hasil perhitungan. Warna teks pada label jumlah dan warna background
         view juga diperbarui berdasarkan perbandingan jumlah item di setiap text field.

         - Parameter: Tidak ada. Fungsi ini menggunakan properti `mapelTextField`, `nilaiTextField`, `guruMapel`,
                      `jumlahMapel`, `jumlahNilai`, `jumlahGuru`, `mapelBackgroundView`, `nilaiBackgroundView`, dan `guruBackgroundView`
                      yang diasumsikan sudah diinisialisasi.

         - Catatan:
             - Jika jumlah item pada `mapelTextField` adalah 0, maka warna teks pada semua label jumlah akan diubah menjadi putih,
               dan warna background pada semua background view akan diubah menjadi merah.
             - Jika jumlah item pada `mapelTextField` lebih dari 0, maka warna teks pada semua label jumlah akan diubah menjadi putih,
               dan warna background view akan diubah menjadi hijau jika jumlah item sama dengan jumlah item pada `mapelTextField`,
               atau merah jika tidak sama.
     */
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
            let backgroundColor: NSColor = if count == referenceCount {
                .systemGreen // Sama, warnai hijau
            } else {
                .systemRed // Tidak sama, warnai merah
            }

            // Update warna teks dan background
            jumlahLabels[index]?.textColor = textColor
            backgroundViews[index].layer?.backgroundColor = backgroundColor.cgColor
        }
    }
}

extension AddDetaildiKelas: KategoriBaruDelegate {
    /**
         Menambahkan semester baru ke daftar semester pada pop-up button dan memilih semester yang baru ditambahkan.

         - Parameter semester: String yang merepresentasikan semester yang akan ditambahkan.
     */
    func didAddNewSemester(_ semester: String) {
        let itemIndex = smstrPopUpButton.numberOfItems - 1 // Indeks untuk item "Tambah..."
        smstrPopUpButton.insertItem(withTitle: semester, at: itemIndex)
        smstrPopUpButton.selectItem(at: itemIndex)
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
                    view.window?.beginSheet(window.window!, completionHandler: nil)
                } else {
                    tambahSemesterViewController.appDelegate = false
                    window.showWindow(nil)
                }
            }
        }
    }
}
