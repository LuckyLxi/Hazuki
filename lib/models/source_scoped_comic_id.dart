class SourceScopedComicId {
  const SourceScopedComicId({required this.sourceKey, required this.comicId});

  static final RegExp _unsafeFileNameChars = RegExp(r'[\\/:*?"<>|]');

  factory SourceScopedComicId.fromStorageKey(
    String storageKey, {
    String fallbackSourceKey = '',
  }) {
    final normalized = storageKey.trim();
    final separatorIndex = normalized.indexOf('::');
    if (separatorIndex <= 0 || separatorIndex >= normalized.length - 2) {
      return SourceScopedComicId(
        sourceKey: fallbackSourceKey.trim(),
        comicId: normalized,
      );
    }
    return SourceScopedComicId(
      sourceKey: normalized.substring(0, separatorIndex).trim(),
      comicId: normalized.substring(separatorIndex + 2).trim(),
    );
  }

  final String sourceKey;
  final String comicId;

  String get normalizedSourceKey => sourceKey.trim();
  String get normalizedComicId => comicId.trim();

  String get storageKey {
    final source = normalizedSourceKey;
    final comic = normalizedComicId;
    if (source.isEmpty) {
      return comic;
    }
    return '$source::$comic';
  }

  String get imageCacheKey => storageKey;

  String get downloadDirName =>
      storageKey.replaceAll(_unsafeFileNameChars, '_');

  bool matchesStorageKey(String candidate) {
    final normalizedCandidate = candidate.trim();
    if (normalizedCandidate.isEmpty) {
      return false;
    }
    return normalizedCandidate == storageKey ||
        (normalizedSourceKey.isEmpty &&
            normalizedCandidate == normalizedComicId);
  }
}
