# Jendela
Jendela utama yang membungkus UI Utama. Merupakan subclass dari `NSWindowController`.

## Overview

``WindowController`` adalah subclass dari `NSWindowController` yang mengelola jendela utama aplikasi. Kelas ini bertanggung jawab untuk:

- Mengelola frame dan posisi jendela
- Menangani toolbar dan item-itemnya
- Menyimpan dan memulihkan state jendela
- Mengelola notifikasi terkait jendela

``MyToolbar`` adalah subclass dari `NSToolbar` yang mengimplementasikan `NSToolbarDelegate` untuk mengelola item toolbar dalam aplikasi.

## Class WindowController

### Properti Utama

- ``WindowController/toolbar``: Toolbar utama aplikasi
- Berbagai outlet untuk item toolbar (``WindowController/kalkulasiButton``, ``WindowController/tambahSiswa``, ``WindowController/statistikButton``, dll.)
- Berbagai outlet untuk toolbar items (``WindowController/kalkulasiToolbar``, ``WindowController/addDataToolbar``, ``WindowController/statistikToolbar``, dll.)

### Fungsi Utama

#### Manajemen Frame Jendela
- ``WindowController/awakeFromNib()``: Mengatur delegate dan memulihkan frame jendela dari UserDefaults
- ``WindowController/windowDidResize(_:)``: Menyimpan frame jendela ketika diresize
- ``WindowController/windowDidMove(_:)``: Menyimpan frame jendela ketika dipindahkan
- ``WindowController/windowWillClose(_:)``: Menyimpan frame jendela sebelum ditutup

#### Penanganan Notifikasi
- ``WindowController/windowDidUpdate(_:)``: Dipanggil ketika jendela diupdate

#### Actions Toolbar
- ``WindowController/addData(_:)``: Menangani aksi tambah data
- ``WindowController/showScrollView(_:)``: Menampilkan rekap nilai jika berada di kelas aktif
- ``WindowController/addSiswa(_:)``: Menangani aksi tambah siswa
- ``WindowController/Statistik(_:)``: Menampilkan statistik
- ``WindowController/jumlah(_:)``: Menampilkan popover jumlah
- ``WindowController/edit(_:)``: Menangani aksi edit
- ``WindowController/hapus(_:)``: Menangani aksi hapus
- ``WindowController/segemntedControl(_:)``: Menangani perubahan segmented control untuk memperbesar tampilan item

## Class MyToolbar

### Fungsi Delegate

- ``MyToolbar/toolbarWillAddItem(_:)``
    - Dipanggil ketika item akan ditambahkan ke toolbar jendela. Mengonfigurasi item berdasarkan view controller yang aktif.

- ``MyToolbar/toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)``
    - Mengembalikan item toolbar yang sesuai dengan identifier yang diberikan.

- ``MyToolbar/toolbarAllowedItemIdentifiers(_:)``
    - Mengembalikan daftar identifier item yang diizinkan dalam toolbar.

### Konfigurasi Item Toolbar

- ``MyToolbar/toolbarItem(for:in:)``
    - Mengembalikan item toolbar yang dikonfigurasi berdasarkan identifier dan window controller.

- ``MyToolbar/customToolbarItem(itemForItemIdentifier:label:paletteLabel:toolTip:itemContent:)``
    - Membuat item toolbar kustom dengan konfigurasi yang diberikan.

- ``MyToolbar/configureTambahDefault(_:)``
    - Mengonfigurasi item "Tambah" default dengan ikon dan label yang sesuai.

## Integrasi dengan View Controller

Toolbar secara dinamis menyesuaikan diri berdasarkan view controller yang aktif:

- ``SiswaViewController``
    - Search field placeholder: "Siswa"
    - Action: ``SiswaViewController/procSearchFieldInput(sender:)``

- ``TransaksiView``
    - Search field placeholder: "Transaksi"
    - Action: ``TransaksiView/procSearchFieldInput(sender:)``

- ``TugasMapelVC``
    - Search field placeholder: "Tugas Guru"
    - Action: ``TugasMapelVC/procSearchFieldInput(sender:)``

- ``KelasVC``
    - Search field placeholder: Dinamis berdasarkan tab yang dipilih
    - Action: ``KelasVC/procSearchFieldInput(sender:)``

- ``InventoryView``
    - Search field placeholder: "Inventaris"
    - Action: ``InventoryView/procSearchFieldInput(sender:)``

### Dan lain-lain
View controller lainnya menonaktifkan search field atau menampilkan placeholder yang sesuai.

> Catatan Penting
> 1. **Persistence**: Frame jendela disimpan di UserDefaults dengan key "WindowFrame"
> 2. **Dynamic Toolbar**: Item toolbar berubah berdasarkan view controller yang aktif
> 3. **Search Field**: Dikonfigurasi secara dinamis dengan placeholder dan action yang sesuai
> 4. **Toolbar Items**: Setiap item memiliki tooltip dan label yang informatif

## Penggunaan

WindowController dan MyToolbar bekerja sama untuk menyediakan:
- Antarmuka pengguna yang konsisten
- Pengelolaan state jendela yang persisten
- Toolbar yang responsif dan kontekstual
- Integrasi yang erat dengan berbagai view controller dalam aplikasi

## Topics

### Class
- ``WindowController``
- ``MyToolbar``
- ``CustomSearchField``
