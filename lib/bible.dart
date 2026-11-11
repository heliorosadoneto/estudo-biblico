import 'dart:convert';
import 'dart:io' show gzip;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bibleCredit = 'Todas as Escrituras em português citadas são da Bíblia Livre (BLIVRE), '
    'Copyright © Diego Santos, Mario Sérgio, e Marco Teles, http://sites.google.com/site/biblialivre/ - fevereiro de 2018. '
    'Licença Creative Commons Atribuição 3.0 Brasil (http://creativecommons.org/licenses/by/3.0/br/). '
    'Reprodução permitida desde que devidamente mencionados fonte e autores.';

const bookNames = [
  'Gênesis', 'Êxodo', 'Levítico', 'Números', 'Deuteronômio', 'Josué', 'Juízes', 'Rute', '1 Samuel', '2 Samuel', '1 Reis', '2 Reis',
  '1 Crônicas', '2 Crônicas', 'Esdras', 'Neemias', 'Ester', 'Jó', 'Salmos', 'Provérbios', 'Eclesiastes', 'Cânticos', 'Isaías', 'Jeremias',
  'Lamentações', 'Ezequiel', 'Daniel', 'Oseias', 'Joel', 'Amós', 'Obadias', 'Jonas', 'Miqueias', 'Naum', 'Habacuque', 'Sofonias', 'Ageu',
  'Zacarias', 'Malaquias', 'Mateus', 'Marcos', 'Lucas', 'João', 'Atos', 'Romanos', '1 Coríntios', '2 Coríntios', 'Gálatas', 'Efésios',
  'Filipenses', 'Colossenses', '1 Tessalonicenses', '2 Tessalonicenses', '1 Timóteo', '2 Timóteo', 'Tito', 'Filemom', 'Hebreus', 'Tiago',
  '1 Pedro', '2 Pedro', '1 João', '2 João', '3 João', 'Judas', 'Apocalipse',
];

class VerseRef {
  final int book, chapter, verse;
  const VerseRef(this.book, this.chapter, this.verse);
  String get key => '$book:$chapter:$verse';
  static VerseRef parse(String k) { final p = k.split(':').map(int.parse).toList(); return VerseRef(p[0], p[1], p[2]); }
  String get label => '${bookNames[book]} $chapter:$verse';
}

class Bible {
  /// chapters[book][chapter-1][verse-1]
  final List<List<List<String>>> chapters;
  Bible._(this.chapters);

  static Bible? instance;
  static Future<Bible> load() async =>
      instance ??= parse((await rootBundle.load('assets/biblia_livre.tsv.gz')).buffer.asUint8List());

  static Bible parse(List<int> gz) {
    final books = List.generate(66, (_) => <List<String>>[]);
    for (final line in const LineSplitter().convert(utf8.decode(gzip.decode(gz)))) {
      final p = line.split('\t');
      final b = int.parse(p[0]), c = int.parse(p[1]), v = int.parse(p[2]);
      while (books[b].length < c) { books[b].add([]); }
      final ch = books[b][c - 1];
      while (ch.length < v) { ch.add(''); }
      ch[v - 1] = p[3];
    }
    return Bible._(books);
  }

  String text(VerseRef r) => chapters[r.book][r.chapter - 1][r.verse - 1];

  static String _norm(String s) {
    const a = 'áàâãäéèêëíìîïóòôõöúùûüç', b = 'aaaaaeeeeiiiiooooouuuuc';
    final l = s.toLowerCase();
    final sb = StringBuffer();
    for (final ch in l.split('')) { final i = a.indexOf(ch); sb.write(i < 0 ? ch : b[i]); }
    return sb.toString();
  }

  List<VerseRef> search(String q, {int limit = 300}) {
    final n = _norm(q.trim());
    final out = <VerseRef>[];
    if (n.length < 3) return out;
    final re = RegExp('(^|[^a-z0-9])${RegExp.escape(n)}(\$|[^a-z0-9])');
    for (var b = 0; b < 66; b++) {
      for (var c = 0; c < chapters[b].length; c++) {
        final ch = chapters[b][c];
        for (var v = 0; v < ch.length; v++) {
          if (re.hasMatch(_norm(ch[v]))) { out.add(VerseRef(b, c + 1, v + 1)); if (out.length >= limit) return out; }
        }
      }
    }
    return out;
  }

  static const _daily = [
    VerseRef(42, 3, 16), VerseRef(18, 23, 1), VerseRef(44, 8, 28), VerseRef(49, 4, 13), VerseRef(23, 29, 11), VerseRef(19, 3, 5),
    VerseRef(22, 41, 10), VerseRef(39, 11, 28), VerseRef(18, 46, 1), VerseRef(5, 1, 9), VerseRef(45, 13, 4), VerseRef(18, 119, 105),
    VerseRef(39, 6, 33), VerseRef(42, 14, 6), VerseRef(49, 4, 6), VerseRef(18, 37, 4), VerseRef(24, 3, 22), VerseRef(57, 11, 1),
    VerseRef(18, 91, 1), VerseRef(44, 12, 12), VerseRef(61, 4, 8), VerseRef(22, 40, 31), VerseRef(42, 16, 33), VerseRef(18, 27, 1),
  ];
  VerseRef verseOfDay(DateTime d) => _daily[d.difference(DateTime(d.year)).inDays % _daily.length];
}

class Favorites {
  static Future<List<VerseRef>> all() async =>
      ((await SharedPreferences.getInstance()).getStringList('fav') ?? []).map(VerseRef.parse).toList();
  /// Favorita todos (ou remove todos, se já eram favoritos). Retorna true se adicionou.
  static Future<bool> setAll(Iterable<VerseRef> refs, bool on) async {
    final sp = await SharedPreferences.getInstance();
    final l = sp.getStringList('fav') ?? [];
    for (final r in refs) { l.remove(r.key); if (on) l.insert(0, r.key); }
    await sp.setStringList('fav', l);
    return on;
  }
  static Future<bool> toggle(VerseRef r) async {
    final sp = await SharedPreferences.getInstance();
    final l = sp.getStringList('fav') ?? [];
    final had = l.remove(r.key);
    if (!had) l.insert(0, r.key);
    await sp.setStringList('fav', l);
    return !had;
  }
  static Future<double> fontSize() async => (await SharedPreferences.getInstance()).getDouble('bible_font') ?? 18;
  static Future<void> setFontSize(double v) async => (await SharedPreferences.getInstance()).setDouble('bible_font', v);
}

/// Marca-texto por versículo: guarda o índice da cor em [HighlightColor.all].
class Highlights {
  static const _key = 'hl';
  static Future<Map<String, int>> all() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return {};
    final m = jsonDecode(raw);
    return m is Map ? {for (final e in m.entries) e.key as String: (e.value as num).toInt()} : {};
  }
  /// [color] null remove o grifo.
  static Future<Map<String, int>> set(Iterable<VerseRef> refs, int? color) async {
    final m = await all();
    for (final r in refs) { color == null ? m.remove(r.key) : m[r.key] = color; }
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(m));
    return m;
  }
}

/// Referência bíblica: "João 3:16", "Jo 3:16-18", "Sl 23", "1 Co 13:4".
class RefQuery {
  final int book, chapter;
  final int? from, to;
  const RefQuery(this.book, this.chapter, [this.from, this.to]);
}

const _abbr = {
  'gn': 0, 'ex': 1, 'lv': 2, 'nm': 3, 'dt': 4, 'js': 5, 'jz': 6, 'rt': 7, '1sm': 8, '2sm': 9, '1rs': 10, '2rs': 11, '1cr': 12, '2cr': 13,
  'ed': 14, 'ne': 15, 'et': 16, 'jo': 42, 'jó': 17, 'sl': 18, 'pv': 19, 'ec': 20, 'ct': 21, 'is': 22, 'jr': 23, 'lm': 24, 'ez': 25, 'dn': 26,
  'os': 27, 'jl': 28, 'am': 29, 'ob': 30, 'jn': 31, 'mq': 32, 'na': 33, 'hc': 34, 'sf': 35, 'ag': 36, 'zc': 37, 'ml': 38, 'mt': 39, 'mc': 40,
  'lc': 41, 'jao': 42, 'at': 43, 'rm': 44, '1co': 45, '2co': 46, 'gl': 47, 'ef': 48, 'fp': 49, 'cl': 50, '1ts': 51, '2ts': 52, '1tm': 53,
  '2tm': 54, 'tt': 55, 'fm': 56, 'hb': 57, 'tg': 58, '1pe': 59, '2pe': 60, '1jo': 61, '2jo': 62, '3jo': 63, 'jd': 64, 'ap': 65,
};

String normRef(String s) {
  const a = 'áàâãäéèêëíìîïóòôõöúùûüç', b = 'aaaaaeeeeiiiiooooouuuuc';
  final sb = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (ch == ' ' || ch == '.') continue;
    final i = a.indexOf(ch);
    sb.write(i < 0 ? ch : b[i]);
  }
  return sb.toString();
}

int? findBook(String raw) {
  final lower = raw.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
  if (_abbr.containsKey(lower)) return _abbr[lower];
  final n = normRef(raw);
  if (n.isEmpty) return null;
  if (_abbr.containsKey(n)) return _abbr[n];
  for (var i = 0; i < 66; i++) { if (normRef(bookNames[i]) == n) return i; }
  for (var i = 0; i < 66; i++) { if (normRef(bookNames[i]).startsWith(n)) return i; }
  return null;
}

RefQuery? parseRef(String q, Bible b) {
  final m = RegExp(r'^\s*(\d?\s*[^\d:]+?)\s*(\d+)(?:\s*[:.,]\s*(\d+)(?:\s*-\s*(\d+))?)?\s*$').firstMatch(q);
  if (m == null) return null;
  final book = findBook(m[1]!);
  if (book == null) return null;
  final c = int.parse(m[2]!);
  if (c < 1 || c > b.chapters[book].length) return null;
  final n = b.chapters[book][c - 1].length;
  final f = m[3] == null ? null : int.parse(m[3]!).clamp(1, n);
  final t = m[4] == null ? f : int.parse(m[4]!).clamp(f!, n);
  return RefQuery(book, c, f, t);
}

/// Formata versículos selecionados como citação: “texto” — João 3:16-17
String formatQuote(Bible b, List<VerseRef> refs) {
  final sorted = [...refs]..sort((x, y) => x.book != y.book ? x.book - y.book : x.chapter != y.chapter ? x.chapter - y.chapter : x.verse - y.verse);
  final out = <String>[];
  var i = 0;
  while (i < sorted.length) {
    final start = sorted[i];
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1].book == start.book && sorted[j + 1].chapter == start.chapter && sorted[j + 1].verse == sorted[j].verse + 1) { j++; }
    final text = [for (var k = i; k <= j; k++) b.text(sorted[k])].join(' ');
    final ref = '${bookNames[start.book]} ${start.chapter}:${start.verse}${j > i ? '-${sorted[j].verse}' : ''}';
    out.add('“$text” — $ref');
    i = j + 1;
  }
  return out.join('\n');
}

bool isQuoteLine(String l) => l.startsWith('“') && l.contains('” — ');
