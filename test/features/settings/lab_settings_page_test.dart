import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/debug/lab_settings_page.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSourcePluginGateway extends Mock implements SourcePluginGateway {}

void main() {
  testWidgets('lab no longer contains plugin management', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final plugins = _MockSourcePluginGateway();
    when(plugins.initialize).thenAnswer((_) async {});
    when(() => plugins.installed).thenReturn([]);
    when(() => plugins.repositories).thenReturn([]);
    when(() => plugins.entriesFor(any())).thenReturn([]);
    when(() => plugins.checkingIndex).thenReturn(false);
    when(() => plugins.errors).thenReturn({});

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LabSettingsPage(sourcePlugins: plugins),
      ),
    );
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(
      tester.element(find.byType(LabSettingsPage)),
    )!;
    expect(find.text(strings.pluginsTitle), findsNothing);
    expect(find.text(strings.settingsPluginsTitle), findsNothing);
    expect(find.text(strings.labSourceAccountTitle), findsNothing);
    expect(find.text(strings.advancedComicIdSearchTitle), findsNothing);

    expect(find.byType(SourcePluginsPage), findsNothing);
    verifyNever(plugins.initialize);
    expect(tester.takeException(), isNull);
  });
}
