import 'package:diario/backup.dart';
import 'package:diario/bible.dart';
import 'package:diario/screens/settings.dart';
import 'package:diario/data.dart';
import 'package:diario/screens/bible.dart';
import 'package:diario/screens/verse_picker.dart';
import 'package:diario/main.dart';
import 'package:diario/screens/editor.dart';
import 'package:diario/screens/list.dart';
import 'package:diario/screens/lock.dart';
import 'package:diario/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget w) => MaterialApp(debugShowCheckedModeBanner: false, theme: Ui.theme(),
    locale: const Locale('pt', 'BR'), supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates, home: w);

void main() {
  setUpAll(() async {
    Future<void> load(String fam, List<String> paths) async {
      final l = FontLoader(fam);
      for (final p in paths) { l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync()))); }
      await l.load();
    }
    await load('Manrope', ['assets/fonts/Manrope.ttf']);
    final fl = Platform.environment['HOME']!;
    await load('MaterialIcons', ['$fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
 await initializeDateFormatting('pt_BR'); SharedPreferences.setMockInitialValues({'fav': ['42:3:16', '18:23:1', '19:3:5']});
    Bible.instance = Bible.parse(File('assets/biblia_livre.tsv.gz').readAsBytesSync()); });
  final now = DateTime(2026, 10, 30);
  var id = 0;
  Entry e(String t, String b, DateTime d) => Entry(id: ++id, title: t, body: b, date: d);
  final store = MemoryStore([
    e('Um dia de chuva', 'Hoje choveu a tarde inteira. Fiquei olhando a janela com um café quente e pensando nos planos para o fim do ano.', now),
    e('Primeiro dia no projeto', 'Comecei o projeto novo e estou animado. Muitas ideias para colocar no papel.', DateTime(2026, 10, 29)),
    e('Passeio no parque', 'Caminhada longa no fim de tarde, o céu estava alaranjado e o vento fresco.', DateTime(2026, 10, 26)),
    e('Aniversário da mãe', 'Almoço em família, bolo de cenoura.', DateTime(2026, 9, 14)),
    e('Viagem', 'Estrada cedo rumo à serra.', DateTime(2026, 9, 3)),
    e('Treino', 'Voltei a correr.', DateTime(2026, 8, 20)),
    e('Férias', 'Primeiro dia de férias.', DateTime(2026, 7, 2)),
    for (var m = 1; m <= 12; m++) e('Mês $m', 'Lembranças de 2025.', DateTime(2025, m, 10)),
    for (var m = 3; m <= 11; m += 4) e('Antigo', 'Lembranças de 2024.', DateTime(2024, m, 5)),
  ]);

  Future<void> shot(WidgetTester t, Widget w, String name) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(RepaintBoundary(child: w));
    await t.runAsync(() => precacheImage(AppLogo.asset, t.element(find.byType(MaterialApp).first)));
    await t.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../shots/$name.png'));
  }

  testWidgets('lock', (t) => shot(t, wrap(LockScreen(creating: false, onUnlocked: () {})), 'lock'));
    testWidgets('editor', (t) => shot(t, wrap(EditorScreen(store: store, entry: Entry(title: 'Querido diário',
      body: 'Hoje acordei cedo e o sol entrava pela janela.\nResolvi começar este caderno para guardar meus pensamentos.', date: now))), 'editor'));
  testWidgets('list 2025 aberto', (t) async {
    await shot(t, wrap(ListScreen(store: store, now: now)), 'list');
    await t.tap(find.text('2025'));
    await t.pumpAndSettle();
    await t.tap(find.text('Dezembro'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -500));
    await t.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../shots/list_ano_aberto.png'));
  });
  testWidgets('menu', (t) => shot(t, wrap(HomeShell(store: store, now: now)), 'menu_estudos'));
  testWidgets('livros', (t) => shot(t, wrap(HomeShell(store: store, initial: 1, now: now)), 'biblia_livros'));
  testWidgets('capitulos', (t) => shot(t, wrap(ChaptersScreen(bible: Bible.instance!, book: 18)), 'biblia_capitulos'));
  testWidgets('leitura', (t) => shot(t, wrap(ReaderScreen(bible: Bible.instance!, book: 42, chapter: 3, highlight: 16)), 'biblia_leitura'));
  testWidgets('busca', (t) => shot(t, wrap(BibleSearchScreen(bible: Bible.instance!, initial: 'meu pastor')), 'biblia_busca'));
  testWidgets('favoritos', (t) => shot(t, wrap(FavoritesScreen(bible: Bible.instance!)), 'biblia_favoritos'));
  testWidgets('ajustes', (t) => shot(t, wrap(HomeShell(store: store, initial: 2, now: now)), 'ajustes_sobre'));
  test('referências', () {
    final b = Bible.instance!;
    final r = parseRef('João 3:16-17', b)!;
    expect([r.book, r.chapter, r.from, r.to], [42, 3, 16, 17]);
    expect(parseRef('Sl 23', b)!.book, 18);
    expect(parseRef('1 Co 13:4', b)!.book, 45);
    expect(parseRef('rm 8.28', b)!.from, 28);
    expect(formatQuote(b, [const VerseRef(42, 3, 17), const VerseRef(42, 3, 16)]), endsWith('” — João 3:16-17'));
  });
  testWidgets('seletor', (t) => shot(t, wrap(Scaffold(backgroundColor: Colors.black,
      body: Align(alignment: Alignment.bottomCenter, child: Material(color: Ui.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: VersePicker(bible: Bible.instance!, initial: 'João 3:16-17', preselected: const {'42:3:21'}))))), 'versiculo_seletor'));
  testWidgets('seletor busca', (t) => shot(t, wrap(Scaffold(backgroundColor: Ui.surface,
      body: SafeArea(child: VersePicker(bible: Bible.instance!, initial: 'amor', preselected: const {})))), 'versiculo_busca'));
  testWidgets('editor com versículo', (t) => shot(t, wrap(EditorScreen(store: store, entry: Entry(title: 'Gratidão',
      body: 'Hoje li um trecho que me marcou muito:\n${formatQuote(Bible.instance!, [const VerseRef(42, 3, 16), const VerseRef(42, 3, 17)])}\nVou guardar isso no coração esta semana.', date: now))), 'editor_versiculo'));
  test('backup cifrado ida e volta', () async {
    BackupCrypto.iterations = 1000;
    final src = MemoryStore([Entry(id: 1, title: 'Olá', body: 'Segredo “x” — João 3:16', date: now)]);
    final file = await Backup.export(src, 'minhasenha');
    expect(String.fromCharCodes(file.sublist(0, 4)), 'MDB1');
    expect(utf8.decode(file, allowMalformed: true).contains('Segredo'), isFalse);
    final dst = MemoryStore([]);
    expect(await Backup.import(dst, file, 'minhasenha'), 1);
    expect((await dst.all()).single.body, 'Segredo “x” — João 3:16');
    expect(() => Backup.import(dst, file, 'errada'), throwsA(isA<BadPassword>()));
    expect(() => Backup.import(dst, [1, 2, 3], 'x'), throwsA(isA<BadFile>()));
  });
  testWidgets('backup card', (t) async {
    SharedPreferences.setMockInitialValues({'auto_backup': true, 'last_backup': DateTime(2026, 10, 30, 22, 15).millisecondsSinceEpoch});
    await shot(t, wrap(Scaffold(appBar: AppBar(titleSpacing: 20, title: const Text('Ajustes')),
        body: ListView(padding: const EdgeInsets.all(20), children: [BackupCard(store: store, demoEmail: 'helio@gmail.com')]))), 'ajustes_backup');
  });
  testWidgets('logo', (t) async {
    t.view.physicalSize = const Size(512, 512); t.view.devicePixelRatio = 1;
    await t.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: RepaintBoundary(child: AppLogo(size: 512)))));
    await t.runAsync(() => precacheImage(AppLogo.asset, t.element(find.byType(Center).first)));
    await t.pump();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../shots/logo.png'));
  });
  testWidgets('app builds', (t) async { await t.pumpWidget(DiarioApp(store: store, hasPassword: false)); await t.pump(); });
}
