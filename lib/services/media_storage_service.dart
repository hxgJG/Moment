import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../services/database_service.dart';

class MediaStorageReport {
  final int totalFileCount;
  final int referencedFileCount;
  final int orphanFileCount;
  final int totalBytes;
  final int referencedBytes;
  final int orphanBytes;

  const MediaStorageReport({
    required this.totalFileCount,
    required this.referencedFileCount,
    required this.orphanFileCount,
    required this.totalBytes,
    required this.referencedBytes,
    required this.orphanBytes,
  });
}

class MediaStorageCleanupResult {
  final int deletedFileCount;
  final int freedBytes;

  const MediaStorageCleanupResult({
    required this.deletedFileCount,
    required this.freedBytes,
  });
}

class MediaStorageService {
  final DatabaseService _databaseService;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Set<String>> Function()? _referencedPathsProvider;

  MediaStorageService({
    DatabaseService? databaseService,
    Future<Directory> Function()? documentsDirectory,
    Future<Set<String>> Function()? referencedPathsProvider,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _referencedPathsProvider = referencedPathsProvider;

  Future<MediaStorageReport> inspectStorage() async {
    final managedFiles = await _managedFiles();
    final referencedPaths = await _loadReferencedPaths();

    var totalBytes = 0;
    var referencedBytes = 0;
    var orphanBytes = 0;
    var referencedFileCount = 0;
    var orphanFileCount = 0;

    for (final file in managedFiles) {
      final stat = await file.stat();
      final size = stat.size;
      totalBytes += size;

      if (referencedPaths.contains(file.path)) {
        referencedFileCount++;
        referencedBytes += size;
      } else {
        orphanFileCount++;
        orphanBytes += size;
      }
    }

    return MediaStorageReport(
      totalFileCount: managedFiles.length,
      referencedFileCount: referencedFileCount,
      orphanFileCount: orphanFileCount,
      totalBytes: totalBytes,
      referencedBytes: referencedBytes,
      orphanBytes: orphanBytes,
    );
  }

  Future<MediaStorageCleanupResult> deleteOrphanedFiles() async {
    final managedFiles = await _managedFiles();
    final referencedPaths = await _loadReferencedPaths();

    var deletedFileCount = 0;
    var freedBytes = 0;

    for (final file in managedFiles) {
      if (referencedPaths.contains(file.path)) {
        continue;
      }
      final stat = await file.stat();
      await file.delete();
      deletedFileCount++;
      freedBytes += stat.size;
    }

    return MediaStorageCleanupResult(
      deletedFileCount: deletedFileCount,
      freedBytes: freedBytes,
    );
  }

  Future<Set<String>> _loadReferencedPaths() async {
    final provider = _referencedPathsProvider;
    if (provider != null) {
      return provider();
    }
    return (await _databaseService.getAllLocalMediaPaths()).toSet();
  }

  Future<List<File>> _managedFiles() async {
    final docsDir = await _documentsDirectory();
    final targets = [
      Directory('${docsDir.path}/media'),
      Directory('${docsDir.path}/audio'),
    ];

    final files = <File>[];
    for (final dir in targets) {
      if (!await dir.exists()) {
        continue;
      }
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          files.add(entity);
        }
      }
    }
    return files;
  }
}
