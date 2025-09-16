# Menyimpan Data
Pengelola data yang dihapus dari berbagai ViewModel dan menyimpan perubahan tersebut ke dalam basis data.

## Overview

``SimpanData`` sebagai pengelola data yang dihapus dari viewModel atau UI untuk diproses di basis data.

Data yang dihapus dari viewModel tidak langsung dihapus dari database, tetapi disimpan sementara dalam singleton ``SingletonData`` sebelum diproses oleh ``SimpanData``.

### Cara Kerja

1. ViewModel menghapus data dari tampilan UI
2. Data yang dihapus disimpan dalam ``SingletonData``
3. ``SimpanData`` memeriksa dan mengumpulkan data yang perlu dihapus dari database
4. Perubahan disimpan ke database ketika pengguna mengkonfirmasi
5. Data dihapus secara permanen dari database

### Alur Penyimpanan Data

1. Pengguna menghapus data dari UI
2. Data disimpan di ``SingletonData``
3. ``SimpanData`` menghitung total data yang akan dihapus
4. Tampilkan konfirmasi kepada pengguna
5. Jika dikonfirmasi, proses penghapusan dimulai
6. Tampilkan progress bar selama penghapusan
7. Hapus data dari database
8. Bersihkan ``SingletonData``
9. Tampilkan notifikasi penyelesaian

> **Catatan Penting**
> - Data tidak langsung dihapus dari database untuk mencegah kehilangan data akibat kesalahan
> - Proses penghapusan dilakukan secara asinkron untuk menjaga responsivitas UI
> - Singleton `SingletonData` digunakan sebagai temporary storage sebelum perubahan disimpan permanen
> - Progress bar memberikan umpan balik visual selama proses penyimpanan berlangsung

## Topics

### Class
- ``SimpanData``

### Memeriksa perubahan
- ``SimpanData/checkAllDataSaved()``
- ``SimpanData/checkUnsavedData(_:)``
- ``SimpanData/showAlert(_:informativeText:tutupApp:window:)``
- ``SimpanData/handleAlertResponse(_:tutupApp:window:)``

### Menghitung data
- ``SimpanData/calculateTotalDeletedData()``

### Menyimpan data
- ``SimpanData/simpanData()``
- ``SimpanData/processDeleteItem(_:)``
- ``SimpanData/gatherAllDataToDelete()``
- ``SimpanData/simpanPerubahan(tutupApp:)``

### Handling Data
- ``SimpanData/handleNoDataToDelete(tutupApp:)``

### Cleanup Singleton
- ``SimpanData/clearDeletedData()``
- ``SimpanData/finishDeletion(totalDeletedData:tutupApp:)``
