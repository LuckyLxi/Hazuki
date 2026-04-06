import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';

class TagCategoryPage extends StatefulWidget {
  const TagCategoryPage({super.key, required this.searchPageBuilder});

  final Widget Function(String tag) searchPageBuilder;

  @override
  State<TagCategoryPage> createState() => _TagCategoryPageState();
}

class _TagCategoryGroupCard extends StatelessWidget {
  const _TagCategoryGroupCard({
    required this.group,
    required this.onOpenTag,
  });

  final CategoryTagGroup group;
  final ValueChanged<String> onOpenTag;

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
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.tags.map((tag) {
                    return ActionChip(
                      label: Text(tag),
                      onPressed: () => onOpenTag(tag),
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

class _TagCategoryPageState extends State<TagCategoryPage> {
  static const _loadTimeout = Duration(seconds: 25);

  List<CategoryTagGroup> _tagGroups = const <CategoryTagGroup>[];

  String? _errorMessage;

  bool _initialLoading = true;
  late final DateTime _sessionStartedAt;
  late final String _sessionId;
  bool _frameTimingsCallbackAttached = false;
  DateTime? _lastJankLogAt;
  int _visibleGroupCount = 0;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _sessionId = _sessionStartedAt.microsecondsSinceEpoch.toString();
    if (HazukiSourceService.instance.softwareLogCaptureEnabled) {
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
    HazukiSourceService.instance.addApplicationLog(
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
        'tagCount': _tagGroups.fold<int>(0, (sum, group) => sum + group.tags.length),
        if (_errorMessage != null) 'errorMessage': _errorMessage,
        if (content != null) ...content,
      },
    );
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!mounted || !HazukiSourceService.instance.softwareLogCaptureEnabled) {
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
        content: {
          'totalMs': totalMs,
          'buildMs': buildMs,
          'rasterMs': rasterMs,
        },
      );
      return;
    }
  }

  Future<List<CategoryTagGroup>> _loadTagGroups() {
    final timeoutMessage = AppLocalizations.of(context)!.tagCategoryLoadTimeout;
    return HazukiSourceService.instance.loadCategoryTagGroups().timeout(
      _loadTimeout,
      onTimeout: () => throw Exception(timeoutMessage),
    );
  }

  Future<void> _loadInitial() async {
    if (!mounted) {
      return;
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
        _errorMessage = null;
        _initialLoading = false;
        _visibleGroupCount = tagGroups.isEmpty ? 0 : 1;
      });
      if (tagGroups.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _visibleGroupCount = tagGroups.length;
          });
        });
      }
      _logTagCategoryEvent(
        'Tag category load succeeded',
        content: {
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'groupCount': tagGroups.length,
          'tagCount': tagGroups.fold<int>(0, (sum, group) => sum + group.tags.length),
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
        _visibleGroupCount = 0;
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

  void _openSearchByTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.searchPageBuilder(tag)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.tagCategoryTitle),
      ),
      body: _initialLoading
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

                final group = _tagGroups[index - 1];
                return _TagCategoryGroupCard(
                  group: group,
                  onOpenTag: _openSearchByTag,
                );
              },
            ),
    );
  }
}
