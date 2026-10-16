import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
import 'chinese_conversion_menu.dart';

class ChineseConversionSetting extends StatefulWidget {
  const ChineseConversionSetting({
    super.key,
    required this.onChanged,
    this.enabled = true,
  });

  final ValueChanged<ChineseConversionMode> onChanged;
  final bool enabled;

  @override
  State<ChineseConversionSetting> createState() =>
      _ChineseConversionSettingState();
}

class _ChineseConversionSettingState extends State<ChineseConversionSetting> {
  final _anchorKey = GlobalKey();
  bool _menuOpen = false;

  Future<void> _showMenu() async {
    if (!widget.enabled || _menuOpen) return;
    _menuOpen = true;
    try {
      final mode = await showChineseConversionMenu(
        context: context,
        anchorKey: _anchorKey,
        selected: hazukiChineseConversion.mode,
      );
      if (mounted && widget.enabled && mode != null) widget.onChanged(mode);
    } finally {
      _menuOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    String label(ChineseConversionMode mode) => switch (mode) {
      ChineseConversionMode.off => strings.otherChineseConversionOff,
      ChineseConversionMode.traditional =>
        strings.otherChineseConversionTraditional,
      ChineseConversionMode.simplified =>
        strings.otherChineseConversionSimplified,
    };

    return ListenableBuilder(
      listenable: hazukiChineseConversion,
      builder: (context, _) => ListTile(
        key: const ValueKey('other-chinese-conversion-menu'),
        enabled: widget.enabled,
        onTap: widget.enabled ? _showMenu : null,
        leading: const Icon(Icons.translate_rounded),
        title: Text(strings.otherChineseConversionTitle),
        subtitle: Text(strings.otherChineseConversionSubtitle),
        trailing: InkWell(
          key: _anchorKey,
          borderRadius: BorderRadius.circular(20),
          onTap: widget.enabled ? _showMenu : null,
          child: Padding(
            key: const ValueKey('chinese-conversion-button'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label(hazukiChineseConversion.mode)),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
