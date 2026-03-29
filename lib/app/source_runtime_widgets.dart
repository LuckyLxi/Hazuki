import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/hazuki_source_service.dart';

enum SourceUpdateDialogAction { skipToday, cancel, downloaded }

class SourceUpdateDialogCard extends StatefulWidget {
  const SourceUpdateDialogCard({
    super.key,
    required this.check,
    required this.dismissible,
    required this.onDownloadCompleted,
  });

  final SourceVersionCheckResult check;
  final ValueNotifier<bool> dismissible;
  final VoidCallback onDownloadCompleted;

  @override
  State<SourceUpdateDialogCard> createState() => _SourceUpdateDialogCardState();
}

class _SourceUpdateDialogCardState extends State<SourceUpdateDialogCard> {
  _SourceUpdateDialogPhase _phase = _SourceUpdateDialogPhase.available;
  double _progress = 0;
  bool _indeterminate = true;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final restartTitle = strings.sourceUpdateRestartTitle;
    final restartMessage = strings.sourceUpdateRestartMessage;
    final localVersionLabel = strings.sourceUpdateLocalLabel;
    final remoteVersionLabel = strings.sourceUpdateCloudLabel;

    const dialogMaxWidth = 360.0;
    final availableMessage = strings.sourceUpdateAvailableMessage;
    final downloadingMessage = strings.sourceUpdateDownloadingMessage;
    final restartHint = strings.sourceUpdateRestartHint;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: dialogMaxWidth),
        padding: _resolveDialogPadding(),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return ClipRect(
                child: FadeTransition(
                  opacity: curved,
                  child: SizeTransition(
                    sizeFactor: curved,
                    axis: Axis.vertical,
                    axisAlignment: 0,
                    child: child,
                  ),
                ),
              );
            },
            child: switch (_phase) {
              _SourceUpdateDialogPhase.available => Column(
                key: const ValueKey<String>('source-update-phase-available'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.system_update_alt_rounded,
                    title: strings.sourceUpdateAvailableTitle,
                    subtitle: availableMessage,
                    accent: colorScheme.primary,
                    badgeText: strings.sourceUpdateRemoteVersion(
                      widget.check.remoteVersion,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildPanel(
                    colorScheme: colorScheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVersionRow(
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          icon: Icons.history_rounded,
                          accent: colorScheme.onSurfaceVariant,
                          label: localVersionLabel,
                          value: widget.check.localVersion,
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildVersionRow(
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          icon: Icons.cloud_download_outlined,
                          accent: colorScheme.primary,
                          label: remoteVersionLabel,
                          value: widget.check.remoteVersion,
                        ),
                      ],
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      message: _errorText!,
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _downloadUpdate,
                    child: Text(strings.sourceUpdateDownload),
                  ),
                  const SizedBox(height: 8),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 4,
                    overflowSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(SourceUpdateDialogAction.skipToday),
                        child: Text(strings.comicDetailRemindLaterToday),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(SourceUpdateDialogAction.cancel),
                        child: Text(strings.commonCancel),
                      ),
                    ],
                  ),
                ],
              ),
              _SourceUpdateDialogPhase.downloading => _buildDownloadingScene(
                colorScheme: colorScheme,
                textTheme: textTheme,
                title: strings.sourceUpdateDownloading,
                subtitle: downloadingMessage,
                badgeText: strings.sourceUpdateRemoteVersion(
                  widget.check.remoteVersion,
                ),
                restartHint: restartHint,
              ),
              _SourceUpdateDialogPhase.restartRequired => Column(
                key: const ValueKey<String>('source-update-phase-restart'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.restart_alt_rounded,
                    title: restartTitle,
                    subtitle: restartMessage,
                    accent: colorScheme.tertiary,
                    badgeText: strings.sourceUpdateRemoteVersion(
                      widget.check.remoteVersion,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildPanel(
                    colorScheme: colorScheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVersionRow(
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          icon: Icons.cloud_done_rounded,
                          accent: colorScheme.tertiary,
                          label: remoteVersionLabel,
                          value: widget.check.remoteVersion,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          restartHint,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(SourceUpdateDialogAction.downloaded),
                    child: Text(strings.commonConfirm),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }

  EdgeInsets _resolveDialogPadding() {
    switch (_phase) {
      case _SourceUpdateDialogPhase.available:
        return const EdgeInsets.fromLTRB(20, 20, 20, 18);
      case _SourceUpdateDialogPhase.downloading:
        return const EdgeInsets.fromLTRB(20, 18, 20, 18);
      case _SourceUpdateDialogPhase.restartRequired:
        return const EdgeInsets.fromLTRB(20, 20, 20, 20);
    }
  }

  Future<void> _downloadUpdate() async {
    widget.dismissible.value = false;
    setState(() {
      _phase = _SourceUpdateDialogPhase.downloading;
      _errorText = null;
      _progress = 0;
      _indeterminate = true;
    });

    final ok = await HazukiSourceService.instance.downloadJmSourceAndReload(
      onProgress: (received, total) {
        if (!mounted) {
          return;
        }
        setState(() {
          if (total > 0) {
            _indeterminate = false;
            _progress = (received / total).clamp(0.0, 1.0);
          } else {
            _indeterminate = true;
          }
        });
      },
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      widget.onDownloadCompleted();
      widget.dismissible.value = true;
      setState(() {
        _phase = _SourceUpdateDialogPhase.restartRequired;
        _indeterminate = false;
        _progress = 1;
      });
      return;
    }

    widget.dismissible.value = false;
    setState(() {
      _phase = _SourceUpdateDialogPhase.available;
      _errorText = l10n(context).sourceUpdateDownloadFailed;
    });
  }

  Widget _buildDownloadingScene({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String title,
    required String subtitle,
    required String badgeText,
    required String restartHint,
  }) {
    final strings = l10n(context);
    final progressLabel = _indeterminate
        ? strings.sourceUpdateDownloading
        : strings.sourceUpdateDownloadingProgress(
            (_progress * 100).toStringAsFixed(0),
          );
    final percentLabel = '${(_progress * 100).toStringAsFixed(0)}%';
    return Column(
      key: const ValueKey<String>('source-update-phase-downloading'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          colorScheme: colorScheme,
          textTheme: textTheme,
          icon: Icons.downloading_rounded,
          title: title,
          subtitle: subtitle,
          accent: colorScheme.primary,
          badgeText: badgeText,
        ),
        const SizedBox(height: 18),
        _buildPanel(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progressLabel,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!_indeterminate)
                    Text(
                      percentLabel,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: _indeterminate ? null : _progress,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _indeterminate ? subtitle : restartHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({
    required ColorScheme colorScheme,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: child,
    );
  }

  Widget _buildHeader({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    String? badgeText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeadingIcon(icon: icon, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
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
        if (badgeText != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText,
              style: textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVersionRow({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon({required IconData icon, required Color accent}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

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

enum _SourceUpdateDialogPhase { available, downloading, restartRequired }
