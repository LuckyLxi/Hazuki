import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'settings_group.dart';

class AboutPageContent extends StatelessWidget {
  const AboutPageContent({
    super.key,
    required this.currentVersion,
    required this.checkingUpdate,
    required this.onCheckUpdate,
    required this.onOpenProject,
    required this.onOpenFeedback,
    required this.onOpenDisclaimer,
    required this.onOpenLicenses,
  });

  final String? currentVersion;
  final bool checkingUpdate;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenProject;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenDisclaimer;
  final VoidCallback onOpenLicenses;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: Column(
                  children: [
                    Semantics(
                      image: true,
                      label: 'Hazuki',
                      child: ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Hazuki',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.aboutDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AboutBadge(
                          label: strings.aboutVersion(currentVersion ?? '…'),
                        ),
                        const _AboutBadge(label: 'GPL-3.0'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: checkingUpdate ? null : onCheckUpdate,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: checkingUpdate
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.system_update_alt_rounded),
                        label: Text(
                          strings.aboutCheckUpdateTitle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.aboutCheckSoftwareUpdateSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _AboutSectionTitle(strings.aboutCommunityTitle),
              SettingsGroup(
                margin: EdgeInsets.zero,
                children: [
                  _AboutAction(
                    icon: Icons.code_rounded,
                    title: strings.aboutProjectTitle,
                    subtitle: 'GitHub · LuckyLxi/Hazuki',
                    external: true,
                    onTap: onOpenProject,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 20),
                  _AboutAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: strings.aboutFeedbackTitle,
                    subtitle: strings.aboutFeedbackSubtitle,
                    external: true,
                    onTap: onOpenFeedback,
                  ),
                ],
              ),
              _AboutSectionTitle(strings.aboutLegalTitle),
              SettingsGroup(
                margin: EdgeInsets.zero,
                children: [
                  _AboutAction(
                    icon: Icons.info_outline_rounded,
                    title: strings.aboutDisclaimerTitle,
                    subtitle: strings.aboutDisclaimerSubtitle,
                    onTap: onOpenDisclaimer,
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 20),
                  _AboutAction(
                    icon: Icons.description_outlined,
                    title: strings.aboutThirdPartyLicensesTitle,
                    subtitle: strings.aboutThirdPartyLicensesSubtitle,
                    onTap: onOpenLicenses,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '© 2026 Hazuki Project',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutBadge extends StatelessWidget {
  const _AboutBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _AboutSectionTitle extends StatelessWidget {
  const _AboutSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AboutAction extends StatelessWidget {
  const _AboutAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        external ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
        size: 20,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
