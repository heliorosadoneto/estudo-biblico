import 'package:flutter/material.dart';
import '../bible.dart';
import '../theme.dart';

/// Abre o seletor e devolve o texto formatado (ou null).
Future<String?> pickVerses(BuildContext context, Bible b, {String initial = '', Set<String> preselected = const {}}) =>
    showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: Ui.surface, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => VersePicker(bible: b, initial: initial, preselected: preselected),
    );

class VersePicker extends StatefulWidget {
  final Bible bible;
  final String initial;
  final Set<String> preselected;
  const VersePicker({super.key, required this.bible, this.initial = '', this.preselected = const {}});
  @override
  State<VersePicker> createState() => _PickerState();
}

class _PickerState extends State<VersePicker> {
  late final _c = TextEditingController(text: widget.initial);
  late final Set<String> _sel = {...widget.preselected};
  int? _browseBook;
  List<VerseRef> _results = [];
  RefQuery? _ref;
  bool _full = false;

  @override
  void initState() { super.initState(); _run(widget.initial); }

  void _run(String q, {bool full = false}) {
    _full = full;
    final b = widget.bible;
    _ref = parseRef(q, b);
    if (_ref != null) {
      final r = _ref!;
      final n = b.chapters[r.book][r.chapter - 1].length;
      _results = [for (var v = (_full ? 1 : (r.from ?? 1)); v <= n; v++) VerseRef(r.book, r.chapter, v)];
      if (r.from != null) { for (var v = r.from!; v <= r.to!; v++) { _sel.add(VerseRef(r.book, r.chapter, v).key); } }
    } else if (q.trim().length >= 3 && findBook(q.trim()) != null && !q.contains(' ', 2)) {
      _browseBook = findBook(q.trim());
      _results = [];
    } else {
      _results = b.search(q, limit: 200);
    }
    setState(() {});
  }

  void _openChapter(int book, int ch) { _c.text = '${bookNames[book]} $ch'; _browseBook = null; _run(_c.text); }

  void _insert() {
    final refs = _sel.map(VerseRef.parse).toList();
    Navigator.pop(context, formatQuote(widget.bible, refs));
  }

  Widget _body() {
    final b = widget.bible;
    final q = _c.text.trim();
    if (_browseBook != null && _ref == null) {
      final book = _browseBook!;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: b.chapters[book].length,
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(12), onTap: () => _openChapter(book, i + 1),
          child: Ink(decoration: BoxDecoration(color: Ui.surface2, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('${i + 1}', style: Ui.h2.copyWith(fontSize: 15)))),
        ),
      );
    }
    if (q.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Escolha um livro, ou digite uma palavra ou referência (ex.: João 3:16, Sl 23, Rm 8:28-30)', style: Ui.small)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 66; i++)
            ActionChip(
              label: Text(bookNames[i], style: const TextStyle(fontFamily: Ui.font, fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: Ui.surface2, side: const BorderSide(color: Ui.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => setState(() { _browseBook = i; _c.text = bookNames[i]; }),
            ),
        ]),
      ]);
    }
    if (_results.isEmpty) return const Center(child: Text('Nada encontrado.', style: Ui.small));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final r = _results[i];
        final on = _sel.contains(r.key);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => on ? _sel.remove(r.key) : _sel.add(r.key)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(color: on ? Ui.red.withValues(alpha: .10) : null, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: on, onChanged: (_) => setState(() => on ? _sel.remove(r.key) : _sel.add(r.key)),
                  activeColor: Ui.red, side: const BorderSide(color: Ui.muted, width: 1.5)),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: _ref != null ? '${r.verse}  ' : '${r.label}  ', style: Ui.date),
                  TextSpan(text: b.text(r), style: Ui.body.copyWith(fontSize: 15, height: 1.45)),
                ])),
              )),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * .88,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Ui.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(children: [
              const Icon(Icons.menu_book, color: Ui.red), const SizedBox(width: 10),
              const Text('Inserir versículo', style: Ui.h2),
              const Spacer(),
              if (_browseBook != null || _c.text.isNotEmpty)
                TextButton(onPressed: () { _c.clear(); _browseBook = null; _run(''); }, child: const Text('Livros')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _c, style: Ui.body, textInputAction: TextInputAction.search,
              decoration: InputDecoration(hintText: 'Palavra ou referência', prefixIcon: const Icon(Icons.search, color: Ui.muted),
                  fillColor: Ui.bg, suffixIcon: _c.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close, color: Ui.muted), onPressed: () { _c.clear(); _browseBook = null; _run(''); })),
              onSubmitted: (q) { _browseBook = null; _run(q); },
            ),
          ),
          if (_ref != null || (_results.isNotEmpty && _c.text.isNotEmpty))
            Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: Align(alignment: Alignment.centerLeft,
                child: Row(children: [
                  Text(_ref != null ? '${bookNames[_ref!.book]} ${_ref!.chapter}' : '${_results.length}${_results.length >= 200 ? '+' : ''} versículos', style: Ui.small.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_ref != null && _ref!.from != null && _ref!.from! > 1 && !_full)
                    GestureDetector(onTap: () => _run(_c.text, full: true), child: Text('Ver capítulo inteiro', style: Ui.date)),
                ]))),
          const SizedBox(height: 6),
          Expanded(child: _body()),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ui.border))),
            child: Row(children: [
              Text(_sel.isEmpty ? 'Nenhum selecionado' : '${_sel.length} selecionado${_sel.length > 1 ? 's' : ''}', style: Ui.small),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
                onPressed: _sel.isEmpty ? null : _insert, icon: const Icon(Icons.format_quote), label: const Text('Inserir')),
            ]),
          ),
        ]),
      );
}
