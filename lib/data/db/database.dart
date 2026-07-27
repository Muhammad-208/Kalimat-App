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

  /// Fingerprint of the bundled kalimat.db, written by `tools/stamp_db.py`.
  ///
  /// The install decision is driven by this stamp rather than by a
  /// hand-maintained integer. Relying on the integer failed twice: new content
  /// shipped, the bump was forgotten, and every existing install silently kept
  /// its old database — the app looked empty while the shipped data was fine.
  /// The stamp changes automatically whenever the database does.
  static const _stampAsset = 'assets/db/kalimat.db.stamp';

  /// Floor for installs predating the stamp (they have no stamp file to read).
  static const bundledDbVersion = 3;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _fileName);
    final versionFile = File('$dbPath.version');

    final stampFile = File('$dbPath.stamp');

    final exists = await File(dbPath).exists();
    final installedVersion = exists && await versionFile.exists()
        ? int.tryParse((await versionFile.readAsString()).trim()) ?? 0
        : 0;

    // The stamp asset is tiny (a hex digest), so reading it on every launch is
    // cheap — unlike the multi-megabyte database it describes.
    final bundledStamp =
        (await rootBundle.loadString(_stampAsset, cache: false)).trim();
    final installedStamp = exists && await stampFile.exists()
        ? (await stampFile.readAsString()).trim()
        : '';

    if (!exists ||
        installedVersion < bundledDbVersion ||
        installedStamp != bundledStamp) {
      await _copyFromAsset(dbPath);
      await versionFile.writeAsString('$bundledDbVersion');
      await stampFile.writeAsString(bundledStamp);
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
