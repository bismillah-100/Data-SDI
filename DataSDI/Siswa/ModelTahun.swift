struct MonthlyData: Hashable {
    var year: Int
    var januari: String
    var februari: String
    var maret: String
    var april: String
    var mei: String
    var juni: String
    var juli: String
    var agustus: String
    var september: String
    var oktober: String
    var november: String
    var desember: String

    // menyiapkan dengan nilai default untuk setiap bulan
    init(year: Int) {
        self.year = year
        self.januari = ""
        self.februari = ""
        self.maret = ""
        self.april = ""
        self.mei = ""
        self.juni = ""
        self.juli = ""
        self.agustus = ""
        self.september = ""
        self.oktober = ""
        self.november = ""
        self.desember = ""
    }
}
