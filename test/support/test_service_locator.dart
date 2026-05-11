import 'package:hazuki/app/service_locator.dart';

/// Resets and re-registers the production service graph for tests.
///
/// Call this in `setUp` of any test that touches services through `sl<T>()`.
/// Tests that need fakes can call [sl.reset] and register their own
/// implementations after invoking this helper.
Future<void> ensureTestServiceLocator() async {
  await sl.reset();
  registerServices();
}
