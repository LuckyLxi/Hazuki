#
# iOS counterpart of the macOS podspec — builds the same bridge + quickjs-ng
# source tree against the iOS Flutter framework.
#
Pod::Spec.new do |s|
  s.name             = 'quickjs_engine'
  s.version          = '0.1.0'
  s.summary          = 'quickjs-ng bridge for full_svg_flutter.'
  s.description      = <<-DESC
Forked from flutter_js. Bundles quickjs-ng 0.14.0 directly so the JS engine
that runs SVGator/SMIL/animation scripts is the same modern QuickJS on every
platform — no JavaScriptCore fallback.
                       DESC
  s.homepage         = 'https://github.com/denisnadey/flutter_full_svg_support'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Denis Nadey' => 'denis.nadey@gmail.com' }
  s.source           = { :path => '.' }

  # Sources are shared with the Swift Package Manager manifests
  # (quickjs_engine/Package.swift and quickjs_engine/quickjs_engine_native/).
  #
  # CocoaPods silently drops source_files outside the pod directory, so listing
  # ../native/cxx/*.c here directly compiled nothing and the bridge symbols
  # were missing at runtime. The quickjs_engine_native .c/.cpp files are small
  # forwarders that #include the shared ../native/cxx sources by relative path
  # (the same technique as Flutter's plugin_ffi template).
  s.source_files = [
    'quickjs_engine/Sources/quickjs_engine/**/*.swift',
    'quickjs_engine/quickjs_engine_native/Sources/quickjs_engine_native/*.{c,cpp}',
  ]
  s.public_header_files = []

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'

  preprocessor_definitions = 'CONFIG_VERSION=\"ng-0.14.0\" $(inherited)'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_C_LANGUAGE_STANDARD' => 'c11',
    'CLANG_ENABLE_MODULES' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../native/cxx" "$(PODS_TARGET_SRCROOT)/../native/cxx/quickjs"',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    # Flutter's optimized configurations drop QuickJS assertions and its
    # ENABLE_DUMPS debug code, like the CMake Release builds on the other
    # platforms and the Swift Package Manager release builds.
    'GCC_PREPROCESSOR_DEFINITIONS[config=Profile]' => "#{preprocessor_definitions} NDEBUG=1",
    'GCC_PREPROCESSOR_DEFINITIONS[config=Release]' => "#{preprocessor_definitions} NDEBUG=1",
    'WARNING_CFLAGS' => '-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-unused-but-set-variable',
  }
end
