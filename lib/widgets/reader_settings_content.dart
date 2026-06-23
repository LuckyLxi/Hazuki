import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/shared/reading/reader_source_image_quality_settings.dart';

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
    required this.filterEnabled,
    required this.filterColor,
    required this.filterStrength,
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
    required this.onFilterEnabledChanged,
    required this.onFilterColorChanged,
    required this.onFilterStrengthChanged,
    required this.onCopyMangaImageQualityChanged,
    required this.onPicacgImageQualityChanged,
    this.onBrightnessChangeEnd,
    this.onFilterStrengthChangeEnd,
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
  final bool filterEnabled;
  final ReaderFilterColor filterColor;
  final double filterStrength;
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
  final ValueChanged<bool> onFilterEnabledChanged;
  final ValueChanged<ReaderFilterColor> onFilterColorChanged;
  final ValueChanged<double>? onFilterStrengthChanged;
  final ValueChanged<double>? onFilterStrengthChangeEnd;
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
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              secondary: const Icon(Icons.filter_vintage_outlined),
              title: Text(l10n(context).readingFilterTitle),
              subtitle: Text(l10n(context).readingFilterSubtitle),
              value: filterEnabled,
              onChanged: onFilterEnabledChanged,
            ),
            _buildFilterOptions(context, drawer: false),
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
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.filter_vintage_outlined),
                title: Text(l10n(context).readingFilterTitle),
                subtitle: Text(l10n(context).readingFilterSubtitle),
                value: filterEnabled,
                onChanged: onFilterEnabledChanged,
              ),
              _buildFilterOptions(context, drawer: true),
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
    return _buildReaderModeSection(context, drawer: false);
  }

  Widget _buildDrawerReaderModeSection(BuildContext context) {
    return _buildReaderModeSection(context, drawer: true);
  }

  Widget _buildReaderModeSection(BuildContext context, {required bool drawer}) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, drawer ? 20 : 16, 16, 16),
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
          _ReaderModeSlider(
            value: readerMode,
            topToBottomLabel: l10n(context).readingModeTopToBottom,
            rightToLeftLabel: l10n(context).readingModeRightToLeft,
            onChanged: onReaderModeChanged,
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

  Widget _buildFilterOptions(BuildContext context, {required bool drawer}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: filterEnabled
          ? Padding(
              key: const ValueKey<String>('reader-filter-options'),
              padding: EdgeInsets.fromLTRB(16, 0, drawer ? 8 : 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReaderFilterColorSlider(
                    value: filterColor,
                    yellowLabel: l10n(context).readingFilterColorYellow,
                    blackLabel: l10n(context).readingFilterColorBlack,
                    onChanged: onFilterColorChanged,
                  ),
                  const SizedBox(height: 8),
                  _buildFilterStrengthSlider(context),
                ],
              ),
            )
          : const SizedBox.shrink(
              key: ValueKey<String>('reader-filter-options-hidden'),
            ),
    );
  }

  Widget _buildFilterStrengthSlider(BuildContext context) {
    final theme = Theme.of(context);
    final strengthText = (filterStrength * 100).round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n(context).readingFilterStrengthLabel(strengthText),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: filterStrength,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: onFilterStrengthChanged,
            onChangeEnd: onFilterStrengthChangeEnd,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.onSurface.withValues(alpha: 0.24),
          ),
        ),
      ],
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
}

class _PageSettingsGroup extends StatelessWidget {
  const _PageSettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
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
    final borderRadius = BorderRadius.circular(24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _ReaderFilterColorSlider extends StatelessWidget {
  const _ReaderFilterColorSlider({
    required this.value,
    required this.yellowLabel,
    required this.blackLabel,
    required this.onChanged,
  });

  final ReaderFilterColor value;
  final String yellowLabel;
  final String blackLabel;
  final ValueChanged<ReaderFilterColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blackSelected = value == ReaderFilterColor.black;

    return SizedBox(
      key: const ValueKey<String>('reader-filter-color-slider'),
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Material(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: blackSelected ? itemWidth : 2,
                  top: 2,
                  bottom: 2,
                  width: itemWidth - 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: blackSelected
                          ? colorScheme.inverseSurface
                          : const Color(0xFFFFE082),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ReaderFilterColorOption(
                        label: yellowLabel,
                        icon: Icons.light_mode_outlined,
                        selected: !blackSelected,
                        selectedColor: const Color(0xFF4E3B00),
                        onTap: () => onChanged(ReaderFilterColor.yellow),
                      ),
                    ),
                    Expanded(
                      child: _ReaderFilterColorOption(
                        label: blackLabel,
                        icon: Icons.dark_mode_outlined,
                        selected: blackSelected,
                        selectedColor: colorScheme.onInverseSurface,
                        onTap: () => onChanged(ReaderFilterColor.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReaderModeSlider extends StatelessWidget {
  const _ReaderModeSlider({
    required this.value,
    required this.topToBottomLabel,
    required this.rightToLeftLabel,
    required this.onChanged,
  });

  final ReaderMode value;
  final String topToBottomLabel;
  final String rightToLeftLabel;
  final ValueChanged<ReaderMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rightToLeftSelected = value == ReaderMode.rightToLeft;

    return SizedBox(
      key: const ValueKey<String>('reader-mode-slider'),
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Material(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: rightToLeftSelected ? itemWidth : 2,
                  top: 2,
                  bottom: 2,
                  width: itemWidth - 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ReaderModeOption(
                        label: topToBottomLabel,
                        icon: Icons.swap_vert_rounded,
                        selected: !rightToLeftSelected,
                        onTap: () => onChanged(ReaderMode.topToBottom),
                      ),
                    ),
                    Expanded(
                      child: _ReaderModeOption(
                        label: rightToLeftLabel,
                        icon: Icons.swap_horiz_rounded,
                        selected: rightToLeftSelected,
                        onTap: () => onChanged(ReaderMode.rightToLeft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReaderModeOption extends StatelessWidget {
  const _ReaderModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderFilterColorOption extends StatelessWidget {
  const _ReaderFilterColorOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? selectedColor : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
