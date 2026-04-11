part of '../comic_detail_page.dart';

extension _ComicDetailMetaSectionExtension on _ComicDetailPageState {
  Widget _buildDetailMetaSection(ComicDetailsData details) {
    final strings = l10n(context);
    final authorLabel = strings.comicDetailAuthor;
    final tagLabel = strings.comicDetailTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComicDetailIdRow(
          id: details.id,
          onCopy: () async {
            final id = details.id.trim();
            if (id.isEmpty) {
              return;
            }
            await Clipboard.setData(ClipboardData(text: id));
            if (!mounted) {
              return;
            }
            unawaited(showHazukiPrompt(context, strings.comicDetailCopiedId));
          },
        ),
        _ComicDetailMetaRow(
          label: authorLabel,
          values: _normalizeComicMetaValues(
            details.tags.keys
                .where(_isComicAuthorKey)
                .expand((k) => details.tags[k] ?? const <String>[])
                .toList(),
            label: authorLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  initialKeyword: value,
                  comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
                    comic: comic,
                    heroTag: heroTag,
                    isDesktopPanel: widget.isDesktopPanel,
                    onCloseRequested: widget.onCloseRequested,
                  ),
                ),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
        _ComicDetailMetaRow(
          label: tagLabel,
          values: _normalizeComicMetaValues(
            details.tags.entries
                .where(
                  (e) =>
                      !_isComicAuthorKey(e.key) &&
                      e.key != details.tags.keys.lastOrNull,
                )
                .expand((e) => e.value)
                .toList(),
            label: tagLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  initialKeyword: value,
                  comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
                    comic: comic,
                    heroTag: heroTag,
                    isDesktopPanel: widget.isDesktopPanel,
                    onCloseRequested: widget.onCloseRequested,
                  ),
                ),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
      ],
    );
  }
}
