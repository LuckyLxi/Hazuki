import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/cache_settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _MockSourceSettingsGateway extends Mock
    implements SourceSettingsGateway {}

const _mb = 1024 * 1024;

void main() {
  testWidgets('shows usage after load and flashes completion after clear', (
    tester,
  ) async {
    final gateway = _MockSourceSettingsGateway();
    var usedBytes = 512 * _mb;
    final firstLoad = Completer<void>();
    when(() => gateway.imageCacheMaxBytes).thenReturn(1024 * _mb);
    when(gateway.getImageCacheStatus).thenAnswer((_) async {
      await firstLoad.future;
      return {
        'maxBytes': 1024 * _mb,
        'usedBytes': usedBytes,
        'autoCleanMode': 'size_overflow',
      };
    });
    when(gateway.clearImageCache).thenAnswer((_) async {
      usedBytes = 0;
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CacheSettingsPage(sourceService: gateway),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    final strings = AppLocalizations.of(
      tester.element(find.byType(CacheSettingsPage)),
    )!;
    // 首次加载期间不显示占比。
    expect(find.text('… / 1.00 GB'), findsOneWidget);

    firstLoad.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('512 MB / 1.00 GB'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(
      find.text(strings.cacheClearNowReleasable('512 MB')),
      findsOneWidget,
    );

    await tester.tap(find.text(strings.cacheClearNowTitle));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(strings.cacheClearConfirm));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0 MB / 1.00 GB'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    // 等待图标切换的退场动画结束。
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text(strings.cacheClearNowSubtitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
