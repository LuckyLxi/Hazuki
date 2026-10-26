import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu.dart';

Future<ChineseConversionMode?> showChineseConversionMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required ChineseConversionMode selected,
  ValueChanged<Animation<double>?>? onTransitionChanged,
}) {
  final strings = AppLocalizations.of(context)!;
  return showHazukiFrostedMenu(
    context: context,
    anchorKey: anchorKey,
    selected: selected,
    // 菜单由当前值胶囊形变展开，与其他菜单设置行一致。
    morphFromAnchor: true,
    onTransitionChanged: onTransitionChanged,
    label: strings.otherChineseConversionTitle,
    keyPrefix: 'chinese-conversion-menu',
    options: [
      for (final mode in ChineseConversionMode.values)
        HazukiFrostedMenuOption(
          value: mode,
          key: ValueKey('chinese-conversion-choice-${mode.name}'),
          label: switch (mode) {
            ChineseConversionMode.off => strings.otherChineseConversionOff,
            ChineseConversionMode.traditional =>
              strings.otherChineseConversionTraditional,
            ChineseConversionMode.simplified =>
              strings.otherChineseConversionSimplified,
          },
        ),
    ],
  );
}
