# Bus Live API Wiring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the `bus` feature slice to the real `/buses/*` Wadeny API, replacing `MockBusData` end-to-end per `docs/superpowers/specs/2026-07-08-bus-flow-redesign-design.md` and amendments in `docs/superpowers/specs/2026-07-08-bus-live-api-gaps.md`.

**Architecture:** Dio transport (`BusApi`) → Freezed DTOs → `BusRepositoryImpl` maps to domain entities → `BusBookingNotifier` owns flow state. Trip detail uses cached search object immediately, then background `GET /buses/trips/{id}` merge. Flat fare = `stations_to.final_price × seat count`.

**Tech Stack:** Flutter, Riverpod, Freezed, Dio, go_router, flutter_test.

---

See plan file at `.cursor/plans/wire_bus_flow_to_live_api_5c7ccb2e.plan.md` for full task breakdown and resolved API decisions.
