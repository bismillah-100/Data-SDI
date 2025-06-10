/// Struct yang dirancang untuk menyimpan data bulanan dalam satu tahun tertentu.
/// Setiap bulan direpresentasikan sebagai sebuah properti String, memungkinkan fleksibilitas dalam jenis data yang disimpan
/// (misalnya, jumlah, status, atau deskripsi).
/// Kepatuhannya terhadap protokol Hashable berarti objek MonthlyData dapat dengan mudah digunakan dalam koleksi
/// seperti Set atau sebagai kunci dalam Dictionary.
struct MonthlyData: Hashable {
    /// `year` adalah tahun yang direpresentasikan oleh data bulanan ini.
    var year: Int

    /// `januari` menyimpan data untuk bulan Januari.
    var januari: String

    /// `februari` menyimpan data untuk bulan Februari.
    var februari: String

    /// `maret` menyimpan data untuk bulan Maret.
    var maret: String

    /// `april` menyimpan data untuk bulan April.
    var april: String

    /// `mei` menyimpan data untuk bulan Mei.
    var mei: String

    /// `juni` menyimpan data untuk bulan Juni.
    var juni: String

    /// `juli` menyimpan data untuk bulan Juli.
    var juli: String

    /// `agustus` menyimpan data untuk bulan Agustus.
    var agustus: String

    /// `september` menyimpan data untuk bulan September.
    var september: String

    /// `oktober` menyimpan data untuk bulan Oktober.
    var oktober: String

    /// `november` menyimpan data untuk bulan November.
    var november: String

    /// `desember` menyimpan data untuk bulan Desember.
    var desember: String

    /// Inisialisasi `MonthlyData` dengan tahun yang ditentukan.
    /// Semua properti bulan diinisialisasi dengan nilai string kosong (`""`) sebagai default.
    ///
    /// - Parameter year: Tahun yang akan diwakili oleh instance `MonthlyData` ini.
    init(year: Int) {
        self.year = year
        januari = ""
        februari = ""
        maret = ""
        april = ""
        mei = ""
        juni = ""
        juli = ""
        agustus = ""
        september = ""
        oktober = ""
        november = ""
        desember = ""
    }
}
