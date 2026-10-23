import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

Future<bool> confirmTranslationClear(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n(context).translationClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).commonConfirm),
          ),
        ],
      ),
    ) ??
    false;
