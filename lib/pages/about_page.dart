import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../widgets/widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
            strings.aboutVersion,
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
                applicationVersion: '1.0.0',
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
