import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _strings(BuildContext context) => AppLocalizations.of(context)!;

class FavoriteLoginRequiredView extends StatelessWidget {
  const FavoriteLoginRequiredView({super.key, this.onLoginPressed});

  final VoidCallback? onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final strings = _strings(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 34,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.favoriteLoginRequired,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              strings.historyLoginRequired,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 52),
                shape: const StadiumBorder(),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onLoginPressed,
              icon: const Icon(Icons.login_rounded, size: 22),
              label: Text(strings.homeLoginTitle),
            ),
          ],
        ),
      ),
    );
  }
}
