import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';
import 'package:hazuki/models/hazuki_models.dart';

import 'favorite_cloud_flow.dart';
import 'favorite_local_flow.dart';

/// Captures the scope at request creation, before any asynchronous work.
class FavoriteListRequest {
  const FavoriteListRequest({
    required this.generation,
    required this.sourceKey,
    required this.mode,
  });

  final int generation;
  final String sourceKey;
  final FavoritePageMode mode;
}

class FavoriteListLoader {
  FavoriteListLoader({
    required this.cloud,
    required this.local,
    SourcePresentationReader presentationFor = emptySourcePresentation,
  }) : _presentationFor = presentationFor;

  final SourcePresentationReader _presentationFor;

  String _localSortStrategy(String sourceKey, String order) {
    final orders = _presentationFor(sourceKey)['localFavoriteOrders'];
    final strategy = orders is Map ? orders[order] : null;
    return const [
          'savedNewest',
          'savedOldest',
          'updatedNewest',
        ].contains(strategy)
        ? strategy as String
        : 'savedNewest';
  }

  static const timeout = Duration(seconds: 90);
  final FavoriteCloudFlow cloud;
  final FavoriteLocalFlow local;
  int _generation = 0;
  bool _disposed = false;

  void invalidate() => _generation++;

  FavoriteListRequest capture({
    required String sourceKey,
    required FavoritePageMode mode,
    bool replace = false,
  }) {
    if (replace) invalidate();
    return FavoriteListRequest(
      generation: _generation,
      sourceKey: sourceKey,
      mode: mode,
    );
  }

  bool isCurrent(
    FavoriteListRequest request, {
    required String sourceKey,
    required FavoritePageMode mode,
  }) =>
      !_disposed &&
      request.generation == _generation &&
      request.sourceKey == sourceKey &&
      request.mode == mode;

  Future<FavoriteComicsResult> load({
    required FavoriteListRequest request,
    required int page,
    required String folderId,
    required String sortOrder,
    required String timeoutMessage,
  }) => request.mode == FavoritePageMode.local
      ? local.loadPage(
          page: page,
          folderId: folderId,
          sortOrder: _localSortStrategy(request.sourceKey, sortOrder),
          sourceKey: '',
        )
      : cloud.loadPage(
          page: page,
          folderId: folderId,
          timeoutMessage: timeoutMessage,
          timeout: timeout,
        );

  void dispose() {
    _disposed = true;
    invalidate();
  }
}
