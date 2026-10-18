import 'dart:async';

import 'package:flutter/foundation.dart';

class SourceLoginCancelled implements Exception {
  const SourceLoginCancelled();
  @override
  String toString() => 'login_cancelled';
}

class SourceLoginCancellation extends ChangeNotifier {
  final _done = Completer<void>();
  bool get isCancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (isCancelled) return;
    _done.complete();
    notifyListeners();
  }

  void check() {
    if (isCancelled) throw const SourceLoginCancelled();
  }
}

class SourceLoginMethod {
  const SourceLoginMethod({
    required this.id,
    required this.title,
    required this.input,
  });
  final String id;
  final Object title;
  final String input;

  static List<SourceLoginMethod> parse(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('plugin_invalid_login_methods');
    }
    final ids = <String>{};
    return List.unmodifiable(
      raw.map((item) {
        if (item is! Map ||
            item['id'] is! String ||
            !RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(item['id'] as String) ||
            !ids.add(item['id'] as String) ||
            !const {'credentials', 'account', 'none'}.contains(item['input']) ||
            !(item['title'] is String &&
                    (item['title'] as String).trim().isNotEmpty ||
                item['title'] is Map &&
                    (item['title'] as Map).isNotEmpty &&
                    (item['title'] as Map).values.every((v) => v is String))) {
          throw const FormatException('plugin_invalid_login_method');
        }
        return SourceLoginMethod(
          id: item['id'] as String,
          title: item['title'] as Object,
          input: item['input'] as String,
        );
      }),
    );
  }
}

typedef SourceLoginPresenter =
    Future<Object?> Function(
      Map<String, dynamic> request,
      SourceLoginCancellation cancellation,
    );

abstract interface class SourceInteractiveAccountGateway {
  void cancelPendingLogin();
  Future<List<SourceLoginMethod>> loadLoginMethods();
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
  });
}
