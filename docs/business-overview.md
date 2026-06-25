# Wadeny — Business Overview

## What is Wadeny?

Wadeny (وادني) is a multi-modal travel booking platform targeting Arabic-speaking users in the Middle East and North Africa region. It is a one-stop app for searching, booking, and managing transportation — covering flights, intercity buses, and private transfers — backed by an in-app wallet and a customer support system.

The backend is hosted at `https://app.telefreik.com` and serves both Arabic and English content via the `Accept-Language` header.

---

## Core Business Domains

### 1. Authentication & Accounts
- Phone-number-based registration with OTP verification
- Login, password reset, and OTP re-send flows
- Firebase push notification token registration
- Account deletion (GDPR-style user control)

### 2. User Profile
- View and update personal info (name, email, phone, avatar)
- Manage a secondary/alternate phone number
- Change password
- Address book: save, update, and delete named locations with GPS coordinates — used for quick booking

### 3. In-App Wallet
- View transaction history
- Charge/top-up the wallet (used to pay for bookings)

### 4. Flight Booking
The flights module supports end-to-end flight reservations:

| Step | What happens |
|------|--------------|
| Search airports | IATA code lookup or free-text airport search (e.g. "دبي") |
| Search flights | One-way, round-trip, or multi-city; filter by cabin class, direct-only, sorting, and currency |
| Browse bundles | View fare bundles (e.g. economy lite vs. flex) per offer |
| Add passengers | Fill passenger details (name, passport, nationality, address) |
| Hold trip | Reserve the offer before payment |
| Confirm order | Finalize and pay for the booking |
| View orders | List and manage booked flight orders from the profile |

Supported currencies include SAR (Saudi Riyal) and others returned by the API.

### 5. Bus Booking
Intercity bus search and ticketing across Egyptian and regional routes:

| Step | What happens |
|------|--------------|
| Search locations/stations | Find bus stops by city or name |
| Browse carriers | View available bus operators |
| Search trips | Find trips between two cities on a given date |
| View trip details | See departure times, pricing, and available seats |
| Select seats | Interactive seat map per trip |
| Book ticket | Create a ticket for selected seats and date |

### 6. Private Transfers
On-demand or pre-booked private vehicle transfers:
- Search by GPS coordinates (from/to latitude & longitude)
- Supports one-way and round trips
- Order placement with departure and destination date/time

### 7. Notifications
- In-app notification inbox (list and delete)
- Firebase token management for push notifications

### 8. Support Tickets
Built-in customer support system:
- Open a ticket with a title, description, and section/category
- View ticket status and history
- Reply to tickets with messages and file attachments

### 9. Content & Discovery
- **Banners**: Promotional banners shown on the home screen
- **Posts/Blog**: Travel articles and news, browsable by category
- **FAQ**: Frequently asked questions
- **Partners**: List of partner companies
- **Static Pages**: Legal, privacy, and informational pages (e.g. Terms of Service)
- **Countries list**: Reference data for country/phone-code selection

---

## Target Market

| Signal | Indication |
|--------|------------|
| `Accept-Language: ar` on all authenticated calls | Primary audience is Arabic speakers |
| Egyptian phone code (`20`) in examples | Egypt is a key market |
| Saudi Riyal (`SAR`) as default currency | Saudi Arabia is a key market |
| Arabic city/station names in examples (e.g. مرسي, سوها) | Egyptian intercity routes |
| Arabic address examples (e.g. محرم بيك) | Egyptian users |
| Flight route example: Cairo (CAI) → Riyadh (RUH) | Egypt–Gulf corridor |

---

## User Journey Summary

```
Register (phone + OTP)
    │
    ▼
Home (banners, discovery)
    │
    ├── Search flights → select bundle → add passengers → hold → pay → order history
    │
    ├── Search buses  → pick trip → select seat → book ticket
    │
    ├── Private transfer → pick coordinates → book
    │
    ├── Wallet → top up → used at checkout
    │
    └── Support → open ticket → reply → resolve
```

---

## Technical Notes for the Mobile App

- All protected endpoints require a **Bearer token** obtained at login.
- The API supports **multi-language responses** — pass `Accept-Language: ar` or `en` per request.
- Push notifications use **Firebase Cloud Messaging**; the device token is registered via `PUT /profile/firebase/token`.
- The address book stores **GPS coordinates** alongside human-readable names — useful for pre-filling pickup/dropoff in the private transfer flow.
- Flight booking is a **multi-step stateful flow**: search → hold → add passengers → select bundle → confirm. The `offer_id` is the session key across these steps.
