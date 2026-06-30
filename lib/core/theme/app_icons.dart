import 'package:flutter/material.dart';

/// Central icon library for the whole app.
///
/// Every screen references icons through this facade (e.g. [AppIcons.mail])
/// instead of reaching for `Icons.*` directly. That keeps icon usage
/// consistent and lets us swap the backing set (Material → a custom outline
/// pack) in one place without touching call-sites.
///
/// The design direction calls for clean **outline** glyphs, so prefer the
/// `_outlined` Material variants here.
///
/// Brand logos (Google / Facebook / Apple) are *not* icons — they live as SVG
/// assets under `assets/brand/` and render via `BrandMark`.
abstract final class AppIcons {
  // ── Auth & identity ──────────────────────────────────────────────────────
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData user = Icons.person_outline_rounded;
  static const IconData phone = Icons.phone_outlined;
  static const IconData shield = Icons.verified_user_outlined;

  // ── Navigation & chrome ──────────────────────────────────────────────────
  static const IconData back = Icons.chevron_left_rounded;
  static const IconData forward = Icons.chevron_right_rounded;
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData bell = Icons.notifications_none_rounded;

  // ── Travel / domain ──────────────────────────────────────────────────────
  static const IconData bus = Icons.directions_bus_outlined;
  static const IconData busFront = Icons.drive_eta_outlined;
  static const IconData flight = Icons.flight_outlined;
  static const IconData transfer = Icons.local_taxi_outlined;
  static const IconData train = Icons.train_outlined;
  static const IconData locationFrom = Icons.my_location_outlined;
  static const IconData locationTo = Icons.location_on_outlined;
  static const IconData swap = Icons.swap_vert_rounded;

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData ticket = Icons.confirmation_number_outlined;
  static const IconData search = Icons.search_rounded;

  // ── Home / nav ────────────────────────────────────────────────────────────
  static const IconData home = Icons.home_rounded;
  static const IconData calendar = Icons.calendar_today_outlined;
}
