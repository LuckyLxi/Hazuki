import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';

class DiscoverAppBarActions extends StatefulWidget {
  const DiscoverAppBarActions({
    super.key,
    required this.isActiveTab,
    required this.morphProgress,
    required this.forceInAppBar,
    required this.onOpenSearch,
    this.searchWidth = 180,
    this.trailingSpacing = 12,
  });

  final bool isActiveTab;
  final double morphProgress;
  final bool forceInAppBar;
  final VoidCallback onOpenSearch;
  final double searchWidth;
  final double trailingSpacing;

  @override
  State<DiscoverAppBarActions> createState() => _DiscoverAppBarActionsState();
}

class _DiscoverAppBarActionsState extends State<DiscoverAppBarActions> {
  bool _suppressPinnedAnimation = false;

  @override
  void didUpdateWidget(covariant DiscoverAppBarActions oldWidget) {
    super.didUpdateWidget(oldWidget);

    final becamePinned =
        oldWidget.isActiveTab &&
        widget.isActiveTab &&
        !oldWidget.forceInAppBar &&
        widget.forceInAppBar &&
        oldWidget.morphProgress < 0.96 &&
        widget.morphProgress < 0.96;
    if (!becamePinned || _suppressPinnedAnimation) {
      return;
    }

    _suppressPinnedAnimation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_suppressPinnedAnimation) {
        return;
      }
      setState(() {
        _suppressPinnedAnimation = false;
      });
    });
  }

  Duration _duration(int milliseconds) {
    return _suppressPinnedAnimation
        ? Duration.zero
        : Duration(milliseconds: milliseconds);
  }

  @override
  Widget build(BuildContext context) {
    final showCollapsedSearch =
        widget.isActiveTab &&
        (widget.forceInAppBar || widget.morphProgress >= 0.96);
    return Row(
      key: const ValueKey<String>('discover-appbar-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        HeroMode(
          enabled: showCollapsedSearch,
          child: Hero(
            tag: discoverSearchHeroTag,
            child: ClipRect(
              child: AnimatedContainer(
                duration: _duration(220),
                curve: Curves.easeOutCubic,
                width: showCollapsedSearch ? widget.searchWidth : 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSlide(
                    offset: showCollapsedSearch
                        ? Offset.zero
                        : const Offset(-0.08, 0),
                    duration: _duration(220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: showCollapsedSearch ? 1 : 0.94,
                      duration: _duration(240),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: showCollapsedSearch ? 1 : 0,
                        duration: _duration(180),
                        curve: Curves.easeOutCubic,
                        child: IgnorePointer(
                          ignoring: !showCollapsedSearch,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: widget.onOpenSearch,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n(context).homeSearchHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
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
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: _duration(220),
          curve: Curves.easeOutCubic,
          width: showCollapsedSearch ? widget.trailingSpacing : 0,
        ),
      ],
    );
  }
}
