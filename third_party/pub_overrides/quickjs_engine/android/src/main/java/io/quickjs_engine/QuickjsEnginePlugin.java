package io.quickjs_engine;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * Android registration stub for quickjs_engine.
 *
 * <p>All JavaScript work happens in the bundled native library through dart:ffi, so this class
 * only exists to satisfy Flutter's plugin registration. It is written in Java on purpose: the
 * plugin does not apply the Kotlin Gradle Plugin, which keeps it compatible with both AGP 8 apps
 * and AGP 9 apps that use built-in Kotlin.
 */
public class QuickjsEnginePlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "io.quickjs_engine");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    result.notImplemented();
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
  }
}
