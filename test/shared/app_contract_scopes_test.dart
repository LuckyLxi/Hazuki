import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/shared/appearance/appearance_settings_scope.dart';
import 'package:hazuki/shared/window/window_title_bar_control.dart';

class _AppearanceSource extends ChangeNotifier
    implements AppearanceSettingsSource {
  @override
  AppearanceSettingsData settings = const AppearanceSettingsData(
    themeMode: ThemeMode.system,
    oledPureBlack: false,
    dynamicColor: false,
    presetIndex: 0,
    displayModeRaw: 'native:auto',
    comicDetailDynamicColor: false,
    useSystemFont: true,
  );

  void enableComicColor() {
    settings = settings.copyWith(comicDetailDynamicColor: true);
    notifyListeners();
  }
}

class _WindowControl extends ChangeNotifier implements WindowTitleBarControl {
  @override
  bool useSystemTitleBar = false;
  final owners = <Object>{};

  @override
  bool get shouldShowCustomTitleBar => !useSystemTitleBar && owners.isEmpty;

  @override
  void suppressCustomTitleBar(Object owner) {
    owners.add(owner);
    notifyListeners();
  }

  @override
  void releaseCustomTitleBarSuppression(Object owner) {
    owners.remove(owner);
    notifyListeners();
  }

  @override
  Future<void> updateUseSystemTitleBar(bool value) async {
    useSystemTitleBar = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('appearance consumers observe an independent settings source', (
    tester,
  ) async {
    final source = _AppearanceSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      HazukiThemeControllerScope(
        controller: source,
        child: Builder(
          builder: (context) => Text(
            '${HazukiThemeControllerScope.of(context).settings.comicDetailDynamicColor}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    expect(find.text('false'), findsOneWidget);
    source.enableComicColor();
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
  });

  testWidgets(
    'window consumers rebind and stop observing the previous control',
    (tester) async {
      final first = _WindowControl();
      final second = _WindowControl();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var builds = 0;
      final consumer = Builder(
        builder: (context) {
          builds++;
          return Text(
            '${HazukiWindowsTitleBarScope.of(context).shouldShowCustomTitleBar}',
            textDirection: TextDirection.ltr,
          );
        },
      );
      Future<void> bind(WindowTitleBarControl controller) => tester.pumpWidget(
        HazukiWindowsTitleBarScope(controller: controller, child: consumer),
      );

      await bind(first);
      first.suppressCustomTitleBar(consumer);
      await tester.pump();
      expect(find.text('false'), findsOneWidget);
      await bind(second);
      expect(find.text('true'), findsOneWidget);
      final buildsAfterRebind = builds;
      first.releaseCustomTitleBarSuppression(consumer);
      await tester.pump();
      expect(builds, buildsAfterRebind);
      await second.updateUseSystemTitleBar(true);
      await tester.pump();
      expect(find.text('false'), findsOneWidget);
    },
  );
}
