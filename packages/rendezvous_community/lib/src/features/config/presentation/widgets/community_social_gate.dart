import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

enum CommunityUnavailableReason { socialDisabled, featureDisabled }

typedef CommunityUnavailableBuilder =
    Widget Function(BuildContext context, CommunityUnavailableReason reason, Widget fallback);

class CommunityAvailabilityScope extends InheritedWidget {
  const CommunityAvailabilityScope({super.key, required this.builder, required super.child});

  final CommunityUnavailableBuilder builder;

  static CommunityUnavailableBuilder? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityAvailabilityScope>()?.builder;

  @override
  bool updateShouldNotify(CommunityAvailabilityScope oldWidget) => !identical(builder, oldWidget.builder);
}

class CommunitySocialGate extends StatelessWidget {
  const CommunitySocialGate({super.key, required this.child, this.feature, this.unavailableBuilder});

  final Widget child;
  final String? feature;
  final CommunityUnavailableBuilder? unavailableBuilder;

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.maybeOf(context);
    if (features == null) return child;
    return ValueListenableBuilder<ClientConfig>(
      valueListenable: features.configService.listenable,
      child: child,
      builder: (context, config, child) {
        final feature = this.feature;
        if (config.socialEnabled && (feature == null || config.flag(feature))) return child!;
        final reason = config.socialEnabled
            ? CommunityUnavailableReason.featureDisabled
            : CommunityUnavailableReason.socialDisabled;
        final fallback = CommunityUnavailableView(reason: reason);
        final builder = unavailableBuilder ?? CommunityAvailabilityScope.maybeOf(context);
        return builder == null ? fallback : builder(context, reason, fallback);
      },
    );
  }
}

class CommunityUnavailableView extends StatelessWidget {
  const CommunityUnavailableView({super.key, this.reason = CommunityUnavailableReason.socialDisabled});

  final CommunityUnavailableReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final social = reason == CommunityUnavailableReason.socialDisabled;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              social ? Icons.construction_outlined : Icons.visibility_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            if (social) ...[
              Text(l10n.socialUnavailableTitle, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(l10n.socialUnavailableBody, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ] else
              Text(l10n.featureUnavailable, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

typedef CommunityUpdateRequiredHandler = void Function(BuildContext context, ClientConfig config);

class CommunityUpdateListener extends StatefulWidget {
  const CommunityUpdateListener({super.key, required this.onUpdateRequired, required this.child});

  final CommunityUpdateRequiredHandler onUpdateRequired;
  final Widget child;

  @override
  State<CommunityUpdateListener> createState() => _CommunityUpdateListenerState();
}

class _CommunityUpdateListenerState extends State<CommunityUpdateListener> {
  CommunityFeatureDependencies? _features;
  bool _notified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final features = CommunityFeatureScope.maybeOf(context);
    if (identical(features, _features)) return;
    _features?.configService.listenable.removeListener(_check);
    _features = features;
    features?.configService.listenable.addListener(_check);
    _check();
  }

  void _check() {
    final config = _features?.configService.current;
    if (config == null) return;
    if (!config.updateRequired) {
      _notified = false;
      return;
    }
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUpdateRequired(context, config);
    });
  }

  @override
  void dispose() {
    _features?.configService.listenable.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
