import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

String typingText(CommunityLocalizations l10n, Iterable<UserSummary> users, {bool direct = false}) {
  final list = users.toList();
  if (list.isEmpty) return '';
  if (direct) return l10n.typingShort;
  return list.length == 1 ? l10n.typing(list.first.name) : l10n.typingMany;
}
