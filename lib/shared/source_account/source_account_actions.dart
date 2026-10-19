import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'source_account_dialogs.dart';
import 'source_switch_list.dart';

export 'source_account_dialogs.dart';

Future<void> showHomeSourceSwitchDialog(
  BuildContext context, {
  required SourceSwitchGateway sourceService,
  Future<void> Function()? onSourceSwitched,
  FavoriteFoldersMorphOrigin? morphOrigin,
  VoidCallback? onDialogClosed,
}) async {
  final registry = sourceService;
  final strings = l10n(context);
  await registry.loadActiveSourcePreference();
  if (!context.mounted) {
    return;
  }

  var switching = false;
  SourceCatalogEntry? switchingSource;
  _HomeSourceSwitchBusyPhase busyPhase = _HomeSourceSwitchBusyPhase.switching;
  String? errorText;

  final dialog = StatefulBuilder(
    builder: (dialogContext, setDialogState) {
      Future<void> switchTo(SourceCatalogEntry source) async {
        if (switching || source.normalizedKey == registry.activeSourceKey) {
          return;
        }
        final previousSourceKey = registry.activeSourceKey;
        setDialogState(() {
          switching = true;
          switchingSource = source;
          busyPhase = _HomeSourceSwitchBusyPhase.switching;
          errorText = null;
        });

        try {
          final wasDownloaded = await sourceService.hasLocalSourceFile(
            source.normalizedKey,
          );
          if (!dialogContext.mounted) {
            return;
          }
          setDialogState(() {
            busyPhase = wasDownloaded
                ? _HomeSourceSwitchBusyPhase.switching
                : _HomeSourceSwitchBusyPhase.downloading;
          });

          if (!wasDownloaded) {
            await sourceService.downloadSourceFile(source.normalizedKey);
            if (!dialogContext.mounted) {
              return;
            }
            setDialogState(() {
              busyPhase = _HomeSourceSwitchBusyPhase.switching;
            });
          } else {
            await registry.activateSource(source.normalizedKey);
          }
          await sourceService.ensureInitialized(
            sourceKey: source.normalizedKey,
          );
          await onSourceSwitched?.call();
          if (morphOrigin?.resolveReturnRect != null) {
            // Flush the profile rebuild and its post-frame drawer forwarding.
            // The first closing paint then reads the newly laid out button.
            await WidgetsBinding.instance.endOfFrame;
          }
          if (!dialogContext.mounted) {
            return;
          }
          Navigator.of(dialogContext).pop();
          if (!context.mounted) {
            return;
          }
          await showHazukiPrompt(
            context,
            strings.labSourceAccountSwitchSuccess,
          );
        } catch (error) {
          try {
            await sourceService.ensureInitialized(sourceKey: previousSourceKey);
          } catch (_) {}
          if (!dialogContext.mounted) {
            return;
          }
          setDialogState(() {
            switching = false;
            switchingSource = null;
            busyPhase = _HomeSourceSwitchBusyPhase.switching;
            errorText = strings.labSourceAccountSwitchFailed('$error');
          });
        }
      }

      return PopScope(
        canPop: !switching,
        child: _HomeSourceSwitchDialog(
          borderRadius: switching ? 18 : 28,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: switching
                  ? _HomeSourceSwitchBusyPane(
                      key: const ValueKey('source-switch-busy'),
                      sourceName: switchingSource?.name ?? '',
                      phase: busyPhase,
                    )
                  : _HomeSourceSwitchPickerPane(
                      key: const ValueKey('source-switch-picker'),
                      sources: registry.allowedSources,
                      activeSourceKey: registry.activeSourceKey ?? '',
                      errorText: errorText,
                      onCancel: () => Navigator.of(dialogContext).pop(),
                      onSelected: switchTo,
                    ),
            ),
          ),
        ),
      );
    },
  );
  if (morphOrigin == null) {
    await showHomeAnimatedDialog<void>(context, child: dialog);
    return;
  }

  final route = RawDialogRoute<void>(
    barrierDismissible: true,
    barrierLabel: strings.dialogBarrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 560),
    pageBuilder: (context, animation, secondaryAnimation) =>
        FavoriteFoldersMorphScope(
          origin: morphOrigin,
          animation: animation,
          child: SafeArea(
            child: Center(
              child: Material(type: MaterialType.transparency, child: dialog),
            ),
          ),
        ),
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
  var buttonRestored = false;
  void restoreButton() {
    if (buttonRestored) return;
    buttonRestored = true;
    onDialogClosed?.call();
  }

  final popped = Navigator.of(context, rootNavigator: true).push(route);
  final animation = route.animation!;
  void handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) restoreButton();
  }

  animation.addStatusListener(handleStatus);
  try {
    await popped;
  } finally {
    // Restore on the final animation frame; waiting for overlay disposal would
    // leave the button invisible for one frame after the morph disappears.
    await route.completed;
    animation.removeStatusListener(handleStatus);
    restoreButton();
  }
}

class _HomeSourceSwitchDialog extends StatelessWidget {
  const _HomeSourceSwitchDialog({
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HazukiLiquidGlass.changes,
      builder: (context, _) {
        final plain =
            FavoriteFoldersMorphScope.maybeOf(context) == null &&
            !HazukiLiquidGlass.isAvailable;
        return Dialog(
          backgroundColor: plain
              ? homeDialogBackgroundColor(context)
              : Colors.transparent,
          elevation: plain ? null : 0,
          clipBehavior: plain ? Clip.antiAlias : Clip.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: _buildSurface(context),
        );
      },
    );
  }

  Widget _buildSurface(BuildContext context) {
    final morph = FavoriteFoldersMorphScope.maybeOf(context);
    final glass = HazukiLiquidGlass.isAvailable;
    final surface = glass
        ? GlassContainer(
            key: const ValueKey('home-source-switch-liquid-glass-surface'),
            useOwnLayer: true,
            quality: HazukiLiquidGlass.navigationQuality,
            shape: LiquidRoundedRectangle(borderRadius: borderRadius),
            settings: HazukiLiquidGlass.popoverSettings(context),
            child: morph == null ? child : null,
          )
        : null;
    if (morph == null) return surface ?? child;
    return AnimatedBuilder(
      animation: morph.animation,
      child: child,
      builder: (context, child) => IgnorePointer(
        ignoring: morph.animation.value < 1,
        child: FavoriteFoldersButtonMorph(
          origin: morph.origin,
          animation: morph.animation,
          surfaceColor: homeDialogBackgroundColor(context),
          outlineColor: Colors.transparent,
          borderRadius: borderRadius,
          shadowBlurRadius: 22,
          surface: surface,
          child: child!,
        ),
      ),
    );
  }
}

Future<void> saveHomeAvatarToDownloads(
  BuildContext context, {
  required MethodChannel mediaChannel,
  required String imageUrl,
  required SourceImageGateway sourceService,
}) async {
  final normalized = imageUrl.trim();
  if (normalized.isEmpty) {
    return;
  }

  final strings = l10n(context);
  try {
    final bytes = await sourceService.downloadImageBytes(normalized);
    final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(
      '${directory.path}/hazuki_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    await mediaChannel.invokeMethod<bool>('scanFile', {'path': file.path});
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(context, strings.homeAvatarSaved);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      strings.homeAvatarSaveFailed('$error'),
      isError: true,
    );
  }
}

enum _HomeSourceSwitchBusyPhase { downloading, switching }

class _HomeSourceSwitchPickerPane extends StatelessWidget {
  const _HomeSourceSwitchPickerPane({
    super.key,
    required this.sources,
    required this.activeSourceKey,
    required this.errorText,
    required this.onCancel,
    required this.onSelected,
  });

  final List<SourceCatalogEntry> sources;
  final String activeSourceKey;
  final String? errorText;
  final VoidCallback onCancel;
  final ValueChanged<SourceCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.homeSourceSwitchTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ConstrainedBox(
                // Three two-line tiles (72 each), including their spacing.
                constraints: const BoxConstraints(maxHeight: 3 * (72 + 6)),
                child: SourceSwitchList(
                  currentIndex: sources.indexWhere(
                    (source) => source.normalizedKey == activeSourceKey,
                  ),
                  children: [
                    for (final source in sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: source.normalizedKey == activeSourceKey
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.58,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: source.normalizedKey == activeSourceKey
                                ? null
                                : () => onSelected(source),
                            leading: Icon(
                              source.normalizedKey == activeSourceKey
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            title: Text(source.name),
                            subtitle: Text(
                              source.normalizedKey == activeSourceKey
                                  ? strings.homeSourceSwitchCurrent
                                  : source.key,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(errorText!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(strings.commonCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSourceSwitchBusyPane extends StatelessWidget {
  const _HomeSourceSwitchBusyPane({
    super.key,
    required this.sourceName,
    required this.phase,
  });

  final String sourceName;
  final _HomeSourceSwitchBusyPhase phase;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final title = switch (phase) {
      _HomeSourceSwitchBusyPhase.downloading =>
        sourceName.trim().isEmpty
            ? strings.sourceBootstrapDownloading
            : strings.homeSourceSwitchDownloadingSource(sourceName),
      _HomeSourceSwitchBusyPhase.switching =>
        sourceName.trim().isEmpty
            ? strings.homeSourceSwitchLoadingTitle
            : strings.homeSourceSwitchLoadingTo(sourceName),
    };

    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.homeSourceSwitchLoadingMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
