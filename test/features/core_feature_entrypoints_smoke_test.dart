import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/app/home/home_feature_entrypoints.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/comments/comments.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/features/favorite/view/favorite_page.dart';
import 'package:hazuki/features/history/history.dart';
import 'package:hazuki/features/home/view/home_page.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/features/settings/settings.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/navigation_tags.dart';

Widget _buildComments({
  required String comicId,
  String? subId,
  required String sourceKey,
  ScrollController? scrollController,
  Future<void> Function()? onRequestTabFullscreen,
  bool showAppBar = false,
  bool isTabView = false,
  bool isActiveInTabView = true,
  Map<String, Object?> Function()? debugOuterScrollStateBuilder,
}) {
  return const SizedBox.shrink();
}

final ReaderCommentsWidgetBuilder _buildReaderComments =
    readerCommentsWidgetBuilderFrom(_buildComments);

void main() {
  test('feature-first entry widgets are constructible from public paths', () {
    registerServices();
    final homeFeatureEntrypoints = buildHazukiHomeFeatureEntrypoints();
    final home = HazukiHomePage(
      initialTabIndex: 1,
      appearanceSettings: const AppearanceSettingsData(
        themeMode: ThemeMode.system,
        oledPureBlack: false,
        dynamicColor: false,
        presetIndex: hazukiDefaultAppearancePresetIndex,
        displayModeRaw: 'system',
        comicDetailDynamicColor: false,
        useSystemFont: true,
      ),
      onAppearanceChanged: (_, {revealOrigin}) async {},
      locale: const Locale('en'),
      onLocaleChanged: (_) async {},
      featureEntrypoints: homeFeatureEntrypoints,
      services: buildHazukiHomeServices(),
    );
    const comic = ExploreComic(
      id: 'comic-id',
      title: 'Hazuki',
      subTitle: 'Smoke',
      cover: '',
    );
    final detail = ComicDetailPage(
      comic: comic,
      heroTag: 'hero',
      readerWidgetBuilder:
          ({
            required title,
            required chapterTitle,
            required comicId,
            required epId,
            required chapterIndex,
            required images,
            required sourceKey,
            comicTheme,
            onFavoriteRequested,
          }) => ReaderPage(
            title: title,
            chapterTitle: chapterTitle,
            comicId: comicId,
            epId: epId,
            chapterIndex: chapterIndex,
            images: images,
            sourceKey: sourceKey,
            commentsWidgetBuilder: _buildReaderComments,
          ),
      searchPageBuilder: (_) => const SizedBox.shrink(),
      commentsWidgetBuilder: _buildComments,
    );
    Widget buildDetail(ExploreComic comic, String heroTag) => ComicDetailPage(
      comic: comic,
      heroTag: heroTag,
      readerWidgetBuilder:
          ({
            required title,
            required chapterTitle,
            required comicId,
            required epId,
            required chapterIndex,
            required images,
            required sourceKey,
            comicTheme,
            onFavoriteRequested,
          }) => ReaderPage(
            title: title,
            chapterTitle: chapterTitle,
            comicId: comicId,
            epId: epId,
            chapterIndex: chapterIndex,
            images: images,
            sourceKey: sourceKey,
            commentsWidgetBuilder: _buildReaderComments,
          ),
      searchPageBuilder: (_) => const SizedBox.shrink(),
      commentsWidgetBuilder: _buildComments,
    );
    final search = SearchPage(
      initialKeyword: comic.title,
      comicDetailPageBuilder: buildDetail,
    );
    final favorite = FavoritePage(
      authVersion: 1,
      onComicTap: (comic, heroTag) async {},
    );
    final comments = const CommentsPage(comicId: 'comic-id');
    final downloads = DownloadsPage(
      readerPageBuilder: (comic, chapter) => const SizedBox.shrink(),
    );
    final history = HistoryPage(
      comicDetailPageBuilder: buildDetail,
      onFavoriteRequested: (_, _) async {},
    );
    final settings = SettingsPage(
      appearanceSettings: const AppearanceSettingsData(
        themeMode: ThemeMode.system,
        oledPureBlack: false,
        dynamicColor: false,
        presetIndex: hazukiDefaultAppearancePresetIndex,
        displayModeRaw: 'system',
        comicDetailDynamicColor: false,
        useSystemFont: true,
      ),
      onAppearanceChanged: (_, {revealOrigin}) async {},
      locale: const Locale('en'),
      onLocaleChanged: (_) async {},
      cloudSyncPageBuilder: (_) => const CloudSyncPage(),
      labSettingsPageBuilder: (_) => const LabSettingsPage(),
      advancedSettingsPageBuilder: (_) => AdvancedSettingsPage(
        logsPageBuilder: (_) => const LogsPage(),
        comicSourceEditorPageBuilder: (_) => const ComicSourceEditorPage(),
        restoreComicSource: (_) async => false,
      ),
    );
    final reader = ReaderPage(
      title: 'Hazuki',
      chapterTitle: 'Chapter 1',
      comicId: 'comic-id',
      epId: 'ep-id',
      chapterIndex: 0,
      images: const ['a', 'b'],
      comicTheme: ThemeData.light(),
      commentsWidgetBuilder: _buildReaderComments,
    );

    expect(home.initialTabIndex, 1);
    expect(detail.comic, comic);
    expect(detail.heroTag, 'hero');
    expect(search.initialKeyword, comic.title);
    expect(favorite.authVersion, 1);
    expect(comments.comicId, 'comic-id');
    expect(downloads.readerPageBuilder, isNotNull);
    expect(history.comicCoverHeroTagBuilder(comic), comicCoverHeroTag(comic));
    expect(
      comicCoverHeroTag(
        const ExploreComic(
          id: 'same-id',
          title: 'JM',
          subTitle: '',
          cover: '',
          sourceKey: 'jm',
        ),
        salt: 'history',
      ),
      isNot(
        comicCoverHeroTag(
          const ExploreComic(
            id: 'same-id',
            title: 'Copy',
            subTitle: '',
            cover: '',
            sourceKey: 'copy_manga',
          ),
          salt: 'history',
        ),
      ),
    );
    expect(settings.appearanceSettings.themeMode, ThemeMode.system);
    expect(reader.images, const ['a', 'b']);
    expect(reader.chapterIndex, 0);
  });
}
