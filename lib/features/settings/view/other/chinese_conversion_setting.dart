import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../settings_group.dart';
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
        leading: const SettingsLeadingIcon(Icons.translate_rounded),
        title: Text(strings.otherChineseConversionTitle),
        subtitle: Text(strings.otherChineseConversionSubtitle),
        // 当前值胶囊与菜单设置项一致，同时作为菜单弹出锚点
        trailing: InkWell(
          key: _anchorKey,
          customBorder: const StadiumBorder(),
          onTap: widget.enabled ? _showMenu : null,
          child: HazukiMenuValuePill(
            key: const ValueKey('chinese-conversion-button'),
            label: label(hazukiChineseConversion.mode),
          ),
        ),
      ),
    );
  }
}
