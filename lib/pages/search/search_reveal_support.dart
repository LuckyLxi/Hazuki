import 'dart:async';

import 'package:flutter/widgets.dart';

import 'search_shared.dart';

class SearchRevealSupport {
  SearchRevealSupport(this.scrollController);

  final ScrollController scrollController;
  final List<Timer> _timers = <Timer>[];
  double progress = 0;

  bool get showCollapsedSearch => progress >= 0.94;

  double calculateProgress() {
    if (!scrollController.hasClients) {
      return 0;
    }
    return (scrollController.position.pixels / searchAppBarRevealOffset).clamp(
      0.0,
      1.0,
    );
  }

  void sync({
    required bool mounted,
    required void Function(double nextProgress) applyProgress,
    bool force = false,
  }) {
    if (!mounted) {
      return;
    }
    final nextProgress = calculateProgress();
    if (!force && (nextProgress - progress).abs() < 0.01) {
      return;
    }
    progress = nextProgress;
    applyProgress(nextProgress);
  }

  void schedule({
    required bool mounted,
    required void Function(bool force) onSyncRequested,
    bool force = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      onSyncRequested(force);
    });
  }

  void scheduleBurst({
    required bool mounted,
    required void Function(bool force) onSyncRequested,
    bool force = false,
  }) {
    cancelTimers();
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 50),
      Duration(milliseconds: 120),
      Duration(milliseconds: 220),
      Duration(milliseconds: 340),
    ];
    for (final delay in delays) {
      final timer = Timer(delay, () {
        if (!mounted) {
          return;
        }
        schedule(
          mounted: mounted,
          onSyncRequested: onSyncRequested,
          force: force,
        );
      });
      _timers.add(timer);
    }
  }

  void cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() {
    cancelTimers();
  }
}
