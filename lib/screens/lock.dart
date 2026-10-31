import 'package:flutter/material.dart';
import '../backup.dart';
import '../data.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  final bool creating;
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.creating, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockState();
}

class _LockState extends State<LockScreen> {
  final _pw = TextEditingController(), _pw2 = TextEditingController();
  String? _err;
  bool _show = false;

  Future<void> _go() async {
    if (widget.creating) {
      if (_pw.text.length < 4) return setState(() => _err = 'A senha precisa de ao menos 4 caracteres');
      if (_pw.text != _pw2.text) return setState(() => _err = 'As senhas não conferem');
      await Auth.setPassword(_pw.text);
    } else if (!await Auth.check(_pw.text)) {
      return setState(() => _err = 'Senha incorreta');
    }
    Session.password = _pw.text;
    _pw.clear(); _pw2.clear();
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
                TextField(
                  controller: _pw, obscureText: !_show, style: Ui.body,
                  onSubmitted: (_) => widget.creating ? null : _go(),
                  decoration: InputDecoration(
                    hintText: 'Senha', prefixIcon: const Icon(Icons.lock_outline, color: Ui.muted),
                    suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Ui.muted),
                        onPressed: () => setState(() => _show = !_show)),
                  ),
                ),
                if (widget.creating) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _pw2, obscureText: !_show, style: Ui.body,
                      decoration: const InputDecoration(hintText: 'Confirmar senha', prefixIcon: Icon(Icons.lock_outline, color: Ui.muted))),
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
