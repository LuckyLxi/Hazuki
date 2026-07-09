class SourceCookieStore {
  SourceCookieStore({
    required List<SourceCookie> Function() loadCookies,
    required Future<void> Function(List<SourceCookie>) saveCookies,
  }) : _loadCookies = loadCookies,
       _saveCookies = saveCookies;

  final List<SourceCookie> Function() _loadCookies;
  final Future<void> Function(List<SourceCookie>) _saveCookies;

  Future<dynamic> handleOperation(Map<String, dynamic> request) async {
    final fn = request['function']?.toString();
    final rawUrl = request['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final url = _normalizeUrl(rawUrl);
    switch (fn) {
      case 'set':
        final list = request['cookies'];
        if (list is List) {
          final cookies = list
              .whereType<Map>()
              .map(
                (item) => SourceCookie.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList();
          await set(url, cookies);
        }
        return null;
      case 'get':
        return get(url).map((cookie) => cookie.toMap()).toList();
      case 'delete':
        await delete(url);
        return null;
      default:
        return null;
    }
  }

  List<SourceCookie> get(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    return _loadCookies()
        .where((cookie) => !cookie.isExpired(now) && cookie.matches(uri))
        .toList();
  }

  Future<void> set(String url, List<SourceCookie> cookies) async {
    final uri = Uri.tryParse(url);
    if (uri == null || cookies.isEmpty) return;
    final all = _loadCookies();
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
    await _saveCookies(all);
  }

  Future<void> delete(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final all = _loadCookies()..removeWhere((cookie) => cookie.matches(uri));
    await _saveCookies(all);
  }

  String? buildHeader(String url) {
    final cookies = get(url);
    if (cookies.isEmpty) return null;
    final selected = <String, SourceCookie>{};
    for (final cookie in cookies) {
      final current = selected[cookie.name];
      if (current == null) {
        selected[cookie.name] = cookie;
        continue;
      }
      final cookieStartsWithDot = cookie.domain.startsWith('.');
      final currentStartsWithDot = current.domain.startsWith('.');
      if (!cookieStartsWithDot && currentStartsWithDot) {
        selected[cookie.name] = cookie;
      } else if (cookieStartsWithDot == currentStartsWithDot &&
          cookie.domain.length > current.domain.length) {
        selected[cookie.name] = cookie;
      }
    }
    return selected.values
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  Future<void> saveFromHeaders(
    String url,
    Map<String, List<String>> headers,
  ) async {
    final setCookies = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .expand((entry) => entry.value)
        .toList();
    if (setCookies.isEmpty) return;
    final parsed = <SourceCookie>[];
    for (final raw in setCookies) {
      for (final segment in _splitSetCookieHeader(raw)) {
        final cookie = SourceCookie.parseSetCookie(segment, url);
        if (cookie != null) parsed.add(cookie);
      }
    }
    await set(url, parsed);
  }

  String _normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme ? trimmed : 'https://$trimmed';
  }

  List<String> _splitSetCookieHeader(String raw) {
    if (!raw.contains(',')) return [raw];
    return raw
        .split(RegExp(r',(?=\s*[^;,\s]+=)'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }
}

class SourceCookie {
  const SourceCookie({
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

  bool isExpired(int now) => expiresAt != null && expiresAt! <= now;

  bool matches(Uri uri) {
    final requestHost = uri.host.toLowerCase();
    final normalizedDomain = domain.toLowerCase();
    final cookieDomain = normalizedDomain.startsWith('.')
        ? normalizedDomain.substring(1)
        : normalizedDomain;
    final domainMatch =
        requestHost == cookieDomain || requestHost.endsWith('.$cookieDomain');
    if (!domainMatch) return false;
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    final cookiePath = path.isEmpty ? '/' : path;
    return requestPath.startsWith(cookiePath);
  }

  SourceCookie withFallbackDomain(String fallbackDomain) {
    if (domain.isNotEmpty) return this;
    return SourceCookie(
      name: name,
      value: value,
      domain: fallbackDomain,
      path: path,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'value': value,
    'domain': domain,
    'path': path,
    'expiresAt': expiresAt,
  };

  static SourceCookie fromMap(Map<String, dynamic> map) {
    return SourceCookie(
      name: map['name']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      domain: map['domain']?.toString() ?? '',
      path: map['path']?.toString() ?? '/',
      expiresAt: map['expiresAt'] is num
          ? (map['expiresAt'] as num).toInt()
          : null,
    );
  }

  static SourceCookie? parseSetCookie(String raw, String fallbackUrl) {
    final uri = Uri.tryParse(fallbackUrl);
    if (uri == null || raw.isEmpty) return null;
    final segments = raw.split(';').map((part) => part.trim()).toList();
    if (segments.isEmpty || !segments.first.contains('=')) return null;
    final first = segments.first;
    final equalIndex = first.indexOf('=');
    if (equalIndex <= 0) return null;
    final name = first.substring(0, equalIndex).trim();
    final value = first.substring(equalIndex + 1).trim();
    String domain = uri.host;
    String path = '/';
    int? expiresAt;
    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i];
      final index = segment.indexOf('=');
      if (index <= 0) continue;
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
        final date = DateTime.tryParse(val);
        if (date != null) expiresAt = date.millisecondsSinceEpoch;
      }
    }
    return SourceCookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expiresAt: expiresAt,
    );
  }
}
