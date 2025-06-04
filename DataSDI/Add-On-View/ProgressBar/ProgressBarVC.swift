//
//  ProgressBarVC.swift
//  Data SDI
//
//  Created by Bismillah on 28/12/23.
//

import Cocoa
import Foundation
class ProgressBarVC: NSViewController {
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    var controller: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(totalStudentsToUpdate)
    }
    var totalStudentsToUpdate: Int = 0 {
        didSet {
            progressIndicator.maxValue = Double(totalStudentsToUpdate)
        }
    }
    
    var currentStudentIndex: Int = 0 {
        didSet {
            DispatchQueue.main.async { [unowned self] in
                progressLabel.stringValue = "Pembaruan \(controller ?? ""): \(currentStudentIndex) daftar dari \(totalStudentsToUpdate) data"
                progressIndicator.doubleValue = Double(currentStudentIndex)
            }
        }
    }
//    func playSound() {
//        NSSound(named: NSSound.Name("Glass"))?.play()
//    }
    deinit {
        progressIndicator.removeFromSuperviewWithoutNeedingDisplay()
        progressLabel = nil
        controller = nil
    }
}

class ProgressBarWindow: NSWindowController, NSWindowDelegate {
    override func awakeFromNib() {
        super.awakeFromNib()
        self.window?.delegate = self
        if let windowFrameData = UserDefaults.standard.data(forKey: "ProgressWindowFrame"),
           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData) {
            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
            let frame = windowFrame.rectValue
            // Mengatur ulang ukuran dan posisi jendela
            self.window?.setFrame(frame, display: true)
        }
//        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self.window, queue: nil) { notification in
//            if let window = notification.object as? NSWindow {
//                let newPosition = window.frame.origin
//                do {
//                    let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(point: newPosition), requiringSecureCoding: false)
//                    UserDefaults.standard.set(data, forKey: "ProgressWindowFrame")
//                } catch {
//                    
//                }
//            }
//        }
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "ProgressWindowFrame")
            } catch {
                
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .sidebar, object: nil)
    }
}
