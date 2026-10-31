import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

Future<String?> showNewGroupDialog(BuildContext context) {
  final deps = CommunityScope.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => CommunityScope(dependencies: deps, child: const _NewGroupDialog()),
  );
}

class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog();

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _name = TextEditingController();
  final _query = TextEditingController();
  final _selected = <String, UserSummary>{};
  List<UserSummary> _results = const [];
  Timer? _debounce;
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    final deps = CommunityScope.of(context);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final users = await deps.profiles.searchUsers(q);
        final me = deps.currentUser?.id;
        if (mounted) {
          setState(
            () => _results = [
              for (final u in users)
                if (u.id != me) u,
            ],
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final id = await CommunityScope.of(context).chat.createGroupRoom(_name.text.trim(), _selected.keys.toList());
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showCommunityError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return AlertDialog(
      title: Text(l10n.newGroup),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.groupName),
              onChanged: (_) => setState(() {}),
            ),
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final u in _selected.values)
                    InputChip(label: Text(u.name), onDeleted: () => setState(() => _selected.remove(u.id))),
                ],
              ),
            TextField(
              controller: _query,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchUsers),
              onChanged: _search,
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final u in _results)
                    CheckboxListTile(
                      value: _selected.containsKey(u.id),
                      secondary: CommunityAvatar(user: u, radius: 16),
                      title: Text(u.name),
                      subtitle: Text('@${u.username}'),
                      onChanged: (v) => setState(() => v! ? _selected[u.id] = u : _selected.remove(u.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _creating || _name.text.trim().isEmpty ? null : _create, child: Text(l10n.create)),
      ],
    );
  }
}
