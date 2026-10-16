import 'package:flutter/widgets.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';

class ChineseConversionScope
    extends InheritedNotifier<ChineseConversionService> {
  ChineseConversionScope({
    super.key,
    ChineseConversionService? service,
    required super.child,
  }) : super(notifier: service ?? hazukiChineseConversion);

  static ChineseConversionService of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ChineseConversionScope>()
          ?.notifier ??
      hazukiChineseConversion;
}

String convertChineseText(BuildContext context, String text) =>
    ChineseConversionScope.of(context).convert(text);
