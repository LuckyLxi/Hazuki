import 'package:flutter/material.dart';

import 'package:hazuki/services/announcements/announcement.dart';

const announcementCardHeight = 48.0;
const announcementCardBorderRadius = 16.0;
const announcementCardIconSize = 22.0;

/// Shared layout for a discover card and the launcher inside its morph dialog.
/// Callers supply the leading widget to preserve their icon and unread state.
class AnnouncementCardContent extends StatelessWidget {
  const AnnouncementCardContent({
    super.key,
    required this.announcement,
    required this.leading,
  });

  final Announcement announcement;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(announcement.publishedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              announcement.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
