import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../services/hazuki_source_service.dart';

bool shouldShowSourceRuntimeStatusCard(
  SourceRuntimeState state, {
  String? fallbackError,
}) {
  if (state.hasFailure || state.isWaitingForRestart) {
    return true;
  }
  final normalizedError = (fallbackError ?? '').trim().toLowerCase();
  if (normalizedError.isEmpty) {
    return false;
  }
  return normalizedError.contains('source_not_initialized') ||
      normalizedError.contains('source_init_failed') ||
      normalizedError.contains('source_download_failed_without_cache') ||
      normalizedError.contains('source_metadata_incomplete') ||
      normalizedError.contains('module handler timeout') ||
      normalizedError.contains('module not found');
}

class SourceRuntimeStatusCard extends StatelessWidget {
  const SourceRuntimeStatusCard({
    super.key,
    required this.state,
    this.fallbackError,
    this.onRetry,
    this.minHeight = 320,
  });

  final SourceRuntimeState state;
  final String? fallbackError;
  final VoidCallback? onRetry;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveSourceRuntimePresentation(
      context,
      state,
      fallbackError: fallbackError,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: minHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: resolved.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        resolved.icon,
                        color: resolved.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolved.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            resolved.message,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (resolved.stageLabel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: resolved.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      resolved.stageLabel!,
                      style: textTheme.labelMedium?.copyWith(
                        color: resolved.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (resolved.showProgress) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 8),
                  ),
                ],
                if (resolved.canRetry) ...[
                  const SizedBox(height: 18),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: Text(l10n(context).commonRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedSourceRuntimePresentation {
  const _ResolvedSourceRuntimePresentation({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.showProgress,
    required this.canRetry,
    this.stageLabel,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String? stageLabel;
  final bool showProgress;
  final bool canRetry;
}

_ResolvedSourceRuntimePresentation _resolveSourceRuntimePresentation(
  BuildContext context,
  SourceRuntimeState state, {
  String? fallbackError,
}) {
  final strings = l10n(context);
  final scheme = Theme.of(context).colorScheme;
  final stageLabel = _resolveStageLabel(strings, state.step);
  final rawError = (state.error ?? fallbackError ?? '').trim();

  if (state.isWaitingForRestart) {
    return _ResolvedSourceRuntimePresentation(
      icon: Icons.restart_alt_rounded,
      accent: scheme.tertiary,
      title: strings.sourceRuntimeWaitingForRestartTitle,
      message: strings.sourceRuntimeWaitingForRestartMessage,
      stageLabel: strings.sourceRuntimeStageWaitingForRestart,
      showProgress: false,
      canRetry: false,
    );
  }

  if (state.phase == SourceRuntimePhase.prewarming) {
    return _ResolvedSourceRuntimePresentation(
      icon: Icons.bolt_rounded,
      accent: scheme.primary,
      title: strings.sourceRuntimePrewarmingTitle,
      message: strings.sourceRuntimePrewarmingMessage,
      stageLabel: stageLabel,
      showProgress: true,
      canRetry: false,
    );
  }

  if (state.phase == SourceRuntimePhase.retrying) {
    return _ResolvedSourceRuntimePresentation(
      icon: Icons.refresh_rounded,
      accent: scheme.primary,
      title: strings.sourceRuntimeRetryingTitle,
      message: strings.sourceRuntimeRetryingMessage,
      stageLabel: stageLabel,
      showProgress: true,
      canRetry: false,
    );
  }

  if (state.hasFailure ||
      shouldShowSourceRuntimeStatusCard(state, fallbackError: rawError)) {
    return _ResolvedSourceRuntimePresentation(
      icon: Icons.error_outline_rounded,
      accent: scheme.error,
      title: strings.sourceRuntimeFailedTitle,
      message: _resolveFriendlySourceError(strings, rawError),
      stageLabel: stageLabel,
      showProgress: false,
      canRetry: state.canRetry,
    );
  }

  return _ResolvedSourceRuntimePresentation(
    icon: Icons.sync_rounded,
    accent: scheme.primary,
    title: strings.sourceRuntimeLoadingTitle,
    message: strings.sourceRuntimeLoadingMessage,
    stageLabel: stageLabel,
    showProgress: true,
    canRetry: false,
  );
}

String? _resolveStageLabel(AppLocalizations strings, SourceRuntimeStep step) {
  return switch (step) {
    SourceRuntimeStep.loadingCache => strings.sourceRuntimeStageLoadingCache,
    SourceRuntimeStep.downloadingSource =>
      strings.sourceRuntimeStageDownloadingSource,
    SourceRuntimeStep.creatingEngine =>
      strings.sourceRuntimeStageCreatingEngine,
    SourceRuntimeStep.runningSourceInit =>
      strings.sourceRuntimeStageRunningSourceInit,
    SourceRuntimeStep.none => null,
  };
}

String _resolveFriendlySourceError(AppLocalizations strings, String rawError) {
  final normalized = rawError.toLowerCase();
  if (normalized.contains('source_download_failed_without_cache')) {
    return strings.sourceRuntimeErrorDownloadUnavailable;
  }
  if (normalized.contains('source_metadata_incomplete')) {
    return strings.sourceRuntimeErrorMetadataIncomplete;
  }
  if (normalized.contains('module handler timeout') ||
      normalized.contains('module not found')) {
    return strings.sourceRuntimeErrorModuleLoad;
  }
  if (normalized.contains('timeout')) {
    return strings.sourceRuntimeErrorTimeout;
  }
  if (normalized.contains('source_init_failed') ||
      normalized.contains('source_not_initialized')) {
    return strings.sourceRuntimeErrorInitialization;
  }
  return strings.sourceRuntimeErrorGeneric;
}
