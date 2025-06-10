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
                            self.updateTotalAmountsForSection(at: sectionIndices)
                        }
                    } else {
                        return // Item tidak ditemukan dalam grup, keluar dari blok.
                    }
                } else {
                    // MARK: - Penanganan untuk Mode Tidak Dikelompokkan

                    // Cari indeks item di array `data` utama (mode tidak dikelompokkan).
                    if let itemIndex = self.data.firstIndex(where: { $0.id == newItem.id }) {
                        // Tambahkan item ke array `dataToDelete`.
                        let itemToDelete = self.data[itemIndex]
                        dataToDelete.append(itemToDelete)
                        // Hapus item dari model data tidak dikelompokkan (`data`).
                        self.data.remove(at: itemIndex)
                        // Perbarui tampilan `collectionView` dengan menghapus item.
                        collectionView.deleteItems(at: [IndexPath(item: itemIndex, section: 0)])
                        // Pilih item berikutnya setelah penghapusan.
                        selectNextItem(afterDeletingFrom: [IndexPath(item: itemIndex, section: 0)])
                    } else {
                        return // Item tidak ditemukan dalam data tidak dikelompokkan, keluar dari blok.
                    }
                }
            }, completionHandler: { [weak self] finish in
                // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                guard let self else { return }
                if self.isGrouped {
                    // Jika dalam mode dikelompokkan, *invalidate* layout untuk memastikan pembaruan yang tepat.
                    self.flowLayout.invalidateLayout()
                }
            })
        }, completionHandler: { [unowned self] in
            // MARK: - Pembaruan Data dan UndoManager Setelah Animasi

            // Handler yang dijalankan setelah seluruh grup animasi selesai.

            // Kirim notifikasi bahwa data telah dihapus, dengan menyertakan entitas yang dihapus.
            NotificationCenter.default.post(name: DataManager.dataDihapusNotif, object: nil, userInfo: ["deletedEntity": dataToDelete])

            // Hapus entitas yang telah ditandai dari Core Data context.
            dataToDelete.forEach { [weak self] item in
                self?.context.delete(item)
            }
            // Simpan perubahan ke Core Data secara permanen.
            do {
                try self.context.save()
            } catch {
                // Tangani error jika penyimpanan gagal.
                print("Gagal menyimpan konteks Core Data setelah undoAddItem: \(error.localizedDescription)")
            }

            // Perbarui tampilan header section jika dalam mode dikelompokkan.
            if self.isGrouped {
                // `originalData` mungkin perlu di-refresh dari DataManager tergantung pada implementasi lain.
                // self.originalData = DataManager.shared.fetchData()

                // Jika ada section, perbarui tampilan garis di header.
                if self.sectionKeys.count >= 1, let topSection = self.flowLayout.findTopSection() {
                    // Buat garis untuk header section paling atas.
                    if let headerView = self.collectionView.supplementaryView(
                        forElementKind: NSCollectionView.elementKindSectionHeader,
                        at: IndexPath(item: 0, section: topSection)
                    ) as? HeaderView {
                        headerView.createLine()
                    }
                    // Hapus garis untuk header section lainnya (kecuali yang paling atas).
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
            animationGroup.leave() // Beri tahu group bahwa operasi telah selesai.
        })

        // Daftarkan operasi 'redo' ke `myUndoManager`.
        // Ketika 'redo' dipicu, `redoAddItem` akan dipanggil dengan snapshot yang sama
        // untuk mengembalikan item yang baru saja di-undo.
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
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
            jenis: snapshot.jenis ?? "Lainnya",
            dari: snapshot.dari ?? "",
            jumlah: snapshot.jumlah,
            kategori: snapshot.kategori ?? "",
            acara: snapshot.acara ?? "",
            keperluan: snapshot.keperluan,
            tanggal: snapshot.tanggal!,
            bulan: snapshot.bulan!,
            tahun: snapshot.tahun!,
            tanda: snapshot.ditandai ?? false
        )

        // Panggil fungsi `dataDitambah()` untuk merefresh `collectionView`
        // agar item yang baru ditambahkan kembali muncul di UI.
        dataDitambah()

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
                }, completionHandler: { finish in
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
            }, completionHandler: {
                NotificationCenter.default.post(name: DataManager.dataDihapusNotif, object: nil, userInfo: ["deletedEntity": dataToDelete])
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
        myUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
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
                } completionHandler: { [weak self] finished in
                    // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                    guard let self else { return }

                    // Setelah update selesai, gulirkan dan pilih item yang baru ditambahkan.
                    if let sectionIndex = self.sectionKeys.sorted().firstIndex(of: groupKey),
                       let sectionData = self.groupedData[groupKey],
                       let itemIndex = sectionData.firstIndex(where: { $0.id == newItem.id })
                    {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        // Pilih dan gulirkan ke item yang baru ditambahkan.
                        self.collectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
                        self.flowLayout.invalidateLayout() // Invalidate layout untuk pembaruan yang tepat.

                        // Perbarui tampilan garis di header section (khususnya untuk section paling atas).
                        if sectionIndex == 0 {
                            if let headerView = self.collectionView.supplementaryView(
                                forElementKind: NSCollectionView.elementKindSectionHeader,
                                at: IndexPath(item: 0, section: sectionIndex)
                            ) as? HeaderView {
                                headerView.createLine()
                            }
                        }
                        // Perbarui garis untuk section lainnya.
                        if self.sectionKeys.count >= 1, let topSection = self.flowLayout.findTopSection() {
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
                } completionHandler: { [weak self] _ in
                    // Handler yang dijalankan setelah pembaruan batch `collectionView` selesai.
                    guard let self else { return }

                    // Temukan item berdasarkan ID setelah penundaan singkat untuk memastikan UI telah diperbarui.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
                        if let itemIndex = self.data.firstIndex(where: { $0.id == newItem.id }) {
                            let indexPath = IndexPath(item: itemIndex, section: 0)
                            // Pilih dan gulirkan ke item yang baru ditambahkan.
                            self.collectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
                        }
                    }
                }
            }
        } // Akhir dari loop `for` snapshots

        // Daftarkan operasi 'redo' ke `myUndoManager`.
        // Ketika 'redo' dipicu, `redoHapus` akan dipanggil dengan `prevData` (item yang baru saja dikembalikan),
        // untuk menghapus item-item tersebut kembali.
        myUndoManager.registerUndo(withTarget: self) { [weak self] targetSelf in
            guard let self else { return } // Pastikan self masih ada.
            self.redoHapus(prevData) // Panggil `redoHapus` dengan item yang baru saja dikembalikan.
        }

        // Simpan perubahan ke Core Data secara permanen.
        do {
            try context.save()
        } catch {
            #if DEBUG
                print("Gagal menyimpan konteks Core Data setelah undoHapus: \(error.localizedDescription)")
            #endif
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
                    jenis: snapshotToRestore.jenis ?? "Lainnya", // Gunakan jenis dari snapshot.
                    dari: snapshotToRestore.dari ?? "", // Gunakan dari dari snapshot.
                    jumlah: snapshotToRestore.jumlah, // Gunakan jumlah dari snapshot.
                    kategori: snapshotToRestore.kategori ?? "tanpa kategori", // Gunakan kategori dari snapshot.
                    acara: snapshotToRestore.acara ?? "tanpa acara", // Gunakan acara dari snapshot.
                    keperluan: snapshotToRestore.keperluan ?? "tanpa keperluan", // Gunakan keperluan dari snapshot.
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
                                    continue
                                #endif
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
        }, completionHandler: { [weak self] finish in
            guard let self else { return }
            if !self.isGrouped {
                self.flowLayout.invalidateLayout()
                DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                    self?.collectionView.selectItems(at: editedIndexPaths, scrollPosition: .centeredVertically)
                }
            } else {
                if !editedSectionIndices.isEmpty {
                    // Perbarui jumlah pengeluaran dan pemasukan untuk section yang mengalami perubahan
                    for sectionIndex in 0 ..< self.collectionView.numberOfSections - 1 {
                        let sectionIndexPath = IndexPath(item: 0, section: sectionIndex)
                        self.updateTotalAmountsForSection(at: sectionIndexPath)
                    }
                }
                // self.originalData = DataManager.shared.fetchData()
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
        guard !sectionDelete.isEmpty, isGrouped else {
            return
        }
        collectionView.performBatchUpdates({
            for data in jenisToDelete {
                self.groupedData.removeValue(forKey: data)
                self.sectionKeys.removeAll(where: { $0 == data })
            }
            self.collectionView.deleteSections(sectionDelete)
        }, completionHandler: { finish in
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
            snapshot.acara ?? "Tanpa Acara"
        case "kategori":
            // Jika pengelompokan berdasarkan "kategori", kembalikan properti 'kategori'.
            // Jika 'kategori' bernilai nil, gunakan nilai default "Tanpa Kategori".
            snapshot.kategori ?? "Tanpa Kategori"
        case "keperluan":
            // Jika pengelompokan berdasarkan "keperluan", kembalikan properti 'keperluan'.
            // Jika 'keperluan' bernilai nil, gunakan nilai default "Tanpa Keperluan".
            snapshot.keperluan ?? "Tanpa Keperluan"
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
            snapshot.acara ?? "Tanpa Acara"
        case "kategori":
            // Mengembalikan properti 'kategori' dari snapshot, dengan nilai default "Tanpa Kategori" jika nil.
            snapshot.kategori ?? "Tanpa Kategori"
        case "keperluan":
            // Mengembalikan properti 'keperluan' dari snapshot, dengan nilai default "Tanpa Keperluan" jika nil.
            snapshot.keperluan ?? "Tanpa Keperluan"
        default:
            // Menggunakan nilai default "Lainnya" jika tidak ada grup yang cocok dipilih atau ditemukan.
            "Lainnya"
        }
    }

    /// Action undo di Menu Bar.
    @objc func performUndo(_ sender: Any) {
        myUndoManager.undo()
        updateUndoRedo()
        NotificationCenter.default.post(name: .perubahanData, object: nil)
    }

    /// Action redo di Menu Bar.
    @objc func performRedo(_ sender: Any) {
        myUndoManager.redo()
        updateUndoRedo()
        NotificationCenter.default.post(name: .perubahanData, object: nil)
    }

    /// Pembaruan undo/redo di Menu Bar.
    /// Aktif jika ``myUndoManager`` bisa undo/redo.
    @objc func updateUndoRedo() {
        DispatchQueue.main.async { [unowned self] in
            guard let mainMenu = NSApp.mainMenu,
                  let editMenuItem = mainMenu.item(withTitle: "Edit"),
                  let editMenu = editMenuItem.submenu,
                  let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
                  let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" })
            else {
                return
            }

            let canUndo = myUndoManager.canUndo
            let canRedo = myUndoManager.canRedo

            if !canUndo {
                undoMenuItem.target = nil
                undoMenuItem.action = nil
                undoMenuItem.isEnabled = false
            } else {
                undoMenuItem.target = self
                undoMenuItem.action = #selector(performUndo(_:))
                undoMenuItem.isEnabled = canUndo
            }

            if !canRedo {
                redoMenuItem.target = nil
                redoMenuItem.action = nil
                redoMenuItem.isEnabled = false
            } else {
                redoMenuItem.target = self
                redoMenuItem.action = #selector(performRedo(_:))
                redoMenuItem.isEnabled = canRedo
            }
        }
    }

    // MARK: - Functions

    /// Membandingkan dua objek `Entity` berdasarkan serangkaian kriteria yang diberikan.
    /// Fungsi ini mengimplementasikan logika pengurutan multi-kriteria, di mana
    /// prioritas pengurutan ditentukan oleh urutan kriteria dalam array `criteria`.
    ///
    /// - Parameters:
    ///   - e1: Objek `Entity` pertama untuk perbandingan.
    ///   - e2: Objek `Entity` kedua untuk perbandingan.
    ///   - criteria: Array `String` yang menentukan kriteria pengurutan dan prioritasnya.
    /// - Returns: `true` jika `e1` harus datang sebelum `e2` dalam urutan yang ditentukan, `false` sebaliknya.
    func compareElements(_ e1: Entity, _ e2: Entity, criteria: [String]) -> Bool {
        // Iterasi melalui setiap kriteria pengurutan yang diberikan.
        // Perbandingan dilakukan secara berurutan; kriteria yang muncul lebih dulu
        // dalam array `criteria` akan memiliki prioritas lebih tinggi.
        for criterion in criteria {
            switch criterion {
            case "terbaru":
                // Bandingkan berdasarkan tanggal terbaru (menurun).
                let date1 = e1.tanggal?.timeIntervalSince1970 ?? 0
                let date2 = e2.tanggal?.timeIntervalSince1970 ?? 0
                if date1 != date2 {
                    return date1 > date2 // `true` jika `e1` lebih baru dari `e2`.
                }

            case "terlama":
                // Bandingkan berdasarkan tanggal terlama (meningkat).
                let date1 = e1.tanggal?.timeIntervalSince1970 ?? 0
                let date2 = e2.tanggal?.timeIntervalSince1970 ?? 0
                if date1 != date2 {
                    return date1 < date2 // `true` jika `e1` lebih lama dari `e2`.
                }

            case "kategori":
                // Bandingkan secara alfabetis berdasarkan kategori (meningkat).
                let kat1 = e1.kategori?.lowercased() ?? ""
                let kat2 = e2.kategori?.lowercased() ?? ""
                if kat1 != kat2 {
                    return kat1 < kat2 // `true` jika kategori `e1` secara alfabetis lebih kecil dari `e2`.
                }

            case "acara":
                // Bandingkan secara alfabetis berdasarkan acara (meningkat).
                let acara1 = e1.acara?.lowercased() ?? ""
                let acara2 = e2.acara?.lowercased() ?? ""
                if acara1 != acara2 {
                    return acara1 < acara2 // `true` jika acara `e1` secara alfabetis lebih kecil dari `e2`.
                }

            case "keperluan":
                // Bandingkan secara alfabetis berdasarkan keperluan (meningkat).
                let kep1 = e1.keperluan?.lowercased() ?? ""
                let kep2 = e2.keperluan?.lowercased() ?? ""
                if kep1 != kep2 {
                    return kep1 < kep2 // `true` jika keperluan `e1` secara alfabetis lebih kecil dari `e2`.
                }

            case "jumlah":
                // Bandingkan berdasarkan jumlah (meningkat).
                let jml1 = e1.jumlah
                let jml2 = e2.jumlah
                if jml1 != jml2 {
                    return jml1 < jml2 // `true` jika jumlah `e1` lebih kecil dari `e2`.
                }

            case "transaksi":
                // Bandingkan berdasarkan jenis transaksi dengan urutan khusus.
                let jenis1 = e1.jenis?.lowercased() ?? ""
                let jenis2 = e2.jenis?.lowercased() ?? ""
                if jenis1 != jenis2 {
                    // Definisikan urutan prioritas untuk jenis transaksi.
                    let order = ["pemasukan": 0, "pengeluaran": 1, "lainnya": 2]
                    let order1 = order[jenis1] ?? 3 // Default ke 3 jika tidak dikenali.
                    let order2 = order[jenis2] ?? 3 // Default ke 3 jika tidak dikenali.
                    return order1 < order2 // `true` jika `jenis1` memiliki prioritas lebih tinggi.
                }

            case "bertanda":
                // Bandingkan berdasarkan status 'ditandai'.
                // Prioritaskan item yang ditandai (true) untuk muncul lebih dulu.
                let ditandai1 = e1.ditandai
                let ditandai2 = e2.ditandai
                if ditandai1 != ditandai2 {
                    return ditandai1 && !ditandai2 // `true` jika `e1` ditandai dan `e2` tidak.
                }

            default:
                // Jika kriteria tidak dikenali, lewati dan lanjutkan ke kriteria berikutnya.
                break
            }
        }
        // Jika semua kriteria dibandingkan dan tidak ada perbedaan yang ditemukan,
        // maka kedua elemen dianggap sama dalam konteks pengurutan ini.
        return false
    }

    /// Mengembalikan daftar kriteria pengurutan yang terprioritas berdasarkan opsi pengurutan yang dipilih.
    /// Fungsi ini menentukan urutan kriteria sekunder (dan seterusnya) yang akan digunakan
    /// jika kriteria utama memiliki nilai yang sama untuk dua elemen. Ini penting untuk
    /// memastikan pengurutan yang konsisten dan terprediksi.
    ///
    /// - Parameter option: Sebuah `String` yang menunjukkan opsi pengurutan utama yang dipilih pengguna.
    ///   Contoh nilai: "terbaru", "terlama", "kategori", "acara", "keperluan", "jumlah", "transaksi", "bertanda".
    /// - Returns: Sebuah array `String` yang berisi daftar kriteria pengurutan,
    ///   diurutkan dari prioritas tertinggi ke terendah.
    func getSortingCriteria(for option: String) -> [String] {
        switch option {
        case "terbaru", "terlama":
            // Jika opsi utama adalah "terbaru" atau "terlama", prioritaskan berdasarkan tanggal,
            // lalu oleh keperluan, acara, kategori, dan terakhir jumlah.
            [option, "keperluan", "acara", "kategori", "jumlah"]
        case "kategori":
            // Jika opsi utama adalah "kategori", prioritaskan berdasarkan kategori,
            // lalu keperluan, acara, jumlah, dan terakhir tanggal terbaru.
            [option, "keperluan", "acara", "jumlah", "terbaru"]
        case "acara":
            // Jika opsi utama adalah "acara", prioritaskan berdasarkan acara,
            // lalu keperluan, kategori, jumlah, dan terakhir tanggal terbaru.
            [option, "keperluan", "kategori", "jumlah", "terbaru"]
        case "keperluan":
            // Jika opsi utama adalah "keperluan", prioritaskan berdasarkan keperluan,
            // lalu acara, kategori, jumlah, dan terakhir tanggal terbaru.
            [option, "acara", "kategori", "jumlah", "terbaru"]
        case "jumlah":
            // Jika opsi utama adalah "jumlah", prioritaskan berdasarkan jumlah,
            // lalu acara, kategori, jenis transaksi, dan terakhir tanggal terbaru.
            [option, "acara", "kategori", "transaksi", "terbaru"]
        case "transaksi":
            // Jika opsi utama adalah "transaksi", prioritaskan berdasarkan jenis transaksi,
            // lalu acara, keperluan, jumlah, dan terakhir tanggal terbaru.
            [option, "acara", "keperluan", "jumlah", "terbaru"]
        case "bertanda":
            // Jika opsi utama adalah "bertanda", prioritaskan item yang ditandai,
            // lalu berdasarkan tanggal terbaru, keperluan, acara, kategori, dan terakhir jumlah.
            [option, "terbaru", "keperluan", "acara", "kategori", "jumlah"]
        default:
            // Untuk opsi lain yang tidak secara eksplisit didefinisikan,
            // gunakan opsi itu sebagai kriteria utama, diikuti oleh "jumlah".
            [option, "jumlah"]
        }
    }

    // MARK: - Insertion Functions

    /// Menentukan apakah sebuah `new` Entity harus disisipkan **sebelum** sebuah `existing` Entity
    /// dalam daftar yang diurutkan, berdasarkan serangkaian kriteria pengurutan yang diberikan.
    ///
    /// Fungsi ini sangat penting untuk mempertahankan urutan yang benar saat menyisipkan
    /// item baru ke dalam daftar yang sudah diurutkan (misalnya, dalam operasi `insert` atau
    /// `move` pada `collectionView` atau `tableView` yang sudah diurutkan).
    ///
    /// - Parameters:
    ///   - existing: Objek `Entity` yang sudah ada di dalam daftar (item yang sedang dibandingkan).
    ///   - new: Objek `Entity` baru yang akan disisipkan ke dalam daftar.
    ///   - criteria: Sebuah array `String` yang berisi nama-nama kriteria pengurutan.
    ///     Urutan kriteria dalam array ini menentukan prioritas pengurutan (kriteria pertama memiliki prioritas tertinggi).
    ///     Kriteria ini harus konsisten dengan yang digunakan dalam fungsi pengurutan lainnya.
    ///
    /// - Returns:
    ///   - `true` jika `new` Entity harus disisipkan **sebelum** `existing` Entity.
    ///   - `false` jika `new` Entity harus disisipkan **setelah** atau pada posisi yang sama dengan `existing` Entity.
    func shouldInsertBefore(_ existing: Entity, _ new: Entity, criteria: [String]) -> Bool {
        // Iterasi melalui setiap kriteria pengurutan yang diberikan.
        // Perbandingan dilakukan secara berurutan; kriteria yang muncul lebih dulu
        // dalam array `criteria` akan memiliki prioritas lebih tinggi.
        for criterion in criteria {
            switch criterion {
            case "terbaru":
                // Kriteria: Tanggal Terbaru (Descending)
                // `new` harus di depan `existing` jika `new` lebih baru dari `existing`.
                let dateExisting = existing.tanggal?.timeIntervalSince1970 ?? 0
                let dateNew = new.tanggal?.timeIntervalSince1970 ?? 0
                if dateExisting != dateNew {
                    // `new` harus disisipkan sebelum `existing` jika tanggal `new` lebih baru (lebih besar)
                    // dari tanggal `existing`, karena kita mengurutkan dari terbaru ke terlama.
                    return dateNew > dateExisting
                }

            case "terlama":
                // Kriteria: Tanggal Terlama (Ascending)
                // `new` harus di depan `existing` jika `new` lebih lama dari `existing`.
                let dateExisting = existing.tanggal?.timeIntervalSince1970 ?? 0
                let dateNew = new.tanggal?.timeIntervalSince1970 ?? 0
                if dateExisting != dateNew {
                    // `new` harus disisipkan sebelum `existing` jika tanggal `new` lebih lama (lebih kecil)
                    // dari tanggal `existing`, karena kita mengurutkan dari terlama ke terbaru.
                    return dateNew < dateExisting
                }

            case "kategori":
                // Kriteria: Kategori (Alfabetis Ascending)
                // `new` harus di depan `existing` jika kategori `new` secara alfabetis lebih kecil.
                let kategoriExisting = existing.kategori?.lowercased() ?? ""
                let kategoriNew = new.kategori?.lowercased() ?? ""
                if kategoriExisting != kategoriNew {
                    // `new` harus disisipkan sebelum `existing` jika kategori `new` secara alfabetis
                    // lebih kecil (datang lebih dulu) dari kategori `existing`.
                    return kategoriNew < kategoriExisting
                }

            case "acara":
                // Kriteria: Acara (Alfabetis Ascending)
                // `new` harus di depan `existing` jika acara `new` secara alfabetis lebih kecil.
                let acaraExisting = existing.acara?.lowercased() ?? ""
                let acaraNew = new.acara?.lowercased() ?? ""
                if acaraExisting != acaraNew {
                    // `new` harus disisipkan sebelum `existing` jika acara `new` secara alfabetis
                    // lebih kecil (datang lebih dulu) dari acara `existing`.
                    return acaraNew < acaraExisting
                }

            case "keperluan":
                // Kriteria: Keperluan (Alfabetis Ascending)
                // `new` harus di depan `existing` jika keperluan `new` secara alfabetis lebih kecil.
                let keperluanExisting = existing.keperluan?.lowercased() ?? ""
                let keperluanNew = new.keperluan?.lowercased() ?? ""
                if keperluanExisting != keperluanNew {
                    // `new` harus disisipkan sebelum `existing` jika keperluan `new` secara alfabetis
                    // lebih kecil (datang lebih dulu) dari keperluan `existing`.
                    return keperluanNew < keperluanExisting
                }

            case "jumlah":
                // Kriteria: Jumlah (Ascending)
                // `new` harus di depan `existing` jika jumlah `new` lebih kecil.
                let jumlahExisting = existing.jumlah
                let jumlahNew = new.jumlah
                if jumlahExisting != jumlahNew {
                    // `new` harus disisipkan sebelum `existing` jika jumlah `new` lebih kecil
                    // dari jumlah `existing`.
                    return jumlahNew < jumlahExisting
                }

            case "transaksi":
                // Kriteria: Jenis Transaksi (Custom Order)
                // `new` harus di depan `existing` jika jenis transaksi `new` memiliki prioritas lebih tinggi.
                let jenisExisting = existing.jenis?.lowercased() ?? ""
                let jenisNew = new.jenis?.lowercased() ?? ""
                if jenisExisting != jenisNew {
                    // Definisikan urutan prioritas untuk jenis transaksi.
                    let order = ["pemasukan": 0, "pengeluaran": 1, "lainnya": 2]
                    let orderExisting = order[jenisExisting] ?? 3 // Default ke 3 jika tidak dikenali.
                    let orderNew = order[jenisNew] ?? 3 // Default ke 3 jika tidak dikenali.
                    // `new` harus disisipkan sebelum `existing` jika urutan prioritas `new` lebih kecil
                    // (memiliki prioritas lebih tinggi) dari `existing`.
                    return orderNew < orderExisting
                }

            case "bertanda":
                // Kriteria: Bertanda (Prioritaskan True)
                // `new` harus di depan `existing` jika `new` ditandai dan `existing` tidak.
                let ditandaiExisting = existing.ditandai
                let ditandaiNew = new.ditandai
                if ditandaiExisting != ditandaiNew {
                    // `new` harus disisipkan sebelum `existing` jika `new` ditandai (true)
                    // dan `existing` tidak ditandai (false).
                    return ditandaiNew && !ditandaiExisting
                }

            default:
                // Jika kriteria tidak dikenali, lewati dan lanjutkan ke kriteria berikutnya.
                break
            }
        }
        // Jika semua kriteria dibandingkan dan tidak ada perbedaan yang ditemukan,
        // maka `new` harus disisipkan setelah `existing` (atau di akhir jika ini adalah item terakhir).
        return false
    }

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
        // Dapatkan kriteria pengurutan yang relevan berdasarkan opsi pengurutan yang sedang aktif.
        let criteria = getSortingCriteria(for: currentSortOption)

        // Temukan indeks pertama di mana elemen yang sudah ada (`existingElement`)
        // harus ditempatkan setelah `element` baru, yang berarti `element` baru
        // harus disisipkan sebelum `existingElement` tersebut.
        // Jika tidak ada elemen yang memenuhi kriteria, berarti `element` baru harus di akhir.
        return data.firstIndex { existingElement in
            shouldInsertBefore(existingElement, element, criteria: criteria)
        } ?? data.endIndex
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
        // Dapatkan kriteria pengurutan yang relevan berdasarkan opsi pengurutan yang sedang aktif.
        let criteria = getSortingCriteria(for: currentSortOption)

        // Temukan indeks pertama di mana elemen yang sudah ada (`existingElement`)
        // harus ditempatkan setelah `element` baru, yang berarti `element` baru
        // harus disisipkan sebelum `existingElement` tersebut.
        // Jika tidak ada elemen yang memenuhi kriteria, berarti `element` baru harus di akhir.
        return array.firstIndex { existingElement in
            shouldInsertBefore(existingElement, element, criteria: criteria)
        } ?? array.endIndex
    }
}
