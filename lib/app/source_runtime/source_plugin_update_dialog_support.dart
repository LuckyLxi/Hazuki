import 'package:flutter/material.dart';

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
    await Navigator.of(context, rootNavigator: true).push<void>(
      _SourcePluginUpdateDialogRoute(
        context: context,
        builder: (_) =>
            SourcePluginUpdateDialog(gateway: plugins, onUpdated: onUpdated),
      ),
    );
  }
}

class _SourcePluginUpdateDialogRoute extends DialogRoute<void> {
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
  String? _updating;
  String? _error;

  Future<void> _update(SourcePluginUpdate update) async {
    if (_updating != null) return;
    setState(() {
      _updating = update.entry.id;
      _error = null;
    });
    try {
      if (update.plugin.customEdited) {
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
        if (proceed != true) return;
      }
      await widget.gateway.installFromRepository(
        update.plugin.repository ?? sourcePluginsRepositoryUrl,
        update.entry,
      );
      if (!mounted) return;
      widget.onUpdated();
      if (widget.gateway.availableUpdates.isEmpty) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    return PopScope(
      canPop: _updating == null,
      child: AlertDialog(
        title: Text(s.pluginsUpdatesTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: widget.gateway,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.pluginsUpdatesMessage),
                  const SizedBox(height: 16),
                  for (final update in widget.gateway.availableUpdates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            update.plugin.manifest.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${update.localVersion} → ${update.entry.version}',
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: _updating == null
                                  ? () => _update(update)
                                  : null,
                              child: Text(s.pluginsUpdate),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_updating != null) const LinearProgressIndicator(),
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
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _updating == null ? () => Navigator.pop(context) : null,
            child: Text(s.commonCancel),
          ),
        ],
      ),
    );
  }
}
