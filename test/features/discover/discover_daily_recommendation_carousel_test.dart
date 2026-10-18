import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/discover/view/discover_daily_recommendation_carousel.dart';
import 'package:hazuki/features/discover/view/discover_daily_recommendation_carousel_widgets.dart';
import 'package:hazuki/features/home/view/home_drawer_snapshot.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

class _Service extends Mock implements DiscoverDailyRecommendationService {
  _Service({this.pluginMode = true});
  final bool pluginMode;
  @override
  bool get usesPluginRecommendations => pluginMode;
}

class _Images extends Fake implements SourceRecommendationGateway {
  _Images() {
    // Seed decoded frames for the two card widths used below. Network bytes
    // and decoded image availability are controlled separately in widget tests.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(2, 2);
    picture.dispose();
    final pixelRatio = TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .devicePixelRatio;
    for (final width in [
      null,
      (264 * pixelRatio).round(),
      (300 * pixelRatio).round(),
    ]) {
      final provider = ResizeImage.resizeIfNeeded(
        width,
        null,
        MemoryImage(bytes),
      );
      provider.obtainKey(ImageConfiguration.empty).then((key) {
        PaintingBinding.instance.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: image.clone())),
          ),
        );
      });
    }
    image.dispose();
  }
  final pending = Completer<Uint8List>();
  bool delayed = false;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZQ0AAAAASUVORK5CYII=',
  );
  @override
  String get activeSourceKey => 'website';
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      delayed ? null : bytes;
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async => delayed ? pending.future : bytes;
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {}
}

List<DiscoverDailyRecommendationEntry> _items(int count) => List.generate(
  count,
  (index) => DiscoverDailyRecommendationEntry(
    comic: ExploreComic(
      id: '$index',
      sourceKey: 'website',
      title: 'Comic $index',
      subTitle: '',
      cover: 'https://example.com/cover-$index.png',
    ),
    imageUrl: 'https://example.com/banner-$index.png',
  ),
);

Widget _carousel(
  _Images images,
  _Service service,
  List<DiscoverDailyRecommendationEntry> items, {
  List<DiscoverDailyRecommendationEntry> pending = const [],
  Widget Function(ExploreComic, String)? comicDetailPageBuilder,
}) => SourceImageGatewayScope(
  gateway: images,
  child: DiscoverDailyRecommendationCarousel(
    displayedRecommendations: items,
    pendingRecommendations: pending,
    isPendingReady: pending.isNotEmpty,
    sourceService: images,
    recommendationService: service,
    comicCoverHeroTagBuilder: (comic, {salt}) => 'comic-${comic.id}-$salt',
    comicDetailPageBuilder:
        comicDetailPageBuilder ?? (comic, heroTag) => const SizedBox(),
  ),
);

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);

  testWidgets('banner content stays separate when opening comic detail', (
    tester,
  ) async {
    final comic = _items(1).single.comic;
    final entry = DiscoverDailyRecommendationEntry(
      comic: comic,
      bannerTitle: 'Website weekly picks',
      author: 'Editor recommendation',
      imageUrl: 'https://example.com/promotional.png',
    );
    final controller = WindowsComicDetailController();
    addTearDown(controller.dispose);
    ExploreComic? openedComic;
    await tester.pumpWidget(
      MaterialApp(
        home: WindowsComicDetailControllerScope(
          controller: controller,
          child: Scaffold(
            body: _carousel(
              _Images(),
              _Service(),
              [entry],
              comicDetailPageBuilder: (comic, _) {
                openedComic = comic;
                return const Scaffold(body: Text('Comic detail'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Website weekly picks'), findsOneWidget);
    expect(find.text('Editor recommendation'), findsOneWidget);
    expect(find.text(comic.title), findsNothing);
    expect(
      tester.widget<HazukiCachedImage>(find.byType(HazukiCachedImage)).url,
      entry.imageUrl,
    );
    await tester.tap(find.text('Website weekly picks'));
    await tester.pumpAndSettle();
    final target = useWindowsComicDetailPanel
        ? controller.entry!.comic
        : openedComic!;
    expect(target, same(comic));
    expect(target.title, 'Comic 0');
    expect(target.cover, 'https://example.com/cover-0.png');
    expect(target.sourceKey, 'website');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('banner title changes refresh without changing comic data', (
    tester,
  ) async {
    final original = _items(1).single;
    var entry = original;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return _carousel(_Images(), _Service(), [entry]);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(original.comic.title), findsOneWidget);
    update(() {
      entry = DiscoverDailyRecommendationEntry(
        comic: original.comic,
        imageUrl: original.imageUrl,
        bannerTitle: 'Updated promotion',
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Updated promotion'), findsOneWidget);
    expect(find.text(original.comic.title), findsNothing);
    update(() {
      entry = original;
    });
    await tester.pumpAndSettle();
    expect(find.text(original.comic.title), findsOneWidget);
    expect(find.text('Updated promotion'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (routeTransition, closing) in [
    (false, false),
    (false, true),
    (true, false),
    (true, true),
  ]) {
    final motion = routeTransition ? 'route' : 'drawer';
    for (final startDuringMotion in [false, true]) {
      testWidgets('carousel paints through $motion closing=$closing, '
          'startsDuringMotion=$startDuringMotion', (tester) async {
        await tester.runAsync(HazukiLiquidGlass.initialize);
        addTearDown(() => HazukiLiquidGlass.setEnabled(false));
        final transition = AnimationController(
          vsync: tester,
          value: closing ? 1 : 0,
          duration: const Duration(milliseconds: 210),
          reverseDuration: const Duration(milliseconds: 160),
        );
        addTearDown(transition.dispose);
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              home: routeTransition
                  ? RouteTransitionSnapshot(
                      secondaryAnimation: transition,
                      child: Scaffold(
                        body: _carousel(_Images(), _Service(), _items(2)),
                      ),
                    )
                  : HomeDrawerSnapshot(
                      animation: transition,
                      child: Scaffold(
                        body: _carousel(_Images(), _Service(), _items(2)),
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pages = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        SnapshotController snapshot() => tester
            .widget<SnapshotWidget>(find.byType(SnapshotWidget))
            .controller;
        void moveCarousel() {
          unawaited(
            pages.animateToPage(
              pages.page!.round() + 1,
              duration: const Duration(milliseconds: 1000),
              curve: const DiscoverCarouselAutoPlayCurve(),
            ),
          );
        }

        if (!startDuringMotion) {
          moveCarousel();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
        }
        if (closing) {
          transition.reverse();
        } else {
          transition.forward();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        if (startDuringMotion) {
          expect(snapshot().allowSnapshotting, isTrue);
          moveCarousel();
          await tester.pump();
        }
        expect(snapshot().allowSnapshotting, isFalse);

        Future<Uint8List> raster() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          return (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              return (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;
        }

        final first = await raster();
        await tester.pump(const Duration(milliseconds: 48));
        final second = await raster();
        expect(
          listEquals(first, second),
          isFalse,
          reason:
              'the visible carousel must keep repainting, not just its controller',
        );
        expect(snapshot().allowSnapshotting, isFalse);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'website cards show placeholders while loading, then reveal images',
    (tester) async {
      final images = _Images()..delayed = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _carousel(images, _Service(), _items(1))),
        ),
      );
      await tester.pump();
      final imageFinder = find.byType(HazukiCachedImage);
      expect(imageFinder, findsWidgets);
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byKey(const ValueKey('loading-stack')),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsNothing,
      );
      images.pending.complete(images.bytes);
      await tester.pump();
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byType(AnimatedOpacity),
        ),
        findsWidgets,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final fades = tester.stateList<ImplicitlyAnimatedWidgetState>(
        find.descendant(
          of: imageFinder,
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        fades.every(
          (state) => state.animation.value > 0 && state.animation.value < 1,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byKey(const ValueKey('loading-stack')),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cached website cards are immediately visible without a reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _carousel(_Images(), _Service(), _items(1))),
      ),
    );
    final imageFinder = find.byType(HazukiCachedImage);
    expect(
      find.descendant(of: imageFinder, matching: find.byType(AnimatedOpacity)),
      findsNothing,
    );
    expect(
      find.descendant(of: imageFinder, matching: find.byType(Image)),
      findsWidgets,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: imageFinder, matching: find.byType(AnimatedOpacity)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'cached side cards and loop copies stay visible over three laps',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: _carousel(_Images(), _Service(), _items(5)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 15; step++) {
        final pages = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        unawaited(
          pages.animateToPage(
            pages.page!.round() + 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.linear,
          ),
        );
        await tester.pump();
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final images = find.byType(HazukiCachedImage);
          expect(
            find.descendant(of: images, matching: find.byType(AnimatedOpacity)),
            findsNothing,
            reason:
                'step=$step frame=$frame must not replay cached image fades',
          );
          expect(
            tester
                .widgetList<RawImage>(
                  find.descendant(of: images, matching: find.byType(RawImage)),
                )
                .every((image) => image.image != null),
            isTrue,
          );
          expect(
            find.descendant(
              of: images,
              matching: find.byKey(const ValueKey('loading-stack')),
            ),
            findsNothing,
          );
        }
        expect(
          tester
              .widget<DiscoverDailyRecommendationIndicators>(
                find.byType(DiscoverDailyRecommendationIndicators),
              )
              .currentIndex,
          (step + 1) % 5,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'author recommendations keep their existing cached image behavior',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _carousel(_Images(), _Service(pluginMode: false), _items(1)),
          ),
        ),
      );
      final imageFinder = find.byType(HazukiCachedImage);
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'refreshing a website banner shows its placeholder instead of the old image',
    (tester) async {
      final images = _Images();
      final service = _Service();
      var items = _items(1);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return _carousel(images, service, items);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      images.delayed = true;
      update(
        () => items = [
          DiscoverDailyRecommendationEntry(
            comic: items.first.comic,
            imageUrl: 'https://example.com/new-banner.png',
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      final imageFinder = find.byType(HazukiCachedImage);
      expect(
        tester
            .widgetList<HazukiCachedImage>(imageFinder)
            .every((image) => image.url.contains('new-banner')),
        isTrue,
      );
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: imageFinder,
          matching: find.byKey(const ValueKey('loading-stack')),
        ),
        findsWidgets,
      );
      images.pending.complete(images.bytes);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: imageFinder, matching: find.byType(Image)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final count in [0, 1, 2, 3, 12, 40]) {
    testWidgets(
      'carousel accepts $count website items and independent banners',
      (tester) async {
        final images = _Images();
        final service = _Service();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: _carousel(images, service, _items(count)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (count > 0) {
          final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
          expect(
            heroes.map((hero) => hero.tag).toSet(),
            hasLength(heroes.length),
          );
          expect(
            tester
                .widget<DiscoverDailyRecommendationIndicators>(
                  find.byType(DiscoverDailyRecommendationIndicators),
                )
                .count,
            count,
          );
          expect(
            tester
                .widgetList<HazukiCachedImage>(find.byType(HazukiCachedImage))
                .every((image) => image.url.contains('banner-')),
            isTrue,
          );
          expect(
            tester
                .widgetList<DiscoverDailyRecommendationCarouselCard>(
                  find.byType(DiscoverDailyRecommendationCarouselCard),
                )
                .every((card) => card.entry.comic.cover.contains('cover-')),
            isTrue,
          );
        } else {
          expect(find.byType(PageView), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'two visible website cards can refresh without waiting to scroll offscreen',
    (tester) async {
      final images = _Images();
      final service = _Service();
      when(
        () => service.promotePendingRecommendations(),
      ).thenAnswer((_) async {});
      var pending = <DiscoverDailyRecommendationEntry>[];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return _carousel(images, service, _items(2), pending: pending);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(
        () => pending = _items(2)
            .map(
              (entry) => DiscoverDailyRecommendationEntry(
                author: 'Updated picks',
                comic: entry.comic,
                imageUrl: entry.imageUrl,
              ),
            )
            .toList(),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<DiscoverDailyRecommendationCarouselCard>(
              find.byType(DiscoverDailyRecommendationCarouselCard),
            )
            .every((card) => card.entry.author == 'Updated picks'),
        isTrue,
      );
      verify(() => service.promotePendingRecommendations()).called(1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final usePending in [false, true]) {
    testWidgets(
      'count changes preserve the active card and indicator (pending=$usePending)',
      (tester) async {
        final images = _Images();
        final service = _Service();
        when(
          () => service.promotePendingRecommendations(),
        ).thenAnswer((_) async {});
        var items = _items(1);
        var pending = <DiscoverDailyRecommendationEntry>[];
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return _carousel(images, service, items, pending: pending);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        void expectActiveComic(int index) {
          final page = tester
              .widget<PageView>(find.byType(PageView))
              .controller!
              .page!
              .round();
          final activeCard = tester
              .widgetList<DiscoverDailyRecommendationCarouselCard>(
                find.byType(DiscoverDailyRecommendationCarouselCard),
              )
              .singleWhere((card) => card.physicalIndex == page);
          expect(activeCard.entry.comic.id, '$index');
          expect(
            tester
                .widget<DiscoverDailyRecommendationIndicators>(
                  find.byType(DiscoverDailyRecommendationIndicators),
                )
                .currentIndex,
            index,
          );
        }

        expectActiveComic(0);
        for (final count in [12, 3, 1, 2]) {
          final drag = count == 3
              ? await tester.startGesture(
                  tester.getCenter(find.byType(PageView)),
                )
              : null;
          if (drag != null) {
            await drag.moveBy(const Offset(-40, 0));
            await tester.pump();
          }
          update(() {
            if (usePending) {
              pending = _items(count);
            } else {
              items = _items(count);
            }
          });
          await tester.pumpAndSettle();
          await drag?.up();
          await tester.pumpAndSettle();
          expectActiveComic(count == 3 ? 2 : 0);
          if (usePending) {
            update(() {
              items = pending;
              pending = [];
            });
            await tester.pumpAndSettle();
          }
          if (count == 12) {
            tester
                .widget<PageView>(find.byType(PageView))
                .controller!
                .jumpToPage(10);
            await tester.pumpAndSettle();
            expectActiveComic(8);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expectActiveComic(1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'pending lists may grow and shrink across loop and single-card modes',
    (tester) async {
      final images = _Images();
      final service = _Service();
      when(
        () => service.promotePendingRecommendations(),
      ).thenAnswer((_) async {});
      var items = _items(1);
      var pending = <DiscoverDailyRecommendationEntry>[];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return _carousel(images, service, items, pending: pending);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final count in [12, 3, 1]) {
        update(() => pending = _items(count));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DiscoverDailyRecommendationIndicators>(
                find.byType(DiscoverDailyRecommendationIndicators),
              )
              .count,
          count,
        );
        expect(tester.takeException(), isNull);
        update(() {
          items = pending;
          pending = [];
        });
        await tester.pumpAndSettle();
      }
      verify(() => service.promotePendingRecommendations()).called(3);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
