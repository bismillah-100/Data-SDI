//
//  AddSiswaViewController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 22/10/23.
//
import Cocoa

class AddSiswaViewController: NSViewController {
    @IBOutlet weak var tambah: NSButton!
    @IBOutlet weak var viewself: AddSiswaView!
    override func viewDidLoad() {
        view = viewself
        tambah.target = self
        tambah.action = #selector(viewself.tambahkan(_:))
    }
}

class AddSiswaView: NSView {
    @IBOutlet weak var view: AddSiswaViewController!
    @IBOutlet weak var namaTextField: NSTextField!
    @IBOutlet weak var alamatTextField: NSTextField!
    @IBOutlet weak var ttlTextField: NSTextField!
    @IBOutlet weak var tahundaftarTextField: NSTextField!
    @IBOutlet weak var namawaliTextField: NSTextField!
    @IBOutlet weak var addData: NSButton!
    @IBOutlet weak var imageView: NSImageView!
    var dbController: DB_Controller!
    var selectedImageData: Data?
    var selectedImageName: String?
    @IBOutlet weak var nis: NSTextField!
    @IBAction func tambahkan(_ sender: Any) {
        dbController = DB_Controller()

        let nama = namaTextField.stringValue.capitalizeFirstLetterOfWords()
        let alamat = alamatTextField.stringValue.capitalizeFirstLetterOfWords()
        let ttl = ttlTextField.stringValue.capitalizeFirstLetterOfWords()
        let tahundaftar = tahundaftarTextField.stringValue
        let namawali = namawaliTextField.stringValue.capitalizeFirstLetterOfWords()
        let newnis = nis.stringValue.capitalizeFirstLetterOfWords()
        dbController.addUser(namaValue: nama, alamatValue: alamat, ttlValue: ttl, tahundaftarValue: tahundaftar, namawaliValue: namawali, nisValue: newnis, jeniskelaminValue: "", statusValue: "", tanggalberhentiValue: "", kelasAktif: "", fotoPath: selectedImageData ?? Data())
    }

    @IBAction func pilihFoto(_ sender: Any) {}

    override func awakeFromNib() {
        super.awakeFromNib()
        // Enable layer in self view.
        wantsLayer = true

        registerForDraggedTypes([.fileURL])
    }
}

extension AddSiswaView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canReadPasteboardObjects = sender.draggingPasteboard.canReadObject(forClasses: [NSImage.self, NSColor.self, NSString.self, NSURL.self])
        if canReadPasteboardObjects {
            return .copy
        }
        return NSDragOperation()
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Berikan respons terhadap pembaruan operasi seret-dan-lepas
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let imageURL = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL else {
            // Tidak dapat membaca URL dari clipboard

            return false
        }

        do {
            let imageData = try Data(contentsOf: imageURL)

            // Mendapatkan nama file dari URL
            selectedImageName = imageURL.lastPathComponent
            selectedImageData = imageData
        } catch {
            return false
        }
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        unhighlight()
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        unhighlight()
    }

    func highlight() {
        if #available(OSX 10.14, *) {
            self.layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            // Fallback on earlier versions
        }
        layer?.borderWidth = 2.0
    }

    func unhighlight() {
        layer?.borderColor = NSColor.clear.cgColor
        layer?.borderWidth = 0.0
    }
}

extension AddSiswaView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        guard let imageURL = sender?.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL else {
            // Tidak dapat membaca URL dari clipboard

            return
        }

        do {
            let imageData = try Data(contentsOf: imageURL)

        } catch {}
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {}

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {}

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {}

    override func mouseDragged(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        let pdfData = dataWithPDF(inside: bounds)
        let imageFromPDF = NSImage(data: pdfData)
        draggingItem.setDraggingFrame(bounds, contents: imageFromPDF)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}
