import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/services/announcement_service.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';

const _manifest = '''
{
  "version": 1,
  "announcements": [
    {
      "id": "normal-1",
      "level": "normal",
      "title": "普通通知",
      "publishedAt": "2026-08-30T08:00:00+08:00",
      "expiresAt": "2026-09-30T00:00:00+08:00",
      "content": [
        {"type": "text", "text": "正文"},
        {
          "type": "image",
          "url": "https://example.com/image.webp",
          "width": 1600,
          "height": 900,
          "caption": "配图"
        },
        {
          "type": "link",
          "label": "详情",
          "url": "https://example.com/details"
        }
      ]
    },
    {
      "id": "important-1",
      "level": "important",
      "title": "重要通知",
      "publishedAt": "2026-08-30T09:00:00+08:00",
      "content": "重要正文"
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('empty manifest is a valid no-announcement response', () {
    expect(parseAnnouncementManifest(''), isEmpty);
  });

  test('announcement URL follows the software update source', () {
    expect(
      resolveAnnouncementManifestUrl(SoftwareUpdateSource.jsDelivr),
      'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/announcement.json',
    );
    expect(
      resolveAnnouncementManifestUrl(SoftwareUpdateSource.github),
      'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/announcement.json',
    );
    expect(
      resolveAnnouncementManifestUrl(SoftwareUpdateSource.ghproxy),
      'https://ghproxy.net/https://raw.githubusercontent.com/'
      'LuckyLxi/Hazuki/main/announcement.json',
    );
  });

  test('parses, sorts, and validates announcement content blocks', () {
    final announcements = parseAnnouncementManifest(_manifest)!;

    expect(announcements, hasLength(2));
    expect(announcements.first.id, 'important-1');
    expect(announcements.last.level, AnnouncementLevel.normal);
    expect(announcements.last.content, hasLength(3));
    final image = announcements.last.content[1] as AnnouncementImageBlock;
    expect(image.aspectRatio, closeTo(16 / 9, 0.001));
    expect(announcements.first.showsAsPopup, isTrue);
    expect(announcements.first.showsAsCard, isFalse);
    expect(announcements.last.showsAsCard, isTrue);
    expect(announcements.last.showsAsPopup, isFalse);
  });

  test('presentation independently controls cards and popups', () async {
    const manifest = '''
      {
        "announcements": [
          {
            "id": "normal-popup",
            "level": "normal",
            "presentation": ["popup"],
            "title": "普通弹窗",
            "publishedAt": "2026-08-31T12:00:00+08:00",
            "content": "普通等级也可以弹窗"
          },
          {
            "id": "important-card",
            "level": "important",
            "presentation": ["card"],
            "title": "重要卡片",
            "publishedAt": "2026-08-31T11:00:00+08:00",
            "content": "重要等级也可以只显示卡片"
          },
          {
            "id": "normal-both",
            "level": "normal",
            "presentation": ["card", "popup"],
            "title": "两处显示",
            "publishedAt": "2026-08-31T10:00:00+08:00",
            "content": "同时进入卡片和弹窗"
          }
        ]
      }
    ''';
    final service = AnnouncementService(
      loadRemote: () async => manifest,
      now: () => DateTime.parse('2026-08-31T13:00:00+08:00'),
    );

    await service.refresh();

    expect(service.discoverCardAnnouncements.map((item) => item.id), [
      'important-card',
      'normal-both',
    ]);
    expect(service.nextPopupToPresent?.id, 'normal-popup');
    await service.markPopupPresented(service.nextPopupToPresent!);
    expect(service.nextPopupToPresent?.id, 'normal-both');

    await service.hideCardFromDiscover(service.discoverCardAnnouncements.first);
    expect(service.discoverCardAnnouncements.map((item) => item.id), [
      'normal-both',
    ]);
    expect(service.notificationHistory, hasLength(3));
  });

  test('rejects invalid explicit presentation values', () {
    final announcements = parseAnnouncementManifest('''
      {
        "announcements": [
          {
            "id": "invalid-presentation",
            "level": "normal",
            "presentation": ["banner"],
            "title": "错误展示方式",
            "publishedAt": "2026-08-31T12:00:00+08:00",
            "content": "不会被载入"
          }
        ]
      }
    ''');

    expect(announcements, isEmpty);
  });

  test(
    'publishedAt is display metadata and does not delay visibility',
    () async {
      final service = AnnouncementService(
        loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "future-dated",
              "level": "normal",
              "title": "带发布时间的通知",
              "publishedAt": "2026-08-30T20:00:00+08:00",
              "content": "立即显示"
            }
          ]
        }
      ''',
        now: () => DateTime.parse('2026-08-30T15:00:00+08:00'),
      );

      await service.refresh();

      expect(service.latestDiscoverCard?.id, 'future-dated');
    },
  );

  test('optional visibleAt delays all visibility until its time', () async {
    var now = DateTime.parse('2026-08-31T11:59:00+08:00');
    final service = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "scheduled-important",
              "level": "important",
              "title": "定时重要通知",
              "publishedAt": "2026-08-30T20:00:00+08:00",
              "visibleAt": "2026-08-31T12:00:00+08:00",
              "content": "到点显示"
            }
          ]
        }
      ''',
      now: () => now,
    );

    await service.refresh();

    expect(service.announcements, isEmpty);
    expect(service.notificationHistory, isEmpty);
    expect(service.nextPopupToPresent, isNull);
    expect(service.unreadCount, 0);

    now = DateTime.parse('2026-08-31T12:00:00+08:00');
    expect(service.announcements.single.id, 'scheduled-important');
    expect(service.notificationHistory.single.id, 'scheduled-important');
    expect(service.nextPopupToPresent?.id, 'scheduled-important');
    expect(service.unreadCount, 1);
  });

  test('rejects malformed roots and skips unusable entries', () {
    expect(parseAnnouncementManifest('{}'), isNull);
    expect(parseAnnouncementManifest('{not json'), isNull);
    expect(
      parseAnnouncementManifest('''
        {"announcements":[{"id":"bad","title":"Missing fields"}]}
      '''),
      isEmpty,
    );
  });

  test('tracks read and one-time important presentation state', () async {
    final now = DateTime.parse('2026-08-31T12:00:00+08:00');
    final service = AnnouncementService(
      loadRemote: () async => _manifest,
      now: () => now,
    );

    await service.refresh();

    expect(service.announcements, hasLength(2));
    expect(service.latestDiscoverCard?.id, 'normal-1');
    expect(service.nextPopupToPresent?.id, 'important-1');
    expect(service.unreadCount, 2);

    final important = service.nextPopupToPresent!;
    await service.markPopupPresented(important);
    expect(service.nextPopupToPresent, isNull);
    expect(service.unreadCount, 1);

    await service.markRead(service.latestDiscoverCard!);
    expect(service.unreadCount, 0);

    final restored = AnnouncementService(
      loadRemote: () async => _manifest,
      now: () => now,
    );
    await restored.refresh();
    expect(restored.nextPopupToPresent, isNull);
    expect(restored.unreadCount, 0);
  });

  test('keeps expired announcements in notification history only', () async {
    final service = AnnouncementService(
      loadRemote: () async => _manifest,
      now: () => DateTime.parse('2026-10-01T12:00:00+08:00'),
    );

    await service.refresh();

    expect(service.announcements.map((item) => item.id), ['important-1']);
    expect(service.notificationHistory, hasLength(2));
    expect(service.isExpired(service.notificationHistory.last), isTrue);
    expect(service.unreadCount, 1);
  });

  test(
    'hides normal cards without reading them and keeps new cards visible',
    () async {
      var manifest = '''
      {
        "announcements": [
          {
            "id": "normal-new",
            "level": "normal",
            "title": "较新通知",
            "publishedAt": "2026-08-31T10:00:00+08:00",
            "content": "较新正文"
          },
          {
            "id": "normal-old",
            "level": "normal",
            "title": "较旧通知",
            "publishedAt": "2026-08-30T10:00:00+08:00",
            "content": "较旧正文"
          }
        ]
      }
    ''';
      final now = DateTime.parse('2026-08-31T12:00:00+08:00');
      final service = AnnouncementService(
        loadRemote: () async => manifest,
        now: () => now,
      );
      await service.refresh();

      final newest = service.discoverCardAnnouncements.first;
      await service.hideCardFromDiscover(newest);
      expect(service.discoverCardAnnouncements.map((item) => item.id), [
        'normal-old',
      ]);
      expect(service.isRead(newest), isFalse);
      expect(service.unreadCount, 2);

      await service.hideAllCardsFromDiscover();
      expect(service.discoverCardAnnouncements, isEmpty);
      expect(service.notificationHistory, hasLength(2));
      expect(service.unreadCount, 2);

      manifest = '''
      {
        "announcements": [
          {
            "id": "normal-future-new",
            "level": "normal",
            "title": "后来发布",
            "publishedAt": "2026-08-31T11:00:00+08:00",
            "content": "新正文"
          },
          {
            "id": "normal-new",
            "level": "normal",
            "title": "较新通知",
            "publishedAt": "2026-08-31T10:00:00+08:00",
            "content": "较新正文"
          },
          {
            "id": "normal-old",
            "level": "normal",
            "title": "较旧通知",
            "publishedAt": "2026-08-30T10:00:00+08:00",
            "content": "较旧正文"
          }
        ]
      }
    ''';
      await service.refresh();
      expect(service.discoverCardAnnouncements.map((item) => item.id), [
        'normal-future-new',
      ]);

      final restored = AnnouncementService(
        loadRemote: () async => manifest,
        now: () => now,
      );
      await restored.refresh();
      expect(restored.discoverCardAnnouncements.map((item) => item.id), [
        'normal-future-new',
      ]);
    },
  );
}
