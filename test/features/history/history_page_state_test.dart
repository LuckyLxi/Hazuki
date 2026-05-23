import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/history/state/history_page_state.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  group('HistoryPageData', () {
    test('entering and leaving selection mode clears selected items', () {
      final data = HistoryPageData()..applyLoaded(const [_comicA, _comicB]);

      data.toggleSelectionMode();
      data.toggleSelection(_comicA.scopedId.storageKey);

      expect(data.selectionMode, isTrue);
      expect(data.selectedStorageKeys, {_comicA.scopedId.storageKey});

      data.toggleSelectionMode();

      expect(data.selectionMode, isFalse);
      expect(data.selectedStorageKeys, isEmpty);
    });

    test('removes one comic without changing unrelated history', () {
      final data = HistoryPageData()
        ..applyLoaded(const [_comicA, _comicB, _comicC]);

      final next = data.removeComic(_comicB);

      expect(next.map((comic) => comic.id), ['a', 'c']);
      expect(data.history.map((comic) => comic.id), ['a', 'c']);
    });

    test('batch delete and clear reset selection state', () {
      final data = HistoryPageData()
        ..applyLoaded(const [_comicA, _comicB, _comicC]);

      data.toggleSelectionMode();
      data.toggleSelection(_comicA.scopedId.storageKey);
      data.toggleSelection(_comicC.scopedId.storageKey);

      final afterDelete = data.removeSelected();

      expect(afterDelete.map((comic) => comic.id), ['b']);
      expect(data.selectionMode, isFalse);
      expect(data.selectedStorageKeys, isEmpty);

      data.toggleSelectionMode();
      data.toggleSelection(_comicB.scopedId.storageKey);

      final afterClear = data.clearHistory();

      expect(afterClear, isEmpty);
      expect(data.history, isEmpty);
      expect(data.selectionMode, isFalse);
      expect(data.selectedStorageKeys, isEmpty);
    });

    test('reload re-enables entry animation after detail navigation', () {
      final data = HistoryPageData();

      data.disableEntryAnimation();
      data.applyLoaded(const [_comicA]);

      expect(data.playItemEntryAnimation, isTrue);
    });

    test('silent reload keeps entry animation disabled', () {
      final data = HistoryPageData();

      data.disableEntryAnimation();
      data.applyLoaded(const [_comicA], playEntryAnimation: false);

      expect(data.playItemEntryAnimation, isFalse);
    });

    test(
      'preserving reload updates entries without reordering existing items',
      () {
        final data = HistoryPageData()..applyLoaded(const [_comicA, _comicB]);

        data.applyLoadedPreservingExistingOrder(const [
          _comicBUpdated,
          _comicA,
          _comicC,
        ], playEntryAnimation: false);

        expect(data.history.map((comic) => comic.id), ['a', 'b', 'c']);
        expect(data.history[1].title, 'B updated');
        expect(data.playItemEntryAnimation, isFalse);
      },
    );
  });
}

const _comicA = ExploreComic(
  id: 'a',
  title: 'A',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);

const _comicB = ExploreComic(
  id: 'b',
  title: 'B',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);

const _comicBUpdated = ExploreComic(
  id: 'b',
  title: 'B updated',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);

const _comicC = ExploreComic(
  id: 'c',
  title: 'C',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);
