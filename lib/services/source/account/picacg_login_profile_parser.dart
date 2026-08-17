import 'dart:convert';

import '../comments/comments_avatar_support.dart';

class PicacgProfileData {
  const PicacgProfileData({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;
}

/// Parses Picacg authentication and profile payloads without runtime access.
class PicacgLoginProfileParser {
  const PicacgLoginProfileParser();

  String? extractLoginToken(dynamic result) {
    if (result is! Map) return null;
    final authResponses = result['authResponses'];
    if (authResponses is! List) return null;
    for (final response in authResponses) {
      if (response is! Map) continue;
      final parsedBody = response['parsedBody'];
      if (parsedBody is Map) {
        final data = parsedBody['data'];
        final token = data is Map ? data['token']?.toString() : null;
        if (token != null && token.trim().isNotEmpty) return token;
      }
      final body = response['body']?.toString();
      if (body == null || body.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final data = decoded['data'];
          final token = data is Map ? data['token']?.toString() : null;
          if (token != null && token.trim().isNotEmpty) return token;
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final payloadText = utf8.decode(payloadBytes);
      final decoded = jsonDecode(payloadText);
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
    return null;
  }

  PicacgProfileData? parseProfileResult({
    required String sourceKey,
    required dynamic result,
  }) {
    if (result is! Map) return null;
    final parsedBody = result['parsedBody'];
    if (parsedBody is Map) {
      final profile = _profileFromMap(sourceKey: sourceKey, map: parsedBody);
      if (profile != null) return profile;
    }
    final body = result['body']?.toString();
    if (body == null || body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return _profileFromMap(sourceKey: sourceKey, map: decoded);
      }
    } catch (_) {}
    return null;
  }

  PicacgProfileData? _profileFromMap({
    required String sourceKey,
    required Map<dynamic, dynamic> map,
  }) {
    final profile = _findProfileMap(map);
    if (profile == null) return null;
    final avatarUrl = normalizeSourceAvatarUrl(
      sourceKey: sourceKey,
      avatar: profile['avatar'],
    );
    final displayName = profile['name']?.toString().trim();
    if ((displayName == null || displayName.isEmpty) && avatarUrl == null) {
      return null;
    }
    return PicacgProfileData(displayName: displayName, avatarUrl: avatarUrl);
  }

  Map<dynamic, dynamic>? _findProfileMap(Map<dynamic, dynamic> map) {
    if (map['avatar'] != null || map['name'] != null) return map;
    final data = map['data'];
    if (data is Map) {
      if (data['avatar'] != null || data['name'] != null) return data;
      final user = data['user'];
      if (user is Map) return user;
    }
    final user = map['user'];
    return user is Map ? user : null;
  }
}
