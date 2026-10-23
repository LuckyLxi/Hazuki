import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/detection/translation_detector_model_store.dart';
import '../../../../services/translation/detection/translation_detector_models.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../settings_group.dart';

class TranslationDetectorGroup extends StatelessWidget {
  const TranslationDetectorGroup({
    super.key,
    required this.settings,
    required this.models,
  });

  final MangaTranslationSettingsStore settings;
  final TranslationDetectorModelStore models;

  Future<void> _save(BuildContext context, Future<void> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = l10n(context).translationSettingsFailed;
    try {
      await action;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete(BuildContext context, String id) async {
    final strings = l10n(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(strings.translationDetectorDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(strings.commonConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && context.mounted) {
      await _save(context, models.delete(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, models]),
      builder: (context, _) {
        final detector =
            settings.textLocator == TranslationTextLocator.detector;
        return SettingsGroup(
          children: [
            ListTile(
              title: Text(strings.translationLocator),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<TranslationTextLocator>(
                      key: const ValueKey('translation-text-locator'),
                      segments: [
                        ButtonSegment(
                          value: TranslationTextLocator.detector,
                          label: Text(strings.translationLocatorDetector),
                        ),
                        ButtonSegment(
                          value: TranslationTextLocator.ai,
                          label: Text(strings.translationLocatorAi),
                        ),
                      ],
                      selected: {settings.textLocator},
                      onSelectionChanged: (value) => unawaited(
                        _save(context, settings.setTextLocator(value.single)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detector
                          ? strings.translationLocatorDetectorHint
                          : strings.translationLocatorAiHint,
                    ),
                  ],
                ),
              ),
            ),
            if (detector) ...[
              if (!models.isInstalled(settings.detectorModelId))
                ListTile(
                  leading: Icon(Icons.error_outline, color: colorScheme.error),
                  title: Text(
                    strings.translationDetectorRequired,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              for (final spec in models.specs)
                _DetectorModelTile(
                  key: ValueKey('translation-detector-${spec.id}'),
                  spec: spec,
                  state: models.stateOf(spec.id),
                  selected: settings.detectorModelId == spec.id,
                  onDownload: () => unawaited(models.download(spec.id)),
                  onCancel: () => models.cancel(spec.id),
                  onSelect: () => unawaited(
                    _save(context, settings.setDetectorModelId(spec.id)),
                  ),
                  onDelete: () => unawaited(_delete(context, spec.id)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DetectorModelTile extends StatelessWidget {
  const _DetectorModelTile({
    super.key,
    required this.spec,
    required this.state,
    required this.selected,
    required this.onDownload,
    required this.onCancel,
    required this.onSelect,
    required this.onDelete,
  });

  final TranslationDetectorModelSpec spec;
  final DetectorModelState state;
  final bool selected;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  static String _formatBytes(num bytes) {
    // 与模型说明保持一致，按十进制 MB 展示。
    if (bytes >= 1e6) {
      final mb = bytes / 1e6;
      return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    }
    return '${(bytes / 1e3).toStringAsFixed(0)} KB';
  }

  (String, String, String) _texts(AppLocalizations strings) =>
      switch (spec.id) {
        'comic_text_detector' => (
          'Comic Text Detector',
          strings.translationDetectorCtdDescription,
          strings.translationDetectorCtdCost,
        ),
        'pp_ocrv5_mobile_det' => (
          'PP-OCRv5 Mobile',
          strings.translationDetectorMobileDescription,
          strings.translationDetectorMobileCost,
        ),
        _ => (
          'PP-OCRv5 Server',
          strings.translationDetectorServerDescription,
          strings.translationDetectorServerCost,
        ),
      };

  String _failure(AppLocalizations strings) => switch (state.failure) {
    DetectorModelFailure.checksumMismatch =>
      strings.translationDetectorFailedChecksum,
    DetectorModelFailure.invalidArchive =>
      strings.translationDetectorFailedArchive,
    DetectorModelFailure.loadFailed => strings.translationDetectorFailedLoad,
    DetectorModelFailure.storage => strings.translationDetectorFailedStorage,
    _ => strings.translationDetectorFailedNetwork,
  };

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final (name, description, cost) = _texts(strings);
    final downloading = state.status == DetectorModelStatus.downloading;
    final verifying = downloading && state.progress >= 1;
    return ListTile(
      title: Text(name),
      trailing: selected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          Text(
            strings.translationDetectorMeta(
              _formatBytes(spec.downloadBytes),
              spec.license,
            ),
          ),
          Text(cost),
          if (selected)
            Text(
              strings.translationDetectorSelected,
              style: TextStyle(color: colorScheme.primary),
            ),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: verifying || state.indeterminate ? null : state.progress,
            ),
            const SizedBox(height: 4),
            Text(
              verifying
                  ? strings.translationDetectorVerifying
                  : strings.translationDetectorProgress(
                      (state.progress * 100).round(),
                      _formatBytes(state.speedBytesPerSecond),
                    ),
            ),
          ],
          if (state.status == DetectorModelStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _failure(strings),
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: switch (state.status) {
                DetectorModelStatus.notInstalled => [
                  FilledButton.tonal(
                    onPressed: onDownload,
                    child: Text(strings.translationDetectorDownload),
                  ),
                ],
                DetectorModelStatus.downloading => [
                  TextButton(
                    onPressed: onCancel,
                    child: Text(strings.commonCancel),
                  ),
                ],
                DetectorModelStatus.failed => [
                  FilledButton.tonal(
                    onPressed: onDownload,
                    child: Text(strings.commonRetry),
                  ),
                ],
                DetectorModelStatus.installed => [
                  if (!selected)
                    FilledButton.tonal(
                      onPressed: onSelect,
                      child: Text(strings.translationDetectorSelect),
                    ),
                  TextButton(
                    onPressed: onDelete,
                    child: Text(strings.translationDetectorDelete),
                  ),
                ],
              },
            ),
          ),
        ],
      ),
    );
  }
}
