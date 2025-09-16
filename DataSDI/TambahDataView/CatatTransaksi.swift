//
//  CatatTransaksi.swift
//  Administrasi
//
//  Created by Bismillah on 15/11/23.
//

import Cocoa

/// Class yang menangani penambahan data administrasi.
class CatatTransaksi: NSViewController {
    /// Outlet untuk memilih jenis transaksi.
    @IBOutlet var pilihjTransaksi: NSPopUpButton!
    /// Outlet untuk pengetikan jumlah.
    @IBOutlet var jumlah: NSTextField!
    /// Outlet untuk pengetikan keperluan.
    @IBOutlet var keperluan: NSTextField!
    /// Outlet untuk pengetikan kategori.
    @IBOutlet var kategori: NSTextField!
    /// Outlet untuk pengetikan acara.
    @IBOutlet var acara: NSTextField!
    /// Outlet untuk pemilihan tanggal
    @IBOutlet var tanggal: ExpandingDatePicker!

    /// Outlet tombol "simpan".
    @IBOutlet var catat: NSButton!
    /// Outlet tombol untuk memberikan tanda transaksi.
    @IBOutlet weak var tandaiButton: NSButton!
    /// Instance ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    /// Properti yang menyimpan semua data administrasi.
    /// Digunakan untuk memeriksa kecocokan data ketika menambahakan data.
    var existingData: [Entity] = []

    /// Properti referensi ketika tampilan ``CatatTransaksi`` ditampilkan dalam jendela *sheet*.
    var sheetWindow = false
    override func viewDidLoad() {
        super.viewDidLoad()
        if sheetWindow {
            let ve = NSVisualEffectView(frame: view.frame)
            ve.blendingMode = .behindWindow
            ve.material = .windowBackground
            ve.state = .followsWindowActiveState
            ve.wantsLayer = true
            view.addSubview(ve, positioned: .below, relativeTo: nil)
            view.window?.backgroundColor = .clear
        }
        keperluan.delegate = self
        kategori.delegate = self
        acara.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
        // Do view setup here.
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        existingData = DataManager.shared.fetchData()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.post(name: .popUpDismissedTV, object: nil)
    }

    /**
         Menangani aksi saat tombol "Tambah Transaksi" ditekan. Fungsi ini melakukan validasi input,
         memeriksa duplikasi data, dan menambahkan data transaksi ke database jika semua validasi berhasil.

         - Parameter sender: Objek `NSButton` yang memicu aksi ini.

         Langkah-langkah yang dilakukan:
         1.  **Validasi Input:** Memastikan bahwa jenis transaksi telah dipilih, dan jumlah transaksi tidak nol,
             serta setidaknya satu keterangan transaksi (kategori, acara, atau keperluan) telah diisi.
             Jika validasi gagal, sebuah alert akan ditampilkan dan fungsi akan berhenti.
         2.  **Pemeriksaan Duplikasi:** Memeriksa apakah data transaksi yang sama sudah ada di database.
             Jika ditemukan duplikat, sebuah alert akan ditampilkan dan fungsi akan berhenti.
         3.  **Penambahan Data:** Jika tidak ada duplikat dan semua validasi berhasil, data transaksi akan ditambahkan
             ke database menggunakan `DataManager.shared.addData`.
         4.  **Pemberitahuan Perubahan Data:** Setelah data berhasil ditambahkan, sebuah pemberitahuan akan diposting
             melalui `NotificationCenter` untuk memberitahu komponen lain bahwa data telah berubah.
         5.  **Reset Menu Items:** Memanggil `ReusableFunc.resetMenuItems()` untuk mereset tampilan menu.
     */
    @IBAction func tambahTransaksi(_: NSButton) {
        let jenisTransaksi = Int16(pilihjTransaksi.selectedItem?.tag ?? 0)

        if pilihjTransaksi.indexOfSelectedItem == 0 {
            let alert = NSAlert()
            alert.messageText = "Pilih Jenis Transaksi"
            alert.informativeText = "Mohon pilih jenis transaksi yang valid."
            alert.alertStyle = .warning
            alert.icon = NSImage(named: "NSCaution")
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let dariSumber = ""
        let jumlahTransaksi = jumlah.doubleValue
        let kategoriTransaksi = kategori.stringValue.capitalizedAndTrimmed()
        let acaraTransaksi = acara.stringValue.capitalizedAndTrimmed()
        let keperluanTransaksi = keperluan.stringValue.capitalizedAndTrimmed()
        let tanggalTransaksi = tanggal.dateValue
        let bulanTransaksi = Calendar.current.component(.month, from: tanggalTransaksi)
        let tahunTransaksi = Calendar.current.component(.year, from: tanggalTransaksi)

        guard !jumlahTransaksi.isZero, !keperluanTransaksi.isEmpty || !acaraTransaksi.isEmpty || !kategoriTransaksi.isEmpty else {
            if jumlahTransaksi.isZero {
                ReusableFunc.showAlert(title: "Jumlah Transaksi Tidak Boleh Kosong", message: "Mohon isi jumlah transaksi dengan nilai yang valid sebelum menyimpan.")
            } else {
                ReusableFunc.showAlert(title: "Keterangan Transaksi Transaksi Tidak Boleh Kosong", message: "Mohon isi setidaknya satu keterangan transaksi sebelum menyimpan.")
            }
            return
        }

        // Periksa duplikasi
        let isDuplicate = existingData.contains { entity in
            entity.jenis == jenisTransaksi &&
                entity.dari == dariSumber &&
                entity.jumlah == jumlahTransaksi &&
                entity.kategori?.value ?? "" == kategoriTransaksi &&
                entity.acara?.value ?? "" == acaraTransaksi &&
                entity.keperluan?.value ?? "" == keperluanTransaksi &&
                entity.tanggal == tanggalTransaksi &&
                entity.bulan == Int64(bulanTransaksi) &&
                entity.tahun == Int64(tahunTransaksi)
        }

        // Jika ditemukan duplikat, tampilkan alert
        if isDuplicate {
            let alert = NSAlert()
            alert.messageText = "Data Duplikat"
            alert.informativeText = "Data dengan informasi yang sama sudah ada di database. Transaksi tidak ditambahkan."
            alert.alertStyle = .warning
            alert.icon = NSImage(named: "NSCaution")
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Memanggil metode addData jika tidak ada duplikat
        let id = DataManager.shared.addData(
            jenis: jenisTransaksi,
            dari: dariSumber,
            jumlah: jumlahTransaksi,
            kategori: kategoriTransaksi,
            acara: acaraTransaksi,
            keperluan: keperluanTransaksi,
            tanggal: tanggalTransaksi,
            bulan: Int16(bulanTransaksi),
            tahun: Int16(tahunTransaksi),
            tanda: tandaiButton.state == .on ? true : false
        )
        guard let id else { return }
        NotificationCenter.default.post(name: DataManager.dataDidChangeNotification, object: nil, userInfo: ["newItem": id])
        ReusableFunc.resetMenuItems()
    }

    /**
         Fungsi ini dipanggil ketika tombol "Aa" ditekan.

         Fungsi ini mengkapitalkan teks pada text field ``keperluan``, ``kategori``, dan `acara`.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_: Any) {
        [keperluan, kategori, acara].kapitalkanSemua()
    }

    /**
         Fungsi ini dipanggil ketika tombol "Aa" ditekan.

         Fungsi ini membuat teks di ``keperluan``, ``kategori``, dan `acara` menjadi HURUF BESAR.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func hurufBesar(_: Any) {
        [keperluan, kategori, acara].hurufBesarSemua()
    }

    /// Fungsi untuk menutup tampilan ``CatatTransaksi``.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    @IBAction func close(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                view.window?.performClose(sender)
            }
        }
    }
}

extension CatatTransaksi: NSTextFieldDelegate {
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
            kategori: Array(ReusableFunc.kategori),
            acara: Array(ReusableFunc.acara),
            keperluan: Array(ReusableFunc.keperluan),
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
