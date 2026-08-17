import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/favorites/source_favorite_folder_membership_probe.dart';
import 'package:hazuki/services/source/favorites/source_favorites_response_parser.dart';

void main() {
  test('skips invalid inputs and the aggregate folder', () async {
    const probe = SourceFavoriteFolderMembershipProbe();
    var loadCalls = 0;

    final emptyResult = await probe.infer(
      comicId: '  ',
      folders: const [FavoriteFolder(id: 'folder', name: 'Folder')],
      singleFolderOnly: false,
      loadPage: ({required page, required folderId}) async {
        loadCalls++;
        return const SourceFavoriteComicsPage(comics: []);
      },
    );
    final aggregateResult = await probe.infer(
      comicId: 'comic',
      folders: const [
        FavoriteFolder(id: '0', name: 'All'),
        FavoriteFolder(id: ' ', name: 'Empty'),
      ],
      singleFolderOnly: false,
      loadPage: ({required page, required folderId}) async {
        loadCalls++;
        return const SourceFavoriteComicsPage(comics: []);
      },
    );

    expect(emptyResult, isEmpty);
    expect(aggregateResult, isEmpty);
    expect(loadCalls, 0);
  });

  test('continues pages until the comic is found', () async {
    const probe = SourceFavoriteFolderMembershipProbe();
    final loadedPages = <(int, String)>[];

    final result = await probe.infer(
      comicId: ' target ',
      folders: const [FavoriteFolder(id: ' folder ', name: 'Folder')],
      singleFolderOnly: false,
      loadPage: ({required page, required folderId}) async {
        loadedPages.add((page, folderId));
        return SourceFavoriteComicsPage(
          comics: [_comic(page == 2 ? 'target' : 'other')],
          maxPage: 3,
        );
      },
    );

    expect(result, {'folder'});
    expect(loadedPages, [(1, 'folder'), (2, 'folder')]);
  });

  test(
    'checks every matching folder unless the source allows only one',
    () async {
      const folders = [
        FavoriteFolder(id: 'first', name: 'First'),
        FavoriteFolder(id: 'second', name: 'Second'),
      ];
      const probe = SourceFavoriteFolderMembershipProbe();
      final allCalls = <String>[];
      final all = await probe.infer(
        comicId: 'comic',
        folders: folders,
        singleFolderOnly: false,
        loadPage: ({required page, required folderId}) async {
          allCalls.add(folderId);
          return SourceFavoriteComicsPage(
            comics: [_comic('comic')],
            maxPage: 1,
          );
        },
      );

      final singleCalls = <String>[];
      final single = await probe.infer(
        comicId: 'comic',
        folders: folders,
        singleFolderOnly: true,
        loadPage: ({required page, required folderId}) async {
          singleCalls.add(folderId);
          return SourceFavoriteComicsPage(
            comics: [_comic('comic')],
            maxPage: 1,
          );
        },
      );

      expect(all, {'first', 'second'});
      expect(allCalls, ['first', 'second']);
      expect(single, {'first'});
      expect(singleCalls, ['first']);
    },
  );

  test(
    'stops on empty pages, missing max page, and the safety limit',
    () async {
      const folders = [FavoriteFolder(id: 'folder', name: 'Folder')];
      var emptyCalls = 0;
      expect(
        await const SourceFavoriteFolderMembershipProbe().infer(
          comicId: 'comic',
          folders: folders,
          singleFolderOnly: false,
          loadPage: ({required page, required folderId}) async {
            emptyCalls++;
            return const SourceFavoriteComicsPage(comics: []);
          },
        ),
        isEmpty,
      );
      expect(emptyCalls, 1);

      var missingMaxCalls = 0;
      await const SourceFavoriteFolderMembershipProbe().infer(
        comicId: 'comic',
        folders: folders,
        singleFolderOnly: false,
        loadPage: ({required page, required folderId}) async {
          missingMaxCalls++;
          return SourceFavoriteComicsPage(comics: [_comic('other')]);
        },
      );
      expect(missingMaxCalls, 1);

      var limitedCalls = 0;
      await const SourceFavoriteFolderMembershipProbe(maxProbePages: 2).infer(
        comicId: 'comic',
        folders: folders,
        singleFolderOnly: false,
        loadPage: ({required page, required folderId}) async {
          limitedCalls++;
          return SourceFavoriteComicsPage(
            comics: [_comic('other')],
            maxPage: 10,
          );
        },
      );
      expect(limitedCalls, 2);
    },
  );
}

ExploreComic _comic(String id) =>
    ExploreComic(id: id, title: id, subTitle: '', cover: '', sourceKey: 'jm');
