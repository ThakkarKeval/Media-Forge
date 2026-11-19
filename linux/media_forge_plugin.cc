#include "include/media_forge/media_forge_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "messages.g.h"
#include "media_forge_plugin_private.h"

#define MEDIA_FORGE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), media_forge_plugin_get_type(), \
                              MediaForgePlugin))

struct _MediaForgePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(MediaForgePlugin, media_forge_plugin, g_object_get_type())

gchar* media_forge_plugin_get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  return g_strdup_printf("Linux %s", uname_data.version);
}

static MediaForgeMediaForgePluginApiGetPlatformVersionResponse *handle_get_platform_version(gpointer user_data) {
  // The plugin instance is unused in this simple example, but more complex
  // plugins may have plugin state to access here.
  // MediaForgePlugin* self = MEDIA_FORGE_PLUGIN(user_data);

  g_autofree gchar *version = media_forge_plugin_get_platform_version();
  return media_forge_media_forge_plugin_api_get_platform_version_response_new(version);
}

static void media_forge_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(media_forge_plugin_parent_class)->dispose(object);
}

static void media_forge_plugin_class_init(MediaForgePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = media_forge_plugin_dispose;
}

static void media_forge_plugin_init(MediaForgePlugin* self) {}

void media_forge_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  MediaForgePlugin* plugin = MEDIA_FORGE_PLUGIN(
      g_object_new(media_forge_plugin_get_type(), nullptr));

  static MediaForgeMediaForgePluginApiVTable api_vtable = {
    .get_platform_version = handle_get_platform_version
  };
  media_forge_media_forge_plugin_api_set_method_handlers(
    fl_plugin_registrar_get_messenger(registrar), nullptr,
    &api_vtable, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
