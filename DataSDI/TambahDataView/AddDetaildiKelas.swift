import Cocoa
import SQLite

/// Struct untuk menyimpan cache penugasan guru yang telah ditambahkan.
private struct PenugasanKey: Hashable {
    let guru: String
    let mapel: String
    let bagian: String
    let semester: String
    let tahunAjaran: String

    static func == (lhs: PenugasanKey, rhs: PenugasanKey) -> Bool {
        lhs.guru == rhs.guru &&
            lhs.mapel == rhs.mapel &&
            lhs.bagian == rhs.bagian &&
            lhs.semester == rhs.semester &&
            lhs.tahunAjaran == rhs.tahunAjaran
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(guru)
        hasher.combine(mapel)
        hasher.combine(bagian)
        hasher.combine(semester)
        hasher.combine(tahunAjaran)
    }
}

/// Class yang menangani logika penambahan data nilai di suatu kelas dan siswa tertentu
/// ketika menambahkan data di ``KelasVC``.
class AddDetaildiKelas: NSViewController {
    typealias MapelIDDictionary = [String: Int64]
    typealias GuruIDDictionary = [String: Int64]
    typealias JabatanByGuruDictionary = [String: String]
    typealias DataNilaiSiswa = (
        mapelArray: [String],
        nilaiArray: [String],
        guruArray: [String],
        siswaID: Int64,
        selectedSiswaName: String,
        selectedKelasTitle: String,
        formattedSemester: String,
        thnAjrn: String,
        tanggalString: String,
        idNamaMapel: MapelIDDictionary,
        idNamaGuru: GuruIDDictionary,
        kelasID: Int64,
        jabatanByGuru: JabatanByGuruDictionary
    )

    private var penugasanCache: [PenugasanKey: (penugasanID: Int64, jabatanID: Int64)] = [:]

    // 2. Helper untuk build key
    private func makeKey(guru: String, mapel: String, bagian: String, semester: String, tahunAjaran: String) -> PenugasanKey {
        .init(guru: guru, mapel: mapel, bagian: bagian, semester: semester, tahunAjaran: tahunAjaran)
    }

    /// Judul view ``AddDetaildiKelas``.
    @IBOutlet weak var titleText: NSTextField!

    /// Outlet untuk pengetikan mata pelajaran.
    @IBOutlet weak var mapelTextField: CustomTextField!
    /// Outlet untuk pengetikan nilai.
    @IBOutlet weak var nilaiTextField: CustomTextField!
    /// Outlet untuk pengetikan nama guru.
    @IBOutlet weak var guruMapel: CustomTextField!

    /// Outlet menu popup pilihan nama.
    @IBOutlet weak var namaPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan semester.
    @IBOutlet weak var smstrPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan kelas.
    @IBOutlet weak var kelasPopUpButton: NSPopUpButton!
    /// Oultet bagian kelas (A,B,C).
    @IBOutlet weak var bagianKelas: NSPopUpButton!

    /// Outlet untuk tombol "catat".
    /// Tombol ini berguna untuk mencatat semua pengetikan ke memori database dan semua ID data yang ditambah ke memori sementara.
    /// Ketika tombol "Batalkan" diklik, semua data di database yang sesuai dengan ID baru yang disimpan sebelumnya akan dihapus.
    @IBOutlet weak var ok: NSButton!

    /// Outlet untuk tombol "simpan".
    /// Tombol ini akan melanjutkan data yang telah disimpan sebelumnya untuk diteruskan ke pembaruan di UI
    /// dengan menjalankan closure ``onSimpanClick``.
    @IBOutlet weak var simpan: NSButton!

    /// Outlet untuk memilih tanggal.
    @IBOutlet weak var pilihTgl: ExpandingDatePicker!
    /// Outlet untuk menghitung jumlah mata pelajaran yang ditambahkan.
    @IBOutlet weak var jumlahMapel: NSTextField!
    /// Outlet untuk menghitung nilai yang ditambahkan.
    @IBOutlet weak var jumlahNilai: NSTextField!
    /// Outlet untuk menghitung jumlah nama guru yang ditambahkan.
    @IBOutlet weak var jumlahGuru: NSTextField!

    /// Outlet tahun ajaran 1.
    @IBOutlet weak var thnAjrn1: CustomTextField!
    /// Outlet tahun ajaran 2.
    @IBOutlet weak var thnAjrn2: CustomTextField!

    /// Tombol checkmark untuk pilihan status siswa di dalam kelas.
    @IBOutlet weak var statusSiswaKelas: NSButton!

    /// Tombol untuk menutup ``AddDetaildiKelas``.
    @IBOutlet weak var tutupBtn: NSButton!

    /// ScrollView yang memuat input field dan popover.
    @IBOutlet weak var scrollView: NSScrollView!

    /// Visual effect yang memuat semua view kecuali ``titleText``.
    @IBOutlet weak var visualEffect: NSVisualEffectView!

    /// Instans ``DatabaseController``.
    let dbController: DatabaseController = .shared

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

    /// Properti yang digunakan untuk referensi jika view ini dipicu dari Menu Bar (AppDelegate)
    /// atau dari ``KelasVC``.
    var appDelegate: Bool = false

    /// Badge View untuk menampilkan jumlah data yang akan ditambahakan.
    lazy var badgeView: NSView = .init()
    // AutoComplete Teks
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!
    /// Properti untuk referensi jendela yang ditampilkan ketika akan membuat kategori (semester) baru.
    var semesterWindow: NSWindowController?

    /// terima userInfo
    typealias SaveHandler = (_ dataArray: [(index: Int, data: KelasModels)], _ tambahData: Bool, _ undoIsHandled: Bool, _ kelasAktif: Bool) -> Void

    /// Closure yang dijalankan ketika tombol simpan diklik.
    var onSimpanClick: SaveHandler?

    /// Ketika dibuka dari rincian siswa nilai ini diubah ke true.
    var isDetailSiswa: Bool = false
    /// Ketika dibuka dari rincian siswa string berisi nama siswa.
    var siswaNama: String = ""
    /// ID siswa  dibuka dari rincian siswa.
    var idSiswa: Int64!

    override func loadView() {
        super.loadView()
        setupBackgroundViews()
        setupBadgeView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mapelTextField.delegate = self
        guruMapel.delegate = self
        nilaiTextField.delegate = self
        thnAjrn1.delegate = self
        thnAjrn2.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            if window.sheetParent == nil {
                visualEffect.material = .popover
            }
        }

        // Menambahkan action untuk kelasPopUpButton
        if !isDetailSiswa {
            kelasPopUpButton.target = self
            kelasPopUpButton.action = #selector(kelasPopUpButtonDidChange)
            kelasPopUpButton.selectItem(at: 0)
            fillNamaPopUpButton(withTable: "Kelas 1")
        } else {
            fillNamaPopUpButton(withTable: "")
        }

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
        if let documentView = scrollView.documentView {
            let topPoint = NSPoint(x: 0, y: documentView.bounds.size.height)
            documentView.scroll(topPoint)
        }
        if appDelegate {
            fillNamaPopUpButton(withTable: kelasPopUpButton.titleOfSelectedItem ?? "")
            tutupBtn.title = "Batalkan"
        }
        guard !isDetailSiswa else { return }
        view.window?.becomeFirstResponder()
        view.window?.becomeKey()
        view.window?.makeFirstResponder(thnAjrn1)
    }

    override func viewWillDisappear() {
        semesterWindow?.close()
        if isDetailSiswa {
            tutup(self)
            NotificationCenter.default.post(.init(name: .addDetilSiswaUITertutup))
        } else {
            NotificationCenter.default.post(name: .popupDismissedKelas, object: nil)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        semesterWindow = nil
        guard !isDetailSiswa else { return }
        view.window?.resignFirstResponder()
        view.window?.resignKey()
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
        if kelasPopUpButton.titleOfSelectedItem != namaKelas {
            penugasanCache.removeAll()
        }
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

        penugasanCache.removeAll()
    }

    /**
         Mengisi popup button nama dengan data dari tabel yang ditentukan.

         Fungsi ini mengambil data nama siswa dan ID siswa dari database berdasarkan tabel yang diberikan,
         kemudian mengisi popup button `namaPopUpButton` dengan nama-nama siswa tersebut.
         Setiap item di popup button akan memiliki tag yang sesuai dengan ID siswa.

         - Parameter table: Nama tabel yang akan digunakan untuk mengambil data siswa.
     */
    func fillNamaPopUpButton(withTable table: String) {
        // Bersihkan popup button sebelum mengisi data baru
        namaPopUpButton.removeAllItems()

        if isDetailSiswa {
            namaPopUpButton.addItem(withTitle: siswaNama)
            namaPopUpButton.item(withTitle: siswaNama)?.tag = Int(idSiswa)
            return
        }

        var siswaData: [String: Int64] = [:]
        siswaData = dbController.getNamaSiswa(withTable: table)

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
            semesters = dbController.fetchSemesters(fromTable: formattedTableName)
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
    let badgeLabel: NSTextField = .init()

    // Setup background view untuk setiap label
    /// Warna latar belakang badge mata pelajaran.
    let mapelBackgroundView: NSView = .init()
    /// Warna latar belakang badge nilai.
    let nilaiBackgroundView: NSView = .init()
    /// Warna latar belakang badge guru.
    let guruBackgroundView: NSView = .init()

    /**
         Menangani perubahan yang terjadi pada `NSPopUpButton` semester.

         Jika item yang dipilih adalah "Tambah...", maka fungsi ini akan membuka jendela untuk menambahkan semester baru.

         - Parameter sender: `NSPopUpButton` yang mengirimkan aksi.
     */
    @IBAction func smstrDidChange(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Tambah..." { // Pilihan "Tambah..."
            guard semesterWindow == nil else {
                semesterWindow?.window?.makeKeyAndOrderFront(self)
                return
            }
            semesterWindow = ReusableFunc.openNewCategoryWindow(view, viewController: self, type: .semester, menuBar: appDelegate, suggestions: ReusableFunc.semester)
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
     - Parameter tahunAjaran: Tahun Ajaran (String).

     */
    func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, mapel: String, nilai: Int64, semester: String, namaguru: String, tanggal: String, tahunAjaran: String) {
        let selectedIndex = kelasPopUpButton.indexOfSelectedItem
        let validKelasModel = KelasModels()
        guard let kelas = TableType(rawValue: selectedIndex)?.table else { return }

        validKelasModel.kelasID = kelasId
        validKelasModel.siswaID = siswaID
        validKelasModel.namasiswa = namasiswa
        validKelasModel.mapel = mapel
        validKelasModel.nilai = nilai
        validKelasModel.semester = semester
        validKelasModel.namaguru = namaguru
        validKelasModel.tanggal = tanggal
        validKelasModel.tahunAjaran = tahunAjaran
        validKelasModel.aktif = statusSiswaKelas.state == .on

        // Periksa duplikat sebelum menambahkan
        if !dataArray.contains(where: { $0.data.kelasID == kelasId }) {
            dataArray.append((index: selectedIndex, data: validKelasModel))
            tableDataArray.append((table: kelas, id: kelasId))
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
    @IBAction func okButtonClicked(_: NSButton) {
        #if DEBUG
            print("[DEBUG] → okButtonClicked fired")
        #endif

        scrollToBottom(of: scrollView)

        // 1️⃣ Ambil judul kelas
        guard let selectedKelasTitle = kelasPopUpButton.titleOfSelectedItem?
            .replacingOccurrences(of: "Kelas ", with: "")
        else {
            #if DEBUG
                print("[DEBUG] gagal ambil selectedKelasTitle")
            #endif
            return
        }
        #if DEBUG
            print("[DEBUG] selectedKelasTitle =", selectedKelasTitle)
        #endif

        // 2️⃣ Ambil siswaID
        guard
            let selectedSiswaName = namaPopUpButton.titleOfSelectedItem,
            let tag = namaPopUpButton.selectedItem?.tag,
            let siswaID = Int64(exactly: tag),
            let selectedSemester = smstrPopUpButton.titleOfSelectedItem
        else {
            #if DEBUG
                print("[DEBUG] gagal ambil siswaID/selectedSemester")
            #endif
            return
        }
        #if DEBUG
            print("[DEBUG] selectedSiswaName =", selectedSiswaName, "siswaID =", siswaID, "selectedSemester =", selectedSemester)
        #endif

        // 3️⃣ Format semester
        let formattedSemester = selectedSemester.contains("Semester")
            ? selectedSemester.replacingOccurrences(of: "Semester ", with: "")
            : selectedSemester
        #if DEBUG
            print("[DEBUG] formattedSemester =", formattedSemester)
        #endif

        // 4️⃣ Parse nilai, mapel, guru
        let nilaiArray = nilaiTextField.stringValue
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let mapelArray = mapelTextField.stringValue
            .components(separatedBy: ",")
            .map { $0.capitalizedAndTrimmed() }
            .filter { !$0.isEmpty }
        let guruArray = guruMapel.stringValue
            .components(separatedBy: ",")
            .map { $0.capitalizedAndTrimmed() }
            .filter { !$0.isEmpty }

        #if DEBUG
            print("[DEBUG] nilaiArray =", nilaiArray)
            print("[DEBUG] mapelArray =", mapelArray)
            print("[DEBUG] guruArray =", guruArray)
        #endif

        // 5️⃣ Validasi input
        guard !thnAjrn1.stringValue.isEmpty || !thnAjrn2.stringValue.isEmpty else {
            ReusableFunc.showAlert(title: "Tahun Ajaran Kosong", message: "Masukkan tahun ajaran")
            #if DEBUG
                print("[DEBUG] tahun ajaran kosong")
            #endif
            return
        }
        guard mapelArray.count == nilaiArray.count, mapelArray.count == guruArray.count else {
            ReusableFunc.showAlert(
                title: "Jumlah Mata Pelajaran, Nilai dan Nama Guru Tidak Sama",
                message: "Pastikan Jumlah Mata Pelajaran, Nilai dan Nama Guru sesuai."
            )
            #if DEBUG
                print("[DEBUG] jumlah array tidak sama")
            #endif
            return
        }
        guard !mapelArray.isEmpty else {
            ReusableFunc.showAlert(title: "Mata Pelajaran Kosong", message: "Harap masukkan setidaknya satu mata pelajaran.")
            #if DEBUG
                print("[DEBUG] mapelArray kosong")
            #endif
            return
        }
        guard !guruArray.isEmpty else {
            ReusableFunc.showAlert(title: "Nama Guru Kosong", message: "Masukkan setidaknya satu nama guru.")
            #if DEBUG
                print("[DEBUG] guruArray kosong")
            #endif
            return
        }

        // 6️⃣ Siapkan tanggal
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let tanggalString = dateFormatter.string(from: pilihTgl.dateValue)
        #if DEBUG
            print("[DEBUG] tanggalString =", tanggalString)
        #endif

        let thnAjrn = thnAjrn1.stringValue + "/" + thnAjrn2.stringValue
        let bk = bagianKelas.titleOfSelectedItem!
        #if DEBUG
            print("[DEBUG] thnAjrn =", thnAjrn, "bk =", bk)
        #endif

        // 7️⃣ Jalankan background Task
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            #if DEBUG
                print("[DEBUG] → background task started")
            #endif

            // 1) Fetch semua ID sekali
            guard let ids = await fetchIDs(
                mapelArray: mapelArray,
                guruArray: guruArray,
                bagianKelasName: bk,
                tingkat: selectedKelasTitle,
                tahunAjaran: thnAjrn,
                semester: formattedSemester
            ) else {
                #if DEBUG
                    print("[DEBUG] fetchIDs returned nil")
                #endif
                return
            }
            let mapel2id = ids.mapel2id
            let guru2id = ids.guru2id
            let kelasID = ids.kelasID
            #if DEBUG
                print("[DEBUG] fetched IDs mapel2id =", mapel2id)
                print("[DEBUG] fetched IDs guru2id  =", guru2id)
                print("[DEBUG] fetched kelasID    =", kelasID)
            #endif

            // 2) Buat semua key
            let penugasanKeys: [PenugasanKey] = zip(mapelArray, guruArray).map { mapel, guru in
                PenugasanKey(
                    guru: guru,
                    mapel: mapel,
                    bagian: bk,
                    semester: formattedSemester,
                    tahunAjaran: thnAjrn
                )
            }
            #if DEBUG
                print("[DEBUG] penugasanKeys =", penugasanKeys)
            #endif

            // 3) Pisahkan existing vs missing
            var existingKeys: [PenugasanKey] = []
            var missingKeys: [PenugasanKey] = []
            for key in penugasanKeys {
                if await penugasanCache[key] != nil {
                    existingKeys.append(key)
                } else {
                    missingKeys.append(key)
                }
            }
            #if DEBUG
                print("[DEBUG] existingKeys =", existingKeys)
                print("[DEBUG] missingKeys  =", missingKeys)
            #endif

            // 4) Siapkan jabatanIDsByGuru
            var jabatanIDsByGuru: [String: Int64] = [:]
            for key in existingKeys {
                if let (id, _) = await penugasanCache[key] {
                    jabatanIDsByGuru[key.guru] = id
                }
            }
            #if DEBUG
                print("[DEBUG] jabatanIDsByGuru =", jabatanIDsByGuru)
            #endif

            // 5) Kalau tidak ada yang missing
            if missingKeys.isEmpty {
                #if DEBUG
                    print("[DEBUG] semua keys ada di cache, langsung insertPenugasanDanNilai loop")
                #endif
                for (idx, mapel) in mapelArray.enumerated() {
                    let key = PenugasanKey(
                        guru: guruArray[idx],
                        mapel: mapel,
                        bagian: bk,
                        semester: formattedSemester,
                        tahunAjaran: thnAjrn
                    )

                    guard
                        let nilai = Int(nilaiArray[idx]),
                        let (_, jabatanID) = await penugasanCache[key],
                        let namaJabatan = await IdsCacheManager.shared.namaJabatan(for: jabatanID)
                    else {
                        #if DEBUG
                            print("[DEBUG] skip insert untuk idx \(idx) karena data invalid")
                        #endif
                        continue
                    }
                    #if DEBUG
                        print("[DEBUG] Insert penugasan: mapel=\(mapel), guru=\(guruArray[idx]), jabatanID=\(jabatanID), namaJabatan=\(namaJabatan), nilai=\(nilai)")
                    #endif

                    await insertPenugasanDanNilai(
                        mapel: mapel,
                        guru: guruArray[idx],
                        namaJabatan: namaJabatan,
                        jabatanID: jabatanID,
                        nilai: nilai,
                        siswaID: siswaID,
                        selectedSiswaName: selectedSiswaName,
                        selectedKelasTitle: selectedKelasTitle,
                        namaKelas: bk,
                        thnAjaran: thnAjrn,
                        semester: formattedSemester,
                        tanggalString: tanggalString,
                        mapel2id: mapel2id,
                        guru2id: guru2id,
                        kelasID: kelasID
                    )
                }
                return
            }

            // 6) Ada missing, tampilkan sheet
            let missingGurus = Set(missingKeys.map(\.guru))
            let daftarSheet: [(String, String)] = missingGurus.map { ($0, "") }
            #if DEBUG
                print("[DEBUG] show sheet untuk missingGurus =", missingGurus)
            #endif

            await MainActor.run {
                let editMapel = EditMapel(nibName: "EditMapel", bundle: nil)
                editMapel.loadView()
                editMapel.tambahStrukturGuru = true
                editMapel.loadGuruData(daftarGuru: daftarSheet)

                editMapel.onJabatanSelected = { [weak self] result in
                    guard let self else { return }
                    #if DEBUG
                        print("[DEBUG] hasil onJabatanSelected =", result)
                    #endif

                    // Build payload dan updateDatabase
                    let dataUntukUpdate: DataNilaiSiswa = (
                        mapelArray: mapelArray,
                        nilaiArray: nilaiArray,
                        guruArray: guruArray,
                        siswaID: siswaID,
                        selectedSiswaName: selectedSiswaName,
                        selectedKelasTitle: selectedKelasTitle,
                        formattedSemester: formattedSemester,
                        thnAjrn: thnAjrn,
                        tanggalString: tanggalString,
                        idNamaMapel: ids.mapel2id,
                        idNamaGuru: ids.guru2id,
                        kelasID: ids.kelasID,
                        jabatanByGuru: result
                    )

                    Task {
                        await self.updateDatabase(data: dataUntukUpdate)
                    }
                }

                self.presentAsSheet(editMapel)
            }
        }

        // 8️⃣ Nonaktifkan UI setelah simpan
        kelasPopUpButton.isEnabled = false
        statusSiswaKelas.isEnabled = false
        thnAjrn1.isEnabled = false
        thnAjrn2.isEnabled = false
        #if DEBUG
            print("[DEBUG] UI elements disabled")
        #endif
    }

    private func scrollToBottom(of scrollView: NSScrollView) {
        // Pastikan documentView ada
        guard let docView = scrollView.documentView else { return }

        // Paksa layout selesai agar ukuran akurat
        scrollView.contentView.layoutSubtreeIfNeeded()
        docView.layoutSubtreeIfNeeded()

        // Ambil tinggi viewport (clipView) dan total tinggi konten
        let visibleHeight = scrollView.contentView.bounds.height
        let totalHeight = docView.bounds.height

        // Kompensasi top inset otomatis
        let insetTop = scrollView.contentInsets.top + 24

        // Hitung offset Y sesuai flipped state
        let yOffset: CGFloat = if docView.isFlipped {
            // Flipped: origin di atas, geser ke bawah konten
            max(totalHeight - visibleHeight + insetTop, 0)
        } else {
            // Non-flipped: origin di bawah, tinggal minus inset
            -insetTop
        }

        // Scroll dan perbarui scrollbar
        let bottomPoint = NSPoint(x: 0, y: yOffset)
        scrollView.contentView.scroll(to: bottomPoint)
        scrollView.reflectScrolledClipView(scrollView.contentView)
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
            /// Memastikan jendela tersedia sebelum mengirim notifikasi.
            if !AppDelegate.shared.mainWindow.isVisible {
                AppDelegate.shared.mainWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            if statusSiswaKelas.state == .on, !isDetailSiswa {
                onSimpanClick?(dataArray, true, false, true)
                NotificationCenter.default.post(name: .updateTableNotificationDetilSiswa, object: nil, userInfo: ["data": dataArray])
            } else if isDetailSiswa {
                onSimpanClick?(dataArray, true, false, statusSiswaKelas.state == .on)
            }

            kelasPopUpButton.isEnabled = true
            statusSiswaKelas.isEnabled = true
            thnAjrn1.isEnabled = true
            thnAjrn2.isEnabled = true
            updateBadgeAppearance()
            tutupJendela(sender)
        }
    }

    /**
         Fungsi ini dipanggil ketika tombol "Aa" ditekan.

         Fungsi ini mengkapitalkan teks pada text field ``mapelTextField`` dan `guruMapel`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_: Any) {
        [mapelTextField, guruMapel].kapitalkanSemua()
    }

    /**
         Fungsi ini dipanggil ketika tombol "AA" ditekan.

         Fungsi ini membuat teks pada text field ``mapelTextField`` dan `guruMapel` menjadi huruf besar semua.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func hurufBesar(_: Any) {
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
                dispatchGroup.enter()
                let id = data.id
                let table = data.table
                var tableType: TableType?

                // Operasi sinkron, tapi tetap kita jaga dengan dispatchGroup
                dbController.deleteSpecificNilai(nilaiID: id)

                if let tableName = getTableName(from: table) {
                    switch tableName {
                    case "kelas1": tableType = .kelas1
                    case "kelas2": tableType = .kelas2
                    case "kelas3": tableType = .kelas3
                    case "kelas4": tableType = .kelas4
                    case "kelas5": tableType = .kelas5
                    case "kelas6": tableType = .kelas6
                    default:
                        dispatchGroup.leave() // tetap leave walaupun continue
                        continue
                    }
                }

                if let wrappedTableType = tableType {
                    NotificationCenter.default.post(
                        name: .kelasDihapus,
                        object: self,
                        userInfo: ["tableType": wrappedTableType, "deletedKelasIDs": [id]]
                    )
                }

                dispatchGroup.leave()
            }

            for (_, id) in penugasanCache {
                dispatchGroup.enter()
                dbController.hapusTugasGuru(id.penugasanID)
                // asumsikan hapusTugasGuru menerima closure completion
                dispatchGroup.leave()
            }

            dispatchGroup.notify(queue: .main) { [unowned self] in
                tutupJendela(sender)
                if !isDetailSiswa {
                    updateItemCount()
                    updateBadgeAppearance()
                }
            }
        }
    }

    private func tutupJendela(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                sheetParent.endSheet(window, returnCode: .cancel)
            } else if appDelegate {
                AppDelegate.shared.popoverAddDataKelas?.performClose(nil)
            } else {
                window.performClose(sender)
            }
            AppDelegate.shared.updateUndoRedoMenu(for: AppDelegate.shared.mainWindow.contentViewController as! SplitVC)
        }
        if !isDetailSiswa {
            SingletonData.insertedID.removeAll()
            dataArray.removeAll()
            tableDataArray.removeAll()
            penugasanCache.removeAll()
            resetForm()
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

    func resetForm() {
        // 🔤 Reset semua CustomTextField
        mapelTextField.stringValue = ""
        nilaiTextField.stringValue = ""
        guruMapel.stringValue = ""

        // 🔘 Reset semua NSPopUpButton ke item pertama (jika ada)
        resetPopUpToFirstItem(namaPopUpButton)
        resetPopUpToFirstItem(smstrPopUpButton)
        resetPopUpToFirstItem(kelasPopUpButton)
        resetPopUpToFirstItem(bagianKelas)
    }

    private func resetPopUpToFirstItem(_ popup: NSPopUpButton?) {
        guard let popup else { return }
        if popup.numberOfItems > 0 {
            popup.selectItem(at: 0)
        }
    }

    deinit {
        #if DEBUG
            print("deinit AddDetaildiKelas")
        #endif
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
        guard let textField = obj.object as? NSTextField,
              UserDefaults.standard.bool(forKey: "showSuggestions")
        else { return }

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
        // Update jumlah item untuk setiap TextField
        updateItemCount()

        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        if let activeTextField = obj.object as? NSTextField,
           let activeText
        {
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

            // Suggestion handling
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])
                suggestionManager.typing = lastWord
            } else {
                suggestionManager.typing = activeText.stringValue
            }

            if activeText.stringValue.isEmpty == true {
                suggestionManager.hideSuggestions()
            } else {
                suggestionManager.controlTextDidChange(obj)
            }
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
    func updateItemCount() {
        func countItems(in text: String) -> Int {
            let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return items.filter { !$0.isEmpty }.count
        }
        guard let mapelTextField, let nilaiTextField, let guruMapel,
              let jumlahMapel, let jumlahNilai, let jumlahGuru
        else {
            #if DEBUG
                print("TextField not initialized")
            #endif
            return
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
            let textColor = NSColor.white
            let backgroundColor = NSColor.systemRed

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
            let textColor = NSColor.white
            let backgroundColor: NSColor = if count == referenceCount {
                .systemGreen // Sama, warnai hijau
            } else {
                .systemRed // Tidak sama, warnai merah
            }

            // Update warna teks dan background
            jumlahLabels[index].textColor = textColor
            backgroundViews[index].layer?.backgroundColor = backgroundColor.cgColor
        }
        jumlahGuru.isHidden = false
        jumlahNilai.isHidden = false
        jumlahMapel.isHidden = false
    }
}

extension AddDetaildiKelas: KategoriBaruDelegate {
    /**
         Menambahkan semester baru ke daftar semester pada pop-up button dan memilih semester yang baru ditambahkan.

         - Parameter semester: String yang merepresentasikan semester yang akan ditambahkan.
     */
    func didAddNewCategory(_ category: String, ofType _: CategoryType) {
        let itemIndex = smstrPopUpButton.numberOfItems - 1 // Indeks untuk item "Tambah..."
        smstrPopUpButton.insertItem(withTitle: category, at: itemIndex)
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
}

extension AddDetaildiKelas {
    /// Proses 1 entri penugasan + nilai
    private func insertPenugasanDanNilai(
        mapel: String,
        guru: String,
        namaJabatan: String,
        jabatanID: Int64,
        nilai: Int,
        siswaID: Int64,
        selectedSiswaName: String,
        selectedKelasTitle: String,
        namaKelas: String,
        thnAjaran: String,
        semester: String,
        tanggalString: String,
        mapel2id: [String: Int64],
        guru2id: [String: Int64],
        kelasID: Int64
    ) async {
        // 1. Key untuk cache
        let key = makeKey(guru: guru, mapel: mapel, bagian: bagianKelas.titleOfSelectedItem!, semester: semester, tahunAjaran: thnAjaran)

        // 2. Cek cache dulu
        let penugasanID: Int64
        let jabID: Int64
        if let entry = penugasanCache[key] {
            // HIT cache
            (penugasanID, jabID) = entry
        } else {
            // MISS → insert/get ke DB
            guard
                let mapelID = mapel2id[mapel],
                let guruID = guru2id[guru],
                let pid = await dbController.insertOrGetPenugasanID(
                    guruID: guruID,
                    mapelID: mapelID,
                    kelasID: kelasID,
                    jabatanID: jabatanID, // ini param func-mu
                    tanggalMulai: tanggalString
                )
            else { return }

            penugasanID = pid
            jabID = jabatanID

            // 3️⃣ Cache hasilnya
            penugasanCache[key] = (penugasanID: pid, jabatanID: jabID)

            let guruModel = GuruModel(idGuru: guruID, idTugas: pid)
            guruModel.namaGuru = guru
            guruModel.mapel = mapel
            guruModel.tahunaktif = thnAjaran
            guruModel.tglMulai = tanggalString
            guruModel.statusTugas = .aktif
            if let kelasNama = kelasPopUpButton.titleOfSelectedItem?.replacingOccurrences(of: "Kelas ", with: ""),
               let bagianKelas = kelasPopUpButton.titleOfSelectedItem,
               let semester = smstrPopUpButton.titleOfSelectedItem
            {
                guruModel.kelas = kelasNama + " " + bagianKelas + " " + semester
            }
            guruModel.struktural = namaJabatan
            GuruViewModel.shared.undoHapus(groupedDeletedData: [mapel: [guruModel]])

            let guruData = GuruModel(idGuru: guruID, idTugas: -1)
            guruData.namaGuru = guru
            GuruViewModel.shared.insertGuruu([guruData])
        }

        // 5. Sekarang insert nilai siswa
        if let idNilai = await dbController.insertNilaiSiswa(
            siswaID: siswaID,
            namaSiswa: selectedSiswaName,
            penugasanGuruID: penugasanID,
            nilai: nilai,
            tingkatKelas: selectedKelasTitle,
            namaKelas: namaKelas,
            tahunAjaran: thnAjaran,
            semester: semester,
            tanggalNilai: tanggalString,
            status: statusSiswaKelas.state == .on ? StatusSiswa.aktif : StatusSiswa.naik
        ) {
            // 6. Update UI / model seperti biasa
            updateModelData(
                withKelasId: Int64(idNilai),
                siswaID: siswaID,
                namasiswa: selectedSiswaName,
                mapel: mapel,
                nilai: Int64(nilai),
                semester: semester,
                namaguru: guru,
                tanggal: tanggalString, tahunAjaran: thnAjaran
            )
            await MainActor.run {
                self.updateBadgeAppearance()
                if !isDetailSiswa {
                    SingletonData.insertedID.insert(idNilai)
                    NotificationCenter.default.post(name: .bisaUndo, object: nil)
                }
            }
        }
    }

    /// Fetch semua ID yang dibutuhkan secara concurrent:
    /// - mapel2id: [namaMapel: mapelID]
    /// - guru2id:  [namaGuru: guruID]
    /// - kelasID:  ID kelas yang baru dibuat/diambil
    func fetchIDs(
        mapelArray: [String],
        guruArray: [String],
        bagianKelasName: String,
        tingkat: String,
        tahunAjaran: String,
        semester: String
    ) async -> (mapel2id: [String: Int64], guru2id: [String: Int64], kelasID: Int64)? {
        // 1. Insert/get kelasID (bisa write)
        guard let kelasID = await dbController.insertOrGetKelasID(
            nama: bagianKelasName,
            tingkat: tingkat,
            tahunAjaran: tahunAjaran,
            semester: semester
        ) else {
            return nil
        }

        // 2. Insert/get mapelIDs (bisa write)
        var mapel2id: [String: Int64] = [:]
        for mapel in Set(mapelArray) {
            if let id = await IdsCacheManager.shared.mapelID(for: mapel) {
                mapel2id[mapel] = id
            }
        }

        // 3. Insert/get guruIDs (bisa write)
        var guru2id: [String: Int64] = [:]
        for guru in Set(guruArray) {
            if let id = await dbController.insertOrGetGuruID(nama: guru) {
                guru2id[guru] = id
            }
        }

        // 4. Return hasil lengkap
        return (mapel2id: mapel2id, guru2id: guru2id, kelasID: kelasID)
    }

    private func updateDatabase(data: DataNilaiSiswa) async {
        for (index, mapel) in data.mapelArray.enumerated() {
            guard let nilai = Int(data.nilaiArray[index]) else {
                ReusableFunc.showAlert(title: "Input Harus Nomor", message: "Harap masukkan nilai numerik")
                continue
            }
            let guru = data.guruArray[index]
            guard let jabatanNama = data.jabatanByGuru[guru],
                  let jid = await IdsCacheManager.shared.jabatanID(for: jabatanNama)
            else {
                // Kalau tidak ada mapping, lewati saja
                continue
            }

            // langsung panggil fungsi async-mu
            await insertPenugasanDanNilai(
                mapel: mapel,
                guru: guru,
                namaJabatan: jabatanNama,
                jabatanID: jid,
                nilai: nilai,
                siswaID: data.siswaID,
                selectedSiswaName: data.selectedSiswaName,
                selectedKelasTitle: data.selectedKelasTitle,
                namaKelas: bagianKelas.titleOfSelectedItem!,
                thnAjaran: data.thnAjrn,
                semester: data.formattedSemester,
                tanggalString: data.tanggalString,
                mapel2id: data.idNamaMapel,
                guru2id: data.idNamaGuru,
                kelasID: data.kelasID
            )
        }
    }
}
