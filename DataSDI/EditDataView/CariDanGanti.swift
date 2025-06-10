//
//  CariDanGanti.swift
//  Data SDI
//
//  Created by Admin on 12/04/25.
//

import Cocoa

/// Class untuk menangani pengeditan cari dan ganti.
/// Mencari kata yang dicari untuk diganti dengan kata yang diberikan pada
/// kolom tertentu.
class CariDanGanti: NSViewController {
    /// Outlet untuk memilih kolom di dalam menu popup.
    @IBOutlet weak var popUpColumn: NSPopUpButton!
    /// Outlet menu popup untuk memilih antara mode ganti teks atau tambah teks.
    @IBOutlet weak var popUpOption: NSPopUpButton!
    /// Outlet menu popup yang ditampilkan ketika ``popUpOption`` yang dipilih adalah "Tambah teks".
    @IBOutlet weak var popUpAddText: NSPopUpButton!

    /// Outlet input untuk mencari teks yang akan diganti.
    @IBOutlet weak var findTextField: NSTextField!

    /// Outlet input untuk mencari teks yang digunakan untuk mengganti kata dari input ``findTextField``.
    @IBOutlet weak var replaceTextField: NSTextField!

    /// Outlet label yang menampilkan contoh penggantian teks atau penambahan teks.
    @IBOutlet weak var exampleLabel: NSTextField!

    /// Outlet untuk tombol "Ubah data".
    @IBOutlet weak var tmblSimpan: NSButton!

    /// Outlet label "Temukan".
    @IBOutlet weak var findLabel: NSTextField!

    /// Outlet label "Ganti dengan".
    @IBOutlet weak var replaceLabel: NSTextField!

    /// Outlet constraint jarak leading (kiri) untuk ``findLabel``.
    @IBOutlet weak var leadingConstraintFindLabel: NSLayoutConstraint!

    /// Outlet constraint jarak trailing (kanan) untuk ``findLabel``.
    @IBOutlet weak var trailingConstraintFindLabel: NSLayoutConstraint!

    /// Properti data yang akan diedit (dikirim dari ViewController asal)
    var objectData: [[String: Any]] = []

    /// Closure callback untuk mengembalikan data yang telah diedit ke ViewController asal
    var onUpdate: (([[String: Any]], String) -> Void)?

    /// Closure callback ketika ``CariDanGanti`` ditutup.
    var onClose: (() -> Void)?

    /// Properti nama-nama kolom yang memungkinkan datanya untuk diedit.
    var columns: [String] = []

    /// Properti untuk menyimpan kolom yang dipilih untuk digunakan ketika menyimpan.
    /// Secara otomatis disimpan ke UserDefaults setiap kali nilainya berubah.
    private(set) var selectedColumn: String = "Nama Barang" {
        didSet {
            UserDefaults.standard.setValue(selectedColumn, forKey: "popUpColumnEditInv")
            updateContoh()
        }
    }

    /// Properti untuk referensi jika penambahan kata untuk kalimat sebelumnya.
    /// Digunakan untuk menyesuaikan konfigurasi saat pengetikan, misalnya saat menampilkan contoh.
    private var addTextBeforeName: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        isiPopUpColumn()
        popUpAddText.isHidden = true
        tmblSimpan.isEnabled = false
        UserDefaults.standard.register(defaults: ["popUpColumnEditInv": "Nama Barang"])
        UserDefaults.standard.register(defaults: ["popUpOptionEditInv": "Ganti Teks"])
        UserDefaults.standard.register(defaults: ["poUpAddTextEditInv": "sebelum nama"])
        if let v = view as? NSVisualEffectView {
            v.blendingMode = .behindWindow
            v.material = .windowBackground
            v.state = .followsWindowActiveState
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        findTextField.delegate = self
        replaceTextField.delegate = self
        if let defaultPopUpColumn = UserDefaults.standard.string(forKey: "popUpColumnEditInv") {
            if popUpColumn.item(withTitle: defaultPopUpColumn) != nil {
                popUpColumn.selectItem(withTitle: defaultPopUpColumn)
            } else {
                popUpColumn.selectItem(at: 0)
            }
            handlePopUpColumn(popUpColumn)
        }

        if let defaultSelectedOption = UserDefaults.standard.string(forKey: "popUpOptionEditInv") {
            popUpOption.selectItem(withTitle: defaultSelectedOption)
            handlePopUpOption(popUpOption)
        }

        if popUpAddText.isEnabled,
           let defaultPopUpAddText = UserDefaults.standard.string(forKey: "poUpAddTextEditInv")
        {
            popUpAddText.selectItem(withTitle: defaultPopUpAddText)
            handlePopUpAddText(popUpAddText)
        }

        updateContoh()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        onClose?()
    }

    /// Mengisi popUpColumn dengan nama kolom yang tersedia di database.
    /// ``columns`` memuat data dari konfigurasi class yang menampilkan ``CariDanGanti``.
    func isiPopUpColumn() {
        popUpColumn.removeAllItems()
        for nama in columns {
            popUpColumn.insertItem(withTitle: nama, at: popUpColumn.numberOfItems)
        }
    }

    /**
         Memperbarui `exampleLabel` dengan contoh teks yang telah dimodifikasi berdasarkan input pengguna dan opsi yang dipilih.

         Fungsi ini mengambil teks dari `findTextField` dan `replaceTextField`, kemudian mencari baris pertama dalam `objectData` yang memiliki data pada kolom yang dipilih (`selectedColumn`).
         Jika ditemukan, fungsi ini akan mengganti atau menambahkan teks berdasarkan opsi yang dipilih pada `popUpOption`.

         - Parameter:
             - findCharacter: Teks yang akan dicari (diambil dari `findTextField`).
             - replaceCharacterWith: Teks pengganti (diambil dari `replaceTextField`).
             - originalText: Teks asli dari baris pertama yang ditemukan pada kolom yang dipilih.
             - replacedText: Teks yang telah dimodifikasi setelah penggantian.

         - Kondisi:
             - Jika `popUpOption.titleOfSelectedItem` adalah "Ganti Teks", maka `exampleLabel` akan diisi dengan contoh teks yang telah diganti.
             - Jika `popUpOption.titleOfSelectedItem` bukan "Ganti Teks", maka teks akan ditambahkan di awal atau di akhir teks asli, tergantung pada nilai `addTextBeforeName`.
             - Jika tidak ada data yang ditemukan pada kolom yang dipilih, `exampleLabel` akan diisi dengan teks default.

         - Catatan:
             Fungsi ini menggunakan `objectData`, `selectedColumn`, `findTextField`, `replaceTextField`, `popUpOption`, `exampleLabel`, dan `addTextBeforeName` yang diasumsikan telah diinisialisasi di tempat lain.
     */
    func updateContoh() {
        let findCharacter = findTextField.stringValue
        let replaceCharacterWith = replaceTextField.stringValue

        // Cari baris pertama yang memiliki data
        if let firstRow = objectData.first(where: {
            if let value = $0[selectedColumn] as? String {
                return !value.isEmpty
            }
            return false
        }), let originalText = firstRow[selectedColumn] as? String {
            let replacedText = originalText.replacingOccurrences(of: findCharacter, with: replaceCharacterWith)
            if popUpOption.titleOfSelectedItem == "Ganti Teks" {
                exampleLabel.stringValue = "Contoh: \(replacedText)"
            } else {
                if addTextBeforeName {
                    exampleLabel.stringValue = "Contoh: " + findCharacter + originalText
                } else {
                    exampleLabel.stringValue = "Contoh: " + originalText + findCharacter
                }
            }
        } else {
            if popUpOption.titleOfSelectedItem == "Ganti Teks" {
                exampleLabel.stringValue = "Contoh: "
            } else {
                exampleLabel.stringValue = "Contoh: " + findCharacter
            }
        }
    }

    /// Action untuk tombol ubah kolom ``popUpColumn``.
    @IBAction func handlePopUpColumn(_ sender: NSPopUpButton) {
        selectedColumn = sender.titleOfSelectedItem ?? ""
    }

    /// Action untuk tombol ubah pilihan ``popUpOption``.
    @IBAction func handlePopUpOption(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Ganti Teks" {
            leadingConstraintFindLabel.constant = 78
            trailingConstraintFindLabel.constant = 255
            replaceTextField.alphaValue = 1
            replaceTextField.isEnabled = true
            replaceLabel.alphaValue = 1
            findLabel.alphaValue = 1
            popUpAddText.isHidden = true
            view.needsDisplay = true
        } else if sender.titleOfSelectedItem == "Tambah Teks" {
            leadingConstraintFindLabel.constant = 11
            trailingConstraintFindLabel.constant = 11
            replaceTextField.alphaValue = 0
            replaceTextField.isEnabled = false
            replaceLabel.alphaValue = 0
            findLabel.alphaValue = 0
            popUpAddText.isHidden = false
            view.needsDisplay = true
        }
        updateContoh()
        view.window?.makeFirstResponder(findTextField)
        UserDefaults.standard.setValue(sender.titleOfSelectedItem ?? "Ganti Teks", forKey: "popUpOptionEditInv")
    }

    /// Action untuk tombol pilihan menambah teks ``popUpAddText``.
    @IBAction func handlePopUpAddText(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            addTextBeforeName = true
        } else {
            addTextBeforeName = false
        }
        updateContoh()
        UserDefaults.standard.setValue(sender.titleOfSelectedItem ?? "Ganti Teks", forKey: "poUpAddTextEditInv")
    }

    /**
     Fungsi ini dipanggil ketika tombol "Ubah data" ditekan. Fungsi ini melakukan iterasi pada setiap baris data dalam `objectData`,
     melakukan operasi editing berdasarkan opsi yang dipilih pada `popUpOption`, dan kemudian mengirimkan data yang telah diperbarui
     kembali ke `ViewController` asal melalui closure `onUpdate`.

     - Parameter sender: Objek `NSButton` yang memicu aksi ini.

     **Detail Operasi:**
     1. **Inisialisasi Data:** Membuat salinan dari `objectData` untuk menyimpan data yang telah diperbarui.
     2. **Iterasi Data:** Melakukan iterasi pada setiap baris data dalam `objectData`.
     3. **Pengambilan Data Baris:** Mengambil data baris pada indeks saat ini.
     4. **Operasi Editing:**
        - Memeriksa opsi yang dipilih pada `popUpOption`.
        - Jika opsi "Ganti Teks" dipilih, fungsi akan mencari teks yang ditentukan dalam `findTextField` dan menggantinya dengan teks dalam `replaceTextField` pada kolom yang dipilih (`selectedColumn`).
        - Jika opsi "Tambah Teks" dipilih, fungsi akan menambahkan teks dari `findTextField` sebelum atau sesudah nilai yang ada pada kolom yang dipilih, tergantung pada nilai `addTextBeforeName`.
     5. **Penyimpanan Data yang Diperbarui:** Menyimpan kembali baris data yang telah diperbarui ke dalam `allUpdatedData`.
     6. **Pengiriman Data:** Mengganti `objectData` dengan `allUpdatedData` dan mengirimkan seluruh data yang telah diperbarui ke `ViewController` asal melalui closure `onUpdate`, bersama dengan indeks kolom yang dipilih.
     */
    @IBAction func updateButtonClicked(_ sender: NSButton) {
        // Pastikan data inventory tersedia sebagai array (beberapa baris)
        var allUpdatedData = objectData

        // Iterasi setiap baris data yang akan diperbarui
        for index in objectData.indices {
            // Ambil row data pada indeks tersebut
            var rowData = objectData[index]

            // Lakukan operasi editing berdasarkan opsi yang dipilih pada popUpOption
            if let title = popUpOption.selectedItem?.title {
                switch title {
                case "Ganti Teks":
                    // Opsi Find & Replace
                    let searchText = findTextField.stringValue
                    let replaceWith = replaceTextField.stringValue
                    if let currentValue = rowData[selectedColumn] as? String {
                        let newValue = currentValue.replacingOccurrences(of: searchText, with: replaceWith)
                        rowData[selectedColumn] = newValue
                    }
                case "Tambah Teks":
                    // Opsi penambahan teks (sebelum atau sesudah nilai)
                    let addText = findTextField.stringValue
                    let currentValue = rowData[selectedColumn] as? String ?? ""
                    let newValue = addTextBeforeName ? (addText + currentValue) : (currentValue + addText)
                    rowData[selectedColumn] = newValue
                default:
                    NSLog("Opsi editing tidak valid.")
                }
            }

            // Simpan kembali row yang telah diperbarui
            allUpdatedData[index] = rowData
        }

        objectData = allUpdatedData

        // Kirim seluruh data yang telah diperbarui ke ViewController asal melalui closure onUpdate
        onUpdate?(allUpdatedData, selectedColumn)
    }

    /// IBAction untuk tombol Cancel "Tutup" di XIB.
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        dismiss(self)
    }

    /// Fungsi untuk menginisialisasi EditInventory dari XIB.
    static func instantiate() -> CariDanGanti {
        CariDanGanti(nibName: "CariDanGanti", bundle: nil)
    }

    deinit {
        onUpdate = nil
    }
}

/// Menggunakan `NSTextFieldDelegate` untuk melacak pengetikan.
extension CariDanGanti: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if findTextField.stringValue.isEmpty {
            tmblSimpan.isEnabled = false
        } else {
            tmblSimpan.isEnabled = true
        }
        updateContoh()
    }
}
