# Catatan Rilis Aplikasi 🎬 📆 ✅

---

## 2025 🔄

### 15 Juni (Versi 52) | Versi Final 2025. ™️
**Pembaruan:**
* **Tampilan:** Layout administrasi saat tidak menggunakan mode grup menggunakan *align left*.
* **Kontrol:** Fitur navigasi kolom berikutnya dengan menekan `tab` saat mengedit di tabel.
* **Kontrol:** Scroll foto di pratinjau foto siswa dengan kilk dan tahan.

**Perbaikan Bug:**
* **Simpan gambar:** Menyimpan gambar ketika nama dari data bermuatan huruf "/".
* **Drag & Drop:** Melakukan drag dari Pratinjau Foto ke Finder.
* **Edit tabel:** Pengeditan di tabel ketika data yang terdapat di kolom hanya berisi satu huruf yang singkat seperti angka "1" atau huruf "i".

### 09 Juni (Versi 48)

**Pembaruan:**
* **Dokumentasi Kode:** Kini lengkap dan dapat dilihat di: https://bismillah-100.github.io/Data-SDI

**Perbaikan Bug:**
* **Undo/Redo di Rincian Siswa:** Tidak bisa dilakukan setelah mengedit data langsung dari tabel.
* **Shortcut Keyboard `⌃+G`:** Perbaikan *bug* ketika mengetik *shortcut* keyboard untuk mengelompokkan data di Daftar Siswa dan Administrasi terlalu cepat dengan menambahkan penundaan sepersekian detik.

### 29 Mei (Versi 43)

**Pembaruan:**
* **Pembaruan Tampilan Pengaturan:** Kini didukung SwiftUI.

**Perbaikan Bug:**
* **Ekspor Foto Edit Data Siswa:** Tidak berfungsi.
* **Pilihan Item Semester di Rincian Siswa:** Selalu kembali ke Semester 1 setiap kali membuka menu semester.

**Peningkatan Kinerja:**
* **Perbaikan Siklus Jendela Rincian Siswa:** Saat ditutup.

### 26 Mei (Versi 40)

**Pembaruan Fitur:**
* **Pengeditan Nama Kolom Inventaris.**
* **Prediksi Pengeditan di Tabel:**
    * Kini mengedit di tabel semakin mudah berkat pembungkus teks yang dapat menyesuaikan lebar dan tingginya secara dinamis sesuai jumlah teks.
    * Prediksi ketik di tabel kini dapat digulir vertikal dan horizontal.
    * Prediksi di tabel kini menggunakan *cache* untuk mempercepat pra-muat prediksi. *Cache* bisa dihapus dari menu bar “Edit -> Reset Ulang Prediksi Ketik”.
    * Prediksi ketik di tabel sangat komprehensif dan tidak bergantung ke kalimat sebelumnya.

**Perbaikan Bug:**
* **Section Header di Transaksi View:** Dalam mode grup.
* **Constraint di Kelas Aktif dan Rincian Siswa.**

**Peningkatan Kinerja:**
* **Pemuatan Data:** Dengan cara asinkron dan konkuren dan dihandel oleh Swift Concurency.
* **Penggunaan Mode “WAL” untuk Koneksi ke Data Base:** File “WAL” dan “SHM” tidak diunggah ke iCloud Drive dengan “Marking” dan dihapus segera setelah aplikasi berhenti. Mohon jangan menghapus kedua file ini ketika aplikasi sedang berjalan untuk konsistensi data.
* **Versi Final untuk macOS Big Sur dan Monterey.**

### 10 Mei (Versi 34)

**Perbaikan Bug dan Peningkatan Fitur Aplikasi:**
* **Koreksi Pembaruan Data Administrasi:** Telah dilakukan perbaikan terhadap *bug* yang mengakibatkan item yang ditandai tidak diperbarui dengan benar saat melakukan pembaruan data Administrasi.
* **Implementasi Fungsi Konversi Kapitalisasi Teks:** Ditambahkan fitur yang memungkinkan pengguna untuk mengubah format kapitalisasi (Kapital dan Huruf Besar) pada seluruh kolom input teks dalam mode pengeditan dan penambahan data.
* **Penyempurnaan Tampilan Mode Edit dan Tambah Data:** Tampilan antarmuka pengguna pada mode pengeditan dan penambahan data telah diperbarui dengan mengimplementasikan latar belakang *windowbackground*. Pembaruan ini bertujuan untuk meningkatkan visibilitas dan kejelasan kolom input teks, terutama ketika tema terang sedang aktif.

### 10 Mei (Versi 34)

* **Perbaikan Pembaruan “Perbarui Nanti”:** File *plist* tidak dimuat ulang setelah mengeklik “Perbarui Nanti” di Update-Agent.

### 10 Mei (Versi 33)

* **Perbaikan Update-Agent.**
* **Perbaikan Jendela Bantuan.**

### 22 April (Versi 32)

* **Meringkas NSSplitViewItems menggunakan NSContainerView:**
    * Sidebar.
    * NSContainerView.
* **Drag & Drop ke Daftar Siswa:** Untuk menambahkan data.
* **Kemampuan untuk Mengganti Nama Item di Ringkasan:**
    * Kelas.
    * Siswa.
    * Guru.
* **Kemampuan untuk Menemukan dan Mengganti Kata:** Pada data di kolom Siswa dan Inventaris.
* **Peningkatan Teknis Asinkron:** Saat menyimpan data.
* **Beralih dari Cocoapods ke Swift Package Manager.**
* **Beralih dari Storyboard ke XIB:** Untuk mempermudah penggunaan ulang beberapa komponen yang sama.
* **Peningkatan Kinerja Keseluruhan.**
* **Implementasi MVVM (Model-View-View Model):** Untuk sebagian data dan tampilan.

### 10 Mei (Versi 32)

* **Kemampuan untuk Memeriksa dan Mengunduh File Data:** Siswa, Guru, Inventaris, Kelas, dan data Administrasi yang belum diunduh dari iCloud Drive dan menunggu proses unduhan selesai supaya tidak membuat file baru. Mungkin aplikasi sedikit lebih lama dimulai karena proses unduhan tergantung kecepatan koneksi internet.
* **Penyimpanan Data Administrasi:** Sekarang data Administrasi disimpan di folder Dokumen pengguna dan dicadangkan ke iCloud ketika pengguna mengaktifkan fitur Dokumen iCloud.
* **Pembaruan Lihat Cepat Daftar Siswa dan Inventaris:** Mendukung animasi bawaan QLPreview.
* **Pembaruan Kolom “Tanggal Dibuat” di Daftar Inventaris:** Sekarang format tanggal dibuat relatif sesuai lebar kolom.
* **Pembaruan Ikon Aplikasi.**
* **Mengaktifkan Fitur Gulir di Jendela Bantuan.**
* **Perbaikan Bug.**

### 10 April (Versi 23)

* **INSHA.A semua bug hampir sepenuhnya diperbaiki.**
* **Pembaruan Target Framework ke macOS 11.1+.**
* **Intensitas Pembaruan:** Karena keterbatasan waktu dan hal lainnya, pembaruan aplikasi ke depannya sedikit menurun intensitasnya. Terimakasih telah bersedia menggunakan aplikasi ini. Semoga hari-hari kita dipenuhi dengan keberkahan.

### 08 April (Versi 20)

**Kemampuan untuk Memeriksa dan Memasang Pembaruan Langsung dari Aplikasi:**
* **Pemeriksaan Pembaruan Secara Otomatis.**
* **Integrasi dengan Pusat Pemberitahuan macOS.**
* **Pembaruan Sekali Klik.**
* **Update-Agent.**
* **Kemampuan untuk Menghentikan Unduhan yang Sedang Berlangsung.**
* **Kemampuan untuk Menunda Pembaruan:** Yang telah diunduh sampai aplikasi ditutup. ™️

### 07 April (Versi 17)

**Detail Siswa:**
* **Layout Ulang Tombol:** Di atas tabel dan kolom. ©️™️
* **Perbaikan Tombol Semester:** Tidak bisa di-klik ketika tabel masih kosong.
* **Perbaikan Bug Minor dan Peningkatan Kinerja.**

### 06 April (Versi 16)

* **Perbaikan *Freeze* Aplikasi:** Ketika mengedit data administrasi dan *undo/redo* secara intensif dapat membuat aplikasi *freeze*. *Bug*: setiap menjalankan proses *undo/redo*, pendaftaran *undo/redo* dilipat gandakan.

**Pembaruan Tampilan Detail Siswa:**
* **Memindahkan Beberapa Tombol ke Toolbar Accessory View.**
* **Perbaikan Bug Minor dan Peningkatan Kinerja.**

### 03 April (Versi 11)

* **Pemberhentian Dukungan untuk macOS 10.15 atau yang Lebih Lama.**
* **Mendukung Tampilan Baru macOS 11.0+.**
* **Persyaratan Sistem Minimal:** macOS 11.1+.
* **Perbaikan *Highlight* Seleksi Tampilan Saldo:** Untuk mendukung NSTableView dengan gaya *inset* di macOS 11.1+.
* **Perbaikan Bug Minor dan Peningkatan Kinerja.**

### 29 Maret (Versi 10)

* **Perbaikan Mode Grup di Daftar Siswa dan Saldo:** Ketika menggulir dan berganti *section* di *header* teratas.
* **Perbaikan Bug Minor dan Peningkatan Kinerja.**

### 28 Maret (Versi 8)

* **Pembaruan Ikon:** Menggunakan SF Symbol versi ke-2.
* **Menghentikan Dukungan untuk macOS 10.14 atau yang Lebih Lama.**
* **Perbaikan Bug dan Peningkatan Kinerja.**

### 25 Maret (Versi 5)

* **Memperbaiki Kolom Daftar Guru.**
* **Perbaikan Bug Minor dan Peningkatan Kinerja.**

### 18 Maret (Versi 1)

* **Fitur Buka di Tab Baru dan Penggunaan Tab:** Ditunda sampai semuanya siap. Fitur belum sepenuhnya berfungsi secara optimal. Fitur ini mungkin bisa siap di versi selanjutnya, tetapi tidak di versi 2025.

---

## 2024 🔄

* **Memuat Data Secara Asinkron:** Ketika aplikasi baru dibuka.
* **Tambahan Daftar Inventaris.**
* **Daftar Inventaris:** Kini bisa ditambahkan kolom kustom.
* **Pencarian Data di Daftar Inventaris.**
* **Kemampuan untuk Mengurungkan Perubahan:** Yang dilakukan di setiap catatan:
    * Administrasi.
    * Daftar Siswa, Guru, dan Inventaris.
    * Kelas Aktif dan Rincian Siswa.
    * Pengeditan teks saat mengedit, menambah, dan menghapus.
* **Drag & Drop Foto ke Daftar Inventaris:** Untuk mengganti atau menambah catatan baru.
* **Drag & Drop Foto ke Daftar Siswa:** Untuk mengganti foto yang diletakkan di baris tertentu.
* **Kemampuan untuk Menyalin Foto:** Menggunakan Drag & Drop dari Daftar Siswa dan Inventaris ke aplikasi lain.
* **Kalkulasi Saldo:** Setiap tahun atau bulan dalam mode grafis mencakup pemasukan, pengeluaran, dan lainnya.
* **Perubahan Tampilan Daftar Guru:** Dengan tampilan yang bisa diperluas sesuai mata pelajaran.
* **Kemampuan untuk Tidak Menghapus Data:** Yang masih bisa diurungkan ketika aplikasi akan ditutup. Data yang diedit tetap pada perubahan terakhir.
* **Kemampuan untuk Menambahkan Semester Baru:** Ketika akan menambah data ke Kelas Aktif atau pun Rincian Siswa (misalnya untuk kategori *Try-Out* atau Data Nilai yang lain).
* **Kemampuan untuk Membuat Jendela Baru dan Menambahkan Tab Baru.**
* **Input Tanggal:** Kini sepenuhnya menggunakan pemilihan tanggal (bukan pengetikan manual).
* **Tampilan Data Struktur Guru:** Sesuai tahun.
* **Kemampuan untuk Menandai Catatan Administrasi.**
* **Kemampuan untuk Mengurutkan Catatan Administrasi:** Dalam mode grup.
* **Jumlah Saldo:** Sekarang menampilkan catatan Administrasi dalam mode tabel.
* **Kalkulasi Nilai Siswa di Kelas Aktif:** Sekarang menggunakan tampilan tabel (sebelumnya hanya teks dalam TextView).
* **Pengurutan Data Otomatis:** Semua data sekarang ditempatkan pada urutannya segera setelah menambahkannya atau mengurungkan penghapusan menggunakan (NSSortDescriptors).
* **Kemampuan untuk Mengekspor Data ke File:** Dalam format Excel, PDF, dan CSV untuk data di Daftar Siswa, Kelas Aktif, dan Rincian Siswa.
* **Kemampuan untuk Menampilkan Saran Pengetikan:** Dan menonaktifkannya.
* **Saran Pengetikan:** Sesuai dengan kolom yang bisa disesuaikan jumlah yang ditampilkan.
* **Kemampuan untuk Mengurutkan Setiap Data di:**
    * Administrasi.
    * Jumlah Saldo.
    * Daftar Guru, Siswa, dan Inventaris.
    * Kelas Aktif.
    * Rincian Siswa.
* **Bantuan Umum Aplikasi.**
* **Jendela Preferensi:** Untuk mengatur bagaimana aplikasi akan berjalan dan kemampuan untuk mengatur ulang peringatan yang diabaikan.
* **Pencadangan Otomatis:** Setiap bulan pada tanggal pertama di folder “Data SDI” yang terdapat di folder “Dokumen”. File ini langsung dicadangkan ke iCloud jika pengguna menggunakan iCloud Drive untuk folder dokumen.
* **Data Administrasi Tidak Dicadangkan Secara Otomatis.** Cadangan hanya untuk data Siswa, Guru, Inventaris dan Kelas Aktif.
* **Perbaikan Action dan Target di Menu Bar:** Setelah perpindahan KeyWindow.
* **Perbaikan Bug Undo/Redo.**
* **Penggunaan File Monitor:** Untuk mengawasi jika file berubah dari luar aplikasi dan menampilkan pemberitahuan.

---

## 2023 🔄

* **NSSplitView:**
    * Sidebar.
    * 9 SplitViewItems.
* **Pencatatan Siswa dan Guru.**
* **Pencatatan Kelas Aktif:** Kelas 1 - Kelas 6 sesuai dengan siswa yang sedang aktif di kelas-kelas tersebut.
* **Tampilan Koleksi Item untuk Data Catatan Administrasi:** Mencakup:
    * Pemasukan.
    * Pengeluaran.
    * Lainnya.
* **Kalkulasi Surplus Saldo, Pemasukan, dan Pengeluaran.**
* **Tampilan Mode Grup:** Sesuai acara, kategori, dan keperluan.
* **Menggunakan Sidebar untuk Navigasi Antar Data.**
* **Kemampuan untuk Melakukan *Undo*:** Pada perubahan data di Daftar Siswa.
* **Tampilan Siswa dalam Mode Kelompok:** Sesuai Kelas.
* **Merekam Seluruh Nilai Siswa:** Dari Kelas 1 - Kelas 6 dalam Rincian Siswa selama data tersebut dicatat dan tidak dihapus.
* **Tampilan Grafis Jumlah Nilai Siswa:** Di setiap kelasnya dan rata-rata semester 1 dan 2.
* **Kemampuan untuk Mengurungkan Perubahan di Kelas Aktif.**
* **Sensus Jumlah Siswa:** Aktif dan berhenti setiap tahun dan setiap bulan sesuai dengan tanggal daftar dan tanggal berhenti.
* **Nilai Kelas Aktif:** Dengan menjumlahkan Nilai Kelas dan Rata-rata nilai kelas dan siswa dalam mode grafis maupun teks yang bisa disimpan ke file format png.
* **Kemampuan untuk Menempelkan Data:** Di *clipboard* ke Daftar Siswa, Kelas Aktif, dan Rincian Siswa.
* **Pencarian untuk Setiap Data di:**
    * Administrasi.
    * Daftar Siswa dan Guru.
    * Kelas Aktif.
* **Penyimpanan File Data:** Di folder Dokumen pengguna. Memungkinkan file untuk disimpan di iCloud, tetapi kemungkinan file belum diunduh ketika aplikasi dibuka.

© Data SDI 2023-2025
