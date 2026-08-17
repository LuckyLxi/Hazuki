import '../comments/comments_avatar_support.dart';
import '../debug/debug_log_internals.dart';
import '../models/source_identity.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'picacg_login_profile_operations.dart';

/// Coordinates common login side data and source-specific profile adapters.
class SourceLoginSideDataOperations {
  SourceLoginSideDataOperations({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost {
    _avatarCapability = SourceAvatarCapability(
      activeFacade: () => facade,
      persistLoginSideData: persistLoginSideData,
    );
  }

  final SourceRuntimeHost _runtimeHost;
  final PicacgLoginProfileOperations _picacg =
      const PicacgLoginProfileOperations();
  late final SourceAvatarCapability _avatarCapability;

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;

  Future<void> persistLoginSideData(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
  }) async {
    final safeResult = jsonSafe(result);
    final results = safeResult is Map ? safeResult['results'] : null;
    if (results is! Map) {
      if (isHazukiPicacgSourceKey(sourceKey)) {
        final persisted = await _picacg.persist(
          facade,
          sourceKey: sourceKey,
          result: safeResult,
        );
        if (persisted) return;
      }
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Login side data missing',
        content: {
          'sourceKey': sourceKey,
          'resultType': safeResult.runtimeType.toString(),
        },
      );
      return;
    }

    final token = results['token'];
    if (isHazukiCopyMangaSourceKey(sourceKey) &&
        token is String &&
        token.trim().isNotEmpty) {
      await facade.saveSourceData(sourceKey, 'token', token.trim());
    }

    final avatarUrl = normalizeSourceAvatarUrl(
      sourceKey: sourceKey,
      avatar: results['avatar'],
    );
    if (avatarUrl != null) {
      facade.runtime.transientAvatarUrl = avatarUrl;
      _logAvatarEvent(
        facade,
        title: 'Login avatar parsed',
        content: {
          'sourceKey': sourceKey,
          'avatar': results['avatar'],
          'avatarUrl': avatarUrl,
          'hasToken': token is String && token.trim().isNotEmpty,
        },
      );
    } else {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Login avatar missing',
        content: {
          'sourceKey': sourceKey,
          'resultKeys': results.keys.map((key) => key.toString()).toList(),
          'avatar': results['avatar'],
          'hasToken': token is String && token.trim().isNotEmpty,
        },
      );
    }
  }

  void logPicacgLoginResponseTrace(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
    String? error,
  }) => _picacg.logResponseTrace(
    facade,
    sourceKey: sourceKey,
    result: result,
    error: error,
  );

  Future<String?> loadCurrentAvatarUrl() =>
      _avatarCapability.loadCurrentAvatarUrl();
}

void _logAvatarEvent(
  HazukiSourceFacade facade, {
  required String title,
  Object? content,
  String level = 'info',
}) {
  facade.addApplicationLog(
    level: level,
    title: title,
    source: 'source_avatar',
    content: content,
  );
}
