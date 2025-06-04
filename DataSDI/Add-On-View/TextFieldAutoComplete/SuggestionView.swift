//
//  SuggestionView.swift
//  TextField Completion
//
//  Created by Bismillah on 02/10/24.
//

import Cocoa

class SuggestionView: NSView {
    @IBOutlet var view: NSView!
    @IBOutlet weak var containerView: NSView!
    var selectedIndex: Int = -1
    var onSuggestionSelected: ((Int, String) -> Void)?
    private var suggestionItemViews: [SuggestionItemView] = []
    var cornerRadius: CGFloat = 7.0 {
        didSet {
            layer?.cornerRadius = cornerRadius
            layer?.masksToBounds = true
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFromNib()
    }
    
    private func setupFromNib() {
        Bundle.main.loadNibNamed("SuggestionView", owner: self, topLevelObjects: nil)
        addSubview(view)
        view.frame = self.bounds
        view.autoresizingMask = [.width, .height]
        
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.masksToBounds = true

        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        
        view.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func updateSuggestions(_ suggestions: [String]) {
        // Hapus semua subview dan suggestionTextFields sebelumnya
        suggestionItemViews.forEach { $0.removeFromSuperview() }
        suggestionItemViews.removeAll()

        // Tambahkan view baru untuk setiap saran
        for (index, suggestion) in suggestions.enumerated() {
            // Buat instance CenteredTextFieldView
            let centeredView = SuggestionItemView(frame: NSRect(x: 0, y: CGFloat((suggestions.count - 1 - index) * 18), width: containerView.frame.width, height: 18), text: suggestion, index: index)
            centeredView.translatesAutoresizingMaskIntoConstraints = false
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(suggestionClicked(_:)))
            centeredView.textField.addGestureRecognizer(clickGesture)
            centeredView.textField.tag = index

            // Tambahkan CenteredTextFieldView ke containerView
            containerView.addSubview(centeredView)
            suggestionItemViews.append(centeredView)
            // Buat dan tambahkan LineView
            let lineView = LineView()
            lineView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(lineView)
            
            
            // Set constraints untuk CenteredTextFieldView
            NSLayoutConstraint.activate([
                centeredView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                centeredView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                centeredView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: CGFloat(index * 21)),  // 20 untuk tinggi + 1 untuk jarak
                centeredView.heightAnchor.constraint(equalToConstant: 20),
                
                // Set constraints untuk LineView
                lineView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                lineView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                lineView.bottomAnchor.constraint(equalTo: centeredView.topAnchor),  // Garis di atas textField
                lineView.heightAnchor.constraint(equalToConstant: 1)  // Tinggi garis
            ])
            
        }

        // Update tinggi containerView dan view utama sesuai dengan jumlah suggestions
        let height = CGFloat(suggestions.count * 21)  // Tinggi 20 untuk textField + 1 untuk jarak
        containerView.frame.size.height = height
        self.frame.size.height = height
        view.frame = self.bounds
        updateHighlight()
    }
    
    @objc private func suggestionClicked(_ gesture: NSClickGestureRecognizer) {
        guard let textField = gesture.view as? NSTextField else { return }
        selectedIndex = textField.tag
        updateHighlight()
        onSuggestionSelected?(textField.tag, textField.stringValue)
        selectSuggestion(at: textField.tag)
        
        
    }
    
    func selectSuggestion(at index: Int) {
        selectedIndex = index
        updateHighlight()
    }
    
    func updateHighlight() {
        for itemView in suggestionItemViews {
            itemView.isHighlighted = (itemView.index == selectedIndex)
        }
    }
}

