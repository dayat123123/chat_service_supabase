enum ReportReason {
  spam('spam'),
  abuse('abuse'),
  scam('scam'),
  pumpAndDump('pump_and_dump'),
  misinformation('misinformation'),
  other('other');

  const ReportReason(this.wireName);
  final String wireName;
}

enum ReportTarget { post, comment, message, user }
