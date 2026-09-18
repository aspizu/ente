@preconcurrency import Flutter
import Foundation

@MainActor
final class MemoryExportChannelAdapter: NSObject, @preconcurrency FlutterStreamHandler {
    private let channel: FlutterMethodChannel
    private let progressChannel: FlutterEventChannel
    private var progressSink: FlutterEventSink?

    init(registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "io.ente.photos.platform/memory_export",
            binaryMessenger: registrar.messenger()
        )
        progressChannel = FlutterEventChannel(
            name: "io.ente.photos.platform/memory_export/progress",
            binaryMessenger: registrar.messenger()
        )
        super.init()
        progressChannel.setStreamHandler(self)
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "cancelExport" {
                result(nil)
                return
            }
            guard call.method == "exportMemory" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let arguments = call.arguments as! [String: Any]
            let input = arguments["input"] as! [String]
            let output = arguments["output"] as! String
            do {
                try MemoryExportService.shared.exportMemory(input: input, output: URL(fileURLWithPath: output)) { progress in
                    self?.progressSink?(min(max(progress, 0.0), 1.0))
                }
                result(nil)
            } catch MemoryExportService.ExportError.unimplemented(let message) {
                result(FlutterError(code: "unimplemented", message: message, details: nil))
            } catch {
                result(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
            }
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        progressSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressSink = nil
        return nil
    }

    func detach() {
        channel.setMethodCallHandler(nil)
        progressChannel.setStreamHandler(nil)
        progressSink = nil
    }
}
