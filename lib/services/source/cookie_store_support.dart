part of '../hazuki_source_service.dart';

extension _CookieStoreSupport on HazukiSourceService {
  Future<dynamic> _handleCookieOperation(Map<String, dynamic> request) async {
    final fn = request['function']?.toString();
    final rawUrl = request['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }

    final url = _normalizeCookieUrl(rawUrl);

    switch (fn) {
      case 'set':
        final list = request['cookies'];
        if (list is List) {
          final cookies = list
              .whereType<Map>()
              .map((e) => _Cookie.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          await _setCookies(url, cookies);
        }
        return null;
      case 'get':
        return _getCookies(url).map((e) => e.toMap()).toList();
      case 'delete':
        await _deleteCookies(url);
        return null;
      default:
        return null;
    }
  }

  List<_Cookie> _loadCookieStore() {
    return facade._loadCookieStore();
  }

  Future<void> _saveCookieStore(List<_Cookie> cookies) async {
    await facade._saveCookieStore(cookies);
  }

  List<_Cookie> _getCookies(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return [];
    }

    final all = _loadCookieStore();
    final now = DateTime.now().millisecondsSinceEpoch;

    return all.where((cookie) {
      if (cookie.isExpired(now)) {
        return false;
      }
      return cookie.matches(uri);
    }).toList();
  }

  Future<void> _setCookies(String url, List<_Cookie> cookies) async {
    final uri = Uri.tryParse(url);
    if (uri == null || cookies.isEmpty) {
      return;
    }

    final all = _loadCookieStore();
    for (final cookie in cookies) {
      final normalized = cookie.withFallbackDomain(uri.host);
      all.removeWhere(
        (existing) =>
            existing.name == normalized.name &&
            existing.domain == normalized.domain &&
            existing.path == normalized.path,
      );
      all.add(normalized);

      if (normalized.domain.startsWith('.')) {
        final hostDomain = normalized.domain.substring(1);
        all.removeWhere(
          (existing) =>
              existing.name == normalized.name &&
              existing.path == normalized.path &&
              existing.domain == hostDomain,
        );
      } else {
        all.removeWhere(
          (existing) =>
              existing.name == normalized.name &&
              existing.path == normalized.path &&
              existing.domain == '.${normalized.domain}',
        );
      }
    }

    await _saveCookieStore(all);
  }

  Future<void> _deleteCookies(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final all = _loadCookieStore();
    all.removeWhere((cookie) => cookie.matches(uri));
    await _saveCookieStore(all);
  }

  String? _buildCookieHeader(String url) {
    final cookies = _getCookies(url);
    if (cookies.isEmpty) {
      return null;
    }

    final selected = <String, _Cookie>{};
    for (final cookie in cookies) {
      final current = selected[cookie.name];
      if (current == null) {
        selected[cookie.name] = cookie;
        continue;
      }

      final cookieDomain = cookie.domain;
      final currentDomain = current.domain;
      final cookieStartsWithDot = cookieDomain.startsWith('.');
      final currentStartsWithDot = currentDomain.startsWith('.');

      if (!cookieStartsWithDot && currentStartsWithDot) {
        selected[cookie.name] = cookie;
      } else if (cookieStartsWithDot == currentStartsWithDot &&
          cookieDomain.length > currentDomain.length) {
        selected[cookie.name] = cookie;
      }
    }

    return selected.values.map((e) => '${e.name}=${e.value}').join('; ');
  }

  Future<void> _saveCookiesFromHeaders(
    String url,
    Map<String, List<String>> headers,
  ) async {
    final setCookies = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .expand((entry) => entry.value)
        .toList();

    if (setCookies.isEmpty) {
      return;
    }

    final parsed = <_Cookie>[];
    for (final raw in setCookies) {
      final segments = _splitSetCookieHeader(raw);
      for (final segment in segments) {
        final cookie = _Cookie.parseSetCookie(segment, url);
        if (cookie != null) {
          parsed.add(cookie);
        }
      }
    }
    await _setCookies(url, parsed);
  }

  String _normalizeCookieUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  List<String> _splitSetCookieHeader(String raw) {
    if (!raw.contains(',')) {
      return [raw];
    }

    final parts = raw.split(RegExp(r',(?=\s*[^;,\s]+=)'));
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}

class _Cookie {
  const _Cookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final int? expiresAt;

  bool isExpired(int now) {
    if (expiresAt == null) {
      return false;
    }
    return expiresAt! <= now;
  }

  bool matches(Uri uri) {
    final requestHost = uri.host.toLowerCase();
    final normalizedDomain = domain.toLowerCase();
    final cookieDomain = normalizedDomain.startsWith('.')
        ? normalizedDomain.substring(1)
        : normalizedDomain;
    final domainMatch =
        requestHost == cookieDomain || requestHost.endsWith('.$cookieDomain');
    if (!domainMatch) {
      return false;
    }

    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    final cookiePath = path.isEmpty ? '/' : path;
    return requestPath.startsWith(cookiePath);
  }

  _Cookie withFallbackDomain(String fallbackDomain) {
    if (domain.isNotEmpty) {
      return this;
    }
    return _Cookie(
      name: name,
      value: value,
      domain: fallbackDomain,
      path: path,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expiresAt': expiresAt,
    };
  }

  static _Cookie fromMap(Map<String, dynamic> map) {
    return _Cookie(
      name: map['name']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      domain: map['domain']?.toString() ?? '',
      path: map['path']?.toString() ?? '/',
      expiresAt: map['expiresAt'] is num
          ? (map['expiresAt'] as num).toInt()
          : null,
    );
  }

  static _Cookie? parseSetCookie(String raw, String fallbackUrl) {
    final uri = Uri.tryParse(fallbackUrl);
    if (uri == null || raw.isEmpty) {
      return null;
    }

    final segments = raw.split(';').map((e) => e.trim()).toList();
    if (segments.isEmpty || !segments.first.contains('=')) {
      return null;
    }

    final first = segments.first;
    final equalIndex = first.indexOf('=');
    if (equalIndex <= 0) {
      return null;
    }

    final name = first.substring(0, equalIndex).trim();
    final value = first.substring(equalIndex + 1).trim();

    String domain = uri.host;
    String path = '/';
    int? expiresAt;

    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i];
      final index = segment.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = segment.substring(0, index).trim().toLowerCase();
      final val = segment.substring(index + 1).trim();

      if (key == 'domain' && val.isNotEmpty) {
        domain = val.startsWith('.') ? val : '.$val';
      } else if (key == 'path' && val.isNotEmpty) {
        path = val;
      } else if (key == 'max-age') {
        final seconds = int.tryParse(val);
        if (seconds != null) {
          expiresAt = DateTime.now().millisecondsSinceEpoch + seconds * 1000;
        }
      } else if (key == 'expires') {
        final dt = DateTime.tryParse(val);
        if (dt != null) {
          expiresAt = dt.millisecondsSinceEpoch;
        }
      }
    }

    return _Cookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expiresAt: expiresAt,
    );
  }
}
