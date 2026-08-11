import 'package:flutter/material.dart';

/// The Modernist design system's tokens, carried over from the web app's
/// `design-system.css` and the overrides `app.css` layers on top.
///
/// The system ships flat — zero radius, no elevation. Bunyad deliberately
/// softens that, so the radius and shadow values here are the app layer's,
/// while colour, type and spacing are the system's own.
class T {
  const T._();

  // ── colour: ground and ink ──────────────────────────────────────────────

  static const Color bg = Color(0xFFF3F2F2);
  static const Color surface = Color(0xFFEAE9E9);
  static const Color text = Color(0xFF201E1D);

  /// Raised surfaces sit lighter than the ground; the ground is never white.
  static const Color raised = Color(0xFFFFFFFF);

  // ── colour: accent ──────────────────────────────────────────────────────
  //
  // Deep steel blue in place of the system's red. The ramp is generated in
  // OKLCH at hue 246° on a lightness ladder re-anchored for a dark accent, so
  // hover (600) and pressed (700) still go darker than the base.

  static const Color accent = Color(0xFF024C7D);
  static const Color accent100 = Color(0xFFEEF6FD);
  static const Color accent200 = Color(0xFFD8E9F8);
  static const Color accent300 = Color(0xFFB8D5F0);
  static const Color accent400 = Color(0xFF78A3CA);
  static const Color accent500 = Color(0xFF2F6897);
  static const Color accent600 = Color(0xFF004471);
  static const Color accent700 = Color(0xFF003356);
  static const Color accent800 = Color(0xFF012540);
  static const Color accent900 = Color(0xFF071928);

  // ── colour: neutrals ────────────────────────────────────────────────────

  static const Color neutral100 = Color(0xFFF8F4F4);
  static const Color neutral200 = Color(0xFFEAE7E7);
  static const Color neutral300 = Color(0xFFD7D3D3);
  static const Color neutral400 = Color(0xFFBAB6B6);
  static const Color neutral500 = Color(0xFF9B9797);
  static const Color neutral600 = Color(0xFF7D7979);
  static const Color neutral700 = Color(0xFF605D5D);
  static const Color neutral800 = Color(0xFF444141);
  static const Color neutral900 = Color(0xFF2D2B2B);

  // ── hairlines ───────────────────────────────────────────────────────────
  //
  // The CSS says color-mix(text 9%/15%, transparent) — the same thing as ink
  // at 9% and 15% opacity.

  static const Color hairline = Color(0x17201E1D);
  static const Color hairlineStrong = Color(0x26201E1D);

  /// Ink at a given opacity, for the many `color-mix(text N%, transparent)`
  /// values the stylesheet uses for muted copy.
  static Color ink(double opacity) => text.withValues(alpha: opacity);

  // ── spacing ─────────────────────────────────────────────────────────────

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;

  // ── radius ──────────────────────────────────────────────────────────────

  static const double rXs = 6;
  static const double rSm = 8;
  static const double rMd = 10;
  static const double rLg = 16;
  static const double rCard = 14;
  static const double rPill = 999;

  static final BorderRadius brXs = BorderRadius.circular(rXs);
  static final BorderRadius brSm = BorderRadius.circular(rSm);
  static final BorderRadius brMd = BorderRadius.circular(rMd);
  static final BorderRadius brLg = BorderRadius.circular(rLg);
  static final BorderRadius brCard = BorderRadius.circular(rCard);
  static final BorderRadius brPill = BorderRadius.circular(rPill);

  // ── elevation ───────────────────────────────────────────────────────────
  //
  // xs rests, sm sits, md lifts, lg floats over the page.

  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0F2D2B2B), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A2D2B2B), blurRadius: 1, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x142D2B2B), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D2D2B2B), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x172D2B2B), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x172D2B2B), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x242D2B2B), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x292D2B2B), blurRadius: 56, offset: Offset(0, 24)),
  ];

  /// The primary button's tinted drop.
  static final List<BoxShadow> shadowAccent = [
    BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  // ── motion ──────────────────────────────────────────────────────────────

  static const Curve ease = Cubic(0.2, 0.7, 0.3, 1);
  static const Duration tFast = Duration(milliseconds: 120);
  static const Duration t = Duration(milliseconds: 170);

  // ── type ────────────────────────────────────────────────────────────────

  static const String fontFamily = 'Archivo';

  /// Headings are Archivo at 800 with the system's tight tracking.
  static const TextStyle _heading = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.015 * 16,
    color: text,
  );

  static TextStyle heading(double size, {Color? color, double? height}) => _heading.copyWith(
        fontSize: size,
        letterSpacing: size * -0.015,
        height: height,
        color: color,
      );

  /// 42px in the stylesheet, but a phone is not a desktop: the page titles are
  /// stepped down so a project name still fits on one line at 390px wide.
  static TextStyle get h1 => heading(32);
  static TextStyle get h2 => heading(26);
  static TextStyle get h3 => heading(21);
  static TextStyle get h4 => heading(18);

  /// `.eyebrow` / `.card-kicker` — 11px, wide tracking, upper case.
  static TextStyle get eyebrow => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.08 * 11,
        height: 1.3,
        color: ink(0.55),
      );

  /// `.kicker` — the accent-coloured version above a page title.
  static TextStyle get kicker => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1 * 11,
        height: 1.3,
        color: accent,
      );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: text,
  );

  static TextStyle get bodySm => body.copyWith(fontSize: 13, height: 1.45);
  static TextStyle get muted => body.copyWith(fontSize: 13, color: ink(0.6), height: 1.45);

  /// The big money figures: `.amount-hero`, `.amount-lg`, `.stat-value`.
  static TextStyle amount(double size, {Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1,
        letterSpacing: size * -0.02,
        color: color ?? text,
      );
}
