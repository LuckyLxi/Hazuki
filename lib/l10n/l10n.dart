import 'package:material_ui/material_ui.dart';

import 'app_localizations.dart';

AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context)!;

/// 应用本地化代理。
///
/// gen-l10n 生成的 `AppLocalizations.localizationsDelegates` 仍引用
/// flutter_localizations 的旧版 Material/Cupertino 代理，material_ui 组件读取不到，
/// 因此统一改用 material_ui 提供的代理集合。
const List<LocalizationsDelegate<dynamic>> hazukiLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
