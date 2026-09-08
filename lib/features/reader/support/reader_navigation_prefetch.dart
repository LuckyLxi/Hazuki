/// Translates navigation targets into image prefetch work.
class ReaderNavigationPrefetch {
  const ReaderNavigationPrefetch({
    required bool Function() noImageModeEnabled,
    required void Function(int index) prefetchAround,
    required void Function(int index) requestPrefetchAhead,
  }) : _noImageModeEnabled = noImageModeEnabled,
       _prefetchAround = prefetchAround,
       _requestPrefetchAhead = requestPrefetchAhead;

  final bool Function() _noImageModeEnabled;
  final void Function(int index) _prefetchAround;
  final void Function(int index) _requestPrefetchAhead;

  void onPageTargetChanged(int index) {
    if (_noImageModeEnabled()) return;
    _prefetchAround(index);
    _requestPrefetchAhead(index);
  }
}
