import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/features/announcements/announcements.dart';
import 'package:hazuki/features/announcements/support/announcement_image_session_cache.dart';
import 'package:hazuki/features/announcements/view/announcement_content.dart';
import 'package:hazuki/features/discover/view/discover_announcement_card.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/announcement_service.dart';

const _manifest = '''
{
  "announcements": [
    {
      "id": "normal-1",
      "level": "normal",
      "title": "卡片通知",
      "publishedAt": "2026-08-30T08:00:00+08:00",
      "content": [{"type":"text","text":"只有打开后才显示的完整正文"}]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AnnouncementService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = AnnouncementService(
      loadRemote: () async => _manifest,
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );
    await service.refresh();
  });

  Widget app(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('discover card stays compact and opens full content dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DiscoverAnnouncementCard(
          announcement: service.latestDiscoverCard!,
          service: service,
          onTap: (anchorContext, onMorphLanding) async {
            await showAnnouncementDialog(
              anchorContext,
              service.latestDiscoverCard!,
              morphFromSource: true,
              onMorphLanding: onMorphLanding,
            );
            await service.markRead(service.latestDiscoverCard!);
          },
        ),
      ),
    );

    final cardRect = tester.getRect(find.byType(DiscoverAnnouncementCard));
    expect(cardRect.height, 48);
    expect(find.text('卡片通知'), findsOneWidget);
    expect(find.text('只有打开后才显示的完整正文'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    final cardMaterial = tester.widget<Material>(
      find.byKey(const ValueKey<String>('discover_announcement_card_material')),
    );
    final cardContext = tester.element(
      find.byKey(const ValueKey<String>('discover_announcement_card_material')),
    );
    expect(
      cardMaterial.color,
      Theme.of(cardContext).colorScheme.primaryContainer,
    );

    await tester.tap(find.byType(DiscoverAnnouncementCard));
    await tester.pump();

    final morphDialog = find.byKey(
      const ValueKey<String>('announcement_morph_dialog'),
    );
    expect(morphDialog, findsOneWidget);
    final initialDialogRect = tester.getRect(morphDialog);
    expect(initialDialogRect.top, closeTo(cardRect.top, 0.1));
    expect(initialDialogRect.height, closeTo(cardRect.height, 0.1));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('discover_announcement_card_opacity'),
            ),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 100));
    final movingDialogRect = tester.getRect(morphDialog);
    expect(movingDialogRect.height, greaterThan(initialDialogRect.height));

    await tester.pumpAndSettle();
    expect(find.text('只有打开后才显示的完整正文'), findsOneWidget);
    expect(tester.getSize(morphDialog).height, lessThan(400));
    final shortContentScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('announcement_dialog_content_scroll')),
    );
    expect(shortContentScroll.physics, isA<NeverScrollableScrollPhysics>());

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(morphDialog, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('discover_announcement_card_opacity'),
            ),
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('discover_announcement_card_opacity'),
            ),
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(milliseconds: 190));
    expect(morphDialog, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('discover_announcement_card_opacity'),
            ),
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(milliseconds: 60));
    final landingScale = tester.widget<ScaleTransition>(
      find.byKey(
        const ValueKey<String>('discover_announcement_card_landing_scale'),
      ),
    );
    expect(landingScale.scale.value, greaterThan(1));
    await tester.pumpAndSettle();
    expect(morphDialog, findsNothing);
    expect(landingScale.scale.value, closeTo(1, 0.001));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('discover_announcement_card_opacity'),
            ),
          )
          .opacity,
      1,
    );
    expect(service.isRead(service.latestDiscoverCard!), isTrue);
  });

  testWidgets('important discover card uses the important color treatment', (
    tester,
  ) async {
    final announcement = Announcement(
      id: 'important-card',
      level: AnnouncementLevel.important,
      presentation: const {AnnouncementPresentation.card},
      title: '重要卡片',
      publishedAt: DateTime.parse('2026-08-31T10:00:00+08:00'),
      content: const [AnnouncementTextBlock('重要卡片正文')],
    );

    await tester.pumpWidget(
      app(
        DiscoverAnnouncementCard(announcement: announcement, service: service),
      ),
    );

    final material = tester.widget<Material>(
      find.byKey(const ValueKey<String>('discover_announcement_card_material')),
    );
    final context = tester.element(
      find.byKey(const ValueKey<String>('discover_announcement_card_material')),
    );
    expect(material.color, Theme.of(context).colorScheme.errorContainer);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.notifications_none_rounded)).color,
      Theme.of(context).colorScheme.error,
    );
  });

  testWidgets(
    'discover announcement slot animates its appearance and removal',
    (tester) async {
      List<Announcement> visibleAnnouncements = const [];
      late StateSetter updateSlot;

      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              updateSlot = setState;
              return DiscoverAnnouncementAnimatedSlot(
                announcements: visibleAnnouncements,
                service: service,
              );
            },
          ),
        ),
      );

      final slot = find.byKey(
        const ValueKey<String>('discover_announcement_slot'),
      );
      expect(tester.getSize(slot).height, 0);

      updateSlot(
        () => visibleAnnouncements = service.discoverCardAnnouncements,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final appearingHeight = tester.getSize(slot).height;
      expect(appearingHeight, greaterThan(0));
      expect(appearingHeight, lessThan(60));

      await tester.pumpAndSettle();
      expect(tester.getSize(slot).height, 60);

      updateSlot(() => visibleAnnouncements = const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final disappearingHeight = tester.getSize(slot).height;
      expect(disappearingHeight, greaterThan(0));
      expect(disappearingHeight, lessThan(60));

      await tester.pumpAndSettle();
      expect(tester.getSize(slot).height, 0);
    },
  );

  testWidgets('discover stack switches cards and hides them without reading', (
    tester,
  ) async {
    final stackService = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "normal-new",
              "level": "normal",
              "title": "新通知",
              "publishedAt": "2026-08-31T10:00:00+08:00",
              "content": "新正文"
            },
            {
              "id": "normal-old",
              "level": "normal",
              "title": "旧通知",
              "publishedAt": "2026-08-30T10:00:00+08:00",
              "content": "旧正文"
            }
          ]
        }
      ''',
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );
    await stackService.refresh();
    await tester.pumpWidget(
      app(
        ListenableBuilder(
          listenable: stackService,
          builder: (context, child) => DiscoverAnnouncementAnimatedSlot(
            announcements: stackService.discoverCardAnnouncements,
            service: stackService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stackFinder = find.byKey(
      const ValueKey<String>('discover_announcement_stack'),
    );
    String topDeckKey() {
      final sizedBox = tester.widget<SizedBox>(stackFinder);
      final stack = sizedBox.child! as Stack;
      final topCard = stack.children.last as Positioned;
      return (topCard.key! as ValueKey<String>).value;
    }

    expect(
      find.byKey(
        const ValueKey<String>('discover_announcement_deck_normal-old'),
      ),
      findsOneWidget,
    );
    expect(topDeckKey(), 'discover_announcement_deck_normal-new');

    final oldVisual = find.byKey(
      const ValueKey<String>('discover_announcement_deck_visual_normal-old'),
    );
    final oldTopBeforeDrag = tester.getTopLeft(oldVisual).dy;
    final drag = await tester.startGesture(tester.getCenter(stackFinder));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(tester.getTopLeft(oldVisual).dy, lessThan(oldTopBeforeDrag));
    await drag.moveBy(const Offset(-180, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(topDeckKey(), 'discover_announcement_deck_normal-old');

    await tester.fling(stackFinder, const Offset(500, 0), 1200);
    await tester.pumpAndSettle();
    expect(topDeckKey(), 'discover_announcement_deck_normal-new');

    await tester.fling(stackFinder, const Offset(500, 0), 1200);
    await tester.pumpAndSettle();
    expect(topDeckKey(), 'discover_announcement_deck_normal-old');
    await tester.fling(stackFinder, const Offset(-500, 0), 1200);
    await tester.pumpAndSettle();
    expect(topDeckKey(), 'discover_announcement_deck_normal-new');

    await tester.longPress(
      find.byKey(
        const ValueKey<String>('discover_announcement_deck_visual_normal-new'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('announcement_menu_hide_current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('announcement_menu_hide_all')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('announcement_menu_hide_current')),
    );
    await tester.pumpAndSettle();
    expect(topDeckKey(), 'discover_announcement_deck_normal-old');
    expect(
      stackService.isRead(stackService.notificationHistory.first),
      isFalse,
    );
    expect(stackService.unreadCount, 2);

    await tester.longPress(
      find.byKey(
        const ValueKey<String>('discover_announcement_deck_visual_normal-old'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('announcement_menu_hide_all')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('discover_announcement_stack')),
      findsNothing,
    );
    expect(stackService.notificationHistory, hasLength(2));
    expect(stackService.unreadCount, 2);
  });

  testWidgets('physical deck reveals its buffered bottom card while dragging', (
    tester,
  ) async {
    final deckService = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "deck-3",
              "level": "normal",
              "title": "第三张",
              "publishedAt": "2026-08-31T12:00:00+08:00",
              "content": "第三张正文"
            },
            {
              "id": "deck-2",
              "level": "normal",
              "title": "第二张",
              "publishedAt": "2026-08-31T11:00:00+08:00",
              "content": "第二张正文"
            },
            {
              "id": "deck-1",
              "level": "normal",
              "title": "第一张",
              "publishedAt": "2026-08-31T10:00:00+08:00",
              "content": "第一张正文"
            }
          ]
        }
      ''',
      now: () => DateTime.parse('2026-08-31T13:00:00+08:00'),
    );
    await deckService.refresh();
    await tester.pumpWidget(
      app(
        DiscoverAnnouncementAnimatedSlot(
          announcements: deckService.discoverCardAnnouncements,
          service: deckService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stackFinder = find.byKey(
      const ValueKey<String>('discover_announcement_stack'),
    );
    final bufferOpacity = find.byKey(
      const ValueKey<String>(
        'discover_announcement_deck_buffer_opacity_deck-3',
      ),
    );
    final bottomVisual = find.byKey(
      const ValueKey<String>('discover_announcement_deck_visual_deck-1'),
    );
    expect(tester.widget<Opacity>(bufferOpacity).opacity, 0);
    expect(
      find.ancestor(of: stackFinder, matching: find.byType(ClipRect)),
      findsNothing,
    );
    final bottomTopBeforeDrag = tester.getTopLeft(bottomVisual).dy;

    final drag = await tester.startGesture(tester.getCenter(stackFinder));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();

    final revealedOpacity = tester.widget<Opacity>(bufferOpacity).opacity;
    expect(revealedOpacity, greaterThan(0));
    expect(revealedOpacity, lessThan(1));
    expect(tester.getTopLeft(bottomVisual).dy, lessThan(bottomTopBeforeDrag));
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('morph dialog caps its height and scrolls long content', (
    tester,
  ) async {
    final announcement = Announcement(
      id: 'long',
      level: AnnouncementLevel.normal,
      presentation: const {AnnouncementPresentation.card},
      title: '长通知',
      publishedAt: DateTime.parse('2026-08-30T08:00:00+08:00'),
      content: [
        AnnouncementTextBlock(List<String>.filled(200, '很长的正文').join()),
      ],
    );
    await tester.pumpWidget(
      app(
        DiscoverAnnouncementCard(
          announcement: announcement,
          service: service,
          onTap: (anchorContext, onMorphLanding) => showAnnouncementDialog(
            anchorContext,
            announcement,
            morphFromSource: true,
            onMorphLanding: onMorphLanding,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DiscoverAnnouncementCard));
    await tester.pumpAndSettle();

    final morphDialog = find.byKey(
      const ValueKey<String>('announcement_morph_dialog'),
    );
    expect(tester.getSize(morphDialog).height, closeTo(568, 0.1));
    final longContentScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('announcement_dialog_content_scroll')),
    );
    expect(longContentScroll.physics, isA<ClampingScrollPhysics>());
    final title = find.byKey(
      const ValueKey<String>('announcement_dialog_title'),
    );
    final date = find.byKey(const ValueKey<String>('announcement_dialog_date'));
    final titleTop = tester.getTopLeft(title).dy;
    final dateTop = tester.getTopLeft(date).dy;

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dy, closeTo(titleTop, 0.1));
    expect(tester.getTopLeft(date).dy, closeTo(dateTop, 0.1));

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'morph dialog scrolls measured image caption and link content at its cap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final linkLabel = List<String>.filled(2, '查看这条公告的完整功能说明').join('，');
      final announcement = Announcement(
        id: 'measured-content',
        level: AnnouncementLevel.normal,
        presentation: const {AnnouncementPresentation.card},
        title: '包含图片的通知',
        publishedAt: DateTime.parse('2026-08-30T08:00:00+08:00'),
        content: [
          const AnnouncementTextBlock('正文内容'),
          const AnnouncementImageBlock(
            url: 'https://example.com/announcement.jpg',
            width: 1600,
            height: 900,
            caption: '功能示意图\n图片说明会占用实际布局高度',
          ),
          AnnouncementLinkBlock(
            label: linkLabel,
            url: 'https://example.com/help',
          ),
        ],
      );
      await tester.pumpWidget(
        app(
          DiscoverAnnouncementCard(
            announcement: announcement,
            service: service,
            onTap: (anchorContext, onMorphLanding) => showAnnouncementDialog(
              anchorContext,
              announcement,
              morphFromSource: true,
              onMorphLanding: onMorphLanding,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DiscoverAnnouncementCard));
      await tester.pumpAndSettle();

      final contentScroll = find.byKey(
        const ValueKey<String>('announcement_dialog_content_scroll'),
      );
      final scrollView = tester.widget<SingleChildScrollView>(contentScroll);
      final scrollableState = tester.state<ScrollableState>(
        find
            .descendant(of: contentScroll, matching: find.byType(Scrollable))
            .first,
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('announcement_morph_dialog')),
            )
            .height,
        closeTo(570, 0.1),
      );
      expect(scrollView.physics, isA<ClampingScrollPhysics>());
      expect(scrollableState.position.maxScrollExtent, greaterThan(0));

      await tester.drag(contentScroll, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, greaterThan(0));
      expect(find.widgetWithText(TextButton, linkLabel), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('important announcement animates on open and close', (
    tester,
  ) async {
    final importantAnnouncement = Announcement(
      id: 'important-animation',
      level: AnnouncementLevel.important,
      presentation: const {AnnouncementPresentation.popup},
      title: '重要通知',
      publishedAt: DateTime.parse('2026-08-30T08:00:00+08:00'),
      content: const [AnnouncementTextBlock('需要立即查看的内容')],
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () =>
                showAnnouncementDialog(context, importantAnnouncement),
            child: const Text('打开重要通知'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开重要通知'));
    await tester.pump();

    final scaleTransition = find.byKey(
      const ValueKey<String>('important_announcement_scale_transition'),
    );
    final fadeTransition = find.byKey(
      const ValueKey<String>('important_announcement_fade_transition'),
    );
    expect(scaleTransition, findsOneWidget);
    expect(fadeTransition, findsOneWidget);
    expect(
      tester.widget<ScaleTransition>(scaleTransition).scale.value,
      closeTo(0.9, 0.01),
    );
    expect(
      tester.widget<FadeTransition>(fadeTransition).opacity.value,
      closeTo(0, 0.01),
    );

    await tester.pumpAndSettle();
    expect(
      tester.widget<ScaleTransition>(scaleTransition).scale.value,
      closeTo(1, 0.01),
    );
    expect(
      tester.widget<FadeTransition>(fadeTransition).opacity.value,
      closeTo(1, 0.01),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleTransition, findsOneWidget);
    expect(
      tester.widget<ScaleTransition>(scaleTransition).scale.value,
      lessThan(1),
    );
    expect(
      tester.widget<FadeTransition>(fadeTransition).opacity.value,
      lessThan(1),
    );

    await tester.pumpAndSettle();
    expect(scaleTransition, findsNothing);
  });

  testWidgets('announcement image opens a zoomable full screen viewer', (
    tester,
  ) async {
    var downloadCount = 0;
    final imageCache = AnnouncementImageSessionCache(
      download: (url) async {
        downloadCount++;
        return base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lE'
          'QVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        );
      },
    );
    final announcement = Announcement(
      id: 'image-viewer',
      level: AnnouncementLevel.normal,
      presentation: const {AnnouncementPresentation.card},
      title: '图片通知',
      publishedAt: DateTime.parse('2026-08-30T08:00:00+08:00'),
      content: const [
        AnnouncementImageBlock(
          url: 'https://example.com/announcement.png',
          width: 1,
          height: 1,
          caption: '图片说明',
        ),
      ],
    );
    Widget content() => app(
      SingleChildScrollView(
        child: AnnouncementContent(
          announcement: announcement,
          imageCache: imageCache,
        ),
      ),
    );
    await tester.pumpWidget(content());
    await tester.pump();

    final revealOpacity = find.byKey(
      const ValueKey<String>(
        'announcement_image_reveal_opacity_'
        'https://example.com/announcement.png',
      ),
    );
    expect(revealOpacity, findsOneWidget);
    expect(tester.widget<Opacity>(revealOpacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(revealOpacity).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(revealOpacity).opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(revealOpacity).opacity, 1);
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsNothing);

    final sourceImage = find.byKey(
      const ValueKey<String>(
        'announcement_image_https://example.com/announcement.png',
      ),
    );
    final sourceOpacity = find.byKey(
      const ValueKey<String>(
        'announcement_image_source_opacity_'
        'https://example.com/announcement.png',
      ),
    );
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 1);
    final sourceRect = tester.getRect(sourceImage);
    await tester.tap(sourceImage);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('announcement_image_viewer')),
      findsOneWidget,
    );
    final sharedElement = find.byKey(
      const ValueKey<String>('announcement_image_shared_element'),
    );
    expect(tester.getRect(sharedElement), sourceRect);
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 0);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.pump();
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 0);
    expect(tester.getRect(sharedElement), sourceRect);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getSize(sharedElement).height,
      greaterThan(sourceRect.height),
    );
    expect(tester.getRect(sharedElement), isNot(sourceRect));
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(
      const ValueKey<String>('announcement_image_interactive_viewer'),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 5);
    final transformationController = viewer.transformationController!;

    await tester.tap(viewerFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewerFinder);
    await tester.pumpAndSettle();
    expect(
      transformationController.value.getMaxScaleOnAxis(),
      closeTo(2.5, 0.01),
    );

    await tester.tap(viewerFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewerFinder);
    await tester.pumpAndSettle();
    expect(
      transformationController.value.getMaxScaleOnAxis(),
      closeTo(1, 0.01),
    );

    Navigator.of(tester.element(viewerFinder)).pop();
    await tester.pump();
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 0);
    expect(sharedElement, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 1);
    expect(sharedElement, findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('announcement_image_viewer')),
      findsNothing,
    );
    expect(tester.widget<Opacity>(sourceOpacity).opacity, 1);
    expect(sharedElement, findsNothing);
    await tester.pumpWidget(content());
    await tester.pumpAndSettle();

    expect(downloadCount, 1);
  });

  testWidgets('notification page renders full content directly', (
    tester,
  ) async {
    await tester.pumpWidget(app(AnnouncementPage(service: service)));
    await tester.pump();

    expect(find.text('卡片通知'), findsOneWidget);
    expect(find.text('只有打开后才显示的完整正文'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(service.unreadCount, 0);
  });

  testWidgets('notification page marks announcements arriving later as read', (
    tester,
  ) async {
    final remoteManifest = Completer<String?>();
    final delayedService = AnnouncementService(
      loadRemote: () => remoteManifest.future,
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );

    await tester.pumpWidget(app(AnnouncementPage(service: delayedService)));
    await tester.pump();
    expect(delayedService.unreadCount, 0);

    final refresh = delayedService.refresh();
    remoteManifest.complete('''
      {
        "announcements": [
          {
            "id": "arrived-later",
            "level": "normal",
            "title": "稍后到达的通知",
            "publishedAt": "2026-08-31T11:00:00+08:00",
            "content": "页面打开后才加载完成"
          }
        ]
      }
    ''');
    await refresh;
    await tester.pumpAndSettle();

    expect(find.text('稍后到达的通知'), findsOneWidget);
    expect(delayedService.unreadCount, 0);
  });

  testWidgets('notification page keeps expired cards with a gray badge', (
    tester,
  ) async {
    final historyService = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "active-1",
              "level": "normal",
              "title": "当前通知",
              "publishedAt": "2026-08-31T08:00:00+08:00",
              "content": "当前内容"
            },
            {
              "id": "expired-1",
              "level": "normal",
              "title": "过期通知",
              "publishedAt": "2026-08-30T08:00:00+08:00",
              "expiresAt": "2026-08-31T00:00:00+08:00",
              "content": "历史内容"
            }
          ]
        }
      ''',
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );
    await historyService.refresh();

    await tester.pumpWidget(app(AnnouncementPage(service: historyService)));
    await tester.pump();

    expect(find.text('当前通知'), findsOneWidget);
    expect(find.text('过期通知'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('announcement_expired_badge_expired-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('announcement_expired_badge_active-1')),
      findsNothing,
    );
    expect(historyService.latestDiscoverCard?.id, 'active-1');
  });

  testWidgets('notification page colors levels and connects timeline cards', (
    tester,
  ) async {
    final timelineService = AnnouncementService(
      loadRemote: () async => '''
        {
          "announcements": [
            {
              "id": "important-1",
              "level": "important",
              "title": "重要通知",
              "publishedAt": "2026-08-31T08:00:00+08:00",
              "content": [{"type":"text","text":"重要内容"}]
            },
            {
              "id": "normal-1",
              "level": "normal",
              "title": "普通通知",
              "publishedAt": "2026-08-30T08:00:00+08:00",
              "content": [{"type":"text","text":"普通内容"}]
            }
          ]
        }
      ''',
      now: () => DateTime.parse('2026-08-31T12:00:00+08:00'),
    );
    await timelineService.refresh();

    await tester.pumpWidget(app(AnnouncementPage(service: timelineService)));
    await tester.pump();

    final importantCard = tester.widget<Card>(
      find.byKey(const ValueKey<String>('announcement_card_important-1')),
    );
    final normalCard = tester.widget<Card>(
      find.byKey(const ValueKey<String>('announcement_card_normal-1')),
    );
    final cardContext = tester.element(
      find.byKey(const ValueKey<String>('announcement_card_normal-1')),
    );
    final theme = Theme.of(cardContext);

    expect(
      importantCard.color,
      Color.alphaBlend(
        Colors.red.withValues(alpha: 0.12),
        theme.colorScheme.surface,
      ),
    );
    expect(
      normalCard.color,
      Color.alphaBlend(
        Colors.blue.withValues(alpha: 0.12),
        theme.colorScheme.surface,
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('announcement_timeline_node_important-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('announcement_timeline_node_normal-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('announcement_timeline_line_important-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('announcement_timeline_line_normal-1')),
      findsOneWidget,
    );
  });
}
