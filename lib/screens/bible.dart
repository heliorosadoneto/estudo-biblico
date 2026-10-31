import 'package:flutter/material.dart';
import '../bible.dart';
import '../theme.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});
  @override
  State<BibleScreen> createState() => _BibleState();
}

class _BibleState extends State<BibleScreen> {
  bool _nt = false;
  Bible? _bible;
  @override
  void initState() { super.initState(); Bible.load().then((b) { if (mounted) setState(() => _bible = b); }); }

  @override
  Widget build(BuildContext context) {
    final b = _bible;
    final range = _nt ? List.generate(27, (i) => i + 39) : List.generate(39, (i) => i);
    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const Text('Bíblia Sagrada'), actions: [
        IconButton(icon: const Icon(Icons.search), tooltip: 'Buscar',
            onPressed: b == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BibleSearchScreen(bible: b)))),
        IconButton(icon: const Icon(Icons.favorite_border), tooltip: 'Favoritos',
            onPressed: b == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(bible: b)))),
        const SizedBox(width: 8),
      ]),
      body: b == null
          ? const Center(child: CircularProgressIndicator(color: Ui.red))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(selectedBackgroundColor: Ui.red, selectedForegroundColor: Colors.white,
                      foregroundColor: Ui.muted, side: const BorderSide(color: Ui.border), textStyle: const TextStyle(fontFamily: Ui.font, fontWeight: FontWeight.w700)),
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: false, label: Text('Antigo Testamento')), ButtonSegment(value: true, label: Text('Novo Testamento'))],
                  selected: {_nt}, onSelectionChanged: (s) => setState(() => _nt = s.first),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: range.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final book = range[i];
                    return Material(color: Colors.transparent, child: InkWell(
                      borderRadius: BorderRadius.circular(Ui.radius),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChaptersScreen(bible: b, book: book))),
                      child: Ink(
                        decoration: Ui.card(), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Text(bookNames[book], style: Ui.h2.copyWith(fontSize: 16)),
                          const Spacer(),
                          Text('${b.chapters[book].length} cap.', style: Ui.small),
                          const Icon(Icons.chevron_right, color: Ui.muted),
                        ]),
                      ),
                    ));
                  },
                ),
              ),
            ]),
    );
  }
}

class ChaptersScreen extends StatelessWidget {
  final Bible bible;
  final int book;
  const ChaptersScreen({super.key, required this.bible, required this.book});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(bookNames[book])),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: bible.chapters[book].length,
          itemBuilder: (_, i) => Material(color: Colors.transparent, child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bible: bible, book: book, chapter: i + 1))),
            child: Ink(decoration: Ui.card().copyWith(borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('${i + 1}', style: Ui.h2))),
          )),
        ),
      );
}

class ReaderScreen extends StatefulWidget {
  final Bible bible;
  final int book, chapter;
  final int? highlight;
  const ReaderScreen({super.key, required this.bible, required this.book, required this.chapter, this.highlight});
  @override
  State<ReaderScreen> createState() => _ReaderState();
}

class _ReaderState extends State<ReaderScreen> {
  late int _ch = widget.chapter;
  double _size = 18;
  Set<String> _favs = {};

  @override
  void initState() {
    super.initState();
    Favorites.fontSize().then((v) => setState(() => _size = v));
    Favorites.all().then((l) => setState(() => _favs = l.map((r) => r.key).toSet()));
  }

  void _font(double d) { setState(() => _size = (_size + d).clamp(14, 32)); Favorites.setFontSize(_size); }

  Future<void> _fav(VerseRef r) async {
    final added = await Favorites.toggle(r);
    setState(() => added ? _favs.add(r.key) : _favs.remove(r.key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Ui.surface2,
          content: Text(added ? '${r.label} salvo nos favoritos' : '${r.label} removido dos favoritos', style: Ui.small.copyWith(color: Colors.white))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final verses = widget.bible.chapters[widget.book][_ch - 1];
    final total = widget.bible.chapters[widget.book].length;
    return Scaffold(
      appBar: AppBar(title: Text('${bookNames[widget.book]} $_ch'), actions: [
        IconButton(icon: const Icon(Icons.text_decrease), tooltip: 'Diminuir letra', onPressed: () => _font(-2)),
        IconButton(icon: const Icon(Icons.text_increase), tooltip: 'Aumentar letra', onPressed: () => _font(2)),
        const SizedBox(width: 4),
      ]),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: verses.length + 1,
        itemBuilder: (_, i) {
          if (i == verses.length) {
            return Padding(padding: const EdgeInsets.only(top: 24), child: Row(children: [
              if (_ch > 1) TextButton.icon(onPressed: () => setState(() => _ch--), icon: const Icon(Icons.chevron_left), label: Text('Capítulo ${_ch - 1}')),
              const Spacer(),
              if (_ch < total) TextButton.icon(onPressed: () => setState(() => _ch++), icon: const Icon(Icons.chevron_right), label: Text('Capítulo ${_ch + 1}')),
            ]));
          }
          final r = VerseRef(widget.book, _ch, i + 1);
          final fav = _favs.contains(r.key);
          final hl = widget.highlight == i + 1 && _ch == widget.chapter;
          return InkWell(
            onTap: () => _fav(r),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(color: hl ? Ui.red.withValues(alpha: .12) : null, borderRadius: BorderRadius.circular(10)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${i + 1}  ', style: Ui.date.copyWith(fontSize: _size * .7)),
                TextSpan(text: verses[i], style: Ui.body.copyWith(fontSize: _size,
                    decoration: fav ? TextDecoration.underline : null, decorationColor: Ui.red, decorationThickness: 2)),
                if (fav) TextSpan(text: '  ♥', style: TextStyle(color: Ui.red, fontSize: _size * .8)),
              ])),
            ),
          );
        },
      ),
    );
  }
}

Widget verseTile(BuildContext context, Bible b, VerseRef r, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(Ui.radius),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bible: b, book: r.book, chapter: r.chapter, highlight: r.verse))),
        child: Ink(
          decoration: Ui.card(), padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.label.toUpperCase(), style: Ui.date),
              const SizedBox(height: 6),
              Text(b.text(r), style: Ui.body.copyWith(fontSize: 15, height: 1.5)),
            ])),
            ?trailing,
          ]),
        ),
      )),
    );

class BibleSearchScreen extends StatefulWidget {
  final Bible bible;
  final String initial;
  const BibleSearchScreen({super.key, required this.bible, this.initial = ''});
  @override
  State<BibleSearchScreen> createState() => _SearchState();
}

class _SearchState extends State<BibleSearchScreen> {
  late final _c = TextEditingController(text: widget.initial);
  late List<VerseRef> _res = widget.bible.search(widget.initial);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Buscar na Bíblia')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(controller: _c, style: Ui.body, textInputAction: TextInputAction.search,
                decoration: const InputDecoration(hintText: 'Palavra ou frase (mín. 3 letras)', prefixIcon: Icon(Icons.search, color: Ui.muted)),
                onSubmitted: (q) => setState(() => _res = widget.bible.search(q))),
          ),
          if (_c.text.length >= 3)
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(alignment: Alignment.centerLeft, child: Text('${_res.length}${_res.length >= 300 ? '+' : ''} versículos', style: Ui.small))),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [for (final r in _res) verseTile(context, widget.bible, r)])),
        ]),
      );
}

class FavoritesScreen extends StatefulWidget {
  final Bible bible;
  const FavoritesScreen({super.key, required this.bible});
  @override
  State<FavoritesScreen> createState() => _FavState();
}

class _FavState extends State<FavoritesScreen> {
  List<VerseRef> _l = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final l = await Favorites.all(); if (mounted) setState(() => _l = l); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Favoritos')),
        body: _l.isEmpty
            ? const Center(child: Text('Nenhum versículo favorito.\nToque num versículo para salvar.', textAlign: TextAlign.center, style: Ui.small))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                for (final r in _l)
                  verseTile(context, widget.bible, r, trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Ui.red), tooltip: 'Remover',
                      onPressed: () async { await Favorites.toggle(r); _load(); })),
              ]),
      );
}
