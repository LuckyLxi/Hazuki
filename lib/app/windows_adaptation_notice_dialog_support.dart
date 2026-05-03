// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import 'app_preferences.dart';

class WindowsAdaptationNoticeDialogSupport {
  const WindowsAdaptationNoticeDialogSupport();

  Future<void> showIfNeeded({
    required GlobalKey<NavigatorState> navigatorKey,
    required bool Function() isMounted,
  }) async {
    if (!Platform.isWindows || !isMounted()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(hazukiWindowsAdaptationNoticeAcceptedPreferenceKey) ??
        false) {
      return;
    }

    final dialogContext =
        navigatorKey.currentState?.overlay?.context ??
        navigatorKey.currentContext;
    if (!isMounted() || dialogContext == null) {
      return;
    }

    final accepted = await showGeneralDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      barrierLabel: l10n(dialogContext).dialogBarrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: SafeArea(
            minimum: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AlertDialog(
                  title: Text(l10n(buildContext).windowsAdaptationNoticeTitle),
                  content: Text(
                    l10n(buildContext).windowsAdaptationNoticeMessage,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(buildContext).pop(true),
                      child: Text(
                        l10n(buildContext).windowsAdaptationNoticeAccept,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(curved),
                  child: dialogChild,
                ),
              ),
            );
          },
    );

    if (accepted == true) {
      await prefs.setBool(
        hazukiWindowsAdaptationNoticeAcceptedPreferenceKey,
        true,
      );
    }
  }
}
