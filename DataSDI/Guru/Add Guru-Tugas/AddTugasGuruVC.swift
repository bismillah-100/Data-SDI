//
//  AddTugasGuruVC.swift
//  Data SDI
//
//  Created by MacBook on 09/07/25.
//

import Cocoa

/// Pengelola logika tampilan untuk menambahkan guru baru dan atau
/// penugasan guru pada mapel dan kelas tertentu.
class AddTugasGuruVC: NSViewController {
    /// Properti `NSTextField` nama untuk menambah/mengedit data.
    var nameTextField: NSTextField!
    /// Properti `NSTextField` alamat untuk menambah/mengedit data.
    var addressTextField: NSTextField!
    /// Properti `NSTextField` mata pelajaran untuk menambah/mengedit data.
    var mapelTextField: NSTextField!
    /// Properti `NSTextField` tahun ajaran untuk menambah/mengedit data.
    var tahunAjaran1TextField: NSTextField!
    /// Properti `NSTextField` tahun ajaran untuk menambah/mengedit data.
    var tahunAjaran2TextField: NSTextField!
    /// Properti `NSPopUpButton` untuk pemilihan nama guru dalam mode add/edit Tugas Guru.
    var namaPopUpButton: NSPopUpButton!
    /// Properti `NSPopUpButton` untuk pemilihan jabatan guru dalam mode add/edit Tugas Guru.
    var jabatanPopUpButton: NSPopUpButton!
    /// Properti `NSPopUpButton` untuk pemilihan kelas dalam mode add/edit Tugas Guru.
    var kelasPopUpButton: NSPopUpButton!
    /// Properti `NSPopUpButton` untuk pemilihan kelas dalam mode add/edit Tugas Guru.
    var bagianKelasPopUpButton: NSPopUpButton!
    /// Properti `NSPopUpButton` untuk pemilihan semester dalam mode add/edit Tugas Guru.
    var semesterPopUpButton: NSPopUpButton!
    /// Properti pemilihan tanggal mulai menggunakan ``ExpandingDatePicker``
    var tanggalMulai: ExpandingDatePicker!
    /// Properti pemilihan tanggal selesai menggunakan ``ExpandingDatePicker``
    var tanggalSelesai: ExpandingDatePicker!
    /// Tombol untuk mengubah nilai ``statusTugas`` ke `true`.
    var aktifSttsButton: NSButton!
    /// Tombol untuk mengubah nilai ``statusTugas`` ke `false`.
    var nonAktifSttsButton: NSButton!

    /// Properti data guru dari baris-baris yang dipilih di ``GuruVC`` atau ``TugasMapelVC`` yang akan diedit.
    var dataToEdit: [GuruModel] = []

    /// Closure yang menjalankan logika penyimpanan data baru ketika tombol ditekan.
    var onSimpanGuru: (([GuruWithUpdate]) -> Void)?

    /// Closure yang menjalankan logika untuk menutup jendela sheet.
    var onClose: (() -> Void)?

    /// Opsi tampilan. Ketika opsi bernilai "addGuru" atau "editGuru" akan menambahkan 2 textField [nama dan alamat].
    /// Ketika opsi bernilai "addTugasGruru" atau "editTugasGuru" akan menambahkan 3 textField [mapel, year, struktur].
    var options: String = "guru"

    /// Instans ``DatabaseController``.
    let dbController = DatabaseController.shared

    /// Nama field untuk label textField yang akan ditambahkan ke view.
    var fieldNames: [String] = []

    /// Opsi untuk mengubah status penugasan guru.
    var statusTugas: Bool = true

    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!

    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    /// Properti untuk menyimpan referensi jendela untuk membuat item baru di dalam `NSPopUpButton`.
    var kategoriWindow: NSWindowController?

    override func loadView() {
        if options == "addGuru" || options == "editGuru" {
            fieldNames = ["Nama Guru:", "Alamat Guru:"]
        } else {
            fieldNames = ["Mata Pelajaran:", "NamaPopup", "Sebagai:"]
        }
        createView(options, guru: dataToEdit)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        syncStatusUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        suggestionManager = SuggestionManager(suggestions: [""])
    }

    /// Fungsi yang memanggil closure ``onSimpanGuru`` ketika tombol tambahkan ditekan.
    @objc func simpanGuru(_: Any) {
        if options == "addGuru" || options == "editGuru" {
            editOrAddGuru()
            return
        }

        Task {
            if options == "addTugasGuru" {
                await tambahTugasGuru()
                return
            }
            if options == "editTugasGuru" {
                await editTugasGuru()
                return
            }
        }
    }

    /// Menambahkan guru baru atau mengedit data guru yang sudah ada, lalu mengirim hasilnya melalui closure `onSimpanGuru`.
    ///
    /// Fungsi ini membaca nilai dari `nameTextField` dan `addressTextField`, kemudian menentukan apakah operasi adalah penambahan guru baru atau pengeditan berdasarkan nilai `options`.
    ///
    /// - Jika `options == "addGuru"`, maka:
    ///   - Guru baru akan ditambahkan ke database menggunakan `dbController.addGuru`.
    ///   - Objek `GuruModel` baru dibuat dan dikirim ke `onSimpanGuru`.
    ///
    /// - Jika mode bukan penambahan:
    ///   - Data guru yang sedang diedit (`dataToEdit`) akan diperbarui dengan nilai baru (jika tersedia).
    ///   - Deep-copy dilakukan menggunakan `.copy()` untuk memastikan perbedaan terdeteksi dengan benar.
    ///   - Hasil perubahan dikirim melalui closure `onSimpanGuru`.
    ///
    /// - Note:
    ///   - Nama atau alamat kosong tidak akan menimpa nilai yang sudah ada jika mengedit data guru.
    ///   - Closure `onSimpanGuru` bertipe `(([guru: GuruModel, update: UpdatePenugasanGuru]) -> Void)?` dan akan dipanggil dengan array perubahan.
    ///
    /// - Warning:
    ///   - Fungsi ini akan keluar lebih awal (`return`) jika nilai teks tidak valid atau jika penambahan guru ke database gagal.
    func editOrAddGuru() {
        guard let nama = nameTextField?.stringValue,
              let alamat = addressTextField?.stringValue
        else { return }

        if options == "addGuru" {
            guard !nama.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                ReusableFunc.showAlert(title: "Nama belum diisi.", message: "Mohon isi nama guru dengan benar.")
                return
            }
            guard let idGuru = dbController.tambahGuru(nama, alamat: alamat) else { return }
            let guruBaru = GuruModel(idGuru: idGuru, idTugas: nil, nama: nama, alamat: alamat, tahunaktif: nil, mapel: nil, struktural: nil, statusTugas: nil, kelas: nil, tglMulai: nil)

            onSimpanGuru?([(
                guru: guruBaru,
                update: UpdatePenugasanGuru()
            )])

            return
        }

        var paket = [GuruWithUpdate]()

        for guru in dataToEdit {
            var guruUpdate = GuruModel(idGuru: guru.idGuru, idTugas: guru.idTugas)
            guruUpdate = guru.copy() // Deep-copy untuk keperluan pair != di viewModel.

            guruUpdate.namaGuru = nama.isEmpty ? guruUpdate.namaGuru : nama
            guruUpdate.alamatGuru = alamat.isEmpty ? guruUpdate.alamatGuru : alamat

            paket.append(contentsOf: [(
                guru: guruUpdate,
                update: UpdatePenugasanGuru()
            )])
        }
        onSimpanGuru?(paket)
    }

    /// Menambahkan tugas guru berdasarkan input dari berbagai field pada UI.
    /// Fungsi ini akan mengambil data dari field seperti tahun ajaran, guru, tanggal mulai, kelas, mapel, jabatan, dan semester.
    /// Kemudian, fungsi akan melakukan validasi dan mendapatkan atau memasukkan data terkait ke database.
    /// Setelah data berhasil dikumpulkan dan diproses, fungsi akan membentuk objek `GuruModel` baru dan memanggil closure `onSimpanGuru`
    /// untuk mengirimkan data guru yang baru beserta status update penugasan.
    ///
    /// - Note: Fungsi ini berjalan secara asynchronous.
    /// - Returns: Tidak mengembalikan nilai, namun akan memanggil closure `onSimpanGuru` jika data berhasil diproses.
    func tambahTugasGuru() async {
        guard !tahunAjaran1TextField.stringValue.isEmpty,
              !tahunAjaran2TextField.stringValue.isEmpty
        else {
            ReusableFunc.showAlert(title: "Tahun Ajaran Kosong", message: "Masukkan tahun ajaran yang valid.")
            return
        }

        let tahunAjaran = tahunAjaran1TextField.stringValue + "/" + tahunAjaran2TextField.stringValue
        guard tahunAjaran1TextField.stringValue.allSatisfy({ $0.isNumber }),
              tahunAjaran2TextField.stringValue.allSatisfy({ $0.isNumber })
        else {
            ReusableFunc.showAlert(title: "Tahun Ajaran Harus Berupa Angka", message: "Masukkan tahun ajaran yang valid.")
            return
        }

        guard let selectedSemester = semesterPopUpButton.titleOfSelectedItem else {
            ReusableFunc.showAlert(title: "Semester tidak valid.", message: "Pilih semester yang valid.")
            return
        }

        let semester = selectedSemester.contains("Semester")
            ? selectedSemester.replacingOccurrences(of: "Semester ", with: "")
            : selectedSemester

        let namaMapel = mapelTextField.stringValue

        guard let guruID = namaPopUpButton.selectedItem?.tag, guruID != 0,
              let tanggalMulai = ReusableFunc.buatFormatTanggal(tanggalMulai.dateValue),
              let namaGuru = namaPopUpButton.selectedItem?.title,
              let namaKelas = kelasPopUpButton.selectedItem?.title,
              let bagianKelas = bagianKelasPopUpButton.selectedItem?.title,
              let jabatanID = jabatanPopUpButton.selectedItem?.tag,
              let namaJabatan = jabatanPopUpButton.titleOfSelectedItem
        else {
            ReusableFunc.showAlert(title: "Form harus lengkap.", message: "Lengkapi form dengan data yang valid.")
            return
        }

        async let idMapel = await IdsCacheManager.shared.mapelID(for: namaMapel)
        async let kelasID = await dbController.insertOrGetKelasID(nama: bagianKelas, tingkat: namaKelas, tahunAjaran: tahunAjaran, semester: semester)

        guard let idMapel = await idMapel,
              let kelasID = await kelasID
        else {
            await MainActor.run {
                ReusableFunc.showAlert(title: "Gagal Mendapatkan Data", message: "Mapel atau kelas tidak valid.")
            }
            return
        }

        // hanya pindahkan ke MainActor jika gagal dan perlu alert
        guard let idTugas = dbController.buatPenugasanGuru(idGuru: Int64(guruID), idJabatan: Int64(jabatanID), idMapel: idMapel, idKelas: kelasID, tanggalMulai: tanggalMulai, statusTugas: statusTugas ? .aktif : .selesai) else {
            await MainActor.run {
                ReusableFunc.showAlert(
                    title: "Penugasan Telah Tercatat.",
                    message: "Data penugasan untuk guru, mata pelajaran, kelas, dan semester ini sudah ada sebelumnya."
                )
            }
            return
        }

        let tglSelesai = tanggalSelesai.isEnabled ? ReusableFunc.buatFormatTanggal(tanggalSelesai.dateValue)! : ""
        let displayedSemester = (semester == "1" || semester == "2") ? "Semester \(semester)" : semester

        let newData = GuruModel(idGuru: Int64(guruID), idTugas: idTugas, nama: namaGuru, alamat: addressTextField?.stringValue ?? "", tahunaktif: tahunAjaran, mapel: mapelTextField?.stringValue ?? "", struktural: namaJabatan, statusTugas: statusTugas ? .aktif : .selesai, kelas: namaKelas + " " + bagianKelas + " - " + displayedSemester, tglMulai: tanggalMulai, tglSelesai: tglSelesai)

        await MainActor.run { [unowned self] in
            self.onSimpanGuru?([(
                guru: newData,
                update: UpdatePenugasanGuru()
            )])
        }
    }

    /// Mengedit data tugas guru berdasarkan data yang telah dipilih.
    /// Fungsi ini akan memperbarui data guru pada array `dataToEdit` dengan informasi terbaru seperti tanggal mulai, tanggal selesai, jabatan, dan mapel.
    /// Setelah data diperbarui, fungsi akan membentuk paket data yang berisi model guru beserta data update penugasan, lalu memanggil closure `onSimpanGuru` pada MainActor untuk menyimpan perubahan.
    ///
    /// - Note: Fungsi ini berjalan secara asynchronous.
    /// - Important: Pastikan semua field yang diperlukan telah terisi dengan benar sebelum memanggil fungsi ini.
    ///
    func editTugasGuru() async {
        let status = statusTugas ? StatusSiswa.aktif : StatusSiswa.selesai
        var paket = [GuruWithUpdate]()
        for (i, guru) in dataToEdit.enumerated() {
            let tanggalBerhenti = tanggalSelesai.isEnabled
                ? ReusableFunc.buatFormatTanggal(tanggalSelesai.dateValue)!
                : nil

            var namaMapel = mapelTextField.stringValue.isEmpty
                ? guru.mapel
                : mapelTextField.stringValue

            let namaJabatan = jabatanPopUpButton.isEnabled
                ? jabatanPopUpButton.titleOfSelectedItem ?? ""
                : guru.struktural ?? ""

            namaMapel = hurufBesar
                ? namaMapel?.uppercased()
                : namaMapel?.capitalizedAndTrimmed()

            let tanggalMulai = tanggalMulai.isEnabled
                ? ReusableFunc.buatFormatTanggal(tanggalMulai.dateValue)!
                : guru.tglMulai

            guard let jabatanID = await IdsCacheManager.shared.jabatanID(for: namaJabatan),
                  let idMapel = await IdsCacheManager.shared.mapelID(for: namaMapel ?? "")
            else { continue }

            var updatedGuru = dataToEdit[i].copy()
            updatedGuru = GuruModel(idGuru: guru.idGuru, idTugas: guru.idTugas, nama: guru.namaGuru, alamat: guru.alamatGuru, tahunaktif: guru.tahunaktif, mapel: namaMapel, struktural: namaJabatan, statusTugas: status, kelas: guru.kelas, tglMulai: tanggalMulai, tglSelesai: tanggalBerhenti)
            paket.append(contentsOf: [(
                guru: updatedGuru,
                update: UpdatePenugasanGuru(idJabatan: Int64(jabatanID), idMapel: idMapel)
            )])
        }
        await MainActor.run { [unowned self] in
            self.onSimpanGuru?(paket)
        }
    }

    /// Memanggil closure ``onClose`` untuk menutup sheet
    /// dari view yang menampilkannya.
    /// - Parameter sender: Objek pemicu.
    @objc
    func tutupSheet(_: Any) {
        onClose?()
    }

    /// Mengubah status tugas berdasarkan tombol yang ditekan.
    /// - Parameter sender: NSButton yang men-trigger aksi ini. Jika tombol `aktifSttsButton` ditekan, maka `statusTugas` akan diatur menjadi `true`. Jika tombol `nonAktifSttsButton` ditekan, maka `statusTugas` akan diatur menjadi `false`.
    /// Setelah status diubah, fungsi ini akan memanggil `syncStatusUI()` untuk memperbarui tampilan status pada UI.
    @objc func ubahStatus(_ sender: NSButton) {
        if sender == aktifSttsButton {
            statusTugas = true
        } else if sender == nonAktifSttsButton {
            statusTugas = false
        }
        syncStatusUI()
    }

    /// Mengubah status pemilihan tanggal mulai tugas menjadi
    /// aktif atau nonaktif sesuai dengan state .on atau .off sender yang merupakan `NSButton`.
    /// - Parameter sender: Objek pemicu harus berupa `NSButton`.
    @objc func enableTanggalMulai(_ sender: NSButton) {
        tanggalMulai.isEnabled = sender.state == .on
    }

    /// Menyinkronkan tampilan UI berdasarkan status tugas saat ini.
    /// - Mengatur apakah tanggal selesai dapat diedit berdasarkan status tugas.
    /// - Mengatur status tombol aktif dan non-aktif sesuai dengan status tugas (`statusTugas`).
    func syncStatusUI() {
        tanggalSelesai?.isEnabled = !statusTugas
        aktifSttsButton?.state = statusTugas ? .on : .off
        nonAktifSttsButton?.state = statusTugas ? .off : .on
    }

    /// Properti `Bool` yang mengontrol apakah teks di beberapa `NSTextField` harus dikapitalisasi
    /// secara otomatis atau tidak.
    ///
    /// Ketika nilai ``kapitalkan`` berubah menjadi `true`:
    /// 1. Teks di ``mapelTextField`` akan dikonversi menjadi huruf kapital.
    ///    Ini dilakukan dengan memanggil metode `kapitalkanSemua()`
    ///    pada array `NSTextField` tersebut.
    /// 2. Jika ``dataToEdit`` (jumlah baris yang dipilih untuk diedit) lebih dari satu,
    ///    maka `placeholderString` dari setiap `NSTextField` tersebut juga akan dikapitalisasi.
    ///    Ini berguna untuk memberikan indikasi visual pada placeholder bahwa input akan dikapitalisasi
    ///    saat dalam mode pengeditan multi-baris.
    ///
    /// Properti ini tidak melakukan tindakan apa pun jika `kapitalkan` diatur menjadi `false`.
    var kapitalkan: Bool = false {
        didSet {
            if kapitalkan { // Memeriksa apakah nilai baru `kapitalkan` adalah `true`.
                // Mengkapitalisasi teks di semua text field yang relevan.
                capitalizeOrUppercase(true)
            }
        }
    }

    /// Properti `Bool` yang mengontrol apakah teks di beberapa `NSTextField` harus dikonversi
    /// menjadi huruf besar secara otomatis atau tidak.
    ///
    /// Ketika nilai ``hurufBesar`` berubah menjadi `true`:
    /// 1. Teks di ``nameTextField`` dan atau ``mapelTextField`` (jika ditampilkan) akan dikonversi menjadi huruf besar.
    ///    Ini dilakukan dengan memanggil metode `kapitalkanSemua()`
    ///    pada array `NSTextField` tersebut.
    /// 2. Jika ada lebih dari satu data yang dipilih untuk diedit (``dataToEdit``),
    ///    maka teks `placeholderString` dari setiap `NSTextField` tersebut juga akan dikonversi menjadi huruf besar.
    ///    Ini memberikan isyarat visual kepada pengguna bahwa input yang diharapkan akan dalam format huruf besar
    ///    ketika melakukan pengeditan multi-baris.
    ///
    /// Properti ini tidak melakukan tindakan apa pun jika ``hurufBesar`` diatur menjadi `false`.
    var hurufBesar: Bool = false {
        didSet {
            if hurufBesar { // Memeriksa apakah nilai baru `hurufBesar` adalah `true`.
                capitalizeOrUppercase(false)
            }
        }
    }

    private func capitalizeOrUppercase(_ capitalize: Bool) {
        // Mengkapitalisasi teks di semua text field yang relevan.
        if let mapelTextField {
            let stringValue = mapelTextField.stringValue
            mapelTextField.stringValue = capitalize ? .capitalized(stringValue)(with: .current) : .uppercased(stringValue)()
        }
        if let nameTextField {
            let stringValue = nameTextField.stringValue
            nameTextField.stringValue = capitalize ? .capitalized(stringValue)(with: .current) : .uppercased(stringValue)()
        }
        if let addressTextField {
            let stringValue = addressTextField.stringValue
            addressTextField.stringValue = capitalize ? .capitalized(stringValue)(with: .current) : .uppercased(stringValue)()
        }

        // Logika khusus untuk pengeditan multi-baris.
        if dataToEdit.count > 1 {
            if let mapelTextField {
                let string = mapelTextField.placeholderString ?? ""

                mapelTextField.placeholderString = capitalize
                    ? .capitalized(string)(with: .current) : .uppercased(string)()
            }
            if let nameTextField {
                let string = nameTextField.placeholderString ?? ""
                nameTextField.placeholderString = capitalize
                    ? .capitalized(string)(with: .current) : .uppercased(string)()
            }
            if let addressTextField {
                let string = addressTextField.placeholderString ?? ""
                addressTextField.placeholderString = capitalize
                    ? .capitalized(string)(with: .current) : .uppercased(string)()
            }
        }
    }

    /// Action untuk tombol yang mengubah nilai ``kapitalkan`` ke true.
    /// Dan mengubah nilai ``hurufBesar`` ke false.
    @objc func kapitalkan(_: Any) {
        kapitalkan = true
        hurufBesar = false
    }

    /// Action untuk tombol yang mengubah nilai ``hurufBesar`` ke true.
    /// Dan mengubah nilai ``kapitalkan`` ke false.
    @objc func hurufBesar(_: Any) {
        hurufBesar = true
        kapitalkan = false
    }

    deinit {
        for v in view.subviews {
            v.removeFromSuperviewWithoutNeedingDisplay()
        }
        view.removeFromSuperview()
        dataToEdit.removeAll()
        onSimpanGuru = nil
        onClose = nil
        #if DEBUG
            print("deinit AddTugasGuruVC")
        #endif
    }
}
