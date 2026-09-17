import "dart:io";

import "package:ente_photos_platform/ente_photos_platform.dart";
import "package:flutter/services.dart";
import "package:logging/logging.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";
import "package:photos/models/file/file.dart";
import "package:photos/module/download/file.dart";

class MemoryExportService {
  MemoryExportService._();

  static final instance = MemoryExportService._();
  static final _logger = Logger("MemoryExportService");

  final Stream<double> progress = MemoryExportClient.instance.progress;
  bool _isExporting = false;
  bool _cancelRequested = false;

  bool get isExporting => _isExporting;

  Future<void> cancelExport() async {
    if (!_isExporting) return;
    _cancelRequested = true;
    await MemoryExportClient.instance.cancelExport();
  }

  Future<File?> export({required List<EnteFile> input}) async {
    if (_isExporting) {
      throw StateError("A memory export is already in progress");
    }
    _isExporting = true;
    _cancelRequested = false;
    final files = <File>[];
    final originPaths = <String>{};
    Directory? exportDirectory;
    try {
      for (final enteFile in input) {
        var file = await getFile(enteFile, isOrigin: true);
        if (file != null &&
            Platform.isIOS &&
            !enteFile.isRemoteOnlyFile &&
            !enteFile.isSharedMediaToAppSandbox) {
          originPaths.add(file.path);
        }
        if (_cancelRequested) {
          throw PlatformException(code: "export_cancelled");
        }
        if (file == null && enteFile.uploadedFileID != null) {
          file = await getFileFromServer(enteFile);
        }
        if (_cancelRequested) {
          throw PlatformException(code: "export_cancelled");
        }
        if (file == null) {
          throw StateError("Failed to resolve a file for memory export");
        }
        files.add(file);
      }
      final tempDirectory = await getTemporaryDirectory();
      exportDirectory = await tempDirectory.createTemp("memory_export_");
      final output = await File(
        path.join(exportDirectory.path, "memory.mp4"),
      ).create();
      if (_cancelRequested) {
        throw PlatformException(code: "export_cancelled");
      }
      await MemoryExportClient.instance.export(
        input: files.map((file) => file.path).toList(),
        output: output.path,
      );
      if (_cancelRequested) {
        throw PlatformException(code: "export_cancelled");
      }
      return output;
    } catch (error) {
      if (exportDirectory != null) {
        try {
          await exportDirectory.delete(recursive: true);
        } catch (e, s) {
          _logger.warning("Failed to delete export directory", e, s);
        }
      }
      if (error is PlatformException && error.code == "export_cancelled") {
        return null;
      }
      rethrow;
    } finally {
      for (final originPath in originPaths) {
        try {
          await File(originPath).delete();
        } catch (e, s) {
          _logger.warning("Failed to delete origin file", e, s);
        }
      }
      _isExporting = false;
    }
  }
}
