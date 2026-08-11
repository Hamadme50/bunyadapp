import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Wires the design tokens into a Material theme, so anything Flutter draws for
/// us — dialogs, text selection, the keyboard's accessory bar — lands in the
/// same palette as the widgets we draw ourselves.
ThemeData buildTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: T.accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: T.accent,
    onPrimary: T.bg,
    surface: T.bg,
    onSurface: T.text,
    error: T.accent700,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: T.bg,
    fontFamily: T.fontFamily,
    splashFactory: InkSparkle.splashFactory,

    textTheme: TextTheme(
      displayLarge: T.h1,
      headlineLarge: T.h1,
      headlineMedium: T.h2,
      headlineSmall: T.h3,
      titleLarge: T.h4,
      bodyLarge: T.body,
      bodyMedium: T.body,
      bodySmall: T.bodySm,
      labelLarge: TextStyle(
        fontFamily: T.fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 14,
        height: 1.2,
      ),
    ),

    // The system's `.input`: recessed, hairline border, accent ring on focus.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.raised,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: T.body.copyWith(fontSize: 14, color: T.ink(0.38)),
      border: OutlineInputBorder(
        borderRadius: T.brMd,
        borderSide: const BorderSide(color: T.hairlineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: T.brMd,
        borderSide: const BorderSide(color: T.hairlineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: T.brMd,
        borderSide: const BorderSide(color: T.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: T.brMd,
        borderSide: const BorderSide(color: T.accent, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: T.brMd,
        borderSide: const BorderSide(color: T.accent, width: 1.6),
      ),
      errorStyle: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.accent700),
    ),

    dividerTheme: const DividerThemeData(color: T.hairline, thickness: 1, space: 1),

    // A date picker is the one place we let Material draw a whole screen.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: T.bg,
      headerBackgroundColor: T.accent,
      headerForegroundColor: T.bg,
      shape: RoundedRectangleBorder(borderRadius: T.brLg),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: T.accent,
      selectionColor: T.accent.withValues(alpha: 0.25),
      selectionHandleColor: T.accent,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(color: T.accent),
  );
}

/// A light status bar with dark icons, matching the app's pale ground.
const SystemUiOverlayStyle bunyadOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: T.bg,
  systemNavigationBarIconBrightness: Brightness.dark,
);
