import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/widgets.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.isLogged,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onOpenLines,
  });

  final bool isLogged;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool checkInBusy;
  final bool checkedInToday;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLines;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(40),
              child: (!isLogged && (avatarUrl ?? '').trim().isEmpty)
                  ? const CircleAvatar(
                      radius: 36,
                      backgroundImage: AssetImage(
                        'assets/avatars/20260307_220809.jpg',
                      ),
                    )
                  : HazukiCachedCircleAvatar(
                      radius: 36,
                      url: avatarUrl ?? '',
                      fallbackIcon: const Icon(Icons.person, size: 36),
                      ignoreNoImageMode: true,
                    ),
            ),
            const SizedBox(height: 12),
            Text(username, style: Theme.of(context).textTheme.titleMedium),
            if (isLogged && !autoCheckInEnabled) ...[
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.92,
                      end: 1,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: FilledButton.icon(
                  key: ValueKey(
                    'checkin-${checkInBusy
                        ? 'busy'
                        : checkedInToday
                        ? 'done'
                        : 'idle'}',
                  ),
                  onPressed: (checkInBusy || checkedInToday)
                      ? null
                      : onCheckInPressed,
                  icon: checkInBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          checkedInToday
                              ? Icons.check_circle_outline
                              : Icons.event_available_outlined,
                        ),
                  label: Text(
                    checkInBusy
                        ? l10n(context).homeCheckInInProgress
                        : checkedInToday
                        ? l10n(context).homeCheckInDone
                        : l10n(context).homeCheckInAction,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(l10n(context).homeMenuHistory),
              onTap: onOpenHistory,
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(l10n(context).homeMenuCategories),
              onTap: onOpenCategories,
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_outlined),
              title: Text(l10n(context).homeMenuRanking),
              onTap: onOpenRanking,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n(context).homeMenuDownloads),
              onTap: onOpenDownloads,
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n(context).settingsTitle),
              onTap: onOpenSettings,
            ),
            ListTile(
              leading: const Icon(Icons.alt_route_outlined),
              title: Text(l10n(context).homeMenuLines),
              onTap: onOpenLines,
            ),
          ],
        ),
      ),
    );
  }
}
