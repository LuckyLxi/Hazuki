import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../../../../services/translation/translation_usage_store.dart';
import '../../../../shared/translation/manga_translation_dependencies.dart';
import '../../../../shared/translation/translation_confirmation_dialog.dart';
import '../settings_group.dart';
import 'translation_locator_page.dart';
import 'translation_prompt_page.dart';
import 'translation_provider_page.dart';
import 'translation_usage_group.dart';

const _duration = Duration(milliseconds: 260);
const _curve = Curves.easeOutCubic;

/// 漫画翻译首页：顶部状态总览，翻译引擎类配置进入二级页，阅读选项就地调整。
class MangaTranslationSettingsPage extends StatefulWidget {
  const MangaTranslationSettingsPage({super.key, required this.dependencies});
  final MangaTranslationDependencies dependencies;

  @override
  State<MangaTranslationSettingsPage> createState() =>
      _MangaTranslationSettingsPageState();
}

class _MangaTranslationSettingsPageState
    extends State<MangaTranslationSettingsPage> {
  late final _settings = widget.dependencies.settings;
  late final _models = widget.dependencies.models;
  late final _usageStore = widget.dependencies.usage;
  late Future<Map<String, DailyTranslationUsage>> _usage = _usageStore.load();
  bool _ready = false;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _usageStore.addListener(_reloadUsage);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _settings.load();
      await _models.load();
      final bytes = await widget.dependencies.cache.sizeBytes();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _cacheBytes = bytes;
      });
    } catch (_) {
      if (mounted) _message(l10n(context).translationSettingsFailed);
    }
  }

  void _reloadUsage() {
    if (mounted) setState(() => _usage = _usageStore.load());
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save(Future<void> action) async {
    try {
      await action;
    } catch (_) {
      if (mounted) _message(l10n(context).translationSettingsFailed);
    }
  }

  Future<void> _clearCache() async {
    if (!await confirmTranslationClear(context)) return;
    await _save(widget.dependencies.cache.clear());
    final bytes = await widget.dependencies.cache.sizeBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  void _open(WidgetBuilder builder) => unawaited(
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder)),
  );

  void _openUsage() => _open(
    (context) => Scaffold(
      appBar: AppBar(title: Text(l10n(context).translationUsage)),
      body: HazukiSettingsPageBody(
        child: ListView(children: [TranslationUsageGroup(store: _usageStore)]),
      ),
    ),
  );

  Future<void> _pickTargetLanguage() async {
    final strings = l10n(context);
    final current = _settings.targetLanguage;
    final selected = await showGeneralDialog<TranslationTargetLanguage>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: _duration,
      pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
        child: SimpleDialog(
          title: Text(strings.translationTargetLanguage),
          children: [
            for (final value in TranslationTargetLanguage.values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, value),
                child: Row(
                  children: [
                    Expanded(child: Text(_languageLabel(strings, value))),
                    if (value == current)
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(CurveTween(curve: _curve));
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (selected != null && selected != current) {
      await _save(_settings.setTargetLanguage(selected));
    }
  }

  static String _languageLabel(
    AppLocalizations strings,
    TranslationTargetLanguage value,
  ) => [
    strings.translationLanguageZhHans,
    strings.translationLanguageZhHant,
    strings.translationLanguageEn,
    strings.translationLanguageJa,
    strings.translationLanguageKo,
    strings.translationLanguageEs,
    strings.translationLanguageFr,
    strings.translationLanguageDe,
    strings.translationLanguageRu,
    strings.translationLanguagePt,
  ][value.index];

  String _locatorSummary(AppLocalizations strings) {
    if (_settings.textLocator == TranslationTextLocator.ai) {
      return strings.translationLocatorAi;
    }
    final id = _settings.detectorModelId;
    final spec = _models.isInstalled(id)
        ? _models.specs.where((spec) => spec.id == id).firstOrNull
        : null;
    final model = spec == null
        ? strings.translationDetectorNoneSelected
        : translationDetectorTexts(strings, spec).$1;
    return '${strings.translationLocatorDetector} · $model';
  }

  @override
  void dispose() {
    _usageStore.removeListener(_reloadUsage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.translationTitle),
        scrolledUnderElevation: 0,
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([_settings, _models]),
              builder: (context, _) {
                final detector =
                    _settings.textLocator == TranslationTextLocator.detector;
                final detectorReady =
                    _models.isRuntimeInstalled &&
                    _models.isInstalled(_settings.detectorModelId);
                return HazukiSettingsPageBody(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _StatusCard(
                        enabled: _settings.enabled,
                        onEnabledChanged: (value) =>
                            _save(_settings.setEnabled(value)),
                        statuses: [
                          (
                            _settings.isConfigured,
                            _settings.isConfigured
                                ? strings.translationStatusProviderReady
                                : strings.translationStatusProviderMissing,
                          ),
                          if (!detector)
                            (true, strings.translationLocatorAi)
                          else
                            (
                              detectorReady,
                              detectorReady
                                  ? strings.translationStatusDetectorReady
                                  : strings.translationStatusDetectorMissing,
                            ),
                        ],
                        language: _languageLabel(
                          strings,
                          _settings.targetLanguage,
                        ),
                        usage: _usage,
                        onUsageTap: _openUsage,
                      ),
                      _SectionLabel(strings.translationSectionEngine),
                      SettingsGroup(
                        children: [
                          _EntryTile(
                            icon: Icons.auto_awesome_outlined,
                            title: strings.translationProviderAndModel,
                            subtitle: _settings.isConfigured
                                ? '${translationProviderLabel(strings, _settings.providerPreset)} · ${_settings.model}'
                                : strings.translationNotConfigured,
                            onTap: () => _open(
                              (_) => TranslationProviderPage(
                                dependencies: widget.dependencies,
                              ),
                            ),
                          ),
                          const _GroupDivider(indent: 72),
                          _EntryTile(
                            key: const ValueKey('translation-locator-entry'),
                            icon: Icons.document_scanner_outlined,
                            title: strings.translationLocator,
                            subtitle: _locatorSummary(strings),
                            onTap: () => _open(
                              (_) => TranslationLocatorPage(
                                settings: _settings,
                                models: _models,
                              ),
                            ),
                          ),
                          const _GroupDivider(indent: 72),
                          _EntryTile(
                            icon: Icons.edit_note_outlined,
                            title: strings.translationSystemPrompt,
                            subtitle: _settings.customSystemPrompt.isEmpty
                                ? strings.translationPromptDefault
                                : strings.translationPromptCustom,
                            onTap: () => _open(
                              (_) => TranslationPromptPage(settings: _settings),
                            ),
                          ),
                        ],
                      ),
                      _SectionLabel(strings.translationSectionReading),
                      SettingsGroup(
                        children: [
                          ListTile(
                            title: Text(strings.translationTargetLanguage),
                            trailing: _FadeText(
                              _languageLabel(strings, _settings.targetLanguage),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: _pickTargetLanguage,
                          ),
                          SwitchListTile(
                            title: Text(strings.translationAutoEnable),
                            subtitle: Text(strings.translationAutoEnableHint),
                            value: _settings.autoEnableReaderMode,
                            onChanged: (value) =>
                                _save(_settings.setAutoEnableReaderMode(value)),
                          ),
                          _PrefetchSelector(
                            value: _settings.prefetchAhead,
                            onChanged: (value) =>
                                _save(_settings.setPrefetchAhead(value)),
                          ),
                          _BubbleStyleSelector(
                            value: _settings.bubbleStyle,
                            onChanged: (value) =>
                                _save(_settings.setBubbleStyle(value)),
                          ),
                          SwitchListTile(
                            title: Text(strings.translationSfx),
                            subtitle: Text(strings.translationSfxHint),
                            value: _settings.translateSfx,
                            onChanged: (value) =>
                                _save(_settings.setTranslateSfx(value)),
                          ),
                          SwitchListTile(
                            title: Text(strings.translationVerticalText),
                            subtitle: Text(strings.translationVerticalTextHint),
                            value: _settings.verticalText,
                            onChanged: (value) =>
                                _save(_settings.setVerticalText(value)),
                          ),
                        ],
                      ),
                      _SectionLabel(strings.translationSectionData),
                      SettingsGroup(
                        children: [
                          ListTile(
                            title: Text(strings.translationUsage),
                            subtitle: Text(strings.translationUsageDetails),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _openUsage,
                          ),
                          const _GroupDivider(indent: 16),
                          ListTile(
                            title: Text(strings.translationCache),
                            subtitle: _FadeText(
                              '${(_cacheBytes / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                            trailing: TextButton(
                              onPressed: _clearCache,
                              child: Text(strings.translationClear),
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

/// 内容变化时淡入淡出的文本。
class _FadeText extends StatelessWidget {
  const _FadeText(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _duration,
    layoutBuilder: (current, previous) => Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [...previous, ?current],
    ),
    child: Text(text, key: ValueKey(text), style: style),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.indent});
  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: indent,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 72,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: _FadeText(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 顶部状态卡：总开关、就绪状态、目标语言与近 30 天用量。
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.enabled,
    required this.onEnabledChanged,
    required this.statuses,
    required this.language,
    required this.usage,
    required this.onUsageTap,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final List<(bool, String)> statuses;
  final String language;
  final Future<Map<String, DailyTranslationUsage>> usage;
  final VoidCallback onUsageTap;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = enabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        decoration: BoxDecoration(
          color: enabled
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        // 前景色随开关状态与底色同步过渡。
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: foreground),
          duration: _duration,
          builder: (context, color, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FadeText(
                          enabled
                              ? strings.translationStatusOn
                              : strings.translationStatusOff,
                          style: textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.translationPrivacy,
                          style: textTheme.bodySmall?.copyWith(
                            color: color?.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: strings.translationEnable,
                    child: Switch(value: enabled, onChanged: onEnabledChanged),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (ok, text) in statuses)
                    _StatusChip(ok: ok, text: text, color: color),
                  _StatusChip(
                    icon: Icons.translate,
                    text: language,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: color?.withValues(alpha: 0.12)),
              InkWell(
                onTap: onUsageTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: FutureBuilder<Map<String, DailyTranslationUsage>>(
                    future: usage,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? const {};
                      final now = DateTime.now();
                      final days = [
                        for (var offset = 29; offset >= 0; offset--)
                          data[TranslationUsageStore.dateKey(
                                DateTime(now.year, now.month, now.day - offset),
                              )] ??
                              const DailyTranslationUsage(),
                      ];
                      final pages = days.fold(0, (sum, day) => sum + day.pages);
                      final tokens = days.fold(
                        0,
                        (sum, day) => sum + day.inputTokens + day.outputTokens,
                      );
                      final locale = Localizations.localeOf(
                        context,
                      ).toLanguageTag();
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.translationRecentDays,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: color?.withValues(alpha: 0.8),
                                  ),
                                ),
                                _FadeText(
                                  strings.translationUsageCompact(
                                    pages,
                                    NumberFormat.compact(
                                      locale: locale,
                                    ).format(tokens),
                                  ),
                                  style: textTheme.titleMedium?.copyWith(
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomPaint(
                            size: const Size(10 * 11 - 3, 3 * 11 - 3),
                            painter: _MiniHeatmapPainter(
                              pages: [for (final day in days) day.pages],
                              colors: [
                                (color ?? foreground).withValues(alpha: 0.1),
                                for (final alpha in [0.3, 0.5, 0.75, 1.0])
                                  colorScheme.primary.withValues(alpha: alpha),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.color,
    this.ok,
    this.icon,
  });

  final String text;
  final Color? color;

  /// 就绪状态；为 null 时显示 [icon]。
  final bool? ok;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconData = icon ?? (ok! ? Icons.check : Icons.error_outline);
    final iconColor = ok == false ? colorScheme.error : colorScheme.primary;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: _duration,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              iconData,
              key: ValueKey(iconData),
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: _FadeText(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// 近 30 天的迷你热力图，按列从旧到新排列，每列 3 天。
class _MiniHeatmapPainter extends CustomPainter {
  const _MiniHeatmapPainter({required this.pages, required this.colors});
  final List<int> pages;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = pages.fold<int>(0, math.max);
    final paint = Paint();
    for (var index = 0; index < pages.length; index++) {
      paint.color = colors[translationHeatmapLevel(pages[index], maximum)];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((index ~/ 3) * 11, (index % 3) * 11, 8, 8),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniHeatmapPainter oldDelegate) =>
      oldDelegate.pages != pages || oldDelegate.colors != colors;
}

/// 预翻译页数的连接式分段按钮，选中项圆角与底色以动画过渡。
class _PrefetchSelector extends StatelessWidget {
  const _PrefetchSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.translationPrefetch,
                  style: textTheme.bodyLarge,
                ),
              ),
              _FadeText(
                value == 0
                    ? strings.translationCurrentOnly
                    : strings.translationPrefetchAhead(value),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var count = 0; count <= 5; count++) ...[
                if (count > 0) const SizedBox(width: 4),
                Expanded(
                  child: _SegmentCell(
                    key: ValueKey('translation-prefetch-$count'),
                    label: '$count',
                    selected: value == count,
                    first: count == 0,
                    last: count == 5,
                    onTap: () => onChanged(count),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    super.key,
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final String label;
  final bool selected, first, last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 选中项变为全圆角，两端保留外侧大圆角，其余为小圆角。
    const outer = Radius.circular(12), inner = Radius.circular(4);
    final radius = selected
        ? BorderRadius.circular(18)
        : BorderRadius.horizontal(
            left: first ? outer : inner,
            right: last ? outer : inner,
          );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: _duration,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 译文底色选择：两张带气泡预览的卡片。
class _BubbleStyleSelector extends StatelessWidget {
  const _BubbleStyleSelector({required this.value, required this.onChanged});
  final TranslationBubbleStyle value;
  final ValueChanged<TranslationBubbleStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.translationBubbleStyle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BubbleOption(
                  key: const ValueKey('translation-bubble-sampled'),
                  label: strings.translationSampled,
                  preview: strings.translationBubblePreview,
                  // 示意从气泡取样得到的暖色底。
                  background: const Color(0xFFF3E6C9),
                  foreground: const Color(0xFF3A2E14),
                  selected: value == TranslationBubbleStyle.sampled,
                  onTap: () => onChanged(TranslationBubbleStyle.sampled),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BubbleOption(
                  key: const ValueKey('translation-bubble-white'),
                  label: strings.translationWhite,
                  preview: strings.translationBubblePreview,
                  background: Colors.white,
                  foreground: Colors.black,
                  outlined: true,
                  selected: value == TranslationBubbleStyle.white,
                  onTap: () => onChanged(TranslationBubbleStyle.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleOption extends StatelessWidget {
  const _BubbleOption({
    super.key,
    required this.label,
    required this.preview,
    required this.background,
    required this.foreground,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  final String label, preview;
  final Color background, foreground;
  final bool selected, outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: radius,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(22),
                      border: outlined
                          ? Border.all(color: const Color(0xFFDDE4E1))
                          : null,
                    ),
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: textTheme.labelLarge,
                          maxLines: 2,
                        ),
                      ),
                      AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: _duration,
                        curve: selected ? Curves.easeOutBack : Curves.easeIn,
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
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
