import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_continue_reading_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExploreComic _comic(String id, String source) => ExploreComic(
  id: id,
  title: 'Comic $id',
  subTitle: 'Author $id',
  cover: '',
  sourceKey: source,
);

void main() {
  late HazukiDatabase database;
  late ReadHistoryService history;
  late ReadingProgressService progress;
  late ValueNotifier<String> source;
  late DiscoverContinueReadingController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = HazukiDatabase.memory();
    history = ReadHistoryService(database: database);
    progress = ReadingProgressService(database: database);
    source = ValueNotifier('a');
    controller = DiscoverContinueReadingController(
      readHistoryService: history,
      readingProgressService: progress,
      activeSourceKey: () => source.value,
      sourceChanges: source,
    );
  });

  tearDown(() async {
    controller.dispose();
    source.dispose();
    history.dispose();
    await database.close();
  });

  test('loads the three most recent comics of the active source', () async {
    await history.replaceSourceHistory(
      sourceKey: 'a',
      history: [
        for (final id in ['1', '2', '3', '4']) _comic(id, 'a'),
      ],
    );
    await history.replaceSourceHistory(
      sourceKey: 'b',
      history: [_comic('9', 'b')],
    );
    await progress.save(
      comicId: '1',
      sourceKey: 'a',
      epId: 'ep-3',
      title: 'Chapter 3',
      chapterIndex: 2,
      pageIndex: 5,
    );

    await controller.load();
    // 写入历史与进度会触发合并后的后台重载，等其完成再断言。
    await pumpEventQueue();

    expect(controller.entries.map((entry) => entry.comic.id), ['1', '2', '3']);
    expect(controller.entries.first.progress, (
      chapterTitle: 'Chapter 3',
      pageIndex: 5,
    ));
    expect(controller.entries[1].progress, isNull);
  });

  test('reloads when the active source changes', () async {
    await history.replaceSourceHistory(
      sourceKey: 'b',
      history: [_comic('9', 'b')],
    );
    await controller.load();
    expect(controller.entries, isEmpty);

    source.value = 'b';
    await pumpEventQueue();

    expect(controller.entries.map((entry) => entry.comic.id), ['9']);
  });
}
