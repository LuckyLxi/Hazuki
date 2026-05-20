import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/support/reader_source_image_quality_settings.dart';
import 'package:hazuki/l10n/l10n.dart';

enum ReaderSettingsSurface { page, drawer }

class ReaderSettingsContent extends StatelessWidget {
  const ReaderSettingsContent({
    super.key,
    required this.surface,
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
    required this.sourceImageQuality,
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
    required this.onCopyMangaImageQualityChanged,
    required this.onPicacgImageQualityChanged,
    this.onBrightnessChangeEnd,
    this.onClose,
  });

  final ReaderSettingsSurface surface;
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
  final ReaderSourceImageQualitySnapshot sourceImageQuality;
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
  final ValueChanged<String?> onCopyMangaImageQualityChanged;
  final ValueChanged<String?> onPicacgImageQualityChanged;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return switch (surface) {
      ReaderSettingsSurface.page => _buildPageContent(context),
      ReaderSettingsSurface.drawer => _buildDrawerContent(context),
    };
  }

  Widget _buildPageContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _PageSettingsGroup(
          children: [
            _buildPageReaderModeTile(context),
            SwitchListTile(
              secondary: const Icon(Icons.auto_stories_outlined),
              title: Text(l10n(context).readingDoublePageModeTitle),
              subtitle: Text(l10n(context).readingDoublePageModeSubtitle),
              value: doublePageMode,
              onChanged: onDoublePageModeChanged,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.touch_app_outlined),
              title: Text(l10n(context).readingTapToTurnPageTitle),
              subtitle: Text(l10n(context).readingTapToTurnPageSubtitle),
              value: tapToTurnPage,
              onChanged: readerMode == ReaderMode.rightToLeft
                  ? onTapToTurnPageChanged
                  : null,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: Text(l10n(context).readingVolumeButtonTurnPageTitle),
              subtitle: Text(l10n(context).readingVolumeButtonTurnPageSubtitle),
              value: volumeButtonTurnPage,
              onChanged: onVolumeButtonTurnPageChanged,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.zoom_in_outlined),
              title: Text(l10n(context).readingPinchToZoomTitle),
              subtitle: Text(l10n(context).readingPinchToZoomSubtitle),
              value: pinchToZoom,
              onChanged: onPinchToZoomChanged,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.save_alt_outlined),
              title: Text(l10n(context).readingLongPressSaveTitle),
              subtitle: Text(l10n(context).readingLongPressSaveSubtitle),
              value: longPressToSave,
              onChanged: onLongPressToSaveChanged,
            ),
          ],
        ),
        _PageSettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.fullscreen_outlined),
              title: Text(l10n(context).readingImmersiveModeTitle),
              subtitle: Text(l10n(context).readingImmersiveModeSubtitle),
              value: immersiveMode,
              onChanged: onImmersiveModeChanged,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              title: Text(l10n(context).readingKeepScreenOnTitle),
              subtitle: Text(l10n(context).readingKeepScreenOnSubtitle),
              value: keepScreenOn,
              onChanged: onKeepScreenOnChanged,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.format_list_numbered_outlined),
              title: Text(l10n(context).readingPageIndicatorTitle),
              subtitle: Text(l10n(context).readingPageIndicatorSubtitle),
              value: pageIndicator,
              onChanged: onPageIndicatorChanged,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_medium_outlined),
              title: Text(l10n(context).readingCustomBrightnessTitle),
              subtitle: Text(l10n(context).readingCustomBrightnessSubtitle),
              value: customBrightness,
              onChanged: onCustomBrightnessChanged,
            ),
            _buildPageBrightnessTile(context),
          ],
        ),
        if (sourceImageQuality.isCopyMangaSource)
          _PageSettingsGroup(children: [_buildCopyMangaImageQualityField()]),
        if (sourceImageQuality.isPicacgSource)
          _PageSettingsGroup(
            children: [
              _buildPicacgImageQualityTile(),
              _buildPicacgImageQualityField(),
            ],
          ),
      ],
    );
  }

  Widget _buildDrawerContent(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n(context).readingSettingsTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n(context).commonClose,
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          _DrawerSettingsGroup(
            theme: theme,
            children: [
              _buildDrawerReaderModeSection(context),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.auto_stories_outlined),
                title: Text(l10n(context).readingDoublePageModeTitle),
                subtitle: Text(l10n(context).readingDoublePageModeSubtitle),
                value: doublePageMode,
                onChanged: onDoublePageModeChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.format_list_numbered_outlined),
                title: Text(l10n(context).readingPageIndicatorTitle),
                subtitle: Text(l10n(context).readingPageIndicatorSubtitle),
                value: pageIndicator,
                onChanged: onPageIndicatorChanged,
              ),
            ],
          ),
          _DrawerSettingsGroup(
            theme: theme,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.touch_app_outlined),
                title: Text(l10n(context).readingTapToTurnPageTitle),
                subtitle: Text(l10n(context).readingTapToTurnPageSubtitle),
                value: tapToTurnPage,
                onChanged: onTapToTurnPageChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(l10n(context).readingVolumeButtonTurnPageTitle),
                subtitle: Text(
                  l10n(context).readingVolumeButtonTurnPageSubtitle,
                ),
                value: volumeButtonTurnPage,
                onChanged: onVolumeButtonTurnPageChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.zoom_in_outlined),
                title: Text(l10n(context).readingPinchToZoomTitle),
                subtitle: Text(l10n(context).readingPinchToZoomSubtitle),
                value: pinchToZoom,
                onChanged: onPinchToZoomChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.save_alt_outlined),
                title: Text(l10n(context).readingLongPressSaveTitle),
                subtitle: Text(l10n(context).readingLongPressSaveSubtitle),
                value: longPressToSave,
                onChanged: onLongPressToSaveChanged,
              ),
            ],
          ),
          _DrawerSettingsGroup(
            theme: theme,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fullscreen_outlined),
                title: Text(l10n(context).readingImmersiveModeTitle),
                subtitle: Text(l10n(context).readingImmersiveModeSubtitle),
                value: immersiveMode,
                onChanged: onImmersiveModeChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.screen_lock_portrait_outlined),
                title: Text(l10n(context).readingKeepScreenOnTitle),
                subtitle: Text(l10n(context).readingKeepScreenOnSubtitle),
                value: keepScreenOn,
                onChanged: onKeepScreenOnChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_medium_outlined),
                title: Text(l10n(context).readingCustomBrightnessTitle),
                subtitle: Text(l10n(context).readingCustomBrightnessSubtitle),
                value: customBrightness,
                onChanged: onCustomBrightnessChanged,
              ),
              _buildDrawerBrightnessTile(context),
            ],
          ),
          if (sourceImageQuality.isCopyMangaSource ||
              sourceImageQuality.isPicacgSource)
            _DrawerSettingsGroup(
              theme: theme,
              children: [
                if (sourceImageQuality.isCopyMangaSource)
                  _buildCopyMangaImageQualityField(),
                if (sourceImageQuality.isPicacgSource) ...[
                  _buildPicacgImageQualityTile(),
                  _buildPicacgImageQualityField(),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPageReaderModeTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.chrome_reader_mode_outlined),
      title: Text(l10n(context).readingModeTitle),
      subtitle: Text(l10n(context).readingModeSubtitle),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<ReaderMode>(
          value: readerMode,
          borderRadius: BorderRadius.circular(18),
          onChanged: onReaderModeChanged,
          items: _buildReaderModeDropdownItems(context),
        ),
      ),
    );
  }

  Widget _buildDrawerReaderModeSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
                      l10n(context).readingModeTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l10n(context).readingModeSubtitle,
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
                  label: Text(l10n(context).readingModeTopToBottom),
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
                ButtonSegment(
                  value: ReaderMode.rightToLeft,
                  label: Text(l10n(context).readingModeRightToLeft),
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
    );
  }

  Widget _buildPageBrightnessTile(BuildContext context) {
    final theme = Theme.of(context);
    final disabledContentColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final brightnessText = (brightnessValue * 100).round().toString();

    return ListTile(
      leading: Icon(
        Icons.wb_sunny_outlined,
        color: customBrightness
            ? theme.colorScheme.onSurface
            : disabledContentColor,
      ),
      title: Text(
        l10n(context).readingBrightnessLabel(brightnessText),
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
        onChanged: customBrightness ? onBrightnessChanged : null,
        onChangeEnd: customBrightness ? onBrightnessChangeEnd : null,
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.colorScheme.onSurface.withValues(alpha: 0.24),
      ),
    );
  }

  Widget _buildDrawerBrightnessTile(BuildContext context) {
    final theme = Theme.of(context);
    final disabledContentColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final sliderInactiveColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.24,
    );
    final brightnessText = (brightnessValue * 100).round().toString();

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: Icon(
        Icons.wb_sunny_outlined,
        color: customBrightness
            ? theme.colorScheme.onSurface
            : disabledContentColor,
      ),
      title: Text(
        l10n(context).readingBrightnessLabel(brightnessText),
        style: TextStyle(
          color: customBrightness
              ? theme.colorScheme.onSurface
              : disabledContentColor,
        ),
      ),
      subtitle: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        ),
        child: Slider(
          value: brightnessValue,
          min: 0,
          max: 1,
          divisions: 100,
          onChanged: customBrightness ? onBrightnessChanged : null,
          onChangeEnd: customBrightness ? onBrightnessChangeEnd : null,
          activeColor: customBrightness
              ? theme.colorScheme.primary
              : sliderInactiveColor,
          inactiveColor: sliderInactiveColor,
        ),
      ),
    );
  }

  Widget _buildCopyMangaImageQualityField() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: DropdownButtonFormField<String>(
            initialValue: sourceImageQuality.copyMangaImageQuality,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n(context).otherCopyMangaImageQualityTitle,
              helperText: l10n(context).otherCopyMangaImageQualitySubtitle,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String>(
                value: '800',
                child: Text(l10n(context).otherCopyMangaImageQualityLow),
              ),
              DropdownMenuItem<String>(
                value: '1200',
                child: Text(l10n(context).otherCopyMangaImageQualityMedium),
              ),
              DropdownMenuItem<String>(
                value: '1500',
                child: Text(l10n(context).otherCopyMangaImageQualityHigh),
              ),
            ],
            onChanged: onCopyMangaImageQualityChanged,
          ),
        );
      },
    );
  }

  Widget _buildPicacgImageQualityTile() {
    return Builder(
      builder: (context) {
        return ListTile(
          leading: const Icon(Icons.photo_size_select_large_outlined),
          title: Text(l10n(context).linePicacgImageQualityTitle),
          subtitle: Text(l10n(context).linePicacgImageQualitySubtitle),
        );
      },
    );
  }

  Widget _buildPicacgImageQualityField() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: DropdownButtonFormField<String>(
            initialValue: sourceImageQuality.picacgImageQuality,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n(context).linePicacgImageQualityLabel,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String>(
                value: 'original',
                child: Text(l10n(context).linePicacgImageQualityOriginal),
              ),
              DropdownMenuItem<String>(
                value: 'medium',
                child: Text(l10n(context).linePicacgImageQualityMedium),
              ),
              DropdownMenuItem<String>(
                value: 'low',
                child: Text(l10n(context).linePicacgImageQualityLow),
              ),
            ],
            onChanged: onPicacgImageQualityChanged,
          ),
        );
      },
    );
  }

  List<DropdownMenuItem<ReaderMode>> _buildReaderModeDropdownItems(
    BuildContext context,
  ) {
    return [
      DropdownMenuItem(
        value: ReaderMode.topToBottom,
        child: Text(l10n(context).readingModeTopToBottom),
      ),
      DropdownMenuItem(
        value: ReaderMode.rightToLeft,
        child: Text(l10n(context).readingModeRightToLeft),
      ),
    ];
  }
}

class _PageSettingsGroup extends StatelessWidget {
  const _PageSettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
}

class _DrawerSettingsGroup extends StatelessWidget {
  const _DrawerSettingsGroup({required this.theme, required this.children});

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
