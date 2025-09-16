# Database

Class yang menyediakan koneksi untuk digunakan berinteraksi dengan file database.

## Overview
![Diagram SQLite dan koneksi database.](SDI-Database)

Ada dua jenis koneksi untuk interaksi dengan file database:
- ``DatabaseController/db`` - Satu Koneksi read/write.
- ``SQLiteConnectionPool/read(_:)`` - Empat koneksi read-only, mendukung pembacaan paralel. Akses dari ``DatabaseManager/shared``.

### SQLite.Swift 

Untuk menggunakan akses paralel untuk fetch, ConnectionPool harus di instantiate terlebih dahulu melalui ``DatabaseManager``.

### Insert:
```swift
// Menggunakan DatabaseController untuk insert
let query = SiswaColumns.tabel.insert(id: 1, nama: "Nama") 
DatabaseController.shared.db.run(query)
```

### Inisialisasi `DatabaseManager`:
```swift
// Tetapkan path ke lokasi file database dengan benar. Contoh folder Data SDI di ~/Dokumen/Data SDI/data.sdi:
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
let db = dataSiswaFolderURL.appendingPathComponent("data.sdi").path
pool = try! SQLiteConnectionPool(path: db, poolSize: 4)
```

### Select menggunakan `DatabaseManager pool`:
```swift
// Menggunakan pool untuk read
let query = SiswaColumns.tabel.filter(SiswaColumns.nama == "Ahmad")
try await DatabaseManager.shared.pool.read { db in
    for row in try db.prepare(query) {
        // Parsing row
    }
}
```

### Select dengan `pool` secara paralel
```swift
// Contoh penggunaan pool untuk operasi paralel
await withTaskGroup(of: Void.self) { group in
    group.addTask {
        try? await DatabaseManager.shared.pool.read { db in
            // Lakukan query pertama di sini
        }
    }
    group.addTask {
        try? await DatabaseManager.shared.pool.read { db in
            // Lakukan query kedua di sini
        }
    }
    // Tambahkan task lainnya sesuai kebutuhan
}
```

## Topics

### Core Data
- ``DataManager``

### SQLite.Swift
- ``ConnectionWorker``
- ``DatabaseController``
- ``DatabaseManager``
- ``SQLiteConnectionPool``

### Kolom Tabel
- ``GuruColumns``
- ``KelasColumns``
- ``JabatanColumns``
- ``MapelColumns``
- ``SiswaColumns``
- ``SiswaKelasColumns``
- ``NilaiSiswaMapelColumns``
- ``PenugasanGuruMapelKelasColumns``

### Monitor File
- ``FileMonitor``
