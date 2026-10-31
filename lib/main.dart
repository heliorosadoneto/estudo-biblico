import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'backup.dart';
import 'data.dart';
import 'theme.dart';
import 'screens/list.dart';
import 'screens/lock.dart';
import 'screens/bible.dart';
import 'screens/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final store = SqlStore();
  runApp(DiarioApp(store: store, hasPassword: await Auth.hasPassword()));
  DriveBackup.init(store);
}

class DiarioApp extends StatefulWidget {
  final EntryStore store;
  final bool hasPassword;
  const DiarioApp({super.key, required this.store, required this.hasPassword});
  @override
  State<DiarioApp> createState() => _AppState();
}

class _AppState extends State<DiarioApp> with WidgetsBindingObserver {
  bool _locked = true;
  late bool _has = widget.hasPassword;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      DriveBackup.auto().whenComplete(() => Session.password = _has ? null : Session.password);
      if (_has) setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Estudo Bíblico',
        debugShowCheckedModeBanner: false,
        theme: Ui.theme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeShell(store: widget.store),
        builder: (context, child) => Stack(children: [
          child!,
          if (_locked) Positioned.fill(child: LockScreen(creating: !_has, onUnlocked: () => setState(() { _locked = false; _has = true; }))),
        ]),
      );
}

class HomeShell extends StatefulWidget {
  final EntryStore store;
  final int initial;
  final DateTime? now;
  const HomeShell({super.key, required this.store, this.initial = 0, this.now});
  @override
  State<HomeShell> createState() => _ShellState();
}

class _ShellState extends State<HomeShell> {
  late int _i = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: [ListScreen(store: widget.store, now: widget.now), const BibleScreen(), SettingsScreen(store: widget.store)]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Estudos'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Bíblia'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
          ],
        ),
      );
}
