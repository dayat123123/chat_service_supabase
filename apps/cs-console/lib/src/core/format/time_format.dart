import 'package:intl/intl.dart';

String clock(DateTime time) => DateFormat('HH.mm', 'id').format(time.toLocal());

String stamp(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final sameDay = local.year == current.year && local.month == current.month && local.day == current.day;
  if (sameDay) return clock(time);
  final pattern = local.year == current.year ? 'd MMM, HH.mm' : 'd MMM yyyy, HH.mm';
  return DateFormat(pattern, 'id').format(local);
}

String shortDate(DateTime time) => DateFormat('d MMM yyyy', 'id').format(time.toLocal());

String waitLabel(Duration wait) {
  if (wait.inMinutes < 1) return '<1m';
  if (wait.inHours < 1) return '${wait.inMinutes}m';
  if (wait.inDays < 1) return '${wait.inHours}j ${wait.inMinutes % 60}m';
  return '${wait.inDays}h ${wait.inHours % 24}j';
}

String minutesLabel(double? minutes) {
  if (minutes == null) return '–';
  if (minutes < 1) return '<1 mnt';
  if (minutes < 60) return '${NumberFormat('#,##0.#', 'id').format(minutes)} mnt';
  final total = minutes.round();
  return '${total ~/ 60} j ${total % 60} mnt';
}

String ratingLabel(double? rating) => rating == null ? '–' : NumberFormat('0.0', 'id').format(rating);

String rupiah(num value) => NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(value);

String number(num value) => NumberFormat.decimalPattern('id').format(value);
