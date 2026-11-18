import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/shared/downloads/chapter_download_flow.dart';

const _first = MangaChapterDownloadTarget(epId: '1', title: 'First', index: 0);
const _second = MangaChapterDownloadTarget(
  epId: '2',
  title: 'Second',
  index: 1,
);
const _third = MangaChapterDownloadTarget(epId: '3', title: 'Third', index: 2);
const _targets = [_first, _second, _third];
const _details = ComicDetailsData(
  id: 'comic',
  sourceKey: 'sample',
  title: 'Comic',
  subTitle: '',
  cover: '',
  description: 'Description',
  updateTime: '',
  likesCount: '',
  chapters: {'1': 'First', '2': 'Second', '3': 'Third'},
  tags: {},
  recommend: [],
  isFavorite: false,
  subId: '',
);

void main() {
  late _Downloader downloader;
  late bool active;

  setUp(() {
    downloader = _Downloader();
    active = true;
  });

  Future<({MangaDownloadEnqueueResult result, int chapterCount})?> run({
    List<MangaChapterDownloadTarget> targets = _targets,
    Future<DownloadedChapterConflictAction?> Function(MangaDownloadConflict)?
    choose,
    Future<bool> Function(MangaDownloadConflict)? confirm,
  }) => enqueueChapterDownloads(
    downloader: downloader,
    details: _details,
    targets: targets,
    coverUrl: 'fallback.jpg',
    isActive: () => active,
    chooseDownloadedAction:
        choose ?? (_) => throw StateError('Unexpected choice'),
    confirmRedownload:
        confirm ?? (_) => throw StateError('Unexpected confirmation'),
  );

  test('empty selection leaves the queue untouched', () async {
    expect(await run(targets: []), isNull);
    expect(downloader.checked, isEmpty);
  });

  test(
    'all selected chapters already in the queue stop before disk checks',
    () async {
      downloader.queued = _targets;
      expect(await run(), (
        result: MangaDownloadEnqueueResult.alreadyQueued,
        chapterCount: 0,
      ));
      expect(downloader.checked, [_targets]);
      expect(downloader.submitted, isEmpty);
    },
  );

  test('only non-queued chapters are checked and submitted in order', () async {
    downloader.queued = [_second];
    expect(await run(), (
      result: MangaDownloadEnqueueResult.queued,
      chapterCount: 2,
    ));
    expect(downloader.checked, [
      _targets,
      [_first, _third],
    ]);
    expect(downloader.submitted, [_first, _third]);
    expect(downloader.redownload, isFalse);
  });

  test('skip excludes downloaded chapters after queue filtering', () async {
    downloader.queued = [_first];
    downloader.downloaded = [_second];
    await run(
      choose: (conflict) async {
        expect(conflict.existingChapters, [_second]);
        return DownloadedChapterConflictAction.skip;
      },
    );
    expect(downloader.submitted, [_third]);
    expect(downloader.redownload, isFalse);
  });

  test(
    'overwrite requires confirmation and keeps all remaining targets',
    () async {
      downloader.queued = [_first];
      downloader.downloaded = [_second];
      final prompts = <String>[];
      await run(
        choose: (_) async {
          prompts.add('choose');
          return DownloadedChapterConflictAction.continueToRedownload;
        },
        confirm: (_) async {
          prompts.add('confirm');
          return true;
        },
      );
      expect(prompts, ['choose', 'confirm']);
      expect(downloader.submitted, [_second, _third]);
      expect(downloader.redownload, isTrue);
    },
  );

  test('dismissing the skip prompt does not submit chapters', () async {
    downloader.downloaded = [_first];
    expect(await run(choose: (_) async => null), isNull);
    expect(downloader.submitted, isEmpty);
  });

  test(
    'declining overwrite for fully downloaded chapters does not submit',
    () async {
      downloader.downloaded = _targets;
      var prompted = false;
      expect(
        await run(
          confirm: (_) async {
            prompted = true;
            return false;
          },
        ),
        isNull,
      );
      expect(prompted, isTrue);
      expect(downloader.submitted, isEmpty);
    },
  );

  test('a page closed during queue checking does not continue', () async {
    final checking = Completer<void>();
    downloader.waitForQueueCheck = checking.future;
    final outcome = run();
    active = false;
    checking.complete();
    expect(await outcome, isNull);
    expect(downloader.checked, [_targets]);
    expect(downloader.submitted, isEmpty);
  });

  test('enqueue errors propagate to the caller', () async {
    final error = StateError('queue write failed');
    downloader.enqueueError = error;
    await expectLater(run(), throwsA(same(error)));
  });
}

class _Downloader implements MangaDownloadCommands {
  List<MangaChapterDownloadTarget> queued = [];
  List<MangaChapterDownloadTarget> downloaded = [];
  final checked = <List<MangaChapterDownloadTarget>>[];
  List<MangaChapterDownloadTarget> submitted = [];
  bool? redownload;
  Future<void>? waitForQueueCheck;
  StateError? enqueueError;

  @override
  Future<MangaDownloadConflict> checkDownloadTaskConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    checked.add(chapters);
    await waitForQueueCheck;
    return MangaDownloadConflict(
      comicTitle: details.title,
      existingChapters: queued,
    );
  }

  @override
  Future<MangaDownloadConflict> checkDownloadConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    checked.add(chapters);
    return MangaDownloadConflict(
      comicTitle: details.title,
      existingChapters: downloaded,
    );
  }

  @override
  Future<MangaDownloadEnqueueResult> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
    bool redownloadExisting = false,
  }) async {
    if (enqueueError case final error?) throw error;
    submitted = chapters;
    redownload = redownloadExisting;
    expect(coverUrl, 'fallback.jpg');
    expect(description, 'Description');
    return MangaDownloadEnqueueResult.queued;
  }
}
