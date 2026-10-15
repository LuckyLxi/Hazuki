import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/settings/view/plugins/source_plugins_page.dart';
import '../../l10n/l10n.dart';
import '../../services/source/plugins/source_plugin_repository.dart';
import '../../services/source/source_capabilities.dart';
import '../service_locator.dart';

class SourcePluginUpdateDialogSupport {
  const SourcePluginUpdateDialogSupport({this.gateway});

  final SourcePluginGateway? gateway;

  Future<void> showIfNeeded({
    required GlobalKey<NavigatorState> navigatorKey,
    required bool Function() isMounted,
    required VoidCallback onUpdated,
  }) async {
    final plugins = gateway ?? sl<SourcePluginGateway>();
    await plugins.checkStartupUpdates();
    if (!isMounted() ||
        plugins.indexError != null ||
        plugins.availableUpdates.isEmpty) {
      return;
    }
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = _SourcePluginUpdateDialogRoute(
      context: context,
      builder: (_) =>
          SourcePluginUpdateDialog(gateway: plugins, onUpdated: onUpdated),
    );
    final viewDetails = await navigator.push<bool>(route);
    await route.completed;
    if (viewDetails != true || !isMounted() || !navigator.mounted) return;
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SourcePluginsPage(
            manager: plugins,
            initialTab: SourcePluginsTab.market,
          ),
        ),
      ),
    );
  }
}

class _SourcePluginUpdateDialogRoute extends DialogRoute<bool> {
  _SourcePluginUpdateDialogRoute({
    required super.context,
    required super.builder,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = animation.drive(
      CurveTween(
        curve: animation.status == AnimationStatus.reverse
            ? Curves.easeInCubic
            : Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class SourcePluginUpdateDialog extends StatefulWidget {
  const SourcePluginUpdateDialog({
    super.key,
    required this.gateway,
    required this.onUpdated,
  });

  final SourcePluginGateway gateway;
  final VoidCallback onUpdated;

  @override
  State<SourcePluginUpdateDialog> createState() =>
      _SourcePluginUpdateDialogState();
}

class _SourcePluginUpdateDialogState extends State<SourcePluginUpdateDialog> {
  bool _updating = false;
  String? _error;

  Future<void> _updateAll() async {
    if (_updating) return;
    final updates = List<SourcePluginUpdate>.of(
      widget.gateway.availableUpdates,
    );
    if (updates.isEmpty) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      if (updates.any((update) => update.plugin.customEdited)) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n(context).pluginsEditedUpdate),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n(context).commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n(context).commonConfirm),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
      final errors = <String>[];
      for (final update in updates) {
        if (!mounted) return;
        try {
          await widget.gateway.installFromRepository(
            update.plugin.repository ?? sourcePluginsRepositoryUrl,
            update.entry,
          );
        } catch (error) {
          errors.add('${update.plugin.manifest.name}: $error');
          continue;
        }
        if (!mounted) return;
        widget.onUpdated();
      }
      if (!mounted) return;
      setState(() => _error = errors.isEmpty ? null : errors.join('\n'));
      if (widget.gateway.availableUpdates.isEmpty) {
        setState(() => _updating = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    return PopScope(
      canPop: !_updating,
      child: AlertDialog(
        title: Text(s.pluginsUpdatesTitle),
        content: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: widget.gateway,
                builder: (context, _) {
                  final updates = widget.gateway.availableUpdates;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        updates.length == 1
                            ? s.pluginsUpdateAvailable(
                                updates.single.plugin.manifest.name,
                              )
                            : updates.isEmpty
                            ? s.pluginsNoUpdate
                            : s.pluginsUpdatesMessage(updates.length),
                      ),
                      if (_updating) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _updating ? null : () => Navigator.pop(context, true),
            child: Text(s.pluginsViewDetails),
          ),
          FilledButton(
            onPressed: _updating ? null : _updateAll,
            child: Text(s.pluginsUpdate),
          ),
        ],
      ),
    );
  }
}
