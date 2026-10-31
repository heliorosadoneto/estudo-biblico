import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../backup.dart';
import '../bible.dart';
import '../data.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  final EntryStore store;
  const SettingsScreen({super.key, required this.store});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  final _old = TextEditingController(), _new = TextEditingController(), _conf = TextEditingController();
  String? _msg;

  Future<void> _change() async {
    if (!await Auth.check(_old.text)) return setState(() => _msg = 'Senha atual incorreta');
    if (_new.text.length < 4) return setState(() => _msg = 'A nova senha precisa de ao menos 4 caracteres');
    if (_new.text != _conf.text) return setState(() => _msg = 'As senhas não conferem');
    await Auth.setPassword(_new.text);
    Session.password = _new.text;
    _old.clear(); _new.clear(); _conf.clear();
    setState(() => _msg = 'Senha alterada com sucesso');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(titleSpacing: 20, title: const Text('Ajustes')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            decoration: Ui.card(), padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Trocar senha', style: Ui.h2),
              const SizedBox(height: 16),
              for (final (c, l) in [(_old, 'Senha atual'), (_new, 'Nova senha'), (_conf, 'Confirmar nova senha')])
                Padding(padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(controller: c, obscureText: true, style: Ui.body, decoration: InputDecoration(hintText: l))),
              const SizedBox(height: 8),
              FilledButton(onPressed: _change, child: const Text('Salvar nova senha')),
              if (_msg != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_msg!, style: Ui.small)),
            ]),
          ),
          const SizedBox(height: 16),
          BackupCard(store: widget.store),
          const SizedBox(height: 16),
          Container(
            decoration: Ui.card(), padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [AppLogo(size: 36), SizedBox(width: 12), Text('Sobre', style: Ui.h2)]),
              const SizedBox(height: 12),
              const Text('Estudo Bíblico · versão 1.1', style: Ui.small),
              const SizedBox(height: 12),
              Text('TEXTO BÍBLICO', style: Ui.date.copyWith(fontSize: 11)),
              const SizedBox(height: 6),
              const Text(bibleCredit, style: Ui.small),
            ]),
          ),
        ]),
      );
}

Future<String?> askPassword(BuildContext context, String title, String msg) {
  final c = TextEditingController();
  return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg, style: Ui.small),
          const SizedBox(height: 14),
          TextField(controller: c, obscureText: true, autofocus: true, style: Ui.body, decoration: const InputDecoration(hintText: 'Senha do app')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Ui.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Continuar')),
        ],
      ));
}

Future<bool> confirm(BuildContext context, String title, String msg, String ok) async =>
    await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: Text(title), content: Text(msg, style: Ui.small),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Ui.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
          ],
        )) ?? false;

class BackupCard extends StatefulWidget {
  final EntryStore store;
  final String? demoEmail; // para capturas de tela
  const BackupCard({super.key, required this.store, this.demoEmail});
  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _auto = false, _busy = false;
  DateTime? _last;

  @override
  void initState() { super.initState(); DriveBackup.changes.addListener(_refresh); _refresh(); }
  @override
  void dispose() { DriveBackup.changes.removeListener(_refresh); super.dispose(); }
  Future<void> _refresh() async {
    final a = await DriveBackup.autoEnabled(), l = await DriveBackup.lastBackup();
    if (mounted) setState(() { _auto = a; _last = l; });
  }

  String? get _email => widget.demoEmail ?? DriveBackup.account?.email;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Ui.surface2, content: Text(m, style: Ui.small.copyWith(color: Colors.white))));

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try { await f(); } on BadPassword { _toast('Senha incorreta para este backup'); } on BadFile { _toast('Arquivo de backup inválido'); }
    catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    if (mounted) setState(() => _busy = false);
    _refresh();
  }

  Future<void> _restoreDrive() async {
    if (!await confirm(context, 'Restaurar do Drive?', 'As anotações atuais deste aparelho serão substituídas pelas do backup.', 'Restaurar')) return;
    if (!mounted) return;
    final pw = await askPassword(context, 'Senha do backup', 'Digite a senha do app usada quando o backup foi feito.');
    if (pw == null) return;
    await _run(() async { final n = await DriveBackup.restore(pw); _toast('$n anotações restauradas'); });
  }

  Future<void> _export() => _run(() async {
        final pw = Session.password;
        if (pw == null) throw Exception('Desbloqueie o app primeiro');
        final bytes = await Backup.export(widget.store, pw);
        final name = 'estudo_biblico_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.mdb';
        final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, dialogTitle: 'Salvar cópia dos estudos');
        if (uri != null) _toast('Cópia salva (cifrada com a senha do app)');
      });

  Future<void> _import() async {
    final f = await FilePicker.pickFile(dialogTitle: 'Escolher cópia dos estudos');
    if (f == null || !mounted) return;
    if (!await confirm(context, 'Importar cópia?', 'As anotações atuais deste aparelho serão substituídas pelas da cópia.', 'Importar')) return;
    if (!mounted) return;
    final pw = await askPassword(context, 'Senha da cópia', 'Digite a senha do app usada quando a cópia foi feita.');
    if (pw == null) return;
    await _run(() async { final n = await Backup.import(widget.store, await f.readAsBytes(), pw); DriveBackup.changes.value++; _toast('$n anotações importadas'); });
  }

  Widget _action(IconData i, String t, VoidCallback? on) => ListTile(
      contentPadding: EdgeInsets.zero, dense: true, enabled: on != null && !_busy,
      leading: Icon(i, color: on == null ? Ui.border : Ui.red), title: Text(t, style: Ui.body.copyWith(fontSize: 15, color: on == null ? Ui.muted : Colors.white)),
      onTap: on);

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return Material(
      color: Ui.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.radius), side: const BorderSide(color: Ui.border)),
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, color: Ui.red), const SizedBox(width: 10),
          const Expanded(child: Text('Backup no Google Drive', style: Ui.h2)),
          if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Ui.red)),
        ]),
        const SizedBox(height: 6),
        const Text('Cópia cifrada com a senha do app, numa pasta oculta do seu Drive.', style: Ui.small),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Ui.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Ui.border)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: email == null ? Ui.surface2 : Ui.red,
                child: Text(email == null ? '?' : email[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(email ?? 'Nenhuma conta conectada', style: Ui.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text(_last == null ? 'Nenhum backup ainda' : 'Último backup: ${DateFormat("d 'de' MMM, HH:mm", 'pt_BR').format(_last!)}', style: Ui.small.copyWith(fontSize: 12)),
            ])),
            TextButton(
              onPressed: _busy ? null : () => _run(() async { email == null ? await DriveBackup.connect() : await DriveBackup.disconnect(); }),
              child: Text(email == null ? 'Conectar' : 'Desconectar')),
          ]),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, value: _auto, activeThumbColor: Colors.white, activeTrackColor: Ui.red,
          title: Text('Backup automático', style: Ui.body.copyWith(fontSize: 15)),
          subtitle: const Text('Depois de salvar uma anotação e ao sair do app', style: Ui.small),
          onChanged: email == null ? null : (v) { DriveBackup.setAuto(v); setState(() => _auto = v); },
        ),
        _action(Icons.cloud_upload_outlined, 'Fazer backup agora', email == null ? null : () => _run(() async { await DriveBackup.backupNow(); _toast('Backup concluído'); })),
        _action(Icons.cloud_download_outlined, 'Restaurar do Drive', email == null ? null : _restoreDrive),
        const Divider(height: 16),
        _action(Icons.file_upload_outlined, 'Exportar cópia (arquivo)', _export),
        _action(Icons.file_download_outlined, 'Importar cópia (arquivo)', _import),
      ]),
    ));
  }
}
