import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/settings_support.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AssignmentView extends StatelessWidget {
  const AssignmentView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminFrame(
      title: l10n.assignmentTitle,
      description: l10n.assignmentDescription,
      children: [
        AdminLoader<SettingEntry>(builder: (context, settings) => _AssignmentForm(admin: admin, settings: settings)),
      ],
    );
  }
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({required this.admin, required this.settings});

  final AdminRepository admin;
  final List<SettingEntry> settings;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  late String _mode = '${_value('assignment.mode') ?? 'claim'}';
  late final int _savedRelease = _int('ticket.auto_release_offline_minutes', 0);
  late bool _release = _savedRelease > 0;
  late final _releaseMinutes = TextEditingController(text: '${_savedRelease > 0 ? _savedRelease : 30}');
  late final _unclaimed = TextEditingController(text: '${_int('alerts.unclaimed_minutes', 10)}');
  late final _p1 = TextEditingController(text: '${_int('alerts.p1_unclaimed_minutes', 2)}');
  final _alertsForm = GlobalKey<FormState>();
  final _releaseForm = GlobalKey<FormState>();

  Object? _value(String key) => findSetting(widget.settings, key)?.value;

  int _int(String key, int fallback) => (_value(key) as num?)?.toInt() ?? fallback;

  @override
  void dispose() {
    _releaseMinutes.dispose();
    _unclaimed.dispose();
    _p1.dispose();
    super.dispose();
  }

  String? Function(String?) _range(int min, int max) => (value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number != null && number >= min && number <= max ? null : context.l10n.numberRange(min, max);
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = findSetting(widget.settings, 'assignment.mode');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsCard(
          title: l10n.assignmentMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: _mode,
                onChanged: (value) => setState(() => _mode = value ?? _mode),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'claim',
                      title: Text(l10n.modeClaim),
                      subtitle: Text(l10n.modeClaimHint),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'auto_assign',
                      title: Text(l10n.modeAuto),
                      subtitle: Text(l10n.modeAutoHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SaveButton(
                    label: l10n.save,
                    onPressed: _mode == current?.value ? null : () => saveSettings(context, widget.admin, {'assignment.mode': _mode}),
                  ),
                  const SizedBox(width: 12),
                  if (current != null) Expanded(child: ChangedBy(entry: current)),
                ],
              ),
            ],
          ),
        ),
        SettingsCard(
          title: l10n.autoRelease,
          subtitle: l10n.autoReleaseHint,
          child: Form(
            key: _releaseForm,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Switch(value: _release, onChanged: (value) => setState(() => _release = value)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: _releaseMinutes,
                    enabled: _release,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.autoReleaseMinutes, border: const OutlineInputBorder()),
                    validator: _release ? _range(1, 1440) : null,
                  ),
                ),
                const SizedBox(width: 12),
                SaveButton(
                  label: l10n.save,
                  onPressed: () {
                    if (!_releaseForm.currentState!.validate()) return;
                    saveSettings(context, widget.admin, {
                      'ticket.auto_release_offline_minutes': _release ? int.parse(_releaseMinutes.text.trim()) : 0,
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        SettingsCard(
          title: l10n.supervisorAlerts,
          child: Form(
            key: _alertsForm,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final (controller, label) in [(_unclaimed, l10n.alertUnclaimed), (_p1, l10n.alertP1)])
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
                      validator: _range(1, 240),
                    ),
                  ),
                SaveButton(
                  label: l10n.save,
                  onPressed: () {
                    if (!_alertsForm.currentState!.validate()) return;
                    saveSettings(context, widget.admin, {
                      'alerts.unclaimed_minutes': int.parse(_unclaimed.text.trim()),
                      'alerts.p1_unclaimed_minutes': int.parse(_p1.text.trim()),
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
