// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../services/software_update_download_service.dart';
import '../services/software_update_service.dart';
import '../widgets/widgets.dart';

enum SoftwareUpdateDialogAction { skipToday, cancel }

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

    return showGeneralDialog<SoftwareUpdateDialogAction>(
      context: effectiveDialogContext,
      barrierDismissible: true,
      barrierLabel: l10n(effectiveDialogContext).dialogBarrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _SoftwareUpdateDialogCard(check: check);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _SoftwareUpdateDialogCard extends StatefulWidget {
  const _SoftwareUpdateDialogCard({required this.check});

  final SoftwareUpdateCheckResult check;

  @override
  State<_SoftwareUpdateDialogCard> createState() =>
      _SoftwareUpdateDialogCardState();
}

class _SoftwareUpdateDialogCardState extends State<_SoftwareUpdateDialogCard> {
  final SoftwareUpdateDownloadService _downloadService =
      SoftwareUpdateDownloadService.instance;

  bool _downloadTriggerBusy = false;

  Future<bool> _openExternalUrl(String url) {
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _openReleasePage() async {
    final opened = await _openExternalUrl(widget.check.releaseUrl);
    if (!opened && mounted) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).aboutOpenLinkFailed,
          isError: true,
        ),
      );
    }
  }

  Future<void> _startDownload() async {
    if (_downloadTriggerBusy) {
      return;
    }
    _downloadService.clearFailure();
    setState(() => _downloadTriggerBusy = true);
    final success = await _downloadService.startDownload(widget.check);
    if (!mounted) {
      return;
    }
    setState(() => _downloadTriggerBusy = false);
    if (success && !_downloadService.isZipMode) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (Platform.isAndroid || Platform.isWindows) {
      await _startDownload();
      return;
    }
  }

  String? _buildFailureMessage(AppLocalizations strings) {
    switch (_downloadService.failureKind) {
      case SoftwareUpdateDownloadFailureKind.none:
        return null;
      case SoftwareUpdateDownloadFailureKind.apkUnavailable:
        return strings.softwareUpdateDownloadUnavailable;
      case SoftwareUpdateDownloadFailureKind.fileInvalid:
        return strings.softwareUpdateDownloadedFileInvalid;
      case SoftwareUpdateDownloadFailureKind.installerLaunchFailed:
        return strings.softwareUpdateInstallerLaunchFailed;
      case SoftwareUpdateDownloadFailureKind.downloadFailed:
        final detail = _downloadService.failureDetail ?? 'Unknown error';
        return strings.softwareUpdateDownloadFailed(detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: _downloadService,
      builder: (context, _) {
        final strings = l10n(context);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final isDownloading = _downloadService.isDownloading;
        final isSuccess = _downloadService.isSuccess;

        final canDownload =
            (Platform.isAndroid
                ? widget.check.apkUrl?.trim().isNotEmpty == true
                : Platform.isWindows
                ? widget.check.windowsUrl?.trim().isNotEmpty == true
                : false) &&
            !_downloadTriggerBusy;
        final failureMessage = _buildFailureMessage(strings);

        return PopScope(
          canPop: !isDownloading,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Center(
              child: Dialog(
                clipBehavior: Clip.antiAlias,
                insetPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  width: math.min(
                    isDownloading || isSuccess ? 332.0 : 388.0,
                    mediaQuery.size.width - 32,
                  ),
                  padding: isDownloading || isSuccess
                      ? const EdgeInsets.fromLTRB(18, 18, 18, 12)
                      : const EdgeInsets.fromLTRB(20, 20, 20, 18),

                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: 0,
                            child: child,
                          ),
                        );
                      },
                      child: isSuccess
                          ? _buildSuccessContent(
                              strings: strings,
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                            )
                          : isDownloading
                          ? _buildDownloadingContent(
                              strings: strings,
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                            )
                          : _buildAvailableContent(
                              strings: strings,
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                              maxHeight: mediaQuery.size.height * 0.70,
                              canDownload: canDownload,
                              failureMessage: failureMessage,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableContent({
    required AppLocalizations strings,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required double maxHeight,
    required bool canDownload,
    required String? failureMessage,
  }) {
    final changelog = widget.check.changelog?.trim();
    final hasChangelog = changelog != null && changelog.isNotEmpty;

    return Column(
      key: const ValueKey<String>('software-update-available'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.softwareUpdateAvailableTitle,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'v${widget.check.latestVersion}',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasChangelog) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: maxHeight * 0.6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.36),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.softwareUpdateChangelogTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      changelog,
                      style: textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (failureMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              failureMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(SoftwareUpdateDialogAction.skipToday);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: Text(
                  strings.comicDetailRemindLaterToday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextButton(
                onPressed: _openReleasePage,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  strings.softwareUpdateViewDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: canDownload
                    ? () => unawaited(_handlePrimaryAction())
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  strings.softwareUpdateDownloadAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessContent({
    required AppLocalizations strings,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.check_circle_rounded, size: 48, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          strings.softwareUpdateDownloadSuccessZipMessage,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final dir = _downloadService.downloadedDir;
              if (dir != null) {
                Process.run('explorer.exe', [dir]);
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(strings.softwareUpdateOpenFolder),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingContent({
    required AppLocalizations strings,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final percentText = _downloadService.indeterminate
        ? null
        : '${(_downloadService.progress * 100).round()}%';
    final speedText = _formatDownloadSpeed(
      _downloadService.speedBytesPerSecond,
    );
    final metaText = percentText == null
        ? speedText
        : '$percentText  $speedText';

    return Column(
      key: const ValueKey<String>('software-update-downloading'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.softwareUpdateDownloadingTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: _downloadService.indeterminate
                ? null
                : _downloadService.progress,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            metaText,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.bottomRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.softwareUpdateBackgroundDownload),
          ),
        ),
      ],
    );
  }

  String _formatDownloadSpeed(double bytesPerSecond) {
    final safeBytes = bytesPerSecond.isFinite ? math.max(bytesPerSecond, 0) : 0;
    if (safeBytes >= 1024 * 1024) {
      return '${(safeBytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (safeBytes >= 1024) {
      return '${(safeBytes / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${safeBytes.toStringAsFixed(0)} B/s';
  }
}
