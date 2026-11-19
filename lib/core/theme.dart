import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// All brand colors live here. Change them once and the whole app follows.
/// Red and yellow come from the A2Z2GO logo and site; the rest are quiet
/// neutrals, with semantic colors dark enough to read on white (4.5:1 or more).
class Brand {
  static const Color primary = Color(0xFFE30500);
  static const Color primaryDark = Color(0xFFB90400);
  static const Color accent = Color(0xFFFCB800);
  static const Color navy = Color(0xFF1A1A1F); // main text
  static const Color background = Color(0xFFF5F5F7);
  static const Color card = Colors.white;
  static const Color muted = Color(0xFF666A75); // secondary text
  static const Color line = Color(0xFFE8E8EC);
  static const Color tint = Color(
    0xFFF0F0F3,
  ); // quiet fill behind icons and avatars
  static const Color good = Color(0xFF15803D);
  static const Color warn = Color(0xFFB45309);
  static const Color bad = Color(0xFFC62828);
  static const Color info = Color(0xFF1D4ED8);

  /// A very soft lift for raised surfaces.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

/// Corner radii.
class Rd {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Motion: short and purposeful.
class Motion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Curve curve = Curves.easeOutCubic;
}

const _font = 'WorkSans';

/// The app font, for the few places that replace a whole text style.
const appFont = _font;

TextTheme _textTheme() {
  const c = Brand.navy;
  return const TextTheme(
    displaySmall: TextStyle(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: c,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: c,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: c,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: c,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: c,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: c,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: c,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: c,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: Brand.muted,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    primary: Brand.primary,
    onPrimary: Colors.white,
    secondary: Brand.accent,
    surface: Brand.card,
    onSurface: Brand.navy,
    error: Brand.bad,
  );
  final radius12 = BorderRadius.circular(Rd.md);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radius12,
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: _textTheme(),
    scaffoldBackgroundColor: Brand.background,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    dividerTheme: const DividerThemeData(
      color: Brand.line,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.navy,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        color: Brand.navy,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Brand.primary,
      unselectedLabelColor: Brand.muted,
      indicatorColor: Brand.primary,
      dividerColor: Brand.line,
      tabAlignment: TabAlignment.start,
      labelStyle: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: Brand.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF6B6F7A)),
      labelStyle: const TextStyle(color: Brand.muted),
      floatingLabelStyle: const TextStyle(
        color: Brand.muted,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(
        color: Brand.bad,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: const TextStyle(color: Brand.muted, fontSize: 12.5),
      border: border(Brand.line),
      enabledBorder: border(Brand.line),
      focusedBorder: border(Brand.primary, 1.8),
      errorBorder: border(Brand.bad),
      focusedErrorBorder: border(Brand.bad, 1.8),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE3E3E8),
        disabledForegroundColor: const Color(0xFF9A9DA6),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Brand.primary, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Brand.primary,
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x26101828),
      height: 68,
      indicatorColor: Brand.primary.withValues(alpha: 0.10),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.xl),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Brand.primary : Brand.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? Brand.primary
              : Brand.muted,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: Brand.line),
      backgroundColor: Colors.white,
      selectedColor: Brand.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Brand.navy,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: Color(0xFF9A9DA6), width: 1.6),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Brand.primary
            : Colors.transparent,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Brand.primary
            : const Color(0xFFC9CBD2),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Brand.primary,
      linearTrackColor: Brand.line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.xl)),
      titleTextStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Brand.navy,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 14,
        height: 1.5,
        color: Brand.muted,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.navy,
      contentTextStyle: const TextStyle(
        fontFamily: _font,
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      iconColor: Brand.muted,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Brand.primary,
      foregroundColor: Colors.white,
    ),
  );
}
