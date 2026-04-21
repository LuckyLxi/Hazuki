import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

class LineSettingsPage extends StatefulWidget {
  const LineSettingsPage({super.key});

  @override
  State<LineSettingsPage> createState() => _LineSettingsPageState();
}

class _LineSettingsPageState extends State<LineSettingsPage> {
  bool _loading = true;
  bool _refreshingStatus = false;

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

  Future<void> _loadSnapshot({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
      });
    }

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
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineLoadFailed('$e'), isError: true),
      );
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshLineStatus() async {
    if (_refreshingStatus) {
      return;
    }

    setState(() {
      _refreshingStatus = true;
    });

    try {
      await HazukiSourceService.instance.refreshLines();
      await _loadSnapshot(showLoading: false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineLoadFailed('$e'), isError: true),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingStatus = false;
        });
      }
    }
  }

  List<DropdownMenuItem<String>> _buildApiItems(BuildContext context) {
    final strings = l10n(context);
    final items = <DropdownMenuItem<String>>[];
    final count = _apiDomains.isEmpty ? 4 : _apiDomains.length;
    for (var i = 1; i <= count; i++) {
      final value = '$i';
      final host = i - 1 < _apiDomains.length ? _apiDomains[i - 1] : '';
      items.add(
        DropdownMenuItem<String>(
          value: value,
          child: Text(
            host.isEmpty
                ? strings.lineOptionLabel(value)
                : strings.lineOptionWithHostLabel(value, host),
          ),
        ),
      );
    }
    return items;
  }

  List<DropdownMenuItem<String>> _buildImageItems(BuildContext context) {
    final strings = l10n(context);
    final items = <DropdownMenuItem<String>>[];
    for (var i = 1; i <= _imageStreamCount; i++) {
      final value = '$i';
      items.add(
        DropdownMenuItem<String>(
          value: value,
          child: Text(strings.lineImageStreamLabel(value)),
        ),
      );
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
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineApiSwitched(value)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(
          context,
          strings.lineSwitchFailed('$e'),
          isError: true,
        ),
      );
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
      await HazukiSourceService.instance.updateLineSetting(
        'imageStream',
        value,
      );
      await HazukiSourceService.instance.refreshLines(
        refreshApiDomains: false,
        refreshImageHost: true,
      );
      await _loadSnapshot();
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineImageSwitched(value)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(
          context,
          strings.lineSwitchFailed('$e'),
          isError: true,
        ),
      );
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
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineRefreshOnStartUpdated));
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineSaveFailed('$e'), isError: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.lineSettingsTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.lineSettingsTitle),
      ),
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
                Icon(
                  Icons.route_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.lineIntro,
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
                    title: Text(strings.lineApiTitle),
                    subtitle: Text(strings.lineApiSubtitle),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedApiDomain,
                    items: _buildApiItems(context),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: strings.lineSelectApiLabel,
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
                    title: Text(strings.lineImageTitle),
                    subtitle: Text(
                      _currentImageHost.trim().isEmpty
                          ? strings.lineImageHostUnavailable
                          : strings.lineImageHostCurrent(_currentImageHost),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedImageStream,
                    items: _buildImageItems(context),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: strings.lineSelectImageLabel,
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
                  title: Text(strings.lineRefreshOnStartTitle),
                  subtitle: Text(strings.lineRefreshOnStartSubtitle),
                  value: _refreshDomainsOnStart,
                  onChanged: _onRefreshDomainsOnStartChanged,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _refreshingStatus ? null : _refreshLineStatus,
                      icon: _refreshingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _refreshingStatus
                            ? strings.commonLoading
                            : strings.lineRefreshStatusButton,
                      ),
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
