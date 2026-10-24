import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/detection/onnx_runtime_library.dart';
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

  Future<void> _delete(
    BuildContext context,
    String message,
    Future<void> Function() delete,
  ) async {
    final strings = l10n(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
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
      await _save(context, delete());
    }
  }

  Widget _warning(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.error_outline, color: colorScheme.error),
      title: Text(message, style: TextStyle(color: colorScheme.error)),
    );
  }

  (String, String, String) _modelTexts(
    AppLocalizations strings,
    TranslationDetectorModelSpec spec,
  ) => switch (spec.id) {
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

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, models]),
      builder: (context, _) {
        final detector =
            settings.textLocator == TranslationTextLocator.detector;
        final runtime = models.runtime;
        final runtimeReady = models.isRuntimeInstalled;
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
            if (detector && runtime == null)
              _warning(context, strings.translationRuntimeUnsupported),
            if (detector && runtime != null) ...[
              if (!runtimeReady)
                _warning(context, strings.translationRuntimeRequired)
              else if (!models.isInstalled(settings.detectorModelId))
                _warning(context, strings.translationDetectorRequired),
              _DownloadTile(
                key: const ValueKey('translation-detector-runtime'),
                name: strings.translationRuntimeTitle,
                lines: [
                  'ONNX Runtime ${OnnxRuntimeLibrarySpec.version}',
                  strings.translationRuntimeDescription,
                ],
                bytes: runtime.entryCompressedBytes,
                license: OnnxRuntimeLibrarySpec.license,
                state: models.runtimeState,
                note: models.runtimeDeletePending
                    ? strings.translationRuntimeDeletePending
                    : null,
                onDownload: models.runtimeDeletePending
                    ? null
                    : () => unawaited(models.downloadRuntime()),
                onCancel: models.cancelRuntime,
                onDelete: () => unawaited(
                  _delete(
                    context,
                    strings.translationRuntimeDeleteConfirm,
                    models.deleteRuntime,
                  ),
                ),
              ),
              for (final spec in models.specs)
                () {
                  final (name, description, cost) = _modelTexts(strings, spec);
                  return _DownloadTile(
                    key: ValueKey('translation-detector-${spec.id}'),
                    name: name,
                    lines: [description],
                    bytes: spec.downloadBytes,
                    license: spec.license,
                    cost: cost,
                    state: models.stateOf(spec.id),
                    selected: settings.detectorModelId == spec.id,
                    onDownload: () => unawaited(models.download(spec.id)),
                    onCancel: () => models.cancel(spec.id),
                    // 运行库未安装时模型不可选用。
                    onSelect: runtimeReady
                        ? () => unawaited(
                            _save(
                              context,
                              settings.setDetectorModelId(spec.id),
                            ),
                          )
                        : null,
                    selectable: true,
                    onDelete: () => unawaited(
                      _delete(
                        context,
                        strings.translationDetectorDeleteConfirm,
                        () => models.delete(spec.id),
                      ),
                    ),
                  );
                }(),
            ],
          ],
        );
      },
    );
  }
}

/// 可下载资源（运行库或检测模型）的一行：说明、进度、失败原因与操作按钮。
class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    super.key,
    required this.name,
    required this.lines,
    required this.bytes,
    required this.license,
    required this.state,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    this.cost,
    this.note,
    this.selected = false,
    this.selectable = false,
    this.onSelect,
  });

  final String name;
  final List<String> lines;
  final int bytes;
  final String license;
  final String? cost;
  final String? note;
  final DetectorModelState state;
  final bool selected;

  /// 是否提供「选用」操作；为 true 且 [onSelect] 为 null 时按钮禁用。
  final bool selectable;
  final VoidCallback? onDownload;
  final VoidCallback onCancel;
  final VoidCallback? onSelect;
  final VoidCallback onDelete;

  static String _formatBytes(num bytes) {
    // 与模型说明保持一致，按十进制 MB 展示。
    if (bytes >= 1e6) {
      final mb = bytes / 1e6;
      return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    }
    return '${(bytes / 1e3).toStringAsFixed(0)} KB';
  }

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
          for (final line in lines) Text(line),
          Text(strings.translationDetectorMeta(_formatBytes(bytes), license)),
          if (cost != null) Text(cost!),
          if (selected)
            Text(
              strings.translationDetectorSelected,
              style: TextStyle(color: colorScheme.primary),
            ),
          if (note != null)
            Text(note!, style: TextStyle(color: colorScheme.error)),
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
                  if (selectable && !selected)
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
