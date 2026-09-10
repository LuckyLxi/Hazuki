import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/picacg_comic_tags.dart';

/// Resolves missing source-specific tags without owning page or storage state.
class FavoriteComicTagLoader {
  const FavoriteComicTagLoader(this._reader);

  final SourceReaderGateway? _reader;

  Future<Map<String, List<String>>> load(
    FavoriteComicsResult result, {
    required void Function(ExploreComic comic, List<String> tags) onTagsLoaded,
  }) async {
    final reader = _reader;
    if (reader == null || result.errorMessage != null) return {};
    final comics = List<ExploreComic>.of(result.comics);
    // Preserve the existing four-at-a-time detail request limit.
    for (var start = 0; start < comics.length; start += 4) {
      final end = (start + 4).clamp(0, comics.length);
      await Future.wait(
        List<Future<void>>.generate(end - start, (offset) async {
          final index = start + offset;
          final comic = comics[index];
          if (comic.sourceKey.trim().toLowerCase() != 'picacg' ||
              comic.tags.isNotEmpty) {
            return;
          }
          try {
            final details = await reader.loadComicDetails(
              comic.id,
              sourceKey: comic.sourceKey,
            );
            final tags = picacgComicDetailTags(details);
            if (tags.isEmpty) return;
            comics[index] = comic.copyWith(tags: tags);
            onTagsLoaded(comic, tags);
          } catch (_) {
            // Tag enrichment is best effort and must not fail the favorites list.
          }
        }),
      );
    }
    return {
      for (final comic in comics)
        if (comic.tags.isNotEmpty) comic.scopedId.storageKey: comic.tags,
    };
  }
}
