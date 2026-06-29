import 'package:flutter/material.dart';

/// REGO "Skyline" design tokens.
///
/// Light-first palette: an immersive blue gradient hero with a white card
/// floating over it, plus an amber accent. Dark-mode overrides are prefixed
/// `dark*` and consumed by [AppTheme.dark].
abstract final class AppColors {
  // ── Brand: Skyline blue ──────────────────────────────────────────────────
  static const primary = Color(0xFF1464EC); // brand blue
  static const primaryDark = Color(0xFF0E50C7); // gradient mid-stop
  static const primaryDeep = Color(0xFF0A3FA3); // gradient end-stop
  static const onPrimary = Color(0xFFFFFFFF);

  /// ~160° hero gradient behind auth/home headers. Angle approximates the
  /// design canvas (the claude.ai/design file is the source of truth).
  static const heroGradient = LinearGradient(
    begin: Alignment(-0.34, -1.0),
    end: Alignment(0.34, 1.0),
    colors: [primary, primaryDark, primaryDeep],
  );

  // ── Accent: amber ────────────────────────────────────────────────────────
  static const secondary = Color(0xFFF0B256);
  static const onSecondary = Color(0xFF231703);

  // ── Backgrounds (light-first) ────────────────────────────────────────────
  static const bgBase = Color(0xFFF4F7FB);
  static const bgElevated = Color(0xFFFFFFFF);
  static const bgCard = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF0E1726);
  static const textSecondary = Color(0xFF5B6B82);
  static const textMuted = Color(0xFF9AA7B8);
  static const onHero = Color(0xFFFFFFFF); // text/icons over the gradient

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const error = Color(0xFFE5484D);
  static const warning = Color(0xFFF0B256);
  static const success = Color(0xFF2BB673);

  // ── Borders ──────────────────────────────────────────────────────────────
  static const border = Color(0xFFE3E9F2);
  static const borderFocus = primary;

  // ── Auth / form surfaces (from the Skyline canvas) ───────────────────────
  static const inputFill = Color(0xFFF4F6FB); // input pill background
  static const hairline = Color(0xFFEEF1F6); // input border / dividers
  static const primaryTint = Color(0xFFE8F0FE); // filled OTP box / icon circle
  static const secondaryTint = Color(0xFFFBF0DE); // amber icon circle

  // ── Dark-mode overrides (used by AppTheme.dark) ──────────────────────────
  static const darkBgBase = Color(0xFF0A1426);
  static const darkBgCard = Color(0xFF13203A);
  static const darkTextPrimary = Color(0xFFEAF0FA);
  static const darkTextSecondary = Color(0xFF9DB0CC);
  static const darkBorder = Color(0xFF22324F);
}
