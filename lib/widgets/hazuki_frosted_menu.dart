import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
class HazukiFrostedMenuOption<T> {
  const HazukiFrostedMenuOption({
    required this.value,
    required this.label,
    this.key,
  }) : children = const [];

  const HazukiFrostedMenuOption.submenu({
    required this.label,
    required this.children,
    this.key,
  }) : value = null;

  final T? value;
  final String label;
  final Key? key;
  final List<HazukiFrostedMenuOption<T>> children;

  bool containsValue(T? selected) => children.isEmpty
      ? value == selected
      : selected != null && children.any((e) => e.containsValue(selected));
}

Future<T?> showHazukiFrostedMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<HazukiFrostedMenuOption<T>> options,
  T? selected,
  String? label,
  String keyPrefix = 'hazuki-frosted-menu',
  Listenable? dismissOn,
  bool waitForDismissal = false,
}) async {
  if (options.isEmpty || anchorKey.currentContext == null) return null;
  final anchor = anchorKey.currentContext!.findRenderObject() as RenderBox?;
  if (anchor == null || !anchor.attached) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final strings = MaterialLocalizations.of(context);
  final route = _HazukiFrostedMenuRoute<T>(
    anchor: anchor,
    options: options,
    selected: selected,
    label: label ?? strings.popupMenuLabel,
    keyPrefix: keyPrefix,
    closeLabel: strings.modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  void dismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) => route.dismiss());
  }

  dismissOn?.addListener(dismiss);
  try {
    final result = await navigator.push<T>(route);
    if (waitForDismissal) await route.completed;
    return result;
  } finally {
    dismissOn?.removeListener(dismiss);
  }
}

class _HazukiFrostedMenuRoute<T> extends PopupRoute<T> {
  _HazukiFrostedMenuRoute({
    required this.anchor,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required String closeLabel,
    required this.themes,
    this.header,
  }) : barrierLabel = closeLabel;

  final RenderBox anchor;
  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String keyPrefix;
  final CapturedThemes themes;
  final String? header;
  CurvedAnimation? _progress;
  CurvedAnimation? _depthProgress;
  bool _openingSubmenu = false;
  _HazukiFrostedMenuRoute<T>? _submenu;

  void dismiss() {
    _submenu?.dismiss();
    if (isActive) navigator?.removeRoute(this);
  }

  Future<void> _select(HazukiFrostedMenuOption<T> option, GlobalKey key) async {
    if (!isCurrent ||
        _openingSubmenu ||
        animation!.status == AnimationStatus.reverse) {
      return;
    }
    if (option.children.isEmpty) {
      navigator!.pop(option.value);
      return;
    }
    final submenuAnchor = key.currentContext?.findRenderObject() as RenderBox?;
    if (submenuAnchor == null || !submenuAnchor.attached) return;
    _openingSubmenu = true;
    final routeNavigator = navigator!;
    final submenu = _submenu = _HazukiFrostedMenuRoute<T>(
      anchor: submenuAnchor,
      selected: selected,
      options: option.children,
      label: option.label,
      header: option.label,
      keyPrefix: '$keyPrefix-submenu',
      closeLabel: barrierLabel,
      themes: themes,
    );
    final value = await routeNavigator.push<T>(submenu);
    // Keep the parent dimmed until the child has finished closing.
    await submenu.completed;
    _submenu = null;
    _openingSubmenu = false;
    if (value != null && isCurrent) routeNavigator.pop(value);
  }

  @override
  void dispose() {
    _progress?.dispose();
    _depthProgress?.dispose();
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
    final depthAnimation = _depthProgress ??= CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return themes.wrap(
      LayoutBuilder(
        builder: (context, constraints) {
          final overlay =
              navigator?.overlay?.context.findRenderObject() as RenderBox?;
          if (!anchor.attached || overlay == null) {
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
            ),
            child: AnimatedBuilder(
              animation: progressAnimation,
              child: ScaleTransition(
                key: ValueKey('$keyPrefix-depth-scale'),
                scale: Tween<double>(
                  begin: 1,
                  end: 0.96,
                ).animate(depthAnimation),
                child: IntrinsicWidth(
                  child: _FrostedMenuSurface<T>(
                    animation: progressAnimation,
                    dimAnimation: depthAnimation,
                    selected: selected,
                    options: options,
                    label: label,
                    header: header,
                    keyPrefix: keyPrefix,
                    onSelected: _select,
                    onBack: () {
                      if (isCurrent &&
                          animation.status != AnimationStatus.reverse) {
                        navigator!.pop();
                      }
                    },
                  ),
                ),
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
  const _FrostedMenuLayout({required this.anchorRect, required this.bounds});

  final Rect anchorRect;
  final Rect bounds;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(240.0, math.max(0.0, bounds.width));
    return BoxConstraints(
      maxWidth: width,
      maxHeight: math.max(0, bounds.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (anchorRect.right - childSize.width).clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - childSize.width),
    ),
    anchorRect.top.clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - childSize.height),
    ),
  );

  @override
  bool shouldRelayout(_FrostedMenuLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect || bounds != oldDelegate.bounds;
}

class _FrostedMenuSurface<T> extends StatelessWidget {
  const _FrostedMenuSurface({
    required this.animation,
    required this.dimAnimation,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required this.onSelected,
    required this.onBack,
    this.header,
  });

  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String? header;
  final String keyPrefix;
  final Animation<double> animation;
  final Animation<double> dimAnimation;
  final void Function(HazukiFrostedMenuOption<T>, GlobalKey) onSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(28);
    return _AnimatedMenuGlass(
      animation: animation,
      dimAnimation: dimAnimation,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) ...[
                    InkWell(
                      key: ValueKey('$keyPrefix-back'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: onBack,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                header!,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.expand_less_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16, indent: 16, endIndent: 16),
                  ],
                  for (final option in options)
                    _FrostedMenuItemAnchor<T>(
                      builder: (anchorKey) => Semantics(
                        selected: option.containsValue(selected),
                        expanded: option.children.isEmpty ? null : false,
                        child: InkWell(
                          key:
                              option.key ??
                              (option.children.isEmpty
                                  ? ValueKey((keyPrefix, option.value as T))
                                  : ValueKey((keyPrefix, option.label))),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onSelected(option, anchorKey),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: option.containsValue(selected)
                                  ? scheme.primaryContainer.withValues(
                                      alpha: 0.5,
                                    )
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
                                    Flexible(
                                      child: Text(
                                        option.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color:
                                                  option.containsValue(selected)
                                                  ? scheme.primary
                                                  : scheme.onSurface,
                                              fontWeight:
                                                  option.containsValue(selected)
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 20,
                                      child: option.children.isNotEmpty
                                          ? const Icon(
                                              Icons.expand_more_rounded,
                                              size: 20,
                                            )
                                          : option.containsValue(selected)
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

class _FrostedMenuItemAnchor<T> extends StatefulWidget {
  const _FrostedMenuItemAnchor({required this.builder});
  final Widget Function(GlobalKey) builder;

  @override
  State<_FrostedMenuItemAnchor<T>> createState() =>
      _FrostedMenuItemAnchorState<T>();
}

class _FrostedMenuItemAnchorState<T> extends State<_FrostedMenuItemAnchor<T>> {
  final _key = GlobalKey();
  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.builder(_key));
}

class _AnimatedMenuGlass extends StatelessWidget {
  const _AnimatedMenuGlass({
    required this.animation,
    required this.dimAnimation,
    required this.child,
    required this.keyPrefix,
  });

  final String keyPrefix;

  final Animation<double> animation;
  final Animation<double> dimAnimation;
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
                child: AnimatedBuilder(
                  animation: dimAnimation,
                  child: foreground,
                  builder: (context, child) => DecoratedBox(
                    key: ValueKey('$keyPrefix-dim'),
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.45 * dimAnimation.value,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
