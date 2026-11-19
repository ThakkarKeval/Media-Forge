#ifndef FLUTTER_PLUGIN_MEDIA_FORGE_PLUGIN_H_
#define FLUTTER_PLUGIN_MEDIA_FORGE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "messages.g.h"

namespace media_forge {

class MediaForgePlugin : public flutter::Plugin, public MediaForgePluginApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MediaForgePlugin();

  virtual ~MediaForgePlugin();

  // Disallow copy and assign.
  MediaForgePlugin(const MediaForgePlugin&) = delete;
  MediaForgePlugin& operator=(const MediaForgePlugin&) = delete;

  ErrorOr<std::string> GetPlatformVersion() override;
};

}  // namespace media_forge

#endif  // FLUTTER_PLUGIN_MEDIA_FORGE_PLUGIN_H_
