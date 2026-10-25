import 'package:flutter/widgets.dart';

abstract interface class WindowTitleBarControl implements Listenable {
  bool get useSystemTitleBar;
  bool get shouldShowCustomTitleBar;
  void suppressCustomTitleBar(Object owner);
  void releaseCustomTitleBarSuppression(Object owner);
  Future<void> updateUseSystemTitleBar(bool value);
}

class HazukiWindowsTitleBarScope
    extends InheritedNotifier<WindowTitleBarControl> {
  const HazukiWindowsTitleBarScope({
    super.key,
    required WindowTitleBarControl controller,
    required super.child,
  }) : super(notifier: controller);

  static WindowTitleBarControl of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'HazukiWindowsTitleBarScope is missing.');
    return scope!;
  }

  static WindowTitleBarControl? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HazukiWindowsTitleBarScope>()
        ?.notifier;
  }
}
