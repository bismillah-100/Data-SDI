//
//  TabContentView.swift
//  Data SDI
//
//  Created by Admin on 17/04/25.
//

import Cocoa

class TabContentView: NSView {

    @IBOutlet var tabView: NSTabView!
    @IBOutlet weak var table1: EditableTableView!
    @IBOutlet weak var table2: EditableTableView!
    @IBOutlet weak var table3: EditableTableView!
    @IBOutlet weak var table4: EditableTableView!
    @IBOutlet weak var table5: EditableTableView!
    @IBOutlet weak var table6: EditableTableView!
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromNib()
    }
    
    private func loadFromNib() {
        var topLevelObjects: NSArray? = nil
        Bundle.main.loadNibNamed("TabContentView", owner: self, topLevelObjects: &topLevelObjects)
    }
}
