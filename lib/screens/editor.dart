import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import 'list.dart';
import '../bible.dart';
import '../backup.dart';
import 'verse_picker.dart';

class EditorScreen extends StatefulWidget {
  final EntryStore store;
  final Entry? entry;
  const EditorScreen({super.key, required this.store, this.entry});
  @override
  State<EditorScreen> createState() => _EditorState();
}

class _EditorState extends State<EditorScreen> {
  late final Entry _e = widget.entry ?? Entry(title: '', body: '', date: DateTime.now());
  late final _title = TextEditingController(text: _e.title);
  late final _body = QuoteController(text: _e.body);

  Future<void> _addVerse() async {
    final b = await Bible.load();
    if (!mounted) return;
    final quote = await pickVerses(context, b);
    if (quote == null) return;
    final t = _body.text;
    final sel = _body.selection;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final before = t.substring(0, at), after = t.substring(end);
    final pre = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final post = after.startsWith('\n') ? '' : '\n';
    _body.value = TextEditingValue(text: '$before$pre$quote$post$after',
        selection: TextSelection.collapsed(offset: before.length + pre.length + quote.length + post.length));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) return;
    _e..title = _title.text.trim()..body = _body.text;
    await widget.store.save(_e);
    DriveBackup.schedule();
  }

  static final _spell = Platform.isAndroid
      ? const SpellCheckConfiguration(misspelledTextStyle: TextStyle(decoration: TextDecoration.underline, decorationColor: Ui.red, decorationStyle: TextDecorationStyle.wavy))
      : null;
  static const _plain = InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero, isCollapsed: true);

  @override
  Widget build(BuildContext context) => PopScope(
        onPopInvokedWithResult: (didPop, _) { if (didPop) _save(); },
        child: Scaffold(
          appBar: AppBar(actions: [
            IconButton(icon: const Icon(Icons.menu_book_outlined), tooltip: 'Inserir versículo', onPressed: _addVerse),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                onPressed: () async { await _save(); if (context.mounted) Navigator.pop(context); },
                child: const Text('Salvar')),
            ),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 40), children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Ui.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(longDate(_e.date).toUpperCase(), style: Ui.date),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _title, style: Ui.h1.copyWith(fontSize: 28), maxLines: null,
                textCapitalization: TextCapitalization.sentences, autocorrect: true, enableSuggestions: true, spellCheckConfiguration: _spell,
                decoration: _plain.copyWith(hintText: 'Título', hintStyle: Ui.h1.copyWith(fontSize: 28, color: Ui.border))),
            const SizedBox(height: 16),
            Container(height: 1, color: Ui.border),
            const SizedBox(height: 16),
            TextField(controller: _body, maxLines: null, minLines: 16, keyboardType: TextInputType.multiline, style: Ui.body,
                textCapitalization: TextCapitalization.sentences, autocorrect: true, enableSuggestions: true, spellCheckConfiguration: _spell,
                decoration: _plain.copyWith(hintText: 'O que você aprendeu hoje?', hintStyle: Ui.body.copyWith(color: Ui.muted))),
          ]),
        ),
      );
}

/// Destaca as citações bíblicas no texto: itálico, cinza claro, referência em vermelho.
class QuoteController extends TextEditingController {
  QuoteController({super.text});
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (isQuoteLine(l)) {
        final k = l.lastIndexOf('” — ');
        spans.add(TextSpan(text: l.substring(0, k + 1), style: style?.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFFD8D8DC), backgroundColor: const Color(0x22E5243B))));
        spans.add(TextSpan(text: l.substring(k + 1), style: style?.copyWith(color: Ui.red, fontWeight: FontWeight.w700, backgroundColor: const Color(0x22E5243B))));
      } else {
        spans.add(TextSpan(text: l, style: style));
      }
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}
