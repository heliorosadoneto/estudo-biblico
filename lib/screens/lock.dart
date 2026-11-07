import 'package:flutter/material.dart';
import '../backup.dart';
import '../data.dart';
import '../password_field.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  final bool creating;
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.creating, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockState();
}

class _LockState extends State<LockScreen> {
  // Plain strings updated only from the fields. Never reassigned from storage.
  String _pw = '', _pw2 = '';
  int _clear = 0;
  String? _err;
  bool _show = false;

  Future<void> _go() async {
    final pw = _pw, pw2 = _pw2;
    if (widget.creating) {
      if (pw.length < 4) return setState(() => _err = 'A senha precisa de ao menos 4 caracteres');
      if (pw != pw2) return setState(() => _err = 'As senhas não conferem');
      await Auth.setPassword(pw);
    } else if (!await Auth.check(pw)) {
      return setState(() => _err = 'Senha incorreta');
    }
    Session.password = pw;
    if (!mounted) return;
    setState(() { _clear++; _err = null; });
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const AppLogo(size: 84),
                const SizedBox(height: 24),
                const Text('Estudo Bíblico', style: Ui.h1),
                const SizedBox(height: 6),
                Text(widget.creating ? 'Crie uma senha para proteger seus estudos' : 'Digite sua senha para continuar', style: Ui.small),
                const SizedBox(height: 36),
                PasswordField(
                  hintText: 'Senha', obscureText: !_show, clearGeneration: _clear,
                  onChanged: (v) { _pw = v; },
                  onSubmitted: widget.creating ? null : (_) { _go(); },
                  prefixIcon: const Icon(Icons.lock_outline, color: Ui.muted),
                  suffixIcon: IconButton(
                    icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Ui.muted),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
                if (widget.creating) ...[
                  const SizedBox(height: 12),
                  PasswordField(
                    hintText: 'Confirmar senha', obscureText: !_show, clearGeneration: _clear,
                    onChanged: (v) { _pw2 = v; },
                    prefixIcon: const Icon(Icons.lock_outline, color: Ui.muted),
                  ),
                ],
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err!, style: Ui.small.copyWith(color: Ui.red))),
                const SizedBox(height: 24),
                FilledButton(onPressed: _go, child: Text(widget.creating ? 'Criar senha' : 'Desbloquear')),
              ]),
            ),
          ),
        ),
      );
}
