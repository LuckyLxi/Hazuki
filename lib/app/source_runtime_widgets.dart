import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/hazuki_source_service.dart';

part 'source_runtime_bootstrap_overlay.dart';
part 'source_runtime_dialog_actions.dart';
part 'source_runtime_dialog_helpers.dart';

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

  void _updateDialogState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    setState(updater);
  }
}

enum _SourceUpdateDialogPhase { available, downloading, restartRequired }
