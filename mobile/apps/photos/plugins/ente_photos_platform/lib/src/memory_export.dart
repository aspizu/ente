import 'package:flutter/services.dart';

class MemoryExportClient {
  MemoryExportClient._();

  static final instance = MemoryExportClient._();

  static const _channel = MethodChannel(
    'io.ente.photos.platform/memory_export',
  );
  final Stream<double> progress = const EventChannel(
    'io.ente.photos.platform/memory_export/progress',
  ).receiveBroadcastStream().map((event) => (event as num).toDouble());

  Future<void> export({
    required List<String> input,
    required String output,
  }) async {
    await _channel.invokeMethod<void>('exportMemory', {
      'input': input,
      'output': output,
    });
  }

  Future<void> cancelExport() async {
    await _channel.invokeMethod<void>('cancelExport');
  }
}
