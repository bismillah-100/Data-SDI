//
//  EditTransaksi.swift
//  Administrasi
//
//  Created by Bismillah on 15/11/23.
//

import Cocoa

/// Class yang menangani pengeditan data administrasi.
class EditTransaksi: NSViewController {
    /// Outlet input pengetikan jumlah.
    @IBOutlet weak var jumlah: NSTextField!
    /// Outlet input pengetikan keperluan.
    @IBOutlet weak var keperluan: NSTextField!
    /// Outlet input pengetikan kategori.
    @IBOutlet weak var kategori: NSTextField!
    /// Outlet input pengetikan acara.
    @IBOutlet weak var acara: NSTextField!

    /// Outlet tombol "simpan".
    @IBOutlet weak var catat: NSButton!

    /// Outlet tombol "tutup".
    @IBOutlet weak var tutup: NSButton!

    /// Outlet menu popup ntuk pemilihan jenis transaksi.
    @IBOutlet weak var transaksi: NSPopUpButton!

    /// Outlet tombol untuk mengaktifkan pemilihan jenis transaksi.
    @IBOutlet weak var ubahTransaksi: NSButton!

    /// Properti untuk menyimpan status on/off
    /// pemilihan jenis transaksi.
    private var statusTransaksi: Bool = true

    /// Outlet tombol untuk memberikan tanda transaksi.
    @IBOutlet weak var tandai: NSButton!
    /// Outlet tombol untuk tidak mengubah tanda transaksi.
    @IBOutlet weak var biarkanTanda: NSButton!
    /// Outlet tombol untuk menghapus tanda transaksi.
    @IBOutlet weak var hapusTanda: NSButton!

    /// Data-data administrasi yang akan diedit.
    var editedEntities: [Entity] = []

    /// Auto Complete NSTextFiedl

    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!

    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    /// Attributed String untuk placeHolder di semua input textField yang digunakan untuk pengetikan
    // di class ``EditTransaksi``.
    var pengeditanMultipelString = NSAttributedString()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        let ve = NSVisualEffectView(frame: view.frame)
        ve.blendingMode = .behindWindow
        ve.material = .windowBackground
        ve.state = .followsWindowActiveState
        view.wantsLayer = true
        view.addSubview(ve, positioned: .below, relativeTo: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        keperluan.delegate = self
        kategori.delegate = self
        acara.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
        // Set nilai awal elemen-elemen form setelah view muncul
        if editedEntities.count == 1 {
            // Hanya satu item yang dipilih
            if let editedEntity = editedEntities.first {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
                transaksi.selectItem(withTitle: editedEntity.jenis ?? "")
                jumlah.doubleValue = editedEntity.jumlah
                jumlah.placeholderString = (formatter.string(from: NSNumber(value: editedEntity.jumlah)) ?? "")
                kategori.stringValue = editedEntity.kategori ?? ""
                kategori.placeholderString = editedEntity.kategori
                acara.stringValue = editedEntity.acara ?? ""
                keperluan.stringValue = editedEntity.keperluan ?? ""
                keperluan.placeholderString = editedEntity.keperluan
                tandai.state = editedEntity.ditandai ? .on : .off
            }
        } else if editedEntities.count > 1 {
            // Lebih dari satu item yang dipilih, atur nilai outlet menjadi "Pengeditan Multipel"
            pengeditanMultipelString = NSAttributedString(string: "pengeditan multipel", attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Sesuaikan warna sesuai keinginan Anda
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13), // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            transaksi.isEnabled = false
            statusTransaksi = false
            ubahTransaksi.state = .off
            resetKapital(pengeditanMultipelString)
            biarkanTanda.state = .on
        }
    }

    /// Action untuk tombol ``tandai``, ``biarkanTanda``, dan ``hapusTanda``.
    @IBAction func ubahTanda(_ sender: NSButton) {}

    /**
         Mengatur ulang teks placeholder untuk beberapa field teks dengan menggunakan attributed string yang diberikan.

         - Parameter attributedString: Attributed string yang akan digunakan sebagai placeholder untuk field jumlah, kategori, acara, dan keperluan.
     */
    func resetKapital(_ attributedString: NSAttributedString) {
        jumlah.placeholderAttributedString = attributedString
        kategori.placeholderAttributedString = attributedString
        acara.placeholderAttributedString = attributedString
        keperluan.placeholderAttributedString = attributedString
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.post(name: .popUpDismissedTV, object: nil)
    }

    /**
         * Action untuk tombol on/off pengeditan jenis transaksi.
         * Fungsi ini mengubah status transaksi (aktif/nonaktif) dan menyesuaikan properti `isEnabled` dari elemen UI ``transaksi``.
         *
         * - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol).
     */
    @IBAction func beralihTransaksi(_ sender: Any) {
        statusTransaksi.toggle()
        if statusTransaksi {
            transaksi.isEnabled = true
        } else {
            transaksi.isEnabled = false
        }
    }

    /**
         Fungsi yang dipanggil ketika tombol "Simpan" diklik.

         Fungsi ini bertanggung jawab untuk menyimpan perubahan data transaksi yang telah diedit.
         Data yang diubah akan disimpan ke Core Data, dan notifikasi akan dikirimkan jika ada perubahan.

         - Parameter sender: Objek `NSButton` yang memicu aksi ini.

         ## Alur Kerja:
         1.  Menentukan nilai `tanda` berdasarkan state dari tombol radio `tandai`, `biarkanTanda`, dan `hapusTanda`.
         2.  Iterasi melalui setiap entitas yang diedit (`editedEntities`).
         3.  Membandingkan data baru dengan data lama untuk mendeteksi perubahan.
         4.  Jika ada perubahan, data akan diperbarui di Core Data menggunakan `DataManager.shared.editData`.
         5.  UUID dari entitas yang diubah akan disimpan dalam set `uuid`.
         6.  Setelah iterasi selesai, jika ada data yang berubah (`isDataChanged` adalah `true`),
             notifikasi `DataManager.dataDieditNotif` akan dikirimkan dengan informasi UUID entitas yang diubah dan snapshot entitas sebelumnya.
         7.  Jika tidak ada perubahan data, sebuah alert akan ditampilkan yang memberitahukan bahwa tidak ada perubahan yang disimpan.

         ## Catatan:
         -   Fungsi ini menggunakan ekstensi `capitalizedAndTrimmed()` untuk memformat string.
         -   Fungsi ini menggunakan `ReusableFunc.createBackup(for:)` untuk membuat backup entitas sebelum perubahan.
         -   Fungsi ini menggunakan `ReusableFunc.teksFormat(_:oldValue:hurufBesar:kapital:)` untuk memformat teks jika ada pengeditan multiple.
         -   Fungsi ini menggunakan `ReusableFunc.showAlert(title:message:)` untuk menampilkan pesan alert.
     */
    @IBAction func simpanButtonClicked(_ sender: NSButton) {
        // Variabel untuk menyimpan data yang diubah
        var uuid: Set<UUID> = []
        var tanda: Bool?
        var prevEntity: [EntitySnapshot] = []
        var isDataChanged = false
        if tandai.state == .on {
            tanda = true
        } else if biarkanTanda.state == .on {
            tanda = nil
        } else if hapusTanda.state == .on {
            tanda = false
        }

        for editedEntity in editedEntities {
            // Data baru yang dibandingkan
            let jenisBaru = transaksi.isEnabled ? transaksi.title : editedEntity.jenis ?? ""
            let dariBaru = editedEntity.dari ?? ""
            let jumlahBaru = jumlah.doubleValue.isZero ? editedEntity.jumlah : jumlah.doubleValue

            var kategoriBaru = kategori.stringValue.isEmpty ? editedEntity.kategori ?? "" : kategori.stringValue.capitalizedAndTrimmed()
            var acaraBaru = acara.stringValue.isEmpty ? editedEntity.acara ?? "" : acara.stringValue.capitalizedAndTrimmed()
            var keperluanBaru = keperluan.stringValue.isEmpty ? editedEntity.keperluan ?? "" : keperluan.stringValue.capitalizedAndTrimmed()
            if editedEntities.count > 1 {
                kategoriBaru = ReusableFunc.teksFormat(kategori.stringValue, oldValue: editedEntity.kategori ?? "", hurufBesar: hurufBesar, kapital: kapitalkan)
                acaraBaru = ReusableFunc.teksFormat(acara.stringValue, oldValue: editedEntity.acara ?? "", hurufBesar: hurufBesar, kapital: kapitalkan)
                keperluanBaru = ReusableFunc.teksFormat(keperluan.stringValue, oldValue: editedEntity.keperluan ?? "", hurufBesar: hurufBesar, kapital: kapitalkan)
            }

            let tanggalBaru = editedEntity.tanggal ?? Date()
            prevEntity.append(ReusableFunc.createBackup(for: editedEntity))

            // Memeriksa perubahan data dengan `guard`
            guard jenisBaru != editedEntity.jenis ||
                dariBaru != editedEntity.dari ||
                jumlahBaru != editedEntity.jumlah ||
                kategoriBaru != editedEntity.kategori ||
                acaraBaru != editedEntity.acara ||
                keperluanBaru != editedEntity.keperluan ||
                tanggalBaru != editedEntity.tanggal ||
                tanda != editedEntity.ditandai ||
                kapitalkan != hurufBesar
            else { continue }

            // Tandai bahwa data berubah dan simpan backup
            isDataChanged = true

            // Perbarui data di Core Data
            DataManager.shared.editData(
                entity: editedEntity,
                jenis: jenisBaru,
                dari: dariBaru,
                jumlah: jumlahBaru,
                kategori: kategoriBaru,
                acara: acaraBaru,
                keperluan: keperluanBaru,
                tanggal: tanggalBaru,
                bulan: editedEntity.bulan,
                tahun: editedEntity.tahun,
                tanda: tanda ?? editedEntity.ditandai
            )

            // Tambahkan UUID entitas yang diubah
            uuid.insert(editedEntity.id ?? UUID())
        }
        // Kirim notifikasi hanya jika ada perubahan data
        if isDataChanged {
            dismiss(nil)
            let notif: [String: Any] = [
                "uuid": uuid,
                "entiti": prevEntity,
            ]
            NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: notif)
        } else {
            ReusableFunc.showAlert(title: "Data tidak dibuah", message: "Tidak ada perubahan yang disimpan")
        }
    }

    /// Properti Untuk Referensi Opsi Kapitalisasi.
    var kapitalkan: Bool = false
    /// Properti untuk referensi opsi HURUF BESAR.
    var hurufBesar: Bool = false

    /**
         Fungsi ini dipanggil ketika tombol untuk mengkapitalkan teks ditekan.

         Fungsi ini mengkapitalkan teks pada text field `keperluan`, `kategori`, dan `acara`.
         Jika ada lebih dari satu entitas yang sedang diedit, fungsi ini akan menampilkan label "Pengeditan Multipel" dengan format tertentu.
         Fungsi ini juga mengatur ulang status kapitalisasi dan mengubah nilai variabel `kapitalkan` menjadi `true` dan `hurufBesar` menjadi `false`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_ sender: Any) {
        [keperluan, kategori, acara].kapitalkanSemua()
        if editedEntities.count > 1 {
            let pengeditanMultipelStringKapital = NSAttributedString(string: "Pengeditan Multipel", attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Sesuaikan warna sesuai keinginan Anda
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13), // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            resetKapital(pengeditanMultipelStringKapital)
        }
        kapitalkan = true
        hurufBesar = false
    }

    /**
         Fungsi ini dipanggil ketika tombol "Huruf Besar" ditekan.

         Fungsi ini mengubah semua teks dalam text field `keperluan`, `kategori`, dan `acara` menjadi huruf besar.
         Jika ada lebih dari satu entitas yang sedang diedit, fungsi ini akan menampilkan teks "PENGEDITAN MULTIPEL" dengan format tertentu.
         Fungsi ini juga mengatur ulang status kapitalisasi dan menandai bahwa huruf besar telah diterapkan.

         - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func hurufBesar(_ sender: Any) {
        [keperluan, kategori, acara].hurufBesarSemua()
        if editedEntities.count > 1 {
            let pengeditanMultipelStringHurufBesar = NSAttributedString(string: "PENGEDITAN MULTIPEL", attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Sesuaikan warna sesuai keinginan Anda
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13), // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            resetKapital(pengeditanMultipelStringHurufBesar)
        }
        kapitalkan = false
        hurufBesar = true
    }

    /**
         Menangani perubahan nilai pada pop up button untuk memilih jenis transaksi.

         Fungsi ini dipanggil ketika nilai yang dipilih pada `NSPopUpButton` berubah. Fungsi ini akan memperbarui jenis transaksi yang dipilih pada objek `transaksi` berdasarkan judul item yang dipilih pada pop up button.

         - Parameter sender: `NSPopUpButton` yang mengirimkan aksi perubahan nilai.
     */
    @IBAction func jenisViewPopUpValueChanged(_ sender: NSPopUpButton) {
        // Set jenis transaksi di jenisPopUp
        transaksi.selectItem(withTitle: sender.titleOfSelectedItem ?? "")
    }

    /// Fungsi untuk menutup ``EditTransaksi``.
    /// - Parameter sender: Objek apapun dapat memicu.
    @IBAction func tutup(_ sender: Any) {
        dismiss(nil)
    }
}

extension EditTransaksi: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        activeText = obj.object as? NSTextField
        let suggestionsDict: [NSTextField: [String]] = [
            kategori: Array(ReusableFunc.kategori),
            acara: Array(ReusableFunc.acara),
            keperluan: Array(ReusableFunc.keperluan),
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

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
}
