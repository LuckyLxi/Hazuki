import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/software_update_dialog_support.dart';
import '../l10n/app_localizations.dart';
import '../services/software_update_service.dart';
import '../widgets/widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _softwareUpdateSkipDateKey = 'software_update_skip_date';

  final SoftwareUpdateDialogSupport _softwareUpdateDialogSupport =
      const SoftwareUpdateDialogSupport();

  bool _checkingUpdate = false;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentVersion = packageInfo.version.trim();
    });
  }

  Future<void> _showDisclaimerDialog(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.dialogBarrierLabel,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          title: Text(strings.aboutDisclaimerTitle),
          content: SingleChildScrollView(
            child: Text(
              strings.aboutDisclaimerContent,
              style: textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.commonClose),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(scaleAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _checkForSoftwareUpdates() async {
    if (_checkingUpdate) {
      return;
    }

    setState(() => _checkingUpdate = true);
    try {
      final check = await SoftwareUpdateService.instance.checkForUpdates();
      if (!mounted) {
        return;
      }
      if (check == null) {
        await showHazukiPrompt(
          context,
          AppLocalizations.of(context)!.softwareUpdateCheckFailed,
          isError: true,
        );
        return;
      }
      if (!check.hasUpdate) {
        await showHazukiPrompt(
          context,
          AppLocalizations.of(context)!.softwareUpdateAlreadyLatest,
        );
        return;
      }

      await _softwareUpdateDialogSupport.showForCheck(
        dialogContext: context,
        isMounted: () => mounted,
        skipPrefsKey: _softwareUpdateSkipDateKey,
        check: check,
        respectSkipPreference: false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        AppLocalizations.of(context)!.softwareUpdateCheckFailed,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.aboutTitle),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 48),
          const Center(child: FlutterLogo(size: 80)),
          const SizedBox(height: 24),
          Text(
            'Hazuki',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.aboutVersion(_currentVersion ?? '1.0.0'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              strings.aboutDescription,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 48),
          const Divider(indent: 32, endIndent: 32),
          ListTile(
            leading: const Icon(Icons.system_update_alt_rounded),
            title: Text(strings.aboutCheckUpdateTitle),
            subtitle: Text(strings.aboutCheckSoftwareUpdateSubtitle),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _checkingUpdate ? null : _checkForSoftwareUpdates,
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(strings.aboutProjectTitle),
            subtitle: Text(strings.aboutProjectSubtitle),
            onTap: () async {
              final url = Uri.parse('https://github.com/LuckyLxi/Hazuki');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  unawaited(
                    showHazukiPrompt(
                      context,
                      strings.aboutOpenLinkFailed,
                      isError: true,
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: Text(strings.aboutFeedbackTitle),
            subtitle: Text(strings.aboutFeedbackSubtitle),
            onTap: () async {
              final url = Uri.parse(
                'https://github.com/LuckyLxi/Hazuki/issues',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  unawaited(
                    showHazukiPrompt(
                      context,
                      strings.aboutOpenFeedbackFailed,
                      isError: true,
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: Text(strings.aboutDisclaimerTitle),
            subtitle: Text(strings.aboutDisclaimerSubtitle),
            onTap: () => unawaited(_showDisclaimerDialog(context)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(strings.aboutThirdPartyLicensesTitle),
            subtitle: Text(strings.aboutThirdPartyLicensesSubtitle),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Hazuki',
                applicationVersion: _currentVersion ?? '1.0.0',
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: FlutterLogo(size: 48),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 Hazuki Project',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
