import 'dart:convert';

enum AppLogSanitization { hideAllSensitive, keepAccountInfo, keepEverything }

class AppLogSanitizer {
  const AppLogSanitizer();

  static const _credentialKeys = <String>{
    'authorization',
    'cookie',
    'cookies',
    'set-cookie',
    'token',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'session',
    'sessionid',
    'session_id',
    'password',
    'passwd',
    'secret',
    'api_key',
    'apikey',
    'client_secret',
    'clientsecret',
    'proxy_authorization',
  };

  static const _accountKeys = <String>{
    'account',
    'currentaccount',
    'current_account',
    'username',
    'user_name',
    'userid',
    'user_id',
    'uid',
    'email',
    'nickname',
  };

  static final _credentialPattern = RegExp(
    r'((?:authorization|proxy[-_ ]?authorization|access[_-]?token|refresh[_-]?token|api[_-]?key|client[_-]?secret|token|cookie|session(?:_id)?|password)\s*[:=]\s*)((?:(?:bearer|basic)\s+)?[^\s,;&]+)',
    caseSensitive: false,
  );

  bool containsSensitiveInformation(Object? value, {String? key}) {
    if (value == null || value == '[hidden]') return false;
    if (key != null &&
        (_isCredentialKey(key) || _isAccountKey(key)) &&
        value.toString().trim().isNotEmpty) {
      return true;
    }
    if (value is Map) {
      return value.entries.any(
        (entry) => containsSensitiveInformation(
          entry.value,
          key: entry.key.toString(),
        ),
      );
    }
    if (value is Iterable && value is! String) {
      return value.any(containsSensitiveInformation);
    }
    if (value is! String || value.trim().isEmpty) return false;

    final trimmed = value.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        if (containsSensitiveInformation(jsonDecode(value))) return true;
      } catch (_) {
        // Fall through to textual detection for non-JSON diagnostic text.
      }
    }
    return _credentialPattern.hasMatch(value);
  }

  Object? sanitize(Object? value, AppLogSanitization mode, {String? key}) {
    if (mode != AppLogSanitization.keepEverything &&
        key != null &&
        _isCredentialKey(key)) {
      return '[hidden]';
    }
    if (mode == AppLogSanitization.hideAllSensitive &&
        key != null &&
        _isAccountKey(key)) {
      return '[hidden]';
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): sanitize(
            entry.value,
            mode,
            key: entry.key.toString(),
          ),
      };
    }
    if (value is Iterable && value is! String) {
      return value.map((item) => sanitize(item, mode)).toList(growable: false);
    }
    if (value is String && mode != AppLogSanitization.keepEverything) {
      return _sanitizeString(value, mode);
    }
    return value;
  }

  String _sanitizeString(String value, AppLogSanitization mode) {
    final trimmed = value.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(value);
        return jsonEncode(sanitize(decoded, mode));
      } catch (_) {
        // Fall through to textual redaction for non-JSON diagnostic text.
      }
    }
    return value.replaceAllMapped(
      _credentialPattern,
      (match) => '${match.group(1)}[hidden]',
    );
  }

  bool _isCredentialKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[-\s]+'), '_');
    final compact = normalized.replaceAll('_', '');
    return _credentialKeys.contains(key.toLowerCase()) ||
        _credentialKeys.contains(normalized) ||
        _credentialKeys.contains(compact) ||
        normalized.endsWith('_token') ||
        normalized.endsWith('_cookie') ||
        normalized.endsWith('_session') ||
        normalized.endsWith('_secret') ||
        normalized.endsWith('_api_key') ||
        compact.endsWith('apikey');
  }

  bool _isAccountKey(String key) {
    final normalized = key.toLowerCase().replaceAll('-', '_');
    return _accountKeys.contains(normalized);
  }
}
