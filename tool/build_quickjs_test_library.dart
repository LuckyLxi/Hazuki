import 'dart:io';
import 'dart:isolate';

/// Builds the installed quickjs_engine bridge where its test loader finds it.
Future<void> main() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:quickjs_engine/quickjs_engine.dart'),
  );
  if (library == null) {
    throw StateError('Run flutter pub get before building the test library.');
  }
  final source = Directory.fromUri(library.resolve('../native/'));
  final build = Directory('packages/quickjs_engine/native/build').absolute;
  final output = build.path.replaceAll('\\', '/');
  for (final args in [
    [
      '-S',
      source.path,
      '-B',
      build.path,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=$output',
      '-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=$output',
    ],
    ['--build', build.path, '--config', 'Release', '--parallel', '4'],
  ]) {
    final process = await Process.start(
      'cmake',
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    final result = await process.exitCode;
    if (result != 0) {
      exitCode = result;
      return;
    }
  }
  stdout.writeln('QuickJS test library built in ${build.path}');
}
