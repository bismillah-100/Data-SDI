//
//  TeksCuplikan.swift
//  Data SDI
//
//  Created by Bismillah on 03/12/23.
//

import Cocoa

/// ViewController untuk memuat `NSPopOver` yang dibuat dari ``Stats`` ketika ada grafik chart yang diklik.
class TeksCuplikan: NSViewController {
    /// View yang memuat textField.
    @IBOutlet var teksView: NSView!
    /// Outlet nilai.
    @IBOutlet weak var nilai: NSTextField!
    /// Outlet kelas.
    @IBOutlet weak var kelas: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        nilai.isSelectable = true
        kelas.isSelectable = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            view.window?.close() // handle manual keyboard esc(keyCode: 53)
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
