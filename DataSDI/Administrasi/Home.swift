//
//  Home.swift
//  Administrasi
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa

class TransaksiView: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    @IBOutlet var hapus: NSButton!
    @IBOutlet var collectionView: NSCollectionView!
    var data: [Entity] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        collectionView.dataSource = self
        collectionView.delegate = self
        data = DataManager.shared.fetchData()

        collectionView.reloadData()
        NotificationCenter.default.removeObserver(self, name: DataManager.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(perbaruiData), name: DataManager.dataDidChangeNotification, object: nil)
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClickGesture)
    }

    @objc func handleDoubleClick(_ gesture: NSGestureRecognizer) {
        if gesture.state == .ended {
            // Dapatkan posisi klik
            let location = gesture.location(in: collectionView)

            // Dapatkan indeks item yang diklik
            if let indexPath = collectionView.indexPathForItem(at: location) {
                // Dapatkan data yang terkait dengan item yang diklik
                let selectedEntity = data[indexPath.item]

                // Membuat instance dari EditViewController
                let editViewController = EditTransaksi(nibName: "EditTransaksi", bundle: nil)

                // Set nilai editedEntity
                editViewController.editedEntity = selectedEntity

                // Menampilkan view controller sebagai sheet
                presentAsSheet(editViewController)
            }
        }
    }

    @objc func perbaruiData() {
        DispatchQueue.main.async {
            self.data = DataManager.shared.fetchData()
            self.collectionView.reloadData()
        }
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        data.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("MyCollectionViewItem"), for: indexPath)

        // Set values of the collection view item attributes based on Core Data
        if let customItem = item as? MyCollectionViewItem {
            let entity = data[indexPath.item]

            customItem.mytextField?.stringValue = entity.jenis ?? ""
            customItem.jumlah?.stringValue = entity.jumlah ?? ""
            customItem.kategori?.stringValue = entity.kategori ?? ""
            customItem.acara?.stringValue = entity.acara ?? ""
            customItem.keperluan?.stringValue = entity.keperluan ?? ""

            if let tanggalDate = entity.tanggal {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd-MM-yyyy" // Set your desired date format
                customItem.tanggal?.stringValue = dateFormatter.string(from: tanggalDate)
            } else {
                customItem.tanggal?.stringValue = ""
            }
        }
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        indexPaths
    }

    func collectionViewSelectionDidChange(_ notification: Notification) {}

    @IBAction func hapusitem(_ sender: NSButton) {
        let selectedIndexes = collectionView.selectionIndexPaths.sorted(by: { $0.item > $1.item }).map(\.item)

        for index in selectedIndexes {
            // Hapus item dari data
            data.remove(at: index)

            // Hapus item dari Core Data
            let context = DataManager.shared.managedObjectContext
            let entityToDelete = DataManager.shared.fetchData()[index]
            context.delete(entityToDelete)

            do {
                // Simpan perubahan ke Core Data
                try context.save()
            } catch {
                // Handle error during Core Data save
            }
        }

        // Perbarui tampilan koleksi setelah menghapus item
        collectionView.deleteItems(at: Set(selectedIndexes.map { IndexPath(item: $0, section: 0) }))
    }

    @objc func deleteSelectedItem(_ sender: Any?) {
        // Pastikan sender adalah instance dari MyCollectionViewItem
        guard let item = sender as? MyCollectionViewItem else {
            return
        }

        // Dapatkan indeks item yang akan dihapus
        if let index = collectionView.indexPath(for: item) {
            // Hapus item dari data
            data.remove(at: index.item)

            // Hapus item dari Core Data
            // ... (Anda perlu menyesuaikan ini sesuai dengan struktur Core Data Anda)

            // Perbarui tampilan koleksi setelah menghapus item
            collectionView.deleteItems(at: [index])
        }
    }
}
