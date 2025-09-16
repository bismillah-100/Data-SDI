//
//  EditData.swift
//  Data SDI
//
//  Created by Bismillah on 27/12/23.
//

import Cocoa

/// Class yang menangani pengeditan data siswa seperti nama siswa, alamat, nis dll.
///
/// Add-On untuk pratinjau foto: <doc:Pratinjau-Foto>.
class EditData: NSViewController {
    // MARK: - UI

    /// Outlet ScrollView
    @IBOutlet weak var scrollView: NSScrollView!

    /// Outlet imageView.
    @IBOutlet weak var imageView: XSDragImageView!

    /// Outlet tombol "Edit".
    @IBOutlet weak var pilihFoto: NSButton!

    /// Outlet tombol "Hapus".
    @IBOutlet weak var hapusFoto: NSButton!

    /// Outlet tombol "Ekspor".
    @IBOutlet weak var eksporFoto: NSButton!

    /// Outlet pemilihan tanggal pendaftaran.
    @IBOutlet weak var tglDaftar: ExpandingDatePicker!

    /// Outlet pemilihan tanggal berhenti.
    @IBOutlet weak var tglBerhenti: ExpandingDatePicker!

    /// Outlet tombol on/off kelamin.
    @IBOutlet weak var kelaminSwitch: NSButton!

    /// Outlet tombol on/off kelas.
    @IBOutlet weak var kelasSwitch: NSButton!

    /// Outlet tombol on/off status.
    @IBOutlet weak var statusSwitch: NSButton!

    /// Outlet tombol on/off tanggal pendaftaran.
    @IBOutlet weak var tglPendaftaranSwitch: NSButton!

    /// Outlet tombol "Batalkan".
    @IBOutlet weak var batalkantmbl: NSButton!

    /// Outlet tombol "Simpan".
    @IBOutlet weak var tmblsimpan: NSButton!

    /// Outlet tombol "Pratinjau".
    @IBOutlet weak var pratinjau: NSButton!

    // MARK: - TextField

    /// Outlet untuk field pengetikan nama siswa.
    @IBOutlet weak var namaSiswa: CustomTextField!

    /// Outlet untuk field pengetikan alamat siswa.
    @IBOutlet weak var alamatSiswa: CustomTextField!

    /// Outlet untuk field pengetikan ttl.
    @IBOutlet weak var ttlTextField: CustomTextField!

    /// Outlet untuk field pengetikan NIS.
    @IBOutlet weak var NIS: CustomTextField!

    /// Outlet untuk field pengetikan nama wali.
    @IBOutlet weak var namawaliTextField: CustomTextField!

    /// Outlet untuk field pengetikan nama ibu.
    @IBOutlet weak var ibu: CustomTextField!

    /// Outlet untuk field pengetikan nomor telepon.
    @IBOutlet weak var tlv: CustomTextField!

    /// Outlet untuk field pengetikan nama ayah.
    @IBOutlet weak var ayah: CustomTextField!

    /// Outlet untuk field pengetikan NISN.
    @IBOutlet weak var NISN: CustomTextField!

    // MARK: - Label

    /// Outlet label nama.
    @IBOutlet weak var namaLabel: CustomTextField!
    /// Outlet label alamat.
    @IBOutlet weak var alamatLabel: CustomTextField!
    /// Outlet label ttl.
    @IBOutlet weak var ttlteks: CustomTextField!
    /// Outlet label nis.
    @IBOutlet weak var nisteks: CustomTextField!
    /// Outlet label nama wali.
    @IBOutlet weak var namaortuteks: CustomTextField!
    /// Outlet label tanggal berhenti.
    @IBOutlet weak var tglBerhentiTeks: CustomTextField!

    // MARK: - Data

    /// Array yang menyimpan data-data siswa yang akan diperbarui.
    var selectedSiswaList: [ModelSiswa] = []
    /// Instance ``DatabaseController``.
    let dbController: DatabaseController = .shared

    // MARK: - Pilihan

    /// Properti yang menyimpan referensi status tombol ``tglPendaftaranSwitch``.
    private var aktifkanTglDaftar: Bool = false
    /// Properti yang menyimpan referensi status ``imageView``.
    private var nonaktifkanImageView: Bool = true

    // MARK: - AutoComplete Teks

    /// Instance ``SuggestionManager``.
    private var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    private var activeText: CustomTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let v = view as? NSVisualEffectView {
            v.blendingMode = .behindWindow
            v.material = .windowBackground
            v.state = .followsWindowActiveState
        }
        namaSiswa.delegate = self
        ttlTextField.delegate = self
        alamatSiswa.delegate = self
        namawaliTextField.delegate = self
        ayah.delegate = self
        ibu.delegate = self
        NIS.delegate = self
        NISN.delegate = self
        tlv.delegate = self
        thnAjaran1.delegate = self
        thnAjaran2.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if selectedSiswaList.count == 1, let siswaData = selectedSiswaList.first {
            // StringValue
            namaSiswa.stringValue = siswaData.nama
            alamatSiswa.stringValue = siswaData.alamat
            ttlTextField.stringValue = siswaData.ttl
            NIS.stringValue = siswaData.nis
            NISN.stringValue = siswaData.nisn
            ayah.stringValue = siswaData.ayah
            ibu.stringValue = siswaData.ibu
            namawaliTextField.stringValue = siswaData.namawali
            tlv.stringValue = siswaData.tlv
            selectKelasRadio()

            switch siswaData.jeniskelamin {
            case .lakiLaki: lakiLakiRadio.state = .on
            case .perempuan: perempuanRadio.state = .on
            }

            switch siswaData.status {
            case .aktif:
                setStatusUI(statusOn: statusAktif, enableTanggal: false, enableKelas: false)
            case .lulus:
                setStatusUI(statusOn: statusLulus, enableTanggal: true, enableKelas: false)
            case .berhenti:
                setStatusUI(statusOn: statusBerhenti, enableTanggal: true, enableKelas: false)
            default:
                break
            }

            statusSwitch.state = .off
            enableStatusRadio(false)

            aktifkanTglDaftar = true
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMMM yyyy"
            if let tglPndftrn = dateFormatter.date(from: siswaData.tahundaftar) { tglDaftar.dateValue = tglPndftrn }
            if let tglBrhnt = dateFormatter.date(from: siswaData.tanggalberhenti) { tglBerhenti.dateValue = tglBrhnt }
            nonaktifkanImageView = false
        } else if selectedSiswaList.count > 1 {
            namaSiswa.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            alamatSiswa.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ttlTextField.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            NIS.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            namawaliTextField.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            NISN.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ayah.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            ibu.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            tlv.placeholderString = "terdapat \(selectedSiswaList.count) data siswa"
            jenisKelaminButtons.forEach { $0.isEnabled = false }
            kelaminSwitch.state = .off
            enableKelasRadio(false)
            kelasSwitch.state = .off
            aktifkanTglDaftar = false
            statusRadioButtons.forEach { $0.isEnabled = false }
            statusSwitch.state = .off
            kelasRadioButtons.forEach { $0.state = .off }
            kelasSwitch.isEnabled = false
            enableKelasRadio(false)
            pilihFoto.isEnabled = false
            imageView.removeFromSuperviewWithoutNeedingDisplay()
            nonaktifkanImageView = true
            hapusFoto.isEnabled = false
            eksporFoto.isEnabled = false
            tglDaftar.isEnabled = false
            tglBerhenti.isEnabled = false
            pratinjau.isEnabled = false
            tglPendaftaranSwitch.state = .off
            imageView.frame = CGRect.zero
            pilihFoto.frame = CGRect.zero
            hapusFoto.frame = CGRect.zero
            eksporFoto.frame = CGRect.zero
        }
    }

    override func viewDidAppear() {
        DispatchQueue.main.async {
            ReusableFunc.resetMenuItems()
        }
    }

    override func viewWillDisappear() {
        NotificationCenter.default.post(name: .popupDismissed, object: nil)
        if tglDaftarBerhenti || kelaminSwitch.state == .on {
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        }
    }

    private // Fungsi helper untuk mengatur status UI
    func setStatusUI(
        statusOn: NSButton,
        enableTanggal: Bool,
        enableKelas: Bool
    ) {
        statusOn.state = .on
        tglBerhenti.isEnabled = enableTanggal
        enableKelasRadio(enableKelas)
        kelasSwitch.state = enableKelas ? .on : .off
        kelasSwitch.isEnabled = enableKelas
    }

    private var kelasRadioButtons: [NSButton] {
        [kelas1Radio, kelas2Radio, kelas3Radio, kelas4Radio, kelas5Radio, kelas6Radio]
    }

    private var jenisKelaminButtons: [NSButton] {
        [lakiLakiRadio, perempuanRadio]
    }

    private var statusRadioButtons: [NSButton] {
        [statusAktif, statusBerhenti, statusLulus]
    }

    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas1Radio: NSButton!
    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas2Radio: NSButton!
    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas3Radio: NSButton!
    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas4Radio: NSButton!
    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas5Radio: NSButton!
    /// Outlet untuk tombol radio kelas siswa.
    @IBOutlet weak var kelas6Radio: NSButton!
    /// Outlet untuk tombol radio jenis kelamin laki-laki.
    @IBOutlet weak var lakiLakiRadio: NSButton!
    /// Outlet untuk tombol radio jenis kelamin perempuan.
    @IBOutlet weak var perempuanRadio: NSButton!

    /// Outlet untuk tahun ajaran 1.
    @IBOutlet weak var thnAjaran1: CustomTextField!
    /// Outlet untuk tahun ajaran 2.
    @IBOutlet weak var thnAjaran2: CustomTextField!
    /// Outlet untuk pop-up semester.
    @IBOutlet weak var popUpSemester: NSPopUpButton!

    private func enableEditKelas(_ enable: Bool) {
        thnAjaran1.isEnabled = enable
        thnAjaran2.isEnabled = enable
        popUpSemester.isEnabled = enable
    }

    /// Aksi yang dipicu ketika salah satu tombol jenis kelamin (laki-laki atau perempuan) ditekan.
    /// - Parameter sender: NSButton yang mewakili tombol jenis kelamin.
    @IBAction func kelaminAction(_: NSButton) {
        // Tidak ada aksi khusus yang diperlukan di sini, hanya untuk mengaktifkan/menonaktifkan tombol jenis kelamin.
    }

    /// Aksi yang dipicu ketika tombol switch jenis kelamin ditekan.
    /// - Parameter sender: ``kelaminSwitch``.
    @IBAction func kelaminSwitch(_ sender: NSButton) {
        let enable = sender.state == .on
        jenisKelaminButtons.forEach { $0.isEnabled = enable }
    }

    /// Aksi yang dipicu ketika salah satu tombol status (aktif, berhenti, dan lulus) ditekan.
    /// - Parameter sender: NSButton.
    @IBAction func statusAction(_ sender: NSButton) {
        let shouldEnable = sender.title == "Aktif"
        kelasSwitch.isEnabled = false
        kelasSwitch.state = shouldEnable ? .on : .off

        tglBerhenti.isEnabled = !shouldEnable
        enableKelasRadio(shouldEnable)
        if selectedSiswaList.count == 1 {
            selectKelasRadio()
        } else {
            kelasRadioButtons.forEach { $0.state = .off }
        }
    }

    @IBAction func kelasAction(_: NSButton) {
//        pilihKelasSwitch.toggle()
//
//        guard selectedSiswaList.count > 1 else { return }
//        let shouldEnable = pilihKelasSwitch
//        pilihStatusSwitch = shouldEnable
//        statusSwitch.animator().state = shouldEnable ? .on : .off
    }

    /**
     Aksi yang dipicu ketika tombol switch kelas ditekan.

     Fungsi ini akan mengaktifkan atau menonaktifkan tombol radio kelas siswa berdasarkan status dari switch.
     Jika switch diaktifkan, tombol radio kelas akan diaktifkan dan kelas yang sesuai akan dipilih.
     Jika switch dinonaktifkan, semua tombol radio kelas akan dinonaktifkan.

     - Parameter sender: Tombol NSButton ``kelasSwitch`` yang memicu aksi ini.
     */
    @IBAction func kelasSwitch(_ sender: NSButton) {
        let shouldEnable = sender.state == .on
        enableKelasRadio(shouldEnable)
    }

    private func selectKelasRadio() {
        switch selectedSiswaList.first!.tingkatKelasAktif {
        case .kelas1: kelas1Radio.state = .on
        case .kelas2: kelas2Radio.state = .on
        case .kelas3: kelas3Radio.state = .on
        case .kelas4: kelas4Radio.state = .on
        case .kelas5: kelas5Radio.state = .on
        case .kelas6: kelas6Radio.state = .on
        default: break
        }
    }

    private func enableKelasRadio(_ shouldEnable: Bool) {
        kelasRadioButtons.forEach { $0.isEnabled = shouldEnable }
        enableEditKelas(shouldEnable)
    }

    /**
     Aksi yang dipicu saat tombol untuk mengaktifkan/menonaktifkan pemilihan tanggal daftar ditekan.

     Fungsi ini akan mengubah status `aktifkanTglDaftar` dan mengatur properti `isEnabled` dari `tglDaftar` sesuai dengan status tersebut.
     - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func ubahTglDftr(_: Any) {
        aktifkanTglDaftar.toggle()
        tglDaftar.isEnabled = aktifkanTglDaftar
    }

    /**
     Menampilkan pratinjau foto siswa yang dipilih dalam sebuah popover.

     Fungsi ini akan mengambil siswa pertama dari `selectedSiswaList`, membuat instance dari `PratinjauFoto` view controller,
     mengatur siswa yang dipilih ke view controller tersebut, dan menampilkan view controller dalam sebuah popover yang muncul
     di dekat tombol yang memicu aksi ini.

     - Parameter sender: Tombol yang memicu aksi pratinjau foto.
     */
    @IBAction func pratinjauFoto(_ sender: NSButton) {
        if let selectedSiswa = selectedSiswaList.first {
            if let viewController = NSStoryboard(name: NSStoryboard.Name("PratinjauFoto"), bundle: nil)
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ImagePreviewViewController")) as? PratinjauFoto
            {
                viewController.selectedSiswa = selectedSiswa
                viewController.loadView()
                // Menampilkan popover atau sheet, sesuai kebutuhan Anda
                let popover = NSPopover()
                popover.contentViewController = viewController
                popover.behavior = .semitransient

                // Tampilkan popover di dekat tombol yang memicunya
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            }
        }
    }

    /**
     Aksi yang dipicu ketika tanggal berhenti dipilih dari `ExpandingDatePicker`.

     Fungsi ini mengambil tanggal yang dipilih dari `ExpandingDatePicker`, memformatnya ke dalam format "dd MMMM yyyy",
     dan kemudian menetapkan tanggal yang diformat kembali ke `dateValue` dari `tglBerhenti`.

     - Parameter sender: `ExpandingDatePicker` yang memicu aksi ini.
     */
    @IBAction func aksiTglBerhenti(_: ExpandingDatePicker) {}

    /**
     * Fungsi ini dipanggil ketika tombol switch status ditekan.
     * Fungsi ini mengatur status UI elemen berdasarkan status switch.
     *
     * - Parameter sender: Tombol NSButton yang memicu aksi ini.
     */
    @IBAction func statusSwitch(_ sender: NSButton) {
        let shouldEnable = sender.state == .on
        enableStatusRadio(shouldEnable)
        statusRadioButtons.forEach { $0.state = .off }

        kelasSwitch.animator().isEnabled = false
        kelasSwitch.animator().state = .off
        enableKelasRadio(false)
    }

    /// Outlet untuk tombol radio status siswa.
    @IBOutlet weak var statusAktif: NSButton!
    /// Outlet untuk tombol radio status siswa berhenti.
    @IBOutlet weak var statusBerhenti: NSButton!
    /// Outlet untuk tombol radio status siswa lulus.
    @IBOutlet weak var statusLulus: NSButton!

    private func enableStatusRadio(_ shouldEnable: Bool) {
        statusAktif.isEnabled = shouldEnable
        statusBerhenti.isEnabled = shouldEnable
        statusLulus.isEnabled = shouldEnable
    }

    /// Properti untuk referensi jika tanggal pendaftaran atau tanggal berhenti berubah.
    var tglDaftarBerhenti = false

    /**
     * Memperbarui data siswa yang ada di database.
     *
     * Fungsi ini memperbarui informasi siswa berdasarkan input yang diberikan, dengan opsi untuk mempertahankan nilai yang ada jika input kosong.
     * Fungsi ini juga menangani pembaruan foto, pencatatan saran perubahan data, dan pengiriman notifikasi terkait perubahan data siswa, kelas, atau status kelulusan.
     *
     * - Parameter siswa: Objek ``ModelSiswa`` yang akan diperbarui.
     * - Parameter input: Objek ``SiswaInput`` yang berisi data baru untuk siswa. Jika sebuah field kosong, nilai yang ada pada `siswa` akan dipertahankan.
     * - Parameter option: Objek ``UpdateOption`` yang mengontrol opsi pembaruan seperti pengaktifan tanggal daftar, pemilihan jenis kelamin, pengaktifan status, pengaktifan tanggal berhenti, dan pemilihan kelas.
     *
     * ## Detail Tambahan:
     * - Fungsi ini menggunakan `dbController` untuk melakukan pembaruan data di database.
     * - Jika `selectedImageData` pada `input` tidak nil, foto siswa juga akan diperbarui.
     * - Notifikasi dikirimkan jika nama siswa diubah dan kelas yang dipilih sama dengan kelas siswa saat ini.
     * - Jika kelas siswa diubah, notifikasi penghapusan siswa dari kelas lama akan dikirimkan, dan kelas aktif siswa akan diperbarui di database.
     * - Jika status siswa diubah menjadi "Lulus", notifikasi penghapusan siswa dari kelas saat ini akan dikirimkan, dan data siswa akan diperbarui sebagai siswa yang lulus.
     */
    func updateSiswa(_ siswa: ModelSiswa, with input: SiswaInput, option: UpdateOption) {
        let id = siswa.id
        let tglBerhenti: String = if input.status == .aktif || input.status == .naik,!option.tglBerhentiEnabled {
            ""
        } else {
            option.tglBerhentiEnabled
                ? input.tanggalBerhenti
                : siswa.tanggalberhenti
        }

        let status: StatusSiswa = input.status == .naik
            ? .aktif : input.status

        if selectedSiswaList.count == 1 {
            dbController.updateSiswa(
                idValue: id,
                namaValue: input.nama.isEmpty ? siswa.nama : input.nama,
                alamatValue: input.alamat,
                ttlValue: input.ttl,
                tahundaftarValue: option.aktifkanTglDaftar ? input.tanggalDaftar : siswa.tahundaftar,
                namawaliValue: input.namawali,
                nisValue: input.nis,
                jeniskelaminValue: option.pilihJnsKelamin ? input.jeniskelamin : siswa.jeniskelamin,
                statusValue: option.statusEnabled ? status : siswa.status,
                tanggalberhentiValue: tglBerhenti,
                nisnValue: input.nisn,
                updatedAyah: input.ayah,
                updatedIbu: input.ibu,
                updatedTlv: input.tlv
            )
        } else {
            dbController.updateSiswa(
                idValue: id,
                namaValue: input.nama.isEmpty ? siswa.nama : input.nama,
                alamatValue: input.alamat.isEmpty ? siswa.alamat : input.alamat,
                ttlValue: input.ttl.isEmpty ? siswa.ttl : input.ttl,
                tahundaftarValue: option.aktifkanTglDaftar ? input.tanggalDaftar : siswa.tahundaftar,
                namawaliValue: input.namawali.isEmpty ? siswa.namawali : input.namawali,
                nisValue: input.nis.isEmpty ? siswa.nis : input.nis,
                jeniskelaminValue: option.pilihJnsKelamin ? input.jeniskelamin : siswa.jeniskelamin,
                statusValue: option.statusEnabled ? status : siswa.status,
                tanggalberhentiValue: tglBerhenti,
                nisnValue: input.nisn.isEmpty ? siswa.nisn : input.nisn,
                updatedAyah: input.ayah.isEmpty ? siswa.ayah : input.ayah,
                updatedIbu: input.ibu.isEmpty ? siswa.ibu : input.ibu,
                updatedTlv: input.tlv.isEmpty ? siswa.tlv : input.tlv
            )
        }

        let data: [SiswaColumn: String] = [
            .nama: input.nama,
            .alamat: input.alamat,
            .ttl: input.ttl,
            .namawali: input.namawali,
            .nis: input.nis,
            .nisn: input.nisn,
            .ayah: input.ayah,
            .ibu: input.ibu,
            .tlv: input.tlv,
        ]

        DatabaseController.shared.catatSuggestions(data: data)

        if let imageData = input.selectedImageData {
            /*
             Sangat penting untuk membuat undo digrup dengan undoEdit di siswaViewController.
             Jika undo tidak digrup, itu berarti akan menyebabkan ada dua undo action yang tidak perlu.
             Karena yang pertama undo untuk mengurungkan pembaruan foto dan yang kedua undo untuk edit data tanpa foto.
             */
            SiswaViewModel.siswaUndoManager.beginUndoGrouping()
            dbController.updateFotoInDatabase(with: imageData, idx: id, undoManager: SiswaViewModel.siswaUndoManager)
        }

        // Notifikasi nama berubah
        if input.nama != siswa.nama {
            let userInfo = NotifSiswaDiedit(updateStudentID: id, kelasSekarang: siswa.tingkatKelasAktif.rawValue, namaSiswa: input.nama)
            NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo.asUserInfo)
        }

        // Kelas berubah
        if option.kelasIsEnabled,
           option.pilihKelasSwitch,
           option.kelasPilihan != siswa.tingkatKelasAktif.rawValue
        {
            SiswaViewModel.shared.kelasEvent.send(.kelasBerubah(id, fromKelas: siswa.tingkatKelasAktif.rawValue))
        }
    }

    /**
         Memperbarui data siswa yang dipilih dengan informasi yang baru.

         Fungsi ini mengambil data dari berbagai elemen UI seperti text field, date picker, dan combo box,
         kemudian memformat data tersebut dan mengirimkannya ke fungsi `updateSiswa` untuk memperbarui data di penyimpanan.
         Setelah pembaruan selesai, fungsi ini menutup tampilan dan mengirimkan notifikasi yang berisi daftar ID siswa yang telah diperbarui.

         - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol "Update").

         ## Detail Proses:
         1.  **Inisialisasi:** Mempersiapkan array `ids` untuk menyimpan ID siswa yang diperbarui dan formatter tanggal.
         2.  **Pengambilan Data:** Mengambil data dari elemen UI dan memformat tanggal pendaftaran dan tanggal berhenti.
         3.  **Kompresi Gambar:** Mengompresi gambar yang dipilih (jika ada).
         4.  **Opsi Pembaruan:** Membuat objek `UpdateOption` yang berisi informasi mengenai status dan opsi yang dipilih pada UI.
         5.  **Iterasi Data Siswa:** Melakukan iterasi pada daftar siswa yang dipilih (`selectedSiswaList`).
             *   **Input Data Siswa:** Membuat objek `SiswaInput` yang berisi data siswa yang baru, diformat menggunakan `ReusableFunc.teksFormat`.
             *   **Pengecekan Perubahan Tanggal:** Memeriksa apakah ada perubahan pada tanggal pendaftaran atau tanggal berhenti. Jika ada, variabel `tglDaftarBerhenti` diatur menjadi `true`.
             *   **Pembaruan Data Siswa:** Memanggil fungsi `updateSiswa` untuk memperbarui data siswa di penyimpanan.
             *   **Penyimpanan ID:** Menambahkan ID siswa yang diperbarui ke array `ids`.
         6.  **Penutupan Tampilan:** Menutup tampilan setelah semua data siswa selesai diperbarui.
         7.  **Pengiriman Notifikasi:** Mengirimkan notifikasi `dataSiswaDiEdit` melalui `NotificationCenter` dengan menyertakan daftar ID siswa yang telah diperbarui. Notifikasi ini dikirimkan pada thread utama (main thread).

         ## Catatan:
         - Fungsi `ReusableFunc.teksFormat` digunakan untuk memformat teks dengan opsi huruf besar dan kapitalisasi.
         - Fungsi `imageView.selectedImage?.compressImage(quality: 0.5)` digunakan untuk mengompresi gambar dengan kualitas 50%.
         - Notifikasi `dataSiswaDiEdit` digunakan untuk memberitahu bagian lain dari aplikasi bahwa data siswa telah diperbarui.
     */
    @IBAction func update(_: Any) {
        var ids = [Int64]()
        let updateKelas = statusSwitch.state == .on ? true : false
        let tahunAjaran1 = thnAjaran1.stringValue
        let tahunAjaran2 = thnAjaran2.stringValue

        let tglPndftrn = ReusableFunc.buatFormatTanggal(tglDaftar.dateValue)!
        let tglBrhnti = ReusableFunc.buatFormatTanggal(tglBerhenti.dateValue)!
        let selectedImageData = nonaktifkanImageView ? nil : imageView.selectedImage?.compressImage(quality: 0.5)
        let selectedKelas = kelasRadioButtons.first { $0.state == .on }
        let jenisKelamin = jenisKelaminButtons.first { $0.state == .on }
        let selectedStatus = statusRadioButtons.first { $0.state == .on }

        let statusSiswa: StatusSiswa? = updateKelas && selectedStatus?.title == "Aktif"
            ? .naik
            : StatusSiswa.from(description: selectedStatus?.title ?? "")

        if updateKelas,
           statusSiswa == .naik,
           tahunAjaran1.isEmpty,
           tahunAjaran2.isEmpty
        {
            ReusableFunc.showAlert(title: "Tahun Ajaran Kosong.", message: "Ketika mengaktifkan pengeditan kelas, tahun ajaran harus diisi dengan benar.")
            return
        }

        if updateKelas,
           statusSiswa == .naik,
           tahunAjaran1.contains(where: \.isLetter),
           tahunAjaran2.contains(where: \.isLetter)
        {
            ReusableFunc.showAlert(title: "Tahun Ajaran Harus Berupa Angka.", message: "Ketika mengaktifkan pengeditan kelas, tahun ajaran harus diisi dengan angka.")
            return
        }

        if updateKelas,
           statusSiswa == .naik,
           selectedKelas == nil
        {
            ReusableFunc.showAlert(title: "Tidak ada kelas yang dipilih.", message: "Pilih kelas yang valid untuk melanjutkan.")
            return
        }

        let option = UpdateOption(
            aktifkanTglDaftar: aktifkanTglDaftar,
            tglBerhentiEnabled: tglBerhenti.isEnabled,
            statusEnabled: updateKelas,
            pilihKelasSwitch: updateKelas,
            kelasIsEnabled: updateKelas,
            pilihJnsKelamin: kelaminSwitch.state == .on,
            kelasPilihan: selectedKelas?.title ?? ""
        )

        let tahunAjaran = thnAjaran1.stringValue + "/" + thnAjaran2.stringValue
        let allowEmpty = selectedSiswaList.count == 1 ? true : false
        let nama = namaSiswa.stringValue
        let alamat = alamatSiswa.stringValue
        let ayah = ayah.stringValue
        let ibu = ibu.stringValue
        let ttl = ttlTextField.stringValue
        let wali = namawaliTextField.stringValue
        let tglBerhentiIsEnabled = tglBerhenti.isEnabled
        let tglDaftarIsEnabled = tglDaftar.isEnabled
        let nis = NIS.stringValue
        let nisn = NISN.stringValue
        let tlv = tlv.stringValue
        let jnsKelamin = JenisKelamin.from(description: jenisKelamin?.title ?? "") ?? .lakiLaki

        DispatchQueue.global(qos: .background).sync { [weak self] in
            guard let self else { return }
            for siswa in selectedSiswaList {
                let input = SiswaInput(
                    nama: ReusableFunc.teksFormat(nama, oldValue: siswa.nama, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    alamat: ReusableFunc.teksFormat(alamat, oldValue: siswa.alamat, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    ttl: ReusableFunc.teksFormat(ttl, oldValue: siswa.ttl, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    nis: nis,
                    nisn: nisn,
                    ayah: ReusableFunc.teksFormat(ayah, oldValue: siswa.ayah, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    ibu: ReusableFunc.teksFormat(ibu, oldValue: siswa.ibu, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    tlv: tlv,
                    namawali: ReusableFunc.teksFormat(wali, oldValue: siswa.namawali, hurufBesar: hurufBesar, kapital: kapitalkan, allowEmpty: allowEmpty),
                    jeniskelamin: jnsKelamin,
                    status: statusSiswa == nil ? siswa.status : statusSiswa!,
                    tanggalDaftar: tglPndftrn,
                    tanggalBerhenti: tglBrhnti,
                    selectedImageData: selectedImageData
                )
                if tglBrhnti != siswa.tanggalberhenti, tglBerhentiIsEnabled {
                    tglDaftarBerhenti = true
                }
                if tglPndftrn != siswa.tahundaftar, tglDaftarIsEnabled {
                    tglDaftarBerhenti = true
                }
                if statusSiswa != siswa.status, statusSiswa == .berhenti || statusSiswa == .lulus {
                    SiswaViewModel.shared.kelasEvent.send(.undoAktifkanSiswa(siswa.id, kelas: siswa.tingkatKelasAktif.rawValue))
                } else if statusSiswa == .aktif, siswa.status != .aktif, let selectedKelas {
                    SiswaViewModel.shared.kelasEvent.send(.aktifkanSiswa(siswa.id, kelas: selectedKelas.title))
                }
                updateSiswa(siswa, with: input, option: option)
                ids.append(siswa.id)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let statusSiswa {
                    let userInfo: [String: Any] = ["ids": ids, "tahunAjaran": tahunAjaran, "semester": popUpSemester.titleOfSelectedItem ?? "", "kelas": selectedKelas?.title ?? "", "updateKelas": updateKelas, "status": statusSiswa]
                    NotificationCenter.default.post(name: .dataSiswaDiEdit, object: nil, userInfo: userInfo)
                }
                dismiss(nil)
            }
        }
    }

    /**
     Menangani aksi saat tombol "insertFoto" ditekan. Membuka panel untuk memilih file gambar (PNG atau JPEG) dan menampilkannya di `imageView`.

     - Parameter sender: Objek yang memicu aksi (biasanya tombol).
     */
    @IBAction func insertFoto(_: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        // Menggunakan sheets
        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            if let self, response == NSApplication.ModalResponse.OK,
               let imageURL = openPanel.urls.first
            {
                do {
                    let imageData = try Data(contentsOf: imageURL)

                    if let image = NSImage(data: imageData) {
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
                    }
                } catch {
                    ReusableFunc.showAlert(title: "Kesalahan", message: error.localizedDescription)
                }
            }
        }
    }

    /**
     * @IBAction func eksporFoto(_ sender: Any)
     *
     * Fungsi ini dipanggil ketika tombol ekspor foto ditekan.
     * Fungsi ini mengambil data foto siswa dari database, mengompresnya, dan menyimpannya ke file yang dipilih pengguna.
     *
     * - Parameter sender: Objek yang mengirimkan aksi (tombol ekspor foto).
     */
    @IBAction func eksporFoto(_: Any) {
        let imageData = dbController.bacaFotoSiswa(idValue: selectedSiswaList.first!.id)
        guard let image = NSImage(data: imageData), let compressedImageData = image.jpegRepresentation else {
            // Tambahkan penanganan jika gagal mengonversi atau mengompresi ke Data
            return
        }

        // Membuat nama file berdasarkanƒ nama siswa
        let fileName = "\(selectedSiswaList.first?.nama.replacingOccurrences(of: "/", with: "-") ?? "unknown").jpeg"

        // Menyimpan data gambar ke file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.image]
        savePanel.nameFieldStringValue = fileName // Menetapkan nama file default

        // Menampilkan save panel
        savePanel.beginSheetModal(for: view.window!) { result in
            if result == .OK, let fileURL = savePanel.url {
                do {
                    try compressedImageData.write(to: fileURL)
                } catch {
                    ReusableFunc.showAlert(title: "Kesalahan", message: error.localizedDescription)
                }
            }
        }
    }

    /**
     * @IBAction func hapusFoto(_ sender: Any)
     *
     * Fungsi ini menampilkan alert konfirmasi untuk menghapus foto siswa yang dipilih.
     * Jika pengguna memilih untuk menghapus, foto akan dihapus dari database dan tampilan gambar akan direset.
     *
     * - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func hapusFoto(_: Any) {
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menghapus foto"
        alert.informativeText = "Foto \(selectedSiswaList.first?.nama ?? "Siswa") akan dihapus. Tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Hapus")

        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            if let self, response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Hapus"
                SiswaViewModel.siswaUndoManager.beginUndoGrouping()
                /*
                 Sangat penting untuk membuat undo digrup dengan undoEdit di siswaViewController.
                 Jika undo tidak digrup, itu berarti akan menyebabkan ada dua undo action yang tidak perlu.
                 Karena yang pertama undo untuk mengurungkan pembaruan foto dan yang kedua undo untuk edit data tanpa foto.
                 */
                dbController.updateFotoInDatabase(with: Data(), idx: selectedSiswaList.first?.id ?? 0, undoManager: SiswaViewModel.siswaUndoManager)
                imageView.image = NSImage(named: .siswa)
                imageView.selectedImage = nil
            }
        }
    }

    /// Properti Untuk Referensi Opsi Kapitalisasi.
    var kapitalkan: Bool = true
    /// Properti untuk referensi opsi HURUF BESAR.
    var hurufBesar: Bool = false

    /**
      * Fungsi ini mengkapitalisasi semua teks pada field yang telah ditentukan (namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah).
      * Jika ada lebih dari satu siswa yang dipilih, placeholder pada field juga akan dikapitalisasi.
      * Variabel `kapitalkan` diatur menjadi `true` dan `hurufBesar` diatur menjadi `false`.
      *
      * - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_: Any) {
        [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah].kapitalkanSemua()
        if selectedSiswaList.count > 1 {
            let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
            for field in fields {
                field?.placeholderString = (field?.placeholderString?.capitalized ?? "")
            }
        }
        kapitalkan = true
        hurufBesar = false
    }

    @IBAction func hurufBesar(_: Any) {
        [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah].hurufBesarSemua()
        if selectedSiswaList.count > 1 {
            let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
            for field in fields {
                field?.placeholderString = (field?.placeholderString?.uppercased() ?? "")
            }
        }

        kapitalkan = false
        hurufBesar = true
    }

    /// Action untuk tombol "Batalkan".
    @IBAction func tutup(_: Any) {
        dismiss(nil)
    }

    /// Action untuk tombol ``tglDaftar``.
    @IBAction func aksiTglPendaftaran(_: ExpandingDatePicker) {}

    deinit {
        #if DEBUG
            print("deinit EditData")
        #endif
    }
}

extension EditData: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
        if textField === thnAjaran1,
           let tahunInt = Int(textField.stringValue)
        {
            thnAjaran2.stringValue = String(tahunInt + 1)
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        activeText = obj.object as? CustomTextField
        let suggestionsDict: [NSTextField: [String]] = [
            namaSiswa: Array(ReusableFunc.namasiswa),
            alamatSiswa: Array(ReusableFunc.alamat),
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

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
