# Split View

Tampilan yang memungkinkan pengguna menavigasi dan memilih konten dalam satu jendela.

## Overview

SplitView adalah `contentView` yang ditampilkan oleh ``WindowController``. Dikelola oleh class ``SplitVC`` yang merupakan subclass dari `NSSplitViewController`.

SplitView digunakan untuk menampilkan dua panel tampilan:
- ``SidebarViewController`` untuk mengelola tampilan panel sisi.
- ``ContainerSplitView`` untuk mengelola tampilan yang dinamis sesuai pilihan dari panel sisi.

- SplitView menangani *observer* `NotificationCenter` dengan nama `.bisaUndo` untuk memperbarui icon simpan di bilah alat (``WindowController/toolbar``). Notifikasi ini menjalankan *selector* di ``SimpanData/calculateTotalDeletedData()``.
    - ``ReusableFunc/cloudArrowUp`` digunakan jika ada data yang belum disimpan.
    - ``ReusableFunc/cloudCheckMark`` digunakan jika semua data telah disimpan.

## Topics

### Tampilan Utama
- ``SplitVC``

### Panel Sisi
- ``SidebarViewController``
- ``EditableOutlineView``

### Model Data
- ``SidebarItem``
- ``SidebarGroup``

### Container View
- ``ContainerSplitView``

### Protokol
- ``AppDelegate``
- ``SidebarDelegate``

