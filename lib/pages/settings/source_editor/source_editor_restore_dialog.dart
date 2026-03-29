import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/hazuki_source_service.dart';
import '../../../widgets/widgets.dart';

Future<bool> showSourceEditorRestoreDialog(BuildContext context) async {
  final strings = l10n(context);
  var phase = _ComicSourceRestoreDialogPhase.confirm;
  var progress = 0.0;
  var indeterminate = true;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: strings.dialogBarrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;

          Widget buildConfirmContent() {
            return Column(
              key: const ValueKey<String>('restore-confirm'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.restore_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.advancedRestoreSourceLabel,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.sourceEditorRestoreConfirmContent,
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
                const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(strings.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () async {
                        setDialogState(() {
                          phase = _ComicSourceRestoreDialogPhase.downloading;
                          progress = 0;
                          indeterminate = true;
                        });

                        final ok = await HazukiSourceService.instance
                            .downloadJmSourceAndReload(
                              onProgress: (received, total) {
                                if (!dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  if (total > 0) {
                                    indeterminate = false;
                                    progress = (received / total).clamp(
                                      0.0,
                                      1.0,
                                    );
                                  } else {
                                    indeterminate = true;
                                  }
                                });
                              },
                            );

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.of(dialogContext).pop(ok);
                        if (!ok && context.mounted) {
                          unawaited(
                            showHazukiPrompt(
                              context,
                              strings.sourceEditorRestoreFailed,
                              isError: true,
                            ),
                          );
                        }
                      },
                      child: Text(strings.commonConfirm),
                    ),
                  ],
                ),
              ],
            );
          }

          Widget buildDownloadingContent() {
            final progressText = indeterminate
                ? strings.sourceUpdateDownloading
                : strings.sourceEditorRestoreDownloadingProgress(
                    (progress * 100).toStringAsFixed(0),
                  );
            return Column(
              key: const ValueKey<String>('restore-downloading'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        value: indeterminate ? null : progress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.sourceEditorRestoringTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: indeterminate ? null : progress,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  progressText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          final canDismiss = phase == _ComicSourceRestoreDialogPhase.confirm;

          return PopScope(
            canPop: canDismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canDismiss
                        ? () => Navigator.of(dialogContext).pop(false)
                        : null,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final transitionProgress = Curves.easeOutCubic
                            .transform(animation.value);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.black.withValues(
                                alpha: 0.22 * transitionProgress,
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorScheme.surface.withValues(
                                      alpha: 0.07 * transitionProgress,
                                    ),
                                    colorScheme.surface.withValues(
                                      alpha: 0.14 * transitionProgress,
                                    ),
                                    colorScheme.surfaceContainerHighest
                                        .withValues(
                                          alpha: 0.20 * transitionProgress,
                                        ),
                                  ],
                                ),
                              ),
                              child: child,
                            ),
                          ],
                        );
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Dialog(
                        clipBehavior: Clip.antiAlias,
                        insetPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          width: phase == _ComicSourceRestoreDialogPhase.confirm
                              ? 360
                              : 320,
                          padding:
                              phase == _ComicSourceRestoreDialogPhase.confirm
                              ? const EdgeInsets.fromLTRB(20, 20, 20, 18)
                              : const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child:
                                phase == _ComicSourceRestoreDialogPhase.confirm
                                ? buildConfirmContent()
                                : buildDownloadingContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );

  return result == true;
}

enum _ComicSourceRestoreDialogPhase { confirm, downloading }
