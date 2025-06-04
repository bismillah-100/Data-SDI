//
//  EditTransaksi.swift
//  Administrasi
//
//  Created by Bismillah on 15/11/23.
//

import Cocoa

class EditTransaksi: NSViewController {
    @IBOutlet weak var jumlah: NSTextField!
    @IBOutlet weak var keperluan: NSTextField!
    @IBOutlet weak var kategori: NSTextField!
    @IBOutlet weak var acara: NSTextField!
    @IBOutlet weak var catat: NSButton!
    @IBOutlet weak var tutup: NSButton!
    @IBOutlet weak var transaksi: NSPopUpButton!
    @IBOutlet weak var ubahTransaksi: NSButton!
    // private var editedEntity: Entity?
    var editedEntities: [Entity] = []
    @IBOutlet weak var tandai: NSButton!
    @IBOutlet weak var biarkanTanda: NSButton!
    @IBOutlet weak var hapusTanda: NSButton!
    // Auto Complete NSTextFiedl
    private var statusTransaksi: Bool = true
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
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
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13) // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            transaksi.isEnabled = false
            statusTransaksi = false
            ubahTransaksi.state = .off
            resetKapital(pengeditanMultipelString)
            biarkanTanda.state = .on
            
            // Periksa status `ditandai` dari semua entitas
            // let allMarked = editedEntities.allSatisfy { $0.ditandai }
            // let allUnmarked = editedEntities.allSatisfy { !$0.ditandai }
            
            // if allMarked {
                // tandai.state = .on
            // } // else if allUnmarked {
                // biarkanTanda.state = .on
            // } else {
                //tandai.state = .on
            // }
        }
    }
    
    @IBAction func ubahTanda(_ sender: NSButton) {}
    
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
    @IBAction func beralihTransaksi(_ sender: Any) {
        statusTransaksi.toggle()
        if statusTransaksi {
            transaksi.isEnabled = true
        } else {
            transaksi.isEnabled = false
        }
    }

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
                "entiti": prevEntity
            ]
            NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: notif)
        } else {
            ReusableFunc.showAlert(title: "Data tidak dibuah", message: "Tidak ada perubahan yang disimpan")
        }
    }
    
    var kapitalkan: Bool = false
    var hurufBesar: Bool = false
    
    @IBAction func kapitalkan(_ sender: Any) {
        [keperluan, kategori, acara].kapitalkanSemua()
        if editedEntities.count > 1 {
            let pengeditanMultipelStringKapital = NSAttributedString(string: "Pengeditan Multipel", attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Sesuaikan warna sesuai keinginan Anda
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13) // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            resetKapital(pengeditanMultipelStringKapital)
        }
        kapitalkan = true
        hurufBesar = false
    }
    @IBAction func hurufBesar(_ sender: Any) {
        [keperluan, kategori, acara].hurufBesarSemua()
        if editedEntities.count > 1 {
            let pengeditanMultipelStringHurufBesar = NSAttributedString(string: "PENGEDITAN MULTIPEL", attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor, // Sesuaikan warna sesuai keinginan Anda
                NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 13) // Sesuaikan font dan ukuran sesuai keinginan Anda
            ])
            resetKapital(pengeditanMultipelStringHurufBesar)
        }
        kapitalkan = false
        hurufBesar = true
    }
    
    @IBAction func jenisViewPopUpValueChanged(_ sender: NSPopUpButton) {
        // Set jenis transaksi di jenisPopUp
        transaksi.selectItem(withTitle: sender.titleOfSelectedItem ?? "")
    }
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
            keperluan: Array(ReusableFunc.keperluan)
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
        guard let textField = obj.object as? NSTextField else {return}
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
}
