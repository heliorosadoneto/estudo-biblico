import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class Entry {
  int? id;
  String title, body;
  DateTime date;
  Entry({this.id, required this.title, required this.body, required this.date});
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'body': body, 'date': date.millisecondsSinceEpoch};
  static Entry fromMap(Map<String, Object?> m) => Entry(
      id: m['id'] as int?, title: m['title'] as String, body: m['body'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int));
}

abstract class EntryStore {
  Future<List<Entry>> all();
  Future<void> save(Entry e);
  Future<void> delete(int id);
  Future<void> replaceAll(List<Entry> entries);
}

class SqlStore implements EntryStore {
  Database? _db;
  Future<Database> get db async => _db ??= await openDatabase(p.join(await getDatabasesPath(), 'diario.db'),
      version: 1, onCreate: (d, _) => d.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, body TEXT, date INTEGER)'));
  @override
  Future<List<Entry>> all() async => (await (await db).query('entries', orderBy: 'date DESC')).map(Entry.fromMap).toList();
  @override
  Future<void> save(Entry e) async {
    final d = await db;
    if (e.id == null) {
      e.id = await d.insert('entries', e.toMap()..remove('id'));
    } else {
      await d.update('entries', e.toMap(), where: 'id=?', whereArgs: [e.id]);
    }
  }
  @override
  Future<void> delete(int id) async => (await db).delete('entries', where: 'id=?', whereArgs: [id]);
  @override
  Future<void> replaceAll(List<Entry> entries) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('entries');
      for (final e in entries) { e.id = await t.insert('entries', e.toMap()..remove('id')); }
    });
  }
}

class MemoryStore implements EntryStore {
  final List<Entry> items;
  MemoryStore(this.items);
  @override
  Future<List<Entry>> all() async => [...items]..sort((a, b) => b.date.compareTo(a.date));
  @override
  Future<void> save(Entry e) async { if (e.id == null) { e.id = items.length + 1; items.add(e); } }
  @override
  Future<void> delete(int id) async => items.removeWhere((e) => e.id == id);
  @override
  Future<void> replaceAll(List<Entry> entries) async { items..clear()..addAll(entries); for (var i = 0; i < items.length; i++) { items[i].id = i + 1; } }
}

/// Local password. Only a salted SHA-256 hash is stored, never the plaintext.
///
/// The current record is a single preference so replacing the password cannot
/// leave the previous hash in place if a second write is dropped. Records
/// written by older builds (`pw_salt` + `pw_hash`) still verify until the next
/// successful change, which removes them.
class Auth {
  static const _recordKey = 'pw_record';
  static const _legacyHashKey = 'pw_hash';
  static const _legacySaltKey = 'pw_salt';

  static Future<bool> hasPassword() async {
    final sp = await SharedPreferences.getInstance();
    return sp.containsKey(_recordKey) || sp.containsKey(_legacyHashKey);
  }

  static String _hash(String salt, String pw) => sha256.convert(utf8.encode('$salt:$pw')).toString();

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Persists [pw] and drops every previously stored secret.
  static Future<void> setPassword(String pw) async {
    final salt = _newSalt();
    final record = jsonEncode({'s': salt, 'h': _hash(salt, pw)});
    final sp = await SharedPreferences.getInstance();
    if (!await sp.setString(_recordKey, record)) {
      throw StateError('Could not persist the new password');
    }
    await sp.remove(_legacyHashKey);
    await sp.remove(_legacySaltKey);
  }

  static Future<bool> check(String pw) async {
    final sp = await SharedPreferences.getInstance();
    final record = sp.getString(_recordKey);
    if (record != null) {
      final decoded = jsonDecode(record);
      if (decoded is! Map) return false;
      final salt = decoded['s'] as String?;
      final hash = decoded['h'] as String?;
      if (salt == null || hash == null) return false;
      return hash == _hash(salt, pw);
    }
    final hash = sp.getString(_legacyHashKey);
    if (hash == null) return false;
    return hash == _hash(sp.getString(_legacySaltKey) ?? '', pw);
  }
}
