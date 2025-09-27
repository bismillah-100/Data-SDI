# Siswa View-Model

``SiswaViewModel`` mengelola data siswa untuk ditampilkan di ``SiswaViewController``, menangani logika bisnis, pengambilan data, dan interaksi dengan penyimpanan persisten. Ia terikat erat dengan implementasi protokol ``SiswaDataSource`` (seperti ``PlainSiswaData`` dan ``GroupedSiswaData``) untuk mengabstraksikan pengelolaan data dalam tampilan datar atau terkelompok berdasarkan ``TableViewMode``.

Artikel ini memberikan gambaran umum tentang arsitektur sistem, operasi kunci (insert/delete/update/relocate), mekanisme pembaruan kelas dan status, penguraian clipboard dan pasting, penyisipan siswa tersembunyi, serta pengambilan data dari database persisten. Ini menyoroti bagaimana operasi-operasi ini beradaptasi antara ``TableViewMode/plain`` dan ``TableViewMode/grouped``.

## Gambaran Umum

``SiswaViewModel`` bertindak sebagai sumber kebenaran tunggal untuk data siswa dalam aplikasi. Ia menggunakan protokol ``SiswaDataSource`` untuk memisahkan pengelolaan data dari lapisan tampilan. View model beralih antara dua implementasi sumber data:

- ``PlainSiswaData``: Menyimpan siswa dalam array datar (`[ModelSiswa]`). Ideal untuk daftar sederhana tanpa pengelompokan.
- ``GroupedSiswaData``: Menyimpan siswa dalam array 2D (`[[ModelSiswa]]`), dikelompokkan berdasarkan tingkat kelas atau status (misalnya, aktif, lulus). Termasuk header kelompok dalam perhitungan baris untuk tampilan tabel.

Mode saat ini disimpan di `UserDefaults` dan dapat diatur melalui ``SiswaViewModel/setMode(_:)``. Semua operasi dirutekan melalui properti ``SiswaViewModel/dataSource``, memastikan perilaku yang konsisten terlepas dari mode.

Ketergantungan kunci:
- ``DatabaseController``: Menangani interaksi SQLite untuk penyimpanan persisten.
- `UndoManager`: Mengelola undo/redo untuk pengeditan, diakses melalui ``SiswaViewModel/siswaUndoManager``.
- Publisher dari `Combine` (seperti ``SiswaViewModel/kelasEvent`` dari jenis ``NaikKelasEvent``) untuk memberi tahu komponen UI tentang perubahan kelas dan status.

### Pengikatan Erat

``SiswaViewModel`` terikat erat dengan ``SiswaDataSource`` untuk menegakkan antarmuka terpadu dalam pengelolaan data. Memungkinkan peralihan mulus antara mode datar dan terkelompok tanpa mengubah logika tampilan. Misalnya:
- Dalam mode datar (``TableViewMode/plain``), indeks adalah posisi array langsung.
- Dalam mode terkelompok (``TableViewMode/grouped``), indeks memperhitungkan header kelompok, menggunakan metode pembantu seperti ``SiswaViewModel/getRowInfoForRow(_:)`` untuk menyelesaikan baris absolut menjadi tuple `(isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int)`.

Pengikatan ini memastikan bahwa operasi seperti insert/delete bersifat mode-agnostik pada tingkat view model, sementara sumber data menangani detail spesifik mode (misalnya, pengelompokan ulang setelah pengurutan).

## Pengambilan Data dan Inisialisasi

Data diambil secara asinkron dari database dan dimuat ke sumber data yang aktif.

### Pengambilan Siswa

Gunakan fungsi ini untuk mengambil data siswa dari database:
- ``SiswaViewModel/fetchSiswaData()``: Memanggil ``SiswaDataSource/fetchSiswa()`` secara asinkron.
  - **Parameter**: Tidak ada parameter.
  - **Detail Operasi**:
    - Di kedua mode: Mengambil semua siswa melalui ``DatabaseController/getSiswa(_:)`` (dengan parameter `group: true` untuk mode terkelompok agar data sudah dikelompokkan terlebih dahulu).
    - Mode datar: Menyimpan hasil dalam array datar.
    - Mode terkelompok: Mengorganisir ke dalam properti `groups` (array 2D) berdasarkan tingkat kelas (misalnya, "Kelas 1" hingga "Kelas 6", ``StatusSiswa/lulus``, atau kelas kosong).

Gunakan fungsi ini untuk mencari siswa berdasarkan filter:
- ``SiswaViewModel/cariSiswa(_:)``: Mencari siswa berdasarkan string filter.
  - **Parameter**:
    - `filter`: String kata kunci pencarian (misalnya, nama siswa).
  - **Detail Operasi**:
    - Dirutekan ke ``SiswaDataSource/cariSiswa(_:)``, yang menanyakan ``DatabaseController/searchSiswa(query:)`` dan memperbarui struktur data (datar atau dikelompokkan ulang).

### Inisialisasi

- Instance singleton (``SiswaViewModel/shared``) memuat ``TableViewMode`` yang disimpan dari `UserDefaults`.
- Pengambilan awal melalui ``SiswaViewModel/fetchSiswaData()`` mengisi sumber data, memastikan data siap untuk pengikatan UI seperti `NSTableView`.

## Operasi Insert, Delete, Update, dan Relocate

Operasi CRUD ini menjaga konsistensi data antara memori (sumber data) dan database, dengan dukungan untuk penyisipan terurut dan relokasi berdasarkan comparator.

### Insert

Gunakan fungsi ini untuk menyisipkan siswa tersembunyi (misalnya, siswa berstatus berhenti atau lulus yang sebelumnya disembunyikan):
- ``SiswaViewModel/insertHiddenSiswa(_:comparator:)``: Mengambil siswa berdasarkan ID dari database dan menyisipkan ke sumber data.
  - **Parameter**:
    - `id`: `Int64` sebagai ID unik siswa yang akan diambil dari database.
    - `comparator`: Closure `(ModelSiswa, ModelSiswa) -> Bool` untuk menentukan urutan penyisipan.
  - **Detail Operasi**:
    - Dirutekan ke ``SiswaDataSource/insert(_:comparator:)``.
    - Mode datar: Menemukan posisi terurut dalam array datar menggunakan binary search.
    - Mode terkelompok: Menentukan indeks kelompok melalui ``GroupedSiswaData/getGroupIndexForStudent(_:)`` dan menyisipkan terurut dalam kelompok tersebut.
    - Mengembalikan `Int` sebagai indeks penyisipan untuk pembaruan UI seperti insert row di tabel.

- Penyisipan umum (misalnya, dari pasting): Setelah insert ke database melalui ``SiswaViewModel/insertToDatabase(_:foto:)``, model ditambahkan ke sumber data dengan pengurutan menggunakan comparator.

### Delete

Gunakan fungsi ini untuk menghapus siswa pada indeks tertentu:
- ``SiswaViewModel/removeSiswa(at:)``: Menghapus pada indeks tertentu.
  - **Parameter**:
    - `index`: `Int` sebagai indeks baris siswa di sumber data.
  - **Detail Operasi**:
    - Dirutekan ke ``SiswaDataSource/remove(at:)``.
    - Mode datar: Penghapusan array sederhana.
    - Mode terkelompok: Menyelesaikan indeks absolut ke kelompok/baris melalui ``SiswaViewModel/getRowInfoForRow(_:)`` dan menghapus dari subkelompok.

Gunakan fungsi ini untuk menghapus berdasarkan objek siswa:
- ``SiswaViewModel/removeSiswa(_:)``: Menghapus berdasarkan objek ``ModelSiswa``.
  - **Parameter**:
    - `siswa`: Objek ``ModelSiswa`` yang akan dihapus.
  - **Detail Operasi**:
    - Mengembalikan tuple `(index: Int, update: UpdateData)` untuk pembaruan UI.

### Update

Gunakan fungsi ini untuk memperbarui siswa yang ada:
- ``SiswaViewModel/updateSiswa(_:)``: Memperbarui siswa yang ada di sumber data.
  - **Parameter**:
    - `siswa`: Objek ``ModelSiswa`` dengan data terbaru.
  - **Detail Operasi**:
    - Dirutekan ke ``SiswaDataSource/update(siswa:)``.
    - Kedua mode: Mengganti model pada indeks yang ditemukan melalui ``SiswaDataSource/indexSiswa(for:)`` (berdasarkan ID).
    - Mengembalikan `Int?` sebagai indeks yang diperbarui.

Gunakan fungsi ini untuk pembaruan komprehensif:
- ``SiswaViewModel/updateDataSiswa(_:dataLama:baru:)``: Pembaruan komprehensif membandingkan model lama dan baru.
  - **Parameter**:
    - `id`: `Int64` sebagai ID siswa.
    - `dataLama`: ``ModelSiswa`` sebelum perubahan.
    - `baru`: ``ModelSiswa`` dengan data terbaru.
  - **Detail Operasi**:
    - Memperbarui bidang database jika berubah (misalnya, nama, alamat, status) melalui ``DatabaseController/updateKolomSiswa(_:kolom:data:)``.
    - Menangani kasus khusus seperti kelulusan dengan ``DatabaseController/editSiswaLulus(siswaID:tanggalLulus:statusEnrollment:registerUndo:)``.
    - Mengirim notifikasi seperti `.dataSiswaDiEditDiSiswaView`.
    - Memperbarui model in-memory melalui ``SiswaViewModel/updateSiswa(_:)``.

Gunakan fungsi ini untuk pembaruan bidang tertentu:
- ``SiswaViewModel/updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``: Pembaruan bidang tertarget.
  - **Parameter**:
    - `id`: `Int64` sebagai ID siswa.
    - `columnIdentifier`: ``SiswaColumn`` sebagai identifier kolom (misalnya, ``SiswaColumn/nama``).
    - `rowIndex`: `Int?` sebagai indeks baris opsional untuk optimasi.
    - `newValue`: `String` sebagai nilai baru.
  - **Detail Operasi**:
    - Memperbarui database melalui ``DatabaseController/updateKolomSiswa(_:kolom:data:)``.
    - Mengupdate properti model melalui ``ModelSiswa/setValue(for:newValue:)``.
    - Mengirim notifikasi undo melalui ``UndoActionNotification/sendNotif(_:columnIdentifier:groupIndex:rowIndex:newValue:isGrouped:updatedSiswa:)``.

### Relocate

Gunakan fungsi ini untuk memindahkan posisi siswa setelah pembaruan:
- ``SiswaViewModel/relocateSiswa(_:comparator:columnIndex:)``: Memindahkan siswa ke posisi baru setelah pembaruan (misalnya, perubahan nama yang memengaruhi urutan).
  - **Parameter**:
    - `siswa`: Objek ``ModelSiswa`` yang akan direlokasi.
    - `comparator`: Closure `(ModelSiswa, ModelSiswa) -> Bool` untuk menentukan urutan.
    - `columnIndex`: `Int?` sebagai indeks kolom yang memicu relokasi (opsional).
  - **Detail Operasi**:
    - Dirutekan ke ``SiswaDataSource/relocateSiswa(_:comparator:columnIndex:)``.
    - Mode datar: Menghapus melalui ``SiswaDataSource/remove(at:)`` dan menyisipkan ulang terurut dalam array datar.
    - Mode terkelompok: Mungkin memindahkan antar kelompok jika kelas/status berubah; menghitung ulang indeks absolut melalui ``GroupedSiswaData/absoluteIndex(for:rowIndex:)``.
    - Mengembalikan ``UpdateData`` opsional jika relocate di model berhasil. (misalnya, ``UpdateData/move(from:to:)``) untuk reload UI yang efisien.

Pengurutan diterapkan melalui ``SiswaViewModel/sortSiswa(by:)``:
- **Parameter**:
  - `sortDescriptor`: `NSSortDescriptor` yang dikonversi menjadi comparator.
- **Detail Operasi**: Dirutekan ke ``SiswaDataSource/sort(by:)``, mengurutkan seluruh data.

## Pembaruan Kelas (Kelas) dan Status

Pembaruan kelas dan status memicu perubahan database, relokasi sumber data, dan event UI melalui ``SiswaViewModel/kelasEvent`` dari jenis ``NaikKelasEvent``.

### Pembaruan Status

Gunakan fungsi ini untuk mengatur status siswa menjadi aktif:
- ``SiswaViewModel/setAktif(for:kelas:)``: Mengatur status menjadi ``StatusSiswa/aktif``, membersihkan tanggal berhenti.
  - **Parameter**:
    - `siswa`: Objek ``ModelSiswa`` yang akan diaktifkan.
    - `kelas`: `String?` sebagai nama kelas opsional untuk memperbarui ``ModelSiswa/tingkatKelasAktif``.
  - **Detail Operasi**:
    - Memperbarui database melalui ``DatabaseController/updateKolomSiswa(_:kolom:data:)`` dan ``DatabaseController/updateStatusSiswa(idSiswa:newStatus:)``.
    - Memperbarui cache dan sumber data melalui ``SiswaViewModel/updateSiswa(_:)``.
    - Mengirim event ``NaikKelasEvent/aktifkanSiswa(_:kelas:)``.

Gunakan fungsi ini untuk penyaringan status:
- ``SiswaViewModel/filterSiswaBerhenti(_:sortDescriptor:)``: Memfilter siswa berstatus ``StatusSiswa/berhenti``.
  - **Parameter**:
    - `isBerhentiHidden`: `Bool` untuk menentukan apakah menyembunyikan siswa berhenti.
    - `comparator`: Closure `(ModelSiswa, ModelSiswa) -> Bool` untuk pengurutan setelah filter.
  - **Detail Operasi**: Mengembalikan array `[Int]` indeks untuk UI; dalam mode terkelompok, menghitung indeks absolut dengan header.

- ``SiswaViewModel/filterSiswaLulus(_:sortDesc:)``: Memfilter siswa berstatus ``StatusSiswa/lulus``.
  - **Parameter** serupa dengan di atas, dengan `tampilkanLulus: Bool`.

### Pembaruan Kelas (Naik Kelas)

Gunakan fungsi ini untuk mengubah kelas aktif siswa secara batch:
- ``SiswaViewModel/naikkanSiswaBatch(siswa:ke:tahunAjaran:semester:status:)``: Memproses promosi kelas batch.
  - **Parameter**:
    - `payload`: ``NaikKelasPayload`` yang berisi siswa, kelas tujuan, tahun ajaran, semester, status, dll.
  - **Detail Operasi**:
    - Membuat payload untuk kelas/tahun/semester baru.
    - Menyisipkan atau mendapatkan ID kelas secara asinkron melalui ``DatabaseController/insertOrGetKelasID(nama:tingkat:tahunAjaran:semester:)``.
    - Memperbarui status pendaftaran, menyisipkan entri riwayat melalui ``DatabaseController/naikkanSiswa(_:intoKelasId:tingkatBaru:tahunAjaran:semester:tanggalNaik:statusEnrollment:)``.
    - Membangun array ``UndoNaikKelasContext`` untuk reversibilitas.
    - Mengirim event seperti ``NaikKelasEvent/kelasBerubah(_:fromKelas:)``.

Gunakan fungsi ini untuk undo promosi kelas:
- ``SiswaViewModel/undoNaikKelas(contexts:siswa:aktifkanSiswa:)``: Membalik promosi kelas.
  - **Parameter**:
    - `contexts`: Array ``UndoNaikKelasContext`` dari operasi sebelumnya.
    - `siswa`: Array ``ModelSiswa`` yang akan dibalik.
    - `aktifkanSiswa`: `Bool` untuk menentukan apakah undo melibatkan aktivasi status.
  - **Detail Operasi**: Membalik entri database, mendaftarkan redo dengan `UndoManager`, dan mengirim event seperti ``NaikKelasEvent/undoUbahKelas(_:toKelas:status:)``.

Gunakan fungsi ini untuk redo promosi kelas:
- ``SiswaViewModel/redoNaikKelas(contexts:siswa:oldData:aktifkanSiswa:)``: Mengulang promosi kelas.
  - **Parameter** serupa dengan undo, ditambah `oldData: [ModelSiswa]` sebagai data sebelum redo.

## Penguraian Clipboard dan Pasting

Menangani impor data dari clipboard atau gambar.

### Penguraian Clipboard

Gunakan fungsi ini untuk menguraikan data dari clipboard:
- ``SiswaViewModel/parseClipboard(_:columnOrder:)``: Menguraikan teks yang dipisahkan tab/koma menjadi array `[ModelSiswa]`.
  - **Parameter**:
    - `raw`: `String` sebagai teks mentah dari clipboard.
    - `columnOrder`: Array `[SiswaColumn]` sebagai urutan kolom untuk mapping data.
  - **Detail Operasi**:
    - Memetakan kolom ke properti melalui kamus setter (misalnya, ``SiswaColumn/nama`` ke ``ModelSiswa/nama``).
    - Menangani default seperti ``StatusSiswa/aktif`` jika tidak ditentukan.
    - Mengembalikan tuple `(siswas: [ModelSiswa], errors: [String])``.

> Pengurutan kolom harus disesuaikan melalui UI, menggunakan enum ``SiswaColumn``.

### Pasting dan Penyisipan

Gunakan fungsi ini untuk menyisipkan data ke database:
- ``SiswaViewModel/insertToDatabase(_:foto:)``: Menyisipkan array siswa ke database.
  - **Parameter**:
    - `siswas`: Array `[ModelSiswa]` yang akan disimpan.
    - `foto`: `Data?` sebagai data foto opsional untuk semua siswa.
  - **Detail Operasi**:
    - Mengatur default seperti ``ModelSiswa/tahundaftar`` menggunakan ``ReusableFunc/todayString()``.
    - Menyimpan melalui ``DatabaseController/catatSiswa(_:)``.
    - Mengembalikan array `[ModelSiswa]` dengan ID yang ditetapkan.

Gunakan fungsi ini untuk pasting dari file gambar:
- ``SiswaViewModel/pasteSiswas(from:)``: Membuat siswa dari array URL file gambar.
  - **Parameter**:
    - `fileURLs`: Array `[URL]` sebagai path file gambar.
  - **Detail Operasi**:
    - Menggunakan nama file sebagai ``ModelSiswa/nama``, mengompres gambar dengan ``AppKit/NSImage/compressImage(quality:)``.
    - Menyimpan ke database dan mengembalikan array `[ModelSiswa]`.

Setelah pasting, siswa disisipkan ke sumber data dengan pengurutan melalui ``SiswaDataSource/insert(_:comparator:)``.

## Penyisipan Siswa Tersembunyi

- Digunakan untuk menampilkan siswa yang sebelumnya disembunyikan (misalnya, berstatus ``StatusSiswa/berhenti`` atau ``StatusSiswa/lulus``).
- Gunakan ``SiswaViewModel/insertHiddenSiswa(_:comparator:)`` (seperti dijelaskan di bagian Insert).
- Terintegrasi dengan penyaringan untuk menampilkan/sembunyikan secara dinamis berdasarkan `UserDefaults` (misalnya, key "sembunyikanSiswaBerhenti").

## Interaksi dengan Database Persisten

Semua perubahan disinkronkan ke ``DatabaseController`` (SQLite):
- Pengambilan: ``DatabaseController/getSiswa(_:)``, ``DatabaseController/searchSiswa(query:)``.
- Insert: ``DatabaseController/catatSiswa(_:)``.
- Update: ``DatabaseController/updateKolomSiswa(_:kolom:data:)``, ``DatabaseController/editSiswaLulus(siswaID:tanggalLulus:statusEnrollment:registerUndo:)``, dll.
- Delete: Implisit melalui penghapusan dari sumber data, tetapi penghapusan database dilakukan secara terpisah (misalnya, melalui query custom).
- Asinkron untuk kinerja, seperti pengambilan paralel di ``SiswaViewModel/fetchEditedSiswa(snapshotSiswas:)`` yang menggunakan `withTaskGroup`.

Undo/redo untuk editing in-line per-kolom bisa menggunakan ``SiswaViewModel/undoAction(originalModel:)`` dan ``SiswaViewModel/redoAction(originalModel:)`` memastikan konsistensi database selama pembalikan.

## Dependensi

- ``SiswaDataSource``
- ``PlainSiswaData``
- ``GroupedSiswaData``
- ``ModelSiswa``
- ``DatabaseController``
- ``StatusSiswa``
- ``KelasAktif``
- ``SiswaColumn``
- ``UpdateData``
- ``NaikKelasEvent``
- ``NaikKelasPayload``
- ``UndoNaikKelasContext``
