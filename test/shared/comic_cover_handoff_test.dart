import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_cover.dart';
import 'package:hazuki/features/discover/view/discover_daily_recommendation_carousel_widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/images/comic_cover_handoff.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

const _bannerUrl = 'https://example.test/banner.png';
const _coverUrl = 'https://example.test/cover.png';
const _heroTag = 'comic-cover-discover-daily-test';

class _Images extends Fake implements SourceImageGateway {
  var cover = Completer<Uint8List>();
  final requests = <String>[];
  Uint8List? cachedCover;

  @override
  String get activeSourceKey => 'website';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      url == _coverUrl ? cachedCover : null;

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) {
    requests.add('$sourceKey|$url');
    return cover.future;
  }
}

class _Artwork {
  _Artwork(this.bytes, this.image);
  final Uint8List bytes;
  final ui.Image image;

  Future<void> seed({
    int? width,
    int? height,
    Future<ImageInfo>? decoded,
  }) async {
    final provider = ResizeImage.resizeIfNeeded(
      width,
      height,
      MemoryImage(bytes),
    );
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        decoded ?? Future.value(ImageInfo(image: image.clone())),
      ),
    );
  }
}

Future<_Artwork> _artwork(WidgetTester tester, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(2, 2);
  picture.dispose();
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  addTearDown(image.dispose);
  return _Artwork(data!.buffer.asUint8List(), image);
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final screenshot = GlobalKey();
  final images = _Images();
  final bannerController = HazukiCachedImageController();
  late _Artwork banner;
  late _Artwork cover;
  late ComicCoverHandoff handoff;
  late StateSetter updateDetail;
  String coverUrl = _coverUrl;
  Completer<ImageInfo>? decodedCover;
  bool animateBanner = false;
  bool useProductionRoute = false;
  bool seedDecodedCover = true;
  bool retainBannerFrame = false;
  bool clearCachesBeforePush = false;
  late PageRoute<void> detailRoute;

  Future<void> open(WidgetTester tester, {bool cached = false}) async {
    addTearDown(bannerController.dispose);
    banner = await _artwork(tester, const Color(0xFFFF0000));
    cover = await _artwork(tester, const Color(0xFF0000FF));
    await banner.seed(width: 300);
    if (seedDecodedCover) {
      await cover.seed(width: 135, height: 190, decoded: decodedCover?.future);
    }
    if (cached) images.cachedCover = cover.bytes;
    putHazukiWidgetImageMemory(_bannerUrl, banner.bytes, sourceKey: 'website');
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshot,
        child: SourceImageGatewayScope(
          gateway: images,
          child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 213,
                  child: animateBanner
                      ? DiscoverDailyRecommendationCarouselCard(
                          physicalIndex: 0,
                          entry: const DiscoverDailyRecommendationEntry(
                            comic: ExploreComic(
                              id: 'test',
                              title: '',
                              subTitle: '',
                              cover: '',
                              sourceKey: 'website',
                            ),
                            imageUrl: _bannerUrl,
                          ),
                          heroTag: _heroTag,
                          heroCardWidth: 300,
                          heroCardHeight: 213,
                          clippedWidth: 300,
                          outerTranslateX: 0,
                          imageTranslateX: 0,
                          cardScale: 1,
                          cardOpacity: 1,
                          hideOverlay: true,
                          imageChild: HazukiCachedImage(
                            url: _bannerUrl,
                            sourceKey: 'website',
                            cacheWidth: 300,
                            fit: BoxFit.cover,
                            waitForFirstFrame: true,
                            animateOnLoad: true,
                            animateOnCacheHit: true,
                            controller: retainBannerFrame
                                ? bannerController
                                : null,
                            loading: ColoredBox(color: Colors.grey),
                            error: ColoredBox(color: Colors.grey),
                          ),
                          onTap: () {},
                        )
                      : Hero(
                          tag: _heroTag,
                          flightShuttleBuilder:
                              buildComicCoverHeroFlightShuttle,
                          placeholderBuilder: buildComicCoverHeroPlaceholder,
                          child: ComicCoverHeroImage(
                            image: const HazukiCachedImage(
                              url: _bannerUrl,
                              sourceKey: 'website',
                              cacheWidth: 300,
                              fit: BoxFit.cover,
                            ),
                            child: HazukiCachedImage(
                              url: _bannerUrl,
                              sourceKey: 'website',
                              cacheWidth: 300,
                              fit: BoxFit.cover,
                              controller: retainBannerFrame
                                  ? bannerController
                                  : null,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pushDetail(tester);
  }

  Future<void> pushDetail(WidgetTester tester) async {
    if (clearCachesBeforePush) {
      clearHazukiWidgetImageMemoryForTesting();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    handoff = ComicCoverHandoff(
      heroTag: _heroTag,
      url: _bannerUrl,
      sourceKey: 'website',
      bytes:
          bannerController.bytesFor(_bannerUrl, sourceKey: 'website') ??
          banner.bytes,
      cacheWidth: 300,
      decodedBanner: retainBannerFrame
          ? bannerController.frameFor(_bannerUrl, sourceKey: 'website')
          : null,
    );
    final routeHandoff = handoff;
    addTearDown(routeHandoff.dispose);
    Widget buildDetail(BuildContext context) => ComicCoverHandoffScope(
      handoff: handoff,
      child: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (_, setState) {
              updateDetail = setState;
              return ComicDetailHeaderCover(
                heroTag: _heroTag,
                displayCoverUrl: coverUrl,
                sourceKey: 'website',
                skeletonColor: Colors.grey,
                headerCoverCacheWidth: 135,
                headerCoverCacheHeight: 190,
                coverBorderRadius: 28,
                onTap: null,
              );
            },
          ),
        ),
      ),
    );
    detailRoute = useProductionRoute
        ? buildSnapshottingPageRoute<void>(
                allowSnapshotting: false,
                builder: buildDetail,
              )
              as PageRoute<void>
        : PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, _, _) => buildDetail(context),
          );
    unawaited(navigator.currentState!.push<void>(detailRoute));
    unawaited(detailRoute.completed.then((_) => routeHandoff.dispose()));
    await tester.pump();
    await tester.pump();
  }

  Future<Color> pixel(WidgetTester tester) async {
    final boundary =
        screenshot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData())!;
        final offset =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        return Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  }

  Future<void> completeUncachedCover(WidgetTester tester) async {
    images.cover.complete(cover.bytes);
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      // Use the real PNG decoder without advancing the animation clock or
      // substituting a pre-seeded frame.
      final stream = ResizeImage.resizeIfNeeded(
        135,
        190,
        MemoryImage(cover.bytes),
      ).resolve(ImageConfiguration.empty);
      final decoded = Completer<void>();
      final listener = ImageStreamListener(
        (info, _) {
          info.dispose();
          if (!decoded.isCompleted) decoded.complete();
        },
        onError: (Object error, StackTrace? stack) {
          if (!decoded.isCompleted) decoded.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      try {
        await decoded.future;
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  setUp(() {
    clearHazukiWidgetImageMemoryForTesting();
    PaintingBinding.instance.imageCache.clear();
    hazukiNoImageModeNotifier.value = false;
  });
  tearDown(() => hazukiNoImageModeNotifier.value = false);

  testWidgets('five cold detail visits keep crossfading with evicted caches', (
    tester,
  ) async {
    final harness = _Harness()
      ..animateBanner = true
      ..useProductionRoute = true
      ..seedDecodedCover = false
      ..retainBannerFrame = true
      ..clearCachesBeforePush = true
      ..coverUrl = '';
    await harness.open(tester);
    for (var visit = 0; visit < 5; visit++) {
      if (visit > 0) {
        harness.cover = await _artwork(tester, const Color(0xFF0000FF));
        harness.images.cover = Completer<Uint8List>();
        harness.coverUrl = '';
        await harness.pushDetail(tester);
      }
      expect(harness.handoff.hasDecodedBanner, isTrue);
      expect(
        peekHazukiWidgetImageMemory(_bannerUrl, sourceKey: 'website'),
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 100));
      harness.updateDetail(
        () => harness.coverUrl = 'https://example.test/cold-cover-$visit.png',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 410));
      await tester.pump();
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      await harness.completeUncachedCover(tester);
      await tester.pump(const Duration(milliseconds: 110));
      final blended = await harness.pixel(tester);
      expect(
        blended.r,
        greaterThan(0),
        reason: 'visit $visit keeps banner under cover',
      );
      expect(blended.b, greaterThan(0), reason: 'visit $visit fades cover in');
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFF0000FF));
      harness.navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final returning = await harness.pixel(tester);
      expect(returning.r, greaterThan(0));
      expect(returning.b, greaterThan(0));
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      expect(harness.handoff.hasDecodedBanner, isFalse);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final coverState in ['missing', 'loaded', 'failed']) {
    testWidgets('invalid banner falls back safely with $coverState cover', (
      tester,
    ) async {
      final images = _Images();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final decodedBanner = Completer<ImageInfo>.sync();
      final bannerProvider = ResizeImage.resizeIfNeeded(
        300,
        null,
        MemoryImage(bytes),
      );
      final bannerKey = await bannerProvider.obtainKey(
        ImageConfiguration.empty,
      );
      PaintingBinding.instance.imageCache.putIfAbsent(
        bannerKey,
        () => OneFrameImageStreamCompleter(decodedBanner.future),
      );
      final handoff = ComicCoverHandoff(
        heroTag: _heroTag,
        url: _bannerUrl,
        sourceKey: 'website',
        bytes: bytes,
        cacheWidth: 300,
      );
      await tester.pumpWidget(
        SourceImageGatewayScope(
          gateway: images,
          child: MaterialApp(
            home: Center(
              child: SizedBox(
                width: 135,
                height: 190,
                child: ComicCoverHandoffImage(
                  handoff: handoff,
                  coverUrl: coverState == 'missing' ? '' : _coverUrl,
                  cacheWidth: 135,
                  cacheHeight: 190,
                ),
              ),
            ),
          ),
        ),
      );
      decodedBanner.completeError(StateError('invalid banner'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(
        tester.getSize(find.byType(ComicCoverHandoffImage)),
        const Size(135, 190),
      );
      expect(handoff.coverRevealed, isFalse);

      if (coverState == 'loaded') {
        final cover = await _artwork(tester, Colors.blue);
        await cover.seed(width: 135, height: 190);
        images.cover.complete(cover.bytes);
        await tester.pumpAndSettle();
        expect(handoff.coverRevealed, isTrue);
        expect(find.byType(RawImage), findsOneWidget);
      } else if (coverState == 'failed') {
        images.cover.completeError(StateError('cover unavailable'));
        await tester.pumpAndSettle();
        expect(handoff.coverRevealed, isFalse);
        expect(find.byType(RawImage), findsNothing);
      } else {
        expect(images.requests, isEmpty);
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final arrivesDuringFlight in [false, true]) {
    testWidgets(
      'production route with cold detail cover, during flight=$arrivesDuringFlight',
      (tester) async {
        final harness = _Harness()
          ..animateBanner = true
          ..useProductionRoute = true
          ..seedDecodedCover = false
          ..coverUrl = '';
        await harness.open(tester);
        await tester.pump(const Duration(milliseconds: 100));
        harness.updateDetail(() => harness.coverUrl = _coverUrl);
        await tester.pump();
        if (arrivesDuringFlight) {
          await harness.completeUncachedCover(tester);
        }
        await tester.pump(const Duration(milliseconds: 410));
        await tester.pump();
        expect(await harness.pixel(tester), const Color(0xFFFF0000));
        if (!arrivesDuringFlight) {
          await harness.completeUncachedCover(tester);
        }
        await tester.pump(const Duration(milliseconds: 110));
        final blended = await harness.pixel(tester);
        expect(blended.r, greaterThan(0));
        expect(blended.b, greaterThan(0));
        await tester.pumpAndSettle();
        expect(await harness.pixel(tester), const Color(0xFF0000FF));
        harness.navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(harness.detailRoute.reverseTransitionDuration);
        for (var frame = 0; frame < 18; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(await harness.pixel(tester), const Color(0xFFFF0000));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('offstage route measurement cannot release the cover reveal', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester, cached: true);
    await tester.pump(const Duration(milliseconds: 100));
    harness.detailRoute.offstage = true;
    await tester.pump();
    harness.detailRoute.offstage = false;
    await tester.pump();
    final image = tester.widget<HazukiCachedImage>(
      find.byWidgetPredicate(
        (widget) => widget is HazukiCachedImage && widget.url == _coverUrl,
        skipOffstage: false,
      ),
    );
    expect(image.revealEnabled, isFalse);
    expect(harness.handoff.coverRevealed, isFalse);
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFF0000FF));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'cached cover waits for Hero landing, then blends with the banner',
    (tester) async {
      final harness = _Harness();
      await harness.open(tester, cached: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      await tester.pump(const Duration(milliseconds: 110));
      final blended = await harness.pixel(tester);
      expect(blended.r, greaterThan(0));
      expect(blended.b, greaterThan(0));
      expect(blended.g, 0);
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFF0000FF));
      expect(harness.handoff.coverRevealed, isTrue);
      expect(harness.images.requests, isEmpty);

      harness.navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final returning = await harness.pixel(tester);
      expect(returning.r, greaterThan(0));
      expect(returning.b, greaterThan(0));
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('slow cover leaves the banner visible after Hero landing', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester);
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    expect(harness.handoff.coverRevealed, isFalse);
    expect(harness.images.requests.toSet(), {'website|$_coverUrl'});
    harness.images.cover.complete(harness.cover.bytes);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    await tester.pump(const Duration(milliseconds: 110));
    final blended = await harness.pixel(tester);
    expect(blended.r, greaterThan(0));
    expect(blended.b, greaterThan(0));
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFF0000FF));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed cover keeps the banner and can return before loading', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester);
    await tester.pumpAndSettle();
    harness.images.cover.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    harness.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing cover retains banner until detail supplies the URL', (
    tester,
  ) async {
    final harness = _Harness()..coverUrl = '';
    await harness.open(tester);
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    expect(harness.images.requests, isEmpty);
    harness.updateDetail(() => harness.coverUrl = _coverUrl);
    await tester.pump();
    await tester.pump();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    harness.images.cover.complete(harness.cover.bytes);
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFF0000FF));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no-image mode hides retained banner and cover', (tester) async {
    final harness = _Harness();
    await harness.open(tester);
    await tester.pumpAndSettle();
    hazukiNoImageModeNotifier.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(harness.handoff.coverRevealed, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final failDecoding in [false, true]) {
    testWidgets(
      failDecoding
          ? 'decode failure keeps banner after bytes arrive'
          : 'received cover bytes do not replace banner before decoding',
      (tester) async {
        final harness = _Harness()..decodedCover = Completer<ImageInfo>();
        await harness.open(tester, cached: true);
        await tester.pumpAndSettle();
        expect(await harness.pixel(tester), const Color(0xFFFF0000));
        expect(harness.handoff.coverRevealed, isFalse);
        if (failDecoding) {
          harness.decodedCover!.completeError(StateError('invalid image'));
          await tester.pumpAndSettle();
          expect(await harness.pixel(tester), const Color(0xFFFF0000));
          expect(harness.handoff.coverRevealed, isFalse);
        } else {
          harness.decodedCover!.complete(
            ImageInfo(image: harness.cover.image.clone()),
          );
          await tester.pump();
          await tester.pump();
          expect(await harness.pixel(tester), const Color(0xFFFF0000));
          await tester.pumpAndSettle();
          expect(await harness.pixel(tester), const Color(0xFF0000FF));
          expect(harness.handoff.coverRevealed, isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('late image completion cannot update a closed detail', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester);
    await tester.pumpAndSettle();
    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    harness.images.cover.complete(harness.cover.bytes);
    await tester.pumpAndSettle();
    expect(await harness.pixel(tester), const Color(0xFFFF0000));
    expect(harness.handoff.coverRevealed, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'returning to an animated carousel does not replay image reveal',
    (tester) async {
      final harness = _Harness()..animateBanner = true;
      await harness.open(tester, cached: true);
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFF0000FF));
      harness.navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var frame = 0; frame < 18; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          await harness.pixel(tester),
          const Color(0xFFFF0000),
          reason:
              'carousel must retain its fully revealed banner at frame $frame',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cover resolved during Hero flight starts its fade after landing',
    (tester) async {
      final harness = _Harness()..coverUrl = '';
      await harness.open(tester);
      await tester.pump(const Duration(milliseconds: 100));
      harness.updateDetail(() => harness.coverUrl = _coverUrl);
      harness.images.cover.complete(harness.cover.bytes);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final image = tester.widget<HazukiCachedImage>(
        find.byWidgetPredicate(
          (widget) => widget is HazukiCachedImage && widget.url == _coverUrl,
          skipOffstage: false,
        ),
      );
      expect(image.revealEnabled, isFalse);
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      expect(await harness.pixel(tester), const Color(0xFFFF0000));
      await tester.pump(const Duration(milliseconds: 110));
      final blended = await harness.pixel(tester);
      expect(blended.r, greaterThan(0));
      expect(blended.b, greaterThan(0));
      await tester.pumpAndSettle();
      expect(await harness.pixel(tester), const Color(0xFF0000FF));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
