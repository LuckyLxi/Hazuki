import 'package:flutter/material.dart';

class ReaderStateScaffold extends StatelessWidget {
  const ReaderStateScaffold({
    super.key,
    required this.theme,
    required this.child,
  });

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: Scaffold(backgroundColor: theme.colorScheme.surface, body: child),
    );
  }
}

class ReaderLoadingStateView extends StatelessWidget {
  const ReaderLoadingStateView({super.key, required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ReaderStateScaffold(
      theme: theme,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class ReaderErrorStateView extends StatelessWidget {
  const ReaderErrorStateView({
    super.key,
    required this.theme,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final ThemeData theme;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ReaderStateScaffold(
      theme: theme,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderEmptyStateView extends StatelessWidget {
  const ReaderEmptyStateView({
    super.key,
    required this.theme,
    required this.message,
  });

  final ThemeData theme;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ReaderStateScaffold(
      theme: theme,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
