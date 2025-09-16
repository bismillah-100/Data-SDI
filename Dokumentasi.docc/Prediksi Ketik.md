# Prediksi Ketik

Menampilkan prediksi ketika mengetik.

## Overview

Ada dua implementasi: ``SuggestionManager`` dan ``OverlayEditorManager``.

1. ``SuggestionManager`` digunakan untuk pengeditan di dalam `NSTextField`.
    - Menggunakan `NSPanel` untuk menampilkan view.
    - Semua prediksi yang akan digunakan di *fetch* satu kali di ``ReusableFunc/updateSuggestions()`` dan ``ReusableFunc/updateSuggestionsEntity()`` sesuai dengan kolom.
    - Ketika ada penambahan/pembaruan data, prediksi akan diperbarui dengan cara menambahkan ke prediksi yang sudah ada tanpa memuat ulang seluruh prediksi dari database.
    - Penentuan kolom diatur dari `NSTextFieldDelegate` ketika `controlTextDidBeginEditing` dari class yang memuat input pengetikan `NSTextField`.
    - Pembaruan real-time untuk prediksi sesuai dengan pengetikan diatur dari `controlTextDidChange` dari class yang memuat input pengetikan `NSTextField`.

2. ``OverlayEditorManager`` digunakan untuk pengeditan di dalam tabel.
    - Menggunakan `NSView` yang ditambahkan sebagai `childView` dengan superview `NSTableView` yang melakukan pengeditan sebagai `parent`.
    - Menggunakan `NSPanel` untuk memuat `NSTableView` yang menampilkan prediksi.
    - Semua prediksi yang akan digunakan di *fetch* satu kali di ``ReusableFunc/updateSuggestions()`` dan ``ReusableFunc/updateSuggestionsEntity()`` sesuai dengan kolom.
    - Pembaruan prediksi real-time di atur ketika `didChangeText` di ``PanelAutocompleteTextView``.
    - Prediksi yang ditampilkan di atur dari `updateSuggestions` di ``PanelAutocompleteTextView``.
    - Prediksi akan disimpan ke cache ``SuggestionCacheManager`` setiap kali pengguna mengetik.
    - Ketika pembaruan di commit, nilai baru akan ditambahkan ke dalam cache jika belum ada.


## Topics

### Suggestion Manager
- ``SuggestionManager``
- ``SuggestionItemView``
- ``SuggestionView``
- ``SuggestionWindow``

### Pendukung UI
- ``LineView``

### Overlay Editor
- ``OverlayEditorManager``
- ``OverlayEditorManagerDelegate``
- ``OverlayEditorManagerDataSource``
- ``EditingViewController``
- ``PanelAutocompleteTextView``
- ``SuggestionCacheManager``
