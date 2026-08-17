import '../debug/debug_log_internals.dart';
import '../models/source_identity.dart';
import '../runtime/source_runtime_facade.dart';
import 'picacg_login_profile_parser.dart';
import 'picacg_profile_script_factory.dart';

/// Handles Picacg token extraction, profile lookup, and response diagnostics.
class PicacgLoginProfileOperations {
  const PicacgLoginProfileOperations();

  static const _parser = PicacgLoginProfileParser();
  static const _scriptFactory = PicacgProfileScriptFactory();

  Future<bool> persist(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
  }) =>
      _persistPicacgLoginSideData(facade, sourceKey: sourceKey, result: result);

  void logResponseTrace(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
    String? error,
  }) => _logPicacgLoginResponseTrace(
    facade,
    sourceKey: sourceKey,
    result: result,
    error: error,
  );
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

Future<bool> _persistPicacgLoginSideData(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required dynamic result,
}) async {
  final token = PicacgLoginProfileOperations._parser
      .extractLoginToken(result)
      ?.trim();
  if (token == null || token.isEmpty) {
    return false;
  }
  await facade.saveSourceData(sourceKey, 'token', token);

  final tokenPayload = PicacgLoginProfileOperations._parser.decodeJwtPayload(
    token,
  );
  final tokenDisplayName = tokenPayload?['name']?.toString().trim();
  if (tokenDisplayName != null && tokenDisplayName.isNotEmpty) {
    await facade.saveSourceData(sourceKey, 'display_name', tokenDisplayName);
  }

  final profile = await _fetchPicacgProfileWithToken(
    facade,
    sourceKey: sourceKey,
    token: token,
  );
  final displayName = profile?.displayName?.trim() ?? tokenDisplayName;
  if (displayName != null && displayName.isNotEmpty) {
    await facade.saveSourceData(sourceKey, 'display_name', displayName);
  }

  final avatarUrl = profile?.avatarUrl?.trim();
  if (avatarUrl != null) {
    facade.runtime.transientAvatarUrl = avatarUrl;
    await facade.saveSourceData(sourceKey, 'avatar_url', avatarUrl);
  }

  _logAvatarEvent(
    facade,
    title: 'Picacg token profile parsed',
    content: {
      'sourceKey': sourceKey,
      'hasProfile': profile != null,
      'displayName': displayName,
      'hasAvatar': avatarUrl != null,
    },
  );
  return true;
}

Future<PicacgProfileData?> _fetchPicacgProfileWithToken(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required String token,
}) async {
  final engine = facade.js.engine;
  if (engine == null) {
    _logAvatarEvent(
      facade,
      level: 'warn',
      title: 'Picacg avatar profile fetch skipped',
      content: {'sourceKey': sourceKey, 'reason': 'missing_engine'},
    );
    return null;
  }

  try {
    final result = engine.evaluate(
      PicacgLoginProfileOperations._scriptFactory.build(token),
      name: 'picacg_profile_avatar.js',
    );
    final resolved = jsonSafe(await facade.js.resolve(result));
    final profile = PicacgLoginProfileOperations._parser.parseProfileResult(
      sourceKey: sourceKey,
      result: resolved,
    );
    if (profile == null) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Picacg avatar profile missing',
        content: {'sourceKey': sourceKey, 'result': resolved},
      );
      return null;
    }
    _logAvatarEvent(
      facade,
      title: 'Picacg avatar profile parsed',
      content: {
        'sourceKey': sourceKey,
        'displayName': profile.displayName,
        'avatarUrl': profile.avatarUrl,
      },
    );
    return profile;
  } catch (error) {
    _logAvatarEvent(
      facade,
      level: 'error',
      title: 'Picacg avatar profile fetch failed',
      content: {'sourceKey': sourceKey, 'error': error.toString()},
    );
    return null;
  }
}

void _logPicacgLoginResponseTrace(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required dynamic result,
  String? error,
}) {
  if (!isHazukiPicacgSourceKey(sourceKey)) {
    return;
  }
  final safeResult = jsonSafe(result);
  final responses = safeResult is Map ? safeResult['authResponses'] : null;
  facade.addApplicationLog(
    level: error == null ? 'info' : 'error',
    title: error == null
        ? 'Picacg login server response'
        : 'Picacg login server response failed',
    source: 'source_login',
    content: {
      'sourceKey': sourceKey,
      'error': ?error,
      'responseCount': responses is List ? responses.length : 0,
      'result': safeResult,
    },
  );
}
