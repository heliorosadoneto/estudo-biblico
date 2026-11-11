import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'backup.dart';
import 'data.dart';
import 'store_scope.dart';
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
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      DriveBackup.auto().whenComplete(() => Session.password = _has ? null : Session.password);
      // Already locked: do not rebuild. A rebuild refreshes the IME connection
      // and Android 10 autofill then writes the saved password over the typing.
      if (_has && !_locked) setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) => StoreScope(store: widget.store, child: MaterialApp(
        title: 'Estudo Bíblico',
        debugShowCheckedModeBanner: false,
        theme: Ui.theme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeShell(store: widget.store),
        builder: (context, child) => Stack(children: [
          child!,
          // The builder sits above the Navigator, so it has no Overlay.
          // A password field focused here throws on every keystroke and the
          // IME puts the previous value back. LockOverlay supplies one.
          if (_locked) Positioned.fill(child: _LockOverlay(creating: !_has, onUnlocked: () => setState(() { _locked = false; _has = true; }))),
        ]),
      ));
}

/// Full-screen lock layer with its own [Overlay], so the password field can
/// update its selection while the user types.
class _LockOverlay extends StatefulWidget {
  final bool creating;
  final VoidCallback onUnlocked;
  const _LockOverlay({required this.creating, required this.onUnlocked});
  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => LockScreen(creating: widget.creating, onUnlocked: widget.onUnlocked),
  );

  @override
  void didUpdateWidget(_LockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
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
