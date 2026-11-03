import 'dart:typed_data';

class CommunityDataExport {
  const CommunityDataExport({required this.bytes, required this.fileName});

  static const mimeType = 'application/json';

  final Uint8List bytes;
  final String fileName;

  static String fileNameFor(String owner, DateTime date) {
    final safe = owner.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final day =
        '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    return 'data-komunitas-${safe.isEmpty ? 'akun' : safe}-$day.json';
  }
}
