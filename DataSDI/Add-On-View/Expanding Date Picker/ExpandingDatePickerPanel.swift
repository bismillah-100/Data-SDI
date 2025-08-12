//  Created by Fred Potter on 03/29/2019.
//  Copyright (c) 2019 Fred Potter. All rights reserved.

import AppKit

/// ExpandingDatePickerPanel adalah panel kustom yang digunakan untuk menampilkan pemilih tanggal yang diperluas.
/// Panel ini dirancang untuk digunakan dengan `ExpandingDatePicker` dan menyediakan antarmuka yang lebih interaktif
/// untuk memilih tanggal. Panel ini menangani berbagai operasi seperti pengunduran fokus, pemilihan tampilan kunci berikutnya,
/// dan pengoperasian lainnya yang terkait dengan pemilih tanggal.
class ExpandingDatePickerPanel: NSPanel {
    weak var sourceDatePicker: ExpandingDatePicker?

    override var canBecomeKey: Bool {
        true
    }

    override func resignKey() {
        super.resignKey()
        sourceDatePicker?.dismissExpandingPanel()
    }

    override func cancelOperation(_: Any?) {
        sourceDatePicker?.dismissExpandingPanel(refocusDatePicker: true)
    }

    override func selectNextKeyView(_: Any?) {
        sourceDatePicker?.dismissExpandingPanel()
        if let nextKeyView = sourceDatePicker?.nextKeyView {
            sourceDatePicker?.window?.makeFirstResponder(nextKeyView)
        }
    }

    override func selectPreviousKeyView(_: Any?) {
        sourceDatePicker?.dismissExpandingPanel()
        if let previousKeyView = sourceDatePicker?.previousKeyView {
            sourceDatePicker?.window?.makeFirstResponder(previousKeyView)
        }
    }
}
