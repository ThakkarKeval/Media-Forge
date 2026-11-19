//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <media_forge/media_forge_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) media_forge_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MediaForgePlugin");
  media_forge_plugin_register_with_registrar(media_forge_registrar);
}
