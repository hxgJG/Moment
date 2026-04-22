import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:moment/services/media_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inspectStorage reports orphan files and cleanup deletes them',
      () async {
    final docsDir =
        await Directory.systemTemp.createTemp('moment-storage-docs');
    addTearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });

    final mediaDir = Directory('${docsDir.path}/media')
      ..createSync(recursive: true);
    final audioDir = Directory('${docsDir.path}/audio')
      ..createSync(recursive: true);

    final referenced = File('${mediaDir.path}/referenced.jpg');
    await referenced.writeAsString('image-data');
    final orphanMedia = File('${mediaDir.path}/orphan.jpg');
    await orphanMedia.writeAsString('unused-image');
    final orphanAudio = File('${audioDir.path}/orphan.m4a');
    await orphanAudio.writeAsString('unused-audio');

    final service = MediaStorageService(
      documentsDirectory: () async => docsDir,
      referencedPathsProvider: () async => {referenced.path},
    );

    final report = await service.inspectStorage();
    expect(report.totalFileCount, 3);
    expect(report.referencedFileCount, 1);
    expect(report.orphanFileCount, 2);

    final cleanup = await service.deleteOrphanedFiles();
    expect(cleanup.deletedFileCount, 2);
    expect(await referenced.exists(), isTrue);
    expect(await orphanMedia.exists(), isFalse);
    expect(await orphanAudio.exists(), isFalse);

    final refreshed = await service.inspectStorage();
    expect(refreshed.totalFileCount, 1);
    expect(refreshed.orphanFileCount, 0);
  });
}
