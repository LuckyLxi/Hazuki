import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hazuki/shared/software_update/software_update_dialog_presenter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/software_update/software_update_service.dart';
import 'about_page_content.dart';
import '../../../widgets/widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    required this.softwareUpdateService,
    required this.softwareUpdateDialog,
  });

  final SoftwareUpdateService softwareUpdateService;
  final SoftwareUpdateDialogPresenter softwareUpdateDialog;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _softwareUpdateSkipDateKey = 'software_update_skip_date';

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
      final check = await widget.softwareUpdateService.checkForUpdates();
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

      await widget.softwareUpdateDialog.showForCheck(
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

  void _showLicenses() {
    final theme = Theme.of(context);
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: theme.copyWith(
              appBarTheme: theme.appBarTheme.copyWith(
                backgroundColor: theme.colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
            ),
            child: LicensePage(
              applicationName: 'Hazuki',
              applicationVersion: _currentVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String path, String failureMessage) async {
    final url = Uri.parse('https://github.com/LuckyLxi/Hazuki$path');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      unawaited(showHazukiPrompt(context, failureMessage, isError: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.aboutTitle),
      ),
      body: AboutPageContent(
        currentVersion: _currentVersion,
        checkingUpdate: _checkingUpdate,
        onCheckUpdate: () => unawaited(_checkForSoftwareUpdates()),
        onOpenProject: () =>
            unawaited(_openLink('', strings.aboutOpenLinkFailed)),
        onOpenFeedback: () =>
            unawaited(_openLink('/issues', strings.aboutOpenFeedbackFailed)),
        onOpenDisclaimer: () => unawaited(_showDisclaimerDialog(context)),
        onOpenLicenses: _showLicenses,
      ),
    );
  }
}
