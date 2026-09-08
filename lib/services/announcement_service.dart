import 'package:shared_preferences/shared_preferences.dart';

import 'announcements/announcement_remote_source.dart';
import 'announcements/announcement_service.dart' as core;
import 'announcements/announcement_store.dart';

export 'announcements/announcement.dart';
export 'announcements/announcement_manifest_parser.dart'
    show parseAnnouncementManifest;
export 'announcements/announcement_remote_source.dart';
export 'announcements/announcement_store.dart';

/// Compatibility adapter for callers using the former service import.
///
/// Production code composes the core service from explicit collaborators in
/// the application service registrar.
class AnnouncementService extends core.AnnouncementService {
  AnnouncementService({
    AnnouncementRemoteSource? remoteSource,
    AnnouncementStore? store,
    AnnouncementRemoteLoader? loadRemote,
    Future<SharedPreferences> Function()? loadPreferences,
    super.now,
  }) : assert(remoteSource == null || loadRemote == null),
       super(
         remoteSource:
             remoteSource ??
             (loadRemote == null
                 ? HttpAnnouncementRemoteSource()
                 : CallbackAnnouncementRemoteSource(loadRemote)),
         store:
             store ??
             SharedPreferencesAnnouncementStore(preferences: loadPreferences),
       );
}
