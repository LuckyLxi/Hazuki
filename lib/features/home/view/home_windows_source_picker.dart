import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/source/source_capabilities.dart';
import '../../../shared/source_account/source_switch_list.dart';
import '../../../widgets/hazuki_m3e_loading_indicator.dart';

Future<void> showHomeWindowsSourcePicker(
  BuildContext context, {
  required Rect sidebarBounds,
  required Rect anchorBounds,
  required SourceSwitchGateway sourceService,
  Future<void> Function()? onSourceSwitched,
}) async {
  await sourceService.loadActiveSourcePreference();
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n(context).dialogBarrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    pageBuilder: (context, animation, secondaryAnimation) => LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final left = sidebarBounds.right.clamp(0.0, constraints.maxWidth - 48);
        final top = anchorBounds.top
            .clamp(
              padding.top + 12,
              math.max(
                padding.top + 12,
                constraints.maxHeight - padding.bottom - 144,
              ),
            )
            .toDouble();
        final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: math.min(336, constraints.maxWidth - left - 12),
              child: ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: FadeTransition(
                    opacity: curved,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.min(
                            420,
                            constraints.maxHeight - top - padding.bottom - 28,
                          ),
                        ),
                        child: _WindowsSourcePickerCard(
                          sourceService: sourceService,
                          onSourceSwitched: onSourceSwitched,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _WindowsSourcePickerCard extends StatefulWidget {
  const _WindowsSourcePickerCard({
    required this.sourceService,
    required this.onSourceSwitched,
  });

  final SourceSwitchGateway sourceService;
  final Future<void> Function()? onSourceSwitched;

  @override
  State<_WindowsSourcePickerCard> createState() =>
      _WindowsSourcePickerCardState();
}

class _WindowsSourcePickerCardState extends State<_WindowsSourcePickerCard> {
  String? _switching;
  String? _error;

  Future<void> _select(SourceCatalogEntry source) async {
    if (_switching != null) return;
    final gateway = widget.sourceService;
    if (source.normalizedKey == gateway.activeSourceKey) {
      Navigator.pop(context);
      return;
    }
    final previousSource = gateway.activeSourceKey;
    setState(() {
      _switching = source.normalizedKey;
      _error = null;
    });
    try {
      await gateway.activateSource(source.normalizedKey);
      await gateway.ensureInitialized(sourceKey: source.normalizedKey);
      if (!mounted) return;
      await widget.onSourceSwitched?.call();
      if (!mounted) return;
      setState(() => _switching = null);
      // Allow PopScope to rebuild before closing after a successful switch.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (error) {
      if (previousSource != null && previousSource.isNotEmpty) {
        try {
          await gateway.ensureInitialized(sourceKey: previousSource);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _switching = null;
        _error = l10n(context).labSourceAccountSwitchFailed('$error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final gateway = widget.sourceService;
    final sources = gateway.allowedSources;
    return PopScope(
      canPop: _switching == null,
      child: Material(
        key: const ValueKey('windows-source-picker-card'),
        color: theme.colorScheme.surfaceContainerLow,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.homeSourceSwitchTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: s.commonClose,
                    onPressed: _switching == null
                        ? () => Navigator.pop(context)
                        : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Flexible(
                child: SourceSwitchList(
                  currentIndex: sources.indexWhere(
                    (source) => source.normalizedKey == gateway.activeSourceKey,
                  ),
                  children: [
                    if (sources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(s.homeSourceSwitchEmpty),
                      ),
                    for (final source in sources)
                      ListTile(
                        key: ValueKey('windows-source-${source.normalizedKey}'),
                        selected:
                            source.normalizedKey == gateway.activeSourceKey,
                        selectedTileColor: theme.colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(source.name),
                        subtitle: Text(
                          source.normalizedKey == gateway.activeSourceKey
                              ? s.homeSourceSwitchCurrent
                              : source.pluginVersion ?? source.normalizedKey,
                        ),
                        trailing: _switching == source.normalizedKey
                            ? SizedBox.square(
                                dimension: 24,
                                child: HazukiM3ELoadingIndicator(
                                  semanticLabel: s.commonLoading,
                                ),
                              )
                            : source.normalizedKey == gateway.activeSourceKey
                            ? const Icon(Icons.check_rounded)
                            : null,
                        enabled: _switching == null,
                        onTap: () => _select(source),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
