import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/l10n/l10n.dart';

// 闃呰鍣ㄨ缃粍锛岄噰鐢ㄥ崱鐗囨牱寮忓憟鐜?
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
          // 椤堕儴鏍囬鍜屽叧闂寜閽?
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.readingSettingsTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.commonClose,
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // 鍒嗙粍 1: 闃呰妯″紡涓庢帓鐗?
          ReaderSettingsGroup(
            theme: theme,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chrome_reader_mode_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.readingModeTitle,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                strings.readingModeSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ReaderMode>(
                        segments: [
                          ButtonSegment(
                            value: ReaderMode.topToBottom,
                            label: Text(strings.readingModeTopToBottom),
                            icon: const Icon(Icons.swap_vert_rounded),
                          ),
                          ButtonSegment(
                            value: ReaderMode.rightToLeft,
                            label: Text(strings.readingModeRightToLeft),
                            icon: const Icon(Icons.swap_horiz_rounded),
                          ),
                        ],
                        selected: {readerMode},
                        onSelectionChanged: (set) {
                          onReaderModeChanged(set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.auto_stories_outlined),
                title: Text(strings.readingDoublePageModeTitle),
                subtitle: Text(strings.readingDoublePageModeSubtitle),
                value: doublePageMode,
                onChanged: onDoublePageModeChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.format_list_numbered_outlined),
                title: Text(strings.readingPageIndicatorTitle),
                subtitle: Text(strings.readingPageIndicatorSubtitle),
                value: pageIndicator,
                onChanged: onPageIndicatorChanged,
              ),
            ],
          ),

          // 鍒嗙粍 2: 浜や簰涓庢墜鍔?
          ReaderSettingsGroup(
            theme: theme,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.touch_app_outlined),
                title: Text(strings.readingTapToTurnPageTitle),
                subtitle: Text(strings.readingTapToTurnPageSubtitle),
                value: tapToTurnPage,
                onChanged: onTapToTurnPageChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(strings.readingVolumeButtonTurnPageTitle),
                subtitle: Text(strings.readingVolumeButtonTurnPageSubtitle),
                value: volumeButtonTurnPage,
                onChanged: onVolumeButtonTurnPageChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.zoom_in_outlined),
                title: Text(strings.readingPinchToZoomTitle),
                subtitle: Text(strings.readingPinchToZoomSubtitle),
                value: pinchToZoom,
                onChanged: onPinchToZoomChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.save_alt_outlined),
                title: Text(strings.readingLongPressSaveTitle),
                subtitle: Text(strings.readingLongPressSaveSubtitle),
                value: longPressToSave,
                onChanged: onLongPressToSaveChanged,
              ),
            ],
          ),

          // 鍒嗙粍 3: 鏄剧ず涓庝寒搴?
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
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.screen_lock_portrait_outlined),
                title: Text(strings.readingKeepScreenOnTitle),
                subtitle: Text(strings.readingKeepScreenOnSubtitle),
                value: keepScreenOn,
                onChanged: onKeepScreenOnChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_medium_outlined),
                title: Text(strings.readingCustomBrightnessTitle),
                subtitle: Text(strings.readingCustomBrightnessSubtitle),
                value: customBrightness,
                onChanged: onCustomBrightnessChanged,
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 8),
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
                subtitle: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: brightnessValue,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    onChanged: customBrightness ? onBrightnessChanged : null,
                    onChangeEnd: customBrightness
                        ? onBrightnessChangeEnd
                        : null,
                    activeColor: customBrightness
                        ? sliderActiveColor
                        : sliderInactiveColor,
                    inactiveColor: sliderInactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
