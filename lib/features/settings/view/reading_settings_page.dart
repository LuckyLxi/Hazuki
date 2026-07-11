import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/features/settings/state/reading_settings_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'settings_group.dart';

class ReadingSettingsPage extends StatefulWidget {
  const ReadingSettingsPage({super.key, required this.sourceService});

  final SourceSettingsGateway sourceService;

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage> {
  late final ReadingSettingsController _controller = ReadingSettingsController(
    sourceService: widget.sourceService,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadSettings());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.readingSettingsTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return ReaderSettingsContent(
              surface: ReaderSettingsSurface.page,
              readerMode: _controller.readerMode,
              doublePageMode: _controller.doublePageMode,
              tapToTurnPage: _controller.tapToTurnPage,
              volumeButtonTurnPage: _controller.volumeButtonTurnPage,
              pinchToZoom: _controller.pinchToZoom,
              longPressToSave: _controller.longPressToSave,
              immersiveMode: _controller.immersiveMode,
              keepScreenOn: _controller.keepScreenOn,
              pageIndicator: _controller.pageIndicator,
              customBrightness: _controller.customBrightness,
              brightnessValue: _controller.brightnessValue,
              filterEnabled: _controller.filterEnabled,
              filterColor: _controller.filterColor,
              filterStrength: _controller.filterStrength,
              sourceImageQuality: _controller.sourceImageQuality,
              onReaderModeChanged: _controller.updateReaderMode,
              onDoublePageModeChanged: _controller.toggleDoublePageMode,
              onTapToTurnPageChanged:
                  _controller.readerMode == ReaderMode.rightToLeft
                  ? _controller.toggleTapToTurnPage
                  : null,
              onVolumeButtonTurnPageChanged:
                  _controller.toggleVolumeButtonTurnPage,
              onPinchToZoomChanged: _controller.togglePinchToZoom,
              onLongPressToSaveChanged: _controller.toggleLongPressToSave,
              onImmersiveModeChanged: _controller.toggleImmersiveMode,
              onKeepScreenOnChanged: _controller.toggleKeepScreenOn,
              onPageIndicatorChanged: _controller.togglePageIndicator,
              onCustomBrightnessChanged: _controller.toggleCustomBrightness,
              onBrightnessChanged: _controller.customBrightness
                  ? _controller.updateBrightness
                  : null,
              onFilterEnabledChanged: _controller.toggleFilter,
              onFilterColorChanged: _controller.updateFilterColor,
              onFilterStrengthChanged: _controller.filterEnabled
                  ? _controller.updateFilterStrength
                  : null,
              onCopyMangaImageQualityChanged:
                  _controller.updateCopyMangaImageQuality,
              onPicacgImageQualityChanged: _controller.updatePicacgImageQuality,
            );
          },
        ),
      ),
    );
  }
}
