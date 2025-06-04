//
//  TeksCuplikan.swift
//  Data SDI
//
//  Created by Bismillah on 03/12/23.
//

import Cocoa

class TeksCuplikan: NSViewController {
    @IBOutlet var teksView: NSView!
    @IBOutlet weak var nilai: NSTextField!
    @IBOutlet weak var kelas: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nilai.isSelectable = true
        kelas.isSelectable = true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            self.view.window?.close() // handle manual keyboard esc(keyCode: 53)
        } else {
            super.keyDown(with: event)
        }
    }
    
    deinit {
        teksView.removeFromSuperviewWithoutNeedingDisplay()
        self.view.removeFromSuperviewWithoutNeedingDisplay()
        teksView = nil
        nilai = nil
        kelas = nil
    }
}
