 //
//  WindowController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa
import SwiftUI

 class WindowController: NSWindowController, NSWindowDelegate {
    // weak var delegate: WindowControllerDelegate?
    @IBOutlet weak var toolbar: MyToolbar!
    @IBOutlet weak var kalkulasiButton: NSButton!
    @IBOutlet weak var tambahDetaildiKelas: NSButton!
    @IBOutlet weak var tambahSiswa: NSButton!
    @IBOutlet weak var jumlahnilaiKelas: NSButton!
    @IBOutlet weak var statistikButton: NSButton!
    @IBOutlet weak var tmblhps: NSButton!
    @IBOutlet weak var tmbledit: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var sidebarButton: NSToolbarItem!
    @IBOutlet weak var search: NSSearchToolbarItem!
    @IBOutlet weak var simpanToolbar: NSToolbarItem!
    @IBOutlet weak var datakelas: NSToolbarItem!
    @IBOutlet weak var segmentedControl: NSToolbarItem!
    @IBOutlet weak var actionToolbar: NSToolbarItem!
    @IBOutlet weak var hapusToolbar: NSToolbarItem!
    @IBOutlet weak var editToolbar: NSToolbarItem!
    @IBOutlet weak var addDataToolbar: NSToolbarItem!
    @IBOutlet weak var jumlahToolbar: NSToolbarItem!
    @IBOutlet weak var kalkulasiToolbar: NSToolbarItem!
    @IBOutlet weak var statistikToolbar: NSToolbarItem!
    @IBOutlet weak var printToolbar: NSToolbarItem!
    @IBOutlet weak var tracking: NSToolbarItem!
    
    var jumlahPopOver: NSPopover?
     
    override var window: NSWindow? {
        didSet {
            if let window = window {
                // Ini sebagai ganti windowDidLoad
                window.contentViewController = SplitVC(nibName: "SplitView", bundle: nil)
                window.toolbar = self.toolbar
            }
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.window?.delegate = self

        if let windowFrameData = UserDefaults.standard.data(forKey: "WindowFrame"),
           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData) {
            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
            var frame = windowFrame.rectValue
            if frame.size.width < 50 {
                frame.size.width = 800  // Ganti dengan lebar default yang diinginkan
            }
            
            if frame.size.height < 50 {
                frame.size.height = 600  // Ganti dengan tinggi default yang diinginkan
            }
            // Mengatur ulang ukuran dan posisi jendela
            self.window?.setFrame(frame, display: true)
        } else {
            // Jika tidak ada ukuran yang disimpan, gunakan ukuran default di sini.
            let defaultSize = NSSize(width: 800, height: 600)
            self.window?.setContentSize(defaultSize)
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self.window, queue: nil) { notification in
            if let window = notification.object as? NSWindow {
                _ = window.frame.size
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                    UserDefaults.standard.set(data, forKey: "WindowFrame")
                } catch {
                    
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self.window, queue: nil) { notification in
            if let window = notification.object as? NSWindow {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                    UserDefaults.standard.set(data, forKey: "WindowFrame")
                } catch {
                    
                }
            }
        }
    }
    
    
//    @IBAction override func newWindowForTab(_ sender: Any?) {
//        let storyboard = NSStoryboard(name: "Main", bundle: nil)
//        guard let newWindowController = storyboard.instantiateController(withIdentifier: "MainWindowController") as? WindowController else {
//            
//            return
//        }
//        
//        // Menambahkan window sebagai tab baru
//        let window = newWindowController.window!
//        
//        // Menambahkan window sebagai tab baru
//        let newWindowIdentifier = UUID().uuidString
//        newWindowController.windowIdentifier = newWindowIdentifier
//        window.windowController = newWindowController
//        window.isReleasedWhenClosed = true
//        window.makeKeyAndOrderFront(self)
//        self.window!.addTabbedWindow(window, ordered: .above)
//        
//        if let splitVC = window.contentViewController as? SplitVC {
//            splitVC.setWindowIdentifier(newWindowController.windowIdentifier)
//            splitVC.resetDelegates()
//        }
//        super.newWindowForTab(sender)
//    }
    func windowDidResize(_ notification: Notification) {
        if let window = self.window {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {
                
            }
        }
    }
    func windowDidMove(_ notification: Notification) {
        if let window = self.window {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {
                
            }
        }
    }
    func windowDidBecomeKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .windowControllerBecomeKey, object: self)
    }
    func windowDidResignKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .windowControllerResignKey, object: self)
    }
    func windowDidUpdate(_ notification: Notification) {

    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {}
        }
        NotificationCenter.default.post(name: .windowControllerClose, object: self)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .sidebar, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }
}
