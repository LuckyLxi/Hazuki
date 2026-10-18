import 'package:flutter/widgets.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';

String loginInteractionText(BuildContext context, Object? value) =>
    localizeSourcePluginText(value, Localizations.localeOf(context).toString());
