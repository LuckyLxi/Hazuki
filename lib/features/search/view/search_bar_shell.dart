import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';

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
    this.onTap,
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
  final VoidCallback? onTap;
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
      onTap: () {
        if (!focusNode.canRequestFocus) {
          return;
        }
        onTap?.call();
        focusNode.requestFocus();
        final textLength = controller.text.length;
        final selection = controller.selection;
        if (!selection.isValid || selection.baseOffset > textLength) {
          controller.selection = TextSelection.collapsed(offset: textLength);
        }
      },
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
        _SearchActionButton(
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

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.showClearAction,
    required this.clearKey,
    required this.submitKey,
    required this.clearTooltip,
    required this.submitTooltip,
    required this.onClear,
    required this.onSubmit,
  });

  final bool showClearAction;
  final String clearKey;
  final String submitKey;
  final String clearTooltip;
  final String submitTooltip;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: showClearAction ? clearTooltip : submitTooltip,
      onPressed: showClearAction ? onClear : onSubmit,
      icon: SizedBox(
        // 固定容器尺寸，防止 AnimatedSwitcher 过渡期间 Stack 大小变化
        // 导致键盘收起时触发 layout 重建而产生位置跳动
        width: 24,
        height: 24,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...previousChildren,
                if (currentChild case final Widget child) child,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeInCubic,
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            showClearAction ? Icons.close : Icons.arrow_forward,
            key: ValueKey<String>(showClearAction ? clearKey : submitKey),
          ),
        ),
      ),
    );
  }
}
