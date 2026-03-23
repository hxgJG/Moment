import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Android / iOS 使用原生 sqflite；桌面端必须初始化 FFI 后再 openDatabase。
Future<void> initSqfliteForPlatform() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return;
  }
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
