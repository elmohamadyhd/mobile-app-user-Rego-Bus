# Trip details — one-time coach tour

> Design spec · 2026-07-19
> Feature slice: `lib/features/bus`

## Problem

First-time users on `BusTripDetailsScreen` cannot discover:

- Tap a timeline row to change boarding / drop-off (and update fare)
- Header map button for the full route in Google Maps
- Long-press a row to open a single stop in Google Maps

## Solution

A **skippable, one-time coach overlay** (3 steps) shown on first visit to trip details when a trip is loaded. Persist `trip_details_coach_seen` in `SecureStorage`. Skip or complete marks seen; dispose mid-tour also marks seen.

## Steps

1. Spotlight first boarding row — tap to choose stops, price updates
2. Spotlight map FAB — full route in Google Maps
3. Spotlight a drop-off row — long-press for single stop on map

## Components

- `CoachMarkOverlay` — reusable in `shared/widgets/`
- `TripDetailsCoach` — step config + storage wiring in bus feature
- `SecureStorage.tripDetailsCoachSeen()` / `setTripDetailsCoachSeen()`

## Out of scope

Settings replay, coach on other screens, per-row map icons.
