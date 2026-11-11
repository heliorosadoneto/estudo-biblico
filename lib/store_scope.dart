import 'package:flutter/widgets.dart';
import 'data.dart';

/// Dá acesso ao banco de estudos em qualquer tela (ex.: o leitor da Bíblia,
/// para inserir um trecho num estudo).
class StoreScope extends InheritedWidget {
  final EntryStore store;
  const StoreScope({super.key, required this.store, required super.child});
  static EntryStore? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()?.store;
  @override
  bool updateShouldNotify(StoreScope old) => old.store != store;
}
