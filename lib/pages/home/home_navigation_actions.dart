import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/hazuki_models.dart';
import '../comic_detail_page.dart';
import '../downloads_page.dart';
import '../history_page.dart';
import '../ranking_page.dart';
import '../reader_page.dart';
import '../search/search.dart';
import '../settings/settings.dart';
import '../tag_category_page.dart';

class HomeNavigationActions {
  const HomeNavigationActions({
    required this.context,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final BuildContext context;
  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;

  Widget buildComicDetailPage(ExploreComic comic, String heroTag) {
    return ComicDetailPage(comic: comic, heroTag: heroTag);
  }

  MaterialPageRoute<void> buildFavoriteDetailRoute(
    ExploreComic comic,
    String heroTag,
  ) {
    return MaterialPageRoute<void>(
      builder: (_) => ComicDetailPage(comic: comic, heroTag: heroTag),
    );
  }

  SearchPage buildSearchPage({String? initialKeyword}) {
    return SearchPage(
      initialKeyword: initialKeyword,
      comicDetailPageBuilder: buildComicDetailPage,
    );
  }

  Future<void> openSearch() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => buildSearchPage()));
  }

  Future<void> openHistory() async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HistoryPage(comicDetailPageBuilder: buildComicDetailPage),
      ),
    );
  }

  Future<void> openCategories() async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TagCategoryPage(
          searchPageBuilder: (tag) => buildSearchPage(initialKeyword: tag),
        ),
      ),
    );
  }

  Future<void> openRanking() async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RankingPage(comicDetailPageBuilder: buildComicDetailPage),
      ),
    );
  }

  Future<void> openDownloads() async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DownloadsPage(
          readerPageBuilder: (comic, chapter) => ReaderPage(
            title: comic.title,
            chapterTitle: chapter.title,
            comicId: comic.comicId,
            epId: chapter.epId,
            chapterIndex: chapter.index,
            images: chapter.imagePaths,
          ),
        ),
      ),
    );
  }

  Future<void> openSettings() async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          appearanceSettings: appearanceSettings,
          onAppearanceChanged: onAppearanceChanged,
          locale: locale,
          onLocaleChanged: onLocaleChanged,
          cloudSyncPageBuilder: (_) => const CloudSyncPage(),
          advancedSettingsPageBuilder: (_) => AdvancedSettingsPage(
            logsPageBuilder: (_) => const LogsPage(),
            comicSourceEditorPageBuilder: (_) => const ComicSourceEditorPage(),
            restoreComicSource: showComicSourceRestoreDialog,
          ),
        ),
      ),
    );
  }

  Future<void> openLines() async {
    Navigator.pop(context);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LineSettingsPage()));
  }
}
