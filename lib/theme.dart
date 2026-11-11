import 'package:flutter/material.dart';

/// Design system: preto, branco e vermelho.
class Ui {
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF151517);
  static const surface2 = Color(0xFF1E1E21);
  static const border = Color(0xFF2A2A2E);
  static const text = Colors.white;
  static const muted = Color(0xFF9A9AA0);
  static const red = Color(0xFFE5243B);
  static const redDark = Color(0xFF9E1527);

  static const radius = 18.0;
  static const font = 'Manrope';

  static const h1 = TextStyle(fontFamily: font, color: text, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5);
  static const h2 = TextStyle(fontFamily: font, color: text, fontSize: 18, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontFamily: font, color: text, fontSize: 17, height: 1.6, fontWeight: FontWeight.w400);
  static const small = TextStyle(fontFamily: font, color: muted, fontSize: 14, height: 1.4);
  static const date = TextStyle(fontFamily: font, color: red, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .3);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: font,
        colorScheme: const ColorScheme.dark(primary: red, secondary: red, surface: surface, onPrimary: Colors.white, onSurface: text, error: red),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: text,
            titleTextStyle: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w800, color: text)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: red, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius)))),
        dialogTheme: DialogThemeData(backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)), titleTextStyle: h2),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: red, textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: surface, labelStyle: small, hintStyle: small,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: red, width: 1.5)),
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: red, selectionColor: Color(0x66E5243B), selectionHandleColor: red),
        dividerColor: border,
        dividerTheme: const DividerThemeData(color: border, thickness: 1),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface, indicatorColor: red.withValues(alpha: .18), surfaceTintColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? red : muted)),
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w700,
              color: s.contains(WidgetState.selected) ? Colors.white : muted)),
        ),
      );

  static BoxDecoration card({bool active = false}) => BoxDecoration(
      color: surface, borderRadius: BorderRadius.circular(radius), border: Border.all(color: active ? red.withValues(alpha: .5) : border));
}

/// Logo: foto de uma Bíblia aberta, em tons quentes, num quadrado arredondado.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 72});
  static const asset = AssetImage('assets/logo.png');
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .225),
        child: Image(image: asset, width: size, height: size, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
      );
}

/// Cores de marca-texto, no espírito do Kindle.
class HighlightColor {
  final String name;
  final Color color;
  const HighlightColor(this.name, this.color);
  static const all = [
    HighlightColor('Amarelo', Color(0xFFFFD84D)),
    HighlightColor('Laranja', Color(0xFFFF9F43)),
    HighlightColor('Rosa', Color(0xFFFF7EB6)),
    HighlightColor('Azul', Color(0xFF5DADE2)),
  ];
}
