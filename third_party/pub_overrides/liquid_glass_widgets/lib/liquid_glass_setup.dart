import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'theme/glass_theme.dart';
import 'theme/glass_theme_data.dart';
import 'types/glass_quality.dart';
import 'utils/accessibility_config.dart' as glass_config;
import 'utils/glass_brightness.dart' show glassExternalBrightnessResolver;
import 'utils/glass_performance_monitor.dart';
import 'src/renderer/liquid_glass_renderer.dart';
import 'src/renderer/shaders.dart';

import 'src/renderer/internal/multi_shader_builder.dart';
import 'widgets/shared/glass_adaptive_scope.dart';
import 'widgets/shared/glass_effect.dart';
import 'widgets/shared/glass_accessibility_scope.dart';
import 'widgets/shared/lightweight_liquid_glass.dart';
import 'widgets/effects/progressive_blur.dart';

/// Entry point and configuration for the Liquid Glass Widgets library.
///
/// ## Setup
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LiquidGlassWidgets.initialize(); // pre-warms shaders
///
///   runApp(LiquidGlassWidgets.wrap(
///     child: const MyApp(),
///     adaptiveQuality: true,
///     theme: GlassThemeData(
///       light: GlassThemeVariant(settings: GlassThemeSettings(blur: 10)),
///       dark:  GlassThemeVariant(settings: GlassThemeSettings(blur: 14)),
///     ),
///   ));
/// }
/// ```
class LiquidGlassWidgets {
  LiquidGlassWidgets._();

  // ── Global accessors ───────────────────────────────────────────────────────

  /// Whether glass widgets automatically respect system accessibility settings
  /// (Reduce Motion, Reduce Transparency / High Contrast).
  ///
  /// Set via [wrap]. Defaults to `true`. Read by glass widgets at build time
  /// via [GlassAccessibilityScope] or a direct [MediaQuery] fallback.
  ///
  /// The setter is provided as an escape hatch for tests and advanced runtime
  /// overrides. In production code, prefer setting this through [wrap].
  static bool get respectSystemAccessibility =>
      glass_config.respectSystemAccessibility;
  static set respectSystemAccessibility(bool value) =>
      glass_config.respectSystemAccessibility = value;

  /// Deprecated — use [respectSystemAccessibility] instead.
  ///
  /// Retained for discoverability (the two-word form reads naturally as a
  /// boolean predicate). Will be removed in v1.0.
  @Deprecated('Use respectSystemAccessibility instead.')
  static bool get respectsAccessibility => respectSystemAccessibility;
  @Deprecated('Use respectSystemAccessibility instead.')
  static set respectsAccessibility(bool value) =>
      respectSystemAccessibility = value;

  /// Global [LiquidGlassSettings] override for the entire application.
  ///
  /// When set, these settings are used as the base for all glass widgets
  /// unless overridden at the widget or layer level.
  static LiquidGlassSettings? globalSettings;

  // ── initialize() ───────────────────────────────────────────────────────────

  /// Initializes platform-level resources for the Liquid Glass library.
  ///
  /// **Responsibility**: async platform / engine setup only. Call once in
  /// `main()` before [runApp]. All behavioral configuration belongs in [wrap].
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await LiquidGlassWidgets.initialize();
  ///   runApp(LiquidGlassWidgets.wrap(const MyApp()));
  /// }
  /// ```
  ///
  /// ### Parameters
  ///
  /// **`enablePerformanceMonitor`** (default `true`)\
  /// In debug and profile builds, the library registers a
  /// `SchedulerBinding.addTimingsCallback` that watches raster durations while
  /// [GlassQuality.premium] surfaces are mounted. When frames consistently
  /// exceed the GPU budget, a single [FlutterError] is emitted with actionable
  /// guidance. The monitor is **automatically disabled in release builds** —
  /// zero overhead in shipped apps. Set to `false` to suppress it during
  /// profiling sessions where the warning would be a false positive.
  ///
  /// ### Tasks performed
  ///
  /// 1. Pre-warms / precaches the lightweight fragment shader.
  /// 2. Pre-warms the interactive indicator shader (custom refraction).
  /// 3. Pre-warms the Impeller rendering pipeline (iOS / Android / macOS).
  /// 4. Optionally registers the debug performance monitor.
  ///
  /// ### Shaders pre-warmed
  ///
  /// | Shader | Role |
  /// |---|---|
  /// | `lightweight_glass.frag` | Minimal glass layer |
  /// | `interactive_indicator.frag` | Custom refraction effect |
  /// | `liquid_glass_geometry_blended.frag` | Geometry / SDF pass |
  /// | `liquid_glass_final_render.frag` | Final composite pass |
  /// | `progressive_blur.frag` | Graduated backdrop blur ([ProgressiveBlur]) |
  static Future<void> initialize({
    bool enablePerformanceMonitor = true,
    bool warmUpImpellerPipeline = true,
  }) async {
    debugPrint('[LiquidGlass] Initializing library...');

    // 1. Pre-warm shader programs in parallel — prevents first-frame jank /
    //    "white flash" when glass widgets first appear.
    //
    //    Shader asset disk-loads are always performed (fast, I/O only, safe on
    //    all platforms). The GPU warm-up step is conditionally skipped via
    //    [warmUpImpellerPipeline].
    await Future.wait([
      LightweightLiquidGlass.preWarm(),
      GlassEffect.preWarm(),
      MultiShaderBuilder.precacheShaders([
        ShaderKeys.blendedGeometry,
        ShaderKeys.liquidGlassRender,
      ]),
      // ProgressiveBlur's graduated-blur shader — warmed here too so consumers
      // never need a separate preload call (it degrades to a uniform blur if the
      // shader can't load, so this never throws).
      ProgressiveBlur.preload(),
    ]);

    // 2. GPU pipeline warm-up — Android only, sequential after step 1.
    //
    //    Must run after precacheShaders so the cached FragmentProgram objects
    //    are available for the toImage() draw call.
    //
    //    On Android GLES, glCompileShader + glLinkProgram is synchronous on the
    //    raster thread (100–800 ms on mid-range SoCs). Running this before
    //    runApp ensures compilation completes behind the native splash screen,
    //    eliminating the nativeSurfaceChanged race condition that causes ANRs
    //    (see GitHub issue #187).
    //
    //    iOS / macOS use precompiled Metal shaders (zero runtime compilation
    //    cost) and skip this step entirely.
    if (warmUpImpellerPipeline) {
      await _warmUpImpellerPipeline();
    }

    // 3. Register the debug performance monitor (no-op in release builds).
    if (enablePerformanceMonitor && !kReleaseMode) {
      GlassPerformanceMonitor.start();
    }

    debugPrint('[LiquidGlass] Initialization complete.');
  }

  // ── wrap() ─────────────────────────────────────────────────────────────────

  /// Wraps [child] in the Liquid Glass infrastructure scopes and applies all
  /// behavioral configuration.
  ///
  /// **Responsibility**: widget-tree composition and runtime behavior. All
  /// configuration that affects how glass widgets behave lives here — explicit,
  /// visible, and co-located with the widget tree entry point.
  ///
  /// **Optional** — provides app-wide theming and adaptive quality.
  /// `GlassBackdropScope` is no longer needed (each glass layer manages its own
  /// backdrop); `wrap()` is only required if you use `theme:` or
  /// `adaptiveQuality:`.
  ///
  /// ```dart
  /// // Zero-config (most apps):
  /// runApp(LiquidGlassWidgets.wrap(const MyApp()));
  ///
  /// // Recommended for Android / broad device support:
  /// runApp(LiquidGlassWidgets.wrap(
  ///   child: const MyApp(),
  ///   adaptiveQuality: true,
  ///   theme: GlassThemeData(...),
  /// ));
  ///
  /// // Game / experience — bypass accessibility, conservative quality start:
  /// runApp(LiquidGlassWidgets.wrap(
  ///   child: const MyApp(),
  ///   respectSystemAccessibility: false,
  ///   adaptiveQuality: true,
  ///   adaptiveConfig: GlassAdaptiveScopeConfig(
  ///     initialQuality: GlassQuality.standard,
  ///     allowStepUp: true,
  ///   ),
  /// ));
  /// ```
  ///
  /// ### Parameters
  ///
  /// **`respectSystemAccessibility`** (default `true`)\
  /// When `true`, system Reduce Motion and Reduce Transparency flags are
  /// respected automatically — no extra setup required. All glass widgets read
  /// `MediaQuery` directly and degrade gracefully. Set to `false` to ignore
  /// system accessibility flags globally (e.g. for a game where full glass
  /// fidelity is intentional regardless of OS settings). A
  /// [GlassAccessibilityScope] placed anywhere in the widget tree always takes
  /// precedence over this flag, allowing per-subtree overrides.
  ///
  /// **`adaptiveQuality`** (default `false`, **experimental**)\
  /// When `true`, inserts a root [GlassAdaptiveScope] that automatically
  /// benchmarks the device and adjusts the global glass quality ceiling in real
  /// time. Three phases:
  ///
  /// - **Phase 1** (synchronous): forces `minimal` where shaders are
  ///   unsupported; caps at `standard` on web.
  /// - **Phase 2** (~180 frames ≈ 3 s at 60 fps): measures real P75 raster
  ///   durations and sets the initial quality tier.
  /// - **Phase 3** (ongoing, near-zero overhead): degrades when P95 exceeds
  ///   1.5× the frame budget for 3 consecutive windows; recovers when P95
  ///   drops below 0.6× budget for 10 consecutive windows.
  ///
  /// **Experimental in 0.8.0** — Phase 2 thresholds (12 ms / 20 ms P75) are
  /// based on reasoning, not yet validated across the full Android device
  /// landscape. Enable this feature and report unexpected quality degradation
  /// or promotion to help us tune the thresholds.
  ///
  /// Acts as an app-wide *quality ceiling* — individual widgets with an
  /// explicit `quality:` parameter are still capped by it. When no
  /// [adaptiveConfig] is provided, the scope starts at [GlassQuality.standard]
  /// to prevent jank during the warm-up window on mid-range devices.
  ///
  /// For per-screen control, use [GlassAdaptiveScope] directly in the tree.

  ///
  /// **`adaptiveConfig`** (optional)\
  /// Custom [GlassAdaptiveScopeConfig] for the root [GlassAdaptiveScope].
  /// Ignored when [adaptiveQuality] is `false`. Defaults to
  /// `GlassAdaptiveScopeConfig(initialQuality: GlassQuality.standard)`.
  ///
  /// ### Scope nesting order (outermost → innermost → child)
  ///
  /// `GlassAdaptiveScope` (when enabled) → `GlassTheme` (when provided) → `child`
  static Widget wrap({
    required Widget child,
    GlassThemeData? theme,
    bool respectSystemAccessibility = true,
    bool adaptiveQuality = false,
    GlassAdaptiveScopeConfig? adaptiveConfig,

    /// Optional brightness resolver for MaterialApp integration.
    ///
    /// When using `MaterialApp`, pass `Theme.maybeBrightnessOf` here so glass
    /// widgets correctly honour `ThemeMode.light` / `.dark` / `.system` even
    /// when the device OS and the app theme disagree:
    ///
    /// ```dart
    /// runApp(LiquidGlassWidgets.wrap(
    ///   child: const MyApp(),
    ///   brightnessResolver: Theme.maybeBrightnessOf,
    /// ));
    /// ```
    ///
    /// This package has zero `flutter/material.dart` imports (required for the
    /// `cupertino_ui` split). The callback pattern lets you bridge Material's
    /// `ThemeMode` into the glass brightness cascade without coupling the
    /// package to Material. `CupertinoApp` users can omit this parameter.
    Brightness? Function(BuildContext)? brightnessResolver,
  }) {
    // Apply global accessibility preference.
    glass_config.respectSystemAccessibility = respectSystemAccessibility;

    // Register the optional Material brightness resolver.
    // This lets MaterialApp users pass Theme.maybeBrightnessOf without this
    // package needing to import flutter/material.dart.
    glassExternalBrightnessResolver = brightnessResolver;

    Widget result = child;

    if (theme != null) {
      result = GlassTheme(data: theme, child: result);
    }

    if (adaptiveQuality) {
      // When no adaptiveConfig is given: GlassAdaptiveScope.initState() seeds
      // the first frame at GlassQuality.standard while Phase 2 benchmarks the
      // device (~3 s). Phase 2 then promotes to `premium` if the device passes
      // the warmup threshold — no caller config needed.
      //
      // When the caller provides adaptiveConfig: use their settings as-is.
      // If initialQuality is null, Phase 2 still runs fresh and promotes/demotes
      // from the conservative standard starting point.
      final config = adaptiveConfig ?? const GlassAdaptiveScopeConfig();

      result = GlassAdaptiveScope(
        minQuality: config.minQuality,
        maxQuality: config.maxQuality,
        initialQuality: config.initialQuality,
        targetFrameMs: config.targetFrameMs,
        allowStepUp: config.allowStepUp,
        onQualityChanged: config.onQualityChanged,
        onDiagnostic: config.onDiagnostic,
        debugLogDiagnostics: config.debugLogDiagnostics,
        child: result,
      );
    }

    return result;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Performs a true asynchronous GPU pipeline warm-up for Android.
  ///
  /// ## Why Android only?
  ///
  /// iOS and macOS use Impeller with Metal, whose shaders are precompiled at
  /// build time into a `.metallib` archive. There is no runtime compilation
  /// step, so no warm-up is needed and this method returns immediately on
  /// those platforms.
  ///
  /// On Android, Impeller may use:
  /// - **Vulkan** — PSO creation from precompiled SPIR-V is fast (~1–2 ms).
  /// - **GLES fallback** — `glCompileShader` + `glLinkProgram` compiles GLSL
  ///   source text at runtime on the raster thread (100–800 ms on mid-range
  ///   SoCs). If this occurs during the first UI frame it races with Android's
  ///   `FlutterJNI.nativeSurfaceChanged`, potentially triggering an ANR
  ///   ("Input dispatching timed out"; see GitHub issue #187).
  ///
  /// ## Mechanism
  ///
  /// Draws both premium glass shaders to a 1×1 off-screen surface and awaits
  /// `Picture.toImage()`. This submits a rasterization job to the Flutter
  /// raster thread, which forces Impeller to compile and link the shader
  /// programs before the first real UI frame is requested.
  ///
  /// Because [initialize] is `await`ed in `main()` before `runApp`, this
  /// compilation happens entirely behind the native splash screen — the ANR
  /// window cannot open.
  ///
  /// ## Pipeline coverage note
  ///
  /// The warm-up draw call uses a simple `drawRect`, which may produce a
  /// slightly different Impeller pipeline descriptor than the full
  /// [LiquidGlassLayer] rendering path (different vertex attributes, blend
  /// state). On GLES, however, once `glCompileShader` has executed for a
  /// fragment shader, any subsequent `glLinkProgram` for a different
  /// vertex/blend combination is significantly cheaper (~20–50 ms), well
  /// within Android's 5-second ANR threshold.
  ///
  /// Called by [initialize] only when [warmUpImpellerPipeline] is `true`.
  static Future<void> _warmUpImpellerPipeline() async {
    // iOS / macOS: Metal uses precompiled shaders — zero runtime cost.
    // Web / Skia: Impeller is not active — isShaderFilterSupported == false.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!ui.ImageFilter.isShaderFilterSupported) return;

    // Retrieve the FragmentProgram objects already cached by step 1 of
    // initialize(). Reusing cached instances avoids creating duplicate GPU
    // objects. If either program is missing (precacheShaders failed),
    // we skip silently — the app will still run, with possible first-frame
    // stutter on GLES.
    final blendedGeometry =
        MultiShaderBuilder.cachedProgram(ShaderKeys.blendedGeometry);
    final finalRender =
        MultiShaderBuilder.cachedProgram(ShaderKeys.liquidGlassRender);

    if (blendedGeometry == null || finalRender == null) {
      debugPrint(
        '[LiquidGlass] Skipping GPU warm-up: shader programs not in cache '
        '(precacheShaders may have failed).',
      );
      return;
    }

    try {
      // Create a 1x1 dummy image to satisfy the fragment shader samplers.
      // If we don't bind samplers, Impeller throws "missing sampler".
      final dummyRecorder = ui.PictureRecorder();
      final dummyCanvas = ui.Canvas(dummyRecorder);
      dummyCanvas.drawColor(const ui.Color(0x00000000), ui.BlendMode.clear);
      final dummyImage = await dummyRecorder.endRecording().toImage(1, 1);

      // Draw both shaders to a 1×1 surface. On GLES this forces
      // glCompileShader + glLinkProgram on the raster thread.
      // On Vulkan this completes in ~1–2 ms.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      for (final program in [blendedGeometry, finalRender]) {
        final shader = program.fragmentShader();

        if (program == finalRender) {
          shader.setImageSampler(0, dummyImage);
          shader.setImageSampler(1, dummyImage);
        }

        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 1, 1),
          ui.Paint()..shader = shader,
        );
        shader.dispose();
      }

      final image = await recorder.endRecording().toImage(1, 1);

      dummyImage.dispose();
      image.dispose();

      debugPrint('[LiquidGlass] ✓ Android GPU pipeline warm-up complete.');
    } catch (e) {
      // Non-fatal: log and continue. The app will launch normally; the first
      // glass frame may stutter on GLES but will not crash.
      debugPrint('[LiquidGlass] GPU warm-up failed (non-critical): $e');
    }
  }
}
