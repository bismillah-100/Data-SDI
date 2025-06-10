//
//  PastediKelas.swift
//  Data Manager
//
//  Created by Bismillah on 21/11/23.
//

import Cocoa
import SQLite

/// Class yang menangani logika tempel (paste) di ``KelasVC``.
class PastediKelas: NSViewController {
    let dbController = DatabaseController.shared
    /// Outlet menu popup pilihan kelas.
    @IBOutlet weak var kelasPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan semester.
    @IBOutlet weak var smstrPopUpButton: NSPopUpButton!
    /// Outlet menu popup pilihan nama.
    @IBOutlet weak var namaPopUpButton: NSPopUpButton!
    /// Outlet tombol "simpan".
    @IBOutlet weak var smpnButton: NSButton!
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

    /**
         Array yang menyimpan data kelas. Setiap elemen dalam array adalah tuple yang berisi indeks (Int) dan data kelas (KelasModels).
     */
    var dataArray: [(index: Int, data: KelasModels)] = []

    /// Referensi identifier untuk jendela.
    /// Deprecated.
    var windowIdentifier: String?

    /// Properti untuk referensi jendela yang ditampilkan ketika akan membuat kategori (semester) baru.
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

    /// Action untuk ``kelasPopUpButton``.
    /// Fungsi ini memperbarui ``namaPopUpButton`` dengan data yang sesuai pada Kelas Aktif terpilih.
    /// - Parameter sender: Objek pemicu `NSPopUpButton`.
    @IBAction func kelasPopUpButtonDidChange(_ sender: NSPopUpButton) {
        loadNamaSiswaForSelectedKelas()
    }

    /// Menentukan pemilihan awal kelas di ``kelasPopUpButton``
    /// dan memuat nama-nama siswa yang ada di kelas.
    /// - Parameter index: Indeks kelas yang akan dipilih.
    func kelasTerpilih(index: Int) {
        kelasPopUpButton.selectItem(at: index)
        loadNamaSiswaForSelectedKelas()
    }

    /**
         Mengisi popup button nama dengan data dari tabel yang ditentukan.

         Fungsi ini mengambil data nama siswa dan ID siswa dari database berdasarkan tabel yang diberikan,
         kemudian mengisi popup button `namaPopUpButton` dengan nama-nama siswa tersebut.
         Setiap item di popup button akan memiliki tag yang sesuai dengan ID siswa.

         - Parameter table: Nama tabel yang akan digunakan untuk mengambil data siswa.
     */
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

    /// Fungsi untuk menutup tampilan ``PastediKelas``.
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            window.sheetParent?.endSheet(window, returnCode: .cancel)
        }
    }

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
}

extension PastediKelas {
    /**
     * Fungsi ini menangani aksi saat tombol "Paste" diklik.
     * Fungsi ini membaca data dari clipboard, memprosesnya berdasarkan format yang ditemukan (dipisahkan oleh tab, koma, atau baris baru),
     * dan memasukkan data tersebut ke dalam database. Data yang dimasukkan mencakup mata pelajaran, nilai, dan nama guru (opsional).
     *
     * - Parameter sender: Objek yang memicu aksi ini.
     *
     * Proses:
     * 1. Mendapatkan nama tabel yang dipilih dari `kelasPopUpButton`.
     * 2. Mendapatkan nama siswa dan ID siswa yang dipilih dari `namaPopUpButton`.
     * 3. Mendapatkan semester yang dipilih dari `smstrPopUpButton`.
     * 4. Membaca string dari clipboard.
     * 5. Membagi string menjadi baris-baris.
     * 6. Untuk setiap baris:
     *    - Membagi baris menjadi komponen-komponen berdasarkan tab atau koma.
     *    - Memvalidasi jumlah komponen dan format nilai (jika ada).
     *    - Memasukkan data ke dalam tabel yang sesuai menggunakan `dbController.insertDataToKelas` atau `dbController.tambahDataKelas`.
     *    - Menangani kesalahan format dan menampilkan pesan kesalahan jika diperlukan.
     * 7. Menutup jendela setelah selesai.
     * 8. Memposting notifikasi untuk memperbarui tampilan tabel.
     *
     * Notifikasi:
     * - `DatabaseController.dataDidChangeNotification`: Memberitahu bahwa data di database telah berubah.
     * - `UpdateTableNotification`: Memberitahu untuk memperbarui tampilan tabel dengan data yang baru dimasukkan.
     */
    @IBAction func pasteItemClicked(_ sender: Any) {
        // Mendapatkan kelasTable berdasarkan tabel yang dipilih
        guard let selectedTableTitle = kelasPopUpButton.titleOfSelectedItem?.replacingOccurrences(of: " ", with: "") else {
            return
        }
        let kelasTable = Table(selectedTableTitle)

        // Mendapatkan nama siswa dan siswaID berdasarkan nama siswa yang dipilih
        guard let selectedSiswaName = namaPopUpButton.titleOfSelectedItem,
              let siswaID = dbController.getSiswaIDForNamaSiswa(selectedSiswaName)
        else {
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
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "UpdateTableNotification"), object: nil, userInfo: ["data": self.dataArray, "tambahData": true, "windowIdentifier": self.windowIdentifier ?? ""])
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
    /**
         Menangani aksi ketika jendela semester ditutup.

         Setelah jendela semester ditutup, fungsi ini akan dipanggil untuk mengatur `semesterWindow` menjadi `nil`.
         Hal ini dilakukan untuk membersihkan referensi ke jendela yang telah ditutup dan mencegah potensi masalah memori atau perilaku yang tidak terduga.
     */
    func didCloseWindow() {
        semesterWindow = nil
    }

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
