//
//  EditInventory.swift
//  Data SDI
//
//  Created by Admin on 12/04/25.
//

import Cocoa

class CariDanGanti: NSViewController {
    @IBOutlet weak var popUpColumn: NSPopUpButton!
    @IBOutlet weak var popUpOption: NSPopUpButton!
    @IBOutlet weak var popUpAddText: NSPopUpButton!
    @IBOutlet weak var findTextField: NSTextField!
    @IBOutlet weak var replaceTextField: NSTextField!
    @IBOutlet weak var exampleLabel: NSTextField!
    @IBOutlet weak var tmblSimpan: NSButton!
    
    @IBOutlet weak var findLabel: NSTextField!
    @IBOutlet weak var replaceLabel: NSTextField!
    
    @IBOutlet weak var leadingConstraintFindLabel: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraintFindLabel: NSLayoutConstraint!
    
    // Data inventory yang akan diedit (dikirim dari ViewController asal)
    var objectData: [[String: Any]] = []
    
    // Closure callback untuk mengembalikan data yang telah diedit ke ViewController asal
    var onUpdate: (([[String: Any]], String) -> Void)?
    
    // Closure callback ringan
    var onClose: (() -> Void)?
    
    // variabel untuk mendapatkan nama kolom
    var columns: [String] = []
    
    // variabel untuk menyimpan kolom yang dipilih untuk digunakan ketika menyimpan
    private(set) var selectedColumn: String = "Nama Barang" {
        didSet {
            UserDefaults.standard.setValue(selectedColumn, forKey: "popUpColumnEditInv")
            updateContoh()
        }
    }
    
    private var addTextBeforeName: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        isiPopUpColumn()
        popUpAddText.isHidden = true
        tmblSimpan.isEnabled = false
        UserDefaults.standard.register(defaults: ["popUpColumnEditInv" : "Nama Barang"])
        UserDefaults.standard.register(defaults: ["popUpOptionEditInv" : "Ganti Teks"])
        UserDefaults.standard.register(defaults: ["poUpAddTextEditInv" : "sebelum nama"])
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
            if (popUpColumn.item(withTitle: defaultPopUpColumn) != nil) {
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
           let defaultPopUpAddText = UserDefaults.standard.string(forKey: "poUpAddTextEditInv") {
            popUpAddText.selectItem(withTitle: defaultPopUpAddText)
            handlePopUpAddText(popUpAddText)
        }
        
        updateContoh()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        onClose?()
    }
    
    /// Mengisi popUpColumn dengan nama kolom yang tersedia di database
    func isiPopUpColumn() {
        popUpColumn.removeAllItems()
        columns.forEach({ nama in
            popUpColumn.insertItem(withTitle: nama, at: popUpColumn.numberOfItems)
        })
    }
    
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
    
    /// untuk tombol ubah kolom
    @IBAction func handlePopUpColumn(_ sender: NSPopUpButton) {
        selectedColumn = sender.titleOfSelectedItem ?? ""
    }
    /// untuk tombol ubah pilihan
    @IBAction func handlePopUpOption(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem == "Ganti Teks" {
            leadingConstraintFindLabel.constant = 78
            trailingConstraintFindLabel.constant = 255
            replaceTextField.alphaValue = 1
            replaceTextField.isEnabled = true
            replaceLabel.alphaValue = 1
            findLabel.alphaValue = 1
            popUpAddText.isHidden = true
            self.view.needsDisplay = true
        }
        else if sender.titleOfSelectedItem == "Tambah Teks" {
            leadingConstraintFindLabel.constant = 11
            trailingConstraintFindLabel.constant = 11
            replaceTextField.alphaValue = 0
            replaceTextField.isEnabled = false
            replaceLabel.alphaValue = 0
            findLabel.alphaValue = 0
            popUpAddText.isHidden = false
            self.view.needsDisplay = true
        }
        updateContoh()
        self.view.window?.makeFirstResponder(findTextField)
        UserDefaults.standard.setValue(sender.titleOfSelectedItem ?? "Ganti Teks", forKey: "popUpOptionEditInv")
    }
    /// untuk tombol pilihan menambah teks
    @IBAction func handlePopUpAddText(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            addTextBeforeName = true
        } else {
            addTextBeforeName = false
        }
        updateContoh()
        UserDefaults.standard.setValue(sender.titleOfSelectedItem ?? "Ganti Teks", forKey: "poUpAddTextEditInv")
    }
    /// IBAction untuk tombol Update di XIB
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
    
    /// IBAction untuk tombol Cancel di XIB
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        self.dismiss(self)
    }
    
    /// Fungsi untuk menginisialisasi EditInventory dari XIB
    static func instantiate() -> CariDanGanti {
        return CariDanGanti(nibName: "CariDanGanti", bundle: nil)
    }
    
    deinit {
        onUpdate = nil
    }
}


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
