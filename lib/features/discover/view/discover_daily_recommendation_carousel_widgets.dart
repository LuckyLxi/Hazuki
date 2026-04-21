import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';

class DiscoverCarouselPagePhysics extends PageScrollPhysics {
  const DiscoverCarouselPagePhysics({super.parent});

  static const SpringDescription _mediumSnapSpring = SpringDescription(
    mass: 1.0,
    stiffness: 1500,
    damping: 77.46,
  );

  @override
  DiscoverCarouselPagePhysics applyTo(ScrollPhysics? ancestor) {
    return DiscoverCarouselPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => _mediumSnapSpring;
}

class DiscoverCarouselAutoPlayCurve extends Curve {
  const DiscoverCarouselAutoPlayCurve();

  static const Curve _segment1 = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve _segment2 = Cubic(0.05, 0.7, 0.1, 1.0);
  static const double _split = 0.166666;

  @override
  double transformInternal(double t) {
    if (t <= 0.0) {
      return 0.0;
    }
    if (t >= 1.0) {
      return 1.0;
    }
    if (t < _split) {
      final localT = t / _split;
      return _segment1.transform(localT) * 0.4;
    }
    final localT = (t - _split) / (1.0 - _split);
    return 0.4 + (_segment2.transform(localT) * 0.6);
  }
}

class DiscoverDailyRecommendationCarouselCard extends StatelessWidget {
  const DiscoverDailyRecommendationCarouselCard({
    super.key,
    required this.physicalIndex,
    required this.entry,
    required this.heroTag,
    required this.heroCardWidth,
    required this.heroCardHeight,
    required this.clippedWidth,
    required this.outerTranslateX,
    required this.imageTranslateX,
    required this.cardScale,
    required this.cardOpacity,
    required this.hideOverlay,
    required this.imageChild,
    required this.onTap,
  });

  final int physicalIndex;
  final DiscoverDailyRecommendationEntry entry;
  final String heroTag;
  final double heroCardWidth;
  final double heroCardHeight;
  final double clippedWidth;
  final double outerTranslateX;
  final double imageTranslateX;
  final double cardScale;
  final double cardOpacity;
  final bool hideOverlay;
  final Widget imageChild;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(outerTranslateX, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Opacity(
          opacity: cardOpacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: cardScale,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              key: ValueKey(
                'discover_daily_recommendation_card_$physicalIndex',
              ),
              width: clippedWidth,
              height: heroCardHeight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: heroTag,
                          flightShuttleBuilder:
                              buildComicCoverHeroFlightShuttle,
                          placeholderBuilder: buildComicCoverHeroPlaceholder,
                          child: OverflowBox(
                            alignment: Alignment.center,
                            minWidth: heroCardWidth,
                            maxWidth: heroCardWidth,
                            child: Transform.translate(
                              offset: Offset(imageTranslateX, 0),
                              child: SizedBox(
                                width: heroCardWidth,
                                height: heroCardHeight,
                                child: imageChild,
                              ),
                            ),
                          ),
                        ),
                        _DiscoverDailyRecommendationCardOverlay(
                          entry: entry,
                          isHidden: hideOverlay,
                          heroTag: heroTag,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoverDailyRecommendationIndicators extends StatelessWidget {
  const DiscoverDailyRecommendationIndicators({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int index = 0; index < count; index++)
          AnimatedContainer(
            key: ValueKey('discover_daily_recommendation_indicator_$index'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: index == currentIndex ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == currentIndex
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _DiscoverDailyRecommendationCardOverlay extends StatefulWidget {
  const _DiscoverDailyRecommendationCardOverlay({
    required this.entry,
    required this.isHidden,
    required this.heroTag,
  });

  final DiscoverDailyRecommendationEntry entry;
  final bool isHidden;
  final String heroTag;

  @override
  State<_DiscoverDailyRecommendationCardOverlay> createState() =>
      _DiscoverDailyRecommendationCardOverlayState();
}

class _DiscoverDailyRecommendationCardOverlayState
    extends State<_DiscoverDailyRecommendationCardOverlay> {
  static const Duration _overlayRevealDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisible = !widget.isHidden;
    final revealDuration = isVisible ? _overlayRevealDuration : Duration.zero;
    return AnimatedOpacity(
      key: ValueKey('discover_daily_recommendation_overlay_${widget.heroTag}'),
      opacity: isVisible ? 1.0 : 0.0,
      duration: revealDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 0.05),
        duration: revealDuration,
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.61),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.entry.comic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
