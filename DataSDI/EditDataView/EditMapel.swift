//
//  EditMapel.swift
//  Data SDI
//
//  Created by Bismillah on 03/10/24.
//

import Cocoa

class EditMapel: NSViewController {
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var tutupButton: NSButton!
    @IBOutlet var contentView: NSView!
    @IBOutlet weak var tambahDaftarGuru: NSButton!

    private var mapelViews: [MapelEditView] = []
    private var mapelData: [(String, String, TableType)] = []
    
    private var scrollViewHeightConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
    }
    override func viewDidAppear() {
        if UserDefaults.standard.bool(forKey: "tambahkanDaftarGuruBaru") == true {
            tambahDaftarGuru.state = .on
        } else {
            tambahDaftarGuru.state = .off
        }
        if let sheetWindow = self.view.window {
            // Menonaktifkan kemampuan untuk memperbesar ukuran sheet
            sheetWindow.styleMask.remove(.resizable)
        }
    }
    
    func loadMapelData(mapelData: [(String, String, TableType)]) {
        self.mapelData = mapelData
        createMapelViews()
    }
    
    private func setupScrollView() {
        scrollView.documentView = contentView
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
            
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Remove existing height constraint if any
        if let existingHeightConstraint = scrollView.constraints.first(where: { $0.firstAttribute == .height }) {
            scrollView.removeConstraint(existingHeightConstraint)
        }
        // Add new height constraint to scrollView
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 252)
        scrollViewHeightConstraint?.priority = .defaultHigh // Set priority lower than required
        scrollViewHeightConstraint?.isActive = true
        
        // Add constraint to limit minimum height of scrollView
        let minHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        minHeightConstraint.priority = .required
        minHeightConstraint.isActive = true
    }
    
    private func createMapelViews() {
        // Clear existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        mapelViews.removeAll()
        
        var lastView: NSView?
        let spacing: CGFloat = 8
        let mapelViewHeight: CGFloat = 30
        let lineHeight: CGFloat = 1
        let maxHeight: CGFloat = 302
        let bottomPadding: CGFloat = 42
        let topPadding: CGFloat = 42  // Sudah didefinisikan

        // Sort and create views
        for (index, (mapel, guru, _)) in mapelData.enumerated().sorted(by: {$0.element.0 < $1.element.0}) {
            let mapelView = MapelEditView(mapel: mapel, guru: guru)
            mapelViews.append(mapelView)
            
            contentView.addSubview(mapelView)
            mapelView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                mapelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
                mapelView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                mapelView.heightAnchor.constraint(equalToConstant: mapelViewHeight),
                mapelView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -8)
            ])
            
            // Constraint untuk first MapelView
            if index == 0 {
                mapelView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing).isActive = true
            } else {
                if let view = lastView {
                    mapelView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: spacing).isActive = true
                }
            }
            
            lastView = mapelView
            
            // Tambahkan line view jika bukan item terakhir
            if index < mapelData.count - 1 {
                let lineView = LineView()
                contentView.addSubview(lineView)
                lineView.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    lineView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                    lineView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                    lineView.topAnchor.constraint(equalTo: mapelView.bottomAnchor, constant: spacing),
                    lineView.heightAnchor.constraint(equalToConstant: lineHeight)
                ])
                
                lastView = lineView
            }
            
            // Pastikan bottom constraint selalu diset untuk setiap MapelView
            if index == mapelData.count - 1 {
                mapelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing).isActive = true
            }
        }
        
        // Calculate total height with minimum height for single item
        let totalItemSpacing = CGFloat(max(1, mapelData.count - 1)) * (spacing * 2 + lineHeight)
        let totalMapelViewsHeight = CGFloat(mapelData.count) * mapelViewHeight
        let totalHeight = max(
            mapelViewHeight + (spacing * 2), // Minimum height for single item
            totalMapelViewsHeight + totalItemSpacing + (spacing * 2)
        )

        // Set up scrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = totalHeight > maxHeight
        
        // Update heights
        let newHeight = min(totalHeight, maxHeight)
        scrollViewHeightConstraint?.constant = newHeight
        contentView.frame.size.height = totalHeight
        
        // ScrollView constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomPadding)
        ])
        
        // Update view height - ensure minimum height when single item
        let finalViewHeight = newHeight + bottomPadding + topPadding
        view.frame.size.height = finalViewHeight
        
        // Update scroll view
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.documentView?.bounds.height ?? 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        view.layoutSubtreeIfNeeded()
    }
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                window.performClose(sender)
            }
        }
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        // Siapkan array untuk menampung data mapel dan guru yang baru
        var updatedMapelData: [(String, String, String, TableType)] = []  // Tambah variabel untuk guru lama
        
        // Loop melalui setiap MapelEditView untuk mendapatkan data yang baru
        for mapelView in mapelViews {
            let updatedMapel = mapelView.getMapelName()
            let updatedGuru = mapelView.getGuruName()
            
            // Cari tipe tabel dan nama guru lama dari mapelData yang asli
            if let originalData = mapelData.first(where: { $0.0 == updatedMapel }) {
                let tableType = originalData.2
                let oldGuru = originalData.1  // Nama guru lama
                updatedMapelData.append((updatedMapel, updatedGuru, oldGuru, tableType))
            }
        }
        
        // Repack data untuk dikirim dalam notifikasi, termasuk nama guru lama
        let repackedMapelData = updatedMapelData.map { ["mapel": $0.0, "guruBaru": $0.1, "guruLama": $0.2, "tipeTabel": $0.3] }
        // Mencatat nama guru baru jika belum tercatat di Daftar Guru
        if tambahDaftarGuru.state == .on {
            let dbController = DatabaseController.shared
            for (_, element) in repackedMapelData.enumerated() {
                let tahunIni = Calendar.current.component(.year, from: Date())
                if let guru = element["guruBaru"] as? String, let mapel = element["mapel"] as? String {
                    dbController.addGuru(namaGuruValue: guru, alamatGuruValue: "", tahunaktifValue: String(tahunIni), mapelValue: mapel, struktur: "")
                    
                }
            }
        }
        // Kirim notifikasi dengan data mapel dan guru yang diperbarui serta guru lama
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "updateGuruMapel"),
            object: nil,
            userInfo: ["mapelData": repackedMapelData]
        )
        self.dismiss(nil)
    }
    
    @IBAction func kapitalkan(_ sender: Any) {
        mapelViews.forEach({ view in
            view.guruTextField.stringValue = view.guruTextField.stringValue.capitalized
        })
    }
    @IBAction func hurufBesar(_ sender: Any) {
        mapelViews.forEach({ view in
            view.guruTextField.stringValue = view.guruTextField.stringValue.uppercased()
        })
    }
    
}


class MapelEditView: NSView {
    @IBOutlet var mapelLabel: NSTextField!
    @IBOutlet var guruTextField: NSTextField!
    var suggestionManager: SuggestionManager!
    var activeText: NSTextField!
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    init(mapel: String, guru: String) {
        mapelLabel = NSTextField(labelWithString: mapel)
        guruTextField = NSTextField(string: guru)
        guruTextField.placeholderString = "Nama Guru \(mapel)"
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        self.mapelLabel = NSTextField()
        self.guruTextField = NSTextField()
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = .clear
        setupViews()
    }
    
    private func setupViews() {
        mapelLabel.translatesAutoresizingMaskIntoConstraints = false
        guruTextField.translatesAutoresizingMaskIntoConstraints = false
        guruTextField.bezelStyle = .roundedBezel
        addSubview(mapelLabel)
        addSubview(guruTextField)
        guruTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
        NSLayoutConstraint.activate([
            mapelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            mapelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            mapelLabel.widthAnchor.constraint(equalToConstant: 150),
            
            guruTextField.leadingAnchor.constraint(equalTo: mapelLabel.trailingAnchor, constant: 4),
            guruTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            guruTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            guruTextField.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func getMapelName() -> String {
        return mapelLabel.stringValue
    }
    
    func getGuruName() -> String {
        return guruTextField.stringValue
    }
}

extension MapelEditView: NSTextFieldDelegate {
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
            guruTextField: Array(ReusableFunc.namaguru)
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
