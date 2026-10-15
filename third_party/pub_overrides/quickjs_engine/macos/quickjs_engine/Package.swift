// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
    name: "quickjs_engine",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        // Flutter links plugin packages by product name, with "_" replaced by "-".
        .library(name: "quickjs-engine", targets: ["quickjs_engine"])
    ],
    dependencies: [
        // QuickJS-NG and the Dart FFI bridge, built as a dynamic framework.
        // See quickjs_engine_native/Package.swift for why.
        .package(name: "quickjs_engine_native", path: "quickjs_engine_native")
        // FlutterFramework is added below when Flutter provides it.
    ],
    targets: [
        .target(
            name: "quickjs_engine",
            dependencies: [
                .product(name: "quickjs-engine-native", package: "quickjs_engine_native")
            ]
        )
    ]
)

// Flutter version compatibility
//
// Flutter 3.41+ generates a local "FlutterFramework" package next to every
// plugin package (<app>/macos/Flutter/ephemeral/Packages/.packages/) and expects
// plugins to depend on it:
//     .package(name: "FlutterFramework", path: "../FlutterFramework")
//     .product(name: "FlutterFramework", package: "FlutterFramework")
// Flutter 3.38 and older do not generate it, and a path dependency on a missing
// directory fails package resolution, so the dependency is only added when the
// sibling package exists. That keeps one manifest working with every Flutter
// version this plugin supports.
//
// It is added here rather than in the Package(...) literal above because
// `flutter build swift-package` evaluates this manifest from a copy that has no
// sibling FlutterFramework and then injects the dependency with
// `swift package add-dependency`, which refuses to add an entry that is already
// in the literal. Entries injected that way are normalized to a single one.
//
// FlutterFramework may declare Flutter's own minimum macOS version (10.15 in
// Flutter 3.41), which a dependent package must not undercut. Without it, the
// plugin keeps accepting macOS 10.14, the lowest version older Flutter releases
// target.
let flutterFramework = "FlutterFramework"
let flutterFrameworkIsAvailable = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: Context.packageDirectory)
        .deletingLastPathComponent()
        .appendingPathComponent(flutterFramework)
        .appendingPathComponent("Package.swift")
        .path
)

package.dependencies.removeAll { dependency in
    if case .fileSystem(_, let path) = dependency.kind {
        return URL(fileURLWithPath: path).lastPathComponent == flutterFramework
    }
    return false
}
for target in package.targets {
    target.dependencies.removeAll { dependency in
        if case .productItem(let name, let packageName, _, _) = dependency {
            return name == flutterFramework && packageName == flutterFramework
        }
        return false
    }
}
if flutterFrameworkIsAvailable {
    package.dependencies.append(.package(name: flutterFramework, path: "../FlutterFramework"))
    for target in package.targets {
        target.dependencies.append(.product(name: flutterFramework, package: flutterFramework))
    }
} else {
    package.platforms = [.macOS("10.14")]
}
