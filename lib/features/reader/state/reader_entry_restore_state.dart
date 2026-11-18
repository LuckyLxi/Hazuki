/// Tracks the one-time position restore for a reader chapter.
class ReaderEntryRestoreState {
  Map<String, dynamic>? _position;
  bool positionReady = false;
  bool settingsReady = false;
  // Null until the preference is loaded or the user sets it.
  bool? restorePagePosition;
  bool _started = false;
  int? _targetImage;

  bool get started => _started;

  void resolvePosition(Map<String, dynamic>? position) {
    _position = position;
    positionReady = true;
  }

  void cancel() {
    _started = true;
    _targetImage = null;
  }

  int? takeTarget({
    required String epId,
    required int imageCount,
    required int spreadSize,
  }) {
    if (!positionReady ||
        !settingsReady ||
        _started ||
        restorePagePosition == null ||
        imageCount == 0) {
      return null;
    }
    _started = true;
    final position = _position;
    if (restorePagePosition != true || position?['epId'] != epId) return null;

    final imagePage = position?['imagePage'];
    final pageIndex = position?['pageIndex'];
    final target = imagePage is int
        ? imagePage - 1
        : (pageIndex is int ? pageIndex * spreadSize : 0);
    return _targetImage = target.clamp(0, imageCount - 1);
  }

  bool canReportVisibleRange(int firstImage, int lastImage) {
    final target = _targetImage;
    if (target != null) {
      if (target < firstImage || target > lastImage) return false;
      _targetImage = null;
    }
    return _started;
  }
}
