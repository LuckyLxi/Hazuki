import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

import 'hazuki_frosted_menu.dart';
import 'source_plugin_menu.dart';

/// Shared interaction owner for menu buttons, dropdowns and plugin controls.
/// The builder retains the control's appearance and chooses its input gesture.
class SourcePluginInteraction<T> extends StatefulWidget {
  const SourcePluginInteraction({
    super.key,
    required this.builder,
    required this.options,
    required this.onSelected,
    this.binding,
    this.selected,
    this.label,
    this.enabled = true,
    this.onOpened,
    this.waitForDismissal = false,
    this.fallback,
  });

  final Widget Function(BuildContext context, VoidCallback? activate) builder;
  final List<HazukiFrostedMenuOption<T>> options;
  final FutureOr<void> Function(T value) onSelected;
  final SourcePluginMenuBinding<T>? binding;
  final T? selected;
  final String? label;
  final bool enabled;
  final VoidCallback? onOpened;
  final bool waitForDismissal;

  /// Invoked directly when a button has no menu declaration.
  final FutureOr<void> Function()? fallback;

  @override
  State<SourcePluginInteraction<T>> createState() =>
      _SourcePluginInteractionController<T>();
}

class _SourcePluginInteractionController<T>
    extends State<SourcePluginInteraction<T>> {
  final _anchorKey = GlobalKey();
  final _dismiss = ValueNotifier(0);
  final _owner = SourceUiOwner();
  SourcePluginGateway? _gateway;
  Object? _scope;
  bool _running = false;
  bool _actionBusy = false;

  Object? _identity(ResolvedSourcePluginMenu? menu) => menu == null
      ? null
      : (
          widget.binding!.menuId,
          menu.sourceKey,
          menu.gateway,
          menu.available,
          menu.canRunActions,
        );

  void _syncScope() {
    final menu = widget.binding?.resolve(context);
    if (_gateway != menu?.gateway) {
      _gateway?.removeListener(_gatewayChanged);
      _gateway = menu?.gateway;
      _gateway?.addListener(_gatewayChanged);
    }
    if (_running && _identity(menu) != _scope) _cancel();
  }

  void _gatewayChanged() {
    if (!mounted) return;
    _syncScope();
    setState(() {});
  }

  void _cancel() {
    _dismiss.value++;
    _owner.cancel('ownerGone');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScope();
  }

  @override
  void didUpdateWidget(covariant SourcePluginInteraction<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncScope();
  }

  @override
  void dispose() {
    _gateway?.removeListener(_gatewayChanged);
    _cancel();
    _owner.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_running || !widget.enabled) return;
    final menu = widget.binding?.resolve(context, listen: false);
    if (widget.fallback != null && menu?.available == false) return;
    _running = true;
    _scope = _identity(menu);
    final revision = _dismiss.value;
    bool valid() => mounted && widget.enabled && _dismiss.value == revision;
    try {
      widget.onOpened?.call();
      if (widget.fallback != null && menu?.entries.isNotEmpty != true) {
        setState(() => _actionBusy = true);
        await _owner.run(() async => await widget.fallback!());
      } else {
        final binding = widget.binding;
        final value = binding == null
            ? await showHazukiFrostedMenu<T>(
                context: context,
                anchorKey: _anchorKey,
                options: widget.options,
                selected: widget.selected,
                label: widget.label,
                dismissOn: _dismiss,
                waitForDismissal: widget.waitForDismissal,
              )
            : await showSourcePluginMenu<T>(
                context: context,
                anchorKey: _anchorKey,
                options: widget.options,
                selected: widget.selected,
                label: widget.label,
                binding: binding,
                dismissOn: _dismiss,
                waitForDismissal: widget.waitForDismissal,
                onActionBusyChanged: (busy) {
                  if (mounted) setState(() => _actionBusy = busy);
                },
              );
        if (valid() && value != null) {
          setState(() => _actionBusy = true);
          await _owner.run(() async => await widget.onSelected(value));
        }
      }
    } catch (error) {
      if (!isSourceUiCancellation(error)) rethrow;
    } finally {
      _running = false;
      _scope = null;
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.binding?.resolve(context);
    final enabled =
        widget.enabled &&
        !_actionBusy &&
        (widget.fallback == null || menu?.available != false) &&
        (widget.fallback != null ||
            widget.options.isNotEmpty ||
            menu?.entries.isNotEmpty == true);
    return KeyedSubtree(
      key: _anchorKey,
      child: widget.builder(context, enabled ? _activate : null),
    );
  }
}

/// Automatically binds a fixed button or declared plugin action to its menu ID.
class SourcePluginButtonInteraction extends StatelessWidget {
  const SourcePluginButtonInteraction({
    super.key,
    required this.id,
    required this.title,
    required this.onInvoke,
    required this.builder,
    this.sourceKey,
    this.gateway,
    this.enabled = true,
  }) : _action = false;

  const SourcePluginButtonInteraction.action({
    super.key,
    required this.id,
    required this.title,
    required this.onInvoke,
    required this.builder,
    this.sourceKey,
    this.gateway,
    this.enabled = true,
  }) : _action = true;

  final String id;
  final String title;
  final String? sourceKey;
  final SourcePluginGateway? gateway;
  final bool enabled;
  final FutureOr<void> Function() onInvoke;
  final Widget Function(BuildContext context, VoidCallback? activate) builder;
  final bool _action;

  @override
  Widget build(BuildContext context) => SourcePluginInteraction<String>(
    binding: SourcePluginMenuBinding(
      menuId: 'plugin.${_action ? 'actions' : 'buttons'}.$id',
      sourceKey: sourceKey,
      gateway: gateway,
      appendUnmentionedOptions: false,
    ),
    options: [HazukiFrostedMenuOption(value: 'default', label: title)],
    onSelected: (_) => onInvoke(),
    fallback: onInvoke,
    enabled: enabled,
    label: title,
    waitForDismissal: true,
    builder: builder,
  );
}
