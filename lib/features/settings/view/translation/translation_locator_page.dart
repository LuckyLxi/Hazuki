import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/detection/translation_detector_model_store.dart';
import '../../../../services/translation/detection/translation_detector_models.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../settings_group.dart';

const _duration = Duration(milliseconds: 240);
const _curve = Curves.easeOutCubic;

/// 检测模型的展示名、说明与开销提示。
(String, String, String) translationDetectorTexts(
  AppLocalizations strings,
  TranslationDetectorModelSpec spec,
) => switch (spec.id) {
  'comic_text_detector' => (
    'Comic Text Detector',
    strings.translationDetectorCtdDescription,
    strings.translationDetectorCtdCost,
  ),
  'comic_text_bubble_detector' => (
    'Comic Text & Bubble Detector',
    strings.translationDetectorBubbleDescription,
    strings.translationDetectorBubbleCost,
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

/// 文字定位方式与本地检测资源（运行库、检测模型）的管理页。
class TranslationLocatorPage extends StatelessWidget {
  const TranslationLocatorPage({
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

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translationLocator)),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, models]),
        builder: (context, _) {
          final detector =
              settings.textLocator == TranslationTextLocator.detector;
          void select(TranslationTextLocator value) =>
              unawaited(_save(context, settings.setTextLocator(value)));
          return HazukiSettingsPageBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _LocatorChoiceCard(
                          key: const ValueKey(
                            'translation-text-locator-detector',
                          ),
                          title: strings.translationLocatorDetector,
                          badge: strings.translationLocatorRecommended,
                          description: strings.translationLocatorDetectorHint,
                          selected: detector,
                          onTap: () => select(TranslationTextLocator.detector),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LocatorChoiceCard(
                          key: const ValueKey('translation-text-locator-ai'),
                          title: strings.translationLocatorAi,
                          description: strings.translationLocatorAiHint,
                          selected: !detector,
                          onTap: () => select(TranslationTextLocator.ai),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 切换定位方式时，下方内容淡入并沿顶部展开或收起。
                AnimatedSwitcher(
                  duration: _duration,
                  switchInCurve: _curve,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                  child: detector
                      ? KeyedSubtree(
                          key: const ValueKey('detector'),
                          child: _detectorSection(context, strings),
                        )
                      : _Notice(
                          key: const ValueKey('ai'),
                          icon: Icons.info_outline,
                          message: strings.translationLocatorAiNote,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detectorSection(BuildContext context, AppLocalizations strings) {
    final runtime = models.runtime;
    if (runtime == null) {
      return _Notice(
        icon: Icons.error_outline,
        message: strings.translationRuntimeUnsupported,
        error: true,
      );
    }
    final runtimeReady = models.isRuntimeInstalled;
    final warning = !runtimeReady
        ? strings.translationRuntimeRequired
        : !models.isInstalled(settings.detectorModelId)
        ? strings.translationDetectorRequired
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: _duration,
          curve: _curve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _duration,
            child: warning == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(warning),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Notice(
                      icon: Icons.error_outline,
                      message: warning,
                      error: true,
                    ),
                  ),
          ),
        ),
        _ResourceCard(
          key: const ValueKey('translation-detector-runtime'),
          name: strings.translationRuntimeTitle,
          lines: [
            'ONNX Runtime ${runtime.version}',
            strings.translationRuntimeDescription,
          ],
          bytes: runtime.downloadBytes,
          license: runtime.license,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            strings.translationDetectorModels,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        for (final spec in models.specs) ...[
          () {
            final (name, description, cost) = translationDetectorTexts(
              strings,
              spec,
            );
            return _ResourceCard(
              key: ValueKey('translation-detector-${spec.id}'),
              name: name,
              lines: [description],
              bytes: spec.downloadBytes,
              license: spec.license,
              cost: cost,
              lightweight: spec.id == 'pp_ocrv5_mobile_det',
              state: models.stateOf(spec.id),
              selectable: true,
              selected: settings.detectorModelId == spec.id,
              onDownload: () => unawaited(models.download(spec.id)),
              onCancel: () => models.cancel(spec.id),
              // 运行库未安装时模型不可选用。
              onSelect: runtimeReady
                  ? () => unawaited(
                      _save(context, settings.setDetectorModelId(spec.id)),
                    )
                  : null,
              onDelete: () => unawaited(
                _delete(
                  context,
                  strings.translationDetectorDeleteConfirm,
                  () => models.delete(spec.id),
                ),
              ),
            );
          }(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// 定位方式选择卡：选中时边框、底色与角标以动画过渡。
class _LocatorChoiceCard extends StatelessWidget {
  const _LocatorChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String description;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.55)
              : colorScheme.surfaceContainerLow,
          border: Border.all(
            width: 2,
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: _duration,
                        curve: selected ? Curves.easeOutBack : Curves.easeIn,
                        child: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = error
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// 可下载资源（运行库或检测模型）的卡片：说明、标签、进度、失败原因与操作。
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
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
    this.lightweight = false,
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

  /// 开销标签是否以轻量色调展示。
  final bool lightweight;
  final String? note;
  final DetectorModelState state;
  final bool selected;

  /// 是否可选用；为 true 且 [onSelect] 为 null 时单选点禁用。
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

  Widget _tag(BuildContext context, String text, Color background, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      );

  Widget _action(AppLocalizations strings) => switch (state.status) {
    DetectorModelStatus.notInstalled => FilledButton.tonal(
      key: const ValueKey('download'),
      onPressed: onDownload,
      child: Text(strings.translationDetectorDownload),
    ),
    DetectorModelStatus.downloading => TextButton(
      key: const ValueKey('cancel'),
      onPressed: onCancel,
      child: Text(strings.commonCancel),
    ),
    DetectorModelStatus.failed => FilledButton.tonal(
      key: const ValueKey('retry'),
      onPressed: onDownload,
      child: Text(strings.commonRetry),
    ),
    DetectorModelStatus.installed => IconButton(
      key: const ValueKey('delete'),
      tooltip: strings.translationDetectorDelete,
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final installed = state.status == DetectorModelStatus.installed;
    final downloading = state.status == DetectorModelStatus.downloading;
    final verifying = downloading && state.progress >= 1;
    final canSelect = selectable && installed && onSelect != null;
    final radius = BorderRadius.circular(16);

    final details = <Widget>[
      if (note != null) Text(note!, style: TextStyle(color: colorScheme.error)),
      if (downloading) ...[
        TweenAnimationBuilder<double>(
          tween: Tween(end: state.progress),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, _) => LinearProgressIndicator(
            value: verifying || state.indeterminate ? null : value,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          verifying
              ? strings.translationDetectorVerifying
              : strings.translationDetectorProgress(
                  (state.progress * 100).round(),
                  _formatBytes(state.speedBytesPerSecond),
                ),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      if (state.status == DetectorModelStatus.failed)
        Text(_failure(strings), style: TextStyle(color: colorScheme.error)),
    ];

    return Semantics(
      selected: selectable ? selected : null,
      inMutuallyExclusiveGroup: selectable,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surfaceContainerLow,
          border: Border.all(
            width: 2,
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: canSelect && !selected ? onSelect : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectable) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _RadioDot(
                            selected: selected,
                            enabled: canSelect,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            for (final line in lines)
                              Text(
                                line,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _tag(
                                  context,
                                  strings.translationDetectorMeta(
                                    _formatBytes(bytes),
                                    license,
                                  ),
                                  colorScheme.surfaceContainerHighest,
                                  colorScheme.onSurfaceVariant,
                                ),
                                if (cost != null)
                                  lightweight
                                      ? _tag(
                                          context,
                                          cost!,
                                          colorScheme.secondaryContainer,
                                          colorScheme.onSecondaryContainer,
                                        )
                                      : _tag(
                                          context,
                                          cost!,
                                          colorScheme.tertiaryContainer,
                                          colorScheme.onTertiaryContainer,
                                        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 下载、取消、重试、删除之间切换时缩放淡入。
                      AnimatedSwitcher(
                        duration: _duration,
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: _action(strings),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: _duration,
                    curve: _curve,
                    alignment: Alignment.topCenter,
                    child: details.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: EdgeInsets.fromLTRB(
                              selectable ? 32 : 0,
                              10,
                              4,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单选圆点：选中时内圆弹出，不可选时整体变淡。
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected
        ? colorScheme.primary
        : enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.3);
    return AnimatedContainer(
      duration: _duration,
      curve: _curve,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: _duration,
        curve: selected ? Curves.easeOutBack : Curves.easeIn,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
