//
//  DetilWindow.swift
//  Data Manager
//
//  Created by Bismillah on 05/11/23.
//

import Cocoa
protocol WindowWillCloseDetailSiswa: AnyObject {
    func processDatabaseOperations(completion: @escaping () -> Void)
    func shouldAllowWindowClose() -> Bool
}
protocol DetilWindowDelegate: AnyObject {
    func detailWindowDidClose(_ window: DetilWindow)
}
class DetilWindow: NSWindowController, NSWindowDelegate {
    var windowData: WindowData?
    weak var closeWindow: DetilWindowDelegate?
    weak var closeWindowDelegate: WindowWillCloseDetailSiswa?
    
    convenience init(contentViewController: NSViewController) {
        let window = NSWindow(contentViewController: contentViewController)
        window.styleMask.insert([.fullSizeContentView, .titled])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .documentWindow
        self.init(window: window)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.delegate = self
        self.window?.identifier = NSUserInterfaceItemIdentifier("JendelaDetail")
        if let windowFrameData = UserDefaults.standard.data(forKey: "JendelaDetail") {
            do {
                windowData = try JSONDecoder().decode(WindowData.self, from: windowFrameData)
            } catch {
                
            }
        }
        
        if let windowData = windowData {
            var frame = windowData.frame
            
            if frame.size.width < 100 || frame.size.height < 100 {
                frame = NSRect(x: 910, y: 400, width: 500, height: 500)
            }
            
            if let screen = NSScreen.main {
                if frame.origin.x < 0 || frame.origin.y < 0 || frame.origin.x + frame.size.width > screen.frame.width || frame.origin.y + frame.size.height > screen.frame.height {
                    frame = NSRect(x: 910, y: 400, width: 500, height: 500)
                }
                
                self.window?.setFrame(frame, display: true)
            }
        } else {
            let defaultSize = NSSize(width: 500, height: 500)
            self.window?.setContentSize(defaultSize)
        }
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: self.window, queue: nil) { [weak self] _ in
            if let self = self, let window = self.window {
                self.windowData = WindowData(frame: window.frame, position: window.frame.origin)
                self.saveWindowData()
            }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self.window, queue: nil) { [weak self] _ in
            if let self = self, let window = self.window {
                self.windowData = WindowData(frame: window.frame, position: window.frame.origin)
                self.saveWindowData()
            }
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let delegate = closeWindowDelegate else { return true }
        if delegate.shouldAllowWindowClose() {
            return true
        } else {
            delegate.processDatabaseOperations { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            }
            return false
        }
    }
    func windowWillClose(_ notification: Notification) {
        closeWindow?.detailWindowDidClose(self)
    }
    func windowDidResignKey(_ notification: Notification) {
        NotificationCenter.default.post(name: Notification.Name("DetilWindowDidResignKey"), object: self)
    }
    func loadWindowData() -> WindowData? {
        if let windowFrameData = UserDefaults.standard.data(forKey: "JendelaDetail") {
            do {
                return try JSONDecoder().decode(WindowData.self, from: windowFrameData)
            } catch {
                #if DEBUG
                print(error.localizedDescription)
                #endif
            }
        }
        return nil
    }
    func saveWindowData() {
        do {
            let data = try JSONEncoder().encode(windowData)
            UserDefaults.standard.set(data, forKey: "JendelaDetail")
        } catch {
            #if DEBUG
            print(error.localizedDescription)
            #endif
        }
    }
    func adjustWindowPosition(baseFrame: NSRect?, offsetMultiplier: Int) {
        guard let screen = NSScreen.main else { return }

        let offset: CGFloat = 20
        var newFrame = baseFrame ?? NSRect(x: 910, y: 400, width: 500, height: 500)

        // Sesuaikan posisi berdasarkan offset multiplier
        newFrame.origin.x += CGFloat(offsetMultiplier) * offset
        newFrame.origin.y -= CGFloat(offsetMultiplier) * offset

        // Pastikan jendela tetap berada dalam batas layar
        if newFrame.origin.x + newFrame.size.width > screen.frame.width {
            newFrame.origin.x = screen.frame.width - newFrame.size.width - offset
        }
        if newFrame.origin.y < screen.frame.origin.y {
            newFrame.origin.y = screen.frame.origin.y + offset
        }

        self.window?.setFrame(newFrame, display: true)
    }


    deinit {
        #if DEBUG
        print("DetilWindowController deinit!")
        #endif
        closeWindow = nil
        closeWindowDelegate = nil
        windowData = nil
        window?.delegate = nil
        contentViewController = nil
        window = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)

    }
}

struct WindowData: Codable {
    var frame: NSRect
    var position: NSPoint
}
