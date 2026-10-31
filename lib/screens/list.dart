import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data.dart';
import '../theme.dart';
import 'editor.dart';
import '../bible.dart';
import 'bible.dart';

String _cap(String s) => s[0].toUpperCase() + s.substring(1);
String longDate(DateTime d) => _cap(DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(d));
String monthName(int m) => _cap(DateFormat('MMMM', 'pt_BR').format(DateTime(2000, m)));

class ListScreen extends StatefulWidget {
  final EntryStore store;
  final DateTime? now; // para testes
  const ListScreen({super.key, required this.store, this.now});
  @override
  State<ListScreen> createState() => _ListState();
}

class _ListState extends State<ListScreen> {
  List<Entry> _all = [];
  String _q = '';
  bool _searching = false;
  final Map<String, bool> _open = {};
  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    Bible.load().then((b) { if (mounted) setState(() => _bible = b); });
  }
  Bible? _bible;

  Widget _verseOfDay(Bible b) {
    final r = b.verseOfDay(_now);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bible: b, book: r.book, chapter: r.chapter, highlight: r.verse))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Ui.radius),
            gradient: const LinearGradient(colors: [Color(0xFF2A0A10), Ui.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Ui.red.withValues(alpha: .35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Ui.red, size: 16), const SizedBox(width: 6),
            Text('VERSÍCULO DO DIA', style: Ui.date.copyWith(fontSize: 11, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 8),
          Text(b.text(r), style: Ui.body.copyWith(fontSize: 15, height: 1.5)),
          const SizedBox(height: 6),
          Text(r.label, style: Ui.small.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
  Future<void> _load() async { final l = await widget.store.all(); if (mounted) setState(() => _all = l); }

  Future<void> _edit([Entry? e]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(store: widget.store, entry: e)));
    _load();
  }

  Future<bool> _confirmDelete(Entry e) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Apagar página?'),
          content: Text('“${e.title.isEmpty ? 'Sem título' : e.title}” será apagada para sempre.', style: Ui.small),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Ui.muted))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar')),
          ],
        ));
    if (ok == true) { await widget.store.delete(e.id!); _load(); }
    return ok == true;
  }

  bool _isOpen(String key, bool def) => _open[key] ?? def;
  void _toggle(String key, bool def) => setState(() => _open[key] = !_isOpen(key, def));

  Widget _header(String key, String title, int n, bool def, {bool big = false}) {
    final open = _isOpen(key, def);
    return InkWell(
      borderRadius: BorderRadius.circular(Ui.radius),
      onTap: () => _toggle(key, def),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: big ? 14 : 10),
        child: Row(children: [
          Text(title, style: big ? Ui.h1.copyWith(fontSize: 24) : Ui.h2),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Ui.surface2, borderRadius: BorderRadius.circular(20)),
              child: Text('$n', style: Ui.small.copyWith(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700))),
          const Spacer(),
          AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, color: open ? Ui.red : Ui.muted)),
        ]),
      ),
    );
  }

  Widget _entry(Entry e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(e),
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(color: Ui.redDark, borderRadius: BorderRadius.circular(Ui.radius)),
              child: const Icon(Icons.delete_outline, color: Colors.white)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Ui.radius),
              onTap: () => _edit(e), onLongPress: () => _confirmDelete(e),
              child: Ink(
                decoration: Ui.card(),
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 44, child: Column(children: [
                    Text('${e.date.day}', style: Ui.h1.copyWith(fontSize: 24, height: 1)),
                    Text(DateFormat('EEE', 'pt_BR').format(e.date).replaceAll('.', '').toUpperCase(), style: Ui.date.copyWith(fontSize: 11)),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title.isEmpty ? 'Sem título' : e.title, style: Ui.h2.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(e.body.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ui.small),
                  ])),
                ]),
              ),
            ),
          ),
        ),
      );

  List<Widget> _months(int year, List<Entry> list, {required bool currentYear}) {
    final out = <Widget>[];
    final months = <int, List<Entry>>{};
    for (final e in list) { months.putIfAbsent(e.date.month, () => []).add(e); }
    for (final m in months.keys) {
      final key = '$year-$m', def = currentYear && m == _now.month;
      out.add(_header(key, monthName(m), months[m]!.length, def));
      if (_isOpen(key, def)) out.addAll(months[m]!.map(_entry));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _all.where((e) => _q.isEmpty || '${e.title} ${e.body}'.toLowerCase().contains(_q.toLowerCase())).toList();
    final children = <Widget>[];
    if (_q.isEmpty && _bible != null) children.add(_verseOfDay(_bible!));
    if (_q.isNotEmpty) {
      children.addAll(items.map(_entry));
    } else {
      final years = <int, List<Entry>>{};
      for (final e in items) { years.putIfAbsent(e.date.year, () => []).add(e); }
      for (final y in years.keys) {
        if (y == _now.year) {
          children.addAll(_months(y, years[y]!, currentYear: true));
        } else {
          final key = '$y', open = _isOpen(key, false);
          children.add(Container(
            margin: const EdgeInsets.only(top: 8, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: Ui.card(active: open),
            child: Column(children: [
              _header(key, '$y', years[y]!.length, false, big: true),
              if (open) ..._months(y, years[y]!, currentYear: false),
            ]),
          ));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: _searching
            ? TextField(autofocus: true, style: Ui.body, decoration: const InputDecoration(hintText: 'Procurar…', isDense: true),
                onChanged: (v) => setState(() => _q = v))
            : const Row(children: [AppLogo(size: 30), SizedBox(width: 12), Text('Meu Diário')]),
        actions: [
          IconButton(icon: Icon(_searching ? Icons.close : Icons.search), onPressed: () => setState(() { _searching = !_searching; _q = ''; })),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Nova página', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        ...children,
        if (items.isEmpty) Padding(padding: const EdgeInsets.only(top: 60),
            child: Text(_all.isEmpty ? 'Nenhuma página ainda.\nToque em "Nova página" para começar.' : 'Nada encontrado.', textAlign: TextAlign.center, style: Ui.small)),
      ]),
    );
  }
}
