import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

class FavoriteLoginRequiredView extends StatelessWidget {
  const FavoriteLoginRequiredView({super.key, this.onLoginPressed});

  final VoidCallback? onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final strings = _strings(context);
    return Center(
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(160, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onLoginPressed,
        child: Text(strings.favoriteLoginRequired),
      ),
    );
  }
}
