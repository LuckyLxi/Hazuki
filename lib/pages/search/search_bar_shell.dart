import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'search_shared.dart';

class SearchBarShell extends StatelessWidget {
  const SearchBarShell({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.clearKey,
    required this.submitKey,
    required this.onClear,
    required this.onSubmit,
    this.onChanged,
    this.onSubmitted,
    this.compact = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String clearKey;
  final String submitKey;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool compact;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final searchBar = SearchBar(
      focusNode: focusNode,
      controller: controller,
      hintText: strings.searchHint,
      autoFocus: autofocus,
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
        ),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      ),
      textInputAction: TextInputAction.search,
      leading: Icon(Icons.search, size: compact ? 20 : 24),
      trailing: [
        buildAnimatedSearchActionButton(
          showClearAction: controller.text.isNotEmpty,
          clearKey: clearKey,
          submitKey: submitKey,
          clearTooltip: strings.searchClearTooltip,
          submitTooltip: strings.searchSubmitTooltip,
          onClear: onClear,
          onSubmit: onSubmit,
        ),
      ],
      onSubmitted: onSubmitted ?? (_) => onSubmit(),
      onChanged: onChanged,
    );

    if (!compact) {
      return SizedBox(height: 56, child: searchBar);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 40),
      child: searchBar,
    );
  }
}
