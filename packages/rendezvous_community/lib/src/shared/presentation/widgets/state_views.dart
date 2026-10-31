import 'package:flutter/material.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';

class OltEmptyView extends StatelessWidget {
  const OltEmptyView({super.key, required this.message, this.icon = Icons.forum_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class OltErrorView extends StatelessWidget {
  const OltErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.errorMessage(error), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class OltSkeleton extends StatefulWidget {
  const OltSkeleton({super.key, this.itemCount = 5, this.itemBuilder});

  final int itemCount;
  final WidgetBuilder? itemBuilder;

  @override
  State<OltSkeleton> createState() => _OltSkeletonState();
}

class _OltSkeletonState extends State<OltSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        itemBuilder: (context, _) => widget.itemBuilder?.call(context) ?? const _PostSkeleton(),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, {double height = 12}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 20, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140),
                const SizedBox(height: 10),
                bar(double.infinity),
                const SizedBox(height: 6),
                bar(double.infinity),
                const SizedBox(height: 6),
                bar(180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
