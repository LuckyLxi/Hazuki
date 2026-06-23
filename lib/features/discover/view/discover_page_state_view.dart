import 'package:flutter/material.dart';

import 'package:hazuki/app/source_runtime/source_runtime_status_card.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

class DiscoverStateView extends StatelessWidget {
  const DiscoverStateView({
    super.key,
    required this.initialLoading,
    required this.refreshing,
    required this.sections,
    required this.errorMessage,
    required this.sourceRuntimeState,
    required this.showLoginRequired,
    required this.allowInitialLoad,
    required this.hideLoadingUntilInitialLoadAllowed,
    required this.onRetry,
    this.onLoginPressed,
  });

  final bool initialLoading;
  final bool refreshing;
  final List<ExploreSection> sections;
  final String? errorMessage;
  final SourceRuntimeState sourceRuntimeState;
  final bool showLoginRequired;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final Future<void> Function() onRetry;
  final VoidCallback? onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final showBlockingLoading =
        initialLoading || (refreshing && sections.isEmpty);
    late final Widget child;

    if (showLoginRequired) {
      child = SizedBox(
        key: const ValueKey('discover-login-required'),
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.discoverLoginRequired),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onLoginPressed,
                child: Text(strings.homeLoginTitle),
              ),
            ],
          ),
        ),
      );
    } else if (showBlockingLoading) {
      if (shouldShowSourceRuntimeStatusCard(sourceRuntimeState)) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-loading'),
          state: sourceRuntimeState,
          minHeight: 360,
        );
      } else if (!allowInitialLoad && hideLoadingUntilInitialLoadAllowed) {
        child = const SizedBox(
          key: ValueKey('discover-placeholder'),
          height: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-loading'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSandyLoadingIndicator(size: 136),
                const SizedBox(height: 10),
                Text(strings.commonLoading),
              ],
            ),
          ),
        );
      }
    } else if (errorMessage != null && sections.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(
        sourceRuntimeState,
        fallbackError: errorMessage,
      )) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-error'),
          state: sourceRuntimeState,
          fallbackError: errorMessage,
          onRetry: onRetry,
          minHeight: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-error'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(errorMessage!, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(strings.commonRetry),
                ),
              ],
            ),
          ),
        );
      }
    } else if (sections.isEmpty) {
      child = SizedBox(
        key: const ValueKey('discover-empty'),
        height: 220,
        child: Center(child: Text(strings.discoverEmpty)),
      );
    } else {
      child = const SizedBox(key: ValueKey('discover-hidden'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            ...<Widget?>[currentChild].whereType<Widget>(),
          ],
        );
      },
      child: child,
    );
  }
}
