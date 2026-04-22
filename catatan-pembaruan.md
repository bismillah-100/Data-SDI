# Catatan Perubahan
## v2.4.0, 22 April 2026
### Perbaikan
- unwrap magnification di pratinjau foto untuk menghindari crash
- pemanggilan API SQLite.swift di Xcode 26.4
- di macOS Tahoe:
	- frame tagControl
	- crash statistikSiswa
	- posisi gambar tidak sejajar dengan kolom nama siswa
	- penyesuaian layout administrasi

### Pembaruan:
- Aplikasi kini telah terverifikasi menggunakan Developer ID
- Penggunaan Sparkle2 untuk pembaruan aplikasi

---

## 2025

## 26 September (Versi 62) | Versi Final 2025. ™️

**Perbaikan:**
- Popup kelas aktif ketika menambahkan data kelas tidak sesuai dengan kelas aktif di daftar siswa.
- Perbaikan lainnya meliputi arsitektur dan state setiap tampilan.

**UI:**

1. Daftar Siswa:
	- Penambahan fitur mengubah kelas dan status di mode grup.
	- Menghapus opsi hapus kelas aktif.
	- Warna latar belakang mengikuti aksen sistem saat drag.
	- Optimasi filter siswa berhenti/lulus + indikator progress.
	- Menambah Data Kelas:
	- Validasi input nilai kelas lebih awal ketika tombol catat ditekan.
	- Tombol tutup, simpan, dan catat kini mengapung di bawah.
	- Scroll menggunakan animasi ketika aktif.
2. Mengedit Data Siswa:
	- Scroll menggunakan animasi ketika aktif.
3. Kelas:
	- Sinkronisasi nama siswa, guru, mapel saat diedit/hapus dari UI lain.
4. Print Kelas:
	- Tampilan print diperbarui dengan garis horizontal pada tabel.
	- Kalkulasi nilai mapel diurutkan dari nilai tertinggi.

---

**23 Agustus (Versi 57)**

**Ringkasan:**

Perapian alur Edit Kelas Aktif dan Status Siswa, pembersihan data ganda di siswa_kelas, optimasi cache dan konkurensi, perbaikan File Monitor, serta penambahan ConnectionWorker untuk SQLiteConnectionPool.   	

**Selesai:**

1. Database menggunakan foreign key.
2. Edit Kelas Aktif: Kelas aktif siswa dapat di-setel dengan konsisten, termasuk jalur Siswa Berhenti dan Siswa Lulus. Serta perbaikan Undo–Redo pada perubahan kelas aktif.
3. Pembersihan siswa_kelas: Menghapus entri siswa_kelas dengan status_enrollment != 1 (Aktif) ketika sudah ada row lain yang aktif dan belum direferensikan di nilai_siswa_mapel.
4. Tambah Data Kelas:
	- Cache kelas aktif: Cache kelas aktif siswa dimuat dan disimpan.
	- Seleksi otomatis: Tahun ajaran otomatis terseleksi untuk siswa yang relevan.
	- Invalidasi cache: Cache dihapus saat ada notifikasi perubahan kelas.
5. Query Kelas Aktif: Query mengambil data berdasarkan status_enrollment aktif lintas tahun ajaran (agnostik terhadap nilai tahun_ajaran) dan berdasarkan kolom status yang aktif di tabel siswa.
6. Charts Ikhtisar Kelas: Penyempurnaan constraint.
7. File Monitor: Perbaikan ketika file database dihapus dan penyempurnaan penanganan dengan Swift Concurrency.
8. Optimasi startup: Pra-muat cache dengan Swift Concurrency dan menunda utilitas setupUI saat aplikasi baru dibuka.
9. Infrastruktur koneksi: Menambahkan ConnectionWorker untuk SQLiteConnectionPool (lihat dokumentasi kode).

**Catatan Perilaku:****

1. Aktivasi siswa dan tahun ajaran:
	- Pengguna wajib memilih tahun ajaran yang valid (untuk insert/update data di database) saat mengaktifkan siswa atau mengubah kelas aktif.
	- Mekanisme aktivasi tidak membuat row baru; sistem mencari row terakhir di siswa_kelas, lalu mengubahnya menjadi aktif.
	- Mekanisme pembaruan Kelas Aktif; sistem akan mencari row dengan status_enrollment yang nonaktif pada selain input tahun ajaran, semester dan tingkat kelas. Jika tidak ditemukan, sistem akan mencari row yang aktif pada input tahun ajaran, semester dan tingkat kelas yang sesuai untuk keperluan undo/redo dan mengubahnya menjadi aktif.

**Telah diperbaiki:**

1. Redo status siswa dengan filter:
	- Perubahan status siswa belum bisa di-redo ketika filter “Berhenti” atau “Lulus” sedang aktif.
2. Perubahan kelas aktif untuk siswa Lulus:
	- Saat Undo bisa menghapus entri baru, namun Redo membuat status_enrollment di siswa_kelas tetap “Lulus”.
	- Kolom status di tabel siswa tidak ikut diperbarui.
3. Perubahan kelas aktif untuk siswa Berhenti:
	- Kolom status di tabel siswa tidak diperbarui; tanggal berhenti di table view tidak sinkron.
4. EditDataVC Undo: Undo tidak memperbarui status_enrollment di siswa_kelas saat mengedit kelas aktif untuk siswa “Berhenti” atau “Lulus” ketika tidak ada status_enrollment yang aktif.
5. TableView & OulineView: Toolbar dan Item Menu Bar tidak diperbarui ketika memanggil func muatUlang(_:).

**Fitur Baru:**

1. Pengetikan Tahun Ajaran: Input tahun ajaran auto-increment (+1).
2. KelasHistorisVC: Kolom status siswa_kelas.

## 10 Agustus (Versi 56

**Perubahan desain** **database:**

1. Database menggunakan foreign key.

**Fitur baru:**

- Histori Nilai Kelas.
- Filter statistik nilai menurut tahun ajaran.
- Penugasan guru.

**Perubahan UI:**

- Menambahkan nilai kelas dan siswa.
- Edit data siswa.
- Paste data nilai kelas.

**Peningkatan UI:**

- Zoom menggunakan trackpad dan tombol pintas ⌘+ / ⌘-.
- Animasi untuk menyembunyikan foto siswa saat menambahkan data.

**Perbaikan Bug:**

1. Drag foto ke data inventaris saat drop di baris paling bawah.

## 5 Juli (Versi 55)

**Peningkatan kinerja:**

- Mengoptimalkan arsitektur dengan menerapkan singleton pada KelasViewModel dan SiswaViewModel.
- Perubahan arsitektur database tabel kelas.
- Menambahkan StringInterner untuk mengurangi duplikasi memori string yang identik.
- Memperbaiki bug sinkronisasi & undo di TransaksiView agar data tetap konsisten meskipun difilter.

## 30 Juni (Versi 54)

**Peningkatan kinerja:**

- Menghapus subclass KelasModels dan KelasPrint.
- Memperbaiki pembaruan data antar view-controller KelasVC dan DetailSiswaController.
- Optimalisasi sorting data, foto siswa dan inventaris, dragging scroll pratinjau foto.
- Mengubah nama ekstensi di folder dokumen ke .sdi

## 25 Juni (Versi 53) | Versi Final 2025. ™️

**Pembaruan:**

- Tampilan: Migrasi DGCharts ke SwiftCharts.

**Perbaikan Bug:**

- Protokol sidebarViewController belum diset ke kelasVC.
- Popover jumlah grafik tidak di-deinit.

## 15 Juni (Versi 52)

**Pembaruan:**

- Tampilan: Layout administrasi saat tidak menggunakan mode grup menggunakan _align _left_.
- Kontrol: Fitur navigasi kolom berikutnya dengan menekan `tab` saat mengedit di tabel.
- Kontrol: Scroll foto di pratinjau foto siswa dengan kilk dan tahan.

**Perbaikan Bug:**

- Simpan gambar: Menyimpan gambar ketika nama dari data bermuatan huruf "/".
- Drag & Drop: Melakukan drag dari Pratinjau Foto ke Finder.
- Edit tabel: Pengeditan di tabel ketika data yang terdapat di kolom hanya berisi satu huruf yang singkat seperti angka "1" atau huruf "i".

## 09/06 (48)

**Pembaruan:**

- Dokumentasi kode dengan lengkap. Bisa dilihat di: [https://github.com/bismillah-100/Data-SDI](https://github.com/bismillah-100/Data-SDI)

**Perbaikan Bug:**

- Tidak bisa undo/redo setelah mengedit data langsung dari tabel di Rincian Siswa.
- Perbaikan bug ketika mengetik _shortcut keyboard_  “⌃+G” untuk mengelompokkan data di Daftar Siswa dan Administrasi ketika di ketik terlalu cepat dengan menambahkan penundaan sepersekian detik .

## 29/05 (43)

**Pembaruan:**

- Pembaruan tampilan Pengaturan; kini didukung SwiftUI.

**Perbaikan bug_:**

- Ekspor foto Edit Data siswa tidak berfungsi.
- Pilihan item semester di Rincian Siswa selalu kembali ke Semester 1 setiap kali membuka menu semester.

**Peningkatan kinerja:**

- Perbaikan siklus jendela Rincian Siswa saat ditutup.

## 26/05 (40)

**Pembaruan Fitur:**

- Pengeditan nama kolom inventaris.
- Prediksi pengeditan di tabel:
	- Kini mengedit di tabel semakin mudah berkat pembungkus teks yang dapat menyesuaikan lebar dan tingginya secara dinamis sesuai jumlah teks.
	- Prediksi ketik di tabel kini dapat digulir vertikal dan horizontal.
	- Prediksi di tabel kini menggunakan _cache_ untuk mempercepat pra-muat prediksi. _Cache_ bisa dihapus dari menu bar “Edit -> Reset Ulang Prediksi Ketik”.
	- Prediksi ketik di tabel sangat komprehensif dan tidak bergantung ke kalimat sebelumnya.

**Perbaikan bug:**

- Section Header di Transaksi View dalam mode group.
- _Constraint_ di Kelas Aktif dan Rincian Siswa.

**Peningkatan Kinerja:**

- Pemuatan data dengan cara asinkron dan konkuren dan dihandel oleh _Swift _Concurency_.
- Penggunaan mode “WAL” untuk koneksi ke Data Base. File “WAL” dan “SHM” tidak diunggah ke iCloud Drive dengan “Marking” dan dihapus segera setelah aplikasi berhenti. Mohon jangan menghapus kedua file ini ketika aplikasi sedang berjalan untuk konsistensi data.
- Versi Final untuk macOS Big Sur dan Monterey.

## 10/05 - (34)

### Perbaikan Bug dan Peningkatan Fitur Aplikasi:
- **Koreksi Pembaruan Data Administrasi:**
	- Telah dilakukan perbaikan terhadap bug yang mengakibatkan item yang ditandai tidak diperbarui dengan benar saat melakukan pembaruan data Administrasi.
- **Implementasi Fungsi Konversi Kapitalisasi Teks:**
	- Ditambahkan fitur yang memungkinkan pengguna untuk mengubah format kapitalisasi (Kapital dan Huruf Besar) pada seluruh kolom input teks dalam mode pengeditan dan penambahan data.
- **Penyempurnaan Tampilan Mode Edit dan Tambah Data:**
	- Tampilan antarmuka pengguna pada mode pengeditan dan penambahan data telah diperbarui dengan mengimplementasikan latar belakang _windowbackground_. Pembaruan ini bertujuan untuk meningkatkan visibilitas dan kejelasan kolom _input_ teks, terutama ketika tema terang sedang aktif.

## 10/05 - (34)

- **Perbaikan Pembaruan “Perbarui** **Nanti”;** file plist tidak dimuat ulang setelah mengeklik “Perbarui Nanti” di Update-Agent.

## 10/05 - (33)

- Perbaikan Update-Agent.
- Perbaikan jendela Bantuan.

## 22/04 - (32)

- Meringkas NSSplitViewItems menggunakan NSContainerView:
	- Sidebar.
	- NSContainerView.
- Drag & Drop ke Daftar Siswa untuk menambahkan data.
- Kemampuan untuk mengganti nama item di Ringkasan:
	- Kelas
	- Siswa
	- Guru
- Kemampuan untuk menemukan dan mengganti kata pada data di kolom Siswa dan Inventaris.
- Peningkatan teknis asinkron saat menyimpan data.
- Beralih dari Cocoapods ke Swift Package Manager.
- Beralih dari Storyboard ke XIB untuk mempermudah penggunaan ulang beberapa komponen yang sama.
- Peningkatan kinerja keseluruhan.
- Implementasi MVVM (Model-View-View Model) untuk sebagian data dan tampilan.

## 10/05 - (32)

- Kemampuan untuk memeriksa dan mengunduh file data Siswa, Guru, Inventaris, Kelas, dan data Administrasi yang belum diunduh dari iCloud Drive dan menunggu proses unduhan selesai supaya tidak membuat file baru. Mungkin aplikasi sedikit lebih lama dimulai karena proses unduhan tergantung kecepatan koneksi internet.
- Sekarang data Administrasi disimpan di folder Dokumen pengguna dan di cadangkan ke iCloud ketika pengguna mengaktifkan fitur Dokumen iCloud
- Pembaruan lihat cepat Daftar Siswa dan Inventaris; Mendukung animasi bawaan _QLPreview_.
- Pembaruan kolom “Tanggal Dibuat” di Daftar Inventaris. Sekarang format tanggal dibuat relatif sesuai lebar kolom.
- Pembaruan ikon aplikasi..
- Mengaktifkan fitur gulir di jendela Bantuan.
- Perbaikan bug.

## 10/04 - (23)

- INSHA.A semua bug hampir sepenuhnya diperbaiki.
- Pembaruan target _framework_ ke macOS 11.1+.
- Karena keterbatasan waktu dan hal lainnya. Pembaruan aplikasi ke depannya sedikit menurun intensitas nya. Terimakasih telah bersedia menggunakan aplikasi ini. Semoga hari-hari kita dipenuhi dengan keberkahan.

## 08/04 - (20)

- Kemampuan untuk memeriksa dan memasang pembaruan langsung dari aplikasi:
	- Pemeriksaan pembaruan secara otomatis.
	- Integrasi dengan Pusat Pemberitahuan macOS.
	- Pembaruan sekali klik.
	- Update-Agent.
	- Kemampuan untuk menghentikan unduhan yang sedang berlangsung.
	- Kemampuan untuk menunda pembaruan yang telah diunduh sampai aplikasi ditutup. ™️

## 07/04 - (17)

- Detail siswa:
	- Layout ulang tombol di atas tabel dan kolom. ©️™️
	- Perbaikan tombol semester tidak bisa di-klik ketika tabel masih kosong.
- Perbaikan bug minor dan peningkatan kinerja.

## 06/04 - (16)

- Perbaikan ketika mengedit data administrasi dan undo/redo secara intensif dapat membuat aplikasi _freeze_. bug: setiap menjalankan proses undo/redo, pendaftaran undo/redo dilipat gandakan.
- Pembaruan Tampilan Detail Siswa:
	- Memindahkan beberapa tombol ke tempat Toolbar Accessory View.
- Perbaikan bug minor dan peningkatan kinerja.

## 03/04 - (11)

- Memberhentikan dukungan untuk macOS 10.15 atau yang lebih lama.
- Mendukung tampilan baru macOS 11.0+.
- Persyaratan sistem minimal adalah macOS 11.1+.
- Perbaikan highlight seleksi tampilan Saldo untuk mendukung NSTableView dengan gaya inset di macOS 11.1+.
- Perbaikan bug minor dan peningkatan kinerja.

## 29/03 - (10)

- Memperbaiki mode grup di Daftar Siswa dan Saldo ketika menggulir dan berganti section di header teratas.
- Perbaikan bug minor dan peningkatan kinerja.

## 28/03 - (8)

- Pembaruan ikon menggunakan SF Symbol versi ke-2.
- Menghentikan dukungan untuk macOS 10.14 atau yang lebih lama.
- Perbaikan bug dan peningkatan kinerja.

## 25/03 - (5)

- Memperbaiki kolom Daftar Guru.
- Perbaikan bug minor dan peningkatan kinerja.

## 18/03 - (1)

- Fitur buka di tab baru dan penggunaan tab ditunda sampai semuanya siap. Fitur belum sepenuhnya berfungsi secara optimal. Fitur ini mungkin bisa siap di versi selanjutnya, tetapi tidak di versi 2025.

---

## 2024

- Memuat data secara asinkron ketika aplikasi baru dibuka.
- Tambahan Daftar Inventaris.
- Daftar Inventaris kini bisa ditambahkan kolom kustom.
- Pencarian data di Daftar Inventaris.
- Kemampuan untuk mengurungkan perubahan yang dilakukan di setiap catatan:
	- Administrasi.
	- Daftar Siswa, Guru, dan Inventaris.
	- Kelas Aktif dan Rincian Siswa.
	- Pengeditan teks saat mengedit, menambah, dan menghapus.
- Drag & Drop Foto ke Daftar Inventaris untuk mengganti atau menambah catatan baru.
- Drag & Drop Foto ke Daftar Siswa untuk mengganti foto yang di letakkan di baris tertentu.
- Kemampuan untuk menyalin foto menggunakan Drag & Drop dari Daftar Siswa dan Inventaris ke aplikasi lain.
- Kalkulasi saldo setiap tahun atau bulan dalam mode grafis mencakup pemasukan, pengeluaran dan lainnya.
- Perubahan tampilan Daftar Guru dengan tampilan yang bisa diperluas sesuai mata pelajaran.
- Kemampuan untuk tidak menghapus data yang masih bisa diurungkan ketika aplikasi akan ditutup. Data yang diedit tetap pada perubahan terakhir.
- Kemampuan untuk menambahkan semester baru ketika akan menambah data ke Kelas Aktif atau pun Rincian Siswa misalnya untuk kategori Try-Out atau Data Nilai yang lain.
- Kemampuan untuk membuat jendela baru dan menambahkan tab baru.
- Input tanggal kini sepenuhnya menggunakan pemilihan tanggal (bukan pengetikan manual).
- Tampilan data Struktur Guru sesuai tahun.
- Kemampuan untuk menandai catatan Administrasi.
- Kemampuan untuk mengurutkan catatan Administrasi dalam mode grup.
- Jumlah Saldo sekarang menampilkan catatan Administrasi dalam mode tabel.
- Kalkulasi nilai siswa di Kelas Aktif sekarang menggunakan tampilan tabel (sebelumnya hanya teks dalam TextView).
- Semua data sekarang ditempatkan pada urutannya segera setelah menambahkannya atau mengurungkan penghapusan menggunakan (NSSortDescriptors).
- Kemampuan untuk mengekspor data ke file dalam format Excel, PDF, dan CSV untuk data di Daftar Siswa, Kelas Aktif, dan Rincian Siswa.
- Kemampuan untuk menampilkan saran pengetikan dan menonaktifkan nya.
- Saran pengetikan sesuai dengan kolom yang bisa disesuaikan jumlah yang ditampilkan.
- Kemampuan untuk mengurutkan setiap data di:
	- Administrasi.
	- Jumlah Saldo.
	- Daftar Guru, Siswa, dan Inventaris. 
	- Kelas Aktif.
	- Rincian Siswa.
- Bantuan Umum Aplikasi.
- Jendela Preferensi untuk mengatur bagaimana aplikasi akan berjalan dan kemampuan untuk mengatur ulang peringatan yang diabaikan.
- Pencadangan otomatis setiap bulan pada tanggal pertama di folder “Data SDI” yang terdapat di folder “Dokumen”. File ini langsung dicadangkan ke iCloud jika pengguna menggunakan iCloud Drive untuk folder dokumen.
	- Data Administrasi tidak dicadangkan secara otomatis. Cadangan hanya untuk data Siswa, Guru, Inventaris dan Kelas Aktif.
- Perbaikan action dan target di Menu Bar setelah perpindahan KeyWindow.
- Perbaikan bug undo/redo.
- Penggunaan File Monitor untuk mengawasi jika file berubah dari luar aplikasi dan menampilkan pemberitahuan.

---

## 2023

- NSSplitView:
	- Sidebar.
	- 9 SplitViewItems.
- Pencatatan Siswa dan Guru.
- Pencatatan Kelas Aktif Kelas 1 - Kelas 6 sesuai dengan siswa yang sedang aktif di kelas-kelas tersebut.
- Tampilan Koleksi Item untuk data Catatan Administrasi mencakup:
	- Pemasukan.
	- Pengeluaran.
	- Lainnya.
- Kalkulasi surplus saldo, pemasukan dan pengeluaran.
- Tampilan mode grup sesuai acara, kategori dan keperluan.
- Menggunakan Sidebar untuk navigasi antar data.
- Kemampuan untuk melakukan mengurungkan pada perubahan data di Daftar Siswa.
- Tampilan siswa dalam mode kelompok sesuai Kelas.
- Merekam seluruh nilai siswa dari Kelas 1 - Kelas 6 dalam Rincian Siswa selama data tersebut dicatat dan tidak dihapus.
- Tampilan grafis jumlah nilai siswa di setiap kelasnya dan rata-rata semester 1 dan 2.
- Kemampuan untuk mengurungkan perubahan di Kelas Aktif
- Sensus Jumlah Siswa aktif dan berhenti setiap tahun dan setiap bulan sesuai dengan tanggal daftar dan tanggal berhenti.
- Nilai Kelas Aktif dengan menjumlahkan Nilai Kelas dan Rata-rata nilai kelas dan siswa dalam mode grafis maupun teks yang bisa disimpan ke file format png.
- Kemampuan untuk menempelkan data di clipboard ke Daftar Siswa, Kelas Aktif dan Rincian Siswa.
- Pencarian untuk setiap data di:
	- Administrasi 
	- Daftar Siswa dan Guru 
	- Kelas Aktif
- File data disimpan di folder Dokumen pengguna. Memungkinkan file untuk disimpan di iCloud, tetapi kemungkinan file belum diunduh ketika aplikasi dibuka.

---

© Data SDI 2023-2025

https://datasdi.wordpress.com ™️

