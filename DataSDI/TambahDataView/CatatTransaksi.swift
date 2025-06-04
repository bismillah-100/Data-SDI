//
//  CatatTransaksi.swift
//  Administrasi
//
//  Created by Bismillah on 15/11/23.
//

import Cocoa

class CatatTransaksi: NSViewController {
    @IBOutlet var pilihjTransaksi: NSPopUpButton!
    @IBOutlet var jumlah: NSTextField!
    @IBOutlet var keperluan: NSTextField!
    @IBOutlet var kategori: NSTextField!
    @IBOutlet var acara: NSTextField!
    @IBOutlet var tanggal: ExpandingDatePicker!
    @IBOutlet var catat: NSButton!
    @IBOutlet weak var tandaiButton: NSButton!
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
    // Ambil semua data dari database
    var existingData: [Entity] = []
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
            self.view.window?.backgroundColor = .clear
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
    @IBAction func tambahTransaksi(_ sender: NSButton) {
        // Mendapatkan nilai dari NSTextField
        guard let jenisTransaksi = pilihjTransaksi.titleOfSelectedItem else {
            return // Jika jenis transaksi tidak dipilih
        }
        
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

        guard !jumlahTransaksi.isZero && (!keperluanTransaksi.isEmpty || !acaraTransaksi.isEmpty || !kategoriTransaksi.isEmpty) else {
            if jumlahTransaksi.isZero {
                ReusableFunc.showAlert(title: "Jumlah Transaksi Tidak Boleh Kosong", message: "Mohon isi jumlah transaksi dengan nilai yang valid sebelum menyimpan.")
            } else {
                ReusableFunc.showAlert(title: "Keterangan Transaksi Transaksi Tidak Boleh Kosong", message: "Mohon isi setidaknya satu keterangan transaksi sebelum menyimpan.")
            }
            return
        }
        
        // Periksa duplikasi
        let isDuplicate = existingData.contains { entity in
            return entity.jenis == jenisTransaksi &&
                   entity.dari == dariSumber &&
                   entity.jumlah == jumlahTransaksi &&
                   entity.kategori == kategoriTransaksi &&
                   entity.acara == acaraTransaksi &&
                   entity.keperluan == keperluanTransaksi &&
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
        _ = DataManager.shared.addData(
            jenis: jenisTransaksi,
            dari: dariSumber,
            jumlah: jumlahTransaksi,
            kategori: kategoriTransaksi,
            acara: acaraTransaksi,
            keperluan: keperluanTransaksi,
            tanggal: tanggalTransaksi,
            bulan: Int64(bulanTransaksi),
            tahun: Int64(tahunTransaksi),
            tanda: tandaiButton.state == .on ? true : false
        )
        
        NotificationCenter.default.post(name: DataManager.dataDidChangeNotification, object: nil)
        ReusableFunc.resetMenuItems()
    }

    @IBAction func kapitalkan(_ sender: Any) {
        [keperluan, kategori, acara].kapitalkanSemua()
    }
    @IBAction func hurufBesar(_ sender: Any) {
        [keperluan, kategori, acara].hurufBesarSemua()
    }
    
    @IBAction func close(_ sender: Any) {
        if let window = self.view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                self.view.window?.performClose(sender)
            }
        }
    }
     
}

extension CatatTransaksi: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        activeText = obj.object as? NSTextField
        let suggestionsDict: [NSTextField: [String]] = [
            kategori: Array(ReusableFunc.kategori),
            acara: Array(ReusableFunc.acara),
            keperluan: Array(ReusableFunc.keperluan)
        ]
        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return false}
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
