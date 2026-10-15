// Minimal GTK Flutter plugin shim — no method-channel handlers needed.
// The Dart side talks to quickjs-ng directly through FFI.
#include "include/quickjs_engine/quickjs_engine_plugin.h"
#include <flutter_linux/flutter_linux.h>

#define QUICKJS_ENGINE_PLUGIN(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), quickjs_engine_plugin_get_type(), QuickjsEnginePlugin))

struct _QuickjsEnginePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(QuickjsEnginePlugin, quickjs_engine_plugin, g_object_get_type())

static void quickjs_engine_plugin_class_init(QuickjsEnginePluginClass* klass) {}
static void quickjs_engine_plugin_init(QuickjsEnginePlugin* self) {}

void quickjs_engine_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  QuickjsEnginePlugin* plugin = QUICKJS_ENGINE_PLUGIN(
      g_object_new(quickjs_engine_plugin_get_type(), nullptr));
  g_object_unref(plugin);
}
