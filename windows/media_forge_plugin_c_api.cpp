#include "include/media_forge/media_forge_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "media_forge_plugin.h"

void MediaForgePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  media_forge::MediaForgePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
