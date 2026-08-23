import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/settings/view/appearance/appearance_settings_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _MockSourceDebugGateway extends Mock implements SourceDebugGateway {}

const _initialSettings = AppearanceSettingsData(
  themeMode: ThemeMode.light,
  oledPureBlack: false,
  dynamicColor: false,
  presetIndex: hazukiDefaultAppearancePresetIndex,
  displayModeRaw: 'system',
  comicDetailDynamicColor: false,
  useSystemFont: true,
);

void main() {
  testWidgets('passes slider bounds for brightness reveal synchronization', (
    tester,
  ) async {
    final appliedModes = <ThemeMode>[];
    Rect? syncRegion;
    var settings = _initialSettings;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppearanceSettingsContent(
                settings: settings,
                locale: const Locale('en'),
                onApply: (next, {revealOrigin, revealSyncRegion}) async {
                  appliedModes.add(next.themeMode);
                  syncRegion = revealSyncRegion;
                  setState(() {
                    settings = next;
                  });
                },
                onApplyLocale: (_) async {},
                debugGateway: _MockSourceDebugGateway(),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(appliedModes, [ThemeMode.dark]);
    expect(syncRegion, isNotNull);
    expect(syncRegion!.width, greaterThan(0));
    expect(syncRegion!.height, 52);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
      Alignment.center,
    );
  });
}
