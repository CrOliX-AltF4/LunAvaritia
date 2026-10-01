import 'package:flutter/material.dart';

/// The DA shared with the site and the panel (ADR-020 D5, DA2): ink ground, ivory text, fine rules, Cormorant
/// Garamond for titles and Inter for the rest. Red is a fill or a border, never text on ink (unreadable there).
abstract final class Palette {
  static const encre = Color(0xFF0D0B09);
  static const encre2 = Color(0xFF1A1612);
  static const encre3 = Color(0xFF2A241D);
  static const ivoire = Color(0xFFF0EBE1);
  static const papier = Color(0xFFE8E2D6);
  static const lune = Color(0xFFC8C0B0);
  static const lavis = Color(0xFF8A9BAE);
  static const rouge = Color(0xFF7A1818);

  /// Secondary text that still reads on ink (≥ 4.5:1).
  static const brume = Color(0xFFA79F92);

  /// Fine rules between rows and around cards.
  static const filet = Color(0x1AF0EBE1);
  static const filetFort = Color(0x3DF0EBE1);
}

const serif = 'Cormorant Garamond';
const sans = 'Inter';

/// A text style on the DA's variable fonts — the weight is set on the font's own axis as well.
TextStyle da({
  String family = sans,
  double size = 15,
  double weight = 300,
  Color color = Palette.ivoire,
  double? height,
  FontStyle? style,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      height: height,
      fontStyle: style,
      letterSpacing: letterSpacing,
    );

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.ivoire,
    onPrimary: Palette.encre,
    secondary: Palette.lavis,
    onSecondary: Palette.encre,
    error: Palette.rouge,
    onError: Palette.ivoire,
    errorContainer: Palette.rouge,
    onErrorContainer: Palette.ivoire,
    surface: Palette.encre,
    onSurface: Palette.ivoire,
    onSurfaceVariant: Palette.lune,
    surfaceContainerLowest: Palette.encre,
    surfaceContainerLow: Palette.encre2,
    surfaceContainer: Palette.encre2,
    surfaceContainerHigh: Palette.encre2,
    surfaceContainerHighest: Palette.encre3,
    outline: Palette.brume,
    outlineVariant: Palette.filet,
    primaryContainer: Palette.encre3,
    onPrimaryContainer: Palette.ivoire,
    secondaryContainer: Palette.encre3,
    onSecondaryContainer: Palette.ivoire,
  );

  final text = TextTheme(
    displaySmall: da(family: serif, size: 40, weight: 400, height: 1.1),
    headlineSmall: da(family: serif, size: 26, weight: 500),
    titleLarge: da(family: serif, size: 22, weight: 500),
    titleMedium: da(size: 16, weight: 400),
    titleSmall: da(size: 14, weight: 400),
    bodyLarge: da(size: 15, height: 1.5),
    bodyMedium: da(size: 14, height: 1.45),
    bodySmall: da(size: 13, color: Palette.lune),
    labelLarge: da(size: 15, weight: 400),
    labelMedium: da(size: 13, color: Palette.lune),
    labelSmall: da(size: 12, color: Palette.lune, letterSpacing: 0.7),
  );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.encre,
    fontFamily: sans,
    textTheme: text,
    dividerTheme: const DividerThemeData(color: Palette.filet, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.encre,
      foregroundColor: Palette.ivoire,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: Palette.filet)),
      titleTextStyle: da(size: 16, weight: 400),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Palette.encre2,
      scrimColor: Color(0xB80D0B09),
      shape: RoundedRectangleBorder(),
      width: 332,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.encre2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.filetFort,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: Palette.filetFort),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ivoire,
        foregroundColor: Palette.encre,
        minimumSize: const Size(44, 44),
        shape: pill,
        textStyle: da(size: 15, weight: 400, color: Palette.encre),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ivoire,
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: Palette.filetFort),
        shape: pill,
        textStyle: da(size: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.lavis, minimumSize: const Size(44, 44), textStyle: da(size: 14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.encre2,
      hintStyle: da(color: Palette.brume),
      labelStyle: da(color: Palette.lune),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Palette.filet)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Palette.filet)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Palette.lune)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.encre3,
      contentTextStyle: da(size: 14),
      actionTextColor: Palette.ivoire,
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Palette.ivoire,
      textColor: Palette.ivoire,
      titleTextStyle: da(size: 15),
      subtitleTextStyle: da(size: 13, color: Palette.lune),
      minVerticalPadding: 12,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.encre : Palette.brume),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ivoire : Palette.encre3),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Palette.ivoire,
      labelStyle: da(size: 13),
      secondaryLabelStyle: da(size: 13, color: Palette.encre, weight: 400),
      side: const BorderSide(color: Palette.filetFort),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      showCheckmark: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.lune),
  );
}
