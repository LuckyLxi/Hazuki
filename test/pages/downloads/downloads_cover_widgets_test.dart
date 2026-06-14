import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  group('DownloadedComicCover', () {
    testWidgets('does not load network cover when no local path is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterialApp(
          DownloadedComicCover(
            comic: _comic(
              localCoverPath: '   ',
              coverUrl: 'https://example.com/cover.jpg',
            ),
          ),
        ),
      );

      expect(find.byType(HazukiCachedImage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('downloaded_cover_placeholder')),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows fallback icon when local path is set but file is missing',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(
            DownloadedComicCover(
              comic: _comic(localCoverPath: 'Z:/missing-cover.png'),
            ),
          ),
        );

        expect(find.byType(HazukiCachedImage), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('downloaded_cover_placeholder')),
          findsOneWidget,
        );
      },
    );

    testWidgets('wraps content with hero and handles taps', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          DownloadedComicCover(
            comic: _comic(coverUrl: 'https://example.com/cover.jpg'),
            heroTag: 'download-cover-hero',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(Hero), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('DownloadedComicCoverPreviewPage', () {
    testWidgets('shows bundled placeholder when cover is unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithMaterialApp(
          DownloadedComicCoverPreviewPage(
            comic: _comic(localCoverPath: null, coverUrl: '   '),
            heroTag: 'preview-hero',
          ),
        ),
      );

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('downloaded_cover_preview_placeholder'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the full preview area as the zoom canvas', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadedComicCoverPreviewPage(
            comic: _comic(localCoverPath: null, coverUrl: '   '),
            heroTag: 'preview-hero',
          ),
        ),
      );

      final viewerFinder = find.byKey(
        const ValueKey<String>('downloaded_cover_viewer'),
      );
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final viewerSize = tester.getSize(viewerFinder);

      expect(viewer.clipBehavior, Clip.none);
      expect(viewer.boundaryMargin, EdgeInsets.zero);
      expect(viewerSize.width, greaterThan(700));
      expect(viewerSize.height, greaterThan(500));
    });

    testWidgets('keeps the cover fixed while it is not zoomed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadedComicCoverPreviewPage(
            comic: _comic(localCoverPath: null, coverUrl: '   '),
            heroTag: 'preview-hero',
          ),
        ),
      );

      final coverFinder = find.byKey(
        const ValueKey<String>('downloaded_cover_preview_placeholder'),
      );
      final originalCenter = tester.getCenter(coverFinder);

      await tester.drag(coverFinder, const Offset(140, 100));
      await tester.pumpAndSettle();

      final draggedCenter = tester.getCenter(coverFinder);
      expect(draggedCenter.dx, closeTo(originalCenter.dx, 0.01));
      expect(draggedCenter.dy, closeTo(originalCenter.dy, 0.01));
    });

    testWidgets('tapping preview pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DownloadedComicCoverPreviewPage(
                            comic: _comic(localCoverPath: null, coverUrl: ''),
                            heroTag: 'preview-hero',
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadedComicCoverPreviewPage), findsOneWidget);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.byType(DownloadedComicCoverPreviewPage), findsNothing);
    });
  });
}

Widget _wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

DownloadedMangaComic _comic({String? localCoverPath, String coverUrl = ''}) {
  return DownloadedMangaComic(
    comicId: 'comic-1',
    title: 'Test Comic',
    subTitle: 'Subtitle',
    description: 'Description',
    coverUrl: coverUrl,
    localCoverPath: localCoverPath,
    chapters: const [],
    updatedAtMillis: 0,
  );
}
