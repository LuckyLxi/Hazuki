import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/source_comic_tags.dart';
import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';

/// Resolves missing source-specific tags without owning page or storage state.
class FavoriteComicTagLoader {
  const FavoriteComicTagLoader(
    this._reader, {
    SourcePresentationReader presentationFor = emptySourcePresentation,
  }) : _presentationFor = presentationFor;

  final SourcePresentationReader _presentationFor;

  final SourceReaderGateway? _reader;

  Future<Map<String, List<String>>> load(
    FavoriteComicsResult result, {
    required void Function(ExploreComic comic, List<String> tags) onTagsLoaded,
    bool Function()? isCurrent,
  }) async {
    final reader = _reader;
    if (reader == null || result.errorMessage != null) return {};
    final comics = List<ExploreComic>.of(result.comics);
    // Preserve the existing four-at-a-time detail request limit.
    for (var start = 0; start < comics.length; start += 4) {
      if (isCurrent?.call() == false) break;
      final end = (start + 4).clamp(0, comics.length);
      await Future.wait(
        List<Future<void>>.generate(end - start, (offset) async {
          final index = start + offset;
          final comic = comics[index];
          final presentation = _presentationFor(comic.sourceKey);
          if (presentation['enrichMissingTags'] != true ||
              comic.tags.isNotEmpty) {
            return;
          }
          try {
            final details = await reader.loadComicDetails(
              comic.id,
              sourceKey: comic.sourceKey,
            );
            if (isCurrent?.call() == false ||
                _presentationFor(comic.sourceKey)['enrichMissingTags'] !=
                    true) {
              return;
            }
            final tags = sourceComicDetailTags(details, presentation);
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
