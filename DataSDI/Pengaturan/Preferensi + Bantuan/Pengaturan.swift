//
//  Pengaturan.swift
//  Data SDI
//
//  Created by Ays on 27/05/25.
//

import Charts
import SwiftUI

/// `PreferensiView` adalah tampilan SwiftUI yang menampilkan pengaturan aplikasi, termasuk opsi untuk prediksi pengetikan, pengelolaan nama guru di kelas aktif, pembaruan aplikasi, dan pengaturan umum lainnya.
/// Tampilan ini menggunakan `PengaturanViewModel` sebagai `@StateObject` untuk mengelola status dan logika bisnis terkait pengaturan.
/// Tampilan ini juga menyediakan opsi untuk mengatur jumlah prediksi yang ditampilkan saat mengetik, serta opsi untuk menyimpan dan memperbarui nama guru di kelas aktif.
struct PreferensiView: View {
    // Gunakan ViewModel sebagai StateObject
    /// ViewModel yang mengatur interaksi dengan data UserDefaults.
    @StateObject private var viewModel: PengaturanViewModel = .init()

    /// Struct view untuk mengatur interaksi kontrol dan emanmpilkan tampilan utama di jendela pengaturan.
    var body: some View {
        List {
            Text("Pengaturan")
                .bold()
                .font(.title)
                .padding(.horizontal, 10)

            /// **Prediksi Ketik**
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    title: { Text("Kapital Otomatis").bold().font(.headline) },
                    icon: { Image(systemName: "textformat") }
                )
                Text("Setelah mengetik huruf pertama kalimat sebelum spasi, (-), dan (,) akan dijadikan huruf besar dan huruf setelah (-) dan (,) akan ditambahkan spasi jika belum ada.")
                    .font(.subheadline) // atau .caption
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }.padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle("Kapitalkan Kalimat Setelah Mengetik", isOn: $viewModel.ketikKapital) // viewModel
                    .toggleStyle(SwitchToggleStyle()).controlSize(.mini)
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: NSColor.separatorColor), style: StrokeStyle(lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: 2) {
                Label(
                    title: { Text("Prediksi Ketik").bold().font(.headline) },
                    icon: { Image(systemName: "character.cursor.ibeam") }
                )
                Text("Prediksi ketika pengetikan dimulai, kecuali di bilah alat pencarian.")
                    .font(.subheadline) // atau .caption
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }.padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle("Tampilkan Prediksi Saat Mengetik", isOn: $viewModel.saranMengetik) // viewModel
                    .toggleStyle(SwitchToggleStyle()).controlSize(.mini)
                // .onChange sudah ditangani di ViewModel setter
                Divider()
                Toggle("Tampilkan Prediksi Saat Mengetik di Tabel", isOn: $viewModel.saranSiswaDanKelasAktif) // viewModel
                    .toggleStyle(SwitchToggleStyle()).controlSize(.mini)
                // .onChange sudah ditangani di ViewModel setter
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Jumlah prediksi yang ditampilkan: \(viewModel.maksimalSaran)") // viewModel
                    HStack(alignment: .center, spacing: 4) {
                        Text("1")
                        Slider(value: Binding( // viewModel
                            get: { Double(viewModel.maksimalSaran) },
                            set: { viewModel.maksimalSaran = Int($0) }
                        ), in: 1 ... 20, step: 1)
                            .padding(.zero)
                        Text("20").frame(width: 30)
                    }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: NSColor.separatorColor), style: StrokeStyle(lineWidth: 1))
            )

            /// **Database**
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    title: { Text("Normalisasi Database").bold().font(.headline) },
                    icon: { Image(systemName: "rectangle.2.swap") }
                )

                Text("Pembersihan entitas tanpa relasi untuk efisiensi basis data ketika aplikasi dibuka atau setelah menyimpan data.")
                    .font(.subheadline) // atau .caption
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }.padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $viewModel.bersihkanTabelKelas) { // viewModel
                    VStack(alignment: .leading, spacing: 2, content: {
                        Text("Kelas")
                        Text("Kelas tanpa relasi ke data kelas atau guru.")
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .font(.subheadline)
                    })
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                Divider()
                Toggle(isOn: $viewModel.bersihkanTabelSiswaKelas) { // viewModel
                    VStack(alignment: .leading, spacing: 2, content: {
                        Text("Siswa Kelas")
                        Text("Kelas tanpa relasi ke data siswa.")
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .font(.subheadline)
                    })
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                Divider()
                Toggle(isOn: $viewModel.bersihkanTabelMapel) { // viewModel
                    VStack(alignment: .leading, spacing: 2, content: {
                        Text("Mata Pelajaran")
                        Text("Mapel tanpa relasi ke data tugas atau kelas.")
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .font(.subheadline)
                    })
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                Divider()
                Toggle(isOn: $viewModel.bersihkanTabelTugas) { // viewModel
                    VStack(alignment: .leading, spacing: 2, content: {
                        Text("Tugas Guru")
                        Text("Tugas guru tanpa relasi ke data nilai.")
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .font(.subheadline)
                    })
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .stroke(Color(nsColor: NSColor.separatorColor), lineWidth: 1)
            )

            /// **Integrasi UndoManager**
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    title: { Text("Perilaku Undo Siswa & Kelas").bold().font(.headline) },
                    icon: { Image(systemName: "link") }
                )

                Text("Gabungkan Riwayat Undo antar Siswa & Kelas.")
                    .font(.subheadline) // atau .caption
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }.padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $viewModel.integrateUndoSiswaKelas) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gabungkan Riwayat (Disarankan)")
                        Text(viewModel.integrateUndoSiswaKelas
                            ? "Riwayat aksi Siswa dan Kelas menjadi satu. Menjaga konsistensi undo, namun dapat berpindah tampilan secara otomatis."
                            : "Riwayat undo-redo Siswa dan Kelas independen. Undo mungkin inkonsisten jika status atau kelas aktif siswa diperbarui.")
                            .font(.subheadline) // atau .caption
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                    }
                } // viewModel
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                Divider()
                Spacer()
                Label {
                    Text("Pengaturan ini diterapkan saat aplikasi dimulai ulang.")
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .stroke(Color(nsColor: NSColor.separatorColor), lineWidth: 1)
            )

            /// **Pembaruan Apl.**
            Label(
                title: { Text("Pembaruan Aplikasi")
                    .bold()
                    .font(.headline)
                },
                icon: { Image(systemName: "gear.badge") }
            ).padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))

            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle("Cek Pembaruan Otomatis", isOn: $viewModel.autoUpdateCheck) // viewModel
                    .toggleStyle(SwitchToggleStyle())
                    .controlSize(.mini)
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .stroke(Color(nsColor: NSColor.separatorColor), lineWidth: 1)
            )

            /// **Lainnya**
            Label(
                title: { Text("Umum").bold().font(.headline) },
                icon: { Image(systemName: "wrench.and.screwdriver.fill") }
            ).padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Button(action: resetSuppressAlert, label: {
                    Text("Reset Semua Dialog Peringatan")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding()
                })
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .circular)
                    .stroke(Color(nsColor: NSColor.separatorColor), lineWidth: 1)
            )
        }
        .frame(minWidth: 227, maxWidth: 350)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }

    /// Fungsi untuk mereset aturan yang menampilkan dialog peringatan sebelum menghapus data.
    private func resetSuppressAlert() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasSuffix("Alert") }
        for key in keys {
            UserDefaults.standard.set(false, forKey: key)
        }
        UserDefaults.standard.synchronize() // Pastikan perubahan disimpan
        ReusableFunc.showProgressWindow(2, pesan: "Semua Dialog direset", image: ReusableFunc.menuOnStateImage)
    }
}

@available(macOS 13.0, *)
#Preview {
    PreferensiView()
}
