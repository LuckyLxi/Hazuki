// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// QuickJS-NG 0.14.0 and the Dart FFI bridge for the quickjs_engine plugin.
//
// This is a dynamic library on purpose. Dart resolves the bridge with
// DynamicLibrary.process(), i.e. dlsym() over every loaded image. When Xcode
// links SwiftPM code statically, it ends up in the Runner executable, and
// archive builds (`flutter build ipa`, STRIP_STYLE = all) strip the
// executable's exports down to __mh_execute_header, so every bridge lookup
// would fail in release. The exports of an embedded framework survive that.
//
// It is a separate package, not a second product of the plugin package, so
// that only this C code is dynamic: the Swift plugin target stays a regular
// static target that depends on FlutterFramework, and Xcode does not have to
// promote FlutterFramework to an additional dynamic framework.
//
// The files in Sources/quickjs_engine_native/ are forwarders that #include the
// plugin's shared native/cxx/ tree, which the podspec and the CMake builds for
// the other platforms compile as well.
let package = Package(
    name: "quickjs_engine_native",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "quickjs-engine-native", type: .dynamic, targets: ["quickjs_engine_native"])
    ],
    targets: [
        .target(
            name: "quickjs_engine_native",
            // Like the CMake Release builds on the other platforms: optimized
            // builds drop QuickJS assertions and its ENABLE_DUMPS debug code.
            cSettings: [
                .define("NDEBUG", .when(configuration: .release))
            ],
            cxxSettings: [
                .define("NDEBUG", .when(configuration: .release))
            ]
        )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)
