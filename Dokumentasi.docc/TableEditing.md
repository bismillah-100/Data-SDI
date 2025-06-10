# Edit Data Tabel

OverlayEditorManager bertindak sebagai manajer editor di setiap data tabel.

## Overview

Menyediakan NSTeksView dan NSTableView.
- NSTextView dapat secara dinamis menyesuaikan lebar dan tinggi frame sesuai dengan jumlah teks.
- NSTableView digunakan untuk menampilkan prediksi saat pengetikan.

## Topics

### Tampilan
- ``EditingViewController``
- ``PanelAutocompleteTextView``

### Manajer Editor
- ``DataSDI/OverlayEditorManager``

### Manajer Prediksi
- ``SuggestionCacheManager``

### Protokol
- ``DataSDI/OverlayEditorManagerDataSource``
- ``DataSDI/OverlayEditorManagerDelegate``

### Enumerations
- ``GrowthDirection``
