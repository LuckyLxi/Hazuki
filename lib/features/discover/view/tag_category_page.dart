import 'package:hazuki/shared/source_task_owner.dart';
import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/hazuki_models.dart';
import '../../../services/source/source_capabilities.dart';
import '../../../shared/navigation_tags.dart';
import '../../../widgets/widgets.dart';
import '../../../widgets/windows_comic_detail_host.dart';
import 'package:hazuki/shared/category_tag_navigation.dart';
import 'package:hazuki/shared/navigation/route_transition_settled.dart';
import 'discover_section_page.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

class TagCategoryPage extends StatefulWidget {
  final SourceTaskControlGateway taskControl;
  const TagCategoryPage({
    required this.taskControl,
    super.key,
    required this.searchPageBuilder,
    required this.comicDetailPageBuilder,
    required this.categorySource,
    required this.discoverSource,
  });

  final Widget Function(String tag) searchPageBuilder;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final SourceCategoryGateway categorySource;
  final SourceDiscoverGateway discoverSource;

  @override
  State<TagCategoryPage> createState() => _TagCategoryPageState();
}

class _TagCategoryGroupCard extends StatelessWidget {
  const _TagCategoryGroupCard({required this.group, required this.onOpenTag});

  final CategoryTagGroup group;
  final void Function(CategoryTagGroup group, int index) onOpenTag;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.tags.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tag = entry.value;
                    return ActionChip(
                      label: Text(tag),
                      onPressed: () => onOpenTag(group, index),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组出现动画：淡入并从下方轻微上移。
///
/// 只驱动透明度和位移，内部卡片作为固定 child 不会随动画重建；
/// 卡片自带 RepaintBoundary，淡入时只合成已缓存的图层。
class _TagCategoryGroupReveal extends StatefulWidget {
  const _TagCategoryGroupReveal({
    required this.animateOnAppear,
    required this.child,
  });

  final bool Function() animateOnAppear;
  final Widget child;

  @override
  State<_TagCategoryGroupReveal> createState() =>
      _TagCategoryGroupRevealState();
}

class _TagCategoryGroupRevealState extends State<_TagCategoryGroupReveal>
    with SingleTickerProviderStateMixin {
  static const double _riseDistance = 16;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final animate = widget.animateOnAppear();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: animate ? 0 : 1,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _progress.value) * _riseDistance),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _TagCategoryPageState extends State<TagCategoryPage>
    with RouteTransitionSettledMixin {
  final _sourceUi = SourceUiOwner();
  late final _readTasks = SourceTaskOwner(widget.taskControl);
  static const _loadTimeout = Duration(seconds: 25);

  SourceCategoryGateway get _sourceService => widget.categorySource;

  List<CategoryTagGroup> _tagGroups = const <CategoryTagGroup>[];

  String? _errorMessage;

  bool _initialLoading = true;
  late final DateTime _sessionStartedAt;
  late final String _sessionId;
  bool _frameTimingsCallbackAttached = false;
  DateTime? _lastJankLogAt;
  // 分组卡片只在数据到达时创建一次，逐组展开时已显示的卡片复用同一实例而不重建
  List<Widget> _groupCards = const <Widget>[];
  int _visibleGroupCount = 0;
  int _revealGeneration = 0;
  bool _revealStarted = false;
  bool _revealingGroups = false;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _sessionId = _sessionStartedAt.microsecondsSinceEpoch.toString();
    if (_sourceService.softwareLogCaptureEnabled) {
      WidgetsBinding.instance.addTimingsCallback(_handleFrameTimings);
      _frameTimingsCallbackAttached = true;
    }
    _logTagCategoryEvent('Tag category session started');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _logTagCategoryEvent(
        'Tag category initial load queued',
        content: {
          'entryToFirstFrameMs': DateTime.now()
              .difference(_sessionStartedAt)
              .inMilliseconds,
        },
      );
      unawaited(_loadInitial());
    });
  }

  @override
  void dispose() {
    _readTasks.dispose();
    _sourceUi.dispose();
    _logTagCategoryEvent('Tag category session ended');
    if (_frameTimingsCallbackAttached) {
      WidgetsBinding.instance.removeTimingsCallback(_handleFrameTimings);
    }
    super.dispose();
  }

  void _logTagCategoryEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    _sourceService.addApplicationLog(
      level: level,
      title: title,
      source: 'tag_category',
      content: {
        'sessionId': _sessionId,
        'entryElapsedMs': DateTime.now()
            .difference(_sessionStartedAt)
            .inMilliseconds,
        'initialLoading': _initialLoading,
        'groupCount': _tagGroups.length,
        'tagCount': _tagGroups.fold<int>(
          0,
          (sum, group) => sum + group.tags.length,
        ),
        if (_errorMessage != null) 'errorMessage': _errorMessage,
        ...?content,
      },
    );
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!mounted || !_sourceService.softwareLogCaptureEnabled) {
      return;
    }
    for (final timing in timings) {
      final totalMs = timing.totalSpan.inMilliseconds;
      final buildMs = timing.buildDuration.inMilliseconds;
      final rasterMs = timing.rasterDuration.inMilliseconds;
      if (totalMs < 32 && buildMs < 16 && rasterMs < 16) {
        continue;
      }
      final now = DateTime.now();
      if (_lastJankLogAt != null &&
          now.difference(_lastJankLogAt!) <
              const Duration(milliseconds: 1200)) {
        return;
      }
      _lastJankLogAt = now;
      _logTagCategoryEvent(
        'Tag category jank frame',
        level: 'warn',
        content: {'totalMs': totalMs, 'buildMs': buildMs, 'rasterMs': rasterMs},
      );
      return;
    }
  }

  Future<List<CategoryTagGroup>> _loadTagGroups() {
    final timeoutMessage = AppLocalizations.of(context)!.tagCategoryLoadTimeout;
    return _sourceUi.run(
      () => SourceUiScope.timeout(
        _sourceService.loadCategoryTagGroups(taskOrigin: _readTasks.origin()),
        _loadTimeout,
        onTimeout: () => throw Exception(timeoutMessage),
      ),
    );
  }

  Future<void> _loadInitial() async {
    _readTasks.restart();
    if (!mounted) {
      return;
    }

    if (!_initialLoading) {
      setState(() {
        _initialLoading = true;
        _errorMessage = null;
        _resetGroupReveal();
      });
    }

    final startedAt = DateTime.now();
    _logTagCategoryEvent('Tag category load started');

    try {
      final tagGroups = await _loadTagGroups();
      if (!mounted) {
        return;
      }

      setState(() {
        _tagGroups = tagGroups;
        _groupCards = [
          for (final group in tagGroups)
            _TagCategoryGroupReveal(
              animateOnAppear: _isRevealingGroups,
              child: _TagCategoryGroupCard(group: group, onOpenTag: _openTag),
            ),
        ];
        _errorMessage = null;
        _initialLoading = false;
        _resetGroupReveal();
        _startGroupReveal();
      });
      _logTagCategoryEvent(
        'Tag category load succeeded',
        content: {
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'groupCount': tagGroups.length,
          'tagCount': tagGroups.fold<int>(
            0,
            (sum, group) => sum + group.tags.length,
          ),
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = AppLocalizations.of(context)!.tagCategoryLoadFailed('$e');
      setState(() {
        _errorMessage = message;
        _initialLoading = false;
      });
      _logTagCategoryEvent(
        'Tag category load failed',
        level: 'error',
        content: {
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'error': e.toString(),
        },
      );
    }
  }

  @override
  void didSettleRouteTransition() => _startGroupReveal();

  void _resetGroupReveal() {
    _revealGeneration++;
    _revealStarted = false;
    _revealingGroups = false;
    _visibleGroupCount = 0;
  }

  /// 逐组展开期间新出现的分组播放出现动画；展开结束后滚动带出的分组直接显示
  bool _isRevealingGroups() => _revealingGroups;

  /// 入场动画结束且数据已到达后，每帧多显示一组，把标签构建分摊到多帧
  void _startGroupReveal() {
    if (_revealStarted || !routeTransitionSettled || _initialLoading) return;
    if (_groupCards.isEmpty) return;
    _revealStarted = true;
    _revealingGroups = true;
    _visibleGroupCount = 1;
    _scheduleNextGroupReveal(_revealGeneration);
  }

  void _scheduleNextGroupReveal(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _revealGeneration) return;
      if (_visibleGroupCount >= _groupCards.length) {
        _revealingGroups = false;
        return;
      }
      setState(() => _visibleGroupCount++);
      _scheduleNextGroupReveal(generation);
    });
  }

  void _openTag(CategoryTagGroup group, int index) {
    final tag = group.tags[index];
    final target = resolveCategoryTagNavigationTarget(<CategoryTagGroup>[
      group,
    ], tag);
    if (target != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DiscoverSectionPage(
            section: ExploreSection(
              title: target.title,
              comics: const <ExploreComic>[],
              viewMoreUrl: target.viewMoreUrl,
            ),
            comicDetailPageBuilder: widget.comicDetailPageBuilder,
            sourceService: widget.discoverSource,
            taskControl: widget.taskControl,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.searchPageBuilder(tag)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return WindowsComicDetailHost(
      suppressExistingPanel: true,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.tagCategoryTitle),
        ),
        // 过渡动画结束前保持加载态，避免大量标签的构建挤进动画帧
        body: _initialLoading || !routeTransitionSettled
            ? ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HazukiSandyLoadingIndicator(size: 136),
                        const SizedBox(height: 10),
                        Text(strings.commonLoading),
                      ],
                    ),
                  ),
                ],
              )
            : (_errorMessage != null && _tagGroups.isEmpty)
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 90),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: () {
                        unawaited(_loadInitial());
                      },
                      child: Text(strings.commonRetry),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: _visibleGroupCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (_tagGroups.isNotEmpty) ...[
                          Text(
                            strings.tagCategoryTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                        ] else
                          Text(strings.tagCategoryEmpty),
                      ],
                    );
                  }

                  return _groupCards[index - 1];
                },
              ),
      ),
    );
  }
}
