import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
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

void main() {
  test('feature-first entry widgets are constructible from public paths', () {
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
    );
    const comic = ExploreComic(
      id: 'comic-id',
      title: 'Hazuki',
      subTitle: 'Smoke',
      cover: '',
    );
    final detail = const ComicDetailPage(comic: comic, heroTag: 'hero');
    final search = SearchPage(
      initialKeyword: comic.title,
      comicDetailPageBuilder: (comic, heroTag) =>
          ComicDetailPage(comic: comic, heroTag: heroTag),
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
      comicDetailPageBuilder: (comic, heroTag) =>
          ComicDetailPage(comic: comic, heroTag: heroTag),
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
    );

    expect(home.initialTabIndex, 1);
    expect(detail.comic, comic);
    expect(detail.heroTag, 'hero');
    expect(search.initialKeyword, comic.title);
    expect(favorite.authVersion, 1);
    expect(comments.comicId, 'comic-id');
    expect(downloads.readerPageBuilder, isNotNull);
    expect(history.comicCoverHeroTagBuilder(comic), comicCoverHeroTag(comic));
    expect(settings.appearanceSettings.themeMode, ThemeMode.system);
    expect(reader.images, const ['a', 'b']);
    expect(reader.chapterIndex, 0);
  });
}
