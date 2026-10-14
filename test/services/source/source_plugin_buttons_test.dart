import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/shared/reading/reader_source_image_quality_settings.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/source_presentation_fixtures.dart';

class _Settings extends Mock implements SourceSettingsGateway {}

void main() {
  test(
    'declared account buttons enable the standard check-in capability without a source ID flag',
    () {
      final host = SourceRuntimeHost(
        catalog: const [
          SourceCatalogEntry(
            key: 'arbitrary',
            name: 'Any plugin',
            fileName: 'any.js',
            presentation: {
              'buttons': [
                {'id': 'checkIn', 'location': 'homeProfile'},
              ],
            },
          ),
        ],
        defaultSourceKey: 'arbitrary',
        secureSessionStorage: MemorySourceSecureSessionStorage(),
        ensureSourceInitialized: (_) async {},
        currentAccountForSource: (_) => null,
        isLoggedForSource: (_) => false,
      );
      addTearDown(host.dispose);
      expect(host.supportsDailyCheckIn, isTrue);
    },
  );
  test('rejects missing, mismatched and reserved button locations', () {
    for (final button in [
      {'id': 'checkIn'},
      {'id': 'checkIn', 'location': 'advanced'},
      {'id': 'comicIdSearch', 'location': 'lab'},
      {'id': 'dailyRecommendation', 'location': 'other'},
      {'id': 'resetDeviceInfo', 'location': 'advanced'},
    ]) {
      expect(
        () => SourcePluginButton.parseList([button]),
        throwsA(isA<SourcePluginException>()),
      );
    }
  });

  test(
    'rejects duplicate slots but allows image quality in both reader locations',
    () {
      expect(
        () => SourcePluginButton.parseList([
          {'id': 'checkIn', 'location': 'homeProfile'},
          {'id': 'checkIn', 'location': 'homeProfile'},
        ]),
        throwsA(isA<SourcePluginException>()),
      );
      expect(
        SourcePluginButton.parseList([
          {'id': 'imageQuality', 'location': 'reading'},
          {'id': 'imageQuality', 'location': 'reader'},
        ]),
        hasLength(2),
      );
    },
  );

  test(
    'manifest validation includes declarations persisted during installation',
    () {
      expect(
        () => SourcePluginManifest.fromJson({
          'id': 'custom',
          'name': 'Custom',
          'version': '1.0.0',
          'entry': 'main.js',
          'presentation': {
            'buttons': [
              {'id': 'checkIn', 'location': 'lines'},
            ],
          },
        }),
        throwsA(isA<SourcePluginException>()),
      );
    },
  );

  testWidgets('button visibility follows declarations for any plugin ID', (
    tester,
  ) async {
    final buttons = <String, bool>{};
    await tester.pumpWidget(
      withTestSourcePresentation(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (final key in ['arbitrary', 'jm', 'picacg', 'copy_manga']) {
                buttons[key] =
                    sourceButton(
                      key,
                      'checkIn',
                      SourcePluginButtonLocation.homeProfile,
                      context: context,
                    ) !=
                    null;
              }
              return const SizedBox();
            },
          ),
        ),
        activeSourceKey: 'arbitrary',
        catalog: const [
          SourceCatalogEntry(
            key: 'arbitrary',
            name: 'Any plugin',
            fileName: 'any.js',
            presentation: {
              'buttons': [
                {'id': 'checkIn', 'location': 'homeProfile'},
              ],
            },
          ),
          SourceCatalogEntry(
            key: 'jm',
            name: 'JM',
            fileName: 'jm.js',
            presentation: {'directComicId': true, 'showComicLike': true},
          ),
        ],
      ),
    );
    expect(buttons, {
      'arbitrary': true,
      'jm': false,
      'picacg': false,
      'copy_manga': false,
    });
    expect(tester.takeException(), isNull);
    tester
        .widget<SourcePresentationScope>(find.byType(SourcePresentationScope))
        .notifier!
        .replaceCatalog(const []);
    await tester.pump();
    expect(buttons.values, everyElement(isFalse));
  });

  test(
    'quality controls honor plugin slots, values and settings keys',
    () async {
      final settings = _Settings();
      when(() => settings.presentationForSource('arbitrary')).thenReturn({
        'imageQualitySetting': 'resolution',
        'imageQualityOptions': {'draft': 'Draft', 'full': 'Full'},
        'imageQualityDefault': 'full',
        'buttons': [
          {'id': 'imageQuality', 'location': 'reader'},
        ],
      });
      when(
        () => settings.updateSourceSetting('arbitrary', 'resolution', 'draft'),
      ).thenAnswer((_) async {});
      final snapshot = ReaderSourceImageQualitySettings.load(
        settings,
        'arbitrary',
      );
      expect(snapshot.isVisibleAt(SourcePluginButtonLocation.reader), isTrue);
      expect(snapshot.isVisibleAt(SourcePluginButtonLocation.reading), isFalse);
      expect(snapshot.value, 'full');
      await ReaderSourceImageQualitySettings.updateImageQuality(
        settings,
        'arbitrary',
        'draft',
      );
      verify(
        () => settings.updateSourceSetting('arbitrary', 'resolution', 'draft'),
      ).called(1);
    },
  );
}
