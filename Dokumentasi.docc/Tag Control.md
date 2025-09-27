# ``DataSDI/TagControl``

## Overview

`TagControl` adalah subclass dari `NSControl` yang merepresentasikan elemen tag berbentuk lingkaran berwarna, dengan dukungan interaksi mouse, status seleksi, dan ikon dinamis.  
Kelas ini dirancang untuk digunakan di antarmuka macOS, termasuk di dalam menu kustom (`NSMenuItem.view`).

`TagControl` menampilkan lingkaran berwarna yang dapat:
- Menunjukkan status **terpilih** (``isSelected``).
- Menampilkan ikon **tambah**, **centang**, atau **hapus** tergantung status.
- Merespons peristiwa *mouse hover* (`mouseEntered`/`mouseExited`) untuk memperbarui tampilan dan teks terkait.
- Mengirim aksi (`action`) ke target saat diklik.

Area pelacakan (`NSTrackingArea`) dibuat satu kali saat inisialisasi ``TagControl``
melalui `init(_:frame:)`, dengan margin tambahan untuk memperluas area interaksi
untuk respons hover yang lebih nyaman.

Untuk kebutuhan area pelacakan yang dinamis (misalnya ukuran view berubah),
perilaku ini dapat diubah dengan meng-`override` fungsi `updateTrackingAreas()`.

Pada implementasi ini, ``TagControl`` ditempatkan di dalam `NSView` container
yang menjadi `view` dari sebuah `NSMenuItem`. Karena frame `NSView` di dalam
`NSMenu` umumnya bersifat statis dan tidak berubah ukuran, pembaruan area
pelacakan secara dinamis tidak memberikan peningkatan berarti.

> **Impelementasi:**
> ``DataSDI/SiswaViewController/createCustomMenu()``
> ``DataSDI/SiswaViewController/createCustomMenu2()``

Desain ini dipilih untuk mengurangi kompleksitas dan menghindari overhead
pemanggilan `updateTrackingAreas()` yang tidak diperlukan.

## Penggunaan

`TagControl` dapat ditempatkan di `NSView` atau di dalam `NSMenuItem.view`.

Pada implementasi di bawah ini, area pelacakan (`NSTrackingArea`) dibuat sekali saat inisialisasi di ``init(_:frame:)`` dengan margin tambahan untuk memperluas area interaksi.

Untuk pelacakan dinamis — misalnya ketika ``TagControl`` ditambahkan ke
sebuah `NSView` yang tinggi dan lebarnya dapat berubah —
area pelacakan (`NSTrackingArea`) lama harus dihapus terlebih dahulu
menggunakan `removeTrackingArea(_:)`.

Setelah itu, buat area pelacakan baru dengan memanggil ``setupTrackingArea()``
di dalam implementasi `updateTrackingAreas()` sambil menyimpan referensi `trackingArea` yang merupakan `NSTrackingArea` supaya mudah ketika dibersihkan.
Langkah ini memastikan area pelacakan selalu sesuai dengan ukuran `bounds`
terbaru dari view.

```swift
let tag = TagControl(NSColor.systemBlue,
                     frame: NSRect(x: 0, y: 0, width: 20, height: 20))
tag.target = self
tag.action = #selector(tagClicked(_:))

let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
containerView.addSubview(tag)

@objc func tagClicked(_ sender: TagControl) {
    print("Tag clicked:", sender.color)
}
```

## Topics

### Properti Tampilan & Status

- ``kelasValue``
- ``textField``
- ``isSelected``
- ``unselected``
- ``multipleItem``
- ``color``  
- ``mouseInside``  
- ``updateTextWork``

### Pelacakan Mouse

- ``setupTrackingArea()``

### Event Mouse

- ``mouseEntered(with:)``  
- ``mouseExited(with:)``
- ``mouseDown(with:)``

### Rendering

- ``draw(_:)``
- ``addPath(_:)`` 
- ``tickPath(_:)``
- ``removePath(_:)`` 

### Utilitas
- ``colorName(for:)``

### State
- ``viewDidHide()``
