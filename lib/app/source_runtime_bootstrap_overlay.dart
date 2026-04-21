import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class InitialSourceBootstrapOverlay extends StatelessWidget {
  const InitialSourceBootstrapOverlay({
    super.key,
    required this.showOverlay,
    required this.showIntro,
    required this.indeterminate,
    required this.progress,
    required this.errorText,
  });

  final bool showOverlay;
  final bool showIntro;
  final bool indeterminate;
  final double progress;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    if (!showOverlay && !showIntro) {
      return const SizedBox.shrink(
        key: ValueKey('initial-source-bootstrap-overlay-empty'),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      key: ValueKey(
        showOverlay
            ? 'initial-source-bootstrap-overlay'
            : 'initial-source-bootstrap-intro',
      ),
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 332,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n(context).sourceBootstrapDownloading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              if (showOverlay) ...[
                LinearProgressIndicator(
                  value: indeterminate ? null : progress,
                  borderRadius: BorderRadius.circular(999),
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                errorText ??
                    (showIntro
                        ? l10n(context).sourceBootstrapPreparing
                        : indeterminate
                        ? l10n(context).sourceBootstrapPreparing
                        : l10n(context).sourceBootstrapProgress(
                            (progress * 100).toStringAsFixed(0),
                          )),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
