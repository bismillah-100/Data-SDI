//
//  EditData.swift
//  Data SDI
//
//  Created by Bismillah on 27/12/23.
//

import Cocoa
import SQLite

/// Class yang menangani pengeditan data siswa seperti nama siswa, alamat, nis dll.
class EditData: NSViewController {
    // MARK: - UI

    /// Outlet garis vertikal di tengah view.
    @IBOutlet weak var verticalLine: NSBox!

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

    /// Outlet pemilihan menu popUp "Status".
    @IBOutlet weak var status: NSPopUpButton!

    /// Outlet pemilihan menu popUp "Kelamin".
    @IBOutlet weak var jnsKelamin: NSPopUpButton!

    /// Outlet pemilihan menu popUp "Kelas".
    @IBOutlet weak var pilihKelas: NSPopUpButton!

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

    /// Outlet untuk garis vertikal di antara tgl pendaftaran dan tgl berhenti.
    @IBOutlet weak var vertical1: NSBox!

    // MARK: - TextField

    /// Outlet untuk field pengetikan nama siswa.
    @IBOutlet weak var namaSiswa: NSTextField!

    /// Outlet untuk field pengetikan alamat siswa.
    @IBOutlet weak var alamatSiswa: NSTextField!

    /// Outlet untuk field pengetikan ttl.
    @IBOutlet weak var ttlTextField: NSTextField!

    /// Outlet untuk field pengetikan NIS.
    @IBOutlet weak var NIS: NSTextField!

    /// Outlet untuk field pengetikan nama wali.
    @IBOutlet weak var namawaliTextField: NSTextField!

    /// Outlet untuk field pengetikan nama ibu.
    @IBOutlet weak var ibu: NSTextField!

    /// Outlet untuk field pengetikan nomor telepon.
    @IBOutlet weak var tlv: NSTextField!

    /// Outlet untuk field pengetikan nama ayah.
    @IBOutlet weak var ayah: NSTextField!

    /// Outlet untuk field pengetikan NISN.
    @IBOutlet weak var NISN: NSTextField!

    // MARK: - Label

    /// Outlet label nama.
    @IBOutlet weak var namaLabel: NSTextField!
    /// Outlet label alamat.
    @IBOutlet weak var alamatLabel: NSTextField!
    /// Outlet label ttl.
    @IBOutlet weak var ttlteks: NSTextField!
    /// Outlet label nis.
    @IBOutlet weak var nisteks: NSTextField!
    /// Outlet label nama wali.
    @IBOutlet weak var namaortuteks: NSTextField!
    /// Outlet label tanggal berhenti.
    @IBOutlet weak var tglBerhentiTeks: NSTextField!

    // MARK: - Data

    /// Array yang menyimpan data-data siswa yang akan diperbarui.
    var selectedSiswaList: [ModelSiswa] = []
    /// Instans ``DatabaseController``.
    let dbController = DatabaseController.shared

    // MARK: - Pilihan

    /// Properti yang menyimpan referensi status tombol ``tglPendaftaranSwitch``.
    private var aktifkanTglDaftar: Bool = false
    /// Properti yang menyimpan referensi status pemilihan tanggal ``tglBerhenti``
    private var aktifkanTglBerhenti: Bool = false
    /// Properti yang menyimpan referensi status tombol ``kelaminSwitch``.
    private var pilihJnsKelamin: Bool = false
    /// Properti yang menyimpan referensi status tombol ``kelasSwitch``.
    private var pilihKelasSwitch: Bool = false
    /// Properti yang menyimpan referensi status tombol ``statusSwitch``..
    private var pilihStatusSwitch: Bool = false
    /// Properti yang menyimpan referensi status ``imageView``.
    private var nonaktifkanImageView: Bool = true

    // MARK: - AutoComplete Teks

    /// Instans ``SuggestionManager``.
    private var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    private var activeText: NSTextField!

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

            pilihKelas.selectItem(withTitle: siswaData.kelasSekarang)
            pilihKelas.selectedItem?.state = .on
            jnsKelamin.selectItem(withTitle: siswaData.jeniskelamin)
            jnsKelamin.selectedItem?.state = .on
            status.selectItem(withTitle: siswaData.status)
            status.selectedItem?.state = .on
            pilihJnsKelamin = true
            aktifkanTglDaftar = true
            pilihKelasSwitch = true
            pilihStatusSwitch = true
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMMM yyyy"
            if let tglPndftrn = dateFormatter.date(from: siswaData.tahundaftar) { tglDaftar.dateValue = tglPndftrn }
            if let tglBrhnt = dateFormatter.date(from: siswaData.tanggalberhenti) { tglBerhenti.dateValue = tglBrhnt }
            if (2 ... 3).contains(status.indexOfSelectedItem) {
                tglBerhenti.isEnabled = true
                aktifkanTglBerhenti = true
                pilihKelas.isEnabled = false
                kelasSwitch.isEnabled = false
            } else {
                tglBerhenti.isEnabled = false
                aktifkanTglBerhenti = false
                pilihKelas.isEnabled = true
                kelasSwitch.isEnabled = true
            }
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
            jnsKelamin.isEnabled = false
            pilihJnsKelamin = false
            kelaminSwitch.state = .off
            pilihKelas.isEnabled = false
            pilihKelasSwitch = false
            kelasSwitch.state = .off
            aktifkanTglDaftar = false
            status.isEnabled = false
            pilihStatusSwitch = false
            statusSwitch.state = .off
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
        if tglDaftarBerhenti {
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        }
    }

    /**
         Mengatur ulang kapitalisasi pada placeholder dari setiap text field yang diberikan.

         Fungsi ini mengambil array text field (namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah)
         dan mengubah placeholder dari setiap field menjadi huruf kecil. Jika sebuah field memiliki placeholder,
         placeholder tersebut akan diubah menjadi huruf kecil. Jika field atau placeholder-nya nil, maka akan diabaikan.
     */
    func resetKapital() {
        let fields = [namaSiswa, alamatSiswa, ttlTextField, namawaliTextField, ibu, ayah]
        for field in fields {
            field?.placeholderString = (field?.placeholderString?.lowercased() ?? "")
        }
    }

    /**
     Aksi yang dipicu saat tombol untuk mengaktifkan/menonaktifkan pemilihan tanggal daftar ditekan.

     Fungsi ini akan mengubah status `aktifkanTglDaftar` dan mengatur properti `isEnabled` dari `tglDaftar` sesuai dengan status tersebut.
     - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func ubahTglDftr(_ sender: Any) {
        aktifkanTglDaftar.toggle()
        if aktifkanTglDaftar {
            tglDaftar.isEnabled = true
        } else {
            tglDaftar.isEnabled = false
        }
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
     Menangani aksi yang dipicu oleh perubahan pilihan pada NSPopUpButton untuk jenis kelamin.

     Fungsi ini dipanggil ketika pengguna memilih item baru dari NSPopUpButton `sender`. Fungsi ini memperbarui tampilan menu dan mengatur status item yang dipilih.

     - Parameter sender: NSPopUpButton yang mengirimkan aksi.
     */
    @IBAction func aksiJenisKelamin(_ sender: NSPopUpButton) {
        let kelamin = sender.titleOfSelectedItem ?? ""
        guard let submenu = sender.menu else { return }
        // Iterate through the items in the submenu
        for bela in submenu.items {
            bela.state = .off
        }
        jnsKelamin.selectItem(withTitle: kelamin)
        jnsKelamin.selectedItem?.state = .on
    }

    /**
         Mengaktifkan atau menonaktifkan pemilihan jenis kelamin berdasarkan status `NSButton`.

         Saat `NSButton` diaktifkan, `jnsKelamin` diaktifkan dan status tombol diatur ke `.on`.
         Saat `NSButton` dinonaktifkan, `jnsKelamin` dinonaktifkan dan status tombol diatur ke `.off`.

         - Parameter sender: `NSButton` yang memicu aksi ini.
     */
    @IBAction func kelaminSwitch(_ sender: NSButton) {
        pilihJnsKelamin.toggle()
        if pilihJnsKelamin {
            jnsKelamin.isEnabled = true
            sender.state = .on
        } else {
            jnsKelamin.isEnabled = false
            sender.state = .off
        }
    }

    /**
     Aksi yang dipicu ketika tanggal berhenti dipilih dari `ExpandingDatePicker`.

     Fungsi ini mengambil tanggal yang dipilih dari `ExpandingDatePicker`, memformatnya ke dalam format "dd MMMM yyyy",
     dan kemudian menetapkan tanggal yang diformat kembali ke `dateValue` dari `tglBerhenti`.

     - Parameter sender: `ExpandingDatePicker` yang memicu aksi ini.
     */
    @IBAction func aksiTglBerhenti(_ sender: ExpandingDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let selectedDate = sender.dateValue
        let formattedDate = dateFormatter.string(from: selectedDate)
        tglBerhenti.dateValue = dateFormatter.date(from: formattedDate)!
    }

    /**
         Fungsi ini dipanggil ketika sebuah item dipilih dari NSPopUpButton untuk kelas.

         Fungsi ini melakukan langkah-langkah berikut:
         1. Memastikan bahwa menu dari pengirim (sender) tidak kosong. Jika kosong, fungsi akan keluar.
         2. Mengatur semua item di submenu menjadi nonaktif (state .off).
         3. Mengatur item yang dipilih saat ini di `pilihKelas` menjadi aktif (state .on).
         4. Menonaktifkan `tglBerhenti`.
         5. Mengaktifkan `statusSwitch` dan mengaturnya ke aktif (state .on).
         6. Mengaktifkan `status` dan memilih item pada indeks 1, kemudian mengaturnya ke aktif (state .on).

         - Parameter:
            - sender: NSPopUpButton yang memicu aksi ini.
     */
    @IBAction func aksiKelas(_ sender: NSPopUpButton) {
        guard let submenu = sender.menu else { return }
        for bela in submenu.items {
            bela.state = .off
        }
        pilihKelas.selectedItem?.state = .on
        tglBerhenti.isEnabled = false
        statusSwitch.isEnabled = true
        statusSwitch.state = .on
        status.isEnabled = true
        status.selectItem(at: 1)
        status.selectedItem?.state = .on
    }

    /**
         Mengelola aksi ketika tombol switch kelas ditekan.

         Fungsi ini menangani perubahan status switch kelas dan memperbarui tampilan antarmuka pengguna sesuai dengan itu.
         Jika switch diaktifkan, dropdown kelas akan diaktifkan. Jika beberapa siswa dipilih, status dan dropdown status juga akan diaktifkan dan diatur ke nilai default.
         Jika switch dinonaktifkan, dropdown kelas akan dinonaktifkan. Jika beberapa siswa dipilih, status dan dropdown status juga akan dinonaktifkan dan diatur ulang.

         - Parameter sender: Tombol switch yang memicu aksi ini.
     */
    @IBAction func kelasSwitch(_ sender: NSButton) {
        pilihKelasSwitch.toggle()
        if pilihKelasSwitch {
            pilihKelas.isEnabled = true
            sender.state = .on
            if selectedSiswaList.count > 1 {
                pilihStatusSwitch = true
                pilihKelas.selectItem(at: 1)
                pilihKelas.selectedItem?.state = .on
                status.isEnabled = true
                status.selectItem(at: 1)
                status.selectedItem?.state = .on
                statusSwitch.animator().state = .on
            }
        } else {
            if selectedSiswaList.count > 1 {
                pilihStatusSwitch = false
                pilihKelas.select(nil)
                status.isEnabled = false
                status.select(nil)
                statusSwitch.animator().state = .off
            }
            pilihKelas.isEnabled = false
            sender.state = .off
        }
    }

    /**
         Fungsi ini dipanggil ketika aksi terjadi pada `NSPopUpButton` status.

         Fungsi ini mengatur ulang status semua item di submenu, memilih item yang sesuai dengan judul yang dipilih,
         dan mengaktifkan atau menonaktifkan beberapa elemen UI berdasarkan indeks item yang dipilih.

         - Parameter sender: `NSPopUpButton` yang mengirimkan aksi.
     */
    @IBAction func aksiStatus(_ sender: NSPopUpButton) {
        guard let submenu = sender.menu else { return }
        for bela in submenu.items {
            bela.state = .off
        }
        let statuss = sender.titleOfSelectedItem ?? ""
        status.selectItem(withTitle: statuss)
        status.selectedItem?.state = .on
        if sender.indexOfSelectedItem == 2 {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        } else if sender.indexOfSelectedItem == 3 {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        } else {
            tglBerhenti.isEnabled = false
            pilihKelas.isEnabled = true
            kelasSwitch.isEnabled = true
            pilihKelasSwitch = true
            kelasSwitch.state = .on
        }
    }

    /**
     * Fungsi ini dipanggil ketika tombol switch status ditekan.
     * Fungsi ini mengatur status UI elemen berdasarkan status switch.
     *
     * - Parameter sender: Tombol NSButton yang memicu aksi ini.
     */
    @IBAction func statusSwitch(_ sender: NSButton) {
        pilihStatusSwitch.toggle()
        if pilihStatusSwitch {
            sender.state = .on
            status.isEnabled = true
            kelasSwitch.isEnabled = true
            if selectedSiswaList.count > 1 {
                pilihKelasSwitch.toggle()
                status.selectItem(at: 1)
                status.selectedItem?.state = .on
                pilihKelas.selectItem(at: 1)
                pilihKelas.selectedItem?.state = .on
            }
            kelasSwitch.animator().state = .on
        } else {
            status.isEnabled = false
            if selectedSiswaList.count > 1 {
                pilihKelasSwitch.toggle()
                status.select(nil)
            }
            pilihKelas.isEnabled = false
            kelasSwitch.animator().state = .off
            sender.state = .off
        }
        if status.titleOfSelectedItem == "Aktif" {
            tglBerhenti.isEnabled = false
            pilihKelas.isEnabled = true
            kelasSwitch.isEnabled = true
            kelasSwitch.animator().state = .on
            pilihKelasSwitch = true
        } else {
            tglBerhenti.isEnabled = true
            pilihKelas.isEnabled = false
            kelasSwitch.isEnabled = false
            pilihKelasSwitch = false
        }
    }

    /// Properti untuk referensi jika tanggal pendaftaran atau tanggal berhenti berubah.
    var tglDaftarBerhenti = false

    /**
     * Memperbarui data siswa yang ada di database.
     *
     * Fungsi ini memperbarui informasi siswa berdasarkan input yang diberikan, dengan opsi untuk mempertahankan nilai yang ada jika input kosong.
     * Fungsi ini juga menangani pembaruan foto, pencatatan saran perubahan data, dan pengiriman notifikasi terkait perubahan data siswa, kelas, atau status kelulusan.
     *
     * - Parameter siswa: Objek `ModelSiswa` yang akan diperbarui.
     * - Parameter input: Objek `SiswaInput` yang berisi data baru untuk siswa. Jika sebuah field kosong, nilai yang ada pada `siswa` akan dipertahankan.
     * - Parameter option: Objek `UpdateOption` yang mengontrol opsi pembaruan seperti pengaktifan tanggal daftar, pemilihan jenis kelamin, pengaktifan status, pengaktifan tanggal berhenti, dan pemilihan kelas.
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

        dbController.updateSiswa(
            idValue: id,
            namaValue: input.nama.isEmpty ? siswa.nama : input.nama,
            alamatValue: input.alamat.isEmpty ? siswa.alamat : input.alamat,
            ttlValue: input.ttl.isEmpty ? siswa.ttl : input.ttl,
            tahundaftarValue: option.aktifkanTglDaftar ? input.tanggalDaftar : siswa.tahundaftar,
            namawaliValue: input.namawali.isEmpty ? siswa.namawali : input.namawali,
            nisValue: input.nis.isEmpty ? siswa.nis : input.nis,
            jeniskelaminValue: option.pilihJnsKelamin ? input.jeniskelamin : siswa.jeniskelamin,
            statusValue: option.statusEnabled ? input.status : siswa.status,
            tanggalberhentiValue: option.tglBerhentiEnabled ? input.tanggalBerhenti : siswa.tanggalberhenti,
            nisnValue: input.nisn.isEmpty ? siswa.nisn : input.nisn,
            updatedAyah: input.ayah.isEmpty ? siswa.ayah : input.ayah,
            updatedIbu: input.ibu.isEmpty ? siswa.ibu : input.ibu,
            updatedTlv: input.tlv.isEmpty ? siswa.tlv : input.tlv
        )

        let data: [ModelSiswaKey: String] = [
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
            dbController.updateFotoInDatabase(with: imageData, idx: id)
        }

        // Notifikasi nama berubah
        if input.nama != siswa.nama, option.kelasPilihan == siswa.kelasSekarang {
            NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: [
                "updateStudentIDs": id,
                "kelasSekarang": siswa.kelasSekarang,
                "namaSiswa": input.nama,
            ])
        }

        // Kelas berubah
        if option.kelasIsEnabled, option.kelasPilihan != siswa.kelasSekarang {
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
                "deletedStudentIDs": [id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true,
            ])
            dbController.updateKelasAktif(idSiswa: id, newKelasAktif: option.pilihKelasSwitch ? option.kelasPilihan : siswa.kelasSekarang)
            dbController.updateTabelKelasAktif(
                idSiswa: id,
                kelasAwal: siswa.kelasSekarang,
                kelasYangDikecualikan: option.kelasPilihan.replacingOccurrences(of: " ", with: "").lowercased()
            )
        }

        // Status lulus
        if option.statusEnabled, input.status == "Lulus" {
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: [
                "deletedStudentIDs": [id],
                "kelasSekarang": siswa.kelasSekarang,
                "isDeleted": true,
            ])
            dbController.editSiswaLulus(namaSiswa: siswa.nama, siswaID: id, kelasBerikutnya: "Lulus")
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
    @IBAction func update(_ sender: Any) {
        var ids = [Int64]()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"

        let tglPndftrn = formatter.string(from: tglDaftar.dateValue)
        let tglBrhnti = formatter.string(from: tglBerhenti.dateValue)
        let selectedImageData = nonaktifkanImageView ? nil : imageView.selectedImage?.compressImage(quality: 0.5)

        let option = UpdateOption(
            aktifkanTglDaftar: aktifkanTglDaftar,
            tglBerhentiEnabled: tglBerhenti.isEnabled,
            statusEnabled: status.isEnabled,
            pilihKelasSwitch: pilihKelasSwitch,
            kelasIsEnabled: pilihKelas.isEnabled,
            pilihJnsKelamin: pilihJnsKelamin,
            kelasPilihan: pilihKelas.titleOfSelectedItem ?? ""
        )

        for siswa in selectedSiswaList {
            let input = SiswaInput(
                nama: ReusableFunc.teksFormat(namaSiswa.stringValue, oldValue: siswa.nama, hurufBesar: hurufBesar, kapital: kapitalkan),
                alamat: ReusableFunc.teksFormat(alamatSiswa.stringValue, oldValue: siswa.alamat, hurufBesar: hurufBesar, kapital: kapitalkan),
                ttl: ReusableFunc.teksFormat(ttlTextField.stringValue, oldValue: siswa.ttl, hurufBesar: hurufBesar, kapital: kapitalkan),
                nis: NIS.stringValue,
                nisn: NISN.stringValue,
                ayah: ReusableFunc.teksFormat(ayah.stringValue, oldValue: siswa.ayah, hurufBesar: hurufBesar, kapital: kapitalkan),
                ibu: ReusableFunc.teksFormat(ibu.stringValue, oldValue: siswa.ibu, hurufBesar: hurufBesar, kapital: kapitalkan),
                tlv: tlv.stringValue,
                namawali: ReusableFunc.teksFormat(namawaliTextField.stringValue, oldValue: siswa.namawali, hurufBesar: hurufBesar, kapital: kapitalkan),
                jeniskelamin: jnsKelamin.titleOfSelectedItem ?? "",
                status: status.titleOfSelectedItem ?? "",
                tanggalDaftar: tglPndftrn,
                tanggalBerhenti: tglBrhnti,
                kelas: pilihKelas.titleOfSelectedItem ?? "",
                selectedImageData: selectedImageData
            )
            if tglBrhnti != siswa.tanggalberhenti {
                tglDaftarBerhenti = true
            }
            if tglPndftrn != siswa.tahundaftar {
                tglDaftarBerhenti = true
            }
            updateSiswa(siswa, with: input, option: option)
            ids.append(siswa.id)
        }

        dismiss(nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dataSiswaDiEdit, object: nil, userInfo: ["ids": ids])
        }
    }

    /**
     Menangani aksi saat tombol "insertFoto" ditekan. Membuka panel untuk memilih file gambar (PNG atau JPEG) dan menampilkannya di `imageView`.

     - Parameter sender: Objek yang memicu aksi (biasanya tombol).
     */
    @IBAction func insertFoto(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        // Menggunakan sheets
        openPanel.beginSheetModal(for: view.window!) { [self] response in
            if response == NSApplication.ModalResponse.OK {
                if let imageURL = openPanel.urls.first {
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
                    } catch {}
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
    @IBAction func eksporFoto(_ sender: Any) {
        let imageData = dbController.bacaFotoSiswa(idValue: selectedSiswaList.first!.id)
        guard let image = NSImage(data: imageData.foto), let compressedImageData = image.compressImage(quality: 0.5) else {
            // Tambahkan penanganan jika gagal mengonversi atau mengompresi ke Data
            return
        }

        // Membuat nama file berdasarkanƒ nama siswa
        let fileName = "\(selectedSiswaList.first?.nama ?? "unknown").png"

        // Menyimpan data gambar ke file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = fileName // Menetapkan nama file default

        // Menampilkan save panel
        savePanel.beginSheetModal(for: view.window!) { result in
            if result == .OK, let fileURL = savePanel.url {
                do {
                    try compressedImageData.write(to: fileURL)

                } catch {}
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
    @IBAction func hapusFoto(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Apakah Anda yakin ingin menghapus foto"
        alert.informativeText = "Foto \(selectedSiswaList.first?.nama ?? "Siswa") akan dihapus. Tindakan ini tidak dapat diurungkan."
        alert.addButton(withTitle: "Batalkan")
        alert.addButton(withTitle: "Hapus")

        // Menangani tindakan setelah pengguna memilih tombol alert
        alert.beginSheetModal(for: view.window!) { [self] response in
            if response == .alertSecondButtonReturn { // .alertSecondButtonReturn adalah tombol "Hapus"
                // Melanjutkan penghapusan jika pengguna menekan tombol "Hapus"
                dbController.hapusFoto(idx: selectedSiswaList.first?.id ?? 0)
                self.imageView.image = NSImage(named: "image")
                imageView.selectedImage = nil
            }
            dbController.vacuumDatabase()
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
    @IBAction func kapitalkan(_ sender: Any) {
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

    @IBAction func hurufBesar(_ sender: Any) {
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
    @IBAction func tutup(_ sender: Any) {
        dismiss(nil)
    }

    /// Action untuk tombol ``tglDaftar``.
    @IBAction func aksiTglPendaftaran(_ sender: ExpandingDatePicker) {}
}

extension EditData: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        activeText = obj.object as? NSTextField
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

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
