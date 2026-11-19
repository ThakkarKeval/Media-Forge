package com.cavernlabs.media.forge.media_forge

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** MediaForgePlugin */
class MediaForgePlugin :
    FlutterPlugin,
    ActivityAware,
    MediaForgePluginApi {

    private var picker: MediaForgePicker? = null
    private var processor: MediaForgeProcessor? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MediaForgePluginApi.setUp(binding.binaryMessenger, this)

        val pickerInstance = MediaForgePicker(binding.applicationContext)
        picker = pickerInstance
        MediaForgePickerApi.setUp(binding.binaryMessenger, pickerInstance)

        val processorInstance = MediaForgeProcessor(binding.applicationContext)
        processor = processorInstance
        MediaForgeProcessorApi.setUp(binding.binaryMessenger, processorInstance)
    }

    override fun getPlatformVersion(): String = "Android ${android.os.Build.VERSION.RELEASE}"

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MediaForgePluginApi.setUp(binding.binaryMessenger, null)
        MediaForgePickerApi.setUp(binding.binaryMessenger, null)
        MediaForgeProcessorApi.setUp(binding.binaryMessenger, null)
        picker = null
        processor = null
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        picker?.activity = binding.activity
        binding.addActivityResultListener(picker!!)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(picker ?: return)
        picker?.activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(picker ?: return)
        picker?.activity = null
        activityBinding = null
    }
}
