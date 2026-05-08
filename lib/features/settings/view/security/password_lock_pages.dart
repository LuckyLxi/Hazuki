import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/widgets/password_lock_widgets.dart';
import 'package:hazuki/widgets/widgets.dart';

class PasswordLockIntroPage extends StatefulWidget {
  const PasswordLockIntroPage({super.key});

  @override
  State<PasswordLockIntroPage> createState() => _PasswordLockIntroPageState();
}

class _PasswordLockIntroPageState extends State<PasswordLockIntroPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).privacyPasswordLockTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.password_rounded,
                  size: 62,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 22),
                Text(
                  l10n(context).privacyPasswordLockIntroTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n(context).privacyPasswordLockIntroSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: () async {
                    final enabled = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const PasswordLockSetupPage(),
                      ),
                    );
                    if (enabled == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(l10n(context).privacyPasswordLockEnableAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordLockSetupPage extends StatefulWidget {
  const PasswordLockSetupPage({super.key});

  @override
  State<PasswordLockSetupPage> createState() => _PasswordLockSetupPageState();
}

class _PasswordLockSetupPageState extends State<PasswordLockSetupPage> {
  String _input = '';
  bool _saving = false;
  bool _errorHighlight = false;

  @override
  void initState() {
    super.initState();
    unawaited(PasswordLockAnimationCache.ensureLoaded());
  }

  Future<void> _appendDigit(String digit) async {
    if (_saving || _input.length >= 4) {
      return;
    }
    await HapticFeedback.mediumImpact();
    setState(() {
      _input = '$_input$digit';
      _errorHighlight = false;
    });
    if (_input.length < 4) {
      return;
    }
    setState(() {
      _saving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    try {
      await PasswordLockService.instance.enableWithPin(_input);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _input = '';
        _errorHighlight = true;
      });
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).privacyPasswordLockEnableFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _removeDigit() async {
    if (_saving || _input.isEmpty) {
      return;
    }
    await HapticFeedback.lightImpact();
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _errorHighlight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).privacyPasswordLockTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const PasswordLockAnimationHeader(size: 244),
                  const SizedBox(height: 8),
                  Text(
                    l10n(context).privacyPasswordLockSetupInstruction,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PasswordLockFilledBoxes(
                    length: _input.length,
                    highlightError: _errorHighlight,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: PasswordLockNumericKeypad(
                        enabled: !_saving,
                        maxWidth: 352,
                        buttonHeight: 72,
                        spacing: 12,
                        digitFontSize: 27,
                        letterFontSize: 14,
                        onDigitPressed: (digit) {
                          unawaited(_appendDigit(digit));
                        },
                        onBackspacePressed: () {
                          unawaited(_removeDigit());
                        },
                      ),
                    ),
                  ),
                  if (_saving)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l10n(context).commonLoading,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
