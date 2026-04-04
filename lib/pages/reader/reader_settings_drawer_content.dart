import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'reader.dart';

class ReaderSettingsGroup extends StatelessWidget {
  const ReaderSettingsGroup({
    super.key,
    required this.theme,
    required this.children,
  });

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
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
}

class ReaderSettingsDrawerContent extends StatelessWidget {
  const ReaderSettingsDrawerContent({
    super.key,
    required this.readerMode,
    required this.doublePageMode,
    required this.tapToTurnPage,
    required this.volumeButtonTurnPage,
    required this.pinchToZoom,
    required this.longPressToSave,
    required this.immersiveMode,
    required this.keepScreenOn,
    required this.pageIndicator,
    required this.customBrightness,
    required this.brightnessValue,
    required this.onReaderModeChanged,
    required this.onDoublePageModeChanged,
    required this.onTapToTurnPageChanged,
    required this.onVolumeButtonTurnPageChanged,
    required this.onPinchToZoomChanged,
    required this.onLongPressToSaveChanged,
    required this.onImmersiveModeChanged,
    required this.onKeepScreenOnChanged,
    required this.onPageIndicatorChanged,
    required this.onCustomBrightnessChanged,
    required this.onBrightnessChanged,
    required this.onBrightnessChangeEnd,
    required this.onClose,
  });

  final ReaderMode readerMode;
  final bool doublePageMode;
  final bool tapToTurnPage;
  final bool volumeButtonTurnPage;
  final bool pinchToZoom;
  final bool longPressToSave;
  final bool immersiveMode;
  final bool keepScreenOn;
  final bool pageIndicator;
  final bool customBrightness;
  final double brightnessValue;
  final ValueChanged<ReaderMode?> onReaderModeChanged;
  final ValueChanged<bool> onDoublePageModeChanged;
  final ValueChanged<bool>? onTapToTurnPageChanged;
  final ValueChanged<bool> onVolumeButtonTurnPageChanged;
  final ValueChanged<bool> onPinchToZoomChanged;
  final ValueChanged<bool> onLongPressToSaveChanged;
  final ValueChanged<bool> onImmersiveModeChanged;
  final ValueChanged<bool> onKeepScreenOnChanged;
  final ValueChanged<bool> onPageIndicatorChanged;
  final ValueChanged<bool> onCustomBrightnessChanged;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onBrightnessChangeEnd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final sliderActiveColor = theme.colorScheme.primary;
    final sliderInactiveColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.24,
    );
    final brightnessText = (brightnessValue * 100).round().toString();
    final disabledContentColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.38,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.readingSettingsTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.commonClose,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          ReaderSettingsGroup(
            theme: theme,
            children: [
              ListTile(
                leading: const Icon(Icons.chrome_reader_mode_outlined),
                title: Text(strings.readingModeTitle),
                subtitle: Text(strings.readingModeSubtitle),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ReaderMode>(
                    value: readerMode,
                    borderRadius: BorderRadius.circular(18),
                    onChanged: onReaderModeChanged,
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
                value: doublePageMode,
                onChanged: onDoublePageModeChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.touch_app_outlined),
                title: Text(strings.readingTapToTurnPageTitle),
                subtitle: Text(strings.readingTapToTurnPageSubtitle),
                value: tapToTurnPage,
                onChanged: onTapToTurnPageChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(strings.readingVolumeButtonTurnPageTitle),
                subtitle: Text(strings.readingVolumeButtonTurnPageSubtitle),
                value: volumeButtonTurnPage,
                onChanged: onVolumeButtonTurnPageChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.zoom_in_outlined),
                title: Text(strings.readingPinchToZoomTitle),
                subtitle: Text(strings.readingPinchToZoomSubtitle),
                value: pinchToZoom,
                onChanged: onPinchToZoomChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.save_alt_outlined),
                title: Text(strings.readingLongPressSaveTitle),
                subtitle: Text(strings.readingLongPressSaveSubtitle),
                value: longPressToSave,
                onChanged: onLongPressToSaveChanged,
              ),
            ],
          ),
          ReaderSettingsGroup(
            theme: theme,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fullscreen_outlined),
                title: Text(strings.readingImmersiveModeTitle),
                subtitle: Text(strings.readingImmersiveModeSubtitle),
                value: immersiveMode,
                onChanged: onImmersiveModeChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.screen_lock_portrait_outlined),
                title: Text(strings.readingKeepScreenOnTitle),
                subtitle: Text(strings.readingKeepScreenOnSubtitle),
                value: keepScreenOn,
                onChanged: onKeepScreenOnChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.format_list_numbered_outlined),
                title: Text(strings.readingPageIndicatorTitle),
                subtitle: Text(strings.readingPageIndicatorSubtitle),
                value: pageIndicator,
                onChanged: onPageIndicatorChanged,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_medium_outlined),
                title: Text(strings.readingCustomBrightnessTitle),
                subtitle: Text(strings.readingCustomBrightnessSubtitle),
                value: customBrightness,
                onChanged: onCustomBrightnessChanged,
              ),
              ListTile(
                leading: Icon(
                  Icons.wb_sunny_outlined,
                  color: customBrightness
                      ? theme.colorScheme.onSurface
                      : disabledContentColor,
                ),
                title: Text(
                  strings.readingBrightnessLabel(brightnessText),
                  style: TextStyle(
                    color: customBrightness
                        ? theme.colorScheme.onSurface
                        : disabledContentColor,
                  ),
                ),
                subtitle: Slider(
                  value: brightnessValue,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: onBrightnessChanged,
                  onChangeEnd: onBrightnessChangeEnd,
                  activeColor: sliderActiveColor,
                  inactiveColor: sliderInactiveColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
