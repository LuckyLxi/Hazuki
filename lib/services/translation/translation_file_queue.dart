/// 将同一文件的读改写串行化；失败只返回给调用者，不阻塞后续操作。
class TranslationFileQueue {
  final _pending = <String, Future<void>>{};

  Future<T> run<T>(String path, Future<T> Function() action) {
    final result = (_pending[path] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[path] = tail;
    tail.then((_) {
      if (identical(_pending[path], tail)) _pending.remove(path);
    });
    return result;
  }
}
