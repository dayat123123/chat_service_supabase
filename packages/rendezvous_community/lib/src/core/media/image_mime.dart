const attachmentBucket = 'attachments';
const avatarBucket = 'avatars';
const supportDocumentBucket = 'cs-documents';
const gifMimeType = 'image/gif';
const pdfMimeType = 'application/pdf';
const maxSupportDocumentBytes = 10 * 1024 * 1024;

bool isPdfFile(String name, [String? reported]) => reported == pdfMimeType || name.toLowerCase().endsWith('.pdf');

String imageExtension(String mimeType) => switch (mimeType) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/gif' => 'gif',
  _ => 'jpg',
};

String mimeFromName(String name, [String? reported]) {
  if (reported != null && reported.startsWith('image/')) return reported;
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
