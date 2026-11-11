// Telas reais das novas funções (logo, grifo, favorito, inserir no estudo).
// Gerar: flutter test test/feature_shots_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';
import 'package:diario/backup.dart';
import 'package:diario/bible.dart';
import 'package:diario/data.dart';
import 'package:diario/main.dart';
import 'package:diario/screens/bible.dart';
import 'package:diario/screens/editor.dart';
import 'package:diario/screens/lock.dart';
import 'package:diario/store_scope.dart';
import 'package:diario/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(EntryStore store, Widget w) => StoreScope(store: store, child: MaterialApp(debugShowCheckedModeBanner: false, theme: Ui.theme(),
    locale: const Locale('pt', 'BR'), supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates, home: w));

const dir = '../docs/screenshots';

void main() {
  setUpAll(() async {
    Future<void> load(String fam, List<String> paths) async {
      final l = FontLoader(fam);
      for (final p in paths) { l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync()))); }
      await l.load();
    }
    await load('Manrope', ['assets/fonts/Manrope.ttf']);
    await load('MaterialIcons', ['${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await initializeDateFormatting('pt_BR');
    Bible.instance = Bible.parse(File('assets/biblia_livre.tsv.gz').readAsBytesSync());
  });

  final now = DateTime(2026, 11, 11);
  MemoryStore studies() => MemoryStore([
        Entry(id: 1, title: 'O Bom Pastor', body: 'Jesus se apresenta como o bom pastor que dá a vida pelas ovelhas.', date: now),
        Entry(id: 2, title: 'Confiança em tempos difíceis', body: 'Anotações do culto de domingo.', date: DateTime(2026, 11, 8)),
        Entry(id: 3, title: 'Salmos de Davi', body: 'Leitura semanal dos Salmos.', date: DateTime(2026, 10, 30)),
        Entry(id: 4, title: 'Fé e esperança', body: 'Hebreus 11.', date: DateTime(2026, 10, 21)),
      ]);

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }
  Future<void> precacheLogo(WidgetTester t) => t.runAsync(() async {
        final ctx = t.element(find.byType(MaterialApp).first);
        await precacheImage(AppLogo.asset, ctx);
      });
  Future<void> snap(String name) => expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('$dir/$name.png'));
  Future<void> flushBackupTimer(WidgetTester t) => t.pump(const Duration(seconds: 9));

  testWidgets('logo: ícone estilo launcher', (t) async {
    t.view.physicalSize = const Size(1080, 1080); t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final fg = MemoryImage(File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png').readAsBytesSync());
    Widget app(Widget icon, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
          icon, const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]);
    await t.pumpWidget(RepaintBoundary(child: MaterialApp(debugShowCheckedModeBanner: false, home: Material(child: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2B3A55), Color(0xFF14161F)])),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Ícone do app (prévia)', style: TextStyle(fontFamily: 'Manrope', color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          app(ClipOval(child: SizedBox(width: 84, height: 84, child: Transform.scale(scale: 1.5, child: Image(image: fg, fit: BoxFit.cover)))), 'Estudo Bíblico'),
          app(const AppLogo(size: 84), 'Estudo Bíblico'),
        ]),
        const SizedBox(height: 28),
        const Text('Android (adaptativo, círculo)      ·      Quadrado arredondado', style: TextStyle(fontFamily: 'Manrope', color: Colors.white54, fontSize: 11)),
      ]),
    )))));
    await t.runAsync(() async {
      final ctx = t.element(find.byType(Material).first);
      await precacheImage(fg, ctx);
      await precacheImage(AppLogo.asset, ctx);
    });
    await t.pumpAndSettle();
    await snap('logo_launcher');
  });

  testWidgets('logo no app: tela de desbloqueio', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(RepaintBoundary(child: wrap(studies(), LockScreen(creating: false, onUnlocked: () {}))));
    await precacheLogo(t);
    await t.pumpAndSettle();
    await snap('logo_app_desbloqueio');
  });

  testWidgets('logo no app: cabeçalho de Estudos', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(RepaintBoundary(child: wrap(studies(), HomeShell(store: studies(), now: now))));
    await precacheLogo(t);
    await t.pumpAndSettle();
    await snap('logo_app_cabecalho');
  });

  testWidgets('logo no app: Ajustes › Sobre', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    final s = studies();
    await t.pumpWidget(RepaintBoundary(child: wrap(s, HomeShell(store: s, initial: 2, now: now))));
    await precacheLogo(t);
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).last, const Offset(0, -600));
    await t.pumpAndSettle();
    await snap('logo_app_sobre');
  });

  testWidgets('seleção de versículo: favorito + cores, depois grifo aplicado e salvo', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({'fav': ['18:23:6']});
    await t.pumpWidget(RepaintBoundary(child: wrap(studies(), ReaderScreen(bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse_1')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('verse_actions')), findsOneWidget);
    expect(find.text('Favoritar'), findsOneWidget);
    await snap('versiculo_selecionado');

    // grifa o v.1 de amarelo
    await t.tap(find.byKey(const Key('hl_0')));
    await t.pumpAndSettle();
    // v.4 de laranja, v.5 de rosa, v.6 de azul
    for (final (v, c) in [(4, 1), (5, 2), (6, 3)]) {
      await t.tap(find.byKey(Key('verse_$v')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('hl_$c')));
      await t.pumpAndSettle();
    }
    // favorita o v.1
    await t.tap(find.byKey(const Key('verse_1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act_fav')));
    await t.pumpAndSettle();
    final sp = await SharedPreferences.getInstance();
    expect(jsonDecode(sp.getString('hl')!), {'18:23:1': 0, '18:23:4': 1, '18:23:5': 2, '18:23:6': 3});
    expect(sp.getStringList('fav'), containsAll(['18:23:1', '18:23:6']));
    expect(find.byKey(const Key('verse_actions')), findsNothing);
    await t.pump(const Duration(seconds: 5)); // some o aviso
    await t.pumpAndSettle();
    await snap('versiculo_grifado');

    // reabrir a tela mantém os grifos (persistência)
    await t.pumpWidget(RepaintBoundary(child: wrap(studies(), ReaderScreen(key: UniqueKey(), bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    final span = (t.widget<RichText>(find.descendant(of: find.byKey(const Key('verse_1')), matching: find.byType(RichText)).first).text as TextSpan).children!.first as TextSpan;
    final verseSpan = span.children![1] as TextSpan;
    expect(verseSpan.style!.backgroundColor, isNotNull);
  });

  testWidgets('inserir no estudo: lista de estudos → insere no escolhido', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({'hl': jsonEncode({'18:23:1': 0})});
    final s = studies();
    await t.pumpWidget(RepaintBoundary(child: wrap(s, ReaderScreen(bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse_1')));
    await t.tap(find.byKey(const Key('verse_2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act_study')));
    await t.pumpAndSettle();
    expect(find.text('Adicionar ao estudo'), findsOneWidget);
    expect(find.text('Criar novo estudo'), findsOneWidget);
    await snap('estudo_lista');

    await t.tap(find.text('Salmos de Davi'));
    await t.pumpAndSettle();
    final e = (await s.all()).firstWhere((e) => e.title == 'Salmos de Davi');
    expect(e.body, startsWith('Leitura semanal dos Salmos.\n“'));
    expect(e.body, endsWith('” — Salmos 23:1-2'));
    expect(find.textContaining('Trecho adicionado a “Salmos de Davi”'), findsOneWidget);
    await snap('estudo_inserido_aviso');

    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    await snap('estudo_inserido_editor');
    await flushBackupTimer(t);
  });

  testWidgets('inserir no estudo: criar novo estudo com o trecho', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    final s = studies();
    await t.pumpWidget(RepaintBoundary(child: wrap(s, ReaderScreen(bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse_4')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act_study')));
    await t.pumpAndSettle();
    await t.tap(find.text('Criar novo estudo'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('novo_estudo_titulo')), 'Sem medo do vale');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final created = (await s.all()).firstWhere((e) => e.title == 'Sem medo do vale');
    expect(created.body, endsWith('” — Salmos 23:4'));
    await flushBackupTimer(t);
  });

  testWidgets('inserir no estudo: formulário de novo estudo (tela)', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    final s = studies();
    await t.pumpWidget(RepaintBoundary(child: wrap(s, ReaderScreen(bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse_4')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act_study')));
    await t.pumpAndSettle();
    await t.tap(find.text('Criar novo estudo'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('novo_estudo_titulo')), 'Sem medo do vale');
    await t.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await snap('estudo_novo');
  });

  testWidgets('inserir no estudo: sem estudos abre direto a criação', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    final s = MemoryStore([]);
    await t.pumpWidget(RepaintBoundary(child: wrap(s, ReaderScreen(bible: Bible.instance!, book: 18, chapter: 23))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse_1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act_study')));
    await t.pumpAndSettle();
    expect(find.text('Você ainda não tem estudos. Crie o primeiro com este trecho.'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await snap('estudo_novo_sem_estudos');
    await t.tap(find.text('Criar estudo com o trecho'));
    await t.pumpAndSettle();
    expect((await s.all()).single.title, 'Estudo de Salmos 23:1');
    await flushBackupTimer(t);
  });

  test('backup leva e traz os grifos', () async {
    SharedPreferences.setMockInitialValues({'fav': ['18:23:1'], 'hl': jsonEncode({'18:23:1': 2})});
    final bytes = await Backup.serialize(MemoryStore([]));
    SharedPreferences.setMockInitialValues({});
    await Backup.restore(MemoryStore([]), bytes);
    expect(await Highlights.all(), {'18:23:1': 2});
  });
}
