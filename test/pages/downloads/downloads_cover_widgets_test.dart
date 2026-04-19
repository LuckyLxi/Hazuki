import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/pages/downloads/downloads_cover_widgets.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadedComicCover', () {
    testWidgets('renders network cover when no local path is provided', (
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

      expect(find.byType(HazukiCachedImage), findsOneWidget);
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
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
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
    testWidgets('shows broken image placeholder when cover is unavailable', (
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
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
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
