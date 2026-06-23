import 'cloud_sync_participant.dart';
import 'cloud_sync_favorites_participant.dart';
import 'cloud_sync_comment_filter_participant.dart';
import 'cloud_sync_reading_participant.dart';
import 'cloud_sync_settings_participant.dart';
import 'cloud_sync_source_participant.dart';
import '../download_groups_service.dart';
import '../source/source_capabilities.dart';
import '../local_favorites/local_favorites_contracts.dart';
import '../read_history_service.dart';
import '../reading_progress_service.dart';
import '../search_history_service.dart';

class CloudSyncParticipantSet {
  const CloudSyncParticipantSet({
    required this.reading,
    required this.settings,
    required this.searchHistory,
    required this.source,
    required this.commentFilter,
    required this.favorites,
    required this.downloadGroups,
  });

  final CloudSyncReadingParticipant reading;
  final CloudSyncSettingsParticipant settings;
  final SearchHistorySyncParticipant searchHistory;
  final CloudSyncSourceParticipant source;
  final CommentFilterSyncParticipant commentFilter;
  final LocalFavoritesSyncParticipant favorites;
  final DownloadGroupsSyncParticipant downloadGroups;
}

CloudSyncParticipantSet createCloudSyncParticipantSet({
  required SourceSyncGateway source,
  required ReadHistoryService readHistory,
  required ReadingProgressService readingProgress,
  required LocalFavoritesSyncStore localFavorites,
  required DownloadGroupsService downloadGroups,
  required SearchHistoryService searchHistory,
}) {
  final favoritesParticipant = LocalFavoritesSyncParticipant(localFavorites);
  final downloadGroupsParticipant = DownloadGroupsSyncParticipant(
    downloadGroups,
  );
  const commentFilterParticipant = CommentFilterSyncParticipant();
  return CloudSyncParticipantSet(
    reading: CloudSyncReadingParticipant(
      readHistory: readHistory,
      readingProgress: readingProgress,
      activeSourceKey: () => source.activeSourceKey,
    ),
    settings: CloudSyncSettingsParticipant(
      localFavorites: favoritesParticipant,
      downloadGroups: downloadGroupsParticipant,
      commentFilter: commentFilterParticipant,
    ),
    searchHistory: SearchHistorySyncParticipant(searchHistory),
    source: CloudSyncSourceParticipant(source),
    commentFilter: commentFilterParticipant,
    favorites: favoritesParticipant,
    downloadGroups: downloadGroupsParticipant,
  );
}
