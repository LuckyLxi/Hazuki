import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import '../support/comic_detail_session_controller.dart';

class ComicDetailHeaderActionRow extends StatelessWidget {
  const ComicDetailHeaderActionRow({
    super.key,
    required this.details,
    required this.actionButtonsKey,
    required this.shouldAnimateInitialDetailReveal,
  });

  final ComicDetailsData? details;
  final GlobalKey actionButtonsKey;
  final bool shouldAnimateInitialDetailReveal;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final actions = scope.actions;
    final session = scope.session;
    final detailsReady = details != null;

    return SizedBox(
      key: actionButtonsKey,
      height: 48,
      child: AnimatedSlide(
        offset: shouldAnimateInitialDetailReveal
            ? (detailsReady ? Offset.zero : const Offset(0, -0.08))
            : Offset.zero,
        duration: shouldAnimateInitialDetailReveal
            ? const Duration(milliseconds: 320)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        child: Row(
          children: [
            AbsorbPointer(
              absorbing: !detailsReady,
              child: IconButton(
                tooltip: l10n(context).comicDetailChapters,
                onPressed: () {
                  if (detailsReady) {
                    actions.showChaptersPanel(context, details!);
                  }
                },
                icon: const Icon(Icons.format_list_bulleted_rounded),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AbsorbPointer(
                absorbing: !detailsReady,
                child: FilledButton.icon(
                  onPressed: () {
                    if (detailsReady) {
                      unawaited(actions.openReader(context, details!));
                    }
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(_buildReaderButtonLabel(context, session)),
                ),
              ),
            ),
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
