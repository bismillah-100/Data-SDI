//
//  Pengaturan.swift
//  Data SDI
//
//  Created by Ays on 27/05/25.
//

import SwiftUI
import Charts

/// `PreferensiView` adalah tampilan SwiftUI yang menampilkan pengaturan aplikasi, termasuk opsi untuk prediksi pengetikan, pengelolaan nama guru di kelas aktif, pembaruan aplikasi, dan pengaturan umum lainnya.
/// Tampilan ini menggunakan `PengaturanViewModel` sebagai `@StateObject` untuk mengelola status dan logika bisnis terkait pengaturan.
/// Tampilan ini juga menyediakan opsi untuk mengatur jumlah prediksi yang ditampilkan saat mengetik, serta opsi untuk menyimpan dan memperbarui nama guru di kelas aktif.
struct PreferensiView: View {
    // Gunakan ViewModel sebagai StateObject
    /// ViewModel yang mengatur interaksi dengan data UserDefaults.
    @StateObject private var viewModel = PengaturanViewModel()

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

            /// **Nama Guru Kelas Aktif**
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    title: { Text("Nama Guru Kelas Aktif").bold().font(.headline) },
                    icon: { Image(systemName: "graduationcap.fill") }
                )

                Text("Pengelola data guru ketika nama guru di Kelas Aktif diperbarui.")
                    .font(.subheadline) // atau .caption
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }.padding(EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 40))
            LazyVStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $viewModel.catatKeDaftarGuru) { // viewModel
                    VStack(alignment: .leading, spacing: 2, content: {
                        Text("Simpan guru baru ke Daftar Guru")
                        Text("Saat aktif: Nama guru baru akan disimpan ke Daftar Guru setelah menambahkan nilai di Kelas Aktif, jika nama guru tersebut belum terdata di Daftar Guru.")
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .font(.subheadline)
                    })
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                // .onChange sudah ditangani di ViewModel setter
                Divider()

                Toggle(isOn: $viewModel.updateNamaGuru) { // viewModel
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Perbarui semua nama guru yang sama")
                        Text("Saat aktif: Setelah memperbarui nama guru aplikasi akan mencari nama guru yang sama di Kelas Aktif yang sama dan juga memperbaruinya dengan nama baru, jika mata pelajaran juga sama.")
                            .font(.subheadline) // atau .caption
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                    }
                }

                .toggleStyle(SwitchToggleStyle()).controlSize(.mini)
                // .onChange sudah ditangani di ViewModel setter
                Divider()

                Toggle(isOn: $viewModel.timpaNamaGuru) { // viewModel
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timpa nama guru sebelumnya")
                        Text("Saat diaktifkan: setelah memperbarui nama guru aplikasi juga akan memperbarui semua nama guru yang sama jika: Mata Pelajaran sama dan Kelas Aktif juga sama")
                            .font(.subheadline)
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                    }
                }
                .disabled(!viewModel.updateNamaGuru) // viewModel
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                // .onChange sudah ditangani di ViewModel setter
                Spacer()
                Divider()
                Label {
                    Text("Pengaturan Nama Guru di Kelas Aktif tidak berlaku untuk data kelas yang tidak di Kelas Aktif. Data kelas yang ada pada siswa (di Rincian Siswa) jika tidak ada di Kelas Aktif, maka tidak akan terpengaruh ketika mengubah nama guru di Kelas Aktif.")
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
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
        ReusableFunc.showProgressWindow(2, pesan: "Semua Dialog direset", image: ReusableFunc.menuOnStateImage!)
    }
}

@available(macOS 13.0, *)
#Preview {
    PreferensiView()
}
