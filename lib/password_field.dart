import 'package:flutter/material.dart';
import 'theme.dart';

/// Password entry that never writes a stored value over what the user is typing.
///
/// The controller is created once here and kept for the life of this [State].
/// [initialText] is copied into it a single time in [initState]. [build],
/// [didUpdateWidget], and [didChangeDependencies] do not assign `controller.text`,
/// so a parent rebuild, a [FutureBuilder]/[StreamBuilder], or a dependency change
/// cannot put a saved password back on top of keystrokes.
///
/// Platform autofill is off. [TextField.autofillHints] defaults to an empty
/// list, and an empty list still enables autofill: the hint ("Senha") and the
/// obscured input are sent to Android. On Android 10 (moto g9 plus) the
/// autofill service answers each keystroke by committing the previously saved
/// password, so the field never accepts a new value. Null — not an empty list —
/// is what disables that channel. The activity also opts the window out.
class PasswordField extends StatefulWidget {
  /// Applied once, only when this state is first created. Not a live binding.
  final String? initialText;
  final String hintText;
  final bool obscureText;
  final bool autofocus;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Increment to clear the field once. The new value is not copied in.
  final int clearGeneration;

  const PasswordField({
    super.key,
    this.initialText,
    required this.hintText,
    this.obscureText = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.clearGeneration = 0,
  });

  @override
  State<PasswordField> createState() => PasswordFieldState();
}

class PasswordFieldState extends State<PasswordField> {
  late final TextEditingController _controller;

  TextEditingController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final seed = widget.initialText;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      // Notify after the first frame, and only if the user has not already typed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text == seed) widget.onChanged?.call(seed);
      });
    }
  }

  @override
  void didUpdateWidget(PasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearGeneration != oldWidget.clearGeneration) {
      _controller.clear();
    }
    // initialText is intentionally ignored after the first insert.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        style: Ui.body,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        keyboardType: TextInputType.visiblePassword,
        // null disables autofill. An empty list is the TextField default and
        // still registers the field, which is what puts the saved password back.
        autofillHints: null,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(hintText: widget.hintText, prefixIcon: widget.prefixIcon, suffixIcon: widget.suffixIcon),
      );
}
