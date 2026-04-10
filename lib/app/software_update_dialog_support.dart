// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/software_update_service.dart';

enum SoftwareUpdateDialogAction { skipToday, cancel, openedRelease }

class SoftwareUpdateDialogSupport {
  const SoftwareUpdateDialogSupport();

  Future<SoftwareUpdateDialogAction?> showIfNeeded({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required bool Function() isMounted,
    required String skipPrefsKey,
    bool respectSkipPreference = true,
  }) async {
    final check = await SoftwareUpdateService.instance.checkForUpdates();
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

  Future<SoftwareUpdateDialogAction?> showForCheck({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required bool Function() isMounted,
    required String skipPrefsKey,
    required SoftwareUpdateCheckResult check,
    bool respectSkipPreference = true,
  }) async {
    if (!isMounted() || !check.hasUpdate) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final skipPayload = prefs.getString(skipPrefsKey);
    if (respectSkipPreference &&
        _shouldSkipSoftwareUpdateDialog(
          skipPayload: skipPayload,
          check: check,
        )) {
      return null;
    }

    final result = await _showDialog(
      navigatorKey: navigatorKey,
      dialogContext: dialogContext,
      check: check,
    );

    if (result == SoftwareUpdateDialogAction.skipToday) {
      await prefs.setString(
        skipPrefsKey,
        _buildSoftwareUpdateSkipPayload(check),
      );
    }

    return result;
  }

  bool _shouldSkipSoftwareUpdateDialog({
    required String? skipPayload,
    required SoftwareUpdateCheckResult check,
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
      final currentVersion = map['currentVersion']?.toString();
      final latestVersion = map['latestVersion']?.toString();
      return date == _formatTodayKey() &&
          currentVersion == check.currentVersion &&
          latestVersion == check.latestVersion;
    } catch (_) {
      return false;
    }
  }

  String _buildSoftwareUpdateSkipPayload(SoftwareUpdateCheckResult check) {
    return jsonEncode({
      'date': _formatTodayKey(),
      'currentVersion': check.currentVersion,
      'latestVersion': check.latestVersion,
    });
  }

  String _formatTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<SoftwareUpdateDialogAction?> _showDialog({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required SoftwareUpdateCheckResult check,
  }) async {
    final effectiveDialogContext =
        dialogContext ??
        navigatorKey?.currentState?.overlay?.context ??
        navigatorKey?.currentContext;
    if (effectiveDialogContext == null) {
      return null;
    }

    return showDialog<SoftwareUpdateDialogAction>(
      context: effectiveDialogContext,
      builder: (context) {
        final strings = l10n(context);
        final changelog = check.changelog;
        return AlertDialog(
          title: Text(strings.softwareUpdateAvailableTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.softwareUpdateAvailableMessage),
                  const SizedBox(height: 12),
                  Text(
                    strings.softwareUpdateCurrentVersion(check.currentVersion),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.softwareUpdateLatestVersion(check.latestVersion),
                  ),
                  if (changelog != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      strings.softwareUpdateChangelogTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(changelog),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(SoftwareUpdateDialogAction.skipToday);
              },
              child: Text(strings.comicDetailRemindLaterToday),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(SoftwareUpdateDialogAction.cancel);
              },
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                final uri = Uri.parse(check.releaseUrl);
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!context.mounted) {
                  return;
                }
                if (!opened) {
                  Navigator.of(context).pop(SoftwareUpdateDialogAction.cancel);
                  return;
                }
                Navigator.of(
                  context,
                ).pop(SoftwareUpdateDialogAction.openedRelease);
              },
              child: Text(strings.softwareUpdateOpenRelease),
            ),
          ],
        );
      },
    );
  }
}
