import 'package:flutter/material.dart';

class ApsColors {
  static const primary = Color(0xFF2B5BD7);
  static const primaryDark = Color(0xFF1E3FA0);
  static const ink = Color(0xFF0F1B33);
  static const muted = Color(0xFF667085);
  static const bg = Color(0xFFF5F8FC);
  static const card = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF1E8E4E);
  static const successBg = Color(0xFFE3F5EA);
  static const warn = Color(0xFFB54708);
  static const warnBg = Color(0xFFFEF0C7);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFEE4E2);
  static const infoBg = Color(0xFFE8EEFF);
  static const notConnectedBg = Color(0xFFFCE4DC);
  static const notConnected = Color(0xFFC2410C);
}

class ApsText {
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ApsColors.ink);
  static const section = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ApsColors.ink);
  static const body = TextStyle(fontSize: 14, color: ApsColors.ink);
  static const bodyBold = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ApsColors.ink);
  static const caption = TextStyle(fontSize: 12, color: ApsColors.muted);
  static const label = TextStyle(fontSize: 13, color: ApsColors.muted);
  static const amount = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ApsColors.success);
}

ThemeData buildApsTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ApsColors.primary, brightness: Brightness.light).copyWith(
    primary: ApsColors.primary,
    surface: ApsColors.card,
  );
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ApsColors.bg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: ApsColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: ApsColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(ApsColors.border),
      enabledBorder: border(ApsColors.border),
      focusedBorder: border(ApsColors.primary, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ApsColors.primary,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: ApsColors.primary,
        side: const BorderSide(color: ApsColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ApsColors.primary : const Color(0xFFD0D5DD)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: ApsColors.border, thickness: 1, space: 1),
  );
}
