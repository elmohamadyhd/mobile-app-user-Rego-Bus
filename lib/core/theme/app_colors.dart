import 'package:flutter/material.dart';

/// Design-token color palette. Replace hex values to match your brand.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF4F8CFF);
  static const primaryVariant = Color(0xFF2563EB);
  static const onPrimary = Color(0xFFFFFFFF);

  static const secondary = Color(0xFF10B981);
  static const onSecondary = Color(0xFFFFFFFF);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const bgBase = Color(0xFF0F0F0F);
  static const bgElevated = Color(0xFF1A1A1A);
  static const bgCard = Color(0xFF242424);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F2F2);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textMuted = Color(0xFF666666);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);

  // ── Borders ──────────────────────────────────────────────────────────────
  static const border = Color(0xFF2E2E2E);
  static const borderFocus = Color(0xFF4F8CFF);

  // ── Light-mode overrides (used by AppTheme.light) ────────────────────────
  static const lightBgBase = Color(0xFFF9FAFB);
  static const lightBgCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);
}
