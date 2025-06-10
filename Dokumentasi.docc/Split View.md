# Split View

SplitView adalah `contentView` yang ditampilkan oleh ``WindowController``. Dikelola oleh class `SplitVC` yang merupakan subclass dari `NSSplitViewController`.

## Overview

SplitView digunakan untuk menampilkan dua panel tampilan:
- ``SidebarViewController`` untuk mengelola tampilan panel sisi.
- ``ContainerSplitView`` untuk mengelola tampilan yang dinamis sesuai pilihan dari panel sisi.

## Topics

### Tampilan Utama
- ``SplitVC``

### Panel Sisi
- ``SidebarViewController``

### Model Data
- ``SidebarItem``
- ``SidebarGroup``

### Container View
- ``ContainerSplitView``

### Enum
- ``SidebarItemType``
- ``NameConstants``
- ``NodeType``

### Protokol
- ``AppDelegate``
- ``SidebarDelegate``

