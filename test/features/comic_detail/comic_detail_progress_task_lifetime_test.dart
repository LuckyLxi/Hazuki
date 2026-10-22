import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_session_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/models/source_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'progress replacement keeps its watcher and isolates late results',
    () async {
      final repository = _Repository();
      final controller = ComicDetailSessionController(
        repository: repository,
        comic: const ExploreComic(
          id: 'comic',
          sourceKey: 'one',
          title: 'Comic',
          subTitle: '',
          cover: '',
        ),
        sourceKey: 'one',
        applyInitialFavoriteOverrides:
            ({required favoriteOverride, required cloudFavoriteOverride}) {},
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.initialize();
      expect(repository.origins, hasLength(1));
      expect(repository.watchOrigin!.cancellation!.reason, isNull);

      final next = controller.loadReadingProgress();
      expect(
        repository.origins.first.cancellation!.reason,
        SourceTaskStopReason.superseded,
      );
      expect(repository.watchOrigin!.cancellation!.reason, isNull);
      repository.replies[1].complete({'epId': 'current'});
      await next;
      repository.replies[0].complete({'epId': 'old'});
      await Future<void>.delayed(Duration.zero);
      expect(controller.lastReadProgress!['epId'], 'current');
      expect(notifications, 1);

      final last = controller.loadReadingProgress();
      controller.dispose();
      expect(
        repository.origins.last.cancellation!.reason,
        SourceTaskStopReason.ownerDisposed,
      );
      expect(
        repository.watchOrigin!.cancellation!.reason,
        SourceTaskStopReason.ownerDisposed,
      );
      repository.replies.last.complete({'epId': 'disposed'});
      await last;
      expect(notifications, 1);
      await controller.loadReadingProgress();
      expect(repository.origins, hasLength(3));
      await repository.changes.close();
    },
  );
}

class _Repository extends Fake implements ComicDetailFeatureFacade {
  final origins = <SourceTaskOrigin>[];
  final replies = <Completer<Map<String, dynamic>?>>[];
  final changes = StreamController<void>.broadcast();
  SourceTaskOrigin? watchOrigin;

  @override
  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) => Completer<ComicDetailsData>().future;

  @override
  Future<Map<String, dynamic>?> loadReadingProgress(
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  }) {
    origins.add(taskOrigin!);
    final reply = Completer<Map<String, dynamic>?>();
    replies.add(reply);
    return reply.future;
  }

  @override
  Stream<void> watchReadingProgressChanges({SourceTaskOrigin? taskOrigin}) {
    watchOrigin = taskOrigin;
    return changes.stream;
  }
}
