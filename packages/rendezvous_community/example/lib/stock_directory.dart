import 'package:rendezvous_community/rendezvous_community.dart';

const stockNames = {
  'IHSG': 'Indeks Harga Saham Gabungan',
  'LQ45': 'Indeks LQ45',
  'IDX30': 'Indeks IDX30',
  'BBCA': 'Bank Central Asia Tbk',
  'BBRI': 'Bank Rakyat Indonesia (Persero) Tbk',
  'BMRI': 'Bank Mandiri (Persero) Tbk',
  'BBNI': 'Bank Negara Indonesia (Persero) Tbk',
  'BRIS': 'Bank Syariah Indonesia Tbk',
  'BBTN': 'Bank Tabungan Negara (Persero) Tbk',
  'ARTO': 'Bank Jago Tbk',
  'TLKM': 'Telkom Indonesia (Persero) Tbk',
  'ISAT': 'Indosat Tbk',
  'EXCL': 'XLSMART Telecom Sejahtera Tbk',
  'TOWR': 'Sarana Menara Nusantara Tbk',
  'JSMR': 'Jasa Marga (Persero) Tbk',
  'BREN': 'Barito Renewables Energy Tbk',
  'ASII': 'Astra International Tbk',
  'UNTR': 'United Tractors Tbk',
  'GOTO': 'GoTo Gojek Tokopedia Tbk',
  'BUKA': 'Bukalapak.com Tbk',
  'EMTK': 'Elang Mahkota Teknologi Tbk',
  'UNVR': 'Unilever Indonesia Tbk',
  'ICBP': 'Indofood CBP Sukses Makmur Tbk',
  'INDF': 'Indofood Sukses Makmur Tbk',
  'MYOR': 'Mayora Indah Tbk',
  'HMSP': 'H.M. Sampoerna Tbk',
  'GGRM': 'Gudang Garam Tbk',
  'CPIN': 'Charoen Pokphand Indonesia Tbk',
  'AMRT': 'Sumber Alfaria Trijaya Tbk',
  'KLBF': 'Kalbe Farma Tbk',
  'MAPI': 'Mitra Adiperkasa Tbk',
  'ERAA': 'Erajaya Swasembada Tbk',
  'ADRO': 'Alamtri Resources Indonesia Tbk',
  'PTBA': 'Bukit Asam Tbk',
  'ITMG': 'Indo Tambangraya Megah Tbk',
  'MEDC': 'Medco Energi Internasional Tbk',
  'PGAS': 'Perusahaan Gas Negara Tbk',
  'CUAN': 'Petrindo Jaya Kreasi Tbk',
  'ANTM': 'Aneka Tambang Tbk',
  'INCO': 'Vale Indonesia Tbk',
  'MDKA': 'Merdeka Copper Gold Tbk',
  'MBMA': 'Merdeka Battery Materials Tbk',
  'AMMN': 'Amman Mineral Internasional Tbk',
  'TPIA': 'Chandra Asri Pacific Tbk',
  'SMGR': 'Semen Indonesia (Persero) Tbk',
  'INTP': 'Indocement Tunggal Prakarsa Tbk',
  'PANI': 'Pantai Indah Kapuk Dua Tbk',
  'BSDE': 'Bumi Serpong Damai Tbk',
  'CTRA': 'Ciputra Development Tbk',
};

Future<List<StockSuggestion>> searchStocks(String query) async {
  final q = query.toUpperCase();
  return [
    for (final MapEntry(key: code, value: name) in stockNames.entries)
      if (code.startsWith(q)) StockSuggestion(code: code, name: name),
    for (final MapEntry(key: code, value: name) in stockNames.entries)
      if (!code.startsWith(q) && name.toUpperCase().contains(q)) StockSuggestion(code: code, name: name),
  ];
}
