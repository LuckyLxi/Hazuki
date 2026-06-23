import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/state/downloads_completed_list_controller.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

void main() {
  test('list controller owns enter and exit transitions', () async {
    final controller = DownloadsCompletedListController(
      comics: const [_comic1],
      transitionDuration: Duration.zero,
    );

    controller.sync(const [_comic2]);

    expect(controller.entries.map((entry) => entry.comic.comicId), [
      'comic-1',
      'comic-2',
    ]);
    expect(controller.entries.first.exiting, isTrue);
    expect(controller.entries.last.entering, isTrue);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.entries, hasLength(1));
    expect(controller.entries.single.comic.comicId, 'comic-2');
    expect(controller.entries.single.entering, isFalse);
    controller.dispose();
  });
}

const _comic1 = DownloadedMangaComic(
  comicId: 'comic-1',
  title: 'One',
  subTitle: '',
  description: '',
  coverUrl: '',
  localCoverPath: null,
  chapters: [],
  updatedAtMillis: 1,
);

const _comic2 = DownloadedMangaComic(
  comicId: 'comic-2',
  title: 'Two',
  subTitle: '',
  description: '',
  coverUrl: '',
  localCoverPath: null,
  chapters: [],
  updatedAtMillis: 2,
);
