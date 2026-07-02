# Wadeny API Reference (v1)

> Generated from [`Wadeny.postman_collection.....v2.json`](../api%20postman%20collection/Wadeny.postman_collection.....v2.json)

## Overview

| Property | Value |
|----------|-------|
| **Base URL** | `https://app.telefreik.com` |
| **Collection** | Wadeny |
| **Default auth** | Bearer token (`{{token}}`) |
| **Content-Type** | `application/json` (most endpoints) |
| **Total requests** | 60 |
| **Documented saved responses** | 23 |

Public endpoints (no auth): Auth group (login, register, OTP, password reset) and most Content endpoints.

## Quick reference (unique endpoints)

| Method | Path | Example name |
|--------|------|--------------|
| `DELETE` | `/profile` | Delete account |
| `DELETE` | `/profile/address-book/4` | Delete |
| `DELETE` | `/profile/notifications` | Delete |
| `GET` | `/banners` | Banners list |
| `GET` | `/buses/carriers` | Carriers |
| `GET` | `/buses/locations` | Locations |
| `GET` | `/buses/stations` | Stations |
| `GET` | `/buses/trips` | Search trips |
| `GET` | `/buses/trips/235914/seats` | Seats |
| `GET` | `/buses/trips/236162` | Search details |
| `GET` | `/countries` | Countries List |
| `GET` | `/faq` | Faq |
| `GET` | `/flights/:offer_id/bundles` | Bundels |
| `GET` | `/flights/airports/search` | Airports |
| `GET` | `/flights/iata` | IATA |
| `GET` | `/pages` | Pages |
| `GET` | `/pages/sy-s-lkhsosy` | Show Page |
| `GET` | `/partners` | Partners list |
| `GET` | `/posts` | List |
| `GET` | `/posts/:slug` | Show |
| `GET` | `/posts/categories` | Categories |
| `GET` | `/private/search` | Search |
| `GET` | `/profile` | Show profile |
| `GET` | `/profile/address-book` | List |
| `GET` | `/profile/notifications` | List |
| `GET` | `/profile/orders/flights` | List |
| `GET` | `/profile/tickets` | Tickets list |
| `GET` | `/profile/tickets/5` | Show ticket |
| `GET` | `/profile/tickets/6/replies` | List |
| `GET` | `/profile/wallet` | List transactions |
| `GET` | `/settings` | Settings |
| `POST` | `/auth/forget-password` | Forget password |
| `POST` | `/auth/login` | Login |
| `POST` | `/auth/register` | Register |
| `POST` | `/auth/resend-otp` | OTP Re-Send |
| `POST` | `/auth/reset-password` | Reset password |
| `POST` | `/auth/send-otp` | OTP Send |
| `POST` | `/auth/validate-otp` | Validate OTP |
| `POST` | `/auth/verify-otp` | OTP Verification |
| `POST` | `/buses/trips/42109/create-ticket` | Create Ticket |
| `POST` | `/contact` | Contact us |
| `POST` | `/flights/:offer_id` | Pending Trip |
| `POST` | `/flights/:offer_id/confirm` | Confirm Order |
| `POST` | `/flights/:offer_id/hold` | Hold Trip |
| `POST` | `/flights/:offer_id/passengers` | Add Passenger |
| `POST` | `/flights/search` | Search |
| `POST` | `/private/orders` | Orders |
| `POST` | `/profile` | Update profile |
| `POST` | `/profile/address-book` | Create |
| `POST` | `/profile/tickets` | Create Ticket |
| `POST` | `/profile/tickets/6/replies` | Create |
| `POST` | `/profile/update-password` | Update password |
| `POST` | `/profile/verify-alt-phone` | Verify Alt phone |
| `POST` | `/profile/wallet/:amount/charge` | Charge |
| `PUT` | `/profile/address-book/14` | Update |
| `PUT` | `/profile/firebase/token` | Update Token |

## Table of contents

- [Auth](#auth) (8 requests)
- [Profile](#profile) (21 requests)
- [Content](#content) (12 requests)
- [Flights](#flights) (8 requests)
- [Private](#private) (3 requests)
- [Buses](#buses) (7 requests)
- [Currencies](#currencies) (1 requests)
- [Collection issues](#collection-issues)

## Auth

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `POST` | `/auth/login` | Login |
| 2 | `POST` | `/auth/register` | Register |
| 3 | `POST` | `/auth/verify-otp` | OTP Verification |
| 4 | `POST` | `/auth/resend-otp` | OTP Re-Send |
| 5 | `POST` | `/auth/send-otp` | OTP Send |
| 6 | `POST` | `/auth/validate-otp` | Validate OTP |
| 7 | `POST` | `/auth/forget-password` | Forget password |
| 8 | `POST` | `/auth/reset-password` | Reset password |

### Response envelope

All Auth endpoints return JSON with this shape (HTTP status may differ from the inner `status` field):

```json
{
  "status": 200,
  "message": "…",
  "errors": {
    "field": "…"
  },
  "data": {}
}
```

- `errors` values are **strings** in live responses; the mobile app normalizes strings and arrays.
- `Accept-Language` (`ar` / `en`) localizes `message` and `errors` text.
- Success responses that return a session include `data.api_token` (Bearer token for subsequent calls).

### Login

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/login` |
| **Full URL** | `https://app.telefreik.com/auth/login` |
| **Auth** | No (public) |

**Body (form-data):** `phonecode`, `mobile`, `password`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Content-Type` | application/json |
| `Accept-Language` | en |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `422` | Invalid credentials | default | `credentials` |
| `400` | Mobile not registered | default | `mobile` |
| `200` | Success — user data | default | — |
| `200` | Success — user data | en | — |
| `422` | Invalid credentials | en | `credentials` |
| `400` | Mobile not registered | en | `mobile` |

#### 422 — Invalid credentials (default)

```json
{
  "status": 422,
  "message": "invalid credential",
  "errors": {
    "credentials": "رقم الهاتف او كلمة المرور غير صحيحة"
  },
  "data": {}
}
```

#### 400 — Mobile not registered (default)

```json
{
  "status": 400,
  "message": "رقم الهاتف غير مسجل لدينا",
  "errors": {
    "mobile": "رقم الهاتف غير مسجل لدينا"
  },
  "data": {}
}
```

#### 200 — Success — user data (default)

```json
{
  "status": 200,
  "message": "ببانات المستخدم",
  "errors": {},
  "data": {
    "id": 75,
    "name": "abdallah",
    "email": "elmohamady82@gmail.com",
    "mobile": "1554052685",
    "phonecode": "20",
    "status": "Active",
    "avatar": "",
    "api_token": "<redacted>",
    "is_profile_completed": true
  }
}
```

#### 200 — Success — user data (en)

```json
{
  "status": 200,
  "message": "User data",
  "errors": {},
  "data": {
    "id": 75,
    "name": "abdallah",
    "email": "elmohamady82@gmail.com",
    "mobile": "1554052685",
    "phonecode": "20",
    "status": "Active",
    "avatar": "",
    "api_token": "<redacted>",
    "is_profile_completed": true
  }
}
```

#### 422 — Invalid credentials (en)

```json
{
  "status": 422,
  "message": "invalid credential",
  "errors": {
    "credentials": "phone or password in invalid"
  },
  "data": {}
}
```

#### 400 — Mobile not registered (en)

```json
{
  "status": 400,
  "message": "Mobile number is not exists",
  "errors": {
    "mobile": "Mobile number is not exists"
  },
  "data": {}
}
```

### Register

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/register` |
| **Full URL** | `https://app.telefreik.com/auth/register` |
| **Auth** | No (public) |

**Body (form-data):** `email`, `mobile`, `phonecode`, `name`, `password`, `password_confirmation`, `firebase_token`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `400` | Email and mobile already taken (×2) | ar | `email`, `mobile` |
| `400` | Mobile not registered | ar | `mobile` |
| `200` | Success — OTP sent | ar | — |

#### 400 — Email and mobile already taken (ar)

```json
{
  "status": 400,
  "message": "قيمة حقل البريد الالكتروني مُستخدمة من قبل",
  "errors": {
    "email": "قيمة حقل البريد الالكتروني مُستخدمة من قبل",
    "mobile": "قيمة حقل الجوال مُستخدمة من قبل"
  },
  "data": {}
}
```

#### 400 — Mobile not registered (ar)

```json
{
  "status": 400,
  "message": "قيمة حقل الجوال مُستخدمة من قبل",
  "errors": {
    "mobile": "قيمة حقل الجوال مُستخدمة من قبل"
  },
  "data": {}
}
```

#### 200 — Success — OTP sent (ar)

```json
{
  "status": 200,
  "message": "تم ارسال كود التحقيق",
  "errors": {},
  "data": {}
}
```

### OTP Verification

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/verify-otp` |
| **Full URL** | `https://app.telefreik.com/auth/verify-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Success — user data | ar | — |
| `400` | Invalid verification code | ar | `code` |

#### 200 — Success — user data (ar)

```json
{
  "status": 200,
  "message": "User logged in successfully.",
  "errors": {},
  "data": {
    "id": 75,
    "name": "abdallah",
    "email": "elmohamady82@gmail.com",
    "mobile": "1554052685",
    "phonecode": "20",
    "status": "Active",
    "avatar": "",
    "api_token": "<redacted>",
    "is_profile_completed": true
  }
}
```

#### 400 — Invalid verification code (ar)

```json
{
  "status": 400,
  "message": "كود التحقق غير صحيح",
  "errors": {
    "code": "كود التحقق غير صحيح"
  },
  "data": {}
}
```

### OTP Re-Send

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/resend-otp` |
| **Full URL** | `https://app.telefreik.com/auth/resend-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`

**Headers:**

| Header | Value |
|--------|-------|
| `Content-Type` | application/json |
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Success — OTP sent | ar | — |
| `404` | Record not found | ar | — |

#### 200 — Success — OTP sent (ar)

```json
{
  "status": 200,
  "message": "تم ارسال كود التحقيق",
  "errors": {},
  "data": {}
}
```

#### 404 — Record not found (ar)

```json
{
  "status": 404,
  "message": "This record can't be found",
  "errors": {},
  "data": {}
}
```

### OTP Send

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/send-otp` |
| **Full URL** | `https://app.telefreik.com/auth/send-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`

**Headers:**

| Header | Value |
|--------|-------|
| `Content-Type` | application/json |
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Success — OTP sent | ar | — |
| `404` | Record not found | ar | — |

#### 200 — Success — OTP sent (ar)

```json
{
  "status": 200,
  "message": "تم ارسال كود التحقيق",
  "errors": {},
  "data": {}
}
```

#### 404 — Record not found (ar)

```json
{
  "status": 404,
  "message": "This record can't be found",
  "errors": {},
  "data": {}
}
```

### Validate OTP

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/validate-otp` |
| **Full URL** | `https://app.telefreik.com/auth/validate-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `400` | Invalid verification code | ar | `code` |
| `200` | Success — valid code | ar | — |

#### 400 — Invalid verification code (ar)

```json
{
  "status": 400,
  "message": "كود التحقق غير صحيح",
  "errors": {
    "code": "كود التحقق غير صحيح"
  },
  "data": {}
}
```

#### 200 — Success — valid code (ar)

```json
{
  "status": 200,
  "message": "Valid code",
  "errors": {},
  "data": {}
}
```

### Forget password

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/forget-password` |
| **Full URL** | `https://app.telefreik.com/auth/forget-password` |
| **Auth** | No (public) |

**Body (JSON):**

```json
{
  "mobile": 1554052685,
  "phonecode": 20
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Content-Type` | application/json |
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Success — OTP sent | ar | — |
| `400` | Mobile not registered | ar | `mobile` |

#### 200 — Success — OTP sent (ar)

```json
{
  "status": 200,
  "message": "تم ارسال كود التحقيق",
  "errors": {},
  "data": {}
}
```

#### 400 — Mobile not registered (ar)

```json
{
  "status": 400,
  "message": "رقم الهاتف غير مسجل لدينا",
  "errors": {
    "mobile": "رقم الهاتف غير مسجل لدينا"
  },
  "data": {}
}
```

### Reset password

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/reset-password` |
| **Full URL** | `https://app.telefreik.com/auth/reset-password` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`, `password`, `password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Content-Type` | application/json |
| `Accept` | application/json |
| `Accept-Language` | ar |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `400` | Invalid verification code | ar | `code` |
| `400` | Invalid verification code | ar | `code`, `password` |
| `400` | Password confirmation mismatch | ar | `password` |
| `200` | Success — password updated | ar | — |

#### 400 — Invalid verification code (ar)

```json
{
  "status": 400,
  "message": "كود التحقق غير صحيح",
  "errors": {
    "code": "كود التحقق غير صحيح"
  },
  "data": {}
}
```

#### 400 — Invalid verification code (ar)

```json
{
  "status": 400,
  "message": "كود التحقق غير صحيح",
  "errors": {
    "code": "كود التحقق غير صحيح",
    "password": "حقل التأكيد غير مُطابق للحقل كلمة المرور"
  },
  "data": {}
}
```

#### 400 — Password confirmation mismatch (ar)

```json
{
  "status": 400,
  "message": "حقل التأكيد غير مُطابق للحقل كلمة المرور",
  "errors": {
    "password": "حقل التأكيد غير مُطابق للحقل كلمة المرور"
  },
  "data": {}
}
```

#### 200 — Success — password updated (ar)

```json
{
  "status": 200,
  "message": "تم تحديث كلمة المرور",
  "errors": {},
  "data": {}
}
```

## Profile

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/profile/address-book` | List |
| 2 | `POST` | `/profile/address-book` | Create |
| 3 | `PUT` | `/profile/address-book/14` | Update |
| 4 | `DELETE` | `/profile/address-book/4` | Delete |
| 5 | `GET` | `/profile/notifications` | List |
| 6 | `DELETE` | `/profile/notifications` | Delete |
| 7 | `GET` | `/profile/tickets/6/replies` | List |
| 8 | `POST` | `/profile/tickets/6/replies` | Create |
| 9 | `GET` | `/profile/tickets` | Tickets list |
| 10 | `GET` | `/profile/tickets/5` | Show ticket |
| 11 | `POST` | `/profile/tickets` | Create Ticket |
| 12 | `GET` | `/profile/wallet` | List transactions |
| 13 | `POST` | `/profile/wallet/:amount/charge` | Charge |
| 14 | `GET` | `/profile/orders/flights` | List |
| 15 | `GET` | `/profile/orders/flights` | Show |
| 16 | `GET` | `/profile` | Show profile |
| 17 | `POST` | `/profile` | Update profile |
| 18 | `PUT` | `/profile/firebase/token` | Update Token |
| 19 | `POST` | `/profile/verify-alt-phone` | Verify Alt phone |
| 20 | `POST` | `/profile/update-password` | Update password |
| 21 | `DELETE` | `/profile` | Delete account |

#### addresses

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/address-book` |
| **Full URL** | `https://app.telefreik.com/profile/address-book` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

### Create

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/address-book` |
| **Full URL** | `https://app.telefreik.com/profile/address-book` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Body (JSON):**

```json
{
  "name": "محرب بيك",
  "map_location": {
    "lat": "24.2222",
    "lng": "46.5555",
    "address_name": "محرم بيك شارع المطافي عماره عشره"
  },
  "notes": "{{$randomLoremText}}"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Update

| | |
|---|---|
| **Method** | `PUT` |
| **Path** | `/profile/address-book/14` |
| **Full URL** | `https://app.telefreik.com/profile/address-book/14` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "phone": "1090510796",
  "map_location": {
    "lat": 31.04472075613956,
    "lng": 31.379182285062797,
    "address_name": "{{$randomStreetAddress}}"
  },
  "city_id": 1,
  "notes": "{{$randomLoremText}}"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

### Delete

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile/address-book/4` |
| **Full URL** | `https://app.telefreik.com/profile/address-book/4` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

#### Notifications

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/notifications` |
| **Full URL** | `https://app.telefreik.com/profile/notifications` |
| **Auth** | Bearer token required |
| **Folder** | Notifications |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

### Delete

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile/notifications` |
| **Full URL** | `https://app.telefreik.com/profile/notifications` |
| **Auth** | Bearer token required |
| **Folder** | Notifications |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

#### Tickets > Replies

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets/6/replies` |
| **Full URL** | `https://app.telefreik.com/profile/tickets/6/replies` |
| **Auth** | Bearer token required |
| **Folder** | Tickets > Replies |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Create

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/tickets/6/replies` |
| **Full URL** | `https://app.telefreik.com/profile/tickets/6/replies` |
| **Auth** | Bearer token required |
| **Folder** | Tickets > Replies |

**Body (form-data):** `message`, `attachments[]`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

#### Tickets

### Tickets list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets` |
| **Full URL** | `https://app.telefreik.com/profile/tickets` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show ticket

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets/5` |
| **Full URL** | `https://app.telefreik.com/profile/tickets/5` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Create Ticket

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/tickets` |
| **Full URL** | `https://app.telefreik.com/profile/tickets` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Body (form-data):** `title`, `description`, `section`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

#### Wallet

### List transactions

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/wallet` |
| **Full URL** | `https://app.telefreik.com/profile/wallet` |
| **Auth** | Bearer token required |
| **Folder** | Wallet |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`, `password`, `password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Charge

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/wallet/:amount/charge` |
| **Full URL** | `https://app.telefreik.com/profile/wallet/:amount/charge` |
| **Auth** | Bearer token required |
| **Folder** | Wallet |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`, `password`, `password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

#### Orders > Flights

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/orders/flights` |
| **Full URL** | `https://app.telefreik.com/profile/orders/flights` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Flights |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/orders/flights` |
| **Full URL** | `https://app.telefreik.com/profile/orders/flights` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Flights |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show profile

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile` |
| **Full URL** | `https://app.telefreik.com/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Update profile

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile` |
| **Full URL** | `https://app.telefreik.com/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Update Token

| | |
|---|---|
| **Method** | `PUT` |
| **Path** | `/profile/firebase/token` |
| **Full URL** | `https://app.telefreik.com/profile/firebase/token` |
| **Auth** | Bearer token required |

**Body (form-data):** 

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Verify Alt phone

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/verify-alt-phone` |
| **Full URL** | `https://app.telefreik.com/profile/verify-alt-phone` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "mobile": 1090510796,
  "phonecode": 20,
  "code": 8241
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Update password

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/update-password` |
| **Full URL** | `https://app.telefreik.com/profile/update-password` |
| **Auth** | Bearer token required |

**Body (form-data):** `current_password`, `new_password`, `new_password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Delete account

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile` |
| **Full URL** | `https://app.telefreik.com/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** 

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `firebase_token` | AhMeDs |

## Content

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/posts` | List |
| 2 | `GET` | `/posts/:slug` | Show |
| 3 | `GET` | `/posts/categories` | Categories |
| 4 | `GET` | `/banners` | Banners list |
| 5 | `GET` | `/faq` | Faq |
| 6 | `GET` | `/partners` | Partners list |
| 7 | `POST` | `/contact` | Contact us |
| 8 | `GET` | `/pages` | Pages |
| 9 | `GET` | `/pages/sy-s-lkhsosy` | Show Page |
| 10 | `GET` | `/countries` | Countries List |
| 11 | `GET` | `/settings` | Settings |
| 12 | `GET` | `—` | New Request |

#### Posts

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/posts` |
| **Full URL** | `https://app.telefreik.com/posts?category_id=1` |
| **Auth** | Bearer token required |
| **Folder** | Posts |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` |  |
| `category_id` | 1 |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/posts/:slug` |
| **Full URL** | `https://app.telefreik.com/posts/:slug` |
| **Auth** | Bearer token required |
| **Folder** | Posts |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Categories

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/posts/categories` |
| **Full URL** | `https://app.telefreik.com/posts/categories` |
| **Auth** | Bearer token required |
| **Folder** | Posts |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Banners list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/banners` |
| **Full URL** | `https://app.telefreik.com/banners` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Faq

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/faq` |
| **Full URL** | `https://app.telefreik.com/faq` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Partners list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/partners` |
| **Full URL** | `https://app.telefreik.com/partners` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Contact us

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/contact` |
| **Full URL** | `https://app.telefreik.com/contact` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Pages

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/pages` |
| **Full URL** | `https://app.telefreik.com/pages` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
]
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show Page

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/pages/sy-s-lkhsosy` |
| **Full URL** | `https://app.telefreik.com/pages/sy-s-lkhsosy` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "{{$randomLoremLines}}"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Countries List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/countries` |
| **Full URL** | `https://app.telefreik.com/countries` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "lorem ipsum lorem ipsum lorem ipsum lorem ipsum"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Settings

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/settings` |
| **Full URL** | `https://app.telefreik.com/settings` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "email": "{{$randomEmail}}",
  "phone": "{{$randomBankAccount}}",
  "message": "{{$randomLoremLines}}"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### New Request

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `*(not configured)*` |
| **Full URL** | `*(not configured)*` |
| **Auth** | Bearer token required |

## Flights

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/flights/iata` | IATA |
| 2 | `GET` | `/flights/airports/search` | Airports |
| 3 | `POST` | `/flights/search` | Search |
| 4 | `POST` | `/flights/:offer_id/confirm` | Confirm Order |
| 5 | `GET` | `/flights/:offer_id/bundles` | Bundels |
| 6 | `POST` | `/flights/:offer_id/passengers` | Add Passenger |
| 7 | `POST` | `/flights/:offer_id/hold` | Hold Trip |
| 8 | `POST` | `/flights/:offer_id` | Pending Trip |

### IATA

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/iata` |
| **Full URL** | `https://app.telefreik.com/flights/iata?search=CAI` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `search` | CAI |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Airports

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/airports/search` |
| **Full URL** | `https://app.telefreik.com/flights/airports/search?term=دبي` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | دبي |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

### Search

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/search` |
| **Full URL** | `https://app.telefreik.com/flights/search` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "origin": "CAI",
  "destination": "RUH",
  "date": "2026-06-30",
  "passengers": [
    {
      "passengerTypeCode": "ADT",
      "count": 1
    }
  ],
  "sortingCriteria": "CheapestFirst",
  "cabinClass": "CABIN_CLASS_ECONOMY",
  "directFlightsOnly": false,
  "trip_type": "one_way",
  "curreny": "SAR"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Confirm Order

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/confirm` |
| **Full URL** | `https://app.telefreik.com/flights/:offer_id/confirm` |
| **Auth** | Bearer token required |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Bundels

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/:offer_id/bundles` |
| **Full URL** | `https://app.telefreik.com/flights/:offer_id/bundles?=` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `` |  |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Add Passenger

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/passengers` |
| **Full URL** | `https://app.telefreik.com/flights/:offer_id/passengers` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "passengers": [
    {
      "title": "MR",
      "firstName": "Ahmed",
      "middleName": "Mostafa",
      "lastName": "Ahmed",
      "birthDate": "1990-01-02",
      "documentNumber": "299060912312",
      "nationalityCountryCode": "EGP",
      "residenceCountryCode": "EGP",
      "gender": "M",
      "email": "ahmed.mostafa.dev.eg@gmail.com",
      "phone": "01090510796",
      "passengerTypeCode": "ADT",
      "address": {
        "countryCode": "EG",
        "cityCode": "91 09305948255",
        "line1": "Sector 132, Logix Technova",
        "line2": "Noida,UP"
      }
    }
  ]
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Hold Trip

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/hold` |
| **Full URL** | `https://app.telefreik.com/flights/:offer_id/hold` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "_selectedBundles": [
    {
      "journeyKey": "Rmx5TmFzI0VHWSNYWX4gNTY2fiB+fkNBSX4wMi8yMy8yMDI2IDA4OjIwfkpFRH4wMi8yMy8yMDI2IDExOjM1fn4=",
      "selectedBundleCode": "LCAI"
    }
  ]
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Pending Trip

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id` |
| **Full URL** | `https://app.telefreik.com/flights/:offer_id` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "selectedBundles": [
    {
      "journeyKey": "Rmx5TmFzI0VHWSNYWX4gNTY2fiB+fkNBSX4wMi8yMy8yMDI2IDA4OjIwfkpFRH4wMi8yMy8yMDI2IDExOjM1fn4=",
      "selectedBundleCode": "PCAI"
    }
  ],
  "currency": "SAR"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Authorization` | Bearer {{token}} |

## Private

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/private/search` | Search |
| 2 | `GET` | `/flights/airports/search` | Show Trip Details |
| 3 | `POST` | `/private/orders` | Orders |

### Search

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/private/search` |
| **Full URL** | `https://app.telefreik.com/private/search?from_latitude=30.0314696&from_longitude=31.2612288&to_latitude=31.182972882989525&to_longitude=29.894801258559188&rounded=false` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `from_latitude` | 30.0314696 |
| `from_longitude` | 31.2612288 |
| `to_latitude` | 31.182972882989525 |
| `to_longitude` | 29.894801258559188 |
| `rounded` | false |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

### Show Trip Details

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/airports/search` |
| **Full URL** | `https://app.telefreik.com/flights/airports/search?term=دبي` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | دبي |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | ar |

### Orders

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/private/orders` |
| **Full URL** | `https://app.telefreik.com/private/orders` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "trip_id": 1,
  "rounded": false,
  "departure": {
    "latitude": "30.0314696",
    "longitude": "31.2612288",
    "date": "2026-12-20"
  },
  "destination": {
    "latitude": "31.182972882989525",
    "longitude": "29.894801258559188",
    "date": "2026-12-20"
  }
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Authorization` | Bearer {{token}} |

## Buses

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/buses/locations` | Locations |
| 2 | `GET` | `/buses/stations` | Stations |
| 3 | `GET` | `/buses/carriers` | Carriers |
| 4 | `GET` | `/buses/trips` | Search trips |
| 5 | `GET` | `/buses/trips/236162` | Search details |
| 6 | `GET` | `/buses/trips/235914/seats` | Seats |
| 7 | `POST` | `/buses/trips/42109/create-ticket` | Create Ticket |

### Locations

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/locations` |
| **Full URL** | `https://app.telefreik.com/buses/locations` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | مرسي |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept-Language` | en |

### Stations

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/stations` |
| **Full URL** | `https://app.telefreik.com/buses/stations` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | سوها |
| `pagination` | false |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept-Language` | ar |

### Carriers

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/carriers` |
| **Full URL** | `https://app.telefreik.com/buses/carriers` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | سوها |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept-Language` | ar |

### Search trips

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips` |
| **Full URL** | `https://app.telefreik.com/buses/trips?city_from=1&city_to=2&date=2026-07-01&page=1&currency=SAR` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `city_from` | 1 |
| `city_to` | 2 |
| `date` | 2026-07-01 |
| `page` | 1 |
| `page` | 2 |
| `currency` | SAR |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept-Language` | en |

### Search details

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips/236162` |
| **Full URL** | `https://app.telefreik.com/buses/trips/236162` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `page` | 1 |
| `accept` |  |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept-Language` | ar |

### Seats

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips/235914/seats` |
| **Full URL** | `https://app.telefreik.com/buses/trips/235914/seats?from_city_id=1&to_city_id=2&from_location_id=EGCAIBCN&to_location_id=EGALEALG&date=2026-04-27` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `from_city_id` | 1 |
| `to_city_id` | 2 |
| `from_location_id` | EGCAIBCN |
| `to_location_id` | EGALEALG |
| `date` | 2026-04-27 |

**Headers:**

| Header | Value |
|--------|-------|
| `Content-Type` | application/json |
| `Accept` | application/json |

### Create Ticket

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/buses/trips/42109/create-ticket` |
| **Full URL** | `https://app.telefreik.com/buses/trips/42109/create-ticket` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "from_city_id": 1,
  "to_city_id": 2,
  "from_location_id": "1647",
  "to_location_id": "1648",
  "date": "2026-04-06",
  "seats": [
    {
      "seat_type_id": "15",
      "seat_id": "15"
    }
  ]
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Content-Type` | application/json |

## Currencies

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/flights/iata` | Currencies |

### Currencies

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/iata` |
| **Full URL** | `https://app.telefreik.com/flights/iata?search=CAI` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `search` | CAI |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |

## Collection issues

The following inconsistencies exist in the Postman collection and may not reflect the real API:

| Item | Issue |
|------|-------|
| Content → New Request | No URL configured (empty request) |
| Private → Show Trip Details | URL points to `/flights/airports/search` instead of a private trip endpoint |
| Currencies | Named "Currencies" but URL is `/flights/iata?search=CAI` — likely copy-paste error |
| Profile → Orders → Flights → Show | Same URL as List (`/profile/orders/flights`) — Show may need `/{id}` |

Nested items under Flights → Search (One Way, Round Trip, Multi City) and under Buses folders are **saved response examples**, not separate API endpoints. They all call the same endpoint as their parent request.

Saved responses documented under Auth (and other folders when using `--responses=all`) are **real response examples** attached to the parent request — not separate endpoints.
