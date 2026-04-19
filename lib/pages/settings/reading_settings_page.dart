import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import '../../widgets/widgets.dart';
import 'settings_group.dart';

class ReadingSettingsPage extends StatefulWidget {
  const ReadingSettingsPage({super.key});

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage> {
  static const _readerSettingsStore = ReaderSettingsStore();

  ReaderMode _readerMode = ReaderSettingsStore.defaultReaderMode;
  bool _doublePageMode = ReaderSettingsStore.defaultDoublePageMode;
  bool _tapToTurnPage = ReaderSettingsStore.defaultTapToTurnPage;
  bool _volumeButtonTurnPage = ReaderSettingsStore.defaultVolumeButtonTurnPage;
  bool _immersiveMode = ReaderSettingsStore.defaultImmersiveMode;
  bool _keepScreenOn = ReaderSettingsStore.defaultKeepScreenOn;
  bool _customBrightness = ReaderSettingsStore.defaultCustomBrightness;
  double _brightnessValue = ReaderSettingsStore.defaultBrightnessValue;
  bool _pageIndicator = ReaderSettingsStore.defaultPageIndicator;
  bool _pinchToZoom = ReaderSettingsStore.defaultPinchToZoom;
  bool _longPressToSave = ReaderSettingsStore.defaultLongPressToSave;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _readerSettingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _readerMode = settings.readerMode;
      _doublePageMode = settings.doublePageMode;
      _tapToTurnPage = settings.tapToTurnPage;
      _volumeButtonTurnPage = settings.volumeButtonTurnPage;
      _immersiveMode = settings.immersiveMode;
      _keepScreenOn = settings.keepScreenOn;
      _customBrightness = settings.customBrightness;
      _brightnessValue = settings.brightnessValue;
      _pageIndicator = settings.pageIndicator;
      _pinchToZoom = settings.pinchToZoom;
      _longPressToSave = settings.longPressToSave;
    });
  }

  Future<void> _updateReaderMode(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    setState(() {
      _readerMode = value;
    });
    await _readerSettingsStore.saveReaderMode(value);
  }

  Future<void> _toggleTapToTurnPage(bool value) async {
    setState(() => _tapToTurnPage = value);
    await _readerSettingsStore.saveTapToTurnPage(value);
  }

  Future<void> _toggleDoublePageMode(bool value) async {
    setState(() => _doublePageMode = value);
    await _readerSettingsStore.saveDoublePageMode(value);
  }

  Future<void> _toggleVolumeButtonTurnPage(bool value) async {
    setState(() => _volumeButtonTurnPage = value);
    await _readerSettingsStore.saveVolumeButtonTurnPage(value);
  }

  Future<void> _toggleImmersiveMode(bool value) async {
    setState(() => _immersiveMode = value);
    await _readerSettingsStore.saveImmersiveMode(value);
  }

  Future<void> _toggleKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    await _readerSettingsStore.saveKeepScreenOn(value);
  }

  Future<void> _toggleCustomBrightness(bool value) async {
    setState(() => _customBrightness = value);
    await _readerSettingsStore.saveCustomBrightness(value);
  }

  Future<void> _updateBrightness(double value) async {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    setState(() => _brightnessValue = normalized);
    await _readerSettingsStore.saveBrightnessValue(normalized);
  }

  Future<void> _togglePageIndicator(bool value) async {
    setState(() => _pageIndicator = value);
    await _readerSettingsStore.savePageIndicator(value);
  }

  Future<void> _togglePinchToZoom(bool value) async {
    setState(() => _pinchToZoom = value);
    await _readerSettingsStore.savePinchToZoom(value);
  }

  Future<void> _toggleLongPressToSave(bool value) async {
    setState(() => _longPressToSave = value);
    await _readerSettingsStore.saveLongPressToSave(value);
  }

  Widget _buildGroup(BuildContext context, {required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final brightnessText = (_brightnessValue * 100).round().toString();
    final sliderActiveColor = Theme.of(context).colorScheme.primary;
    final sliderInactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.24);

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.readingSettingsTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildGroup(
              context,
              children: [
                ListTile(
                  leading: const Icon(Icons.chrome_reader_mode_outlined),
                  title: Text(strings.readingModeTitle),
                  subtitle: Text(strings.readingModeSubtitle),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ReaderMode>(
                      value: _readerMode,
                      borderRadius: BorderRadius.circular(18),
                      onChanged: _updateReaderMode,
                      items: [
                        DropdownMenuItem(
                          value: ReaderMode.topToBottom,
                          child: Text(strings.readingModeTopToBottom),
                        ),
                        DropdownMenuItem(
                          value: ReaderMode.rightToLeft,
                          child: Text(strings.readingModeRightToLeft),
                        ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_stories_outlined),
                  title: Text(strings.readingDoublePageModeTitle),
                  subtitle: Text(strings.readingDoublePageModeSubtitle),
                  value: _doublePageMode,
                  onChanged: _toggleDoublePageMode,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.touch_app_outlined),
                  title: Text(strings.readingTapToTurnPageTitle),
                  subtitle: Text(strings.readingTapToTurnPageSubtitle),
                  value: _tapToTurnPage,
                  onChanged: _readerMode == ReaderMode.rightToLeft
                      ? _toggleTapToTurnPage
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: Text(strings.readingVolumeButtonTurnPageTitle),
                  subtitle: Text(strings.readingVolumeButtonTurnPageSubtitle),
                  value: _volumeButtonTurnPage,
                  onChanged: _toggleVolumeButtonTurnPage,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.zoom_in_outlined),
                  title: Text(strings.readingPinchToZoomTitle),
                  subtitle: Text(strings.readingPinchToZoomSubtitle),
                  value: _pinchToZoom,
                  onChanged: _togglePinchToZoom,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.save_alt_outlined),
                  title: Text(strings.readingLongPressSaveTitle),
                  subtitle: Text(strings.readingLongPressSaveSubtitle),
                  value: _longPressToSave,
                  onChanged: _toggleLongPressToSave,
                ),
              ],
            ),
            _buildGroup(
              context,
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fullscreen_outlined),
                  title: Text(strings.readingImmersiveModeTitle),
                  subtitle: Text(strings.readingImmersiveModeSubtitle),
                  value: _immersiveMode,
                  onChanged: _toggleImmersiveMode,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.screen_lock_portrait_outlined),
                  title: Text(strings.readingKeepScreenOnTitle),
                  subtitle: Text(strings.readingKeepScreenOnSubtitle),
                  value: _keepScreenOn,
                  onChanged: _toggleKeepScreenOn,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_list_numbered_outlined),
                  title: Text(strings.readingPageIndicatorTitle),
                  subtitle: Text(strings.readingPageIndicatorSubtitle),
                  value: _pageIndicator,
                  onChanged: _togglePageIndicator,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.brightness_medium_outlined),
                  title: Text(strings.readingCustomBrightnessTitle),
                  subtitle: Text(strings.readingCustomBrightnessSubtitle),
                  value: _customBrightness,
                  onChanged: _toggleCustomBrightness,
                ),
                ListTile(
                  leading: Icon(
                    Icons.wb_sunny_outlined,
                    color: _customBrightness
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  title: Text(
                    strings.readingBrightnessLabel(brightnessText),
                    style: TextStyle(
                      color: _customBrightness
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                  subtitle: Slider(
                    value: _brightnessValue,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    onChanged: _customBrightness ? _updateBrightness : null,
                    activeColor: sliderActiveColor,
                    inactiveColor: sliderInactiveColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
