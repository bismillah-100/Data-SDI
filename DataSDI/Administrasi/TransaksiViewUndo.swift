//
//  TransaksiViewUndo.swift
//  Data SDI
//
//  Created by Bismillah on 04/11/24.
//

extension TransaksiView {
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
                    let sortedKeys = groupedData.keys.sorted()

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
            dataToDelete.forEach { [weak self] item in
                self?.context.delete(item)
            }
            // Simpan perubahan ke Core Data secara permanen.
            do {
                try context.save()
            } catch {
                // Tangani error jika penyimpanan gagal.
                #if DEBUG
                    print("Gagal menyimpan konteks Core Data setelah undoAddItem: \(error.localizedDescription)")
                #endif
            }

            // Perbarui tampilan header section jika dalam mode dikelompokkan.
            if isGrouped {
                // `originalData` mungkin perlu di-refresh dari DataManager tergantung pada implementasi lain.
                // self.originalData = DataManager.shared.fetchData()

                // Jika ada section, perbarui tampilan garis di header.
                if sectionKeys.count >= 1, let topSection = flowLayout.findTopSection() {
                    // Buat garis untuk header section paling atas.
                    if let headerView = collectionView.supplementaryView(
                        forElementKind: NSCollectionView.elementKindSectionHeader,
                        at: IndexPath(item: 0, section: topSection)
                    ) as? HeaderView {
                        headerView.createLine()
                    }
                    // Hapus garis untuk header section lainnya (kecuali yang paling atas).
                    for i in 1 ..< sectionKeys.count {
                        guard i != topSection else { continue }
                        if let headerView = collectionView.supplementaryView(
                            forElementKind: NSCollectionView.elementKindSectionHeader,
                            at: IndexPath(item: 0, section: i)
                        ) as? HeaderView {
                            headerView.removeLine()
                        }
                    }
                }
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

        // Tambahkan kembali data item ke Core Data menggunakan DataManager.
        // Properti dari snapshot digunakan untuk mengisi atribut item baru.
        DataManager.shared.addData(
            id: snapshot.id!,
            jenis: snapshot.jenis,
            dari: snapshot.dari ?? "",
            jumlah: snapshot.jumlah,
            kategori: snapshot.kategori?.value ?? "",
            acara: snapshot.acara?.value ?? "",
            keperluan: snapshot.keperluan?.value ?? "",
            tanggal: snapshot.tanggal!,
            bulan: snapshot.bulan!,
            tahun: snapshot.tahun!,
            tanda: snapshot.ditandai ?? false
        )

        // Panggil fungsi `dataDitambah()` untuk merefresh `collectionView`
        // agar item yang baru ditambahkan kembali muncul di UI.
        NotificationCenter.default.post(name: DataManager.dataDidChangeNotification, object: nil, userInfo: ["newItem": snapshot.id!])

        // Panggil `checkForDuplicateID` untuk memeriksa apakah ada UUID yang sama.
        checkForDuplicateID(NSMenuItem())
    }

    // MARK: - UNDOHAPUS

    /// Mengembalikan (redo) tindakan penghapusan satu atau beberapa item yang sebelumnya di-undo.
    /// Fungsi ini menghapus kembali item-item dari `collectionView` dan Core Data
    /// yang sebelumnya sudah ditambahkan kembali melalui fungsi `undoHapus`.
    ///
    /// - Parameter data: Sebuah array dari objek `Entity` yang mewakili item-item
    ///   yang akan dihapus kembali.
    func redoHapus(_ data: [Entity]) {
        collectionView.deselectAll(self)
        var prevData: [EntitySnapshot] = []
        for data in data {
            guard data.jumlah != 0 else { return }
            var dataToDelete: [Entity] = []
            let snapshot = EntitySnapshot(
                id: data.id,
                jenis: data.jenis,
                dari: data.dari,
                jumlah: data.jumlah,
                kategori: data.kategori,
                acara: data.acara,
                keperluan: data.keperluan,
                tanggal: data.tanggal ?? Date(),
                bulan: data.bulan,
                tahun: data.tahun, ditandai: data.ditandai
            )
            prevData.append(snapshot)

            let animationGroup = DispatchGroup()
            animationGroup.enter()
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = false
                context.duration = 0 // Sesuaikan durasi animasi sesuai kebutuhan
                collectionView.performBatchUpdates({
                    if isGrouped {
                        guard let groupKey = getEntityGroupKey(for: data) else { return }
                        let sortedKeys = groupedData.keys.sorted()

                        if let groupKeyIndex = sortedKeys.firstIndex(of: groupKey),
                           var itemsInSection = groupedData[sortedKeys[groupKeyIndex]],
                           let itemIndex = itemsInSection.firstIndex(where: { $0.id == data.id })
                        {
                            // Hapus dari context Core Data
                            let itemToDelete = itemsInSection[itemIndex]
                            dataToDelete.append(itemToDelete)
                            selectNextItem(afterDeletingFrom: [IndexPath(item: itemIndex, section: groupKeyIndex)])
                            itemsInSection.remove(at: itemIndex)
                            groupedData[sortedKeys[groupKeyIndex]] = itemsInSection.isEmpty ? nil : itemsInSection

                            // Perbarui tampilan untuk mode `isGrouped`
                            let indexPath = IndexPath(item: itemIndex, section: groupKeyIndex)
                            collectionView.scrollToItems(at: Set([indexPath]), scrollPosition: .centeredVertically)
                            collectionView.deleteItems(at: [indexPath])
                            if itemsInSection.isEmpty {
                                groupedData.removeValue(forKey: sortedKeys[groupKeyIndex])
                                sectionKeys.removeAll(where: { $0 == groupKey })
                                collectionView.deleteSections(IndexSet(integer: groupKeyIndex))
                            }
                        } else {}
                    } else {
                        if let itemIndex = self.data.firstIndex(where: { $0.id == data.id }) {
                            let itemToDelete = self.data[itemIndex]
                            dataToDelete.append(itemToDelete)
                            self.data.remove(at: itemIndex)
                            collectionView.deleteItems(at: [IndexPath(item: itemIndex, section: 0)])
                            selectNextItem(afterDeletingFrom: [IndexPath(item: itemIndex, section: 0)])
                        } else {
                            return
                        }
                    }
                }, completionHandler: { _ in
                    if self.isGrouped {
                        self.flowLayout.invalidateLayout()
                        if self.sectionKeys.count >= 1, let topSection = self.flowLayout.findTopSection() {
                            if let headerView = self.collectionView.supplementaryView(
                                forElementKind: NSCollectionView.elementKindSectionHeader,
                                at: IndexPath(item: 0, section: topSection)
                            ) as? HeaderView {
                                headerView.createLine()
                            }
                            for i in 1 ..< self.sectionKeys.count {
                                guard i != topSection else { continue }
                                if let headerView = self.collectionView.supplementaryView(
                                    forElementKind: NSCollectionView.elementKindSectionHeader,
                                    at: IndexPath(item: 0, section: i)
                                ) as? HeaderView {
                                    headerView.removeLine()
                                }
                            }
                        }
                    }
                })
                NotificationCenter.default.post(name: DataManager.dataDihapusNotif, object: nil, userInfo: ["deletedEntity": prevData])
            }, completionHandler: {
                for i in dataToDelete {
                    self.context.delete(i)
                }
                do {
                    try self.context.save()
                } catch {
                    print(error.localizedDescription)
                }

                animationGroup.leave()
            })
        }
        // Mendaftarkan undo untuk redo
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard self == self else { return }
            self?.undoHapus(prevData)
        })
    }

    /// Mengembalikan (undo) tindakan penghapusan item yang sebelumnya dilakukan.
    /// Fungsi ini akan membuat kembali item-item yang telah dihapus dan menampilkannya kembali
    /// di `collectionView` dan menyimpannya di Core Data.
    ///
    /// - Parameter snapshot: Sebuah array dari `EntitySnapshot` yang berisi data
    ///   dari item-item yang sebelumnya dihapus dan perlu dikembalikan.
    func undoHapus(_ snapshots: [EntitySnapshot]) {
        // Batalkan semua pilihan di `collectionView`.
        collectionView.deselectAll(nil)

        // Array untuk menyimpan entitas yang baru dibuat kembali.
        // Ini akan digunakan untuk operasi redo (yaitu, redo dari undoHapus).
        var prevData: [Entity] = []

        // Iterasi melalui setiap snapshot dalam array yang diberikan.
        for snapshot in snapshots {
            // Buat objek `Entity` baru di Core Data context.
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

            if isGrouped {
                // MARK: - Penanganan untuk Mode Dikelompokkan

                // Dapatkan kunci grup untuk snapshot. Jika tidak ada, lewati.
                guard let groupKey = getGroupKey(for: snapshot) else { return }

                // Lakukan pembaruan batch pada `collectionView` untuk animasi penambahan item.
                collectionView.performBatchUpdates {
                    // Periksa apakah kunci grup sudah ada di `groupedData`.
                    if groupedData.keys.contains(groupKey), var sectionData = groupedData[groupKey] {
                        // Jika grup sudah ada, tentukan indeks penyisipan yang benar
                        // agar item tetap terurut dalam section.
                        let itemIndex = insertionIndex(for: newItem, in: sectionData)
                        // Periksa apakah item dengan ID yang sama sudah ada di section.
                        let itemExists = sectionData.contains { $0.id == newItem.id }

                        if !itemExists {
                            // Jika item belum ada, sisipkan item baru ke dalam `sectionData`.
                            sectionData.insert(newItem, at: itemIndex)
                            // Perbarui `groupedData` dengan `sectionData` yang telah dimodifikasi.
                            groupedData[groupKey] = sectionData

                            // Dapatkan indeks section yang diurutkan.
                            if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                                // Sisipkan item ke `collectionView` secara visual.
                                collectionView.insertItems(at: [indexPath])
                                // Perbarui total jumlah yang ditampilkan di header section.
                                let sectionIndices = IndexPath(item: 0, section: sectionIndex)
                                self.updateTotalAmountsForSection(at: sectionIndices)
                            }
                        }
                    } else {
                        // Jika grup belum ada (section baru):
                        groupedData[groupKey] = [newItem] // Buat grup baru dengan item ini.
                        // Tambahkan kunci grup ke `sectionKeys` jika belum ada dan urutkan.
                        if !sectionKeys.sorted().contains(groupKey) {
                            sectionKeys.append(groupKey)
                            sectionKeys.sort() // Pastikan `sectionKeys` tetap terurut.
                        }

                        // Dapatkan indeks section yang baru diurutkan.
                        if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                            collectionView.insertSections([sectionIndex]) // Sisipkan section baru.
                            let indexPath = IndexPath(item: 0, section: sectionIndex)
                            collectionView.insertItems(at: [indexPath]) // Sisipkan item pertama ke section baru.
                        }
                    }
                } completionHandler: { [weak self] _ in
                    // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                    guard let self else { return }

                    // Setelah update selesai, gulirkan dan pilih item yang baru ditambahkan.
                    if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey),
                       let sectionData = groupedData[groupKey],
                       let itemIndex = sectionData.firstIndex(where: { $0.id == newItem.id })
                    {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        // Pilih dan gulirkan ke item yang baru ditambahkan.
                        collectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
                        flowLayout.invalidateLayout() // Invalidate layout untuk pembaruan yang tepat.

                        // Perbarui tampilan garis di header section (khususnya untuk section paling atas).
                        if sectionIndex == 0 {
                            if let headerView = collectionView.supplementaryView(
                                forElementKind: NSCollectionView.elementKindSectionHeader,
                                at: IndexPath(item: 0, section: sectionIndex)
                            ) as? HeaderView {
                                headerView.createLine()
                            }
                        }
                        // Perbarui garis untuk section lainnya.
                        if sectionKeys.count >= 1, let topSection = flowLayout.findTopSection() {
                            for i in 1 ..< sectionKeys.count {
                                guard i != topSection else { continue }
                                if let headerView = collectionView.supplementaryView(
                                    forElementKind: NSCollectionView.elementKindSectionHeader,
                                    at: IndexPath(item: 0, section: i)
                                ) as? HeaderView {
                                    headerView.removeLine()
                                }
                            }
                        }
                    }
                }
            } else {
                // MARK: - Penanganan untuk Mode Tidak Dikelompokkan

                // Tentukan indeks penyisipan yang benar agar item tetap terurut.
                let index = insertionIndex(for: newItem)
                // Sisipkan item baru ke dalam array data utama.
                data.insert(newItem, at: index) // Asumsi `data` adalah array model utama untuk non-grup.

                // Lakukan pembaruan batch pada `collectionView`.
                collectionView.performBatchUpdates {
                    let indexPath = IndexPath(item: index, section: 0)
                    collectionView.insertItems(at: [indexPath]) // Sisipkan item ke `collectionView` secara visual.
                } completionHandler: { _ in
                    // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                    // Temukan item berdasarkan ID setelah penundaan singkat untuk memastikan UI telah diperbarui.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self else { return }
                        if let itemIndex = data.firstIndex(where: { $0.id == newItem.id }) {
                            let indexPath = IndexPath(item: itemIndex, section: 0)
                            // Pilih dan gulirkan ke item yang baru ditambahkan.
                            collectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
                        }
                    }
                }
            }
        } // Akhir dari loop `for` snapshots

        // Daftarkan operasi 'redo' ke `myUndoManager`.
        // Ketika 'redo' dipicu, `redoHapus` akan dipanggil dengan `prevData` (item yang baru saja dikembalikan),
        // untuk menghapus item-item tersebut kembali.
        myUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let self else { return } // Pastikan self masih ada.
            redoHapus(prevData) // Panggil `redoHapus` dengan item yang baru saja dikembalikan.
        }

        // Simpan perubahan ke Core Data secara permanen.
        do {
            try context.save()
        } catch {
            #if DEBUG
                print("Gagal menyimpan konteks Core Data setelah undoHapus: \(error.localizedDescription)")
            #endif
        }

        prevData.forEach { d in
            NotificationCenter.default.post(name: DataManager.dataDitambahNotif, object: nil, userInfo: ["data": d])
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
        var editedIndexPaths: Set<IndexPath> = []
        var editedSectionIndices: IndexSet = []
        var sectionDelete: IndexSet = [] // IndexSet untuk section yang akan dihapus setelah performBatchUpdates
        var jenisToDelete: [String] = []
        let sortedSectionKeys = groupedData.keys.sorted()
        var insertion = 0

        collectionView.performBatchUpdates({
            if isGrouped {
                for (section, jenisTransaksi) in sortedSectionKeys.enumerated() {
                    guard var items = groupedData[jenisTransaksi] else {
                        continue
                    }

                    // Loop melalui setiap item dalam section, hanya tambahkan yang ID-nya cocok
                    for (itemIndex, entity) in items.enumerated().reversed() {
                        if let entityId = entity.id, ids.contains(entityId) {
                            guard let snapshot = prevData.first(where: { $0.id == entityId }) else { continue }
                            // Now the comparison should work
                            if snapshot == entity {
                                #if DEBUG
                                    print("snapshot sama persis")
                                #endif
                                continue
                            }

                            var groupKey: String
                            groupKey = getEntityGroupKey(for: entity) ?? "Lainnya"
                            let oldGroupKey: String = if let oldData = prevData.first(where: { $0.id == entityId }) {
                                getGroupKey(for: oldData) ?? "Lainnya"
                            } else {
                                "Lainnya"
                            }

                            guard groupKey != oldGroupKey else {
                                let indexPath = IndexPath(item: itemIndex, section: section)
                                collectionView.reloadItems(at: Set([indexPath]))
                                updateTotalAmountsForSection(at: indexPath)
                                continue
                            }
                            if groupKey != oldGroupKey {
                                // Periksa apakah key ada di groupedData
                                let sectionExists = sortedSectionKeys.contains(groupKey)
                                if sectionExists, var sectionData = groupedData[groupKey] {
                                    let newIndex = insertionIndex(for: entity, in: sectionData)
                                    let itemExists = sectionData.contains { $0.id == entity.id }
                                    if !itemExists {
                                        sectionData.insert(entity, at: newIndex)
                                        groupedData[groupKey] = sectionData

                                        // Dapatkan section index dari sectionKeys
                                        if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                                            let prevIndexPath = IndexPath(item: itemIndex, section: section)
                                            items.remove(at: itemIndex) // Hapus item dari section lama
                                            groupedData[jenisTransaksi] = items

                                            let indexPath = IndexPath(item: newIndex, section: sectionIndex)
                                            collectionView.deleteItems(at: Set([prevIndexPath]))
                                            if items.isEmpty {
                                                // Tambahkan index section untuk dihapus, tanpa menghapus dari groupedData dan sectionKeys
                                                if let sectionIndex = sectionKeys.sorted().firstIndex(of: jenisTransaksi) {
                                                    jenisToDelete.append(jenisTransaksi)
                                                    sectionDelete.insert(sectionIndex)
                                                }
                                            }
                                            collectionView.insertItems(at: Set([indexPath]))
                                            editedSectionIndices.insert(indexPath.section)
                                            editedIndexPaths.insert(indexPath)
                                        }
                                    }
                                } else {
                                    // Section belum ada, buat section baru
                                    if groupedData[groupKey] == nil {
                                        insertion = 0

                                        groupedData[groupKey] = [entity]
                                        sectionKeys.append(groupKey)
                                        if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                                            collectionView.insertSections(IndexSet(integer: sectionIndex))
                                            editedSectionIndices.insert(sectionIndex)
                                        }
                                    } else {
                                        if let groupedEntity = groupedData[groupKey] {
                                            insertion = insertionIndex(for: entity, in: groupedEntity)
                                        }
                                        groupedData[groupKey]?.append(entity)
                                    }

                                    if let sectionIndex = sectionKeys.sorted().firstIndex(of: groupKey) {
                                        // Pastikan items masih memiliki item sebelum menghapus
                                        guard itemIndex < items.count else { continue }

                                        let prevIndexPath = IndexPath(item: itemIndex, section: section)
                                        editedSectionIndices.insert(prevIndexPath.section)
                                        // Pastikan section masih memiliki items sebelum mencoba menghapus
                                        if !items.isEmpty {
                                            collectionView.deleteItems(at: [prevIndexPath])
                                        }
                                        items.remove(at: itemIndex)
                                        groupedData[jenisTransaksi] = items
                                        let newIndexPath = IndexPath(item: insertion, section: sectionIndex)
                                        editedIndexPaths.insert(newIndexPath)
                                        // collectionView.moveItem(at: prevIndexPath, to: newIndexPath)
                                        collectionView.insertItems(at: Set([newIndexPath]))

                                        // Pindahkan pengecekan items.isEmpty ke sini
                                        if items.isEmpty {
                                            if let sectionIndex = sectionKeys.sorted().firstIndex(of: jenisTransaksi) {
                                                jenisToDelete.append(jenisTransaksi)
                                                sectionDelete.insert(sectionIndex)
                                            }
                                        }
                                    } else {}
                                }
                            }
                        }
                    }
                }
            } else {
                editedIndexPaths = Set(data.enumerated().compactMap { index, entity in
                    if let entityId = entity.id, ids.contains(entityId) {
                        return IndexPath(item: index, section: 0)
                    }
                    return nil
                })
                collectionView.reloadItems(at: editedIndexPaths)
            }
            // Simpan indeks item yang dipilih sebelum reload
            // let selectedIndexPaths = collectionView.selectionIndexPaths
        }, completionHandler: { [weak self] _ in
            guard let self else { return }
            if !isGrouped {
                flowLayout.invalidateLayout()
                DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                    self?.collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
                }
            } else {
                if !editedSectionIndices.isEmpty {
                    // Perbarui jumlah pengeluaran dan pemasukan untuk section yang mengalami perubahan
                    for sectionIndex in 0 ..< collectionView.numberOfSections - 1 {
                        let sectionIndexPath = IndexPath(item: 0, section: sectionIndex)
                        updateTotalAmountsForSection(at: sectionIndexPath)
                    }
                }
                // self.originalData = DataManager.shared.fetchData()
                if sectionKeys.count >= 1, let topSection = flowLayout.findTopSection() {
                    if let headerView = collectionView.supplementaryView(
                        forElementKind: NSCollectionView.elementKindSectionHeader,
                        at: IndexPath(item: 0, section: topSection)
                    ) as? HeaderView {
                        headerView.createLine()
                    }
                    for i in 1 ..< sectionKeys.count {
                        guard i != topSection else { continue }
                        if let headerView = collectionView.supplementaryView(
                            forElementKind: NSCollectionView.elementKindSectionHeader,
                            at: IndexPath(item: 0, section: i)
                        ) as? HeaderView {
                            headerView.removeLine()
                        }
                    }
                }
            }
        })
        guard !sectionDelete.isEmpty, isGrouped else {
            return
        }
        collectionView.performBatchUpdates({
            for data in jenisToDelete {
                self.groupedData.removeValue(forKey: data)
                self.sectionKeys.removeAll(where: { $0 == data })
            }
            self.collectionView.deleteSections(sectionDelete)
        }, completionHandler: { _ in
            self.flowLayout.invalidateLayout()
            // Perbarui jumlah pengeluaran dan pemasukan untuk section yang mengalami perubahan
            guard !editedSectionIndices.isEmpty else { return }
            for sectionIndex in 0 ..< self.collectionView.numberOfSections - 1 {
                let sectionIndexPath = IndexPath(item: 0, section: sectionIndex)
                self.updateTotalAmountsForSection(at: sectionIndexPath)
            }
        })
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
            redoSelector: #selector(performRedo(_:))
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
