import 'package:flutter/widgets.dart';

import 'package:hazuki/services/source/gateways/source_image_gateways.dart';

class SourceImageGatewayScope extends InheritedNotifier<Listenable> {
  const SourceImageGatewayScope({
    super.key,
    required this.gateway,
    Listenable? sourceListenable,
    required super.child,
  }) : super(notifier: sourceListenable);

  final SourceImageGateway gateway;

  static SourceImageGateway of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SourceImageGatewayScope>();
    assert(scope != null, 'SourceImageGatewayScope is missing.');
    return scope!.gateway;
  }

  static SourceImageGateway read(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<SourceImageGatewayScope>();
    assert(scope != null, 'SourceImageGatewayScope is missing.');
    return scope!.gateway;
  }

  @override
  bool updateShouldNotify(SourceImageGatewayScope oldWidget) {
    return gateway != oldWidget.gateway || super.updateShouldNotify(oldWidget);
  }
}
