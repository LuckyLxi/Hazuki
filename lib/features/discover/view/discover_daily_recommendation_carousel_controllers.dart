import 'dart:async';

import 'package:flutter/widgets.dart';

/// Manages the auto-play timer for the carousel.
/// Callers decide when to arm/cancel; this class only owns the timer lifecycle.
class CarouselAutoPlayController {
  Timer? _timer;

  bool get isArmed => _timer != null;

  void arm({required Duration interval, required VoidCallback onTick}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// Manages the [PageController] lifecycle and infinite-loop boundary
/// normalization for the carousel.
class CarouselLoopPageController {
  CarouselLoopPageController({
    required this.onBoundaryJumpApplied,
    required this.onLog,
  });

  final VoidCallback onBoundaryJumpApplied;
  final void Function(String title, {Map<String, Object?>? content}) onLog;

  late PageController pageController;
  bool isNormalizingLoopBoundary = false;
  bool _disposed = false;

  void initPageController({
    required int initialPage,
    required double viewportFraction,
  }) {
    pageController = PageController(
      initialPage: initialPage,
      viewportFraction: viewportFraction,
    );
  }

  /// Disposes the current controller and creates a new one at [currentPage].
  void rebuildPageController({
    required int currentPage,
    required double viewportFraction,
  }) {
    pageController.dispose();
    pageController = PageController(
      initialPage: currentPage,
      viewportFraction: viewportFraction,
    );
  }

  /// Detects whether the settled page is in the ghost zone and schedules a
  /// silent jump back into the real range. [recommendationCount] must be > 1.
  void normalizeLoopBoundary({required int recommendationCount}) {
    if (!pageController.hasClients ||
        isNormalizingLoopBoundary ||
        recommendationCount <= 1) {
      return;
    }
    final settledPage = pageController.page?.round();
    if (settledPage == null) return;

    if (settledPage <= 1) {
      onLog(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': settledPage + recommendationCount,
        },
      );
      _scheduleJump(settledPage + recommendationCount);
    } else if (settledPage >= recommendationCount + 2) {
      onLog(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': settledPage - recommendationCount,
        },
      );
      _scheduleJump(settledPage - recommendationCount);
    }
  }

  void _scheduleJump(int targetPage) {
    isNormalizingLoopBoundary = true;
    onLog(
      'Discover carousel loop boundary jump scheduled',
      content: {'targetPhysicalPage': targetPage},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !pageController.hasClients) {
        isNormalizingLoopBoundary = false;
        onLog(
          'Discover carousel loop boundary jump aborted',
          content: {'targetPhysicalPage': targetPage},
        );
        return;
      }
      pageController.jumpToPage(targetPage);
      isNormalizingLoopBoundary = false;
      onLog(
        'Discover carousel loop boundary jump applied',
        content: {'targetPhysicalPage': targetPage},
      );
      onBoundaryJumpApplied();
    });
  }

  void dispose() {
    _disposed = true;
    pageController.dispose();
  }
}
