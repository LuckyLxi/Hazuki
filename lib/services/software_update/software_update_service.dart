import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/preferences/hazuki_preference_keys.dart';
import '../network/hazuki_network.dart';
import 'software_update_version_utils.dart';

const _ghproxyBaseUrl = 'https://ghproxy.net/';
const _jsDelivrUpdateManifestUrl =
    'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json';
const _githubRawUpdateManifestUrl =
    'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/update.json';
const _ghproxyUpdateManifestUrl =
    '$_ghproxyBaseUrl$_githubRawUpdateManifestUrl';
const _githubLatestReleaseUrl =
    'https://api.github.com/repos/LuckyLxi/Hazuki/releases/latest';

enum SoftwareUpdateSource {
  jsDelivr('jsdelivr'),
  github('github'),
  ghproxy('ghproxy');

  const SoftwareUpdateSource(this.preferenceValue);

  final String preferenceValue;

  static SoftwareUpdateSource fromPreference(String? value) {
    return SoftwareUpdateSource.values.firstWhere(
      (source) => source.preferenceValue == value,
      orElse: () => SoftwareUpdateSource.jsDelivr,
    );
  }
}

Future<SoftwareUpdateSource> loadSoftwareUpdateSourcePreference() async {
  final prefs = await SharedPreferences.getInstance();
  return SoftwareUpdateSource.fromPreference(
    prefs.getString(hazukiSoftwareUpdateSourcePreferenceKey),
  );
}

String resolveSoftwareUpdateCheckUrl(SoftwareUpdateSource source) {
  return switch (source) {
    SoftwareUpdateSource.jsDelivr => _jsDelivrUpdateManifestUrl,
    SoftwareUpdateSource.github => _githubLatestReleaseUrl,
    SoftwareUpdateSource.ghproxy => _ghproxyUpdateManifestUrl,
  };
}

String? resolveSoftwareUpdateDownloadUrl(
  String? url,
  SoftwareUpdateSource source,
) {
  final normalized = url?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (source != SoftwareUpdateSource.ghproxy ||
      normalized.startsWith(_ghproxyBaseUrl)) {
    return normalized;
  }

  final host = Uri.tryParse(normalized)?.host.toLowerCase();
  final isGitHubUrl =
      host == 'github.com' ||
      host?.endsWith('.github.com') == true ||
      host == 'githubusercontent.com' ||
      host?.endsWith('.githubusercontent.com') == true;
  return isGitHubUrl ? '$_ghproxyBaseUrl$normalized' : normalized;
}

class SoftwareUpdateService {
  SoftwareUpdateService();

  final HazukiNetworkClient _client = HazukiNetworkClient(
    dio: createHazukiDio(
      baseOptions: BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 3),
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    ),
  );

  Future<SoftwareUpdateCheckResult?> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final supportedAbis = await _resolveSupportedAbis();
    final source = await loadUpdateSource();
    final updateData = await _getJsonMap(resolveSoftwareUpdateCheckUrl(source));
    if (updateData == null) {
      return null;
    }

    if (source == SoftwareUpdateSource.github) {
      return _buildResultFromRelease(
        updateData,
        currentVersion: currentVersion,
        supportedAbis: supportedAbis,
        source: source,
      );
    }

    return _buildResultFromManifest(
      updateData,
      currentVersion: currentVersion,
      supportedAbis: supportedAbis,
      source: source,
    );
  }

  Future<SoftwareUpdateSource> loadUpdateSource() async {
    return loadSoftwareUpdateSourcePreference();
  }

  Future<void> setUpdateSource(SoftwareUpdateSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      hazukiSoftwareUpdateSourcePreferenceKey,
      source.preferenceValue,
    );
  }

  Future<Map<String, dynamic>?> _getJsonMap(String url) async {
    try {
      final response = await _client.get<String>(url);
      final body = response.data?.trim();
      if (body == null || body.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  SoftwareUpdateCheckResult? _buildResultFromManifest(
    Map<String, dynamic> manifest, {
    required String currentVersion,
    required List<String> supportedAbis,
    required SoftwareUpdateSource source,
  }) {
    final latestVersionRaw = manifest['version']?.toString().trim();
    final releaseUrl = manifest['releaseUrl']?.toString().trim();
    final apkUrl = resolveSoftwareUpdateDownloadUrl(
      _resolveManifestApkUrl(manifest, supportedAbis: supportedAbis),
      source,
    );
    final windowsExeUrl = resolveSoftwareUpdateDownloadUrl(
      _resolveManifestWindowsExeUrl(manifest),
      source,
    );
    final windowsZipUrl = resolveSoftwareUpdateDownloadUrl(
      _resolveManifestWindowsZipUrl(manifest),
      source,
    );
    final changelog = _normalizeChangelog(manifest['changelog']?.toString());

    if (latestVersionRaw == null ||
        latestVersionRaw.isEmpty ||
        releaseUrl == null ||
        releaseUrl.isEmpty) {
      return null;
    }

    final latestVersion = _normalizeVersion(latestVersionRaw);
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      apkUrl: apkUrl != null && apkUrl.isNotEmpty ? apkUrl : null,
      windowsUrl: windowsExeUrl ?? windowsZipUrl,
      windowsExeUrl: windowsExeUrl,
      windowsZipUrl: windowsZipUrl,
      changelog: changelog,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  SoftwareUpdateCheckResult? _buildResultFromRelease(
    Map<String, dynamic> release, {
    required String currentVersion,
    required List<String> supportedAbis,
    required SoftwareUpdateSource source,
  }) {
    final latestVersionRaw =
        release['tag_name']?.toString().trim().isNotEmpty == true
        ? release['tag_name'].toString().trim()
        : release['name']?.toString().trim();
    final releaseUrl = release['html_url']?.toString().trim();
    final changelog = _normalizeChangelog(release['body']?.toString());
    final assets = release['assets'];

    String? apkUrl;
    String? windowsExeUrl;
    String? windowsZipUrl;
    if (assets is List) {
      apkUrl = _selectBestApkUrlFromAssets(
        assets,
        supportedAbis: supportedAbis,
      );
      windowsExeUrl = _selectWindowsExeUrlFromAssets(assets);
      windowsZipUrl = _selectWindowsZipUrlFromAssets(assets);
    }
    apkUrl = resolveSoftwareUpdateDownloadUrl(apkUrl, source);
    windowsExeUrl = resolveSoftwareUpdateDownloadUrl(windowsExeUrl, source);
    windowsZipUrl = resolveSoftwareUpdateDownloadUrl(windowsZipUrl, source);

    if (latestVersionRaw == null ||
        latestVersionRaw.isEmpty ||
        releaseUrl == null ||
        releaseUrl.isEmpty) {
      return null;
    }

    final latestVersion = _normalizeVersion(latestVersionRaw);
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      apkUrl: apkUrl,
      windowsUrl: windowsExeUrl ?? windowsZipUrl,
      windowsExeUrl: windowsExeUrl,
      windowsZipUrl: windowsZipUrl,
      changelog: changelog,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  String _normalizeVersion(String version) => normalizeSoftwareVersion(version);

  String? _normalizeChangelog(String? changelog) {
    if (changelog == null) {
      return null;
    }
    final normalized = changelog.replaceAll('\r\n', '\n').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<List<String>> _resolveSupportedAbis() async {
    if (!Platform.isAndroid) {
      return const [];
    }
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.supportedAbis
          .map((abi) => abi.trim().toLowerCase())
          .where((abi) => abi.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _resolveManifestApkUrl(
    Map<String, dynamic> manifest, {
    required List<String> supportedAbis,
  }) {
    final apkUrlsRaw = manifest['apkUrls'];
    if (apkUrlsRaw is Map) {
      final apkUrls = <String, String>{};
      for (final entry in apkUrlsRaw.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        apkUrls[key] = value;
      }
      final selected = _selectBestApkUrlFromMap(
        apkUrls,
        supportedAbis: supportedAbis,
      );
      if (selected != null) {
        return selected;
      }
    }

    final legacyApkUrl = manifest['apkUrl']?.toString().trim();
    return legacyApkUrl != null && legacyApkUrl.isNotEmpty
        ? legacyApkUrl
        : null;
  }

  Map<String, String> _parseManifestWindowsUrls(Map<String, dynamic> manifest) {
    final windowsUrlsRaw = manifest['windowsUrls'];
    if (windowsUrlsRaw is! Map) return {};
    final result = <String, String>{};
    for (final entry in windowsUrlsRaw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }

  String? _resolveManifestWindowsExeUrl(Map<String, dynamic> manifest) {
    final urls = _parseManifestWindowsUrls(manifest);
    if (urls.isEmpty) return null;
    final arch = _resolveWindowsArch();
    if (arch != null) {
      final url = urls['${arch}_exe'];
      if (url != null && url.isNotEmpty) return url;
    }
    for (final a in _windowsArchPriority) {
      final url = urls['${a}_exe'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? _resolveManifestWindowsZipUrl(Map<String, dynamic> manifest) {
    final urls = _parseManifestWindowsUrls(manifest);
    if (urls.isEmpty) {
      final legacy = manifest['windowsUrl']?.toString().trim();
      return legacy != null && legacy.isNotEmpty ? legacy : null;
    }
    final arch = _resolveWindowsArch();
    if (arch != null) {
      final url = urls['${arch}_zip'];
      if (url != null && url.isNotEmpty) return url;
    }
    for (final a in _windowsArchPriority) {
      final url = urls['${a}_zip'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? _selectBestApkUrlFromAssets(
    List assets, {
    required List<String> supportedAbis,
  }) {
    final candidates = <String, String>{};
    String? fallback;
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(asset);
      final name = map['name']?.toString().trim().toLowerCase() ?? '';
      final url = map['browser_download_url']?.toString().trim();
      if (!name.endsWith('.apk') || url == null || url.isEmpty) {
        continue;
      }
      fallback ??= url;
      for (final abi in _apkAbiPriority) {
        if (name.contains(abi)) {
          candidates.putIfAbsent(abi, () => url);
        }
      }
      if (name.contains('universal')) {
        candidates.putIfAbsent('universal', () => url);
      }
    }
    return _selectBestApkUrlFromMap(candidates, supportedAbis: supportedAbis) ??
        fallback;
  }

  String? _selectWindowsExeUrlFromAssets(List assets) {
    for (final arch in _windowsArchPriority) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final map = Map<String, dynamic>.from(asset);
        final name = map['name']?.toString().trim().toLowerCase() ?? '';
        final url = map['browser_download_url']?.toString().trim();
        if (url == null || url.isEmpty) continue;
        if (name.endsWith('.exe') && name.contains(arch)) return url;
      }
    }
    return null;
  }

  String? _selectWindowsZipUrlFromAssets(List assets) {
    for (final arch in _windowsArchPriority) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final map = Map<String, dynamic>.from(asset);
        final name = map['name']?.toString().trim().toLowerCase() ?? '';
        final url = map['browser_download_url']?.toString().trim();
        if (url == null || url.isEmpty) continue;
        if (name.endsWith('.zip') && name.contains(arch)) return url;
      }
    }
    return null;
  }

  String? _selectBestApkUrlFromMap(
    Map<String, String> apkUrls, {
    required List<String> supportedAbis,
  }) {
    for (final abi in supportedAbis) {
      final direct = apkUrls[abi];
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
    }
    for (final abi in _apkAbiPriority) {
      if (supportedAbis.contains(abi)) {
        final matched = apkUrls[abi];
        if (matched != null && matched.isNotEmpty) {
          return matched;
        }
      }
    }
    for (final abi in _apkAbiPriority) {
      final matched = apkUrls[abi];
      if (matched != null && matched.isNotEmpty) {
        return matched;
      }
    }
    return apkUrls['universal'];
  }

  String? _resolveWindowsArch() {
    if (!Platform.isWindows) {
      return null;
    }

    final abiLabel = Abi.current().toString().toLowerCase();
    if (abiLabel.contains('arm64')) {
      return 'arm64';
    }
    if (abiLabel.contains('x64')) {
      return 'x64';
    }
    if (abiLabel.contains('ia32') || abiLabel.contains('x86')) {
      return 'x86';
    }

    final processArch = Platform.environment['PROCESSOR_ARCHITECTURE']
        ?.toLowerCase();
    if (processArch == 'amd64' || processArch == 'x86_64') {
      return 'x64';
    }
    if (processArch == 'arm64') {
      return 'arm64';
    }
    if (processArch == 'x86') {
      return 'x86';
    }
    return null;
  }

  static const List<String> _apkAbiPriority = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
    'x86',
  ];

  static const List<String> _windowsArchPriority = ['x64', 'arm64', 'x86'];

  bool _isVersionGreater(String a, String b) => isSoftwareVersionGreater(a, b);
}

class SoftwareUpdateCheckResult {
  const SoftwareUpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.hasUpdate,
    this.apkUrl,
    this.windowsUrl,
    this.windowsExeUrl,
    this.windowsZipUrl,
    this.changelog,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final String? windowsUrl;
  final String? windowsExeUrl;
  final String? windowsZipUrl;
  final String? changelog;
  final bool hasUpdate;

  SoftwareUpdateCheckResult copyWith({
    String? currentVersion,
    String? latestVersion,
    String? releaseUrl,
    String? apkUrl,
    String? windowsUrl,
    String? windowsExeUrl,
    String? windowsZipUrl,
    String? changelog,
    bool? hasUpdate,
  }) {
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseUrl: releaseUrl ?? this.releaseUrl,
      apkUrl: apkUrl ?? this.apkUrl,
      windowsUrl: windowsUrl ?? this.windowsUrl,
      windowsExeUrl: windowsExeUrl ?? this.windowsExeUrl,
      windowsZipUrl: windowsZipUrl ?? this.windowsZipUrl,
      changelog: changelog ?? this.changelog,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }
}
