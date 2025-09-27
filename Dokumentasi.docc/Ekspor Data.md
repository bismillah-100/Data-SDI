# Ekspor Data

Kumpulan fungsi utilitas dalam class `ReusableFunc` untuk menangani ekspor data ke format CSV, Excel, dan PDF menggunakan skrip Python.

## Overview

Fungsi-fungsi ini juga menangani instalasi dan pemeriksaan dependensi Python yang diperlukan.

## Ekspor CSV/Excel/PDF

- ``ReusableFunc/saveToCSV(header:rows:separator:destinationURL:rowMapper:)``
    - Menyimpan array data ke file CSV dengan header dan separator yang dapat dikustomisasi.
    - **Parameters:**
        - `header`: Array string yang berisi header CSV
        - `rows`: Array data yang akan dikonversi
        - `separator`: Pemisah kolom (default: `;`)
        - `destinationURL`: URL tujuan penyimpanan file
        - `rowMapper`: Closure untuk mengubah setiap item menjadi array string

- ``ReusableFunc/chooseFolderAndSaveCSV(header:rows:namaFile:window:sheetWindow:pythonPath:pdf:rowMapper:)``
    - Menyimpan data ke CSV kemudian mengonversinya ke XLSX/PDF menggunakan skrip Python.
    - **Parameters:**
        - `header`: Header untuk file CSV
        - `rows`: Data yang akan diekspor
        - `namaFile`: Nama file output (tanpa ekstensi)
        - `window`: Window parent untuk menampilkan sheet
        - `sheetWindow`: Window sheet yang terkait
        - `pythonPath`: Path interpreter Python
        - `pdf`: Boolean menentukan output PDF (true) atau Excel (false)
        - `rowMapper`: Closure untuk mapping data

## Python Utilities

- ``ReusableFunc/checkCommandAvailability(command:arguments:)``
    - Memeriksa ketersediaan perintah sistem dan mengembalikan outputnya.

- ``ReusableFunc/checkPythonAndPandasInstallation(window:completion:)``
    - Memeriksa dan menginstal Python 3 serta package yang diperlukan (pandas, openpyxl, reportlab).
    - **Alur Kerja:**
        1. Menampilkan progress bar
        2. Mencari instalasi Python 3
        3. Memeriksa dan menginstal package yang dibutuhkan
        4. Menyelesaikan proses dengan completion handler

- ``ReusableFunc/runPythonScript(csvFileURL:window:pythonPath:completion:)``
    - Menjalankan skrip Python "CSV2XCL.py" untuk konversi CSV ke Excel.

- ``ReusableFunc/runPythonScriptPDF(csvFileURL:window:pythonPath:completion:)``
    - Menjalankan skrip Python "CSV2PDF.py" untuk konversi CSV ke PDF.

- ``ReusableFunc/promptToSaveXLSXFile(from:previousFileName:window:sheetWindow:pdf:)``
    - Menampilkan dialog penyimpanan untuk file hasil konversi.

## Fungsi Support

- ``ReusableFunc/checkPythonInstallation(pythonFound:progressViewController:window:progressWindow:)``
     - Memverifikasi instalasi Python 3.

- ``ReusableFunc/checkAndInstallPackage(pythonPath:package:progressViewController:missingPackagesWrapper:)``
    - Memeriksa dan menginstal package Python tertentu.

- ``ReusableFunc/installPackage(pythonPath:package:progressViewController:completion:)``
    - Menginstal package Python dengan menampilkan progress real-time.

- ``ReusableFunc/updateProgressForPackage(package:progressViewController:terinstal:)``
    - Memperbarui UI progress bar selama instalasi package.

- ``ReusableFunc/finishInstallation(missingPackagesWrapper:progressViewController:window:progressWindow:pythonFound:completion:)``
    - Menyelesaikan proses instalasi dan menangani hasilnya.

> **Catatan Implementasi**
> - Menggunakan `Process` dan `Pipe` untuk menjalankan perintah sistem
> - Progress bar diperbarui secara real-time selama instalasi package
> - File temporary CSV dihapus setelah proses konversi selesai
> - Mendukung konversi ke format Excel (XLSX) dan PDF
> - Memeriksa koneksi internet sebelum menginstal package

> **Error Handling**
> - Menampilkan alert untuk Python yang tidak terinstal
> - Menangani package yang gagal diinstal
> - Menampilkan error output dari proses Python
> - Membersihkan file temporary bahkan ketika proses gagal
