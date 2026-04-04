import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';

class TagCategoryPage extends StatefulWidget {
  const TagCategoryPage({super.key, required this.searchPageBuilder});

  final Widget Function(String tag) searchPageBuilder;

  @override
  State<TagCategoryPage> createState() => _TagCategoryPageState();
}

class _TagCategoryPageState extends State<TagCategoryPage> {
  static const _loadTimeout = Duration(seconds: 25);

  List<CategoryTagGroup> _tagGroups = const <CategoryTagGroup>[];

  String? _errorMessage;

  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadInitial());
    });
  }

  Future<List<CategoryTagGroup>> _loadTagGroups() {
    final timeoutMessage = AppLocalizations.of(context)!.tagCategoryLoadTimeout;
    return HazukiSourceService.instance.loadCategoryTagGroups().timeout(
      _loadTimeout,
      onTimeout: () => throw Exception(timeoutMessage),
    );
  }

  Future<void> _loadInitial() async {
    if (!mounted) {
      return;
    }

    try {
      final tagGroups = await _loadTagGroups();
      if (!mounted) {
        return;
      }

      setState(() {
        _tagGroups = tagGroups;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.tagCategoryLoadFailed('$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    }
  }

  void _openSearchByTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.searchPageBuilder(tag)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.tagCategoryTitle),
      ),
      body: _initialLoading
          ? ListView(
              children: [
                const SizedBox(height: 160),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HazukiSandyLoadingIndicator(size: 136),
                      const SizedBox(height: 10),
                      Text(strings.commonLoading),
                    ],
                  ),
                ),
              ],
            )
          : (_errorMessage != null && _tagGroups.isEmpty)
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 90),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(_loadInitial());
                    },
                    child: Text(strings.commonRetry),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_tagGroups.isNotEmpty)
                  Text(
                    strings.tagCategoryTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (_tagGroups.isNotEmpty) const SizedBox(height: 10),
                if (_tagGroups.isEmpty) Text(strings.tagCategoryEmpty),
                for (final group in _tagGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: group.tags.map((tag) {
                                return ActionChip(
                                  label: Text(tag),
                                  onPressed: () => _openSearchByTag(tag),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
