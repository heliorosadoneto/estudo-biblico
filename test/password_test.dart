import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:diario/backup.dart';
import 'package:diario/data.dart';
import 'package:diario/main.dart';
import 'package:diario/password_field.dart';
import 'package:diario/screens/lock.dart';
import 'package:diario/screens/settings.dart';
import 'package:diario/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget w) => MaterialApp(debugShowCheckedModeBanner: false, theme: Ui.theme(), home: w);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  String legacyHash(String salt, String pw) => sha256.convert(utf8.encode('$salt:$pw')).toString();

  test('setPassword replaces the previous password', () async {
    await Auth.setPassword('antiga');
    expect(await Auth.hasPassword(), isTrue);
    expect(await Auth.check('antiga'), isTrue);

    await Auth.setPassword('nova-senha');
    expect(await Auth.check('antiga'), isFalse);
    expect(await Auth.check('nova-senha'), isTrue);

    final sp = await SharedPreferences.getInstance();
    expect(sp.containsKey('pw_hash'), isFalse);
    expect(sp.containsKey('pw_salt'), isFalse);
    expect(sp.containsKey('pw_record'), isTrue);
  });

  test('legacy salt and hash still verify, then a change drops them', () async {
    SharedPreferences.setMockInitialValues({
      'pw_salt': 'oldsalt',
      'pw_hash': legacyHash('oldsalt', 'antiga'),
    });
    expect(await Auth.check('antiga'), isTrue);
    expect(await Auth.check('outra'), isFalse);

    await Auth.setPassword('nova-senha');
    expect(await Auth.check('antiga'), isFalse);
    expect(await Auth.check('nova-senha'), isTrue);
    final sp = await SharedPreferences.getInstance();
    expect(sp.containsKey('pw_hash'), isFalse);
    expect(sp.containsKey('pw_salt'), isFalse);
  });

  testWidgets('stored password is applied once and typing is not overwritten', (tester) async {
    final host = GlobalKey<_HostState>();
    await tester.pumpWidget(wrap(_Host(key: host, seed: 'senha-salva')));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'senha-salva');

    await tester.enterText(find.byType(TextField), 'o-que-eu-digitei');
    await tester.pump();
    host.currentState!.rebuild();
    await tester.pump();
    host.currentState!.rebuild(changeTheme: true);
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'o-que-eu-digitei');
    expect(host.currentState!.latest, 'o-que-eu-digitei');
  });

  testWidgets('password fields are not registered for platform autofill', (tester) async {
    await tester.pumpWidget(wrap(LockScreen(creating: true, onUnlocked: () {})));
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.autofillHints, isNull);
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
    }
  });

  testWidgets('lock screen keeps typed password across visibility toggle and rebuild', (tester) async {
    await tester.pumpWidget(wrap(LockScreen(creating: false, onUnlocked: () {})));
    await tester.enterText(find.byType(TextField), 'digitando');
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'digitando');

    await tester.pumpWidget(wrap(LockScreen(creating: false, onUnlocked: () {})));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'digitando');
  });

  testWidgets('pause while locked does not rebuild the password away', (tester) async {
    await tester.pumpWidget(DiarioApp(store: MemoryStore([]), hasPassword: true));
    await tester.pump();
    final lockField = find.descendant(of: find.byType(LockScreen), matching: find.byType(TextField));
    await tester.enterText(lockField, 'digitando');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.widget<TextField>(lockField).controller!.text, 'digitando');
  });

  testWidgets('change-password fields do not prefill the saved password', (tester) async {
    Session.password = 'segredo-salvo';
    addTearDown(() => Session.password = null);
    await tester.pumpWidget(wrap(SettingsScreen(store: MemoryStore([]))));
    await tester.pump();
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('saving a new password persists and clears the fields', (tester) async {
    await Auth.setPassword('antiga');
    await tester.pumpWidget(wrap(SettingsScreen(store: MemoryStore([]))));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'antiga');
    await tester.enterText(fields.at(1), 'nova12');
    await tester.enterText(fields.at(2), 'nova12');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(await Auth.check('nova12'), isTrue);
    expect(await Auth.check('antiga'), isFalse);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, isEmpty);
    expect(find.text('Senha alterada com sucesso'), findsOneWidget);
  });
}

class _Host extends StatefulWidget {
  final String seed;
  const _Host({super.key, required this.seed});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int n = 0;
  bool dark = true;
  String latest = '';

  void rebuild({bool changeTheme = false}) => setState(() { n++; dark = changeTheme ? !dark : dark; });

  @override
  Widget build(BuildContext context) => Theme(
        data: Ui.theme().copyWith(brightness: dark ? Brightness.dark : Brightness.light),
        child: Scaffold(body: Column(children: [
          PasswordField(hintText: 'Senha', initialText: widget.seed, onChanged: (v) => latest = v),
          Text('rebuilds:$n'),
        ])),
      );
}
