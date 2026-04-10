// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../services/hazuki_source_service.dart';
import 'source_runtime_widgets.dart';

class SourceUpdateDialogSupport {
  const SourceUpdateDialogSupport();

  Future<SourceUpdateDialogAction?> showIfNeeded({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required bool Function() isMounted,
    required String skipPrefsKey,
    bool respectSkipPreference = true,
  }) async {
    final check = await HazukiSourceService.instance
        .checkJmSourceVersionFromCloud();
    if (!isMounted() || check == null || !check.hasUpdate) {
      return null;
    }

    return showForCheck(
      navigatorKey: navigatorKey,
      dialogContext: dialogContext,
      isMounted: isMounted,
      skipPrefsKey: skipPrefsKey,
      check: check,
      respectSkipPreference: respectSkipPreference,
    );
  }

  Future<SourceUpdateDialogAction?> showForCheck({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required bool Function() isMounted,
    required String skipPrefsKey,
    required SourceVersionCheckResult check,
    bool respectSkipPreference = true,
  }) async {
    if (!isMounted() || !check.hasUpdate) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final skipPayload = prefs.getString(skipPrefsKey);
    if (respectSkipPreference &&
        _shouldSkipSourceUpdateDialog(skipPayload: skipPayload, check: check)) {
      return null;
    }

    final dismissible = ValueNotifier<bool>(false);
    var downloadCompleted = false;

    final result = await _showAnimatedDialog<SourceUpdateDialogAction>(
      navigatorKey: navigatorKey,
      dialogContext: dialogContext,
      barrierDismissible: false,
      dismissibleListenable: dismissible,
      child: SourceUpdateDialogCard(
        check: check,
        dismissible: dismissible,
        onDownloadCompleted: () {
          downloadCompleted = true;
        },
      ),
    );

    dismissible.dispose();

    final effectiveResult = downloadCompleted && result == null
        ? SourceUpdateDialogAction.downloaded
        : result;

    if (effectiveResult == SourceUpdateDialogAction.skipToday) {
      await prefs.setString(skipPrefsKey, _buildSourceUpdateSkipPayload(check));
    }

    return effectiveResult;
  }

  String _formatTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _shouldSkipSourceUpdateDialog({
    required String? skipPayload,
    required SourceVersionCheckResult check,
  }) {
    if (skipPayload == null || skipPayload.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(skipPayload);
      if (decoded is! Map) {
        return false;
      }
      final map = Map<String, dynamic>.from(decoded);
      final date = map['date']?.toString();
      final localVersion = map['localVersion']?.toString();
      final remoteVersion = map['remoteVersion']?.toString();
      return date == _formatTodayKey() &&
          localVersion == check.localVersion &&
          remoteVersion == check.remoteVersion;
    } catch (_) {
      return false;
    }
  }

  String _buildSourceUpdateSkipPayload(SourceVersionCheckResult check) {
    return jsonEncode({
      'date': _formatTodayKey(),
      'localVersion': check.localVersion,
      'remoteVersion': check.remoteVersion,
    });
  }

  Future<T?> _showAnimatedDialog<T>({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required Widget child,
    bool barrierDismissible = true,
    ValueNotifier<bool>? dismissibleListenable,
  }) {
    final effectiveDialogContext =
        dialogContext ??
        navigatorKey?.currentState?.overlay?.context ??
        navigatorKey?.currentContext;
    if (effectiveDialogContext == null) {
      return Future<T?>.value(null);
    }
    return showGeneralDialog<T>(
      context: effectiveDialogContext,
      barrierDismissible: false,
      barrierLabel: l10n(effectiveDialogContext).dialogBarrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        Widget buildPage(bool canDismiss) {
          return PopScope(
            canPop: canDismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canDismiss
                        ? () => Navigator.of(buildContext).maybePop()
                        : null,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final colorScheme = Theme.of(context).colorScheme;
                        final transitionProgress = Curves.easeOutCubic
                            .transform(animation.value);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.black.withValues(
                                alpha: 0.20 * transitionProgress,
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorScheme.surface.withValues(
                                      alpha: 0.06 * transitionProgress,
                                    ),
                                    colorScheme.surface.withValues(
                                      alpha: 0.12 * transitionProgress,
                                    ),
                                    colorScheme.surfaceContainerHighest
                                        .withValues(
                                          alpha: 0.18 * transitionProgress,
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
                      child: Material(
                        type: MaterialType.transparency,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (dismissibleListenable == null) {
          return buildPage(barrierDismissible);
        }

        return ValueListenableBuilder<bool>(
          valueListenable: dismissibleListenable,
          builder: (context, canDismiss, _) {
            return buildPage(canDismiss);
          },
        );
      },
      transitionBuilder:
          (buildContext, animation, secondaryAnimation, dialogChild) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                  child: dialogChild,
                ),
              ),
            );
          },
    );
  }
}
