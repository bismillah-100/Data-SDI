//
//  HelpViewController.swift
//  Data SDI
//
//  Created by Bismillah on 04/11/24.
//

import Cocoa

class HelpViewController: NSViewController {
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var contentView: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    override func viewWillAppear() {
        super.viewWillAppear()
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self = self else { return }
            if let docView = self.scrollView.documentView {
                // Scroll ke atas
                let topPoint = NSPoint(x: 0, y: docView.bounds.height - self.scrollView.contentView.bounds.height)
                self.scrollView.scroll(topPoint)
            }
            self.view.needsLayout = true
            self.view.layoutSubtreeIfNeeded()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        AppDelegate.shared.helpWindow = nil
    }
    @IBAction func radioOn(_ sender: NSButton) {
        sender.state = .on
    }
    @IBAction func checkOn(_ sender: NSButton) {
        sender.state = .on
    }
    @IBAction func radioOff(_ sender: NSButton) {
        sender.state = .off
    }
    @IBAction func checOff(_ sender: NSButton) {
        sender.state = .off
    }
}
