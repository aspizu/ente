package io.ente.photos.platform.flutter

import android.content.Context
import androidx.media3.transformer.Transformer
import io.ente.photos.platform.memoryexport.MemoryExportService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class MemoryExportChannelAdapter : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var progressChannel: EventChannel
    private var progressSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var transformer: Transformer? = null
    private var pendingResult: MethodChannel.Result? = null

    fun attach(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "io.ente.photos.platform/memory_export")
        progressChannel = EventChannel(binding.binaryMessenger, "io.ente.photos.platform/memory_export/progress")
        channel.setMethodCallHandler(this)
        progressChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancelExport") {
            try {
                cancelExport()
                result.success(null)
            } catch (error: Exception) {
                result.error("export_failed", error.message, null)
            }
            return
        }
        if (call.method != "exportMemory") {
            result.notImplemented()
            return
        }
        val input = call.argument<List<String>>("input")!!
        val output = call.argument<String>("output")!!
        if (pendingResult != null) {
            result.error("export_failed", "A memory export is already in progress", null)
            return
        }
        pendingResult = result
        try {
            transformer = MemoryExportService.exportMemory(
                context,
                input,
                File(output),
                onProgress = { progress ->
                    progressSink?.success(progress.coerceIn(0.0, 1.0))
                },
                onCompleted = {
                    transformer = null
                    pendingResult = null
                    result.success(null)
                },
                onError = { error ->
                    transformer = null
                    pendingResult = null
                    result.error("export_failed", error.message, null)
                }
            )
        } catch (error: Exception) {
            pendingResult = null
            result.error("export_failed", error.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }

    fun cancelExport() {
        transformer?.cancel()
        transformer = null
        pendingResult?.error("export_cancelled", "Memory export cancelled", null)
        pendingResult = null
    }

    fun detach() {
        cancelExport()
        channel.setMethodCallHandler(null)
        progressChannel.setStreamHandler(null)
        progressSink = null
    }
}
