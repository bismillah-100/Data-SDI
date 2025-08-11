# Menyimpan Data

Aplikasi menghapus data dari basis data menggunakan ``SimpanData`` yang merupakan class bertanggung jawab untuk menghapus data dari database setelah dihapus dari viewModel.

## Overview

viewModel atau viewController ketika menghapus data tidak langsung menghapus data dari basis data. Data yang dihapus akan disimpan di dalam array singleton ``SingletonData`` dan akan dikelola oleh class ``SimpanData`` saat perubahan tersebut disimpan ke database.

## Topics

### Class
- ``SimpanData``

### Memeriksa perubahan
- ``SimpanData/checkAllDataSaved()``
- ``SimpanData/checkUnsavedData(_:)``

### Menghitung data
- ``SimpanData/calculateTotalDeletedData()``

### Menyimpan data
- ``SimpanData/processDeleteItem(_:)``
- ``SimpanData/gatherAllDataToDelete()``

### Membatalkan perubahan
- ``SimpanData/simpanPerubahan(tutupApp:)``

### Cleanup Singleton
- ``SimpanData/clearDeletedData()``
- ``SimpanData/finishDeletion(totalDeletedData:tutupApp:)``
