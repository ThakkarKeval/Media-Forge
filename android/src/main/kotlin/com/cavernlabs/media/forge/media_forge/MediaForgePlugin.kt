package com.cavernlabs.media.forge.media_forge

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** MediaForgePlugin */
class MediaForgePlugin :
    FlutterPlugin,
    MediaForgePluginApi {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MediaForgePluginApi.setUp(binding.binaryMessenger, this)
    }

    override fun getPlatformVersion(): String = "Android ${android.os.Build.VERSION.RELEASE}"

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MediaForgePluginApi.setUp(binding.binaryMessenger, null)
    }
}
