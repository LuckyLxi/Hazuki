# Hazuki patches to quickjs_engine 0.1.6

- Hazuki owns each production runtime in a background isolate. The native byte mailbox supports synchronous host return values without blocking the Flutter isolate, and has synchronized completion, timeout and close paths. Mailbox IDs never expose runtime pointers.
- Async task context is captured by Promise reactions at registration and by queued jobs, including `await` and thenable adoption. Reference notifications release the worker's metadata with native jobs and Promises. Dart host Future resolvers restore their captured context.
- `executePendingJobOnce()` allows bounded worker batches while preserving JS microtask checkpoints. Snapshot reads can suppress redundant dispatch wake-ups. The shared C++17 build links the platform thread library; Apple forwarders still compile these same sources.

Base: the published [quickjs_engine 0.1.6](https://pub.dev/packages/quickjs_engine/versions/0.1.6) archive, including QuickJS-NG 0.14.0 and its original licenses.

- The native bridge accepts the timeout already passed by Dart and installs a monotonic-clock interrupt handler. Evaluation, direct function calls, and Promise jobs each start a new execution deadline. This preserves Hazuki's existing five-second script execution limit; waiting for HTTP or other Dart Futures does not consume that limit.
- The Dart FFI bridge removes freed runtimes from `runtimeOpaques`, so reloading or inspecting plugins does not retain the old engine and callbacks.
- String conversion handles both flat strings and QuickJS-NG rope strings, preserving long concatenated values in evaluations, Promise results, and host messages.
- `executePendingJob()` drains synchronously and reports native job errors to its caller. Hazuki can then fail pending operations after an interrupted Promise job instead of leaving them waiting indefinitely.
- macOS CocoaPods compiles the same patched native sources as iOS, SwiftPM, Android, Linux, and Windows. The upstream prebuilt macOS dylib is omitted because it lacks the timeout patch.

Hazuki's `SourceScriptEngine` is the main-isolate proxy. Its worker adapts `JsEvalResult`, drives bounded microtask checkpoints and owns every native reference. Closing rejects pending proxy calls, settles worker host Future resolvers, cancels timers and frees native resources before acknowledging exit. Late main-isolate host results are ignored. Regression tests are in `test/services/source/source_script_engine_test.dart` and `source_script_background_test.dart` in the application.

From the application root, run `dart run tool/build_quickjs_test_library.dart` before `flutter test`. It resolves this package from the active package configuration and builds the native library at a location supported by the package's test loader. CMake and a C++17 compiler are required.

## Opt-in task control

`QuickJsRuntime2(taskControlEnabled: true)` creates a native control record on its owning worker. The default is `false`; Hazuki production runtimes do not enable it. `runtime.taskControl.controlId` is an opaque integer that can be sent to another isolate and reconstructed with `QuickJsTaskControl.fromId`. Control operations register unique task tokens, request a typed stop, release caller ownership with `complete`, and query live task/work/retained-shared-work counts. They never access QuickJS pointers. A stop receipt acknowledges the request, not completion of shared work.

The worker enters calls with `withTaskContext(token, ...)` and advances Promise checkpoints with `executePendingJobStep()`. Each step reports the actual job task, execution status and typed stop reason; controlled legacy dispatch methods use the same settlement path. Evaluation continues to use `JsEvalResult.isError`, and Promise results continue to use Futures. `QuickJsTaskStoppedError` carries the task token, cancellation/timeout reason and available JS stack, identified by native private error fields rather than exception text.

The native work graph separates caller roots from Promise production and reaction work. Reactions, async continuations, adoption jobs, combinations, remote functions and host Future resolvers preserve task/work contexts. Reachability protects producers with live consumers, including dependency cycles. Stopped user branches settle their derived results without executing their `catch/finally`; live consumers still receive shared results. Dart result observers pin the value for settlement but are not business roots, and a stopped caller's observer rejects independently of retained shared work. Internal settlement does not re-enter the suspended user frame.

The cross-isolate registry holds shared control records under a short registry lock. Per-control graph changes use a separate lock and atomic stop flags; graph traversal and JS execution never hold the registry lock. Closing unregisters the opaque ID before freeing the runtime. Late control operations return invalid, and host Future completion checks the exact Dart runtime epoch before native access. Resolver completion preserves the existing job-dispatch wakeup in both modes.

`test/task_control_test.dart` owns QuickJS exclusively in test workers and sends only opaque IDs to the test isolate. CI rebuilds the native library, analyzes this package and discovers these tests with the existing full package test command. The application-level cancellation, HTTP/Timer subscription cleanup and automatic runtime recovery are not connected by this patch.
