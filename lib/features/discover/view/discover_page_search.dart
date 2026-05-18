import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/search_box_outline.dart';

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
  });

  final double height;
  final double borderRadius;
  final double horizontalPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: IgnorePointer(
        child: SizedBox(
          height: height,
          child: SearchBar(
            hintText: AppLocalizations.of(context)!.searchHint,
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(
              hazukiSearchBoxBackgroundColor(context),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                side: hazukiSearchBoxOutlineSide(context),
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
    );
  }
}
