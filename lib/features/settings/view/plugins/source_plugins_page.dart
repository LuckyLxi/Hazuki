import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';

import 'package:hazuki/widgets/widgets.dart';
import 'source_plugin_settings_page.dart';

part 'source_plugins_widgets.dart';

enum _PluginOperationPage { installed, available }

enum _PluginMarketFilter { all, notInstalled, updates }

enum _PluginSheetAction { settings, update, copyRepository, uninstall }

enum SourcePluginsTab { installed, market }

class SourcePluginsPage extends StatefulWidget {
  const SourcePluginsPage({
    super.key,
    required this.manager,
    this.initialTab = SourcePluginsTab.installed,
  });
  final SourcePluginGateway manager;
  final SourcePluginsTab initialTab;
  @override
  State<SourcePluginsPage> createState() => _SourcePluginsPageState();
}

class _SourcePluginsPageState extends State<SourcePluginsPage> {
  late final SourcePluginGateway _manager;
  _PluginOperationPage? _busyPage;
  bool get _busy => _busyPage != null;
  final Set<String> _installing = {};
  final Map<String, bool> _pendingEnabled = {};
  _PluginMarketFilter _marketFilter = _PluginMarketFilter.all;
  bool _sorting = false;
  // 排序模式下的乐观顺序，避免等待注册表写入时列表回跳。
  List<String>? _sortOrder;
  bool get _hasOperations => _busy || _installing.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager;
    unawaited(_initialize());
  }

  // 进页面的初始化通常已在启动时完成，不走 _run，避免加载条闪现后收起带动列表上移。
  Future<void> _initialize() async {
    try {
      await _manager.initialize();
    } catch (error) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? pluginId,
    _PluginOperationPage page = _PluginOperationPage.installed,
  }) async {
    if (_busy ||
        (pluginId == null
            ? _installing.isNotEmpty
            : _installing.contains(pluginId))) {
      return;
    }
    setState(() {
      if (pluginId == null) {
        _busyPage = page;
      } else {
        _installing.add(pluginId);
      }
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (pluginId == null) {
            _busyPage = null;
          } else {
            _installing.remove(pluginId);
          }
        });
      }
    }
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JavaScript', extensions: ['js']),
      ],
    );
    if (file != null) await _manager.importPackage(await file.readAsBytes());
  }

  Future<void> _setEnabled(String id, bool enabled) async {
    if (_hasOperations || _pendingEnabled.containsKey(id)) return;
    setState(() => _pendingEnabled[id] = enabled);
    try {
      await _manager.setEnabled(id, enabled);
    } catch (error) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      if (mounted) setState(() => _pendingEnabled.remove(id));
    }
  }

  Future<void> _update(String id) async {
    final update = await _manager.checkUpdate(id);
    if (update == null) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, l10n(context).pluginsNoUpdate));
      }
      return;
    }
    final plugin = _manager.pluginFor(id)!;
    await _installFromRepository(
      plugin.repository ?? sourcePluginsRepositoryUrl,
      update,
    );
  }

  Future<void> _confirmUninstall(InstalledSourcePlugin plugin) async {
    final s = l10n(context);
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(s.pluginsUninstallTitle),
          content: Text(s.pluginsUninstallConfirm(plugin.manifest.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.commonConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(
                begin: 0.9,
                end: 1.0,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _manager.uninstall(plugin.manifest.id));
  }

  Future<void> _installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  ) async {
    if (_manager.pluginFor(entry.id)?.customEdited == true) {
      if (!mounted) return;
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
    await _manager.installFromRepository(repository, entry);
  }

  bool _hasUpdate(String id) =>
      _manager.availableUpdates.any((update) => update.entry.id == id);

  SourcePluginUpdate? _updateFor(String id) {
    for (final update in _manager.availableUpdates) {
      if (update.entry.id == id) return update;
    }
    return null;
  }

  // 只有来自内置或已登记仓库的插件才能走仓库更新流程。
  bool _canUpdate(InstalledSourcePlugin plugin) =>
      plugin.repository != null &&
      (plugin.repository == sourcePluginsRepositoryUrl ||
          _manager.repositories.contains(plugin.repository));

  String _repositoryLabel(InstalledSourcePlugin plugin) {
    final repository = plugin.repository;
    if (repository == null) return l10n(context).pluginsLocalPackage;
    return repository == sourcePluginsRepositoryUrl
        ? sourcePluginsRepositoryName
        : repository;
  }

  Future<void> _showActions(InstalledSourcePlugin plugin) async {
    final s = l10n(context);
    final id = plugin.manifest.id;
    final update = _updateFor(id);
    final action = await showModalBottomSheet<_PluginSheetAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _PluginActionSheet(
        plugin: plugin,
        subtitle: '${plugin.manifest.version} · $id',
        settingsEnabled: plugin.enabled,
        updateLabel: _canUpdate(plugin)
            ? (update == null
                  ? s.pluginsCheckUpdate
                  : s.pluginsUpdateTo(update.entry.version))
            : null,
        updateTrailing: update == null ? null : _repositoryLabel(plugin),
        canCopyRepository: plugin.repository != null,
      ),
    );
    if (action == null || !mounted || _hasOperations) return;
    switch (action) {
      case _PluginSheetAction.settings:
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  SourcePluginSettingsPage(gateway: _manager, id: id),
            ),
          ),
        );
      case _PluginSheetAction.update:
        await _run(() => _update(id));
      case _PluginSheetAction.copyRepository:
        await Clipboard.setData(ClipboardData(text: plugin.repository!));
        if (mounted) {
          unawaited(showHazukiPrompt(context, s.pluginsRepositoryCopied));
        }
      case _PluginSheetAction.uninstall:
        await _confirmUninstall(plugin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(s.pluginsTitle),
          actions: [
            AnimatedBuilder(
              animation: _manager,
              builder: (context, _) => IconButton(
                tooltip: s.pluginsImportLocal,
                onPressed: _hasOperations ? null : () => _run(_import),
                icon: const Icon(Icons.note_add_outlined),
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.pluginsInstalled),
              Tab(text: s.pluginsAvailable),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: AnimatedBuilder(
                animation: _manager,
                builder: (context, _) => TabBarView(
                  children: [_installedTab(context), _marketTab(context)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<InstalledSourcePlugin> _sortedInstalled() {
    final installed = _manager.installed;
    final order = _sortOrder;
    if (order == null) return installed;
    final byId = {for (final plugin in installed) plugin.manifest.id: plugin};
    return [
      for (final id in order) ?byId[id],
      // 排序期间新安装的插件追加到末尾。
      for (final plugin in installed)
        if (!order.contains(plugin.manifest.id)) plugin,
    ];
  }

  Future<void> _movePlugin(int oldIndex, int newIndex) async {
    final ids = [for (final plugin in _sortedInstalled()) plugin.manifest.id];
    if (oldIndex == newIndex) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    setState(() => _sortOrder = ids);
    try {
      await _manager.reorder(ids);
    } catch (error) {
      if (!mounted) return;
      // 写入失败时管理器已回滚，丢弃乐观顺序以显示真实顺序。
      setState(() => _sortOrder = null);
      unawaited(showHazukiPrompt(context, error.toString(), isError: true));
    }
  }

  void _setSorting(bool sorting) => setState(() {
    _sorting = sorting;
    _sortOrder = null;
  });

  Widget _installedTab(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
        child: child,
      ),
    ),
    child: _sorting && _manager.installed.length > 1
        ? _installedSortList(context)
        : _installedList(context),
  );

  Widget _installedList(BuildContext context) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final installed = _manager.installed;
    return ListView(
      key: const PageStorageKey('installed-plugins'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 平滑收起进度条，避免卸载完成时列表上跳打断卡片退场动画。
        _PluginRevealSection(
          visible: _busyPage == _PluginOperationPage.installed,
          child: const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        ),
        if (installed.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.pluginsInstalled} · ${installed.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _hasOperations ? null : () => _setSorting(true),
                  icon: const Icon(Icons.swap_vert, size: 18),
                  label: Text(s.pluginsSort),
                ),
              ],
            ),
          ),
        _PluginFadeSwitcher(
          child: installed.isEmpty
              ? _PluginEmptyState(
                  key: const ValueKey('installed-empty'),
                  icon: Icons.extension_outlined,
                  message: s.pluginsEmpty,
                )
              : const SizedBox(key: ValueKey('installed-list')),
        ),
        _AnimatedPluginGrid<InstalledSourcePlugin>(
          items: installed,
          keyOf: (plugin) => plugin.manifest.id,
          itemBuilder: _installedCard,
        ),
      ],
    );
  }

  Widget _installedSortList(BuildContext context) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plugins = _sortedInstalled();
    return ReorderableListView.builder(
      key: const PageStorageKey('installed-plugins-sort'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      buildDefaultDragHandles: false,
      header: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.pluginsSortHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () => _setSorting(false),
              child: Text(s.pluginsSortDone),
            ),
          ],
        ),
      ),
      itemCount: plugins.length,
      onReorderItem: (oldIndex, newIndex) =>
          unawaited(_movePlugin(oldIndex, newIndex)),
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(animation.value);
          // 阴影只画在卡片区域，不包含条目底部间距。
          return Transform.scale(
            scale: 1 + 0.03 * t,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.22 * t),
                          blurRadius: 18 * t,
                          offset: Offset(0, 6 * t),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(type: MaterialType.transparency, child: child),
              ],
            ),
          );
        },
      ),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return Padding(
          key: ValueKey('plugin-sort-${plugin.manifest.id}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _PluginSurface(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  _PluginAvatar(
                    label: plugin.manifest.name,
                    background: plugin.enabled
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    foreground: plugin.enabled
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plugin.manifest.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${plugin.manifest.id} · ${plugin.enabled ? s.pluginsEnabled : s.pluginsDisabled}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: s.pluginsSortHandle(plugin.manifest.name),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _marketTab(BuildContext context) {
    final s = l10n(context);
    const repository = sourcePluginsRepositoryUrl;
    final entries = _manager.entriesFor(repository);
    final notInstalled = entries
        .where((entry) => _manager.pluginFor(entry.id) == null)
        .toList();
    final updates = entries.where((entry) => _hasUpdate(entry.id)).toList();
    final visible = switch (_marketFilter) {
      _PluginMarketFilter.all => entries,
      _PluginMarketFilter.notInstalled => notInstalled,
      _PluginMarketFilter.updates => updates,
    };
    return ListView(
      key: const PageStorageKey('available-plugins'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_manager.indexError case final error?) ...[
          _PluginError(message: error),
          const SizedBox(height: 12),
        ],
        _repositoryHeader(
          context,
          repository,
          count: entries.length,
          updates: updates.length,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _PluginEmptyState(
            icon: Icons.storefront_outlined,
            message: s.pluginsRepositoryEmpty,
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (filter, label, count) in [
                (_PluginMarketFilter.all, s.pluginsFilterAll, entries.length),
                (
                  _PluginMarketFilter.notInstalled,
                  s.pluginsFilterNotInstalled,
                  notInstalled.length,
                ),
                (
                  _PluginMarketFilter.updates,
                  s.pluginsFilterUpdates,
                  updates.length,
                ),
              ])
                ChoiceChip(
                  label: Text('$label $count'),
                  selected: _marketFilter == filter,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _marketFilter = filter),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PluginFadeSwitcher(
            child: visible.isEmpty
                ? Padding(
                    key: const ValueKey('market-filter-empty'),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      s.pluginsFilterEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('market-list')),
          ),
          _AnimatedPluginGrid<SourcePluginIndexEntry>(
            items: visible,
            keyOf: (entry) => entry.id,
            itemBuilder: (context, entry) =>
                _marketCard(context, repository, entry),
          ),
        ],
      ],
    );
  }

  Widget _installedCard(BuildContext context, InstalledSourcePlugin plugin) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = plugin.manifest.id;
    final enabled = _pendingEnabled[id] ?? plugin.enabled;
    final update = _canUpdate(plugin) ? _updateFor(id) : null;
    final error = _manager.errors[id];
    return _PluginSurface(
      child: InkWell(
        onTap: _hasOperations ? null : () => _showActions(plugin),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PluginAvatar(
                    label: plugin.manifest.name,
                    background: enabled
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    foreground: enabled
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                          child: Text(plugin.manifest.name),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$id · ${_repositoryLabel(plugin)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    label: plugin.manifest.name,
                    child: Switch(
                      value: enabled,
                      onChanged:
                          _hasOperations || _pendingEnabled.containsKey(id)
                          ? null
                          : (value) => _setEnabled(id, value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PluginBadge(
                          label: enabled ? s.pluginsEnabled : s.pluginsDisabled,
                          highlighted: enabled,
                        ),
                        _PluginBadge(label: plugin.manifest.version),
                        if (plugin.customEdited)
                          _PluginBadge(label: s.pluginsLocallyEdited),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('plugin-actions-$id'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).moreButtonTooltip,
                    onPressed: _hasOperations
                        ? null
                        : () => _showActions(plugin),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              _PluginRevealSection(
                visible: update != null,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.tertiary,
                        foregroundColor: scheme.onTertiary,
                      ),
                      onPressed: _hasOperations
                          ? null
                          : () => _run(() => _update(id)),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        s.pluginsUpdateTo(update?.entry.version ?? ''),
                      ),
                    ),
                  ),
                ),
              ),
              _PluginRevealSection(
                visible: error != null,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 12, end: 8),
                  child: _PluginError(message: error ?? ''),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repositoryHeader(
    BuildContext context,
    String repository, {
    required int count,
    required int updates,
  }) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _PluginSurface(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(Icons.layers_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourcePluginsRepositoryName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.pluginsRepositorySummary(count, updates),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PluginRefreshButton(
              tooltip: s.pluginsRefresh,
              refreshing:
                  _busyPage == _PluginOperationPage.available ||
                  _manager.checkingIndex,
              onPressed: _hasOperations || _manager.checkingIndex
                  ? null
                  : () => _run(
                      () => _manager.refreshRepository(repository),
                      page: _PluginOperationPage.available,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketCard(
    BuildContext context,
    String repository,
    SourcePluginIndexEntry entry,
  ) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final installed = _manager.pluginFor(entry.id);
    final hasUpdate = installed != null && _hasUpdate(entry.id);
    final installing = _installing.contains(entry.id);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              if (hasUpdate) ...[
                TextSpan(
                  text: '${entry.id} · ${installed.manifest.version} → ',
                ),
                TextSpan(
                  text: entry.version,
                  style: TextStyle(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                TextSpan(text: '${entry.id} · ${entry.version}'),
            ],
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final action = FilledButton(
      key: ValueKey('plugin-market-action-${entry.id}'),
      style: hasUpdate
          ? FilledButton.styleFrom(
              backgroundColor: scheme.tertiary,
              foregroundColor: scheme.onTertiary,
            )
          : null,
      onPressed:
          _busy ||
              installing ||
              _manager.checkingIndex ||
              (installed != null && !hasUpdate)
          ? null
          : () => _run(
              () => _installFromRepository(repository, entry),
              pluginId: entry.id,
            ),
      child: _PluginOperationLabel(
        loading: installing,
        loadingLabel: s.commonLoading,
        label: installed == null
            ? s.pluginsInstall
            : hasUpdate
            ? s.pluginsUpdate
            : s.pluginsAlreadyInstalled,
      ),
    );
    return _PluginSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 窄屏或大字号时按钮放到文字下方，避免横向溢出。
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final compact = constraints.maxWidth / scale < 240;
            return Row(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                _PluginAvatar(
                  label: entry.name,
                  background: installed == null
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  foreground: installed == null
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [info, const SizedBox(height: 12), action],
                        )
                      : info,
                ),
                if (!compact) ...[const SizedBox(width: 12), action],
              ],
            );
          },
        ),
      ),
    );
  }
}
