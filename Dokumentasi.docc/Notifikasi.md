# Notifikasi

API untuk mengirim dan menerima notifikasi secara **type‑safe** menggunakan protokol ``NotificationPayload``.

## Overview

Framework notifikasi ini menyediakan cara yang aman dan terstruktur untuk mengirim dan menerima event di dalam aplikasi.  
Setiap notifikasi diwakili oleh sebuah `struct` yang mengimplementasikan ``NotificationPayload``, sehingga parsing `userInfo` menjadi strongly‑typed dan bebas dari casting manual yang rawan error.

Setiap payload:
- Memiliki properti `asUserInfo` untuk konversi ke dictionary yang kompatibel dengan `NotificationCenter`.
- Menyediakan initializer `init?(userInfo:)` untuk parsing otomatis dari notifikasi yang diterima.
- Menyediakan metode statis `.sendNotif(...)` untuk mengirim notifikasi dengan payload yang sesuai.

Dibuat untuk:
- **Type safety**, **Clarity**, **Maintainability**

### Penggunaan

Pendekatan ini menggantikan pola lama yang mengandalkan `NotificationCenter` dengan `userInfo` berbasis dictionary tanpa tipe yang jelas.  
Dengan `NotificationPayload`, setiap event memiliki kontrak data yang eksplisit.

1. **Kirim notifikasi** dengan `.sendNotif(...)` pada struct payload.
2. **Terima notifikasi** dengan ``Foundation/NotificationCenter/addObserver(forName:object:queue:filter:using:)`` kustom yang langsung mem‑parse payload ke tipe yang sesuai.
3. **Gunakan data** tanpa perlu casting manual.

## Topics

### Protokol

- ``NotificationPayload``

### Structures

- ``DeleteNilaiKelasNotif``
- ``NilaiKelasNotif``
- ``NotifSiswaDihapus``
- ``NotifSiswaDiedit``
- ``UndoActionNotification``
