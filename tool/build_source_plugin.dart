import 'dart:io';
import 'package:path/path.dart' as p;

/// Publishes a self-contained JS plugin without altering its implementation.
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/build_source_plugin.dart <plugin.js> [output.js]',
    );
    exitCode = 64;
    return;
  }
  final source = File(p.normalize(p.absolute(args.first)));
  if (p.extension(source.path) != '.js') {
    throw ArgumentError('Input must be a single .js file');
  }
  final script = await source.readAsString();
  final name = p.basenameWithoutExtension(source.path) == 'main'
      ? p.basename(source.parent.path)
      : p.basenameWithoutExtension(source.path);
  final output = File(
    args.length == 2 ? args[1] : 'build/source_plugins/$name.js',
  );
  if (p.extension(output.path) != '.js') {
    throw ArgumentError('Output must use the .js extension');
  }
  if (p.equals(source.path, p.absolute(output.path))) {
    throw ArgumentError('Output must differ from the source file');
  }
  await output.parent.create(recursive: true);
  await output.writeAsString(script, flush: true);
  stdout.writeln(p.absolute(output.path));
}
