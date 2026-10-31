import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';

/// Senha da sessão (só em memória, após desbloquear) — usada para cifrar os backups automáticos.
class Session {
  static String? password;
}

class BadPassword implements Exception {}
class BadFile implements Exception {}

/// Formato do arquivo: "MDB1" | sal(16) | nonce(12) | cifra AES-256-GCM | mac(16)
class BackupCrypto {
  static const _magic = [0x4D, 0x44, 0x42, 0x31];
  static int iterations = 100000;
  static final _aes = AesGcm.with256bits();

  static Future<SecretKey> _key(String pw, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256).deriveKeyFromPassword(password: pw, nonce: salt);

  static Future<Uint8List> encrypt(List<int> plain, String pw) async {
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final nonce = List<int>.generate(12, (_) => r.nextInt(256));
    final box = await _aes.encrypt(plain, secretKey: await _key(pw, salt), nonce: nonce);
    return Uint8List.fromList([..._magic, ...salt, ...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<List<int>> decrypt(List<int> data, String pw) async {
    if (data.length < 48 || !listEquals(data.sublist(0, 4), _magic)) throw BadFile();
    final salt = data.sublist(4, 20), nonce = data.sublist(20, 32);
    final box = SecretBox(data.sublist(32, data.length - 16), nonce: nonce, mac: Mac(data.sublist(data.length - 16)));
    try {
      return await _aes.decrypt(box, secretKey: await _key(pw, salt));
    } on SecretBoxAuthenticationError {
      throw BadPassword();
    }
  }
}

class Backup {
  static Future<List<int>> serialize(EntryStore store) async {
    final sp = await SharedPreferences.getInstance();
    return utf8.encode(jsonEncode({
      'app': 'meu_diario', 'version': 1, 'created': DateTime.now().toIso8601String(),
      'entries': [for (final e in await store.all()) e.toMap()..remove('id')],
      'favorites': sp.getStringList('fav') ?? [],
    }));
  }

  static Future<int> restore(EntryStore store, List<int> json) async {
    final m = jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
    if (m['app'] != 'meu_diario') throw BadFile();
    final entries = [for (final e in m['entries'] as List) Entry.fromMap(Map<String, Object?>.from(e as Map))];
    await store.replaceAll(entries);
    await (await SharedPreferences.getInstance()).setStringList('fav', List<String>.from(m['favorites'] as List));
    return entries.length;
  }

  static Future<Uint8List> export(EntryStore store, String pw) async => BackupCrypto.encrypt(await serialize(store), pw);
  static Future<int> import(EntryStore store, List<int> file, String pw) async => restore(store, await BackupCrypto.decrypt(file, pw));
}

/// Google Drive (pasta oculta appDataFolder).
class DriveBackup {
  static const fileName = 'meu_diario_backup.mdb';
  static final _gs = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  static EntryStore? store;
  static Timer? _debounce;
  static final changes = ValueNotifier(0);

  static GoogleSignInAccount? get account => _gs.currentUser;

  static Future<void> init(EntryStore s) async {
    store = s;
    try { await _gs.signInSilently(); } catch (_) {}
    changes.value++;
    if ((await SharedPreferences.getInstance()).getBool('backup_pending') ?? false) unawaited(auto());
  }

  /// Lança exceção com mensagem amigável se o Drive não estiver configurado.
  static Future<GoogleSignInAccount?> connect() async {
    try {
      final a = await _gs.signIn();
      changes.value++;
      return a;
    } catch (e) {
      throw Exception('Não foi possível conectar ao Google Drive. O login do Google ainda não foi configurado para este app '
          '(veja docs/GOOGLE_DRIVE.md) ou não há internet. O diário continua funcionando normalmente.');
    }
  }

  static Future<void> disconnect() async {
    try { await _gs.disconnect(); } catch (_) { await _gs.signOut(); }
    changes.value++;
  }

  static Future<drive.DriveApi> _api() async {
    final client = await _gs.authenticatedClient();
    if (client == null) throw Exception('Conta Google não conectada');
    return drive.DriveApi(client);
  }

  static Future<String?> _fileId(drive.DriveApi api) async =>
      (await api.files.list(spaces: 'appDataFolder', q: "name='$fileName'", $fields: 'files(id)')).files?.firstOrNull?.id;

  static Future<void> backupNow() async {
    final pw = Session.password;
    if (pw == null) throw Exception('Desbloqueie o diário primeiro');
    final data = await Backup.export(store!, pw);
    final api = await _api();
    final media = drive.Media(Stream.value(data), data.length);
    final id = await _fileId(api);
    if (id == null) {
      await api.files.create(drive.File(name: fileName, parents: ['appDataFolder']), uploadMedia: media);
    } else {
      await api.files.update(drive.File(), id, uploadMedia: media);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('last_backup', DateTime.now().millisecondsSinceEpoch);
    await sp.setBool('backup_pending', false);
    changes.value++;
  }

  static Future<int> restore(String pw) async {
    final api = await _api();
    final id = await _fileId(api);
    if (id == null) throw Exception('Nenhum backup encontrado no Drive');
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final c in media.stream) { bytes.addAll(c); }
    final n = await Backup.import(store!, bytes, pw);
    changes.value++;
    return n;
  }

  static Future<bool> autoEnabled() async => (await SharedPreferences.getInstance()).getBool('auto_backup') ?? false;
  static Future<void> setAuto(bool v) async { await (await SharedPreferences.getInstance()).setBool('auto_backup', v); changes.value++; }
  static Future<DateTime?> lastBackup() async {
    final v = (await SharedPreferences.getInstance()).getInt('last_backup');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  /// Chamado após salvar uma página: agenda backup em 8 s.
  static void schedule() {
    SharedPreferences.getInstance().then((sp) => sp.setBool('backup_pending', true));
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), auto);
  }

  /// Backup automático silencioso; se falhar, fica pendente para a próxima vez.
  static Future<void> auto() async {
    _debounce?.cancel();
    try {
      if (!await autoEnabled() || account == null || Session.password == null || store == null) return;
      if (!((await SharedPreferences.getInstance()).getBool('backup_pending') ?? false)) return;
      await backupNow();
    } catch (_) {}
  }
}
