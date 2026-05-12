import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/navigation_tags.dart';

class DiscoverTopSearchBox extends StatelessWidget {
  const DiscoverTopSearchBox({
    super.key,
    required this.searchMorphProgress,
    required this.onOpenSearch,
  });

  final double searchMorphProgress;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final hideProgress = Curves.easeOutCubic.transform(searchMorphProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: _DiscoverSearchBox(
              height: 56,
              borderRadius: 16,
              horizontalPadding: 16,
              onTap: searchMorphProgress >= 0.96 ? null : onOpenSearch,
              heroEnabled: searchMorphProgress < 0.96,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverSearchBox extends StatelessWidget {
  const _DiscoverSearchBox({
    required this.height,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.onTap,
    required this.heroEnabled,
  });

  final double height;
  final double borderRadius;
  final double horizontalPadding;
  final VoidCallback? onTap;
  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: heroEnabled,
      child: Hero(
        tag: discoverSearchHeroTag,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: IgnorePointer(
            child: SizedBox(
              height: height,
              child: SearchBar(
                hintText: AppLocalizations.of(context)!.searchHint,
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: horizontalPadding),
                ),
                leading: const Icon(Icons.search),
                trailing: const [Icon(Icons.arrow_forward)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
