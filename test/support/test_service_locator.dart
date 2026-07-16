import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';

/// 重置并重新注册用于测试的生产服务图。
///
/// 在任何通过 `sl<T>()` 访问服务的测试的 `setUp` 中调用此函数。
/// 需要使用 fake 的测试可以在调用此辅助函数后调用 [sl.reset] 并注册自己的实现。
Future<void> ensureTestServiceLocator() async {
  await sl.reset();
  sl.registerLazySingleton<HazukiDatabase>(
    () => HazukiDatabase.memory(),
    dispose: (database) => database.close(),
  );
  sl.registerLazySingleton<SourceRuntimeAssembly>(
    () => SourceRuntimeAssembly(
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    ),
  );
  registerServices();
}
