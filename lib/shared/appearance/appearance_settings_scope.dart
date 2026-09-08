import 'package:flutter/widgets.dart';
import 'appearance_settings.dart';

abstract interface class AppearanceSettingsSource implements Listenable {
  AppearanceSettingsData get settings;
}

class HazukiThemeControllerScope
    extends InheritedNotifier<AppearanceSettingsSource> {
  const HazukiThemeControllerScope({
    super.key,
    required AppearanceSettingsSource controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceSettingsSource? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HazukiThemeControllerScope>()
        ?.notifier;
  }

  static AppearanceSettingsSource of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'HazukiThemeControllerScope not found');
    return controller!;
  }
}
