import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_cover.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureTestServiceLocator();
  });

  testWidgets('cover preview uses the full page as its zoom canvas', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapPreview());

    final viewerFinder = find.byKey(
      const ValueKey<String>('comic_cover_viewer'),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final viewerSize = tester.getSize(viewerFinder);

    expect(viewer.clipBehavior, Clip.none);
    expect(viewer.boundaryMargin, EdgeInsets.zero);
    expect(viewerSize.width, greaterThan(700));
    expect(viewerSize.height, greaterThan(500));
  });

  testWidgets('cover preview stays fixed while it is not zoomed', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapPreview());

    final coverFinder = find.byIcon(Icons.broken_image_outlined);
    final originalCenter = tester.getCenter(coverFinder);

    await tester.drag(coverFinder, const Offset(140, 100));
    await tester.pumpAndSettle();

    final draggedCenter = tester.getCenter(coverFinder);
    expect(draggedCenter.dx, closeTo(originalCenter.dx, 0.01));
    expect(draggedCenter.dy, closeTo(originalCenter.dy, 0.01));
  });

  testWidgets('cover preview keeps its long press action', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(
      _wrapPreview(onLongPress: () => longPressed = true),
    );

    await tester.longPress(find.byIcon(Icons.broken_image_outlined));

    expect(longPressed, isTrue);
  });

  testWidgets('restored cached background is visible on its first frame', (
    tester,
  ) async {
    const url = 'https://example.test/restored-background.png';
    final gateway = _CoverImageGateway();

    await tester.pumpWidget(
      _wrapBackground(gateway: gateway, url: url, key: const ValueKey('seed')),
    );
    await tester.pumpAndSettle();
    expect(gateway.downloadCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _wrapBackground(
        gateway: gateway,
        url: url,
        key: const ValueKey('normal-cache-hit'),
      ),
    );
    final backgroundOpacity = find.byKey(
      const ValueKey('static-cover-blur-$url'),
    );
    expect(tester.widget<AnimatedOpacity>(backgroundOpacity).opacity, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _wrapBackground(
        gateway: gateway,
        url: url,
        key: const ValueKey('restored-cache-hit'),
        showCachedCoverImmediately: true,
      ),
    );
    expect(tester.widget<AnimatedOpacity>(backgroundOpacity).opacity, 1);
    expect(gateway.downloadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routed background fades in and reuses the cover on reentry', (
    tester,
  ) async {
    const url = 'https://example.test/routed-background.png';
    final gateway = _CoverImageGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                buildSnapshottingPageRoute<void>(
                  allowSnapshotting: false,
                  builder: (_) => Scaffold(
                    body: ComicBlurredCoverBackground(
                      coverUrl: url,
                      sourceKey: 'copy_manga',
                      imageGateway: gateway,
                    ),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );

    final background = find.byKey(const ValueKey('static-cover-blur-$url'));
    void expectLiveBackground() {
      final snapshots = find.ancestor(
        of: background,
        matching: find.byType(SnapshotWidget),
      );
      // The route keeps a snapshot wrapper for secondary transitions, but
      // must leave the background live during its own entrance and exit.
      expect(snapshots, findsWidgets);
      for (final snapshot in tester.widgetList<SnapshotWidget>(snapshots)) {
        expect(snapshot.controller.allowSnapshotting, isFalse);
      }
    }

    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.text('Open detail'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final route = ModalRoute.of(tester.element(background))!;
      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect((route as PageRoute<void>).allowSnapshotting, isFalse);
      expectLiveBackground();
      await tester.pump(const Duration(milliseconds: 160));
      expectLiveBackground();
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: background, matching: find.byType(FadeTransition)),
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      expect(route.animation!.isCompleted, isFalse);
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(gateway.downloadCount, 1);
      Navigator.of(tester.element(background)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expectLiveBackground();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

Widget _wrapPreview({VoidCallback? onLongPress}) {
  return SourceImageGatewayScope(
    gateway: sl<SourceImageGateway>(),
    child: MaterialApp(
      home: ComicCoverPreviewPage(
        imageUrl: '',
        sourceKey: '',
        heroTag: 'preview-hero',
        onLongPress: onLongPress ?? () {},
      ),
    ),
  );
}

Widget _wrapBackground({
  required SourceImageGateway gateway,
  required String url,
  required Key key,
  bool showCachedCoverImmediately = false,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: SizedBox.expand(
      child: ComicBlurredCoverBackground(
        key: key,
        coverUrl: url,
        sourceKey: 'copy_manga',
        imageGateway: gateway,
        showCachedCoverImmediately: showCachedCoverImmediately,
      ),
    ),
  );
}

class _CoverImageGateway implements SourceImageGateway {
  static final Uint8List _imageBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  int downloadCount = 0;

  @override
  String get activeSourceKey => 'copy_manga';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      null;

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    downloadCount += 1;
    return _imageBytes;
  }
}
