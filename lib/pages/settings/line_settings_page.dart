part of '../../main.dart';

class LineSettingsPage extends StatefulWidget {
  const LineSettingsPage({super.key});

  @override
  State<LineSettingsPage> createState() => _LineSettingsPageState();
}

class _LineSettingsPageState extends State<LineSettingsPage> {
  bool _loading = true;

  String _selectedApiDomain = '1';
  String _selectedImageStream = '1';
  bool _refreshDomainsOnStart = true;

  List<String> _apiDomains = const [];
  int _imageStreamCount = 4;
  String _currentImageHost = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSnapshot());
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
    });

    try {
      final snapshot = await HazukiSourceService.instance
          .getLineSettingsSnapshot()
          .timeout(const Duration(seconds: 20));

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
      if (selectedApiInt == null || selectedApiInt < 1 || selectedApiInt > apiCount) {
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

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedApiDomain = selectedApi;
        _selectedImageStream = selectedImage;
        _refreshDomainsOnStart = snapshot['refreshDomainsOnStart'] == true;
        _apiDomains = apiDomains;
        _imageStreamCount = imageCount;
        _currentImageHost = snapshot['imageHost']?.toString() ?? '';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('线路信息加载失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<DropdownMenuItem<String>> _buildApiItems() {
    final items = <DropdownMenuItem<String>>[];
    final count = _apiDomains.isEmpty ? 4 : _apiDomains.length;
    for (var i = 1; i <= count; i++) {
      final value = '$i';
      final host = i - 1 < _apiDomains.length ? _apiDomains[i - 1] : '';
      items.add(
        DropdownMenuItem<String>(
          value: value,
          child: Text(host.isEmpty ? '线路$value' : '线路$value  ($host)'),
        ),
      );
    }
    return items;
  }

  List<DropdownMenuItem<String>> _buildImageItems() {
    final items = <DropdownMenuItem<String>>[];
    for (var i = 1; i <= _imageStreamCount; i++) {
      final value = '$i';
      items.add(DropdownMenuItem<String>(value: value, child: Text('分流$value')));
    }
    return items;
  }

  Future<void> _onApiChanged(String? value) async {
    if (value == null || value == _selectedApiDomain) {
      return;
    }
    setState(() {
      _selectedApiDomain = value;
    });

    try {
      await HazukiSourceService.instance.updateLineSetting('apiDomain', value);
      await HazukiSourceService.instance.refreshLines(
        refreshApiDomains: false,
        refreshImageHost: false,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('API 域名分流已切到线路$value')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切换失败: $e')));
    }
  }

  Future<void> _onImageStreamChanged(String? value) async {
    if (value == null || value == _selectedImageStream) {
      return;
    }
    setState(() {
      _selectedImageStream = value;
    });

    try {
      await HazukiSourceService.instance.updateLineSetting('imageStream', value);
      await HazukiSourceService.instance.refreshLines(
        refreshApiDomains: false,
        refreshImageHost: true,
      );
      await _loadSnapshot();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片域名分流已切到分流$value')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切换失败: $e')));
    }
  }

  Future<void> _onRefreshDomainsOnStartChanged(bool value) async {
    setState(() {
      _refreshDomainsOnStart = value;
    });

    try {
      await HazukiSourceService.instance.updateLineSetting(
        'refreshDomainsOnStart',
        value,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新启动自动刷新设置')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: hazukiFrostedAppBar(context: context, title: const Text('线路')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('线路')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_outlined, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '你可以分别切换 API 与图片分流，切换后会自动应用到后续请求。',
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('API 域名分流'),
                    subtitle: const Text('用于接口请求，建议网络异常时切换'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedApiDomain,
                    items: _buildApiItems(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '选择 API 线路',
                      isDense: true,
                    ),
                    onChanged: _onApiChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('图片域名分流'),
                    subtitle: Text(
                      _currentImageHost.trim().isEmpty
                          ? '当前未获取到图片域名'
                          : '当前域名：$_currentImageHost',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedImageStream,
                    items: _buildImageItems(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '选择图片分流',
                      isDense: true,
                    ),
                    onChanged: _onImageStreamChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: const Text('启动时刷新域名列表'),
                  subtitle: const Text('每次打开应用时自动更新 API 域名池'),
                  value: _refreshDomainsOnStart,
                  onChanged: _onRefreshDomainsOnStartChanged,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _loadSnapshot,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新线路状态'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
