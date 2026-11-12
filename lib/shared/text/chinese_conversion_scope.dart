import 'package:flutter/widgets.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';

class ChineseConversionScope
    extends InheritedNotifier<ChineseConversionService> {
  const ChineseConversionScope({
    super.key,
    required ChineseConversionService service,
    required super.child,
  }) : super(notifier: service);

  static ChineseConversionService? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChineseConversionScope>()
      ?.notifier;

  /// 不建立依赖，供事件回调与异步流程读取。
  static ChineseConversionService read(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<ChineseConversionScope>();
    assert(scope != null, 'ChineseConversionScope is missing.');
    return scope!.notifier!;
  }
}

/// 树上没有 scope 时按原文显示。
String convertChineseText(BuildContext context, String text) =>
    ChineseConversionScope.maybeOf(context)?.convert(text) ?? text;
