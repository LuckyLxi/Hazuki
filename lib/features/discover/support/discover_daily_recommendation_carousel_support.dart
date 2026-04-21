import 'dart:math' as math;

import 'package:hazuki/services/discover_daily_recommendation_service.dart';

class DiscoverCarouselLoopMetrics {
  const DiscoverCarouselLoopMetrics({required this.recommendationCount});

  final int recommendationCount;

  bool get isLooping => recommendationCount > 1;

  int get loopedItemCount =>
      isLooping ? recommendationCount + 5 : recommendationCount;

  int get initialPhysicalPage => isLooping ? 2 : 0;

  int physicalPageForLogical(int logicalPage) {
    if (!isLooping) {
      return logicalPage;
    }
    return logicalPage + 2;
  }

  int logicalPageForPhysical(int physicalPage) {
    if (recommendationCount == 0) {
      return 0;
    }
    if (!isLooping) {
      return physicalPage.clamp(0, recommendationCount - 1);
    }
    final normalized = (physicalPage - 2) % recommendationCount;
    return normalized < 0 ? normalized + recommendationCount : normalized;
  }

  int normalizeLogicalPage(int logicalPage) {
    if (recommendationCount == 0) {
      return 0;
    }
    final normalized = logicalPage % recommendationCount;
    return normalized < 0 ? normalized + recommendationCount : normalized;
  }

  List<int> coverWarmUpOrder(int anchorLogicalPage) {
    if (recommendationCount == 0) {
      return const <int>[];
    }
    final order = <int>[];
    for (var offset = 0; offset < recommendationCount; offset++) {
      order.add(normalizeLogicalPage(anchorLogicalPage + offset));
      if (offset > 0) {
        order.add(normalizeLogicalPage(anchorLogicalPage - offset));
      }
    }
    return order.toSet().toList(growable: false);
  }
}

String discoverDailyRecommendationSnapshotKey(
  List<DiscoverDailyRecommendationEntry> recommendations,
) {
  return recommendations
      .map(
        (entry) =>
            '${entry.author}|${entry.comic.id}|${entry.comic.title}|${entry.comic.cover}',
      )
      .join('||');
}

class DiscoverCarouselCardLayoutMetrics {
  const DiscoverCarouselCardLayoutMetrics({
    required this.clipScaleX,
    required this.imageTranslateX,
    required this.cardScale,
    required this.cardOpacity,
    required this.outerTranslateX,
  });

  final double clipScaleX;
  final double imageTranslateX;
  final double cardScale;
  final double cardOpacity;
  final double outerTranslateX;

  double clippedWidth(double heroCardWidth) {
    return (heroCardWidth * clipScaleX).clamp(0.0, heroCardWidth);
  }

  double visibleWidth({
    required double heroCardWidth,
    required double viewportWidth,
  }) {
    final width = clippedWidth(heroCardWidth);
    if (width <= 0 || cardOpacity <= 0.001) {
      return 0;
    }
    final left = outerTranslateX;
    final right = left + width;
    final visibleLeft = math.max(0.0, left);
    final visibleRight = math.min(viewportWidth, right);
    return math.max(0.0, visibleRight - visibleLeft);
  }
}

DiscoverCarouselCardLayoutMetrics buildDiscoverCarouselCardLayoutMetrics({
  required double delta,
  required double heroCardWidth,
  required double pageExtent,
  required double itemSpacing,
}) {
  const narrowRatio = 0.29;
  const incomingExpansionHold = 0.72;
  const parallaxRatio = 0.035;
  const trailingSmallRevealDelay = 0.42;

  double clipScaleX;
  double imageTranslateX;
  double cardScale;
  double cardOpacity;
  double outerTranslateX;
  final slotLeft = delta * pageExtent;
  final narrowWidth = heroCardWidth * narrowRatio;

  if (delta >= -1 && delta <= 0) {
    final progress = (-delta).clamp(0.0, 1.0);
    clipScaleX = _lerp(1.0, 0.0, progress);
    imageTranslateX = heroCardWidth * parallaxRatio * progress;
    cardScale = 1.0;
    cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;
    outerTranslateX = -slotLeft;
  } else if (delta > 0 && delta <= 1) {
    final progress = (1 - delta).clamp(0.0, 1.0);
    final lockedRightLeft = itemSpacing + narrowWidth;
    double desiredLeft;

    if (progress < incomingExpansionHold) {
      final phase = progress / incomingExpansionHold;
      clipScaleX = _lerp(narrowRatio, 1.0, phase);
      desiredLeft = _lerp(heroCardWidth + itemSpacing, lockedRightLeft, phase);
    } else {
      final phase =
          (progress - incomingExpansionHold) / (1.0 - incomingExpansionHold);
      clipScaleX = 1.0;
      desiredLeft = _lerp(lockedRightLeft, 0.0, phase);
    }

    imageTranslateX = heroCardWidth * parallaxRatio * (1.0 - progress);
    cardScale = 1.0;
    cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;
    outerTranslateX = desiredLeft - slotLeft;
  } else if (delta > 1 && delta <= 2) {
    final progress = (2 - delta).clamp(0.0, 1.0);

    final lockedRightLeft = itemSpacing + narrowWidth;
    double index1DesiredLeft;
    double index1ClipScaleX;

    if (progress < incomingExpansionHold) {
      final phase = progress / incomingExpansionHold;
      index1ClipScaleX = _lerp(narrowRatio, 1.0, phase);
      index1DesiredLeft = _lerp(
        heroCardWidth + itemSpacing,
        lockedRightLeft,
        phase,
      );
    } else {
      final phase =
          (progress - incomingExpansionHold) / (1.0 - incomingExpansionHold);
      index1ClipScaleX = 1.0;
      index1DesiredLeft = _lerp(lockedRightLeft, 0.0, phase);
    }

    final index1ClippedWidth = (heroCardWidth * index1ClipScaleX).clamp(
      0.0,
      heroCardWidth,
    );
    final index1RightEdge = index1DesiredLeft + index1ClippedWidth;

    final revealProgress =
        ((progress - trailingSmallRevealDelay) /
                (1.0 - trailingSmallRevealDelay))
            .clamp(0.0, 1.0);
    clipScaleX = _lerp(0.0, narrowRatio, revealProgress);
    imageTranslateX = heroCardWidth * parallaxRatio * delta;
    cardScale = 1.0;
    cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;

    final currentX = index1RightEdge + itemSpacing;
    outerTranslateX = currentX - slotLeft;
  } else {
    clipScaleX = 0.0;
    imageTranslateX = 0.0;
    cardScale = 1.0;
    cardOpacity = 0.0;
    outerTranslateX = 0.0;
  }

  return DiscoverCarouselCardLayoutMetrics(
    clipScaleX: clipScaleX,
    imageTranslateX: imageTranslateX,
    cardScale: cardScale,
    cardOpacity: cardOpacity,
    outerTranslateX: outerTranslateX,
  );
}

String describeDiscoverCarouselCardPhase(
  double delta,
  double clipScaleX,
  double cardOpacity,
) {
  if (cardOpacity <= 0.001 || clipScaleX <= 0.001) {
    return 'hidden';
  }
  if (delta >= -0.12 && delta <= 0.12) {
    return 'active';
  }
  if (delta > 0 && clipScaleX <= 0.36) {
    return 'incoming_thumbnail';
  }
  if (delta > 0 && clipScaleX < 0.98) {
    return 'incoming_expand';
  }
  if (delta > 0 && clipScaleX >= 0.98) {
    return 'incoming_full';
  }
  if (delta >= -1.0 && delta < 0) {
    return 'outgoing';
  }
  if (delta > 1.0) {
    return 'trailing_thumbnail';
  }
  return 'transitioning';
}

double roundDiscoverCarouselValue(num value, int fractionDigits) {
  return double.parse(value.toStringAsFixed(fractionDigits));
}

String shortenDiscoverCarouselUrl(String url) {
  final normalized = url.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return normalized.length <= 120
        ? normalized
        : '${normalized.substring(0, 117)}...';
  }
  final host = uri.host;
  final path = uri.pathSegments.isEmpty
      ? uri.path
      : uri.pathSegments
            .skip(uri.pathSegments.length > 2 ? uri.pathSegments.length - 2 : 0)
            .join('/');
  final compact = host.isEmpty ? normalized : '$host/$path';
  return compact.length <= 120 ? compact : '${compact.substring(0, 117)}...';
}

double _lerp(double begin, double end, double t) {
  return begin + (end - begin) * t;
}
