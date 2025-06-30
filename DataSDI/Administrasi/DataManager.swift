//
//  DataManager.swift //  Administrasi
//
//  Created by Bismillah on 13/11/23.
//

import CoreData
import Foundation
import SQLite3

/// Pengelola baca/tulis database CoreData.
///
/// Logika pengelolaan data di dalam file sqlite yang dibuat CoreData.
/// Menyalin file ke direktori ~/Application Support/DataSDI/ untuk editing.
/// *Checkpoint* ketika aplikasi akan ditutup untuk integrasi file WAL dan SHM ke file sqlite
/// dan menyimpannya di direktori ~/Documents/DataSDI/
class DataManager {
    /// Singleton untuk mengelola data Administrasi
    static let shared = DataManager()

    /// Instans FileManager.default
    let fileManager = FileManager.default

    /// folder Application Support di ~/Library
    static let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

    /// url ke file Data Manager.sqlite di folder ~/Library/Apllication Support/
    static let sourceURL = {
        #if DEBUG
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("DataSDI/Data Manager.sqlite")
        #else
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Data SDI/Data Manager.sqlite")
        #endif
    }()
    /// url ke file Administrasi.sdi di folder dokumen
    static let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Data SDI/Administrasi.sdi")

    /// Private initializer untuk singleton DataManager.shared
    private init() {}

    /// Notifikasi data administrasi jika berubah.
    static let dataDidChangeNotification = NSNotification.Name("DataManagerDataDidChange")
    /// Notifikasi data administrasi jika diperbarui.
    static let dataDieditNotif = NSNotification.Name("DataDiedit")
    /// Notifikasi data administrasi jika dihapus.
    static let dataDihapusNotif = NSNotification.Name("DataDihapus")
    /// Notifikasi data administrasi jika ditambah.
    static let dataDitambahNotif = NSNotification.Name("DataDitambah")

    /// UndoManager untuk TransaksiView.
    public var myUndoManager: UndoManager = .init()

    /// Sebuah instans `NSManagedObjectContext` yang dikonfigurasi untuk operasi di *background*.
    ///
    /// Konteks ini diambil dari `persistentContainer` milik `AppDelegate` dan diatur untuk
    /// secara otomatis menggabungkan perubahan dari konteks induknya (`automaticallyMergesChangesFromParent = true`).
    /// Ini sangat berguna untuk melakukan operasi Core Data yang intensif tanpa memblokir *thread* utama UI,
    /// memastikan aplikasi tetap responsif.
    ///
    /// - Catatan:
    ///   - Mengasumsikan bahwa `NSApplication.shared.delegate` dapat di-*cast* ke `AppDelegate`.
    ///   - `AppDelegate` harus memiliki properti `persistentContainer` yang mengembalikan `NSPersistentContainer`.
    ///   - Penggunaan konteks *background* ini membantu menjaga performa aplikasi tetap lancar
    ///     saat melakukan *fetch* atau menyimpan data dalam jumlah besar.
    let managedObjectContext: NSManagedObjectContext = {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    /// Memeriksa dan menetapkan UUID ke entitas yang belum memilikinya.
    ///
    /// Fungsi ini melakukan *fetch* semua `Entity` dari Core Data yang properti `id`-nya adalah `nil`.
    /// Tergantung pada nilai parameter `postNotification`, fungsi ini akan melakukan salah satu dari dua hal:
    ///
    /// 1.  **Jika `postNotification` adalah `true` (default):**
    ///     Jika ada entitas dengan `id` `nil`, fungsi ini akan memposting notifikasi
    ///     `.didAssignUUID`. Ini berguna untuk memberi tahu bagian lain dari aplikasi bahwa
    ///     ada entitas yang perlu diperbarui UUID-nya.
    ///
    /// 2.  **Jika `postNotification` adalah `false`:**
    ///     Fungsi ini akan mengiterasi semua entitas yang `id`-nya `nil`, menetapkan `UUID()` baru
    ///     ke masing-masing entitas, dan kemudian menyimpan perubahan ke Core Data. Ini adalah
    ///     mekanisme untuk memperbaiki data yang tidak memiliki UUID.
    ///
    /// Penanganan kesalahan dasar disertakan, dan kesalahan akan dicetak ke konsol dalam mode `DEBUG`.
    ///
    /// - Parameter postNotification: Sebuah `Bool` yang menentukan perilaku fungsi.
    ///   - `true`: Hanya memposting notifikasi jika ditemukan entitas tanpa UUID.
    ///   - `false`: Menetapkan UUID dan menyimpan perubahan ke entitas yang tidak memilikinya.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.managedObjectContext` untuk interaksi Core Data.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` dengan properti `id` yang bertipe `UUID?`.
    ///   - `.didAssignUUID` adalah `Notification.Name` yang telah didefinisikan sebelumnya di dalam Folder /Main/Extensions/Notification.
    func checkAndAssignUUIDIfNeeded(postNotification: Bool = true) {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == nil")

        do {
            let entitiesWithNilID = try DataManager.shared.managedObjectContext.fetch(fetchRequest)
            if postNotification {
                if !entitiesWithNilID.isEmpty {
                    NotificationCenter.default.post(name: .didAssignUUID, object: nil)
                }
            } else {
                if !entitiesWithNilID.isEmpty {
                    for entity in entitiesWithNilID {
                        entity.id = UUID()
                    }
                    try DataManager.shared.managedObjectContext.save()
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menambahkan entitas data baru ke Core Data dengan detail yang diberikan.
    ///
    /// Fungsi ini membuat objek `Entity` baru di dalam `NSManagedObjectContext` yang dikelola oleh `DataManager.shared`.
    /// Semua properti yang relevan dari entitas diatur menggunakan nilai parameter yang disediakan.
    /// Setelah entitas diatur, perubahan disimpan ke Core Data. Jika penyimpanan berhasil,
    /// notifikasi `DataManager.dataDitambahNotif` akan diposting, berisi entitas yang baru ditambahkan.
    ///
    /// Selain itu, fungsi ini memperbarui koleksi global dari string unik untuk **kategori**, **acara**, dan **keperluan**
    /// yang disimpan dalam `ReusableFunc`. Ini melibatkan pemisahan string input berdasarkan spasi,
    /// membersihkan entri, dan menambahkan versi yang dikapitalisasi dan dipangkas ke set yang sesuai.
    ///
    /// - Parameters:
    ///   - id: `UUID` unik untuk entitas data.
    ///   - jenis: `String` yang menunjukkan jenis data (misalnya, "Pemasukan", "Pengeluaran").
    ///   - dari: `String` yang menunjukkan sumber atau asal data.
    ///   - jumlah: `Double` yang menunjukkan nilai numerik data.
    ///   - kategori: `String` yang menunjukkan kategori data.
    ///   - acara: `String` yang menunjukkan acara terkait data.
    ///   - keperluan: `String` opsional yang menunjukkan keperluan data.
    ///   - tanggal: `Date` yang menunjukkan tanggal data.
    ///   - bulan: `Int64` yang menunjukkan bulan data.
    ///   - tahun: `Int64` yang menunjukkan tahun data.
    ///   - tanda: `Bool` yang menunjukkan status penandaan data.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.managedObjectContext` untuk manajemen Core Data.
    ///   - `Entity` diasumsikan sebagai kelas `NSManagedObject` yang dihasilkan dari model Core Data.
    ///   - `DataManager.dataDitambahNotif` diasumsikan sebagai `Notification.Name` yang telah didefinisikan.
    ///   - `ReusableFunc.kategori`, `ReusableFunc.acara`, dan `ReusableFunc.keperluan` diasumsikan sebagai
    ///     properti `Set<String>` statis atau global yang dapat diakses untuk menyimpan string unik.
    ///   - Kesalahan saat menyimpan ke Core Data akan dicetak ke konsol dalam mode `DEBUG`.
    func addData(id: UUID, jenis: String, dari: String, jumlah: Double, kategori: String, acara: String, keperluan: String?, tanggal: Date, bulan: Int64, tahun: Int64, tanda: Bool) {
        if let entity = NSEntityDescription.entity(forEntityName: "Entity", in: DataManager.shared.managedObjectContext) {
            let data = NSManagedObject(entity: entity, insertInto: DataManager.shared.managedObjectContext) as! Entity
            // Setel nilai-nilai atribut sesuai kebutuhan
            data.id = id
            data.jenis = jenis
            data.dari = dari
            data.jumlah = jumlah
            data.kategori = kategori
            data.acara = acara
            data.keperluan = keperluan
            data.tanggal = tanggal
            data.bulan = bulan
            data.tahun = tahun
            data.ditandai = tanda
            // Simpan perubahan ke Core Data
            do {
                try managedObjectContext.save()
                NotificationCenter.default.post(name: DataManager.dataDitambahNotif, object: nil, userInfo: ["data": data])
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
            var kategoriW: Set<String> = []
            var acaraW: Set<String> = []
            var keperluanW: Set<String> = []
            kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            kategoriW.insert(kategori.capitalizedAndTrimmed())
            ReusableFunc.kategori.formUnion(kategoriW)

            acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            acaraW.insert(acara.capitalizedAndTrimmed())
            ReusableFunc.acara.formUnion(acaraW)

            let perlu = keperluan ?? ""
            keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            keperluanW.insert(perlu.capitalizedAndTrimmed())
            ReusableFunc.keperluan.formUnion(keperluanW)
        }
    }

    /// Seperti fungsi `addData(id:)` namun ini untuk data yang benar-benar baru dan memasukkan id UUID secara acak.
    /// - Returns: Ini adalah UUID yang dibuat yang bisa digunakan untuk proses undo/redo penambahan data di administrasi.
    func addData(jenis: String, dari: String, jumlah: Double, kategori: String, acara: String, keperluan: String?, tanggal: Date, bulan: Int64, tahun: Int64, tanda: Bool) -> UUID? {
        if let entity = NSEntityDescription.entity(forEntityName: "Entity", in: DataManager.shared.managedObjectContext) {
            let data = NSManagedObject(entity: entity, insertInto: DataManager.shared.managedObjectContext) as! Entity
            // Setel nilai-nilai atribut sesuai kebutuhan
            data.id = UUID()
            data.jenis = jenis
            data.dari = dari
            data.jumlah = jumlah
            data.kategori = kategori
            data.acara = acara
            data.keperluan = keperluan
            data.tanggal = tanggal
            data.bulan = bulan
            data.tahun = tahun
            data.ditandai = tanda
            // Simpan perubahan ke Core Data
            do {
                try managedObjectContext.save()
                NotificationCenter.default.post(name: DataManager.dataDitambahNotif, object: nil, userInfo: ["data": data])
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
            var kategoriW: Set<String> = []
            var acaraW: Set<String> = []
            var keperluanW: Set<String> = []
            kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            kategoriW.insert(kategori.capitalizedAndTrimmed())
            ReusableFunc.kategori.formUnion(kategoriW)

            acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            acaraW.insert(acara.capitalizedAndTrimmed())
            ReusableFunc.acara.formUnion(acaraW)

            let perlu = keperluan ?? ""
            keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            keperluanW.insert(perlu.capitalizedAndTrimmed())
            ReusableFunc.keperluan.formUnion(keperluanW)

            return data.id
        }
        return nil
    }

    /// Fungsi untuk mengambil data dari Core Data
    func getEntityForAutoCompletion() -> [AutoCompletion] {
        var result: [AutoCompletion] = []
        if let fetchedData = DataManager.shared.fetchAutoCompletionData() {
            for data in fetchedData {
                var autoCompleteItem = AutoCompletion()
                autoCompleteItem.kategori = data["kategori"] as? String ?? ""
                autoCompleteItem.acara = data["acara"] as? String ?? ""
                autoCompleteItem.keperluan = data["keperluan"] as? String ?? ""
                result.append(autoCompleteItem)
            }
        } else {}
        return result
    }

    /// Mengambil data yang relevan untuk fitur pelengkapan otomatis dari Core Data.
    ///
    /// Fungsi ini melakukan *fetch* semua `Entity` dari Core Data, secara spesifik hanya mengambil
    /// properti `kategori`, `acara`, dan `keperluan`. Hasil *fetch* dikembalikan sebagai array
    /// dari kamus (`[[String: Any]]`), di mana setiap kamus mewakili satu entitas dan berisi
    /// nilai-nilai untuk properti yang diminta.
    ///
    /// Fungsi ini juga mencoba untuk mengubah hasil *fetch* menjadi array objek `AutoCompletion`
    /// meskipun pada akhirnya mengembalikan `result` asli dari *fetch* yang bertipe `[[String: Any]]`.
    ///
    /// - Returns: Sebuah array opsional `[[String: Any]]` yang berisi kamus data
    ///            (`kategori`, `acara`, `keperluan`) dari setiap entitas yang berhasil diambil.
    ///            Mengembalikan `nil` jika *fetch* gagal atau hasilnya tidak dapat di-*cast*
    ///            dengan benar.
    ///
    /// - Catatan:
    ///   - `managedObjectContext` diasumsikan sebagai `NSManagedObjectContext` yang tersedia
    ///     untuk melakukan operasi Core Data.
    ///   - `Entity` diasumsikan sebagai nama entitas Core Data yang valid.
    ///   - `AutoCompletion` diasumsikan sebagai struktur atau kelas yang memiliki properti
    ///     `kategori`, `acara`, dan `keperluan` (meskipun bagian ini dari kode tampaknya tidak
    ///     digunakan untuk nilai kembalian).
    ///   - Kesalahan saat *fetch* akan dicetak ke konsol dalam mode `DEBUG`.
    func fetchAutoCompletionData() -> [[String: Any]]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")

        // Mengatur agar hanya mengambil kolom `kategori`, `acara`, dan `keperluan`
        fetchRequest.propertiesToFetch = ["kategori", "acara", "keperluan"]
        fetchRequest.resultType = .dictionaryResultType // Agar hasil berupa dictionary

        do {
            let fetchedResults = try managedObjectContext.fetch(fetchRequest)
            guard let result = fetchedResults as? [[String: Any]] else {
                return nil
            }

            var autoCompleteItems: [AutoCompletion] = []

            for data in result {
                var autoCompleteItem = AutoCompletion()
                autoCompleteItem.kategori = data["kategori"] as? String ?? ""
                autoCompleteItem.acara = data["acara"] as? String ?? ""
                autoCompleteItem.keperluan = data["keperluan"] as? String ?? ""
                autoCompleteItems.append(autoCompleteItem)
            }
            return result
        } catch let error as NSError {
            #if DEBUG
                print(error)
            #endif
            return nil
        }
    }

    /// Ini adalah varian spesifik dari operasi pengambilan data sesuai dengan UUID yang diberikan; untuk mengambil *semua* entitas,
    /// lihat ``fetchData()``
    func fetchData(by id: UUID) -> Entity? {
        let fetchRequest = NSFetchRequest<Entity>(entityName: "Entity")

        // Menambahkan predicate untuk filter berdasarkan id
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        // Menambahkan sort descriptor untuk menyortir data berdasarkan tanggal dari terlama ke terbaru
        let sortDescriptor = NSSortDescriptor(key: "tanggal", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            // Mengambil entitas pertama yang sesuai dengan ID
            return try managedObjectContext.fetch(fetchRequest).first
        } catch let error as NSError {
            #if DEBUG
                print(error)
            #endif
            return nil
        }
    }

    /// Mengambil semua entitas dari Core Data dan mengembalikannya dalam urutan tanggal menaik.
    ///
    /// Fungsi ini melakukan operasi *fetch* secara sinkron pada `managedObjectContext` yang dibagikan
    /// oleh `DataManager`. Semua `Entity` akan diambil dan diurutkan berdasarkan properti `tanggal`
    /// dari yang paling lama ke yang paling baru.
    ///
    /// - Returns: Sebuah array `[Entity]` yang berisi semua entitas yang berhasil diambil dari Core Data.
    ///            Mengembalikan array kosong jika tidak ada data atau jika terjadi kesalahan saat *fetch*.
    ///
    /// - Catatan:
    ///   - Fungsi ini menggunakan `DataManager.shared.managedObjectContext` yang diasumsikan
    ///     telah dikonfigurasi dengan benar untuk mengakses penyimpanan Core Data.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` yang dihasilkan dari model Core Data
    ///     dengan properti `tanggal`.
    ///   - Kesalahan saat *fetch* akan dicetak ke konsol dalam mode `DEBUG`.
    func fetchData() -> [Entity] {
        var entities: [Entity] = []
        DataManager.shared.managedObjectContext.performAndWait {
            let fetchRequest = NSFetchRequest<Entity>(entityName: "Entity")
            // Menambahkan sort descriptor untuk menyortir data berdasarkan tanggal dari terlama ke terbaru
            let sortDescriptor = NSSortDescriptor(key: "tanggal", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            do {
                entities = try DataManager.shared.managedObjectContext.fetch(fetchRequest)
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
        }

        return entities
    }

    /// Menandai (atau membatalkan tanda) suatu entitas tanpa memposting notifikasi.
    ///
    /// Fungsi ini memperbarui properti `ditandai` dari `entity` yang diberikan ke nilai `tertandai` yang ditentukan.
    /// Perubahan ini dilakukan dalam blok `performAndWait` pada `managedObjectContext` untuk memastikan
    /// operasi yang aman terhadap *thread*. Jika status penandaan berubah, `UUID` entitas akan
    /// dimasukkan ke dalam set `uuid` (meskipun set ini tidak digunakan setelahnya di dalam fungsi).
    /// Perubahan kemudian disimpan ke Core Data. Kesalahan selama proses penyimpanan akan dicetak ke konsol.
    ///
    /// - Parameters:
    ///   - entity: Objek `Entity` yang akan ditandai atau dibatalkan tandanya.
    ///   - tertandai: Nilai `Bool` yang menunjukkan apakah entitas harus ditandai (`true`)
    ///                atau dibatalkan tandanya (`false`).
    ///
    /// - Catatan:
    ///   - `managedObjectContext` diasumsikan sebagai `NSManagedObjectContext` yang tersedia.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` yang dihasilkan dari model Core Data
    ///     dengan properti `ditandai` (bertipe `Bool`) dan `id` (bertipe `UUID?`).
    ///   - Fungsi ini secara eksplisit *tidak* memposting notifikasi setelah perubahan,
    ///     berbeda dengan beberapa operasi data lainnya.
    func tandaiDataTanpaNotif(_ entity: Entity, tertandai: Bool) {
        var uuid: Set<UUID> = []
        managedObjectContext.performAndWait {
            if entity.ditandai != tertandai {
                entity.ditandai = tertandai
                uuid.insert(entity.id ?? UUID())
            }
            do {
                try managedObjectContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    /// Mengedit properti-properti dari entitas Core Data yang sudah ada.
    ///
    /// Fungsi ini memperbarui properti-properti dari objek `Entity` yang diberikan (`entity`)
    /// dengan nilai-nilai baru yang disediakan sebagai parameter. Setelah semua properti diatur,
    /// perubahan disimpan ke `managedObjectContext`. Jika penyimpanan berhasil, notifikasi
    /// `DataManager.dataDiperbaruiNotif` akan diposting, memberi tahu bagian lain dari aplikasi
    /// tentang perubahan yang telah terjadi.
    ///
    /// Selain itu, fungsi ini memperbarui koleksi global dari string unik untuk **kategori**, **acara**,
    /// dan **keperluan** yang disimpan dalam `ReusableFunc`. Ini melibatkan pemisahan string input
    /// berdasarkan spasi, membersihkan entri, dan menambahkan versi yang dikapitalisasi dan dipangkas
    /// ke set yang sesuai.
    ///
    /// - Parameters:
    ///   - entity: Objek `Entity` yang akan diedit. Ini harus merupakan entitas yang sudah ada dan diambil dari Core Data.
    ///   - jenis: `String` baru untuk jenis data (misalnya, "Pemasukan", "Pengeluaran").
    ///   - dari: `String` baru untuk sumber atau asal data.
    ///   - jumlah: `Double` baru untuk nilai numerik data.
    ///   - kategori: `String` baru untuk kategori data.
    ///   - acara: `String` baru untuk acara terkait data.
    ///   - keperluan: `String` opsional baru untuk keperluan data.
    ///   - tanggal: `Date` baru untuk tanggal data.
    ///   - bulan: `Int64` baru untuk bulan data.
    ///   - tahun: `Int64` baru untuk tahun data.
    ///   - tanda: `Bool` baru untuk status penandaan data.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `managedObjectContext` (diasumsikan `DataManager.shared.managedObjectContext`)
    ///     untuk interaksi Core Data.
    ///   - `DataManager.dataDiperbaruiNotif` diasumsikan sebagai `Notification.Name` yang telah didefinisikan.
    ///   - `ReusableFunc.kategori`, `ReusableFunc.acara`, dan `ReusableFunc.keperluan` diasumsikan sebagai
    ///     properti `Set<String>` statis atau global yang dapat diakses untuk menyimpan string unik.
    ///   - Kesalahan saat menyimpan ke Core Data akan dicetak ke konsol dalam mode `DEBUG`.
    func editData(entity: Entity, jenis: String, dari: String, jumlah: Double, kategori: String, acara: String, keperluan: String?, tanggal: Date, bulan: Int64, tahun: Int64, tanda: Bool) {
        // Setel nilai-nilai atribut sesuai kebutuhan
        if entity.jenis != jenis {
            entity.jenis = jenis
        }

        if entity.kategori != kategori {
            entity.kategori = kategori
        }

        if entity.acara != acara {
            entity.acara = acara
        }
        if entity.keperluan != keperluan {
            entity.keperluan = keperluan
        }

        if entity.jumlah != jumlah {
            entity.jumlah = jumlah
        }

        if entity.ditandai != tanda {
            entity.ditandai = tanda
        }

        // Simpan perubahan ke Core Data
        do {
            try managedObjectContext.save()

        } catch let error as NSError {
            #if DEBUG
                print(error)
            #endif
        }
        var kategoriW: Set<String> = []
        var acaraW: Set<String> = []
        var keperluanW: Set<String> = []
        kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        kategoriW.insert(kategori.capitalizedAndTrimmed())
        ReusableFunc.kategori.formUnion(kategoriW)

        acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        acaraW.insert(acara.capitalizedAndTrimmed())
        ReusableFunc.acara.formUnion(acaraW)

        let perlu = keperluan ?? ""
        keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        keperluanW.insert(perlu.capitalizedAndTrimmed())
        ReusableFunc.keperluan.formUnion(keperluanW)
    }

    /// Menghitung total pemasukan, total pengeluaran, dan saldo akhir dari semua data yang tersimpan.
    ///
    /// Fungsi ini mengambil semua `Entity` dari Core Data dan mengiterasinya untuk menjumlahkan
    /// nilai `jumlah` berdasarkan `jenis` ("Pemasukan" atau "Pengeluaran"). Perhitungan dilakukan
    /// secara sinkron pada `managedObjectContext` untuk memastikan akses data yang aman.
    /// Saldo akhir dihitung sebagai selisih antara total pemasukan dan total pengeluaran.
    ///
    /// - Returns: Sebuah *tuple* `(Double, Double, Double)` yang berisi:
    ///   - Elemen pertama: **Total Pemasukan** (`totalMasuk`).
    ///   - Elemen kedua: **Total Pengeluaran** (`totalKeluar`).
    ///   - Elemen ketiga: **Saldo Akhir** (`saldo`).
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.fetchData()` untuk mengambil semua entitas.
    ///   - `Entity` diasumsikan memiliki properti `jenis` (bertipe `String`) dan `jumlah` (bertipe `Double`).
    func calculateSaldo() -> (Double, Double, Double) {
        var totalMasuk = 0.0
        var totalKeluar = 0.0
        DataManager.shared.managedObjectContext.performAndWait {
            let entities = DataManager.shared.fetchData()

            // Iterasi melalui setiap data untuk menghitung total masuk dan keluar
            for entity in entities {
                // Check if entity.jumlah is not nil
                if entity.jenis == "Pemasukan" {
                    totalMasuk += entity.jumlah
                } else if entity.jenis == "Pengeluaran" {
                    totalKeluar += entity.jumlah
                }
            }
        }

        let saldo = totalMasuk - totalKeluar

        return (totalMasuk, totalKeluar, saldo)
    }

    /// Menyalin file *database* Core Data utama aplikasi ke direktori Dokumen.
    ///
    /// Fungsi ini dirancang untuk membuat salinan *database* yang lengkap dan konsisten.
    /// Ini memastikan semua perubahan tertunda disimpan dan semua transaksi dari
    /// *Write-Ahead Logging* (WAL) dan file Shared Memory (SHM) ditulis ke dalam
    /// file `.sqlite` utama sebelum proses penyalinan.
    ///
    /// - Catatan:
    ///   - Memeriksa keberadaan *database* sumber (`DataManager.sourceURL`).
    ///   - Menyimpan semua perubahan yang belum disimpan dalam `managedObjectContext`.
    ///   - Menjalankan `PRAGMA wal_checkpoint(FULL);` menggunakan SQLite C API untuk
    ///     mengintegrasikan data WAL/SHM ke *database* utama.
    ///   - Merefresh semua objek dalam konteks untuk membersihkan *cache*.
    ///   - Menghapus salinan *database* lama di direktori tujuan (`DataManager.destURL`) jika ada.
    ///   - Menyalin file `.sqlite` utama ke lokasi tujuan.
    ///   - Mencetak pesan keberhasilan atau kesalahan ke konsol (terutama dalam mode `DEBUG`).
    func copyDatabaseToDocuments() {
        guard FileManager.default.fileExists(atPath: DataManager.sourceURL.path) else {
            print("❌ Database sumber tidak ditemukan.")
            return
        }

        let context = managedObjectContext
        do {
            // Simpan semua perubahan sebelum menyalin database
            if context.hasChanges {
                #if DEBUG
                    print("📝 Menyimpan perubahan ke database...")
                #endif
                try context.save()
                #if DEBUG
                    print("✅ Perubahan berhasil disimpan.")
                #endif
            }

            // Pastikan semua transaksi dari WAL masuk ke database utama
            print("🔄 Memindahkan transaksi WAL ke .sqlite...")
            let sqlStatement = "PRAGMA wal_checkpoint(FULL);"

            guard let sqliteURL = context.persistentStoreCoordinator?.persistentStores.first?.url?.path else {
                #if DEBUG
                    print("❌ Tidak bisa menemukan database.")
                #endif
                return
            }

            var db: OpaquePointer?
            if sqlite3_open_v2(sqliteURL, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
                var statement: OpaquePointer? = nil
                if sqlite3_prepare_v2(db, sqlStatement, -1, &statement, nil) == SQLITE_OK {
                    if sqlite3_step(statement) == SQLITE_DONE {
                        print("✅ WAL checkpoint berhasil, semua transaksi tersimpan.")
                    } else {
                        #if DEBUG
                            print("❌ Error menjalankan WAL checkpoint.")
                        #endif
                    }
                } else {
                    #if DEBUG
                        print("❌ Error menyiapkan statement SQLite.")
                    #endif
                }
                sqlite3_finalize(statement)
                sqlite3_close(db)
            } else {
                print("❌ Error membuka database SQLite.")
            }

            // Refresh agar tidak ada cache yang tertinggal
            context.refreshAllObjects()

            // Hapus salinan lama jika ada
            if FileManager.default.fileExists(atPath: DataManager.destURL.path) {
                try FileManager.default.removeItem(at: DataManager.destURL)
            }

            // Salin database utama `.sqlite`
            try FileManager.default.copyItem(at: DataManager.sourceURL, to: DataManager.destURL)
            
            #if DEBUG
                print("✅ Salinan database berhasil dibuat dan WAL serta SHM dihapus.")
            #endif
        } catch {
            print("❌ Error menyalin database: \(error.localizedDescription)")
        }
    }
}

// MARK: - Properti

/// Sebuah struktur `EntitySnapshot` merepresentasikan salinan data (snapshot) dari sebuah entitas.
///
/// Struktur ini dirancang untuk berfungsi sebagai representasi data entitas yang bersifat nilai (`value type`),
/// cocok untuk digunakan dalam konteks di mana Anda memerlukan salinan data yang tidak terikat
/// langsung ke `NSManagedObjectContext` Core Data. Ini mengimplementasikan protokol `Hashable`,
/// `Comparable`, dan `Equatable` untuk memungkinkan penggunaan dalam koleksi seperti `Set` atau
/// untuk operasi perbandingan dan pengurutan.
///
/// - Catatan Penting:
///   Implementasi `Equatable` (`static func ==`) memiliki overload yang membandingkan `EntitySnapshot`
///   dengan objek `Entity` (Core Data). Hal ini memungkinkan perbandingan langsung antara snapshot
///   dan entitas Core Data yang sebenarnya.
public struct EntitySnapshot: Hashable, Comparable, Equatable {
    /// ID unik entitas. Digunakan sebagai dasar untuk `Hashable` dan *fallback* untuk `Comparable`.
    let id: UUID?
    /// Jenis entitas (misalnya, "Pemasukan", "Pengeluaran").
    let jenis: String?
    /// Sumber atau asal data entitas.
    let dari: String?
    /// Jumlah numerik entitas.
    let jumlah: Double
    /// Kategori entitas.
    let kategori: String?
    /// Acara terkait entitas.
    let acara: String?
    /// Keperluan atau deskripsi tambahan entitas.
    let keperluan: String?
    /// Tanggal entitas. Digunakan sebagai kriteria pengurutan utama untuk `Comparable`.
    let tanggal: Date?
    /// Bulan entitas (sebagai `Int64`).
    let bulan: Int64?
    /// Tahun entitas (sebagai `Int64`).
    let tahun: Int64?
    /// Status penandaan entitas.
    let ditandai: Bool?

    // MARK: - Implementasi Protokol Comparable

    /// Mengimplementasikan operator `<` untuk membandingkan dua `EntitySnapshot`.
    ///
    /// Pengurutan utama dilakukan berdasarkan properti `tanggal`. Jika `tanggal` tidak tersedia
    /// untuk kedua entitas, pengurutan akan dilakukan berdasarkan representasi string dari `id` (`uuidString`).
    ///
    /// - Parameters:
    ///   - lhs: `EntitySnapshot` di sisi kiri operator.
    ///   - rhs: `EntitySnapshot` di sisi kanan operator.
    /// - Returns: `true` jika `lhs` dianggap "kurang dari" `rhs`, `false` jika sebaliknya.
    public static func < (lhs: EntitySnapshot, rhs: EntitySnapshot) -> Bool {
        // Sorting berdasarkan tanggal jika tersedia
        if let lhsTanggal = lhs.tanggal, let rhsTanggal = rhs.tanggal {
            return lhsTanggal < rhsTanggal
        } else if let lhsID = lhs.id, let rhsID = rhs.id {
            // Fallback sorting berdasarkan ID jika tanggal tidak tersedia
            return lhsID.uuidString < rhsID.uuidString
        }
        return false // Mengembalikan false jika tidak ada kriteria yang valid untuk perbandingan
    }

    // MARK: - Implementasi Protokol Hashable

    /// Mengimplementasikan `hash(into:)` untuk mendukung protokol `Hashable`.
    ///
    /// Hanya properti `id` yang digunakan untuk menghasilkan nilai *hash*, karena `id` diasumsikan
    /// sebagai pengidentifikasi unik untuk setiap entitas.
    ///
    /// - Parameter hasher: `Hasher` yang digunakan untuk menggabungkan nilai *hash*.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mengimplementasikan operator `==` untuk membandingkan `EntitySnapshot` dengan objek `Entity` Core Data.
    ///
    /// Perbandingan dilakukan berdasarkan beberapa properti utama untuk menentukan kesetaraan.
    ///
    /// - Parameters:
    ///   - lhs: `EntitySnapshot` di sisi kiri operator.
    ///   - rhs: Objek `Entity` Core Data di sisi kanan operator.
    /// - Returns: `true` jika `EntitySnapshot` dan `Entity` dianggap sama berdasarkan properti yang dibandingkan,
    ///            `false` jika sebaliknya.
    static func == (lhs: EntitySnapshot, rhs: Entity) -> Bool {
        lhs.id == rhs.id &&
            lhs.jenis == rhs.jenis &&
            lhs.jumlah == rhs.jumlah &&
            lhs.acara == rhs.acara &&
            lhs.kategori == rhs.kategori &&
            lhs.keperluan == rhs.keperluan &&
            lhs.ditandai == rhs.ditandai
    }

    /// Mengimplementasikan operator `!=` untuk membandingkan `EntitySnapshot` dengan objek `Entity` Core Data.
    ///
    /// Ini adalah kebalikan dari operator `==`.
    ///
    /// - Parameters:
    ///   - lhs: `EntitySnapshot` di sisi kiri operator.
    ///   - rhs: Objek `Entity` Core Data di sisi kanan operator.
    /// - Returns: `true` jika `EntitySnapshot` dan `Entity` dianggap tidak sama, `false` jika sebaliknya.
    static func != (lhs: EntitySnapshot, rhs: Entity) -> Bool {
        !(lhs == rhs)
    }
}

/// Penambahan perbandingan terbalik.
extension Entity {
    static func == (lhs: Entity, rhs: EntitySnapshot) -> Bool {
        rhs == lhs // This uses the implementation above
    }

    static func != (lhs: Entity, rhs: EntitySnapshot) -> Bool {
        !(lhs == rhs)
    }
}
