import '../../../shared/preferences/software_update_source.dart';

const sourcePluginsRepositoryUrl =
    'https://raw.githubusercontent.com/LuckyLxi/Sources/main/plugins.json';
const sourcePluginsRepositoryName = 'LuckyLxi/Sources';

const _githubRawBase =
    'https://raw.githubusercontent.com/LuckyLxi/Sources/main/';
const _jsDelivrBase = 'https://cdn.jsdelivr.net/gh/LuckyLxi/Sources@main/';
const _githubBlobBase = 'https://github.com/LuckyLxi/Sources/blob/main/';
const _ghproxyBase = 'https://ghproxy.net/$_githubRawBase';

/// Keep the repository identity stable when switching download routes.
String canonicalSourcePluginUrl(String url) {
  for (final base in [
    _githubRawBase,
    _jsDelivrBase,
    _githubBlobBase,
    _ghproxyBase,
  ]) {
    if (url == '${base}plugins.json') {
      return sourcePluginsRepositoryUrl;
    }
  }
  return url;
}

/// 将内置仓库的插件包地址切换到所选更新源，保留相对路径与查询参数。
Uri resolveSourcePluginPackageUrl(Uri url, SoftwareUpdateSource source) {
  final address = url.toString();
  for (final base in [_githubRawBase, _jsDelivrBase, _ghproxyBase]) {
    if (!address.startsWith(base)) continue;
    final path = address.substring(base.length);
    if (path.isEmpty) return url;
    return Uri.parse(switch (source) {
      SoftwareUpdateSource.jsDelivr => '$_jsDelivrBase$path',
      SoftwareUpdateSource.github => '$_githubRawBase$path',
      SoftwareUpdateSource.ghproxy => '$_ghproxyBase$path',
    });
  }
  return url;
}

Uri resolveSourcePluginIndexUrl(Uri url, SoftwareUpdateSource source) {
  final canonical = canonicalSourcePluginUrl(url.toString());
  if (canonical != sourcePluginsRepositoryUrl) return url;
  const path = 'plugins.json';
  return Uri.parse(switch (source) {
    SoftwareUpdateSource.jsDelivr => '$_jsDelivrBase$path',
    SoftwareUpdateSource.github => '$_githubRawBase$path',
    SoftwareUpdateSource.ghproxy => '$_ghproxyBase$path',
  });
}
