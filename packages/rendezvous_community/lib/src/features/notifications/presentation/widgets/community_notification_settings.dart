import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/cubit/notification_preferences_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

Future<void> openCommunityNotificationSettings(BuildContext context) {
  final features = CommunityFeatureScope.of(context);
  final title = context.communityL10n.notificationSettings;
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CommunityFeatureScope(
        dependencies: features,
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
                child: const SingleChildScrollView(child: CommunityNotificationSettings()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CommunityNotificationSettings extends StatelessWidget {
  const CommunityNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.of(context);
    return BlocProvider(
      create: (_) => NotificationPreferencesCubit(features.notificationPreferences)..load(),
      child: const _SettingsView(),
    );
  }
}

String notificationTypeLabel(CommunityLocalizations l10n, String type) => switch (type) {
  'reply' => l10n.notifTypeReply,
  'mention' => l10n.notifTypeMention,
  'like' => l10n.notifTypeLike,
  'follow' => l10n.notifTypeFollow,
  'message' => l10n.notifTypeMessage,
  'announcement' => l10n.notifTypeAnnouncement,
  'appeal' => l10n.notifTypeAppeal,
  'followed_post' => l10n.notifTypeFollowedPost,
  'watchlist_digest' => l10n.notifTypeWatchlistDigest,
  'moderation' => l10n.notifTypeModeration,
  notificationTradeType => l10n.notifTypeTrade,
  notificationFundsType => l10n.notifTypeFunds,
  notificationMarketType => l10n.notifTypeMarket,
  notificationOltInfoType => l10n.notifTypeOltInfo,
  notificationPromoType => l10n.notifTypePromo,
  _ => type,
};

String? notificationTypeDescription(CommunityLocalizations l10n, String type) => switch (type) {
  notificationTradeType => l10n.notifTypeTradeHint,
  notificationFundsType => l10n.notifTypeFundsHint,
  notificationMarketType => l10n.notifTypeMarketHint,
  notificationOltInfoType => l10n.notifTypeOltInfoHint,
  notificationPromoType => l10n.notifTypePromoHint,
  'followed_post' => l10n.notifTypeFollowedPostHint,
  'watchlist_digest' => l10n.notifTypeWatchlistDigestHint,
  'moderation' => l10n.notifTypeModerationHint,
  _ => null,
};

String? _formatTime(TimeOfDay? time) =>
    time == null ? null : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTime(String? value) {
  final parts = (value ?? '').split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null ? null : TimeOfDay(hour: hour, minute: minute);
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.preference, required this.muted});

  final NotificationTypePreference preference;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final cubit = context.read<NotificationPreferencesCubit>();
    final pref = preference;
    final description = notificationTypeDescription(l10n, pref.type);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(notificationTypeLabel(l10n, pref.type)),
                if (description != null) Text(description, style: muted),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: pref.supportsInApp
                ? Switch(
                    value: pref.inApp ?? true,
                    onChanged: pref.inAppLocked ? null : (value) => cubit.setChannel(pref.type, inApp: value),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(
            width: 72,
            child: Switch(
              value: pref.push,
              onChanged: (value) => cubit.setChannel(pref.type, push: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _pickTime(BuildContext context, QuietHours quiet, {required bool start}) async {
    final cubit = context.read<NotificationPreferencesCubit>();
    final initial = _parseTime(start ? quiet.start : quiet.end) ?? TimeOfDay(hour: start ? 22 : 6, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    await cubit.setQuietHours(
      quiet.copyWith(
        enabled: true,
        start: start ? _formatTime(picked) : quiet.start ?? '22:00',
        end: start ? quiet.end ?? '06:00' : _formatTime(picked),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return BlocConsumer<NotificationPreferencesCubit, NotificationPreferencesState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<NotificationPreferencesCubit>();
        switch (state.status) {
          case LoadStatus.initial || LoadStatus.loading:
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: LinearProgressIndicator(),
            );
          case LoadStatus.failure:
            return ListTile(
              leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
              title: Text(l10n.errorMessage(state.error!)),
              trailing: TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
            );
          case LoadStatus.ready:
            break;
        }
        final quiet = state.preferences.quietHours;
        final oltTypes = [
          for (final pref in state.preferences.types)
            if (pref.isOlt) pref,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    child: Text(l10n.notifInApp, textAlign: TextAlign.center, style: muted),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(l10n.notifPush, textAlign: TextAlign.center, style: muted),
                  ),
                ],
              ),
            ),
            for (final pref in state.preferences.types)
              if (!pref.isOlt) _TypeRow(preference: pref, muted: muted),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l10n.notifSupportAlwaysOn, style: muted),
            ),
            if (oltTypes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(l10n.notifSectionOlt, style: theme.textTheme.titleSmall),
              ),
              for (final pref in oltTypes) _TypeRow(preference: pref, muted: muted),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(l10n.notifOltImportantHint, style: muted),
              ),
            ],
            SwitchListTile(
              title: Text(l10n.quietHours),
              subtitle: Text(
                quiet.enabled && quiet.start != null && quiet.end != null
                    ? '${l10n.quietHoursRange(quiet.start!, quiet.end!)}\n${l10n.quietHoursHint}'
                    : l10n.quietHoursHint,
                style: muted,
              ),
              isThreeLine: quiet.enabled,
              value: quiet.enabled,
              onChanged: (enabled) => cubit.setQuietHours(
                quiet.copyWith(
                  enabled: enabled,
                  start: enabled ? quiet.start ?? '22:00' : null,
                  end: enabled ? quiet.end ?? '06:00' : null,
                ),
              ),
            ),
            if (quiet.enabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickTime(context, quiet, start: true),
                      icon: const Icon(Icons.bedtime_outlined, size: 18),
                      label: Text('${l10n.quietHoursStart} ${quiet.start ?? '22:00'}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickTime(context, quiet, start: false),
                      icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                      label: Text('${l10n.quietHoursEnd} ${quiet.end ?? '06:00'}'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
