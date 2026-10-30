import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/core/format/time_format.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/admin_frame.dart';
import 'package:cs_console/src/features/admin/presentation/widgets/settings_support.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

final _opensPattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
final _closesPattern = RegExp(r'^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$');

String holidayKindLabel(BuildContext context, HolidayKind kind) {
  final l10n = context.l10n;
  return switch (kind) {
    HolidayKind.national => l10n.holidayNational,
    HolidayKind.collectiveLeave => l10n.holidayCollective,
    HolidayKind.exchange => l10n.holidayExchange,
  };
}

class HoursView extends StatelessWidget {
  const HoursView({super.key, required this.admin});

  final AdminRepository admin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminFrame(
      title: l10n.hoursTitle,
      description: l10n.hoursDescription,
      children: [
        AdminLoader<SettingEntry>(
          builder: (context, settings) {
            final hours = findSetting(settings, 'service.hours');
            return hours == null ? const SizedBox.shrink() : _ServiceHours(admin: admin, entry: hours);
          },
        ),
        _Holidays(admin: admin),
      ],
    );
  }
}

class _DayHours {
  _DayHours(Object? value)
    : open = value is List && value.length == 2,
      opens = TextEditingController(text: value is List && value.length == 2 ? '${value[0]}' : '08:00'),
      closes = TextEditingController(text: value is List && value.length == 2 ? '${value[1]}' : '17:00');

  bool open;
  final TextEditingController opens;
  final TextEditingController closes;

  bool get valid =>
      !open ||
      (_opensPattern.hasMatch(opens.text.trim()) &&
          _closesPattern.hasMatch(closes.text.trim()) &&
          opens.text.trim().compareTo(closes.text.trim()) < 0);

  Object? get value => open ? [opens.text.trim(), closes.text.trim()] : null;

  void dispose() {
    opens.dispose();
    closes.dispose();
  }
}

class _ServiceHours extends StatefulWidget {
  const _ServiceHours({required this.admin, required this.entry});

  final AdminRepository admin;
  final SettingEntry entry;

  @override
  State<_ServiceHours> createState() => _ServiceHoursState();
}

class _ServiceHoursState extends State<_ServiceHours> {
  late final Map<int, _DayHours> _days = {
    for (var day = 1; day <= 7; day++)
      day: _DayHours(widget.entry.value is Map ? (widget.entry.value! as Map)['$day'] : null),
  };
  bool _showErrors = false;

  @override
  void dispose() {
    for (final day in _days.values) {
      day.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_days.values.any((d) => !d.valid)) return;
    await saveSettings(context, widget.admin, {
      'service.hours': {for (final MapEntry(:key, :value) in _days.entries) '$key': value.value},
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final weekday = DateFormat('EEEE', 'id');
    return SettingsCard(
      title: l10n.serviceHours,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: number, value: day) in _days.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(weekday.format(DateTime(2024, 1, number)))),
                  SizedBox(
                    width: 120,
                    child: Row(
                      children: [
                        Switch(value: day.open, onChanged: (value) => setState(() => day.open = value)),
                        const SizedBox(width: 6),
                        Text(day.open ? l10n.dayOpen : l10n.dayClosed),
                      ],
                    ),
                  ),
                  if (day.open) ...[
                    _TimeField(controller: day.opens, label: l10n.opensAt, onChanged: () => setState(() {})),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                    _TimeField(controller: day.closes, label: l10n.closesAt, onChanged: () => setState(() {})),
                    if (_showErrors && !day.valid) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(l10n.hoursInvalid, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              SaveButton(label: l10n.saveHours, onPressed: _save),
              const SizedBox(width: 12),
              Expanded(child: ChangedBy(entry: widget.entry)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.controller, required this.label, required this.onChanged});

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: TextField(
      controller: controller,
      maxLength: 5,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label, hintText: 'HH:MM', counterText: '', border: const OutlineInputBorder()),
    ),
  );
}

class _Holidays extends StatefulWidget {
  const _Holidays({required this.admin});

  final AdminRepository admin;

  @override
  State<_Holidays> createState() => _HolidaysState();
}

class _HolidaysState extends State<_Holidays> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      key: ValueKey(_year),
      create: (_) => AdminListCubit<Holiday>(() => widget.admin.holidays(_year))..load(),
      child: Builder(
        builder: (context) => SettingsCard(
          title: l10n.holidaysTitle('$_year'),
          subtitle: l10n.holidaysHint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.previousYear,
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$_year', style: Theme.of(context).textTheme.titleSmall),
                  IconButton(
                    tooltip: l10n.nextYear,
                    onPressed: () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showHolidayDialog(context, widget.admin, _year),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addHoliday),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdminLoader<Holiday>(
                builder: (context, holidays) => holidays.isEmpty
                    ? Padding(padding: const EdgeInsets.all(8), child: Text(l10n.noHolidays))
                    : AdminTable(
                        columns: [l10n.holidayDate, l10n.holidayName, l10n.holidayKind, ''],
                        rows: [
                          for (final holiday in holidays)
                            DataRow(cells: [
                              DataCell(Text(DateFormat('EEE, d MMM yyyy', 'id').format(holiday.day))),
                              DataCell(Text(holiday.name)),
                              DataCell(Text(holidayKindLabel(context, holiday.kind))),
                              DataCell(IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _confirmDelete(context, widget.admin, holiday),
                              )),
                            ]),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, AdminRepository admin, Holiday holiday) async {
  final l10n = context.l10n;
  final cubit = context.read<AdminListCubit<Holiday>>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteHolidayTitle),
      content: Text(l10n.deleteHolidayBody(holiday.name, shortDate(holiday.day))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await cubit.save((_) => admin.deleteHoliday(holiday.day));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> _showHolidayDialog(BuildContext context, AdminRepository admin, int year) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider.value(
    value: context.read<AdminListCubit<Holiday>>(),
    child: _HolidayDialog(admin: admin, year: year),
  ),
);

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({required this.admin, required this.year});

  final AdminRepository admin;
  final int year;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _name = TextEditingController();
  DateTime? _day;
  HolidayKind _kind = HolidayKind.national;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(widget.year),
      lastDate: DateTime(widget.year, 12, 31),
      initialDate: _day ?? (now.year == widget.year ? now : DateTime(widget.year)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _submit() async {
    final day = _day;
    if (day == null || _name.text.trim().length < 2) return;
    setState(() => _error = null);
    try {
      await context.read<AdminListCubit<Holiday>>().save(
        (_) => widget.admin.saveHoliday(Holiday(day: day, name: _name.text.trim(), kind: _kind)),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = context.select((AdminListCubit<Holiday> c) => c.state.saving);
    final ready = _day != null && _name.text.trim().length >= 2;
    return AlertDialog(
      title: Text(l10n.addHoliday),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.event, size: 18),
              label: Text(_day == null ? l10n.holidayDate : DateFormat('EEEE, d MMMM yyyy', 'id').format(_day!)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.holidayName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<HolidayKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.holidayKind, border: const OutlineInputBorder()),
              items: [
                for (final kind in HolidayKind.values)
                  DropdownMenuItem(value: kind, child: Text(holidayKindLabel(context, kind))),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            DialogError(_error),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: saving || !ready ? null : _submit,
          child: saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
