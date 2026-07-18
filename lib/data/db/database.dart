import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the bundled Kalimat SQLite database.
///
/// Offline-first strategy:
///  1. The prebuilt `kalimat.db` ships inside the APK as an asset.
///  2. On first launch (or when the bundled version is newer) we copy it into
///     the app's writable documents dir.
///  3. We open it READ-ONLY — the app never mutates the dictionary.
///
/// To ship a content update you rebuild `kalimat.db` in your Python pipeline,
/// bump [bundledDbVersion], and release. The copy-if-newer check swaps it in.
class KalimatDb {
  KalimatDb._();
  static final KalimatDb instance = KalimatDb._();

  static const _assetPath = 'assets/db/kalimat.db';
  static const _fileName = 'kalimat.db';

  /// Bump this whenever you ship a new kalimat.db (keep in sync with meta.db_version).
  static const bundledDbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _fileName);
    final versionFile = File('$dbPath.version');

    final exists = await File(dbPath).exists();
    final installedVersion = exists && await versionFile.exists()
        ? int.tryParse((await versionFile.readAsString()).trim()) ?? 0
        : 0;

    if (!exists || installedVersion < bundledDbVersion) {
      await _copyFromAsset(dbPath);
      await versionFile.writeAsString('$bundledDbVersion');
    }

    return openDatabase(dbPath, readOnly: true);
  }

  Future<void> _copyFromAsset(String dbPath) async {
    // Ensure the parent dir exists.
    await Directory(p.dirname(dbPath)).create(recursive: true);
    final bytes = await rootBundle.load(_assetPath);
    final buffer = bytes.buffer;
    await File(dbPath).writeAsBytes(
      buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
  }
}
