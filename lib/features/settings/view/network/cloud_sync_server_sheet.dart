part of 'cloud_sync_page.dart';

enum _ServerSheetPhase { idle, saving, success }

/// 服务器编辑表单：在本地副本上编辑，提交时保存并检测连接；
/// 检测成功后按钮变为勾选再自动收起，失败则留在表单内展示原因。
class _CloudSyncServerSheet extends StatefulWidget {
  const _CloudSyncServerSheet({required this.controller});

  final CloudSyncController controller;

  @override
  State<_CloudSyncServerSheet> createState() => _CloudSyncServerSheetState();
}

class _CloudSyncServerSheetState extends State<_CloudSyncServerSheet> {
  late final TextEditingController _urlController = TextEditingController(
    text: widget.controller.urlController.text,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.controller.usernameController.text,
  );
  late final TextEditingController _passwordController = TextEditingController(
    text: widget.controller.passwordController.text,
  );

  bool _passwordVisible = false;
  _ServerSheetPhase _phase = _ServerSheetPhase.idle;
  String? _urlError;
  String? _usernameError;
  String? _passwordError;
  String? _submitError;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations strings) {
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    setState(() {
      _urlError = url.isEmpty
          ? strings.cloudSyncFieldRequired
          : (uri == null || !uri.hasScheme
                ? strings.cloudSyncInvalidUrl
                : null);
      _usernameError = _usernameController.text.trim().isEmpty
          ? strings.cloudSyncFieldRequired
          : null;
      _passwordError = _passwordController.text.trim().isEmpty
          ? strings.cloudSyncFieldRequired
          : null;
    });
    return _urlError == null &&
        _usernameError == null &&
        _passwordError == null;
  }

  Future<void> _submit() async {
    final strings = AppLocalizations.of(context)!;
    if (_phase != _ServerSheetPhase.idle || !_validate(strings)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _ServerSheetPhase.saving;
      _submitError = null;
    });

    try {
      await widget.controller.saveServerConfig(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ServerSheetPhase.idle;
        _submitError = strings.cloudSyncSaveFailed('$e');
      });
      return;
    }
    if (!mounted) return;

    final status = widget.controller.status;
    if (status != null && !status.ok) {
      // 配置已保存，但连接失败时留在表单内便于修改。
      setState(() {
        _phase = _ServerSheetPhase.idle;
        _submitError = status.message.trim().isEmpty
            ? strings.cloudSyncStatusDisconnected
            : status.message.trim();
      });
      return;
    }

    setState(() => _phase = _ServerSheetPhase.success);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) Navigator.of(context).pop();
  }

  void _clearError(VoidCallback clear) {
    setState(() {
      clear();
      _submitError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final editable = _phase == _ServerSheetPhase.idle;
    final success = _phase == _ServerSheetPhase.success;
    final successColor = _cloudSyncSuccessColor(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.cloudSyncEditServerTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              enabled: editable,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_urlError != null || _submitError != null) {
                  _clearError(() => _urlError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://dav.example.com/dav',
                helperText: strings.cloudSyncUrlHelper,
                errorText: _urlError,
                prefixIcon: const Icon(Icons.link_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              enabled: editable,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_usernameError != null || _submitError != null) {
                  _clearError(() => _usernameError = null);
                }
              },
              decoration: InputDecoration(
                labelText: strings.cloudSyncUsernameLabel,
                errorText: _usernameError,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: editable,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submit()),
              onChanged: (_) {
                if (_passwordError != null || _submitError != null) {
                  _clearError(() => _passwordError = null);
                }
              },
              decoration: InputDecoration(
                labelText: strings.cloudSyncPasswordLabel,
                errorText: _passwordError,
                prefixIcon: const Icon(Icons.key_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _passwordVisible = !_passwordVisible);
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: _cloudSyncPopTransition,
                    child: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      key: ValueKey(_passwordVisible),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: _cloudSyncMotion,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _submitError == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 18,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _submitError!,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                // 按钮底色由 Material 自带的颜色过渡动画切换为成功色。
                style: FilledButton.styleFrom(
                  backgroundColor: success ? successColor : null,
                  foregroundColor: success ? colorScheme.surface : null,
                ),
                onPressed: () => unawaited(_submit()),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: _cloudSyncPopTransition,
                  child: switch (_phase) {
                    _ServerSheetPhase.idle => Text(
                      strings.cloudSyncSaveAndTest,
                      key: const ValueKey('idle'),
                    ),
                    _ServerSheetPhase.saving => SizedBox(
                      key: const ValueKey('saving'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    _ServerSheetPhase.success => const Icon(
                      Icons.check_rounded,
                      key: ValueKey('success'),
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
