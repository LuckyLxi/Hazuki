import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SoftwareUpdateService {
  SoftwareUpdateService._();

  static final SoftwareUpdateService instance = SoftwareUpdateService._();

  static const _updateManifestUrls = [
    'https://fastly.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://gcore.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/update.json',
  ];

  static const _latestReleaseUrl =
      'https://api.github.com/repos/LuckyLxi/Hazuki/releases/latest';

  final Dio _dio = Dio(
    BaseOptions(
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
  );

  Future<SoftwareUpdateCheckResult?> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final supportedAbis = await _resolveSupportedAbis();

    final manifestData = await _loadUpdateManifest();
    if (manifestData != null) {
      final manifestResult = _buildResultFromManifest(
        manifestData,
        currentVersion: currentVersion,
        supportedAbis: supportedAbis,
      );
      if (manifestResult != null) {
        if (manifestResult.hasUpdate && manifestResult.changelog == null) {
          final releaseData = await _loadLatestReleaseFromGitHubApi();
          if (releaseData != null) {
            final releaseResult = _buildResultFromRelease(
              releaseData,
              currentVersion: currentVersion,
              supportedAbis: supportedAbis,
            );
            if (releaseResult != null &&
                releaseResult.latestVersion == manifestResult.latestVersion &&
                releaseResult.changelog != null) {
              return manifestResult.copyWith(
                changelog: releaseResult.changelog,
              );
            }
          }
        }
        return manifestResult;
      }
    }

    final releaseData = await _loadLatestReleaseFromGitHubApi();
    if (releaseData == null) {
      return null;
    }

    return _buildResultFromRelease(
      releaseData,
      currentVersion: currentVersion,
      supportedAbis: supportedAbis,
    );
  }

  Future<Map<String, dynamic>?> _loadUpdateManifest() async {
    for (final url in _updateManifestUrls) {
      final jsonMap = await _getJsonMap(url);
      if (jsonMap != null) {
        return jsonMap;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadLatestReleaseFromGitHubApi() async {
    return _getJsonMap(_latestReleaseUrl);
  }

  Future<Map<String, dynamic>?> _getJsonMap(String url) async {
    try {
      final response = await _dio.get<String>(url);
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
  }) {
    final latestVersionRaw = manifest['version']?.toString().trim();
    final releaseUrl = manifest['releaseUrl']?.toString().trim();
    final apkUrl = _resolveManifestApkUrl(
      manifest,
      supportedAbis: supportedAbis,
    );
    final windowsUrl = _resolveManifestWindowsUrl(manifest);
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
      windowsUrl: windowsUrl != null && windowsUrl.isNotEmpty
          ? windowsUrl
          : null,
      changelog: changelog,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  SoftwareUpdateCheckResult? _buildResultFromRelease(
    Map<String, dynamic> release, {
    required String currentVersion,
    required List<String> supportedAbis,
  }) {
    final latestVersionRaw =
        release['tag_name']?.toString().trim().isNotEmpty == true
        ? release['tag_name'].toString().trim()
        : release['name']?.toString().trim();
    final releaseUrl = release['html_url']?.toString().trim();
    final changelog = _normalizeChangelog(release['body']?.toString());
    final assets = release['assets'];

    String? apkUrl;
    String? windowsUrl;
    if (assets is List) {
      apkUrl = _selectBestApkUrlFromAssets(
        assets,
        supportedAbis: supportedAbis,
      );
      windowsUrl = _selectBestWindowsUrlFromAssets(assets);
    }

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
      windowsUrl: windowsUrl,
      changelog: changelog,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  String _normalizeVersion(String version) {
    return version.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

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

  String? _resolveManifestWindowsUrl(Map<String, dynamic> manifest) {
    final windowsUrlsRaw = manifest['windowsUrls'];
    if (windowsUrlsRaw is! Map) {
      final legacyWindowsUrl = manifest['windowsUrl']?.toString().trim();
      return legacyWindowsUrl != null && legacyWindowsUrl.isNotEmpty
          ? legacyWindowsUrl
          : null;
    }

    final windowsUrls = <String, String>{};
    for (final entry in windowsUrlsRaw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      windowsUrls[key] = value;
    }

    return _selectBestWindowsUrlFromMap(windowsUrls);
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

  String? _selectBestWindowsUrlFromAssets(List assets) {
    final candidates = <String, String>{};
    String? fallback;
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(asset);
      final name = map['name']?.toString().trim().toLowerCase() ?? '';
      final url = map['browser_download_url']?.toString().trim();
      final isWindowsPackage =
          name.endsWith('.zip') ||
          name.endsWith('.msi') ||
          name.endsWith('.exe') ||
          name.endsWith('.msix') ||
          name.endsWith('.msixbundle');
      if (!isWindowsPackage || url == null || url.isEmpty) {
        continue;
      }
      fallback ??= url;
      for (final arch in _windowsArchPriority) {
        if (name.contains(arch)) {
          candidates.putIfAbsent(arch, () => url);
        }
      }
    }
    return _selectBestWindowsUrlFromMap(candidates) ?? fallback;
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

  String? _selectBestWindowsUrlFromMap(Map<String, String> windowsUrls) {
    final currentArch = _resolveWindowsArch();
    if (currentArch != null) {
      final direct = windowsUrls[currentArch];
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
    }

    for (final arch in _windowsArchPriority) {
      final matched = windowsUrls[arch];
      if (matched != null && matched.isNotEmpty) {
        return matched;
      }
    }
    return null;
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

  bool _isVersionGreater(String a, String b) {
    final pa = _parseVersionSegments(a);
    final pb = _parseVersionSegments(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) {
        return true;
      }
      if (va < vb) {
        return false;
      }
    }
    return false;
  }

  List<int> _parseVersionSegments(String version) {
    final cleaned = version.trim().split('+').first.split('-').first;
    return cleaned.split('.').map((segment) {
      final match = RegExp(r'\d+').firstMatch(segment);
      return int.tryParse(match?.group(0) ?? '0') ?? 0;
    }).toList();
  }
}

class SoftwareUpdateCheckResult {
  const SoftwareUpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.hasUpdate,
    this.apkUrl,
    this.windowsUrl,
    this.changelog,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final String? windowsUrl;
  final String? changelog;
  final bool hasUpdate;

  SoftwareUpdateCheckResult copyWith({
    String? currentVersion,
    String? latestVersion,
    String? releaseUrl,
    String? apkUrl,
    String? windowsUrl,
    String? changelog,
    bool? hasUpdate,
  }) {
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseUrl: releaseUrl ?? this.releaseUrl,
      apkUrl: apkUrl ?? this.apkUrl,
      windowsUrl: windowsUrl ?? this.windowsUrl,
      changelog: changelog ?? this.changelog,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }
}
