import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import '../support/comic_detail_session_controller.dart';
import 'comic_detail_favorite_button.dart';

class ComicDetailHeaderActionRow extends StatelessWidget {
  const ComicDetailHeaderActionRow({
    super.key,
    required this.details,
    required this.actionButtonsKey,
    required this.shouldAnimateInitialDetailReveal,
    this.useMobileStyle = false,
  });

  final ComicDetailsData? details;
  final GlobalKey actionButtonsKey;
  final bool shouldAnimateInitialDetailReveal;
  final bool useMobileStyle;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final actions = scope.actions;
    final session = scope.session;
    final readerButtonLabel = _buildReaderButtonLabel(context, session);
    final labelTransitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final detailsReady = details != null;
    final animateSlide = !useMobileStyle && shouldAnimateInitialDetailReveal;
    final colors = Theme.of(context).colorScheme;
    final chaptersButton = AbsorbPointer(
      absorbing: !detailsReady,
      child: IconButton(
        tooltip: l10n(context).comicDetailChapters,
        style: useMobileStyle
            ? IconButton.styleFrom(
                fixedSize: const Size(48, 48),
                backgroundColor: colors.primary.withValues(alpha: 0.08),
                foregroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              )
            : null,
        onPressed: () {
          if (detailsReady) actions.showChaptersPanel(context, details!);
        },
        icon: const Icon(Icons.format_list_bulleted_rounded),
      ),
    );
    final readerLabel = AnimatedSwitcher(
      duration: labelTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => LayoutBuilder(
        builder: (context, constraints) => Stack(
          alignment: Alignment.center,
          children: [
            // Only the current label determines the target size.
            for (final child in previousChildren)
              Positioned.fill(
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: constraints.maxWidth,
                  child: child,
                ),
              ),
            ?currentChild,
          ],
        ),
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.16),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        readerButtonLabel,
        key: ValueKey(readerButtonLabel),
        maxLines: useMobileStyle ? 1 : null,
        overflow: useMobileStyle ? TextOverflow.ellipsis : null,
      ),
    );
    final readerButton = Expanded(
      child: AbsorbPointer(
        absorbing: !detailsReady,
        child: FilledButton.icon(
          style: useMobileStyle
              ? FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                )
              : null,
          onPressed: () {
            if (detailsReady) unawaited(actions.openReader(context, details!));
          },
          icon: Icon(
            Icons.menu_book_outlined,
            size: useMobileStyle ? 20 : null,
          ),
          label: ClipRect(
            child: labelTransitionDuration == Duration.zero
                ? readerLabel
                : AnimatedSize(
                    duration: labelTransitionDuration,
                    curve: Curves.easeOutCubic,
                    child: readerLabel,
                  ),
          ),
        ),
      ),
    );

    return SizedBox(
      key: actionButtonsKey,
      height: 48,
      child: AnimatedSlide(
        offset: animateSlide
            ? (detailsReady ? Offset.zero : const Offset(0, -0.08))
            : Offset.zero,
        duration: animateSlide
            ? const Duration(milliseconds: 320)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        child: Row(
          children: [
            if (useMobileStyle) ...[
              readerButton,
              const SizedBox(width: 8),
              chaptersButton,
              const SizedBox(width: 8),
              ComicDetailFavoriteButton(details: details),
            ] else ...[
              chaptersButton,
              const SizedBox(width: 8),
              readerButton,
            ],
          ],
        ),
      ),
    );
  }

  String _buildReaderButtonLabel(
    BuildContext context,
    ComicDetailSessionController session,
  ) {
    if (details == null) return l10n(context).comicDetailRead;
    final lastReadProgress = session.lastReadProgress;
    if (lastReadProgress?['cloud'] == true &&
        details!.chapters.containsKey(lastReadProgress?['epId'])) {
      return l10n(context).comicDetailContinueReading(
        details!.chapters[lastReadProgress!['epId']]!,
      );
    }
    if (lastReadProgress != null &&
        details!.chapters.length > 1 &&
        lastReadProgress['index'] is int &&
        (lastReadProgress['index'] as int) >= 1 &&
        details!.chapters.containsKey(lastReadProgress['epId'])) {
      final title = lastReadProgress['title'] as String? ?? '';
      return l10n(context).comicDetailContinueReading(title);
    }
    return l10n(context).comicDetailRead;
  }
}
