import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
class HazukiFrostedMenuOption<T> {
  const HazukiFrostedMenuOption({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

Future<T?> showHazukiFrostedMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<HazukiFrostedMenuOption<T>> options,
  T? selected,
  String? label,
  String keyPrefix = 'hazuki-frosted-menu',
}) async {
  if (options.isEmpty || anchorKey.currentContext == null) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final strings = MaterialLocalizations.of(context);
  return navigator.push<T>(
    _HazukiFrostedMenuRoute<T>(
      anchorKey: anchorKey,
      options: options,
      selected: selected,
      label: label ?? strings.popupMenuLabel,
      keyPrefix: keyPrefix,
      closeLabel: strings.modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

class _HazukiFrostedMenuRoute<T> extends PopupRoute<T> {
  _HazukiFrostedMenuRoute({
    required this.anchorKey,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required String closeLabel,
    required this.themes,
  }) : barrierLabel = closeLabel;

  final GlobalKey anchorKey;
  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String keyPrefix;
  final CapturedThemes themes;
  CurvedAnimation? _progress;

  @override
  void dispose() {
    _progress?.dispose();
    super.dispose();
  }

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final progressAnimation = _progress ??= CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return themes.wrap(
      LayoutBuilder(
        builder: (context, constraints) {
          final anchor =
              anchorKey.currentContext?.findRenderObject() as RenderBox?;
          final overlay =
              navigator?.overlay?.context.findRenderObject() as RenderBox?;
          if (anchor == null || !anchor.attached || overlay == null) {
            return const SizedBox.shrink();
          }
          final anchorRect =
              anchor.localToGlobal(Offset.zero, ancestor: overlay) &
              anchor.size;
          final media = MediaQuery.of(context);
          final bounds = Rect.fromLTRB(
            media.padding.left + 12,
            media.padding.top + 12,
            constraints.maxWidth - media.padding.right - 12,
            constraints.maxHeight -
                math.max(media.padding.bottom, media.viewInsets.bottom) -
                12,
          );
          final below =
              bounds.bottom - anchorRect.bottom >= anchorRect.top - bounds.top;
          return CustomSingleChildLayout(
            delegate: _FrostedMenuLayout(
              anchorRect: anchorRect,
              bounds: bounds,
              below: below,
            ),
            child: AnimatedBuilder(
              animation: progressAnimation,
              child: _FrostedMenuSurface<T>(
                animation: progressAnimation,
                selected: selected,
                options: options,
                label: label,
                keyPrefix: keyPrefix,
                onSelected: (mode) {
                  if (isCurrent &&
                      animation.status != AnimationStatus.reverse) {
                    navigator!.pop(mode);
                  }
                },
              ),
              builder: (context, child) {
                final progress = progressAnimation.value;
                return IgnorePointer(
                  ignoring: animation.status == AnimationStatus.reverse,
                  child: FractionalTranslation(
                    translation: Offset(
                      0,
                      (below ? -0.06 : 0.06) * (1 - progress),
                    ),
                    child: Transform.scale(
                      key: ValueKey('$keyPrefix-scale'),
                      alignment: below
                          ? Alignment.topRight
                          : Alignment.bottomRight,
                      scale: ui.lerpDouble(0.86, 1, progress),
                      child: child,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FrostedMenuLayout extends SingleChildLayoutDelegate {
  const _FrostedMenuLayout({
    required this.anchorRect,
    required this.bounds,
    required this.below,
  });

  final Rect anchorRect;
  final Rect bounds;
  final bool below;
  static const gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(240.0, math.max(0.0, bounds.width));
    final availableHeight = below
        ? bounds.bottom - anchorRect.bottom - gap
        : anchorRect.top - bounds.top - gap;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, availableHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (anchorRect.right - childSize.width).clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - childSize.width),
    ),
    below ? anchorRect.bottom + gap : anchorRect.top - gap - childSize.height,
  );

  @override
  bool shouldRelayout(_FrostedMenuLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      bounds != oldDelegate.bounds ||
      below != oldDelegate.below;
}

class _FrostedMenuSurface<T> extends StatelessWidget {
  const _FrostedMenuSurface({
    required this.animation,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required this.onSelected,
  });

  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String keyPrefix;
  final Animation<double> animation;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(28);
    return _AnimatedMenuGlass(
      animation: animation,
      keyPrefix: keyPrefix,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHigh.withValues(alpha: 0.82),
              scheme.surfaceContainerHigh.withValues(alpha: 0.66),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: label,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    Semantics(
                      selected: option.value == selected,
                      child: InkWell(
                        key: option.key ?? ValueKey((keyPrefix, option.value)),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onSelected(option.value),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: option.value == selected
                                ? scheme.primaryContainer.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: option.value == selected
                                                ? scheme.primary
                                                : scheme.onSurface,
                                            fontWeight: option.value == selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 20,
                                    child: option.value == selected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color: scheme.primary,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
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

class _AnimatedMenuGlass extends StatelessWidget {
  const _AnimatedMenuGlass({
    required this.animation,
    required this.child,
    required this.keyPrefix,
  });

  final String keyPrefix;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, foreground) {
        final progress = animation.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16 * progress),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            key: ValueKey('$keyPrefix-surface'),
            borderRadius: radius,
            child: BackdropFilter(
              // Keep the backdrop outside Opacity's offscreen buffer so it can
              // sample the page during every opening and closing frame.
              filter: ui.ImageFilter.blur(
                sigmaX: 24 * progress,
                sigmaY: 24 * progress,
              ),
              child: Opacity(
                key: ValueKey('$keyPrefix-opacity'),
                opacity: progress,
                child: foreground,
              ),
            ),
          ),
        );
      },
    );
  }
}
