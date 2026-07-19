import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Central icon library for the whole app.
///
/// Every screen references icons through this facade (e.g. [AppIcons.mail])
/// instead of reaching for icon packs directly. That keeps icon usage
/// consistent and lets us swap the backing set in one place without touching
/// call-sites.
///
/// The design direction calls for clean **outline** Tabler glyphs — see
/// `design/V1/uploads/claude-ai-design-brief.md`.
///
/// Brand logos (Google / Facebook / Apple) are *not* icons — they live as SVG
/// assets under `assets/brand/` and render via `BrandMark`.
abstract final class AppIcons {
  // ── Auth & identity ──────────────────────────────────────────────────────
  static const IconData mail = TablerIcons.mail;
  static const IconData lock = TablerIcons.lock;
  static const IconData eye = TablerIcons.eye;
  static const IconData eyeOff = TablerIcons.eyeOff;
  static const IconData user = TablerIcons.user;
  static const IconData phone = TablerIcons.phone;
  static const IconData shield = TablerIcons.shieldCheck;

  // ── Navigation & chrome ──────────────────────────────────────────────────
  static const IconData back = TablerIcons.chevronLeft;
  static const IconData forward = TablerIcons.chevronRight;
  static const IconData chevronDown = TablerIcons.chevronDown;
  static const IconData close = TablerIcons.x;
  static const IconData check = TablerIcons.check;
  static const IconData bell = TablerIcons.bell;

  // ── Travel / domain ──────────────────────────────────────────────────────
  static const IconData bus = TablerIcons.bus;
  static const IconData busFront = TablerIcons.steeringWheel;
  static const IconData private = TablerIcons.diamond;
  static const IconData flight = TablerIcons.plane;
  static const IconData transfer = TablerIcons.car;
  static const IconData train = TablerIcons.train;
  static const IconData locationFrom = TablerIcons.currentLocation;
  static const IconData locationTo = TablerIcons.mapPin;
  static const IconData map = TablerIcons.map;
  static const IconData swap = TablerIcons.arrowsDownUp;

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData wallet = TablerIcons.wallet;
  static const IconData walletDeposit = TablerIcons.arrowDownLeft;
  static const IconData walletWithdraw = TablerIcons.arrowUpRight;
  static const IconData ticket = TablerIcons.ticket;
  static const IconData search = TablerIcons.search;

  // ── Home / nav ────────────────────────────────────────────────────────────
  static const IconData home = TablerIcons.home;
  static const IconData calendar = TablerIcons.calendar;

  // ── Filters & feedback ───────────────────────────────────────────────────
  static const IconData filter = TablerIcons.adjustmentsHorizontal;
  static const IconData error = TablerIcons.alertCircle;

  // ── Ratings ──────────────────────────────────────────────────────────────
  static const IconData star = TablerIcons.star;

  // ── Amenities ────────────────────────────────────────────────────────────
  static const IconData amenityWifi = TablerIcons.wifi;
  static const IconData amenityAC = TablerIcons.airConditioning;
  static const IconData amenitySockets = TablerIcons.plug;
  static const IconData amenityWater = TablerIcons.droplet;
  static const IconData spaceBar = TablerIcons.spacingHorizontal;

  // ── Actions ───────────────────────────────────────────────────────────────
  static const IconData download = TablerIcons.download;
  static const IconData share = TablerIcons.share;
  static const IconData checkCircle = TablerIcons.circleCheck;

  // ── Profile ───────────────────────────────────────────────────────────────
  static const IconData logout = TablerIcons.logout;
  static const IconData language = TablerIcons.language;
  static const IconData settings = TablerIcons.settings;
  static const IconData help = TablerIcons.help;
}
