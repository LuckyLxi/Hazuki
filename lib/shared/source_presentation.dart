import 'package:flutter/widgets.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';

export 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';

/// Injected catalog metadata for currently installed plugins.
class SourcePresentationScope extends InheritedNotifier<SourceRuntimeRegistry> {
  const SourcePresentationScope({
    super.key,
    required SourceRuntimeRegistry registry,
    required super.child,
  }) : super(notifier: registry);
  static SourceRuntimeRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SourcePresentationScope>()
      ?.notifier;
  static SourceRuntimeRegistry? read(BuildContext context) => context
      .getInheritedWidgetOfExactType<SourcePresentationScope>()
      ?.notifier;
}

Map<String, dynamic> sourcePresentation(
  String sourceKey, {
  BuildContext? context,
}) {
  final registry = context == null
      ? null
      : SourcePresentationScope.maybeOf(context);
  return registry?.displayPresentationFor(sourceKey.trim()) ?? const {};
}

bool sourceFeature(String sourceKey, String feature, {BuildContext? context}) =>
    sourcePresentation(sourceKey, context: context)[feature] == true;

/// Comments require an explicit declaration from an enabled, installed plugin.
bool sourceCommentsEnabled(
  String sourceKey, {
  required BuildContext context,
  bool listen = true,
}) {
  final registry = listen
      ? SourcePresentationScope.maybeOf(context)
      : SourcePresentationScope.read(context);
  final key = sourceKey.trim().isEmpty
      ? registry?.activeSourceKey ?? ''
      : sourceKey.trim();
  if (registry?.isAllowedSourceKey(key) != true) return false;
  return registry!.definitionFor(key).presentation['showComments'] == true;
}

/// Button visibility always comes from an installed plugin's declarations.
SourcePluginButton? sourceButton(
  String sourceKey,
  String id,
  SourcePluginButtonLocation location, {
  required BuildContext context,
  bool listen = true,
}) {
  final registry = listen
      ? SourcePresentationScope.maybeOf(context)
      : SourcePresentationScope.read(context);
  if (registry?.isAllowedSourceKey(sourceKey.trim()) != true) return null;
  return sourcePluginButton(
    registry!.definitionFor(sourceKey.trim()).presentation,
    id,
    location,
  );
}

SourcePluginButton? activeSourceButton(
  BuildContext context,
  String id,
  SourcePluginButtonLocation location,
) => sourceButton(
  SourcePresentationScope.maybeOf(context)?.activeSourceKey ?? '',
  id,
  location,
  context: context,
);
