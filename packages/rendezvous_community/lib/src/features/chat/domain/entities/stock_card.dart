const maxStockCards = 3;

final stockCardCodePattern = RegExp(r'^[A-Z][A-Z0-9]{1,11}$');

String? normalizeStockCardCode(String raw) {
  final code = raw.replaceAll(RegExp(r'[\s$]'), '').toUpperCase();
  return stockCardCodePattern.hasMatch(code) ? code : null;
}

List<String> normalizeStockCardCodes(Iterable<String> raw) =>
    <String>{for (final code in raw) ?normalizeStockCardCode(code)}.take(maxStockCards).toList();
