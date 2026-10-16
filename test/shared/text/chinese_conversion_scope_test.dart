import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_expandable_description.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/features/comments/view/comments_widgets.dart';
import 'package:hazuki/features/downloads/view/downloaded_comic_detail_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/comic_cover_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ChineseConversionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ChineseConversionService();
  });

  tearDown(() => service.dispose());

  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ChineseConversionScope(
      service: service,
      child: Scaffold(body: child),
    ),
  );

  testWidgets(
    'updates titles, both descriptions and comments without changing source data',
    (tester) async {
      const comic = ExploreComic(
        id: 'test',
        title: '漫畫標題',
        subTitle: '作者名稱',
        cover: '',
      );
      await tester.pumpWidget(
        app(
          ListView(
            children: [
              SizedBox(
                height: 150,
                child: ComicCoverTile(
                  comic: comic,
                  heroTag: 'test',
                  coverCacheWidth: 100,
                  placeholderColor: Colors.grey,
                  onTap: () async {},
                ),
              ),
              const ComicDetailExpandableDescription(text: '漫畫簡介'),
              const DownloadedComicExpandableDescription(text: '離線簡介'),
              const CommentsSelectableContent(
                content: '評論內容',
                style: TextStyle(fontSize: 14),
                expansionKey: 'comment',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('漫畫標題'), findsOneWidget);

      await tester.runAsync(
        () => service.setMode(ChineseConversionMode.simplified),
      );
      await tester.pumpAndSettle();
      expect(find.text('漫画标题'), findsOneWidget);
      expect(find.text('漫画简介'), findsOneWidget);
      expect(find.text('离线简介'), findsOneWidget);
      expect(find.text('评论内容', findRichText: true), findsOneWidget);
      expect(find.text('作者名稱'), findsOneWidget);
      expect(comic.title, '漫畫標題');

      await service.setMode(ChineseConversionMode.off);
      await tester.pumpAndSettle();
      expect(find.text('漫畫標題'), findsOneWidget);
      expect(find.text('漫畫簡介'), findsOneWidget);
      expect(find.text('離線簡介'), findsOneWidget);
      expect(find.text('評論內容', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'converts decoded comment text and preserves inline image URLs and filter input',
    (tester) async {
      const content =
          '&#x6F22;字<img src="https://example.test/圖片.png" alt="圖片">評論';
      await tester.runAsync(
        () => service.setMode(ChineseConversionMode.simplified),
      );
      late List<InlineSpan> spans;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              spans = buildCommentContentSpans(context, content, null);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect((spans.first as TextSpan).text, '汉字');
      expect((spans.last as TextSpan).text, '评论');
      final image = spans.whereType<WidgetSpan>().single;
      final padding = image.child as Padding;
      expect(
        (padding.child as HazukiCachedImage).url,
        'https://example.test/圖片.png',
      );
      expect(commentFilterText(content), '漢字圖片評論');
    },
  );
}
