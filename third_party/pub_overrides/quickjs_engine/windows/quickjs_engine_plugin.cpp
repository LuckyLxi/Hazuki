// Minimal Windows Flutter plugin shim — no method-channel handlers.
// The Dart side talks to quickjs-ng directly through FFI.
#include "include/quickjs_engine/quickjs_engine_plugin_c_api.h"
#include <flutter/plugin_registrar_windows.h>

namespace quickjs_engine {
class QuickjsEnginePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<QuickjsEnginePlugin>();
    registrar->AddPlugin(std::move(plugin));
  }
  QuickjsEnginePlugin() {}
  virtual ~QuickjsEnginePlugin() {}
};
}  // namespace quickjs_engine

void QuickjsEnginePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  quickjs_engine::QuickjsEnginePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
