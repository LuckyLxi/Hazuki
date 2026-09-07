import '../../software_update/software_update_service.dart';

const _jsDelivrBaseUrl =
    'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/';
const _githubRawBaseUrl =
    'https://raw.githubusercontent.com/venera-app/venera-configs/main/';
const _ghproxyBaseUrl = 'https://ghproxy.net/$_githubRawBaseUrl';

String resolveSourceConfigUrl(String url, SoftwareUpdateSource source) {
  final normalized = url.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  final String relativePath;
  if (normalized.startsWith(_jsDelivrBaseUrl)) {
    relativePath = normalized.substring(_jsDelivrBaseUrl.length);
  } else if (normalized.startsWith(_githubRawBaseUrl)) {
    relativePath = normalized.substring(_githubRawBaseUrl.length);
  } else if (normalized.startsWith(_ghproxyBaseUrl)) {
    relativePath = normalized.substring(_ghproxyBaseUrl.length);
  } else {
    return normalized;
  }

  return switch (source) {
    SoftwareUpdateSource.jsDelivr => '$_jsDelivrBaseUrl$relativePath',
    SoftwareUpdateSource.github => '$_githubRawBaseUrl$relativePath',
    SoftwareUpdateSource.ghproxy => '$_ghproxyBaseUrl$relativePath',
  };
}

Future<List<String>> resolveSelectedSourceConfigUrls(List<String> urls) async {
  final source = await loadSoftwareUpdateSourcePreference();
  return urls
      .map((url) => resolveSourceConfigUrl(url, source))
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
