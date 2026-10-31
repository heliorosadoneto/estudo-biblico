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

/// Senha local: hash SHA-256 com sal aleatório.
class Auth {
  static Future<bool> hasPassword() async => (await SharedPreferences.getInstance()).containsKey('pw_hash');
  static String _hash(String salt, String pw) => sha256.convert(utf8.encode('$salt:$pw')).toString();
  static Future<void> setPassword(String pw) async {
    final r = Random.secure();
    final salt = base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
    final sp = await SharedPreferences.getInstance();
    await sp.setString('pw_salt', salt);
    await sp.setString('pw_hash', _hash(salt, pw));
  }
  static Future<bool> check(String pw) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('pw_hash') == _hash(sp.getString('pw_salt') ?? '', pw);
  }
}
