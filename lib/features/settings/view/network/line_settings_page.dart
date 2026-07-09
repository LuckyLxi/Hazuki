import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/features/settings/state/line_settings_controller.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

class LineSettingsPage extends StatefulWidget {
  const LineSettingsPage({super.key});

  @override
  State<LineSettingsPage> createState() => _LineSettingsPageState();
}

class _LineSettingsPageState extends State<LineSettingsPage> {
  late final LineSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LineSettingsController(
      sourceService: sl<SourceSettingsGateway>(),
    );
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      await _controller.loadSnapshot();
    } catch (e) {
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineLoadFailed('$e'), isError: true),
      );
    }
  }

  Future<void> _refreshLineStatus() async {
    try {
      await _controller.refreshLineStatus();
    } catch (e) {
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineLoadFailed('$e'), isError: true),
      );
    }
  }

  List<DropdownMenuItem<String>> _buildApiItems(BuildContext context) {
    final strings = l10n(context);
    final items = <DropdownMenuItem<String>>[];
    final domains = _controller.apiDomains;
    final count = domains.isEmpty ? 4 : domains.length;
    for (var i = 1; i <= count; i++) {
      final value = '$i';
      final host = i - 1 < domains.length ? domains[i - 1] : '';
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
    for (var i = 1; i <= _controller.imageStreamCount; i++) {
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

  List<DropdownMenuItem<String>> _buildCopyMangaRegionItems(
    BuildContext context,
  ) {
    final strings = l10n(context);
    return [
      DropdownMenuItem<String>(
        value: '1',
        child: Text(strings.lineCopyMangaRegionMainland),
      ),
      DropdownMenuItem<String>(
        value: '0',
        child: Text(strings.lineCopyMangaRegionOverseas),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _buildCopyMangaSearchApiItems(
    BuildContext context,
  ) {
    final strings = l10n(context);
    return [
      DropdownMenuItem<String>(
        value: 'baseAPI',
        child: Text(strings.lineCopyMangaSearchApiBase),
      ),
      DropdownMenuItem<String>(
        value: 'webAPI',
        child: Text(strings.lineCopyMangaSearchApiWeb),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _buildPicacgAppChannelItems(
    BuildContext context,
  ) {
    final strings = l10n(context);
    return [
      DropdownMenuItem<String>(
        value: '1',
        child: Text(strings.linePicacgAppChannelLabel('1')),
      ),
      DropdownMenuItem<String>(
        value: '2',
        child: Text(strings.linePicacgAppChannelLabel('2')),
      ),
      DropdownMenuItem<String>(
        value: '3',
        child: Text(strings.linePicacgAppChannelLabel('3')),
      ),
    ];
  }

  Future<void> _onApiChanged(String? value) async {
    if (value == null || value == _controller.selectedApiDomain) {
      return;
    }
    try {
      await _controller.setApiDomain(value);
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineApiSwitched(value)));
    } catch (e) {
      if (!mounted) return;
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
    if (value == null || value == _controller.selectedImageStream) {
      return;
    }
    try {
      await _controller.setImageStream(value);
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineImageSwitched(value)));
    } catch (e) {
      if (!mounted) return;
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
    try {
      await _controller.setRefreshDomainsOnStart(value);
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(showHazukiPrompt(context, strings.lineRefreshOnStartUpdated));
    } catch (e) {
      if (!mounted) return;
      final strings = l10n(context);
      unawaited(
        showHazukiPrompt(context, strings.lineSaveFailed('$e'), isError: true),
      );
    }
  }

  Future<void> _onCopyMangaRegionChanged(String? value) async {
    if (value == null || value == _controller.copyMangaRegion) {
      return;
    }
    try {
      await _controller.setCopyMangaRegion(value);
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, l10n(context).lineCopyMangaUpdated));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).lineSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _onCopyMangaSearchApiChanged(String? value) async {
    if (value == null || value == _controller.copyMangaSearchApi) {
      return;
    }
    try {
      await _controller.setCopyMangaSearchApi(value);
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, l10n(context).lineCopyMangaUpdated));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).lineSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _onPicacgAppChannelChanged(String? value) async {
    if (value == null || value == _controller.picacgAppChannel) {
      return;
    }
    try {
      await _controller.setPicacgAppChannel(value);
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, l10n(context).linePicacgUpdated));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).lineSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _editCopyMangaBaseUrl() async {
    final strings = l10n(context);
    final controller = TextEditingController(
      text: _controller.copyMangaBaseUrl,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.lineCopyMangaBaseUrlTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: strings.lineCopyMangaBaseUrlLabel,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(strings.commonSave),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    try {
      await _controller.setCopyMangaBaseUrl(normalized);
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, strings.lineCopyMangaUpdated));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(context, strings.lineSaveFailed('$e'), isError: true),
      );
    }
  }

  Future<void> _editPicacgBaseUrl() async {
    final strings = l10n(context);
    final controller = TextEditingController(text: _controller.picacgBaseUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.linePicacgBaseUrlTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: strings.linePicacgBaseUrlLabel,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(strings.commonSave),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    try {
      await _controller.setPicacgBaseUrl(normalized);
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, strings.linePicacgUpdated));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(context, strings.lineSaveFailed('$e'), isError: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.loading) {
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
          body: _controller.isCopyMangaSource
              ? _buildCopyMangaBody(context, colorScheme)
              : _controller.isPicacgSource
              ? _buildPicacgBody(context, colorScheme)
              : _buildJmBody(context, colorScheme),
        );
      },
    );
  }

  Widget _buildPicacgBody(BuildContext context, ColorScheme colorScheme) {
    final strings = l10n(context);
    return ListView(
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
                  strings.linePicacgIntro,
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
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
                  leading: const Icon(Icons.alt_route_outlined),
                  title: Text(strings.linePicacgAppChannelTitle),
                  subtitle: Text(strings.linePicacgAppChannelSubtitle),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _controller.picacgAppChannel,
                  items: _buildPicacgAppChannelItems(context),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: strings.linePicacgAppChannelSelectLabel,
                    isDense: true,
                  ),
                  onChanged: _onPicacgAppChannelChanged,
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
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(strings.linePicacgBaseUrlTitle),
            subtitle: Text(_controller.picacgBaseUrl),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => unawaited(_editPicacgBaseUrl()),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyMangaBody(BuildContext context, ColorScheme colorScheme) {
    final strings = l10n(context);
    return ListView(
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
                  strings.lineCopyMangaIntro,
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
                  leading: const Icon(Icons.public_outlined),
                  title: Text(strings.lineCopyMangaRegionTitle),
                  subtitle: Text(strings.lineCopyMangaRegionSubtitle),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _controller.copyMangaRegion,
                  items: _buildCopyMangaRegionItems(context),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: strings.lineCopyMangaRegionLabel,
                    isDense: true,
                  ),
                  onChanged: _onCopyMangaRegionChanged,
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
                  leading: const Icon(Icons.manage_search_outlined),
                  title: Text(strings.lineCopyMangaSearchApiTitle),
                  subtitle: Text(strings.lineCopyMangaSearchApiSubtitle),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _controller.copyMangaSearchApi,
                  items: _buildCopyMangaSearchApiItems(context),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: strings.lineCopyMangaSearchApiLabel,
                    isDense: true,
                  ),
                  onChanged: _onCopyMangaSearchApiChanged,
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
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(strings.lineCopyMangaBaseUrlTitle),
            subtitle: Text(_controller.copyMangaBaseUrl),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => unawaited(_editCopyMangaBaseUrl()),
          ),
        ),
      ],
    );
  }

  Widget _buildJmBody(BuildContext context, ColorScheme colorScheme) {
    final strings = l10n(context);
    return ListView(
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
                  initialValue: _controller.selectedApiDomain,
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
                    _controller.currentImageHost.trim().isEmpty
                        ? strings.lineImageHostUnavailable
                        : strings.lineImageHostCurrent(
                            _controller.currentImageHost,
                          ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _controller.selectedImageStream,
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
                value: _controller.refreshDomainsOnStart,
                onChanged: _onRefreshDomainsOnStartChanged,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _controller.refreshingStatus
                        ? null
                        : _refreshLineStatus,
                    icon: _controller.refreshingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _controller.refreshingStatus
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
    );
  }
}
