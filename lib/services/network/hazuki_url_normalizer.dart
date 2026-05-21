const Set<String> _jmExplicitPortHosts = {
  'www.jmcomic1.me',
  'www.jmcomic2.me',
  'www.jmcomic3.me',
  'www.jmapiproxyxxx.vip',
  'www.cdntwice.org',
  'cdn-msp.jmapiproxyxxx.vip',
  'cdnhth.jmapiproxyxxx.vip',
  'cdnsha.jmapiproxyxxx.vip',
  'cdnaspa.jmapiproxyxxx.vip',
  'cdnntr.jmapiproxyxxx.vip',
};

const List<String> _jmExplicitPortHostFragments = [
  'jmcomic',
  '18comic',
  'jm365',
  'jmapiproxy',
  'cdn-msp',
  'cdnhth',
  'cdntwice',
  'cdnsha',
  'cdnaspa',
  'cdnntr',
];

String normalizeHazukiRequestUrl(String url, {String sourceKey = ''}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return trimmed;
  }

  if (!_shouldStripExplicitHttpsPort(uri, sourceKey: sourceKey)) {
    return trimmed;
  }

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    path: uri.path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  ).toString();
}

bool _shouldStripExplicitHttpsPort(Uri uri, {required String sourceKey}) {
  if (sourceKey.trim() != 'jm') {
    return false;
  }
  if (uri.scheme.toLowerCase() != 'https' || !uri.hasPort) {
    return false;
  }

  final host = uri.host.toLowerCase();
  if (_jmExplicitPortHosts.contains(host)) {
    return true;
  }
  return _jmExplicitPortHostFragments.any(host.contains);
}
