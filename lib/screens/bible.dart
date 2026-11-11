import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../store_scope.dart';
import 'add_to_study.dart';
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
  Map<String, int> _hl = {};
  final Set<String> _sel = {};

  @override
  void initState() {
    super.initState();
    Favorites.fontSize().then((v) { if (mounted) setState(() => _size = v); });
    Favorites.all().then((l) { if (mounted) setState(() => _favs = l.map((r) => r.key).toSet()); });
    Highlights.all().then((m) { if (mounted) setState(() => _hl = m); });
  }

  void _font(double d) { setState(() => _size = (_size + d).clamp(14, 32)); Favorites.setFontSize(_size); }

  List<VerseRef> get _refs => (_sel.map(VerseRef.parse).toList()..sort((a, b) => a.verse - b.verse));

  void _toast(String msg) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(backgroundColor: Ui.surface2,
        content: Text(msg, style: Ui.small.copyWith(color: Colors.white))));
  }

  String get _selLabel {
    final r = _refs;
    if (r.isEmpty) return '';
    final contiguous = r.last.verse - r.first.verse == r.length - 1;
    final v = r.length == 1 ? '${r.first.verse}' : contiguous ? '${r.first.verse}-${r.last.verse}' : r.map((e) => e.verse).join(', ');
    return '${bookNames[widget.book]} $_ch:$v';
  }

  void _tap(VerseRef r) => setState(() => _sel.contains(r.key) ? _sel.remove(r.key) : _sel.add(r.key));

  Future<void> _fav() async {
    final refs = _refs, label = _selLabel;
    final on = !refs.every((r) => _favs.contains(r.key));
    await Favorites.setAll(refs, on);
    setState(() { on ? _favs.addAll(refs.map((r) => r.key)) : _favs.removeAll(refs.map((r) => r.key)); _sel.clear(); });
    if (mounted) _toast(on ? '$label salvo nos favoritos' : '$label removido dos favoritos');
  }

  Future<void> _paint(int? color) async {
    final m = await Highlights.set(_refs, color);
    setState(() { _hl = m; _sel.clear(); });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: formatQuote(widget.bible, _refs)));
    setState(() => _sel.clear());
    if (mounted) _toast('Trecho copiado');
  }

  Future<void> _study() async {
    final store = StoreScope.of(context);
    if (store == null) return;
    final quote = formatQuote(widget.bible, _refs), title = 'Estudo de $_selLabel';
    final e = await addToStudy(context, store, quote, suggestedTitle: title);
    if (e != null && mounted) setState(() => _sel.clear());
  }

  Widget _actions() {
    final refs = _refs;
    final allFav = refs.every((r) => _favs.contains(r.key));
    final current = refs.map((r) => _hl[r.key]).toSet();
    final active = current.length == 1 ? current.first : null;
    Widget action(IconData i, String label, VoidCallback? on, {Color? color, Key? key}) => Expanded(child: InkWell(
          key: key, onTap: on, borderRadius: BorderRadius.circular(12),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, color: on == null ? Ui.border : color ?? Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: Ui.small.copyWith(fontSize: 12, color: on == null ? Ui.muted : Colors.white)),
          ])),
        ));
    return Container(
      key: const Key('verse_actions'),
      decoration: const BoxDecoration(color: Ui.surface, border: Border(top: BorderSide(color: Ui.border)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(_selLabel.toUpperCase(), style: Ui.date, overflow: TextOverflow.ellipsis)),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, color: Ui.muted), tooltip: 'Limpar seleção',
              onPressed: () => setState(_sel.clear)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text('Grifar', style: Ui.small.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          for (var c = 0; c < HighlightColor.all.length; c++) Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(message: HighlightColor.all[c].name, child: InkResponse(
              key: Key('hl_$c'), onTap: () => _paint(c), radius: 24,
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: HighlightColor.all[c].color, shape: BoxShape.circle,
                  border: Border.all(color: active == c ? Colors.white : Colors.transparent, width: 3)),
                  child: active == c ? const Icon(Icons.check, size: 18, color: Color(0xFF1A1A1A)) : null),
            )),
          ),
          const Spacer(),
          Tooltip(message: 'Remover grifo', child: InkResponse(
            key: const Key('hl_clear'), onTap: current.any((c) => c != null) ? () => _paint(null) : null, radius: 24,
            child: Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Ui.border, width: 1.5)),
                child: Icon(Icons.format_color_reset, size: 18, color: current.any((c) => c != null) ? Colors.white : Ui.border)),
          )),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 4),
        Row(children: [
          action(allFav ? Icons.favorite : Icons.favorite_border, allFav ? 'Desfavoritar' : 'Favoritar', _fav, color: Ui.red, key: const Key('act_fav')),
          action(Icons.playlist_add, 'Adicionar\nao estudo', StoreScope.of(context) == null ? null : _study, key: const Key('act_study')),
          action(Icons.copy_rounded, 'Copiar', _copy, key: const Key('act_copy')),
        ]),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verses = widget.bible.chapters[widget.book][_ch - 1];
    final total = widget.bible.chapters[widget.book].length;
    final selecting = _sel.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(_sel.clear); },
      child: Scaffold(
        appBar: AppBar(title: Text('${bookNames[widget.book]} $_ch'), actions: [
          IconButton(icon: const Icon(Icons.text_decrease), tooltip: 'Diminuir letra', onPressed: () => _font(-2)),
          IconButton(icon: const Icon(Icons.text_increase), tooltip: 'Aumentar letra', onPressed: () => _font(2)),
          const SizedBox(width: 4),
        ]),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: c),
          child: selecting ? _actions() : const SizedBox.shrink(),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: verses.length + 1,
          itemBuilder: (_, i) {
            if (i == verses.length) {
              return Padding(padding: const EdgeInsets.only(top: 24), child: Row(children: [
                if (_ch > 1) TextButton.icon(onPressed: () => setState(() { _ch--; _sel.clear(); }), icon: const Icon(Icons.chevron_left), label: Text('Capítulo ${_ch - 1}')),
                const Spacer(),
                if (_ch < total) TextButton.icon(onPressed: () => setState(() { _ch++; _sel.clear(); }), icon: const Icon(Icons.chevron_right), label: Text('Capítulo ${_ch + 1}')),
              ]));
            }
            final r = VerseRef(widget.book, _ch, i + 1);
            final fav = _favs.contains(r.key);
            final sel = _sel.contains(r.key);
            final hlColor = _hl[r.key] == null ? null : HighlightColor.all[_hl[r.key]!.clamp(0, HighlightColor.all.length - 1)].color;
            final target = widget.highlight == i + 1 && _ch == widget.chapter;
            return InkWell(
              key: Key('verse_${i + 1}'),
              onTap: () => _tap(r),
              onLongPress: () => _tap(r),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration: BoxDecoration(
                  color: sel ? Ui.surface2 : target ? Ui.red.withValues(alpha: .12) : null,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.white.withValues(alpha: .35) : Colors.transparent, width: 1.2),
                ),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${i + 1}  ', style: Ui.date.copyWith(fontSize: _size * .7)),
                  TextSpan(text: verses[i], style: Ui.body.copyWith(fontSize: _size,
                      color: hlColor != null ? const Color(0xFF17130E) : null,
                      backgroundColor: hlColor?.withValues(alpha: .88),
                      decoration: sel ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted, decorationColor: hlColor != null ? const Color(0xFF17130E) : Colors.white70, decorationThickness: 2)),
                  if (fav) WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.favorite, color: Ui.red, size: _size * .85))),
                ])),
              ),
            );
          },
        ),
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
