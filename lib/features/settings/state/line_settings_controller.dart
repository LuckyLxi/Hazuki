import 'package:flutter/foundation.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class LineSettingsController extends ChangeNotifier {
  LineSettingsController({required SourceSettingsGateway sourceService})
    : _sourceService = sourceService;

  final SourceSettingsGateway _sourceService;

  bool _loading = true;
  bool _refreshingStatus = false;

  String _selectedApiDomain = '1';
  String _selectedImageStream = '1';
  String _copyMangaRegion = '0';
  String _copyMangaBaseUrl = 'api.copy2000.online';
  String _copyMangaSearchApi = 'baseAPI';
  String _picacgBaseUrl = 'https://picaapi.picacomic.com';
  String _picacgAppChannel = '3';
  bool _refreshDomainsOnStart = true;

  List<String> _apiDomains = const [];
  int _imageStreamCount = 4;
  String _currentImageHost = '';

  bool _disposed = false;

  bool get loading => _loading;
  bool get refreshingStatus => _refreshingStatus;
  bool get isCopyMangaSource => _sourceService.isActiveCopyMangaSource;
  bool get isPicacgSource =>
      isHazukiPicacgSourceKey(_sourceService.activeSourceKey);
  String get selectedApiDomain => _selectedApiDomain;
  String get selectedImageStream => _selectedImageStream;
  String get copyMangaRegion => _copyMangaRegion;
  String get copyMangaBaseUrl => _copyMangaBaseUrl;
  String get copyMangaSearchApi => _copyMangaSearchApi;
  String get picacgBaseUrl => _picacgBaseUrl;
  String get picacgAppChannel => _picacgAppChannel;
  bool get refreshDomainsOnStart => _refreshDomainsOnStart;
  List<String> get apiDomains => _apiDomains;
  int get imageStreamCount => _imageStreamCount;
  String get currentImageHost => _currentImageHost;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadSnapshot({bool showLoading = true}) async {
    if (_disposed) return;
    if (showLoading) {
      _loading = true;
      _notify();
    }

    try {
      if (_sourceService.isActiveCopyMangaSource) {
        final region =
            _sourceService.loadActiveSourceSetting('region')?.toString() ?? '0';
        _copyMangaRegion = {'0', '1'}.contains(region) ? region : '0';
        final baseUrl =
            _sourceService.loadActiveSourceSetting('base_url')?.toString() ??
            'api.copy2000.online';
        _copyMangaBaseUrl = baseUrl.trim().isEmpty
            ? 'api.copy2000.online'
            : baseUrl.trim();
        final searchApi =
            _sourceService.loadActiveSourceSetting('search_api')?.toString() ??
            'baseAPI';
        _copyMangaSearchApi = {'baseAPI', 'webAPI'}.contains(searchApi)
            ? searchApi
            : 'baseAPI';
        return;
      }
      if (isPicacgSource) {
        final baseUrl =
            _sourceService.loadActiveSourceSetting('base_url')?.toString() ??
            'https://picaapi.picacomic.com';
        _picacgBaseUrl = baseUrl.trim().isEmpty
            ? 'https://picaapi.picacomic.com'
            : baseUrl.trim();
        final appChannel =
            _sourceService.loadActiveSourceSetting('appChannel')?.toString() ??
            '3';
        _picacgAppChannel = {'1', '2', '3'}.contains(appChannel)
            ? appChannel
            : '3';
        return;
      }

      final snapshot = await _sourceService.getLineSettingsSnapshot().timeout(
        const Duration(seconds: 20),
      );
      if (_disposed) return;

      final apiDomainsRaw = snapshot['apiDomains'];
      final apiDomains = <String>[];
      if (apiDomainsRaw is List) {
        for (final item in apiDomainsRaw) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            apiDomains.add(text);
          }
        }
      }

      final imageCountRaw = snapshot['imageStreamOptionsCount'];
      final parsedImageCount = switch (imageCountRaw) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(imageCountRaw?.toString() ?? ''),
      };

      final apiCount = apiDomains.isEmpty ? 4 : apiDomains.length;
      var selectedApi = snapshot['apiDomain']?.toString() ?? '1';
      final selectedApiInt = int.tryParse(selectedApi);
      if (selectedApiInt == null ||
          selectedApiInt < 1 ||
          selectedApiInt > apiCount) {
        selectedApi = '1';
      }

      final imageCount = (parsedImageCount ?? 4).clamp(1, 8);
      var selectedImage = snapshot['imageStream']?.toString() ?? '1';
      final selectedImageInt = int.tryParse(selectedImage);
      if (selectedImageInt == null ||
          selectedImageInt < 1 ||
          selectedImageInt > imageCount) {
        selectedImage = '1';
      }

      _selectedApiDomain = selectedApi;
      _selectedImageStream = selectedImage;
      _refreshDomainsOnStart = snapshot['refreshDomainsOnStart'] == true;
      _apiDomains = apiDomains;
      _imageStreamCount = imageCount;
      _currentImageHost = snapshot['imageHost']?.toString() ?? '';
    } finally {
      if (!_disposed && showLoading) {
        _loading = false;
      }
      _notify();
    }
  }

  Future<void> refreshLineStatus() async {
    if (_disposed || _refreshingStatus) return;
    if (_sourceService.isActiveCopyMangaSource) return;
    _refreshingStatus = true;
    _notify();
    try {
      await _sourceService.refreshLines();
      await loadSnapshot(showLoading: false);
    } finally {
      if (!_disposed) {
        _refreshingStatus = false;
        _notify();
      }
    }
  }

  Future<void> setApiDomain(String value) async {
    if (value == _selectedApiDomain) return;
    _selectedApiDomain = value;
    _notify();
    await _sourceService.updateLineSetting('apiDomain', value);
    await _sourceService.refreshLines(
      refreshApiDomains: false,
      refreshImageHost: false,
    );
  }

  Future<void> setCopyMangaRegion(String value) async {
    if (value == _copyMangaRegion) return;
    _copyMangaRegion = value;
    _notify();
    await _sourceService.updateActiveSourceSetting('region', value);
  }

  Future<void> setCopyMangaBaseUrl(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == _copyMangaBaseUrl) return;
    _copyMangaBaseUrl = normalized;
    _notify();
    await _sourceService.updateActiveSourceSetting('base_url', normalized);
  }

  Future<void> setCopyMangaSearchApi(String value) async {
    final normalized = {'baseAPI', 'webAPI'}.contains(value)
        ? value
        : 'baseAPI';
    if (normalized == _copyMangaSearchApi) return;
    _copyMangaSearchApi = normalized;
    _notify();
    await _sourceService.updateActiveSourceSetting('search_api', normalized);
  }

  Future<void> setPicacgBaseUrl(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == _picacgBaseUrl) return;
    _picacgBaseUrl = normalized;
    _notify();
    await _sourceService.updateActiveSourceSetting('base_url', normalized);
  }

  Future<void> setPicacgAppChannel(String value) async {
    final normalized = {'1', '2', '3'}.contains(value) ? value : '3';
    if (normalized == _picacgAppChannel) return;
    _picacgAppChannel = normalized;
    _notify();
    await _sourceService.updateActiveSourceSetting('appChannel', normalized);
  }

  Future<void> setImageStream(String value) async {
    if (value == _selectedImageStream) return;
    _selectedImageStream = value;
    _notify();
    await _sourceService.updateLineSetting('imageStream', value);
    await _sourceService.refreshLines(
      refreshApiDomains: false,
      refreshImageHost: true,
    );
    await loadSnapshot();
  }

  Future<void> setRefreshDomainsOnStart(bool value) async {
    _refreshDomainsOnStart = value;
    _notify();
    await _sourceService.updateLineSetting('refreshDomainsOnStart', value);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
