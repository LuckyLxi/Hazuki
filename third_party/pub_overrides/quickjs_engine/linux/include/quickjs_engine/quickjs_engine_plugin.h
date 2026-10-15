#ifndef FLUTTER_PLUGIN_QUICKJS_ENGINE_PLUGIN_H_
#define FLUTTER_PLUGIN_QUICKJS_ENGINE_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

typedef struct _QuickjsEnginePlugin QuickjsEnginePlugin;
typedef struct {
  GObjectClass parent_class;
} QuickjsEnginePluginClass;

FLUTTER_PLUGIN_EXPORT GType quickjs_engine_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void quickjs_engine_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_QUICKJS_ENGINE_PLUGIN_H_
