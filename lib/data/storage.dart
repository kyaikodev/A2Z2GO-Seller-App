import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a seller's saved shop data lives. [AppStore] only talks to this, so
/// moving to a database or a server later means writing one more class here.
abstract class StoreStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Keeps data in the phone's key-value preferences (used in tests and on web).
class PrefsStorage implements StoreStorage {
  final SharedPreferences prefs;
  PrefsStorage(this.prefs);

  @override
  Future<String?> read(String key) async => prefs.getString(key);

  @override
  Future<void> write(String key, String value) => prefs.setString(key, value);

  @override
  Future<void> remove(String key) => prefs.remove(key);
}

/// Keeps each seller's data in its own file in the app's private folder.
/// A save writes a temporary file first and then swaps it in, so a crash in the
/// middle of a save can never leave a half-written data file. Unlike the
/// preferences file, it has no practical size limit and is not rewritten
/// together with every other setting.
class FileStorage implements StoreStorage {
  final Directory dir;
  FileStorage(this.dir);

  static Future<FileStorage> create() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/shop_data');
    if (!d.existsSync()) d.createSync(recursive: true);
    return FileStorage(d);
  }

  File _file(String key) => File(
    '${dir.path}/${key.replaceAll(RegExp(r'[^A-Za-z0-9_+\-]'), '_')}.json',
  );

  @override
  Future<String?> read(String key) async {
    final f = _file(key);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String key, String value) async {
    final f = _file(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> remove(String key) async {
    final f = _file(key);
    if (f.existsSync()) await f.delete();
    final tmp = File('${f.path}.tmp');
    if (tmp.existsSync()) await tmp.delete();
  }
}

/// How the running app opens its storage. Tests leave this as is (null means
/// preferences); `main()` points it at files on the phone.
Future<StoreStorage?> Function() openStorage = () async => null;

/// Removes a seller's saved files (used by "Delete account"). Safe to call
/// where there is no file storage, such as tests.
Future<void> deleteSavedFiles(String phone) async {
  try {
    final s = await FileStorage.create();
    await s.remove('data_$phone');
    await s.remove('data_${phone}_backup');
  } catch (_) {}
}
