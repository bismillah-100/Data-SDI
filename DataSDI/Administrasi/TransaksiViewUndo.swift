//
//  TransaksiViewUndo.swift
//  Data SDI
//
//  Created by Bismillah on 04/11/24.
//

typealias ProcessDeleteTransaksi = (dataToDelete: [Entity], snapshots: [EntitySnapshot], indexPaths: [IndexPath])
typealias DeleteTransaksiItems = (sectionsToDelete: IndexSet, editedSections: Set<IndexPath>)

extension TransaksiView {
    private func saveContext() {
        context.performAndWait {
            do {
                try DataManager.shared.managedObjectContext.save()
            } catch {
                ReusableFunc.showAlert(
                    title: "Error saat menyimpan data administrasi.",
                    message: "Terjadi kesalahan yang tidak terduga."
                )
            }
        }
    }

    private func deleteContext(_ entities: [Entity]) {
        context.performAndWait {
            for item in entities {
                DataManager.shared.managedObjectContext.delete(item)
            }
        }
    }

    // MARK: - UNDO ADD ITEM

    /// Mengembalikan tindakan penambahan item sebelumnya ke `collectionView` dan Core Data,
    /// sebagai bagian dari fitur *undo*. Fungsi ini menghapus item yang baru ditambahkan
    /// dari tampilan dan penyimpanan data.
    ///
    /// - Parameter snapshot: Sebuah `EntitySnapshot` yang berisi data dari item
    ///   yang sebelumnya ditambahkan, termasuk ID-nya, yang diperlukan untuk
    ///   mengidentifikasi dan menghapus item tersebut.
    func undoAddItem(_ snapshot: EntitySnapshot) {
        var dataToDelete: [Entity] = [] // Array untuk menyimpan entitas yang akan dihapus dari Core Data.

        // Pastikan item yang akan di-undo masih ada di DataManager. Jika tidak, keluar dari fungsi.
        guard let newItem = DataManager.shared.fetchData(by: snapshot.id!) else {
            return
        }

        // Batalkan semua pilihan di collectionView sebelum melakukan pembaruan.
        collectionView.deselectAll(nil)

        // Gunakan DispatchGroup untuk melacak selesainya operasi animasi dan pembaruan data.
        let animationGroup = DispatchGroup()
        animationGroup.enter() // Beri tahu group bahwa sebuah operasi akan dimulai.

        // Jalankan grup animasi untuk pembaruan tampilan dengan kontrol konteks animasi.
        NSAnimationContext.runAnimationGroup({ [unowned self] context in
            context.allowsImplicitAnimation = false // Nonaktifkan animasi implisit untuk kontrol lebih baik.

            // Lakukan pembaruan batch pada `collectionView` untuk animasi penghapusan item.
            collectionView.performBatchUpdates({ [unowned self] in
                if isGrouped {
                    // MARK: - Penanganan untuk Mode Dikelompokkan

                    // Dapatkan kunci grup untuk item yang akan dihapus.
                    guard let groupKey = getEntityGroupKey(for: newItem) else { return }
                    // Dapatkan kunci grup yang diurutkan untuk mengakses data.
                    let sortedKeys = sectionKeys

                    // Cari indeks section dan item dari `newItem` di dalam `groupedData`.
                    if let groupKeyIndex = sortedKeys.firstIndex(of: groupKey),
                       var itemsInSection = groupedData[sortedKeys[groupKeyIndex]],
                       let itemIndex = itemsInSection.firstIndex(where: { $0.id == newItem.id })
                    {
                        // Tambahkan item ke array `dataToDelete` agar bisa dihapus dari Core Data nanti.
                        let itemToDelete = itemsInSection[itemIndex]
                        dataToDelete.append(itemToDelete)

                        // Pilih item yang akan dihapus untuk memberikan *feedback* visual sesaat sebelum dihapus.
                        collectionView.selectItems(at: Set([IndexPath(item: itemIndex, section: groupKeyIndex)]), scrollPosition: .centeredVertically)

                        // Hapus item dari model data yang dikelompokkan (`groupedData`).
                        itemsInSection.remove(at: itemIndex)
                        // Perbarui grup; jika kosong, setel menjadi `nil` untuk menghapus grup.
                        groupedData[sortedKeys[groupKeyIndex]] = itemsInSection.isEmpty ? nil : itemsInSection

                        // Perbarui tampilan `collectionView` dengan menghapus item secara visual.
                        collectionView.deleteItems(at: [IndexPath(item: itemIndex, section: groupKeyIndex)])
                        // Pilih item berikutnya setelah penghapusan (jika ada) untuk mempertahankan fokus.
                        selectNextItem(afterDeletingFrom: [IndexPath(item: itemIndex, section: groupKeyIndex)])

                        // Jika section menjadi kosong setelah penghapusan item terakhir di dalamnya:
                        if itemsInSection.isEmpty {
                            groupedData.removeValue(forKey: sortedKeys[groupKeyIndex]) // Hapus entri grup dari `groupedData`.
                            sectionKeys.removeAll(where: { $0 == groupKey }) // Hapus kunci dari daftar kunci section.
                            collectionView.deleteSections(IndexSet(integer: groupKeyIndex)) // Hapus section dari tampilan.
                        } else {
                            // Jika section tidak kosong, perbarui total jumlah yang ditampilkan di header section.
                            let sectionIndices = IndexPath(item: 0, section: groupKeyIndex)
                            updateTotalAmountsForSection(at: sectionIndices)
                        }
                    } else {
                        return // Item tidak ditemukan dalam grup, keluar dari blok.
                    }
                } else {
                    // MARK: - Penanganan untuk Mode Tidak Dikelompokkan

                    // Cari indeks item di array `data` utama (mode tidak dikelompokkan).
                    if let itemIndex = data.firstIndex(where: { $0.id == newItem.id }) {
                        // Tambahkan item ke array `dataToDelete`.
                        let itemToDelete = data[itemIndex]
                        dataToDelete.append(itemToDelete)
                        // Hapus item dari model data tidak dikelompokkan (`data`).
                        data.remove(at: itemIndex)
                        // Perbarui tampilan `collectionView` dengan menghapus item.
                        collectionView.deleteItems(at: [IndexPath(item: itemIndex, section: 0)])
                        // Pilih item berikutnya setelah penghapusan.
                        selectNextItem(afterDeletingFrom: [IndexPath(item: itemIndex, section: 0)])
                    } else {
                        dataToDelete.append(newItem)
                    }
                }
            }, completionHandler: { [weak self] _ in
                // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                guard let self else { return }
                if isGrouped {
                    // Jika dalam mode dikelompokkan, *invalidate* layout untuk memastikan pembaruan yang tepat.
                    flowLayout.invalidateLayout()
                }
            })
            // Kirim notifikasi bahwa data telah dihapus, dengan menyertakan entitas yang dihapus.
            NotificationCenter.default.post(name: DataManager.dataDihapusNotif, object: nil, userInfo: ["deletedEntity": [snapshot]])
        }, completionHandler: { [unowned self] in
            // MARK: - Pembaruan Data dan UndoManager Setelah Animasi

            // Hapus entitas yang telah ditandai dari Core Data context.
            deleteContext(dataToDelete)

            // Simpan perubahan ke Core Data secara permanen.
            saveContext()

            // Perbarui tampilan header section jika dalam mode dikelompokkan.
            if isGrouped {
                createLineAtTopSection()
            }
            animationGroup.leave() // Beri tahu group bahwa operasi telah selesai.
        })

        // Daftarkan operasi 'redo' ke `myUndoManager`.
        // Ketika 'redo' dipicu, `redoAddItem` akan dipanggil dengan snapshot yang sama
        // untuk mengembalikan item yang baru saja di-undo.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard self == self else { return } // Pastikan self masih ada.
            self?.redoAddItem(snapshot)
        })
    }

    /// Mengembalikan (redo) tindakan penambahan item yang sebelumnya di-undo.
    /// Fungsi ini menambahkan kembali item ke Core Data berdasarkan `EntitySnapshot` yang diberikan,
    /// lalu memperbarui tampilan `collectionView`.
    ///
    /// - Parameter snapshot: Sebuah `EntitySnapshot` yang berisi data lengkap dari item
    ///   yang akan ditambahkan kembali.
    func redoAddItem(_ snapshot: EntitySnapshot) {
        // Pastikan nilai 'jumlah' (amount) dalam snapshot tidak nol.
        // Jika nol, tidak ada item yang perlu ditambahkan, jadi keluar dari fungsi.
        guard snapshot.jumlah != 0 else { return }

        undoHapus([snapshot])

        // Panggil `checkForDuplicateID` untuk memeriksa apakah ada UUID yang sama.
        checkForDuplicateID(NSMenuItem())
    }

    // MARK: - UNDOHAPUS

    /// Menghapus entitas dari model dan collection view secara deterministik.
    ///
    /// Operasi ini melakukan langkah berikut, secara berurutan:
    /// 1. Mengumpulkan snapshot dari setiap ``Entity`` yang akan dihapus.
    /// 2. Menghitung `IndexPath` target berdasarkan snapshot awal tanpa memodifikasi model.
    /// 3. Men-sort `IndexPath` secara descending untuk mencegah index shift saat mutasi.
    /// 4. Memodifikasi model (``groupedData`` atau ``data``) berdasarkan `IndexPath` yang sudah ditentukan.
    /// 5. Melakukan `collectionView.performBatchUpdates` untuk menghapus item dan section secara atomik.
    /// 6. Memperbarui header/total section yang teredit.
    /// 7. Menghapus objek dari Core Data dan menyimpan context dalam `context.performAndWait`.
    /// 8. Mendaftarkan aksi undo yang memanggil ``undoHapus(_:)``.
    ///
    /// - Important:
    ///   - Harus dipanggil dari main thread.
    ///   - `entities` sebaiknya berisi entitas unik (tidak ada duplikat `id`).
    ///   - Fungsi ini mengubah ``groupedData``, ``sectionKeys``, ``sectionTotals``, dan ``data``.
    ///   - Fungsi akan mem-post NotificationCenter dengan nama ``DataManager/dataDihapusNotif``.
    ///
    /// - Parameter entities: Array `Entity` yang akan dihapus. Untuk penghapusan dari selection gunakan bentuk `IndexPath` caller.
    /// - Complexity: O(n log n) dominan oleh sorting indexPath dan pencarian index per entity.
    /// - Side effects:
    ///   - Memodifikasi model data in-memory.
    ///   - Memanggil `collectionView.deleteItems` dan `collectionView.deleteSections`.
    ///   - Menyimpan perubahan ke Core Data.
    ///   - Mendaftarkan undo yang memulihkan snapshot.
    func performDeletion(_ entities: [Entity]) {
        guard !entities.isEmpty else { return }

        collectionView.deselectAll(self)

        // 1) Kumpulkan indexPath & dataToDelete dari snapshot (tanpa mutasi)
        let (dataToDelete, prevSnapshots, indexPathsToDelete) = gatherDataToDelete(entities: entities)

        guard !indexPathsToDelete.isEmpty else { return }

        // 2) Mutasi model berdasarkan indexPaths yang sudah pasti
        let (sectionsToDelete, editedSections) = deleteItems(at: indexPathsToDelete)

        sectionKeys = groupedData.keys.sorted()

        // 3) UI batch delete
        deleteCollectionViewItems(
            indexPathsToDelete,
            sectionsToDelete: sectionsToDelete,
            editedSections: editedSections,
            deletedEntities: dataToDelete,
            snapshotEntities: prevSnapshots
        )
    }

    /// Mengumpulkan data yang akan dihapus beserta snapshot dan indexPath-nya.
    ///
    /// Fungsi ini tidak memodifikasi model data, hanya membaca state saat ini untuk:
    /// - Membuat snapshot dari setiap entitas yang akan dihapus
    /// - Menentukan `IndexPath` untuk setiap entitas dalam ``groupedData`` atau ``data``
    /// - Mengumpulkan entitas yang valid untuk dihapus
    ///
    /// Fungsi ini melakukan pencarian linear pada array item di setiap section (untuk mode grouped)
    /// atau pada ``data`` (untuk mode flat) menggunakan ID entitas.
    ///
    /// - Parameter entities: Array entitas yang akan dihapus.
    /// - Returns: Tuple berisi:
    ///   - `dataToDelete`: Array entitas yang ditemukan dalam model dan siap dihapus
    ///   - `prevSnapshots`: Array snapshot dari entitas sebelum penghapusan
    ///   - `indexPathsToDelete`: Array `IndexPath` yang menunjukkan lokasi entitas dalam collection view
    ///
    /// - Complexity: O(s × m + n) dimana:
    ///   - s = jumlah sections (atau 1 jika ungrouped)
    ///   - m = rata-rata items per section
    ///   - n = jumlah entitas yang akan dihapus
    ///   Build index map sekali: O(s × m), kemudian O(1) lookup per entity: O(n)
    /// - Note: Menggunakan snapshot state ``sectionKeys`` dan ``groupedData`` sebelum mutasi untuk memastikan konsistensi.
    func gatherDataToDelete(entities: [Entity]) -> ProcessDeleteTransaksi {
        var prevSnapshots: [EntitySnapshot] = []
        var dataToDelete: [Entity] = []
        let sectionKeysBefore = sectionKeys
        let groupedBefore = groupedData
        var indexPathsToDelete: [IndexPath] = []

        // build index map per section: [sectionIndex: [entityId: [indices]]]
        var indexMapBySection: [Int: [UUID: [Int]]] = [:]

        if isGrouped {
            for (sectionIndex, key) in sectionKeysBefore.enumerated() {
                guard let items = groupedBefore[key] else { continue }
                var map: [UUID: [Int]] = [:]
                for (i, item) in items.enumerated() {
                    guard let itemId = item.id else { continue } // unwrap here
                    map[itemId, default: []].append(i)
                }
                indexMapBySection[sectionIndex] = map
            }
        } else {
            // ungrouped: map id -> [indices]
            var map: [UUID: [Int]] = [:]
            for (i, item) in data.enumerated() {
                guard let itemId = item.id else { continue } // unwrap here
                map[itemId, default: []].append(i)
            }
            indexMapBySection[0] = map
        }

        for entity in entities {
            prevSnapshots.append(createSnapshot(from: entity))

            guard let entityId = entity.id else { continue } // unwrap entity.id

            if isGrouped {
                guard let groupKey = getEntityGroupKey(for: entity),
                      let sectionIndex = sectionKeysBefore.lastIndex(of: groupKey),
                      var map = indexMapBySection[sectionIndex],
                      var list = map[entityId], // use unwrapped entityId
                      !list.isEmpty
                else { continue }

                let itemIndex = list.removeLast()
                map[entityId] = list
                indexMapBySection[sectionIndex] = map

                indexPathsToDelete.append(IndexPath(item: itemIndex, section: sectionIndex))
                dataToDelete.append(entity)
            } else {
                guard var map = indexMapBySection[0],
                      var list = map[entityId], // use unwrapped entityId
                      !list.isEmpty
                else { continue }

                let itemIndex = list.removeLast()
                map[entityId] = list
                indexMapBySection[0] = map

                indexPathsToDelete.append(IndexPath(item: itemIndex, section: 0))
                dataToDelete.append(entity)
            }
        }

        return (dataToDelete, prevSnapshots, indexPathsToDelete)
    }

    /// Menghapus item dari model data berdasarkan array `IndexPath`.
    ///
    /// Fungsi ini memodifikasi ``groupedData`` dan ``data`` dengan cara:
    /// 1. Men-sort `IndexPath` secara descending (section tertinggi dulu, item tertinggi dulu dalam section yang sama)
    /// 2. Menghapus item satu per satu dari belakang untuk mencegah index shift
    /// 3. Menghapus section kosong dari ``groupedData``, ``sectionKeys``, ``sectionTotals``, dan ``collapsedSections``
    /// 4. Mencatat section yang masih ada item namun total-nya perlu diperbarui
    ///
    /// - Parameter indexPaths: Array `IndexPath` yang menunjukkan posisi item yang akan dihapus.
    /// - Returns: Tuple berisi:
    ///   - `sectionsToDelete`: `IndexSet` berisi index section yang kosong dan harus dihapus dari UI
    ///   - `editedSections`: `Set<IndexPath>` berisi section yang itemnya berkurang namun tidak kosong
    ///
    /// - Important:
    ///   - Memodifikasi ``groupedData``, ``sectionKeys``, ``sectionTotals``, ``collapsedSections``, dan ``data``.
    ///   - Sorting descending sangat penting untuk mencegah index shifting.
    ///
    /// - Complexity: O(n log n) untuk sorting + O(n) untuk iterasi penghapusan.
    /// - Side effects: Mengubah state model data secara langsung.
    func deleteItems(at indexPaths: [IndexPath]) -> DeleteTransaksiItems {
        var sectionsToDelete = IndexSet()
        var editedSections = Set<IndexPath>()

        let sortedIndexes = indexPaths.sorted {
            if $0.section == $1.section {
                return $0.item > $1.item
            }
            return $0.section > $1.section
        }

        for ip in sortedIndexes {
            if isGrouped {
                guard ip.section < sectionKeys.count else { continue }
                let key = sectionKeys[ip.section]
                guard var items = groupedData[key], ip.item < items.count else { continue }

                items.remove(at: ip.item)
                if items.isEmpty {
                    groupedData.removeValue(forKey: key)
                    sectionKeys.removeAll(where: { $0 == key })
                    sectionTotals.removeValue(forKey: key)
                    collapsedSections.remove(ip.section)
                    sectionsToDelete.insert(ip.section)
                } else {
                    groupedData[key] = items
                    editedSections.insert(IndexPath(item: 0, section: ip.section))
                }
            } else {
                if ip.item < data.count {
                    data.remove(at: ip.item)
                }
            }
        }
        return (sectionsToDelete, editedSections)
    }

    /// Melakukan penghapusan item dan section dari collection view secara atomik.
    ///
    /// Fungsi ini mengatur UI updates, persistence ke Core Data, dan undo registration:
    /// 1. Memanggil `collectionView.performBatchUpdates` untuk menghapus item dan section
    /// 2. Memilih item berikutnya setelah penghapusan (jika ada)
    /// 3. Invalidate layout dan recreate section lines untuk mode grouped
    /// 4. Memperbarui total amounts untuk section yang teredit
    /// 5. Post notification ``DataManager/dataDihapusNotif`` dengan snapshot entitas
    /// 6. Menghapus entitas dari Core Data context dan menyimpan perubahan
    /// 7. Mendaftarkan undo action yang akan memanggil ``undoHapus(_:)``
    ///
    /// - Parameters:
    ///   - indexPaths: Array `IndexPath` yang akan dihapus dari collection view.
    ///   - sectionsToDelete: `IndexSet` berisi index section yang akan dihapus.
    ///   - editedSections: `Set` berisi section yang total-nya perlu diperbarui.
    ///   - deletedEntities: Array entitas yang akan dihapus dari Core Data.
    ///   - snapshotEntities: Array snapshot untuk undo operation dan notification.
    ///   - registerUndo: Flag untuk mengaktifkan/menonaktifkan undo registration. Default: `true`.
    ///   - completion: Closure opsional yang dipanggil setelah batch updates selesai.
    ///
    /// - Important:
    ///   - Harus dipanggil dari main thread karena mengakses UIKit.
    ///   - Memodifikasi Core Data context dan menyimpan perubahan.
    ///   - Mem-post notification yang dapat diobserve oleh komponen lain.
    ///
    /// - Complexity: O(n) untuk deletion + O(s) untuk section updates dimana s adalah jumlah edited sections.
    /// - Side effects:
    ///   - Mengupdate collection view UI
    ///   - Menghapus dan menyimpan Core Data
    ///   - Post notification
    ///   - Mendaftarkan undo action
    func deleteCollectionViewItems(
        _ indexPaths: [IndexPath],
        sectionsToDelete: IndexSet,
        editedSections: Set<IndexPath>,
        deletedEntities: [Entity],
        snapshotEntities: [EntitySnapshot],
        registerUndo: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        collectionView.performBatchUpdates({
            collectionView.deleteItems(at: Set(indexPaths))
            if !sectionsToDelete.isEmpty { collectionView.deleteSections(sectionsToDelete) }
            selectNextItem(afterDeletingFrom: indexPaths)
        }, completionHandler: { [weak self] finished in
            guard let self, finished else { return }

            if isGrouped {
                flowLayout.invalidateLayout()
                createLineAtTopSection()
                collapsedSections.forEach { self.flowLayout.collapseSection(at: $0) }
            }

            editedSections.forEach { self.updateTotalAmountsForSection(at: $0) }

            NotificationCenter.default.post(
                name: DataManager.dataDihapusNotif,
                object: nil,
                userInfo: ["deletedEntity": snapshotEntities]
            )

            deleteContext(deletedEntities)

            saveContext()

            completion?()

            guard registerUndo else { return }
            myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                self?.undoHapus(snapshotEntities)
            }
        })
    }

    /// Mengembalikan (redo) tindakan penghapusan satu atau beberapa item yang sebelumnya di-undo.
    /// Fungsi ini menghapus kembali item-item dari `collectionView` dan Core Data
    /// yang sebelumnya sudah ditambahkan kembali melalui fungsi `undoHapus`.
    ///
    /// - Parameter data: Sebuah array dari objek `Entity` yang mewakili item-item
    ///   yang akan dihapus kembali.
    func redoHapus(_ data: [Entity]) {
        performDeletion(data)
    }

    /// Mengembalikan (undo) tindakan penghapusan item yang sebelumnya dilakukan.
    /// Fungsi ini akan membuat kembali item-item yang telah dihapus dan menampilkannya kembali
    /// di `collectionView` dan menyimpannya di Core Data.
    ///
    /// - Parameter snapshot: Sebuah array dari `EntitySnapshot` yang berisi data
    ///   dari item-item yang sebelumnya dihapus dan perlu dikembalikan.
    func undoHapus(_ snapshots: [EntitySnapshot]) {
        guard !snapshots.isEmpty else { return }
        // Batalkan semua pilihan di `collectionView`.
        collectionView.deselectAll(nil)

        // Array untuk menyimpan entitas yang baru dibuat kembali.
        var prevData: [Entity] = []

        context.performAndWait {
            for snapshot in snapshots {
                let newItem = Entity(context: context)
                // Isi properti `newItem` dengan data dari `snapshot`.
                newItem.id = snapshot.id
                newItem.jenis = snapshot.jenis
                newItem.jumlah = snapshot.jumlah
                newItem.kategori = snapshot.kategori
                newItem.acara = snapshot.acara
                newItem.keperluan = snapshot.keperluan
                newItem.tanggal = snapshot.tanggal
                newItem.bulan = snapshot.bulan ?? 1 // Beri nilai default jika nil.
                newItem.tahun = snapshot.tahun ?? 2024 // Beri nilai default jika nil.
                newItem.ditandai = snapshot.ditandai ?? false // Beri nilai default jika nil.

                prevData.append(newItem) // Tambahkan item yang baru dibuat ke `prevData`.
            }

            saveContext()
        }

        // ✅ PERBAIKAN: Tracking section yang sudah ada SEBELUM insert
        var existingSectionsBeforeInsert: Set<String> = []
        var newSectionKeys: Set<String> = [] // Track section baru berdasarkan key

        if isGrouped {
            existingSectionsBeforeInsert = Set(groupedData.keys)
        }

        // ✅ FASE 1: Update data source dan track section baru berdasarkan KEY
        for newItem in prevData {
            if isGrouped {
                guard let groupKey = getEntityGroupKey(for: newItem) else { continue }
                let isExist = existingSectionsBeforeInsert.contains(groupKey)

                // Update data source
                if isExist, var sectionData = groupedData[groupKey] {
                    let itemIndex = insertionIndex(for: newItem, in: sectionData)
                    sectionData.insert(newItem, at: itemIndex)
                    groupedData[groupKey] = sectionData
                } else {
                    // Section baru
                    if groupedData[groupKey] == nil {
                        groupedData[groupKey] = []
                        newSectionKeys.insert(groupKey) // ✅ Track KEY, bukan index
                    }
                    let insertIndex = insertionIndex(for: newItem, in: groupedData[groupKey]!)
                    groupedData[groupKey]?.insert(newItem, at: insertIndex)
                }
            } else {
                let index = insertionIndex(for: newItem)
                data.insert(newItem, at: index)
            }
        }

        // ✅ FASE 3: Convert section KEYS menjadi INDEXES setelah sort final
        var insertedSections: IndexSet = []
        sectionKeys = groupedData.keys.sorted()
        if isGrouped {
            for sectionKey in newSectionKeys {
                if let sectionIndex = sectionKeys.firstIndex(of: sectionKey) {
                    insertedSections.insert(sectionIndex)
                }
            }
        }

        // ✅ FASE 4: Hitung IndexPath SETELAH data source final
        var insertedItems: Set<IndexPath> = []

        for snapshot in prevData {
            if isGrouped {
                guard let groupKey = getEntityGroupKey(for: snapshot) else { continue }
                guard let sectionData = groupedData[groupKey] else { continue }
                guard let sectionIndex = sectionKeys.firstIndex(of: groupKey) else { continue }

                // Cari item berdasarkan ID
                if let itemIndex = sectionData.firstIndex(where: { $0.id == snapshot.id }) {
                    let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                    insertedItems.insert(indexPath)
                }
            } else {
                if let itemIndex = data.firstIndex(where: { $0.id == snapshot.id }) {
                    let indexPath = IndexPath(item: itemIndex, section: 0)
                    insertedItems.insert(indexPath)
                }
            }
        }

        // ✅ FASE 5: Lakukan UI update dalam satu batch
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }

            // Insert sections dulu
            if !insertedSections.isEmpty {
                collectionView.insertSections(insertedSections)
            }

            // Kemudian insert items
            if !insertedItems.isEmpty {
                collectionView.insertItems(at: insertedItems)
            }
        } completionHandler: { [weak self] finished in
            guard let self, finished else { return }

            if isGrouped {
                createLineAtTopSection()
                flowLayout.invalidateLayout()
                // Update total amounts untuk sections yang terpengaruh
                let affectedSections = insertedItems.map(\.section)
                for sectionIndex in affectedSections {
                    let sectionIndexPath = IndexPath(item: 0, section: sectionIndex)
                    updateTotalAmountsForSection(at: sectionIndexPath)
                }
            }

            // Register undo
            myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                guard let self else { return }
                redoHapus(prevData)
            }

            // Post notifications
            for d in prevData {
                NotificationCenter.default.post(
                    name: DataManager.dataDitambahNotif,
                    object: nil,
                    userInfo: ["data": d]
                )
            }

            // Select last inserted item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                collectionView.selectItems(at: insertedItems, scrollPosition: .centeredVertically)
                collectionView(collectionView, didSelectItemsAt: insertedItems)
            }
        }
    }

    /// Membuat salinan data dengan struktur ``DataSDI/EntitySnapshot`` sebelum diperbarui/dihapus.
    ///
    /// - Parameter entity: Data yang akan dibuat salinan.
    /// - Returns: Data yang telah disalin menggunakan struktur ``DataSDI/EntitySnapshot``.
    func createSnapshot(from entity: Entity) -> EntitySnapshot {
        EntitySnapshot(
            id: entity.id,
            jenis: entity.jenis,
            dari: entity.dari,
            jumlah: entity.jumlah,
            kategori: entity.kategori,
            acara: entity.acara,
            keperluan: entity.keperluan,
            tanggal: entity.tanggal,
            bulan: entity.bulan,
            tahun: entity.tahun,
            ditandai: entity.ditandai
        )
    }

    // MARK: - UNDOEDIT

    /// Mengembalikan (undo) tindakan pengeditan item-item yang sebelumnya dilakukan.
    /// Fungsi ini mengambil data backup dari item-item sebelum diedit, lalu mengembalikan
    /// properti item-item tersebut ke kondisi sebelumnya di Core Data.
    ///
    /// - Parameter entityBackup: Sebuah array `EntitySnapshot` yang berisi data
    ///   dari item-item **sebelum** diedit (kondisi yang ingin dikembalikan).
    func undoEdit(_ entityBackup: [EntitySnapshot]) {
        // Set untuk menyimpan UUID dari entitas yang telah di-undo (dikembalikan ke kondisi sebelumnya).
        var updatedEntityIDs: Set<UUID> = []
        // Array untuk menyimpan snapshot dari data *saat ini* sebelum di-undo.
        // Ini akan menjadi "prevData" untuk operasi redo (mengembalikan ke kondisi setelah edit).
        var currentSnapshotsBeforeUndo: [EntitySnapshot] = []

        // Iterasi melalui setiap snapshot di `entityBackup`. Setiap snapshot mewakili
        // kondisi sebuah entitas sebelum pengeditan yang di-undo.
        context.performAndWait { [weak self] in
            guard let self else { return }
            for snapshotToRestore in entityBackup {
                // Cari entitas yang sesuai di Core Data berdasarkan ID dari snapshot.
                if let entity = DataManager.shared.fetchData(by: snapshotToRestore.id ?? UUID()) {
                    // Ambil snapshot dari kondisi *saat ini* (setelah pengeditan yang akan di-undo).
                    // Snapshot ini akan menjadi `prevData` untuk operasi redo.
                    let currentSnapshot = createSnapshot(from: entity)
                    currentSnapshotsBeforeUndo.append(currentSnapshot)

                    // Perbarui entitas di Core Data kembali ke kondisi yang ada di `snapshotToRestore`.
                    DataManager.shared.editData(
                        entity: entity,
                        jenis: snapshotToRestore.jenis, // Gunakan jenis dari snapshot.
                        dari: snapshotToRestore.dari ?? "", // Gunakan dari dari snapshot.
                        jumlah: snapshotToRestore.jumlah, // Gunakan jumlah dari snapshot.
                        kategori: snapshotToRestore.kategori?.value ?? "tanpa kategori", // Gunakan kategori dari snapshot.
                        acara: snapshotToRestore.acara?.value ?? "tanpa acara", // Gunakan acara dari snapshot.
                        keperluan: snapshotToRestore.keperluan?.value ?? "tanpa keperluan", // Gunakan keperluan dari snapshot.
                        tanggal: snapshotToRestore.tanggal ?? Date(), // Gunakan tanggal dari snapshot.
                        bulan: snapshotToRestore.bulan ?? 1, // Gunakan bulan dari snapshot.
                        tahun: snapshotToRestore.tahun ?? 2024, // Gunakan tahun dari snapshot.
                        tanda: snapshotToRestore.ditandai ?? false // Gunakan tanda dari snapshot.
                    )

                    // Tambahkan ID entitas yang baru saja di-undo ke set `updatedEntityIDs`.
                    updatedEntityIDs.insert(snapshotToRestore.id ?? UUID())
                }
            }
        }

        // Kirim notifikasi bahwa data telah diedit.
        // Informasi yang disertakan adalah UUID dari entitas yang diubah
        // dan `currentSnapshotsBeforeUndo` yang berisi kondisi item sebelum `undoEdit` dipanggil.
        NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: ["uuid": updatedEntityIDs, "entiti": currentSnapshotsBeforeUndo])
    }

    /// Memperbarui tampilan `collectionView` setelah item-item diedit.
    /// Fungsi ini menangani pembaruan baik dalam mode dikelompokkan (grouped) maupun tidak dikelompokkan (non-grouped),
    /// termasuk perubahan grup (section) jika ada properti yang relevan dengan pengelompokan diubah.
    ///
    /// - Parameters:
    ///   - ids: `Set` dari `UUID` yang berisi ID dari entitas-entitas yang telah diedit.
    ///   - prevData: Array ``DataSDI/EntitySnapshot`` yang berisi data dari entitas-entitas
    ///     **sebelum** pengeditan terjadi. Ini penting untuk membandingkan perubahan
    ///     dan menentukan apakah item berpindah grup.
    func updateItem(ids: Set<UUID>, prevData: [EntitySnapshot]) {
        // ✅ FASE 1: Analisis - Kumpulkan semua perubahan yang perlu dilakukan
        struct ItemChange {
            let entity: Entity
            let oldGroupKey: String
            let newGroupKey: String
            let oldIndexPath: IndexPath
            let changeType: ChangeType

            enum ChangeType {
                case reload // Item tidak pindah section, hanya reload
                case move // Item pindah section
            }
        }

        var changes: [ItemChange] = []
        var sectionsToDelete: Set<String> = []
        var sectionsToCreate: Set<String> = []
        let existingSectionsBeforeUpdate = Set(groupedData.keys)

        // Collect all changes
        if isGrouped {
            for (sectionIndex, sectionKey) in sectionKeys.enumerated() {
                guard let items = groupedData[sectionKey] else { continue }

                for (itemIndex, entity) in items.enumerated() {
                    guard let entityId = entity.id, ids.contains(entityId) else { continue }
                    guard let snapshot = prevData.first(where: { $0.id == entityId }) else { continue }

                    // Skip jika data tidak berubah
                    if snapshot == entity {
                        continue
                    }

                    let oldGroupKey = getGroupKey(for: snapshot) ?? "Lainnya"
                    let newGroupKey = getEntityGroupKey(for: entity) ?? "Lainnya"
                    let oldIndexPath = IndexPath(item: itemIndex, section: sectionIndex)

                    if oldGroupKey == newGroupKey {
                        // Item tetap di section yang sama, cukup reload
                        changes.append(ItemChange(
                            entity: entity,
                            oldGroupKey: oldGroupKey,
                            newGroupKey: newGroupKey,
                            oldIndexPath: oldIndexPath,
                            changeType: .reload
                        ))
                    } else {
                        // Item pindah section
                        changes.append(ItemChange(
                            entity: entity,
                            oldGroupKey: oldGroupKey,
                            newGroupKey: newGroupKey,
                            oldIndexPath: oldIndexPath,
                            changeType: .move
                        ))

                        // Track section yang mungkin perlu dibuat
                        if !existingSectionsBeforeUpdate.contains(newGroupKey) {
                            sectionsToCreate.insert(newGroupKey)
                        }
                    }
                }
            }
        } else {
            // Non-grouped mode: simple reload
            let editedIndexPaths = Set(data.enumerated().compactMap { index, entity in
                if let entityId = entity.id, ids.contains(entityId) {
                    return IndexPath(item: index, section: 0)
                }
                return nil
            })

            collectionView.performBatchUpdates {
                collectionView.reloadItems(at: editedIndexPaths)
            } completionHandler: { [weak self] _ in
                guard let self else { return }
                flowLayout.invalidateLayout()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
                }
            }
            return
        }

        // ✅ FASE 2: Update Data Source
        // Remove items that will move from their old sections
        for change in changes where change.changeType == .move {
            guard var oldSectionData = groupedData[change.oldGroupKey] else { continue }
            oldSectionData.removeAll { $0.id == change.entity.id }

            if oldSectionData.isEmpty {
                sectionsToDelete.insert(change.oldGroupKey)
                groupedData.removeValue(forKey: change.oldGroupKey)
                sectionKeys.removeAll { $0 == change.oldGroupKey }
                sectionTotals.removeValue(forKey: change.oldGroupKey)
            } else {
                groupedData[change.oldGroupKey] = oldSectionData
            }
        }

        // Add/update items in their new sections
        for change in changes where change.changeType == .move {
            if groupedData[change.newGroupKey] == nil {
                groupedData[change.newGroupKey] = []
                if !sectionKeys.contains(change.newGroupKey) {
                    sectionKeys.append(change.newGroupKey)
                }
            }

            guard var newSectionData = groupedData[change.newGroupKey] else { continue }

            // Remove if exists (shouldn't happen, but safety)
            newSectionData.removeAll { $0.id == change.entity.id }

            // Insert at correct position
            let insertIndex = insertionIndex(for: change.entity, in: newSectionData)
            newSectionData.insert(change.entity, at: insertIndex)
            groupedData[change.newGroupKey] = newSectionData
        }

        // ✅ FASE 3: Sort keys and calculate final IndexPaths
        sectionKeys = groupedData.keys.sorted()
        let sortedKeys = sectionKeys

        var sectionsToDeleteIndexes: IndexSet = []
        var sectionsToInsertIndexes: IndexSet = []
        var itemsToDelete: Set<IndexPath> = []
        var itemsToInsert: Set<IndexPath> = []
        var itemsToReload: Set<IndexPath> = []
        var itemsToSelect: Set<IndexPath> = []

        // Calculate delete section indexes (before any changes)
        let oldSectionKeys = existingSectionsBeforeUpdate.sorted()

        for sectionKey in sectionsToDelete {
            if let oldIndex = oldSectionKeys.firstIndex(of: sectionKey) {
                sectionsToDeleteIndexes.insert(oldIndex)
            }
        }

        // Calculate insert section indexes (after sort)
        for sectionKey in sectionsToCreate {
            if let newIndex = sortedKeys.firstIndex(of: sectionKey) {
                sectionsToInsertIndexes.insert(newIndex)
            }
        }

        // Calculate item changes
        for change in changes {
            switch change.changeType {
            case .reload:
                if let sectionIndex = sortedKeys.firstIndex(of: change.newGroupKey),
                   let sectionData = groupedData[change.newGroupKey],
                   let itemIndex = sectionData.firstIndex(where: { $0.id == change.entity.id })
                {
                    let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                    itemsToReload.insert(indexPath)
                }

            case .move:
                // Delete from old position
                itemsToDelete.insert(change.oldIndexPath)

                // Insert at new position
                if let newSectionIndex = sortedKeys.firstIndex(of: change.newGroupKey),
                   let sectionData = groupedData[change.newGroupKey],
                   let newItemIndex = sectionData.firstIndex(where: { $0.id == change.entity.id })
                {
                    let newIndexPath = IndexPath(item: newItemIndex, section: newSectionIndex)
                    itemsToInsert.insert(newIndexPath)
                    itemsToSelect.insert(newIndexPath)
                }
            }
        }

        // ✅ FASE 4: Perform single batch update
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }

            // Order matters: delete items -> delete sections -> insert sections -> insert items -> reload items

            // 1. Delete items first
            if !itemsToDelete.isEmpty {
                collectionView.deleteItems(at: itemsToDelete)
            }

            // 2. Delete empty sections
            if !sectionsToDeleteIndexes.isEmpty {
                collectionView.deleteSections(sectionsToDeleteIndexes)
            }

            // 3. Insert new sections
            if !sectionsToInsertIndexes.isEmpty {
                collectionView.insertSections(sectionsToInsertIndexes)
            }

            // 4. Insert moved items
            if !itemsToInsert.isEmpty {
                collectionView.insertItems(at: itemsToInsert)
            }

            // 5. Reload items that didn't move
            if !itemsToReload.isEmpty {
                collectionView.reloadItems(at: itemsToReload)
            }

            // 6. Update totals for affected sections
            let allAffectedSections = Set(
                itemsToInsert.map(\.section) +
                    itemsToReload.map(\.section) +
                    sectionsToInsertIndexes.map { $0 }
            )

            for sectionIndex in allAffectedSections {
                let sectionIndexPath = IndexPath(item: 0, section: sectionIndex)
                updateTotalAmountsForSection(at: sectionIndexPath)
            }

        } completionHandler: { [weak self] finished in
            guard let self, finished else {
                return
            }
            // Invalidate layout and headers
            flowLayout.invalidateLayout()

            let allAffectedSections = Set(
                itemsToInsert.map(\.section) +
                    itemsToReload.map(\.section) +
                    sectionsToInsertIndexes.map { $0 }
            )

            for sectionIndex in allAffectedSections {
                invalidateHeader(at: sectionIndex)
            }

            // Select moved items
            if !itemsToSelect.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.collectionView.selectItems(at: itemsToSelect, scrollPosition: .centeredVertically)
                }
            }
        }
    }

    // MARK: - function untuk mendapatkan group key

    /// Menentukan kunci pengelompokan untuk objek `Entity` yang diberikan.
    /// Kunci pengelompokan ini digunakan untuk mengelompokkan item-item dalam `collectionView`
    /// berdasarkan preferensi pengelompokan yang saat ini dipilih (`selectedGroup`).
    ///
    /// - Parameter snapshot: Objek `Entity` yang ingin diambil kunci pengelompokannya.
    /// - Returns: Sebuah `String` yang mewakili kunci grup, atau "Lainnya" jika
    ///   tidak ada grup spesifik yang ditemukan atau dipilih.
    func getEntityGroupKey(for snapshot: Entity) -> String? {
        // Pernyataan `switch` digunakan untuk memeriksa nilai dari `selectedGroup`.
        switch selectedGroup {
        case "acara":
            // Jika pengelompokan berdasarkan "acara", kembalikan properti 'acara' dari entitas.
            // Jika 'acara' bernilai nil, gunakan nilai default "Tanpa Acara".
            snapshot.acara?.value ?? "Tanpa Acara"
        case "kategori":
            // Jika pengelompokan berdasarkan "kategori", kembalikan properti 'kategori'.
            // Jika 'kategori' bernilai nil, gunakan nilai default "Tanpa Kategori".
            snapshot.kategori?.value ?? "Tanpa Kategori"
        case "keperluan":
            // Jika pengelompokan berdasarkan "keperluan", kembalikan properti 'keperluan'.
            // Jika 'keperluan' bernilai nil, gunakan nilai default "Tanpa Keperluan".
            snapshot.keperluan?.value ?? "Tanpa Keperluan"
        default:
            // Jika `selectedGroup` tidak cocok dengan kasus yang didefinisikan,
            // atau jika `selectedGroup` bernilai nil, gunakan nilai default "Lainnya".
            "Lainnya"
        }
    }

    /// Menentukan kunci pengelompokan untuk objek `EntitySnapshot` yang diberikan.
    /// Fungsi ini serupa dengan `getEntityGroupKey`, namun ia beroperasi pada
    /// `EntitySnapshot` yang tidak dapat diubah (sering digunakan untuk data historis atau status undo).
    ///
    /// - Parameter snapshot: Objek `EntitySnapshot` yang ingin diambil kunci pengelompokannya.
    /// - Returns: Sebuah `String` yang mewakili kunci grup, atau "Lainnya" jika
    ///   tidak ada grup spesifik yang ditemukan atau dipilih.
    func getGroupKey(for snapshot: EntitySnapshot) -> String? {
        // Serupa dengan `getEntityGroupKey`, pernyataan `switch` ini memeriksa `selectedGroup`.
        switch selectedGroup {
        case "acara":
            // Mengembalikan properti 'acara' dari snapshot, dengan nilai default "Tanpa Acara" jika nil.
            snapshot.acara?.value ?? "Tanpa Acara"
        case "kategori":
            // Mengembalikan properti 'kategori' dari snapshot, dengan nilai default "Tanpa Kategori" jika nil.
            snapshot.kategori?.value ?? "Tanpa Kategori"
        case "keperluan":
            // Mengembalikan properti 'keperluan' dari snapshot, dengan nilai default "Tanpa Keperluan" jika nil.
            snapshot.keperluan?.value ?? "Tanpa Keperluan"
        default:
            // Menggunakan nilai default "Lainnya" jika tidak ada grup yang cocok dipilih atau ditemukan.
            "Lainnya"
        }
    }

    /// Action undo di Menu Bar.
    @objc func performUndo(_: Any) {
        myUndoManager.undo()
        NotificationCenter.default.post(name: .perubahanData, object: nil)
    }

    /// Action redo di Menu Bar.
    @objc func performRedo(_: Any) {
        myUndoManager.redo()
        NotificationCenter.default.post(name: .perubahanData, object: nil)
    }

    /// Pembaruan undo/redo di Menu Bar.
    /// Aktif jika ``myUndoManager`` bisa undo/redo.
    @objc func updateUndoRedo() {
        UndoRedoManager.shared.updateUndoRedoState(
            for: self, undoManager: myUndoManager,
            undoSelector: #selector(performUndo(_:)),
            redoSelector: #selector(performRedo(_:)),
            updateToolbar: false
        )
        UndoRedoManager.shared.startObserving()
    }

    // MARK: - Functions

    /// Fungsi perbandingan terpadu yang membandingkan dua Entity berdasarkan serangkaian kriteria.
    func compare(_ e1: Entity, _ e2: Entity, criteria: [SortCriterion]) -> ComparisonResult {
        for criterion in criteria {
            // Panggil comparator dari enum untuk kriteria saat ini
            let result = criterion.comparator(e1, e2)

            // Jika hasilnya tidak sama, kita telah menemukan urutannya.
            if result != .orderedSame {
                return result
            }
        }
        // Jika semua kriteria sama, anggap mereka setara.
        return .orderedSame
    }

    /// Membandingkan dua objek `Entity` berdasarkan serangkaian kriteria yang diberikan.
    /// Fungsi ini mengimplementasikan logika pengurutan multi-kriteria, di mana
    /// prioritas pengurutan ditentukan oleh urutan kriteria dalam array `criteria`.
    ///
    /// - Parameters:
    ///   - e1: Objek `Entity` pertama untuk perbandingan.
    ///   - e2: Objek `Entity` kedua untuk perbandingan.
    ///   - criteria: Array `String` yang menentukan kriteria pengurutan dan prioritasnya.
    /// - Returns: `true` jika `e1` harus datang sebelum `e2` dalam urutan yang ditentukan, `false` sebaliknya.
    func compareElements(_ e1: Entity, _ e2: Entity, criteria: [SortCriterion]) -> Bool {
        compare(e1, e2, criteria: criteria) == .orderedAscending
    }

    /// Mengembalikan daftar kriteria pengurutan yang terprioritas berdasarkan opsi pengurutan yang dipilih.
    /// Fungsi ini menentukan urutan kriteria sekunder (dan seterusnya) yang akan digunakan
    /// jika kriteria utama memiliki nilai yang sama untuk dua elemen. Ini penting untuk
    /// memastikan pengurutan yang konsisten dan terprediksi.
    ///
    /// - Parameter option: Sebuah `String` yang menunjukkan opsi pengurutan utama yang dipilih pengguna yang akan
    /// dikonversi ke ``SortCriterion``. Jika konversi gagal, akan return [.jumlah].
    ///   Contoh nilai: "terbaru", "terlama", "kategori", "acara", "keperluan", "jumlah", "transaksi", "bertanda".
    /// - Returns: Sebuah array ``SortCriterion`` yang berisi daftar kriteria pengurutan,
    ///   diurutkan dari prioritas tertinggi ke terendah.
    func getSortingCriteria(for option: String) -> [SortCriterion] {
        guard let sortOption = SortCriterion(rawValue: option) else { return [.jumlah] }
        return switch sortOption {
        case .terbaru, .terlama:
            [sortOption, .keperluan, .acara, .kategori, .jumlah]
        case .kategori:
            [sortOption, .keperluan, .acara, .jumlah, .terbaru]
        case .acara:
            // Jika opsi utama adalah "acara", prioritaskan berdasarkan acara,
            // lalu keperluan, kategori, jumlah, dan terakhir tanggal terbaru.
            [sortOption, .keperluan, .kategori, .jumlah, .terbaru]
        case .keperluan:
            // Jika opsi utama adalah "keperluan", prioritaskan berdasarkan keperluan,
            // lalu acara, kategori, jumlah, dan terakhir tanggal terbaru.
            [sortOption, .keperluan, .kategori, .jumlah, .terbaru]
        case .jumlah:
            // Jika opsi utama adalah "jumlah", prioritaskan berdasarkan jumlah,
            // lalu acara, kategori, jenis transaksi, dan terakhir tanggal terbaru.
            [sortOption, .acara, .kategori, .transaksi, .terbaru]
        case .transaksi:
            // Jika opsi utama adalah "transaksi", prioritaskan berdasarkan jenis transaksi,
            // lalu acara, keperluan, jumlah, dan terakhir tanggal terbaru.
            [sortOption, .acara, .keperluan, .jumlah, .terbaru]
        case .bertanda:
            [sortOption, .terbaru, .keperluan, .acara, .kategori, .jumlah]
        }
    }

    // MARK: - Insertion Functions

    /// Menentukan indeks penyisipan yang tepat untuk sebuah `Entity` baru
    /// ke dalam array data utama aplikasi (`self.data`) agar urutan pengurutan
    /// yang sedang aktif (`currentSortOption`) tetap terjaga.
    ///
    /// Fungsi ini menggunakan kriteria pengurutan yang diperoleh dari `getSortingCriteria`
    /// dan logika perbandingan dari `shouldInsertBefore` untuk menemukan posisi yang benar.
    ///
    /// - Parameter element: Objek `Entity` yang akan disisipkan.
    /// - Returns: Indeks `Int` di mana `element` harus disisipkan dalam `self.data`.
    ///   Mengembalikan `data.endIndex` jika `element` harus berada di akhir array.
    func insertionIndex(for element: Entity) -> Int {
        insertionIndex(for: element, in: data)
    }

    /// Menentukan indeks penyisipan yang tepat untuk sebuah `Entity` baru
    /// ke dalam array `Entity` tertentu yang disediakan, agar urutan pengurutan
    /// yang sedang aktif (`currentSortOption`) tetap terjaga.
    ///
    /// Fungsi ini memungkinkan penentuan indeks penyisipan dalam sub-array atau
    /// grup data tertentu, menjaga konsistensi urutan pengurutan di dalamnya.
    ///
    /// - Parameters:
    ///   - element: Objek `Entity` yang akan disisipkan.
    ///   - array: Array `Entity` tempat `element` akan disisipkan.
    /// - Returns: Indeks `Int` di mana `element` harus disisipkan dalam `array` yang diberikan.
    ///   Mengembalikan `array.endIndex` jika `element` harus berada di akhir array.
    func insertionIndex(for element: Entity, in array: [Entity]) -> Int {
        // Dapatkan kriteria dari opsi yang aktif
        let criteria = getSortingCriteria(for: currentSortOption)

        // Gunakan binary search untuk menemukan indeks
        var low = 0
        var high = array.count
        while low < high {
            let mid = low + (high - low) / 2
            // Gunakan fungsi compare terpadu kita
            if compare(array[mid], element, criteria: criteria) == .orderedAscending {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
