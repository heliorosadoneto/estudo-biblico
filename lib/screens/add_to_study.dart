import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backup.dart';
import '../data.dart';
import '../theme.dart';
import 'editor.dart';

/// Insere [quote] num estudo existente ou num novo. Retorna o estudo alterado.
Future<Entry?> addToStudy(BuildContext context, EntryStore store, String quote, {String suggestedTitle = ''}) async {
  final entry = await showModalBottomSheet<Entry>(
    context: context, isScrollControlled: true, backgroundColor: Ui.surface, showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StudyPickerSheet(store: store, quote: quote, suggestedTitle: suggestedTitle),
  );
  if (entry == null || !context.mounted) return entry;
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  messenger.showSnackBar(SnackBar(
    backgroundColor: Ui.surface2,
    content: Text('Trecho adicionado a “${entry.title.isEmpty ? 'Sem título' : entry.title}”', style: Ui.small.copyWith(color: Colors.white)),
    action: SnackBarAction(label: 'Abrir', textColor: Ui.red,
        onPressed: () => nav.push(MaterialPageRoute(builder: (_) => EditorScreen(store: store, entry: entry)))),
  ));
  return entry;
}

/// Junta o trecho ao final do texto do estudo, em linha própria.
String appendQuote(String body, String quote) {
  if (body.trim().isEmpty) return quote;
  return body.endsWith('\n') ? '$body$quote' : '$body\n$quote';
}

class StudyPickerSheet extends StatefulWidget {
  final EntryStore store;
  final String quote, suggestedTitle;
  final bool startCreating;
  const StudyPickerSheet({super.key, required this.store, required this.quote, this.suggestedTitle = '', this.startCreating = false});
  @override
  State<StudyPickerSheet> createState() => _StudyPickerState();
}

class _StudyPickerState extends State<StudyPickerSheet> {
  List<Entry>? _all;
  late bool _creating = widget.startCreating;
  late final _title = TextEditingController(text: widget.suggestedTitle);

  @override
  void initState() {
    super.initState();
    widget.store.all().then((l) { if (mounted) setState(() { _all = l; if (l.isEmpty) _creating = true; }); });
  }

  Future<void> _insert(Entry e) async {
    e.body = appendQuote(e.body, widget.quote);
    await widget.store.save(e);
    DriveBackup.schedule();
    if (mounted) Navigator.pop(context, e);
  }

  Future<void> _create() async {
    final t = _title.text.trim();
    final e = Entry(title: t.isEmpty ? 'Novo estudo' : t, body: widget.quote, date: DateTime.now());
    await widget.store.save(e);
    DriveBackup.schedule();
    if (mounted) Navigator.pop(context, e);
  }

  Widget _preview() => Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Ui.surface2, borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: Ui.red, width: 3))),
        child: Text(widget.quote, maxLines: 4, overflow: TextOverflow.ellipsis,
            style: Ui.body.copyWith(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic, color: const Color(0xFFD8D8DC))),
      );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_creating ? 'Novo estudo' : 'Adicionar ao estudo', style: Ui.h2),
          const SizedBox(height: 12),
          _preview(),
          const SizedBox(height: 16),
          if (all == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Ui.red)))
          else if (_creating) ...[
            if (all.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text('Você ainda não tem estudos. Crie o primeiro com este trecho.', style: Ui.small)),
            TextField(key: const Key('novo_estudo_titulo'), controller: _title, autofocus: !widget.startCreating, style: Ui.body,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título do estudo', prefixIcon: Icon(Icons.edit_note, color: Ui.muted)),
                onSubmitted: (_) => _create()),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Criar estudo com o trecho')),
            if (all.isNotEmpty) Center(child: TextButton(onPressed: () => setState(() => _creating = false), child: const Text('Escolher um estudo existente'))),
          ] else ...[
            Material(color: Colors.transparent, child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _creating = true),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Ui.red.withValues(alpha: .5))),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline, color: Ui.red), const SizedBox(width: 12),
                  Text('Criar novo estudo', style: Ui.h2.copyWith(fontSize: 15)),
                ]),
              ),
            )),
            const SizedBox(height: 14),
            Text('SEUS ESTUDOS', style: Ui.date.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            Flexible(child: ListView.separated(
              shrinkWrap: true, itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = all[i];
                return Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _insert(e),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: Ui.card().copyWith(borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.title.isEmpty ? 'Sem título' : e.title, style: Ui.h2.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(e.date), style: Ui.small.copyWith(fontSize: 12)),
                      ])),
                      const Icon(Icons.playlist_add, color: Ui.muted),
                    ]),
                  ),
                ));
              },
            )),
          ],
        ]),
      ),
    );
  }
}
