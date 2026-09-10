import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/services/announcement_service.dart';
import 'package:hazuki/services/announcements/announcement_popup_coordinator.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';

const _cachedPopupManifest = '''
{
  "announcements": [
    {
      "id": "cached-popup",
      "level": "important",
      "title": "Cached popup",
      "publishedAt": "2026-08-31T10:00:00+08:00",
      "content": "Cached content"
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'waits for remote validation before presenting a cached popup',
    () async {
      SharedPreferences.setMockInitialValues({
        hazukiAnnouncementCachePreferenceKey: _cachedPopupManifest,
      });
      final remoteManifest = Completer<String?>();
      final service = AnnouncementService(
        loadRemote: () => remoteManifest.future,
        now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
      );
      final shownIds = <String>[];
      final coordinator = AnnouncementPopupCoordinator(
        controller: service,
        showAnnouncement: (announcement) async {
          shownIds.add(announcement.id);
        },
        isActive: () => true,
      );

      final start = coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(service.nextPopupToPresent?.id, 'cached-popup');
      expect(service.isReadyForPopupPresentation, isFalse);
      expect(shownIds, isEmpty);

      remoteManifest.complete('{"announcements": []}');
      await start;

      expect(service.isReadyForPopupPresentation, isTrue);
      expect(shownIds, isEmpty);
      coordinator.dispose();
      service.dispose();
    },
  );

  test('presents validated popups in order and records them', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "newer",
              "level": "important",
              "title": "Newer",
              "publishedAt": "2026-08-31T11:00:00+08:00",
              "content": "Newer content"
            },
            {
              "id": "older",
              "level": "important",
              "title": "Older",
              "publishedAt": "2026-08-31T10:00:00+08:00",
              "content": "Older content"
            }
          ]
        }
      ''',
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );
    final shownIds = <String>[];
    final coordinator = AnnouncementPopupCoordinator(
      controller: service,
      showAnnouncement: (announcement) async {
        shownIds.add(announcement.id);
      },
      isActive: () => true,
    );

    await coordinator.start();

    expect(shownIds, ['newer', 'older']);
    expect(service.nextPopupToPresent, isNull);
    expect(service.unreadCount, 0);
    coordinator.dispose();
    service.dispose();
  });
}
