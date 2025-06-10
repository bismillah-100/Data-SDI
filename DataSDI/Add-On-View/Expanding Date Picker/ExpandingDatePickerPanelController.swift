//  Created by Fred Potter on 03/29/2019.
//  Copyright (c) 2019 Fred Potter. All rights reserved.

import AppKit

/// ExpandingDatePicker adalah pemilih tanggal kustom yang dapat diperluas menjadi panel dengan antarmuka pemilih tanggal yang lebih detail.
/// Komponen ini dirancang untuk digunakan pada aplikasi macOS di mana pemilihan tanggal yang lebih interaktif diperlukan.
class InternalDatePicker: NSDatePicker {
    weak var expandingDatePicker: ExpandingDatePicker?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            expandingDatePicker?.dismissExpandingPanel(refocusDatePicker: true)
            return
        } else {
            super.keyDown(with: event)
        }
    }
}

/// ExpandingDatePickerPanelController adalah pengontrol yang mengelola panel pemilih tanggal yang diperluas.
/// Pengontrol ini bertanggung jawab untuk menginisialisasi dan mengonfigurasi dua pemilih tanggal: satu berbasis teks dan satu berbasis grafis.
/// Keduanya terikat ke pemilih tanggal sumber (`ExpandingDatePicker`) dan menyediakan fungsionalitas untuk menangani perubahan tanggal.
/// Pengontrol ini juga mengelola binding standar dan replikasi binding dari pemilih tanggal sumber ke kedua pemilih tanggal.
class ExpandingDatePickerPanelController: NSViewController, CALayerDelegate {
    let sourceDatePicker: ExpandingDatePicker
    let datePickerTextual: InternalDatePicker
    let datePickerGraphical: NSDatePicker

    /// Inisialisasi pengontrol dengan pemilih tanggal sumber.
    /// Pengontrol ini mengonfigurasi dua pemilih tanggal: satu berbasis teks dan satu berbasis grafis.
    /// - Parameter sourceDatePicker: `ExpandingDatePicker` yang menjadi sumber tanggal untuk kedua pemilih tanggal.
    init(sourceDatePicker: ExpandingDatePicker) {
        self.sourceDatePicker = sourceDatePicker

        // Buat formatter yang akan digunakan untuk kedua date picker
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.doesRelativeDateFormatting = false

        // Gunakan locale yang konsisten
        dateFormatter.locale = Locale(identifier: "en_GB_POSIX")

        // Setup datePickerTextual
        datePickerTextual = InternalDatePicker(frame: .zero)
        datePickerTextual.datePickerMode = .single
        datePickerTextual.datePickerStyle = .textField
        datePickerTextual.datePickerElements = .yearMonthDay
        datePickerTextual.controlSize = sourceDatePicker.controlSize
        datePickerTextual.font = sourceDatePicker.font
        datePickerTextual.calendar = sourceDatePicker.calendar
        datePickerTextual.timeZone = sourceDatePicker.timeZone
        datePickerTextual.minDate = sourceDatePicker.minDate
        datePickerTextual.maxDate = sourceDatePicker.maxDate
        datePickerTextual.formatter = dateFormatter
        datePickerTextual.locale = dateFormatter.locale
        datePickerTextual.sizeToFit()
        datePickerTextual.drawsBackground = false
        datePickerTextual.isBordered = false
        datePickerTextual.isEnabled = true
        datePickerTextual.expandingDatePicker = sourceDatePicker

        // Setup datePickerGraphical
        datePickerGraphical = NSDatePicker(frame: .zero)
        datePickerGraphical.datePickerMode = .single
        datePickerGraphical.datePickerStyle = .clockAndCalendar
        datePickerGraphical.datePickerElements = .yearMonthDay
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateFormat = "dd/MM/yyyy"
        dateFormatter1.formatterBehavior = .behavior10_4
        dateFormatter1.doesRelativeDateFormatting = false

        // Gunakan locale yang konsisten
        dateFormatter1.locale = Locale(identifier: "id_ID_POSIX")
        datePickerGraphical.formatter = dateFormatter1
        datePickerGraphical.locale = dateFormatter1.locale
        datePickerGraphical.sizeToFit()
        datePickerGraphical.drawsBackground = false
        datePickerGraphical.isBordered = false
        datePickerGraphical.isEnabled = true
        datePickerGraphical.calendar = sourceDatePicker.calendar
        datePickerGraphical.timeZone = sourceDatePicker.timeZone
        datePickerGraphical.minDate = sourceDatePicker.minDate
        datePickerGraphical.maxDate = sourceDatePicker.maxDate

        // Binding standar
        let bindingOptions: [NSBindingOption: Any] = [
            .raisesForNotApplicableKeys: true,
            .continuouslyUpdatesValue: true,
        ]

        datePickerTextual.bind(.value,
                               to: sourceDatePicker,
                               withKeyPath: #keyPath(NSDatePicker.dateValue),
                               options: bindingOptions)

        datePickerGraphical.bind(.value,
                                 to: sourceDatePicker,
                                 withKeyPath: #keyPath(NSDatePicker.dateValue),
                                 options: bindingOptions)

        // Replikasi binding
        for bindingName in sourceDatePicker.exposedBindings {
            guard let bindingInfo = sourceDatePicker.infoForBinding(bindingName) else {
                continue
            }

            guard let keyPath = bindingInfo[.observedKeyPath] as? String,
                  let object = bindingInfo[.observedObject]
            else {
                continue
            }
            let options = bindingInfo[.options] as? [NSBindingOption: Any]

            datePickerTextual.bind(bindingName,
                                   to: object,
                                   withKeyPath: keyPath,
                                   options: options)
            datePickerGraphical.bind(bindingName,
                                     to: object,
                                     withKeyPath: keyPath,
                                     options: options)
        }

        super.init(nibName: nil, bundle: nil)

        datePickerTextual.target = self
        datePickerTextual.action = #selector(dateChanged(_:))
        datePickerGraphical.target = self
        datePickerGraphical.action = #selector(dateChanged(_:))

        // Pastikan formatter diterapkan ke cell
        if let cell = datePickerTextual.cell as? NSDatePickerCell {
            cell.formatter = dateFormatter
        }
        if let cell = datePickerGraphical.cell as? NSDatePickerCell {
            cell.formatter = dateFormatter
        }
    }

    // Tambahkan required initializer
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let stack = NSStackView(views: [datePickerTextual, datePickerGraphical])
        stack.spacing = 0
        stack.orientation = .vertical
        stack.alignment = .left

        // Force layout now so the `bounds` will be true.
        stack.needsLayout = true
        stack.layoutSubtreeIfNeeded()

        let backdropView = ExpandingDatePickerPanelBackdropView(frame: stack.bounds,
                                                                datePickerTextual: datePickerTextual,
                                                                datePickerGraphical: datePickerGraphical)
        backdropView.addSubview(stack)
        view = backdropView
    }

    /// Menangani perubahan tanggal pada pemilih tanggal.
    /// Metode ini dipanggil ketika pengguna mengubah tanggal pada salah satu pemilih tanggal.
    @objc
    func dateChanged(_ sender: NSDatePicker) {
        guard let target = sourceDatePicker.target,
              let action = sourceDatePicker.action
        else {
            return
        }

        let _ = target.perform(action, with: sourceDatePicker)
    }
}
