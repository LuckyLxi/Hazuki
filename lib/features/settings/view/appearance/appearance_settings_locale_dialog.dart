import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

Future<AppearanceLocaleDialogChoice?> showAppearanceLocaleDialog(
  BuildContext context, {
  required Locale? currentLocale,
}) {
  return showGeneralDialog<AppearanceLocaleDialogChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.dialogBarrierLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final strings = AppLocalizations.of(dialogContext)!;
      final colorScheme = Theme.of(dialogContext).colorScheme;
      final currentLanguageCode = currentLocale?.languageCode;

      return SafeArea(
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 360,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.displayLanguageTitle,
                    style: Theme.of(dialogContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.displayLanguageSubtitle,
                    style: Theme.of(dialogContext).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _AppearanceLocaleOptionTile(
                    title: strings.displayLanguageSystem,
                    subtitle: 'Use device setting',
                    selected: currentLocale == null,
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(const AppearanceLocaleDialogChoice.system()),
                  ),
                  const SizedBox(height: 10),
                  _AppearanceLocaleOptionTile(
                    title: strings.displayLanguageZhHans,
                    subtitle: 'Simplified Chinese',
                    selected: currentLanguageCode == 'zh',
                    onTap: () => Navigator.of(dialogContext).pop(
                      const AppearanceLocaleDialogChoice.locale(Locale('zh')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AppearanceLocaleOptionTile(
                    title: strings.displayLanguageEnglish,
                    subtitle: 'English',
                    selected: currentLanguageCode == 'en',
                    onTap: () => Navigator.of(dialogContext).pop(
                      const AppearanceLocaleDialogChoice.locale(Locale('en')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AppearanceLocaleDialogChoice {
  const AppearanceLocaleDialogChoice.system()
    : followSystem = true,
      locale = null;

  const AppearanceLocaleDialogChoice.locale(this.locale) : followSystem = false;

  final bool followSystem;
  final Locale? locale;
}

class _AppearanceLocaleOptionTile extends StatelessWidget {
  const _AppearanceLocaleOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.82,
                            )
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Icon(
                selected
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? colorScheme.onPrimary : colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
