import 'package:hazuki/services/announcements/announcement_remote_source.dart';
import 'package:hazuki/services/announcements/announcement_service.dart';
import 'package:hazuki/services/announcements/announcement_store.dart';

/// 以回调提供公告清单、以 SharedPreferences 持久化已读状态的测试用公告服务。
AnnouncementService buildTestAnnouncementService({
  required AnnouncementRemoteLoader loadRemote,
  DateTime Function()? now,
}) => AnnouncementService(
  remoteSource: CallbackAnnouncementRemoteSource(loadRemote),
  store: SharedPreferencesAnnouncementStore(),
  now: now,
);
