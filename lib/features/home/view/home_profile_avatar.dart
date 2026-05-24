import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

class HomeProfileAvatar extends StatelessWidget {
  const HomeProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.loading,
    required this.size,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.heroEnabled = false,
    this.borderRadius,
  });

  final String? avatarUrl;
  final bool loading;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool heroEnabled;
  final BorderRadius? borderRadius;

  bool get _useRoundedRectangle => borderRadius != null;

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = (avatarUrl ?? '').trim();
    final radius = size / 2;
    final contentSize = (size - borderWidth * 2).clamp(0.0, size).toDouble();
    final borderRadius = this.borderRadius;
    final fallbackIcon = Icon(
      Icons.person_outline,
      size: contentSize * 0.58,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        border: borderWidth > 0
            ? Border.all(
                color:
                    borderColor ?? Theme.of(context).colorScheme.outlineVariant,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        child: loading
            ? HazukiShimmerLoading(width: contentSize, height: contentSize)
            : resolvedAvatarUrl.isEmpty
            ? Center(child: fallbackIcon)
            : _useRoundedRectangle
            ? HazukiCachedImage(
                url: resolvedAvatarUrl,
                width: contentSize,
                height: contentSize,
                fit: BoxFit.cover,
                error: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                loading: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                ignoreNoImageMode: true,
              )
            : HazukiCachedCircleAvatar(
                radius: contentSize / 2,
                url: resolvedAvatarUrl,
                useShimmerFallback: true,
                ignoreNoImageMode: true,
              ),
      ),
    );

    return HeroMode(
      enabled: heroEnabled,
      child: Hero(
        tag: homeProfileAvatarHeroTag,
        child: Material(
          type: MaterialType.transparency,
          shape: borderRadius == null
              ? CircleBorder(side: _heroBorderSide(context))
              : RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: _heroBorderSide(context),
                ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: radius * 2, height: radius * 2, child: avatar),
        ),
      ),
    );
  }

  BorderSide _heroBorderSide(BuildContext context) {
    if (borderWidth <= 0) {
      return BorderSide.none;
    }
    return BorderSide(
      color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
      width: borderWidth,
    );
  }
}
